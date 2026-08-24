import assert from "node:assert/strict";
import {
  DEFAULT_TEMPLATE_MATCH_POLICY,
  calibrateDocumentClassPolicies,
  runReviewedTemplateBenchmark
} from "../web/template-match-benchmark.mjs";
import {
  REVIEWED_TEMPLATE_BENCHMARK_METADATA,
  REVIEWED_TEMPLATE_FIXTURES
} from "./fixtures/template_matching_reviewed_fixtures.mjs";

const report = runReviewedTemplateBenchmark(REVIEWED_TEMPLATE_FIXTURES);
assert.equal(report.passed, true, JSON.stringify(report.failures, null, 2));
assert.equal(report.fixtureCount, REVIEWED_TEMPLATE_FIXTURES.length);
assert.deepEqual(report.counts, {
  exact: 2,
  knownVariant: 2,
  familyMatch: 6,
  ambiguous: 6,
  stale: 1,
  noMatch: 7
});

for (const result of report.cases) {
  assert.equal(result.passed, true, `${result.id} did not satisfy its review decision`);
  if (["ambiguous", "stale", "noMatch"].includes(result.expectedState)) {
    assert.equal(result.actualSelectedTemplateID, null, `${result.id} must abstain`);
  }
}

const falsePositiveCases = report.cases.filter((result) => result.expectedState === "noMatch");
assert.equal(falsePositiveCases.length, 7);
assert.ok(falsePositiveCases.every((result) => result.noSelectionPassed));
assert.ok(falsePositiveCases.every((result) => result.forbiddenPassed));

for (const fixture of REVIEWED_TEMPLATE_FIXTURES) {
  assert.ok(fixture.documentClass, `${fixture.id} must identify a document class`);
  assert.equal(fixture.reviewLabel.reviewer, "corpus-curator");
  assert.equal(fixture.reviewLabel.independentAgreement, "not-measured");
}

const calibration = calibrateDocumentClassPolicies(REVIEWED_TEMPLATE_FIXTURES);
assert.equal(calibration.passed, true, JSON.stringify(calibration, null, 2));
assert.deepEqual(Object.keys(calibration.policyByDocumentClass), [
  "nativeWidget",
  "publicAcroForm",
  "rotatedNativeWidget",
  "rotatedStaticForm",
  "scannedDocument",
  "staticPrintedForm"
]);
for (const [documentClass, result] of Object.entries(calibration.classes)) {
  if (documentClass === "scannedDocument") {
    assert.equal(result.policy.familyAcceptance, "disabled");
    assert.equal(result.policy.calibrationStatus, "insufficientEvidence");
  } else {
    assert.equal(result.policy.familyAcceptance, "review");
    assert.equal(result.policy.calibrationStatus, "calibrated");
    assert.equal(result.policy.evidence.falsePositiveGate, true);
    assert.ok(
      result.policy.evidence.maximumNegativeScore < result.policy.familyThreshold,
      `${documentClass} threshold must clear its hardest negative`
    );
    assert.ok(
      result.policy.familyThreshold <= result.policy.evidence.minimumPositiveScore,
      `${documentClass} threshold must retain its weakest positive`
    );
  }
}

const calibratedReport = runReviewedTemplateBenchmark(REVIEWED_TEMPLATE_FIXTURES, {
  documentClassPolicies: calibration.policyByDocumentClass
});
assert.equal(calibratedReport.passed, true, JSON.stringify(calibratedReport.failures, null, 2));

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

const weakenedClassPolicies = Object.fromEntries(
  Object.entries(calibration.policyByDocumentClass).map(([documentClass, classPolicy]) => [
    documentClass,
    { ...classPolicy, familyThreshold: 0, ambiguityMargin: 0, familyAcceptance: "review" }
  ])
);
const classMutation = runReviewedTemplateBenchmark(REVIEWED_TEMPLATE_FIXTURES, {
  documentClassPolicies: weakenedClassPolicies
});
assert.equal(classMutation.passed, false, "weakened class policies must fail the benchmark");
assert.ok(
  classMutation.failures.some((failure) => failure.expectedState === "noMatch"),
  "class threshold mutation must expose at least one false positive"
);
assert.ok(
  classMutation.failures.some((failure) => failure.expectedState === "ambiguous"),
  "class ambiguity mutation must expose at least one unsafe selection"
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
  classes: Object.fromEntries(Object.entries(calibration.classes).map(([documentClass, result]) => [
    documentClass,
    {
      fixtureCount: result.fixtureCount,
      familyThreshold: result.policy.familyThreshold,
      ambiguityMargin: result.policy.ambiguityMargin,
      familyAcceptance: result.policy.familyAcceptance,
      calibrationStatus: result.policy.calibrationStatus,
      minimumPositiveScore: result.policy.evidence.minimumPositiveScore,
      maximumNegativeScore: result.policy.evidence.maximumNegativeScore,
      falsePositiveGate: result.policy.evidence.falsePositiveGate
    }
  ])),
  falsePositiveGates: falsePositiveCases.map((result) => ({
    id: result.id,
    score: result.score,
    selected: result.actualSelectedTemplateID,
    passed: result.passed
  })),
  mutationGate: {
    weakenedPolicyDetected: !thresholdMutation.passed,
    failures: thresholdMutation.failures.map((failure) => failure.id),
    weakenedClassPolicyDetected: !classMutation.passed,
    classFailures: classMutation.failures.map((failure) => failure.id)
  },
  privacy: "value-free keyed fixture records"
}, null, 2));
