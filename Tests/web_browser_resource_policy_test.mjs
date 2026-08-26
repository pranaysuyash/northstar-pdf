import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4174/web/index.html";
const sourcePath = path.join(root, "benchmark/results/public-sample-form.pdf");
const expectedDigest = crypto.createHash("sha256").update(fs.readFileSync(sourcePath)).digest("hex");
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.chooseBrowserResourcePolicy), undefined, { timeout: 30_000 });
  await page.locator("#fileInput").setInputFiles(sourcePath);
  await page.waitForFunction((digest) => window.__pdfEditorContractFixture.snapshot()?.resourcePolicy?.header?.sourceDigest === digest, expectedDigest, { timeout: 30_000 });
  const result = await page.evaluate((digest) => {
    const fixture = window.__pdfEditorContractFixture;
    const snapshot = fixture.snapshot();
    const low = fixture.chooseBrowserResourcePolicy({
      environment: { cpuLogicalCores: 2, deviceMemoryGB: 2, devicePixelRatio: 3, connection: { saveData: false } },
      document: { byteCount: 40_000_000, pageCount: 40, rasterPageCount: 40, maxImagePixelsPerPage: 12_000_000 },
      request: { ocrRequested: true, batchRequested: true },
      sourceDigest: digest
    });
    const unknown = fixture.chooseBrowserResourcePolicy({
      environment: { cpuLogicalCores: null, deviceMemoryGB: null, devicePixelRatio: 2 },
      document: { pageCount: 1 },
      sourceDigest: digest
    });
    fixture.validateBrowserResourcePolicy(low, { expectedSourceDigest: digest });
    fixture.validateBrowserResourcePolicy(unknown, { expectedSourceDigest: digest });
    return {
      snapshotPolicy: snapshot.resourcePolicy,
      low,
      unknown,
      summary: fixture.summarizeResourceEvent({ eventType: "render-cancelled", sourceDigest: digest, text: "secret" })
    };
  }, expectedDigest);
  assert.equal(result.snapshotPolicy.header.sourceDigest, expectedDigest);
  assert.equal(result.snapshotPolicy.payload.safety.contentLogged, false);
  assert.equal(result.snapshotPolicy.payload.budgets.ocr.state, "deferred");
  assert.equal(result.low.payload.budgets.ocr.state, "limited");
  assert.equal(result.low.payload.budgets.recovery.partialOutputAllowed, false);
  assert.ok(result.unknown.payload.decisions.some((decision) => decision.reasonCode === "unknownMemoryPressure"));
  assert.equal(result.summary.contentLogged, false);
  assert.equal(JSON.stringify(result).includes("secret"), false);
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log("web browser resource policy: live fixture emission, adaptive decisions, source binding, and value-free runtime surface passed");
} finally {
  await browser.close();
}
