export const REVIEWED_COMPLETION_METRICS_VERSION = { major: 1, minor: 0 };

export const REVIEWED_COMPLETION_METRICS_CONTRACT = Object.freeze({
  schema: "pdf-editor.reviewed-completion-metrics",
  version: REVIEWED_COMPLETION_METRICS_VERSION,
  privacy: "value-free-counters-and-states-only",
  silentAutofillPolicy: "forbidden",
  primaryDenominator: "reviewed-correction-cases",
  abstentionStates: ["ambiguous", "stale", "noMatch"],
  hardNegativeState: "noMatch"
});

function ratio(numerator, denominator) {
  return denominator ? numerator / denominator : 0;
}

function selected(caseResult) {
  return caseResult.actualSelectedTemplateID ?? null;
}

function count(cases, predicate) {
  return cases.filter(predicate).length;
}

function requireArray(value, name) {
  if (!Array.isArray(value)) throw new Error(`${name} must be an array.`);
  return value;
}

export function computeReviewedCompletionMetrics({ correctionReport, matchingReport }) {
  if (!correctionReport || !matchingReport) {
    throw new Error("Correction and matching reports are required for completion metrics.");
  }
  const correctionCases = requireArray(correctionReport.cases, "correctionReport.cases");
  const matchingCases = requireArray(matchingReport.cases, "matchingReport.cases");
  const abstentionCases = matchingCases.filter((caseResult) =>
    REVIEWED_COMPLETION_METRICS_CONTRACT.abstentionStates.includes(caseResult.expectedState)
  );
  const hardNegativeCases = matchingCases.filter((caseResult) =>
    caseResult.expectedState === REVIEWED_COMPLETION_METRICS_CONTRACT.hardNegativeState
  );
  const hardNegativeReplays = correctionCases.flatMap((caseResult) => caseResult.hardNegativeResults || []);
  const privacyPassed = correctionReport.privacy?.passed === true;

  const improvedCorrectionCases = count(correctionCases, (caseResult) =>
    caseResult.promoted.reviewedTargetCount > caseResult.baseline.reviewedTargetCount
      && caseResult.promoted.eventStatus === "applied"
  );
  const rollbackRestoredCases = count(correctionCases, (caseResult) =>
    caseResult.rollback.historyUnchanged
      && caseResult.rollback.state === caseResult.baseline.state
      && caseResult.rollback.reviewedTargetCount === caseResult.baseline.reviewedTargetCount
  );
  const sourceBoundValidatedCases = count(correctionCases, (caseResult) =>
    caseResult.safeCompletion?.sourceDigestBound === true
      && caseResult.safeCompletion?.sourceUnchanged === true
      && caseResult.safeCompletion?.outputReopenable === true
  );
  const explicitReviewGuardedCases = count(correctionCases, (caseResult) =>
    caseResult.safeCompletion?.mappingReviewRequired === true
      && caseResult.safeCompletion?.valueReviewRequired === true
      && caseResult.safeCompletion?.materializationAllowedWithoutReview === false
  );
  const silentAutofillCount = count(correctionCases, (caseResult) =>
    caseResult.safeCompletion?.silentAutofillDetected === true
  );

  const abstainedCount = count(abstentionCases, (caseResult) => selected(caseResult) === null);
  const abstentionFailures = abstentionCases.filter((caseResult) => selected(caseResult) !== null);
  const hardNegativeSelections = count(hardNegativeCases, (caseResult) => selected(caseResult) !== null);
  const hardNegativeReplaySelections = count(hardNegativeReplays, (entry) => entry.selectedTemplateID !== null);

  const metrics = {
    schema: REVIEWED_COMPLETION_METRICS_CONTRACT.schema,
    version: { ...REVIEWED_COMPLETION_METRICS_VERSION },
    privacy: {
      valueFree: privacyPassed && correctionReport.privacy.valueFreeCorrectionRecords === true,
      sourceBytesStored: correctionReport.privacy.sourceBytesStored === true,
      rawLabelsStored: correctionReport.privacy.rawLabelsStored === true,
      profileValuesStored: Number(correctionReport.privacy.profileValueCount || 0) > 0,
      contentLogged: false
    },
    reviewedCorrection: {
      eligibleCaseCount: correctionCases.length,
      promotedCorrectionCount: count(correctionCases, (caseResult) => caseResult.promoted.eventStatus === "applied"),
      baselineReviewedTargetCount: correctionCases.reduce((sum, caseResult) => sum + caseResult.baseline.reviewedTargetCount, 0),
      promotedReviewedTargetCount: correctionCases.reduce((sum, caseResult) => sum + caseResult.promoted.reviewedTargetCount, 0),
      reviewedTargetCoverageLift: correctionCases.reduce((sum, caseResult) => sum + caseResult.promoted.reviewedTargetCount, 0)
        - correctionCases.reduce((sum, caseResult) => sum + caseResult.baseline.reviewedTargetCount, 0),
      improvedCaseCount: improvedCorrectionCases,
      improvementRate: ratio(improvedCorrectionCases, correctionCases.length),
      rollbackRestoredCount: rollbackRestoredCases,
      rollbackRestorationRate: ratio(rollbackRestoredCases, correctionCases.length)
    },
    abstention: {
      eligibleCaseCount: abstentionCases.length,
      abstainedCount,
      abstentionRate: ratio(abstainedCount, abstentionCases.length),
      failureCount: abstentionFailures.length,
      expectedStateCounts: abstentionCases.reduce((result, caseResult) => {
        result[caseResult.expectedState] = (result[caseResult.expectedState] || 0) + 1;
        return result;
      }, {})
    },
    hardNegative: {
      fixtureCount: hardNegativeCases.length,
      selectedCount: hardNegativeSelections,
      abstainedCount: hardNegativeCases.length - hardNegativeSelections,
      abstentionRate: ratio(hardNegativeCases.length - hardNegativeSelections, hardNegativeCases.length),
      falsePositiveRate: ratio(hardNegativeSelections, hardNegativeCases.length),
      promotionReplayCount: hardNegativeReplays.length,
      promotionReplaySelectedCount: hardNegativeReplaySelections,
      promotionReplayAbstentionRate: ratio(
        hardNegativeReplays.length - hardNegativeReplaySelections,
        hardNegativeReplays.length
      )
    },
    safeCompletion: {
      eligibleCaseCount: correctionCases.length,
      sourceBoundValidatedCount: sourceBoundValidatedCases,
      sourceBoundValidatedRate: ratio(sourceBoundValidatedCases, correctionCases.length),
      explicitReviewGuardedCount: explicitReviewGuardedCases,
      explicitReviewGuardedRate: ratio(explicitReviewGuardedCases, correctionCases.length),
      materializationAllowedWithoutReviewCount: count(correctionCases, (caseResult) =>
        caseResult.safeCompletion?.materializationAllowedWithoutReview === true
      ),
      silentAutofillCount,
      safeCompletionReadyCount: count(correctionCases, (caseResult) =>
        caseResult.safeCompletion?.reviewedTargetReadyForExplicitValueReview === true
      ),
      safeCompletionReadyRate: ratio(
        count(correctionCases, (caseResult) =>
          caseResult.safeCompletion?.reviewedTargetReadyForExplicitValueReview === true
        ),
        correctionCases.length
      )
    }
  };

  metrics.passed = matchingReport.passed === true
    && correctionReport.privacy?.passed === true
    && metrics.privacy.valueFree
    && metrics.reviewedCorrection.improvementRate > 0
    && metrics.abstention.failureCount === 0
    && metrics.hardNegative.selectedCount === 0
    && metrics.hardNegative.promotionReplaySelectedCount === 0
    && metrics.safeCompletion.sourceBoundValidatedCount === correctionCases.length
    && metrics.safeCompletion.explicitReviewGuardedCount === correctionCases.length
    && metrics.safeCompletion.materializationAllowedWithoutReviewCount === 0
    && metrics.safeCompletion.silentAutofillCount === 0;

  return metrics;
}
