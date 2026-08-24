import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const fixture = path.join(projectRoot, "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(10_000);

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));

  const choiceRow = page.locator("#candidateList .completion-item").filter({ hasText: "Choice pattern" }).first();
  await choiceRow.locator("button").click();
  await page.waitForFunction(() => !document.querySelector("#choiceCellSelect")?.hidden);
  await page.locator("#choiceCellSelect").selectOption("0");
  await page.locator("#applyOverlayButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length >= 1);

  const textRow = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  await textRow.locator("button").click();
  await page.locator("#synthesizeFieldButton").click();
  assert.match(await page.locator("#editList").textContent(), /synthesizeNativeField/);

  const downloadPromise = page.waitForEvent("download");
  await page.locator("#exportButton").click();
  await downloadPromise;
  const validation = await page.locator("#validationBox").textContent();
  assert.match(validation, /Last export: validated/);
  assert.match(validation, /nativeFields/);
  assert.match(validation, /appliedOperations/);
  console.log("web static actions: reviewed choice mark, native-field synthesis, export, and reopen validation passed");
} finally {
  await browser.close();
}
