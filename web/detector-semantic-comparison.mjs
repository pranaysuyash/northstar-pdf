/**
 * Reviewed detector comparison across native and browser providers.
 *
 * This layer compares provider output to stable, reviewed region labels and
 * then compares the provider results to each other. Provider candidate IDs,
 * labels, prose, scores, timestamps, and raw digests are intentionally not
 * copied into the report.
 */

export const DETECTOR_SEMANTIC_COMPARISON_CONTRACT = Object.freeze({
  name: "pdf-editor.detector-semantic-comparison",
  version: Object.freeze({ major: 1, minor: 0 }),
  matching: Object.freeze({
    minimumIoU: 0.25,
    nearIoU: 0.05,
    geometryTolerancePoints: 0.5,
    strategy: "reviewed-region-first-score-with-one-selected-candidate"
  }),
  falsePositiveSeverityWeights: Object.freeze({ low: 1, medium: 3, high: 9, critical: 27 })
});

const EVIDENCE_FAMILY_BY_KIND = Object.freeze({
  vectorRectangle: "geometry",
  vectorLine: "geometry",
  underline: "geometry",
  checkboxShape: "geometry",
  whitespace: "whitespace",
  textLabel: "label",
  spatialRelationship: "relationship",
  ocrText: "ocr",
  ocrBounds: "ocr",
  nativeField: "nativeField"
});

const ALLOWED_SEVERITIES = new Set(["low", "medium", "high", "critical"]);

function area(rect) {
  return Math.max(0, rect?.width || 0) * Math.max(0, rect?.height || 0);
}

export function rectIoU(left, right) {
  if (!left || !right) return 0;
  const x1 = Math.max(left.x, right.x);
  const y1 = Math.max(left.y, right.y);
  const x2 = Math.min(left.x + left.width, right.x + right.width);
  const y2 = Math.min(left.y + left.height, right.y + right.height);
  const intersection = area({
    x: x1,
    y: y1,
    width: Math.max(0, x2 - x1),
    height: Math.max(0, y2 - y1)
  });
  return intersection / Math.max(1, area(left) + area(right) - intersection);
}

function ratio(numerator, denominator) {
  return denominator === 0 ? null : numerator / denominator;
}

function rounded(value, places = 4) {
  if (!Number.isFinite(value)) return value;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function evidenceItems(candidate) {
  return candidate?.evidenceItems || [];
}

export function evidenceFamilies(candidate) {
  return [...new Set(evidenceItems(candidate)
    .map((item) => EVIDENCE_FAMILY_BY_KIND[item.kind] || item.kind)
    .filter(Boolean))].sort();
}

function normalizedCandidate(candidate, index) {
  return {
    index,
    pageIndex: candidate?.pageIndex ?? null,
    bounds: candidate?.bounds || null,
    kind: candidate?.kind || null,
    suggestedFieldType: candidate?.suggestedFieldType || null,
    entryMode: candidate?.entryMode || "unknown",
    groupMemberCount: Number.isInteger(candidate?.groupMemberCount) ? candidate.groupMemberCount : 1,
    status: candidate?.status || "unknown",
    evidenceFamilies: evidenceFamilies(candidate),
    labelAssociated: Boolean(candidate?.labelText)
      || evidenceFamilies(candidate).includes("label")
      || evidenceFamilies(candidate).includes("relationship"),
    fusionState: candidate?.fusion?.state || null
  };
}

function requiredEvidenceFamilies(caseLabel) {
  return [...new Set((caseLabel.expectedEvidenceFamilies || caseLabel.requiredEvidence || [])
    .map((kind) => EVIDENCE_FAMILY_BY_KIND[kind] || kind)
    .filter(Boolean))].sort();
}

function minimumEvidenceFamilies(caseLabel) {
  return [...new Set((caseLabel.requiredEvidence || caseLabel.expectedEvidenceFamilies || [])
    .map((kind) => EVIDENCE_FAMILY_BY_KIND[kind] || kind)
    .filter(Boolean))].sort();
}

function expectedLabelAssociation(caseLabel) {
  if (caseLabel.expectedLabelAssociation) return caseLabel.expectedLabelAssociation;
  return caseLabel.hardNegative ? "none" : "associated";
}

function expectedGrouping(caseLabel) {
  return caseLabel.expectedGrouping || {
    state: "single",
    memberCount: 1
  };
}

function falsePositiveSeverity(caseLabel) {
  const severity = caseLabel.falsePositiveSeverity || (caseLabel.hardNegative ? "medium" : null);
  if (severity && !ALLOWED_SEVERITIES.has(severity)) throw new Error(`unsupported false-positive severity: ${severity}`);
  return severity;
}

function candidateMatchesReview(caseLabel, candidate) {
  if (!candidate || candidate.pageIndex !== caseLabel.pageIndex) return false;
  if (rectIoU(caseLabel.target, candidate.bounds) < DETECTOR_SEMANTIC_COMPARISON_CONTRACT.matching.minimumIoU) return false;
  const requiredEvidence = minimumEvidenceFamilies(caseLabel);
  if (!requiredEvidence.every((family) => candidate.evidenceFamilies.includes(family))) return false;
  if (caseLabel.requiredCandidateKind && candidate.kind !== caseLabel.requiredCandidateKind) return false;
  if (caseLabel.requiredFieldType && candidate.suggestedFieldType !== caseLabel.requiredFieldType) return false;
  return true;
}

function candidateScore(caseLabel, candidate) {
  const requiredEvidence = requiredEvidenceFamilies(caseLabel);
  const evidenceCoverage = requiredEvidence.length === 0
    ? 1
    : requiredEvidence.filter((family) => candidate.evidenceFamilies.includes(family)).length / requiredEvidence.length;
  const kindAgreement = caseLabel.requiredCandidateKind
    ? candidate.kind === caseLabel.requiredCandidateKind ? 1 : 0
    : 1;
  const fieldTypeAgreement = caseLabel.requiredFieldType
    ? candidate.suggestedFieldType === caseLabel.requiredFieldType ? 1 : 0
    : 1;
  return rectIoU(caseLabel.target, candidate.bounds) * 0.7
    + evidenceCoverage * 0.15
    + kindAgreement * 0.1
    + fieldTypeAgreement * 0.05;
}

function selectCandidate(caseLabel, candidates) {
  const normalized = candidates.map(normalizedCandidate);
  const matching = normalized
    .filter((candidate) => candidateMatchesReview(caseLabel, candidate))
    .sort((left, right) => candidateScore(caseLabel, right) - candidateScore(caseLabel, left));
  const near = normalized.filter((candidate) => (
    candidate.pageIndex === caseLabel.pageIndex
      && rectIoU(caseLabel.target, candidate.bounds) >= DETECTOR_SEMANTIC_COMPARISON_CONTRACT.matching.nearIoU
  ));
  return {
    selected: matching[0] || null,
    matching,
    near
  };
}

function setAgreement(expected, actual) {
  const expectedSet = new Set(expected);
  const actualSet = new Set(actual);
  const intersection = [...expectedSet].filter((value) => actualSet.has(value));
  return {
    expected: [...expectedSet].sort(),
    actual: [...actualSet].sort(),
    intersection: intersection.sort(),
    missing: [...expectedSet].filter((value) => !actualSet.has(value)).sort(),
    unexpected: [...actualSet].filter((value) => !expectedSet.has(value)).sort(),
    exact: intersection.length === expectedSet.size && intersection.length === actualSet.size,
    recall: ratio(intersection.length, expectedSet.size),
    precision: ratio(intersection.length, actualSet.size)
  };
}

function groupingComparison(caseLabel, candidate) {
  const expected = expectedGrouping(caseLabel);
  if (!candidate) {
    return {
      expected,
      actual: null,
      state: expected.state === "abstain" ? "agree" : "unknown"
    };
  }
  const actual = {
    state: candidate.groupMemberCount > 1 ? "grouped" : "single",
    memberCount: candidate.groupMemberCount
  };
  return {
    expected,
    actual,
    state: expected.state === actual.state
      && (expected.memberCount === undefined || expected.memberCount === actual.memberCount)
      ? "agree"
      : "mismatch"
  };
}

function labelComparison(caseLabel, candidate) {
  const expected = expectedLabelAssociation(caseLabel);
  if (!candidate) {
    return { expected, actual: null, state: expected === "none" ? "agree" : "unknown" };
  }
  const actual = candidate.labelAssociated ? "associated" : "none";
  return { expected, actual, state: expected === actual ? "agree" : "mismatch" };
}

function severityWeight(severity) {
  return severity ? DETECTOR_SEMANTIC_COMPARISON_CONTRACT.falsePositiveSeverityWeights[severity] : 0;
}

function evaluateAdapter(labels, candidates) {
  const cases = labels.cases.map((caseLabel) => {
    const selection = selectCandidate(caseLabel, candidates || []);
    const detected = Boolean(selection.selected);
    const expectedDetected = caseLabel.expected === "detected";
    const correctState = expectedDetected === detected;
    const selected = selection.selected;
    const evidence = selected
      ? setAgreement(requiredEvidenceFamilies(caseLabel), selected.evidenceFamilies)
      : setAgreement(requiredEvidenceFamilies(caseLabel), []);
    const label = labelComparison(caseLabel, selected);
    const grouping = groupingComparison(caseLabel, selected);
    const severity = falsePositiveSeverity(caseLabel);
    return {
      reviewedRegionID: caseLabel.reviewedRegionID || `reviewed:${caseLabel.id}`,
      caseID: caseLabel.id,
      class: caseLabel.class,
      expected: caseLabel.expected,
      hardNegative: Boolean(caseLabel.hardNegative),
      falsePositiveSeverity: severity,
      detected,
      state: correctState ? "pass" : "mismatch",
      selectedCandidateIndex: selected?.index ?? null,
      nearCandidateCount: selection.near.length,
      evidenceFamilyAgreement: evidence,
      labelAssociation: label,
      grouping,
      candidateIdentity: selected ? {
        pageIndex: selected.pageIndex,
        bounds: selected.bounds,
        kind: selected.kind,
        suggestedFieldType: selected.suggestedFieldType,
        entryMode: selected.entryMode,
        groupMemberCount: selected.groupMemberCount
      } : null
    };
  });

  const positive = cases.filter((entry) => !entry.hardNegative);
  const negative = cases.filter((entry) => entry.hardNegative);
  const truePositive = positive.filter((entry) => entry.detected).length;
  const falseNegative = positive.length - truePositive;
  const falsePositive = negative.filter((entry) => entry.detected).length;
  const trueNegative = negative.length - falsePositive;
  const evidenceRows = cases.filter((entry) => entry.detected);
  const exactEvidence = evidenceRows.filter((entry) => entry.evidenceFamilyAgreement.exact).length;
  const associatedExpected = cases.filter((entry) => entry.labelAssociation.expected === "associated");
  const associatedObserved = associatedExpected.filter((entry) => entry.labelAssociation.actual === "associated").length;
  const groupingRows = cases.filter((entry) => entry.grouping.actual);
  const groupingAgreement = groupingRows.filter((entry) => entry.grouping.state === "agree").length;
  const severityCounts = {};
  let severityBurden = 0;
  for (const entry of negative.filter((candidate) => candidate.detected)) {
    severityCounts[entry.falsePositiveSeverity] = (severityCounts[entry.falsePositiveSeverity] || 0) + 1;
    severityBurden += severityWeight(entry.falsePositiveSeverity);
  }
  const failureClusters = {};
  const addFailure = (cluster, entry) => {
    const current = failureClusters[cluster] || { count: 0, caseIDs: [] };
    current.count += 1;
    current.caseIDs.push(entry.caseID);
    failureClusters[cluster] = current;
  };
  for (const entry of cases) {
    if (entry.state !== "pass") addFailure(entry.hardNegative ? "falsePositive" : "reviewedRegionMiss", entry);
    if (entry.detected && !entry.evidenceFamilyAgreement.exact) addFailure("evidenceFamilyMismatch", entry);
    if (entry.labelAssociation.state === "mismatch") addFailure("labelAssociationMismatch", entry);
    if (entry.grouping.state === "mismatch") addFailure("groupingMismatch", entry);
  }
  const metrics = {
    reviewedRegionCount: cases.length,
    positiveRegionCount: positive.length,
    hardNegativeRegionCount: negative.length,
    truePositive,
    falseNegative,
    falsePositive,
    trueNegative,
    precision: ratio(truePositive, truePositive + falsePositive),
    recall: ratio(truePositive, positive.length),
    falsePositiveRate: ratio(falsePositive, negative.length),
    correctAbstentionRate: ratio(trueNegative, negative.length),
    positiveAbstentionRate: ratio(falseNegative, positive.length),
    evidenceFamilyExactRate: ratio(exactEvidence, evidenceRows.length),
    labelAssociationPrecision: ratio(associatedObserved, associatedExpected.length),
    groupingAgreementRate: ratio(groupingAgreement, groupingRows.length),
    falsePositiveSeverityCounts: severityCounts,
    falsePositiveSeverityBurden: severityBurden
  };
  return {
    cases,
    metrics,
    failureClusters,
    passed: metrics.recall === 1
      && metrics.falsePositiveRate === 0
      && (metrics.evidenceFamilyExactRate ?? 1) === 1
      && (metrics.labelAssociationPrecision ?? 1) === 1
      && (metrics.groupingAgreementRate ?? 1) === 1
      && severityBurden === 0
  };
}

function compareAdapters(native, browser) {
  const cases = native.cases.map((nativeCase) => {
    const browserCase = browser.cases.find((entry) => entry.reviewedRegionID === nativeCase.reviewedRegionID);
    const mismatchKinds = [];
    if (!browserCase) mismatchKinds.push("missingReviewedRegion");
    else {
      if (nativeCase.detected !== browserCase.detected) mismatchKinds.push("detectionState");
      if (JSON.stringify(nativeCase.evidenceFamilyAgreement.actual) !== JSON.stringify(browserCase.evidenceFamilyAgreement.actual)) mismatchKinds.push("evidenceFamilies");
      if (nativeCase.labelAssociation.actual !== browserCase.labelAssociation.actual) mismatchKinds.push("labelAssociation");
      if (nativeCase.grouping.actual?.state !== browserCase.grouping.actual?.state
        || nativeCase.grouping.actual?.memberCount !== browserCase.grouping.actual?.memberCount) mismatchKinds.push("grouping");
      if (nativeCase.candidateIdentity?.kind !== browserCase.candidateIdentity?.kind) mismatchKinds.push("candidateKind");
    }
    return {
      reviewedRegionID: nativeCase.reviewedRegionID,
      state: mismatchKinds.length === 0 ? "pass" : "mismatch",
      mismatchKinds
    };
  });
  const mismatchCounts = {};
  for (const entry of cases) for (const kind of entry.mismatchKinds) mismatchCounts[kind] = (mismatchCounts[kind] || 0) + 1;
  return {
    cases,
    mismatchCounts,
    mismatchCount: cases.filter((entry) => entry.state !== "pass").length,
    passed: cases.every((entry) => entry.state === "pass")
  };
}

export function buildDetectorSemanticComparisonReport({ labels, sourceDigest, nativeCandidates, browserCandidates }) {
  if (!labels?.cases || !Array.isArray(labels.cases)) throw new Error("reviewed detector labels are required");
  const native = evaluateAdapter(labels, nativeCandidates);
  const browser = evaluateAdapter(labels, browserCandidates);
  const parity = compareAdapters(native, browser);
  const caseIDs = labels.cases.map((entry) => entry.reviewedRegionID || `reviewed:${entry.id}`);
  if (new Set(caseIDs).size !== caseIDs.length) throw new Error("reviewed region IDs must be unique");
  return {
    schema: DETECTOR_SEMANTIC_COMPARISON_CONTRACT.name,
    version: DETECTOR_SEMANTIC_COMPARISON_CONTRACT.version,
    sourceDigest,
    fixture: labels.fixture,
    reviewedRegionCount: labels.cases.length,
    policy: {
      matching: DETECTOR_SEMANTIC_COMPARISON_CONTRACT.matching,
      falsePositiveSeverityWeights: DETECTOR_SEMANTIC_COMPARISON_CONTRACT.falsePositiveSeverityWeights,
      reviewRequired: labels.policy?.reviewRequired !== false,
      noSilentAutofill: true,
      rawContentRetention: "none"
    },
    adapters: { native, browser },
    semanticParity: parity,
    passed: native.passed && browser.passed && parity.passed
  };
}

export function mutateDetectorComparisonReport(report, mutation) {
  const copy = structuredClone(report);
  if (mutation === "remove-reviewed-region") {
    copy.adapters.browser.cases = copy.adapters.browser.cases.slice(1);
  } else if (mutation === "promote-high-severity-negative") {
    const target = copy.adapters.browser.cases.find((entry) => entry.hardNegative && entry.falsePositiveSeverity === "high");
    if (target) target.detected = true;
  } else if (mutation === "strip-evidence-family") {
    const target = copy.adapters.browser.cases.find((entry) => entry.detected);
    if (target) {
      target.evidenceFamilyAgreement.exact = false;
      target.evidenceFamilyAgreement.missing = ["geometry"];
    }
  } else if (mutation === "break-label-association") {
    const target = copy.adapters.browser.cases.find((entry) => entry.labelAssociation.expected === "associated");
    if (target) target.labelAssociation.state = "mismatch";
  } else if (mutation === "split-group") {
    const target = copy.adapters.browser.cases.find((entry) => entry.grouping.actual);
    if (target) target.grouping.state = "mismatch";
  } else {
    throw new Error(`unknown detector comparison mutation: ${mutation}`);
  }
  return copy;
}
