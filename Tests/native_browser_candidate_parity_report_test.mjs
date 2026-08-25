import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildCandidateParityReport,
  compareCandidateBundles,
  CANDIDATE_PARITY_CONTRACT
} from "../web/candidate-parity.mjs";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");
const resultRoot = path.join(projectRoot, "benchmark/results/semantic-parity/2026-08-25");
const nativeDirectory = path.join(resultRoot, "native");
const browserDirectory = path.join(resultRoot, "web");
const reportPath = path.join(resultRoot, "candidate-parity-report.json");

function corpusFromManifest() {
  const manifest = fs.readFileSync(manifestPath, "utf8");
  return [...manifest.matchAll(/^\| `([^`]+\.pdf)` \|/gm)].map((match) => match[1]);
}

function fileNameFor(relativePath) {
  return relativePath.replaceAll("/", "__").replace(/\.pdf$/i, ".json");
}

function expectedFailure(relativePath) {
  return relativePath.includes("truncated-128-bytes.pdf") || relativePath.includes("malformed-");
}

function sourceDigest(relativePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(projectRoot, relativePath))).digest("hex");
}

function readBundle(directory, relativePath) {
  const filePath = path.join(directory, fileNameFor(relativePath));
  assert.equal(fs.existsSync(filePath), true, `missing parity bundle: ${filePath}`);
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

const corpus = corpusFromManifest();
assert.equal(corpus.length, 18, "the candidate report must use the current 18-fixture corpus");
const fixtures = corpus.map((relativePath) => {
  const nativeBundle = readBundle(nativeDirectory, relativePath);
  const browserBundle = readBundle(browserDirectory, relativePath);
  const digest = nativeBundle.document?.payload?.source?.sha256 || nativeBundle.sourceDigest || sourceDigest(relativePath);
  return compareCandidateBundles(nativeBundle, browserBundle, {
    sourcePath: relativePath,
    sourceDigest: digest,
    expectedFailure: expectedFailure(relativePath)
  });
});

const report = buildCandidateParityReport({
  corpusManifest: "docs/fixtures/manifest.md",
  fixtures
});
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

assert.deepEqual(report.version, CANDIDATE_PARITY_CONTRACT.version);
assert.equal(report.fixtureCount, 18);
assert.equal(report.passed, true);
assert.ok(report.aggregate.nativeCount > 0, "corpus should include native static candidates");
assert.ok(report.aggregate.browserCount > 0, "corpus should include browser static candidates");
assert.ok(report.aggregate.nativeOnlyCount > 0 || report.aggregate.browserOnlyCount > 0,
  "the report should expose provider-specific candidate sets");
assert.ok(report.aggregate.mismatchCounts.candidateKind || report.aggregate.mismatchCounts.fieldType || report.aggregate.mismatchCounts.grouping,
  "the report should expose semantic candidate differences");
assert.equal(report.generatedAtPresent, false, "the report should not persist timestamps by default");

const staticFixture = fixtures.find((fixture) => fixture.sourcePath.includes("pdfkit-form6-run-2026-08-23/noop.pdf"));
assert.ok(staticFixture, "static Form 6 candidate fixture should be present");
assert.ok(staticFixture.metrics.nativeCount > 0);
assert.ok(staticFixture.metrics.browserCount > 0);
assert.ok(staticFixture.metrics.nativeOnlyCount > 0 || staticFixture.metrics.browserOnlyCount > 0);

const reportText = fs.readFileSync(reportPath, "utf8");
assert.equal(reportText.includes('"labelText":'), false, "candidate label fields must not enter the parity artifact");
assert.equal(reportText.includes('"text":'), false, "provider evidence prose fields must not enter the parity artifact");
assert.equal(reportText.includes('"generatedAt":'), false, "timestamps must not enter the parity artifact");
assert.equal(reportText.includes('"outputDigest":'), false, "output digests must not enter the parity artifact");

console.log(JSON.stringify({
  reportPath: path.relative(projectRoot, reportPath),
  fixtureCount: report.fixtureCount,
  aggregate: report.aggregate,
  staticFixture: {
    nativeCount: staticFixture.metrics.nativeCount,
    browserCount: staticFixture.metrics.browserCount,
    matchedCount: staticFixture.metrics.matchedCount,
    nativeOnlyCount: staticFixture.metrics.nativeOnlyCount,
    browserOnlyCount: staticFixture.metrics.browserOnlyCount,
    mismatchCounts: staticFixture.mismatchCounts
  }
}, null, 2));
