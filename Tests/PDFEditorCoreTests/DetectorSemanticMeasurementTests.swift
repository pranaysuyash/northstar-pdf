import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Helpers

private func candidate(
  page: Int = 0,
  x: Double, y: Double, width: Double, height: Double,
  kind: String? = nil,
  evidence: [String],
  label: Bool = false,
  groupCount: Int = 1
) -> DetectorCandidate {
  DetectorCandidate(
    pageIndex: page,
    bounds: PDFRect(x: x, y: y, width: width, height: height),
    kind: kind,
    groupMemberCount: groupCount,
    evidenceFamilies: evidence,
    labelAssociated: label
  )
}

/// The calibration fixture candidates as a native-like lane would produce them:
/// 5 positives detected with full evidence + label, 5 hard negatives abstained.
/// Plus the 6 base-form AcroForm widgets (page 0) that every corpus-sweep
/// fixture carries.
private func perfectNativeCandidates() -> [DetectorCandidate] {
  [
    candidate(x: 180, y: 700, width: 300, height: 32, kind: "vectorRectangle",
              evidence: ["geometry", "label", "relationship"], label: true),
    candidate(x: 180, y: 640, width: 14, height: 14, kind: "vectorRectangle",
              evidence: ["geometry", "label", "relationship"], label: true),
    candidate(x: 180, y: 580, width: 250, height: 6, kind: "underline",
              evidence: ["geometry", "label", "relationship"], label: true),
    candidate(x: 180, y: 520, width: 220, height: 24, kind: "whitespace",
              evidence: ["whitespace", "label", "relationship"], label: true),
    candidate(x: 180, y: 460, width: 180, height: 24, kind: "textLabel",
              evidence: ["label", "relationship"], label: true),
    // Base-form AcroForm widgets (identical rects across all 5 sweep fixtures).
    candidate(x: 185.5, y: 705.39, width: 251, height: 23, kind: "nativeField",
              evidence: ["nativeField"], label: true),
    candidate(x: 185.5, y: 617.39, width: 251, height: 67, kind: "nativeField",
              evidence: ["nativeField"], label: true),
    candidate(x: 185.5, y: 567.39, width: 19, height: 19, kind: "nativeField",
              evidence: ["nativeField"], label: true),
    candidate(x: 185.5, y: 523.39, width: 19, height: 19, kind: "nativeField",
              evidence: ["nativeField"], label: true),
    candidate(x: 255.5, y: 523.39, width: 19, height: 19, kind: "nativeField",
              evidence: ["nativeField"], label: true),
    candidate(x: 185.5, y: 477.39, width: 251, height: 23, kind: "nativeField",
              evidence: ["nativeField"], label: true)
  ]
}

// MARK: - Ground Truth Tests

@Suite("Reviewed Candidate Ground Truth")
struct ReviewedGroundTruthTests {

  @Test("Canonical corpus has 108 cases across 16 fixtures")
  func canonicalCorpus() {
    let gt = ReviewedCandidateGroundTruth.canonical()
    #expect(gt.cases.count == 108, "Expected 108 cases, got \(gt.cases.count)")
    #expect(gt.positiveCount == 95, "Expected 95 positives")
    #expect(gt.hardNegativeCount == 13, "Expected 13 hard negatives")
  }

  @Test("Detector-calibration fixture has 10 human-reviewed cases")
  func detectorCalibrationFixture() {
    let gt = ReviewedCandidateGroundTruth.canonical()
    let cases = gt.cases(forFixture: "detector-calibration.pdf")
    #expect(cases.count == 10)
    #expect(cases.allSatisfy { $0.provenance == "human-reviewed" })
  }

  @Test("Corpus-sweep entries are human-reviewed after the 2026-08-28 review pass")
  func corpusSweepEntries() {
    let gt = ReviewedCandidateGroundTruth.canonical()
    let sweep = gt.cases.filter { $0.fixtureID != "detector-calibration.pdf" }
    #expect(sweep.count == 98)
    #expect(sweep.allSatisfy { $0.provenance == "human-reviewed" })
    #expect(sweep.filter(\.isHardNegative).count == 8)
    #expect(sweep.filter { $0.expectedState == "detected" }.count == 90)
  }

  @Test("All 15 form-bearing fixtures have positive field expectations")
  func formFixturesPositive() {
    let gt = ReviewedCandidateGroundTruth.canonical()
    let formFixtures = [
      "plain-text.pdf", "multi-column.pdf", "navigation.pdf",
      "signed-valid-structure.pdf", "xfa-static.pdf",
      "geometry.pdf", "metadata-complete.pdf", "metadata-absent.pdf",
      "metadata-custom.pdf", "metadata-malformed.pdf", "metadata-unicode.pdf",
      "signed-invalid-structure.pdf", "signed-multiple.pdf",
      "xfa-hybrid.pdf", "xfa-dynamic.pdf"
    ]
    for fixture in formFixtures {
      let cases = gt.cases(forFixture: fixture)
      let positives = cases.filter { $0.expectedState == "detected" }
      #expect(positives.count == 6, "\(fixture) should have 6 positive field cases, got \(positives.count)")
      #expect(positives.allSatisfy { $0.className == "nativeField" })
    }
  }

  @Test("Review record captures the corrected fixture findings")
  func reviewRecord() {
    let record = ReviewedCandidateGroundTruth.reviewRecord
    #expect(record.reviewedOn == "2026-08-28")
    #expect(record.fixtureFindings.count == 15)
    #expect(record.fixtureFindings["plain-text.pdf"]?.contains("6 AcroForm widgets") == true)
    #expect(record.fixtureFindings["xfa-dynamic.pdf"]?.contains("AcroForm tree empty") == true)
  }

  @Test("Every case has stable reviewed region IDs")
  func stableRegionIDs() {
    let gt = ReviewedCandidateGroundTruth.canonical()
    let ids = Set(gt.cases.map(\.reviewedRegionID))
    #expect(ids.count == gt.cases.count, "Reviewed region IDs must be unique")
  }
}

// MARK: - Measurement Tests

@Suite("Detector Semantic Measurement")
struct DetectorSemanticMeasurementTests {

  private let groundTruth = ReviewedCandidateGroundTruth.canonical()
  private let measurement = DetectorSemanticMeasurement()

  @Test("Perfect native lane: precision 1, recall 1, abstention 1, label 1")
  func perfectNative() {
    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: perfectNativeCandidates()
    )
    #expect(result.metrics.precision == 1.0)
    #expect(result.metrics.recall == 1.0)
    #expect(result.metrics.abstention == 1.0)
    #expect(result.metrics.labelAssociationPrecision == 1.0)
    #expect(result.metrics.severityBurden == 0)
    #expect(result.metrics.passed)
    #expect(result.passedCount == groundTruth.cases.count)
  }

  @Test("Missing positive candidate drops recall and fails")
  func missingPositive() {
    // Remove the checkbox candidate (case p0-checkbox)
    var candidates = perfectNativeCandidates()
    candidates.remove(at: 1)

    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.recall != 1.0)
    #expect(!result.metrics.passed)
    #expect(result.failedCount == 1)
  }

  @Test("Hard negative promoted as candidate drops precision and abstention")
  func hardNegativePromoted() {
    var candidates = perfectNativeCandidates()
    // Promote the decorative rectangle hard negative (p1, target 50,700,200,60)
    candidates.append(candidate(
      page: 1, x: 50, y: 700, width: 200, height: 60,
      kind: "vectorRectangle", evidence: ["geometry"], label: false
    ))

    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.precision != 1.0)
    #expect(result.metrics.abstention != 1.0)
    #expect(!result.metrics.passed)
    #expect(result.metrics.severityBurden == 3) // medium severity weight
  }

  @Test("Hard negative promoted with high severity has burden 9")
  func highSeverityBurden() {
    var candidates = perfectNativeCandidates()
    // Promote the isolated square (high severity)
    candidates.append(candidate(
      page: 1, x: 300, y: 640, width: 12, height: 12,
      kind: "vectorRectangle", evidence: ["geometry"], label: false
    ))

    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.severityBurden == 9)
  }

  @Test("Label association mismatch detected")
  func labelMismatch() {
    var candidates = perfectNativeCandidates()
    // First positive detected but WITHOUT label association
    candidates[0] = candidate(
      x: 180, y: 700, width: 300, height: 32,
      kind: "vectorRectangle", evidence: ["geometry"], label: false
    )

    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.labelAssociationPrecision != 1.0)
    let caseResult = result.cases.first { $0.caseID == "p0-vector-rectangle" }
    #expect(caseResult?.labelAssociation.state == "mismatch")
  }

  @Test("Browser lane measured independently")
  func browserLane() {
    let result = measurement.measure(
      lane: .browser,
      groundTruth: groundTruth,
      candidates: perfectNativeCandidates()
    )
    #expect(result.lane == .browser)
    #expect(result.metrics.passed)
  }

  @Test("Native and browser parity: identical lanes produce zero mismatches")
  func parityAgreement() {
    let report = measurement.compare(
      groundTruth: groundTruth,
      nativeCandidates: perfectNativeCandidates(),
      browserCandidates: perfectNativeCandidates()
    )
    #expect(report.passed)
    #expect(report.unexpectedMismatchCount == 0)
  }

  @Test("Native/browser detection divergence surfaces in parity")
  func parityDivergence() {
    var browserCandidates = perfectNativeCandidates()
    browserCandidates.remove(at: 2) // browser misses the underline

    let report = measurement.compare(
      groundTruth: groundTruth,
      nativeCandidates: perfectNativeCandidates(),
      browserCandidates: browserCandidates
    )
    #expect(!report.passed)
    let entry = report.parity.first { $0.caseID == "p0-underline" }
    #expect(entry?.hasMismatch == true)
    #expect(entry?.mismatchKinds.contains("detection") == true)
  }

  @Test("Browser candidates decode from JSON contract shape")
  func browserJSONDecoding() {
    let json: [String: Any] = [
      "pageIndex": 0,
      "bounds": ["x": 180.0, "y": 700.0, "width": 300.0, "height": 32.0],
      "kind": "vectorRectangle",
      "evidenceItems": [
        ["kind": "vectorRectangle"],
        ["kind": "textLabel"],
        ["kind": "spatialRelationship"]
      ],
      "labelText": "Applicant Name",
      "groupMemberCount": 1
    ]
    let decoded = DetectorCandidate.browser(from: json)
    #expect(decoded != nil)
    #expect(decoded?.evidenceFamilies == ["geometry", "label", "relationship"])
    #expect(decoded?.labelAssociated == true)
  }

  @Test("Markdown export is content-free and includes metrics")
  func markdownExport() {
    let report = measurement.compare(
      groundTruth: groundTruth,
      nativeCandidates: perfectNativeCandidates(),
      browserCandidates: perfectNativeCandidates()
    )
    let md = measurement.toMarkdown(report)
    #expect(md.contains("Detector Semantic Comparison Report"))
    #expect(md.contains("Precision: 1.000"))
    #expect(md.contains("Recall: 1.000"))
    #expect(md.contains("Abstention: 1.000"))
    #expect(md.contains("reviewed:p0:applicant-name-box"))
  }

  // MARK: - Mutation Sensitivity (S3)

  @Test("S3: Removing required evidence families degrades agreement")
  func mutationEvidenceRemoval() {
    var candidates = perfectNativeCandidates()
    // Strip the label + relationship evidence families from the first positive.
    // Minimum match evidence (geometry) is still present → detection survives,
    // but the expected evidence family set [geometry, label, relationship]
    // is no longer exactly matched → evidence-family agreement degrades.
    candidates[0] = candidate(
      x: 180, y: 700, width: 300, height: 32,
      kind: "vectorRectangle", evidence: ["geometry"], label: false
    )
    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.evidenceFamilyAgreement != 1.0)
    #expect(!result.metrics.passed)
    let caseResult = result.cases.first { $0.caseID == "p0-vector-rectangle" }
    #expect(caseResult?.evidenceFamilyAgreement.exact == false)
    #expect(caseResult?.evidenceFamilyAgreement.missing == ["label", "relationship"])
  }

  @Test("S3: Shifting bounds below minimum IoU kills the match")
  func mutationBoundsShift() {
    var candidates = perfectNativeCandidates()
    // Move the checkbox far away (IoU drops below 0.25)
    candidates[1] = candidate(
      x: 500, y: 100, width: 14, height: 14,
      kind: "vectorRectangle", evidence: ["geometry", "label", "relationship"], label: true
    )
    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.recall != 1.0)
  }

  @Test("S3: Wrong page index kills the match")
  func mutationWrongPage() {
    var candidates = perfectNativeCandidates()
    // Same geometry but on page 1 instead of page 0
    candidates[0] = candidate(
      page: 1, x: 180, y: 700, width: 300, height: 32,
      kind: "vectorRectangle", evidence: ["geometry", "label", "relationship"], label: true
    )
    let result = measurement.measure(
      lane: .native,
      groundTruth: groundTruth,
      candidates: candidates
    )
    #expect(result.metrics.recall != 1.0)
  }
}

// MARK: - Native RegionCandidate Adapter Test

@Suite("Native RegionCandidate Adapter")
struct NativeCandidateAdapterTests {

  @Test("RegionCandidate normalizes to DetectorCandidate")
  func nativeAdapter() {
    let candidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 180, y: 700, width: 300, height: 32),
      kind: .vectorRegion,
      score: 0.9,
      evidence: ["vectorRectangle"],
      labelText: "Applicant Name",
      groupMemberCount: 1,
      evidenceItems: [
        CandidateEvidence(kind: .vectorRectangle, origin: .geometryExtraction, summary: "box"),
        CandidateEvidence(kind: .textLabel, origin: .textExtraction, summary: "label"),
        CandidateEvidence(kind: .spatialRelationship, origin: .geometryExtraction, summary: "rel")
      ]
    )

    let normalized = DetectorCandidate.native(from: candidate)
    #expect(normalized.evidenceFamilies == ["geometry", "label", "relationship"])
    #expect(normalized.labelAssociated)
    #expect(normalized.pageIndex == 0)
  }

  @Test("RegionCandidate without label is not label-associated")
  func nativeAdapterNoLabel() {
    let candidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 50, y: 700, width: 200, height: 60),
      kind: .vectorRegion,
      score: 0.5,
      evidence: ["vectorRectangle"],
      evidenceItems: [
        CandidateEvidence(kind: .vectorRectangle, origin: .geometryExtraction, summary: "box")
      ]
    )
    let normalized = DetectorCandidate.native(from: candidate)
    #expect(normalized.evidenceFamilies == ["geometry"])
    #expect(!normalized.labelAssociated)
  }
}