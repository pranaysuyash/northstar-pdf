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

function assertContained(rect, container, label) {
  const tolerance = 2;
  const detail = JSON.stringify({ rect, container });
  assert.ok(rect.left >= container.left - tolerance, `${label} left edge escaped page shell ${detail}`);
  assert.ok(rect.top >= container.top - tolerance, `${label} top edge escaped page shell ${detail}`);
  assert.ok(rect.right <= container.right + tolerance, `${label} right edge escaped page shell ${detail}`);
  assert.ok(rect.bottom <= container.bottom + tolerance, `${label} bottom edge escaped page shell ${detail}`);
}

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
  const row = page.locator("#candidateList .completion-item").filter({ hasText: "Character-entry region" }).first();
  await row.locator("button").click();
  await page.locator("#completionValue").fill("AB");
  await page.locator("#applyOverlayButton").click();
  await page.waitForFunction(() => document.querySelectorAll(".overlay-preview").length === 2);

  const modes = ["single", "continuous", "twoPage"];
  const observed = [];
  for (const viewMode of modes) {
    await page.locator("#viewMode").selectOption(viewMode);
    await page.locator("#fitMode").selectOption("fitWidth");
    for (let rotation = 0; rotation < 4; rotation += 1) {
      if (rotation > 0) await page.locator("#rotateR").click();
      await page.waitForTimeout(80);
      const geometry = await page.evaluate(() => [...document.querySelectorAll(".page-shell")].map((shell) => {
        const shellRect = shell.getBoundingClientRect();
        const shellBounds = { left: shellRect.left, top: shellRect.top, right: shellRect.right, bottom: shellRect.bottom };
        const previews = [...shell.querySelectorAll(".candidate-preview, .overlay-preview")].map((preview) => {
          const rect = preview.getBoundingClientRect();
          return { left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom };
        });
        return { shellBounds, previews };
      }));
      geometry.forEach((pageGeometry, pageIndex) => {
        pageGeometry.previews.forEach((preview, previewIndex) => {
          assertContained(preview, pageGeometry.shellBounds, `${viewMode} rotation ${rotation * 90} page ${pageIndex} preview ${previewIndex}`);
        });
      });
      observed.push({ viewMode, rotation: rotation * 90, pageCount: geometry.length, previewCount: geometry.reduce((sum, pageGeometry) => sum + pageGeometry.previews.length, 0) });
    }
  }
  await page.locator("#zoomSlider").fill("175");
  await page.waitForTimeout(80);
  const zoomPreviewCount = await page.locator(".overlay-preview").count();
  assert.equal(zoomPreviewCount, 2, "zoom must retain both per-cell overlays");
  assert.equal(observed.length, modes.length * 4);
  assert.ok(observed.every((entry) => entry.previewCount >= 2), "every view state must render the reviewed overlays");
  console.log(`web coordinate fidelity: ${observed.length} view states, rotations 0/90/180/270, zoom, and two-page containment passed`);
} finally {
  await browser.close();
}
