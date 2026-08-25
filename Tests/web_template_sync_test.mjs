import assert from "node:assert/strict";
import { appendTemplateRevision } from "../web/pdf-template-contract.mjs";
import {
  decryptTemplateSyncEnvelope,
  encryptTemplateSyncEnvelope,
  mergeTemplateHistories
} from "../web/pdf-template-sync.mjs";

const templateID = "sync-template-1";
const makeRevision = (revisionID, parentRevisionID = null) => ({
  header: {
    contractName: "pdf-editor.template",
    version: { major: 1, minor: 0 },
    templateDigest: "hmac:sync-layout",
    generatedAt: "2026-08-25T00:00:00.000Z",
    provider: { id: "test", version: "1", platform: "node", capabilities: [] }
  },
  payload: {
    templateID,
    revisionID,
    parentRevisionID,
    displayName: "Sync template",
    lifecycle: "active",
    privacyMode: "localMinimized",
    fingerprint: { layoutFingerprint: "hmac:sync-layout", exactSourceDigests: ["a".repeat(64)] },
    mappings: [],
    reviewPolicy: { requireValueReview: true }
  }
});

const first = makeRevision("sync-revision-1");
const second = makeRevision("sync-revision-2", first.payload.revisionID);
const history = appendTemplateRevision({ templateID, revisions: [first] }, second);
const envelope = await encryptTemplateSyncEnvelope({
  history,
  learningEvents: [{ id: "sync-learning-1", templateID, status: "pending", kind: "completionValidated" }],
  deviceID: "device-a",
  generation: 2,
  passphrase: "sync-passphrase-123"
});
assert.equal(envelope.contractName, "pdf-editor.template-sync");
assert.equal(JSON.stringify(envelope).includes("Sync template"), false);
const decrypted = await decryptTemplateSyncEnvelope(envelope, { passphrase: "sync-passphrase-123" });
assert.deepEqual(decrypted.history, history);
await assert.rejects(
  () => decryptTemplateSyncEnvelope(envelope, { passphrase: "wrong-passphrase-123" }),
  /authentication failed/
);

const merged = mergeTemplateHistories({ templateID, revisions: [first] }, history);
assert.deepEqual(merged.conflicts, []);
assert.deepEqual(merged.history, history);
const conflicting = makeRevision("sync-revision-2", first.payload.revisionID);
conflicting.payload.displayName = "Conflict";
const conflictResult = mergeTemplateHistories(history, { templateID, revisions: [conflicting] });
assert.equal(conflictResult.history, null);
assert.equal(conflictResult.conflicts.length, 1);

console.log("web template sync: client encryption, value-free envelope, and conflict abstention passed");
