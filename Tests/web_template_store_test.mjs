import assert from "node:assert/strict";
import { createEncryptedOPFSTemplateStore, createEphemeralTemplateStore } from "../web/pdf-template-store.mjs";

const store = createEphemeralTemplateStore();
const template = {
  header: {
    contractName: "pdf-editor.template",
    version: { major: 1, minor: 0 },
    templateDigest: "hmac:test",
    generatedAt: "2026-08-24T00:00:00.000Z",
    provider: { id: "test", version: "1", platform: "web", capabilities: [] }
  },
  payload: {
    templateID: "template-store-test",
    revisionID: "revision-store-test",
    displayName: "Store test",
    lifecycle: "active",
    privacyMode: "localMinimized",
    fingerprint: { layoutFingerprint: "hmac:test" },
    mappings: [],
    reviewPolicy: { requireValueReview: true }
  }
};

const childTemplate = {
  ...template,
  payload: {
    ...template.payload,
    revisionID: "revision-store-test-child",
    parentRevisionID: template.payload.revisionID,
    displayName: "Store test child"
  }
};

const profile = {
  header: {
    contractName: "pdf-editor.profile",
    version: { major: 1, minor: 0 },
    profileID: "profile-store-test",
    revisionID: "profile-revision-store-test",
    generatedAt: "2026-08-24T00:00:00.000Z",
    provider: { id: "test", version: "1", platform: "web", capabilities: [] }
  },
  payload: {
    profileID: "profile-store-test",
    revisionID: "profile-revision-store-test",
    displayName: "Store profile",
    revisionNumber: 1,
    storageScope: "deviceLocal",
    requiresUnlock: true,
    values: [{
      id: "profile-value-store-test",
      semanticKey: "person.fullName",
      value: { kind: "text", text: "Profile value" }
    }]
  }
};

await store.put("template", template.payload.templateID, template);
assert.deepEqual(await store.get("template", template.payload.templateID), template);
assert.deepEqual(await store.list("template"), [{ kind: "template", id: template.payload.templateID }]);
assert.deepEqual((await store.saveTemplateRevision(template)).revisions.length, 1);
assert.deepEqual((await store.saveTemplateRevision(childTemplate)).revisions.length, 2);
await assert.rejects(
  () => store.saveTemplateRevision({
    ...childTemplate,
    payload: { ...childTemplate.payload, revisionID: "revision-store-test-stale", parentRevisionID: "missing-parent" }
  }),
  /parent is not present/
);
assert.deepEqual((await store.getTemplateHistory(template.payload.templateID)).revisions.length, 2);
const transfer = await store.exportTemplateHistory(template.payload.templateID);
assert.equal(transfer.containsSourceBytes, false);
assert.equal(transfer.containsProfileValues, false);
const importedTemplateID = "imported-template-store-test";
await store.importTemplateHistory({
  ...transfer,
  history: {
    ...transfer.history,
    templateID: importedTemplateID,
    revisions: transfer.history.revisions.map((revision) => ({
      ...revision,
      payload: { ...revision.payload, templateID: importedTemplateID }
    }))
  }
}, { replace: false });
assert.equal((await store.getTemplateHistory(importedTemplateID)).revisions.length, 2);
await store.saveLearningEvent({
  id: "learning-store-test",
  templateID: template.payload.templateID,
  baseRevisionID: template.payload.revisionID,
  sourceDigest: "d".repeat(64),
  kind: "completionValidated",
  status: "pending",
  createdAt: new Date().toISOString()
});
assert.equal((await store.getLearningEvents(template.payload.templateID)).length, 1);
await store.saveProfileRevision(profile);
assert.equal((await store.getProfileHistory(profile.payload.profileID)).revisions.length, 1);
store.lockProfile(profile.payload.profileID);
await assert.rejects(() => store.getProfileHistory(profile.payload.profileID), { code: "profile_locked" });
await store.unlockProfile(profile.payload.profileID);
await assert.rejects(() => store.put("template", "source", { bytes: "%PDF-1.7" }));
await store.deleteProfile(profile.payload.profileID);
assert.equal(await store.getProfileHistory(profile.payload.profileID), null);
await store.deleteTemplate(template.payload.templateID);
assert.equal(await store.getTemplateHistory(template.payload.templateID), null);
await store.remove("template", template.payload.templateID);
assert.equal(await store.get("template", template.payload.templateID), null);
const opfsStore = createEncryptedOPFSTemplateStore({ passphrase: "opfs-template-test-passphrase" });
await assert.rejects(() => opfsStore.unlock(), { code: "opfs_unavailable" });
console.log("web template store: ephemeral isolation and source-byte guard passed");
