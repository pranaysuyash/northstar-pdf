export const CONTRACT_VERSION = Object.freeze({ major: 1, minor: 0 });

export const COMPANION_STATES = Object.freeze([
  "accepted",
  "rejected",
  "started",
  "progress",
  "completed",
  "abstained",
  "failed",
  "cancelled"
]);

const REQUEST_TYPES = new Set([
  "ocr.textBounds",
  "edit.existingText",
  "validate.independentViewer",
  "validate.rasterDiff"
]);

const isRecord = (value) => value !== null && typeof value === "object" && !Array.isArray(value);
const isNonEmpty = (value) => typeof value === "string" && value.length > 0;
const isDigest = (value) => typeof value === "string" && /^[0-9a-f]{64}$/i.test(value);
const isVersion = (value) => isRecord(value) && value.major === CONTRACT_VERSION.major && Number.isInteger(value.minor) && value.minor >= 0;
const assertValid = (condition, message) => {
  if (!condition) throw new Error(message);
};

export function validateCompanionHello(message) {
  assertValid(isRecord(message) && message.type === "pdf-editor.companion.hello", "invalid companion hello type");
  assertValid(isVersion(message.version), "unsupported companion protocol version");
  assertValid(isNonEmpty(message.sessionID) && isNonEmpty(message.clientNonce), "hello identity is empty");
  assertValid(isNonEmpty(message.origin), "hello origin is empty");
  assertValid(Array.isArray(message.requestedCapabilities) && message.requestedCapabilities.every((value) => REQUEST_TYPES.has(value)), "hello capability request is invalid");
  assertValid(typeof message.localOnly === "boolean" && message.localOnly, "companion protocol must be local-only");
  return true;
}

export function validateCompanionHelloResponse(message, hello) {
  assertValid(isRecord(message) && message.type === "pdf-editor.companion.hello-response", "invalid companion hello response type");
  assertValid(isVersion(message.version), "unsupported companion protocol version");
  assertValid(isNonEmpty(message.sessionID) && isNonEmpty(message.serverNonce), "hello response identity is empty");
  assertValid(isNonEmpty(message.companionID), "companion ID is empty");
  assertValid(typeof message.accepted === "boolean", "hello response acceptance is missing");
  assertValid(Array.isArray(message.providerIDs) && message.providerIDs.every(isNonEmpty), "hello response provider IDs are invalid");
  if (hello) {
    validateCompanionHello(hello);
    assertValid(message.sessionID === hello.sessionID, "hello response session mismatch");
  }
  return true;
}

export function validateCompanionCapabilityRequest(message, context = {}) {
  assertValid(isRecord(message) && message.type === "pdf-editor.companion.capability-request", "invalid companion capability request type");
  assertValid(isVersion(message.version), "unsupported companion protocol version");
  assertValid(isNonEmpty(message.sessionID) && isNonEmpty(message.requestID), "capability request identity is empty");
  assertValid(isNonEmpty(message.clientNonce) && isNonEmpty(message.serverNonce), "capability request nonce is empty");
  assertValid(REQUEST_TYPES.has(message.capability), "unsupported companion capability");
  assertValid(isDigest(message.sourceDigest), "source digest must be a 64-character hex digest");
  assertValid(Number.isInteger(message.sourceByteCount) && message.sourceByteCount >= 0, "source byte count is invalid");
  assertValid(Number.isInteger(message.sourcePageCount) && message.sourcePageCount >= 0, "source page count is invalid");
  assertValid(Number.isInteger(message.maxOutputBytes) && message.maxOutputBytes > 0, "max output bytes must be positive");
  assertValid(Number.isInteger(message.timeoutMs) && message.timeoutMs > 0, "timeout must be positive");
  assertValid(message.inputMode === "source-bytes" || message.inputMode === "file-token", "input mode is invalid");
  assertValid(Array.isArray(message.operationIDs) && message.operationIDs.every(isNonEmpty), "operation IDs are invalid");
  assertValid(typeof message.localOnly === "boolean" && message.localOnly, "companion request must be local-only");
  if (message.inputMode === "source-bytes") {
    assertValid(isNonEmpty(message.sourceBytesBase64), "source bytes are required for source-bytes mode");
    assertValid(message.sourceFileToken === undefined || message.sourceFileToken === null, "file token is forbidden for source-bytes mode");
  } else {
    assertValid(message.sourceBytesBase64 === undefined || message.sourceBytesBase64 === null, "source bytes are forbidden for file-token mode");
    assertValid(isNonEmpty(message.sourceFileToken), "source file token is required for file-token mode");
  }
  if (context.hello) {
    validateCompanionHello(context.hello);
    assertValid(message.sessionID === context.hello.sessionID, "capability request session mismatch");
    assertValid(message.clientNonce === context.hello.clientNonce, "capability request client nonce mismatch");
  }
  if (context.helloResponse) {
    validateCompanionHelloResponse(context.helloResponse, context.hello);
    assertValid(message.serverNonce === context.helloResponse.serverNonce, "capability request server nonce mismatch");
  }
  return true;
}

export function validateCompanionCapabilityResponse(message, request) {
  assertValid(isRecord(message) && message.type === "pdf-editor.companion.capability-response", "invalid companion capability response type");
  assertValid(isVersion(message.version), "unsupported companion protocol version");
  assertValid(isNonEmpty(message.sessionID) && isNonEmpty(message.requestID), "capability response identity is empty");
  assertValid(COMPANION_STATES.includes(message.state), "unknown companion response state");
  assertValid(isNonEmpty(message.providerID), "capability response provider ID is empty");
  assertValid(message.outputDigest === null || isDigest(message.outputDigest), "output digest is invalid");
  assertValid(Array.isArray(message.reasonCodes) && message.reasonCodes.every(isNonEmpty), "reason codes are invalid");
  if (request) {
    validateCompanionCapabilityRequest(request);
    assertValid(message.sessionID === request.sessionID && message.requestID === request.requestID, "capability response request mismatch");
  }
  return true;
}

export function validateCompanionCancellation(message, context = {}) {
  assertValid(isRecord(message) && message.type === "pdf-editor.companion.cancel", "invalid companion cancellation type");
  assertValid(isVersion(message.version), "unsupported companion protocol version");
  assertValid(isNonEmpty(message.sessionID) && isNonEmpty(message.requestID), "cancellation identity is empty");
  assertValid(isNonEmpty(message.clientNonce) && isNonEmpty(message.serverNonce), "cancellation nonce is empty");
  if (context.request) {
    validateCompanionCapabilityRequest(context.request);
    assertValid(message.sessionID === context.request.sessionID && message.requestID === context.request.requestID, "cancellation request mismatch");
    assertValid(message.clientNonce === context.request.clientNonce && message.serverNonce === context.request.serverNonce, "cancellation nonce mismatch");
  }
  return true;
}
