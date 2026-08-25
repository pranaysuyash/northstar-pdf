import Foundation
import Testing

@testable import PDFEditorCore

struct TemplateIndexTests {
    private let provider = PDFProviderDescriptor(id: "template-index-test", version: "1", platform: "test")

    private func revision(
        templateID: UUID,
        revisionID: UUID,
        layout: String,
        digest: String,
        lifecycle: PDFTemplateLifecycle = .active
    ) -> PDFTemplateContract {
        let page = PDFTemplatePageSignature(
            pageIndex: 0,
            widthPoints: 612,
            heightPoints: 792,
            rotationDegrees: 0,
            nativeFieldKinds: [.text],
            nativeFieldNameTokens: ["hmac:name"],
            anchorTokens: ["hmac:name"],
            regionSignatures: [])
        let fingerprint = PDFTemplateFingerprint(
            layoutFingerprint: layout,
            exactSourceDigests: [digest],
            pageSignatures: [page])
        return PDFTemplateContract(
            header: PDFTemplateHeader(templateDigest: layout, provider: provider),
            payload: PDFTemplatePayload(
                templateID: templateID,
                revisionID: revisionID,
                displayName: "Index fixture",
                lifecycle: lifecycle,
                fingerprint: fingerprint,
                mappings: []))
    }

    @Test func indexPrioritizesExactAndKnownVariantEvidenceAndAbstainsOnFamilyTies() throws {
        let sourceDigest = String(repeating: "b", count: 64)
        let exactID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let variantID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let familyID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let exact = revision(templateID: exactID, revisionID: exactID, layout: "layout-a", digest: sourceDigest)
        let variant = revision(templateID: variantID, revisionID: variantID, layout: "layout-a", digest: String(repeating: "c", count: 64))
        let family = revision(templateID: familyID, revisionID: familyID, layout: "layout-family", digest: String(repeating: "d", count: 64))
        let index = try PDFTemplateIndex(histories: [
            PDFTemplateRevisionSet(templateID: exactID, revisions: [exact]),
            PDFTemplateRevisionSet(templateID: variantID, revisions: [variant]),
            PDFTemplateRevisionSet(templateID: familyID, revisions: [family])
        ])

        let exactResult = try PDFTemplateIndexQuery.query(
            index: index,
            fingerprint: exact.payload.fingerprint,
            sourceDigest: sourceDigest)
        #expect(exactResult.state == .exact)
        #expect(exactResult.selectedRevisionID == exact.payload.revisionID)

        let variantResult = try PDFTemplateIndexQuery.query(
            index: index,
            fingerprint: variant.payload.fingerprint,
            sourceDigest: String(repeating: "e", count: 64))
        #expect(variantResult.state == .knownVariant)
        #expect(variantResult.abstained == false)

        let familyResult = try PDFTemplateIndexQuery.query(
            index: try PDFTemplateIndex(histories: [PDFTemplateRevisionSet(templateID: familyID, revisions: [family])]),
            fingerprint: PDFTemplateFingerprint(
                layoutFingerprint: "layout-other",
                pageSignatures: family.payload.fingerprint.pageSignatures),
            sourceDigest: String(repeating: "f", count: 64))
        #expect(familyResult.state == .familyMatch)
        #expect(familyResult.abstained == false)
    }

    @Test func revokedExactRevisionIsStaleAndIndexRejectsDuplicateIdentity() throws {
        let templateID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let digest = String(repeating: "a", count: 64)
        let revoked = revision(templateID: templateID, revisionID: templateID, layout: "layout-revoked", digest: digest, lifecycle: .revoked)
        let index = try PDFTemplateIndex(histories: [PDFTemplateRevisionSet(templateID: templateID, revisions: [revoked])])
        let result = try PDFTemplateIndexQuery.query(index: index, fingerprint: revoked.payload.fingerprint, sourceDigest: digest)
        #expect(result.state == .stale)
        #expect(result.abstained)
        #expect(throws: PDFTemplatePersistenceError.self) {
            try PDFTemplateIndex(entries: [PDFTemplateIndexEntry(revision: revoked), PDFTemplateIndexEntry(revision: revoked)])
        }
    }
}
