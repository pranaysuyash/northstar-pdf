import { validateTemplateContract } from "./pdf-template-contract.mjs";

export const TEMPLATE_MATCH_BENCHMARK_VERSION = { major: 1, minor: 0 };

export const DEFAULT_TEMPLATE_MATCH_POLICY = Object.freeze({
  familyThreshold: 0.76,
  ambiguityMargin: 0.05,
  geometryWeight: 0.20,
  nativeFieldWeight: 0.25,
  anchorWeight: 0.25,
  regionWeight: 0.30
});

function clamp(value) {
  return Math.max(0, Math.min(1, value));
}

function normalizedFingerprint(candidate) {
  const fingerprint = candidate?.payload?.fingerprint || candidate?.fingerprint || candidate;
  if (!fingerprint || typeof fingerprint !== "object") {
    throw new Error("A template fingerprint is required for benchmark matching.");
  }
  if (!Array.isArray(fingerprint.pageSignatures)) {
    throw new Error("A template fingerprint must contain page signatures.");
  }
  return fingerprint;
}

function templateID(candidate, fallback = null) {
  return candidate?.payload?.templateID || candidate?.templateID || fallback;
}

function sequenceSimilarity(left = [], right = [], key = (value) => value) {
  const a = left.map(key);
  const b = right.map(key);
  if (!a.length && !b.length) return 1;
  if (!a.length || !b.length) return 0;
  const table = Array.from({ length: a.length + 1 }, () => Array(b.length + 1).fill(0));
  for (let row = 1; row <= a.length; row += 1) {
    for (let column = 1; column <= b.length; column += 1) {
      table[row][column] = a[row - 1] === b[column - 1]
        ? table[row - 1][column - 1] + 1
        : Math.max(table[row - 1][column], table[row][column - 1]);
    }
  }
  return (2 * table[a.length][b.length]) / (a.length + b.length);
}

function pageGeometrySimilarity(left = [], right = []) {
  if (left.length !== right.length) return 0;
  if (!left.length && !right.length) return 1;
  return left.reduce((sum, page, index) => {
    const other = right[index];
    const widthDelta = Math.abs(page.widthPoints - other.widthPoints) / Math.max(page.widthPoints, other.widthPoints, 1);
    const heightDelta = Math.abs(page.heightPoints - other.heightPoints) / Math.max(page.heightPoints, other.heightPoints, 1);
    const rotation = page.rotationDegrees === other.rotationDegrees ? 0 : 1;
    return sum + clamp(1 - widthDelta - heightDelta - rotation);
  }, 0) / left.length;
}

function setSimilarity(left = [], right = [], key = (value) => value) {
  const a = new Set(left.map(key));
  const b = new Set(right.map(key));
  if (!a.size && !b.size) return 1;
  if (!a.size || !b.size) return 0;
  const intersection = [...a].filter((value) => b.has(value)).length;
  return intersection / new Set([...a, ...b]).size;
}

function regionSimilarity(left = [], right = []) {
  if (left.length !== right.length) {
    return clamp(1 - Math.abs(left.length - right.length) / Math.max(left.length, right.length, 1));
  }
  if (!left.length && !right.length) return 1;
  return left.reduce((sum, region, index) => {
    const other = right[index];
    const rect = region.normalizedRect || {};
    const otherRect = other.normalizedRect || {};
    const geometryDelta = ["x", "y", "width", "height"].reduce(
      (total, key) => total + Math.abs(Number(rect[key] || 0) - Number(otherRect[key] || 0)),
      0
    );
    const kind = region.kind === other.kind ? 1 : 0;
    const fieldType = (region.suggestedFieldType || null) === (other.suggestedFieldType || null) ? 1 : 0;
    const groupCount = region.groupMemberCount === other.groupMemberCount ? 1 : 0;
    return sum + (kind * 0.35) + (fieldType * 0.25) + (groupCount * 0.10) + (clamp(1 - geometryDelta) * 0.30);
  }, 0) / left.length;
}

function pageFeatureSimilarity(leftPage, rightPage) {
  const nativeFields = sequenceSimilarity(leftPage.nativeFieldKinds, rightPage.nativeFieldKinds);
  const nativeNames = sequenceSimilarity(leftPage.nativeFieldNameTokens, rightPage.nativeFieldNameTokens);
  const anchors = setSimilarity(leftPage.anchorTokens, rightPage.anchorTokens);
  const regions = regionSimilarity(leftPage.regionSignatures, rightPage.regionSignatures);
  return {
    nativeFields: (nativeFields * 0.7) + (nativeNames * 0.3),
    anchors,
    regions
  };
}

export function scoreTemplateFingerprints(leftCandidate, rightCandidate, policy = DEFAULT_TEMPLATE_MATCH_POLICY) {
  const left = normalizedFingerprint(leftCandidate);
  const right = normalizedFingerprint(rightCandidate);
  const pageCount = left.pageSignatures.length === right.pageSignatures.length ? 1 : 0;
  const geometry = pageCount ? pageGeometrySimilarity(left.pageSignatures, right.pageSignatures) : 0;
  const featureScores = left.pageSignatures.reduce((scores, page, index) => {
    const other = right.pageSignatures[index];
    if (!other) return scores;
    const pageScores = pageFeatureSimilarity(page, other);
    scores.nativeFields += pageScores.nativeFields;
    scores.anchors += pageScores.anchors;
    scores.regions += pageScores.regions;
    scores.count += 1;
    return scores;
  }, { nativeFields: 0, anchors: 0, regions: 0, count: 0 });
  const nativeFieldScore = featureScores.count ? featureScores.nativeFields / featureScores.count : 0;
  const anchorScore = featureScores.count ? featureScores.anchors / featureScores.count : 0;
  const regionScore = featureScores.count ? featureScores.regions / featureScores.count : 0;
  const score = clamp(
    (geometry * policy.geometryWeight)
    + (nativeFieldScore * policy.nativeFieldWeight)
    + (anchorScore * policy.anchorWeight)
    + (regionScore * policy.regionWeight)
  );
  return {
    score,
    components: {
      pageCount,
      geometry,
      nativeFields: nativeFieldScore,
      anchors: anchorScore,
      regions: regionScore
    }
  };
}

function candidateState(candidate, fingerprint, sourceDigest, scoreResult, policy) {
  const candidateFingerprint = normalizedFingerprint(candidate);
  const exactSource = (candidateFingerprint.exactSourceDigests || []).includes(sourceDigest);
  if (exactSource) return { state: "exact", score: 1, reason: "Reviewed source digest matched." };
  if (candidateFingerprint.layoutFingerprint === fingerprint.layoutFingerprint) {
    return { state: "knownVariant", score: 0.9, reason: "Reviewed keyed layout matched a different source digest." };
  }
  if (scoreResult.score >= policy.familyThreshold) {
    return { state: "familyMatch", score: scoreResult.score, reason: "Structural family evidence exceeded the reviewed threshold." };
  }
  return { state: "noMatch", score: scoreResult.score, reason: "No reviewed exact, variant, or family threshold was met." };
}

export function classifyTemplateIndex({
  templates,
  fingerprint,
  sourceDigest,
  expectedSourceDigest = null,
  policy = DEFAULT_TEMPLATE_MATCH_POLICY
}) {
  if (expectedSourceDigest && expectedSourceDigest !== sourceDigest) {
    return {
      state: "stale",
      score: 0,
      selectedTemplateID: null,
      candidates: [],
      reasons: ["The current source digest differs from the reviewed session source digest."],
      falsePositiveGate: { passed: true, selected: false }
    };
  }
  const ranked = (templates || []).map((template, index) => {
    if (template?.payload) validateTemplateContract(template);
    const id = templateID(template, `template-${index + 1}`);
    const scoreResult = scoreTemplateFingerprints(template, fingerprint, policy);
    const classification = candidateState(template, fingerprint, sourceDigest, scoreResult, policy);
    return {
      templateID: id,
      state: classification.state,
      score: classification.score,
      reason: classification.reason,
      components: scoreResult.components
    };
  }).sort((left, right) => right.score - left.score || left.templateID.localeCompare(right.templateID));

  const viable = ranked.filter((candidate) => ["exact", "knownVariant", "familyMatch"].includes(candidate.state));
  if (!viable.length) {
    return {
      state: "noMatch",
      score: ranked[0]?.score || 0,
      selectedTemplateID: null,
      candidates: ranked,
      reasons: ["No reviewed template exceeded the matching threshold."],
      falsePositiveGate: { passed: true, selected: false }
    };
  }
  const [best, second] = viable;
  const ambiguous = second && best.state !== "exact"
    && second.state !== "exact"
    && (best.score - second.score) < policy.ambiguityMargin;
  if (ambiguous) {
    return {
      state: "ambiguous",
      score: best.score,
      selectedTemplateID: null,
      candidates: viable,
      reasons: ["Multiple reviewed templates are within the ambiguity margin."],
      falsePositiveGate: { passed: true, selected: false }
    };
  }
  return {
    state: best.state,
    score: best.score,
    selectedTemplateID: best.templateID,
    candidates: ranked,
    reasons: [best.reason],
    falsePositiveGate: { passed: true, selected: true }
  };
}

export function runReviewedTemplateBenchmark(fixtures, policy = DEFAULT_TEMPLATE_MATCH_POLICY) {
  const cases = fixtures.map((fixture) => {
    const actual = classifyTemplateIndex({ ...fixture.input, policy });
    const expected = fixture.expected;
    const statePassed = actual.state === expected.state;
    const selectedPassed = expected.selectedTemplateID === undefined
      ? true
      : actual.selectedTemplateID === expected.selectedTemplateID;
    const forbiddenPassed = !(expected.forbiddenStates || []).includes(actual.state);
    const noSelectionPassed = expected.mustNotSelect !== true || actual.selectedTemplateID === null;
    return {
      id: fixture.id,
      label: fixture.label,
      expectedState: expected.state,
      actualState: actual.state,
      expectedSelectedTemplateID: expected.selectedTemplateID ?? null,
      actualSelectedTemplateID: actual.selectedTemplateID,
      score: actual.score,
      statePassed,
      selectedPassed,
      forbiddenPassed,
      noSelectionPassed,
      passed: statePassed && selectedPassed && forbiddenPassed && noSelectionPassed,
      actual
    };
  });
  const failures = cases.filter((fixture) => !fixture.passed);
  const counts = cases.reduce((result, fixture) => {
    result[fixture.expectedState] = (result[fixture.expectedState] || 0) + 1;
    return result;
  }, {});
  return {
    benchmarkVersion: { ...TEMPLATE_MATCH_BENCHMARK_VERSION },
    policy: { ...policy },
    fixtureCount: cases.length,
    passed: failures.length === 0,
    failures: failures.map(({ actual, ...fixture }) => fixture),
    counts,
    cases
  };
}
