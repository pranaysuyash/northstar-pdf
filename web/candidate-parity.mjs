/**
 * Native/browser semantic candidate parity projection.
 *
 * This is deliberately separate from whole-document parity. Candidate
 * providers may group, split, or classify the same visual region differently,
 * so the report measures directional coverage and semantic agreement rather
 * than treating either provider as ground truth.
 */

export const CANDIDATE_PARITY_CONTRACT = Object.freeze({
  name: "pdf-editor.native-web-candidate-parity",
  version: Object.freeze({ major: 1, minor: 0 }),
  matching: Object.freeze({
    minimumIoU: 0.8,
    geometryTolerancePoints: 0.5,
    matching: "greedy-highest-compatibility-one-to-one"
  }),
  ignoredRepresentationFields: Object.freeze([
    "candidate.id",
    "candidate.labelText",
    "candidate.evidence[].text",
    "candidate.evidence[].summary",
    "candidate.score",
    "candidate.fusion.evidenceIDs",
    "provider.id",
    "provider.version",
    "generatedAt",
    "outputDigest"
  ])
});

function round(value, places = 2) {
  if (typeof value !== "number" || !Number.isFinite(value)) return value;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function rectProjection(rect) {
  if (!rect) return null;
  return {
    x: round(rect.x),
    y: round(rect.y),
    width: round(rect.width),
    height: round(rect.height)
  };
}

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

function evidenceItems(candidate) {
  return candidate?.evidenceItems || [];
}

function evidenceKinds(candidate) {
  return [...new Set(evidenceItems(candidate).map((item) => item.kind).filter(Boolean))].sort();
}

function evidenceOrigins(candidate) {
  return [...new Set(evidenceItems(candidate).map((item) => item.origin).filter(Boolean))].sort();
}

function coordinateProjection(candidate) {
  const space = candidate?.coordinate?.coordinateSpace || {};
  return {
    unit: space.unit || null,
    origin: space.origin || null,
    pageBox: space.pageBox || null,
    rotationDegrees: space.rotationDegrees ?? null
  };
}

function candidateProjection(candidate) {
  return {
    pageIndex: candidate?.pageIndex ?? null,
    bounds: rectProjection(candidate?.bounds),
    kind: candidate?.kind || null,
    suggestedFieldType: candidate?.suggestedFieldType || null,
    entryMode: candidate?.entryMode || "unknown",
    groupMemberCount: candidate?.groupMemberCount || 1,
    status: candidate?.status || "unknown",
    evidenceKinds: evidenceKinds(candidate),
    evidenceOrigins: evidenceOrigins(candidate),
    labelPresent: Boolean(candidate?.labelText),
    coordinateSpace: coordinateProjection(candidate),
    fusionState: candidate?.fusion?.state || null
  };
}

export function extractCandidates(bundle) {
  return bundle?.document?.payload?.candidates || bundle?.candidates || [];
}

export function normalizeCandidate(candidate) {
  return candidateProjection(candidate);
}

function sortedSet(values) {
  return [...new Set(values)].sort();
}

function sameSet(left, right) {
  return JSON.stringify(sortedSet(left)) === JSON.stringify(sortedSet(right));
}

function sameNumber(left, right, tolerance) {
  if (left === right) return true;
  if (!Number.isFinite(left) || !Number.isFinite(right)) return false;
  return Math.abs(left - right) <= tolerance;
}

function sameBounds(left, right, tolerance) {
  if (!left || !right) return left === right;
  return ["x", "y", "width", "height"].every((key) => sameNumber(left[key], right[key], tolerance));
}

function sameCoordinateSpace(left, right) {
  return ["unit", "origin", "pageBox", "rotationDegrees"].every((key) => left[key] === right[key]);
}

function mismatchKinds(nativeCandidate, browserCandidate, matching) {
  const mismatches = [];
  if (!sameBounds(nativeCandidate.bounds, browserCandidate.bounds, CANDIDATE_PARITY_CONTRACT.matching.geometryTolerancePoints)) {
    mismatches.push("geometryPrecision");
  }
  if (nativeCandidate.kind !== browserCandidate.kind) mismatches.push("candidateKind");
  if (nativeCandidate.suggestedFieldType !== browserCandidate.suggestedFieldType) mismatches.push("fieldType");
  if (nativeCandidate.entryMode !== browserCandidate.entryMode) mismatches.push("entryMode");
  if (!sameSet(nativeCandidate.evidenceKinds, browserCandidate.evidenceKinds)) mismatches.push("evidenceKinds");
  if (!sameSet(nativeCandidate.evidenceOrigins, browserCandidate.evidenceOrigins)) mismatches.push("evidenceOrigins");
  if (nativeCandidate.labelPresent !== browserCandidate.labelPresent) mismatches.push("labelPresence");
  if (!sameCoordinateSpace(nativeCandidate.coordinateSpace, browserCandidate.coordinateSpace)) mismatches.push("coordinateSpace");
  if (nativeCandidate.status !== browserCandidate.status) mismatches.push("reviewState");
  if (nativeCandidate.fusionState !== browserCandidate.fusionState) mismatches.push("fusionState");
  if (nativeCandidate.groupMemberCount !== browserCandidate.groupMemberCount) mismatches.push("grouping");
  return mismatches;
}

function pairScore(nativeCandidate, browserCandidate, iou) {
  let score = iou;
  if (nativeCandidate.kind === browserCandidate.kind) score += 0.08;
  if (nativeCandidate.suggestedFieldType === browserCandidate.suggestedFieldType) score += 0.06;
  if (nativeCandidate.entryMode === browserCandidate.entryMode) score += 0.04;
  if (sameSet(nativeCandidate.evidenceKinds, browserCandidate.evidenceKinds)) score += 0.03;
  if (nativeCandidate.labelPresent === browserCandidate.labelPresent) score += 0.01;
  return score;
}

function pairCandidates(nativeCandidates, browserCandidates) {
  const possiblePairs = [];
  for (let nativeIndex = 0; nativeIndex < nativeCandidates.length; nativeIndex += 1) {
    for (let browserIndex = 0; browserIndex < browserCandidates.length; browserIndex += 1) {
      const nativeCandidate = nativeCandidates[nativeIndex];
      const browserCandidate = browserCandidates[browserIndex];
      if (nativeCandidate.pageIndex !== browserCandidate.pageIndex) continue;
      const iou = rectIoU(nativeCandidate.bounds, browserCandidate.bounds);
      if (iou < CANDIDATE_PARITY_CONTRACT.matching.minimumIoU) continue;
      possiblePairs.push({
        nativeIndex,
        browserIndex,
        iou,
        score: pairScore(nativeCandidate, browserCandidate, iou)
      });
    }
  }
  possiblePairs.sort((left, right) => (
    right.score - left.score
      || right.iou - left.iou
      || left.nativeIndex - right.nativeIndex
      || left.browserIndex - right.browserIndex
  ));
  const usedNative = new Set();
  const usedBrowser = new Set();
  return possiblePairs.filter((pair) => {
    if (usedNative.has(pair.nativeIndex) || usedBrowser.has(pair.browserIndex)) return false;
    usedNative.add(pair.nativeIndex);
    usedBrowser.add(pair.browserIndex);
    return true;
  });
}

function ratio(numerator, denominator) {
  return denominator === 0 ? null : numerator / denominator;
}

function metricSummary(nativeCount, browserCount, matchedCount, equivalentPairCount) {
  const nativeCoverage = nativeCount === 0 ? (browserCount === 0 ? 1 : 0) : matchedCount / nativeCount;
  const browserCoverage = browserCount === 0 ? (nativeCount === 0 ? 1 : 0) : matchedCount / browserCount;
  return {
    nativeCount,
    browserCount,
    matchedCount,
    nativeOnlyCount: nativeCount - matchedCount,
    browserOnlyCount: browserCount - matchedCount,
    nativeCandidateCoverage: nativeCoverage,
    browserCandidateCoverage: browserCoverage,
    agreementF1: ratio(2 * nativeCoverage * browserCoverage, nativeCoverage + browserCoverage),
    equivalentPairCount,
    equivalentPairRate: ratio(equivalentPairCount, matchedCount)
  };
}

function increment(counts, keys) {
  for (const key of keys) counts[key] = (counts[key] || 0) + 1;
}

function candidateReportForFixture({ sourcePath, sourceDigest, expectedFailure, nativeBundle, browserBundle }) {
  const nativeCandidates = extractCandidates(nativeBundle).map(normalizeCandidate);
  const browserCandidates = extractCandidates(browserBundle).map(normalizeCandidate);
  const pairs = pairCandidates(nativeCandidates, browserCandidates);
  const pairedNative = new Set(pairs.map((pair) => pair.nativeIndex));
  const pairedBrowser = new Set(pairs.map((pair) => pair.browserIndex));
  const mismatchCounts = {};
  const equivalentPairs = [];
  const semanticPairs = [];
  for (const pair of pairs) {
    const nativeCandidate = nativeCandidates[pair.nativeIndex];
    const browserCandidate = browserCandidates[pair.browserIndex];
    const mismatches = mismatchKinds(nativeCandidate, browserCandidate, pair);
    increment(mismatchCounts, mismatches);
    const entry = {
      nativeIndex: pair.nativeIndex,
      browserIndex: pair.browserIndex,
      pageIndex: nativeCandidate.pageIndex,
      iou: round(pair.iou, 4),
      state: mismatches.length === 0 ? "equivalent" : "matchedWithDifferences",
      mismatchKinds: mismatches,
      native: nativeCandidate,
      browser: browserCandidate
    };
    semanticPairs.push(entry);
    if (mismatches.length === 0) equivalentPairs.push(entry);
  }
  const nativeOnly = nativeCandidates
    .map((candidate, index) => ({ index, candidate }))
    .filter((entry) => !pairedNative.has(entry.index));
  const browserOnly = browserCandidates
    .map((candidate, index) => ({ index, candidate }))
    .filter((entry) => !pairedBrowser.has(entry.index));
  const metrics = metricSummary(nativeCandidates.length, browserCandidates.length, pairs.length, equivalentPairs.length);
  return {
    sourcePath,
    sourceDigest,
    expectedFailure,
    nativeStatus: nativeBundle?.status || null,
    browserStatus: browserBundle?.status || null,
    sourceBinding: {
      native: nativeBundle?.sourceDigest || nativeBundle?.document?.payload?.source?.sha256 || null,
      browser: browserBundle?.sourceDigest || browserBundle?.document?.payload?.source?.sha256 || null
    },
    metrics,
    mismatchCounts,
    matchedWithDifferencesCount: semanticPairs.length - equivalentPairs.length,
    matchedPairs: semanticPairs,
    nativeOnly: nativeOnly.map((entry) => ({ index: entry.index, candidate: entry.candidate })),
    browserOnly: browserOnly.map((entry) => ({ index: entry.index, candidate: entry.candidate }))
  };
}

function aggregateFixtureMetrics(fixtures) {
  const totals = fixtures.reduce((accumulator, fixture) => {
    for (const key of ["nativeCount", "browserCount", "matchedCount", "nativeOnlyCount", "browserOnlyCount", "equivalentPairCount"]) {
      accumulator[key] += fixture.metrics[key];
    }
    for (const [key, count] of Object.entries(fixture.mismatchCounts)) {
      accumulator.mismatchCounts[key] = (accumulator.mismatchCounts[key] || 0) + count;
    }
    return accumulator;
  }, {
    nativeCount: 0,
    browserCount: 0,
    matchedCount: 0,
    nativeOnlyCount: 0,
    browserOnlyCount: 0,
    equivalentPairCount: 0,
    mismatchCounts: {}
  });
  return {
    ...metricSummary(totals.nativeCount, totals.browserCount, totals.matchedCount, totals.equivalentPairCount),
    mismatchCounts: totals.mismatchCounts,
    matchedWithDifferencesCount: totals.matchedCount - totals.equivalentPairCount
  };
}

export function buildCandidateParityReport({ corpusManifest, fixtures, generatedAt = null }) {
  const aggregate = aggregateFixtureMetrics(fixtures);
  return {
    harness: "pdf-editor-native-web-candidate-parity",
    schema: CANDIDATE_PARITY_CONTRACT.name,
    version: CANDIDATE_PARITY_CONTRACT.version,
    generatedAtPresent: Boolean(generatedAt),
    corpusManifest,
    fixtureCount: fixtures.length,
    normalization: {
      matching: CANDIDATE_PARITY_CONTRACT.matching,
      ignoredRepresentationFields: CANDIDATE_PARITY_CONTRACT.ignoredRepresentationFields,
      privacy: "candidate labels and evidence prose are omitted; only presence, kinds, origins, geometry, and states are retained"
    },
    aggregate,
    fixtures,
    status: "measured",
    passed: fixtures.every((fixture) => fixture.expectedFailure
      ? fixture.nativeStatus === "inspectionFailed" && fixture.browserStatus === "inspectionFailed"
      : fixture.sourceBinding.native === fixture.sourceDigest
        && fixture.sourceBinding.browser === fixture.sourceDigest)
  };
}

export function compareCandidateBundles(nativeBundle, browserBundle, metadata = {}) {
  return candidateReportForFixture({
    sourcePath: metadata.sourcePath || null,
    sourceDigest: metadata.sourceDigest || nativeBundle?.sourceDigest || null,
    expectedFailure: Boolean(metadata.expectedFailure),
    nativeBundle,
    browserBundle
  });
}
