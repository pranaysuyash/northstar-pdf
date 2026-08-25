import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const projectRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const reportPath = path.join(projectRoot, "benchmark/results/semantic-parity/2026-08-25/parity-report.json");
assert.equal(fs.existsSync(reportPath), true, "fresh semantic parity report must exist");

const reportText = fs.readFileSync(reportPath, "utf8");
const report = JSON.parse(reportText);
const policy = report.normalizationContract?.policy;

assert.deepEqual(report.version, { major: 1, minor: 1 });
assert.equal(report.corpusManifest, "docs/fixtures/manifest.md");
assert.equal(report.fixtureCount, 18);
assert.equal(report.unexpectedMismatchCount, 0);
assert.deepEqual(report.unexpectedMismatchCounts, {});
assert.equal(policy.outputDigestComparison, "never-semantic-equality");
for (const field of [
  "document.header.provider.id",
  "document.header.generatedAt",
  "document.payload.fields[].id",
  "document.payload.candidates[].id",
  "document.payload.candidates[].evidenceItems[].id",
  "editSession.operations[].id",
  "validation.checks[].id",
  "validation.outputDigest"
]) {
  assert.ok(policy.ignoredRepresentationFields.includes(field), `normalization policy missing ${field}`);
}

assert.equal(report.fixtures.length, report.fixtureCount);
for (const fixture of report.fixtures) {
  assert.equal(fixture.nativeStatus, fixture.webStatus, `${fixture.sourcePath} status parity`);
  assert.equal(fixture.normalization.native.outputDigestCompared, false);
  assert.equal(fixture.normalization.browser.outputDigestCompared, false);
  assert.equal(fixture.normalization.semanticProjectionDigest.comparatorEquivalent, fixture.mismatchCount === 0);
  assert.equal(fixture.sourceBinding.expectedFailure, fixture.expectedFailure);
  if (!fixture.expectedFailure) {
    assert.equal(fixture.sourceBinding.nativeMatchesLive, true, `${fixture.sourcePath} native source binding`);
    assert.equal(fixture.sourceBinding.browserMatchesLive, true, `${fixture.sourcePath} browser source binding`);
  }
}

assert.equal(reportText.includes('"outputDigest":'), false, "report must not expose provider output digest values");
assert.equal(reportText.includes('"generatedAt":'), false, "report must not compare or copy provider timestamps");
console.log(`native/browser semantic parity report: ${report.fixtureCount} fixtures, ${report.mismatchCount} declared mismatches, 0 unexpected`);
