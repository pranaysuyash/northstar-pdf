/* Browser adapter for the shared PDF template and profile contracts.
 *
 * The native Swift types are canonical for the product model. This module
 * keeps the browser lane on the same JSON shape and matching rules without
 * storing source bytes or profile values in a template record.
 */

export const PDF_TEMPLATE_CONTRACT_NAME = "pdf-editor.template";
export const PDF_PROFILE_CONTRACT_NAME = "pdf-editor.profile";
export const PDF_TEMPLATE_CONTRACT_VERSION = { major: 1, minor: 0 };

const COMPLETION_REVIEW_PROTOCOL = "mapping-and-profile-value-v1";

function requireObject(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value;
}

function canonicalProfileValue(value) {
  if (!value || typeof value !== "object") return null;
  if (value.kind === "text") return `text:${value.text ?? ""}`;
  if (value.kind === "choice") return `choice:${value.choice ?? ""}`;
  if (value.kind === "boolean") return `boolean:${value.boolean ? "true" : "false"}`;
  if (value.kind === "assetReference") return `assetReference:${value.assetID ?? ""}`;
  return null;
}

function profileValueDigest(value) {
  const canonical = canonicalProfileValue(value);
  if (canonical == null) return null;
  const bytes = new TextEncoder().encode(canonical);
  const K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];
  const words = Array.from({ length: Math.ceil((bytes.length + 9) / 64) * 16 }, () => 0);
  for (let index = 0; index < bytes.length; index += 1) words[index >> 2] |= bytes[index] << (24 - (index % 4) * 8);
  words[bytes.length >> 2] |= 0x80 << (24 - (bytes.length % 4) * 8);
  words[words.length - 2] = Math.floor(bytes.length * 8 / 0x100000000);
  words[words.length - 1] = (bytes.length * 8) >>> 0;
  let [a, b, c, d, e, f, g, h] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  const rotr = (value, amount) => (value >>> amount) | (value << (32 - amount));
  for (let offset = 0; offset < words.length; offset += 16) {
    const w = words.slice(offset, offset + 16);
    for (let index = 16; index < 64; index += 1) {
      const s0 = rotr(w[index - 15], 7) ^ rotr(w[index - 15], 18) ^ (w[index - 15] >>> 3);
      const s1 = rotr(w[index - 2], 17) ^ rotr(w[index - 2], 19) ^ (w[index - 2] >>> 10);
      w[index] = (w[index - 16] + s0 + w[index - 7] + s1) >>> 0;
    }
    let [aa, bb, cc, dd, ee, ff, gg, hh] = [a, b, c, d, e, f, g, h];
    for (let index = 0; index < 64; index += 1) {
      const S1 = rotr(ee, 6) ^ rotr(ee, 11) ^ rotr(ee, 25);
      const ch = (ee & ff) ^ (~ee & gg);
      const temp1 = (hh + S1 + ch + K[index] + w[index]) >>> 0;
      const S0 = rotr(aa, 2) ^ rotr(aa, 13) ^ rotr(aa, 22);
      const maj = (aa & bb) ^ (aa & cc) ^ (bb & cc);
      const temp2 = (S0 + maj) >>> 0;
      [hh, gg, ff, ee, dd, cc, bb, aa] = [gg, ff, ee, (dd + temp1) >>> 0, cc, bb, aa, (temp1 + temp2) >>> 0];
    }
    [a, b, c, d, e, f, g, h] = [(a + aa) >>> 0, (b + bb) >>> 0, (c + cc) >>> 0, (d + dd) >>> 0, (e + ee) >>> 0, (f + ff) >>> 0, (g + gg) >>> 0, (h + hh) >>> 0];
  }
  return `sha256:${[a, b, c, d, e, f, g, h].map((value) => value.toString(16).padStart(8, "0")).join("")}`;
}

function requireVersion(version, label) {
  requireObject(version, label);
  if (version.major !== PDF_TEMPLATE_CONTRACT_VERSION.major
      || version.minor > PDF_TEMPLATE_CONTRACT_VERSION.minor) {
    throw new Error(`${label} version is not readable by this adapter.`);
  }
}

function assertMapping(mapping) {
  requireObject(mapping, "template mapping");
  if (typeof mapping.id !== "string" || !mapping.id) throw new Error("Template mapping id is required.");
  if (typeof mapping.semanticKey !== "string" || !mapping.semanticKey) throw new Error("Template mapping semanticKey is required.");
  if (mapping.status === "confirmed" && mapping.target?.pageIndex !== mapping.target?.region?.pageIndex) {
    throw new Error(`Confirmed mapping ${mapping.id} has mismatched coordinate page indexes.`);
  }
}

export function validateTemplateContract(template) {
  requireObject(template, "template contract");
  requireObject(template.header, "template header");
  requireVersion(template.header.version, "template");
  if (template.header.contractName !== PDF_TEMPLATE_CONTRACT_NAME) throw new Error("Unexpected template contract name.");
  if (typeof template.header.templateDigest !== "string" || !template.header.templateDigest) throw new Error("Template digest is required.");
  requireObject(template.payload, "template payload");
  if (typeof template.payload.templateID !== "string" || typeof template.payload.revisionID !== "string") {
    throw new Error("Template and revision IDs are required.");
  }
  requireObject(template.payload.fingerprint, "template fingerprint");
  if (typeof template.payload.fingerprint.layoutFingerprint !== "string") throw new Error("Layout fingerprint is required.");
  for (const mapping of template.payload.mappings || []) assertMapping(mapping);
  return template;
}

export function validateProfileContract(profile) {
  requireObject(profile, "profile contract");
  requireObject(profile.header, "profile header");
  requireVersion(profile.header.version, "profile");
  if (profile.header.contractName !== PDF_PROFILE_CONTRACT_NAME) throw new Error("Unexpected profile contract name.");
  requireObject(profile.payload, "profile payload");
  if (profile.header.profileID !== profile.payload.profileID || profile.header.revisionID !== profile.payload.revisionID) {
    throw new Error("Profile header and payload revisions do not match.");
  }
  return profile;
}

export function approvedTemplateMappings(template) {
  validateTemplateContract(template);
  return (template.payload.mappings || []).filter((mapping) => (
    mapping.status === "confirmed"
    && mapping.semanticKey
    && mapping.target?.pageIndex === mapping.target?.region?.pageIndex
  ));
}

function normalizeStructuralText(text) {
  return String(text || "")
    .toLowerCase()
    .replace(/[0-9]+/g, "#")
    .replace(/[^a-z#]+/g, " ")
    .trim()
    .split(/\s+/)
    .join(" ");
}

async function hmacToken(value, workspaceKey) {
  const keyBytes = typeof workspaceKey === "string"
    ? new TextEncoder().encode(workspaceKey)
    : workspaceKey;
  if (!keyBytes?.byteLength) throw new Error("A non-empty local workspace key is required for template fingerprints.");
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value)));
  return `hmac:${Array.from(signature, (byte) => byte.toString(16).padStart(2, "0")).join("")}`;
}

function normalizedRect(rect, page) {
  const width = Math.max(1, page.bounds.width);
  const height = Math.max(1, page.bounds.height);
  return {
    x: rect.x / width,
    y: rect.y / height,
    width: rect.width / width,
    height: rect.height / height
  };
}

function compareReadingOrder(left, right) {
  return Math.abs(left.bounds.y - right.bounds.y) > 0.001
    ? left.bounds.y - right.bounds.y
    : left.bounds.x - right.bounds.x;
}

function canonicalDescriptor(pageSignatures) {
  return pageSignatures.map((page) => {
    const fields = page.nativeFieldKinds.join(",");
    const names = page.nativeFieldNameTokens.join(",");
    const anchors = page.anchorTokens.join(",");
    const regions = page.regionSignatures.map((region) => [
      region.kind,
      region.suggestedFieldType || "none",
      [region.normalizedRect.x, region.normalizedRect.y, region.normalizedRect.width, region.normalizedRect.height]
        .map((value) => Number(value).toFixed(4)).join(","),
      region.anchorToken || "none",
      String(region.groupMemberCount)
    ].join("~")).join("|");
    return [
      String(page.pageIndex),
      `${Number(page.widthPoints).toFixed(3)},${Number(page.heightPoints).toFixed(3)}`,
      String(page.rotationDegrees),
      fields,
      names,
      anchors,
      regions
    ].join("#");
  }).join("\n");
}

export async function createTemplateFingerprint({ document, workspaceKey, includeExactSourceDigest = false }) {
  requireObject(document, "document contract");
  const payload = document.payload || document;
  const pages = [...(payload.pages || [])].sort((left, right) => left.pageIndex - right.pageIndex);
  const pageSignatures = [];
  for (const page of pages) {
    const fields = (payload.fields || [])
      .filter((field) => field.pageIndex === page.pageIndex)
      .sort(compareReadingOrder);
    const candidates = (payload.candidates || [])
      .filter((candidate) => candidate.pageIndex === page.pageIndex)
      .sort(compareReadingOrder);
    const pageAnchors = [];
    const regionSignatures = [];
    for (const candidate of candidates) {
      const anchorToken = candidate.labelText
        ? await hmacToken(normalizeStructuralText(candidate.labelText), workspaceKey)
        : null;
      if (anchorToken) pageAnchors.push(anchorToken);
      regionSignatures.push({
        kind: candidate.kind,
        suggestedFieldType: candidate.suggestedFieldType || null,
        normalizedRect: normalizedRect(candidate.bounds, page),
        anchorToken,
        groupMemberCount: Math.max(1, candidate.groupMemberCount || 1)
      });
    }
    const nativeFieldNameTokens = [];
    for (const field of fields) {
      nativeFieldNameTokens.push(await hmacToken(normalizeStructuralText(field.name), workspaceKey));
    }
    pageSignatures.push({
      pageIndex: page.pageIndex,
      widthPoints: page.bounds.width,
      heightPoints: page.bounds.height,
      rotationDegrees: page.rotation || 0,
      nativeFieldKinds: fields.map((field) => field.kind),
      nativeFieldNameTokens,
      anchorTokens: pageAnchors,
      regionSignatures
    });
  }
  const layoutFingerprint = await hmacToken(canonicalDescriptor(pageSignatures), workspaceKey);
  return {
    algorithm: "layout-v1+hmac-sha256",
    keyScope: "workspace",
    featureVersion: "layout-features-1",
    layoutFingerprint,
    exactSourceDigests: includeExactSourceDigest && payload.source?.sha256 ? [payload.source.sha256] : [],
    pageSignatures
  };
}

function suggestedTypeForNativeField(kind) {
  if (kind === "choice") return "choice";
  if (kind === "button") return "checkbox";
  if (kind === "signature") return "signature";
  return "text";
}

function directlyEditableCandidate(candidate) {
  return ["singleText", "characterGrid", "signature"].includes(candidate.entryMode)
    || (!candidate.entryMode && ["text", "date", "number", "signature"].includes(candidate.suggestedFieldType));
}

export function captureTemplateDraft({ document, fingerprint, displayName = "Reviewed local layout", templateID = null, sessionID = null }) {
  requireObject(document, "document contract");
  requireObject(fingerprint, "template fingerprint");
  const payload = document.payload || document;
  if (!payload.source?.sha256) throw new Error("A source digest is required for local template capture.");
  const id = templateID || `template-${Date.now()}`;
  const mappings = [];
  const fields = [...(payload.fields || [])].sort(compareReadingOrder);
  for (const [index, field] of fields.entries()) {
    const pageFields = fields.filter((entry) => entry.pageIndex === field.pageIndex);
    const fieldIndex = pageFields.findIndex((entry) => entry.id === field.id);
    const page = (fingerprint.pageSignatures || []).find((entry) => entry.pageIndex === field.pageIndex);
    const region = field.coordinate || {
      pageIndex: field.pageIndex,
      rect: field.bounds,
      coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
    };
    mappings.push({
      id: `mapping-${Date.now()}-${index + 1}`,
      semanticKey: `field.${field.kind}.${index + 1}`,
      target: {
        kind: "nativeField",
        pageIndex: field.pageIndex,
        region,
        nativeFieldNameToken: page?.nativeFieldNameTokens?.[fieldIndex] || null
      },
      suggestedFieldType: suggestedTypeForNativeField(field.kind),
      evidenceReferences: [],
      status: "proposed",
      reviewPolicy: "alwaysReviewMappingAndValue",
      createdFromSessionID: sessionID
    });
  }
  const candidates = [...(payload.candidates || [])]
    .filter((candidate) => candidate.coordinate && directlyEditableCandidate(candidate))
    .sort(compareReadingOrder);
  candidates.forEach((candidate, index) => {
    mappings.push({
      id: `mapping-${Date.now()}-${fields.length + index + 1}`,
      semanticKey: `region.${candidate.suggestedFieldType || "text"}.${index + 1}`,
      target: {
        kind: "staticRegion",
        pageIndex: candidate.pageIndex,
        region: candidate.coordinate,
        candidateKind: candidate.kind
      },
      suggestedFieldType: candidate.suggestedFieldType || "text",
      evidenceReferences: [candidate.id, ...(candidate.evidenceItems || []).map((item) => item.id)],
      status: "proposed",
      reviewPolicy: "alwaysReviewMappingAndValue",
      createdFromSessionID: sessionID
    });
  });
  const revisionID = `revision-${Date.now()}`;
  return {
    header: {
      contractName: PDF_TEMPLATE_CONTRACT_NAME,
      version: { ...PDF_TEMPLATE_CONTRACT_VERSION },
      templateDigest: fingerprint.layoutFingerprint,
      generatedAt: new Date().toISOString(),
      provider: document.header?.provider || { id: "pdf-editor-core", version: "1", platform: "web", capabilities: [] }
    },
    payload: {
      templateID: id,
      revisionID,
      parentRevisionID: null,
      displayName,
      lifecycle: "draft",
      privacyMode: "localMinimized",
      fingerprint,
      mappings,
      reviewPolicy: {
        defaultMappingPolicy: "alwaysReviewMappingAndValue",
        requireValueReview: true,
        allowBatchMappingApproval: false
      }
    }
  };
}

export function activateTemplateRevision({ draft, approvedMappingIDs, reviewedMappingIDs, sessionID = null }) {
  validateTemplateContract(draft);
  if (draft.payload.lifecycle !== "draft") throw new Error("Only draft template revisions can be activated.");
  const mappingIDs = new Set((draft.payload.mappings || []).map((mapping) => mapping.id));
  const approved = new Set(approvedMappingIDs || []);
  const reviewed = new Set(reviewedMappingIDs || []);
  if (mappingIDs.size !== reviewed.size || [...mappingIDs].some((id) => !reviewed.has(id)) || [...approved].some((id) => !reviewed.has(id))) {
    throw new Error("Every template mapping must have an explicit review decision before activation.");
  }
  if (!approved.size) throw new Error("At least one mapping must be approved before activation.");
  return {
    ...draft,
    header: { ...draft.header, generatedAt: new Date().toISOString() },
    payload: {
      ...draft.payload,
      revisionID: `revision-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      parentRevisionID: draft.payload.revisionID,
      lifecycle: "active",
      mappings: draft.payload.mappings.map((mapping) => ({
        ...mapping,
        status: approved.has(mapping.id) ? "confirmed" : "rejected",
        createdFromSessionID: sessionID || mapping.createdFromSessionID || null
      }))
    }
  };
}

export function appendTemplateRevision(history, revision) {
  requireObject(history, "template revision history");
  validateTemplateContract(revision);
  if (history.templateID !== revision.payload.templateID) throw new Error("Template revision history identity mismatch.");
  const revisions = history.revisions || [];
  if (revisions.some((entry) => entry.payload.revisionID === revision.payload.revisionID)) throw new Error("Duplicate template revision.");
  if (revision.payload.parentRevisionID && !revisions.some((entry) => entry.payload.revisionID === revision.payload.parentRevisionID)) {
    throw new Error("Template revision parent is not present in local history.");
  }
  return { templateID: history.templateID, revisions: [...revisions, revision] };
}

export function appendProfileRevision(history, revision) {
  requireObject(history, "profile revision history");
  validateProfileContract(revision);
  if (history.profileID !== revision.payload.profileID) throw new Error("Profile revision history identity mismatch.");
  const revisions = history.revisions || [];
  if (revisions.some((entry) => entry.payload.revisionID === revision.payload.revisionID)) throw new Error("Duplicate profile revision.");
  if (revision.payload.parentRevisionID && !revisions.some((entry) => entry.payload.revisionID === revision.payload.parentRevisionID)) {
    throw new Error("Profile revision parent is not present in local history.");
  }
  return { profileID: history.profileID, revisions: [...revisions, revision] };
}

/**
 * Materialize a new immutable template revision after a strict validated
 * completion. The current source digest is added as a reviewed variant, but
 * no profile value or source PDF bytes are copied into the revision.
 */
export function makeValidatedTemplateRevision({ template, sourceDigest, sessionID = null }) {
  validateTemplateContract(template);
  if (template.payload.lifecycle !== "active") {
    throw new Error("Only an active template can receive a validated completion revision.");
  }
  if (typeof sourceDigest !== "string" || !sourceDigest) {
    throw new Error("A source digest is required for a validated template revision.");
  }
  const fingerprint = {
    ...template.payload.fingerprint,
    exactSourceDigests: [...new Set([
      ...(template.payload.fingerprint.exactSourceDigests || []),
      sourceDigest
    ])]
  };
  const revision = {
    ...template,
    header: { ...template.header, generatedAt: new Date().toISOString() },
    payload: {
      ...template.payload,
      revisionID: `revision-validated-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      parentRevisionID: template.payload.revisionID,
      lifecycle: "active",
      fingerprint,
      mappings: (template.payload.mappings || []).map((mapping) => ({
        ...mapping,
        createdFromSessionID: sessionID || mapping.createdFromSessionID || null
      }))
    }
  };
  return validateTemplateContract(revision);
}

function stableMappingProjection(mapping) {
  return {
    id: mapping.id,
    semanticKey: mapping.semanticKey,
    target: mapping.target,
    suggestedFieldType: mapping.suggestedFieldType || null,
    evidenceReferences: [...(mapping.evidenceReferences || [])].sort(),
    status: mapping.status,
    reviewPolicy: mapping.reviewPolicy || null,
    sourceVariantID: mapping.sourceVariantID || null,
    supersedesMappingID: mapping.supersedesMappingID || null
  };
}

/** Compare two immutable revisions without treating timestamps as changes. */
export function diffTemplateRevisions(fromRevision, toRevision) {
  validateTemplateContract(fromRevision);
  validateTemplateContract(toRevision);
  if (fromRevision.payload.templateID !== toRevision.payload.templateID) {
    throw new Error("Template revision diff requires matching template IDs.");
  }
  const before = new Map((fromRevision.payload.mappings || []).map((mapping) => [mapping.id, mapping]));
  const after = new Map((toRevision.payload.mappings || []).map((mapping) => [mapping.id, mapping]));
  const mappingChanges = [];
  for (const id of new Set([...before.keys(), ...after.keys()])) {
    const left = before.get(id);
    const right = after.get(id);
    const leftProjection = left ? stableMappingProjection(left) : null;
    const rightProjection = right ? stableMappingProjection(right) : null;
    if (JSON.stringify(leftProjection) !== JSON.stringify(rightProjection)) {
      mappingChanges.push({
        mappingID: id,
        change: !left ? "added" : !right ? "removed" : "changed",
        before: leftProjection,
        after: rightProjection
      });
    }
  }
  const beforeDigests = new Set(fromRevision.payload.fingerprint.exactSourceDigests || []);
  const afterDigests = new Set(toRevision.payload.fingerprint.exactSourceDigests || []);
  return {
    contractName: "pdf-editor.template-revision-diff",
    version: { major: 1, minor: 0 },
    templateID: fromRevision.payload.templateID,
    fromRevisionID: fromRevision.payload.revisionID,
    toRevisionID: toRevision.payload.revisionID,
    lifecycleChanged: fromRevision.payload.lifecycle !== toRevision.payload.lifecycle,
    fingerprintChanged: fromRevision.payload.fingerprint.layoutFingerprint !== toRevision.payload.fingerprint.layoutFingerprint,
    exactSourceDigestsAdded: [...afterDigests].filter((digest) => !beforeDigests.has(digest)).sort(),
    exactSourceDigestsRemoved: [...beforeDigests].filter((digest) => !afterDigests.has(digest)).sort(),
    mappingChanges: mappingChanges.sort((left, right) => left.mappingID.localeCompare(right.mappingID))
  };
}

export function exportTemplateHistory(history) {
  requireObject(history, "template revision history");
  if (typeof history.templateID !== "string" || !Array.isArray(history.revisions) || !history.revisions.length) {
    throw new Error("Template revision history is invalid.");
  }
  let validated = { templateID: history.templateID, revisions: [] };
  for (const revision of history.revisions) {
    if (revision.payload.templateID !== history.templateID) throw new Error("Template history identity mismatch.");
    validated = appendTemplateRevision(validated, revision);
  }
  return {
    contractName: "pdf-editor.template-transfer",
    version: { major: 1, minor: 0 },
    exportedAt: new Date().toISOString(),
    containsSourceBytes: false,
    containsProfileValues: false,
    history: validated
  };
}

export function importTemplateHistory(envelope) {
  requireObject(envelope, "template transfer envelope");
  if (envelope.contractName !== "pdf-editor.template-transfer" || envelope.version?.major !== 1) {
    throw new Error("Unsupported template transfer envelope.");
  }
  if (envelope.containsSourceBytes || envelope.containsProfileValues) {
    throw new Error("Template transfer envelopes cannot contain source bytes or profile values.");
  }
  return exportTemplateHistory(envelope.history).history;
}

export function matchTemplate({ template, fingerprint, sourceDigest }) {
  validateTemplateContract(template);
  const payload = template.payload;
  if (payload.lifecycle !== "active") {
    return {
      state: "unsupported",
      score: 0,
      templateID: payload.templateID,
      revisionID: payload.revisionID,
      sourceDigest,
      reasons: ["The template revision is not active and cannot propose mappings."],
      approvedMappingIDs: [],
      requiresMappingReview: true,
      requiresValueReview: true
    };
  }
  const exactSource = (fingerprint.exactSourceDigests || []).includes(sourceDigest);
  const layoutMatch = fingerprint.layoutFingerprint === payload.fingerprint.layoutFingerprint;
  const state = exactSource ? "exact" : layoutMatch ? "knownVariant" : "noMatch";
  return {
    state,
    score: exactSource ? 1 : layoutMatch ? 0.9 : 0,
    templateID: payload.templateID,
    revisionID: payload.revisionID,
    sourceDigest,
    reasons: [exactSource
      ? "The source digest is a reviewed exact template example."
      : layoutMatch
        ? "The keyed layout fingerprint matches, but this source digest is a different example."
        : "The source does not match the template fingerprint."],
    approvedMappingIDs: state === "noMatch" ? [] : approvedTemplateMappings(template).map((mapping) => mapping.id),
    requiresMappingReview: true,
    requiresValueReview: payload.reviewPolicy?.requireValueReview ?? true
  };
}

export function createCompletionProposal({ template, match, profile = null, sessionID = `session-${Date.now()}` }) {
  validateTemplateContract(template);
  if (!match?.templateID || !match?.revisionID) return null;
  const approvedIDs = new Set(match.approvedMappingIDs || []);
  const values = new Map((profile?.payload?.values || []).map((record) => [record.semanticKey, record.value]));
  const entries = (template.payload.mappings || [])
    .filter((mapping) => approvedIDs.has(mapping.id))
    .map((mapping) => {
      const value = values.get(mapping.semanticKey) || null;
      return {
        id: `completion-entry-${mapping.id}`,
        mappingID: mapping.id,
        semanticKey: mapping.semanticKey,
        target: mapping.target,
        candidateID: mapping.evidenceReferences?.find((reference) => /^[0-9a-f-]{36}$/i.test(reference)) || null,
        mappingReview: "pending",
        profileID: profile?.payload?.profileID || null,
        profileRevisionID: profile?.payload?.revisionID || null,
        value,
        valueReview: value ? "resolvedUnreviewed" : "unresolved",
        mappingApproval: null,
        profileValueApproval: null,
        resolvedTargetID: null
      };
    });
  return {
    id: `completion-${Date.now()}`,
    sessionID,
    templateID: match.templateID,
    revisionID: match.revisionID,
    sourceDigest: match.sourceDigest,
    matchState: match.state,
    reasons: match.reasons || [],
    entries,
    reviewProtocol: COMPLETION_REVIEW_PROTOCOL,
    createdAt: new Date().toISOString()
  };
}

function replaceCompletionEntries(proposal, transform) {
  return { ...proposal, entries: proposal.entries.map(transform) };
}

export function reviewCompletionMapping(proposal, mappingID, approved) {
  return replaceCompletionEntries(proposal, (entry) => entry.mappingID === mappingID
    ? {
      ...entry,
      mappingReview: approved ? "approved" : "rejected",
      mappingApproval: {
        state: approved ? "approved" : "rejected",
        mappingID,
        targetID: entry.resolvedTargetID || null,
        coordinate: entry.target.region,
        reviewedAt: new Date().toISOString()
      }
    }
    : entry);
}

export function reviewCompletionValue(proposal, mappingID, value, approved = false) {
  const digest = profileValueDigest(value);
  return replaceCompletionEntries(proposal, (entry) => {
    if (entry.mappingID !== mappingID) return entry;
    const canApprove = approved && value && entry.profileID && entry.profileRevisionID && digest;
    return {
      ...entry,
      value,
      valueReview: canApprove ? "approved" : value ? "resolvedUnreviewed" : "unresolved",
      profileValueApproval: {
        state: canApprove ? "approved" : value ? "resolvedUnreviewed" : "unresolved",
        profileID: entry.profileID || null,
        profileRevisionID: entry.profileRevisionID || null,
        semanticKey: entry.semanticKey,
        valueDigest: digest,
        reviewedAt: new Date().toISOString()
      }
    };
  });
}

export function resolveCompletionTarget(proposal, mappingID, targetID) {
  return replaceCompletionEntries(proposal, (entry) => entry.mappingID === mappingID
    ? {
      ...entry,
      mappingReview: (targetID || null) === (entry.resolvedTargetID || null) ? entry.mappingReview : "pending",
      mappingApproval: (targetID || null) === (entry.resolvedTargetID || null) ? entry.mappingApproval : null,
      resolvedTargetID: targetID || null
    }
    : entry);
}

function completionReviewable(state) {
  return ["exact", "knownVariant", "familyMatch"].includes(state);
}

function valueAsString(value) {
  if (!value) return "";
  if (value.kind === "boolean") return value.boolean ? "true" : "false";
  return value.text ?? value.choice ?? value.assetID ?? "";
}

function completionPayload(entry) {
  const value = entry.value;
  if (!value) return null;
  if (value.kind === "text") return { kind: "text", value: value.text };
  if (value.kind === "choice") return { kind: "choice", value: value.choice };
  if (value.kind === "boolean" && entry.target.kind === "nativeField") {
    return { kind: "boolean", value: value.boolean };
  }
  return null;
}

export function canMaterializeCompletion({ proposal, currentSourceDigest }) {
  if (currentSourceDigest !== proposal.sourceDigest) {
    return { ok: false, code: "staleSource", expected: proposal.sourceDigest, actual: currentSourceDigest };
  }
  if (!completionReviewable(proposal.matchState)) {
    return { ok: false, code: "matchNotReviewable", state: proposal.matchState };
  }
  if (proposal.reviewProtocol && proposal.reviewProtocol !== COMPLETION_REVIEW_PROTOCOL) {
    return { ok: false, code: "unsupportedReviewProtocol", protocol: proposal.reviewProtocol };
  }
  for (const entry of proposal.entries || []) {
    if (entry.mappingReview !== "approved") return { ok: false, code: "mappingReviewRequired", mappingID: entry.mappingID };
    if (entry.mappingApproval?.state !== "approved"
      || entry.mappingApproval.mappingID !== entry.mappingID
      || JSON.stringify(entry.mappingApproval.coordinate) !== JSON.stringify(entry.target.region)
      || (entry.mappingApproval.targetID || null) !== (entry.resolvedTargetID || null)) {
      return { ok: false, code: "mappingApprovalRequired", mappingID: entry.mappingID };
    }
    if (entry.valueReview !== "approved") return { ok: false, code: "valueReviewRequired", mappingID: entry.mappingID };
    if (!entry.value) return { ok: false, code: "missingValue", mappingID: entry.mappingID };
    const expectedValueDigest = profileValueDigest(entry.value);
    if (entry.profileValueApproval?.state !== "approved"
      || entry.profileValueApproval.profileID !== entry.profileID
      || entry.profileValueApproval.profileRevisionID !== entry.profileRevisionID
      || entry.profileValueApproval.semanticKey !== entry.semanticKey
      || !expectedValueDigest
      || entry.profileValueApproval.valueDigest !== expectedValueDigest) {
      return { ok: false, code: "profileValueApprovalRequired", mappingID: entry.mappingID };
    }
    if (entry.target?.pageIndex !== entry.target?.region?.pageIndex) {
      return { ok: false, code: "coordinateMismatch", mappingID: entry.mappingID };
    }
    if (entry.target.kind === "nativeField" && !entry.resolvedTargetID) {
      return { ok: false, code: "unresolvedNativeTarget", mappingID: entry.mappingID };
    }
    if (!completionPayload(entry)) return { ok: false, code: "unsupportedValue", mappingID: entry.mappingID };
  }
  return { ok: true };
}

export function materializeCompletionOperations({ proposal, currentSourceDigest }) {
  const gate = canMaterializeCompletion({ proposal, currentSourceDigest });
  if (!gate.ok) throw new Error(`Completion cannot materialize: ${gate.code}`);
  return proposal.entries.map((entry, index) => {
    const native = entry.target.kind === "nativeField";
    return {
      id: `operation-${proposal.sessionID}-${index + 1}`,
      pageIndex: entry.target.pageIndex,
      targetID: native ? entry.resolvedTargetID : null,
      kind: native ? "nativeFieldValue" : "overlayText",
      value: valueAsString(entry.value),
      bounds: entry.target.region.rect,
      candidateID: entry.target.candidateID || entry.target.anchorToken || null,
      previousValue: null,
      createdAt: new Date().toISOString(),
      sessionID: proposal.sessionID,
      parentOperationID: null,
      sourceDigest: proposal.sourceDigest,
      coordinate: entry.target.region,
      payload: completionPayload(entry),
      reversible: true,
      destructive: false
    };
  });
}

export function createLearningEvent({ template, proposal, kind, mappingID = null, candidateID = null, note = null }) {
  validateTemplateContract(template);
  return {
    id: `learning-${Date.now()}-${Math.random().toString(16).slice(2)}`,
    templateID: template.payload.templateID,
    baseRevisionID: template.payload.revisionID,
    sourceDigest: proposal.sourceDigest,
    kind,
    mappingID,
    candidateID,
    completionSessionID: proposal.sessionID,
    status: "pending",
    note,
    createdAt: new Date().toISOString()
  };
}

export function canPromoteTemplateRevision({ template, sourceDigest, validation, events }) {
  validateTemplateContract(template);
  if (template.payload.lifecycle !== "active") return false;
  if (validation?.status !== "validated" || !validation.sourceUnchanged || !validation.outputReopenable) return false;
  if (validation.sourceDigest !== sourceDigest || !events?.length) return false;
  if ((validation.checks || []).some((check) => ["unknown", "failed"].includes(check.status))) return false;
  return events.every((event) => event.templateID === template.payload.templateID
    && event.baseRevisionID === template.payload.revisionID
    && event.sourceDigest === sourceDigest
    && event.status === "pending");
}
