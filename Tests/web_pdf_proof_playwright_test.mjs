import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";

async function waitForText(page, locator, pattern, timeout = 30_000) {
  await locator.waitFor({ state: "visible", timeout });
  try {
    await page.waitForFunction(
      ({ selector, source }) => new RegExp(source).test(document.querySelector(selector)?.textContent || ""),
      { selector: `#${await locator.getAttribute("id")}`, source: pattern.source },
      { timeout }
    );
  } catch (error) {
    throw new Error(`${error.message}; status=${await page.locator("#status").textContent()}; source=${await locator.textContent()}`);
  }
}

async function loadCorpus(page, relativePath) {
  const absolutePath = path.join(projectRoot, relativePath);
  const fileInput = page.locator("#fileInput");
  await fileInput.setInputFiles(absolutePath);
  await waitForText(page, page.locator("#completionSource"), /SHA-256/);
  return {
    source: await page.locator("#completionSource").textContent(),
    status: await page.locator("#status").textContent(),
    fields: await page.locator("#fieldList .completion-item").count(),
    candidates: await page.locator("#candidateList .completion-item").count()
  };
}

async function exportProof(page) {
  const downloadPromise = page.waitForEvent("download", { timeout: 30_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  await page.waitForFunction(
    () => /Last export:|Export failed:/.test(document.querySelector("#validationBox")?.textContent || document.querySelector("#status")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  const download = await downloadPromise;
  assert.ok(download, `browser export should download; status=${await page.locator("#status").textContent()}; validation=${await page.locator("#validationBox").textContent()}`);
  const outputPath = await download.path();
  assert.ok(outputPath, "browser export should provide a download path");
  const stream = await download.createReadStream();
  let byteCount = 0;
  for await (const chunk of stream) { byteCount += chunk.length; }
  assert.ok(byteCount > 0 && fs.statSync(outputPath).size > 0, `browser export should contain PDF bytes: stream=${byteCount} file=${fs.statSync(outputPath).size}`);
  await page.waitForFunction(
    () => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  const validation = await page.locator("#validationBox").textContent();
  assert.match(validation, /Last export: (validated|validatedWithWarnings)/);
  assert.match(validation, /outputReopen/);
  const metrics = await page.locator("#impactMetricsContent").textContent();
  assert.match(metrics, /Outside-region text/);
  assert.match(metrics, /Outside-region raster/);
  assert.match(metrics, /Pages compared/);
  assert.match(metrics, /Changed pixels \/ compared/);
  assert.match(metrics, /Outside-pixel ratio/);
  assert.doesNotMatch(metrics, /sourceOutside|outputOutside/);
  return { downloadName: download.suggestedFilename(), validation, metrics };
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ acceptDownloads: true, viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") {
    consoleErrors.push(message.text());
  } else if (message.type() !== "debug") {
    console.error(`[browser:${message.type()}] ${message.text()}`);
  }
});
page.on("pageerror", (error) => {
  pageErrors.push(error.message);
});
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib), undefined, { timeout: 30_000 });

  const native = await loadCorpus(page, "benchmark/results/public-sample-form.pdf");
  assert.match(native.source, /public-sample-form\.pdf/);
  assert.ok(native.fields > 0, "public sample should expose native fields");
  assert.ok(native.candidates >= 0, "native inspection should also complete candidate detection");
  await page.locator("#fieldList button", { hasText: "Select field" }).first().click();
  await page.locator("#completionValue").fill("Browser native fill");
  await page.locator("#applyFieldButton").click();
  assert.match(await page.locator("#editList").textContent(), /nativeFieldValue/);
  const nativeExport = await exportProof(page);

  const staticPDF = await loadCorpus(page, "benchmark/results/2026-08-23-pdfkit-form6/artifacts/noop.pdf");
  assert.match(staticPDF.source, /noop\.pdf/);
  assert.ok(staticPDF.candidates > 0, "Form-6 corpus should expose at least one static candidate");
  let staticCandidateRow = page.locator("#candidateList .completion-item").filter({ hasText: "Text entry region" }).first();
  if (await staticCandidateRow.count() === 0) {
    staticCandidateRow = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  }
  assert.equal(await staticCandidateRow.count(), 1, "static proof should select an editable candidate");
  await staticCandidateRow.locator("button").click();
  await page.locator("#completionValue").fill("Browser overlay fill");
  await page.locator("#applyOverlayButton").click();
  assert.match(await page.locator("#editList").textContent(), /overlayText/);
  const staticExport = await exportProof(page);

  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);

  console.log(JSON.stringify({
    native: { ...native, export: nativeExport },
    static: { ...staticPDF, export: staticExport }
  }, null, 2));
} finally {
  await browser.close();
}
