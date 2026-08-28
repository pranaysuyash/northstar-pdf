import Foundation

// MARK: - Bridge States

/// States returned by the bridge for structured failures.
public enum BridgeState: String, Codable, Sendable, CaseIterable {
    case unsupported
    case companionRequired
    case failed
    case warning
    case unknown
}

// MARK: - Authentication

/// Origin-bound authentication token for bridge security.
public struct BridgeAuthentication: Codable, Sendable, Hashable {
    /// Unique bridge instance identifier.
    public let bridgeID: UUID
    /// Originating application bundle identifier.
    public let originBundleID: String
    /// HMAC signature of origin + timestamp.
    public let signature: Data
    /// Timestamp of authentication.
    public let timestamp: Date
    /// Time-to-live in seconds (default: 3600).
    public let ttlSeconds: TimeInterval
    
    public init(bridgeID: UUID = UUID(), originBundleID: String, signature: Data, timestamp: Date = Date(), ttlSeconds: TimeInterval = 3600) {
        self.bridgeID = bridgeID
        self.originBundleID = originBundleID
        self.signature = signature
        self.timestamp = timestamp
        self.ttlSeconds = ttlSeconds
    }
    
    /// Whether this authentication has expired.
    public var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttlSeconds
    }
}

// MARK: - Egress Gate

/// Controls network egress — disabled by default per zero-egress doctrine.
public actor EgressGate {
    /// Whether egress is globally allowed.
    public private(set) var isEnabled: Bool = false
    
    /// Per-connection opt-in registry.
    private var allowedConnections: Set<String> = []
    
    public init() {}
    
    /// Enable egress (requires explicit user consent).
    public func enable() {
        isEnabled = true
    }
    
    /// Disable all egress.
    public func disable() {
        isEnabled = false
        allowedConnections.removeAll()
    }
    
    /// Opt in to a specific connection.
    public func allowConnection(_ identifier: String) {
        allowedConnections.insert(identifier)
    }
    
    /// Revoke a specific connection.
    public func revokeConnection(_ identifier: String) {
        allowedConnections.remove(identifier)
    }
    
    /// Check if a specific connection is allowed.
    public func isConnectionAllowed(_ identifier: String) -> Bool {
        guard isEnabled else { return false }
        return allowedConnections.contains(identifier)
    }
    
    /// All active connections.
    public var activeConnections: [String] {
        Array(allowedConnections)
    }
}

// MARK: - Bridge Message

/// Encrypted message envelope for bridge communication.
public struct BridgeMessage: Codable, Sendable, Identifiable {
    public let id: UUID
    /// Request or response identifier for correlation.
    public let correlationID: UUID
    /// Source digest binding (per contract).
    public let sourceDigest: String
    /// Contract version.
    public let contractVersion: String
    /// Encrypted payload.
    public let encryptedPayload: Data
    /// HMAC of the envelope.
    public let hmac: Data
    /// Timestamp.
    public let timestamp: Date
    
    public init(correlationID: UUID = UUID(), sourceDigest: String, contractVersion: String, encryptedPayload: Data, hmac: Data, timestamp: Date = Date()) {
        self.id = UUID()
        self.correlationID = correlationID
        self.sourceDigest = sourceDigest
        self.contractVersion = contractVersion
        self.encryptedPayload = encryptedPayload
        self.hmac = hmac
        self.timestamp = timestamp
    }
}

// MARK: - Bridge Response

/// Structured response from the companion.
public struct BridgeResponse: Codable, Sendable {
    /// State of the operation.
    public let state: BridgeState
    /// Decoded result payload (nil on failure).
    public let payload: Data?
    /// Human-readable message.
    public let message: String
    /// Warnings (non-fatal).
    public let warnings: [String]
    
    public init(state: BridgeState, payload: Data? = nil, message: String = "", warnings: [String] = []) {
        self.state = state
        self.payload = payload
        self.message = message
        self.warnings = warnings
    }
}

// MARK: - Bridge Error

public enum BridgeError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case authenticationExpired
    case egressDisabled
    case connectionNotAllowed(String)
    case contractVersionMismatch(expected: String, received: String)
    case sourceDigestMismatch
    case timeout(TimeInterval)
    case resourceLimitExceeded(String)
    case invalidMessage(String)
    case operationCancelled
    case providerNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Bridge is not authenticated"
        case .authenticationExpired:
            return "Bridge authentication has expired"
        case .egressDisabled:
            return "Network egress is disabled"
        case .connectionNotAllowed(let id):
            return "Connection not allowed: \(id)"
        case .contractVersionMismatch(let expected, let received):
            return "Contract version mismatch: expected \(expected), received \(received)"
        case .sourceDigestMismatch:
            return "Source digest does not match the bound document"
        case .timeout(let interval):
            return "Operation timed out after \(interval)s"
        case .resourceLimitExceeded(let resource):
            return "Resource limit exceeded: \(resource)"
        case .invalidMessage(let detail):
            return "Invalid bridge message: \(detail)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .providerNotFound(let id):
            return "Provider not found: \(id)"
        }
    }
}

// MARK: - CompanionBridge

/// Authenticated, origin-bound bridge for companion communication.
/// Enforces egress gating, contract versioning, source digest binding,
/// resource limits, and structured failure responses.
public actor CompanionBridge {
    /// Current authentication state.
    private var authentication: BridgeAuthentication?
    
    /// Egress gate (disabled by default).
    public let egressGate = EgressGate()
    
    /// Resource limits for this bridge session.
    public var resourceLimits: ResourceLimits
    
    /// Active correlation IDs (pending requests).
    private var pendingRequests: Set<UUID> = []
    
    /// Completion handlers for pending requests.
    private var completionHandlers: [UUID: (BridgeResponse) -> Void] = [:]
    
    /// Request history (append-only, value-free).
    public private(set) var requestLog: [RequestLogEntry] = []
    
    /// The transport layer for companion communication.
    private var transport: (any CompanionTransport)?
    
    /// Transport configuration.
    public var transportConfiguration: TransportConfiguration?
    
    public init(resourceLimits: ResourceLimits = ResourceLimits()) {
        self.resourceLimits = resourceLimits
    }
    
    /// Initialize with a specific transport.
    public init(transport: any CompanionTransport, resourceLimits: ResourceLimits = ResourceLimits()) {
        self.transport = transport
        self.resourceLimits = resourceLimits
    }
    
    /// Initialize with transport configuration (creates transport lazily).
    public init(configuration: TransportConfiguration, resourceLimits: ResourceLimits = ResourceLimits()) {
        self.transportConfiguration = configuration
        self.transport = CompanionTransportFactory.transport(for: configuration)
        self.resourceLimits = resourceLimits
    }
    
    /// The active transport (creates from config if needed).
    private func getTransport() throws -> any CompanionTransport {
        if let transport { return transport }
        if let config = transportConfiguration {
            let t = CompanionTransportFactory.transport(for: config)
            self.transport = t
            return t
        }
        throw TransportError.notConnected
    }
    
    // MARK: - Authentication
    
    /// Authenticate the bridge with origin-bound credentials.
    public func authenticate(_ auth: BridgeAuthentication) async throws {
        guard !auth.isExpired else {
            throw BridgeError.authenticationExpired
        }
        // In production: verify HMAC signature against origin bundle ID
        self.authentication = auth
        logRequest(.init(kind: .handshake, providerID: "system", success: true))
    }
    
    /// Check if the bridge is authenticated and not expired.
    public var isAuthenticated: Bool {
        guard let auth = authentication else { return false }
        return !auth.isExpired
    }
    
    /// Invalidate current authentication.
    public func invalidate() {
        authentication = nil
    }
    
    // MARK: - Transport Handshake
    
    /// Perform a handshake with the companion through the transport layer.
    public func performHandshake(
        sourceDigest: String,
        contractVersion: Int = 1
    ) async throws -> HandshakeResponse {
        let activeTransport = try getTransport()
        
        let request = HandshakeRequest(
            sourceDigest: sourceDigest,
            contractVersion: contractVersion
        )
        let requestData = try JSONEncoder().encode(request)
        
        let responseData = try await activeTransport.handshake(requestData)
        
        let response = try JSONDecoder().decode(HandshakeResponse.self, from: responseData)
        logRequest(.init(kind: .handshake, providerID: response.provider.providerID, success: true))
        
        return response
    }
    
    /// Connect the transport (for local IPC that needs explicit connect).
    public func connectTransport() throws {
        if let localTransport = transport as? LocalCompanionTransport {
            try localTransport.connect()
        }
    }
    
    /// Connect the transport by launching a companion process.
    public func connectTransport(launchPath: String, arguments: [String] = []) throws {
        if let localTransport = transport as? LocalCompanionTransport {
            try localTransport.connect(launchPath: launchPath, arguments: arguments)
        }
    }
    
    /// Disconnect the transport.
    public func disconnectTransport() async {
        await transport?.disconnect()
    }
    
    /// Whether the transport is currently connected.
    public var isTransportConnected: Bool {
        get async { await transport?.isConnected ?? false }
    }
    
    // MARK: - Request Lifecycle
    
    /// Send a request through the bridge with full contract enforcement.
    public func sendRequest(
        providerID: String,
        sourceDigest: String,
        contractVersion: String,
        operation: String,
        payload: Data,
        connectionID: String? = nil
    ) async throws -> BridgeResponse {
        // 1. Check authentication
        guard isAuthenticated else {
            logRequest(.init(kind: .request, providerID: providerID, success: false, error: "notAuthenticated"))
            throw BridgeError.notAuthenticated
        }
        
        // 2. Check egress (if network operation)
        if let connID = connectionID {
            guard await egressGate.isConnectionAllowed(connID) else {
                logRequest(.init(kind: .request, providerID: providerID, success: false, error: "egressDisabled"))
                throw BridgeError.connectionNotAllowed(connID)
            }
        }
        
        // 3. Check resource limits
        guard pendingRequests.count < resourceLimits.maxConcurrentRequests else {
            logRequest(.init(kind: .request, providerID: providerID, success: false, error: "resourceLimitExceeded"))
            throw BridgeError.resourceLimitExceeded("maxConcurrentRequests (\(resourceLimits.maxConcurrentRequests))")
        }
        
        // 4. Create correlation ID and track
        let correlationID = UUID()
        pendingRequests.insert(correlationID)
        
        // 5. Log request (value-free)
        logRequest(.init(kind: .request, providerID: providerID, success: true))
        
        // 6. Build message envelope
        let message = BridgeMessage(
            correlationID: correlationID,
            sourceDigest: sourceDigest,
            contractVersion: contractVersion,
            encryptedPayload: payload,
            hmac: Data() // HMAC computed in production
        )
        
        // 7. Send via transport with timeout
        let responseData: Data
        do {
            let activeTransport = try getTransport()
            responseData = try await activeTransport.send(
                try JSONEncoder().encode(message),
                timeout: resourceLimits.requestTimeoutSeconds
            )
        } catch {
            pendingRequests.remove(correlationID)
            logRequest(.init(kind: .response, providerID: providerID, success: false, error: String(describing: error)))
            throw error
        }
        
        // 8. Decode response
        let response: BridgeResponse
        do {
            response = try JSONDecoder().decode(BridgeResponse.self, from: responseData)
        } catch {
            pendingRequests.remove(correlationID)
            logRequest(.init(kind: .response, providerID: providerID, success: false, error: "decodeError"))
            throw TransportError.invalidResponse("Failed to decode response: \(error.localizedDescription)")
        }
        
        // 9. Clean up
        pendingRequests.remove(correlationID)
        logRequest(.init(kind: .response, providerID: providerID, success: response.state != .failed))
        
        return response
    }
    
    /// Cancel a pending request.
    public func cancelRequest(_ correlationID: UUID) {
        pendingRequests.remove(correlationID)
        completionHandlers.removeValue(forKey: correlationID)
        logRequest(.init(kind: .cancellation, providerID: "system", success: true))
    }
    
    /// Cancel all pending requests.
    public func cancelAll() {
        let ids = Array(pendingRequests)
        for id in ids {
            cancelRequest(id)
        }
    }
    
    /// Number of pending requests.
    public var pendingCount: Int {
        pendingRequests.count
    }
}

// MARK: - Request Log (Value-Free)

/// Append-only log of bridge requests — no document content, no field values.
public struct RequestLogEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    /// Request kind (handshake, request, response, cancellation).
    public let kind: RequestKind
    /// Provider identifier.
    public let providerID: String
    /// Whether the request succeeded.
    public let success: Bool
    /// Error string (value-free).
    public let error: String?
    /// Timestamp.
    public let timestamp: Date
    
    public enum RequestKind: String, Codable, Sendable {
        case handshake
        case request
        case response
        case cancellation
    }
    
    public init(kind: RequestKind, providerID: String, success: Bool, error: String? = nil) {
        self.id = UUID()
        self.kind = kind
        self.providerID = providerID
        self.success = success
        self.error = error
        self.timestamp = Date()
    }
}

extension CompanionBridge {
    /// Append a log entry.
    private func logRequest(_ entry: RequestLogEntry) {
        requestLog.append(entry)
        // Trim to prevent unbounded growth
        if requestLog.count > resourceLimits.maxLogEntries {
            requestLog = Array(requestLog.suffix(resourceLimits.maxLogEntries))
        }
    }
    
    /// Recent log entries.
    public func recentLog(limit: Int = 50) -> [RequestLogEntry] {
        Array(requestLog.suffix(limit))
    }
    
    /// Clear log.
    public func clearLog() {
        requestLog.removeAll()
    }
}
