import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import {
  buildDetectorSemanticComparisonReport,
  rectIoU
} from "../web/detector-semantic-comparison.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const labelsPath = path.join(root, "benchmark/results/detector-calibration/detector_calibration_labels.json");
const labels = JSON.parse(fs.readFileSync(labelsPath, "utf8"));
const fixturePath = path.join(root, labels.fixture);
const sourceDigest = crypto.createHash("sha256").update(fs.readFileSync(fixturePath)).digest("hex");
const nativeDirectory = path.join(root, "benchmark/results/detector-calibration/native");
const nativeBundlePath = path.join(nativeDirectory, "benchmark__results__detector-calibration__detector-calibration.json");
const reportPath = path.join(root, "benchmark/results/detector-calibration/detector-semantic-comparison-report.json");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4174/web/index.html";

function clone(value) {
  return structuredClone(value);
}

function candidatesForCase(caseLabel, candidates) {
  return candidates.filter((candidate) => (
    candidate.pageIndex === caseLabel.pageIndex
      && rectIoU(candidate.bounds, caseLabel.target) >= 0.25
  ));
}

function buildMutation(labelsForRun, nativeCandidates, browserCandidates) {
  return buildDetectorSemanticComparisonReport({
    labels: labelsForRun,
    sourceDigest,
    nativeCandidates,
    browserCandidates
  });
}

assert.equal(labels.sourceSha256, sourceDigest, "reviewed detector labels must bind to exact fixture bytes");
execFileSync("swift", [
  "run", "PDFContractHarness",
  "--manifest", "docs/fixtures/detector-calibration-manifest.md",
  "--output-dir", "benchmark/results/detector-calibration/native"
], { cwd: root, stdio: "inherit" });
const nativeBundle = JSON.parse(fs.readFileSync(nativeBundlePath, "utf8"));
assert.equal(nativeBundle.sourceDigest, sourceDigest, "native detector output must bind to reviewed fixture bytes");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot), undefined, { timeout: 30_000 });
  await page.locator("#fileInput").setInputFiles(fixturePath);
  await page.waitForFunction(
    (expected) => window.__pdfEditorContractFixture.snapshot()?.document?.payload?.source?.sha256 === expected,
    sourceDigest,
    { timeout: 30_000 }
  );
  const browserSnapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const nativeCandidates = nativeBundle.candidates || [];
  const browserCandidates = browserSnapshot.document.payload.candidates || [];
  const report = buildDetectorSemanticComparisonReport({
    labels,
    sourceDigest,
    nativeCandidates,
    browserCandidates
  });
  fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

  assert.equal(report.passed, true, `detector semantic comparison failed: ${JSON.stringify(report, null, 2)}`);
  assert.equal(report.reviewedRegionCount, labels.cases.length);
  assert.equal(report.adapters.native.metrics.precision, 1);
  assert.equal(report.adapters.native.metrics.recall, 1);
  assert.equal(report.adapters.browser.metrics.precision, 1);
  assert.equal(report.adapters.browser.metrics.recall, 1);
  assert.equal(report.adapters.native.metrics.correctAbstentionRate, 1);
  assert.equal(report.adapters.browser.metrics.correctAbstentionRate, 1);
  assert.equal(report.adapters.native.metrics.falsePositiveSeverityBurden, 0);
  assert.equal(report.adapters.browser.metrics.falsePositiveSeverityBurden, 0);
  assert.equal(report.semanticParity.passed, true);

  const positiveCase = labels.cases.find((entry) => entry.id === "p0-vector-rectangle");
  const hardNegativeCase = labels.cases.find((entry) => entry.id === "p1-isolated-square");
  const positiveCandidates = candidatesForCase(positiveCase, browserCandidates);
  assert.ok(positiveCandidates.length > 0, "baseline must contain the reviewed positive region");

  const removedPositive = browserCandidates.filter((candidate) => !positiveCandidates.includes(candidate));
  const removedReport = buildMutation(labels, nativeCandidates, removedPositive);
  assert.equal(removedReport.passed, false, "removing a reviewed region must fail");
  assert.ok(removedReport.adapters.browser.failureClusters.reviewedRegionMiss);

  const promotedHardNegative = [
    ...browserCandidates,
    { ...clone(positiveCandidates[0]), pageIndex: hardNegativeCase.pageIndex, bounds: hardNegativeCase.target }
  ];
  const promotedReport = buildMutation(labels, nativeCandidates, promotedHardNegative);
  assert.equal(promotedReport.passed, false, "promoting a hard negative must fail");
  assert.equal(promotedReport.adapters.browser.metrics.falsePositive, 1);
  assert.equal(promotedReport.adapters.browser.metrics.falsePositiveSeverityBurden, 9);
  assert.ok(promotedReport.adapters.browser.failureClusters.falsePositive);

  const strippedEvidence = browserCandidates.map((candidate) => (
    positiveCandidates.includes(candidate)
      ? { ...clone(candidate), evidenceItems: candidate.evidenceItems.filter((item) => item.kind === "vectorRectangle") }
      : candidate
  ));
  const evidenceReport = buildMutation(labels, nativeCandidates, strippedEvidence);
  assert.equal(evidenceReport.passed, false, "stripping evidence families must fail");
  assert.ok(evidenceReport.adapters.browser.failureClusters.evidenceFamilyMismatch);

  const strippedLabel = browserCandidates.map((candidate) => (
    positiveCandidates.includes(candidate)
      ? { ...clone(candidate), labelText: undefined, evidenceItems: candidate.evidenceItems.filter((item) => !["textLabel", "spatialRelationship"].includes(item.kind)) }
      : candidate
  ));
  const labelReport = buildMutation(labels, nativeCandidates, strippedLabel);
  assert.equal(labelReport.passed, false, "stripping label association must fail");
  assert.ok(labelReport.adapters.browser.failureClusters.labelAssociationMismatch);

  const splitGrouping = browserCandidates.map((candidate) => (
    positiveCandidates.includes(candidate)
      ? { ...candidate, groupMemberCount: 2 }
      : candidate
  ));
  const groupingReport = buildMutation(labels, nativeCandidates, splitGrouping);
  assert.equal(groupingReport.passed, false, "grouping drift must fail");
  assert.ok(groupingReport.adapters.browser.failureClusters.groupingMismatch);

  const reportText = fs.readFileSync(reportPath, "utf8");
  assert.equal(reportText.includes("Applicant Name"), false, "reviewed labels must not leak into report");
  assert.equal(reportText.includes('"labelText"'), false, "candidate labels must not enter report");
  assert.equal(reportText.includes('"text":'), false, "evidence prose must not enter report");
  assert.equal(reportText.includes('"id": "5CA84DCC'), false, "provider evidence IDs must not enter report");

  console.log(JSON.stringify({
    reportPath: path.relative(root, reportPath),
    reviewedRegionCount: report.reviewedRegionCount,
    nativeMetrics: report.adapters.native.metrics,
    browserMetrics: report.adapters.browser.metrics,
    semanticParity: report.semanticParity,
    mutationEvidence: [
      { mutation: "remove-reviewed-region", killed: !removedReport.passed, cluster: "reviewedRegionMiss" },
      { mutation: "promote-high-severity-negative", killed: !promotedReport.passed, cluster: "falsePositive" },
      { mutation: "strip-evidence-family", killed: !evidenceReport.passed, cluster: "evidenceFamilyMismatch" },
      { mutation: "break-label-association", killed: !labelReport.passed, cluster: "labelAssociationMismatch" },
      { mutation: "split-group", killed: !groupingReport.passed, cluster: "groupingMismatch" }
    ]
  }, null, 2));
} finally {
  await browser.close();
}
