import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { chromium } from "playwright";
import {
  IHATEPDF_EXPERIMENT_LEDGER_VERSION,
  projectBrowserIhatepdfParity,
  runIhatepdfExperimentParity,
  validateIhatepdfExperimentLedger
} from "../web/ihatepdf-experiment-contract.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const ledgerPath = path.join(projectRoot, "Tests/fixtures/ihatepdf_experiment_ledger.json");
const outputDirectory = path.join(projectRoot, "benchmark/results/ihatepdf-experiments");
const nativePath = path.join(outputDirectory, "2026-08-24-native-parity.json");
const browserPath = path.join(outputDirectory, "2026-08-24-browser-parity.json");
const reportPath = path.join(outputDirectory, "2026-08-24-semantic-parity-report.json");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";

const ledger = JSON.parse(fs.readFileSync(ledgerPath, "utf8"));
const sourceDigests = {};
for (const parityCase of ledger.parityCases) {
  const sourcePath = path.join(projectRoot, parityCase.sourceFixture);
  sourceDigests[parityCase.sourceFixture] = crypto.createHash("sha256").update(fs.readFileSync(sourcePath)).digest("hex");
}

assert.deepEqual(validateIhatepdfExperimentLedger(ledger), { passed: true, errors: [] });
assert.deepEqual(IHATEPDF_EXPERIMENT_LEDGER_VERSION, { major: 1, minor: 0 });
assert.equal(ledger.entries.length, 6);
assert.equal(ledger.parityCases.length, 6);

const mutations = [
  {
    name: "missing-falsifier",
    mutate(candidate) { delete candidate.entries[0].falsifier; },
    expectedError: "E-001.evidenceFields"
  },
  {
    name: "coordinate-origin-mismatch",
    mutate(candidate) { candidate.parityCases[1].coordinate.origin = "upperLeft"; },
    expectedError: "E-002.caseCoordinate"
  },
  {
    name: "unbound-source",
    mutate(candidate) { candidate.parityCases[2].expected.sourceBound = false; },
    expectedError: "E-003.sourceBinding"
  },
  {
    name: "operation-kind-drift",
    mutate(candidate) { candidate.entries[3].operationKind = "overlayText"; },
    expectedError: "E-004.operationKind"
  }
];
for (const mutation of mutations) {
  const candidate = structuredClone(ledger);
  mutation.mutate(candidate);
  const result = validateIhatepdfExperimentLedger(candidate);
  assert.equal(result.passed, false, `${mutation.name} must be rejected`);
  assert.ok(result.errors.includes(mutation.expectedError), `${mutation.name} must report ${mutation.expectedError}`);
}

const native = (() => {
  execFileSync("swift", [
    "run",
    "PDFExperimentParityHarness",
    "--ledger",
    "Tests/fixtures/ihatepdf_experiment_ledger.json",
    "--output",
    "benchmark/results/ihatepdf-experiments/2026-08-24-native-parity.json"
  ], { cwd: projectRoot, stdio: "inherit" });
  return JSON.parse(fs.readFileSync(nativePath, "utf8"));
})();
assert.equal(native.passed, true);
assert.equal(native.caseCount, 6);

const browserAdapterProjection = projectBrowserIhatepdfParity({ ledger, sourceDigests });
const browserAdapterReport = runIhatepdfExperimentParity({ ledger, sourceDigests });
assert.equal(browserAdapterReport.passed, true);
assert.equal(browserAdapterProjection.length, 6);

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));
let browserReport;
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture?.runIhatepdfExperimentParity),
    undefined,
    { timeout: 30_000 }
  );
  browserReport = await page.evaluate(({ inputLedger, inputDigests }) => (
    window.__pdfEditorContractFixture.runIhatepdfExperimentParity({
      ledger: inputLedger,
      sourceDigests: inputDigests
    })
  ), { inputLedger: ledger, inputDigests: sourceDigests });
} finally {
  await browser.close();
}
assert.deepEqual(consoleErrors, []);
assert.deepEqual(pageErrors, []);
assert.equal(browserReport.passed, true);
assert.equal(browserReport.caseCount, 6);

function parityProjection(entry) {
  return {
    id: entry.id,
    experimentID: entry.experimentID,
    sourceFixture: entry.sourceFixture,
    sourceDigest: entry.sourceDigest,
    operationKind: entry.operationKind,
    coordinate: entry.coordinate,
    executionState: entry.executionState,
    sourceBound: entry.sourceBound,
    reviewRequired: entry.reviewRequired,
    abstainIfUnsupported: entry.abstainIfUnsupported,
    privacyClass: entry.privacyClass,
    validationKinds: [...entry.validationKinds].sort(),
    ledgerVersion: entry.ledgerVersion,
    semanticParity: entry.semanticParity
  };
}

const nativeByID = new Map(native.cases.map((entry) => [entry.id, entry]));
const browserByID = new Map(browserReport.cases.map((entry) => [entry.id, entry]));
const cases = ledger.parityCases.map((parityCase) => {
  const nativeCase = nativeByID.get(parityCase.id);
  const browserCase = browserByID.get(parityCase.id);
  assert.ok(nativeCase, `native case missing: ${parityCase.id}`);
  assert.ok(browserCase, `browser case missing: ${parityCase.id}`);
  const nativeProjection = parityProjection(nativeCase);
  const browserProjection = parityProjection(browserCase);
  const mismatches = isDeepStrictEqual(nativeProjection, browserProjection)
    ? []
    : [{ native: nativeProjection, browser: browserProjection }];
  return {
    id: parityCase.id,
    experimentID: parityCase.experimentID,
    sourceFixture: parityCase.sourceFixture,
    mismatchCount: mismatches.length,
    mismatches
  };
});
const report = {
  harness: "pdf-editor-native-browser-ihatepdf-experiment-semantic-parity",
  version: IHATEPDF_EXPERIMENT_LEDGER_VERSION,
  ledgerPath: path.relative(projectRoot, ledgerPath),
  sourceDocument: ledger.sourceDocument,
  entryCount: ledger.entries.length,
  caseCount: cases.length,
  passed: cases.every((entry) => entry.mismatchCount === 0),
  mutationCount: mutations.length,
  mutationsKilled: mutations.length,
  browser: { baseURL, consoleErrors, pageErrors },
  cases
};
fs.mkdirSync(outputDirectory, { recursive: true });
fs.writeFileSync(nativePath, `${JSON.stringify(native, null, 2)}\n`);
fs.writeFileSync(browserPath, `${JSON.stringify(browserReport, null, 2)}\n`);
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
assert.equal(report.passed, true, JSON.stringify(report, null, 2));
console.log(JSON.stringify({
  harness: report.harness,
  ledgerVersion: report.version,
  entryCount: report.entryCount,
  caseCount: report.caseCount,
  passed: report.passed,
  mutationsKilled: report.mutationsKilled,
  reportPath: path.relative(projectRoot, reportPath)
}, null, 2));
