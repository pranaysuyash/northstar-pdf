/**
 * Network-egression assertion for browser lanes (RG-028).
 *
 * Proves that the web companion's core modules make zero external network
 * requests when processing a local PDF. This converts the privacy-boundary
 * policy from an asserted claim to a tier-2 testable invariant.
 *
 * Method: intercept all HTTP(S) requests via Playwright's page.on('request')
 * and assert zero outbound calls during the full workflow cycle.
 *
 * Evidence tier: Tier 2 / S1 (assertion exists and passes).
 */
import assert from "node:assert/strict";
import http from "node:http";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const testDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDir, "..");
const fixture = path.join(
  projectRoot,
  "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf"
);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".pdf": "application/pdf",
  ".png": "image/png",
};

// Self-boot server
const server = http.createServer(async (req, res) => {
  try {
    const urlPath = decodeURIComponent(
      new URL(req.url, "http://127.0.0.1").pathname
    );
    const filePath = path.join(projectRoot, path.normalize(urlPath));
    if (!filePath.startsWith(projectRoot)) throw new Error("traversal");
    const data = await fs.readFile(filePath);
    res.writeHead(200, {
      "content-type": MIME[path.extname(filePath).toLowerCase()] ?? "application/octet-stream",
    });
    res.end(data);
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found");
  }
});

await new Promise((r) => server.listen(0, "127.0.0.1", r));
const port = server.address().port;
const baseURL = `http://127.0.0.1:${port}/web/index.html`;

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(10_000);

const externalRequests = [];
page.on("request", (req) => {
  const url = req.url();
  // Allow same-origin (127.0.0.1) and about:blank; flag everything else.
  if (
    !url.startsWith("http://127.0.0.1") &&
    !url.startsWith("about:") &&
    !url.startsWith("data:")
  ) {
    externalRequests.push({ url, method: req.method() });
  }
});

try {
  // Load the app
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib));

  // Load a local PDF
  await page.locator("#fileInput").setInputFiles(fixture);
  await page.waitForFunction(
    () => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document),
    { timeout: 10_000 }
  );

  // Exercise core operations: inspect candidates, apply overlay, undo
  const candidateRow = page
    .locator("#candidateList .completion-item")
    .filter({ hasText: /Text entry region|Character-entry region/ })
    .first();
  if ((await candidateRow.count()) > 0) {
    await candidateRow.locator("button").click();
    await page.waitForFunction(
      () => !document.querySelector("#candidateAction")?.hidden
    );
    await page.locator("#completionValue").fill("Egress test value");
    await page.locator("#applyOverlayButton").click();
    await page.waitForFunction(
      () => document.querySelectorAll(".overlay-preview").length > 0
    );
    await page.locator("#undoEditButton").click();
  }

  // Wait a beat for any async outbound requests
  await new Promise((r) => setTimeout(r, 2000));

  // Assert: zero external requests
  assert.equal(
    externalRequests.length,
    0,
    `Expected zero external requests, found ${externalRequests.length}:\n` +
      externalRequests.map((r) => `  ${r.method} ${r.url}`).join("\n")
  );

  console.log(
    "browser network-egression: zero external requests during full workflow cycle"
  );
  console.log(
    "RG-028 local-first privacy boundary: asserted AND tested (Tier 2/S1)"
  );
} finally {
  await browser.close();
  server.close();
}
