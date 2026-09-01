import assert from "node:assert/strict";
import {
  buildPreflightReport,
  comparePreflightTransitions
} from "../web/pdf-preflight.mjs";
import {
  collectExportContractViolations,
  guardedPdfLibExport
} from "../web/pdf-contract-mutation-gate.mjs";

const sourceDigest = "a".repeat(64);
const sourceBytes = new TextEncoder().encode("%PDF-1.7\n%%EOF");
const pageCoordinates = [{ pageIndex: 0, rotation: 0 }];
const operation = {
  id: "reviewed-overlay",
  pageIndex: 0,
  kind: "overlayText",
  value: "reviewed",
  bounds: { x: 20, y: 20, width: 120, height: 20 },
  sourceDigest,
  coordinate: {
    pageIndex: 0,
    rect: { x: 20, y: 20, width: 120, height: 20 },
    coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
  },
  reversible: true,
  destructive: false
};
const document = {
  header: { sourceDigest },
  payload: {
    metadata: {},
    fields: [],
    attachments: [],
    annotationTypeCounts: {},
    security: { isEncrypted: false }
  }
};
const sourcePreflight = buildPreflightReport({ document, sourceBytes, generatedAt: "2026-08-31T00:00:00.000Z" });

async function rejectsBeforeWriter(label, options, code) {
  let writerCalled = false;
  const violations = collectExportContractViolations(options);
  assert.ok(violations.length > 0, `${label} should produce a violation`);
  assert.ok(violations.some((violation) => violation.code === code), `${label} should expose ${code}`);
  await assert.rejects(
    guardedPdfLibExport({
      ...options,
      writer: () => {
        writerCalled = true;
        return "must-not-run";
      }
    }),
    (error) => error.code === code,
    label
  );
  assert.equal(writerCalled, false, `${label} must stop before the writer`);
}

await rejectsBeforeWriter("metadata transition", {
  currentSourceDigest: sourceDigest,
  operations: [operation],
  pageCoordinates,
  sourcePreflight,
  expectedPreflightTransitions: { metadata: "changed" }
}, "privacySensitiveChange");

await rejectsBeforeWriter("attachment transition", {
  currentSourceDigest: sourceDigest,
  operations: [{ ...operation, privacySensitive: true }],
  pageCoordinates,
  sourcePreflight
}, "privacySensitiveChange");

await rejectsBeforeWriter("unknown transition", {
  currentSourceDigest: sourceDigest,
  operations: [operation],
  pageCoordinates,
  sourcePreflight,
  expectedPreflightTransitions: { embeddedActions: "unknown" }
}, "unknownPreflightState");

const changedOutput = structuredClone(sourcePreflight);
changedOutput.header.sourceDigest = "b".repeat(64);
changedOutput.payload.encryption.encrypted = true;
const transition = comparePreflightTransitions(sourcePreflight, changedOutput);
assert.equal(transition.status, "failed");
assert.deepEqual(transition.unauthorizedSurfaces, ["encryption"]);

const allowedOutput = structuredClone(sourcePreflight);
allowedOutput.header.sourceDigest = "c".repeat(64);
allowedOutput.payload.privacySensitiveContent.annotationCount += 1;
const allowed = comparePreflightTransitions(sourcePreflight, allowedOutput, {
  allowedChangedSurfaces: ["privacySensitiveContent"]
});
assert.equal(allowed.status, "passed");
assert.deepEqual(allowed.unauthorizedSurfaces, []);

const unknownOutput = structuredClone(sourcePreflight);
delete unknownOutput.payload.attachments;
await rejectsBeforeWriter("unknown output surface", {
  currentSourceDigest: sourceDigest,
  operations: [operation],
  pageCoordinates,
  sourcePreflight,
  outputPreflight: unknownOutput
}, "unknownPreflightState");

console.log("browser pre-export privacy gate: declared transitions, sensitive operations, unknown states, and output transition failures passed");
