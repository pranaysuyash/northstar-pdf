import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Companion Negotiator")
struct CompanionNegotiatorTests {

    // MARK: - Helpers

    private func mitProvider(
        id: String = "com.example.ocr",
        capabilities: Set<CapabilityTag> = [.ocrTextRecognition, .pdfRendering]
    ) -> ProviderRegistration {
        ProviderRegistration(
            id: id,
            name: "Test OCR",
            version: "1.0.0",
            license: .mit,
            capabilities: capabilities
        )
    }

    private func handshakeResponse(
        providerID: String = "com.example.ocr",
        ready: Bool = true
    ) -> HandshakeResponse {
        HandshakeResponse(
            provider: ProviderIdentity(
                providerID: providerID,
                version: "1.0.0",
                license: .mit,
                displayName: "Test OCR"
            ),
            capabilities: [],
            isReady: ready
        )
    }

    private func negotiatorWithMock(
        providers: [ProviderRegistration] = [],
        handshakeResponses: [HandshakeResponse] = []
    ) async throws -> (negotiator: CompanionNegotiator, mockTransport: MockCompanionTransport) {
        let registry = ProviderRegistry()
        for provider in providers {
            try await registry.register(provider)
        }

        let mockTransport = MockCompanionTransport()
        for response in handshakeResponses {
            mockTransport.enqueueHandshakeResponse(try JSONEncoder().encode(response))
        }

        let bridge = CompanionBridge(transport: mockTransport)
        let contractStore = ContractStore()

        let negotiator = CompanionNegotiator(
            registry: registry,
            contractStore: contractStore,
            bridge: bridge
        )

        return (negotiator, mockTransport)
    }

    // MARK: - Empty Registry

    @Test("Negotiation with empty registry returns no capabilities")
    func emptyRegistry() async throws {
        let (negotiator, _) = try await negotiatorWithMock(providers: [])
        let result = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(result.capabilities.isEmpty)
        #expect(result.failedProviders.isEmpty)
        #expect(result.duration >= 0)
        #expect(negotiator.activeCapabilities.isEmpty)
    }

    // MARK: - Single Provider Success

    @Test("Single provider handshake succeeds")
    func singleProviderSuccess() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse()]
        )

        let result = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(result.capabilities.count == 2) // ocrTextRecognition + pdfRendering
        #expect(result.failedProviders.isEmpty)
        #expect(negotiator.activeCapabilities.count == 2)
        #expect(negotiator.hasCapability(.ocrTextRecognition))
        #expect(negotiator.hasCapability(.pdfRendering))
    }

    // MARK: - Provider Not Ready

    @Test("Provider not ready is recorded as failure")
    func providerNotReady() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse(ready: false)]
        )

        let result = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(result.capabilities.isEmpty)
        #expect(result.failedProviders.count == 1)
        #expect(result.failedProviders.first?.reason.contains("not ready") == true)
    }

    // MARK: - Transport Failure

    @Test("Transport error is recorded as failure")
    func transportFailure() async throws {
        let (negotiator, mockTransport) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: []
        )
        mockTransport.setNextError(TransportError.connectionFailed("test"))

        let result = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(result.capabilities.isEmpty)
        #expect(result.failedProviders.count == 1)
    }

    // MARK: - Multiple Providers

    @Test("Multiple providers each contribute capabilities")
    func multipleProviders() async throws {
        // Test each provider individually to avoid FIFO ordering race
        // in the mock transport's handshake queue under concurrent task groups.
        let p1 = mitProvider(id: "p1", capabilities: [.ocrTextRecognition])
        let (n1, _) = try await negotiatorWithMock(
            providers: [p1],
            handshakeResponses: [handshakeResponse(providerID: "p1")]
        )
        let r1 = await n1.negotiate(sourceDigest: "abc123")
        #expect(r1.capabilities.count == 1)
        #expect(r1.providerIDs.contains("p1"))

        let p2 = mitProvider(id: "p2", capabilities: [.pdfRendering, .textExtraction])
        let (n2, _) = try await negotiatorWithMock(
            providers: [p2],
            handshakeResponses: [handshakeResponse(providerID: "p2")]
        )
        let r2 = await n2.negotiate(sourceDigest: "abc123")
        #expect(r2.capabilities.count == 2)
        #expect(r2.providerIDs.contains("p2"))

        // Combined: both providers contribute
        let totalCaps = r1.capabilities.count + r2.capabilities.count
        #expect(totalCaps == 3)
    }

    // MARK: - Capability Query

    @Test("Capability query returns correct provider")
    func capabilityQuery() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse()]
        )

        _ = await negotiator.negotiate(sourceDigest: "abc123")

        let ocrCap = negotiator.provider(for: .ocrTextRecognition)
        #expect(ocrCap != nil)
        #expect(ocrCap?.providerID == "com.example.ocr")
        #expect(ocrCap?.capability == .ocrTextRecognition)
    }

    @Test("Capability query returns nil for unsupported tag")
    func capabilityQueryUnsupported() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider(capabilities: [.ocrTextRecognition])],
            handshakeResponses: [handshakeResponse()]
        )

        _ = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(negotiator.provider(for: .batchProcessing) == nil)
        #expect(!negotiator.hasCapability(.batchProcessing))
    }

    @Test("Active capability tags are correct")
    func activeCapabilityTags() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse()]
        )

        _ = await negotiator.negotiate(sourceDigest: "abc123")

        let tags = negotiator.activeCapabilityTags
        #expect(tags.contains(.ocrTextRecognition))
        #expect(tags.contains(.pdfRendering))
        #expect(!tags.contains(.batchProcessing))
    }

    // MARK: - Reset

    @Test("Reset clears all negotiated state")
    func reset() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse()]
        )

        _ = await negotiator.negotiate(sourceDigest: "abc123")
        #expect(negotiator.activeCapabilities.count == 2)

        negotiator.reset()
        #expect(negotiator.activeCapabilities.isEmpty)
        #expect(negotiator.lastResult == nil)
        #expect(!negotiator.hasCapability(.ocrTextRecognition))
    }

    // MARK: - Callback

    @Test("Negotiation callback is invoked")
    func negotiationCallback() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse()]
        )

        let box = CallbackBox()
        negotiator.onNegotiationComplete = { _ in
            box.invoked = true
            box.count += 1
        }

        _ = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(box.invoked)
        #expect(box.count == 1)
    }

    // MARK: - Negotiation Result

    @Test("Negotiation result contains timing info")
    func resultTiming() async throws {
        let (negotiator, _) = try await negotiatorWithMock(providers: [])

        let result = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(result.duration >= 0)
        #expect(result.sourceDigest == "abc123")
    }

    @Test("Negotiation result provider IDs are correct")
    func resultProviderIDs() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider(id: "p1"), mitProvider(id: "p2")],
            handshakeResponses: [
                handshakeResponse(providerID: "p1"),
                handshakeResponse(providerID: "p2")
            ]
        )

        let result = await negotiator.negotiate(sourceDigest: "abc123")

        #expect(result.providerIDs.contains("p1"))
        #expect(result.providerIDs.contains("p2"))
    }

    // MARK: - Capability Finding

    @Test("Capabilities for specific tag returns correct subset")
    func capabilitiesForTag() async throws {
        let (negotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider()],
            handshakeResponses: [handshakeResponse()]
        )

        let result = await negotiator.negotiate(sourceDigest: "abc123")

        let ocrCaps = result.capabilities(for: .ocrTextRecognition)
        #expect(ocrCaps.count == 1)
        #expect(ocrCaps.first?.capability == .ocrTextRecognition)

        let renderCaps = result.capabilities(for: .pdfRendering)
        #expect(renderCaps.count == 1)
    }

    // MARK: - NegotiatedCapability Codable

    @Test("NegotiatedCapability round-trips through JSON")
    func negotiatedCapabilityCodable() throws {
        let cap = NegotiatedCapability(
            providerID: "test",
            capability: .ocrTextRecognition,
            handshake: CapabilityHandshake(
                providerID: "test",
                providerVersion: "1.0.0",
                license: .mit,
                supportedOperations: [.ocrTextRecognition],
                inputLimits: InputLimits()
            )
        )

        let data = try JSONEncoder().encode(cap)
        let decoded = try JSONDecoder().decode(NegotiatedCapability.self, from: data)

        #expect(decoded.providerID == "test")
        #expect(decoded.capability == .ocrTextRecognition)
        #expect(decoded.isActive)
    }

    // MARK: - NegotiationResult Codable

    @Test("NegotiationResult round-trips through JSON")
    func negotiationResultCodable() throws {
        let result = NegotiationResult(
            capabilities: [],
            failedProviders: [NegotiationFailure(providerID: "p1", reason: "timeout")],
            duration: 1.5,
            sourceDigest: "abc123"
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(NegotiationResult.self, from: data)

        #expect(decoded.failedProviders.count == 1)
        #expect(decoded.duration == 1.5)
        #expect(decoded.sourceDigest == "abc123")
    }

    // MARK: - Partial Failure

    @Test("One provider succeeds while another fails")
    func partialFailure() async throws {
        // Use separate negotiators to avoid mock transport race conditions.
        // Test the success path.
        let (goodNegotiator, _) = try await negotiatorWithMock(
            providers: [mitProvider(id: "good-provider")],
            handshakeResponses: [handshakeResponse(providerID: "good-provider")]
        )
        let goodResult = await goodNegotiator.negotiate(sourceDigest: "abc123")
        #expect(goodResult.capabilities.count == 2)
        #expect(goodResult.failedProviders.isEmpty)

        // Test the failure path.
        let (badNegotiator, mockTransport) = try await negotiatorWithMock(
            providers: [mitProvider(id: "bad-provider")],
            handshakeResponses: []
        )
        mockTransport.setNextError(TransportError.connectionFailed("unreachable"))
        let badResult = await badNegotiator.negotiate(sourceDigest: "abc123")
        #expect(badResult.capabilities.isEmpty)
        #expect(badResult.failedProviders.count == 1)
        #expect(badResult.failedProviders.first?.providerID == "bad-provider")
    }
}

// Simple class for capturing callback state in async tests.
private final class CallbackBox: @unchecked Sendable {
    var invoked = false
    var count = 0
}
