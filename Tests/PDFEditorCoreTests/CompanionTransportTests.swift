import Darwin
import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Companion Transport")
struct CompanionTransportTests {
    
    // MARK: - V-02: Helper for valid HMAC signatures
    
    /// Create a valid HMAC signature for testing.
    private func validSignature(bundleID: String = "com.example.app", timestamp: Date = Date()) -> Data {
        CompanionBridge.computeHMAC(originBundleID: bundleID, timestamp: timestamp)
    }
    
    // MARK: - Mock Transport

    @Test("Mock transport sends and receives messages")
    func mockTransportSendReceive() async throws {
        let transport = MockCompanionTransport()
        let request = Data("test-request".utf8)
        let expectedResponse = Data("test-response".utf8)

        transport.enqueueResponse(expectedResponse)

        let response = try await transport.send(request, timeout: 5)
        #expect(response == expectedResponse)
        #expect(transport.sentMessages.count == 1)
        #expect(transport.sentMessages.first == request)
    }

    @Test("Mock transport records all sent messages")
    func mockTransportRecordsAll() async throws {
        let transport = MockCompanionTransport()
        transport.enqueueResponse(Data("r1".utf8))
        transport.enqueueResponse(Data("r2".utf8))
        transport.enqueueResponse(Data("r3".utf8))

        _ = try await transport.send(Data("m1".utf8), timeout: 5)
        _ = try await transport.send(Data("m2".utf8), timeout: 5)
        _ = try await transport.send(Data("m3".utf8), timeout: 5)

        #expect(transport.sentMessages.count == 3)
    }

    @Test("Mock transport throws when no responses queued")
    func mockTransportEmptyResponses() async {
        let transport = MockCompanionTransport()

        do {
            _ = try await transport.send(Data("request".utf8), timeout: 5)
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("Mock transport throws queued error")
    func mockTransportQueuedError() async {
        let transport = MockCompanionTransport()
        transport.setNextError(TransportError.timeout(5))

        do {
            _ = try await transport.send(Data("request".utf8), timeout: 5)
            Issue.record("Expected error")
        } catch let error as TransportError {
            if case .timeout(let interval) = error {
                #expect(interval == 5)
            } else {
                Issue.record("Wrong error type")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("Mock transport handshake returns queued response")
    func mockTransportHandshake() async throws {
        let transport = MockCompanionTransport()
        let handshakeResponse = Data("handshake-response".utf8)
        transport.enqueueHandshakeResponse(handshakeResponse)

        let response = try await transport.handshake(Data("handshake-request".utf8))
        #expect(response == handshakeResponse)
    }

    @Test("Mock transport reset clears all state")
    func mockTransportReset() async throws {
        let transport = MockCompanionTransport()
        transport.enqueueResponse(Data("r".utf8))
        _ = try await transport.send(Data("m".utf8), timeout: 5)

        transport.reset()
        #expect(transport.sentMessages.isEmpty)
        #expect(transport.responses.isEmpty)
        #expect(transport.isConnected)
    }

    @Test("Mock transport simulated delay works")
    func mockTransportDelay() async throws {
        let transport = MockCompanionTransport()
        transport.simulatedDelay = 0.01
        transport.enqueueResponse(Data("response".utf8))

        let start = Date()
        _ = try await transport.send(Data("request".utf8), timeout: 5)
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed >= 0.01)
    }

    @Test("Mock transport disconnect sets isConnected false")
    func mockTransportDisconnect() async {
        let transport = MockCompanionTransport()
        #expect(transport.isConnected)
        await transport.disconnect()
        #expect(!transport.isConnected)
    }

    // MARK: - Transport Configuration

    @Test("Transport configuration defaults are sensible")
    func configDefaults() {
        let config = TransportConfiguration()
        #expect(config.mode == .local)
        #expect(config.connectionTimeout == 10)
        #expect(config.requireTLS == true)
        #expect(config.maxRetries == 3)
        #expect(config.retryBaseDelay == 0.5)
        #expect(config.keepAlive == true)
    }

    @Test("Local configuration sets socket path")
    func configLocal() {
        let config = TransportConfiguration.local(socketPath: "/tmp/test.sock")
        #expect(config.mode == .local)
        #expect(config.socketPath == "/tmp/test.sock")
    }

    @Test("HTTP configuration sets endpoint")
    func configHTTP() {
        let url = URL(string: "https://companion.example.com")!
        let config = TransportConfiguration.http(endpoint: url)
        #expect(config.mode == .http)
        #expect(config.httpEndpoint == url)
        #expect(config.requireTLS == true)
    }

    @Test("Mock configuration is mock mode")
    func configMock() {
        let config = TransportConfiguration.mock
        #expect(config.mode == .mock)
    }

    @Test("Transport configuration is codable")
    func configCodable() throws {
        let config = TransportConfiguration(
            mode: .http,
            httpEndpoint: URL(string: "https://example.com"),
            connectionTimeout: 30,
            requireTLS: false,
            maxRetries: 5
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TransportConfiguration.self, from: data)
        #expect(decoded.mode == .http)
        #expect(decoded.connectionTimeout == 30)
        #expect(decoded.requireTLS == false)
        #expect(decoded.maxRetries == 5)
    }

    // MARK: - Transport Factory

    @Test("Factory creates mock transport for mock config")
    func factoryMock() {
        let transport = CompanionTransportFactory.transport(for: .mock)
        #expect(transport is MockCompanionTransport)
    }

    @Test("Factory creates HTTP transport for HTTP config")
    func factoryHTTP() {
        let config = TransportConfiguration.http(endpoint: URL(string: "https://example.com")!)
        let transport = CompanionTransportFactory.transport(for: config)
        #expect(transport is HTTPCompanionTransport)
    }

    @Test("Factory creates local transport for local config")
    func factoryLocal() {
        let config = TransportConfiguration.local(socketPath: "/tmp/test.sock")
        let transport = CompanionTransportFactory.transport(for: config)
        #expect(transport is LocalCompanionTransport)
    }

    // MARK: - Transport Errors

    @Test("Transport errors have descriptive messages")
    func transportErrorMessages() {
        #expect(TransportError.connectionFailed("reason").errorDescription?.contains("reason") == true)
        #expect(TransportError.timeout(5).errorDescription?.contains("5") == true)
        #expect(TransportError.connectionClosed.errorDescription != nil)
        #expect(TransportError.notConnected.errorDescription != nil)
        #expect(TransportError.cancelled.errorDescription != nil)
    }

    // MARK: - Bridge + Mock Transport Integration

    @Test("Bridge with mock transport sends request through transport")
    func bridgeMockTransport() async throws {
        let mockTransport = MockCompanionTransport()
        let bridge = CompanionBridge(transport: mockTransport)
        // V-02: use same timestamp for both signature and auth
        let ts = Date()
        try await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: validSignature(timestamp: ts),
            timestamp: ts
        ))

        // Configure mock to return a valid BridgeResponse
        let response = BridgeResponse(state: .unsupported, message: "mock")
        mockTransport.enqueueResponse(try JSONEncoder().encode(response))

        let result = try await bridge.sendRequest(
            providerID: "test",
            sourceDigest: "abc123",
            contractVersion: "1.0.0",
            operation: "render",
            payload: Data("payload".utf8)
        )

        #expect(result.state == .unsupported)
        #expect(result.message == "mock")
        #expect(mockTransport.sentMessages.count == 1)
    }

    @Test("Bridge with mock transport performs handshake")
    func bridgeMockHandshake() async throws {
        let mockTransport = MockCompanionTransport()
        let bridge = CompanionBridge(transport: mockTransport)

        let handshakeResponse = HandshakeResponse(
            provider: ProviderIdentity(
                providerID: "test-provider",
                version: "1.0.0",
                license: .mit,
                displayName: "Test"
            ),
            capabilities: [],
            isReady: true
        )
        mockTransport.enqueueHandshakeResponse(try JSONEncoder().encode(handshakeResponse))

        let result = try await bridge.performHandshake(sourceDigest: "abc123")
        #expect(result.provider.providerID == "test-provider")
        #expect(result.isReady)
    }

    @Test("Bridge transport error propagates correctly")
    func bridgeTransportError() async throws {
        let mockTransport = MockCompanionTransport()
        mockTransport.setNextError(TransportError.timeout(30))
        let bridge = CompanionBridge(transport: mockTransport)
        // V-02: use same timestamp for both signature and auth
        let ts = Date()
        try await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: validSignature(timestamp: ts),
            timestamp: ts
        ))

        do {
            _ = try await bridge.sendRequest(
                providerID: "test",
                sourceDigest: "abc",
                contractVersion: "1.0.0",
                operation: "render",
                payload: Data()
            )
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("Bridge logs transport errors in request log")
    func bridgeLogsTransportErrors() async {
        let mockTransport = MockCompanionTransport()
        mockTransport.setNextError(TransportError.connectionFailed("test"))
        let bridge = CompanionBridge(transport: mockTransport)
        // V-02 fix: use valid HMAC signature
        let timestamp = Date()
        let validSignature = CompanionBridge.computeHMAC(
            originBundleID: "com.example.app",
            timestamp: timestamp
        )
        try? await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: validSignature,
            timestamp: timestamp
        ))

        do {
            _ = try await bridge.sendRequest(
                providerID: "test-provider",
                sourceDigest: "abc",
                contractVersion: "1.0.0",
                operation: "render",
                payload: Data()
            )
        } catch {}

        let log = await bridge.recentLog(limit: 10)
        let failedResponses = log.filter { $0.kind == .response && !$0.success }
        #expect(failedResponses.count == 1)
        #expect(failedResponses.first?.providerID == "test-provider")
    }

    @Test("Bridge unauthenticated request still throws before transport")
    func bridgeUnauthBypassesTransport() async {
        let mockTransport = MockCompanionTransport()
        let bridge = CompanionBridge(transport: mockTransport)

        do {
            _ = try await bridge.sendRequest(
                providerID: "test",
                sourceDigest: "abc",
                contractVersion: "1.0.0",
                operation: "render",
                payload: Data()
            )
            Issue.record("Expected error")
        } catch BridgeError.notAuthenticated {
            // Expected — transport was never called
        } catch {
            Issue.record("Wrong error: \(error)")
        }

        // Transport should not have received any messages
        #expect(mockTransport.sentMessages.isEmpty)
    }

    @Test("Bridge egress gate blocks before transport")
    func bridgeEgressBlocksTransport() async {
        let mockTransport = MockCompanionTransport()
        let bridge = CompanionBridge(transport: mockTransport)
        try? await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8)
        ))
        // Egress gate is disabled by default

        do {
            _ = try await bridge.sendRequest(
                providerID: "test",
                sourceDigest: "abc",
                contractVersion: "1.0.0",
                operation: "ocr",
                payload: Data(),
                connectionID: "remote-provider"
            )
            // If connectionID is nil, egress check is skipped
        } catch {
            #expect(error is BridgeError)
        }

        // Transport should not have been called if connectionID was provided
        #expect(mockTransport.sentMessages.isEmpty)
    }

    // MARK: - Bridge Lifecycle

    @Test("Bridge with mock transport is connected by default")
    func bridgeTransportLifecycle() async throws {
        let bridge = CompanionBridge(configuration: .mock)
        // Mock transport starts connected (in-process, no real connection needed)
        #expect(await bridge.isTransportConnected)
    }

    @Test("Bridge configuration stores and creates transport")
    func bridgeConfigCreation() async throws {
        let bridge = CompanionBridge(configuration: .mock)
        let ts1 = Date()
        try await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: validSignature(timestamp: ts1),
            timestamp: ts1
        ))

        let mockTransport = MockCompanionTransport()
        mockTransport.enqueueResponse(try JSONEncoder().encode(
            BridgeResponse(state: .unsupported, message: "test")
        ))

        // Replace transport with a mock for testing
        let testBridge = CompanionBridge(transport: mockTransport)
        let ts2 = Date()
        try await testBridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: validSignature(timestamp: ts2),
            timestamp: ts2
        ))

        let response = try await testBridge.sendRequest(
            providerID: "test",
            sourceDigest: "abc",
            contractVersion: "1.0.0",
            operation: "render",
            payload: Data()
        )
        #expect(response.state == .unsupported)
    }

    // MARK: - HTTP Transport Configuration

    @Test("HTTP transport initializes with URLSession")
    func httpTransportInit() {
        let config = TransportConfiguration.http(endpoint: URL(string: "https://example.com")!)
        let transport = HTTPCompanionTransport(configuration: config)
        #expect(transport is HTTPCompanionTransport)
    }

    @Test("HTTP transport throws without endpoint")
    func httpTransportNoEndpoint() async {
        let config = TransportConfiguration(mode: .http)
        let transport = HTTPCompanionTransport(configuration: config)

        do {
            _ = try await transport.send(Data("test".utf8), timeout: 5)
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    @Test("HTTP transport handshake throws without endpoint")
    func httpTransportHandshakeNoEndpoint() async {
        let config = TransportConfiguration(mode: .http)
        let transport = HTTPCompanionTransport(configuration: config)

        do {
            _ = try await transport.handshake(Data("test".utf8))
            Issue.record("Expected error")
        } catch {
            #expect(error is TransportError)
        }
    }

    // MARK: - Zero-Egress Doctrine Enforcement (V-05/V-06)

    /// S2: before EgressGate enforcement landed, this send attempted a real
    /// network request and failed with a connection error — not egressDenied.
    @Test("HTTP transport refuses to send while egress gate is disabled")
    func httpTransportSendDeniedWhenGateDisabled() async {
        let config = TransportConfiguration.http(endpoint: URL(string: "https://companion.invalid")!)
        let transport = HTTPCompanionTransport(configuration: config)

        do {
            _ = try await transport.send(Data("payload".utf8), timeout: 5)
            Issue.record("Expected egress denial")
        } catch let error as TransportError {
            guard case .egressDenied = error else {
                Issue.record("Expected .egressDenied, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("HTTP transport refuses to handshake while egress gate is disabled")
    func httpTransportHandshakeDeniedWhenGateDisabled() async {
        let config = TransportConfiguration.http(endpoint: URL(string: "https://companion.invalid")!)
        let transport = HTTPCompanionTransport(configuration: config)

        do {
            _ = try await transport.handshake(Data("hello".utf8))
            Issue.record("Expected egress denial")
        } catch let error as TransportError {
            guard case .egressDenied = error else {
                Issue.record("Expected .egressDenied, got \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    /// Once the gate is enabled and the host is allow-listed, the transport
    /// proceeds past the gate and fails later at the network layer (port 9
    /// refuses instantly), proving the gate no longer blocks an allowed host.
    /// URLSession errors surface as URLError through the retry loop, so the
    /// assertion is "the failure is not egressDenied" rather than a specific type.
    @Test("HTTP transport proceeds past gate when enabled and host allowed")
    func httpTransportSendAllowedAfterGateEnable() async {
        var config = TransportConfiguration.http(endpoint: URL(string: "https://127.0.0.1:9/")!)
        config.maxRetries = 0
        config.connectionTimeout = 3
        let gate = EgressGate()
        let transport = HTTPCompanionTransport(configuration: config, egressGate: gate)

        await gate.enable()
        await gate.allowConnection("127.0.0.1")

        do {
            _ = try await transport.send(Data("payload".utf8), timeout: 5)
            Issue.record("Expected connection failure for refused port")
        } catch {
            if let transportError = error as? TransportError,
               case .egressDenied = transportError {
                Issue.record("Allowed host must not be blocked by the gate")
            }
            // Any other failure (URLError connection refused, …) proves the gate passed.
        }
    }

    /// The shared gate the bridge exposes must be the one the HTTP transport
    /// enforces, so the dashboard's enable/disable controls the data path.
    @Test("Factory passes the shared gate to the HTTP transport")
    func factorySharesEgressGate() async {
        let gate = EgressGate()
        let config = TransportConfiguration.http(endpoint: URL(string: "https://companion.invalid")!)
        let transport = CompanionTransportFactory.transport(for: config, egressGate: gate)

        guard let httpTransport = transport as? HTTPCompanionTransport else {
            Issue.record("Expected HTTP transport")
            return
        }

        let enforcedGate = await httpTransport.egressGate.isEnabled
        let sharedGate = await gate.isEnabled
        #expect(enforcedGate == sharedGate)

        await gate.enable()
        #expect(await httpTransport.egressGate.isEnabled)
    }

    // MARK: - Local Transport

    @Test("Local transport initializes with socket path")
    func localTransportInit() {
        let config = TransportConfiguration.local(socketPath: "/tmp/test.sock")
        let transport = LocalCompanionTransport(configuration: config)
        #expect(transport is LocalCompanionTransport)
        #expect(!transport.isConnected)
    }

    @Test("Local transport connect fails without socket file")
    func localTransportConnectFails() {
        let config = TransportConfiguration.local(socketPath: "/tmp/nonexistent-\(UUID()).sock")
        let transport = LocalCompanionTransport(configuration: config)

        #expect(throws: TransportError.self) {
            try transport.connect()
        }
    }

    @Test("Local transport send throws when not connected")
    func localTransportSendNotConnected() async {
        let config = TransportConfiguration.local(socketPath: "/tmp/test.sock")
        let transport = LocalCompanionTransport(configuration: config)

        do {
            _ = try await transport.send(Data("test".utf8), timeout: 5)
            Issue.record("Expected error")
        } catch TransportError.notConnected {
            // Expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test("Local transport disconnect when not connected is safe")
    func localTransportDisconnectSafe() async {
        let config = TransportConfiguration.local(socketPath: "/tmp/test.sock")
        let transport = LocalCompanionTransport(configuration: config)
        await transport.disconnect()
        #expect(!transport.isConnected)
    }

    // MARK: - V-04: Native Unix Socket Round-Trip

    /// Spawn a blocking Unix domain socket server at `path` that reads one
    /// length-prefixed frame and either echoes the payload back reversed
    /// (proving a real round trip) or stays silent to exercise the timeout.
    private func startEchoServer(at path: String, respond: Bool = true) {
        Thread.detachNewThread {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { return }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = path.utf8CString
            guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
                close(fd)
                return
            }
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dest in
                    for i in 0..<pathBytes.count {
                        dest[i] = pathBytes[i]
                    }
                }
            }

            unlink(path)
            let bindResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard bindResult == 0, listen(fd, 1) == 0 else {
                close(fd)
                return
            }

            var clientAddr = addr
            let clientFD = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                var len = socklen_t(MemoryLayout<sockaddr_un>.size)
                return accept(fd, ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }, &len)
            }
            guard clientFD >= 0 else {
                close(fd)
                return
            }

            func readExact(_ count: Int) -> Data? {
                var data = Data()
                while data.count < count {
                    var chunk = [UInt8](repeating: 0, count: count - data.count)
                    let n = Darwin.read(clientFD, &chunk, chunk.count)
                    guard n > 0 else { return nil }
                    data.append(contentsOf: chunk.prefix(Int(n)))
                }
                return data
            }

            guard let lengthData = readExact(4), lengthData.count == 4 else {
                close(clientFD)
                close(fd)
                return
            }
            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
            guard let payload = readExact(Int(length)) else {
                close(clientFD)
                close(fd)
                return
            }

            if respond {
                // Echo the payload back, reversed, to prove a real round trip.
                let echoed = Data(payload.reversed())
                var outLen = UInt32(echoed.count).bigEndian
                var frame = Data(bytes: &outLen, count: 4)
                frame.append(echoed)
                frame.withUnsafeBytes { _ = Darwin.write(clientFD, $0.baseAddress, frame.count) }
            } else {
                // Stay silent so the client's send() must time out.
                Thread.sleep(forTimeInterval: 5)
            }

            close(clientFD)
            close(fd)
            unlink(path)
        }
    }

    /// Wait for the server socket file to appear (server binds asynchronously).
    private func waitForSocketFile(_ path: String) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("V-04 native socket round-trips a frame without socat")
    func nativeSocketRoundTrip() async throws {
        let path = "/tmp/pdf-editor-v04-roundtrip-\(UUID().uuidString).sock"
        startEchoServer(at: path)
        try await waitForSocketFile(path)

        let transport = LocalCompanionTransport(configuration: .local(socketPath: path))
        try transport.connect()
        #expect(transport.isConnected)

        let payload = Data("v04-native-socket-round-trip".utf8)
        let response = try await transport.send(payload, timeout: 3)
        #expect(response == Data(payload.reversed()))

        await transport.disconnect()
        #expect(!transport.isConnected)
    }

    @Test("V-04 native socket enforces send timeout")
    func nativeSocketTimeout() async throws {
        let path = "/tmp/pdf-editor-v04-timeout-\(UUID().uuidString).sock"
        startEchoServer(at: path, respond: false)
        try await waitForSocketFile(path)

        let transport = LocalCompanionTransport(configuration: .local(socketPath: path))
        try transport.connect()

        do {
            _ = try await transport.send(Data("ping".utf8), timeout: 1)
            Issue.record("Expected timeout")
        } catch TransportError.timeout {
            // Expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }

        await transport.disconnect()
    }

    // MARK: - Codable Round-Trip

    @Test("BridgeMessage encodes and decodes with transport")
    func bridgeMessageTransportRoundTrip() throws {
        let message = BridgeMessage(
            correlationID: UUID(),
            sourceDigest: "abc123",
            contractVersion: "1.0.0",
            encryptedPayload: Data("payload".utf8),
            hmac: Data("hmac".utf8)
        )

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(BridgeMessage.self, from: data)

        #expect(decoded.sourceDigest == message.sourceDigest)
        #expect(decoded.contractVersion == message.contractVersion)
        #expect(decoded.correlationID == message.correlationID)
        #expect(decoded.encryptedPayload == message.encryptedPayload)
    }

    @Test("BridgeResponse encodes and decodes with transport")
    func bridgeResponseTransportRoundTrip() throws {
        let response = BridgeResponse(
            state: .warning,
            payload: Data("result".utf8),
            message: "success",
            warnings: ["minor issue"]
        )

        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(BridgeResponse.self, from: data)

        #expect(decoded.state == .warning)
        #expect(decoded.payload == Data("result".utf8))
        #expect(decoded.message == "success")
        #expect(decoded.warnings == ["minor issue"])
    }
}
