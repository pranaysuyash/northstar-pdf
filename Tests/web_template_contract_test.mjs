import assert from "node:assert/strict";
import {
  activateTemplateRevision,
  appendTemplateRevision,
  canMaterializeCompletion,
  canPromoteTemplateRevision,
  captureTemplateDraft,
  createTemplateFingerprint,
  createCompletionProposal,
  createLearningEvent,
  diffTemplateRevisions,
  exportTemplateHistory,
  importTemplateHistory,
  makeValidatedTemplateRevision,
  matchTemplate,
  materializeCompletionOperations,
  resolveCompletionTarget,
  reviewCompletionMapping,
  reviewCompletionValue,
  validateProfileContract,
  validateTemplateContract
} from "../web/pdf-template-contract.mjs";

assert.ok(globalThis.crypto?.subtle, "Node must expose Web Crypto for template fingerprint tests");

const sourceDigest = "d".repeat(64);
const documentContract = {
  header: {
    contractName: "pdf-editor.document",
    version: { major: 1, minor: 0 },
    sourceDigest,
    generatedAt: "2026-08-24T00:00:00.000Z",
    provider: { id: "pdfjs-pdflib", version: "test", platform: "web", capabilities: [] }
  },
  payload: {
    source: { fileName: "recurring-form.pdf", byteCount: 2048, sha256: sourceDigest },
    pages: [{
      pageIndex: 0,
      pageLabel: "1",
      bounds: { x: 0, y: 0, width: 600, height: 800 },
      rotation: 0
    }],
    fields: [],
    candidates: [{
      id: "candidate-1",
      pageIndex: 0,
      bounds: { x: 120, y: 540, width: 220, height: 20 },
      coordinate: {
        pageIndex: 0,
        rect: { x: 120, y: 540, width: 220, height: 20 },
        coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
      },
      kind: "textAnchored",
      suggestedFieldType: "text",
      labelText: "Applicant legal name",
      groupMemberCount: 1
    }]
  }
};

const fingerprint = await createTemplateFingerprint({
  document: documentContract,
  workspaceKey: "local-template-key",
  includeExactSourceDigest: true
});
assert.match(fingerprint.layoutFingerprint, /^hmac:/);
assert.match(fingerprint.pageSignatures[0].anchorTokens[0], /^hmac:/);
assert.equal(fingerprint.exactSourceDigests[0], sourceDigest);

const draft = captureTemplateDraft({
  document: documentContract,
  fingerprint,
  templateID: "template-capture-1",
  sessionID: "capture-session-1"
});
validateTemplateContract(draft);
assert.equal(draft.payload.lifecycle, "draft");
assert.equal(draft.payload.mappings.length, 1);
assert.equal(draft.payload.mappings[0].status, "proposed");
assert.equal(JSON.stringify(draft).includes("Applicant legal name"), false);
const draftSnapshot = JSON.stringify(draft);
const capturedMappingIDs = draft.payload.mappings.map((mapping) => mapping.id);
assert.throws(() => activateTemplateRevision({
  draft,
  approvedMappingIDs: capturedMappingIDs,
  reviewedMappingIDs: []
}));
const activeCapture = activateTemplateRevision({
  draft,
  approvedMappingIDs: capturedMappingIDs,
  reviewedMappingIDs: capturedMappingIDs,
  sessionID: "review-session-1"
});
assert.equal(draft.payload.lifecycle, "draft");
assert.equal(activeCapture.payload.lifecycle, "active");
assert.notEqual(activeCapture.payload.revisionID, draft.payload.revisionID);
assert.equal(activeCapture.payload.parentRevisionID, draft.payload.revisionID);
assert.deepEqual(activeCapture.payload.mappings.map((mapping) => mapping.status), ["confirmed"]);
assert.equal(JSON.stringify(draft), draftSnapshot);
const revisionHistory = appendTemplateRevision(
  { templateID: draft.payload.templateID, revisions: [draft] },
  activeCapture
);
assert.equal(revisionHistory.revisions.length, 2);
assert.equal(revisionHistory.revisions[1].payload.parentRevisionID, revisionHistory.revisions[0].payload.revisionID);
assert.throws(() => appendTemplateRevision(revisionHistory, activeCapture));

const validatedChild = makeValidatedTemplateRevision({
  template: activeCapture,
  sourceDigest: "e".repeat(64),
  sessionID: "validated-session-1"
});
assert.equal(validatedChild.payload.lifecycle, "active");
assert.equal(validatedChild.payload.parentRevisionID, activeCapture.payload.revisionID);
assert.ok(validatedChild.payload.fingerprint.exactSourceDigests.includes(sourceDigest));
assert.equal(JSON.stringify(validatedChild).includes("Ada Lovelace"), false);
const validatedHistory = appendTemplateRevision(
  revisionHistory,
  validatedChild
);
const revisionDiff = diffTemplateRevisions(activeCapture, validatedChild);
assert.deepEqual(revisionDiff.exactSourceDigestsAdded, ["e".repeat(64)]);
assert.equal(revisionDiff.mappingChanges.length, 0);
const transfer = exportTemplateHistory(validatedHistory);
assert.equal(transfer.containsSourceBytes, false);
assert.equal(transfer.containsProfileValues, false);
assert.deepEqual(importTemplateHistory(transfer), validatedHistory);
assert.throws(() => importTemplateHistory({ ...transfer, containsProfileValues: true }));

const mapping = {
  id: "mapping-1",
  semanticKey: "person.fullName",
  target: {
    kind: "staticRegion",
    pageIndex: 0,
    region: {
      pageIndex: 0,
      rect: { x: 120, y: 540, width: 220, height: 20 },
      coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
    },
    candidateKind: "textAnchored"
  },
  suggestedFieldType: "text",
  evidenceReferences: ["candidate-1"],
  status: "confirmed",
  reviewPolicy: "alwaysReviewMappingAndValue"
};
const template = {
  header: {
    contractName: "pdf-editor.template",
    version: { major: 1, minor: 0 },
    templateDigest: fingerprint.layoutFingerprint,
    generatedAt: "2026-08-24T00:00:00.000Z",
    provider: { id: "pdfjs-pdflib", version: "test", platform: "web", capabilities: [] }
  },
  payload: {
    templateID: "template-1",
    revisionID: "revision-1",
    parentRevisionID: null,
    displayName: "Recurring application",
    lifecycle: "active",
    privacyMode: "localMinimized",
    fingerprint,
    mappings: [mapping],
    reviewPolicy: {
      defaultMappingPolicy: "alwaysReviewMappingAndValue",
      requireValueReview: true,
      allowBatchMappingApproval: false
    }
  }
};
validateTemplateContract(template);
const encodedTemplate = JSON.stringify(template);
assert.equal(encodedTemplate.includes("Applicant legal name"), false);
assert.equal(encodedTemplate.includes("Ada Lovelace"), false);

const exact = matchTemplate({ template, fingerprint, sourceDigest });
assert.equal(exact.state, "exact");
assert.deepEqual(exact.approvedMappingIDs, ["mapping-1"]);
assert.equal(exact.requiresValueReview, true);

const profile = {
  header: {
    contractName: "pdf-editor.profile",
    version: { major: 1, minor: 0 },
    profileID: "profile-1",
    revisionID: "profile-revision-2",
    generatedAt: "2026-08-24T00:00:00.000Z",
    provider: { id: "local-vault", version: "test", platform: "web", capabilities: [] }
  },
  payload: {
    profileID: "profile-1",
    revisionID: "profile-revision-2",
    parentRevisionID: "profile-revision-1",
    displayName: "Personal profile",
    revisionNumber: 2,
    storageScope: "userSelectedVault",
    requiresUnlock: true,
    values: [{ id: "value-1", semanticKey: "person.fullName", value: { kind: "text", text: "Ada Lovelace" } }]
  }
};
validateProfileContract(profile);

let completion = createCompletionProposal({ template, match: exact, profile, sessionID: "completion-1" });
assert.equal(completion.entries[0].valueReview, "resolvedUnreviewed");
assert.equal(canMaterializeCompletion({ proposal: completion, currentSourceDigest: sourceDigest }).code, "mappingReviewRequired");
const valueOnly = reviewCompletionValue(completion, "mapping-1", { kind: "text", text: "Ada Lovelace" }, true);
assert.equal(canMaterializeCompletion({ proposal: valueOnly, currentSourceDigest: sourceDigest }).code, "mappingReviewRequired");
completion = reviewCompletionMapping(completion, "mapping-1", true);
assert.equal(canMaterializeCompletion({ proposal: completion, currentSourceDigest: sourceDigest }).code, "valueReviewRequired");
completion = reviewCompletionValue(completion, "mapping-1", { kind: "text", text: "Ada Lovelace" }, true);
assert.equal(canMaterializeCompletion({ proposal: completion, currentSourceDigest: sourceDigest }).ok, true);
const completionOperations = materializeCompletionOperations({ proposal: completion, currentSourceDigest: sourceDigest });
assert.equal(completionOperations[0].kind, "overlayText");
assert.equal(completionOperations[0].sourceDigest, sourceDigest);
assert.equal(canMaterializeCompletion({ proposal: completion, currentSourceDigest: "f".repeat(64) }).code, "staleSource");
const changedValue = {
  ...completion,
  entries: [{ ...completion.entries[0], value: { kind: "text", text: "Grace Hopper" } }]
};
assert.equal(canMaterializeCompletion({ proposal: changedValue, currentSourceDigest: sourceDigest }).code, "profileValueApprovalRequired");
const movedTarget = resolveCompletionTarget(completion, "mapping-1", "provider-target");
assert.equal(movedTarget.entries[0].mappingReview, "pending");
assert.equal(canMaterializeCompletion({ proposal: movedTarget, currentSourceDigest: sourceDigest }).code, "mappingReviewRequired");

const learningEvent = createLearningEvent({ template, proposal: completion, kind: "completionValidated", mappingID: "mapping-1" });
const validReport = {
  status: "validated",
  sourceUnchanged: true,
  outputReopenable: true,
  sourceDigest,
  checks: [{ status: "passed", kind: "outputReopen" }]
};
assert.equal(canPromoteTemplateRevision({ template, sourceDigest, validation: validReport, events: [learningEvent] }), true);
assert.equal(canPromoteTemplateRevision({
  template,
  sourceDigest,
  validation: { ...validReport, status: "validatedWithWarnings" },
  events: [learningEvent]
}), false);
assert.equal(canPromoteTemplateRevision({
  template,
  sourceDigest,
  validation: { ...validReport, checks: [{ status: "unknown", kind: "visualDiff" }] },
  events: [learningEvent]
}), false);

const variant = matchTemplate({
  template,
  fingerprint: { ...fingerprint, exactSourceDigests: [] },
  sourceDigest: "e".repeat(64)
});
assert.equal(variant.state, "knownVariant");

const noMatch = matchTemplate({
  template,
  fingerprint: { ...fingerprint, layoutFingerprint: "hmac:other", exactSourceDigests: [] },
  sourceDigest: "e".repeat(64)
});
assert.equal(noMatch.state, "noMatch");
assert.deepEqual(noMatch.approvedMappingIDs, []);

assert.equal(profile.payload.revisionNumber, 2);

assert.throws(() => validateTemplateContract({ ...template, header: { ...template.header, version: { major: 2, minor: 0 } } }));
assert.throws(() => validateProfileContract({ ...profile, payload: { ...profile.payload, revisionID: "wrong" } }));

console.log("web template contract: fingerprint, mapping, profile, matcher, and negative checks passed");
