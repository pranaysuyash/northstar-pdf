import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";
import { compareIndependentPreservation } from "../benchmark/independent-preservation-validator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4184/web/index.html";
const sourcePath = path.join(root, "benchmark/results/rotation-corpus/rotated-widget-90.pdf");
const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-rotated-crop-replay-"));
const cropSourcePath = path.join(tempDirectory, "rotated-crop-offset.pdf");
const outputPath = path.join(tempDirectory, "rotated-crop-overlay.pdf");

execFileSync("python3", ["-c", [
  "import pikepdf, sys",
  "p = pikepdf.open(sys.argv[1])",
  "pg = p.pages[0]",
  "pg.MediaBox = pikepdf.Array([0, 0, 720, 900])",
  "pg.CropBox = pikepdf.Array([12, 18, 624, 810])",
  "p.save(sys.argv[2])"
].join(";"), sourcePath, cropSourcePath]);

async function load(page) {
  const runtimeURL = new URL(baseURL);
  runtimeURL.searchParams.set("proof", `rotated-${Date.now()}-${Math.random()}`);
  await page.goto(runtimeURL.toString(), { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot));
  await page.locator("#fileInput").setInputFiles(cropSourcePath);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
try {
  const inspectPage = await browser.newPage({ acceptDownloads: true });
  await load(inspectPage);
  const inspected = await inspectPage.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const pageFacts = inspected.document.payload.pages[0];
  assert.equal(pageFacts.rotation, 90);
  assert.deepEqual(pageFacts.cropBox, { x: 12, y: 18, width: 612, height: 792 });
  assert.equal(pageFacts.bounds.width, 612);
  assert.equal(pageFacts.bounds.height, 792);
  await inspectPage.close();

  const nativePage = await browser.newPage({ acceptDownloads: true });
  await load(nativePage);
  await nativePage.locator("#fieldList button").first().click();
  await nativePage.locator("#completionValue").fill("Grace Hopper");
  await nativePage.locator("#applyFieldButton").click();
  await nativePage.locator("#exportButton").click();
  await nativePage.waitForTimeout(1_000);
  const nativeValidation = await nativePage.evaluate(() => window.__pdfEditorContractFixture.snapshot().validation);
  assert.equal(nativeValidation.status, "failed");
  assert.match(nativeValidation.messages.join(" "), /no form field with the name/i);
  await nativePage.close();

  const overlayPage = await browser.newPage({ acceptDownloads: true });
  await load(overlayPage);
  await overlayPage.locator("#manualTextButton").click();
  const canvas = overlayPage.locator(".page-shell canvas").first();
  const canvasBox = await canvas.boundingBox();
  assert.ok(canvasBox, "rotated crop fixture must render a page canvas");
  await overlayPage.mouse.click(canvasBox.x + canvasBox.width * 0.35, canvasBox.y + canvasBox.height * 0.35);
  await overlayPage.locator("#completionValue").fill("ROTATED");
  await overlayPage.locator("#applyOverlayButton").click();
  const snapshot = await overlayPage.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const operation = snapshot.editSession.operations[0];
  assert.equal(operation.kind, "overlayText");
  assert.equal(operation.coordinate.coordinateSpace.rotationDegrees, 90);
  assert.equal(operation.coordinate.coordinateSpace.pageBox, "crop");
  assert.equal(operation.coordinate.rect.x >= 0, true);
  assert.equal(operation.coordinate.rect.y >= 0, true);

  const downloadPromise = overlayPage.waitForEvent("download", { timeout: 30_000 });
  await overlayPage.locator("#exportButton").click();
  const download = await downloadPromise;
  await download.saveAs(outputPath);
  await overlayPage.waitForFunction(() => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""));
  const exportedSnapshot = await overlayPage.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  assert.equal(exportedSnapshot.validation.status, "validated");
  const independent = compareIndependentPreservation({
    sourcePath: cropSourcePath,
    outputPath,
    operations: exportedSnapshot.editSession.operations
  });
  console.log("independent-debug", JSON.stringify({ text: independent.text, raster: independent.raster, reopen: independent.outputReopen }, null, 2));
  assert.equal(independent.text.status, "passed");
  assert.equal(independent.raster.status, "passed");
  assert.equal(independent.outputReopen.status, "passed");
  console.log(JSON.stringify({
    test: "rotated_operation_replay",
    page: { rotation: pageFacts.rotation, cropBox: pageFacts.cropBox },
    nativeFieldExport: nativeValidation.status,
    overlayOperation: { kind: operation.kind, coordinate: operation.coordinate },
    independent: { text: independent.text.status, raster: independent.raster.status, reopen: independent.outputReopen.status }
  }, null, 2));
} finally {
  await browser.close();
  fs.rmSync(tempDirectory, { recursive: true, force: true });
}
