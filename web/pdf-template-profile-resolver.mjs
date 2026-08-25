// Value-free automatic profile selection shared by the browser review surface.
// A result may identify a profile, but it never carries profile values.

export const PROFILE_RESOLUTION_STATES = Object.freeze(["selected", "ambiguous", "noMatch"]);

function payloadOf(profile) {
  return profile?.payload || profile || {};
}

function valueKind(value) {
  return value?.kind || null;
}

function compatible(value, fieldType) {
  const kind = valueKind(value);
  switch (fieldType) {
    case "checkbox": return kind === "boolean";
    case "choice":
    case "radio": return kind === "choice";
    case "signature": return kind === "assetReference";
    case "text":
    case "date":
    case "number":
    case "unknown":
    default: return kind === "text" || kind === "choice";
  }
}

export function resolveTemplateProfile({ template, profiles = [], ambiguityMargin = 0.05 } = {}) {
  const mappings = (template?.payload?.mappings || template?.mappings || [])
    .filter((mapping) => mapping.status === "confirmed" || mapping.isApproved === true);
  if (!mappings.length) {
    return {
      state: "noMatch",
      candidates: [],
      selectedProfileID: null,
      selectedRevisionID: null,
      abstained: true,
      ambiguityMargin,
      reasons: ["No reviewed template mappings are available for profile resolution."]
    };
  }

  const candidates = profiles.map((profile) => {
    const payload = payloadOf(profile);
    const values = new Map((payload.values || []).map((entry) => [entry.semanticKey, entry.value]));
    const matchedMappingIDs = [];
    const missingSemanticKeys = [];
    const typeMismatches = [];
    for (const mapping of mappings) {
      const value = values.get(mapping.semanticKey);
      if (!value) {
        missingSemanticKeys.push(mapping.semanticKey);
      } else if (compatible(value, mapping.suggestedFieldType)) {
        matchedMappingIDs.push(mapping.id);
      } else {
        typeMismatches.push(mapping.semanticKey);
      }
    }
    const score = matchedMappingIDs.length / Math.max(mappings.length, 1);
    const reasons = [`Matched ${matchedMappingIDs.length} of ${mappings.length} reviewed mapping(s) without exposing values.`];
    if (missingSemanticKeys.length) reasons.push(`Missing ${missingSemanticKeys.length} semantic key(s).`);
    if (typeMismatches.length) reasons.push(`${typeMismatches.length} value kind mismatch(es).`);
    return {
      id: payload.profileID,
      profileID: payload.profileID,
      revisionID: payload.revisionID,
      displayName: payload.displayName || "Unnamed profile",
      score,
      matchedMappingIDs: [...matchedMappingIDs].sort(),
      missingSemanticKeys: [...missingSemanticKeys].sort(),
      typeMismatches: [...typeMismatches].sort(),
      reasons
    };
  }).sort((left, right) => right.score - left.score || String(left.profileID).localeCompare(String(right.profileID)));

  const top = candidates[0];
  if (!top || top.missingSemanticKeys.length || top.typeMismatches.length) {
    return {
      state: "noMatch", candidates, selectedProfileID: null, selectedRevisionID: null,
      abstained: true, ambiguityMargin,
      reasons: ["No unlocked profile contains every reviewed semantic key with a compatible value kind."]
    };
  }
  const second = candidates[1];
  if (second && !second.missingSemanticKeys.length && !second.typeMismatches.length
      && top.score - second.score < ambiguityMargin) {
    return {
      state: "ambiguous", candidates, selectedProfileID: null, selectedRevisionID: null,
      abstained: true, ambiguityMargin,
      reasons: ["Multiple complete profiles are too close to select safely."]
    };
  }
  return {
    state: "selected", candidates, selectedProfileID: top.profileID,
    selectedRevisionID: top.revisionID, abstained: false, ambiguityMargin,
    reasons: ["Exactly one complete, type-compatible profile was selected for review."]
  };
}

