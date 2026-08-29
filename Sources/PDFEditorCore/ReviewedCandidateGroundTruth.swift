import Foundation

/// Reviewed candidate ground truth — the canonical reviewed-region labels
/// used to measure detector precision, recall, abstention, and label
/// association across the PDF corpus.
///
/// Mirrors `benchmark/results/detector-calibration/detector_calibration_labels.json`
/// (schema `pdf-editor.detector-calibration-labels` v1.0) and extends it
/// corpus-wide.
///
/// Truth taxonomy (§2):
/// - The 10 detector-calibration regions are **human-reviewed** ground truth
///   (provenance: 2026-08-25 reviewed calibration, source SHA-256
///   `5d50d759273ea20f43beecbc97737cf7053e0cf61ce643bb802e3b9b29b83d6f`).
/// - Corpus-sweep entries are **generator-derived** reviewed labels (provenance:
///   `benchmark/results/corpus-sweep-2026-08-25/manifest.json` expected facts),
///   labeled `provenance: "generator-manifest"` — they are structural expectations,
///   not human visual review.
///
/// First principle: provider candidates are never ground truth. Only reviewed
/// sidecar labels are ground truth. Provider candidate IDs, text, scores, and
/// digests never enter the report.

// MARK: - Ground Truth Case

/// A single reviewed region expectation.
public struct ReviewedGroundTruthCase: Codable, Sendable, Identifiable, Hashable {
  public let id: String
  /// Stable reviewed region ID (survives across provider runs and candidate IDs).
  public let reviewedRegionID: String
  /// Corpus fixture this region belongs to (e.g., "detector-calibration.pdf").
  public let fixtureID: String
  public let pageIndex: Int
  /// Detector class: vectorRectangle, checkbox, underline, whitespace, labelAssociation…
  public let className: String
  /// Expected detection state: "detected" or "abstain".
  public let expectedState: String
  /// Hard negative — looks similar but must NOT be promoted.
  public let isHardNegative: Bool
  /// Reviewed target rect in PDF points (lower-left origin, crop box).
  public let target: PDFRect
  /// Minimum evidence kinds required to match (e.g., ["vectorRectangle"]).
  public let requiredEvidence: [String]
  /// Complete expected evidence families (e.g., ["geometry", "label", "relationship"]).
  public let expectedEvidenceFamilies: [String]
  /// Expected label association: "associated" or "none".
  public let expectedLabelAssociation: String
  /// Expected grouping state: "single", "grouped", or "abstain".
  public let expectedGroupingState: String
  /// False-positive severity if a hard negative is promoted: low/medium/high/critical.
  public let falsePositiveSeverity: String?
  /// Provenance of this label: "human-reviewed" or "generator-manifest".
  public let provenance: String
  /// Why this region exists.
  public let rationale: String?

  public init(
    id: String,
    reviewedRegionID: String,
    fixtureID: String,
    pageIndex: Int,
    className: String,
    expectedState: String,
    isHardNegative: Bool,
    target: PDFRect,
    requiredEvidence: [String],
    expectedEvidenceFamilies: [String],
    expectedLabelAssociation: String,
    expectedGroupingState: String,
    falsePositiveSeverity: String? = nil,
    provenance: String = "human-reviewed",
    rationale: String? = nil
  ) {
    self.id = id
    self.reviewedRegionID = reviewedRegionID
    self.fixtureID = fixtureID
    self.pageIndex = pageIndex
    self.className = className
    self.expectedState = expectedState
    self.isHardNegative = isHardNegative
    self.target = target
    self.requiredEvidence = requiredEvidence
    self.expectedEvidenceFamilies = expectedEvidenceFamilies
    self.expectedLabelAssociation = expectedLabelAssociation
    self.expectedGroupingState = expectedGroupingState
    self.falsePositiveSeverity = falsePositiveSeverity
    self.provenance = provenance
    self.rationale = rationale
  }
}

// MARK: - Ground Truth Corpus

/// The full reviewed ground truth across the PDF corpus.
public struct ReviewedCandidateGroundTruth: Codable, Sendable {
  public let schema: String
  public let cases: [ReviewedGroundTruthCase]

  public init(schema: String = "pdf-editor.detector-semantic-comparison", cases: [ReviewedGroundTruthCase]) {
    self.schema = schema
    self.cases = cases
  }

  public func cases(forFixture fixtureID: String) -> [ReviewedGroundTruthCase] {
    cases.filter { $0.fixtureID == fixtureID }
  }

  public func cases(hardNegatives: Bool) -> [ReviewedGroundTruthCase] {
    cases.filter { $0.isHardNegative == hardNegatives }
  }

  public var positiveCount: Int { cases.filter { $0.expectedState == "detected" }.count }
  public var hardNegativeCount: Int { cases.filter { $0.isHardNegative }.count }

  // MARK: - Canonical corpus

  /// The canonical reviewed ground truth corpus.
  ///
  /// - `detector-calibration.pdf`: the 10 human-reviewed regions (mirrors the
  ///   reviewed labels JSON exactly).
  /// - Corpus-sweep fixtures: generator-derived structural expectations.
  public static func canonical() -> ReviewedCandidateGroundTruth {
    ReviewedCandidateGroundTruth(cases: Self.detectorCalibrationCases + Self.corpusSweepCases)
  }

  /// The 10 human-reviewed detector-calibration regions (v1.0 labels).
  public static let detectorCalibrationCases: [ReviewedGroundTruthCase] = [
    ReviewedGroundTruthCase(
      id: "p0-vector-rectangle", reviewedRegionID: "reviewed:p0:applicant-name-box",
      fixtureID: "detector-calibration.pdf", pageIndex: 0,
      className: "vectorRectangle", expectedState: "detected", isHardNegative: false,
      target: PDFRect(x: 180, y: 700, width: 300, height: 32),
      requiredEvidence: ["vectorRectangle"],
      expectedEvidenceFamilies: ["geometry", "label", "relationship"],
      expectedLabelAssociation: "associated", expectedGroupingState: "single",
      rationale: "Labeled rectangular entry region after Applicant Name."
    ),
    ReviewedGroundTruthCase(
      id: "p0-checkbox", reviewedRegionID: "reviewed:p0:agreement-checkbox",
      fixtureID: "detector-calibration.pdf", pageIndex: 0,
      className: "checkbox", expectedState: "detected", isHardNegative: false,
      target: PDFRect(x: 180, y: 640, width: 14, height: 14),
      requiredEvidence: ["vectorRectangle"],
      expectedEvidenceFamilies: ["geometry", "label", "relationship"],
      expectedLabelAssociation: "associated", expectedGroupingState: "single",
      rationale: "Checkbox cell following an agreement statement."
    ),
    ReviewedGroundTruthCase(
      id: "p0-underline", reviewedRegionID: "reviewed:p0:signature-rule",
      fixtureID: "detector-calibration.pdf", pageIndex: 0,
      className: "underline", expectedState: "detected", isHardNegative: false,
      target: PDFRect(x: 180, y: 580, width: 250, height: 6),
      requiredEvidence: ["underline"],
      expectedEvidenceFamilies: ["geometry", "label", "relationship"],
      expectedLabelAssociation: "associated", expectedGroupingState: "single",
      rationale: "Signature underline following a label."
    ),
    ReviewedGroundTruthCase(
      id: "p0-whitespace", reviewedRegionID: "reviewed:p0:empty-entry",
      fixtureID: "detector-calibration.pdf", pageIndex: 0,
      className: "whitespace", expectedState: "detected", isHardNegative: false,
      target: PDFRect(x: 180, y: 520, width: 220, height: 24),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace", "label", "relationship"],
      expectedLabelAssociation: "associated", expectedGroupingState: "single",
      rationale: "Empty whitespace entry region with a label."
    ),
    ReviewedGroundTruthCase(
      id: "p0-label-association", reviewedRegionID: "reviewed:p0:date-field",
      fixtureID: "detector-calibration.pdf", pageIndex: 0,
      className: "labelAssociation", expectedState: "detected", isHardNegative: false,
      target: PDFRect(x: 180, y: 460, width: 180, height: 24),
      requiredEvidence: ["textLabel", "spatialRelationship"],
      expectedEvidenceFamilies: ["label", "relationship"],
      expectedLabelAssociation: "associated", expectedGroupingState: "single",
      rationale: "Label-to-region spatial association for a date field."
    ),
    ReviewedGroundTruthCase(
      id: "p1-decorative-rectangle", reviewedRegionID: "reviewed:p1:decorative-box",
      fixtureID: "detector-calibration.pdf", pageIndex: 1,
      className: "vectorRectangle", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 50, y: 700, width: 200, height: 60),
      requiredEvidence: ["vectorRectangle"],
      expectedEvidenceFamilies: ["geometry"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "medium",
      rationale: "Decorative box with no field intent — must abstain."
    ),
    ReviewedGroundTruthCase(
      id: "p1-isolated-square", reviewedRegionID: "reviewed:p1:isolated-square",
      fixtureID: "detector-calibration.pdf", pageIndex: 1,
      className: "checkbox", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 300, y: 640, width: 12, height: 12),
      requiredEvidence: ["vectorRectangle"],
      expectedEvidenceFamilies: ["geometry"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "high",
      rationale: "Isolated square without label or context — must abstain."
    ),
    ReviewedGroundTruthCase(
      id: "p1-bare-rule", reviewedRegionID: "reviewed:p1:bare-rule",
      fixtureID: "detector-calibration.pdf", pageIndex: 1,
      className: "underline", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 50, y: 580, width: 300, height: 4),
      requiredEvidence: ["underline"],
      expectedEvidenceFamilies: ["geometry"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "low",
      rationale: "Bare horizontal rule with no label — must abstain."
    ),
    ReviewedGroundTruthCase(
      id: "p1-generic-box", reviewedRegionID: "reviewed:p1:generic-box",
      fixtureID: "detector-calibration.pdf", pageIndex: 1,
      className: "labelAssociation", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 300, y: 500, width: 150, height: 40),
      requiredEvidence: ["textLabel", "spatialRelationship"],
      expectedEvidenceFamilies: ["label", "relationship"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "high",
      rationale: "Generic box with unrelated nearby text — must not associate."
    ),
    ReviewedGroundTruthCase(
      id: "p1-generic-whitespace", reviewedRegionID: "reviewed:p1:generic-whitespace",
      fixtureID: "detector-calibration.pdf", pageIndex: 1,
      className: "whitespace", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 50, y: 460, width: 400, height: 30),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "medium",
      rationale: "Large whitespace gap with no label — must abstain."
    )
  ]

  /// Generator-derived structural expectations for corpus-sweep fixtures.
  /// Provenance: manifest.json expected facts (pages, rotations, sizes).
  /// These assert *non-detection* invariants (no editable candidates on
  /// plain text / navigation / metadata pages) plus rotation-aware geometry
  /// on the geometry fixture.
  public static let corpusSweepCases: [ReviewedGroundTruthCase] = [
    ReviewedGroundTruthCase(
      id: "cs-plain-text-no-candidates", reviewedRegionID: "reviewed:plain-text:no-editable-regions",
      fixtureID: "plain-text.pdf", pageIndex: 0,
      className: "whitespace", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 0, y: 0, width: 612, height: 792),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "medium", provenance: "generator-manifest",
      rationale: "Plain-text page must not yield editable candidates."
    ),
    ReviewedGroundTruthCase(
      id: "cs-multi-column-no-candidates", reviewedRegionID: "reviewed:multi-column:no-editable-regions",
      fixtureID: "multi-column.pdf", pageIndex: 0,
      className: "whitespace", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 0, y: 0, width: 612, height: 792),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "medium", provenance: "generator-manifest",
      rationale: "Multi-column text page must not yield editable candidates."
    ),
    ReviewedGroundTruthCase(
      id: "cs-navigation-no-candidates", reviewedRegionID: "reviewed:navigation:no-editable-regions",
      fixtureID: "navigation.pdf", pageIndex: 0,
      className: "whitespace", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 0, y: 0, width: 612, height: 792),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "medium", provenance: "generator-manifest",
      rationale: "Navigation-only page must not yield editable candidates."
    ),
    ReviewedGroundTruthCase(
      id: "cs-signature-no-candidates", reviewedRegionID: "reviewed:signed-valid:no-editable-regions",
      fixtureID: "signed-valid-structure.pdf", pageIndex: 0,
      className: "whitespace", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 0, y: 0, width: 612, height: 792),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "high", provenance: "generator-manifest",
      rationale: "Signed document must not yield editable candidates (signature guard)."
    ),
    ReviewedGroundTruthCase(
      id: "cs-xfa-no-candidates", reviewedRegionID: "reviewed:xfa-static:no-editable-regions",
      fixtureID: "xfa-static.pdf", pageIndex: 0,
      className: "whitespace", expectedState: "abstain", isHardNegative: true,
      target: PDFRect(x: 0, y: 0, width: 612, height: 792),
      requiredEvidence: ["whitespace"],
      expectedEvidenceFamilies: ["whitespace"],
      expectedLabelAssociation: "none", expectedGroupingState: "abstain",
      falsePositiveSeverity: "high", provenance: "generator-manifest",
      rationale: "XFA document must not yield editable candidates (XFA guard)."
    )
  ]
}