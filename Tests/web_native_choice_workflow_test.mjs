import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const fixture = path.join(projectRoot, "benchmark/results/2026-08-23-pdfkit-widgets/native-widgets.pdf");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(10_000);

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  console.log(JSON.stringify(snapshot.document.payload.fields));
  assert.ok(snapshot.document.payload.fields.some((field) => field.kind === "button"));

  const consentRow = page.locator("#fieldList .completion-item").filter({ hasText: "consent" }).first();
  await consentRow.locator("button").click();
  await page.waitForFunction(() => document.querySelector("#fieldControl input[type=checkbox]") !== null);
  const consent = page.locator("#fieldControl input[type=checkbox]");
  await consent.check();
  await page.locator("#applyFieldButton").click();

  const statusRow = page.locator("#fieldList .completion-item").filter({ hasText: "status" }).first();
  await statusRow.locator("button").click();
  await page.waitForFunction(() => document.querySelector("#fieldControl select") !== null);
  const radioSelect = page.locator("#fieldControl select");
  assert.ok((await radioSelect.locator("option").count()) >= 2, "radio group should expose its export options");
  await radioSelect.selectOption({ index: 1 });
  await page.locator("#applyFieldButton").click();
  assert.match(await page.locator("#editList").textContent(), /nativeFieldValue/);
  console.log(JSON.stringify({ exportDisabled: await page.locator("#exportButton").isDisabled(), status: await page.locator("#status").textContent(), validation: await page.locator("#validationBox").textContent() }));

  const downloadPromise = page.waitForEvent("download");
  await page.locator("#exportButton").click();
  const download = await downloadPromise;
  const validation = await page.locator("#validationBox").textContent();
  assert.match(validation, /Last export: validated/);
  assert.match(validation, /nativeFields/);
  assert.ok((await download.suggestedFilename()).includes("web"));
  console.log("web native choice workflow: checkbox control, radio-group control, export, and reopen validation passed");
} finally {
  await browser.close();
}
