import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

let result;
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture?.runReviewedCorrectionBenchmark),
    undefined,
    { timeout: 30_000 }
  );
  result = await page.evaluate(async () => {
    const fixtures = (await import("/Tests/fixtures/template_matching_reviewed_fixtures.mjs")).REVIEWED_TEMPLATE_FIXTURES;
    const api = window.__pdfEditorContractFixture;
    const calibration = api.calibrateDocumentClassPolicies(fixtures);
    const report = api.runReviewedCorrectionBenchmark({ fixtures, calibration });
    return {
      passed: report.passed,
      fixtureCount: report.fixtureCount,
      reviewedTargetCoverageLift: report.improvement.reviewedTargetCoverageLift,
      selectedHardNegatives: report.hardNegativeAbstention.selectedCountAfterPromotion,
      rollback: report.rollback.passed,
      privacy: report.privacy.passed,
      abstentionRate: report.metrics.abstention.abstentionRate,
      hardNegativeFalsePositiveRate: report.metrics.hardNegative.falsePositiveRate,
      safeCompletionReadyRate: report.metrics.safeCompletion.safeCompletionReadyRate,
      silentAutofillCount: report.metrics.safeCompletion.silentAutofillCount,
      metricsPassed: report.metrics.passed
    };
  });
} finally {
  await browser.close();
}

assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
assert.deepEqual(result, {
  passed: true,
  fixtureCount: 5,
  reviewedTargetCoverageLift: 5,
  selectedHardNegatives: 0,
  rollback: true,
  privacy: true,
  abstentionRate: 1,
  hardNegativeFalsePositiveRate: 0,
  safeCompletionReadyRate: 1,
  silentAutofillCount: 0,
  metricsPassed: true
});

const report = {
  benchmark: "reviewed-template-correction-benefit-browser",
  baseURL,
  ...result,
  consoleErrors: consoleErrors.length,
  pageErrors: pageErrors.length
};
const outputPath = path.resolve(
  "benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json"
);
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({ ...report, outputPath }, null, 2));
