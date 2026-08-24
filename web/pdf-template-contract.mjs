/* Browser adapter for the shared PDF template and profile contracts.
 *
 * The native Swift types are canonical for the product model. This module
 * keeps the browser lane on the same JSON shape and matching rules without
 * storing source bytes or profile values in a template record.
 */

export const PDF_TEMPLATE_CONTRACT_NAME = "pdf-editor.template";
export const PDF_PROFILE_CONTRACT_NAME = "pdf-editor.profile";
export const PDF_TEMPLATE_CONTRACT_VERSION = { major: 1, minor: 0 };

function requireObject(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value;
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
    createdAt: new Date().toISOString()
  };
}

function replaceCompletionEntries(proposal, transform) {
  return { ...proposal, entries: proposal.entries.map(transform) };
}

export function reviewCompletionMapping(proposal, mappingID, approved) {
  return replaceCompletionEntries(proposal, (entry) => entry.mappingID === mappingID
    ? { ...entry, mappingReview: approved ? "approved" : "rejected" }
    : entry);
}

export function reviewCompletionValue(proposal, mappingID, value, approved = true) {
  return replaceCompletionEntries(proposal, (entry) => {
    if (entry.mappingID !== mappingID) return entry;
    return {
      ...entry,
      value,
      valueReview: approved && value ? "approved" : value ? "rejected" : "unresolved"
    };
  });
}

export function resolveCompletionTarget(proposal, mappingID, targetID) {
  return replaceCompletionEntries(proposal, (entry) => entry.mappingID === mappingID
    ? { ...entry, resolvedTargetID: targetID || null }
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
  for (const entry of proposal.entries || []) {
    if (entry.mappingReview !== "approved") return { ok: false, code: "mappingReviewRequired", mappingID: entry.mappingID };
    if (entry.valueReview !== "approved") return { ok: false, code: "valueReviewRequired", mappingID: entry.mappingID };
    if (!entry.value) return { ok: false, code: "missingValue", mappingID: entry.mappingID };
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
