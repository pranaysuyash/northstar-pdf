import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const sourceRelativePath = "benchmark/results/public-sample-form.pdf";
const sourcePath = path.join(projectRoot, sourceRelativePath);
assert.equal(fs.existsSync(sourcePath), true, "impact validator source fixture should exist");
const sourceBase64 = fs.readFileSync(sourcePath).toString("base64");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib), undefined, { timeout: 30_000 });
  const result = await page.evaluate(async (encodedSource) => {
    const { compareOutsideRegions } = await import("/web/pdf-impact-validator.mjs");
    const binary = atob(encodedSource);
    const sourceBytes = Uint8Array.from(binary, (character) => character.charCodeAt(0)).buffer;
    const sourceDocument = await window.pdfjsLib.getDocument({ data: new Uint8Array(sourceBytes.slice(0)) }).promise;

    const noOp = await compareOutsideRegions({
      pdfjsLib: window.pdfjsLib,
      sourceDocument,
      outputDocument: sourceDocument,
      operations: []
    });

    const writer = await window.PDFLib.PDFDocument.load(sourceBytes.slice(0));
    writer.getPages()[0].drawText("OUTSIDE MUTATION", { x: 72, y: 120, size: 18 });
    const mutatedBytes = await writer.save();
    const mutatedDocument = await window.pdfjsLib.getDocument({ data: mutatedBytes }).promise;

    const unauthorizedMutation = await compareOutsideRegions({
      pdfjsLib: window.pdfjsLib,
      sourceDocument,
      outputDocument: mutatedDocument,
      operations: []
    });

    const authorizedMutation = await compareOutsideRegions({
      pdfjsLib: window.pdfjsLib,
      sourceDocument,
      outputDocument: mutatedDocument,
      operations: [{
        id: "authorized-overlay",
        pageIndex: 0,
        coordinate: {
          pageIndex: 0,
          rect: { x: 60, y: 105, width: 250, height: 50 }
        }
      }]
    });

    const missingCoordinate = await compareOutsideRegions({
      pdfjsLib: window.pdfjsLib,
      sourceDocument,
      outputDocument: mutatedDocument,
      operations: [{ id: "missing-coordinate", pageIndex: 0 }]
    });

    const mismatchedCoordinate = await compareOutsideRegions({
      pdfjsLib: window.pdfjsLib,
      sourceDocument,
      outputDocument: mutatedDocument,
      operations: [{
        id: "mismatched-coordinate",
        pageIndex: 0,
        coordinate: {
          pageIndex: 1,
          rect: { x: 60, y: 105, width: 250, height: 50 }
        }
      }]
    });

    return {
      noOp: { text: noOp.text.status, raster: noOp.raster.status },
      unauthorizedMutation: { text: unauthorizedMutation.text.status, raster: unauthorizedMutation.raster.status },
      authorizedMutation: { text: authorizedMutation.text.status, raster: authorizedMutation.raster.status },
      missingCoordinate: { text: missingCoordinate.text.status, raster: missingCoordinate.raster.status },
      mismatchedCoordinate: { text: mismatchedCoordinate.text.status, raster: mismatchedCoordinate.raster.status }
    };
  }, sourceBase64);

  assert.deepEqual(result.noOp, { text: "passed", raster: "passed" });
  assert.deepEqual(result.unauthorizedMutation, { text: "failed", raster: "failed" });
  assert.deepEqual(result.authorizedMutation, { text: "passed", raster: "passed" });
  assert.deepEqual(result.missingCoordinate, { text: "unknown", raster: "unknown" });
  assert.deepEqual(result.mismatchedCoordinate, { text: "unknown", raster: "unknown" });
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log(JSON.stringify({ test: "web_pdf_impact_validator", result }, null, 2));
} finally {
  await browser.close();
}
