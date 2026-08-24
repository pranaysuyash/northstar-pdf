import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "/Users/pranay/.agents/skills/testing/playwright-skill/node_modules/playwright/index.mjs";
import { compareIndependentPreservation, independentViewerReopen } from "../benchmark/independent-preservation-validator.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const baseURL = process.env.PDF_PROOF_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");
const resultRoot = path.join(projectRoot, "benchmark/results/contract-parity-2026-08-24");
const nativeDirectory = path.join(resultRoot, "native");
const webDirectory = path.join(resultRoot, "web");
const webExportDirectory = path.join(resultRoot, "web-exports");
const reportPath = path.join(resultRoot, "parity-report.json");
const independentReportPath = path.join(resultRoot, "independent-preservation-report.json");

function corpusFromManifest() {
  const manifest = fs.readFileSync(manifestPath, "utf8");
  return [...manifest.matchAll(/^\| `([^`]+\.pdf)` \|/gm)].map((match) => match[1]);
}

function fileNameFor(relativePath) {
  return relativePath.replaceAll("/", "__").replace(/\.pdf$/i, ".json");
}

function pdfFileNameFor(relativePath, suffix) {
  return relativePath.replaceAll("/", "__").replace(/\.pdf$/i, `${suffix}.pdf`);
}

function expectedFailure(relativePath) {
  return relativePath.includes("truncated-128-bytes.pdf");
}

function passwordFor(relativePath) {
  return relativePath.includes("encrypted-reader.pdf") ? "reader-password" : null;
}

function sourceDigest(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(projectRoot, relativePath))).digest("hex");
}

function readNativeBundle(relativePath) {
  const file = path.join(nativeDirectory, fileNameFor(relativePath));
  assert.equal(fs.existsSync(file), true, `native harness did not emit ${relativePath}`);
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function round(value, places = 2) {
  if (typeof value !== "number" || !Number.isFinite(value)) return value;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function rectProjection(rect) {
  if (!rect) return null;
  return {
    x: round(rect.x),
    y: round(rect.y),
    width: round(rect.width),
    height: round(rect.height)
  };
}

function coordinateProjection(region) {
  if (!region) return null;
  return {
    pageIndex: region.pageIndex,
    rect: rectProjection(region.rect),
    coordinateSpace: {
      unit: region.coordinateSpace.unit,
      origin: region.coordinateSpace.origin,
      pageBox: region.coordinateSpace.pageBox,
      rotationDegrees: region.coordinateSpace.rotationDegrees
    }
  };
}

function multiset(values) {
  return values.map((value) => JSON.stringify(value)).sort();
}

function fieldProjection(field) {
  return {
    pageIndex: field.pageIndex,
    name: field.name,
    kind: field.kind,
    bounds: rectProjection(field.bounds),
    valuePresent: Boolean(field.value),
    choices: [...(field.choices || [])].sort()
  };
}

function candidateProjection(candidate) {
  return {
    pageIndex: candidate.pageIndex,
    kind: candidate.kind,
    suggestedFieldType: candidate.suggestedFieldType || null,
    entryMode: candidate.entryMode || "unknown",
    groupMemberCount: candidate.groupMemberCount || 1,
    bounds: rectProjection(candidate.bounds),
    coordinate: coordinateProjection(candidate.coordinate),
    evidenceKinds: [...new Set((candidate.evidenceItems || []).map((item) => item.kind))].sort(),
    labelPresent: Boolean(candidate.labelText)
  };
}

function pageProjection(page) {
  return {
    pageIndex: page.pageIndex,
    bounds: rectProjection(page.bounds),
    rotation: page.rotation,
    characterCount: page.characterCount,
    annotationCount: page.annotationCount,
    hasSelectableText: page.hasSelectableText
  };
}

function linkProjection(link) {
  return {
    pageIndex: link.pageIndex,
    label: link.label || "",
    kind: link.kind || "unknown",
    targetPageIndex: link.targetPageIndex ?? null,
    destination: link.destination ?? null,
    destinationBounds: rectProjection(link.destinationBounds),
    isSafeExternal: Boolean(link.isSafeExternal)
  };
}

function outlineProjection(items) {
  return (items || []).map((item) => ({
    title: item.title || "",
    level: item.level || 0,
    destinationPageIndex: item.destinationPageIndex ?? null,
    children: outlineProjection(item.children)
  }));
}

function accessibilityProjection(value) {
  if (!value) return null;
  return {
    hasTaggedContent: Boolean(value.hasTaggedContent),
    hasReadingOrder: Boolean(value.hasReadingOrder)
  };
}

function pushMismatch(mismatches, kind, pathName, nativeValue, webValue) {
  mismatches.push({
    kind,
    path: pathName,
    native: nativeValue,
    web: webValue
  });
}

function compareArray(mismatches, kind, pathName, nativeValues, webValues) {
  if (JSON.stringify(nativeValues) !== JSON.stringify(webValues)) {
    pushMismatch(mismatches, kind, pathName, nativeValues, webValues);
  }
}

function compareBundles(nativeBundle, webBundle) {
  const mismatches = [];
  const nativeDocument = nativeBundle.document;
  const webDocument = webBundle.document;
  if (!nativeDocument || !webDocument) {
    if (Boolean(nativeDocument) !== Boolean(webDocument)) {
      pushMismatch(mismatches, "document.presence", "document", Boolean(nativeDocument), Boolean(webDocument));
    }
    return mismatches;
  }

  const nativePayload = nativeDocument.payload;
  const webPayload = webDocument.payload;
  if (nativePayload.source.sha256 !== webPayload.source.sha256) {
    pushMismatch(mismatches, "source.digest", "document.payload.source.sha256", nativePayload.source.sha256, webPayload.source.sha256);
  }
  compareArray(
    mismatches,
    "source.metadata",
    "document.payload.source",
    { fileName: nativePayload.source.fileName, byteCount: nativePayload.source.byteCount },
    { fileName: webPayload.source.fileName, byteCount: webPayload.source.byteCount }
  );

  const nativePages = (nativePayload.pages || []).map(pageProjection);
  const webPages = (webPayload.pages || []).map(pageProjection);
  compareArray(mismatches, "page.count", "document.payload.pages.length", nativePages.length, webPages.length);
  const pageCount = Math.min(nativePages.length, webPages.length);
  for (let index = 0; index < pageCount; index += 1) {
    const nativePage = nativePages[index];
    const webPage = webPages[index];
    for (const key of ["bounds", "rotation", "hasSelectableText"]) {
      if (JSON.stringify(nativePage[key]) !== JSON.stringify(webPage[key])) {
        pushMismatch(mismatches, "page.geometry-or-text", `document.payload.pages[${index}].${key}`, nativePage[key], webPage[key]);
      }
    }
    for (const key of ["characterCount", "annotationCount"]) {
      if (nativePage[key] !== webPage[key]) {
        pushMismatch(mismatches, "page.provider-count", `document.payload.pages[${index}].${key}`, nativePage[key], webPage[key]);
      }
    }
  }

  const nativeFields = multiset((nativePayload.fields || []).map(fieldProjection));
  const webFields = multiset((webPayload.fields || []).map(fieldProjection));
  compareArray(mismatches, "native-fields", "document.payload.fields", nativeFields, webFields);

  const nativeCandidates = multiset((nativePayload.candidates || []).map(candidateProjection));
  const webCandidates = multiset((webPayload.candidates || []).map(candidateProjection));
  compareArray(mismatches, "candidate-semantic-set", "document.payload.candidates", nativeCandidates, webCandidates);
  if ((nativePayload.candidates || []).length !== (webPayload.candidates || []).length) {
    pushMismatch(
      mismatches,
      "candidate.count",
      "document.payload.candidates.length",
      nativePayload.candidates?.length || 0,
      webPayload.candidates?.length || 0
    );
  }

  const nativeCoordinates = (nativeBundle.coordinates?.pages || []).map((entry) => ({
    pageIndex: entry.pageIndex,
    region: coordinateProjection(entry.region)
  }));
  const webCoordinates = (webBundle.coordinates?.pages || []).map((entry) => ({
    pageIndex: entry.pageIndex,
    region: coordinateProjection(entry.region)
  }));
  compareArray(mismatches, "coordinates", "coordinates.pages", nativeCoordinates, webCoordinates);

  const nativeOperations = nativeBundle.editSession?.operations || [];
  const webOperations = webBundle.editSession?.operations || [];
  compareArray(mismatches, "operation.lineage", "editSession.operations.length", nativeOperations.length, webOperations.length);
  if (nativeOperations.length || webOperations.length) {
    compareArray(
      mismatches,
      "operation.semantic-set",
      "editSession.operations",
      multiset(nativeOperations.map((operation) => ({
        pageIndex: operation.pageIndex,
        kind: operation.kind,
        targetIDPresent: Boolean(operation.targetID),
        coordinate: coordinateProjection(operation.coordinate),
        sourceDigest: operation.sourceDigest
      }))),
      multiset(webOperations.map((operation) => ({
        pageIndex: operation.pageIndex,
        kind: operation.kind,
        targetIDPresent: Boolean(operation.targetID),
        coordinate: coordinateProjection(operation.coordinate),
        sourceDigest: operation.sourceDigest
      })))
    );
  }

  const nativeValidation = nativeBundle.validation;
  const webValidation = webBundle.validation;
  if (Boolean(nativeValidation) !== Boolean(webValidation)) {
    pushMismatch(mismatches, "validation.presence", "validation", Boolean(nativeValidation), Boolean(webValidation));
  } else if (nativeValidation && webValidation) {
    for (const key of ["status", "sourceUnchanged", "outputReopenable"]) {
      if (nativeValidation[key] !== webValidation[key]) {
        pushMismatch(mismatches, "validation.status", `validation.${key}`, nativeValidation[key], webValidation[key]);
      }
    }
    const nativeChecks = Object.fromEntries((nativeValidation.checks || []).map((check) => [check.kind, check.status]));
    const webChecks = Object.fromEntries((webValidation.checks || []).map((check) => [check.kind, check.status]));
    compareArray(mismatches, "validation.check-kinds", "validation.checks", Object.keys(nativeChecks).sort(), Object.keys(webChecks).sort());
    for (const kind of new Set([...Object.keys(nativeChecks), ...Object.keys(webChecks)])) {
      if (nativeChecks[kind] !== webChecks[kind]) {
        pushMismatch(mismatches, "validation.check-status", `validation.checks.${kind}.status`, nativeChecks[kind] || null, webChecks[kind] || null);
      }
    }
  }

  const metadataComparisons = [
    ["links", (value) => (value || []).map(linkProjection)],
    ["outlines", outlineProjection],
    ["attachments", (value) => [...(value || [])].sort()],
    ["accessibility", accessibilityProjection],
    ["security", (value) => value ? {
      isEncrypted: Boolean(value.isEncrypted),
      isLocked: Boolean(value.isLocked),
      requiresPassword: Boolean(value.requiresPassword)
    } : null]
  ];
  for (const [key, project] of metadataComparisons) {
    const nativeValue = project(nativePayload[key]);
    const webValue = project(webPayload[key]);
    if (JSON.stringify(nativeValue) !== JSON.stringify(webValue)) {
      pushMismatch(mismatches, `document.${key}`, `document.payload.${key}`, nativeValue, webValue);
    }
  }
  return mismatches;
}

async function waitForDigest(page, digest) {
  await page.waitForFunction(
    (expected) => window.__pdfEditorContractFixture?.snapshot?.()?.document?.payload?.source?.sha256 === expected,
    digest,
    { timeout: 30_000 }
  );
}

async function loadBrowserFixture(page, relativePath) {
  const absolutePath = path.join(projectRoot, relativePath);
  await page.locator("#fileInput").setInputFiles(absolutePath);
  const password = passwordFor(relativePath);
  if (password) {
    await page.locator("#passwordModal.show").waitFor({ state: "visible", timeout: 30_000 });
    await page.locator("#passwordInput").fill(password);
    await page.locator("#passwordSubmit").click();
  }
  if (expectedFailure(relativePath)) {
    await page.waitForFunction(
      () => /cannot-open|failed to load/i.test(document.querySelector("#status")?.textContent || ""),
      undefined,
      { timeout: 30_000 }
    );
    return {
      contractName: "pdf-editor.browser-fixture",
      version: { major: 1, minor: 0 },
      sourcePath: relativePath,
      expectedFailure: true,
      status: "inspectionFailed",
      sourceDigest: null,
      document: null,
      coordinates: null,
      candidates: null,
      editSession: null,
      validation: null,
      error: await page.locator("#status").textContent()
    };
  }
  await waitForDigest(page, sourceDigest(relativePath));
  const downloadPromise = page.waitForEvent("download", { timeout: 5_000 }).catch(() => null);
  await page.locator("#exportButton").click();
  await page.waitForFunction(
    () => /Last export:/.test(document.querySelector("#validationBox")?.textContent || ""),
    undefined,
    { timeout: 30_000 }
  );
  const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
  const download = await downloadPromise;
  let browserExportPath = null;
  if (download) {
    browserExportPath = path.join(webExportDirectory, pdfFileNameFor(relativePath, "-browser-noop"));
    await download.saveAs(browserExportPath);
  }
  return {
    ...snapshot,
    sourcePath: relativePath,
    expectedFailure: false,
    status: snapshot.validation?.status === "failed" ? "inspectedExportFailed" : "inspected",
    sourceDigest: snapshot.document.header.sourceDigest,
    error: snapshot.validation?.status === "failed" ? snapshot.validation.messages?.join(" ") : null,
    browserExportPath
  };
}

fs.mkdirSync(nativeDirectory, { recursive: true });
fs.mkdirSync(webDirectory, { recursive: true });
fs.mkdirSync(webExportDirectory, { recursive: true });
const corpus = corpusFromManifest();
assert.ok(corpus.length > 0, "fixture manifest should provide PDFs");

execFileSync("swift", [
  "run",
  "PDFContractHarness",
  "--manifest",
  "docs/fixtures/manifest.md",
  "--output-dir",
  "benchmark/results/contract-parity-2026-08-24/native"
], { cwd: projectRoot, stdio: "inherit" });

const nativeBundles = Object.fromEntries(corpus.map((relativePath) => [relativePath, readNativeBundle(relativePath)]));
const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ acceptDownloads: true, viewport: { width: 1440, height: 1000 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (message) => {
  if (message.type() === "error") consoleErrors.push(message.text());
});
page.on("pageerror", (error) => pageErrors.push(error.message));

const webBundles = {};
const browserExportPaths = {};
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot), undefined, { timeout: 30_000 });
  for (const relativePath of corpus) {
    const loaded = await loadBrowserFixture(page, relativePath);
    browserExportPaths[relativePath] = loaded.browserExportPath;
    const { browserExportPath, ...bundle } = loaded;
    webBundles[relativePath] = bundle;
    fs.writeFileSync(path.join(webDirectory, fileNameFor(relativePath)), `${JSON.stringify(webBundles[relativePath], null, 2)}\n`);
  }
} finally {
  await browser.close();
}

const independentReports = corpus.map((relativePath) => {
  const sourcePath = path.join(projectRoot, relativePath);
  const password = passwordFor(relativePath);
  const sourceViewer = independentViewerReopen({ filePath: sourcePath, password });
  const nativeExportPath = path.join(nativeDirectory, "exports", pdfFileNameFor(relativePath, "-native-noop"));
  const browserExportPath = browserExportPaths[relativePath];
  const native = fs.existsSync(nativeExportPath)
    ? compareIndependentPreservation({ sourcePath, outputPath: nativeExportPath, password })
    : { status: "unknown", message: "Native validated export was not retained." };
  const browser = browserExportPath && fs.existsSync(browserExportPath)
    ? compareIndependentPreservation({ sourcePath, outputPath: browserExportPath, password })
    : { status: "unknown", message: "Browser export was not produced by the provider." };
  return {
    sourcePath: relativePath,
    expectedFailure: expectedFailure(relativePath),
    sourceViewer,
    native: { outputPath: path.relative(projectRoot, nativeExportPath), ...native },
    browser: { outputPath: browserExportPath ? path.relative(projectRoot, browserExportPath) : null, ...browser }
  };
});
fs.writeFileSync(independentReportPath, `${JSON.stringify({
  harness: "pdf-editor-independent-preservation",
  version: { major: 1, minor: 0 },
  corpusManifest: "docs/fixtures/manifest.md",
  validator: "benchmark/independent-preservation-validator.mjs",
  reports: independentReports
}, null, 2)}\n`);

const fixtureReports = corpus.map((relativePath) => {
  const nativeBundle = nativeBundles[relativePath];
  const webBundle = webBundles[relativePath];
  const mismatches = [];
  if ((nativeBundle.sourceDigest ?? null) !== (webBundle.sourceDigest ?? null)) {
    pushMismatch(mismatches, "source.digest", "sourceDigest", nativeBundle.sourceDigest ?? null, webBundle.sourceDigest ?? null);
  }
  if (nativeBundle.status !== webBundle.status) {
    pushMismatch(mismatches, "fixture.status", "status", nativeBundle.status, webBundle.status);
  }
  if (nativeBundle.expectedFailure !== webBundle.expectedFailure) {
    pushMismatch(mismatches, "fixture.expected-failure", "expectedFailure", nativeBundle.expectedFailure, webBundle.expectedFailure);
  }
  mismatches.push(...compareBundles(nativeBundle, webBundle));
  return {
    sourcePath: relativePath,
    sourceDigest: sourceDigest(relativePath),
    nativeStatus: nativeBundle.status,
    webStatus: webBundle.status,
    expectedFailure: expectedFailure(relativePath),
    mismatchCount: mismatches.length,
    mismatches,
    firstMismatches: mismatches.slice(0, 12)
  };
});

const mismatchCounts = fixtureReports.reduce((counts, report) => {
  for (const mismatch of report.mismatches) counts[mismatch.kind] = (counts[mismatch.kind] || 0) + 1;
  return counts;
}, {});
const report = {
  harness: "pdf-editor-native-web-contract-parity",
  version: { major: 1, minor: 0 },
  corpusManifest: "docs/fixtures/manifest.md",
  nativeProvider: nativeBundles[corpus[0]]?.document?.header?.provider || null,
  webProvider: webBundles[corpus[0]]?.document?.header?.provider || null,
  fixtureCount: fixtureReports.length,
  mismatchCount: fixtureReports.reduce((total, fixture) => total + fixture.mismatchCount, 0),
  mismatchCounts,
  independentPreservationReport: path.relative(projectRoot, independentReportPath),
  independentPreservation: independentReports.map((entry) => ({
    sourcePath: entry.sourcePath,
    sourceViewerStatus: entry.sourceViewer.reopen.status,
    nativeStatus: entry.native.status,
    browserStatus: entry.browser.status,
    nativeStructuralStatus: entry.native.outputReopen?.structuralCheck?.status || null,
    browserStructuralStatus: entry.browser.outputReopen?.structuralCheck?.status || null
  })),
  consoleErrors,
  pageErrors,
  fixtures: fixtureReports
};
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
assert.deepEqual(consoleErrors, [], `browser console errors: ${consoleErrors.join(" | ")}`);
assert.deepEqual(pageErrors, [], `browser page errors: ${pageErrors.join(" | ")}`);
assert.equal(fixtureReports.length, corpus.length);
assert.ok(fixtureReports.every((fixture) => fixture.sourceDigest === sourceDigest(fixture.sourcePath)));
console.log(JSON.stringify({
  harness: report.harness,
  fixtureCount: report.fixtureCount,
  mismatchCount: report.mismatchCount,
  mismatchCounts: report.mismatchCounts,
  firstMismatches: fixtureReports.flatMap((fixture) => fixture.firstMismatches.map((mismatch) => ({
    sourcePath: fixture.sourcePath,
    ...mismatch
  }))).slice(0, 20),
  reportPath: path.relative(projectRoot, reportPath)
}, null, 2));
