/**
 * Privacy-first PDF preflight.
 *
 * Preflight describes observed risk surfaces. It does not remove anything,
 * execute document actions, fetch destinations, or certify a file as clean.
 * Raw metadata values, attachment names, URLs, source bytes, and active-content
 * payloads are intentionally excluded from the report.
 */

export const PDF_PREFLIGHT_CONTRACT_NAME = "pdf-editor.preflight";
export const PDF_PREFLIGHT_CONTRACT_VERSION = Object.freeze({ major: 1, minor: 1 });

// These are the structural surfaces that must be compared before an export is
// published. They are intentionally separate from PDF writer operation kinds:
// a text overlay may be an allowed operation while a metadata or action
// transition caused by the same writer is still an export failure.
export const PREFLIGHT_PROTECTED_SURFACES = Object.freeze([
  "metadata",
  "attachments",
  "embeddedActions",
  "encryption",
  "annotations",
  "formValues",
  "revisions",
  "privacySensitiveContent"
]);

export const PREFLIGHT_TRANSITION_STATES = Object.freeze([
  "unchanged",
  "changed",
  "added",
  "removed",
  "unknown",
  "unsupported"
]);

const FORBIDDEN_REPORT_KEYS = new Set([
  "pageText", "ocrText", "sourceBytes", "sourceData", "password", "profileValue",
  "imagePixels", "rawURL", "rawUrl", "attachmentName", "sourceBytesBase64"
]);

const TOKEN_PATTERNS = Object.freeze({
  embeddedFiles: /\/EmbeddedFiles\b/g,
  fileAttachment: /\/FileAttachment\b/g,
  xfa: /\/XFA\b/g,
  richMedia: /\/RichMedia\b/g,
  javascriptAction: /\/(?:JavaScript|JS)\b/g,
  openAction: /\/OpenAction\b/g,
  additionalAction: /\/AA\b/g,
  launchAction: /\/Launch\b/g,
  submitFormAction: /\/SubmitForm\b/g,
  remoteGoToAction: /\/GoToR\b/g,
  uriAction: /\/URI\b/g,
  encryption: /\/Encrypt\b/g,
  signature: /\/(?:Sig|DocTimeStamp)\b/g,
  metadataStream: /\/Metadata\b/g,
  eofMarker: /%%EOF\b/g,
  startxref: /\bstartxref\b/g,
  previousRevision: /\/Prev\b/g
});

const textDecoder = typeof TextDecoder === "function" ? new TextDecoder("latin1") : null;

function assertRecord(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
}

function assertDigest(value, label = "sourceDigest") {
  if (typeof value !== "string" || !/^[0-9a-f]{64}$/i.test(value)) throw new Error(`${label} must be a SHA-256 digest`);
}

function countMatches(text, pattern) {
  pattern.lastIndex = 0;
  return [...text.matchAll(pattern)].length;
}

function normalizedSourceBytes(sourceBytes) {
  if (sourceBytes instanceof Uint8Array) return sourceBytes;
  if (sourceBytes instanceof ArrayBuffer) return new Uint8Array(sourceBytes);
  return null;
}

export function scanPDFStructure(sourceBytes, { maxScanBytes = 50_000_000 } = {}) {
  const bytes = normalizedSourceBytes(sourceBytes);
  if (!bytes) {
    return { state: "unknown", method: "boundedTokenScan", scannedByteCount: 0, truncated: false, counts: {} };
  }
  const scan = bytes.byteLength > maxScanBytes ? bytes.subarray(0, maxScanBytes) : bytes;
  const text = textDecoder ? textDecoder.decode(scan) : String.fromCharCode(...scan.subarray(0, Math.min(scan.length, 1_000_000)));
  const counts = Object.fromEntries(Object.entries(TOKEN_PATTERNS).map(([key, pattern]) => [key, countMatches(text, pattern)]));
  return {
    state: "observed",
    method: "boundedTokenScan",
    scannedByteCount: scan.byteLength,
    truncated: scan.byteLength !== bytes.byteLength,
    counts
  };
}

function metadataPresence(metadata = {}) {
  const fields = ["title", "author", "subject", "creator", "producer", "creationDate", "modificationDate", "keywords"];
  return fields.reduce((result, field) => {
    const value = metadata[field] ?? metadata[field[0]?.toUpperCase() + field.slice(1)];
    result[field] = { present: typeof value === "string" ? value.trim().length > 0 : Boolean(value) };
    return result;
  }, {});
}

function finding({ id, category, code, severity, state, count = 0, reasonCodes = [], evidence = "inspection" }) {
  return { id, category, code, severity, state, count, reasonCodes: [...reasonCodes].sort(), evidence };
}

function externalLinkSummary(links = []) {
  const external = links.filter((link) => link.kind === "externalURL");
  const unsafe = external.filter((link) => link.isSafeExternal === false);
  return {
    externalURLCount: external.length,
    safeExternalURLCount: external.length - unsafe.length,
    unsafeExternalURLCount: unsafe.length,
    internalPageLinkCount: links.filter((link) => link.kind === "internalPage").length,
    unknownDestinationCount: links.filter((link) => link.kind === "unknown" || !link.kind).length
  };
}

function annotationSummary(payload = {}) {
  const raw = payload.annotationTypeCounts && typeof payload.annotationTypeCounts === "object"
    ? payload.annotationTypeCounts
    : {};
  const surfaceWasProvided = Object.prototype.hasOwnProperty.call(payload, "annotationTypeCounts");
  const byKind = Object.fromEntries(Object.entries(raw).map(([kind, count]) => [kind, Number.isFinite(count) ? count : 0]));
  const totalCount = Object.values(byKind).reduce((total, count) => total + count, 0);
  return {
    totalCount,
    byKind,
    unknownCount: byKind.unknown || 0,
    coverage: surfaceWasProvided
      ? { state: "observed", reasonCodes: ["pdfjsAnnotationEnumeration"] }
      : { state: "unknown", reasonCodes: ["annotationSurfaceNotProvided"] }
  };
}

function formValuePresence(payload = {}) {
  const fields = Array.isArray(payload.fields) ? payload.fields : null;
  if (!fields) {
    return {
      state: "unknown",
      fieldCount: 0,
      populatedFieldCount: 0,
      byKind: {},
      reasonCodes: ["fieldInspectionNotProvided"]
    };
  }
  const byKind = {};
  let populatedFieldCount = 0;
  for (const field of fields) {
    const kind = String(field?.kind || "unknown");
    byKind[kind] = byKind[kind] || { fieldCount: 0, populatedFieldCount: 0 };
    byKind[kind].fieldCount += 1;
    const value = field?.value;
    if (value !== null && value !== undefined && String(value).trim().length > 0) {
      populatedFieldCount += 1;
      byKind[kind].populatedFieldCount += 1;
    }
  }
  return {
    state: "observed",
    fieldCount: fields.length,
    populatedFieldCount,
    byKind,
    reasonCodes: ["fieldValuePresenceOnly"]
  };
}

function coverageSummary(scan, annotationCoverage) {
  const coverage = {
    metadata: {
      state: scan.counts.metadataStream > 0 ? "partial" : "observed",
      reasonCodes: scan.counts.metadataStream > 0 ? ["xmpMetadataPresenceDetectedButNotParsed"] : []
    },
    attachments: {
      state: scan.truncated ? "partial" : "observed",
      reasonCodes: scan.truncated ? ["boundedScanTruncated"] : ["embeddedPayloadBytesNotRetained"]
    },
    annotations: annotationCoverage,
    scripts: {
      state: "partial",
      reasonCodes: ["tokenScanDoesNotProveReachability", ...(scan.truncated ? ["boundedScanTruncated"] : [])].sort()
    },
    revisions: {
      state: "unknown",
      reasonCodes: ["incrementalRevisionParserNotRun"]
    }
  };
  return coverage;
}

function tokenFinding(scan, token, category, code, severity, reasonCodes = []) {
  const count = scan.state === "observed" ? (scan.counts[token] || 0) : 0;
  return finding({
    id: `${category}-${code}`,
    category,
    code,
    severity: count ? severity : scan.state === "unknown" ? "unknown" : "info",
    state: scan.state === "observed" ? (count ? "possible" : "not-observed") : "unknown",
    count,
    reasonCodes: count ? reasonCodes : scan.state === "unknown" ? ["byteScanUnavailable"] : [],
    evidence: scan.method
  });
}

export function buildPreflightReport({
  document,
  sourceBytes = null,
  provider = document?.header?.provider || { id: "unknown", version: "unknown", platform: "unknown", capabilities: [] },
  generatedAt = new Date().toISOString()
} = {}) {
  assertRecord(document, "document contract");
  const payload = document.payload || document;
  const sourceDigest = document.header?.sourceDigest || payload.source?.sha256;
  assertDigest(sourceDigest);
  const scan = scanPDFStructure(sourceBytes);
  const metadata = metadataPresence(payload.metadata || {});
  const metadataCount = Object.values(metadata).filter((entry) => entry.present).length;
  const links = externalLinkSummary(payload.links || []);
  const attachmentsCount = Array.isArray(payload.attachments) ? payload.attachments.length : 0;
  const annotations = annotationSummary(payload);
  const formValues = formValuePresence(payload);
  const encrypted = Boolean(payload.security?.isEncrypted || scan.counts.encryption > 0);
  const coverage = coverageSummary(scan, annotations.coverage);
  const unknownCoverage = {
    categories: coverage,
    unknownCount: Object.values(coverage).filter((entry) => entry.state === "unknown").length
  };
  const fileAttachmentCount = (annotations.byKind.fileAttachment || 0) + (scan.counts.fileAttachment || 0);
  const findings = [
    finding({ id: "metadata-presence", category: "metadata", code: "metadata.present", severity: metadataCount ? "warning" : "info", state: metadataCount ? "observed" : "not-observed", count: metadataCount, reasonCodes: metadataCount ? ["metadataValuesMayContainPersonalInformation"] : [] }),
    finding({ id: "embedded-attachments", category: "embeddedData", code: "embedded.attachments", severity: attachmentsCount ? "warning" : "info", state: attachmentsCount ? "observed" : "not-observed", count: attachmentsCount, reasonCodes: attachmentsCount ? ["embeddedContentRequiresSeparateReview"] : [] }),
    tokenFinding(scan, "embeddedFiles", "embeddedData", "embedded-file-spec-token", "warning", ["possibleEmbeddedFileNameTree"]),
    tokenFinding(scan, "fileAttachment", "embeddedData", "file-attachment-token", "warning", ["possibleEmbeddedAttachmentAnnotation"]),
    tokenFinding(scan, "xfa", "embeddedData", "xfa-token", "blocked", ["xfaSemanticsNotPreservedBySharedContract"]),
    tokenFinding(scan, "richMedia", "embeddedData", "rich-media-token", "blocked", ["richMediaRequiresIsolatedProvider"]),
    finding({ id: "network-external", category: "networkBoundary", code: "network.external-links", severity: links.externalURLCount ? "warning" : "info", state: links.externalURLCount ? "observed" : "not-observed", count: links.externalURLCount, reasonCodes: links.externalURLCount ? ["destinationNotFetchedByPreflight"] : [] }),
    finding({ id: "network-unsafe", category: "networkBoundary", code: "network.unsafe-links", severity: links.unsafeExternalURLCount ? "blocked" : "info", state: links.unsafeExternalURLCount ? "observed" : "not-observed", count: links.unsafeExternalURLCount, reasonCodes: links.unsafeExternalURLCount ? ["unsafeSchemeOrDestination"] : [] }),
    tokenFinding(scan, "uriAction", "networkBoundary", "network-uri-action-token", "warning", ["possibleNetworkAction"]),
    tokenFinding(scan, "remoteGoToAction", "networkBoundary", "network-remote-goto-token", "warning", ["possibleRemoteDocumentReference"]),
    tokenFinding(scan, "submitFormAction", "networkBoundary", "network-submit-form-token", "blocked", ["formSubmissionMustNeverBeExecutedByPreflight"]),
    tokenFinding(scan, "launchAction", "activeContent", "active-launch-token", "blocked", ["launchActionNeverExecuted"]),
    tokenFinding(scan, "javascriptAction", "activeContent", "active-javascript-token", "blocked", ["embeddedJavaScriptNeverExecuted"]),
    tokenFinding(scan, "openAction", "activeContent", "active-open-action-token", "warning", ["documentOpenActionNotExecuted"]),
    tokenFinding(scan, "additionalAction", "activeContent", "active-additional-action-token", "warning", ["additionalActionsNotExecuted"]),
    tokenFinding(scan, "signature", "security", "signature-token", "warning", ["signatureValidityRequiresCryptographicValidator"]),
    finding({ id: "security-encryption", category: "security", code: "security.encryption", severity: encrypted ? "warning" : "info", state: encrypted ? "observed" : "not-observed", count: encrypted ? 1 : 0, reasonCodes: encrypted ? ["passwordAndPermissionsBoundary"] : [] }),
    finding({ id: "byte-scan-state", category: "preflight", code: "preflight.byte-scan", severity: scan.state === "unknown" ? "unknown" : scan.truncated ? "warning" : "info", state: scan.state, count: scan.scannedByteCount, reasonCodes: scan.truncated ? ["boundedScanTruncated"] : [], evidence: scan.method })
  ];
  const sanitization = {
    status: "not-run",
    safeToClaimClean: false,
    sourceUnchanged: true,
    supportedModes: ["report-only", "new-copy-required"],
    limits: [
      "Preflight does not remove metadata or embedded data.",
      "Preflight does not execute or neutralize document JavaScript or actions.",
      "Preflight does not prove that hidden incremental revisions are absent.",
      "Preflight does not prove that signatures remain valid after mutation.",
      "Preflight does not certify XFA, rich media, annotations, or embedded files as preserved or removed.",
      "A bounded token scan may report possible structures without proving reachability."
    ]
  };
  const summary = {
    findingCount: findings.length,
    warningCount: findings.filter((item) => item.severity === "warning").length,
    blockedCount: findings.filter((item) => item.severity === "blocked").length,
    unknownCount: findings.filter((item) => item.state === "unknown").length,
    metadataFieldCount: metadataCount,
    embeddedDataCount: attachmentsCount + (scan.counts.embeddedFiles || 0) + (scan.counts.fileAttachment || 0),
    networkBoundaryCount: links.externalURLCount + (scan.counts.uriAction || 0) + (scan.counts.remoteGoToAction || 0) + (scan.counts.submitFormAction || 0),
    activeContentCount: (scan.counts.javascriptAction || 0) + (scan.counts.openAction || 0) + (scan.counts.additionalAction || 0) + (scan.counts.launchAction || 0)
    ,unknownCoverageCount: unknownCoverage.unknownCount
  };
  return {
    header: { contractName: PDF_PREFLIGHT_CONTRACT_NAME, version: PDF_PREFLIGHT_CONTRACT_VERSION, sourceDigest, generatedAt, provider },
    payload: {
      summary,
      metadata: { fields: metadata, rawValuesIncluded: false },
      embeddedData: { attachmentCount: attachmentsCount, possibleTokenCounts: { embeddedFiles: scan.counts.embeddedFiles || 0, fileAttachment: scan.counts.fileAttachment || 0, xfa: scan.counts.xfa || 0, richMedia: scan.counts.richMedia || 0 } },
      attachments: {
        attachmentCount: attachmentsCount,
        fileAttachmentCount,
        embeddedFileNameTreeCount: scan.counts.embeddedFiles || 0,
        unknownCount: scan.truncated ? 1 : 0,
        coverage: coverage.attachments
      },
      annotations,
      scripts: {
        javaScriptActionCount: scan.counts.javascriptAction || 0,
        openActionCount: scan.counts.openAction || 0,
        additionalActionCount: scan.counts.additionalAction || 0,
        launchActionCount: scan.counts.launchAction || 0,
        submitFormActionCount: scan.counts.submitFormAction || 0,
        remoteGoToActionCount: scan.counts.remoteGoToAction || 0,
        uriActionCount: scan.counts.uriAction || 0,
        executionAttempted: false,
        coverage: coverage.scripts
      },
      revisions: {
        eofMarkerCount: scan.counts.eofMarker || 0,
        startxrefCount: scan.counts.startxref || 0,
        previousRevisionReferenceCount: scan.counts.previousRevision || 0,
        incrementalUpdateCountEstimate: Math.max(0, (scan.counts.eofMarker || 0) - 1),
        hiddenContentState: "unknown",
        coverage: coverage.revisions
      },
      encryption: {
        state: scan.state,
        encrypted,
        encryptionMarkerCount: scan.counts.encryption || 0,
        permissionsObserved: Boolean(payload.permissions),
        permissionChangeState: payload.permissions ? "observed" : "unknown"
      },
      formValues,
      // This aggregate is deliberately value-free. It gives the transition
      // gate a stable privacy surface without serializing names, values, text,
      // URLs, attachment names, or active-content payloads.
      privacySensitiveContent: {
        metadataFieldCount: metadataCount,
        attachmentCount: attachmentsCount,
        annotationCount: annotations.totalCount,
        formFieldCount: formValues.fieldCount,
        populatedFormFieldCount: formValues.populatedFieldCount,
        embeddedActionCount: (scan.counts.javascriptAction || 0)
          + (scan.counts.openAction || 0)
          + (scan.counts.additionalAction || 0)
          + (scan.counts.launchAction || 0)
          + (scan.counts.submitFormAction || 0)
          + (scan.counts.remoteGoToAction || 0)
          + (scan.counts.uriAction || 0),
        signatureCount: scan.counts.signature || 0,
        encryptionState: encrypted ? "encrypted" : "plain"
      },
      coverage,
      unknownCoverage,
      networkBoundaries: { ...links, possibleActionTokenCounts: { uri: scan.counts.uriAction || 0, remoteGoTo: scan.counts.remoteGoToAction || 0, submitForm: scan.counts.submitFormAction || 0 } },
      activeContent: { possibleActionTokenCounts: { javascript: scan.counts.javascriptAction || 0, openAction: scan.counts.openAction || 0, additionalAction: scan.counts.additionalAction || 0, launch: scan.counts.launchAction || 0 }, executionAttempted: false },
      security: { encrypted, locked: Boolean(payload.security?.isLocked), permissionsObserved: Boolean(payload.permissions) },
      sanitization,
      findings
    }
  };
}

export function validatePreflightReport(report, { expectedSourceDigest = null } = {}) {
  assertRecord(report, "preflight report");
  if (report.header?.contractName !== PDF_PREFLIGHT_CONTRACT_NAME) throw new Error("invalid preflight contract name");
  if (JSON.stringify(report.header.version) !== JSON.stringify(PDF_PREFLIGHT_CONTRACT_VERSION)) throw new Error("unsupported preflight contract version");
  assertDigest(report.header.sourceDigest);
  if (expectedSourceDigest !== null) {
    assertDigest(expectedSourceDigest, "expectedSourceDigest");
    if (report.header.sourceDigest.toLowerCase() !== expectedSourceDigest.toLowerCase()) throw new Error("preflight source digest is stale");
  }
  assertRecord(report.payload, "preflight payload");
  if (report.payload.sanitization?.status !== "not-run") throw new Error("preflight sanitization must remain not-run");
  if (report.payload.sanitization?.sourceUnchanged !== true) throw new Error("preflight source must remain unchanged");
  if (report.payload.sanitization?.safeToClaimClean !== false) throw new Error("preflight cannot claim a sanitized or clean PDF");
  if (report.payload.activeContent?.executionAttempted !== false) throw new Error("preflight must not execute active content");
  if (report.payload.scripts?.executionAttempted !== false) throw new Error("preflight must not execute script content");
  if (report.payload.summary?.unknownCoverageCount !== report.payload.unknownCoverage?.unknownCount) throw new Error("preflight unknown coverage summary is inconsistent");
  const serialized = JSON.stringify(report);
  for (const forbidden of FORBIDDEN_REPORT_KEYS) {
    if (Object.prototype.hasOwnProperty.call(report, forbidden) || serialized.includes(`"${forbidden}"`)) throw new Error(`preflight contains forbidden content field: ${forbidden}`);
  }
  for (const item of report.payload.findings || []) {
    if (!["info", "warning", "blocked", "unknown"].includes(item.severity)) throw new Error("preflight finding severity is unknown");
    if (!["observed", "possible", "not-observed", "unknown"].includes(item.state)) throw new Error("preflight finding state is unknown");
  }
  if (report.payload.encryption) {
    if (!["observed", "unknown"].includes(report.payload.encryption.state)) throw new Error("preflight encryption state is unknown");
    if (typeof report.payload.encryption.encrypted !== "boolean") throw new Error("preflight encryption flag is invalid");
  }
  if (report.payload.formValues) {
    if (!["observed", "unknown"].includes(report.payload.formValues.state)) throw new Error("preflight form-value state is unknown");
    for (const key of ["fieldCount", "populatedFieldCount"]) {
      if (!Number.isInteger(report.payload.formValues[key]) || report.payload.formValues[key] < 0) throw new Error("preflight form-value count is invalid");
    }
  }
  if (report.payload.privacySensitiveContent) {
    for (const value of Object.values(report.payload.privacySensitiveContent)) {
      if (typeof value !== "number" && typeof value !== "string") throw new Error("preflight privacy surface is not value-minimized");
    }
  }
  const findings = report.payload.findings || [];
  const summary = report.payload.summary || {};
  if (summary.findingCount !== findings.length ||
      summary.warningCount !== findings.filter((item) => item.severity === "warning").length ||
      summary.blockedCount !== findings.filter((item) => item.severity === "blocked").length ||
      summary.unknownCount !== findings.filter((item) => item.state === "unknown").length) {
    throw new Error("preflight finding summary is inconsistent");
  }
  return true;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]));
}

function normalizeReasonCode(code) {
  return {
    pdfkitPageAnnotationEnumeration: "pageAnnotationEnumeration",
    pdfjsAnnotationEnumeration: "pageAnnotationEnumeration"
  }[code] || code;
}

function normalizeCoverage(coverage) {
  if (!coverage) return coverage;
  return {
    ...coverage,
    reasonCodes: [...(coverage.reasonCodes || [])].map(normalizeReasonCode).sort()
  };
}

function normalizeFinding(item) {
  return {
    category: item.category,
    code: item.code,
    severity: item.severity,
    state: item.state,
    count: item.count,
    reasonCodes: [...(item.reasonCodes || [])].map(normalizeReasonCode).sort(),
    evidence: item.evidence
  };
}

/**
 * Removes adapter identity and run-time volatility while retaining the
 * privacy facts that must agree across native PDFKit and browser PDF.js.
 * Source identity remains because a preflight report is source-bound.
 */
export function normalizePreflightReport(report) {
  assertRecord(report, "preflight report");
  const payload = report.payload || {};
  return canonicalize({
    contractName: report.header?.contractName,
    version: report.header?.version,
    sourceDigest: report.header?.sourceDigest,
    payload: {
      summary: payload.summary,
      metadata: payload.metadata,
      embeddedData: payload.embeddedData,
      attachments: payload.attachments ? { ...payload.attachments, coverage: normalizeCoverage(payload.attachments.coverage) } : payload.attachments,
      annotations: payload.annotations ? { ...payload.annotations, coverage: normalizeCoverage(payload.annotations.coverage) } : payload.annotations,
      scripts: payload.scripts ? { ...payload.scripts, coverage: normalizeCoverage(payload.scripts.coverage) } : payload.scripts,
      revisions: payload.revisions ? { ...payload.revisions, coverage: normalizeCoverage(payload.revisions.coverage) } : payload.revisions,
      encryption: payload.encryption,
      formValues: payload.formValues,
      privacySensitiveContent: payload.privacySensitiveContent,
      coverage: payload.coverage && Object.fromEntries(Object.entries(payload.coverage).map(([key, value]) => [key, normalizeCoverage(value)])),
      unknownCoverage: payload.unknownCoverage ? {
        ...payload.unknownCoverage,
        categories: Object.fromEntries(Object.entries(payload.unknownCoverage.categories || {}).map(([key, value]) => [key, normalizeCoverage(value)]))
      } : payload.unknownCoverage,
      networkBoundaries: payload.networkBoundaries,
      activeContent: payload.activeContent,
      security: payload.security,
      sanitization: payload.sanitization,
      findings: [...(payload.findings || [])].map(normalizeFinding).sort((a, b) => `${a.category}.${a.code}`.localeCompare(`${b.category}.${b.code}`))
    }
  });
}

function transitionSnapshot(report, surface) {
  const payload = report?.payload;
  if (!payload) return null;
  switch (surface) {
    case "metadata":
      return payload.metadata?.fields || null;
    case "attachments":
      return payload.attachments ? {
        attachmentCount: payload.attachments.attachmentCount,
        fileAttachmentCount: payload.attachments.fileAttachmentCount,
        embeddedFileNameTreeCount: payload.attachments.embeddedFileNameTreeCount
      } : null;
    case "embeddedActions":
      return payload.scripts ? {
        javaScriptActionCount: payload.scripts.javaScriptActionCount,
        openActionCount: payload.scripts.openActionCount,
        additionalActionCount: payload.scripts.additionalActionCount,
        launchActionCount: payload.scripts.launchActionCount,
        submitFormActionCount: payload.scripts.submitFormActionCount,
        remoteGoToActionCount: payload.scripts.remoteGoToActionCount,
        uriActionCount: payload.scripts.uriActionCount
      } : null;
    case "encryption":
      return payload.encryption || (payload.security ? { encrypted: payload.security.encrypted } : null);
    case "annotations":
      return payload.annotations ? {
        totalCount: payload.annotations.totalCount,
        byKind: payload.annotations.byKind
      } : null;
    case "formValues":
      return payload.formValues ? {
        state: payload.formValues.state,
        fieldCount: payload.formValues.fieldCount,
        populatedFieldCount: payload.formValues.populatedFieldCount,
        byKind: payload.formValues.byKind
      } : null;
    case "revisions":
      return payload.revisions ? {
        eofMarkerCount: payload.revisions.eofMarkerCount,
        startxrefCount: payload.revisions.startxrefCount,
        previousRevisionReferenceCount: payload.revisions.previousRevisionReferenceCount,
        incrementalUpdateCountEstimate: payload.revisions.incrementalUpdateCountEstimate
      } : null;
    case "privacySensitiveContent":
      return payload.privacySensitiveContent || null;
    default:
      return null;
  }
}

function transitionState(sourceValue, outputValue) {
  if (sourceValue === null || outputValue === null) return "unknown";
  if (JSON.stringify(canonicalize(sourceValue)) === JSON.stringify(canonicalize(outputValue))) return "unchanged";
  return "changed";
}

/**
 * Compare value-minimized preflight observations at the source/output
 * boundary. This is intentionally not a sanitization claim. A changed
 * surface is publishable only when the caller explicitly authorizes that
 * surface and separately proves the operation is supported.
 */
export function comparePreflightTransitions(
  sourceReport,
  outputReport,
  { allowedChangedSurfaces = [] } = {}
) {
  const allowed = new Set(Array.isArray(allowedChangedSurfaces) ? allowedChangedSurfaces : []);
  const transitions = {};
  for (const surface of PREFLIGHT_PROTECTED_SURFACES) {
    const sourceValue = transitionSnapshot(sourceReport, surface);
    const outputValue = transitionSnapshot(outputReport, surface);
    const status = transitionState(sourceValue, outputValue);
    transitions[surface] = {
      status,
      authorized: status === "unchanged" || allowed.has(surface),
      source: sourceValue,
      output: outputValue
    };
  }
  const changedSurfaces = PREFLIGHT_PROTECTED_SURFACES.filter((surface) => transitions[surface].status === "changed");
  const unknownSurfaces = PREFLIGHT_PROTECTED_SURFACES.filter((surface) => transitions[surface].status === "unknown");
  const unauthorizedSurfaces = changedSurfaces.filter((surface) => !transitions[surface].authorized);
  const status = unauthorizedSurfaces.length ? "failed" : unknownSurfaces.length ? "unknown" : "passed";
  return {
    status,
    sourceDigest: sourceReport?.header?.sourceDigest || null,
    outputDigest: outputReport?.header?.sourceDigest || null,
    changedSurfaces,
    unknownSurfaces,
    unauthorizedSurfaces,
    transitions,
    message: unauthorizedSurfaces.length
      ? `Unapproved privacy-sensitive transition(s): ${unauthorizedSurfaces.join(", ")}.`
      : unknownSurfaces.length
        ? `Privacy transition coverage is unknown for: ${unknownSurfaces.join(", ")}.`
        : "Protected preflight surfaces are unchanged or explicitly authorized."
  };
}

function collectDifferences(nativeValue, webValue, pathName, differences) {
  if (differences.length >= 100) return;
  if (Object.is(nativeValue, webValue)) return;
  if (Array.isArray(nativeValue) && Array.isArray(webValue)) {
    if (nativeValue.length !== webValue.length) {
      differences.push({ path: pathName, native: nativeValue.length, web: webValue.length });
      return;
    }
    nativeValue.forEach((value, index) => collectDifferences(value, webValue[index], `${pathName}[${index}]`, differences));
    return;
  }
  if (nativeValue && webValue && typeof nativeValue === "object" && typeof webValue === "object") {
    const keys = new Set([...Object.keys(nativeValue), ...Object.keys(webValue)]);
    for (const key of [...keys].sort()) collectDifferences(nativeValue[key], webValue[key], `${pathName}.${key}`, differences);
    return;
  }
  differences.push({ path: pathName, native: nativeValue ?? null, web: webValue ?? null });
}

export function comparePreflightReports(nativeReport, webReport) {
  const native = normalizePreflightReport(nativeReport);
  const web = normalizePreflightReport(webReport);
  const differences = [];
  collectDifferences(native, web, "preflight", differences);
  return { equivalent: differences.length === 0, differences, native, web };
}

export const preflightForbiddenReportKeys = Object.freeze([...FORBIDDEN_REPORT_KEYS]);
