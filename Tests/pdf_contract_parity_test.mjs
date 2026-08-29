import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { compareIndependentPreservation, independentViewerReopen } from "../benchmark/independent-preservation-validator.mjs";
import { buildBrowserExportIndependentViewerReport } from "../benchmark/browser-export-independent-viewer-validator.mjs";
import { comparePreflightReports } from "../web/pdf-preflight.mjs";
import {
  compareNormalizedContractBundles,
  normalizeContractBundle,
  PARITY_CONTRACT,
  representationFacts
} from "../web/pdf-contract-parity.mjs";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");
const parityFixturePath = path.join(projectRoot, "Tests/fixtures/pdf_corpus_semantic_parity_fixture.json");
const parityFixtureDescriptor = JSON.parse(fs.readFileSync(parityFixturePath, "utf8"));
const resultRoot = path.resolve(
  projectRoot,
  process.env.PDF_PARITY_RESULT_ROOT || "benchmark/results/contract-parity-2026-08-24"
);
const nativeDirectory = path.join(resultRoot, "native");
const webDirectory = path.join(resultRoot, "web");
const webExportDirectory = path.join(resultRoot, "web-exports");
const reportPath = path.join(resultRoot, "parity-report.json");
const independentReportPath = path.join(resultRoot, "independent-preservation-report.json");
const independentBrowserViewerReportPath = path.join(resultRoot, "independent-browser-viewer-report.json");
const preflightReportPath = path.join(resultRoot, "privacy-preflight-parity-report.json");

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
  return relativePath.includes("truncated-128-bytes.pdf") || relativePath.includes("malformed-");
}

function passwordFor(relativePath) {
  return relativePath.includes("encrypted-reader.pdf") || relativePath.includes("encrypted-") ? "reader-password" : null;
}

function sourceDigest(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(projectRoot, relativePath))).digest("hex");
}

function semanticProjectionDigest(bundle) {
  return crypto.createHash("sha256")
    .update(JSON.stringify(normalizeContractBundle(bundle)))
    .digest("hex");
}

function parityCaseFor(relativePath) {
  return parityFixtureDescriptor.cases.find((entry) => entry.sourceFixture === relativePath) || null;
}

function readNativeBundle(relativePath) {
  const file = path.join(nativeDirectory, fileNameFor(relativePath));
  assert.equal(fs.existsSync(file), true, `native harness did not emit ${relativePath}`);
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function pushMismatch(mismatches, kind, pathName, nativeValue, webValue) {
  mismatches.push({ kind, path: pathName, native: nativeValue, web: webValue });
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
      preflight: null,
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
  path.relative(projectRoot, nativeDirectory)
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
const independentBrowserViewerReport = buildBrowserExportIndependentViewerReport({ projectRoot, resultRoot });
fs.writeFileSync(independentBrowserViewerReportPath, `${JSON.stringify(independentBrowserViewerReport, null, 2)}\n`);

const fixtureReports = corpus.map((relativePath) => {
  const nativeBundle = nativeBundles[relativePath];
  const webBundle = webBundles[relativePath];
  const parityCase = parityCaseFor(relativePath);
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
  mismatches.push(...compareNormalizedContractBundles(nativeBundle, webBundle));
  const allowedMismatchKinds = parityCase?.allowedOpenMismatchKinds || [];
  const allowedMismatches = mismatches.filter((mismatch) => allowedMismatchKinds.includes(mismatch.kind));
  const unexpectedMismatches = mismatches.filter((mismatch) => !allowedMismatchKinds.includes(mismatch.kind));
  const nativeProjectionDigest = semanticProjectionDigest(nativeBundle);
  const browserProjectionDigest = semanticProjectionDigest(webBundle);
  return {
    parityCaseID: parityCase?.id || null,
    sourcePath: relativePath,
    sourceDigest: sourceDigest(relativePath),
    sourceBinding: {
      liveSourceDigest: sourceDigest(relativePath),
      nativeSourceDigest: nativeBundle.sourceDigest ?? nativeBundle.document?.payload?.source?.sha256 ?? null,
      browserSourceDigest: webBundle.sourceDigest ?? webBundle.document?.payload?.source?.sha256 ?? null,
      nativeMatchesLive: expectedFailure(relativePath) ? null : (nativeBundle.sourceDigest ?? nativeBundle.document?.payload?.source?.sha256 ?? null) === sourceDigest(relativePath),
      browserMatchesLive: expectedFailure(relativePath) ? null : (webBundle.sourceDigest ?? webBundle.document?.payload?.source?.sha256 ?? null) === sourceDigest(relativePath),
      expectedFailure: expectedFailure(relativePath)
    },
    nativeStatus: nativeBundle.status,
    webStatus: webBundle.status,
    expectedFailure: expectedFailure(relativePath),
    normalization: {
      native: representationFacts(nativeBundle),
      browser: representationFacts(webBundle),
      semanticProjectionDigest: {
        native: nativeProjectionDigest,
        browser: browserProjectionDigest,
        exactDigestEquality: nativeProjectionDigest === browserProjectionDigest,
        comparatorEquivalent: mismatches.length === 0
      }
    },
    allowedMismatchKinds,
    allowedMismatchCount: allowedMismatches.length,
    unexpectedMismatchCount: unexpectedMismatches.length,
    unexpectedMismatches: unexpectedMismatches.slice(0, 12),
    mismatchCount: mismatches.length,
    mismatches,
    firstMismatches: mismatches.slice(0, 12)
  };
});

const mismatchCounts = fixtureReports.reduce((counts, report) => {
  for (const mismatch of report.mismatches) counts[mismatch.kind] = (counts[mismatch.kind] || 0) + 1;
  return counts;
}, {});
const unexpectedMismatchCounts = fixtureReports.reduce((counts, report) => {
  for (const mismatch of report.unexpectedMismatches) counts[mismatch.kind] = (counts[mismatch.kind] || 0) + 1;
  return counts;
}, {});
const preflightFixtureReports = corpus.map((relativePath) => {
  const nativeReport = nativeBundles[relativePath].preflight || null;
  const webReport = webBundles[relativePath].preflight || null;
  const differences = [];
  if (nativeReport && webReport) {
    differences.push(...comparePreflightReports(nativeReport, webReport).differences);
  } else if (nativeReport || webReport) {
    differences.push({ path: "preflight.presence", native: Boolean(nativeReport), web: Boolean(webReport) });
  }
  return {
    sourcePath: relativePath,
    expectedFailure: expectedFailure(relativePath),
    sourceDigest: sourceDigest(relativePath),
    nativeStatus: nativeReport ? "observed" : "unavailable",
    browserStatus: webReport ? "observed" : "unavailable",
    mismatchCount: differences.length,
    mismatches: differences.slice(0, 100)
  };
});
const preflightMismatchCounts = preflightFixtureReports.reduce((counts, fixture) => {
  for (const mismatch of fixture.mismatches) {
    const key = mismatch.path || "unknown";
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}, {});
const privacyPreflightReport = {
  harness: "pdf-editor-native-web-privacy-preflight-parity",
  version: { major: 1, minor: 0 },
  contract: { name: "pdf-editor.preflight", version: { major: 1, minor: 1 } },
  corpusManifest: "docs/fixtures/manifest.md",
  normalization: {
    excludes: ["header.provider", "header.generatedAt", "provider-specific finding IDs", "output file digests"],
    retains: ["sourceDigest", "metadata presence", "embedded-data counts", "annotation taxonomy", "script/action counts", "revision evidence", "coverage states", "unknown reasons", "sanitization and execution invariants"]
  },
  fixtureCount: preflightFixtureReports.length,
  mismatchCount: preflightFixtureReports.reduce((total, fixture) => total + fixture.mismatchCount, 0),
  mismatchCounts: preflightMismatchCounts,
  fixtures: preflightFixtureReports
};
fs.writeFileSync(preflightReportPath, `${JSON.stringify(privacyPreflightReport, null, 2)}\n`);
const report = {
  harness: "pdf-editor-native-web-contract-parity",
  version: { major: 1, minor: 1 },
  corpusManifest: "docs/fixtures/manifest.md",
  normalizationContract: {
    name: PARITY_CONTRACT.name,
    version: PARITY_CONTRACT.version,
    policy: PARITY_CONTRACT.normalizationPolicy,
    semanticEqualityExcludes: PARITY_CONTRACT.ignoredFields
  },
  nativeProvider: nativeBundles[corpus[0]]?.document?.header?.provider || null,
  webProvider: webBundles[corpus[0]]?.document?.header?.provider || null,
  fixtureCount: fixtureReports.length,
  mismatchCount: fixtureReports.reduce((total, fixture) => total + fixture.mismatchCount, 0),
  mismatchCounts,
  unexpectedMismatchCount: fixtureReports.reduce((total, fixture) => total + fixture.unexpectedMismatchCount, 0),
  unexpectedMismatchCounts,
  independentPreservationReport: path.relative(projectRoot, independentReportPath),
  independentBrowserViewerReport: path.relative(projectRoot, independentBrowserViewerReportPath),
  independentBrowserViewer: {
    statusCounts: independentBrowserViewerReport.statusCounts,
    agreementCounts: independentBrowserViewerReport.agreementCounts,
    unexpectedDivergenceCount: independentBrowserViewerReport.unexpectedDivergenceCount
  },
  privacyPreflightReport: path.relative(projectRoot, preflightReportPath),
  privacyPreflight: {
    fixtureCount: privacyPreflightReport.fixtureCount,
    mismatchCount: privacyPreflightReport.mismatchCount,
    mismatchCounts: privacyPreflightReport.mismatchCounts
  },
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
assert.equal(report.unexpectedMismatchCount, 0, `unexpected parity mismatches: ${report.unexpectedMismatches.join("; ")}`);
console.log(JSON.stringify({
  harness: report.harness,
  fixtureCount: report.fixtureCount,
  mismatchCount: report.mismatchCount,
  mismatchCounts: report.mismatchCounts,
  privacyPreflight: report.privacyPreflight,
  firstMismatches: fixtureReports.flatMap((fixture) => fixture.firstMismatches.map((mismatch) => ({
    sourcePath: fixture.sourcePath,
    ...mismatch
  }))).slice(0, 20),
  reportPath: path.relative(projectRoot, reportPath)
}, null, 2));
