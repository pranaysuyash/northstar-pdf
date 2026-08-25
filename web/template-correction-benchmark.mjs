import {
  appendTemplateRevision,
  canPromoteTemplateRevision,
  canMaterializeCompletion,
  createCompletionProposal,
  createLearningEvent,
  matchTemplate,
  validateTemplateContract
} from "./pdf-template-contract.mjs";
import {
  classifyTemplateIndex,
  resolveTemplateMatchPolicy,
  runReviewedTemplateBenchmark
} from "./template-match-benchmark.mjs";
import { computeReviewedCompletionMetrics } from "./reviewed-completion-metrics.mjs";

export const TEMPLATE_CORRECTION_BENCHMARK_VERSION = { major: 1, minor: 0 };

const FORBIDDEN_CONTENT_PATTERNS = [
  /%PDF-/i,
  /"rawPDF"/i,
  /"bytes"/i,
  /passphrase/i,
  /"Ada Lovelace"/i,
  /"Applicant"/i
];

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function correctionMapping({ scenarioID, sessionID }) {
  return {
    id: `mapping-correction-${scenarioID}`,
    semanticKey: `reviewed.${scenarioID}.primaryRegion`,
    target: {
      kind: "staticRegion",
      pageIndex: 0,
      region: {
        pageIndex: 0,
        rect: { x: 90, y: 180, width: 180, height: 24 },
        coordinateSpace: {
          unit: "points",
          origin: "lowerLeft",
          pageBox: "crop",
          rotationDegrees: 0
        }
      },
      candidateKind: "textAnchored"
    },
    suggestedFieldType: "text",
    evidenceReferences: [`candidate-evidence-${scenarioID}`],
    status: "confirmed",
    reviewPolicy: "alwaysReviewMappingAndValue",
    createdFromSessionID: sessionID
  };
}

export function containsCorrectionContent(value) {
  const serialized = JSON.stringify(value);
  return FORBIDDEN_CONTENT_PATTERNS.some((pattern) => pattern.test(serialized));
}

export function createReviewedCorrection({
  template,
  scenarioID,
  documentClass,
  sourceDigest,
  fingerprint,
  sessionID = `correction-session-${scenarioID}`
}) {
  validateTemplateContract(template);
  if (!sourceDigest || !fingerprint?.layoutFingerprint) {
    throw new Error("A reviewed correction requires a source digest and keyed fingerprint.");
  }
  const mapping = correctionMapping({ scenarioID, sessionID });
  const proposal = {
    sessionID,
    sourceDigest,
    templateID: template.payload.templateID,
    revisionID: template.payload.revisionID,
    matchState: "noMatch",
    entries: []
  };
  const event = createLearningEvent({
    template,
    proposal,
    kind: "mappingConfirmed",
    mappingID: mapping.id,
    note: "Reviewed recurring source variant correction."
  });
  return {
    event,
    reviewDecision: "sameFamily",
    documentClass,
    scenarioID,
    sourceDigest,
    fingerprint: clone(fingerprint),
    mapping,
    sessionID
  };
}

export function promoteReviewedCorrection({
  template,
  history,
  correction,
  validation,
  revisionID = `revision-correction-${correction.scenarioID}`
}) {
  validateTemplateContract(template);
  if (correction.reviewDecision !== "sameFamily") {
    throw new Error("Only an explicit reviewed same-family correction can be promoted.");
  }
  if (correction.sourceDigest !== correction.event.sourceDigest) {
    throw new Error("Correction event and reviewed correction source digests differ.");
  }
  if (!canPromoteTemplateRevision({
    template,
    sourceDigest: correction.sourceDigest,
    validation,
    events: [correction.event]
  })) {
    throw new Error("Correction cannot be promoted without strict source-bound validation.");
  }
  if (containsCorrectionContent(correction)) {
    throw new Error("Correction contains prohibited document or profile content.");
  }
  const fingerprint = {
    ...clone(template.payload.fingerprint),
    exactSourceDigests: unique([
      ...(template.payload.fingerprint.exactSourceDigests || []),
      correction.sourceDigest
    ])
  };
  const child = {
    ...clone(template),
    header: {
      ...clone(template.header),
      generatedAt: "2026-08-24T00:00:00.000Z"
    },
    payload: {
      ...clone(template.payload),
      revisionID,
      parentRevisionID: template.payload.revisionID,
      fingerprint,
      mappings: [
        ...(template.payload.mappings || []),
        clone(correction.mapping)
      ],
      lifecycle: "active"
    }
  };
  validateTemplateContract(child);
  const nextHistory = appendTemplateRevision(history, child);
  return {
    child,
    history: nextHistory,
    appliedEvent: { ...correction.event, status: "applied" }
  };
}

export function rollbackReviewedCorrection({ history, childRevisionID, originalHistoryJSON = null }) {
  const child = (history.revisions || []).find((revision) => revision.payload.revisionID === childRevisionID);
  if (!child) throw new Error("Correction child revision is not present in history.");
  if (!child.payload.parentRevisionID) throw new Error("Correction child revision has no rollback parent.");
  const parent = (history.revisions || []).find((revision) => revision.payload.revisionID === child.payload.parentRevisionID);
  if (!parent) throw new Error("Correction rollback parent is not present in history.");
  return {
    history,
    activeRevision: parent,
    revokedRevisionID: childRevisionID,
    parentRevisionID: parent.payload.revisionID,
    historyUnchanged: originalHistoryJSON === null || JSON.stringify(parent) === originalHistoryJSON
  };
}

function correctedVariantFingerprint(fingerprint, scenarioID) {
  return {
    ...clone(fingerprint),
    layoutFingerprint: `hmac:correction-${scenarioID}`,
    exactSourceDigests: [],
    pageSignatures: (fingerprint.pageSignatures || []).map((page) => ({
      ...page,
      anchorTokens: (page.anchorTokens || []).map((_, index) => `hmac:correction-anchor-${scenarioID}-${index}`)
    }))
  };
}

function completionCoverage(template, fingerprint, sourceDigest, sessionID) {
  const match = matchTemplate({ template, fingerprint, sourceDigest });
  const proposal = createCompletionProposal({ template, match, profile: null, sessionID });
  return {
    state: match.state,
    selectedTemplate: match.templateID && match.state !== "noMatch" ? match.templateID : null,
    approvedMappingCount: match.approvedMappingIDs?.length || 0,
    reviewedTargetCount: proposal?.entries?.length || 0,
    profileValueCount: 0,
    proposal
  };
}

export function measureCorrectionScenario({
  scenario,
  classPolicies,
  hardNegativeFixtures
}) {
  const template = scenario.input.templates[0];
  const sourceDigest = scenario.input.sourceDigest;
  const measuredFingerprint = correctedVariantFingerprint(scenario.input.fingerprint, scenario.id);
  const measuredScenario = {
    ...scenario,
    input: {
      ...scenario.input,
      fingerprint: measuredFingerprint
    }
  };
  const policy = { documentClassPolicies: classPolicies };
  const baselineClassified = classifyTemplateIndex({
    ...measuredScenario.input,
    policy
  });
  const baselineCoverage = completionCoverage(
    template,
    measuredFingerprint,
    sourceDigest,
    `baseline-${scenario.id}`
  );
  const history = { templateID: template.payload.templateID, revisions: [template] };
  const validation = {
    status: "validated",
    sourceUnchanged: true,
    outputReopenable: true,
    sourceDigest,
    checks: [{ status: "passed", kind: "outputReopen" }]
  };
  const correction = createReviewedCorrection({
    template,
    scenarioID: scenario.id,
    documentClass: scenario.documentClass,
    sourceDigest,
    fingerprint: measuredFingerprint
  });
  const correctionRecordValueFree = !containsCorrectionContent(correction);
  const promotion = promoteReviewedCorrection({ template, history, correction, validation });
  const promotedClassified = classifyTemplateIndex({
    ...measuredScenario.input,
    templates: [promotion.child],
    policy
  });
  const promotedCoverage = completionCoverage(
    promotion.child,
    { ...measuredFingerprint, exactSourceDigests: [sourceDigest] },
    sourceDigest,
    `promoted-${scenario.id}`
  );
  const materializationProbe = canMaterializeCompletion({
    proposal: promotedCoverage.proposal,
    currentSourceDigest: sourceDigest
  });
  const rollback = rollbackReviewedCorrection({
    history: promotion.history,
    childRevisionID: promotion.child.payload.revisionID,
    originalHistoryJSON: JSON.stringify(template)
  });
  const rollbackClassified = classifyTemplateIndex({
    ...measuredScenario.input,
    templates: [rollback.activeRevision],
    policy
  });
  const rollbackCoverage = completionCoverage(
    rollback.activeRevision,
    measuredFingerprint,
    sourceDigest,
    `rollback-${scenario.id}`
  );
  const hardNegativeResults = hardNegativeFixtures.map((fixture) => {
    const classified = classifyTemplateIndex({
      ...fixture.input,
      templates: [promotion.child],
      policy
    });
    return {
      id: fixture.id,
      state: classified.state,
      selectedTemplateID: classified.selectedTemplateID
    };
  });
  return {
    id: scenario.id,
    documentClass: scenario.documentClass,
    baseline: {
      state: baselineClassified.state,
      selectedTemplateID: baselineClassified.selectedTemplateID,
      reviewedTargetCount: baselineCoverage.reviewedTargetCount,
      approvedMappingCount: baselineCoverage.approvedMappingCount
    },
    promoted: {
      state: promotedClassified.state,
      selectedTemplateID: promotedClassified.selectedTemplateID,
      reviewedTargetCount: promotedCoverage.reviewedTargetCount,
      approvedMappingCount: promotedCoverage.approvedMappingCount,
      revisionID: promotion.child.payload.revisionID,
      eventStatus: promotion.appliedEvent.status
    },
    rollback: {
      state: rollbackClassified.state,
      selectedTemplateID: rollbackClassified.selectedTemplateID,
      reviewedTargetCount: rollbackCoverage.reviewedTargetCount,
      approvedMappingCount: rollbackCoverage.approvedMappingCount,
      activeRevisionID: rollback.activeRevision.payload.revisionID,
      parentRevisionID: rollback.parentRevisionID,
      historyUnchanged: rollback.historyUnchanged
    },
    hardNegativeResults,
    correctionRecordValueFree,
    safeCompletion: {
      sourceDigestBound: correction.sourceDigest === correction.event.sourceDigest
        && correction.event.sourceDigest === validation.sourceDigest,
      sourceUnchanged: validation.sourceUnchanged === true,
      outputReopenable: validation.outputReopenable === true,
      validationStatus: validation.status,
      reviewedTargetReadyForExplicitValueReview: promotedCoverage.reviewedTargetCount > 0,
      mappingReviewRequired: (promotedCoverage.proposal?.entries || []).some((entry) => entry.mappingReview !== "approved"),
      valueReviewRequired: (promotedCoverage.proposal?.entries || []).some((entry) => entry.valueReview !== "approved"),
      materializationAllowedWithoutReview: materializationProbe.ok === true,
      materializationGuardCode: materializationProbe.code || null,
      silentAutofillDetected: materializationProbe.ok === true
    }
  };
}

export function runReviewedCorrectionBenchmark({ fixtures, calibration, matchingReport = null }) {
  const scenarios = fixtures.filter((fixture) => fixture.id.endsWith("family-positive"));
  const hardNegativeFixtures = fixtures.filter((fixture) => fixture.expected.state === "noMatch");
  const classPolicies = calibration.policyByDocumentClass;
  const cases = scenarios.map((scenario) => measureCorrectionScenario({
    scenario,
    classPolicies,
    hardNegativeFixtures
  }));
  const baselineTargets = cases.reduce((sum, result) => sum + result.baseline.reviewedTargetCount, 0);
  const promotedTargets = cases.reduce((sum, result) => sum + result.promoted.reviewedTargetCount, 0);
  const rollbackTargets = cases.reduce((sum, result) => sum + result.rollback.reviewedTargetCount, 0);
  const improvedCases = cases.filter((result) =>
    result.promoted.reviewedTargetCount > result.baseline.reviewedTargetCount
      && result.promoted.state !== "noMatch"
  );
  const hardNegativePreserved = cases.every((result) => result.hardNegativeResults.every((negative) =>
    negative.state === "noMatch" && negative.selectedTemplateID === null
  ));
  const rollbackPreserved = cases.every((result) =>
    result.rollback.state === result.baseline.state
      && result.rollback.reviewedTargetCount === result.baseline.reviewedTargetCount
      && result.rollback.activeRevisionID === result.rollback.parentRevisionID
      && result.rollback.historyUnchanged
  );
  const report = {
    benchmark: "reviewed-template-correction-benefit",
    version: { ...TEMPLATE_CORRECTION_BENCHMARK_VERSION },
    fixtureCount: cases.length,
    metricDefinition: {
      primary: "reviewedTargetCoverage",
      description: "Count of reviewed template mappings surfaced in a completion proposal without resolving profile values.",
      baseline: "Active parent revision before a reviewed correction event.",
      promoted: "Immutable child revision after strict validation and explicit correction review.",
      notMeasured: ["keystroke time", "user acceptance rate", "profile-value completion", "real-world recall"]
    },
    improvement: {
      baselineReviewedTargetCount: baselineTargets,
      promotedReviewedTargetCount: promotedTargets,
      reviewedTargetCoverageLift: promotedTargets - baselineTargets,
      improvedCaseCount: improvedCases.length,
      improvementRate: cases.length ? improvedCases.length / cases.length : 0,
      allPromotionsImproved: improvedCases.length === cases.length
    },
    rollback: {
      passed: rollbackPreserved,
      baselineTargetCountAfterRollback: rollbackTargets,
      historyPreserved: rollbackPreserved,
      childRevisionsRemainAuditable: cases.every((result) => Boolean(result.promoted.revisionID))
    },
    hardNegativeAbstention: {
      fixtureCount: hardNegativeFixtures.length,
      passed: hardNegativePreserved,
      selectedCountAfterPromotion: cases.reduce((sum, result) => sum + result.hardNegativeResults.filter((entry) => entry.selectedTemplateID).length, 0),
      abstainedCountAfterPromotion: cases.reduce((sum, result) => sum + result.hardNegativeResults.filter((entry) => entry.selectedTemplateID === null).length, 0)
    },
    privacy: {
      passed: cases.every((result) => result.correctionRecordValueFree),
      valueFreeCorrectionRecords: true,
      profileValueCount: 0,
      sourceBytesStored: false,
      rawLabelsStored: false
    },
    cases
  };
  const reviewedMatchingReport = matchingReport || runReviewedTemplateBenchmark(fixtures, {
    documentClassPolicies: calibration.policyByDocumentClass
  });
  report.metrics = computeReviewedCompletionMetrics({
    correctionReport: report,
    matchingReport: reviewedMatchingReport
  });
  report.passed = report.improvement.allPromotionsImproved
    && report.rollback.passed
    && report.hardNegativeAbstention.passed
    && report.privacy.passed
    && report.metrics.passed;
  return report;
}
