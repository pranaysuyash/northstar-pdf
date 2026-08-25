import assert from "node:assert/strict";
import {
  createSessionPrivacyProvenance,
  validateSessionPrivacyProvenance,
  sessionProvenanceForbiddenKeys
} from "../web/pdf-session-provenance.mjs";

const sourceDigest = "a".repeat(64);
const outputDigest = "b".repeat(64);
const provider = { id: "pdfjs-pdflib", version: "test", platform: "web", capabilities: ["session-provenance"] };

function base(overrides = {}) {
  return createSessionPrivacyProvenance({
    sessionID: "browser-session-test",
    sourceDigest,
    provider,
    generatedAt: "2026-08-25T00:00:00.000Z",
    processing: { locality: "local-browser", sourceInput: "local-file-picker", dataEgress: "none" },
    sourceRetention: { state: "in-memory-session", retainedUntilSessionEnd: true, deletion: "pending", sourceCopyCount: 1 },
    exportProvenance: {
      state: "not-attempted",
      sourceDigest,
      outputDigest: null,
      storage: "not-applicable",
      validation: "not-run",
      outputReopenable: null,
      operationCount: 0
    },
    ...overrides
  });
}

const initial = base();
assert.equal(validateSessionPrivacyProvenance(initial, { expectedSourceDigest: sourceDigest }), true);
const serialized = JSON.stringify(initial);
for (const key of sessionProvenanceForbiddenKeys) assert.equal(serialized.includes(`"${key}"`), false, `forbidden key leaked: ${key}`);
for (const value of ["private.pdf", "secret OCR", "https://private.example", "%PDF-1.7"]) assert.equal(serialized.includes(value), false, `sensitive value leaked: ${value}`);

const completed = base({
  exportProvenance: {
    state: "succeeded",
    sourceDigest,
    outputDigest,
    storage: "local-download",
    validation: "validated",
    outputReopenable: true,
    operationCount: 2,
    exporterID: "pdf-lib",
    validationProviderID: "pdfjs"
  }
});
assert.equal(validateSessionPrivacyProvenance(completed), true);
assert.equal(completed.payload.export.outputDigest, outputDigest);

function rejects(label, mutate, expected = undefined) {
  const mutated = structuredClone(initial);
  mutate(mutated);
  assert.throws(() => validateSessionPrivacyProvenance(mutated, { expectedSourceDigest: sourceDigest }), expected, label);
}

rejects("stale digest is rejected", (record) => { record.header.sourceDigest = "c".repeat(64); }, /source mismatch|stale/);
rejects("source bytes claim is rejected", (record) => { record.payload.privacy.sourceBytesIncluded = true; }, /privacy leak/);
rejects("OCR not-used contradiction is rejected", (record) => { record.payload.ocr.processedPageCount = 1; }, /OCR/);
rejects("successful export without output digest is rejected", (record) => {
  record.payload.export.state = "succeeded";
  record.payload.export.storage = "local-download";
  record.payload.export.validation = "validated";
  record.payload.export.outputReopenable = true;
}, /output|export/);
rejects("not-attempted export with artifact evidence is rejected", (record) => { record.payload.export.outputDigest = outputDigest; }, /not-attempted|artifact/);

const localRuntime = base({ processing: { locality: "local-browser", sourceInput: "local-file-picker", dataEgress: "runtime-only", networkRequestCount: 1 } });
assert.equal(validateSessionPrivacyProvenance(localRuntime), true);

const unknownProvider = base({
  processing: { locality: "unknown", sourceInput: "unknown", dataEgress: "unknown" },
  ocr: { state: "unknown", providerIDs: [], processedPageCount: 0, recognizedTextRetained: false, recognizedBoundsRetained: false },
  sourceRetention: { state: "unknown", retainedUntilSessionEnd: false, deletion: "unknown", sourceCopyCount: 0 }
});
assert.equal(validateSessionPrivacyProvenance(unknownProvider), true);
assert.equal(unknownProvider.payload.processing.locality, "unknown");

console.log("session privacy provenance contract: locality, OCR, retention, export, zero-content, and mutation guards passed");
