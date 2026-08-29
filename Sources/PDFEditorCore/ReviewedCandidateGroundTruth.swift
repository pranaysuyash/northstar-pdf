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
/// - The corpus-sweep cases were originally **generator-manifest** structural
///   expectations. A human review pass on 2026-08-28 (qpdf 12.4 structural
///   inspection of every fixture) found those expectations were **wrong**: all
///   five fixtures are the base `public-sample-form.pdf` with pages added, so
///   page 0 of each retains the 6 AcroForm widgets. The cases were corrected
///   to 30 native-field positives + 5 page-level abstains and re-labeled
///   `human-reviewed` with the review record below.
///
/// First principle: provider candidates are never ground truth. Only reviewed
/// sidecar labels are ground truth. Provider candidate IDs, text, scores, and
/// digests never enter the report.

// MARK: - Review Record

/// Record of the human review pass that corrected the corpus-sweep cases.
public struct GroundTruthReviewRecord: Codable, Sendable, Equatable {
  public let reviewedOn: String
  public let reviewer: String
  public let method: String
  public let tool: String
  /// Per-fixture observed structure (widget counts, page counts, boxes).
  public let fixtureFindings: [String: String]
}

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

  /// Human-reviewed corpus-sweep cases (corrected + extended 2026-08-28).
  ///
  /// The original generator-manifest cases asserted "no editable candidates"
  /// on five fixtures. qpdf 12.4 structural inspection (every object, every
  /// page /Annots, every widget /Rect) proved that wrong: **every** fixture is
  /// `public-sample-form.pdf` (6 AcroForm widgets on page 0) with pages added
  /// by `Tests/fixtures/generate_corpus_sweep.py`. The corrected truth:
  /// - 90 native-field positives (6 widgets × 15 form-bearing fixtures,
  ///   page 0) — the widget rects are identical across fixtures (same base
  ///   form). xfa-dynamic is included: its AcroForm tree is empty (dynamic
  ///   XFA characteristic) but the 6 widget annotations ARE on the page.
  /// - 8 page-level abstains for the genuinely widget-free added pages
  ///   (plain-text ×2, multi-column ×1, navigation ×2, geometry ×3).
  public static let corpusSweepCases: [ReviewedGroundTruthCase] = {
    // Widget rects observed on page 0 of every fixture (qpdf --show-object).
    // Field order: name (Tx), notes (Tx), subscribe (Btn), contact (Btn),
    // contact (Btn), country (Ch).
    struct Widget { let name: String; let rect: PDFRect }
    let widgets: [Widget] = [
      Widget(name: "applicant.name", rect: PDFRect(x: 185.5, y: 705.39, width: 251, height: 23)),
      Widget(name: "applicant.notes", rect: PDFRect(x: 185.5, y: 617.39, width: 251, height: 67)),
      Widget(name: "applicant.subscribe", rect: PDFRect(x: 185.5, y: 567.39, width: 19, height: 19)),
      Widget(name: "applicant.contact", rect: PDFRect(x: 185.5, y: 523.39, width: 19, height: 19)),
      Widget(name: "applicant.contact", rect: PDFRect(x: 255.5, y: 523.39, width: 19, height: 19)),
      Widget(name: "applicant.country", rect: PDFRect(x: 185.5, y: 477.39, width: 251, height: 23))
    ]
    // All 15 fixtures carry the base form widgets on page 0 (qpdf verified).
    let formFixtures = [
      "plain-text.pdf", "multi-column.pdf", "navigation.pdf",
      "signed-valid-structure.pdf", "xfa-static.pdf",
      "geometry.pdf", "metadata-complete.pdf", "metadata-absent.pdf",
      "metadata-custom.pdf", "metadata-malformed.pdf", "metadata-unicode.pdf",
      "signed-invalid-structure.pdf", "signed-multiple.pdf",
      "xfa-hybrid.pdf", "xfa-dynamic.pdf"
    ]

    var cases: [ReviewedGroundTruthCase] = []
    for fixture in formFixtures {
      for (index, widget) in widgets.enumerated() {
        let fixtureID = fixture.replacingOccurrences(of: ".pdf", with: "")
        let xfaNote = fixture == "xfa-dynamic.pdf"
          ? " (AcroForm tree empty — dynamic XFA — but widget annotations present on page)"
          : ""
        cases.append(ReviewedGroundTruthCase(
          id: "cs-\(fixtureID)-field-\(index)",
          reviewedRegionID: "reviewed:\(fixtureID):field-\(index)",
          fixtureID: fixture, pageIndex: 0,
          className: "nativeField", expectedState: "detected", isHardNegative: false,
          target: widget.rect,
          requiredEvidence: ["nativeField"],
          expectedEvidenceFamilies: ["nativeField"],
          expectedLabelAssociation: "associated", expectedGroupingState: "single",
          rationale: "Native AcroForm widget '\(widget.name)' on base-form page 0 (reviewed via qpdf structural inspection)\(xfaNote)."
        ))
      }
    }

    // Page-level abstains for the genuinely widget-free added pages.
    let abstains: [(fixture: String, page: Int, rect: PDFRect, severity: String, why: String)] = [
      ("plain-text.pdf", 1, PDFRect(x: 0, y: 0, width: 612, height: 792), "medium",
       "Added text page 2 — no /Annots (qpdf verified)."),
      ("plain-text.pdf", 2, PDFRect(x: 0, y: 0, width: 612, height: 792), "medium",
       "Added text page 3 — no /Annots (qpdf verified)."),
      ("multi-column.pdf", 1, PDFRect(x: 0, y: 0, width: 792, height: 612), "medium",
       "Added text page 2 — no /Annots (qpdf verified)."),
      ("navigation.pdf", 1, PDFRect(x: 0, y: 0, width: 612, height: 792), "medium",
       "Added page 2 — link annots only, no editable widgets (qpdf verified)."),
      ("navigation.pdf", 2, PDFRect(x: 0, y: 0, width: 612, height: 792), "medium",
       "Added page 3 — no /Annots (qpdf verified)."),
      ("geometry.pdf", 1, PDFRect(x: 0, y: 0, width: 200, height: 2000), "medium",
       "Added tall page 2 — no /Annots (qpdf verified)."),
      ("geometry.pdf", 2, PDFRect(x: 0, y: 0, width: 612, height: 792), "medium",
       "Added rotated page 3 — no /Annots (qpdf verified)."),
      ("geometry.pdf", 3, PDFRect(x: 36, y: 36, width: 364, height: 664), "medium",
       "Added cropped page 4 — no /Annots, crop box [36 36 400 700] (qpdf verified).")
    ]
    for abstain in abstains {
      let fixtureID = abstain.fixture.replacingOccurrences(of: ".pdf", with: "")
      cases.append(ReviewedGroundTruthCase(
        id: "cs-\(fixtureID)-page-\(abstain.page)-no-fields",
        reviewedRegionID: "reviewed:\(fixtureID):page-\(abstain.page):no-fields",
        fixtureID: abstain.fixture, pageIndex: abstain.page,
        className: "whitespace", expectedState: "abstain", isHardNegative: true,
        target: abstain.rect,
        requiredEvidence: ["whitespace"],
        expectedEvidenceFamilies: ["whitespace"],
        expectedLabelAssociation: "none", expectedGroupingState: "abstain",
        falsePositiveSeverity: abstain.severity,
        rationale: abstain.why
      ))
    }
    return cases
  }()

  /// Record of the 2026-08-28 human review pass that corrected and extended
  /// the corpus-sweep cases.
  public static let reviewRecord = GroundTruthReviewRecord(
    reviewedOn: "2026-08-28",
    reviewer: "doctrine-alignment review pass (qpdf structural inspection)",
    method: "All 15 fixtures opened with qpdf 12.4 --json + --show-object; page /Annots arrays,"
      + " widget /Rect and /FT inspected; generator script intent cross-checked",
    tool: "qpdf 12.4.0",
    fixtureFindings: [
      "plain-text.pdf": "3 pages; page 0 = base form with 6 AcroForm widgets; pages 1-2 no /Annots",
      "multi-column.pdf": "2 pages; page 0 = base form with 6 widgets; page 1 no /Annots",
      "navigation.pdf": "3 pages; page 0 = base form with 6 widgets; page 1 has 3 link annots only; page 2 no /Annots",
      "signed-valid-structure.pdf": "1 page; base form with 6 widgets + signature",
      "xfa-static.pdf": "1 page; base form with 6 widgets + XFA packet",
      "geometry.pdf": "4 pages; page 0 = base form with 6 widgets; pages 1-3 no /Annots (200x2000, 612x792 r90, crop [36 36 400 700])",
      "metadata-complete.pdf": "1 page; base form with 6 widgets + metadata",
      "metadata-absent.pdf": "1 page; base form with 6 widgets, no metadata",
      "metadata-custom.pdf": "1 page; base form with 6 widgets + custom metadata",
      "metadata-malformed.pdf": "1 page; base form with 6 widgets + malformed metadata",
      "metadata-unicode.pdf": "1 page; base form with 6 widgets + unicode metadata",
      "signed-invalid-structure.pdf": "1 page; base form with 6 widgets + invalid signature structure",
      "signed-multiple.pdf": "1 page; base form with 6 widgets + multiple signatures",
      "xfa-hybrid.pdf": "1 page; base form with 6 widgets + hybrid XFA packet",
      "xfa-dynamic.pdf": "1 page; 6 widget annotations present but AcroForm tree empty (dynamic XFA)"
    ]
  )
}