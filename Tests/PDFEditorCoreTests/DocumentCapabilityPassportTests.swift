import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Document capability passport")
struct DocumentCapabilityPassportTests {
  private let source = DocumentInspection(
    source: DocumentSource(
      fileName: "passport.pdf",
      byteCount: 10,
      sha256: String(repeating: "c", count: 64)
    ),
    pages: [],
    fields: [],
    candidates: [],
    warnings: [],
    permissions: PDFPermissionsSummary(
      canPrint: true,
      canCopy: true,
      canModify: true,
      canAddAnnotations: true,
      isReadOnly: false
    )
  )

  @Test("A clean unrestricted document exposes useful capabilities")
  func unrestrictedDocument() {
    let passport = DocumentCapabilityPassport.make(
      inspection: source,
      canExport: true,
      hasPreflightReport: true
    )

    #expect(passport.sourceFileName == "passport.pdf")
    #expect(passport.entries.first(where: { $0.id == "read-and-extract" })?.state == .available)
    #expect(passport.entries.first(where: { $0.id == "export-copy" })?.state == .available)
    #expect(passport.entries.first(where: { $0.id == "preflight" })?.state == .available)
    #expect(passport.sourceWarningCount == 0)
  }

  @Test("A document without fields marks completion as not applicable")
  func noFieldsAreNotApplicable() {
    let passport = DocumentCapabilityPassport.make(
      inspection: source,
      canExport: true,
      hasPreflightReport: false
    )

    #expect(passport.entries.first(where: { $0.id == "fill-fields" })?.state == .notApplicable)
    #expect(passport.entries.first(where: { $0.id == "preflight" })?.state == .pending)
  }

  @Test("Restricted permissions are blocked and warnings need review")
  func restrictionsAndWarnings() {
    let restricted = DocumentInspection(
      source: source.source,
      pages: [],
      fields: [NativeField(
        id: "name",
        name: "Name",
        kind: .text,
        pageIndex: 0,
        bounds: PDFRect(x: 0, y: 0, width: 10, height: 10),
        value: nil,
        choices: []
      )],
      candidates: [],
      warnings: ["Source structure needs review."],
      permissions: PDFPermissionsSummary(
        canPrint: true,
        canCopy: false,
        canModify: false,
        canAddAnnotations: false,
        isReadOnly: true
      )
    )
    let passport = DocumentCapabilityPassport.make(
      inspection: restricted,
      canExport: false,
      hasPreflightReport: false
    )

    #expect(passport.entries.first(where: { $0.id == "read-and-extract" })?.state == .blocked)
    #expect(passport.entries.first(where: { $0.id == "fill-fields" })?.state == .blocked)
    #expect(passport.entries.first(where: { $0.id == "source-warnings" })?.state == .needsReview)
    #expect(passport.entries.first(where: { $0.id == "export-copy" })?.state == .blocked)
  }

  @Test("No document fails closed without a source fingerprint")
  func noDocumentFailsClosed() {
    let passport = DocumentCapabilityPassport.make(
      inspection: nil,
      canExport: true,
      hasPreflightReport: true
    )

    #expect(passport.sourceDigest == nil)
    #expect(passport.entries.count == 1)
    #expect(passport.entries[0].state == .blocked)
  }
}
