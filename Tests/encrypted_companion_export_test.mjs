import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { chromium } from "playwright";
import { compareIndependentPreservation, independentViewerReopen } from "../benchmark/independent-preservation-validator.mjs";

const root = path.resolve(new URL("..", import.meta.url).pathname);
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4184/web/index.html";
const sourcePath = path.join(root, "benchmark/results/security-corpus/encrypted-reader.pdf");
const outputDirectory = path.join(root, "benchmark/results/encrypted-companion-2026-08-25");
const tempDirectory = fs.mkdtempSync(path.join(os.tmpdir(), "pdf-editor-encrypted-companion-"));
const plaintextPath = path.join(tempDirectory, "plaintext.pdf");
const browserOutputPath = path.join(tempDirectory, "browser-output.pdf");
const encryptedOutputPath = path.join(tempDirectory, "encrypted-output.pdf");
const password = "reader-password";
const ownerPassword = "owner-password";

function digest(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function qpdf(args) {
  return execFileSync(process.env.QPDF_BIN || "qpdf", args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

function encryptionFacts(filePath) {
  const text = qpdf(["--show-encryption", `--password=${password}`, filePath]);
  return {
    encrypted: /stream encryption method|R =/i.test(text),
    algorithm: text.match(/file encryption method\s*[:=]\s*([^\s]+)/i)?.[1] || (text.match(/algorithm:([^\s)]+)/i)?.[1] || null),
    permissions: text.includes("modify forms")
  };
}

async function load(page, filePath) {
  const url = new URL(baseURL);
  url.searchParams.set("proof", `encrypted-companion-${Date.now()}-${Math.random()}`);
  await page.goto(url.toString(), { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot));
  await page.locator("#fileInput").setInputFiles(filePath);
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot?.()?.document));
}

try {
  let wrongPasswordFailed = false;
  try {
    qpdf(["--password=wrong-password", "--decrypt", sourcePath, path.join(tempDirectory, "wrong.pdf")]);
  } catch (error) {
    wrongPasswordFailed = true;
  }
  assert.equal(wrongPasswordFailed, true, "wrong password must not unlock the companion lane");

  qpdf([`--password=${password}`, "--decrypt", sourcePath, plaintextPath]);
  const plaintextDigest = digest(plaintextPath);
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  let snapshot;
  try {
    const page = await browser.newPage({ acceptDownloads: true });
    await load(page, plaintextPath);
    await page.locator("#manualTextButton").click();
    const canvas = page.locator(".page-shell canvas").first();
    const canvasBox = await canvas.boundingBox();
    assert.ok(canvasBox, "decrypted companion input must render");
    await page.mouse.click(canvasBox.x + canvasBox.width * 0.28, canvasBox.y + canvasBox.height * 0.28);
    await page.locator("#completionValue").fill("COMPANION");
    await page.locator("#applyOverlayButton").click();
    const operation = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot().editSession.operations[0]);
    assert.equal(operation.sourceDigest, plaintextDigest);
    const downloadPromise = page.waitForEvent("download");
    await page.locator("#exportButton").click();
    const download = await downloadPromise;
    await download.saveAs(browserOutputPath);
    snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
    assert.equal(snapshot.validation.status, "validated");
    await page.close();
  } finally {
    await browser.close();
  }

  qpdf(["--encrypt", password, ownerPassword, "256", "--", browserOutputPath, encryptedOutputPath]);
  const sourceEncryption = encryptionFacts(sourcePath);
  const outputEncryption = encryptionFacts(encryptedOutputPath);
  assert.equal(sourceEncryption.encrypted, true);
  assert.equal(outputEncryption.encrypted, true);
  assert.equal(outputEncryption.algorithm, "AESv3");

  const independent = compareIndependentPreservation({
    sourcePath,
    outputPath: encryptedOutputPath,
    operations: snapshot.editSession.operations,
    password
  });
  assert.equal(independent.sourceReopen.status, "passed");
  assert.equal(independent.outputReopen.status, "passed");
  assert.equal(independent.text.status, "passed");
  assert.equal(independent.raster.status, "passed");

  const report = {
    contract: "pdf-editor.encrypted-companion-export",
    version: { major: 1, minor: 0 },
    status: "passed",
    source: { digest: digest(sourcePath), encrypted: sourceEncryption },
    plaintextStage: { digest: plaintextDigest, browserProvider: "pdfjs-pdflib", validation: snapshot.validation.status },
    operationIDs: snapshot.editSession.operations.map((operation) => operation.id),
    output: { digest: digest(encryptedOutputPath), encrypted: outputEncryption },
    independent: {
      sourceReopen: independent.sourceReopen.status,
      outputReopen: independent.outputReopen.status,
      text: independent.text.status,
      raster: independent.raster.status
    },
    wrongPasswordRejected: true,
    rawContentInReport: false,
    providerBoundary: "qpdf companion encryption around a browser-reviewed plaintext operation"
  };
  fs.mkdirSync(outputDirectory, { recursive: true });
  fs.writeFileSync(path.join(outputDirectory, "report.json"), `${JSON.stringify(report, null, 2)}\n`);
  console.log(JSON.stringify(report, null, 2));
} finally {
  fs.rmSync(tempDirectory, { recursive: true, force: true });
}
