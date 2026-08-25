/**
 * Evidence-only benchmark contract for semantic text runs and OCR geometry.
 *
 * The contract intentionally retains hashes, counts, and geometry, never the
 * recognized or replacement text. It is therefore safe to place in local
 * benchmark reports governed by the corpus logging policy.
 */

export const TEXT_RUN_OCR_ALIGNMENT_CONTRACT = "pdf-editor.text-run-ocr-alignment";
export const TEXT_RUN_OCR_ALIGNMENT_VERSION = Object.freeze({ major: 1, minor: 0 });

const EPSILON = 0.0001;

function assertFinite(value, label) {
  if (!Number.isFinite(Number(value))) throw new Error(`${label} must be finite`);
  return Number(value);
}

function rect(value, label = "bounds") {
  if (!value || typeof value !== "object") throw new Error(`${label} is required`);
  const result = {
    x: assertFinite(value.x, `${label}.x`),
    y: assertFinite(value.y, `${label}.y`),
    width: assertFinite(value.width, `${label}.width`),
    height: assertFinite(value.height, `${label}.height`)
  };
  if (result.width < 0 || result.height < 0) throw new Error(`${label} dimensions must be non-negative`);
  return result;
}

function normalizeText(value) {
  return String(value || "")
    .normalize("NFKC")
    .replace(/\s+/gu, " ")
    .trim();
}

function fnvFallback(value) {
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.codePointAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

async function sha256(value) {
  const normalized = normalizeText(value);
  const subtle = globalThis.crypto?.subtle;
  if (!subtle) return `fnv1a-${fnvFallback(normalized)}`;
  const bytes = new TextEncoder().encode(normalized);
  const digest = await subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function coordinateSpace(rotationDegrees = 0) {
  return {
    unit: "points",
    origin: "lowerLeft",
    pageBox: "crop",
    rotationDegrees: ((Number(rotationDegrees) % 360) + 360) % 360
  };
}

export async function normalizeTextRun({
  pageIndex,
  sequence,
  text,
  bounds,
  pageBounds,
  rotation = 0,
  providerID,
  sourceDigest,
  origin = "unknown",
  hasEOL = false
}) {
  const normalized = normalizeText(text);
  const runBounds = rect(bounds);
  const page = rect(pageBounds, "pageBounds");
  const textHash = await sha256(normalized);
  const insidePage = runBounds.x >= page.x - EPSILON
    && runBounds.y >= page.y - EPSILON
    && runBounds.x + runBounds.width <= page.x + page.width + EPSILON
    && runBounds.y + runBounds.height <= page.y + page.height + EPSILON;
  return {
    runID: `${pageIndex}:${sequence}:${textHash.slice(0, 16)}`,
    pageIndex: Number(pageIndex),
    sequence: Number(sequence),
    textHash,
    characterCount: normalized.length,
    bounds: runBounds,
    pageBounds: page,
    coordinate: {
      pageIndex: Number(pageIndex),
      rect: runBounds,
      coordinateSpace: coordinateSpace(rotation)
    },
    geometryStatus: insidePage ? "insidePage" : "outsidePage",
    origin,
    providerID: providerID || "unknown",
    sourceDigest: sourceDigest || null,
    hasEOL: Boolean(hasEOL)
  };
}

/**
 * PDF.js text items use a text transform whose translation is the baseline
 * in PDF user space. Convert it to a lower-left rectangle before normalizing.
 */
export async function normalizePdfJsTextItems({
  items,
  pageIndex,
  pageBounds,
  rotation = 0,
  providerID = "pdfjs",
  sourceDigest
}) {
  const page = rect(pageBounds, "pageBounds");
  const runs = [];
  for (const [sequence, item] of (items || []).entries()) {
    const text = normalizeText(item?.str);
    if (!text) continue;
    const transform = item?.transform && typeof item.transform.length === "number"
      ? Array.from(item.transform)
      : [];
    const x = Number(transform[4]);
    const baseline = Number(transform[5]);
    const transformedHeight = Math.hypot(Number(transform[2]) || 0, Number(transform[3]) || 0);
    const height = Math.max(Number(item?.height) || 0, transformedHeight, 1);
    const width = Math.max(Number(item?.width) || 0, 1);
    const bounds = {
      x: Number.isFinite(x) ? x : page.x,
      y: Number.isFinite(baseline) ? baseline - height : page.y,
      width,
      height
    };
    runs.push(await normalizeTextRun({
      pageIndex,
      sequence,
      text,
      bounds,
      pageBounds: page,
      rotation,
      providerID,
      sourceDigest,
      origin: "pdfjs.textContent",
      hasEOL: Boolean(item?.hasEOL)
    }));
  }
  return runs;
}

export async function normalizeNativeTextRun({
  pageIndex,
  sequence,
  text,
  bounds,
  pageBounds,
  rotation = 0,
  sourceDigest,
  providerID = "pdfkit"
}) {
  return normalizeTextRun({
    pageIndex,
    sequence,
    text,
    bounds,
    pageBounds,
    rotation,
    providerID,
    sourceDigest,
    origin: "pdfkit.selectionByLine"
  });
}

export async function normalizeOCREvidence({
  pageIndex,
  sequence,
  text,
  bounds,
  pageBounds,
  rotation = 0,
  confidence = null,
  providerID,
  sourceDigest
}) {
  const run = await normalizeTextRun({
    pageIndex,
    sequence,
    text,
    bounds,
    pageBounds,
    rotation,
    providerID,
    sourceDigest,
    origin: "ocr.textObservation"
  });
  return {
    ...run,
    confidence: confidence == null ? null : Math.max(0, Math.min(1, Number(confidence)))
  };
}

function sameBounds(left, right, tolerance) {
  return Math.abs(left.x - right.x) <= tolerance
    && Math.abs(left.y - right.y) <= tolerance
    && Math.abs(left.width - right.width) <= tolerance
    && Math.abs(left.height - right.height) <= tolerance;
}

function groupByHash(runs) {
  const result = new Map();
  for (const run of runs || []) {
    const values = result.get(run.textHash) || [];
    values.push(run);
    result.set(run.textHash, values);
  }
  return result;
}

export function compareTextRunProjections({
  nativeRuns = [],
  browserRuns = [],
  sourceDigest,
  tolerancePoints = 2
}) {
  const native = nativeRuns.filter((run) => run.sourceDigest === sourceDigest || !run.sourceDigest);
  const browser = browserRuns.filter((run) => run.sourceDigest === sourceDigest || !run.sourceDigest);
  const browserByHash = groupByHash(browser);
  let exactMatches = 0;
  let geometryMatches = 0;
  const unmatchedNative = [];
  for (const run of native) {
    const candidates = browserByHash.get(run.textHash) || [];
    const match = candidates.find((candidate) => !candidate.__used);
    if (!match) {
      unmatchedNative.push({ pageIndex: run.pageIndex, sequence: run.sequence, textHash: run.textHash });
      continue;
    }
    match.__used = true;
    exactMatches += 1;
    if (sameBounds(run.bounds, match.bounds, tolerancePoints)) geometryMatches += 1;
  }
  for (const run of browser) delete run.__used;
  const denominator = Math.max(native.length, browser.length, 1);
  return {
    state: native.length === 0 && browser.length === 0
      ? "noTextRuns"
      : exactMatches === 0
        ? "providerDivergence"
        : "measured",
    sourceDigest: sourceDigest || null,
    nativeRunCount: native.length,
    browserRunCount: browser.length,
    nativeCharacterCount: native.reduce((sum, run) => sum + run.characterCount, 0),
    browserCharacterCount: browser.reduce((sum, run) => sum + run.characterCount, 0),
    exactTextHashMatches: exactMatches,
    textRunRecall: exactMatches / denominator,
    geometryMatchCount: geometryMatches,
    geometryAgreement: exactMatches === 0 ? 0 : geometryMatches / exactMatches,
    unmatchedNative: unmatchedNative.slice(0, 12),
    tolerancePoints
  };
}

export function compareOCRLayerAlignment({
  ocrRuns = [],
  referenceRuns = [],
  sourceDigest,
  tolerancePoints = 3
}) {
  const ocr = ocrRuns.filter((run) => run.sourceDigest === sourceDigest || !run.sourceDigest);
  const reference = referenceRuns.filter((run) => run.sourceDigest === sourceDigest || !run.sourceDigest);
  if (ocr.length === 0) {
    return {
      state: reference.length === 0 ? "noEvidence" : "abstainedNoOCR",
      sourceDigest: sourceDigest || null,
      ocrObservationCount: 0,
      referenceRunCount: reference.length,
      matchedTextCount: 0,
      geometryAgreement: null,
      tolerancePoints
    };
  }
  if (reference.length === 0) {
    return {
      state: "abstainedNoReference",
      sourceDigest: sourceDigest || null,
      ocrObservationCount: ocr.length,
      referenceRunCount: 0,
      matchedTextCount: 0,
      geometryAgreement: null,
      tolerancePoints
    };
  }
  const referenceByHash = groupByHash(reference);
  let matched = 0;
  let geometryMatches = 0;
  for (const observation of ocr) {
    const candidate = (referenceByHash.get(observation.textHash) || []).find((run) => !run.__used);
    if (!candidate) continue;
    candidate.__used = true;
    matched += 1;
    if (sameBounds(observation.bounds, candidate.bounds, tolerancePoints)) geometryMatches += 1;
  }
  for (const run of reference) delete run.__used;
  return {
    state: "measured",
    sourceDigest: sourceDigest || null,
    ocrObservationCount: ocr.length,
    referenceRunCount: reference.length,
    matchedTextCount: matched,
    textRecall: matched / Math.max(reference.length, 1),
    geometryMatchCount: geometryMatches,
    geometryAgreement: matched === 0 ? 0 : geometryMatches / matched,
    tolerancePoints
  };
}

export function buildTextRunReplacementProbe({
  sourceDigest,
  run,
  providerID,
  operationSupported = false,
  outsideRegionValidation = "not-run",
  visualValidation = "not-run"
}) {
  if (!sourceDigest || !run?.runID) throw new Error("A source-bound text run is required");
  return {
    operationKind: "textRunReplacement",
    sourceDigest,
    providerID: providerID || "unknown",
    targetRunID: run.runID,
    targetPageIndex: run.pageIndex,
    targetBounds: run.bounds,
    targetTextHash: run.textHash,
    reviewState: "review-required",
    capabilityState: operationSupported ? "supported-needs-fidelity-proof" : "abstained-unsupported",
    outsideRegionValidation,
    visualValidation,
    replacementValueRetained: false
  };
}

/**
 * Build the typed in-memory intent for a semantic text-run rewrite. The
 * current browser writer must reject this operation before pdf-lib because
 * drawing replacement text is an overlay, not an existing-object rewrite.
 * The replacement value is intentionally caller-owned and never serialized
 * by the value-free evidence report.
 */
export function buildTextRunReplacementOperation({
  sourceDigest,
  run,
  replacementText,
  fontFingerprint = null,
  operationID = `text-run-replacement:${run?.runID || "unknown"}`
}) {
  if (!sourceDigest || !run?.runID || !run?.coordinate) {
    throw new Error("A source-bound text run with coordinates is required");
  }
  return {
    id: operationID,
    pageIndex: run.pageIndex,
    targetID: run.runID,
    kind: "textRunReplacement",
    value: String(replacementText ?? ""),
    bounds: run.bounds,
    sourceDigest,
    coordinate: run.coordinate,
    payload: {
      kind: "textRunReplacement",
      originalTextHash: run.textHash,
      runID: run.runID,
      fontFingerprint
    },
    reversible: true,
    destructive: false
  };
}

export function validateTextRunOCRAlignmentReport(report) {
  if (!report || report.contractName !== TEXT_RUN_OCR_ALIGNMENT_CONTRACT) {
    throw new Error("invalid text-run/OCR alignment contract");
  }
  if (report.version?.major !== TEXT_RUN_OCR_ALIGNMENT_VERSION.major) {
    throw new Error("unsupported text-run/OCR alignment contract major version");
  }
  if (!Array.isArray(report.cases)) throw new Error("alignment report cases are required");
  for (const entry of report.cases) {
    if (!entry.fixtureId || !entry.sourceDigest) throw new Error("alignment case must be source-bound");
    if (!entry.native || !entry.browser) throw new Error("alignment case needs native and browser projections");
    if (entry.replacement?.replacementValueRetained) throw new Error("replacement values must not be retained");
  }
  return true;
}
