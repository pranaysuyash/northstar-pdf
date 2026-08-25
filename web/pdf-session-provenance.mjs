/**
 * Privacy and provenance for one PDF editing session.
 *
 * This is intentionally separate from pdf-preflight.mjs. Preflight describes
 * the source document; this contract describes data flow and artifacts created
 * while working on that source. It contains no PDF bytes, text, values,
 * filenames, URLs, OCR text, or screenshots.
 */

export const PDF_SESSION_PROVENANCE_CONTRACT_NAME = "pdf-editor.session-provenance";
export const PDF_SESSION_PROVENANCE_CONTRACT_VERSION = Object.freeze({ major: 1, minor: 0 });

const DIGEST = /^[0-9a-f]{64}$/i;
const FORBIDDEN_KEYS = Object.freeze([
  "sourceBytes", "sourceData", "documentText", "ocrText", "fieldValues",
  "fileName", "filename", "rawURL", "rawUrl", "url", "screenshot", "imagePixels"
]);
const PROCESSING_LOCALITIES = new Set(["local-device", "local-browser", "local-companion", "remote-service", "mixed", "unknown"]);
const EGRESS_STATES = new Set(["none", "runtime-only", "source-bytes", "derived-content", "mixed", "unknown"]);
const OCR_STATES = new Set(["not-used", "local-device", "local-browser", "local-companion", "remote-service", "mixed", "unknown"]);
const RETENTION_STATES = new Set(["in-memory-session", "local-draft", "persistent-local", "external", "not-retained", "unknown"]);
const DELETION_STATES = new Set(["pending", "deleted", "unavailable", "not-applicable", "unknown"]);
const EXPORT_STATES = new Set(["not-attempted", "succeeded", "failed", "unknown"]);
const STORAGE_STATES = new Set(["ephemeral", "local-download", "local-file", "external", "unknown", "not-applicable"]);
const VALIDATION_STATES = new Set(["not-run", "validated", "validated-with-warnings", "failed", "unknown"]);

function assertRecord(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
}

function assertDigest(value, label) {
  if (typeof value !== "string" || !DIGEST.test(value)) throw new Error(`${label} must be a SHA-256 digest`);
}

function nonNegativeInteger(value, label) {
  if (!Number.isInteger(value) || value < 0) throw new Error(`${label} must be a non-negative integer`);
  return value;
}

function sortedStrings(values, label) {
  if (!Array.isArray(values) || values.some((value) => typeof value !== "string" || !value)) {
    throw new Error(`${label} must be an array of non-empty strings`);
  }
  return [...new Set(values)].sort();
}

export function createSessionPrivacyProvenance({
  sessionID,
  sourceDigest,
  provider,
  generatedAt = new Date().toISOString(),
  processing,
  ocr = {
    state: "not-used",
    providerIDs: [],
    processedPageCount: 0,
    recognizedTextRetained: false,
    recognizedBoundsRetained: false
  },
  sourceRetention,
  exportProvenance
} = {}) {
  if (typeof sessionID !== "string" || !sessionID) throw new Error("sessionID must be a non-empty opaque string");
  assertDigest(sourceDigest, "sourceDigest");
  assertRecord(provider, "provider");
  assertRecord(processing, "processing");
  assertRecord(ocr, "ocr");
  assertRecord(sourceRetention, "sourceRetention");
  assertRecord(exportProvenance, "exportProvenance");
  return {
    header: {
      contractName: PDF_SESSION_PROVENANCE_CONTRACT_NAME,
      version: { ...PDF_SESSION_PROVENANCE_CONTRACT_VERSION },
      sessionID,
      sourceDigest,
      generatedAt,
      provider: { ...provider }
    },
    payload: {
      privacy: {
        sourceBytesIncluded: false,
        documentTextIncluded: false,
        ocrTextIncluded: false,
        fieldValuesIncluded: false,
        filenamesIncluded: false,
        URLsIncluded: false
      },
      processing: {
        locality: processing.locality,
        sourceInput: processing.sourceInput,
        dataEgress: processing.dataEgress,
        networkRequestCount: nonNegativeInteger(processing.networkRequestCount ?? 0, "networkRequestCount"),
        companionRequestCount: nonNegativeInteger(processing.companionRequestCount ?? 0, "companionRequestCount")
      },
      ocr: {
        state: ocr.state,
        providerIDs: sortedStrings(ocr.providerIDs || [], "ocr.providerIDs"),
        processedPageCount: nonNegativeInteger(ocr.processedPageCount ?? 0, "processedPageCount"),
        recognizedTextRetained: Boolean(ocr.recognizedTextRetained),
        recognizedBoundsRetained: Boolean(ocr.recognizedBoundsRetained)
      },
      sourceRetention: {
        state: sourceRetention.state,
        retainedUntilSessionEnd: Boolean(sourceRetention.retainedUntilSessionEnd),
        deletion: sourceRetention.deletion,
        sourceCopyCount: nonNegativeInteger(sourceRetention.sourceCopyCount ?? 0, "sourceCopyCount")
      },
      export: {
        state: exportProvenance.state,
        sourceDigest: exportProvenance.sourceDigest || sourceDigest,
        outputDigest: exportProvenance.outputDigest ?? null,
        storage: exportProvenance.storage,
        validation: exportProvenance.validation,
        outputReopenable: exportProvenance.outputReopenable ?? null,
        operationCount: nonNegativeInteger(exportProvenance.operationCount ?? 0, "operationCount"),
        exporterID: exportProvenance.exporterID ?? null,
        validationProviderID: exportProvenance.validationProviderID ?? null
      }
    }
  };
}

export function validateSessionPrivacyProvenance(record, { expectedSourceDigest } = {}) {
  assertRecord(record, "session provenance");
  const header = record.header;
  const payload = record.payload;
  assertRecord(header, "session provenance header");
  assertRecord(payload, "session provenance payload");
  if (header.contractName !== PDF_SESSION_PROVENANCE_CONTRACT_NAME) throw new Error("invalid session provenance contract");
  if (header.version?.major !== 1 || header.version?.minor !== 0) throw new Error("unsupported session provenance version");
  if (typeof header.sessionID !== "string" || !header.sessionID) throw new Error("invalid session provenance session ID");
  assertDigest(header.sourceDigest, "header.sourceDigest");
  assertDigest(payload.export?.sourceDigest, "export.sourceDigest");
  if (header.sourceDigest.toLowerCase() !== payload.export.sourceDigest.toLowerCase()) throw new Error("session provenance source mismatch");
  if (expectedSourceDigest && header.sourceDigest.toLowerCase() !== expectedSourceDigest.toLowerCase()) throw new Error("stale session provenance source digest");

  const privacy = payload.privacy;
  assertRecord(privacy, "privacy flags");
  for (const key of ["sourceBytesIncluded", "documentTextIncluded", "ocrTextIncluded", "fieldValuesIncluded", "filenamesIncluded", "URLsIncluded"]) {
    if (privacy[key] !== false) throw new Error(`privacy leak flag ${key} must remain false`);
  }

  const processing = payload.processing;
  assertRecord(processing, "processing provenance");
  if (!PROCESSING_LOCALITIES.has(processing.locality) || !EGRESS_STATES.has(processing.dataEgress)) throw new Error("invalid processing locality or egress state");
  nonNegativeInteger(processing.networkRequestCount, "processing.networkRequestCount");
  nonNegativeInteger(processing.companionRequestCount, "processing.companionRequestCount");

  const ocr = payload.ocr;
  assertRecord(ocr, "ocr provenance");
  if (ocr.state === "not-used") {
    if (ocr.providerIDs.length !== 0 || ocr.processedPageCount !== 0 || ocr.recognizedTextRetained || ocr.recognizedBoundsRetained) {
      throw new Error("not-used OCR provenance contains usage evidence");
    }
  } else if (ocr.state === "unknown") {
    if (ocr.providerIDs.length !== 0 || ocr.processedPageCount !== 0 || ocr.recognizedTextRetained || ocr.recognizedBoundsRetained) {
      throw new Error("unknown OCR provenance contains usage evidence");
    }
  } else if (!OCR_STATES.has(ocr.state) || !Array.isArray(ocr.providerIDs) || ocr.providerIDs.length === 0 || ocr.processedPageCount <= 0) {
    throw new Error("OCR provenance is contradictory or unknown");
  }

  const retention = payload.sourceRetention;
  assertRecord(retention, "source retention provenance");
  if (!RETENTION_STATES.has(retention.state) || !DELETION_STATES.has(retention.deletion)) throw new Error("invalid source retention state");
  if (retention.state === "unknown" || retention.state === "not-retained") {
    if (retention.retainedUntilSessionEnd || retention.sourceCopyCount !== 0) throw new Error("not-retained source contains retention evidence");
  } else if (retention.sourceCopyCount <= 0) {
    throw new Error("retained source must report at least one bounded copy");
  }

  const output = payload.export;
  assertRecord(output, "export provenance");
  if (!EXPORT_STATES.has(output.state) || !STORAGE_STATES.has(output.storage) || !VALIDATION_STATES.has(output.validation)) throw new Error("invalid export provenance state");
  if (output.state === "not-attempted") {
    if (output.outputDigest !== null || output.validation !== "not-run" || output.storage !== "not-applicable" || output.outputReopenable !== null) {
      throw new Error("not-attempted export contains artifact evidence");
    }
  } else if (output.state === "succeeded") {
    assertDigest(output.outputDigest, "export.outputDigest");
    if (!["validated", "validated-with-warnings"].includes(output.validation) || output.storage === "not-applicable" || output.outputReopenable !== true) {
      throw new Error("successful export is missing validation provenance");
    }
  } else if (output.state === "failed" && !["failed", "unknown"].includes(output.validation)) {
    throw new Error("failed export has an invalid validation state");
  }

  const serialized = JSON.stringify(record);
  for (const key of FORBIDDEN_KEYS) {
    if (Object.prototype.hasOwnProperty.call(record, key) || serialized.includes(`"${key}"`)) {
      throw new Error(`session provenance contains forbidden content field ${key}`);
    }
  }
  return true;
}

export const sessionProvenanceForbiddenKeys = FORBIDDEN_KEYS;
