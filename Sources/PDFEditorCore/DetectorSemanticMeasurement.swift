import Foundation

/// Detector semantic measurement — measures native vs browser detector
/// precision, recall, abstention, and label-association agreement against
/// reviewed candidate ground truth across the PDF corpus.
///
/// Mirrors `web/detector-semantic-comparison.mjs` (contract
/// `pdf-editor.detector-semantic-comparison` v1.0) so native and browser
/// measurements are directly comparable:
/// - matching: minimumIoU 0.25, nearIoU 0.05, geometryTolerancePoints 0.5
/// - strategy: reviewed-region-first-score-with-one-selected-candidate
/// - false-positive severity weights: low 1, medium 3, high 9, critical 27
///
/// First principle: provider candidates are never ground truth. Only reviewed
/// sidecar labels are ground truth. Provider candidate IDs, labels, prose,
/// scores, timestamps, and raw digests never enter the report.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — every metric is derived from reviewed ground truth
/// - §5 Evidence-based — precision/recall/abstention are measured, not claimed
/// - §12 Privacy — report contains region identities, never document content

// MARK: - Evidence Family Mapping

/// Maps evidence kinds to their semantic families (mirrors mjs EVIDENCE_FAMILY_BY_KIND).
public enum EvidenceFamilyMapping {
  public static func family(forKind kind: String) -> String? {
    switch kind {
    case "vectorRectangle", "vectorLine", "underline", "checkboxShape": return "geometry"
    case "whitespace": return "whitespace"
    case "textLabel": return "label"
    case "spatialRelationship": return "relationship"
    case "ocrText", "ocrBounds": return "ocr"
    case "nativeField": return "nativeField"
    default: return nil
    }
  }

  /// Map a CandidateEvidenceKind to its family.
  public static func family(forEvidenceKind kind: CandidateEvidenceKind) -> String? {
    family(forKind: kind.rawValue)
  }
}

// MARK: - Detector Lane

/// Which detector lane produced the candidates.
public enum DetectorLane: String, Codable, Sendable, CaseIterable {
  case native = "native"
  case browser = "browser"
}

// MARK: - Normalized Detector Candidate

/// A provider candidate normalized to the measurement contract.
/// Candidate IDs, text, scores, and digests are intentionally excluded.
public struct DetectorCandidate: Sendable, Equatable {
  public let pageIndex: Int
  public let bounds: PDFRect
  /// Candidate kind (vectorRectangle, checkboxShape, underline, whitespace, textLabel…).
  public let kind: String?
  public let suggestedFieldType: String?
  public let entryMode: String
  public let groupMemberCount: Int
  public let evidenceFamilies: [String]
  public let labelAssociated: Bool

  public init(
    pageIndex: Int,
    bounds: PDFRect,
    kind: String? = nil,
    suggestedFieldType: String? = nil,
    entryMode: String = "unknown",
    groupMemberCount: Int = 1,
    evidenceFamilies: [String],
    labelAssociated: Bool
  ) {
    self.pageIndex = pageIndex
    self.bounds = bounds
    self.kind = kind
    self.suggestedFieldType = suggestedFieldType
    self.entryMode = entryMode
    self.groupMemberCount = max(1, groupMemberCount)
    self.evidenceFamilies = evidenceFamilies
    self.labelAssociated = labelAssociated
  }

  /// Normalize a native RegionCandidate.
  public static func native(from candidate: RegionCandidate) -> DetectorCandidate {
    let families = Array(Set(candidate.evidenceItems.compactMap {
      EvidenceFamilyMapping.family(forEvidenceKind: $0.kind)
    })).sorted()
    let labelAssociated = candidate.labelText != nil
      || families.contains("label")
      || families.contains("relationship")
    return DetectorCandidate(
      pageIndex: candidate.pageIndex,
      bounds: candidate.bounds,
      kind: candidate.kind.rawValue,
      suggestedFieldType: candidate.suggestedFieldType?.rawValue,
      entryMode: candidate.entryMode.rawValue,
      groupMemberCount: candidate.groupMemberCount,
      evidenceFamilies: families,
      labelAssociated: labelAssociated
    )
  }

  /// Normalize a browser candidate from decoded JSON (mirrors mjs normalizedCandidate).
  public static func browser(from json: [String: Any]) -> DetectorCandidate? {
    guard let pageIndex = json["pageIndex"] as? Int,
          let boundsDict = json["bounds"] as? [String: Any],
          let x = boundsDict["x"] as? Double,
          let y = boundsDict["y"] as? Double,
          let width = boundsDict["width"] as? Double,
          let height = boundsDict["height"] as? Double
    else { return nil }

    let evidenceItems = (json["evidenceItems"] as? [[String: Any]]) ?? []
    let families = Array(Set(evidenceItems.compactMap { item -> String? in
      guard let kind = item["kind"] as? String, !kind.isEmpty else { return nil }
      // Mirrors mjs: EVIDENCE_FAMILY_BY_KIND[kind] || kind (identity fallback).
      return EvidenceFamilyMapping.family(forKind: kind) ?? kind
    })).sorted()

    let groupCount = (json["groupMemberCount"] as? Int) ?? 1
    let labelAssociated = (json["labelText"] as? String) != nil
      || families.contains("label")
      || families.contains("relationship")

    return DetectorCandidate(
      pageIndex: pageIndex,
      bounds: PDFRect(x: x, y: y, width: width, height: height),
      kind: json["kind"] as? String,
      suggestedFieldType: json["suggestedFieldType"] as? String,
      entryMode: json["entryMode"] as? String ?? "unknown",
      groupMemberCount: groupCount,
      evidenceFamilies: families,
      labelAssociated: labelAssociated
    )
  }
}

// MARK: - Geometry Helpers

/// IoU between two rects (mirrors mjs rectIoU).
public func detectorRectIoU(_ left: PDFRect, _ right: PDFRect) -> Double {
  let l = left.standardized
  let r = right.standardized
  let ix = max(l.x, r.x)
  let iy = max(l.y, r.y)
  let iw = min(l.x + l.width, r.x + r.width) - ix
  let ih = min(l.y + l.height, r.y + r.height) - iy
  let intersection = max(0, iw) * max(0, ih)
  let union = max(1, l.width * l.height + r.width * r.height - intersection)
  return intersection / union
}

// MARK: - Set Agreement

/// Set agreement between expected and actual evidence families
/// (mirrors mjs setAgreement).
public struct EvidenceSetAgreement: Codable, Sendable, Equatable {
  public let expected: [String]
  public let actual: [String]
  public let intersection: [String]
  public let missing: [String]
  public let unexpected: [String]
  public let exact: Bool
  public let recall: Double?
  public let precision: Double?

  public init(expected: [String], actual: [String]) {
    let expectedSet = Set(expected)
    let actualSet = Set(actual)
    let intersection = expectedSet.intersection(actualSet).sorted()
    self.expected = expectedSet.sorted()
    self.actual = actualSet.sorted()
    self.intersection = intersection
    self.missing = expectedSet.subtracting(actualSet).sorted()
    self.unexpected = actualSet.subtracting(expectedSet).sorted()
    self.exact = intersection.count == expectedSet.count && intersection.count == actualSet.count
    self.recall = expectedSet.isEmpty ? nil : Double(intersection.count) / Double(expectedSet.count)
    self.precision = actualSet.isEmpty ? nil : Double(intersection.count) / Double(actualSet.count)
  }
}

// MARK: - Case Result

/// Per-case measurement result for one lane.
public struct DetectorCaseResult: Codable, Sendable {
  public let reviewedRegionID: String
  public let caseID: String
  public let className: String
  public let expectedState: String
  public let isHardNegative: Bool
  public let fixtureID: String
  public let detected: Bool
  public let state: String // "pass" | "mismatch"
  public let nearCandidateCount: Int
  public let evidenceFamilyAgreement: EvidenceSetAgreement
  public let labelAssociation: LabelAgreement
  public let grouping: GroupingAgreement
  public let falsePositiveSeverity: String?

  public var passed: Bool { state == "pass" }
}

/// Label association agreement.
public struct LabelAgreement: Codable, Sendable, Equatable {
  public let expected: String
  public let actual: String?
  public let state: String // "agree" | "mismatch" | "unknown"

  public init(expected: String, actual: String?, state: String) {
    self.expected = expected
    self.actual = actual
    self.state = state
  }
}

/// Grouping agreement.
public struct GroupingAgreement: Codable, Sendable, Equatable {
  public let expectedState: String
  public let actualState: String?
  public let expectedMemberCount: Int?
  public let actualMemberCount: Int?
  public let state: String // "agree" | "mismatch" | "unknown"

  public init(
    expectedState: String,
    actualState: String?,
    expectedMemberCount: Int? = nil,
    actualMemberCount: Int? = nil,
    state: String
  ) {
    self.expectedState = expectedState
    self.actualState = actualState
    self.expectedMemberCount = expectedMemberCount
    self.actualMemberCount = actualMemberCount
    self.state = state
  }
}

// MARK: - Metrics

/// Detector metrics for one lane (mirrors mjs metrics).
public struct DetectorMetrics: Codable, Sendable, Equatable {
  public let precision: Double?
  public let recall: Double?
  /// Correct abstention rate over hard negatives.
  public let abstention: Double?
  public let labelAssociationPrecision: Double?
  public let evidenceFamilyAgreement: Double?
  public let groupingAgreement: Double?
  /// Weighted severity burden of false positives (low 1, medium 3, high 9, critical 27).
  public let severityBurden: Int
  public let passed: Bool

  public init(
    precision: Double?,
    recall: Double?,
    abstention: Double?,
    labelAssociationPrecision: Double?,
    evidenceFamilyAgreement: Double?,
    groupingAgreement: Double?,
    severityBurden: Int,
    passed: Bool
  ) {
    self.precision = precision
    self.recall = recall
    self.abstention = abstention
    self.labelAssociationPrecision = labelAssociationPrecision
    self.evidenceFamilyAgreement = evidenceFamilyAgreement
    self.groupingAgreement = groupingAgreement
    self.severityBurden = severityBurden
    self.passed = passed
  }
}

// MARK: - Lane Result

/// Full measurement result for one lane.
public struct DetectorLaneResult: Codable, Sendable {
  public let lane: DetectorLane
  public let cases: [DetectorCaseResult]
  public let metrics: DetectorMetrics

  public var passedCount: Int { cases.filter(\.passed).count }
  public var failedCount: Int { cases.count - passedCount }
}

// MARK: - Parity

/// Native vs browser parity on a reviewed case.
public struct DetectorParityEntry: Codable, Sendable {
  public let reviewedRegionID: String
  public let caseID: String
  public let fixtureID: String
  public let nativeDetected: Bool
  public let browserDetected: Bool
  public let nativeLabel: String?
  public let browserLabel: String?
  public let mismatchKinds: [String]

  public var hasMismatch: Bool { !mismatchKinds.isEmpty }
}

// MARK: - Report

/// Full native vs browser semantic comparison report.
public struct DetectorSemanticReport: Codable, Sendable {
  public let schema: String
  public let groundTruthCount: Int
  public let native: DetectorLaneResult
  public let browser: DetectorLaneResult
  public let parity: [DetectorParityEntry]
  public let passed: Bool

  public var unexpectedMismatchCount: Int { parity.filter(\.hasMismatch).count }
}

// MARK: - Measurement Engine

/// Measures detector precision, recall, abstention, and label association
/// against reviewed ground truth across the corpus.
public struct DetectorSemanticMeasurement: Sendable {
  /// Minimum IoU for a candidate to match a reviewed region (contract 0.25).
  public let minimumIoU: Double
  /// IoU threshold for "near" candidates (contract 0.05).
  public let nearIoU: Double
  /// False-positive severity weights (contract low 1, medium 3, high 9, critical 27).
  public let severityWeights: [String: Int]

  public init(
    minimumIoU: Double = 0.25,
    nearIoU: Double = 0.05,
    severityWeights: [String: Int] = ["low": 1, "medium": 3, "high": 9, "critical": 27]
  ) {
    self.minimumIoU = minimumIoU
    self.nearIoU = nearIoU
    self.severityWeights = severityWeights
  }

  // MARK: Candidate Selection (mirrors mjs)

  private func candidateMatchesReview(_ caseLabel: ReviewedGroundTruthCase, _ candidate: DetectorCandidate) -> Bool {
    guard candidate.pageIndex == caseLabel.pageIndex else { return false }
    guard detectorRectIoU(caseLabel.target, candidate.bounds) >= minimumIoU else { return false }
    let minimum = minimumEvidenceFamilies(caseLabel)
    guard minimum.allSatisfy({ candidate.evidenceFamilies.contains($0) }) else { return false }
    return true
  }

  private func candidateScore(_ caseLabel: ReviewedGroundTruthCase, _ candidate: DetectorCandidate) -> Double {
    let required = requiredEvidenceFamilies(caseLabel)
    let coverage = required.isEmpty
      ? 1.0
      : Double(required.filter { candidate.evidenceFamilies.contains($0) }.count) / Double(required.count)
    let kindAgreement = 1.0 // kind is optional in this contract version
    let fieldTypeAgreement = 1.0
    return detectorRectIoU(caseLabel.target, candidate.bounds) * 0.7
      + coverage * 0.15
      + kindAgreement * 0.1
      + fieldTypeAgreement * 0.05
  }

  /// Expected evidence families for agreement comparison (mirrors mjs requiredEvidenceFamilies:
  /// uses expectedEvidenceFamilies first, falls back to requiredEvidence; identity fallback
  /// keeps family names already in family form).
  private func requiredEvidenceFamilies(_ caseLabel: ReviewedGroundTruthCase) -> [String] {
    let source = caseLabel.expectedEvidenceFamilies.isEmpty ? caseLabel.requiredEvidence : caseLabel.expectedEvidenceFamilies
    let mapped = source.compactMap { EvidenceFamilyMapping.family(forKind: $0) ?? $0 }
    return Array(Set(mapped)).sorted()
  }

  /// Minimum evidence families required for a candidate to MATCH a reviewed region
  /// (mirrors mjs minimumEvidenceFamilies: uses requiredEvidence first; identity fallback
  /// keeps family names already in family form).
  private func minimumEvidenceFamilies(_ caseLabel: ReviewedGroundTruthCase) -> [String] {
    let source = caseLabel.requiredEvidence.isEmpty ? caseLabel.expectedEvidenceFamilies : caseLabel.requiredEvidence
    let mapped = source.compactMap { EvidenceFamilyMapping.family(forKind: $0) ?? $0 }
    return Array(Set(mapped)).sorted()
  }

  private func expectedLabelAssociation(_ caseLabel: ReviewedGroundTruthCase) -> String {
    caseLabel.expectedLabelAssociation.isEmpty
      ? (caseLabel.isHardNegative ? "none" : "associated")
      : caseLabel.expectedLabelAssociation
  }

  // MARK: Per-Case Evaluation

  private func evaluateCase(
    _ caseLabel: ReviewedGroundTruthCase,
    candidates: [DetectorCandidate]
  ) -> DetectorCaseResult {
    let normalized = candidates
    let matching = normalized
      .filter { candidateMatchesReview(caseLabel, $0) }
      .sorted { candidateScore(caseLabel, $0) > candidateScore(caseLabel, $1) }
    let near = normalized.filter {
      $0.pageIndex == caseLabel.pageIndex
        && detectorRectIoU(caseLabel.target, $0.bounds) >= nearIoU
    }
    let selected = matching.first

    let detected = selected != nil
    let expectedDetected = caseLabel.expectedState == "detected"
    let correctState = expectedDetected == detected

    // Evidence family agreement
    let required = requiredEvidenceFamilies(caseLabel)
    let actualFamilies = selected?.evidenceFamilies ?? []
    let evidence = EvidenceSetAgreement(expected: required, actual: actualFamilies)

    // Label association
    let expectedLabel = expectedLabelAssociation(caseLabel)
    let label: LabelAgreement
    if let selected {
      let actual = selected.labelAssociated ? "associated" : "none"
      label = LabelAgreement(
        expected: expectedLabel,
        actual: actual,
        state: expectedLabel == actual ? "agree" : "mismatch"
      )
    } else {
      label = LabelAgreement(
        expected: expectedLabel,
        actual: nil,
        state: expectedLabel == "none" ? "agree" : "unknown"
      )
    }

    // Grouping
    let grouping: GroupingAgreement
    if caseLabel.expectedGroupingState == "abstain" {
      grouping = GroupingAgreement(
        expectedState: "abstain",
        actualState: selected.map { $0.groupMemberCount > 1 ? "grouped" : "single" },
        expectedMemberCount: nil,
        actualMemberCount: selected?.groupMemberCount,
        state: "agree"
      )
    } else if let selected {
      let actualState = selected.groupMemberCount > 1 ? "grouped" : "single"
      grouping = GroupingAgreement(
        expectedState: caseLabel.expectedGroupingState,
        actualState: actualState,
        expectedMemberCount: 1,
        actualMemberCount: selected.groupMemberCount,
        state: caseLabel.expectedGroupingState == actualState ? "agree" : "mismatch"
      )
    } else {
      grouping = GroupingAgreement(
        expectedState: caseLabel.expectedGroupingState,
        actualState: nil,
        expectedMemberCount: 1,
        actualMemberCount: nil,
        state: "unknown"
      )
    }

    return DetectorCaseResult(
      reviewedRegionID: caseLabel.reviewedRegionID,
      caseID: caseLabel.id,
      className: caseLabel.className,
      expectedState: caseLabel.expectedState,
      isHardNegative: caseLabel.isHardNegative,
      fixtureID: caseLabel.fixtureID,
      detected: detected,
      state: correctState ? "pass" : "mismatch",
      nearCandidateCount: near.count,
      evidenceFamilyAgreement: evidence,
      labelAssociation: label,
      grouping: grouping,
      falsePositiveSeverity: caseLabel.falsePositiveSeverity
    )
  }

  // MARK: Metrics

  private func computeMetrics(cases: [DetectorCaseResult]) -> DetectorMetrics {
    let positives = cases.filter { $0.expectedState == "detected" && !$0.isHardNegative }
    let hardNegatives = cases.filter { $0.isHardNegative }

    let truePositive = positives.filter(\.detected).count
    let falseNegative = positives.filter { !$0.detected }.count
    // False positives: hard negatives that were detected
    let falsePositive = hardNegatives.filter(\.detected).count

    let precision = (truePositive + falsePositive) > 0
      ? Double(truePositive) / Double(truePositive + falsePositive)
      : nil
    let recall = positives.isEmpty ? nil : Double(truePositive) / Double(positives.count)

    // Correct abstention: hard negatives NOT detected (rejected)
    let correctAbstention = hardNegatives.filter { !$0.detected }.count
    let abstention = hardNegatives.isEmpty ? nil : Double(correctAbstention) / Double(hardNegatives.count)

    // Label association precision over cases expecting association
    let associatedExpected = cases.filter { $0.labelAssociation.expected == "associated" }
    let associatedObserved = associatedExpected.filter { $0.labelAssociation.state == "agree" }.count
    let labelAssociationPrecision = associatedExpected.isEmpty
      ? nil
      : Double(associatedObserved) / Double(associatedExpected.count)

    // Evidence family agreement over detected positives
    let detectedPositives = positives.filter(\.detected)
    let evidenceAgreement = detectedPositives.isEmpty
      ? nil
      : Double(detectedPositives.filter { $0.evidenceFamilyAgreement.exact }.count) / Double(detectedPositives.count)

    // Grouping agreement
    let groupingAgreement = cases.isEmpty
      ? nil
      : Double(cases.filter { $0.grouping.state == "agree" }.count) / Double(cases.count)

    // Severity burden of false positives
    let burden = hardNegatives
      .filter(\.detected)
      .reduce(0) { $0 + (severityWeights[$1.falsePositiveSeverity ?? ""] ?? 0) }

    let passed = (recall ?? 1) == 1
      && (abstention ?? 1) == 1
      && (labelAssociationPrecision ?? 1) == 1
      && (evidenceAgreement ?? 1) == 1
      && (groupingAgreement ?? 1) == 1

    return DetectorMetrics(
      precision: precision,
      recall: recall,
      abstention: abstention,
      labelAssociationPrecision: labelAssociationPrecision,
      evidenceFamilyAgreement: evidenceAgreement,
      groupingAgreement: groupingAgreement,
      severityBurden: burden,
      passed: passed
    )
  }

  // MARK: Report

  /// Measure a lane against ground truth.
  public func measure(
    lane: DetectorLane,
    groundTruth: ReviewedCandidateGroundTruth,
    candidates: [DetectorCandidate]
  ) -> DetectorLaneResult {
    let results = groundTruth.cases.map { evaluateCase($0, candidates: candidates) }
    return DetectorLaneResult(lane: lane, cases: results, metrics: computeMetrics(cases: results))
  }

  /// Full native vs browser comparison.
  public func compare(
    groundTruth: ReviewedCandidateGroundTruth,
    nativeCandidates: [DetectorCandidate],
    browserCandidates: [DetectorCandidate]
  ) -> DetectorSemanticReport {
    let native = measure(lane: .native, groundTruth: groundTruth, candidates: nativeCandidates)
    let browser = measure(lane: .browser, groundTruth: groundTruth, candidates: browserCandidates)

    let nativeByCase = Dictionary(uniqueKeysWithValues: native.cases.map { ($0.caseID, $0) })
    let browserByCase = Dictionary(uniqueKeysWithValues: browser.cases.map { ($0.caseID, $0) })

    let parity = groundTruth.cases.compactMap { caseLabel -> DetectorParityEntry? in
      guard let nativeCase = nativeByCase[caseLabel.id],
            let browserCase = browserByCase[caseLabel.id]
      else { return nil }

      var mismatchKinds: [String] = []
      if nativeCase.detected != browserCase.detected { mismatchKinds.append("detection") }
      if nativeCase.labelAssociation.actual != browserCase.labelAssociation.actual {
        mismatchKinds.append("labelAssociation")
      }
      if nativeCase.evidenceFamilyAgreement.actual != browserCase.evidenceFamilyAgreement.actual {
        mismatchKinds.append("evidenceFamilies")
      }
      if nativeCase.grouping.state != browserCase.grouping.state {
        mismatchKinds.append("grouping")
      }

      return DetectorParityEntry(
        reviewedRegionID: caseLabel.reviewedRegionID,
        caseID: caseLabel.id,
        fixtureID: caseLabel.fixtureID,
        nativeDetected: nativeCase.detected,
        browserDetected: browserCase.detected,
        nativeLabel: nativeCase.labelAssociation.actual,
        browserLabel: browserCase.labelAssociation.actual,
        mismatchKinds: mismatchKinds
      )
    }

    let passed = native.metrics.passed && browser.metrics.passed && parity.allSatisfy { !$0.hasMismatch }

    return DetectorSemanticReport(
      schema: "pdf-editor.detector-semantic-comparison",
      groundTruthCount: groundTruth.cases.count,
      native: native,
      browser: browser,
      parity: parity,
      passed: passed
    )
  }

  // MARK: Markdown Export

  /// Export the report as markdown (content-free: region identities only).
  public func toMarkdown(_ report: DetectorSemanticReport) -> String {
    var md = "# Detector Semantic Comparison Report\n\n"
    md += "**Schema:** \(report.schema)\n"
    md += "**Reviewed regions:** \(report.groundTruthCount)\n"
    md += "**Passed:** \(report.passed)\n\n"

    md += "## Native\n"
    md += "- Precision: \(report.native.metrics.precision.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Recall: \(report.native.metrics.recall.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Abstention: \(report.native.metrics.abstention.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Label association: \(report.native.metrics.labelAssociationPrecision.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Severity burden: \(report.native.metrics.severityBurden)\n\n"

    md += "## Browser\n"
    md += "- Precision: \(report.browser.metrics.precision.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Recall: \(report.browser.metrics.recall.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Abstention: \(report.browser.metrics.abstention.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Label association: \(report.browser.metrics.labelAssociationPrecision.map { String(format: "%.3f", $0) } ?? "n/a")\n"
    md += "- Severity burden: \(report.browser.metrics.severityBurden)\n\n"

    if !report.parity.isEmpty {
      md += "## Native vs Browser Parity\n\n"
      md += "| Region | Fixture | Native | Browser | Mismatches |\n"
      md += "|---|---|---|---|---|\n"
      for entry in report.parity {
        let nativeState = entry.nativeDetected ? "detected" : "abstain"
        let browserState = entry.browserDetected ? "detected" : "abstain"
        md += "| \(entry.reviewedRegionID) | \(entry.fixtureID) | \(nativeState) | \(browserState) | \(entry.mismatchKinds.joined(separator: ", ")) |\n"
      }
    }

    return md
  }
}