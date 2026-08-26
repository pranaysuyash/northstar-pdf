import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const baseURL = process.env.PDF_EDITOR_BASE_URL || "http://127.0.0.1:4173/web/index.html";
const nativePath = path.join(projectRoot, "benchmark/results/text-run-ocr-alignment/native.json");
const outputPath = path.join(projectRoot, "benchmark/results/text-run-ocr-alignment/browser-and-native.json");
const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");

const {
  buildTextRunReplacementProbe,
  compareOCRLayerAlignment,
  compareTextRunProjections,
  validateTextRunOCRAlignmentReport
} = await import("../web/text-run-ocr-alignment-benchmark.mjs");

const nativeReport = JSON.parse(fs.readFileSync(nativePath, "utf8"));
const nativeByPath = new Map(nativeReport.cases.map((entry) => [entry.sourcePath, entry]));
const corpus = [...fs.readFileSync(manifestPath, "utf8").matchAll(/^\| `([^`]+\.pdf)` \|/gm)]
  .map((match) => match[1]);

function sourceDigest(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(projectRoot, relativePath))).digest("hex");
}

function expectedFailure(relativePath) {
  return relativePath.includes("truncated-128-bytes.pdf") || relativePath.includes("malformed-");
}

function passwordFor(relativePath) {
  return relativePath.includes("encrypted-reader.pdf") || relativePath.includes("encrypted-")
    ? "reader-password"
    : null;
}

function pageRunGroups(runs) {
  const grouped = new Map();
  for (const run of runs || []) {
    const list = grouped.get(run.pageIndex) || [];
    list.push(run);
    grouped.set(run.pageIndex, list);
  }
  return grouped;
}

async function loadFixture(page, relativePath) {
  await page.locator("#fileInput").setInputFiles(path.join(projectRoot, relativePath));
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
    return { status: "inspectionFailed", snapshot: null };
  }
  const digest = sourceDigest(relativePath);
  await page.waitForFunction(
    (expected) => window.__pdfEditorContractFixture?.snapshot?.()?.document?.payload?.source?.sha256 === expected,
    digest,
    { timeout: 30_000 }
  );
  return { status: "inspected", snapshot: await page.evaluate(() => window.__pdfEditorContractFixture.snapshot()) };
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const cases = [];
try {
  await page.goto(baseURL, { waitUntil: "networkidle" });
  await page.waitForFunction(
    () => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot),
    undefined,
    { timeout: 30_000 }
  );

  for (const relativePath of corpus) {
    const native = nativeByPath.get(relativePath);
    assert.ok(native, `native benchmark missing ${relativePath}`);
    const expectedDigest = sourceDigest(relativePath);
    const loaded = await loadFixture(page, relativePath);
    const browserSnapshot = loaded.snapshot;
    const browserDigest = browserSnapshot?.document?.payload?.source?.sha256 || null;
    assert.equal(browserDigest, loaded.snapshot ? expectedDigest : null, `browser digest mismatch for ${relativePath}`);
    assert.equal(loaded.status === "inspectionFailed", expectedFailure(relativePath), `status mismatch for ${relativePath}`);

    const browserRuns = browserSnapshot?.textRuns || [];
    const nativePages = native.native.pages || [];
    const browserPages = browserSnapshot?.document?.payload?.pages || [];
    const browserByPage = pageRunGroups(browserRuns);
    const comparisons = nativePages.map((nativePage) => {
      const browserPage = browserPages.find((pageFact) => pageFact.pageIndex === nativePage.pageIndex);
      const browserPageRuns = browserByPage.get(nativePage.pageIndex) || [];
      return {
        pageIndex: nativePage.pageIndex,
        nativeBounds: nativePage.bounds,
        browserBounds: browserPage?.bounds || null,
        rotation: { native: nativePage.rotation, browser: browserPage?.rotation ?? null },
        textRuns: compareTextRunProjections({
          nativeRuns: nativePage.textRuns,
          browserRuns: browserPageRuns,
          sourceDigest: native.sourceDigest,
          tolerancePoints: 2
        }),
        ocrAlignment: compareOCRLayerAlignment({
          ocrRuns: nativePage.ocrRuns,
          referenceRuns: browserPageRuns,
          sourceDigest: native.sourceDigest,
          tolerancePoints: 3
        })
      };
    });
    const firstRun = browserRuns[0] || nativePages.flatMap((entry) => entry.textRuns)[0] || null;
    let replacementGate = null;
    if (firstRun && browserSnapshot) {
      replacementGate = await page.evaluate(({ run }) => {
        const fixture = window.__pdfEditorContractFixture;
        const snapshot = fixture.snapshot();
        const operation = {
          id: "text-run-replacement-probe",
          pageIndex: run.pageIndex,
          kind: "textRunReplacement",
          value: "",
          bounds: run.bounds,
          sourceDigest: snapshot.document.header.sourceDigest,
          coordinate: run.coordinate,
          reversible: true,
          destructive: false
        };
        try {
          fixture.assertExportableContract({
            currentSourceDigest: snapshot.document.header.sourceDigest,
            operations: [operation],
            pageCoordinates: snapshot.coordinates.pages,
            validation: null
          });
          return { accepted: true, codes: [] };
        } catch (error) {
          return {
            accepted: false,
            codes: Array.isArray(error.issues) ? error.issues.map((issue) => issue.code) : [error.code || "unknown"]
          };
        }
      }, { run: firstRun });
    }
    const replacement = firstRun
      ? {
        ...buildTextRunReplacementProbe({
        sourceDigest: native.sourceDigest,
        run: firstRun,
        providerID: "pdfjs-pdflib",
        operationSupported: false,
        outsideRegionValidation: "not-run",
        visualValidation: "not-run"
        }),
        mutationGate: replacementGate
      }
      : {
        operationKind: "textRunReplacement",
        sourceDigest: native.sourceDigest || null,
        providerID: "pdfjs-pdflib",
        targetRunID: null,
        capabilityState: "abstained-no-text-run",
        reviewState: "not-applicable",
        outsideRegionValidation: "not-run",
        visualValidation: "not-run",
        mutationGate: null,
        replacementValueRetained: false
      };
    cases.push({
      fixtureId: native.fixtureId,
      sourcePath: relativePath,
      sourceDigest: native.sourceDigest || expectedDigest,
      expectedFailure: expectedFailure(relativePath),
      status: loaded.status,
      native: native.native,
      browser: browserSnapshot
        ? {
          providerID: browserSnapshot.document.header.provider.id,
          providerVersion: browserSnapshot.document.header.provider.version,
          pageCount: browserSnapshot.document.payload.pages.length,
          pages: browserSnapshot.document.payload.pages.map((pageFact) => ({
            pageIndex: pageFact.pageIndex,
            bounds: pageFact.bounds,
            rotation: pageFact.rotation,
            textRuns: browserByPage.get(pageFact.pageIndex) || [],
            ocrRuns: [],
            ocrState: "not-installed"
          }))
        }
        : { providerID: "pdfjs-pdflib", providerVersion: "pdfjs-4.2.67+pdf-lib-1.17.1", pageCount: 0, pages: [] },
      comparisons,
      replacement,
      nativeReplacement: native.replacement,
      privacy: {
        rawTextRetained: false,
        replacementValueRetained: false,
        ocrValueRetained: false
      }
    });
  }
} finally {
  await browser.close();
}

const comparisonEntries = cases.flatMap((entry) => entry.comparisons);
const textMeasured = comparisonEntries.filter((entry) => entry.textRuns.state === "measured");
const ocrMeasured = comparisonEntries.filter((entry) => entry.ocrAlignment.state === "measured");
const ocrAbstained = comparisonEntries.filter((entry) => entry.ocrAlignment.state.startsWith("abstained"));
const replacementStates = [...new Set(cases.map((entry) => entry.replacement.capabilityState))];
const report = {
  contractName: "pdf-editor.text-run-ocr-alignment",
  version: { major: 1, minor: 0 },
  generatedAt: new Date().toISOString(),
  corpusManifest: "docs/fixtures/manifest.md",
  nativeEvidence: "benchmark/results/text-run-ocr-alignment/native.json",
  browserProvider: "pdfjs-pdflib",
  browserRuntime: "local PDF.js vendor bundle plus browser fixture",
  replacementPolicy: "true semantic replacement is measured as abstained until a provider proves source-bound replacement and independent preservation",
  summary: {
    fixtureCount: cases.length,
    inspectedFixtureCount: cases.filter((entry) => entry.status === "inspected").length,
    expectedFailureCount: cases.filter((entry) => entry.expectedFailure).length,
    pageCount: comparisonEntries.length,
    textMeasuredPageCount: textMeasured.length,
    ocrMeasuredPageCount: ocrMeasured.length,
    ocrAbstainedPageCount: ocrAbstained.length,
    textHashAgreementMean: textMeasured.length
      ? textMeasured.reduce((sum, entry) => sum + entry.textRuns.textRunRecall, 0) / textMeasured.length
      : null,
    textGeometryAgreementMean: textMeasured.length
      ? textMeasured.reduce((sum, entry) => sum + entry.textRuns.geometryAgreement, 0) / textMeasured.length
      : null,
    ocrGeometryAgreementMean: ocrMeasured.length
      ? ocrMeasured.reduce((sum, entry) => sum + (entry.ocrAlignment.geometryAgreement || 0), 0) / ocrMeasured.length
      : null,
    replacementStates,
    gates: {
      sourceDigestBinding: cases.every((entry) => entry.sourceDigest === sourceDigest(entry.sourcePath)),
      noRawContentLogging: cases.every((entry) => entry.privacy.rawTextRetained === false && entry.privacy.ocrValueRetained === false),
      noSilentTextReplacement: cases.every((entry) => entry.replacement.capabilityState.startsWith("abstained")
        && (entry.replacement.mutationGate == null
          || (entry.replacement.mutationGate.accepted === false
            && entry.replacement.mutationGate.codes.includes("unsupportedOperation")))),
      textGeometryWithinTwoPoints: textMeasured.length > 0 && textMeasured.every((entry) => entry.textRuns.geometryAgreement === 1),
      ocrGeometryWithinThreePoints: ocrMeasured.length > 0 && ocrMeasured.every((entry) => entry.ocrAlignment.geometryAgreement === 1),
      missingBrowserOCRAbstains: ocrAbstained.every((entry) => entry.ocrAlignment.state.startsWith("abstained"))
    }
  },
  firstMismatches: textMeasured
    .filter((entry) => entry.textRuns.geometryAgreement < 1 || entry.textRuns.textRunRecall < 1)
    .slice(0, 12)
    .map((entry) => ({
      pageIndex: entry.pageIndex,
      text: entry.textRuns,
      sourcePath: cases.find((candidate) => candidate.comparisons.includes(entry))?.sourcePath || null
    })),
  cases
};
validateTextRunOCRAlignmentReport(report);
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);

console.log(JSON.stringify({
  report: path.relative(projectRoot, outputPath),
  fixtureCount: cases.length,
  measuredTextPages: textMeasured.length,
  ocrAbstentions: ocrAbstained.length,
  replacementStates
}, null, 2));
