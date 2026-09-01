import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Tests that captureDraft passes V2 layout through to the fingerprint,
/// verifying the production capture flow carries the cell channel.
@Suite("captureDraft V2 wiring")
struct CaptureDraftV2Tests {

    // MARK: - Helpers

    private let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func makeInspection(fixture: String = "public-sample-form") throws -> (DocumentInspection, URL) {
        let provider = PDFKitProvider()
        let url = projectRoot.appendingPathComponent("benchmark/results/\(fixture).pdf")
        let inspection = try provider.inspect(url: url)
        return (inspection, url)
    }

    private func makeV2(url: URL) -> LayoutFingerprintV2? {
        guard let doc = PDFDocument(url: url) else { return nil }
        return LayoutFingerprintV2Extractor.extract(from: doc)
    }

    // MARK: - Tests

    @Test("captureDraft without layoutV2 produces layout-features-1 fingerprint")
    func captureDraftWithoutV2() throws {
        let (inspection, _) = try makeInspection()
        let key = Data("test-workspace".utf8)

        let contract = try PDFTemplateCapture.captureDraft(
            from: inspection,
            workspaceKey: key,
            displayName: "No V2 test"
        )

        // Without V2, featureVersion should be layout-features-1
        #expect(contract.payload.fingerprint.featureVersion == "layout-features-1")
        // Page signatures should have no cell tokens
        for sig in contract.payload.fingerprint.pageSignatures {
            #expect(sig.textCellTokens.isEmpty)
            #expect(sig.fieldCellTokens.isEmpty)
            #expect(sig.annotationCellTokens.isEmpty)
        }
    }

    @Test("captureDraft with layoutV2 produces layout-features-2 fingerprint with cell tokens")
    func captureDraftWithV2() throws {
        let (inspection, url) = try makeInspection()
        let key = Data("test-workspace".utf8)
        let v2 = try #require(makeV2(url: url))

        let contract = try PDFTemplateCapture.captureDraft(
            from: inspection,
            workspaceKey: key,
            displayName: "V2 test",
            layoutV2: v2
        )

        // With V2, featureVersion should be layout-features-2
        #expect(contract.payload.fingerprint.featureVersion == "layout-features-2")
        // At least one page should have cell tokens
        let hasCells = contract.payload.fingerprint.pageSignatures.contains {
            !$0.textCellTokens.isEmpty || !$0.fieldCellTokens.isEmpty
        }
        #expect(hasCells, "V2 capture should populate cell tokens in page signatures")
        // Cell tokens should be HMAC-keyed (hmac: prefix)
        for sig in contract.payload.fingerprint.pageSignatures {
            for token in sig.fieldCellTokens {
                #expect(token.hasPrefix("hmac:"), "Field cell tokens must be HMAC-keyed")
            }
            for token in sig.textCellTokens {
                #expect(token.hasPrefix("hmac:"), "Text cell tokens must be HMAC-keyed")
            }
        }
    }

    @Test("captureDraft with V2 produces different fingerprint than without V2")
    func v2ChangesFingerprint() throws {
        let (inspection, url) = try makeInspection()
        let key = Data("test-workspace".utf8)
        let v2 = try #require(makeV2(url: url))

        let withoutV2 = try PDFTemplateCapture.captureDraft(
            from: inspection, workspaceKey: key, displayName: "No V2"
        )
        let withV2 = try PDFTemplateCapture.captureDraft(
            from: inspection, workspaceKey: key, displayName: "V2",
            layoutV2: v2
        )

        // The fingerprints must differ because V2 changes the canonical descriptor
        #expect(
            withoutV2.payload.fingerprint.layoutFingerprint != withV2.payload.fingerprint.layoutFingerprint,
            "V2 cells should change the fingerprint digest"
        )
    }

    @Test("captureDraft V2 layout fingerprint is deterministic")
    func v2Deterministic() throws {
        let (inspection, url) = try makeInspection()
        let key = Data("test-workspace".utf8)
        let v2 = try #require(makeV2(url: url))

        let c1 = try PDFTemplateCapture.captureDraft(
            from: inspection, workspaceKey: key, displayName: "Det", layoutV2: v2
        )
        let c2 = try PDFTemplateCapture.captureDraft(
            from: inspection, workspaceKey: key, displayName: "Det", layoutV2: v2
        )

        #expect(c1.payload.fingerprint.layoutFingerprint == c2.payload.fingerprint.layoutFingerprint)
        #expect(c1.payload.fingerprint.pageSignatures.count == c2.payload.fingerprint.pageSignatures.count)
    }
}
