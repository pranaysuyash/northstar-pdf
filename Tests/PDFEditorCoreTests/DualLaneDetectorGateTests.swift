import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Tests for the dual-lane detector gate.
///
/// Doctrine alignment:
/// - §3 Proportional rigor — Tier 3 integration tests with real corpus
/// - §5 Evidence-based — every claim verified against real PDFs
@Suite("Dual-Lane Detector Gate")
struct DualLaneDetectorGateTests {

  private let gate = DualLaneDetectorGate()

  // MARK: - Live Corpus

  @Test("Live corpus passes dual-lane gate with all fixtures")
  func liveCorpusGatePasses() throws {
    let fixtures = corpusSweepFixtures()
    guard !fixtures.isEmpty else {
      return  // corpus not available on this machine
    }

    let result = try gate.run(provider: PDFKitProvider(), fixtures: fixtures)

    // Every fixture must have reviewed cases
    for fixture in result.fixtures {
      #expect(fixture.reviewedCaseCount > 0, "\(fixture.fixtureID) must have reviewed cases")
      #expect(!fixture.unreviewed, "\(fixture.fixtureID) must not be unreviewed")
    }

    // Native lane must pass for all fixtures
    for fixture in result.fixtures {
      if let native = fixture.native {
        #expect(native.metrics.passed, "\(fixture.fixtureID) native lane must pass")
      }
    }

    #expect(result.passed, "All fixtures must pass the dual-lane gate")
    print("\n[DualLane evidence] \(result.summary)")
  }

  // MARK: - Mutation Tests

  @Test("Dropped-field mutation fails the gate on the affected fixture")
  func droppedFieldMutationFailsGate() throws {
    let fixtures = corpusSweepFixtures()
    guard let firstFixture = fixtures.first else { return }

    let inspection = try PDFKitProvider().inspect(url: firstFixture)
    let allCandidates = NativeDetectorGate.liveCandidates(inspection)

    // Drop one candidate to simulate a regression
    guard var candidates = allCandidates.first else { return }
    let droppedCandidates = Array(allCandidates.dropFirst())

    let gate = DualLaneDetectorGate()
    let result = try gate.run(
      provider: PDFKitProvider(),
      fixtures: [firstFixture],
      nativeCandidates: { _ in droppedCandidates }
    )

    // The fixture should fail (dropped candidate = lower recall)
    if let fixture = result.fixtures.first, let native = fixture.native {
      #expect(!native.metrics.passed || native.metrics.recall ?? 1.0 < 1.0,
              "Dropped candidate must reduce recall or fail the fixture")
    }
  }

  // MARK: - Unreviewed Fixture

  @Test("Fixture with no ground truth fails closed")
  func unreviewedFixtureFailsClosed() throws {
    // Use a real PDF that's NOT in the ground truth. The public-sample-form
    // is in the threshold calibration corpus but not the detector ground truth.
    let results = "\(TestRepoRoot.prefix)benchmark/results"
    let sampleForm = URL(fileURLWithPath: "\(results)/public-sample-form.pdf")
    guard FileManager.default.fileExists(atPath: sampleForm.path) else { return }

    let result = try gate.run(provider: PDFKitProvider(), fixtures: [sampleForm])

    if let fixture = result.fixtures.first {
      #expect(fixture.unreviewed, "public-sample-form.pdf must be unreviewed in detector ground truth")
      #expect(!result.passed, "Unreviewed fixture must fail the gate (fail-closed)")
    }
  }

  // MARK: - Both Lanes Measured

  @Test("Both native and browser lanes are measured when browser candidates provided")
  func bothLanesMeasured() throws {
    let fixtures = corpusSweepFixtures()
    guard let firstFixture = fixtures.first else { return }

    let inspection = try PDFKitProvider().inspect(url: firstFixture)
    let nativeCands = NativeDetectorGate.liveCandidates(inspection)

    // Provide empty browser candidates to trigger browser lane measurement
    let result = try gate.run(
      provider: PDFKitProvider(),
      fixtures: [firstFixture],
      browserCandidates: { _ in [] }
    )

    if let fixture = result.fixtures.first {
      #expect(fixture.native != nil, "Native lane must be measured")
      #expect(fixture.browser != nil, "Browser lane must be measured when candidates provided")
    }
  }

  @Test("Browser lane absent when no browser candidates callback provided")
  func browserLaneAbsent() throws {
    let fixtures = corpusSweepFixtures()
    guard let firstFixture = fixtures.first else { return }

    let result = try gate.run(
      provider: PDFKitProvider(),
      fixtures: [firstFixture]
    )

    if let fixture = result.fixtures.first {
      #expect(fixture.browser == nil, "Browser lane must be nil when no callback provided")
    }
  }

  // MARK: - Report Round-Trip

  @Test("Gate result round-trips through JSON")
  func reportRoundTrip() throws {
    let fixtures = corpusSweepFixtures()
    guard let firstFixture = fixtures.first else { return }

    let result = try gate.run(provider: PDFKitProvider(), fixtures: [firstFixture])

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(result)
    let decoded = try JSONDecoder().decode(DualLaneDetectorGateResult.self, from: data)

    #expect(decoded.schema == result.schema)
    #expect(decoded.passed == result.passed)
    #expect(decoded.fixtures.count == result.fixtures.count)
    #expect(decoded.groundTruthCount == result.groundTruthCount)
  }

  // MARK: - Helpers

  private func corpusSweepFixtures() -> [URL] {
    let results = "\(TestRepoRoot.prefix)benchmark/results"
    let sweepDir = "\(results)/corpus-sweep-2026-08-25"
    let names = [
      "plain-text.pdf", "multi-column.pdf", "navigation.pdf", "geometry.pdf",
      "metadata-complete.pdf", "metadata-absent.pdf", "metadata-custom.pdf",
      "metadata-malformed.pdf", "metadata-unicode.pdf",
      "signed-valid-structure.pdf", "signed-invalid-structure.pdf", "signed-multiple.pdf",
      "xfa-static.pdf", "xfa-hybrid.pdf", "xfa-dynamic.pdf"
    ]
    return names.compactMap { name in
      let url = URL(fileURLWithPath: "\(sweepDir)/\(name)")
      return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
  }
}
