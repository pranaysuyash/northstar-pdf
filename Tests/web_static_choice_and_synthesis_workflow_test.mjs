import assert from "node:assert/strict";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

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
  const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const choiceIndex = snapshot.document.payload.candidates.findIndex((candidate) =>
    ["checkbox", "radioGroup"].includes(candidate.entryMode) && (candidate.memberBounds || []).length > 0);
  assert.ok(choiceIndex >= 0, "at least one grouped choice candidate should expose member cells");
  await page.locator("#candidateList .completion-item").nth(choiceIndex).locator("button").click();
  await page.waitForFunction(() => !document.querySelector("#choiceCellSelect")?.hidden);
  await page.locator("#choiceCellSelect").selectOption("0");
  await page.locator("#applyOverlayButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length >= 1);

  const downloadPromise = page.waitForEvent("download", { timeout: 15_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  const choiceDownload = await downloadPromise;
  assert.ok(choiceDownload, `static choice export did not download: ${await page.locator("#status").textContent()}`);
  assert.match(await page.locator("#validationBox").textContent(), /Last export: validated/);

  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  const form6Snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const textIndex = form6Snapshot.document.payload.candidates.findIndex((candidate) => candidate.entryMode === "characterGrid");
  assert.ok(textIndex >= 0, "the reviewed fixture should expose a character grid");
  const textRow = page.locator("#candidateList .completion-item").nth(textIndex);
  await textRow.locator("button").click();
  await page.locator("#synthesizeFieldButton").click();
  assert.match(await page.locator("#editList").textContent(), /synthesizeNativeField/);

  const form6DownloadPromise = page.waitForEvent("download", { timeout: 15_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  const download = await form6DownloadPromise;
  assert.ok(download, `native-field synthesis export did not download: ${await page.locator("#status").textContent()}`);
  const validation = await page.locator("#validationBox").textContent();
  assert.match(validation, /Last export: validated/);
  assert.match(validation, /nativeFields/);
  assert.match(validation, /appliedOperations/);
  console.log("web static actions: reviewed choice mark, native-field synthesis, export, and reopen validation passed");
} finally {
  await browser.close();
}
