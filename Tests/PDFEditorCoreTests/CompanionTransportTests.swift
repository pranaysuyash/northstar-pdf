import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Companion Transport")
struct CompanionTransportTests {

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
        try await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8)
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
    func bridgeTransportError() async {
        let mockTransport = MockCompanionTransport()
        mockTransport.setNextError(TransportError.timeout(30))
        let bridge = CompanionBridge(transport: mockTransport)
        try? await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8)
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
        try? await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8)
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
        try await bridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8)
        ))

        let mockTransport = MockCompanionTransport()
        mockTransport.enqueueResponse(try JSONEncoder().encode(
            BridgeResponse(state: .unsupported, message: "test")
        ))

        // Replace transport with a mock for testing
        let testBridge = CompanionBridge(transport: mockTransport)
        try await testBridge.authenticate(BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8)
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
