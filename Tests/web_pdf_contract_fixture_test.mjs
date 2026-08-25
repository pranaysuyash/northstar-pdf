import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");
const outputDirectory = process.env.PDF_CONTRACT_FIXTURE_OUTPUT_DIR || null;

function corpusFromManifest() {
  const manifest = fs.readFileSync(manifestPath, "utf8");
  return [...manifest.matchAll(/^\| `([^`]+\.pdf)` \|/gm)].map((match) => match[1]);
}

async function waitForSnapshot(page, expectedDigest) {
  await page.waitForFunction(
    (digest) => window.__pdfEditorContractFixture?.snapshot?.()?.document?.header?.sourceDigest === digest,
    expectedDigest,
    { timeout: 30_000 }
  );
}

function fixtureExpectation(relativePath) {
  if (relativePath.includes("encrypted-reader.pdf") || relativePath.includes("encrypted-")) {
    return { password: "reader-password" };
  }
  if (relativePath.includes("truncated-128-bytes.pdf") || relativePath.includes("malformed-")) {
    return { expectedFailure: /cannot-open|failed to load/i };
  }
  return {};
}

async function loadCorpus(page, relativePath) {
  const absolutePath = path.join(projectRoot, relativePath);
  assert.equal(fs.existsSync(absolutePath), true, `Corpus fixture is missing: ${relativePath}`);
  const expectedDigest = crypto.createHash("sha256").update(fs.readFileSync(absolutePath)).digest("hex");
  await page.locator("#fileInput").setInputFiles(absolutePath);
  const expectation = fixtureExpectation(relativePath);
  if (expectation.password) {
    await page.locator("#passwordModal.show").waitFor({ state: "visible", timeout: 30_000 });
    await page.locator("#passwordInput").fill(expectation.password);
    await page.locator("#passwordSubmit").click();
  }
  if (expectation.expectedFailure) {
    await page.waitForFunction(
      (source) => new RegExp(source, "i").test(document.querySelector("#status")?.textContent || ""),
      expectation.expectedFailure.source,
      { timeout: 30_000 }
    );
    return { expectedFailure: true, status: await page.locator("#status").textContent() };
  }
  await waitForSnapshot(page, expectedDigest);
  return page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
}

function assertCoordinateRegion(region, label) {
  assert.ok(region, `${label} should carry a page-space coordinate region`);
  assert.equal(region.coordinateSpace.unit, "points", `${label} should use PDF points`);
  assert.equal(region.coordinateSpace.origin, "lowerLeft", `${label} should use lower-left PDF coordinates`);
  assert.equal(region.coordinateSpace.pageBox, "crop", `${label} should be crop-box relative`);
  assert.equal(Number.isInteger(region.pageIndex), true, `${label} should use a zero-based page index`);
  for (const key of ["x", "y", "width", "height"]) {
    assert.equal(typeof region.rect[key], "number", `${label} rect.${key} should be numeric`);
  }
}

function assertContractBundle(bundle, relativePath) {
  assert.equal(bundle.contractName, "pdf-editor.browser-fixture");
  assert.deepEqual(bundle.version, { major: 1, minor: 0 });

  const documentContract = bundle.document;
  const digest = documentContract.header.sourceDigest;
  assert.equal(documentContract.header.contractName, "pdf-editor.document");
  assert.equal(documentContract.header.version.major, 1);
  assert.equal(documentContract.payload.source.sha256, digest);
  assert.equal(documentContract.payload.source.fileName, path.basename(relativePath));
  assert.equal(bundle.coordinates.sourceDigest, digest);
  assert.equal(bundle.editSession.header.contractName, "pdf-editor.edit-session");
  assert.equal(bundle.editSession.header.sourceDigest, digest);

  const pages = documentContract.payload.pages;
  assert.equal(bundle.coordinates.pages.length, pages.length);
  for (const page of pages) {
    const pageCoordinate = bundle.coordinates.pages.find((entry) => entry.pageIndex === page.pageIndex);
    assert.ok(pageCoordinate, `Missing coordinate contract for page ${page.pageIndex}`);
    assertCoordinateRegion(pageCoordinate.region, `page ${page.pageIndex}`);
    assert.equal(pageCoordinate.region.rect.x, page.bounds.x);
    assert.equal(pageCoordinate.region.rect.y, page.bounds.y);
    assert.equal(pageCoordinate.region.rect.width, page.bounds.width);
    assert.equal(pageCoordinate.region.rect.height, page.bounds.height);
  }

  assert.deepEqual(bundle.candidates, documentContract.payload.candidates, "candidate projection should be lossless");
  if (bundle.candidates.length > 0) {
    assert.equal(
      bundle.candidates.some((candidate) => candidate.kind === "vectorRegion"),
      true,
      `${relativePath} should expose geometry-backed candidates when vector evidence exists`
    );
  }
  for (const candidate of bundle.candidates) {
    assert.equal(candidate.sourceDigest, digest);
    assertCoordinateRegion(candidate.coordinate, `candidate ${candidate.id}`);
    assert.equal(candidate.coordinate.pageIndex, candidate.pageIndex);
    assert.ok(Array.isArray(candidate.evidenceItems), `candidate ${candidate.id} should expose evidence items`);
    assert.ok(candidate.evidenceItems.length > 0, `candidate ${candidate.id} should expose typed evidence`);
    for (const evidence of candidate.evidenceItems) {
      if (evidence.region) {
        assertCoordinateRegion(evidence.region, `evidence ${evidence.id}`);
      }
    }
  }

  assert.ok(Array.isArray(bundle.editSession.reviews));
  assert.ok(Array.isArray(bundle.editSession.operations));
  for (const operation of bundle.editSession.operations) {
    assert.equal(operation.sourceDigest, digest, `operation ${operation.id} must bind to the source digest`);
    assertCoordinateRegion(operation.coordinate, `operation ${operation.id}`);
    assert.equal(operation.coordinate.pageIndex, operation.pageIndex);
    assert.ok(operation.payload, `operation ${operation.id} should carry a typed payload`);
  }

  const validation = bundle.validation;
  assert.ok(validation, "fixture should emit a validation report after export");
  assert.ok(["validated", "validatedWithWarnings", "failed"].includes(validation.status), `unexpected validation status: ${validation.status}`);
  assert.equal(validation.sourceDigest, digest);
  const checkKinds = new Set(validation.checks.map((check) => check.kind));
  if (validation.status === "failed") {
    assert.equal(validation.checks.some((check) => check.status === "failed"), true, "failed validation should explain the failure");
  } else {
    assert.equal(validation.outputReopenable, true);
    for (const requiredKind of ["sourceDigest", "outputReopen", "pageGeometry", "appliedOperations", "outsideRegionText", "visualDiff", "providerCapability"]) {
      assert.equal(checkKinds.has(requiredKind), true, `validation should emit ${requiredKind}`);
    }
  }
  assert.deepEqual(
    validation.operationIDs,
    bundle.editSession.operations.map((operation) => operation.id),
    "validation should preserve operation lineage"
  );
}

async function exportReviewedSession(page, snapshot, index, relativePath) {
  const value = `Browser fixture ${index + 1}`;
  let attemptedEdit = false;
  if (!snapshot.document.payload.security?.isEncrypted) {
    const nativeFieldIndex = snapshot.document.payload.fields.findIndex((field) => ["text", "button", "choice"].includes(field.kind));
    if (nativeFieldIndex >= 0) {
      attemptedEdit = true;
      await page.locator("#fieldList button").nth(nativeFieldIndex).click();
      await page.locator("#completionValue").fill(value);
      await page.locator("#applyFieldButton").click();
    } else if (snapshot.candidates.length > 0) {
      attemptedEdit = true;
      await page.locator("#candidateList button").first().click();
      await page.locator("#completionValue").fill(value);
      await page.locator("#applyOverlayButton").click();
    }
  }

  const downloadPromise = page.waitForEvent("download", { timeout: 10_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  await page.waitForFunction(
    () => /Last export:|Export failed:/.test(document.querySelector("#validationBox")?.textContent || document.querySelector("#status")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  await page.waitForFunction(
    () => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  const snapshotAfterExport = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const download = await downloadPromise;
  const isNoOp = !attemptedEdit;
  if (isNoOp) {
    assert.ok(
      download,
      `${relativePath} should produce an export download; status=${await page.locator("#status").textContent()}; validation=${await page.locator("#validationBox").textContent()}`
    );
    const downloadedPath = await download.path();
    assert.ok(downloadedPath, `${relativePath} should expose a downloaded artifact`);
    assert.deepEqual(
      fs.readFileSync(downloadedPath),
      fs.readFileSync(path.join(projectRoot, relativePath)),
      "no-op export must preserve source bytes exactly"
    );
  }
  return snapshotAfterExport;
}

async function assertEncryptedEditRejected(page, snapshot, relativePath) {
  const downloadPromise = page.waitForEvent("download", { timeout: 5_000 }).catch(() => null);
  await page.locator("#fieldList button").first().click();
  await page.locator("#completionValue").fill("must not be exported");
  await page.locator("#applyFieldButton").click();
  await page.locator("#exportButton").click();
  await page.waitForFunction(
    () => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  const rejected = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const download = await downloadPromise;
  assert.equal(download, null, `${relativePath} encrypted edits must not download an artifact`);
  assert.equal(rejected.validation.status, "failed");
  assert.match(rejected.validation.messages.join(" "), /encrypted PDF editing is not supported/i);
}

const corpus = corpusFromManifest();
assert.ok(corpus.length > 0, "fixture manifest should provide at least one PDF");

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ acceptDownloads: true, viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
let currentSourcePath = "";
page.on("console", (message) => {
  if (message.type() === "error") {
    consoleErrors.push(message.text());
  } else if (message.type() !== "debug") {
    console.error(`[browser:${message.type()}] ${message.text()}`);
  }
});
page.on("pageerror", (error) => {
  pageErrors.push(`${currentSourcePath}: ${error.message}`);
});

const emitted = [];
const geometryEvidenceCoverage = {
  vectorRectangle: false,
  checkbox: false,
  whitespace: false,
  labelAssociation: false
};
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib), undefined, { timeout: 30_000 });
  await page.waitForFunction(() => Boolean(window.__pdfEditorContractFixture?.snapshot), undefined, { timeout: 30_000 });

  for (const [index, relativePath] of corpus.entries()) {
    currentSourcePath = relativePath;
    const inspected = await loadCorpus(page, relativePath);
    if (inspected.expectedFailure) {
      assert.match(inspected.status, fixtureExpectation(relativePath).expectedFailure);
      emitted.push({ sourcePath: relativePath, expectedFailure: inspected.status });
      continue;
    }
    const completed = await exportReviewedSession(page, inspected, index, relativePath);
    assertContractBundle(completed, relativePath);
    if (inspected.document.payload.security?.isEncrypted) {
      await assertEncryptedEditRejected(page, completed, relativePath);
    }
    for (const candidate of completed.candidates) {
      const evidenceKinds = new Set((candidate.evidenceItems || []).map((evidence) => evidence.kind));
      geometryEvidenceCoverage.vectorRectangle ||= evidenceKinds.has("vectorRectangle");
      geometryEvidenceCoverage.checkbox ||= candidate.suggestedFieldType === "checkbox"
        && evidenceKinds.has("vectorRectangle")
        && (candidate.evidenceItems || []).some((evidence) => /checkbox-shaped/i.test(evidence.summary));
      geometryEvidenceCoverage.whitespace ||= evidenceKinds.has("whitespace");
      geometryEvidenceCoverage.labelAssociation ||= Boolean(candidate.labelText)
        && evidenceKinds.has("textLabel")
        && evidenceKinds.has("spatialRelationship");
    }
    const bundle = {
      sourcePath: relativePath,
      sourceDigest: completed.document.header.sourceDigest,
      document: completed.document,
      coordinates: completed.coordinates,
      candidates: completed.candidates,
      editSession: completed.editSession,
      validation: completed.validation
    };
    emitted.push(bundle);

    if (outputDirectory) {
      fs.mkdirSync(outputDirectory, { recursive: true });
      const basename = relativePath.replace(/[^a-zA-Z0-9]+/g, "-").replace(/^-|-$/g, "");
      fs.writeFileSync(path.join(outputDirectory, `${basename}.json`), `${JSON.stringify(bundle, null, 2)}\n`);
    }
  }
  assert.equal(geometryEvidenceCoverage.vectorRectangle, true, "corpus should emit vector-rectangle evidence");
  assert.equal(geometryEvidenceCoverage.checkbox, true, "corpus should emit explicit checkbox evidence");
  assert.equal(geometryEvidenceCoverage.whitespace, true, "corpus should emit whitespace evidence");
  assert.equal(geometryEvidenceCoverage.labelAssociation, true, "corpus should emit paired label-association evidence");
  assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
  assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
} finally {
  await browser.close();
}

console.log(JSON.stringify({
  contractName: "pdf-editor.browser-contract-fixtures",
  version: { major: 1, minor: 0 },
  fixtureCount: emitted.length,
  fixtures: emitted
}, null, 2));
