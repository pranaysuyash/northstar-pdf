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

  const grouped = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot().document.payload.candidates
    .filter((candidate) => candidate.entryMode === "characterGrid"));
  assert.ok(grouped.length > 0, "the static Form 6 fixture should expose a grouped character region");
  assert.ok(grouped.some((candidate) => (candidate.memberBounds || []).length >= 3), "grouped candidate should retain cell bounds");

  const groupedRow = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  await groupedRow.locator("button").click();
  await page.waitForFunction(() => !document.querySelector("#candidateAction")?.hidden);
  assert.match(await page.locator("#candidateActionDetail").textContent(), /Character-entry region/);

  await page.locator("#completionValue").fill("AB");
  await page.locator("#applyOverlayButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length === 2);
  assert.equal(await page.locator(".overlay-preview").count(), 2, "each entered character should preview in its own cell");

  console.log("web character-grid workflow: grouped cell detection, per-cell preview, and bounded value entry passed");
} finally {
  await browser.close();
}
