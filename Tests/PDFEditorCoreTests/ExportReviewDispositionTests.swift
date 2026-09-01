import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Export review disposition")
struct ExportReviewDispositionTests {
  private let sourceDigest = String(repeating: "a", count: 64)

  private func report(
    status: ValidationStatus,
    outputDigest: String? = String(repeating: "b", count: 64)
  ) -> ValidationReport {
    ValidationReport(
      status: status,
      messages: status == .validatedWithWarnings ? ["Accessibility validation was not run."] : [],
      sourceUnchanged: status != .failed,
      outputReopenable: outputDigest != nil,
      sourceDigest: sourceDigest,
      outputDigest: outputDigest
    )
  }

  @Test("No report exposes no disposition actions")
  func noReportHasNoActions() {
    let options = ExportReviewDispositionOptions.make(report: nil, outputIsPresent: false)

    #expect(!options.canRework)
    #expect(!options.canAcceptAsVariance)
    #expect(!options.canDiscard)
  }

  @Test("Validated warnings with an output permit every explicit disposition")
  func warningReportWithOutputOffersAllActions() {
    let options = ExportReviewDispositionOptions.make(
      report: report(status: .validatedWithWarnings),
      outputIsPresent: true
    )

    #expect(options.canRework)
    #expect(options.canAcceptAsVariance)
    #expect(options.canDiscard)
  }

  @Test("A warning without an output cannot be accepted or discarded")
  func warningReportWithoutOutputCannotProceed() {
    let options = ExportReviewDispositionOptions.make(
      report: report(status: .validatedWithWarnings),
      outputIsPresent: false
    )

    #expect(options.canRework)
    #expect(!options.canAcceptAsVariance)
    #expect(!options.canDiscard)
  }

  @Test("Failed validation permits rework but never variance acceptance")
  func failedReportRequiresRework() {
    let options = ExportReviewDispositionOptions.make(
      report: report(status: .failed),
      outputIsPresent: true
    )

    #expect(options.canRework)
    #expect(!options.canAcceptAsVariance)
    #expect(options.canDiscard)
  }
}
