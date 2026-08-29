import Foundation
import Testing
@testable import PDFEditorCore

/// The automated detector gate for the native candidate pipeline.
///
/// The gate runs the live `PDFProvider` pipeline (candidates + fields
/// channel) over the real corpus fixtures against the reviewed ground truth,
/// and fails on any regression. These tests prove four properties:
///
/// 1. The live corpus passes the gate (current pipeline state, verified).
/// 2. A detector regression fails the gate, attributed to the fixture.
/// 3. Unreviewed fixtures fail closed — new corpus entries must be reviewed
///    before they can pass.
/// 4. The report is content-free (privacy §12) and round-trips.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — metrics derive only from human-reviewed ground truth
/// - §5 Evidence-based — the gate measures real fixtures, not synthetic lanes
/// - §10 Failure — regression is detected and attributed per fixture

// MARK: - Corpus Paths

private enum GateCorpusPath {
  static let sweep = "/Users/pranay/Projects/pdf_editor/benchmark/results/corpus-sweep-2026-08-25"

  static func sweepPDF(_ name: String) -> URL {
    URL(fileURLWithPath: "\(sweep)/\(name)")
  }
}

/// The 15 corpus-sweep fixtures (manifest: docs/fixtures/corpus-sweep-detector-manifest.md).
private let sweepFixtureNames = [
  "plain-text.pdf", "multi-column.pdf", "navigation.pdf", "geometry.pdf",
  "metadata-complete.pdf", "metadata-absent.pdf", "metadata-custom.pdf",
  "metadata-malformed.pdf", "metadata-unicode.pdf",
  "signed-valid-structure.pdf", "signed-invalid-structure.pdf", "signed-multiple.pdf",
  "xfa-static.pdf", "xfa-hybrid.pdf", "xfa-dynamic.pdf"
]

// MARK: - Gate Tests

@Suite("Native Detector Gate")
struct NativeDetectorGateTests {

  private let gate = NativeDetectorGate()
  private let provider = PDFKitProvider()

  @Test("Live corpus sweep passes the automated gate")
  func liveCorpusGatePasses() throws {
    let fixtures = sweepFixtureNames.map(GateCorpusPath.sweepPDF)
    let result = try gate.run(provider: provider, fixtures: fixtures)

    #expect(result.fixtureCount == 15)
    #expect(result.groundTruthCount == 108)
    #expect(result.reviewedCaseCount == 98, "All 98 corpus-sweep reviewed cases must be measured")
    #expect(result.unreviewedFixtureCount == 0)
    #expect(result.failedFixtureCount == 0)
    #expect(result.passed)

    for fixture in result.fixtures {
      #expect(fixture.passed, "\(fixture.fixtureID) must pass: \(fixture.error ?? "metrics \(String(describing: fixture.lane?.metrics))")")
      #expect(fixture.sourceDigest != nil && fixture.sourceDigest?.count == 64, "\(fixture.fixtureID) must bind a source digest")
      guard let lane = fixture.lane else {
        Issue.record("\(fixture.fixtureID) unexpectedly has no lane result")
        continue
      }
      #expect(lane.metrics.precision == 1.0, "\(fixture.fixtureID) precision")
      #expect(lane.metrics.recall == 1.0, "\(fixture.fixtureID) recall")
      #expect((lane.metrics.abstention ?? 1.0) == 1.0, "\(fixture.fixtureID) abstention")
      #expect(lane.metrics.labelAssociationPrecision == 1.0, "\(fixture.fixtureID) label association")
      #expect(lane.metrics.evidenceFamilyAgreement == 1.0, "\(fixture.fixtureID) evidence family agreement")
      #expect(lane.metrics.severityBurden == 0, "\(fixture.fixtureID) severity burden")
    }
  }

  @Test("A dropped field detection fails the gate, attributed to its fixture")
  func gateFailsOnRegression() throws {
    let fixtures = sweepFixtureNames.map(GateCorpusPath.sweepPDF)
    let result = try gate.run(provider: provider, fixtures: fixtures) { inspection in
      var live = NativeDetectorGate.liveCandidates(inspection)
      // Regression: the "name" field (first nativeField, page 0) of the
      // plain-text fixture is no longer surfaced by the fields channel.
      if inspection.source.fileName == "plain-text.pdf",
         let index = live.firstIndex(where: { $0.kind == "nativeField" && $0.pageIndex == 0 }) {
        live.remove(at: index)
      }
      return live
    }

    #expect(!result.passed)
    #expect(result.failedFixtureCount == 1, "Regression must be contained to one fixture")
    let plainText = result.fixtures.first { $0.fixtureID == "plain-text.pdf" }
    #expect(plainText?.passed == false)
    #expect(plainText?.lane?.metrics.recall == 5.0 / 6.0, "Dropping 1 of 6 fields must drop recall")
    let otherFixturesGreen = result.fixtures
      .filter { $0.fixtureID != "plain-text.pdf" }
      .allSatisfy(\.passed)
    #expect(otherFixturesGreen, "Other fixtures must remain green (per-fixture scoping)")
  }

  @Test("Unreviewed fixtures fail closed — the gate cannot be silently widened")
  func gateFailsClosedOnUnreviewedFixture() throws {
    // The base form has no reviewed ground truth (no fixtureID entries):
    // a new corpus entry cannot silently pass the gate.
    let fixtures = [URL(fileURLWithPath: "/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf")]
    let result = try gate.run(provider: provider, fixtures: fixtures)

    #expect(!result.passed)
    #expect(result.unreviewedFixtureCount == 1)
    #expect(result.fixtures.first?.unreviewed == true)
    #expect(result.fixtures.first?.passed == false)
    #expect(result.summary.contains("UNREVIEWED"))
  }

  @Test("Inspection failure fails the gate and is recorded in the report")
  func gateFailsOnPipelineFailure() throws {
    let missing = URL(fileURLWithPath: "/dev/null/does-not-exist.pdf")
    let result = try gate.run(provider: provider, fixtures: [missing])

    #expect(!result.passed)
    #expect(result.fixtures.first?.error != nil)
    #expect(result.fixtures.first?.passed == false)
  }
}

// MARK: - Fields Channel Mapping

@Suite("Fields Channel Mapping")
struct FieldsChannelMappingTests {

  @Test("Native field maps to the cross-lane candidate contract (mirrors mjs fieldCandidates)")
  func fieldMapping() {
    let field = NativeField(
      id: "f-name",
      name: "Applicant Name",
      kind: .text,
      pageIndex: 0,
      bounds: PDFRect(x: 185.5, y: 705.39, width: 251, height: 23),
      value: "Ada",
      choices: []
    )
    let candidate = DetectorCandidate.native(from: field)
    #expect(candidate.kind == "nativeField")
    #expect(candidate.suggestedFieldType == "text")
    #expect(candidate.entryMode == "native")
    #expect(candidate.groupMemberCount == 1)
    #expect(candidate.evidenceFamilies == ["nativeField"])
    #expect(candidate.labelAssociated, "Field name is the label association")
  }

  @Test("liveCandidates combines detector candidates and the fields channel")
  func liveCandidatesCombinesChannels() throws {
    let inspection = DocumentInspection(
      source: DocumentSource(fileName: "sample.pdf", byteCount: 100, sha256: String(repeating: "a", count: 64)),
      pages: [],
      fields: [
        NativeField(id: "f1", name: "Name", kind: .text, pageIndex: 0,
                    bounds: PDFRect(x: 10, y: 10, width: 100, height: 20), value: nil, choices: [])
      ],
      candidates: [
        RegionCandidate(
          pageIndex: 1,
          bounds: PDFRect(x: 200, y: 200, width: 50, height: 50),
          kind: .vectorRegion,
          score: 0.8,
          evidence: ["vectorRectangle"],
          evidenceItems: [CandidateEvidence(kind: .vectorRectangle, origin: .geometryExtraction, summary: "box")]
        )
      ],
      warnings: []
    )
    let live = NativeDetectorGate.liveCandidates(inspection)
    #expect(live.count == 2)
    #expect(live.contains { $0.kind == "nativeField" && $0.suggestedFieldType == "text" })
    #expect(live.contains { $0.kind == "vectorRegion" && $0.pageIndex == 1 })
  }

  @Test("Gate report round-trips and is content-free (privacy §12)")
  func reportRoundTripAndPrivacy() throws {
    let fixtures = ["plain-text.pdf", "geometry.pdf"].map(GateCorpusPath.sweepPDF)
    let result = try NativeDetectorGate().run(provider: PDFKitProvider(), fixtures: fixtures)
    #expect(result.passed)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(result),
          let json = String(data: data, encoding: .utf8) else {
      Issue.record("Gate result must serialize")
      return
    }
    let decoder = JSONDecoder()
    guard let roundTripped = try? decoder.decode(NativeDetectorGateResult.self, from: data) else {
      Issue.record("Gate result must round-trip")
      return
    }
    #expect(roundTripped.fixtureCount == result.fixtureCount)
    #expect(roundTripped.passed == result.passed)
    #expect(roundTripped.fixtures.map(\.fixtureID) == result.fixtures.map(\.fixtureID))
    // Privacy: no document text, field values, or candidate prose in the report.
    #expect(!json.contains("labelText"))
    #expect(!json.contains("\"value\""))
  }
}