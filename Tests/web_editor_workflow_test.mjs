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
page.setDefaultTimeout(5_000);
page.on("pageerror", (error) => console.error(`[workflow:pageerror] ${error.message}`));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));

  let candidateRow = page.locator("#candidateList .completion-item").filter({ hasText: "Text entry region" }).first();
  if (await candidateRow.count() === 0) {
    candidateRow = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  }
  assert.equal(await candidateRow.count(), 1, "workflow should select an explicitly editable candidate");
  await candidateRow.locator("button").click();
  await page.waitForFunction(() => !document.querySelector("#candidateAction")?.hidden);
  await page.locator(".candidate-preview").first().waitFor();
  await page.locator(".candidate-preview.selected").first().waitFor();
  assert.ok(await page.locator(".candidate-preview.selected").count() > 0, "selected candidate should be highlighted on the page");

  await page.locator("#completionValue").fill("Reviewed value");
  await page.locator("#applyOverlayButton").click();
  assert.match(await page.locator("#editList").textContent(), /overlayText/);
  await page.locator(".overlay-preview").waitFor();
  assert.equal(await page.locator(".overlay-preview").count(), 1, "applied overlay should be visible in the page view");

  await page.locator(".overlay-preview").click();
  await page.locator("#completionValue").fill("Updated value");
  await page.locator("#applyOverlayButton").click();
  assert.match(await page.locator("#editList").textContent(), /Updated value/);

  await page.locator("#undoEditButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length === 0);
  assert.equal(await page.locator(".overlay-preview").count(), 0, "undo should remove the pending overlay preview");

  await page.locator("#dismissCandidateButton").click();
  assert.match(await page.locator("#restoreDismissedButton").textContent(), /Show dismissed \(1\)/);
  await page.locator("#restoreDismissedButton").click();
  const restoreCandidateButton = page.locator("#candidateList button").filter({ hasText: "Restore" }).first();
  assert.equal(await restoreCandidateButton.count(), 1);
  await restoreCandidateButton.click();

  await page.locator("#manualTextButton").click();
  assert.match(await page.locator("#status").textContent(), /Click the document/);
  await page.locator("#viewerStack .page-shell").first().click({ position: { x: 110, y: 110 } });
  await page.locator("#completionValue").fill("Manual value");
  await page.locator("#applyOverlayButton").click();
  assert.match(await page.locator("#editList").textContent(), /Manual value/);

  console.log("web editor workflow: highlight, apply, edit, undo, dismiss/restore, and manual placement passed");
} finally {
  await browser.close();
}
