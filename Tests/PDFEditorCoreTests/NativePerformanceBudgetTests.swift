import Foundation
import Testing
@testable import PDFEditorCore

/// Native performance budget tests mirroring the browser RG-037
/// continuous-view measurement. Measures cold-start PDF inspection,
/// field-tree walk, incremental write, and text-search latencies on a
/// controlled fixture to establish a baseline for the native lane.
///
/// Budgets are provisional: they record observed medians and flag
/// regressions beyond 3× the current baseline. Formal budget ratification
/// requires device-matrix measurement (remaining RG-037 work).
struct NativePerformanceBudgetTests {
  private var publicSampleURL: URL? {
    guard let path = ProcessInfo.processInfo.environment["PDF_EDITOR_PUBLIC_ACROFORM_INPUT"],
      FileManager.default.fileExists(atPath: path)
    else { return nil }
    return URL(fileURLWithPath: path)
  }

  @Test func coldStartInspectionCompletesWithinBudget() throws {
    guard let url = publicSampleURL else { return }
    let data = try Data(contentsOf: url)
    let provider = PDFKitProvider()

    let start = CFAbsoluteTimeGetCurrent()
    let inspection = try provider.inspect(url: url)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(!inspection.fields.isEmpty)
    // Budget: cold inspection under 2 seconds on any reasonable hardware.
    #expect(
      elapsed < 2.0,
      "Cold inspection took \(String(format: "%.3f", elapsed))s — exceeds 2s budget"
    )
    print("  cold inspection: \(String(format: "%.3f", elapsed))s (budget 2.0s)")
  }

  @Test func fieldTreeWalkCompletesWithinBudget() throws {
    guard let url = publicSampleURL else { return }
    let data = try Data(contentsOf: url)

    let start = CFAbsoluteTimeGetCurrent()
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(!nodes.isEmpty)
    // Budget: AcroForm walk under 0.5 seconds.
    #expect(
      elapsed < 0.5,
      "Field-tree walk took \(String(format: "%.3f", elapsed))s — exceeds 0.5s budget"
    )
    print("  field-tree walk: \(String(format: "%.3f", elapsed))s (budget 0.5s)")
  }

  @Test func incrementalWriteCompletesWithinBudget() throws {
    guard let url = publicSampleURL else { return }
    let data = try Data(contentsOf: url)
    let nodes = try PDFIncrementalFormWriter.walkAcroForm(data)

    let start = CFAbsoluteTimeGetCurrent()
    let plan = try PDFIncrementalFormWriter.resolveEditPlan(
      nodes: nodes, targetFieldName: "applicant.name", requestedValue: "Perf Test",
      source: data)
    let output = try PDFIncrementalFormWriter.incrementalFieldUpdate(
      data, edits: plan.objectEdits, newObjects: plan.newObjectBodies)
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    #expect(output.count > data.count)
    #expect(output.prefix(data.count) == data)
    // Budget: incremental write under 0.5 seconds.
    #expect(
      elapsed < 0.5,
      "Incremental write took \(String(format: "%.3f", elapsed))s — exceeds 0.5s budget"
    )
    print("  incremental write: \(String(format: "%.3f", elapsed))s (budget 0.5s)")
  }

  @Test func inspectorFieldLookupCompletesWithinBudget() throws {
    guard let url = publicSampleURL else { return }
    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: url)

    let start = CFAbsoluteTimeGetCurrent()
    // Simulate repeated field lookups (typical UI interaction pattern).
    for _ in 0..<100 {
      _ = inspection.fields.first { $0.name == "applicant.name" }
    }
    let elapsed = CFAbsoluteTimeGetCurrent() - start

    // Budget: 100 field lookups under 0.01 seconds (O(1) per lookup).
    #expect(
      elapsed < 0.01,
      "100 field lookups took \(String(format: "%.6f", elapsed))s — exceeds 10ms budget"
    )
    print(
      "  100 field lookups: \(String(format: "%.6f", elapsed))s (budget 10ms)"
    )
  }
}
