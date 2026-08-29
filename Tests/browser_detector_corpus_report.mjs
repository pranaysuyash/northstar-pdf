import assert from "node:assert/strict";
import crypto from "node:crypto";
import http from "node:http";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";
import { buildDetectorSemanticComparisonReport } from "../web/detector-semantic-comparison.mjs";

/**
 * Browser detector lane against the real corpus + native-vs-browser report.
 *
 * Runs the browser geometry detector (PDF.js, vendored) on every corpus-sweep
 * fixture, loads the matching native PDFKit bundles, and evaluates both lanes
 * against the reviewed 108-case ground truth
 * (benchmark/results/detector-calibration/corpus_sweep_ground_truth.json,
 * exported from ReviewedCandidateGroundTruth.canonical()).
 *
 * Per-fixture measurement (fixture-scoped candidates vs fixture-scoped cases)
 * avoids the pooled over-count problem of identical base-form rects.
 *
 * Output: benchmark/results/detector-calibration/corpus-native-browser-semantic-parity-2026-08-28.json
 *
 * Doctrine: §5 Evidence-based, §2 Truth taxonomy, §12 Privacy (report carries
 * region identities and metrics, never document content).
 */

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const corpusDirectory = path.join(projectRoot, "benchmark/results/corpus-sweep-2026-08-25");
const nativeDirectory = path.join(projectRoot, "benchmark/results/detector-calibration/native-corpus");
const groundTruthPath = path.join(projectRoot, "benchmark/results/detector-calibration/corpus_sweep_ground_truth.json");
const reportPath = path.join(projectRoot, "benchmark/results/detector-calibration/corpus-native-browser-semantic-parity-2026-08-28.json");

const fixtureNames = [
  "plain-text.pdf", "multi-column.pdf", "navigation.pdf", "geometry.pdf",
  "metadata-complete.pdf", "metadata-absent.pdf", "metadata-custom.pdf",
  "metadata-malformed.pdf", "metadata-unicode.pdf",
  "signed-valid-structure.pdf", "signed-invalid-structure.pdf", "signed-multiple.pdf",
  "xfa-static.pdf", "xfa-hybrid.pdf", "xfa-dynamic.pdf"
];

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".wasm": "application/wasm",
};

let server;
let baseURL = process.env.PDF_EDITOR_BASE_URL;
if (!baseURL) {
  server = http.createServer(async (req, res) => {
    try {
      const urlPath = decodeURIComponent(new URL(req.url, "http://127.0.0.1").pathname);
      const filePath = path.join(projectRoot, path.normalize(urlPath));
      if (!filePath.startsWith(projectRoot)) throw new Error("path traversal rejected");
      const data = await fs.readFile(filePath);
      res.writeHead(200, { "content-type": mimeTypes[path.extname(filePath).toLowerCase()] ?? "application/octet-stream" });
      res.end(data);
    } catch {
      res.writeHead(404, { "content-type": "text/plain" });
      res.end("not found");
    }
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  baseURL = `http://127.0.0.1:${server.address().port}/web/index.html`;
}

const groundTruth = JSON.parse(await fs.readFile(groundTruthPath, "utf8"));
assert.equal(groundTruth.cases.length, 108, "ground truth must have 108 cases");

function sha256(data) {
  return crypto.createHash("sha256").update(data).digest("hex");
}

function nativeBundlePath(fixtureName) {
  const relative = `benchmark/results/corpus-sweep-2026-08-25/${fixtureName}`;
  return path.join(nativeDirectory, `${relative.replaceAll("/", "__").replace(/\.pdf$/, ".json")}`);
}

const browser = await chromium.launch({ channel: "chrome", headless: true });
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
page.setDefaultTimeout(30_000);

const fixtures = [];
try {
  for (const fixtureName of fixtureNames) {
    const fixturePath = path.join(corpusDirectory, fixtureName);
    const data = await fs.readFile(fixturePath);
    const digest = sha256(data);

    await page.goto(baseURL, { waitUntil: "networkidle" });
    await page.waitForFunction(() => Boolean(window.pdfjsLib && window.PDFLib && window.__pdfEditorContractFixture?.snapshot));
    await page.locator("#fileInput").setInputFiles(fixturePath);
    await page.waitForFunction(
      (expected) => window.__pdfEditorContractFixture.snapshot()?.document?.header?.sourceDigest === expected,
      digest,
      { timeout: 30_000 }
    );
    const snapshot = await page.evaluate(() => window.__pdfEditorContractFixture.snapshot());
    const candidates = snapshot.document.payload.candidates || [];
    const browserFields = snapshot.document.payload.fields || [];
    const browserDigest = snapshot.document.header.sourceDigest;
    assert.equal(browserDigest, digest, `${fixtureName}: browser digest must match file`);

    const nativeBundle = JSON.parse(await fs.readFile(nativeBundlePath(fixtureName), "utf8"));
    assert.equal(nativeBundle.sourceDigest, digest, `${fixtureName}: native digest must match file`);
    const nativeFields = nativeBundle.document.payload.fields || [];

    fixtures.push({
      fixtureName,
      sourceDigest: digest,
      nativeCandidates: nativeBundle.candidates || [],
      browserCandidates: candidates,
      nativeFields,
      browserFields
    });
    console.log(`[browser-lane] ${fixtureName}: native cand=${nativeBundle.candidates?.length ?? 0} fields=${nativeFields.length} | browser cand=${candidates.length} fields=${browserFields.length}`);
  }
} finally {
  await browser.close();
  if (server) server.close();
}

/**
 * Native AcroForm fields are confirmed editable regions surfaced through the
 * fields channel — the candidate detectors correctly abstain from re-
 * suggesting them. The ground truth's nativeField cases measure detection of
 * these regions, so fields are mapped to candidate-shape entries (kind
 * nativeField) and measured alongside real candidates. Documented in the
 * report as candidateSource: "fields-channel".
 */
function fieldCandidates(fields) {
  return (fields || []).map((field) => ({
    pageIndex: field.pageIndex,
    bounds: field.bounds,
    kind: "nativeField",
    suggestedFieldType: field.kind,
    entryMode: "native",
    groupMemberCount: 1,
    evidenceItems: [
      { kind: "nativeField", origin: "nativeFieldExtraction", summary: `Native field ${field.name}` }
    ],
    // labelText drives label association in the mjs normalizedCandidate
    // (labelText OR label/relationship evidence family). It does not add a
    // label evidence family, keeping the evidence-family agreement exact.
    labelText: field.name
  }));
}

// Per-fixture measurement: scope candidates and cases to the fixture.
const perFixture = fixtures.map((fixture) => {
  const labels = {
    ...groundTruth,
    fixture: fixture.fixtureName,
    cases: groundTruth.cases.filter((entry) => entry.fixtureID === fixture.fixtureName)
  };
  const report = buildDetectorSemanticComparisonReport({
    labels,
    sourceDigest: fixture.sourceDigest,
    nativeCandidates: [...fixture.nativeCandidates, ...fieldCandidates(fixture.nativeFields)],
    browserCandidates: [...fixture.browserCandidates, ...fieldCandidates(fixture.browserFields)]
  });
  return {
    fixture: fixture.fixtureName,
    sourceDigest: fixture.sourceDigest,
    reviewedRegionCount: report.reviewedRegionCount,
    passed: report.passed,
    native: {
      passed: report.adapters.native.passed,
      metrics: report.adapters.native.metrics,
      caseStates: report.adapters.native.cases.map((entry) => ({
        reviewedRegionID: entry.reviewedRegionID,
        expected: entry.expected,
        detected: entry.detected,
        state: entry.state
      }))
    },
    browser: {
      passed: report.adapters.browser.passed,
      metrics: report.adapters.browser.metrics,
      caseStates: report.adapters.browser.cases.map((entry) => ({
        reviewedRegionID: entry.reviewedRegionID,
        expected: entry.expected,
        detected: entry.detected,
        state: entry.state
      }))
    },
    parity: {
      passed: report.semanticParity.passed,
      mismatchCount: report.semanticParity.mismatchCount,
      mismatchCounts: report.semanticParity.mismatchCounts
    }
  };
});

// Corpus aggregation: pool case states across fixtures per lane.
function poolMetrics(entries, lane) {
  const all = entries.flatMap((entry) => entry[lane].caseStates);
  const positives = all.filter((entry) => entry.expected === "detected");
  const negatives = all.filter((entry) => entry.expected === "abstain");
  const truePositive = positives.filter((entry) => entry.detected).length;
  const falseNegative = positives.length - truePositive;
  const falsePositive = negatives.filter((entry) => entry.detected).length;
  const correctAbstention = negatives.length - falsePositive;
  return {
    cases: all.length,
    truePositive,
    falseNegative,
    falsePositive,
    correctAbstention,
    precision: truePositive + falsePositive > 0 ? truePositive / (truePositive + falsePositive) : null,
    recall: positives.length > 0 ? truePositive / positives.length : null,
    abstention: negatives.length > 0 ? correctAbstention / negatives.length : null
  };
}

const corpusReport = {
  schema: "pdf-editor.detector-semantic-comparison-corpus",
  version: { major: 1, minor: 0 },
  generatedAt: "2026-08-28T00:00:00.000Z",
  groundTruth: {
    schema: groundTruth.schema,
    caseCount: groundTruth.cases.length,
    fixtures: [...new Set(groundTruth.cases.map((entry) => entry.fixtureID))].length,
    reviewedOn: groundTruth.reviewedOn
  },
  policy: {
    matching: "reviewed-region-first-score-with-one-selected-candidate",
    minimumIoU: 0.25,
    perFixtureScoping: true,
    candidateSource: "candidates-channel plus fields-channel mapped as nativeField candidates (confirmed fields are not re-suggested)"
  },
  perFixture,
  corpus: {
    native: poolMetrics(perFixture, "native"),
    browser: poolMetrics(perFixture, "browser"),
    fixturePassCount: perFixture.filter((entry) => entry.passed).length,
    fixtureCount: perFixture.length,
    passed: perFixture.every((entry) => entry.passed)
  }
};

await fs.writeFile(reportPath, `${JSON.stringify(corpusReport, null, 2)}\n`);
console.log(`\n[corpus] ${corpusReport.corpus.fixturePassCount}/${corpusReport.corpus.fixtureCount} fixtures passed; overall passed=${corpusReport.corpus.passed}`);
console.log(`[corpus] native  precision=${corpusReport.corpus.native.precision?.toFixed(3)} recall=${corpusReport.corpus.native.recall?.toFixed(3)} abstention=${corpusReport.corpus.native.abstention?.toFixed(3)}`);
console.log(`[corpus] browser precision=${corpusReport.corpus.browser.precision?.toFixed(3)} recall=${corpusReport.corpus.browser.recall?.toFixed(3)} abstention=${corpusReport.corpus.browser.abstention?.toFixed(3)}`);
console.log(`[corpus] report: ${path.relative(projectRoot, reportPath)}`);