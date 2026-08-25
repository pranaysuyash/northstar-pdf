import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Graceful Degradation and Exception Handling Tests")
struct GracefulDegradationExceptionTests {

  private let provider = PDFProviderDescriptor(id: "degradation-test", version: "1", platform: "test")
  private let templateID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

  private func mapping(
    id: UUID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
    key: String = "person.fullName",
    status: PDFTemplateMappingStatus = .confirmed
  ) -> PDFTemplateMapping {
    PDFTemplateMapping(
      id: id,
      semanticKey: key,
      target: PDFTemplateMappingTarget(
        kind: .nativeField,
        pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 10, width: 100, height: 20))),
      suggestedFieldType: .text,
      status: status)
  }

  private func template(revisionID: UUID, mappings: [PDFTemplateMapping]) -> PDFTemplateContract {
    let fingerprint = PDFTemplateFingerprint(
      layoutFingerprint: "layout-degradation",
      exactSourceDigests: [String(repeating: "a", count: 64)],
      pageSignatures: [PDFTemplatePageSignature(pageIndex: 0, widthPoints: 612, heightPoints: 792, rotationDegrees: 0, nativeFieldKinds: [.text], nativeFieldNameTokens: [], anchorTokens: [], regionSignatures: [])])
    return PDFTemplateContract(
      header: PDFTemplateHeader(templateDigest: "template-degradation", provider: provider),
      payload: PDFTemplatePayload(
        templateID: templateID,
        revisionID: revisionID,
        displayName: "Degradation fixture",
        lifecycle: .active,
        fingerprint: fingerprint,
        mappings: mappings))
  }

  private func profile(id: UUID, name: String, value: PDFProfileValue) -> PDFProfileContract {
    let payload = PDFProfilePayload(
      profileID: id,
      revisionID: id,
      displayName: name,
      values: [PDFProfileValueRecord(semanticKey: "person.fullName", value: value)])
    return PDFProfileContract(
      header: PDFProfileHeader(profileID: id, revisionID: id, provider: provider),
      payload: payload)
  }

  // MARK: - 1. Capability Fallback & Negotiation Degradation (PER-0925)

  @Test func capabilityNegotiationGracefullyDegradesWhenPreferredProviderIsRevoked() throws {
    let capabilityID = "text.runReplacement"
    let manifest = ProviderCapabilityManifest(
      providerID: "com.pdfeditor.experimental",
      name: "Experimental Provider",
      version: "1.0.0",
      installState: .enabled,
      license: ProviderLicenseRecord(name: "MIT", status: .approved),
      capabilities: [
        ProviderCapabilityRecord(
          capabilityID: capabilityID,
          lane: .textRunReplacement,
          state: .revoked, // Revoked capability
          limits: ProviderCapabilityLimits(
            maxBytes: 10_000_000,
            maxPages: 100,
            supportsEncrypted: false,
            supportsScanned: false
          ),
          measurementIDs: []
        )
      ],
      measurements: [],
      revocations: [
        ProviderRevocationRecord(
          revocationID: "REV-001",
          capabilityID: capabilityID,
          reason: "Security audit failed",
          revokedAt: Date()
        )
      ]
    )

    let registry = ProviderCapabilityRegistry(providers: [manifest])
    let request = ProviderCapabilityRequest(
      capability: capabilityID,
      source: ProviderSourceFacts(byteCount: 5000, pageCount: 1, isEncrypted: false, isScanned: false),
      policy: ProviderCapabilityPolicy(
        preferredProviderIDs: ["com.pdfeditor.experimental"],
        minimumState: .enabled,
        allowExperimental: false
      )
    )

    let decision = try ProviderCapabilityNegotiator.negotiate(registry: registry, request: request)
    #expect(decision.decision == .abstained)
    #expect(decision.selectedProviderID == nil)
    #expect(decision.rejectionReasons.contains { $0.contains("providerRevoked") || $0.contains("capabilityState:revoked") })
  }

  // MARK: - 2. Template Resolution Ambiguity & Tie Abstention (PER-0925 / PER-0929)

  @Test func templateProfileResolverAbstainsOnAmbiguousTies() {
    let profile1ID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let profile2ID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

    let profile1 = profile(id: profile1ID, name: "Alice Smith", value: .text("Alice Smith"))
    let profile2 = profile(id: profile2ID, name: "Alice Smyth", value: .text("Alice Smyth"))

    let result = PDFTemplateProfileResolver.resolve(
      template: template(revisionID: templateID, mappings: [mapping()]),
      profiles: [profile1, profile2],
      ambiguityMargin: 0.05
    )
    #expect(result.abstained == true)
    #expect(result.state == .ambiguous)
    #expect(result.selectedProfileID == nil)
    #expect(result.reasons.contains { $0.contains("too close") })
  }

  // MARK: - 3. Document Diff Fallback States (PER-0925)

  @Test func documentDiffDegradesToIncompleteWhenPageCountsMismatch() {
    let sourceSource = DocumentSource(fileName: "source.pdf", byteCount: 1000, sha256: "source-sha")
    let outputSource = DocumentSource(fileName: "output.pdf", byteCount: 2000, sha256: "output-sha")

    let page1 = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 100,
      annotationCount: 0,
      hasSelectableText: true
    )
    let page2 = PageSnapshot(
      pageIndex: 1,
      pageLabel: "2",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 100,
      annotationCount: 0,
      hasSelectableText: true
    )

    let sourceInspection = DocumentInspection(
      source: sourceSource,
      pages: [page1],
      fields: [],
      candidates: [],
      warnings: [],
      links: [],
      outlines: [],
      metadata: PDFDocumentMetadata(title: "", author: "", subject: "", creator: "", producer: "", creationDate: "", modificationDate: "", keywords: ""),
      permissions: PDFPermissionsSummary(canPrint: true, canCopy: true, canModify: true, canAddAnnotations: true, isReadOnly: false),
      attachments: []
    )

    let outputInspection = DocumentInspection(
      source: outputSource,
      pages: [page1, page2], // 2 pages vs 1
      fields: [],
      candidates: [],
      warnings: [],
      links: [],
      outlines: [],
      metadata: PDFDocumentMetadata(title: "", author: "", subject: "", creator: "", producer: "", creationDate: "", modificationDate: "", keywords: ""),
      permissions: PDFPermissionsSummary(canPrint: true, canCopy: true, canModify: true, canAddAnnotations: true, isReadOnly: false),
      attachments: []
    )

    let diff = DocumentDiffBuilder.build(source: sourceInspection, output: outputInspection, operations: [])
    #expect(diff.summary.overallStatus == .incomplete)
    #expect(diff.pages.isEmpty)
  }

  // MARK: - 4. OCR Observation Page Space Mapping

  @Test func ocrObservationToPageSpaceMapsCorrectly() {
    let observation = OCRObservation(
      text: "Tax ID Number",
      normalizedBounds: PDFRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
      confidence: 0.95
    )

    let pageBounds = PDFRect(x: 0, y: 0, width: 600, height: 800)
    let evidence = observation.toPageSpace(pageBounds: pageBounds, pageIndex: 0)

    #expect(evidence.pageIndex == 0)
    #expect(evidence.text == "Tax ID Number")
    #expect(evidence.bounds.x == 60.0) // 0.1 * 600
    #expect(evidence.bounds.y == 160.0) // 0.2 * 800
    #expect(evidence.bounds.width == 180.0) // 0.3 * 600
    #expect(evidence.bounds.height == 40.0) // 0.05 * 800
  }
}
