import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { buildCalibrationReport, rectIoU } from "../web/detector-calibration.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const labelsPath = path.join(root, "benchmark/results/detector-calibration/detector_calibration_labels.json");
const labels = JSON.parse(fs.readFileSync(labelsPath, "utf8"));
const fixturePath = path.join(root, labels.fixture);
const nativeDirectory = path.join(root, "benchmark/results/detector-calibration/native");
const nativeBundlePath = path.join(nativeDirectory, "benchmark__results__detector-calibration__detector-calibration.json");
const reportPath = path.join(root, "benchmark/results/detector-calibration/detector-calibration-report.json");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4174/web/index.html";
const sourceDigest = crypto.createHash("sha256").update(fs.readFileSync(fixturePath)).digest("hex");

function findPositiveCandidate(caseLabel, candidates) {
  return candidates.findIndex((candidate) => (
    candidate.pageIndex === caseLabel.pageIndex && rectIoU(candidate.bounds, caseLabel.target) >= 0.25
  ));
}

function browserMutationReport(browserCandidates, mutation) {
  return buildCalibrationReport({
    labels,
    sourceDigest,
    nativeCandidates: nativeBundle?.candidates || [],
    browserCandidates,
    generatedAt: `2026-08-25T00:00:00.000Z-${mutation}`
  });
}

assert.equal(labels.sourceSha256, sourceDigest, "calibration labels must bind to exact fixture bytes");
fs.mkdirSync(nativeDirectory, { recursive: true });
execFileSync("swift", [
  "run", "PDFContractHarness",
  "--manifest", "docs/fixtures/detector-calibration-manifest.md",
  "--output-dir", "benchmark/results/detector-calibration/native"
], { cwd: root, stdio: "inherit" });
const nativeBundle = JSON.parse(fs.readFileSync(nativeBundlePath, "utf8"));
assert.equal(nativeBundle.sourceDigest, sourceDigest, "native source digest must match labels");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot), undefined, { timeout: 30_000 });
  await page.locator("#fileInput").setInputFiles(fixturePath);
  await page.waitForFunction((expected) => window.__pdfEditorContractFixture.snapshot()?.document?.payload?.source?.sha256 === expected, sourceDigest, { timeout: 30_000 });
  const browserSnapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  assert.equal(browserSnapshot.document.header.sourceDigest, sourceDigest, "browser source digest must match labels");
  const report = buildCalibrationReport({
    labels,
    sourceDigest,
    nativeCandidates: nativeBundle.candidates || [],
    browserCandidates: browserSnapshot.document.payload.candidates || [],
    generatedAt: "2026-08-25T00:00:00.000Z"
  });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  assert.equal(report.passed, true, `detector calibration failed: ${JSON.stringify(report, null, 2)}`);

  const browserCandidates = browserSnapshot.document.payload.candidates || [];
  const positiveCase = labels.cases.find((entry) => !entry.hardNegative);
  const positiveIndex = findPositiveCandidate(positiveCase, browserCandidates);
  assert.notEqual(positiveIndex, -1, `baseline must contain a candidate for ${positiveCase.id}`);

  const missingPositive = browserCandidates.filter((candidate) => (
    candidate.pageIndex !== positiveCase.pageIndex || rectIoU(candidate.bounds, positiveCase.target) < 0.05
  ));
  const missingPositiveReport = browserMutationReport(missingPositive, "remove-positive");
  assert.equal(missingPositiveReport.passed, false, "removing a reviewed positive must fail calibration");
  assert.ok(missingPositiveReport.adapters.browser.failureClusters.byCluster.noCandidateNearTarget,
    "positive removal must form a noCandidateNearTarget cluster");

  const hardNegative = labels.cases.find((entry) => entry.hardNegative);
  const promotedHardNegative = [
    ...browserCandidates,
    { ...browserCandidates[positiveIndex], pageIndex: hardNegative.pageIndex, bounds: hardNegative.target }
  ];
  const promotedHardNegativeReport = browserMutationReport(promotedHardNegative, "promote-hard-negative");
  assert.equal(promotedHardNegativeReport.passed, false, "promoting a hard negative must fail calibration");
  assert.ok(promotedHardNegativeReport.adapters.browser.failureClusters.byCluster.hardNegativePromotion,
    "hard-negative promotion must form a hardNegativePromotion cluster");

  const evidenceMismatch = browserCandidates.map((candidate) => (
    candidate.pageIndex === positiveCase.pageIndex && rectIoU(candidate.bounds, positiveCase.target) >= 0.05
      ? { ...candidate, evidenceItems: [] }
      : candidate
  ));
  const evidenceMismatchReport = browserMutationReport(evidenceMismatch, "strip-required-evidence");
  assert.equal(evidenceMismatchReport.passed, false, "stripping required evidence must fail calibration");
  assert.ok(evidenceMismatchReport.adapters.browser.failureClusters.byCluster.evidenceMismatch,
    "stripped evidence must form an evidenceMismatch cluster");

  console.log(JSON.stringify({
    passed: report.passed,
    reportPath: path.relative(root, reportPath),
    native: report.adapters.native.metrics,
    browser: report.adapters.browser.metrics,
    failureClusters: {
      native: report.adapters.native.failureClusters,
      browser: report.adapters.browser.failureClusters
    },
    mutationEvidence: [
      { mutation: "remove-positive", killed: !missingPositiveReport.passed, cluster: "noCandidateNearTarget" },
      { mutation: "promote-hard-negative", killed: !promotedHardNegativeReport.passed, cluster: "hardNegativePromotion" },
      { mutation: "strip-required-evidence", killed: !evidenceMismatchReport.passed, cluster: "evidenceMismatch" }
    ],
    mismatches: report.semanticParity.mismatches
  }, null, 2));
} finally {
  await browser.close();
}
