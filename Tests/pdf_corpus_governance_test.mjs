import assert from "node:assert/strict";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const testsDirectory = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(testsDirectory, "..");
const manifestPath = path.join(testsDirectory, "fixtures/pdf_corpus_governance_manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

assert.equal(manifest.schema, "pdf-editor.corpus-governance");
assert.equal(manifest.schemaVersion, "1.0.0");
assert.ok(manifest.privacyPolicy.prohibitedDefaults.includes("upload-source-bytes"));
assert.ok(manifest.provenancePolicy.requiredForEveryEntry.includes("sha256"));
assert.ok(manifest.validators.includes("privacy-zero-content-log"));
assert.ok(manifest.classes.includes("handwritten"));

const requiredFields = manifest.provenancePolicy.requiredForEveryEntry;
const seenIds = new Set();
const seenPaths = new Set();
const classCoverage = new Set();
const digestCoverage = new Set();
const qpdfChecks = [];
const providerProbes = [];

for (const fixture of manifest.fixtures) {
  assert.equal(seenIds.has(fixture.fixtureId), false, `duplicate fixture id: ${fixture.fixtureId}`);
  assert.equal(seenPaths.has(fixture.relativePath), false, `duplicate fixture path: ${fixture.relativePath}`);
  seenIds.add(fixture.fixtureId);
  seenPaths.add(fixture.relativePath);

  for (const field of requiredFields) {
    assert.ok(fixture[field] !== undefined, `${fixture.fixtureId} missing ${field}`);
  }
  assert.match(fixture.sha256, /^[0-9a-f]{64}$|^REPLACE_AFTER_GENERATION$/);
  assert.ok(fixture.documentClasses.length > 0);
  assert.ok(fixture.allowedOperations.length > 0);
  assert.ok(fixture.requiredValidators.length > 0);
  assert.ok(manifest.privacyPolicy.allowedClasses.includes(fixture.privacyClass));

  const artifactPath = path.join(root, fixture.relativePath);
  assert.equal(fs.existsSync(artifactPath), true, `missing corpus artifact: ${fixture.relativePath}`);
  if (fixture.sha256 !== "REPLACE_AFTER_GENERATION") {
    const digest = crypto.createHash("sha256").update(fs.readFileSync(artifactPath)).digest("hex");
    assert.equal(digest, fixture.sha256, `digest drift: ${fixture.fixtureId}`);
    digestCoverage.add(fixture.fixtureId);
  }

  const qpdfArgs = fixture.documentClasses.includes("encrypted")
    ? ["--password=reader-password", "--check", artifactPath]
    : ["--check", artifactPath];
  const qpdf = spawnSync("qpdf", qpdfArgs, { encoding: "utf8" });
  assert.equal(qpdf.error, undefined, "qpdf is required for governed corpus validation");
  const qpdfStatus = qpdf.status;
  const expectsSafeParseFailure = fixture.expectedInspection === "inspection-failed-safe";
  if (expectsSafeParseFailure) {
    assert.notEqual(qpdfStatus, 0, `${fixture.fixtureId} must remain malformed`);
  } else {
    assert.equal(qpdfStatus, 0, `${fixture.fixtureId} failed qpdf structural validation`);
  }
  qpdfChecks.push({
    fixtureId: fixture.fixtureId,
    qpdfStatus,
    expectedInspection: fixture.expectedInspection,
    passwordSupplied: fixture.documentClasses.includes("encrypted")
  });
  for (const documentClass of fixture.documentClasses) classCoverage.add(documentClass);

  if (fixture.groundTruthPath) {
    assert.equal(fs.existsSync(path.join(root, fixture.groundTruthPath)), true, `${fixture.fixtureId} missing ground truth`);
  }
  if (fixture.documentClasses.includes("handwritten")) {
    const imagePath = artifactPath.replace(/\.pdf$/i, ".png");
    assert.equal(fs.existsSync(imagePath), true, `${fixture.fixtureId} missing raster source`);
    const ocr = spawnSync("tesseract", [imagePath, "stdout", "--psm", "6"], { encoding: "utf8" });
    providerProbes.push({
      fixtureId: fixture.fixtureId,
      provider: "tesseract",
      status: ocr.error ? "unavailable" : ocr.status === 0 ? "completed" : "failed",
      outputBytes: Buffer.byteLength(ocr.stdout || "", "utf8"),
      contentLogged: false
    });
  }
  if (fixture.expectedInspection === "inspection-failed-safe") {
    assert.ok(fixture.allowedOperations.includes("safe-error"));
    assert.ok(fixture.allowedOperations.includes("no-export"));
  }
  if (fixture.documentClasses.includes("encrypted")) {
    assert.ok(fixture.passwordPolicy, `${fixture.fixtureId} missing password policy`);
    assert.ok(fixture.allowedOperations.includes("inspect-after-unlock"));
  }
  if (fixture.documentClasses.includes("handwritten")) {
    assert.ok(fixture.handwritingPolicy, `${fixture.fixtureId} missing handwriting policy`);
    assert.ok(fixture.allowedOperations.includes("handwriting-abstention"));
  }
}

for (const requiredClass of ["scanned", "rotated", "malformed", "encrypted", "handwritten", "mixed-content"]) {
  assert.ok(classCoverage.has(requiredClass), `missing governed class: ${requiredClass}`);
}
assert.ok(digestCoverage.size >= manifest.fixtures.length - 1, "too many unresolved artifact digests");

const report = {
  harness: "pdf-editor-corpus-governance",
  manifestId: manifest.manifestId,
  fixtureCount: manifest.fixtures.length,
  digestVerifiedCount: digestCoverage.size,
  classes: [...classCoverage].sort(),
  qpdfChecks,
  providerProbes,
  privacyPolicy: "zero-content logging and local-only default",
  contentLogging: "none",
  passed: true
};
const reportPath = path.join(root, "benchmark/results/governed-corpus/governance-report.json");
fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);

console.log(JSON.stringify({ ...report, reportPath: path.relative(root, reportPath) }, null, 2));
