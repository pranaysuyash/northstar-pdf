import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { chromium } from "playwright";
import { compareIndependentPreservation } from "../benchmark/independent-preservation-validator.mjs";
import { pdfPython } from "./pdf-python.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const baseURL = (() => {
  const u = process.env.PDF_EDITOR_BASE_URL;
  if (!u) { console.error("FATAL: PDF_EDITOR_BASE_URL not set. Start a local server or set the env var."); process.exit(1); }
  return u;
})();
const sourcePath = path.join(root, "benchmark/results/rotation-corpus/rotated-widget-90.pdf");
const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-rotated-crop-replay-"));
const scenarios = [
  {
    id: "rotated-90-crop-offset",
    rotation: 90,
    mediaBox: [0, 0, 720, 900],
    cropBox: [12, 18, 624, 810]
  },
  {
    id: "rotated-180-crop-offset",
    rotation: 180,
    mediaBox: [0, 0, 720, 900],
    cropBox: [24, 30, 636, 822]
  },
  {
    id: "rotated-270-zero-offset",
    rotation: 270,
    mediaBox: [0, 0, 612, 792],
    cropBox: [0, 0, 612, 792]
  }
].map((scenario) => ({
  ...scenario,
  sourcePath: path.join(tempDirectory, `${scenario.id}.pdf`),
  outputPath: path.join(tempDirectory, `${scenario.id}-output.pdf`)
}));

for (const scenario of scenarios) {
  execFileSync(pdfPython, ["-c", [
    "import pikepdf, sys",
    "p = pikepdf.open(sys.argv[1])",
    "pg = p.pages[0]",
    "pg.MediaBox = pikepdf.Array([float(v) for v in sys.argv[3].split(',')])",
    "pg.CropBox = pikepdf.Array([float(v) for v in sys.argv[4].split(',')])",
    "pg.Rotate = int(sys.argv[5])",
    "p.save(sys.argv[2])"
  ].join(";"), sourcePath, scenario.sourcePath, scenario.mediaBox.join(","), scenario.cropBox.join(","), String(scenario.rotation)]);
}

async function load(page, source) {
  const runtimeURL = new URL(baseURL);
  runtimeURL.searchParams.set("proof", `rotated-${Date.now()}-${Math.random()}`);
  await page.goto(runtimeURL.toString(), { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot));
  await page.locator("#fileInput").setInputFiles(source);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
}

async function replayReviewedOverlay(browser, scenario) {
  const page = await browser.newPage({ acceptDownloads: true });
  try {
    await load(page, scenario.sourcePath);
    const inspected = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
    const pageFacts = inspected.document.payload.pages[0];
    assert.equal(pageFacts.rotation, scenario.rotation);
    assert.deepEqual(pageFacts.cropBox, {
      x: scenario.cropBox[0],
      y: scenario.cropBox[1],
      width: scenario.cropBox[2] - scenario.cropBox[0],
      height: scenario.cropBox[3] - scenario.cropBox[1]
    });

    await page.locator("#manualTextButton").click();
    const canvas = page.locator(".page-shell canvas").first();
    const canvasBox = await canvas.boundingBox();
    assert.ok(canvasBox, `${scenario.id} must render a page canvas`);
    await page.mouse.click(canvasBox.x + canvasBox.width * 0.35, canvasBox.y + canvasBox.height * 0.35);
    await page.locator("#completionValue").fill(`ROTATED-${scenario.rotation}`);
    await page.locator("#applyOverlayButton").click();

    const reviewed = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
    const operation = reviewed.editSession.operations[0];
    assert.equal(operation.kind, "overlayText");
    assert.equal(operation.coordinate.coordinateSpace.rotationDegrees, scenario.rotation);
    assert.equal(operation.coordinate.coordinateSpace.pageBox, "crop");
    assert.equal(operation.coordinate.pageIndex, 0);
    assert.ok(operation.bounds.width > 0 && operation.bounds.height > 0);
    assert.ok(operation.bounds.x >= 0 && operation.bounds.y >= 0);
    assert.ok(
      operation.bounds.x + operation.bounds.width <= pageFacts.cropBox.width + 0.01,
      `${scenario.id} operation must remain inside crop-box-relative width`
    );
    assert.ok(
      operation.bounds.y + operation.bounds.height <= pageFacts.cropBox.height + 0.01,
      `${scenario.id} operation must remain inside crop-box-relative height`
    );

    const downloadPromise = page.waitForEvent("download", { timeout: 30_000 }).catch(() => null);
    await page.locator("#exportButton").click();
    const download = await downloadPromise;
    await page.waitForFunction(() => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""));
    const exported = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
    assert.ok(download, `${scenario.id} should publish a validated export: ${JSON.stringify(exported.validation)}`);
    await download.saveAs(scenario.outputPath);
    assert.equal(exported.validation.status, "validated", `${scenario.id} should validate after reopen`);
    for (const kind of ["outputReopen", "privacyPreflight", "outsideRegionText", "visualDiff"]) {
      const check = exported.validation.checks.find((entry) => entry.kind === kind);
      assert.equal(check?.status, "passed", `${scenario.id} ${kind} should pass`);
    }

    const independent = compareIndependentPreservation({
      sourcePath: scenario.sourcePath,
      outputPath: scenario.outputPath,
      operations: exported.editSession.operations
    });
    assert.equal(independent.text.status, "passed", `${scenario.id} independent text preservation should pass: ${JSON.stringify(independent.text)}`);
    assert.equal(independent.raster.status, "passed", `${scenario.id} independent raster preservation should pass: ${JSON.stringify(independent.raster)}`);
    assert.equal(independent.outputReopen.status, "passed", `${scenario.id} independent reopen should pass: ${JSON.stringify(independent.outputReopen)}`);
    return {
      rotation: scenario.rotation,
      cropBox: pageFacts.cropBox,
      operation: {
        kind: operation.kind,
        coordinate: operation.coordinate,
        bounds: operation.bounds
      },
      browser: {
        reopen: "passed",
        privacyPreflight: "passed",
        outsideRegionText: "passed",
        visualDiff: "passed"
      },
      independent: {
        text: independent.text.status,
        raster: independent.raster.status,
        reopen: independent.outputReopen.status
      }
    };
  } finally {
    await page.close();
  }
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
try {
  const results = [];
  for (const scenario of scenarios) {
    results.push(await replayReviewedOverlay(browser, scenario));
  }
  console.log(JSON.stringify({
    test: "rotated_operation_replay",
    scenarios: results
  }, null, 2));
} finally {
  await browser.close();
  fs.rmSync(tempDirectory, { recursive: true, force: true });
}
