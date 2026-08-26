// Regenerates the browser-side contract fixture bundles consumed by
// Tests/native_browser_candidate_parity_report_test.mjs.
//
// For every fixture in docs/fixtures/manifest.md this crawls /web/index.html,
// feeds the PDF to the file input, waits for the contract fixture snapshot,
// and writes the bundle to
// benchmark/results/semantic-parity/<date>/web/<flattened-name>.json.
// Fixtures that fail inspection (truncated/malformed) get the same structured
// `inspectionFailed` envelope the app produces, so downstream comparisons see
// an explicit failure instead of a missing file.
//
// Usage: node tools/regenerate_browser_contract_bundles.mjs \
//   [--base-url http://127.0.0.1:4923/web/index.html] \
//   [--out benchmark/results/semantic-parity/2026-08-25/web]
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function parseArgs(argv) {
  const args = { baseURL: process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4923/web/index.html", out: null };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--base-url") args.baseURL = argv[i + 1];
    if (argv[i] === "--out") args.out = argv[i + 1];
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const outDirectory = args.out
  ? path.resolve(args.out)
  : path.join(projectRoot, "benchmark/results/semantic-parity/2026-08-25/web");

const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");
const fixtures = [...fs.readFileSync(manifestPath, "utf8").matchAll(/^\| `([^`]+\.pdf)` \|/gm)].map((m) => m[1]);
assert.equal(fixtures.length, 18, "expected the 18-fixture corpus");

fs.mkdirSync(outDirectory, { recursive: true });

function fileNameFor(relativePath) {
  return relativePath.replaceAll("/", "__").replace(/\.pdf$/i, ".json");
}

function failureEnvelope({ relativePath, digest }) {
  return {
    contractName: "pdf-editor.browser-fixture",
    version: { major: 1, minor: 0 },
    sourcePath: relativePath,
    expectedFailure: true,
    status: "inspectionFailed",
    sourceDigest: digest,
    document: null,
    coordinates: null,
    candidates: null,
    editSession: null,
    preflight: null,
    validation: null,
    error: "fixture failed browser inspection (expected-failure corpus entry)"
  };
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(30_000);

let written = 0;
try {
  await page.goto(args.baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot), undefined, { timeout: 60_000 });

  for (const relativePath of fixtures) {
    const absolutePath = path.join(projectRoot, relativePath);
    const bytes = fs.readFileSync(absolutePath);
    const digest = crypto.createHash("sha256").update(bytes).digest("hex");
    const target = path.join(outDirectory, fileNameFor(relativePath));

    try {
      await page.locator("#fileInput").setInputFiles(absolutePath);
      const isEncrypted = /encrypted/i.test(relativePath);
      if (isEncrypted) {
        // Encrypted corpus entries open the password modal; the documented
        // reader password unlocks them. Their in-document digest is computed
        // over the decrypted render, so match on document presence.
        await page.waitForFunction(
          () => window.__pdfEditorContractFixture.snapshot()?.document != null
            || (document.getElementById("passwordModal")?.hidden === false),
          undefined,
          { timeout: 45_000 }
        );
        const modalVisible = await page.evaluate(
          () => document.getElementById("passwordModal")?.hidden === false
        );
        if (modalVisible) {
          await page.locator("#passwordInput").fill("reader-password");
          await page.locator("#passwordSubmit").click();
        }
        await page.waitForFunction(
          () => window.__pdfEditorContractFixture.snapshot()?.document?.payload?.source?.sha256 != null,
          undefined,
          { timeout: 45_000 }
        );
      } else {
        await page.waitForFunction(
          (expected) => window.__pdfEditorContractFixture.snapshot()?.document?.payload?.source?.sha256 === expected,
          digest,
          { timeout: 45_000 }
        );
      }
      const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
      fs.writeFileSync(target, `${JSON.stringify(snapshot, null, 2)}\n`);
      const candidateCount = snapshot.document?.payload?.candidates?.length ?? 0;
      console.log(`ok        ${relativePath} (candidates: ${candidateCount})`);
    } catch (error) {
      // Expected-failure fixtures never produce a snapshot; record the
      // explicit failure envelope so the parity report can classify them.
      const isExpected = /truncated|malformed/i.test(relativePath);
      if (!isExpected) throw error;
      fs.writeFileSync(target, `${JSON.stringify(failureEnvelope({ relativePath, digest }), null, 2)}\n`);
      console.log(`failed-ok ${relativePath} (expected inspection failure)`);
    }
    written += 1;
  }
} finally {
  await browser.close();
}

console.log(`wrote ${written}/${fixtures.length} browser bundles to ${path.relative(projectRoot, outDirectory)}`);
