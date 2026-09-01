import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Export review receipt")
struct ExportReviewReceiptTests {
  private let source = DocumentInspection(
    source: DocumentSource(
      fileName: "review.pdf",
      byteCount: 42,
      sha256: String(repeating: "a", count: 64)
    ),
    pages: [],
    fields: [],
    candidates: [],
    warnings: []
  )

  @Test("A clean export is ready but validation remains pending")
  func cleanExportIsPendingValidation() {
    let receipt = ExportReviewReceipt.make(
      source: source,
      operations: [],
      canExport: true
    )

    #expect(receipt.state == .ready)
    #expect(receipt.canProceed)
    #expect(!receipt.requiresExplicitReview)
    #expect(receipt.checks.first(where: { $0.id == "validation" })?.state == .pending)
    #expect(receipt.checks.first(where: { $0.id == "source-preservation" })?.state == .pending)
  }

  @Test("Warnings and destructive operations require an explicit review")
  func warningsAndDestructiveOperationsNeedReview() {
    let warningSource = DocumentInspection(
      source: source.source,
      pages: [],
      fields: [],
      candidates: [],
      warnings: ["Accessibility validation was not run."]
    )
    let operation = EditOperation(
      id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
      pageIndex: 0,
      kind: .flatten,
      value: "payload must not appear in receipt",
      destructive: true
    )

    let receipt = ExportReviewReceipt.make(
      source: warningSource,
      operations: [operation],
      canExport: true
    )

    #expect(receipt.state == .needsReview)
    #expect(receipt.canProceed)
    #expect(receipt.requiresExplicitReview)
    #expect(receipt.sourceWarningCount == 1)
    #expect(receipt.operationSummaries == [
      ExportReviewOperationSummary(
        kind: .flatten,
        title: "Flattening",
        count: 1,
        containsDestructiveOperation: true
      )
    ])
    let encoded = String(data: try! JSONEncoder().encode(receipt), encoding: .utf8)!
    #expect(!encoded.contains("payload must not appear in receipt"))
  }

  @Test("Denied export is blocked even when the source exists")
  func deniedExportIsBlocked() {
    let receipt = ExportReviewReceipt.make(
      source: source,
      operations: [],
      canExport: false
    )

    #expect(receipt.state == .blocked)
    #expect(!receipt.canProceed)
    #expect(receipt.checks.first(where: { $0.id == "permissions" })?.state == .blocked)
  }

  @Test("Validated output changes pending checks into verified evidence")
  func validatedOutputIsDistinct() {
    let report = ValidationReport(
      status: .validated,
      messages: [],
      sourceUnchanged: true,
      outputReopenable: true,
      sourceDigest: source.source.sha256,
      outputDigest: String(repeating: "b", count: 64)
    )
    let receipt = ExportReviewReceipt.make(
      source: source,
      operations: [],
      canExport: true,
      outputValidation: report
    )

    #expect(receipt.state == .validated)
    #expect(receipt.canProceed)
    #expect(receipt.checks.first(where: { $0.id == "validation" })?.state == .confirmed)
    #expect(receipt.checks.first(where: { $0.id == "source-preservation" })?.state == .confirmed)
  }

  @Test("Duplicate operation IDs block ledger trust")
  func duplicateOperationIDsAreBlocked() {
    let id = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    let first = EditOperation(id: id, pageIndex: 0, kind: .annotation, value: "one")
    let second = EditOperation(id: id, pageIndex: 0, kind: .annotation, value: "two")
    let receipt = ExportReviewReceipt.make(
      source: source,
      operations: [first, second],
      canExport: true
    )

    #expect(receipt.state == .blocked)
    #expect(!receipt.canProceed)
    #expect(receipt.checks.first(where: { $0.id == "operation-ledger" })?.state == .blocked)
  }

  @Test("Receipt preserves the selected copy profile")
  func profileIsExplicit() {
    let receipt = ExportReviewReceipt.make(
      source: source,
      operations: [],
      canExport: true,
      profile: .sanitizedCopy
    )

    #expect(receipt.profile == .sanitizedCopy)
    #expect(receipt.profile.title == "Sanitized Copy")
    #expect(receipt.profile.detail.contains("metadata"))
  }
}
