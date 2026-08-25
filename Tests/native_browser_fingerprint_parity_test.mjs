import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  FINGERPRINT_PARITY_CONTRACT,
  buildStructuralFingerprint,
  compareStructuralFingerprints
} from "../web/pdf-fingerprint-parity.mjs";

const projectRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const fixturePath = path.join(projectRoot, "Tests/fixtures/pdf_fingerprint_parity_fixture.json");
const reportPath = path.join(projectRoot, "benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json");
assert.equal(fs.existsSync(fixturePath), true, "fingerprint parity fixture must exist");
assert.equal(fs.existsSync(reportPath), true, "fingerprint parity report must exist");

const fixtureText = fs.readFileSync(fixturePath, "utf8");
const fixture = JSON.parse(fixtureText);
const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
const fixtureCasesText = JSON.stringify(fixture.cases);

assert.deepEqual(fixture.contract.version, { major: 1, minor: 0 });
assert.deepEqual(report.contract.version, { major: 1, minor: 0 });
assert.equal(fixture.cases.length, 18);
assert.equal(report.aggregate.fixtureCount, 18);
assert.equal(report.aggregate.equalCount, 2);
assert.equal(report.aggregate.semanticDivergenceCount, 8);
assert.equal(report.aggregate.mixedDivergenceCount, 8);
assert.equal(report.aggregate.divergentFeatureCounts.permissions, 16);
assert.equal(report.aggregate.divergentFeatureCounts["pages.characterCounts"], 8);
assert.equal(report.aggregate.divergentFeatureCounts["candidates.count"], 2);
assert.equal(report.aggregate.divergentFeatureCounts["candidates.coordinateSpaceCounts"], 2);
assert.equal(report.aggregate.divergentFeatureCounts["pages.boxes"], 1);

for (const forbidden of ["generatedAt", "outputDigest", "provider", "labelText", "PDFBytes"]) {
  assert.equal(fixtureCasesText.includes(`"${forbidden}"`), false, `fixture cases must exclude ${forbidden}`);
}
for (const entry of fixture.cases) {
  if (entry.expectedFailure) {
    assert.equal(entry.native.status, "inspectionFailed", `${entry.sourcePath} native failure state`);
    assert.equal(entry.browser.status, "inspectionFailed", `${entry.sourcePath} browser failure state`);
  } else {
    assert.ok(entry.sourceDigest, `${entry.sourcePath} must retain source binding`);
    assert.equal(entry.native.source.sha256, entry.browser.source.sha256, `${entry.sourcePath} source digest parity`);
    assert.equal(entry.comparison.sourceBinding.digestEqual, true, `${entry.sourcePath} source binding`);
  }
}

const equalCase = fixture.cases.find((entry) => entry.comparison.status === "equal");
assert.ok(equalCase, "fixture should retain an equal failure-state case");
assert.deepEqual(equalCase.comparison.divergentFeatureIDs, []);
const baselineCase = fixture.cases.find((entry) => !entry.expectedFailure);
assert.ok(baselineCase, "fixture should retain a readable case for mutation checks");

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

const native = clone(baselineCase.native);
const browser = clone(baselineCase.browser);

const rotationMutation = clone(browser);
rotationMutation.pages.boxes[0].rotation += 90;
assert.ok(
  compareStructuralFingerprints(native, rotationMutation).divergentFeatureIDs.includes("pages.boxes"),
  "rotation mutation must be detected"
);

const permissionMutation = clone(browser);
permissionMutation.permissions = { ...permissionMutation.permissions, canPrint: !permissionMutation.permissions?.canPrint };
assert.ok(
  compareStructuralFingerprints(native, permissionMutation).divergentFeatureIDs.includes("permissions"),
  "permission mutation must be detected"
);

const sourceMutation = clone(browser);
sourceMutation.source.sha256 = "stale-source-digest";
const sourceComparison = compareStructuralFingerprints(native, sourceMutation);
assert.equal(sourceComparison.sourceBinding.digestEqual, false, "stale source digest must fail source binding");

const candidateCase = fixture.cases.find((entry) => entry.native.candidates.count > 0);
assert.ok(candidateCase, "fixture must contain a candidate-bearing case");
const candidateNative = clone(candidateCase.native);
const candidateBrowser = clone(candidateCase.browser);
candidateBrowser.candidates.count += 1;
assert.ok(
  compareStructuralFingerprints(candidateNative, candidateBrowser).divergentFeatureIDs.includes("candidates.count"),
  "candidate population mutation must be detected"
);

const coordinateMutation = clone(candidateCase.browser);
const coordinateKey = Object.keys(coordinateMutation.candidates.coordinateSpaceCounts)[0];
const coordinateValue = JSON.parse(coordinateKey);
coordinateValue.rotationDegrees = (coordinateValue.rotationDegrees || 0) + 90;
const replacementKey = JSON.stringify(coordinateValue);
delete coordinateMutation.candidates.coordinateSpaceCounts[coordinateKey];
coordinateMutation.candidates.coordinateSpaceCounts[replacementKey] = candidateCase.browser.candidates.coordinateSpaceCounts[coordinateKey];
assert.ok(
  compareStructuralFingerprints(candidateCase.native, coordinateMutation).divergentFeatureIDs.includes("candidates.coordinateSpaceCounts"),
  "coordinate-space mutation must be detected"
);

const textRepresentation = clone(baselineCase.browser);
textRepresentation.pages.characterCounts = textRepresentation.pages.characterCounts.map((value) => value + 1);
const textComparison = compareStructuralFingerprints(baselineCase.native, textRepresentation);
assert.equal(textComparison.features.find((feature) => feature.id === "pages.characterCounts").status, "representation-difference");

assert.equal(FINGERPRINT_PARITY_CONTRACT.ignoredRepresentationFields.includes("document.header.generatedAt"), true);
console.log("native/browser structural fingerprint parity: 18 fixtures, expected divergence clusters and mutation guards passed");
