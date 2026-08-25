import { matchTemplate, validateTemplateContract } from "./pdf-template-contract.mjs";

export const TEMPLATE_INDEX_CONTRACT = Object.freeze({
  contractName: "pdf-editor.template-index",
  version: Object.freeze({ major: 1, minor: 0 }),
  privacy: "value-free-keyed-layout-only"
});

const FAMILY_THRESHOLD = 0.72;
const AMBIGUITY_MARGIN = 0.05;

function requireFingerprint(fingerprint) {
  if (!fingerprint || typeof fingerprint.layoutFingerprint !== "string" || !Array.isArray(fingerprint.pageSignatures)) {
    throw new TypeError("A keyed template fingerprint is required.");
  }
}

function histogram(values) {
  const counts = new Map();
  for (const value of values) counts.set(value, (counts.get(value) || 0) + 1);
  return counts;
}

function histogramSimilarity(left, right) {
  const keys = new Set([...left.keys(), ...right.keys()]);
  let distance = 0;
  let total = 0;
  for (const key of keys) {
    const a = left.get(key) || 0;
    const b = right.get(key) || 0;
    distance += Math.abs(a - b);
    total += Math.max(a, b);
  }
  return total === 0 ? 1 : Math.max(0, 1 - distance / total);
}

function pageSimilarity(left, right) {
  const pageCount = Math.max(left.length, right.length, 1);
  const shared = Math.min(left.length, right.length);
  let total = 0;
  for (let index = 0; index < shared; index += 1) {
    const a = left[index];
    const b = right[index];
    const width = Math.max(a.widthPoints, b.widthPoints, 1);
    const height = Math.max(a.heightPoints, b.heightPoints, 1);
    const geometry = Math.max(0, 1 - (Math.abs(a.widthPoints - b.widthPoints) / width + Math.abs(a.heightPoints - b.heightPoints) / height) / 2);
    const rotation = a.rotationDegrees === b.rotationDegrees ? 1 : 0;
    const fields = histogramSimilarity(histogram(a.nativeFieldKinds || []), histogram(b.nativeFieldKinds || []));
    const regions = histogramSimilarity(
      histogram((a.regionSignatures || []).map((region) => `${region.kind}:${region.suggestedFieldType || "unknown"}`)),
      histogram((b.regionSignatures || []).map((region) => `${region.kind}:${region.suggestedFieldType || "unknown"}`))
    );
    const anchors = histogramSimilarity(histogram(a.anchorTokens || []), histogram(b.anchorTokens || []));
    total += geometry * 0.25 + rotation * 0.10 + fields * 0.25 + regions * 0.25 + anchors * 0.15;
  }
  return total / pageCount;
}

function structuralScore(left, right) {
  requireFingerprint(left);
  requireFingerprint(right);
  return pageSimilarity(left.pageSignatures, right.pageSignatures);
}

function validateEntry(entry) {
  if (!entry || typeof entry.templateID !== "string" || typeof entry.revisionID !== "string") {
    throw new TypeError("Template index entry identity is invalid.");
  }
  if (!["active", "revoked", "archived", "draft"].includes(entry.lifecycle)) {
    throw new TypeError("Template index entry lifecycle is invalid.");
  }
  requireFingerprint(entry.fingerprint);
  if (!Array.isArray(entry.exactSourceDigests) || entry.exactSourceDigests.some((digest) => typeof digest !== "string")) {
    throw new TypeError("Template index exact source digests are invalid.");
  }
  if ("displayName" in entry && typeof entry.displayName !== "string") throw new TypeError("Template index display name is invalid.");
  if (JSON.stringify(entry).includes("profileValue") || JSON.stringify(entry).includes("%PDF-")) {
    throw new TypeError("Template index cannot contain profile values or source bytes.");
  }
  return entry;
}

export function buildTemplateIndex(histories = []) {
  const entries = [];
  for (const history of histories) {
    if (!history || !Array.isArray(history.revisions)) continue;
    for (const revision of history.revisions) {
      validateTemplateContract(revision);
      entries.push(validateEntry({
        templateID: revision.payload.templateID,
        revisionID: revision.payload.revisionID,
        parentRevisionID: revision.payload.parentRevisionID || null,
        displayName: revision.payload.displayName,
        lifecycle: revision.payload.lifecycle,
        fingerprint: revision.payload.fingerprint,
        exactSourceDigests: [...(revision.payload.fingerprint.exactSourceDigests || [])]
      }));
    }
  }
  const unique = new Map(entries.map((entry) => [`${entry.templateID}:${entry.revisionID}`, entry]));
  return {
    contractName: TEMPLATE_INDEX_CONTRACT.contractName,
    version: { ...TEMPLATE_INDEX_CONTRACT.version },
    privacy: TEMPLATE_INDEX_CONTRACT.privacy,
    entries: [...unique.values()].sort((left, right) => `${left.templateID}:${left.revisionID}`.localeCompare(`${right.templateID}:${right.revisionID}`))
  };
}

export function validateTemplateIndex(index) {
  if (!index || index.contractName !== TEMPLATE_INDEX_CONTRACT.contractName || index.version?.major !== TEMPLATE_INDEX_CONTRACT.version.major) {
    throw new TypeError("Unsupported template index contract.");
  }
  if (index.privacy !== TEMPLATE_INDEX_CONTRACT.privacy || !Array.isArray(index.entries)) {
    throw new TypeError("Template index privacy or entries are invalid.");
  }
  const IDs = new Set();
  for (const entry of index.entries) {
    validateEntry(entry);
    const key = `${entry.templateID}:${entry.revisionID}`;
    if (IDs.has(key)) throw new TypeError("Template index contains duplicate revision identity.");
    IDs.add(key);
  }
  return index;
}

function resultFor(entry, fingerprint, sourceDigest) {
  const exact = entry.exactSourceDigests.includes(sourceDigest);
  const layout = entry.fingerprint.layoutFingerprint === fingerprint.layoutFingerprint;
  const score = layout ? 0.90 : structuralScore(entry.fingerprint, fingerprint);
  const state = entry.lifecycle !== "active"
    ? (exact ? "stale" : "unsupported")
    : exact ? "exact" : layout ? "knownVariant" : score >= FAMILY_THRESHOLD ? "familyMatch" : "noMatch";
  return {
    state,
    score: exact ? 1 : Number(score.toFixed(6)),
    templateID: entry.templateID,
    revisionID: entry.revisionID,
    sourceDigest,
    reasons: exact
      ? ["The source digest is a reviewed exact template example."]
      : layout
        ? ["The keyed layout fingerprint matches a reviewed source variant."]
        : score >= FAMILY_THRESHOLD
          ? ["The structural family score exceeds the review threshold; mapping review remains required."]
          : ["No reviewed template family exceeded the acceptance threshold."],
    requiresMappingReview: true,
    requiresValueReview: true,
    approvedMappingIDs: []
  };
}

export function queryTemplateIndex({ index, fingerprint, sourceDigest, maxResults = 8 }) {
  validateTemplateIndex(index);
  requireFingerprint(fingerprint);
  if (typeof sourceDigest !== "string" || sourceDigest.length === 0) throw new TypeError("Template lookup requires a source digest.");
  const candidates = index.entries
    .map((entry) => resultFor(entry, fingerprint, sourceDigest))
    .filter((result) => !["noMatch", "unsupported"].includes(result.state))
    .sort((left, right) => {
      const rank = { exact: 3, knownVariant: 2, familyMatch: 1, stale: 0 };
      return (rank[right.state] || 0) - (rank[left.state] || 0)
        || right.score - left.score
        || `${left.templateID}:${left.revisionID}`.localeCompare(`${right.templateID}:${right.revisionID}`);
    });
  if (candidates.length === 0) {
    return { state: "noMatch", candidates: [], selected: null, abstained: true, ambiguityMargin: AMBIGUITY_MARGIN };
  }
  const top = candidates[0];
  const second = candidates[1];
  // Exact and known-variant evidence has an explicit identity signal. Only
  // competing family candidates may be rejected as ambiguous.
  const ambiguous = second
    && top.state === "familyMatch"
    && second.state === "familyMatch"
    && top.score - second.score < AMBIGUITY_MARGIN;
  if (ambiguous) {
    return {
      state: "ambiguous",
      candidates: candidates.slice(0, maxResults),
      selected: null,
      abstained: true,
      ambiguityMargin: AMBIGUITY_MARGIN,
      reasons: ["Multiple local template revisions are too close to select safely."]
    };
  }
  return {
    state: top.state,
    candidates: candidates.slice(0, maxResults),
    selected: top,
    abstained: top.state === "stale",
    ambiguityMargin: AMBIGUITY_MARGIN,
    reasons: top.reasons
  };
}

export function findTemplateRevision(history, result) {
  if (!history || !result?.selected) return null;
  if (history.templateID !== result.selected.templateID) return null;
  return history.revisions.find((revision) => revision.payload.revisionID === result.selected.revisionID) || null;
}
