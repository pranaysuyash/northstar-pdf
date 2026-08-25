import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync, spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(testDirectory, "..");
const ledgerPath = path.join(projectRoot, "Tests/fixtures/cross_project_evidence_ledger.json");
const parityFixturePath = path.join(projectRoot, "Tests/fixtures/pdf_corpus_semantic_parity_fixture.json");
const manifestPath = path.join(projectRoot, "docs/fixtures/manifest.md");
const parityReportPath = path.join(projectRoot, "benchmark/results/contract-parity-2026-08-24/parity-report.json");
const outputDirectory = path.join(projectRoot, "benchmark/results/cross-project-ledger");
const outputPath = path.join(outputDirectory, "2026-08-24-ledger-parity.json");
const port = 8184;
const baseURL = `http://127.0.0.1:${port}/web/index.html`;

function readJSON(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function sha256(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function manifestEntries() {
  const contents = fs.readFileSync(manifestPath, "utf8");
  return [...contents.matchAll(/^\| `([^`]+\.pdf)` \| `([0-9a-f]{64})` \|/gm)].map((match) => ({
    sourceFixture: match[1],
    sourceDigest: match[2]
  }));
}

async function waitForServer(url, timeoutMs = 15_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // The server is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Project-owned browser server did not start at ${url}`);
}

function startProjectServer() {
  return spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1"], {
    cwd: projectRoot,
    stdio: "ignore"
  });
}

function stopProjectServer(server) {
  if (!server || server.killed) return;
  server.kill("SIGINT");
}

function validateLedger(ledger) {
  assert.equal(ledger.ledgerName, "pdf-editor.cross-project-evidence-ledger");
  assert.deepEqual(ledger.ledgerVersion, { major: 1, minor: 0 });
  assert.equal(ledger.canonicalOwner, "/Users/pranay/Projects/pdf_editor");
  assert.equal(ledger.entries.length, 6);
  const ids = new Set();
  const sourceEvidence = [];
  for (const entry of ledger.entries) {
    assert.match(entry.id, /^CP-\d{3}$/);
    assert.equal(ids.has(entry.id), false, `duplicate evidence entry ${entry.id}`);
    ids.add(entry.id);
    assert.deepEqual(entry.version, { major: 1, minor: 0 });
    assert.ok(entry.projectID);
    assert.ok(entry.projectPath);
    assert.ok(entry.owner);
    assert.ok(entry.sourceFiles.length > 0);
    assert.ok(entry.inputs.length > 0);
    assert.ok(entry.outputs.length > 0);
    assert.ok(entry.transferablePrimitives.length > 0);
    assert.ok(entry.notImported.length > 0);
    assert.ok(entry.falsifier);
    assert.ok(entry.rollback);
    assert.ok(entry.importDecision);
    for (const sourceFile of entry.sourceFiles) {
      assert.equal(fs.existsSync(sourceFile), true, `ledger source is missing: ${sourceFile}`);
      const stat = fs.statSync(sourceFile);
      sourceEvidence.push({
        entryID: entry.id,
        projectID: entry.projectID,
        sourcePath: sourceFile,
        kind: stat.isDirectory() ? "directory" : "file",
        sha256: stat.isFile() ? sha256(sourceFile) : null
      });
    }
  }
  assert.deepEqual([...ids].sort(), ["CP-001", "CP-002", "CP-003", "CP-004", "CP-005", "CP-006"]);
  return sourceEvidence;
}

function validateParityFixture(fixture, ledger, manifest) {
  assert.equal(fixture.fixtureName, "pdf-editor.native-web-semantic-parity-corpus");
  assert.deepEqual(fixture.fixtureVersion, { major: 1, minor: 1 });
  assert.equal(fixture.corpusManifest, "docs/fixtures/manifest.md");
  assert.equal(fixture.normalizedComparator, "web/pdf-contract-parity.mjs");
  assert.equal(fixture.mutationHarness, "Tests/pdf_contract_parity_mutation_test.mjs");
  assert.equal(fixture.sourceIdentity, "sha256");
  assert.ok(fixture.semanticFields.includes("document.payload.source.sha256"));
  assert.ok(fixture.semanticFields.includes("coordinates.pages[]"));
  assert.ok(fixture.semanticFields.includes("editSession.operations[]"));
  assert.match(fixture.mismatchPolicy, /record-and-classify/);
  assert.equal(fixture.cases.length, manifest.length);
  const manifestByPath = new Map(manifest.map((entry) => [entry.sourceFixture, entry]));
  const ledgerIDs = new Set(ledger.entries.map((entry) => entry.id));
  const seen = new Set();
  for (const entry of fixture.cases) {
    assert.match(entry.id, /^PARITY-\d{3}$/);
    assert.equal(seen.has(entry.id), false, `duplicate parity case ${entry.id}`);
    seen.add(entry.id);
    const manifestEntry = manifestByPath.get(entry.sourceFixture);
    assert.ok(manifestEntry, `parity fixture is not in the manifest: ${entry.sourceFixture}`);
    assert.equal(fs.existsSync(path.join(projectRoot, entry.sourceFixture)), true);
    assert.deepEqual(entry.evidenceLedgerIDs.filter((id) => ledgerIDs.has(id)), entry.evidenceLedgerIDs);
    assert.ok(entry.evidenceLedgerIDs.length > 0);
    assert.equal(typeof entry.expectedFailure, "boolean");
    assert.ok(entry.expectedNativeStatus);
    assert.ok(entry.expectedBrowserStatus);
  }
  assert.deepEqual(
    fixture.cases.map((entry) => entry.sourceFixture).sort(),
    manifest.map((entry) => entry.sourceFixture).sort()
  );
}

const ledger = readJSON(ledgerPath);
const parityFixture = readJSON(parityFixturePath);
const manifest = manifestEntries();
const sourceEvidence = validateLedger(ledger);
validateParityFixture(parityFixture, ledger, manifest);

const server = startProjectServer();
let parityReport;
try {
  await waitForServer(baseURL);
  execFileSync(process.execPath, ["Tests/pdf_contract_parity_test.mjs"], {
    cwd: projectRoot,
    env: { ...process.env, PDF_PROOF_BASE_URL: baseURL },
    stdio: "inherit"
  });
  parityReport = readJSON(parityReportPath);
} finally {
  stopProjectServer(server);
}

assert.equal(parityReport.harness, "pdf-editor-native-web-contract-parity");
assert.deepEqual(parityReport.version, parityFixture.fixtureVersion);
assert.equal(parityReport.fixtureCount, parityFixture.cases.length);
const parityCasesByPath = new Map(parityFixture.cases.map((entry) => [entry.sourceFixture, entry]));
const reportCasesByPath = new Map(parityReport.fixtures.map((entry) => [entry.sourcePath, entry]));
const mismatchClassification = [];
const sourceIdentityDrift = [];
for (const manifestEntry of manifest) {
  const expected = parityCasesByPath.get(manifestEntry.sourceFixture);
  const actual = reportCasesByPath.get(manifestEntry.sourceFixture);
  assert.ok(actual, `parity report is missing ${manifestEntry.sourceFixture}`);
  const observedDigest = sha256(path.join(projectRoot, manifestEntry.sourceFixture));
  assert.equal(actual.sourceDigest, observedDigest);
  if (manifestEntry.sourceDigest !== observedDigest) {
    sourceIdentityDrift.push({
      sourceFixture: manifestEntry.sourceFixture,
      declaredManifestDigest: manifestEntry.sourceDigest,
      observedLiveDigest: observedDigest,
      disposition: "preserved-for-review; manifest-and-generated-artifact-were-not-rewritten"
    });
  }
  assert.equal(actual.expectedFailure, expected.expectedFailure);
  assert.equal(actual.nativeStatus, expected.expectedNativeStatus);
  assert.equal(actual.webStatus, expected.expectedBrowserStatus);
  const unexpected = actual.mismatches.filter((mismatch) => !expected.allowedOpenMismatchKinds.includes(mismatch.kind));
  assert.deepEqual(unexpected, [], `unexpected parity mismatch for ${manifestEntry.sourceFixture}`);
  mismatchClassification.push({
    sourceFixture: manifestEntry.sourceFixture,
    mismatchCount: actual.mismatchCount,
    mismatchKinds: [...new Set(actual.mismatches.map((mismatch) => mismatch.kind))].sort(),
    allowedOpenMismatchKinds: expected.allowedOpenMismatchKinds
  });
}

const report = {
  harness: "pdf-editor-cross-project-evidence-ledger-parity",
  version: { major: 1, minor: 0 },
  ledgerPath: path.relative(projectRoot, ledgerPath),
  parityFixturePath: path.relative(projectRoot, parityFixturePath),
  corpusManifest: path.relative(projectRoot, manifestPath),
  nativeBrowserParityReport: path.relative(projectRoot, parityReportPath),
  ledgerEntryCount: ledger.entries.length,
  corpusFixtureCount: parityFixture.cases.length,
  sourceEvidenceCount: sourceEvidence.length,
  sourceEvidence,
  parity: {
    fixtureCount: parityReport.fixtureCount,
    mismatchCount: parityReport.mismatchCount,
    mismatchCounts: parityReport.mismatchCounts,
    unexpectedMismatchCount: 0,
    classification: mismatchClassification
  },
  sourceIdentityDrift,
  passed: true,
  claimBoundary: "Ledger provenance and native/browser semantic parity pass; neighboring runtime reuse and universal PDF fidelity remain unproven."
};
fs.mkdirSync(outputDirectory, { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(JSON.stringify({
  harness: report.harness,
  ledgerEntryCount: report.ledgerEntryCount,
  corpusFixtureCount: report.corpusFixtureCount,
  sourceEvidenceCount: report.sourceEvidenceCount,
  parityMismatchCount: report.parity.mismatchCount,
  unexpectedMismatchCount: report.parity.unexpectedMismatchCount,
  passed: report.passed,
  reportPath: path.relative(projectRoot, outputPath)
}, null, 2));
