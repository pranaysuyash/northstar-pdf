import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const reportPath = path.join(root, "benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json");
assert.ok(fs.existsSync(reportPath), "run the OCR comparison before validating its report");
const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));

assert.equal(report.contract, "pdf-editor.ocr-provider-comparison");
assert.deepEqual(report.version, { major: 1, minor: 0 });
assert.equal(report.measurements["local-tesseract"].cases.length, 6);
assert.equal(report.measurements["native-vision"].cases.length, 6);
assert.equal(report.measurements.preparationFailures.length, 0);

const tesseract = report.measurements["local-tesseract"];
const vision = report.measurements["native-vision"];
const browserWasm = report.measurements["browser-wasm-tesseract"];
assert.equal(tesseract.summary.latencyGate.passed, true);
assert.equal(vision.summary.latencyGate.passed, true);
assert.equal(tesseract.cases.every((record) => record.status === "measured"), true);
assert.equal(vision.cases.every((record) => record.status === "measured"), true);
assert.equal(browserWasm.cases.length, 6);
assert.equal(browserWasm.cases.every((record) => record.status === "measured"), true);

const tesseractNoisy = tesseract.cases.find((record) => record.fixtureId === "scanned-noisy");
const visionNoisy = vision.cases.find((record) => record.fixtureId === "scanned-noisy");
assert.ok(tesseractNoisy.anchorRecall < 0.66, "Tesseract noisy-scan miss must remain visible");
assert.ok(visionNoisy.anchorRecall >= 0.66, "Vision noisy-scan threshold should be met");
const browserNoisy = browserWasm.cases.find((record) => record.fixtureId === "scanned-noisy");
assert.ok(browserNoisy.anchorRecall < 0.66, "Browser WASM noisy-scan miss must remain visible");
const browserRotated = browserWasm.cases.find((record) => record.fixtureId === "rotated-hybrid-90-raster-page");
assert.ok(browserRotated.anchorRecall >= 0.66, "Browser WASM rotated threshold should be met");
assert.equal(browserWasm.cases.every((record) => record.coordinateSpace === "normalizedLowerLeft"), true);
assert.equal(browserWasm.cases.every((record) => record.boundsValidCount > 0), true);
assert.equal(browserWasm.cases.every((record) => record.boundsUnion != null), true);
assert.equal(browserWasm.cases.every((record) => record.confidenceMean == null || (record.confidenceMean >= 0 && record.confidenceMean <= 1)), true);
assert.equal(tesseract.cases.every((record) => record.confidenceMean == null || (record.confidenceMean >= 0 && record.confidenceMean <= 1)), true);
assert.equal(vision.cases.every((record) => record.confidenceMean == null || (record.confidenceMean >= 0 && record.confidenceMean <= 1)), true);

assert.equal(report.recovery.malformed.passed, true);
assert.equal(report.recovery.encrypted.passed, true);
assert.equal(report.recovery.large.passed, true);
assert.equal(report.recovery.companionCrashTimeoutRecovery, "not-measured-no-companion-installed");

assert.equal(report.privacy.sourceBytesLogged, false);
assert.equal(report.privacy.pageTextLogged, false);
assert.equal(report.privacy.ocrTextLogged, false);
assert.equal(report.privacy.groundTruthLogged, false);
assert.equal(report.privacy.passwordsLogged, false);
assert.equal(report.privacy.profileValuesLogged, false);
assert.equal(report.privacy.reportContainsContent, false);
assert.equal(report.privacy.browserWasmAssetsServedLocally, true);
assert.deepEqual(report.privacy.browserExternalNetworkRequests, []);
assert.equal(report.privacy.browserNetworkBoundaryPassed, true);
assert.equal(report.gates.privacy, true);
assert.equal(report.gates.promotionReady, false);
assert.equal(report.providers.find((provider) => provider.providerId === "companion-pdfbox").measurementStatus, "not-measured");
assert.equal(report.providers.find((provider) => provider.providerId === "companion-mupdf").defaultState, "quarantined");
assert.equal(report.companionCandidates.find((provider) => provider.providerId === "companion-mupdf").renderControl, "passed");
assert.equal(report.alignment.browserWasmVsVision.length, 6);
assert.equal(report.alignment.browserWasmVsVision.find((row) => row.fixtureId === "scanned-noisy").status, "divergent");

console.log(JSON.stringify({
  contract: report.contract,
  passed: true,
  checks: 17,
  tesseractMeanAnchorRecall: tesseract.summary.meanAnchorRecall,
  visionMeanAnchorRecall: vision.summary.meanAnchorRecall,
  tesseractMedianMilliseconds: tesseract.summary.latencyGate.medianMilliseconds,
  visionMedianMilliseconds: vision.summary.latencyGate.medianMilliseconds,
  browserWasmMeanAnchorRecall: browserWasm.summary.meanAnchorRecall,
  browserWasmMedianMilliseconds: browserWasm.summary.latencyGate.medianMilliseconds,
  browserWasmP95Milliseconds: browserWasm.summary.latencyGate.p95Milliseconds,
  malformedRecovery: report.recovery.malformed.passed,
  encryptedRecovery: report.recovery.encrypted.passed,
  largeRecovery: report.recovery.large.passed,
  companionRuntime: report.recovery.companionCrashTimeoutRecovery
}, null, 2));
