import assert from "node:assert/strict";
import {
  DEFAULT_TEMPLATE_MATCH_POLICY,
  runReviewedTemplateBenchmark
} from "../web/template-match-benchmark.mjs";
import {
  REVIEWED_TEMPLATE_BENCHMARK_METADATA,
  REVIEWED_TEMPLATE_FIXTURES
} from "./fixtures/template_matching_reviewed_fixtures.mjs";

const report = runReviewedTemplateBenchmark(REVIEWED_TEMPLATE_FIXTURES);
assert.equal(report.passed, true, JSON.stringify(report.failures, null, 2));
assert.equal(report.fixtureCount, 7);
assert.deepEqual(report.counts, {
  exact: 1,
  knownVariant: 1,
  familyMatch: 1,
  ambiguous: 1,
  stale: 1,
  noMatch: 2
});

for (const result of report.cases) {
  assert.equal(result.passed, true, `${result.id} did not satisfy its review decision`);
  if (["ambiguous", "stale", "noMatch"].includes(result.expectedState)) {
    assert.equal(result.actualSelectedTemplateID, null, `${result.id} must abstain`);
  }
}

const falsePositiveCases = report.cases.filter((result) => result.expectedState === "noMatch");
assert.equal(falsePositiveCases.length, 2);
assert.ok(falsePositiveCases.every((result) => result.noSelectionPassed));
assert.ok(falsePositiveCases.every((result) => result.forbiddenPassed));

const thresholdMutation = runReviewedTemplateBenchmark(REVIEWED_TEMPLATE_FIXTURES, {
  ...DEFAULT_TEMPLATE_MATCH_POLICY,
  familyThreshold: 0.10,
  ambiguityMargin: 0
});
assert.equal(thresholdMutation.passed, false, "weakened thresholds must fail the benchmark");
assert.ok(
  thresholdMutation.failures.some((failure) => failure.id === "near-family-negative"),
  "the near-family false positive must detect a weakened family threshold"
);
assert.ok(
  thresholdMutation.failures.some((failure) => failure.id === "ambiguous-family-choice"),
  "the ambiguity gate must detect a policy that removes the ambiguity margin"
);

const privacyText = JSON.stringify(REVIEWED_TEMPLATE_FIXTURES);
assert.equal(privacyText.includes("Applicant"), false);
assert.equal(privacyText.includes("Ada Lovelace"), false);
assert.equal(privacyText.includes("sha256:"), true, "source identities remain explicit benchmark inputs");
assert.equal(REVIEWED_TEMPLATE_BENCHMARK_METADATA.privacy.includes("No labels"), true);

console.log(JSON.stringify({
  benchmark: "reviewed-template-matching",
  fixtureCount: report.fixtureCount,
  counts: report.counts,
  familyThreshold: report.policy.familyThreshold,
  ambiguityMargin: report.policy.ambiguityMargin,
  falsePositiveGates: falsePositiveCases.map((result) => ({
    id: result.id,
    score: result.score,
    selected: result.actualSelectedTemplateID,
    passed: result.passed
  })),
  mutationGate: {
    weakenedPolicyDetected: !thresholdMutation.passed,
    failures: thresholdMutation.failures.map((failure) => failure.id)
  },
  privacy: "value-free keyed fixture records"
}, null, 2));
