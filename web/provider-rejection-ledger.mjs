/**
 * Provider-neutral rejection ledger.
 *
 * This module is deliberately free of Node or PDF-engine dependencies so the
 * browser adapter, native adapter fixtures, and companion bridge can project
 * their provider-local failures into the same semantic report.
 */

export const REJECTION_LEDGER_CONTRACT = "pdf-editor.rejection-ledger";
export const REJECTION_LEDGER_VERSION = Object.freeze({ major: 1, minor: 0 });

export const PROVIDER_KINDS = Object.freeze(["native", "browser", "companion"]);
export const REJECTION_STATES = Object.freeze(["rejected", "abstained", "failed", "cancelled", "completed"]);

export const SHARED_REJECTION_CODES = Object.freeze({
  staleSourceDigest: { category: "source", retryable: false, recovery: "reopenCurrentSource" },
  sourceByteCountMismatch: { category: "source", retryable: false, recovery: "reinspectSource" },
  inputMissing: { category: "input", retryable: true, recovery: "chooseAnotherSource" },
  inputTooLarge: { category: "resource", retryable: false, recovery: "reduceScopeOrUseApprovedProvider" },
  cannotOpen: { category: "input", retryable: false, recovery: "retainSourceAndInspect" },
  passwordRequired: { category: "input", retryable: true, recovery: "requestPassword" },
  passwordIncorrect: { category: "input", retryable: true, recovery: "retryPassword" },
  invalidPage: { category: "contract", retryable: false, recovery: "reviseOperation" },
  invalidOperation: { category: "contract", retryable: false, recovery: "reviseOperation" },
  unsupportedOperation: { category: "capability", retryable: false, recovery: "chooseSupportedOperation" },
  destructiveOperation: { category: "safety", retryable: false, recovery: "reviewDestructiveIntent" },
  unknownValidationState: { category: "validation", retryable: false, recovery: "inspectValidationEvidence" },
  coordinateMismatch: { category: "coordinate", retryable: false, recovery: "reinspectPageGeometry" },
  providerUnavailable: { category: "provider", retryable: true, recovery: "retryOrSelectProvider" },
  runtimeUnavailable: { category: "provider", retryable: true, recovery: "restoreRuntime" },
  providerFailure: { category: "provider", retryable: true, recovery: "retryAsNewCopy" },
  providerRevoked: { category: "provider", retryable: false, recovery: "selectAnotherProvider" },
  licenseUnapproved: { category: "provider", retryable: false, recovery: "reviewProviderLicense" },
  sourceOutsideProviderLimits: { category: "resource", retryable: false, recovery: "selectAnotherProvider" },
  outputLimit: { category: "resource", retryable: false, recovery: "reduceScopeOrIncreaseApprovedLimit" },
  timeout: { category: "runtime", retryable: true, recovery: "retryWithResourceBudget" },
  cancelled: { category: "runtime", retryable: true, recovery: "resumeOrRetry" },
  exportFailed: { category: "export", retryable: true, recovery: "retryAsNewCopy" },
  validationFailed: { category: "validation", retryable: false, recovery: "inspectValidationEvidence" },
  unknownRejection: { category: "unknown", retryable: false, recovery: "retainEvidenceAndReview" }
});

const CODE_ALIASES = Object.freeze({
  sourceDigestMismatch: "staleSourceDigest",
  staleSource: "staleSourceDigest",
  capabilityNotSupported: "unsupportedOperation",
  unsupported: "unsupportedOperation",
  unsupportedFeature: "unsupportedOperation",
  noHandler: "providerUnavailable",
  providerNotInstalled: "providerUnavailable",
  capabilityRevoked: "providerRevoked",
  capabilityStateRevoked: "providerRevoked",
  unapprovedLicense: "licenseUnapproved",
  providerTimeout: "timeout",
  exportFailedValidation: "validationFailed",
  unknownValidation: "unknownValidationState"
});

const CODE_PATTERN = /^[A-Za-z][A-Za-z0-9:_-]{0,96}$/;
const DIGEST_PATTERN = /^[0-9a-f]{64}$/i;
const isRecord = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

export class RejectionLedgerError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "RejectionLedgerError";
    this.code = code;
  }
}

function fail(message) {
  throw new RejectionLedgerError("invalidRejectionLedger", message);
}

function requireString(value, path, { allowEmpty = false } = {}) {
  if (typeof value !== "string" || (!allowEmpty && value.length === 0)) fail(`${path} must be a ${allowEmpty ? "string" : "non-empty string"}`);
}

function requireDigest(value, path, { allowNull = false } = {}) {
  if (allowNull && value === null) return;
  if (typeof value !== "string" || !DIGEST_PATTERN.test(value)) fail(`${path} must be a SHA-256 digest`);
}

function canonicalCode(rawCode, reasonCodes, state) {
  const candidates = [rawCode, ...(Array.isArray(reasonCodes) ? reasonCodes : [])]
    .filter((value) => typeof value === "string" && value.length > 0);
  for (const candidate of candidates) {
    const normalized = CODE_ALIASES[candidate] || candidate;
    if (Object.hasOwn(SHARED_REJECTION_CODES, normalized)) return normalized;
  }
  if (state === "cancelled") return "cancelled";
  if (state === "failed") return "providerFailure";
  if (state === "abstained" || state === "rejected") return "unknownRejection";
  return null;
}

function normalizedReasonCodeCount(reasonCodes) {
  if (reasonCodes === undefined) return { known: 0, unknown: 0 };
  if (!Array.isArray(reasonCodes) || reasonCodes.some((value) => typeof value !== "string" || !CODE_PATTERN.test(value))) {
    fail("attempt.reasonCodes must contain bounded code strings");
  }
  return reasonCodes.reduce((counts, value) => {
    const normalized = CODE_ALIASES[value] || value;
    if (Object.hasOwn(SHARED_REJECTION_CODES, normalized)) counts.known += 1;
    else counts.unknown += 1;
    return counts;
  }, { known: 0, unknown: 0 });
}

function normalizeLineage(lineage, expectedSourceDigest) {
  if (!Array.isArray(lineage) || lineage.length === 0) fail("attempt.operationLineage must be a non-empty array");
  const normalized = lineage.map((entry, index) => {
    if (!isRecord(entry)) fail(`attempt.operationLineage[${index}] must be an object`);
    requireString(entry.operationID, `attempt.operationLineage[${index}].operationID`);
    requireString(entry.kind, `attempt.operationLineage[${index}].kind`);
    if (!Number.isInteger(entry.pageIndex) || entry.pageIndex < 0) fail(`attempt.operationLineage[${index}].pageIndex must be a non-negative integer`);
    requireDigest(entry.sourceDigest, `attempt.operationLineage[${index}].sourceDigest`);
    if (entry.sourceDigest.toLowerCase() !== expectedSourceDigest.toLowerCase()) fail("operation lineage source digest does not match attempt source digest");
    return {
      operationID: entry.operationID,
      kind: entry.kind,
      pageIndex: entry.pageIndex,
      sourceDigest: entry.sourceDigest.toLowerCase()
    };
  });
  return normalized.sort((left, right) => `${left.pageIndex}:${left.kind}:${left.operationID}`.localeCompare(`${right.pageIndex}:${right.kind}:${right.operationID}`));
}

export function lineageSignature(lineage) {
  return lineage.map((entry) => `${entry.pageIndex}|${entry.kind}|${entry.operationID}|${entry.sourceDigest}`).join(";");
}

export function normalizeRejectionAttempt(attempt) {
  if (!isRecord(attempt)) fail("attempt must be an object");
  requireString(attempt.attemptID, "attempt.attemptID");
  requireString(attempt.caseID, "attempt.caseID");
  requireString(attempt.providerID, "attempt.providerID");
  if (!PROVIDER_KINDS.includes(attempt.providerKind)) fail("attempt.providerKind is unsupported");
  requireString(attempt.capability, "attempt.capability");
  requireString(attempt.phase, "attempt.phase");
  if (!REJECTION_STATES.includes(attempt.state)) fail("attempt.state is unsupported");
  requireDigest(attempt.sourceDigest, "attempt.sourceDigest");
  const lineage = normalizeLineage(attempt.operationLineage, attempt.sourceDigest);
  const reasonCounts = normalizedReasonCodeCount(attempt.reasonCodes);
  const code = canonicalCode(attempt.code || attempt.rejection?.code, attempt.reasonCodes, attempt.state);
  const isRejection = ["rejected", "abstained", "failed", "cancelled"].includes(attempt.state);
  if (isRejection && !code) fail("rejected attempt has no canonical rejection code");
  if (attempt.outputDigest !== undefined && attempt.outputDigest !== null) requireDigest(attempt.outputDigest, "attempt.outputDigest");
  return {
    attemptID: attempt.attemptID,
    caseID: attempt.caseID,
    providerID: attempt.providerID,
    providerKind: attempt.providerKind,
    capability: attempt.capability,
    phase: attempt.phase,
    state: attempt.state,
    outcome: isRejection ? "rejected" : "completed",
    sourceDigest: attempt.sourceDigest.toLowerCase(),
    operationLineage: lineage,
    operationLineageSignature: lineageSignature(lineage),
    rejection: code ? {
      code,
      category: SHARED_REJECTION_CODES[code].category,
      retryable: SHARED_REJECTION_CODES[code].retryable,
      recovery: SHARED_REJECTION_CODES[code].recovery,
      providerReasonCodeCount: reasonCounts.known,
      unknownProviderReasonCodeCount: reasonCounts.unknown
    } : null
  };
}

export function createRejectionLedger({ ledgerID, sourceDigest, attempts }) {
  requireString(ledgerID, "ledgerID");
  requireDigest(sourceDigest, "sourceDigest");
  if (!Array.isArray(attempts) || attempts.length === 0) fail("attempts must be a non-empty array");
  const normalizedAttempts = attempts.map(normalizeRejectionAttempt);
  for (const attempt of normalizedAttempts) {
    if (attempt.sourceDigest !== sourceDigest.toLowerCase()) fail("attempt source digest does not match ledger source digest");
  }
  const providerIDs = new Set(normalizedAttempts.map((attempt) => attempt.providerID));
  const providerKinds = new Set(normalizedAttempts.map((attempt) => attempt.providerKind));
  if (providerIDs.size !== 1 || providerKinds.size !== 1) fail("all attempts in a ledger must belong to one provider");
  return {
    contract: REJECTION_LEDGER_CONTRACT,
    version: REJECTION_LEDGER_VERSION,
    ledgerID,
    sourceDigest: sourceDigest.toLowerCase(),
    attempts: normalizedAttempts
  };
}

function compareAttempts(left, right) {
  const sameLineage = left.sourceDigest === right.sourceDigest && left.operationLineageSignature === right.operationLineageSignature;
  const sameOutcome = left.outcome === right.outcome;
  const sameCode = left.rejection?.code === right.rejection?.code;
  const sameRecovery = left.rejection?.recovery === right.rejection?.recovery;
  const comparable = sameLineage && left.rejection?.code !== "unknownRejection" && right.rejection?.code !== "unknownRejection";
  return {
    caseID: left.caseID,
    leftProviderID: left.providerID,
    rightProviderID: right.providerID,
    sameLineage,
    sameOutcome,
    sameCode,
    sameRecovery,
    comparable,
    equivalent: sameLineage && sameOutcome && sameCode && sameRecovery && comparable
  };
}

export function compareRejectionLedgers(ledgers) {
  if (!Array.isArray(ledgers) || ledgers.length < 2) fail("at least two rejection ledgers are required for comparison");
  const normalized = ledgers.map((ledger) => createRejectionLedger(ledger));
  const sourceDigests = new Set(normalized.map((ledger) => ledger.sourceDigest));
  const cases = new Map();
  for (const ledger of normalized) {
    for (const attempt of ledger.attempts) {
      const key = `${attempt.caseID}|${attempt.capability}`;
      if (!cases.has(key)) cases.set(key, []);
      cases.get(key).push(attempt);
    }
  }
  const comparisons = [];
  for (const attempts of cases.values()) {
    for (let leftIndex = 0; leftIndex < attempts.length; leftIndex += 1) {
      for (let rightIndex = leftIndex + 1; rightIndex < attempts.length; rightIndex += 1) {
        if (attempts[leftIndex].providerID === attempts[rightIndex].providerID) continue;
        comparisons.push(compareAttempts(attempts[leftIndex], attempts[rightIndex]));
      }
    }
  }
  const providerSummaries = Object.fromEntries(normalized.map((ledger) => [
    ledger.attempts[0].providerID,
    {
      providerKind: ledger.attempts[0].providerKind,
      attemptCount: ledger.attempts.length,
      rejectedCount: ledger.attempts.filter((attempt) => attempt.outcome === "rejected").length,
      codes: [...new Set(ledger.attempts.map((attempt) => attempt.rejection?.code).filter(Boolean))].sort()
    }
  ]));
  const comparableComparisons = comparisons.filter((comparison) => comparison.comparable);
  return {
    contract: "pdf-editor.rejection-comparison-report",
    version: REJECTION_LEDGER_VERSION,
    sourceDigests: [...sourceDigests].sort(),
    providerSummaries,
    comparisons,
    summary: {
      providerCount: normalized.length,
      caseCount: cases.size,
      comparisonCount: comparisons.length,
      comparableCount: comparableComparisons.length,
      equivalentCount: comparableComparisons.filter((comparison) => comparison.equivalent).length,
      disagreementCount: comparableComparisons.filter((comparison) => !comparison.equivalent).length,
      unknownCount: comparisons.filter((comparison) => !comparison.comparable).length
    }
  };
}
