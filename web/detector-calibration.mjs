export const DETECTOR_CALIBRATION_SCHEMA = "pdf-editor.detector-calibration-report";
export const DETECTOR_CALIBRATION_VERSION = Object.freeze({ major: 1, minor: 1 });

function area(rect) {
  return Math.max(0, rect?.width || 0) * Math.max(0, rect?.height || 0);
}

export function rectIoU(left, right) {
  if (!left || !right) return 0;
  const x1 = Math.max(left.x, right.x);
  const y1 = Math.max(left.y, right.y);
  const x2 = Math.min(left.x + left.width, right.x + right.width);
  const y2 = Math.min(left.y + left.height, right.y + right.height);
  const intersection = area({ x: x1, y: y1, width: Math.max(0, x2 - x1), height: Math.max(0, y2 - y1) });
  return intersection / Math.max(1, area(left) + area(right) - intersection);
}

function evidenceKinds(candidate) {
  return new Set((candidate?.evidenceItems || []).map((item) => item.kind === "vectorLine" ? "underline" : item.kind));
}

function matchesCase(caseLabel, candidate) {
  if (!candidate || candidate.pageIndex !== caseLabel.pageIndex) return false;
  const kinds = evidenceKinds(candidate);
  if (!caseLabel.requiredEvidence.every((kind) => kinds.has(kind))) return false;
  if (caseLabel.requiredCandidateKind && candidate.kind !== caseLabel.requiredCandidateKind) return false;
  if (caseLabel.requiredFieldType && candidate.suggestedFieldType !== caseLabel.requiredFieldType) return false;
  return rectIoU(caseLabel.target, candidate.bounds) >= 0.25;
}

function candidateDiagnostics(caseLabel, candidates) {
  const pageCandidates = (candidates || []).filter((candidate) => candidate?.pageIndex === caseLabel.pageIndex);
  const nearCandidates = pageCandidates.filter((candidate) => rectIoU(caseLabel.target, candidate.bounds) >= 0.05);
  const evidenceCandidates = nearCandidates.filter((candidate) => {
    const kinds = evidenceKinds(candidate);
    return caseLabel.requiredEvidence.every((kind) => kinds.has(kind));
  });
  const kindCandidates = evidenceCandidates.filter((candidate) => (
    !caseLabel.requiredCandidateKind || candidate.kind === caseLabel.requiredCandidateKind
  ));
  const fieldTypeCandidates = kindCandidates.filter((candidate) => (
    !caseLabel.requiredFieldType || candidate.suggestedFieldType === caseLabel.requiredFieldType
  ));
  return {
    nearCandidates,
    evidenceCandidates,
    kindCandidates,
    fieldTypeCandidates
  };
}

export function evaluateCalibrationCases(labels, candidates) {
  return labels.cases.map((caseLabel) => {
    const matchingCandidates = (candidates || []).filter((candidate) => matchesCase(caseLabel, candidate));
    const diagnostics = candidateDiagnostics(caseLabel, candidates);
    const detected = matchingCandidates.length > 0;
    return {
      id: caseLabel.id,
      pageIndex: caseLabel.pageIndex,
      class: caseLabel.class,
      expected: caseLabel.expected,
      hardNegative: caseLabel.hardNegative,
      detected,
      candidateCount: matchingCandidates.length,
      nearCandidateCount: diagnostics.nearCandidates.length,
      scores: matchingCandidates.map((candidate) => candidate.score).filter((score) => Number.isFinite(score)).sort((a, b) => b - a),
      state: caseLabel.expected === (detected ? "detected" : "abstain") ? "pass" : "mismatch"
    };
  });
}

function ratio(numerator, denominator) {
  return denominator === 0 ? null : numerator / denominator;
}

function summarizeClass(caseLabels, evaluations) {
  const classes = [...new Set(caseLabels.map((entry) => entry.class))].sort();
  return Object.fromEntries(classes.map((className) => {
    const rows = evaluations.filter((entry) => entry.class === className);
    const positive = rows.filter((entry) => !entry.hardNegative);
    const negative = rows.filter((entry) => entry.hardNegative);
    const truePositive = positive.filter((entry) => entry.detected).length;
    const falseNegative = positive.length - truePositive;
    const falsePositive = negative.filter((entry) => entry.detected).length;
    const trueNegative = negative.length - falsePositive;
    const positiveScores = positive.flatMap((entry) => entry.scores);
    const negativeScores = negative.flatMap((entry) => entry.scores);
    const recall = ratio(truePositive, positive.length);
    const precision = ratio(truePositive, truePositive + falsePositive);
    const falsePositiveRate = ratio(falsePositive, negative.length);
    const abstentionRate = ratio(trueNegative, negative.length);
    const minimumPositiveScore = positiveScores.length ? Math.min(...positiveScores) : null;
    const maximumHardNegativeScore = negativeScores.length ? Math.max(...negativeScores) : null;
    return [className, {
      cases: rows.length,
      truePositive,
      falseNegative,
      falsePositive,
      trueNegative,
      recall,
      precision,
      falsePositiveRate,
      abstentionRate,
      threshold: {
        minimumAcceptedSuggestionScore: minimumPositiveScore,
        maximumObservedHardNegativeScore: maximumHardNegativeScore,
        calibration: "reviewed-positive-lower-bound-plus-zero-hard-negative-gate"
      },
      passed: (recall ?? 1) >= 1 && (falsePositiveRate ?? 0) <= 0
    }];
  }));
}

function summarizeOverall(caseLabels, evaluations) {
  const positive = evaluations.filter((entry) => !entry.hardNegative);
  const negative = evaluations.filter((entry) => entry.hardNegative);
  const truePositive = positive.filter((entry) => entry.detected).length;
  const falseNegative = positive.length - truePositive;
  const falsePositive = negative.filter((entry) => entry.detected).length;
  const trueNegative = negative.length - falsePositive;
  const recall = ratio(truePositive, positive.length);
  const precision = ratio(truePositive, truePositive + falsePositive);
  const falsePositiveRate = ratio(falsePositive, negative.length);
  const abstentionRate = ratio(trueNegative, negative.length);
  return {
    cases: caseLabels.length,
    positiveCases: positive.length,
    hardNegativeCases: negative.length,
    truePositive,
    falseNegative,
    falsePositive,
    trueNegative,
    recall,
    precision,
    falsePositiveRate,
    abstentionRate,
    passed: (recall ?? 1) >= 1 && (falsePositiveRate ?? 0) <= 0
  };
}

function failureClusterFor(caseLabel, evaluation, candidates) {
  if (evaluation.state === "pass") return null;
  if (caseLabel.hardNegative && evaluation.detected) {
    return {
      cluster: "hardNegativePromotion",
      code: "hard_negative_promoted"
    };
  }

  const diagnostics = candidateDiagnostics(caseLabel, candidates);
  if (diagnostics.nearCandidates.length === 0) {
    return {
      cluster: "noCandidateNearTarget",
      code: "positive_miss_no_near_candidate"
    };
  }
  if (diagnostics.evidenceCandidates.length === 0) {
    return {
      cluster: "evidenceMismatch",
      code: "positive_miss_required_evidence"
    };
  }
  if (diagnostics.kindCandidates.length === 0) {
    return {
      cluster: "candidateKindMismatch",
      code: "positive_miss_candidate_kind"
    };
  }
  if (diagnostics.fieldTypeCandidates.length === 0) {
    return {
      cluster: "fieldTypeMismatch",
      code: "positive_miss_field_type"
    };
  }
  return {
    cluster: "geometryMismatch",
    code: "positive_miss_iou_threshold"
  };
}

export function summarizeFailureClusters(labels, evaluations, candidates) {
  const failures = evaluations.flatMap((evaluation) => {
    const caseLabel = labels.cases.find((entry) => entry.id === evaluation.id);
    const classification = failureClusterFor(caseLabel, evaluation, candidates);
    if (!classification) return [];
    return [{
      id: evaluation.id,
      class: evaluation.class,
      hardNegative: evaluation.hardNegative,
      expected: evaluation.expected,
      detected: evaluation.detected,
      cluster: classification.cluster,
      code: classification.code,
      nearCandidateCount: evaluation.nearCandidateCount,
      candidateCount: evaluation.candidateCount
    }];
  });
  const byCluster = {};
  for (const failure of failures) {
    const current = byCluster[failure.cluster] || { count: 0, caseIds: [] };
    current.count += 1;
    current.caseIds.push(failure.id);
    byCluster[failure.cluster] = current;
  }
  return {
    failureCount: failures.length,
    byCluster,
    cases: failures,
    passed: failures.length === 0
  };
}

export function buildCalibrationReport({ labels, sourceDigest, nativeCandidates, browserCandidates, generatedAt }) {
  const nativeCases = evaluateCalibrationCases(labels, nativeCandidates);
  const browserCases = evaluateCalibrationCases(labels, browserCandidates);
  const parityCases = nativeCases.map((nativeCase, index) => {
    const browserCase = browserCases[index];
    return {
      id: nativeCase.id,
      class: nativeCase.class,
      native: nativeCase.state,
      browser: browserCase.state,
      state: nativeCase.state === browserCase.state ? "pass" : "mismatch"
    };
  });
  const nativeMetrics = {
    overall: summarizeOverall(labels.cases, nativeCases),
    byClass: summarizeClass(labels.cases, nativeCases)
  };
  const browserMetrics = {
    overall: summarizeOverall(labels.cases, browserCases),
    byClass: summarizeClass(labels.cases, browserCases)
  };
  const nativeFailures = summarizeFailureClusters(labels, nativeCases, nativeCandidates);
  const browserFailures = summarizeFailureClusters(labels, browserCases, browserCandidates);
  return {
    schema: DETECTOR_CALIBRATION_SCHEMA,
    version: DETECTOR_CALIBRATION_VERSION,
    generatedAt,
    fixture: labels.fixture,
    sourceSha256: sourceDigest,
    policy: labels.policy,
    adapters: {
      native: { cases: nativeCases, metrics: nativeMetrics, failureClusters: nativeFailures, passed: nativeMetrics.overall.passed && nativeFailures.passed },
      browser: { cases: browserCases, metrics: browserMetrics, failureClusters: browserFailures, passed: browserMetrics.overall.passed && browserFailures.passed }
    },
    semanticParity: {
      cases: parityCases,
      mismatches: parityCases.filter((entry) => entry.state !== "pass").map((entry) => entry.id),
      passed: parityCases.every((entry) => entry.state === "pass")
    },
    passed: nativeMetrics.overall.passed
      && browserMetrics.overall.passed
      && nativeFailures.passed
      && browserFailures.passed
      && parityCases.every((entry) => entry.state === "pass")
  };
}
