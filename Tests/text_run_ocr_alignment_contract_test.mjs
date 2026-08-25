import assert from "node:assert/strict";
import {
  buildTextRunReplacementProbe,
  buildTextRunReplacementOperation,
  compareOCRLayerAlignment,
  compareTextRunProjections,
  normalizeOCREvidence,
  normalizeTextRun,
  validateTextRunOCRAlignmentReport
} from "../web/text-run-ocr-alignment-benchmark.mjs";
import { assertExportableContract } from "../web/pdf-contract-mutation-gate.mjs";

const sourceDigest = "a".repeat(64);
const pageBounds = { x: 0, y: 0, width: 600, height: 800 };
const nativeRun = await normalizeTextRun({
  pageIndex: 0,
  sequence: 0,
  text: "Stable label",
  bounds: { x: 40, y: 700, width: 90, height: 12 },
  pageBounds,
  sourceDigest,
  providerID: "pdfkit",
  origin: "test"
});
const browserRun = await normalizeTextRun({
  pageIndex: 0,
  sequence: 1,
  text: "Stable label",
  bounds: { x: 40, y: 699.5, width: 90.5, height: 12.2 },
  pageBounds,
  sourceDigest,
  providerID: "pdfjs",
  origin: "test"
});
const ocrRun = await normalizeOCREvidence({
  pageIndex: 0,
  sequence: 0,
  text: "Stable label",
  bounds: { x: 40, y: 700.2, width: 90.1, height: 12.1 },
  pageBounds,
  sourceDigest,
  providerID: "native-vision",
  confidence: 0.91
});

const runComparison = compareTextRunProjections({
  nativeRuns: [nativeRun],
  browserRuns: [browserRun],
  sourceDigest,
  tolerancePoints: 2
});
assert.equal(runComparison.state, "measured");
assert.equal(runComparison.exactTextHashMatches, 1);
assert.equal(runComparison.geometryAgreement, 1);

const ocrComparison = compareOCRLayerAlignment({
  ocrRuns: [ocrRun],
  referenceRuns: [browserRun],
  sourceDigest,
  tolerancePoints: 2
});
assert.equal(ocrComparison.state, "measured");
assert.equal(ocrComparison.matchedTextCount, 1);
assert.equal(ocrComparison.geometryAgreement, 1);

const abstention = compareOCRLayerAlignment({
  ocrRuns: [ocrRun],
  referenceRuns: [],
  sourceDigest
});
assert.equal(abstention.state, "abstainedNoReference");
assert.equal(abstention.geometryAgreement, null);

const probe = buildTextRunReplacementProbe({
  sourceDigest,
  run: nativeRun,
  providerID: "pdfjs-pdflib",
  operationSupported: false
});
assert.equal(probe.capabilityState, "abstained-unsupported");
assert.equal(probe.replacementValueRetained, false);
assert.equal(Object.hasOwn(probe, "replacementText"), false);

const replacementOperation = buildTextRunReplacementOperation({
  sourceDigest: "a".repeat(64),
  run: {
    runID: "0:0:source-run",
    pageIndex: 0,
    textHash: "b".repeat(64),
    bounds: { x: 72, y: 700, width: 80, height: 12 },
    coordinate: {
      pageIndex: 0,
      rect: { x: 72, y: 700, width: 80, height: 12 },
      coordinateSpace: { unit: "points", origin: "lowerLeft", pageBox: "crop", rotationDegrees: 0 }
    }
  },
  replacementText: "reviewed value"
});
assert.equal(replacementOperation.kind, "textRunReplacement");
assert.equal(replacementOperation.payload.originalTextHash, "b".repeat(64));
assert.equal(replacementOperation.reversible, true);
assert.equal(replacementOperation.destructive, false);
assert.throws(() => assertExportableContract({
  currentSourceDigest: sourceDigest,
  operations: [replacementOperation],
  pageCoordinates: [{ pageIndex: 0, rotation: 0 }]
}), /unsupportedOperation/);

const report = {
  contractName: "pdf-editor.text-run-ocr-alignment",
  version: { major: 1, minor: 0 },
  cases: [{
    fixtureId: "synthetic-contract-case",
    sourceDigest,
    native: { providerID: "pdfkit" },
    browser: { providerID: "pdfjs-pdflib" },
    replacement: probe
  }]
};
assert.equal(validateTextRunOCRAlignmentReport(report), true);
assert.throws(() => validateTextRunOCRAlignmentReport({
  ...report,
  cases: [{ ...report.cases[0], replacement: { ...probe, replacementValueRetained: true } }]
}), /replacement values must not be retained/);
const outsideRun = await normalizeTextRun({
  pageIndex: 0,
  sequence: 0,
  text: "outside",
  bounds: { x: 590, y: 700, width: 40, height: 12 },
  pageBounds,
  sourceDigest
});
assert.equal(outsideRun.geometryStatus, "outsidePage");

console.log("text-run/OCR alignment contract: 18 checks passed");
