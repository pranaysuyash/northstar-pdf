/*
 * Device-adaptive, value-free resource governance for browser PDF work.
 *
 * This module decides budgets. It does not render, OCR, mutate PDF bytes, or
 * promote partial output. Those responsibilities remain with PDF.js, an OCR
 * worker/provider, pdf-lib, and the source-bound validation pipeline.
 */

export const BROWSER_RESOURCE_POLICY_CONTRACT = "pdf-editor.browser-resource-policy";
export const BROWSER_RESOURCE_POLICY_VERSION = Object.freeze({ major: 1, minor: 0 });

const STATES = new Set(["enabled", "limited", "deferred", "unknown", "blocked"]);
const MEMORY_STATES = new Set(["available", "unavailable", "unknown"]);
const CONNECTION_TYPES = new Set(["slow-2g", "2g", "3g", "4g", "unknown"]);
const DIGEST_RE = /^[0-9a-f]{64}$/i;

function finiteNumber(value, fallback = null) {
  return Number.isFinite(value) ? Number(value) : fallback;
}

function nonNegative(value, fallback = 0) {
  const normalized = finiteNumber(value, fallback);
  return normalized == null ? fallback : Math.max(0, normalized);
}

function positiveInteger(value, fallback) {
  const normalized = Math.floor(nonNegative(value, fallback));
  return normalized > 0 ? normalized : fallback;
}

function integerOrNull(value) {
  if (!Number.isFinite(value)) return null;
  return Math.max(0, Math.floor(value));
}

function numberOrNull(value) {
  return Number.isFinite(value) ? Number(value) : null;
}

function stringOrNull(value) {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function boolOrNull(value) {
  return typeof value === "boolean" ? value : null;
}

function normalizeMemoryState(value, hasSignal) {
  if (MEMORY_STATES.has(value)) return value;
  return hasSignal ? "available" : "unknown";
}

export function normalizeResourceEnvironment(input = {}) {
  const memoryGB = numberOrNull(input.deviceMemoryGB);
  const storage = input.storage || {};
  const memory = input.memory || {};
  const viewport = input.viewport || {};
  const connection = input.connection || {};
  return {
    cpuLogicalCores: integerOrNull(input.cpuLogicalCores),
    deviceMemoryGB: memoryGB == null ? null : Math.max(0, memoryGB),
    devicePixelRatio: Math.max(1, finiteNumber(input.devicePixelRatio, 1)),
    viewport: {
      width: Math.max(0, finiteNumber(viewport.width, 0)),
      height: Math.max(0, finiteNumber(viewport.height, 0))
    },
    connection: {
      effectiveType: CONNECTION_TYPES.has(connection.effectiveType)
        ? connection.effectiveType
        : "unknown",
      saveData: boolOrNull(connection.saveData)
    },
    memory: {
      state: normalizeMemoryState(memory.state, memory.usedJSHeapSize != null),
      usedJSHeapSize: numberOrNull(memory.usedJSHeapSize),
      jsHeapSizeLimit: numberOrNull(memory.jsHeapSizeLimit)
    },
    storage: {
      state: MEMORY_STATES.has(storage.state) ? storage.state : "unknown",
      quotaBytes: numberOrNull(storage.quotaBytes),
      usageBytes: numberOrNull(storage.usageBytes)
    },
    browserFamily: stringOrNull(input.browserFamily)
  };
}

export function collectBrowserResourceEnvironment(globalObject = globalThis) {
  const navigatorObject = globalObject.navigator || {};
  const performanceObject = globalObject.performance || {};
  const memory = performanceObject.memory || {};
  const connection = navigatorObject.connection || {};
  const storage = navigatorObject.storage;
  return normalizeResourceEnvironment({
    cpuLogicalCores: navigatorObject.hardwareConcurrency,
    deviceMemoryGB: navigatorObject.deviceMemory,
    devicePixelRatio: globalObject.devicePixelRatio,
    viewport: {
      width: globalObject.innerWidth,
      height: globalObject.innerHeight
    },
    connection: {
      effectiveType: connection.effectiveType,
      saveData: connection.saveData
    },
    memory: {
      state: memory.usedJSHeapSize == null ? "unknown" : "available",
      usedJSHeapSize: memory.usedJSHeapSize,
      jsHeapSizeLimit: memory.jsHeapSizeLimit
    },
    storage: {
      state: "unknown",
      quotaBytes: null,
      usageBytes: null
    },
    browserFamily: navigatorObject.userAgentData?.brands?.[0]?.brand || null
  });
}

export function normalizeResourceDocument(input = {}) {
  const pages = positiveInteger(input.pageCount, 1);
  return {
    byteCount: nonNegative(input.byteCount),
    pageCount: pages,
    maxPageAreaPoints: nonNegative(input.maxPageAreaPoints, 612 * 792),
    maxPageDimensionPoints: nonNegative(input.maxPageDimensionPoints, 792),
    rotatedPageCount: Math.min(pages, integerOrNull(input.rotatedPageCount) || 0),
    rasterPageCount: Math.min(pages, integerOrNull(input.rasterPageCount) || 0),
    selectableTextPageCount: Math.min(pages, integerOrNull(input.selectableTextPageCount) || 0),
    nativeFieldCount: nonNegative(input.nativeFieldCount),
    candidateCount: nonNegative(input.candidateCount),
    maxImagePixelsPerPage: nonNegative(input.maxImagePixelsPerPage),
    hasAttachments: Boolean(input.hasAttachments),
    isEncrypted: Boolean(input.isEncrypted),
    isMalformed: Boolean(input.isMalformed)
  };
}

function addDecision(decisions, id, capability, state, reasonCode, evidence = {}) {
  decisions.push({ id, capability, state, reasonCode, evidence });
}

function memoryClass(environment) {
  if (environment.deviceMemoryGB != null) {
    if (environment.deviceMemoryGB <= 2) return "low";
    if (environment.deviceMemoryGB < 8) return "mid";
    return "high";
  }
  return "unknown";
}

function renderBudget(environment, document) {
  const memory = memoryClass(environment);
  const cores = environment.cpuLogicalCores || 2;
  const basePixels = memory === "low" ? 8_000_000 : memory === "high" && cores >= 8 ? 32_000_000 : 16_000_000;
  const maxDPR = memory === "low" ? 1.5 : memory === "high" && cores >= 8 ? 3 : 2;
  const pageAreaAtDPR = document.maxPageAreaPoints * maxDPR * maxDPR;
  const pagePixels = Math.max(1, Math.min(basePixels, Math.floor(pageAreaAtDPR)));
  const pageScale = Math.min(maxDPR, Math.sqrt(basePixels / Math.max(1, document.maxPageAreaPoints)));
  const large = document.pageCount > 20 || document.byteCount > 20_000_000 || document.maxPageAreaPoints > 2_000_000;
  const rasterHeavy = document.rasterPageCount > 0 || document.maxImagePixelsPerPage > 8_000_000;
  const constrained = memory === "low" || memory === "unknown" || environment.connection.saveData === true;
  const maxConcurrentPages = constrained ? 1 : large || rasterHeavy ? 2 : Math.min(4, Math.max(1, cores));
  return {
    maxDevicePixelRatio: Math.max(1, Math.min(maxDPR, pageScale)),
    maxCanvasPixels: pagePixels,
    maxPagePixels: pagePixels,
    maxPageScale: Math.max(0.1, pageScale),
    maxConcurrentPages,
    chunkPages: large ? 1 : maxConcurrentPages,
    yieldEveryMs: constrained || large ? 8 : 16,
    workerCount: Math.max(1, Math.min(constrained ? 1 : 2, cores)),
    allowHighDPI: pageScale >= 2 && !constrained && !large && !rasterHeavy,
    reasons: [
      ...(memory === "unknown" ? ["deviceMemoryUnavailable"] : []),
      ...(large ? ["largeDocumentPageBudget"] : []),
      ...(rasterHeavy ? ["rasterPixelBudget"] : []),
      ...(environment.devicePixelRatio > maxDPR ? ["highDPIClamped"] : []),
      ...(environment.connection.saveData === true ? ["saveDataConservativeBudget"] : [])
    ]
  };
}

function ocrBudget(environment, document, request, render) {
  const requested = request.ocrRequested === true;
  const memory = memoryClass(environment);
  const constrained = memory === "low" || memory === "unknown" || environment.connection.saveData === true;
  const pagePixels = memory === "low" ? 2_000_000 : memory === "high" ? 12_000_000 : 6_000_000;
  const hasScannedWork = document.rasterPageCount > 0 || document.selectableTextPageCount < document.pageCount;
  const supported = requested && !document.isMalformed;
  const state = !requested ? "deferred" : !supported ? "blocked" : constrained ? "limited" : "enabled";
  return {
    state,
    enabled: state === "enabled" || state === "limited",
    maxConcurrentJobs: constrained ? 1 : Math.min(2, Math.max(1, environment.cpuLogicalCores || 1)),
    maxPixelsPerPage: pagePixels,
    maxPagesPerBatch: constrained ? 1 : hasScannedWork ? 4 : 8,
    maxBatchPixels: pagePixels * (constrained ? 1 : hasScannedWork ? 4 : 8),
    yieldEveryMs: constrained ? 8 : 16,
    cancellationTimeoutMs: constrained ? 5_000 : 15_000,
    requiresUserConfirmation: true,
    reasons: [
      ...(!requested ? ["ocrNeedsExplicitOptIn"] : []),
      ...(memory === "unknown" ? ["deviceMemoryUnavailable"] : []),
      ...(constrained ? ["ocrPixelsClamped"] : []),
      ...(document.isMalformed ? ["malformedDocumentNoOCR"] : [])
    ]
  };
}

function batchBudget(environment, document, request) {
  const requested = request.batchRequested === true;
  const memory = memoryClass(environment);
  const constrained = memory === "low" || memory === "unknown" || environment.connection.saveData === true;
  const maxDocuments = constrained ? 5 : memory === "high" ? 50 : 20;
  const maxTotalBytes = constrained ? 20_000_000 : memory === "high" ? 500_000_000 : 150_000_000;
  const maxTotalPages = constrained ? 50 : memory === "high" ? 500 : 200;
  const state = requested ? "limited" : "deferred";
  return {
    state,
    enabled: requested,
    maxDocuments,
    maxTotalBytes,
    maxTotalPages,
    maxConcurrentDocuments: constrained ? 1 : 2,
    checkpointEveryDocuments: constrained ? 1 : 5,
    checkpointEveryPages: document.pageCount > 20 || constrained ? 5 : 20,
    reasons: [
      ...(!requested ? ["batchNeedsExplicitOptIn"] : []),
      ...(constrained ? ["largeDocumentBatchBudget"] : [])
    ]
  };
}

function recoveryBudget(environment, document, request) {
  const longRunning = document.pageCount > 10 || document.byteCount > 10_000_000 || request.ocrRequested === true || request.batchRequested === true;
  const constrained = memoryClass(environment) === "low" || memoryClass(environment) === "unknown";
  return {
    checkpointRequired: longRunning,
    retryCount: constrained ? 1 : 2,
    backoffMs: constrained ? 250 : 500,
    staleDigestRequired: true,
    resumeSupported: true,
    partialOutputAllowed: false,
    cancellationSupported: true,
    reasons: [
      ...(longRunning ? ["checkpointRequired"] : []),
      ...(longRunning ? ["cancellationCheckpoint"] : []),
      "recoveryResumeFromDigest"
    ]
  };
}

export function chooseBrowserResourcePolicy({
  environment = {},
  document = {},
  request = {},
  generatedAt = new Date().toISOString(),
  sourceDigest = null,
  provider = { providerID: "pdfjs-pdflib-browser", runtimeKind: "browser" }
} = {}) {
  const normalizedEnvironment = normalizeResourceEnvironment(environment);
  const normalizedDocument = normalizeResourceDocument(document);
  const normalizedRequest = {
    renderMode: request.renderMode || "reader",
    ocrRequested: request.ocrRequested === true,
    batchRequested: request.batchRequested === true,
    highDPIRequested: request.highDPIRequested === true
  };
  const render = renderBudget(normalizedEnvironment, normalizedDocument);
  const ocr = ocrBudget(normalizedEnvironment, normalizedDocument, normalizedRequest, render);
  const batch = batchBudget(normalizedEnvironment, normalizedDocument, normalizedRequest);
  const recovery = recoveryBudget(normalizedEnvironment, normalizedDocument, normalizedRequest);
  const decisions = [];
  addDecision(decisions, "render", "render", render.allowHighDPI ? "enabled" : "limited", render.reasons[0] || "boundedRenderBudget", {
    maxDevicePixelRatio: render.maxDevicePixelRatio,
    maxCanvasPixels: render.maxCanvasPixels
  });
  addDecision(decisions, "ocr", "ocr", ocr.state, ocr.reasons[0] || "ocrExplicitRequest", {
    maxPagesPerBatch: ocr.maxPagesPerBatch,
    maxPixelsPerPage: ocr.maxPixelsPerPage
  });
  addDecision(decisions, "batch", "batch", batch.state, batch.reasons[0] || "batchExplicitRequest", {
    maxDocuments: batch.maxDocuments,
    maxTotalPages: batch.maxTotalPages
  });
  addDecision(decisions, "recovery", "recovery", recovery.checkpointRequired ? "limited" : "enabled", recovery.reasons[0] || "recoveryPolicy", {
    checkpointRequired: recovery.checkpointRequired,
    resumeSupported: recovery.resumeSupported
  });
  if (normalizedEnvironment.memory.state === "unknown") {
    addDecision(decisions, "memory-signal", "memory", "unknown", "unknownMemoryPressure", {});
  }
  return {
    header: {
      contractName: BROWSER_RESOURCE_POLICY_CONTRACT,
      version: BROWSER_RESOURCE_POLICY_VERSION,
      generatedAt,
      sourceDigest: DIGEST_RE.test(sourceDigest || "") ? sourceDigest : null,
      provider
    },
    payload: {
      environment: normalizedEnvironment,
      document: normalizedDocument,
      request: normalizedRequest,
      budgets: { render, ocr, batch, recovery },
      decisions,
      safety: {
        contentLogged: false,
        networkAccessAttempted: false,
        sourceBytesMutated: false,
        partialOutputPromoted: false,
        cancellationSupported: true
      }
    }
  };
}

export function validateBrowserResourcePolicy(policy, { expectedSourceDigest = null } = {}) {
  if (!policy || policy.header?.contractName !== BROWSER_RESOURCE_POLICY_CONTRACT) throw new Error("invalid resource policy contract");
  if (policy.header.version?.major !== BROWSER_RESOURCE_POLICY_VERSION.major) throw new Error("unsupported resource policy contract version");
  if (policy.header.sourceDigest != null && !DIGEST_RE.test(policy.header.sourceDigest)) throw new Error("invalid resource policy source digest");
  if (expectedSourceDigest != null && policy.header.sourceDigest !== expectedSourceDigest) throw new Error("resource policy source digest mismatch");
  const { budgets, decisions, safety } = policy.payload || {};
  if (!budgets?.render || !budgets?.ocr || !budgets?.batch || !budgets?.recovery) throw new Error("resource policy budgets are incomplete");
  if (!Array.isArray(decisions) || decisions.some((decision) => !STATES.has(decision.state))) throw new Error("resource policy decision state is unknown");
  if (safety?.contentLogged !== false || safety?.networkAccessAttempted !== false || safety?.sourceBytesMutated !== false || safety?.partialOutputPromoted !== false) throw new Error("resource policy safety invariant failed");
  if (budgets.recovery.partialOutputAllowed !== false || budgets.recovery.staleDigestRequired !== true || budgets.recovery.resumeSupported !== true) throw new Error("resource recovery invariant failed");
  if (budgets.render.maxConcurrentPages < 1 || budgets.ocr.maxConcurrentJobs < 1 || budgets.batch.maxConcurrentDocuments < 1) throw new Error("resource concurrency budget is invalid");
  return true;
}

export function summarizeResourceEvent(event = {}) {
  return {
    contractName: "pdf-editor.resource-event",
    version: BROWSER_RESOURCE_POLICY_VERSION,
    eventType: stringOrNull(event.eventType) || "unknown",
    sourceDigest: DIGEST_RE.test(event.sourceDigest || "") ? event.sourceDigest : null,
    operationID: stringOrNull(event.operationID),
    batchIndex: integerOrNull(event.batchIndex),
    pageCount: integerOrNull(event.pageCount),
    completedCount: integerOrNull(event.completedCount),
    cancelled: event.cancelled === true,
    recovered: event.recovered === true,
    status: stringOrNull(event.status) || "unknown",
    reasonCode: stringOrNull(event.reasonCode),
    elapsedMs: nonNegative(event.elapsedMs),
    contentLogged: false
  };
}

export function createResourceCheckpoint({ sourceDigest, operationID, batchIndex, completedCount = 0, policyDigest = null } = {}) {
  if (!DIGEST_RE.test(sourceDigest || "")) throw new Error("checkpoint requires source digest");
  if (!stringOrNull(operationID)) throw new Error("checkpoint requires operation ID");
  return Object.freeze({
    contractName: "pdf-editor.resource-checkpoint",
    version: BROWSER_RESOURCE_POLICY_VERSION,
    sourceDigest,
    operationID,
    batchIndex: Math.max(0, integerOrNull(batchIndex) || 0),
    completedCount: Math.max(0, integerOrNull(completedCount) || 0),
    policyDigest: DIGEST_RE.test(policyDigest || "") ? policyDigest : null,
    partialOutputPromoted: false
  });
}

export function validateResourceCheckpoint(checkpoint, { sourceDigest, operationID } = {}) {
  if (!checkpoint || checkpoint.contractName !== "pdf-editor.resource-checkpoint") throw new Error("invalid resource checkpoint");
  if (checkpoint.sourceDigest !== sourceDigest) throw new Error("stale resource checkpoint source digest");
  if (checkpoint.operationID !== operationID) throw new Error("resource checkpoint operation mismatch");
  if (checkpoint.partialOutputPromoted !== false) throw new Error("resource checkpoint cannot promote partial output");
  return true;
}

export async function runAdaptiveBatches({
  items = [],
  policy,
  sourceDigest,
  operationID,
  signal,
  processItem,
  saveCheckpoint = async () => {},
  startCheckpoint = null
} = {}) {
  validateBrowserResourcePolicy(policy, { expectedSourceDigest: sourceDigest });
  if (typeof processItem !== "function") throw new Error("adaptive batch processor is required");
  if (startCheckpoint) validateResourceCheckpoint(startCheckpoint, { sourceDigest, operationID });
  const checkpointEvery = Math.max(1, policy.payload.budgets.batch.checkpointEveryDocuments);
  const startIndex = startCheckpoint ? startCheckpoint.completedCount : 0;
  const results = [];
  let cancelled = false;
  for (let index = startIndex; index < items.length; index += 1) {
    if (signal?.aborted) {
      cancelled = true;
      break;
    }
    results.push(await processItem(items[index], index));
    if ((index + 1) % checkpointEvery === 0 || index === items.length - 1) {
      const checkpoint = createResourceCheckpoint({ sourceDigest, operationID, batchIndex: index, completedCount: index + 1 });
      await saveCheckpoint(checkpoint);
    }
    await new Promise((resolve) => setTimeout(resolve, policy.payload.budgets.render.yieldEveryMs));
  }
  return {
    status: cancelled ? "cancelled" : "completed",
    cancelled,
    recovered: startIndex > 0,
    completedCount: startIndex + results.length,
    resultCount: results.length,
    partialOutputPromoted: false,
    checkpointRequired: policy.payload.budgets.recovery.checkpointRequired,
    results
  };
}

export const __testOnly = Object.freeze({ memoryClass, renderBudget, ocrBudget, batchBudget, recoveryBudget });
