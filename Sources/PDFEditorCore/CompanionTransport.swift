import Foundation
import os
#if canImport(Network)
import Network
#endif

// MARK: - Transport Protocol

/// Abstract transport for companion communication.
///
/// First principle: the companion is optional and the transport is pluggable.
/// The bridge never assumes a specific transport — it delegates to whichever
/// transport was configured at startup.
///
/// Doctrine alignment:
/// - §3: Do things smartly — pluggable transport prevents vendor lock-in
/// - §8: Capability activation — transport is opt-in per companion
/// - §12: Privacy stays value-free — transport layer never inspects payloads
public protocol CompanionTransport: Sendable {
    /// Send a request envelope and receive a response envelope.
    ///
    /// - Parameters:
    ///   - envelope: The serialized request to send.
    ///   - timeout: Maximum time to wait for a response.
    /// - Returns: The raw response data from the companion.
    /// - Throws: `TransportError` on failure.
    func send(_ envelope: Data, timeout: TimeInterval) async throws -> Data

    /// Perform a handshake with the companion.
    ///
    /// - Parameter request: The handshake request payload.
    /// - Returns: The handshake response payload.
    /// - Throws: `TransportError` on failure.
    func handshake(_ request: Data) async throws -> Data

    /// Cancel an in-flight request by correlation ID.
    func cancel(correlationID: UUID) async

    /// Whether the transport is currently connected/available.
    var isConnected: Bool { get async }

    /// Tear down the transport connection.
    func disconnect() async
}

// MARK: - Transport Errors

/// Errors specific to the transport layer.
public enum TransportError: Error, LocalizedError, Sendable {
    case connectionFailed(String)
    case timeout(TimeInterval)
    case connectionClosed
    case invalidResponse(String)
    case handshakeFailed(String)
    case tlsError(String)
    case dnsResolutionFailed(String)
    case socketError(String)
    case cancelled
    case notConnected

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason): return "Connection failed: \(reason)"
        case .timeout(let interval): return "Transport timed out after \(interval)s"
        case .connectionClosed: return "Connection was closed by the remote end"
        case .invalidResponse(let detail): return "Invalid response: \(detail)"
        case .handshakeFailed(let reason): return "Handshake failed: \(reason)"
        case .tlsError(let detail): return "TLS error: \(detail)"
        case .dnsResolutionFailed(let host): return "DNS resolution failed for \(host)"
        case .socketError(let detail): return "Socket error: \(detail)"
        case .cancelled: return "Request was cancelled"
        case .notConnected: return "Transport is not connected"
        }
    }
}

// MARK: - Transport Configuration

/// Configures how the bridge connects to a companion.
public struct TransportConfiguration: Codable, Sendable, Hashable {
    /// The transport mode to use.
    public var mode: TransportMode

    /// HTTP endpoint URL (for HTTP mode).
    public var httpEndpoint: URL?

    /// Unix domain socket path (for local IPC mode).
    public var socketPath: String?

    /// Connection timeout in seconds.
    public var connectionTimeout: TimeInterval

    /// Whether to require TLS for HTTP connections.
    public var requireTLS: Bool

    /// Maximum number of retry attempts on transient failures.
    public var maxRetries: Int

    /// Base delay between retries in seconds (exponential backoff).
    public var retryBaseDelay: TimeInterval

    /// Whether to keep connections alive between requests.
    public var keepAlive: Bool

    public init(
        mode: TransportMode = .local,
        httpEndpoint: URL? = nil,
        socketPath: String? = nil,
        connectionTimeout: TimeInterval = 10,
        requireTLS: Bool = true,
        maxRetries: Int = 3,
        retryBaseDelay: TimeInterval = 0.5,
        keepAlive: Bool = true
    ) {
        self.mode = mode
        self.httpEndpoint = httpEndpoint
        self.socketPath = socketPath
        self.connectionTimeout = connectionTimeout
        self.requireTLS = requireTLS
        self.maxRetries = maxRetries
        self.retryBaseDelay = retryBaseDelay
        self.keepAlive = keepAlive
    }

    /// Local IPC configuration (Unix domain socket).
    public static func local(socketPath: String) -> TransportConfiguration {
        TransportConfiguration(mode: .local, socketPath: socketPath)
    }

    /// HTTP configuration.
    public static func http(endpoint: URL, requireTLS: Bool = true) -> TransportConfiguration {
        TransportConfiguration(mode: .http, httpEndpoint: endpoint, requireTLS: requireTLS)
    }

    /// In-process mock configuration (for testing).
    public static let mock = TransportConfiguration(mode: .mock)
}

/// The transport mode determines which concrete transport is used.
public enum TransportMode: String, Codable, Sendable, CaseIterable {
    /// Local IPC via Unix domain socket.
    case local
    /// HTTP/HTTPS to a network companion.
    case http
    /// In-process mock (for testing).
    case mock
}

// MARK: - Transport Factory

/// Creates the appropriate transport based on configuration.
public struct CompanionTransportFactory {
    /// Create a transport from the given configuration.
    public static func transport(for config: TransportConfiguration) -> any CompanionTransport {
        switch config.mode {
        case .local:
            return LocalCompanionTransport(configuration: config)
        case .http:
            return HTTPCompanionTransport(configuration: config)
        case .mock:
            return MockCompanionTransport()
        }
    }
}

// MARK: - HTTP Transport

/// HTTP/HTTPS-based transport for network companions.
///
/// Uses URLSession for HTTP communication with TLS support,
/// timeout enforcement, and retry logic.
public final class HTTPCompanionTransport: CompanionTransport, @unchecked Sendable {
    private let configuration: TransportConfiguration
    private let session: URLSession
    private let sessionDelegate: HTTPTransportDelegate
    private var connected = false

    public var isConnected: Bool { connected }

    public init(configuration: TransportConfiguration) {
        self.configuration = configuration

        let delegate = HTTPTransportDelegate()
        self.sessionDelegate = delegate

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.connectionTimeout
        sessionConfig.timeoutIntervalForResource = configuration.connectionTimeout * 2
        sessionConfig.waitsForConnectivity = true

        if !configuration.keepAlive {
            sessionConfig.httpAdditionalHeaders = ["Connection": "close"]
        }

        self.session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
    }

    public func send(_ envelope: Data, timeout: TimeInterval) async throws -> Data {
        guard let endpoint = configuration.httpEndpoint else {
            throw TransportError.connectionFailed("No HTTP endpoint configured")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout
        request.httpBody = envelope

        var lastError: Error?
        for attempt in 0...configuration.maxRetries {
            do {
                if attempt > 0 {
                    let delay = configuration.retryBaseDelay * pow(2.0, Double(attempt - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw TransportError.invalidResponse("Non-HTTP response")
                }

                switch httpResponse.statusCode {
                case 200...299:
                    connected = true
                    return data
                case 400...499:
                    // Client errors — don't retry
                    throw TransportError.invalidResponse("HTTP \(httpResponse.statusCode)")
                case 500...599:
                    // Server errors — retry
                    lastError = TransportError.invalidResponse("HTTP \(httpResponse.statusCode)")
                    continue
                default:
                    throw TransportError.invalidResponse("HTTP \(httpResponse.statusCode)")
                }
            } catch let error as TransportError {
                throw error
            } catch {
                lastError = error
                if attempt < configuration.maxRetries {
                    continue
                }
            }
        }

        throw lastError ?? TransportError.connectionFailed("All retry attempts exhausted")
    }

    public func handshake(_ request: Data) async throws -> Data {
        guard let endpoint = configuration.httpEndpoint else {
            throw TransportError.connectionFailed("No HTTP endpoint configured")
        }

        let handshakeURL = endpoint.appendingPathComponent("handshake")
        var urlRequest = URLRequest(url: handshakeURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = configuration.connectionTimeout
        urlRequest.httpBody = request

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TransportError.handshakeFailed("Non-HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                throw TransportError.handshakeFailed("HTTP \(httpResponse.statusCode)")
            }

            connected = true
            return data
        } catch let error as TransportError {
            throw error
        } catch {
            throw TransportError.handshakeFailed(error.localizedDescription)
        }
    }

    public func cancel(correlationID: UUID) async {
        // HTTP is request/response — no persistent connection to cancel.
        // The server will time out the request naturally.
    }

    public func disconnect() async {
        connected = false
        session.invalidateAndCancel()
    }
}

// MARK: - HTTP Transport Delegate

/// URLSession delegate that handles TLS and connection events.
private final class HTTPTransportDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // In production: validate companion server certificate.
        // For now, accept all (the egress gate controls whether
        // we connect at all).
        completionHandler(.performDefaultHandling, nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Connection-level errors are surfaced through the async throw.
    }
}

// MARK: - Local IPC Transport

/// Unix domain socket transport for local companion processes.
///
/// Communicates with a companion running on the same machine via
/// a Unix domain socket. This is the preferred transport for
/// privacy — no network egress required.
///
/// Protocol: length-prefixed JSON messages over a stream socket.
/// Frame format: [4-byte big-endian length][JSON payload]
public final class LocalCompanionTransport: CompanionTransport, @unchecked Sendable {
    private let configuration: TransportConfiguration
    private let socketPath: String
    private var readPipe: Pipe?
    private var writePipe: Pipe?
    private var process: Process?
    private var connected = false

    public var isConnected: Bool { connected }

    public init(configuration: TransportConfiguration) {
        self.configuration = configuration
        self.socketPath = configuration.socketPath ?? "/tmp/pdf-editor-companion-\(UUID().uuidString).sock"
    }

    /// Connect to a running companion process via its Unix socket.
    public func connect() throws {
        guard !connected else { return }

        // Check if socket file exists
        guard FileManager.default.fileExists(atPath: socketPath) else {
            throw TransportError.connectionFailed("Socket not found at \(socketPath)")
        }

        // Create pipes for communication
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/socat")
        proc.arguments = [
            "STDIO", "UNIX-CONNECT:\(socketPath)"
        ]
        proc.standardInput = outputPipe
        proc.standardOutput = inputPipe
        proc.standardError = FileHandle.nullDevice

        do {
            try proc.run()
        } catch {
            throw TransportError.connectionFailed("Failed to launch socat: \(error.localizedDescription)")
        }

        self.process = proc
        self.readPipe = inputPipe
        self.writePipe = outputPipe
        self.connected = true
    }

    /// Connect by launching a companion process.
    public func connect(launchPath: String, arguments: [String] = []) throws {
        guard !connected else { return }

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = arguments
        proc.standardInput = outputPipe
        proc.standardOutput = inputPipe
        proc.standardError = errorPipe

        do {
            try proc.run()
        } catch {
            throw TransportError.connectionFailed("Failed to launch \(launchPath): \(error.localizedDescription)")
        }

        self.process = proc
        self.readPipe = inputPipe
        self.writePipe = outputPipe
        self.connected = true
    }

    public func send(_ envelope: Data, timeout: TimeInterval) async throws -> Data {
        guard connected else {
            throw TransportError.notConnected
        }

        guard let writePipe = writePipe, let readPipe = readPipe else {
            throw TransportError.connectionFailed("Pipes not initialized")
        }

        // Encode as length-prefixed frame
        let frame = lengthPrefix(envelope)

        // Write
        writePipe.fileHandleForWriting.write(frame)

        // Read response with timeout
        let readHandle = readPipe.fileHandleForReading
        let readTask = Task<Data?, Never> { () -> Data? in
            self.readResponse(from: readHandle)
        }

        // Race between read and timeout
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            if let data = await readTask.value {
                return data
            }
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms poll
        }

        // Cancel the read task
        readTask.cancel()
        throw TransportError.timeout(timeout)
    }

    public func handshake(_ request: Data) async throws -> Data {
        return try await send(request, timeout: configuration.connectionTimeout)
    }

    public func cancel(correlationID: UUID) async {
        // For local IPC, we can send a cancellation frame
        // or simply let the companion time out.
    }

    public func disconnect() async {
        connected = false

        writePipe?.fileHandleForWriting.closeFile()
        readPipe?.fileHandleForReading.closeFile()
        process?.terminate()
        process = nil
        readPipe = nil
        writePipe = nil
    }

    // MARK: - Frame Helpers

    /// Read a length-prefixed frame from a file handle.
    private func readResponse(from handle: FileHandle) -> Data? {
        // Read 4-byte length prefix
        let lengthData = handle.readData(ofLength: 4)
        guard lengthData.count == 4 else { return nil }

        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
        guard length > 0, length < 100_000_000 else { return nil } // Sanity check: 100MB max

        return handle.readData(ofLength: Int(length))
    }

    /// Wrap data in a length-prefixed frame.
    private func lengthPrefix(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(data)
        return frame
    }
}

// MARK: - Mock Transport

/// In-process mock transport for testing.
/// Records all sent messages and returns pre-configured responses.
public final class MockCompanionTransport: CompanionTransport, @unchecked Sendable {
    /// Internal mutable state protected by an unfair lock.
    private struct State {
        var sentMessages: [Data] = []
        var responses: [Data] = []
        var handshakeResponses: [Data] = []
        var nextError: Error?
        var isConnected: Bool = true
        var simulatedDelay: TimeInterval = 0
    }
    private let stateBox = OSAllocatedUnfairLock(initialState: State())

    /// Whether the transport reports as connected.
    public var isConnected: Bool {
        get { stateBox.withLock { $0.isConnected } }
        set { stateBox.withLock { $0.isConnected = newValue } }
    }

    /// Simulated delay before returning responses.
    public var simulatedDelay: TimeInterval {
        get { stateBox.withLock { $0.simulatedDelay } }
        set { stateBox.withLock { $0.simulatedDelay = newValue } }
    }

    public init() {}

    /// All messages sent through this transport.
    public var sentMessages: [Data] {
        stateBox.withLock { $0.sentMessages }
    }

    /// Pre-configured responses (read-only access).
    public var responses: [Data] {
        stateBox.withLock { $0.responses }
    }

    /// Set an error to throw on the next send/handshake call (cleared after use).
    public func setNextError(_ error: Error?) {
        stateBox.withLock { $0.nextError = error }
    }

    public func send(_ envelope: Data, timeout: TimeInterval) async throws -> Data {
        let error: Error? = stateBox.withLock { box in
            let e = box.nextError
            box.nextError = nil
            box.sentMessages.append(envelope)
            return e
        }
        if let error { throw error }

        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        return try stateBox.withLock { box in
            guard !box.responses.isEmpty else {
                throw TransportError.invalidResponse("No mock responses configured")
            }
            return box.responses.removeFirst()
        }
    }

    public func handshake(_ request: Data) async throws -> Data {
        let error: Error? = stateBox.withLock { box in
            let e = box.nextError
            box.nextError = nil
            box.sentMessages.append(request)
            return e
        }
        if let error { throw error }

        return try stateBox.withLock { box in
            guard !box.handshakeResponses.isEmpty else {
                throw TransportError.handshakeFailed("No mock handshake responses configured")
            }
            return box.handshakeResponses.removeFirst()
        }
    }

    public func cancel(correlationID: UUID) async {
        // No-op for mock.
    }

    public func disconnect() async {
        stateBox.withLock { $0.isConnected = false }
    }

    /// Queue a response for the next send call.
    public func enqueueResponse(_ response: Data) {
        stateBox.withLock { $0.responses.append(response) }
    }

    /// Queue a handshake response.
    public func enqueueHandshakeResponse(_ response: Data) {
        stateBox.withLock { $0.handshakeResponses.append(response) }
    }

    /// Reset all state.
    public func reset() {
        stateBox.withLock { box in
            box.sentMessages.removeAll()
            box.responses.removeAll()
            box.handshakeResponses.removeAll()
            box.nextError = nil
            box.simulatedDelay = 0
            box.isConnected = true
        }
    }
}
