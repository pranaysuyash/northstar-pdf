import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";
import { compareIndependentPreservation, independentViewerReopen } from "../benchmark/independent-preservation-validator.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const sourceRelativePath = "benchmark/results/public-sample-form.pdf";
const sourcePath = path.join(projectRoot, sourceRelativePath);
const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-independent-test-"));
const outputPath = path.join(tempDirectory, "reviewed-output.pdf");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ acceptDownloads: true, viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.locator("#fileInput").setInputFiles(sourcePath);
  await page.waitForFunction(
    (expected) => window.__pdfEditorContractFixture?.snapshot?.()?.document?.payload?.source?.sha256 === expected,
    "5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8",
    { timeout: 30_000 }
  );
  await page.locator("#fieldList button").first().click();
  await page.locator("#completionValue").fill("Independent viewer mutation");
  await page.locator("#applyFieldButton").click();
  const downloadPromise = page.waitForEvent("download", { timeout: 30_000 });
  await page.locator("#exportButton").click();
  await page.waitForFunction(() => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""), undefined, { timeout: 30_000 });
  const download = await downloadPromise;
  await download.saveAs(outputPath);
  const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const operations = snapshot.editSession.operations;
  assert.equal(operations.length, 1, "the mutation fixture should contain one reviewed operation");

  const unauthorized = compareIndependentPreservation({ sourcePath, outputPath });
  const authorized = compareIndependentPreservation({ sourcePath, outputPath, operations });
  assert.equal(unauthorized.text.status, "failed", "independent text diff must reject an unauthorized mutation");
  assert.equal(unauthorized.raster.status, "failed", "independent raster diff must reject an unauthorized mutation");
  assert.equal(authorized.text.status, "passed", "independent text diff must pass inside the reviewed region");
  assert.equal(authorized.raster.status, "passed", "independent raster diff must pass inside the reviewed region");
  assert.equal(authorized.outputReopen.status, "passed", "Poppler must reopen the reviewed export");

  const rotatedWidget = independentViewerReopen({
    filePath: path.join(projectRoot, "benchmark/results/rotation-corpus/rotated-widget-90.pdf")
  });
  const rotatedForm = independentViewerReopen({
    filePath: path.join(projectRoot, "benchmark/results/rotation-corpus/rotated-form6-mixed.pdf")
  });
  assert.equal(rotatedWidget.reopen.status, "passed");
  assert.deepEqual(rotatedWidget.reopen.pageFacts.pages.map((page) => page.rotation), [90]);
  assert.equal(rotatedForm.reopen.status, "passed");
  assert.deepEqual(rotatedForm.reopen.pageFacts.pages.map((page) => page.rotation), [90, 180]);
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);

  console.log(JSON.stringify({
    test: "pdf_independent_preservation",
    sourcePath: sourceRelativePath,
    unauthorized: { text: unauthorized.text.status, raster: unauthorized.raster.status },
    authorized: { text: authorized.text.status, raster: authorized.raster.status, reopen: authorized.outputReopen.status },
    rotatedFixtures: {
      widget90: rotatedWidget.reopen.pageFacts.pages.map((page) => page.rotation),
      formMixed: rotatedForm.reopen.pageFacts.pages.map((page) => page.rotation)
    }
  }, null, 2));
} finally {
  await browser.close();
  fs.rmSync(tempDirectory, { recursive: true, force: true });
}
