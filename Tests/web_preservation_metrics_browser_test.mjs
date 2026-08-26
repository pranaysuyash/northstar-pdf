import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";

async function openPDF(page, relativePath, { requireCandidate = false } = {}) {
  await page.locator("#fileInput").setInputFiles(path.join(projectRoot, relativePath));
  await page.waitForFunction(
    () => /SHA-256/.test(document.querySelector("#completionSource")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  if (requireCandidate) {
    await page.waitForFunction(
      () => document.querySelectorAll("#candidateList .completion-item").length > 0,
      undefined,
      { timeout: 30_000 }
    );
  }
}

function assertNoContentMetrics(metrics) {
  assert.match(metrics, /Outside-region text/);
  assert.match(metrics, /Outside-region raster/);
  assert.match(metrics, /Pages changed outside region/);
  assert.match(metrics, /Changed pixels \/ compared/);
  assert.match(metrics, /Outside-pixel ratio/);
  assert.match(metrics, /Evidence basis/);
  assert.doesNotMatch(metrics, /sourceOutside|outputOutside/);
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ acceptDownloads: true, viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib), undefined, { timeout: 30_000 });

  await openPDF(page, "benchmark/results/public-sample-form.pdf");
  const passingDownload = page.waitForEvent("download", { timeout: 30_000 });
  await page.locator("#exportButton").click();
  await page.waitForFunction(() => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""), undefined, { timeout: 30_000 });
  const passingDownloadResult = await passingDownload;
  const passingMetrics = await page.locator("#impactMetricsContent").textContent();
  assert.match(await page.locator("#validationBox").textContent(), /Last export: validated/);
  assertNoContentMetrics(passingMetrics);
  assert.match(passingMetrics, /Source pages1Pages compared0/);
  assert.match(passingMetrics, /Changed pixels \/ compared0 \/ 0/);
  assert.match(passingMetrics, /source-digest-equality \/ source-digest-equality/);
  assert.ok(passingDownloadResult, "passing no-op should download");

  await openPDF(page, "benchmark/results/2026-08-23-pdfkit-form6/artifacts/noop.pdf", { requireCandidate: true });
  let candidateRow = page.locator("#candidateList .completion-item").filter({ hasText: "Text entry region" }).first();
  if (await candidateRow.count() === 0) {
    candidateRow = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  }
  assert.equal(await candidateRow.count(), 1, "static fixture should expose a reviewed candidate");
  await candidateRow.locator("button").click();
  await page.locator("#completionValue").fill("Browser overlay fill");
  await page.locator("#applyOverlayButton").click();
  const failedDownload = page.waitForEvent("download", { timeout: 2_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  await page.waitForFunction(() => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""), undefined, { timeout: 30_000 });
  const failedDownloadResult = await failedDownload;
  const failedMetrics = await page.locator("#impactMetricsContent").textContent();
  assert.match(await page.locator("#validationBox").textContent(), /Last export: failed/);
  assertNoContentMetrics(failedMetrics);
  assert.match(failedMetrics, /Statusfailed/);
  assert.match(failedMetrics, /Pages changed outside region1/);
  assert.match(failedMetrics, /Changed pixels \/ compared385 \/ 2,317,088/);
  assert.match(failedMetrics, /0\.0166%/);
  assert.match(failedMetrics, /1\.5x \/ 8/);
  assert.equal(failedDownloadResult, null, "failed preservation validation must withhold the export");

  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log(JSON.stringify({
    test: "web_preservation_metrics_browser",
    passing: { status: "validated", metrics: passingMetrics },
    failed: { status: "failed", metrics: failedMetrics, downloadWithheld: failedDownloadResult === null }
  }, null, 2));
} finally {
  await browser.close();
}
