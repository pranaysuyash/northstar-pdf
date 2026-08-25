/**
 * Deterministic, content-minimizing evidence fusion for candidate review.
 *
 * This is a decision layer above provider adapters. It consumes typed evidence
 * metadata and never promotes a suggestion directly into an edit operation.
 * Native and browser adapters use the same weights, thresholds, and reason
 * codes so provider differences remain visible instead of being normalized.
 */

const DEFAULT_THRESHOLDS = Object.freeze({
  accept: 0.72,
  review: 0.45,
  conflictIoU: 0.10,
  highConfidence: 0.80
});

const KIND_WEIGHTS = Object.freeze({
  nativeField: 1.00,
  manual: 1.00,
  vectorRectangle: 0.75,
  vectorLine: 0.75,
  underline: 0.65,
  textLabel: 0.65,
  ocrText: 0.60,
  spatialRelationship: 0.50,
  repeatedPattern: 0.50,
  whitespace: 0.40
});

const KIND_GROUPS = Object.freeze({
  nativeField: "semantic",
  manual: "semantic",
  vectorRectangle: "geometry",
  vectorLine: "geometry",
  underline: "geometry",
  whitespace: "geometry",
  textLabel: "language",
  ocrText: "language",
  spatialRelationship: "relationship",
  repeatedPattern: "relationship"
});

function clamp(value, minimum = 0, maximum = 1) {
  return Math.max(minimum, Math.min(maximum, Number.isFinite(value) ? value : 0));
}

function rounded(value) {
  return Number(clamp(value).toFixed(6));
}

function normalizedRect(rect) {
  if (!rect || !Number.isFinite(rect.x) || !Number.isFinite(rect.y)
    || !Number.isFinite(rect.width) || !Number.isFinite(rect.height)) return null;
  const x = Math.min(rect.x, rect.x + rect.width);
  const y = Math.min(rect.y, rect.y + rect.height);
  const right = Math.max(rect.x, rect.x + rect.width);
  const top = Math.max(rect.y, rect.y + rect.height);
  return { x, y, width: right - x, height: top - y };
}

function intersectionOverUnion(left, right) {
  const a = normalizedRect(left);
  const b = normalizedRect(right);
  if (!a || !b || a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0) return 0;
  const x = Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x));
  const y = Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
  const intersection = x * y;
  const union = a.width * a.height + b.width * b.height - intersection;
  return union > 0 ? intersection / union : 0;
}

function canonicalSignal(signal, index) {
  return {
    id: String(signal?.id || `signal-${index + 1}`),
    kind: String(signal?.kind || "unknown"),
    origin: String(signal?.origin || "provider"),
    providerID: signal?.providerID ? String(signal.providerID) : null,
    score: clamp(Number(signal?.score)),
    region: signal?.region || null
  };
}

function regionAgreement(signals) {
  const regions = signals.map((signal) => signal.region).filter(Boolean);
  if (regions.length < 2) return 1;
  let total = 0;
  let pairs = 0;
  for (let left = 0; left < regions.length; left += 1) {
    for (let right = left + 1; right < regions.length; right += 1) {
      total += intersectionOverUnion(regions[left], regions[right]);
      pairs += 1;
    }
  }
  return pairs ? total / pairs : 1;
}

export function fuseCandidateEvidence({ signals = [], thresholds = {} } = {}) {
  const policy = { ...DEFAULT_THRESHOLDS, ...thresholds };
  const canonical = signals.map(canonicalSignal);
  if (!canonical.length) {
    return {
      state: "abstain",
      score: 0,
      supportScore: 0,
      coverageScore: 0,
      agreementScore: 0,
      evidenceIDs: [],
      independentGroups: [],
      conflict: false,
      reasonCodes: ["noEvidence"]
    };
  }
  const weightedTotal = canonical.reduce((total, signal) => total + signal.score * (KIND_WEIGHTS[signal.kind] || 0.40), 0);
  const weightTotal = canonical.reduce((total, signal) => total + (KIND_WEIGHTS[signal.kind] || 0.40), 0);
  const supportScore = weightTotal ? weightedTotal / weightTotal : 0;
  const independentGroups = [...new Set(canonical.map((signal) => KIND_GROUPS[signal.kind]).filter(Boolean))].sort();
  const coverageScore = independentGroups.length / 4;
  const agreementScore = regionAgreement(canonical);
  const highConfidence = canonical.filter((signal) => signal.score >= policy.highConfidence);
  const conflict = highConfidence.length > 1 && regionAgreement(highConfidence) < policy.conflictIoU;
  const score = 0.55 * supportScore + 0.25 * coverageScore + 0.20 * agreementScore;
  const reasonCodes = [];
  if (independentGroups.length < 2) reasonCodes.push("singleEvidenceFamily");
  if (agreementScore < policy.conflictIoU) reasonCodes.push("lowGeometricAgreement");
  if (conflict) reasonCodes.push("conflictingHighConfidenceEvidence");
  let state = "abstain";
  if (conflict) state = "abstain";
  else if (score >= policy.accept) state = "supported";
  else if (score >= policy.review) state = "review";
  else reasonCodes.push("lowSupport");
  if (state !== "abstain" && !reasonCodes.includes("singleEvidenceFamily")) reasonCodes.push("independentEvidenceAgreement");
  return {
    state,
    score: rounded(score),
    supportScore: rounded(supportScore),
    coverageScore: rounded(coverageScore),
    agreementScore: rounded(agreementScore),
    evidenceIDs: canonical.map((signal) => signal.id).sort(),
    independentGroups,
    conflict,
    reasonCodes: [...new Set(reasonCodes)].sort()
  };
}

export const evidenceFusionPolicy = Object.freeze({
  thresholds: DEFAULT_THRESHOLDS,
  kindWeights: KIND_WEIGHTS,
  kindGroups: KIND_GROUPS
});
