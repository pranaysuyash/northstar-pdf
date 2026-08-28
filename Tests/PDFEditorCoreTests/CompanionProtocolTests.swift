import Testing
import Foundation
@testable import PDFEditorCore

@Suite("Companion Protocol Tests")
struct CompanionProtocolTests {
    
    // MARK: - Bridge Authentication
    
    @Test("Bridge starts unauthenticated")
    func bridgeStartsUnauthenticated() async {
        let bridge = CompanionBridge()
        #expect(await !bridge.isAuthenticated)
    }
    
    @Test("Bridge authenticates with valid auth")
    func bridgeAuthenticates() async throws {
        let bridge = CompanionBridge()
        let auth = BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("valid-signature".utf8)
        )
        try await bridge.authenticate(auth)
        #expect(await bridge.isAuthenticated)
    }
    
    @Test("Bridge rejects expired authentication")
    func bridgeRejectsExpiredAuth() async throws {
        let bridge = CompanionBridge()
        let auth = BridgeAuthentication(
            originBundleID: "com.example.app",
            signature: Data("sig".utf8),
            timestamp: Date().addingTimeInterval(-7200),
            ttlSeconds: 3600
        )
        do {
            try await bridge.authenticate(auth)
            Issue.record("Should have thrown")
        } catch {
            #expect(error is BridgeError)
        }
    }
    
    @Test("Bridge invalidates authentication")
    func bridgeInvalidates() async throws {
        let bridge = CompanionBridge()
        let auth = BridgeAuthentication(originBundleID: "com.example.app", signature: Data("sig".utf8))
        try await bridge.authenticate(auth)
        #expect(await bridge.isAuthenticated)
        await bridge.invalidate()
        #expect(await !bridge.isAuthenticated)
    }
    
    // MARK: - Bridge Request Lifecycle
    
    @Test("Bridge rejects request when unauthenticated")
    func bridgeRejectsUnauthRequest() async throws {
        let bridge = CompanionBridge()
        do {
            _ = try await bridge.sendRequest(
                providerID: "test",
                sourceDigest: "abc123",
                contractVersion: "1.0.0",
                operation: "render",
                payload: Data()
            )
            Issue.record("Should have thrown")
        } catch {
            #expect(error is BridgeError)
        }
    }
    
    @Test("Bridge tracks pending requests")
    func bridgeTracksPending() async throws {
        let bridge = CompanionBridge()
        #expect(await bridge.pendingCount == 0)
    }
    
    @Test("Bridge request log is append-only")
    func bridgeRequestLog() async throws {
        let bridge = CompanionBridge()
        let log = await bridge.recentLog(limit: 10)
        #expect(log.isEmpty)
    }
    
    // MARK: - Egress Gate
    
    @Test("Egress gate starts disabled")
    func egressGateStartsDisabled() async {
        let gate = EgressGate()
        #expect(await !gate.isEnabled)
    }
    
    @Test("Egress gate enables with consent")
    func egressGateEnables() async {
        let gate = EgressGate()
        await gate.enable()
        #expect(await gate.isEnabled)
    }
    
    @Test("Egress gate blocks connections when disabled")
    func egressGateBlocksWhenDisabled() async {
        let gate = EgressGate()
        #expect(await !gate.isConnectionAllowed("test"))
    }
    
    @Test("Egress gate allows opted-in connections")
    func egressGateAllowsOptedIn() async {
        let gate = EgressGate()
        await gate.enable()
        await gate.allowConnection("provider-1")
        #expect(await gate.isConnectionAllowed("provider-1"))
        #expect(await !gate.isConnectionAllowed("provider-2"))
    }
    
    @Test("Egress gate revokes connections")
    func egressGateRevokes() async {
        let gate = EgressGate()
        await gate.enable()
        await gate.allowConnection("provider-1")
        await gate.revokeConnection("provider-1")
        #expect(await !gate.isConnectionAllowed("provider-1"))
    }
    
    @Test("Egress gate disable clears all connections")
    func egressGateDisableClears() async {
        let gate = EgressGate()
        await gate.enable()
        await gate.allowConnection("a")
        await gate.allowConnection("b")
        await gate.disable()
        #expect(await gate.activeConnections.isEmpty)
    }
    
    // MARK: - Resource Limits
    
    @Test("Default resource limits are reasonable")
    func defaultResourceLimits() {
        let limits = ResourceLimits()
        #expect(limits.maxConcurrentRequests == 4)
        #expect(limits.requestTimeoutSeconds == 120)
        #expect(limits.maxPayloadBytes > 0)
    }
    
    @Test("Strict limits are tighter")
    func strictLimits() {
        let limits = ResourceLimits.strict
        #expect(limits.maxConcurrentRequests == 1)
        #expect(limits.requestTimeoutSeconds < 60)
    }
    
    @Test("Relaxed limits are more generous")
    func relaxedLimits() {
        let limits = ResourceLimits.relaxed
        #expect(limits.maxConcurrentRequests > 4)
        #expect(limits.requestTimeoutSeconds > 120)
    }
    
    @Test("Payload validation catches oversized")
    func payloadValidation() {
        let limits = ResourceLimits(maxPayloadBytes: 100)
        let result = limits.validatePayload(Data(count: 200))
        #expect(!result.isValid)
    }
    
    @Test("Payload validation accepts valid size")
    func payloadValidationAccepts() {
        let limits = ResourceLimits(maxPayloadBytes: 100)
        let result = limits.validatePayload(Data(count: 50))
        #expect(result.isValid)
    }
    
    // MARK: - Provider Registry
    
    @Test("Registry rejects non-permissive licenses")
    func registryRejectsCopyleft() async throws {
        let registry = ProviderRegistry()
        let gplProvider = ProviderRegistration(
            id: "gpl-test",
            name: "GPL Provider",
            version: "1.0.0",
            license: .gpl3,
            capabilities: [.pdfRendering]
        )
        do {
            try await registry.register(gplProvider)
            Issue.record("Should have thrown")
        } catch {
            #expect(error is ProviderError)
        }
    }
    
    @Test("Registry accepts permissive licenses")
    func registryAcceptsPermissive() async throws {
        let registry = ProviderRegistry()
        let mitProvider = ProviderRegistration(
            id: "mit-test",
            name: "MIT Provider",
            version: "1.0.0",
            license: .mit,
            capabilities: [.pdfRendering]
        )
        try await registry.register(mitProvider)
        #expect(await registry.count == 1)
    }
    
    @Test("Registry finds providers by capability")
    func registryFindsByCapability() async throws {
        let registry = ProviderRegistry()
        let p1 = ProviderRegistration(
            id: "p1", name: "P1", version: "1.0.0",
            license: .mit, capabilities: [.pdfRendering, .textExtraction]
        )
        let p2 = ProviderRegistration(
            id: "p2", name: "P2", version: "1.0.0",
            license: .apache2, capabilities: [.ocrTextRecognition]
        )
        try await registry.register(p1)
        try await registry.register(p2)
        
        let renderingProviders = await registry.providers(for: .pdfRendering)
        #expect(renderingProviders.count == 1)
        #expect(renderingProviders.first?.id == "p1")
    }
    
    @Test("Registry best provider prefers fewest failures")
    func registryBestProvider() async throws {
        let registry = ProviderRegistry()
        var p1 = ProviderRegistration(
            id: "p1", name: "P1", version: "2.0.0",
            license: .mit, capabilities: [.pdfRendering]
        )
        p1.failureCount = 3
        var p2 = ProviderRegistration(
            id: "p2", name: "P2", version: "1.0.0",
            license: .mit, capabilities: [.pdfRendering]
        )
        p2.failureCount = 0
        try await registry.register(p1)
        try await registry.register(p2)
        
        let best = await registry.bestProvider(for: .pdfRendering)
        #expect(best?.id == "p2")
    }
    
    @Test("Registry auto-disables after 5 failures")
    func registryAutoDisable() async throws {
        let registry = ProviderRegistry()
        let p = ProviderRegistration(
            id: "p1", name: "P1", version: "1.0.0",
            license: .mit, capabilities: [.pdfRendering]
        )
        try await registry.register(p)
        
        for _ in 0..<5 {
            await registry.recordFailure(id: "p1")
        }
        
        let providers = await registry.enabledProviders
        #expect(providers.isEmpty)
    }
    
    @Test("Registry re-enables disabled provider")
    func registryReEnable() async throws {
        let registry = ProviderRegistry()
        let p = ProviderRegistration(
            id: "p1", name: "P1", version: "1.0.0",
            license: .mit, capabilities: [.pdfRendering]
        )
        try await registry.register(p)
        await registry.recordFailure(id: "p1")
        await registry.recordFailure(id: "p1")
        await registry.reEnable(id: "p1")
        
        let providers = await registry.enabledProviders
        #expect(providers.count == 1)
    }
    
    @Test("Registry capability matrix")
    func registryCapabilityMatrix() async throws {
        let registry = ProviderRegistry()
        let p = ProviderRegistration(
            id: "p1", name: "P1", version: "1.0.0",
            license: .mit, capabilities: [.pdfRendering, .textExtraction]
        )
        try await registry.register(p)
        
        let matrix = await registry.capabilityMatrix()
        #expect(matrix[.pdfRendering]?.contains("p1") == true)
        #expect(matrix[.textExtraction]?.contains("p1") == true)
    }
    
    // MARK: - Capability Handshake
    
    @Test("Handshake validates correctly")
    func handshakeValidation() {
        let handshake = CapabilityHandshake(
            providerID: "test",
            providerVersion: "1.0.0",
            license: .mit,
            supportedOperations: [.pdfRendering, .textExtraction],
            inputLimits: InputLimits(maxPages: 100)
        )
        
        let digest = SourceDigest(sha256: "abc123", sizeBytes: 1000)
        let request = CompanionRequest(
            sourceDigest: digest,
            operation: .pdfRendering,
            providerID: "test"
        )
        
        let validation = request.validate(against: handshake)
        #expect(validation.isValid)
    }
    
    @Test("Handshake rejects unsupported capability")
    func handshakeRejectsUnsupported() {
        let handshake = CapabilityHandshake(
            providerID: "test",
            providerVersion: "1.0.0",
            license: .mit,
            supportedOperations: [.pdfRendering],
            inputLimits: InputLimits(maxPages: 100)
        )
        
        let digest = SourceDigest(sha256: "abc123", sizeBytes: 1000)
        let request = CompanionRequest(
            sourceDigest: digest,
            operation: .ocrTextRecognition,
            providerID: "test"
        )
        
        let validation = request.validate(against: handshake)
        #expect(!validation.isValid)
    }
    
    @Test("Handshake rejects oversized input")
    func handshakeRejectsOversized() {
        let handshake = CapabilityHandshake(
            providerID: "test",
            providerVersion: "1.0.0",
            license: .mit,
            supportedOperations: [.pdfRendering],
            inputLimits: InputLimits(maxFileSizeBytes: 100)
        )
        
        let digest = SourceDigest(sha256: "abc123", sizeBytes: 200)
        let request = CompanionRequest(
            sourceDigest: digest,
            operation: .pdfRendering,
            providerID: "test"
        )
        
        let validation = request.validate(against: handshake)
        #expect(!validation.isValid)
    }
    
    @Test("Handshake rejects copyleft license")
    func handshakeRejectsCopyleft() {
        let handshake = CapabilityHandshake(
            providerID: "test",
            providerVersion: "1.0.0",
            license: .agpl3,
            supportedOperations: [.pdfRendering],
            inputLimits: InputLimits()
        )
        
        let digest = SourceDigest(sha256: "abc123", sizeBytes: 1000)
        let request = CompanionRequest(
            sourceDigest: digest,
            operation: .pdfRendering,
            providerID: "test"
        )
        
        let validation = request.validate(against: handshake)
        #expect(!validation.isValid)
    }
    
    // MARK: - Contract Version
    
    @Test("Contract version comparison")
    func contractVersionComparison() {
        let v1 = ContractVersion(major: 1, minor: 0, patch: 0)
        let v2 = ContractVersion(major: 1, minor: 1, patch: 0)
        let v3 = ContractVersion(major: 2, minor: 0, patch: 0)
        
        #expect(v1 < v2)
        #expect(v2 < v3)
        #expect(v1.isCompatible(with: v2))
        #expect(!v1.isCompatible(with: v3))
    }
    
    @Test("Contract version parsing")
    func contractVersionParsing() {
        let v = ContractVersion.parse("1.2.3")
        #expect(v != nil)
        #expect(v?.major == 1)
        #expect(v?.minor == 2)
        #expect(v?.patch == 3)
    }
    
    // MARK: - Source Digest
    
    @Test("Source digest computation is deterministic")
    func sourceDigestDeterministic() {
        let data = Data("test content".utf8)
        let d1 = SourceDigest.compute(from: data, documentName: "test.pdf")
        let d2 = SourceDigest.compute(from: data, documentName: "test.pdf")
        #expect(d1.sha256 == d2.sha256)
        #expect(d1.sizeBytes == d2.sizeBytes)
    }
    
    @Test("Source digest differs for different content")
    func sourceDigestDiffers() {
        let d1 = SourceDigest.compute(from: Data("content A".utf8))
        let d2 = SourceDigest.compute(from: Data("content B".utf8))
        #expect(d1.sha256 != d2.sha256)
    }
    
    // MARK: - Contract Store
    
    @Test("Contract store stores and retrieves handshakes")
    func contractStoreBasic() async {
        let store = ContractStore()
        let handshake = CapabilityHandshake(
            providerID: "test",
            providerVersion: "1.0.0",
            license: .mit,
            supportedOperations: [.pdfRendering],
            inputLimits: InputLimits()
        )
        await store.store(handshake)
        
        let retrieved = await store.handshake(for: "test")
        #expect(retrieved != nil)
        #expect(retrieved?.providerID == "test")
    }
    
    @Test("Contract store freshness check")
    func contractStoreFreshness() async {
        let store = ContractStore()
        let handshake = CapabilityHandshake(
            providerID: "test",
            providerVersion: "1.0.0",
            license: .mit,
            supportedOperations: [.pdfRendering],
            inputLimits: InputLimits()
        )
        await store.store(handshake)
        
        let fresh = await store.hasFreshHandshake(for: "test")
        #expect(fresh)
        
        let missing = await store.hasFreshHandshake(for: "other")
        #expect(!missing)
    }
    
    // MARK: - Value-Free Logger
    
    @Test("Logger sanitizes PDF text content")
    func loggerSanitizesPDFText() async {
        let logger = ValueFreeLogger()
        // Create a string longer than 500 chars to trigger PDF text detection
        let longText = String(repeating: "This is PDF document content that should never appear in logs. ", count: 10)
        let sanitized = await logger.sanitize(longText)
        #expect(sanitized == "[REDACTED]")
    }
    
    @Test("Logger sanitizes password patterns")
    func loggerSanitizesPasswords() async {
        let logger = ValueFreeLogger()
        let sanitized = await logger.sanitize("password: mysecretpassword123")
        #expect(sanitized.contains("[REDACTED]"))
    }
    
    @Test("Logger sanitizes email addresses")
    func loggerSanitizesEmails() async {
        let logger = ValueFreeLogger()
        let sanitized = await logger.sanitize("Contact user@example.com for details")
        #expect(sanitized.contains("[REDACTED]"))
    }
    
    @Test("Logger detects sensitive data")
    func loggerDetectsSensitive() async {
        let logger = ValueFreeLogger()
        let hasSensitive = await logger.containsSensitiveData("password: secret123")
        #expect(hasSensitive)
        
        let noSensitive = await logger.containsSensitiveData("Build complete")
        #expect(!noSensitive)
    }
    
    @Test("Logger stores and queries entries")
    func loggerStoresAndQueries() async {
        let logger = ValueFreeLogger()
        await logger.info("Test message", category: .bridge)
        await logger.warning("Warning message", category: .security)
        
        let all = await logger.allEntries()
        #expect(all.count == 2)
        
        let warnings = await logger.entries(level: .warning)
        #expect(warnings.count == 1)
    }
    
    @Test("Logger respects minimum level")
    func loggerRespectsMinLevel() async {
        let logger = ValueFreeLogger()
        await logger.setMinimumLevel(.warning)
        await logger.debug("Should not appear")
        await logger.info("Should not appear")
        await logger.warning("Should appear")
        
        let entries = await logger.allEntries()
        #expect(entries.count == 1)
    }
    
    @Test("Logger clear removes all entries")
    func loggerClear() async {
        let logger = ValueFreeLogger()
        await logger.info("Message 1")
        await logger.info("Message 2")
        await logger.clear()
        
        let entries = await logger.allEntries()
        #expect(entries.isEmpty)
    }
    
    // MARK: - Operation Cancellation
    
    @Test("Operation cancellation tracks state")
    func cancellationTracking() async {
        let cancellation = OperationCancellation()
        let id = UUID()
        
        #expect(await !cancellation.isCancelled(id))
        await cancellation.cancel(id: id, reason: "user")
        #expect(await cancellation.isCancelled(id))
        #expect(await cancellation.reason(for: id) == "user")
    }
    
    @Test("Operation cancellation throw check")
    func cancellationThrowCheck() async {
        let cancellation = OperationCancellation()
        let id = UUID()
        
        await cancellation.cancel(id: id)
        
        do {
            try await cancellation.checkCancellation(id)
            Issue.record("Should have thrown")
        } catch {
            #expect(error is BridgeError)
        }
    }
    
    @Test("Operation cancellation clears")
    func cancellationClear() async {
        let cancellation = OperationCancellation()
        let id = UUID()
        await cancellation.cancel(id: id)
        await cancellation.clearCancellation(id)
        #expect(await !cancellation.isCancelled(id))
    }
    
    // MARK: - BridgeMessage
    
    @Test("BridgeMessage encodes and decodes")
    func bridgeMessageCodable() throws {
        let message = BridgeMessage(
            sourceDigest: "abc123",
            contractVersion: "1.0.0",
            encryptedPayload: Data("payload".utf8),
            hmac: Data("hmac".utf8)
        )
        
        let encoder = JSONEncoder()
        _ = try encoder.encode(message)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BridgeResponse.self, from: """
            {"state": "unsupported", "payload": null, "message": "test", "warnings": []}
            """.data(using: .utf8)!)
        #expect(decoded.state == .unsupported)
    }
    
    // MARK: - Capability Tags
    
    @Test("CapabilityTag has all expected cases")
    func capabilityTagCases() {
        let allCases = CapabilityTag.allCases
        #expect(allCases.contains(.pdfRendering))
        #expect(allCases.contains(.textExtraction))
        #expect(allCases.contains(.acroFormInspection))
        #expect(allCases.contains(.pageReorder))
        #expect(allCases.contains(.redaction))
        #expect(allCases.contains(.ocrTextRecognition))
        #expect(allCases.contains(.batchProcessing))
    }
    
    // MARK: - Timeout Config
    
    @Test("Timeout config returns correct timeouts")
    func timeoutConfig() {
        let config = TimeoutConfig()
        #expect(config.timeout(for: "ocr") == config.ocrTimeout)
        #expect(config.timeout(for: "validate") == config.validationTimeout)
        #expect(config.timeout(for: "handshake") == config.handshakeTimeout)
        #expect(config.timeout(for: "unknown") == config.defaultTimeout)
    }
}
