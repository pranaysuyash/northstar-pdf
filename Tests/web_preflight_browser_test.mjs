import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const sourcePath = path.join(root, "benchmark/results/public-sample-form.pdf");
const expectedDigest = crypto.createHash("sha256").update(fs.readFileSync(sourcePath)).digest("hex");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => { if (message.type() === "error") consoleErrors.push(message.text()); });
page.on("pageerror", (error) => pageErrors.push(error.message));

try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture?.validatePreflightReport),
    undefined,
    { timeout: 30_000 }
  );
  await page.locator("#fileInput").setInputFiles(sourcePath);
  await page.waitForFunction(
    (digest) => window.__pdfEditorContractFixture.snapshot()?.preflight?.header?.sourceDigest === digest,
    expectedDigest,
    { timeout: 30_000 }
  );

  const result = await page.evaluate((digest) => {
    const fixture = window.__pdfEditorContractFixture;
    const snapshot = fixture.snapshot();
    const report = snapshot.preflight;
    const sessionProvenance = snapshot.sessionProvenance;
    fixture.validatePreflightReport(report, { expectedSourceDigest: digest });
    fixture.validateSessionPrivacyProvenance(sessionProvenance, { expectedSourceDigest: digest });
    const serialized = JSON.stringify(report);
    const sessionSerialized = JSON.stringify(sessionProvenance);
    return {
      report,
      sessionProvenance,
      serialized,
      sessionSerialized,
      boxText: document.querySelector("#preflightBox")?.textContent || ""
    };
  }, expectedDigest);

  assert.equal(result.report.header.contractName, "pdf-editor.preflight");
  assert.equal(result.report.header.sourceDigest, expectedDigest);
  assert.equal(result.report.payload.metadata.rawValuesIncluded, false);
  assert.equal(result.report.payload.sanitization.status, "not-run");
  assert.equal(result.report.payload.sanitization.safeToClaimClean, false);
  assert.equal(result.report.payload.activeContent.executionAttempted, false);
  assert.equal(result.sessionProvenance.header.contractName, "pdf-editor.session-provenance");
  assert.equal(result.sessionProvenance.header.sourceDigest, expectedDigest);
  assert.equal(result.sessionProvenance.payload.processing.locality, "local-browser");
  assert.equal(result.sessionProvenance.payload.processing.dataEgress, "none");
  assert.equal(result.sessionProvenance.payload.ocr.state, "not-used");
  assert.equal(result.sessionProvenance.payload.sourceRetention.state, "in-memory-session");
  assert.equal(result.sessionProvenance.payload.export.state, "not-attempted");
  assert.equal(result.sessionProvenance.payload.privacy.sourceBytesIncluded, false);
  assert.match(result.boxText, /Sanitization: not-run/);
  assert.equal(result.serialized.includes("public-sample-form.pdf"), false);
  assert.equal(result.sessionSerialized.includes("public-sample-form.pdf"), false);
  assert.equal(result.sessionSerialized.includes('"documentText":'), false);

  await assert.rejects(
    page.evaluate((staleDigest) => window.__pdfEditorContractFixture.validatePreflightReport(
      window.__pdfEditorContractFixture.snapshot().preflight,
      { expectedSourceDigest: staleDigest }
    ), "b".repeat(64)),
    /stale/
  );
  await assert.rejects(
    page.evaluate((digest) => {
      const provenance = structuredClone(window.__pdfEditorContractFixture.snapshot().sessionProvenance);
      provenance.payload.privacy.fieldValuesIncluded = true;
      return window.__pdfEditorContractFixture.validateSessionPrivacyProvenance(provenance, { expectedSourceDigest: digest });
    }, expectedDigest),
    /privacy leak/
  );
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
  console.log("web preflight browser adapter: report emission, UI boundary, source binding, and zero-content surface passed");
} finally {
  await browser.close();
}
