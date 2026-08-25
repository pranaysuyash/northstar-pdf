import { negotiateCapability } from "./provider-capability-contract.mjs";

export const PDF_CAPABILITY_LANES = Object.freeze([
  "native.choice",
  "native.checkbox",
  "signature.visual",
  "signature.cryptographic",
  "ocr.textBounds",
  "ocr.searchLayer",
  "text.runReplacement",
  "text.reflow",
  "redaction.permanent",
  "xfa.forms",
  "pdfua.conformance",
  "independentViewer.reopen"
]);

export const PDF_CAPABILITY_OUTCOMES = Object.freeze([
  "available",
  "partial",
  "unsupported",
  "unknown",
  "revoked",
  "needsReview"
]);

function requireLane(lane) {
  if (!PDF_CAPABILITY_LANES.includes(lane)) throw new TypeError(`Unsupported PDF capability lane: ${lane}`);
}

export function createPDFCapabilityRequest({ lane, source, sourceDigest, operationKinds = [], policy }) {
  requireLane(lane);
  if (!sourceDigest || typeof sourceDigest !== "string") throw new TypeError("Capability requests require a source digest.");
  if (!source || !Number.isInteger(source.byteCount) || !Number.isInteger(source.pageCount)) throw new TypeError("Capability requests require source facts.");
  return {
    contract: "pdf-editor.provider-capability-request",
    version: { major: 1, minor: 0 },
    capability: lane,
    operationKinds: [...operationKinds],
    source: { ...source },
    sourceDigest,
    policy: policy || { localOnly: true, minimumState: "enabled", allowExperimental: false, preferredProviderIDs: [] }
  };
}

export function resolvePDFCapability({ registry, request }) {
  requireLane(request?.capability);
  const decision = negotiateCapability(registry, request);
  const outcome = decision.decision === "selected"
    ? (decision.reasonCodes.includes("partialEvidence") ? "partial" : "available")
    : decision.reasonCodes.includes("providerRevoked") ? "revoked" : "unknown";
  return {
    contract: "pdf-editor.pdf-capability-outcome",
    version: { major: 1, minor: 0 },
    lane: request.capability,
    sourceDigest: request.sourceDigest,
    outcome,
    providerID: decision.providerID,
    measurementID: decision.measurementID,
    fallbackProviderIDs: decision.fallbackProviderIDs,
    reasonCodes: decision.reasonCodes,
    requiresReview: outcome !== "available",
    decision
  };
}

export function createCapabilityExecutionResult({ request, admission, outputDigest = null, validationState = "unknown", evidence = [] }) {
  requireLane(request?.capability);
  if (!admission || admission.sourceDigest !== request.sourceDigest) throw new TypeError("Capability result source digest does not match request.");
  if (!["passed", "failed", "unknown", "skipped"].includes(validationState)) throw new TypeError("Capability validation state is invalid.");
  const outcome = admission.outcome === "available" && validationState === "passed" ? "available"
    : admission.outcome === "revoked" ? "revoked"
      : validationState === "failed" ? "partial" : "needsReview";
  return {
    contract: "pdf-editor.pdf-capability-result",
    version: { major: 1, minor: 0 },
    lane: request.capability,
    sourceDigest: request.sourceDigest,
    providerID: admission.providerID,
    measurementID: admission.measurementID,
    outcome,
    validationState,
    outputDigest,
    evidence: [...evidence],
    reasonCodes: outcome === "available" ? ["validatedForSource"] : ["resultRequiresReview"]
  };
}

export function validateCapabilityResult(result) {
  requireLane(result?.lane);
  if (!result.sourceDigest || !PDF_CAPABILITY_OUTCOMES.includes(result.outcome)) throw new TypeError("Capability result identity or outcome is invalid.");
  if (!Array.isArray(result.evidence)) throw new TypeError("Capability result evidence must be an array.");
  return result;
}
