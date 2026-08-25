import assert from "node:assert/strict";
import { buildPreflightReport, validatePreflightReport, preflightForbiddenReportKeys } from "../web/pdf-preflight.mjs";

const sourceBytes = new TextEncoder().encode(`%PDF-1.7
/Metadata /EmbeddedFiles /FileAttachment /XFA /RichMedia
/JavaScript /OpenAction /AA /Launch /SubmitForm /GoToR /URI
/Encrypt /Sig /DocTimeStamp
%%EOF`);
const sourceDigest = "a".repeat(64);
const document = {
  header: {
    contractName: "pdf-editor.document",
    version: { major: 1, minor: 0 },
    sourceDigest,
    provider: { id: "pdfjs-pdflib", version: "test", platform: "web", capabilities: [] }
  },
  payload: {
    source: { fileName: "sensitive-form.pdf", byteCount: sourceBytes.byteLength, sha256: sourceDigest },
    metadata: {
      title: "Private title value",
      author: "Private author value",
      subject: "Private subject value",
      creator: "Private creator value",
      producer: "Private producer value",
      creationDate: "2026-08-25T00:00:00Z",
      modificationDate: "2026-08-25T00:00:01Z",
      keywords: "private-keyword"
    },
    links: [
      { kind: "externalURL", isSafeExternal: true, destination: "https://safe.example/private" },
      { kind: "externalURL", isSafeExternal: false, destination: "file:///private/secret" },
      { kind: "internalPage", isSafeExternal: true },
      { kind: "unknown", isSafeExternal: false }
    ],
    annotationTypeCounts: { widget: 1, link: 1, markup: 2 },
    attachments: ["private-attachment.docx"],
    security: { isEncrypted: true, isLocked: false }
  }
};

const report = buildPreflightReport({ document, sourceBytes, generatedAt: "2026-08-25T00:00:00.000Z" });
assert.equal(validatePreflightReport(report), true);
assert.equal(report.header.contractName, "pdf-editor.preflight");
assert.equal(report.header.sourceDigest, sourceDigest);
assert.equal(report.payload.metadata.rawValuesIncluded, false);
assert.equal(report.payload.summary.metadataFieldCount, 8);
assert.equal(report.payload.summary.embeddedDataCount >= 3, true);
assert.equal(report.payload.summary.networkBoundaryCount >= 4, true);
assert.equal(report.payload.summary.activeContentCount >= 4, true);
assert.equal(report.payload.networkBoundaries.unsafeExternalURLCount, 1);
assert.equal(report.payload.activeContent.executionAttempted, false);
assert.equal(report.payload.scripts.executionAttempted, false);
assert.equal(report.payload.annotations.totalCount, 4);
assert.equal(report.payload.annotations.coverage.state, "observed");
assert.equal(report.payload.revisions.hiddenContentState, "unknown");
assert.equal(report.payload.unknownCoverage.unknownCount, 1);
assert.equal(report.payload.sanitization.status, "not-run");
assert.equal(report.payload.sanitization.safeToClaimClean, false);
assert.equal(report.payload.sanitization.sourceUnchanged, true);

const serialized = JSON.stringify(report);
for (const forbidden of [
  "Private title value", "Private author value", "private-attachment.docx",
  "https://safe.example/private", "file:///private/secret", "%PDF-1.7"
]) {
  assert.equal(serialized.includes(forbidden), false, `raw content leaked: ${forbidden}`);
}
for (const key of preflightForbiddenReportKeys) {
  assert.equal(Object.prototype.hasOwnProperty.call(report, key), false, `forbidden report key present: ${key}`);
}

function rejectsMutation(label, mutate) {
  const mutated = structuredClone(report);
  mutate(mutated);
  assert.throws(() => validatePreflightReport(mutated, { expectedSourceDigest: sourceDigest }), undefined, label);
}

rejectsMutation("stale source digest is rejected", (mutated) => {
  mutated.header.sourceDigest = "b".repeat(64);
});
rejectsMutation("sanitization clean claim is rejected", (mutated) => {
  mutated.payload.sanitization.safeToClaimClean = true;
});
rejectsMutation("completed sanitization state is rejected by preflight", (mutated) => {
  mutated.payload.sanitization.status = "completed";
});
rejectsMutation("preflight execution claim is rejected", (mutated) => {
  mutated.payload.activeContent.executionAttempted = true;
});
rejectsMutation("preflight script execution claim is rejected", (mutated) => {
  mutated.payload.scripts.executionAttempted = true;
});
rejectsMutation("unknown finding severity is rejected", (mutated) => {
  mutated.payload.findings[0].severity = "mystery";
});
rejectsMutation("unknown finding state is rejected", (mutated) => {
  mutated.payload.findings[0].state = "mystery";
});
rejectsMutation("raw page text field is rejected", (mutated) => {
  mutated.pageText = "secret OCR text";
});
rejectsMutation("unsupported contract version is rejected", (mutated) => {
  mutated.header.version = { major: 2, minor: 0 };
});
rejectsMutation("unknown coverage summary mismatch is rejected", (mutated) => {
  mutated.payload.summary.unknownCoverageCount += 1;
});

const reportWithoutBytes = buildPreflightReport({ document });
assert.equal(reportWithoutBytes.payload.summary.unknownCount, 13);
assert.equal(reportWithoutBytes.payload.sanitization.safeToClaimClean, false);
assert.equal(validatePreflightReport(reportWithoutBytes), true);

console.log("preflight contract: observation, zero-content serialization, sanitization boundary, and mutation guards passed");
