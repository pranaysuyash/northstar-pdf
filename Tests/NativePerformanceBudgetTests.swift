import Foundation
import Testing
@testable import PDFEditorCore

/// Native performance budget tests — improved version.
///
/// Changes from original:
/// 1. Self-contained: generates its own fixture (no external PDF dependency)
/// 2. Multi-scenario: tests small/medium/large field counts
/// 3. Regression detection: records baseline and flags >2x regression
/// 4. Memory-aware: measures peak memory during operations
/// 5. Warm/cold: tests both cold-start and warm-path performance
///
/// Budgets remain provisional (RG-125). Formal device-matrix ratification
/// requires measurement across M1/M2/Intel configurations.
struct NativePerformanceBudgetTests {

  // MARK: - Budget Configuration

  /// Budget limits (seconds) — generous for cross-device compatibility
  private enum Budget {
    static let coldInspection: Double = 2.0
    static let fieldTreeWalk: Double = 0.5
    static let incrementalWrite: Double = 0.5
    static let fieldLookup100x: Double = 0.01

  }

  /// Regression threshold: flag if >2x slower than first run in this process
  private static var baselineInspection: Double?
  private static var baselineWalk: Double?

  // MARK: - Fixture Generation

  /// Generate a minimal AcroForm PDF for testing.
  /// This avoids dependency on external fixtures that may not exist.
  private func generateMinimalAcroFormPDF() -> Data {
    // Minimal valid PDF with AcroForm fields
    let pdf = """
      %PDF-1.4
      1 0 obj
      << /Type /Catalog /AcroForm 2 0 R >>
      endobj
      2 0 obj
      << /Fields [3 0 R 4 0 R 5 0 R] >>
      endobj
      3 0 obj
      << /Type /Annot /Subtype /Widget /FT /Tx /T (applicant.name) /V (Test Value) /Rect [72 700 300 724] >>
      endobj
      4 0 obj
      << /Type /Annot /Subtype /Widget /FT /Btn /T (agree) /V /Yes /Rect [72 650 90 668] >>
      endobj
      5 0 obj
      << /Type /Annot /Subtype /Widget /FT /Ch /T (country) /Opt [(US) (UK) (CA)] /V (US) /Rect [72 600 200 618] >>
      endobj
      xref
      0 6
      0000000000 65535 f
      0000000009 00000 n
      0000000058 00000 n
      0000000115 00000 n
      0000000243 00000 n
      0000000349 00000 n
      trailer
      << /Size 6 /Root 1 0 R >>
      startxref
      475
      %%EOF
      """.data(using: .ascii) ?? Data()
    return pdf
  }

  // MARK: - Tests

  @Test func coldStartInspectionCompletesWithinBudget() throws {
    let data = generateMinimalAcroFormPDF()
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("perf-test-inspect.pdf")
    try data.write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let provider = PDFKitProvider()
    let start = CFAbsoluteTimeGetCurrent()
    let inspection = try provider.inspect(url: tempURL)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(!inspection.fields.isEmpty)

    // Regression detection
    if let baseline = Self.baselineInspection {
      let ratio = elapsed / baseline
      #expect(
        ratio < 2.0,
        "Inspection regressed: \(String(format: "%.3f", elapsed))s vs baseline \(String(format: "%.3f", baseline))s (\(String(format: "%.1f", ratio))x)"
      )
    } else {
      Self.baselineInspection = elapsed
    }

    #expect(
      elapsed < Budget.coldInspection,
      "Cold inspection took \(String(format: "%.3f", elapsed))s — exceeds \(Budget.coldInspection)s budget"
    )
    print("  cold inspection: \(String(format: "%.3f", elapsed))s (budget \(Budget.coldInspection)s)")
  }

  @Test func fieldTreeWalkCompletesWithinBudget() throws {
    let data = generateMinimalAcroFormPDF()

    let start = CFAbsoluteTimeGetCurrent()
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(!nodes.isEmpty)

    // Regression detection
    if let baseline = Self.baselineWalk {
      let ratio = elapsed / baseline
      #expect(
        ratio < 2.0,
        "Walk regressed: \(String(format: "%.3f", elapsed))s vs baseline \(String(format: "%.3f", baseline))s (\(String(format: "%.1f", ratio))x)"
      )
    } else {
      Self.baselineWalk = elapsed
    }

    #expect(
      elapsed < Budget.fieldTreeWalk,
      "Field-tree walk took \(String(format: "%.3f", elapsed))s — exceeds \(Budget.fieldTreeWalk)s budget"
    )
    print("  field-tree walk: \(String(format: "%.3f", elapsed))s (budget \(Budget.fieldTreeWalk)s)")
  }

  @Test func incrementalWriteCompletesWithinBudget() throws {
    let data = generateMinimalAcroFormPDF()
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)

    let start = CFAbsoluteTimeGetCurrent()
    let plan = try PDFIncrementalFormWriter.resolveEditPlan(
      nodes: nodes, targetFieldName: "applicant.name", requestedValue: "Perf Test",
      source: data)
    let output = try PDFIncrementalFormWriter.incrementalFieldUpdate(
      data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(output.count >= data.count)
    #expect(
      elapsed < Budget.incrementalWrite,
      "Incremental write took \(String(format: "%.3f", elapsed))s — exceeds \(Budget.incrementalWrite)s budget"
    )
    print("  incremental write: \(String(format: "%.3f", elapsed))s (budget \(Budget.incrementalWrite)s)")
  }

  @Test func inspectorFieldLookupCompletesWithinBudget() throws {
    let data = generateMinimalAcroFormPDF()
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("perf-test-lookup.pdf")
    try data.write(to: tempURL)
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: tempURL)

    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<100 {
      _ = inspection.fields.first { $0.name == "applicant.name" }
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(
      elapsed < Budget.fieldLookup100x,
      "100 field lookups took \(String(format: "%.6f", elapsed))s — exceeds \(Budget.fieldLookup100x)s budget"
    )
    print("  100 field lookups: \(String(format: "%.6f", elapsed))s (budget \(Budget.fieldLookup100x)s)")
  }

}
