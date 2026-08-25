import assert from "node:assert/strict";
import {
  calibrateDocumentClassPolicies,
  runReviewedTemplateBenchmark
} from "../web/template-match-benchmark.mjs";
import {
  computeReviewedCompletionMetrics
} from "../web/reviewed-completion-metrics.mjs";
import {
  runReviewedCorrectionBenchmark
} from "../web/template-correction-benchmark.mjs";
import { REVIEWED_TEMPLATE_FIXTURES } from "./fixtures/template_matching_reviewed_fixtures.mjs";

const calibration = calibrateDocumentClassPolicies(REVIEWED_TEMPLATE_FIXTURES);
const matchingReport = runReviewedTemplateBenchmark(REVIEWED_TEMPLATE_FIXTURES, {
  documentClassPolicies: calibration.policyByDocumentClass
});
const correctionReport = runReviewedCorrectionBenchmark({
  fixtures: REVIEWED_TEMPLATE_FIXTURES,
  calibration,
  matchingReport
});

const baseline = computeReviewedCompletionMetrics({ correctionReport, matchingReport });
assert.equal(baseline.passed, true);
assert.equal(baseline.safeCompletion.silentAutofillCount, 0);

const hardNegativeSelection = structuredClone(matchingReport);
const hardNegativeCase = hardNegativeSelection.cases.find((caseResult) => caseResult.expectedState === "noMatch");
hardNegativeCase.actualSelectedTemplateID = "unsafe-template";
const hardNegativeMetrics = computeReviewedCompletionMetrics({
  correctionReport,
  matchingReport: hardNegativeSelection
});
assert.equal(hardNegativeMetrics.hardNegative.selectedCount, 1);
assert.equal(hardNegativeMetrics.hardNegative.falsePositiveRate > 0, true);
assert.equal(hardNegativeMetrics.passed, false);

const reviewBypass = structuredClone(correctionReport);
reviewBypass.cases[0].safeCompletion.materializationAllowedWithoutReview = true;
reviewBypass.cases[0].safeCompletion.silentAutofillDetected = true;
const reviewBypassMetrics = computeReviewedCompletionMetrics({
  correctionReport: reviewBypass,
  matchingReport
});
assert.equal(reviewBypassMetrics.safeCompletion.materializationAllowedWithoutReviewCount, 1);
assert.equal(reviewBypassMetrics.safeCompletion.silentAutofillCount, 1);
assert.equal(reviewBypassMetrics.passed, false);

const privacyMutation = structuredClone(correctionReport);
privacyMutation.privacy.passed = false;
const privacyMetrics = computeReviewedCompletionMetrics({
  correctionReport: privacyMutation,
  matchingReport
});
assert.equal(privacyMetrics.passed, false);

const abstentionBypass = structuredClone(matchingReport);
const ambiguousCase = abstentionBypass.cases.find((caseResult) => caseResult.expectedState === "ambiguous");
ambiguousCase.actualSelectedTemplateID = "unsafe-ambiguous-selection";
const abstentionMetrics = computeReviewedCompletionMetrics({
  correctionReport,
  matchingReport: abstentionBypass
});
assert.equal(abstentionMetrics.abstention.failureCount, 1);
assert.equal(abstentionMetrics.passed, false);

console.log("reviewed completion metrics mutation suite: 5 checks passed");
