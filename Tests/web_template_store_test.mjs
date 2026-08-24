import assert from "node:assert/strict";
import { createEphemeralTemplateStore } from "../web/pdf-template-store.mjs";

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

await store.put("template", template.payload.templateID, template);
assert.deepEqual(await store.get("template", template.payload.templateID), template);
assert.deepEqual(await store.list("template"), [{ kind: "template", id: template.payload.templateID }]);
await assert.rejects(() => store.put("template", "source", { bytes: "%PDF-1.7" }));
await store.remove("template", template.payload.templateID);
assert.equal(await store.get("template", template.payload.templateID), null);
console.log("web template store: ephemeral isolation and source-byte guard passed");
