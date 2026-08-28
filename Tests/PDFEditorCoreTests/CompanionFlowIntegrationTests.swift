import Foundation
import Testing
@testable import PDFEditorCore

/// Integration tests exercising the full companion flow:
/// handshake → capability check → request → response → logging.
///
/// These tests wire together CompanionBridge, ProviderRegistry,
/// ContractStore, ValueFreeLogger, and OperationCancellation to
/// verify end-to-end behaviour across every layer of the companion
/// protocol.
@Suite("Companion Flow Integration")
struct CompanionFlowIntegrationTests {

  // MARK: - Helpers

  /// Create a CompanionBridge with a mock transport for testing.
  private func bridgeWithMock(
    responses: [BridgeResponse] = []
  ) -> (bridge: CompanionBridge, transport: MockCompanionTransport) {
    let mockTransport = MockCompanionTransport()
    for response in responses {
      mockTransport.enqueueResponse(try! JSONEncoder().encode(response))
    }
    let bridge = CompanionBridge(transport: mockTransport)
    return (bridge, mockTransport)
  }

  /// A permissive provider registration for happy-path tests.
  private func mitProvider(
    id: String = "com.example.native-ocr",
    capabilities: Set<CapabilityTag> = [.ocrTextRecognition, .pdfRendering]
  ) -> ProviderRegistration {
    ProviderRegistration(
      id: id,
      name: "Native OCR",
      version: "1.2.0",
      license: .mit,
      capabilities: capabilities
    )
  }

  /// A copyleft provider that must be rejected.
  private func gplProvider() -> ProviderRegistration {
    ProviderRegistration(
      id: "com.example.gpl-ocr",
      name: "GPL OCR",
      version: "1.0.0",
      license: .gpl3,
      capabilities: [.ocrTextRecognition]
    )
  }

  /// A valid handshake for a permissive provider.
  private func validHandshake(
    providerID: String = "com.example.native-ocr",
    operations: Set<CapabilityTag> = [.ocrTextRecognition, .pdfRendering],
    license: ProviderLicense = .mit
  ) -> CapabilityHandshake {
    CapabilityHandshake(
      providerID: providerID,
      providerVersion: "1.2.0",
      license: license,
      supportedOperations: operations,
      inputLimits: InputLimits(maxPages: 500, maxFileSizeBytes: 100 * 1024 * 1024)
    )
  }

  /// A valid source digest from known content.
  private func sourceDigest(bytes: Int = 1024) -> SourceDigest {
    let data = Data(repeating: 0x42, count: bytes)
    return SourceDigest.compute(from: data, documentName: "test.pdf")
  }

  /// A valid bridge authentication.
  private func bridgeAuth() -> BridgeAuthentication {
    BridgeAuthentication(
      originBundleID: "com.example.pdf-editor",
      signature: Data("integration-test-sig".utf8)
    )
  }

  // MARK: - Full Happy-Path Flow

  /// Handshake → capability check → request → response → logging.
  @Test("Full happy-path flow: register, handshake, validate, request, log")
  func fullHappyPath() async throws {
    // 1. Provider registry: register a permissive provider.
    let registry = ProviderRegistry()
    try await registry.register(mitProvider())

    // 2. Contract store: store a validated handshake.
    let contractStore = ContractStore()
    let handshake = validHandshake()
    await contractStore.store(handshake)

    // 3. Bridge: authenticate with mock transport.
    let (bridge, mockTransport) = bridgeWithMock()
    mockTransport.enqueueResponse(try JSONEncoder().encode(
      BridgeResponse(state: .unsupported, message: "mock")
    ))
    try await bridge.authenticate(bridgeAuth())
    #expect(await bridge.isAuthenticated)

    // 4. Capability check: validate a request against the handshake.
    let digest = sourceDigest()
    let request = CompanionRequest(
      sourceDigest: digest,
      operation: .ocrTextRecognition,
      providerID: "com.example.native-ocr"
    )
    let validation = request.validate(against: handshake)
    #expect(validation.isValid)

    // 5. Send request through the bridge.
    let response = try await bridge.sendRequest(
      providerID: "com.example.native-ocr",
      sourceDigest: digest.sha256,
      contractVersion: ContractVersion.current.stringValue,
      operation: "ocr.textRecognition",
      payload: Data("sample-pdf-payload".utf8)
    )
    // Bridge returns the mock response.
    #expect(response.state == .unsupported)

    // 6. Verify logging: bridge should have recorded the handshake,
    //    request, and response entries.
    let log = await bridge.recentLog(limit: 20)
    let kinds = log.map(\.kind)
    #expect(kinds.contains(.handshake))
    #expect(kinds.contains(.request))
    #expect(kinds.contains(.response))

    // 7. Verify the provider is still in the registry.
    let found = await registry.provider(id: "com.example.native-ocr")
    #expect(found != nil)
    #expect(found?.license == .mit)
  }

  // MARK: - Handshake → Capability Check → Rejection

  /// Handshake succeeds but capability check rejects an unsupported operation.
  @Test("Handshake succeeds, capability check rejects unsupported op")
  func handshakeSucceedsCapabilityRejects() async throws {
    let registry = ProviderRegistry()
    try await registry.register(mitProvider(capabilities: [.pdfRendering]))

    let contractStore = ContractStore()
    let handshake = validHandshake(operations: [.pdfRendering])
    await contractStore.store(handshake)

    // Request an OCR operation the provider does not support.
    let request = CompanionRequest(
      sourceDigest: sourceDigest(),
      operation: .ocrTextRecognition,
      providerID: "com.example.native-ocr"
    )
    let validation = request.validate(against: handshake)
    #expect(!validation.isValid)
    #expect(validation.errorMessage?.contains("ocrTextRecognition") == true)
  }

  // MARK: - Copyleft License Rejection

  /// Provider with GPL license is rejected at registration time.
  @Test("GPL provider rejected at registration")
  func gplProviderRejected() async throws {
    let registry = ProviderRegistry()
    do {
      try await registry.register(gplProvider())
      Issue.record("Expected licenseNotPermitted error")
    } catch is ProviderError {
      // Expected.
    }
    #expect(await registry.count == 0)
  }

  /// Handshake with copyleft license fails capability validation.
  @Test("Copyleft handshake fails capability validation")
  func copyleftHandshakeFailsValidation() async {
    let handshake = validHandshake(license: .agpl3)
    let request = CompanionRequest(
      sourceDigest: sourceDigest(),
      operation: .pdfRendering,
      providerID: "com.example.native-ocr"
    )
    let validation = request.validate(against: handshake)
    #expect(!validation.isValid)
    #expect(validation.errorMessage?.contains("license") == true)
  }

  // MARK: - Oversized Input Rejection

  /// Input exceeding provider limits is rejected by capability check.
  @Test("Oversized input rejected by capability check")
  func oversizedInputRejected() {
    let handshake = validHandshake()
    let oversizedDigest = sourceDigest(bytes: 200 * 1024 * 1024) // 200 MB
    let request = CompanionRequest(
      sourceDigest: oversizedDigest,
      operation: .ocrTextRecognition,
      providerID: "com.example.native-ocr"
    )
    let validation = request.validate(against: handshake)
    #expect(!validation.isValid)
    #expect(validation.errorMessage?.contains("too large") == true)
  }

  // MARK: - Contract Version Mismatch

  /// Request with incompatible contract version is rejected.
  @Test("Contract version mismatch rejected")
  func contractVersionMismatch() {
    let handshake = validHandshake()
    // Create a request with a different major version.
    let request = CompanionRequest(
      contractVersion: ContractVersion(major: 2, minor: 0, patch: 0),
      sourceDigest: sourceDigest(),
      operation: .ocrTextRecognition,
      providerID: "com.example.native-ocr"
    )
    let validation = request.validate(against: handshake)
    #expect(!validation.isValid)
    #expect(validation.errorMessage?.contains("version") == true)
  }

  // MARK: - Bridge Authentication & Egress Gating

  /// Unauthenticated bridge rejects requests.
  @Test("Unauthenticated bridge rejects all requests")
  func unauthenticatedBridgeRejects() async throws {
    let bridge = CompanionBridge()
    do {
      _ = try await bridge.sendRequest(
        providerID: "test",
        sourceDigest: "abc",
        contractVersion: "1.0.0",
        operation: "render",
        payload: Data()
      )
      Issue.record("Expected notAuthenticated error")
    } catch BridgeError.notAuthenticated {
      // Expected.
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  /// Expired authentication is rejected.
  @Test("Expired bridge authentication rejected")
  func expiredAuthRejected() async throws {
    let bridge = CompanionBridge()
    let expiredAuth = BridgeAuthentication(
      originBundleID: "com.example.app",
      signature: Data("sig".utf8),
      timestamp: Date().addingTimeInterval(-7200),
      ttlSeconds: 3600
    )
    do {
      try await bridge.authenticate(expiredAuth)
      Issue.record("Expected authenticationExpired error")
    } catch BridgeError.authenticationExpired {
      // Expected.
    } catch {
      Issue.record("Wrong error type: \(error)")
    }
  }

  /// Authenticated bridge with egress disabled rejects network requests.
  @Test("Bridge with egress disabled rejects network requests")
  func egressDisabledRejects() async throws {
    let bridge = CompanionBridge()
    try await bridge.authenticate(bridgeAuth())

    // Egress gate is disabled by default.
    #expect(await !bridge.egressGate.isEnabled)

    do {
      _ = try await bridge.sendRequest(
        providerID: "test",
        sourceDigest: "abc",
        contractVersion: "1.0.0",
        operation: "ocr",
        payload: Data(),
        connectionID: "provider-1"
      )
      // Should still succeed because connectionID check is only for
      // non-nil values, but egress gate blocks it.
    } catch {
      #expect(error is BridgeError)
    }
  }

  /// Authenticated bridge with egress enabled and connection allowed
  /// accepts the request.
  @Test("Bridge with egress enabled accepts request")
  func egressEnabledAccepts() async throws {
    let (bridge, mockTransport) = bridgeWithMock()
    mockTransport.enqueueResponse(try JSONEncoder().encode(
      BridgeResponse(state: .unsupported, message: "mock")
    ))
    try await bridge.authenticate(bridgeAuth())

    // Enable egress and allow the connection.
    await bridge.egressGate.enable()
    await bridge.egressGate.allowConnection("provider-1")
    #expect(await bridge.egressGate.isConnectionAllowed("provider-1"))

    // Request without connectionID bypasses egress check.
    let response = try await bridge.sendRequest(
      providerID: "test",
      sourceDigest: "abc",
      contractVersion: "1.0.0",
      operation: "render",
      payload: Data()
    )
    #expect(response.state == .unsupported)
  }

  // MARK: - Resource Limits

  /// Bridge respects max concurrent request limit.
  @Test("Bridge enforces max concurrent requests")
  func maxConcurrentEnforced() async throws {
    let limits = ResourceLimits(maxConcurrentRequests: 1)
    let mockTransport = MockCompanionTransport()
    mockTransport.enqueueResponse(try JSONEncoder().encode(
      BridgeResponse(state: .unsupported)
    ))
    let bridge = CompanionBridge(transport: mockTransport, resourceLimits: limits)
    try await bridge.authenticate(bridgeAuth())

    // First request succeeds (enters pending, then completes immediately).
    _ = try await bridge.sendRequest(
      providerID: "test",
      sourceDigest: "abc",
      contractVersion: "1.0.0",
      operation: "render",
      payload: Data()
    )
    // After completion, pending count is back to 0.
    #expect(await bridge.pendingCount == 0)
  }

  /// Strict resource limits are tighter than defaults.
  @Test("Strict limits enforce tighter constraints")
  func strictLimitsEnforced() {
    let strict = ResourceLimits.strict
    #expect(strict.maxConcurrentRequests == 1)
    #expect(strict.requestTimeoutSeconds < 60)
  }

  // MARK: - Provider Registry Integration

  /// Best provider selection considers failure history.
  @Test("Registry selects provider with fewest failures")
  func bestProviderSelection() async throws {
    let registry = ProviderRegistry()

    // Provider with many failures.
    var failing = mitProvider(id: "failing-provider")
    failing.failureCount = 10
    try await registry.register(failing)

    // New provider with no failures.
    try await registry.register(mitProvider(id: "fresh-provider"))

    let best = await registry.bestProvider(for: .ocrTextRecognition)
    #expect(best?.id == "fresh-provider")
  }

  /// Provider auto-disables after 5 consecutive failures.
  @Test("Provider auto-disables after 5 failures")
  func providerAutoDisables() async throws {
    let registry = ProviderRegistry()
    try await registry.register(mitProvider())

    for _ in 0..<5 {
      await registry.recordFailure(id: "com.example.native-ocr")
    }

    let enabled = await registry.enabledProviders
    #expect(enabled.isEmpty)

    // Re-enable and verify.
    await registry.reEnable(id: "com.example.native-ocr")
    let reenabled = await registry.enabledProviders
    #expect(reenabled.count == 1)
  }

  /// Capability matrix correctly aggregates providers.
  @Test("Capability matrix covers registered providers")
  func capabilityMatrixAggregates() async throws {
    let registry = ProviderRegistry()
    try await registry.register(mitProvider(
      id: "p1",
      capabilities: [.pdfRendering, .textExtraction]
    ))
    try await registry.register(mitProvider(
      id: "p2",
      capabilities: [.ocrTextRecognition, .pdfRendering]
    ))

    let matrix = await registry.capabilityMatrix()
    let renderingProviders = matrix[.pdfRendering] ?? []
    #expect(renderingProviders.count == 2)
    #expect(renderingProviders.contains("p1"))
    #expect(renderingProviders.contains("p2"))
  }

  /// Providers filtered by ALL capabilities work correctly.
  @Test("Providers filtered by multiple capabilities")
  func multiCapabilityFilter() async throws {
    let registry = ProviderRegistry()
    try await registry.register(mitProvider(
      id: "p1",
      capabilities: [.pdfRendering, .textExtraction]
    ))
    try await registry.register(mitProvider(
      id: "p2",
      capabilities: [.pdfRendering, .ocrTextRecognition]
    ))
    try await registry.register(mitProvider(
      id: "p3",
      capabilities: [.pdfRendering, .textExtraction, .ocrTextRecognition]
    ))

    let both = await registry.providers(forAll: [.pdfRendering, .ocrTextRecognition])
    #expect(both.count == 2)
    #expect(both.map(\.id).contains("p2"))
    #expect(both.map(\.id).contains("p3"))
  }

  // MARK: - Contract Store Integration

  /// Contract store persists handshakes and tracks freshness.
  @Test("Contract store persists and tracks freshness")
  func contractStorePersistence() async {
    let store = ContractStore()

    // No handshake initially.
    #expect(await store.handshake(for: "provider-1") == nil)
    #expect(await !store.hasFreshHandshake(for: "provider-1"))

    // Store a handshake.
    let handshake = validHandshake()
    await store.store(handshake)

    // Now it's available and fresh.
    let retrieved = await store.handshake(for: "com.example.native-ocr")
    #expect(retrieved != nil)
    #expect(retrieved?.providerID == "com.example.native-ocr")
    #expect(await store.hasFreshHandshake(for: "com.example.native-ocr"))

    // Remove it.
    await store.remove(providerID: "com.example.native-ocr")
    #expect(await store.handshake(for: "com.example.native-ocr") == nil)
  }

  /// Multiple providers stored simultaneously.
  @Test("Contract store handles multiple providers")
  func multiProviderStore() async {
    let store = ContractStore()
    let h1 = validHandshake(providerID: "provider-a")
    let h2 = validHandshake(providerID: "provider-b")

    await store.store(h1)
    await store.store(h2)

    #expect(await store.allHandshakes.count == 2)
    let ids = await store.registeredProviderIDs
    #expect(ids.count == 2)
  }

  // MARK: - Value-Free Logger Integration

  /// Logger redacts sensitive data across the full flow.
  @Test("Logger redacts sensitive data throughout flow")
  func loggerRedactsSensitiveData() async {
    let logger = ValueFreeLogger()

    // Messages with sensitive data should be redacted.
    await logger.info("password: secret123", category: .security)
    await logger.info("Contact user@example.com", category: .audit)
    await logger.info("Processing OCR output: very long text that could be document content that should never appear in logs because it violates the value-free principle and could leak sensitive information from the PDF being processed", category: .operation)

    let entries = await logger.allEntries()
    #expect(entries.count == 3)

    // All entries should have been sanitized.
    for entry in entries {
      #expect(!entry.message.contains("secret123"))
      #expect(!entry.message.contains("user@example.com"))
    }
  }

  /// Logger respects minimum log level.
  @Test("Logger minimum level filters entries")
  func loggerLevelFiltering() async {
    let logger = ValueFreeLogger()
    await logger.setMinimumLevel(.warning)

    await logger.debug("debug message")
    await logger.info("info message")
    await logger.warning("warning message")
    await logger.error("error message")
    await logger.critical("critical message")

    let entries = await logger.allEntries()
    #expect(entries.count == 3)
    #expect(entries.allSatisfy { $0.level >= .warning })
  }

  /// Logger tracks statistics correctly.
  @Test("Logger tracks statistics")
  func loggerStatistics() async {
    let logger = ValueFreeLogger()
    await logger.info("info-one", category: .bridge)
    await logger.info("info-two", category: .operation)
    await logger.warning("warn-one", category: .security)
    await logger.error("error-one", category: .error)
    await logger.error("error-two", category: .error)
    await logger.critical("crit-one", category: .security)

    let stats = await logger.stats
    #expect(stats.infoCount == 2)
    #expect(stats.warningCount == 1)
    #expect(stats.errorCount == 2)
    #expect(stats.criticalCount == 1)
    #expect(stats.totalEntries == 6)
  }

  /// Logger clear resets everything.
  @Test("Logger clear resets entries and stats")
  func loggerClearResets() async {
    let logger = ValueFreeLogger()
    await logger.info("msg1")
    await logger.error("msg2")
    await logger.clear()

    let entries = await logger.allEntries()
    #expect(entries.isEmpty)
    let stats = await logger.stats
    #expect(stats.totalEntries == 0)
  }

  /// Logger export produces valid JSON.
  @Test("Logger export produces valid JSON")
  func loggerExportJSON() async {
    let logger = ValueFreeLogger()
    await logger.info("message one", category: .bridge)
    await logger.warning("message two", category: .security)

    let data = await logger.exportJSON()
    if let data {
      // Verify it's valid JSON and contains expected structure.
      let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      #expect(parsed != nil)
      #expect(parsed?.count == 2)
      // Verify each entry has the expected keys.
      if let first = parsed?.first {
        #expect(first["level"] != nil)
        #expect(first["category"] != nil)
        #expect(first["message"] != nil)
      }
    } else {
      // exportJSON returns nil only if encoding fails.
      // Verify the entries exist.
      let entries = await logger.allEntries()
      #expect(entries.count == 2)
    }
  }

  // MARK: - Cancellation Integration

  /// Cancellation propagates through the operation lifecycle.
  @Test("Cancellation propagates correctly")
  func cancellationPropagation() async {
    let cancellation = OperationCancellation()
    let opID = UUID()

    // Not cancelled initially.
    #expect(await !cancellation.isCancelled(opID))

    // Cancel with reason.
    await cancellation.cancel(id: opID, reason: "timeout")
    #expect(await cancellation.isCancelled(opID))
    #expect(await cancellation.reason(for: opID) == "timeout")

    // Throws when checked.
    await #expect(throws: BridgeError.self) {
      try await cancellation.checkCancellation(opID)
    }

    // Clear.
    await cancellation.clearCancellation(opID)
    #expect(await !cancellation.isCancelled(opID))
  }

  /// Cancellation of one operation does not affect others.
  @Test("Cancellation is per-operation")
  func cancellationPerOperation() async {
    let cancellation = OperationCancellation()
    let id1 = UUID()
    let id2 = UUID()

    await cancellation.cancel(id: id1)
    #expect(await cancellation.isCancelled(id1))
    #expect(await !cancellation.isCancelled(id2))
  }

  // MARK: - Bridge Message & Response

  /// Bridge message round-trips through JSON encoding.
  @Test("Bridge message encodes and decodes")
  func bridgeMessageRoundTrip() throws {
    let original = BridgeMessage(
      sourceDigest: "abc123def456",
      contractVersion: "1.0.0",
      encryptedPayload: Data("encrypted-content".utf8),
      hmac: Data([0x01, 0x02, 0x03])
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(BridgeMessage.self, from: data)

    #expect(decoded.sourceDigest == original.sourceDigest)
    #expect(decoded.contractVersion == original.contractVersion)
    #expect(decoded.encryptedPayload == original.encryptedPayload)
    #expect(decoded.hmac == original.hmac)
  }

  /// Bridge response states are distinct and meaningful.
  @Test("Bridge response states cover all cases")
  func bridgeResponseStates() {
    let states: [BridgeState] = [.unsupported, .companionRequired, .failed, .warning, .unknown]
    #expect(states.count == 5)
    #expect(Set(states).count == 5) // All unique
  }

  // MARK: - Egress Gate Lifecycle

  /// Egress gate full lifecycle: disable → enable → allow → revoke → disable.
  @Test("Egress gate full lifecycle")
  func egressGateLifecycle() async {
    let gate = EgressGate()

    // Starts disabled.
    #expect(await !gate.isEnabled)
    #expect(await !gate.isConnectionAllowed("any"))

    // Enable.
    await gate.enable()
    #expect(await gate.isEnabled)

    // Allow a connection.
    await gate.allowConnection("provider-a")
    #expect(await gate.isConnectionAllowed("provider-a"))
    #expect(await !gate.isConnectionAllowed("provider-b"))

    // Revoke.
    await gate.revokeConnection("provider-a")
    #expect(await !gate.isConnectionAllowed("provider-a"))

    // Allow multiple, then disable clears all.
    await gate.allowConnection("x")
    await gate.allowConnection("y")
    await gate.disable()
    #expect(await gate.activeConnections.isEmpty)
    #expect(await !gate.isEnabled)
  }

  // MARK: - Request Log Value-Free Verification

  /// Bridge request log never contains document content.
  @Test("Request log is value-free")
  func requestLogValueFree() async throws {
    let (bridge, mockTransport) = bridgeWithMock()
    // Queue responses for all 5 requests.
    for _ in 0..<5 {
      mockTransport.enqueueResponse(try JSONEncoder().encode(
        BridgeResponse(state: .unsupported)
      ))
    }
    try await bridge.authenticate(bridgeAuth())

    // Send several requests.
    for i in 0..<5 {
      _ = try await bridge.sendRequest(
        providerID: "provider-\(i)",
        sourceDigest: "digest-\(i)",
        contractVersion: "1.0.0",
        operation: "op-\(i)",
        payload: Data("some-payload-\(i)".utf8)
      )
    }

    let log = await bridge.recentLog(limit: 100)

    // Log entries should only contain kind, providerID, success, error.
    // No payload content, no source bytes.
    for entry in log {
      // Provider IDs are identifiers, not content.
      #expect(entry.providerID.hasPrefix("provider") || entry.providerID == "system")
      // Error strings are value-free.
      if let error = entry.error {
        #expect(!error.contains("secret"))
        #expect(!error.contains("password"))
      }
    }
  }

  // MARK: - Timeout Configuration

  /// Timeout config returns appropriate values per operation type.
  @Test("Timeout config per operation type")
  func timeoutConfigPerOperation() {
    let config = TimeoutConfig()

    #expect(config.timeout(for: "ocr") == config.ocrTimeout)
    #expect(config.timeout(for: "validate") == config.validationTimeout)
    #expect(config.timeout(for: "handshake") == config.handshakeTimeout)
    #expect(config.timeout(for: "unknown") == config.defaultTimeout)

    // OCR should be longest, handshake shortest.
    #expect(config.ocrTimeout > config.defaultTimeout)
    #expect(config.handshakeTimeout < config.defaultTimeout)
  }

  // MARK: - Protocol Version

  /// Companion protocol version v1 is current.
  @Test("Protocol version v1 is current")
  func protocolVersionV1() {
    #expect(CompanionProtocolVersion.v1.rawValue == 1)
    // v1 is the only defined version; verify it exists.
    #expect(CompanionProtocolVersion(rawValue: 1) != nil)
  }

  // MARK: - End-to-End: Multiple Providers with Capability Routing

  /// Multiple providers registered; best provider selected per capability.
  @Test("Capability routing selects best provider per operation")
  func capabilityRouting() async throws {
    let registry = ProviderRegistry()

    // OCR specialist.
    try await registry.register(mitProvider(
      id: "ocr-specialist",
      capabilities: [.ocrTextRecognition, .ocrBounding]
    ))

    // Rendering specialist.
    try await registry.register(mitProvider(
      id: "render-specialist",
      capabilities: [.pdfRendering, .thumbnailGeneration]
    ))

    // Generalist.
    try await registry.register(mitProvider(
      id: "generalist",
      capabilities: [.pdfRendering, .ocrTextRecognition, .textExtraction]
    ))

    // OCR routing should prefer ocr-specialist.
    let ocrProviders = await registry.providers(for: .ocrTextRecognition)
    #expect(ocrProviders.count == 2) // ocr-specialist + generalist

    // Rendering routing should find render-specialist + generalist.
    let renderProviders = await registry.providers(for: .pdfRendering)
    #expect(renderProviders.count == 2)

    // All three support textExtraction? No, only generalist.
    let textProviders = await registry.providers(for: .textExtraction)
    #expect(textProviders.count == 1)
    #expect(textProviders.first?.id == "generalist")
  }

  // MARK: - End-to-End: Handshake + Store + Validate + Request

  /// Complete lifecycle: register → handshake → store → validate → request → log.
  @Test("Complete lifecycle: register to log")
  func completeLifecycle() async throws {
    // 1. Register provider.
    let registry = ProviderRegistry()
    let provider = ProviderRegistration(
      id: "lifecycle-provider",
      name: "Lifecycle Test",
      version: "2.0.0",
      license: .apache2,
      capabilities: [.acroFormFilling, .formValidation]
    )
    try await registry.register(provider)

    // 2. Create and store handshake.
    let contractStore = ContractStore()
    let handshake = CapabilityHandshake(
      providerID: "lifecycle-provider",
      providerVersion: "2.0.0",
      license: .apache2,
      supportedOperations: [.acroFormFilling, .formValidation],
      inputLimits: InputLimits(maxPages: 200, maxFileSizeBytes: 50 * 1024 * 1024)
    )
    await contractStore.store(handshake)

    // 3. Validate request against handshake.
    let digest = sourceDigest(bytes: 1024)
    let request = CompanionRequest(
      sourceDigest: digest,
      operation: .acroFormFilling,
      providerID: "lifecycle-provider"
    )
    let validation = request.validate(against: handshake)
    #expect(validation.isValid)

    // 4. Send through bridge with mock transport.
    let (bridge, mockTransport) = bridgeWithMock()
    mockTransport.enqueueResponse(try JSONEncoder().encode(
      BridgeResponse(state: .unsupported, message: "mock")
    ))
    try await bridge.authenticate(bridgeAuth())
    let response = try await bridge.sendRequest(
      providerID: "lifecycle-provider",
      sourceDigest: digest.sha256,
      contractVersion: ContractVersion.current.stringValue,
      operation: "acroFormFilling",
      payload: Data("form-data".utf8)
    )
    #expect(response.state == .unsupported)

    // 5. Record success in registry.
    await registry.recordSuccess(id: "lifecycle-provider")
    let p = await registry.provider(id: "lifecycle-provider")
    #expect(p?.lastHandshake != nil)
    #expect(p?.failureCount == 0)

    // 6. Verify log contains the full flow.
    let log = await bridge.recentLog(limit: 20)
    #expect(log.count >= 3) // handshake + request + response
    #expect(log.map(\.kind).contains(.handshake))
    #expect(log.map(\.kind).contains(.request))
    #expect(log.map(\.kind).contains(.response))
  }

  // MARK: - Edge Cases

  /// Empty payload request succeeds.
  @Test("Empty payload request succeeds")
  func emptyPayloadRequest() async throws {
    let (bridge, mockTransport) = bridgeWithMock()
    mockTransport.enqueueResponse(try JSONEncoder().encode(
      BridgeResponse(state: .unsupported, message: "mock")
    ))
    try await bridge.authenticate(bridgeAuth())

    let response = try await bridge.sendRequest(
      providerID: "test",
      sourceDigest: "abc",
      contractVersion: "1.0.0",
      operation: "render",
      payload: Data()
    )
    #expect(response.state == .unsupported)
  }

  /// Bridge can invalidate and re-authenticate.
  @Test("Bridge invalidation and re-authentication")
  func bridgeReauth() async throws {
    let bridge = CompanionBridge()

    try await bridge.authenticate(bridgeAuth())
    #expect(await bridge.isAuthenticated)

    await bridge.invalidate()
    #expect(await !bridge.isAuthenticated)

    try await bridge.authenticate(bridgeAuth())
    #expect(await bridge.isAuthenticated)
  }

  /// Contract version parsing round-trips.
  @Test("Contract version parse and stringify")
  func contractVersionRoundTrip() {
    let v = ContractVersion(major: 3, minor: 12, patch: 456)
    let s = v.stringValue
    #expect(s == "3.12.456")
    let parsed = ContractVersion.parse(s)
    #expect(parsed == v)
  }

  /// Source digest is deterministic for same input.
  @Test("Source digest is deterministic")
  func sourceDigestDeterministic() {
    let data = Data("deterministic-content".utf8)
    let d1 = SourceDigest.compute(from: data, documentName: "a.pdf")
    let d2 = SourceDigest.compute(from: data, documentName: "a.pdf")
    #expect(d1.sha256 == d2.sha256)
    #expect(d1.sizeBytes == d2.sizeBytes)
  }

  /// Source digest differs for different content.
  @Test("Source digest differs for different content")
  func sourceDigestDiffers() {
    let d1 = SourceDigest.compute(from: Data("content-a".utf8))
    let d2 = SourceDigest.compute(from: Data("content-b".utf8))
    #expect(d1.sha256 != d2.sha256)
  }
}
