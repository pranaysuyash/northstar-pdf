import Foundation
import Testing

@testable import PDFEditorCore

struct PreflightContractTests {
  private let digest = String(repeating: "a", count: 64)
  private let provider = PDFProviderDescriptor(
    id: "pdfkit", version: "test", platform: "macOS", capabilities: ["bounded-token-scan"])

  private func inspection() -> DocumentInspection {
    DocumentInspection(
      source: DocumentSource(fileName: "private.pdf", byteCount: 200, sha256: digest),
      pages: [],
      fields: [],
      candidates: [],
      warnings: [],
      links: [
        PDFLink(id: "safe", pageIndex: 0, label: "safe", kind: .externalURL, destination: "https://private.example", isSafeExternal: true),
        PDFLink(id: "unsafe", pageIndex: 0, label: "unsafe", kind: .externalURL, destination: "file:///private", isSafeExternal: false),
        PDFLink(id: "internal", pageIndex: 0, label: "internal", kind: .internalPage, targetPageIndex: 1)
      ],
      metadata: PDFDocumentMetadata(
        title: "Private title", author: "Private author", subject: "Private subject",
        creator: "Private creator", producer: "Private producer", creationDate: "Private date",
        modificationDate: "", keywords: "private keyword"),
      permissions: PDFPermissionsSummary(canPrint: true, canCopy: false, canModify: false, canAddAnnotations: false, isReadOnly: true),
      attachments: ["private-attachment.docx"],
      security: PDFSecuritySummary(isEncrypted: true, isLocked: false, requiresPassword: false),
      annotationTypeCounts: ["widget": 1, "link": 1, "markup": 2]
    )
  }

  @Test func nativePreflightContainsCountsNotSensitiveValues() throws {
    let data = Data("%PDF-1.7 /EmbeddedFiles /FileAttachment /XFA /RichMedia /JavaScript /OpenAction /AA /Launch /SubmitForm /GoToR /URI /Encrypt /Sig /DocTimeStamp".utf8)
    let report = PDFPreflightBuilder.build(
      inspection: inspection(), data: data, provider: provider,
      generatedAt: "2026-08-25T00:00:00.000Z")
    try PDFPreflightValidator.validate(report)

    #expect(report.header.contractName == "pdf-editor.preflight")
    #expect(report.header.sourceDigest == digest)
    #expect(report.payload.metadata.rawValuesIncluded == false)
    #expect(report.payload.summary.metadataFieldCount == 7)
    #expect(report.payload.embeddedData.attachmentCount == 1)
    #expect(report.payload.networkBoundaries.unsafeExternalURLCount == 1)
    #expect(report.payload.activeContent.executionAttempted == false)
    #expect(report.payload.scripts.executionAttempted == false)
    #expect(report.payload.annotations.totalCount == 4)
    #expect(report.payload.annotations.coverage.state == .observed)
    #expect(report.payload.revisions.hiddenContentState == .unknown)
    #expect(report.payload.unknownCoverage.unknownCount == 1)
    #expect(report.payload.sanitization.status == .notRun)
    #expect(report.payload.sanitization.safeToClaimClean == false)

    let encoder = JSONEncoder()
    let serialized = String(decoding: try encoder.encode(report), as: UTF8.self)
    #expect(!serialized.contains("Private title"))
    #expect(!serialized.contains("private-attachment.docx"))
    #expect(!serialized.contains("private.example"))
    #expect(!serialized.contains("%PDF-1.7"))
  }

  @Test func nativePreflightValidatorRejectsAFalseCleanClaim() throws {
    let report = PDFPreflightBuilder.build(
      inspection: inspection(), data: Data("%PDF-1.7".utf8), provider: provider)
    let tampered = PDFPreflightReport(
      header: report.header,
      payload: PDFPreflightPayload(
        summary: report.payload.summary,
        metadata: report.payload.metadata,
        embeddedData: report.payload.embeddedData,
        networkBoundaries: report.payload.networkBoundaries,
        activeContent: report.payload.activeContent,
        security: report.payload.security,
        sanitization: PDFPreflightSanitization(
          status: .notRun, safeToClaimClean: true,
          sourceUnchanged: true, limits: report.payload.sanitization.limits),
        findings: report.payload.findings))
    #expect(throws: PDFPreflightValidationError.cleanClaimNotAllowed) {
      try PDFPreflightValidator.validate(tampered)
    }
  }

  @Test func PDFKitProviderEmitsPreflightForTheCorpusFixture() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let sourceURL = projectRoot.appendingPathComponent("benchmark/results/public-sample-form.pdf")
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      Issue.record("The public corpus fixture is required for the native preflight gate")
      return
    }
    let report = try PDFKitProvider().preflight(url: sourceURL, password: nil)
    try PDFPreflightValidator.validate(report, expectedSourceDigest: report.header.sourceDigest)
    #expect(report.payload.metadata.rawValuesIncluded == false)
    #expect(report.payload.sanitization.status == .notRun)
    #expect(report.payload.sanitization.safeToClaimClean == false)
  }
}
