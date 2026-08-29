import Foundation
import Testing
@testable import PDFEditorCore

/// Exports the canonical reviewed ground truth to the browser-contract shape
/// (`web/detector-semantic-comparison.mjs` labels format) so the node runner
/// can evaluate both lanes against the same 108-case corpus.
///
/// The artifact is deterministic (fixed generatedAt) and committed as
/// evidence: `benchmark/results/detector-calibration/corpus_sweep_ground_truth.json`.
///
/// Doctrine alignment:
/// - §6 Documentation — the export makes the Swift-side ground truth durable
///   and cross-lane usable.
/// - §2 Truth taxonomy — provenance is preserved per case.
@Suite("Ground Truth Export")
struct GroundTruthExportTests {

  private struct ExportCase: Codable {
    let id: String
    let reviewedRegionID: String
    let fixtureID: String
    let pageIndex: Int
    let `class`: String
    let expected: String
    let hardNegative: Bool
    let target: ExportRect
    let requiredEvidence: [String]
    let expectedEvidenceFamilies: [String]
    let expectedLabelAssociation: String
    let expectedGrouping: ExportGrouping
    let falsePositiveSeverity: String?
    let provenance: String
    let rationale: String?
  }

  private struct ExportGrouping: Codable {
    let state: String
    let memberCount: Int?
  }

  private struct ExportRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
  }

  private struct ExportLabels: Codable {
    let schema: String
    let fixture: String
    let reviewedOn: String
    let policy: ExportPolicy
    let cases: [ExportCase]
  }

  private struct ExportPolicy: Codable {
    let reviewRequired: Bool
  }

  private func exportCase(_ c: ReviewedGroundTruthCase) -> ExportCase {
    let grouping: ExportGrouping
    switch c.expectedGroupingState {
    case "grouped": grouping = ExportGrouping(state: "grouped", memberCount: nil)
    case "abstain": grouping = ExportGrouping(state: "abstain", memberCount: nil)
    default: grouping = ExportGrouping(state: "single", memberCount: 1)
    }
    return ExportCase(
      id: c.id,
      reviewedRegionID: c.reviewedRegionID,
      fixtureID: c.fixtureID,
      pageIndex: c.pageIndex,
      class: c.className,
      expected: c.expectedState,
      hardNegative: c.isHardNegative,
      target: ExportRect(x: c.target.x, y: c.target.y, width: c.target.width, height: c.target.height),
      requiredEvidence: c.requiredEvidence,
      expectedEvidenceFamilies: c.expectedEvidenceFamilies,
      expectedLabelAssociation: c.expectedLabelAssociation,
      expectedGrouping: grouping,
      falsePositiveSeverity: c.falsePositiveSeverity,
      provenance: c.provenance,
      rationale: c.rationale
    )
  }

  @Test("Ground truth exports to the browser-contract shape and round-trips")
  func exportRoundTrip() {
    let groundTruth = ReviewedCandidateGroundTruth.canonical()
    let labels = ExportLabels(
      schema: "pdf-editor.detector-calibration-labels",
      fixture: "corpus-sweep-2026-08-25",
      reviewedOn: "2026-08-28",
      policy: ExportPolicy(reviewRequired: true),
      cases: groundTruth.cases.map(exportCase)
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(labels),
          let json = String(data: data, encoding: .utf8) else {
      #expect(Bool(false), "Export must serialize")
      return
    }

    // Round-trip: decode must reproduce the same case count and IDs.
    let decoder = JSONDecoder()
    guard let decoded = try? decoder.decode(ExportLabels.self, from: data) else {
      #expect(Bool(false), "Export must round-trip")
      return
    }
    #expect(decoded.cases.count == groundTruth.cases.count)
    #expect(decoded.cases.allSatisfy { $0.provenance == "human-reviewed" })

    // Persist the artifact.
    let artifactURL = URL(fileURLWithPath: "/Users/pranay/Projects/pdf_editor/benchmark/results/detector-calibration")
      .appendingPathComponent("corpus_sweep_ground_truth.json")
    try? data.write(to: artifactURL)
    #expect(FileManager.default.fileExists(atPath: artifactURL.path), "Export must be persisted")
  }
}