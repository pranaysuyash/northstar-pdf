import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  calibrateDocumentClassPolicies
} from "../web/template-match-benchmark.mjs";
import {
  containsCorrectionContent,
  createReviewedCorrection,
  promoteReviewedCorrection,
  runReviewedCorrectionBenchmark
} from "../web/template-correction-benchmark.mjs";
import { REVIEWED_TEMPLATE_FIXTURES } from "./fixtures/template_matching_reviewed_fixtures.mjs";

const outputPath = path.resolve(
  "benchmark/results/template-matching/2026-08-24-correction-benefit.json"
);
const calibration = calibrateDocumentClassPolicies(REVIEWED_TEMPLATE_FIXTURES);
assert.equal(calibration.passed, true);

const report = runReviewedCorrectionBenchmark({
  fixtures: REVIEWED_TEMPLATE_FIXTURES,
  calibration
});

assert.equal(report.passed, true, JSON.stringify(report, null, 2));
assert.equal(report.fixtureCount, 5);
assert.deepEqual(report.improvement, {
  baselineReviewedTargetCount: 0,
  promotedReviewedTargetCount: 5,
  reviewedTargetCoverageLift: 5,
  improvedCaseCount: 5,
  improvementRate: 1,
  allPromotionsImproved: true
});
assert.equal(report.rollback.passed, true);
assert.equal(report.rollback.baselineTargetCountAfterRollback, 0);
assert.equal(report.rollback.historyPreserved, true);
assert.equal(report.rollback.childRevisionsRemainAuditable, true);
assert.equal(report.hardNegativeAbstention.fixtureCount, 7);
assert.equal(report.hardNegativeAbstention.selectedCountAfterPromotion, 0);
assert.equal(report.hardNegativeAbstention.abstainedCountAfterPromotion, 35);
assert.equal(report.hardNegativeAbstention.passed, true);
assert.deepEqual(report.metrics.reviewedCorrection, {
  eligibleCaseCount: 5,
  promotedCorrectionCount: 5,
  baselineReviewedTargetCount: 0,
  promotedReviewedTargetCount: 5,
  reviewedTargetCoverageLift: 5,
  improvedCaseCount: 5,
  improvementRate: 1,
  rollbackRestoredCount: 5,
  rollbackRestorationRate: 1
});
assert.deepEqual(report.metrics.abstention, {
  eligibleCaseCount: 14,
  abstainedCount: 14,
  abstentionRate: 1,
  failureCount: 0,
  expectedStateCounts: { ambiguous: 6, stale: 1, noMatch: 7 }
});
assert.deepEqual(report.metrics.hardNegative, {
  fixtureCount: 7,
  selectedCount: 0,
  abstainedCount: 7,
  abstentionRate: 1,
  falsePositiveRate: 0,
  promotionReplayCount: 35,
  promotionReplaySelectedCount: 0,
  promotionReplayAbstentionRate: 1
});
assert.deepEqual(report.metrics.safeCompletion, {
  eligibleCaseCount: 5,
  sourceBoundValidatedCount: 5,
  sourceBoundValidatedRate: 1,
  explicitReviewGuardedCount: 5,
  explicitReviewGuardedRate: 1,
  materializationAllowedWithoutReviewCount: 0,
  silentAutofillCount: 0,
  safeCompletionReadyCount: 5,
  safeCompletionReadyRate: 1
});
assert.equal(report.metrics.passed, true);
assert.deepEqual(report.privacy, {
  passed: true,
  valueFreeCorrectionRecords: true,
  profileValueCount: 0,
  sourceBytesStored: false,
  rawLabelsStored: false
});

for (const result of report.cases) {
  assert.equal(result.baseline.state, "noMatch");
  assert.equal(result.baseline.selectedTemplateID, null);
  assert.equal(result.promoted.state, "exact");
  assert.ok(result.promoted.selectedTemplateID);
  assert.match(result.promoted.selectedTemplateID, /^template-class-/);
  assert.equal(result.promoted.reviewedTargetCount, 1);
  assert.equal(result.promoted.approvedMappingCount, 1);
  assert.equal(result.promoted.eventStatus, "applied");
  assert.equal(result.rollback.state, "noMatch");
  assert.equal(result.rollback.selectedTemplateID, null);
  assert.equal(result.rollback.reviewedTargetCount, 0);
  assert.equal(result.rollback.historyUnchanged, true);
  assert.equal(result.correctionRecordValueFree, true);
}

const hardNegative = REVIEWED_TEMPLATE_FIXTURES.find((fixture) => fixture.id === "public-acro-form-hard-negative");
const positive = REVIEWED_TEMPLATE_FIXTURES.find((fixture) => fixture.id === "public-acro-form-family-positive");
const template = positive.input.templates[0];
const correction = createReviewedCorrection({
  template,
  scenarioID: "hard-negative-rejection-probe",
  documentClass: hardNegative.documentClass,
  sourceDigest: hardNegative.input.sourceDigest,
  fingerprint: hardNegative.input.fingerprint
});
assert.throws(() => promoteReviewedCorrection({
  template,
  history: { templateID: template.payload.templateID, revisions: [template] },
  correction: { ...correction, reviewDecision: "hardNegative" },
  validation: {
    status: "validated",
    sourceUnchanged: true,
    outputReopenable: true,
    sourceDigest: hardNegative.input.sourceDigest,
    checks: [{ status: "passed", kind: "outputReopen" }]
  }
}), /same-family/);

assert.equal(containsCorrectionContent({ note: "Ada Lovelace" }), true);
assert.equal(containsCorrectionContent({ note: "reviewed structural correction" }), false);
const serializedReport = JSON.stringify(report);
assert.equal(serializedReport.includes("Ada Lovelace"), false);
assert.equal(serializedReport.includes("%PDF-"), false);
assert.equal(serializedReport.includes("passphrase"), false);
assert.equal(serializedReport.includes("silentAutofillDetected\\\":true"), false);

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);

console.log(JSON.stringify({
  benchmark: report.benchmark,
  fixtureCount: report.fixtureCount,
  passed: report.passed,
  reviewedTargetCoverageLift: report.improvement.reviewedTargetCoverageLift,
  hardNegativeAbstention: report.hardNegativeAbstention,
  rollback: report.rollback,
  privacy: report.privacy,
  outputPath
}, null, 2));
