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
  // index.html loads design-system.css asynchronously (rel=preload swap);
  // wait until it is parsed before making style assertions.
  await page.waitForFunction(() => {
    for (const sheet of document.styleSheets) {
      if ((sheet.href || "").includes("design-system.css")) {
        try {
          return sheet.cssRules.length > 50;
        } catch {
          return false;
        }
      }
    }
    return false;
  });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));

  const grouped = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot().document.payload.candidates
    .filter((candidate) => candidate.entryMode === "characterGrid"));
  assert.ok(grouped.length > 0, "the static Form 6 fixture should expose a grouped character region");
  assert.ok(grouped.some((candidate) => (candidate.memberBounds || []).length >= 3), "grouped candidate should retain cell bounds");

  // Form 6 has two sibling fields on the same baseline. They must remain
  // separate even though the PDF has no continuous horizontal rule between
  // them. The detector's cell-width signature and gap pattern are the
  // boundary evidence; a regression here recreates the oversized union.
  const geometryRows = grouped.filter((candidate) => candidate.pageIndex === 0);
  const firstNameRow = geometryRows.filter((candidate) => Math.abs(candidate.bounds.y - 604.49) <= 1);
  assert.equal(firstNameRow.length, 2, "the first-name baseline should split into two sibling character fields");
  assert.deepEqual(firstNameRow.map((candidate) => candidate.groupMemberCount).sort((a, b) => a - b), [11, 12], "sibling fields should retain their independent cell counts");
  const nameRow = geometryRows.filter((candidate) => Math.abs(candidate.bounds.y - 618.41) <= 1);
  assert.equal(nameRow.length, 1, "the name baseline should contain one editable field, not the adjacent photo cell");
  assert.equal(nameRow[0].groupMemberCount, 12, "the name field should exclude the photo-box cell");
  for (const candidate of [...firstNameRow, ...nameRow]) {
    const cells = candidate.memberBounds || [];
    const union = cells.reduce((bounds, cell) => ({
      x: Math.min(bounds.x, cell.x),
      y: Math.min(bounds.y, cell.y),
      maxX: Math.max(bounds.maxX, cell.x + cell.width),
      maxY: Math.max(bounds.maxY, cell.y + cell.height)
    }), { x: Infinity, y: Infinity, maxX: -Infinity, maxY: -Infinity });
    assert.ok(Math.abs(candidate.bounds.x - union.x) <= 0.01, "candidate left edge should equal its member-cell union");
    assert.ok(Math.abs(candidate.bounds.x + candidate.bounds.width - union.maxX) <= 0.01, "candidate right edge should equal its member-cell union");
  }

  await page.waitForSelector(".candidate-preview.character-grid");
  const groupedPreview = page.locator(".candidate-preview.character-grid").first();
  assert.ok(await groupedPreview.count() > 0, "character-grid candidates should render a dedicated preview boundary");
  assert.equal(await groupedPreview.evaluate((element) => getComputedStyle(element).backgroundColor), "rgba(0, 0, 0, 0)", "the grid union must not paint a solid block over PDF text");
  assert.equal(await groupedPreview.evaluate((element) => getComputedStyle(element).borderStyle), "dashed", "the grid union should be a boundary, not a filled region");
  assert.ok(await page.locator(".candidate-cell-tint").count() > 0, "character-grid candidates should expose per-cell tints");
  assert.ok(await groupedPreview.evaluate((element) => element.textContent === ""), "grid previews should not place labels over the PDF text");

  const groupedRow = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  await groupedRow.locator("button").click();
  await page.waitForFunction(() => !document.querySelector("#candidateAction")?.hidden);
  assert.match(await page.locator("#candidateActionDetail").textContent(), /Character-entry region/);

  await page.locator("#searchInput").fill("Application");
  await page.locator("#searchButton").click();
  await page.waitForSelector(".text-layer mark");
  const markBackground = await page.locator(".text-layer mark").first().evaluate((element) => getComputedStyle(element).backgroundColor);
  // The wash may be authored in rgba or oklch; what matters is that its
  // alpha stays low enough for the underlying PDF text to remain legible.
  const alphaMatch = markBackground.match(/\/\s*([\d.]+)\s*\)/) || markBackground.match(/,\s*([\d.]+)\)$/);
  const markAlpha = alphaMatch ? Number(alphaMatch[1]) : 1;
  assert.ok(markAlpha > 0 && markAlpha <= 0.3, `search highlight opacity should preserve the underlying PDF text (got ${markBackground})`);

  await page.locator("#completionValue").fill("AB");
  await page.locator("#applyOverlayButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length === 2);
  assert.equal(await page.locator(".overlay-preview").count(), 2, "each entered character should preview in its own cell");

  console.log("web character-grid workflow: grouped cell detection, per-cell preview, and bounded value entry passed");
} finally {
  await browser.close();
}
