/**
 * Provider-neutral structural fingerprint parity.
 *
 * This is intentionally lower-level than candidate pairing and higher-level
 * than PDF object identity. It answers what each provider observed about the
 * same source document while excluding provider IDs, timestamps, raw labels,
 * output digests, and serialized PDF bytes from semantic comparison.
 */

export const FINGERPRINT_PARITY_CONTRACT = Object.freeze({
  name: "pdf-editor.native-web-structural-fingerprint-parity",
  version: Object.freeze({ major: 1, minor: 0 }),
  coordinateTolerancePoints: 0.01,
  textCharacterRelativeTolerance: 0.05,
  textCharacterMinimumTolerance: 16,
  ignoredRepresentationFields: Object.freeze([
    "document.header.provider.id",
    "document.header.provider.version",
    "document.header.provider.platform",
    "document.header.generatedAt",
    "document.header.sourceDigest",
    "document.payload.source.sha256",
    "document.payload.fields[].id",
    "document.payload.candidates[].id",
    "document.payload.candidates[].evidenceItems[].id",
    "editSession.operations[].id",
    "validation.outputDigest",
    "rawLabels",
    "PDFBytes"
  ]),
  sourceIdentityFields: Object.freeze([
    "sourcePath",
    "sourceDigest",
    "sourceByteCount"
  ])
});

function round(value, places = 2) {
  if (typeof value !== "number" || !Number.isFinite(value)) return value;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function rectSignature(rect) {
  if (!rect) return null;
  return {
    x: round(rect.x),
    y: round(rect.y),
    width: round(rect.width),
    height: round(rect.height)
  };
}

function sortedEntries(values) {
  return Object.fromEntries(Object.entries(values).sort(([left], [right]) => left.localeCompare(right)));
}

function histogram(values) {
  const counts = {};
  for (const value of values) {
    const key = String(value ?? "unknown");
    counts[key] = (counts[key] || 0) + 1;
  }
  return sortedEntries(counts);
}

function countBy(values, selector) {
  return histogram(values.map(selector));
}

function uniqueSorted(values) {
  return [...new Set(values.filter((value) => value !== null && value !== undefined))].sort();
}

function coordinateSpace(candidateOrRegion) {
  const space = candidateOrRegion?.coordinate?.coordinateSpace
    || candidateOrRegion?.coordinateSpace
    || candidateOrRegion?.region?.coordinateSpace
    || {};
  return {
    unit: space.unit || null,
    origin: space.origin || null,
    pageBox: space.pageBox || null,
    rotationDegrees: space.rotationDegrees ?? null
  };
}

function pageBoxSignature(page) {
  return {
    pageIndex: page?.pageIndex ?? null,
    bounds: rectSignature(page?.bounds),
    cropBox: rectSignature(page?.cropBox),
    rotation: page?.rotation ?? null,
    coordinateSpace: {
      unit: "points",
      origin: "lowerLeft",
      pageBox: "crop",
      rotationDegrees: page?.rotation ?? null
    }
  };
}

function bucketCharacterCount(value) {
  if (!Number.isFinite(value)) return "unknown";
  if (value === 0) return "0";
  if (value < 100) return "1-99";
  if (value < 1000) return "100-999";
  if (value < 5000) return "1000-4999";
  return "5000+";
}

function bucketTextLength(value) {
  if (!Number.isFinite(value)) return "unknown";
  if (value === 0) return "0";
  if (value < 16) return "1-15";
  if (value < 64) return "16-63";
  if (value < 256) return "64-255";
  return "256+";
}

function fieldsFor(bundle) {
  return bundle?.document?.payload?.fields || [];
}

function candidatesFor(bundle) {
  return bundle?.document?.payload?.candidates || bundle?.candidates || [];
}

function pagesFor(bundle) {
  return bundle?.document?.payload?.pages || [];
}

function annotationCounts(bundle) {
  const payload = bundle?.document?.payload || {};
  return {
    total: pagesFor(bundle).reduce((total, page) => total + (page.annotationCount || 0), 0),
    byType: sortedEntries(payload.annotationTypeCounts || {})
  };
}

function navigationFingerprint(bundle) {
  const payload = bundle?.document?.payload || {};
  const links = payload.links || [];
  const outlines = payload.outlines || [];
  const flattenOutlines = (items) => items.flatMap((item) => [item, ...flattenOutlines(item.children || [])]);
  const flatOutlines = flattenOutlines(outlines);
  return {
    links: {
      count: links.length,
      kindCounts: countBy(links, (link) => link.kind || "unknown"),
      targetPageCount: links.filter((link) => link.targetPageIndex !== null && link.targetPageIndex !== undefined).length,
      externalSafeCount: links.filter((link) => link.isSafeExternal === true).length
    },
    outlines: {
      count: flatOutlines.length,
      maxDepth: flatOutlines.reduce((max, item) => Math.max(max, item.level || 0), 0)
    },
    attachments: {
      count: (payload.attachments || []).length
    }
  };
}

function permissionFingerprint(bundle) {
  const permissions = bundle?.document?.payload?.permissions;
  if (!permissions) return null;
  return Object.fromEntries(Object.entries(permissions)
    .filter(([key, value]) => typeof value === "boolean" || typeof value === "string" || typeof value === "number")
    .sort(([left], [right]) => left.localeCompare(right)));
}

function candidateFingerprint(candidates) {
  const evidence = candidates.flatMap((candidate) => candidate.evidenceItems || []);
  const labels = candidates.map((candidate) => candidate.labelText || "");
  const members = candidates.map((candidate) => candidate.groupMemberCount || 1);
  return {
    count: candidates.length,
    kindCounts: countBy(candidates, (candidate) => candidate.kind || "unknown"),
    suggestedFieldTypeCounts: countBy(candidates, (candidate) => candidate.suggestedFieldType || "unknown"),
    entryModeCounts: countBy(candidates, (candidate) => candidate.entryMode || "unknown"),
    statusCounts: countBy(candidates, (candidate) => candidate.status || "unknown"),
    groupMemberCountHistogram: histogram(members),
    evidenceKindCounts: countBy(evidence, (item) => item.kind || "unknown"),
    evidenceOriginCounts: countBy(evidence, (item) => item.origin || "unknown"),
    coordinateSpaceCounts: countBy(candidates, (candidate) => JSON.stringify(coordinateSpace(candidate))),
    labelAssociation: {
      presentCount: labels.filter(Boolean).length,
      absentCount: labels.filter((label) => !label).length,
      lengthBuckets: histogram(labels.filter(Boolean).map((label) => bucketTextLength(label.length)))
    },
    geometryByPage: candidates.reduce((result, candidate) => {
      const key = String(candidate.pageIndex ?? "unknown");
      result[key] = result[key] || [];
      result[key].push(rectSignature(candidate.bounds));
      return result;
    }, {})
  };
}

function fieldFingerprint(fields) {
  return {
    count: fields.length,
    kindCounts: countBy(fields, (field) => field.kind || "unknown"),
    choiceCardinality: histogram(fields.map((field) => (field.choices || []).length)),
    valuePresenceCount: fields.filter((field) => field.value !== null && field.value !== undefined && field.value !== "").length,
    geometryByPage: fields.reduce((result, field) => {
      const key = String(field.pageIndex ?? "unknown");
      result[key] = result[key] || [];
      result[key].push({ kind: field.kind || "unknown", bounds: rectSignature(field.bounds) });
      return result;
    }, {})
  };
}

function pageFingerprint(pages) {
  return {
    count: pages.length,
    boxes: pages.map(pageBoxSignature),
    rotationCounts: countBy(pages, (page) => page.rotation ?? "unknown"),
    selectableTextCounts: countBy(pages, (page) => Boolean(page.hasSelectableText)),
    characterCounts: pages.map((page) => page.characterCount ?? null),
    characterCountBuckets: histogram(pages.map((page) => bucketCharacterCount(page.characterCount))),
    annotationCounts: pages.map((page) => page.annotationCount ?? 0),
    textPageCount: pages.filter((page) => Boolean(page.hasSelectableText)).length
  };
}

/**
 * Create a privacy-minimized structural fingerprint from a provider bundle.
 * Source identity is retained only for binding. Provider representation facts
 * are deliberately not part of the structural fingerprint.
 */
export function buildStructuralFingerprint(bundle) {
  const payload = bundle?.document?.payload || {};
  const pages = pagesFor(bundle);
  const fields = fieldsFor(bundle);
  const candidates = candidatesFor(bundle);
  const source = payload.source || {};
  return {
    contract: FINGERPRINT_PARITY_CONTRACT.name,
    version: FINGERPRINT_PARITY_CONTRACT.version,
    status: bundle?.status || null,
    expectedFailure: Boolean(bundle?.expectedFailure),
    source: {
      sha256: source.sha256 || bundle?.sourceDigest || null,
      byteCount: source.byteCount ?? null
    },
    pages: pageFingerprint(pages),
    fields: fieldFingerprint(fields),
    candidates: candidateFingerprint(candidates),
    annotations: annotationCounts(bundle),
    navigation: navigationFingerprint(bundle),
    permissions: permissionFingerprint(bundle),
    security: payload.security ? {
      isEncrypted: Boolean(payload.security.isEncrypted),
      isLocked: Boolean(payload.security.isLocked),
      requiresPassword: Boolean(payload.security.requiresPassword)
    } : null,
    accessibility: payload.accessibility ? {
      hasTaggedContent: Boolean(payload.accessibility.hasTaggedContent),
      hasReadingOrder: Boolean(payload.accessibility.hasReadingOrder)
    } : null,
    warnings: {
      count: (payload.warnings || []).length
    }
  };
}

function deepEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function compareWithStatus(nativeValue, browserValue, status = "semantic-divergence") {
  if (deepEqual(nativeValue, browserValue)) {
    return { status: "agree", native: nativeValue, browser: browserValue };
  }
  return { status, native: nativeValue, browser: browserValue };
}

function compareCharacterCounts(nativeCounts, browserCounts) {
  if (deepEqual(nativeCounts, browserCounts)) {
    return { status: "agree", native: nativeCounts, browser: browserCounts, maxAbsoluteDelta: 0 };
  }
  const deltas = nativeCounts.map((value, index) => Math.abs((value || 0) - (browserCounts[index] || 0)));
  const maxAbsoluteDelta = Math.max(0, ...deltas);
  const semantic = nativeCounts.length === browserCounts.length && nativeCounts.every((value, index) => {
    const other = browserCounts[index];
    if (value === other) return true;
    const tolerance = Math.max(
      FINGERPRINT_PARITY_CONTRACT.textCharacterMinimumTolerance,
      Math.ceil(Math.abs(value || 0) * FINGERPRINT_PARITY_CONTRACT.textCharacterRelativeTolerance)
    );
    return Math.abs((value || 0) - (other || 0)) <= tolerance;
  });
  return {
    status: semantic ? "representation-difference" : "semantic-divergence",
    native: nativeCounts,
    browser: browserCounts,
    maxAbsoluteDelta
  };
}

function compareFeature(id, nativeFingerprint, browserFingerprint) {
  const nativeValue = id.split(".").reduce((value, key) => value?.[key], nativeFingerprint);
  const browserValue = id.split(".").reduce((value, key) => value?.[key], browserFingerprint);
  if (id === "pages.characterCounts") return { id, ...compareCharacterCounts(nativeValue || [], browserValue || []) };
  return { id, ...compareWithStatus(nativeValue, browserValue) };
}

export const STRUCTURAL_FEATURES = Object.freeze([
  "pages.count",
  "pages.boxes",
  "pages.rotationCounts",
  "pages.selectableTextCounts",
  "pages.characterCounts",
  "pages.characterCountBuckets",
  "pages.annotationCounts",
  "fields.count",
  "fields.kindCounts",
  "fields.choiceCardinality",
  "fields.geometryByPage",
  "candidates.count",
  "candidates.kindCounts",
  "candidates.suggestedFieldTypeCounts",
  "candidates.entryModeCounts",
  "candidates.groupMemberCountHistogram",
  "candidates.evidenceKindCounts",
  "candidates.evidenceOriginCounts",
  "candidates.coordinateSpaceCounts",
  "candidates.labelAssociation",
  "candidates.geometryByPage",
  "annotations",
  "navigation",
  "permissions",
  "security",
  "accessibility"
]);

export function compareStructuralFingerprints(nativeFingerprint, browserFingerprint) {
  const features = STRUCTURAL_FEATURES.map((id) => compareFeature(id, nativeFingerprint, browserFingerprint));
  const sourceDigestEqual = nativeFingerprint?.source?.sha256 === browserFingerprint?.source?.sha256;
  const sourceByteCountEqual = nativeFingerprint?.source?.byteCount === browserFingerprint?.source?.byteCount;
  const featureDivergences = features.filter((feature) => feature.status !== "agree");
  const hasSemanticDivergence = featureDivergences.some((feature) => feature.status === "semantic-divergence");
  const hasRepresentationDifference = featureDivergences.some((feature) => feature.status === "representation-difference");
  return {
    sourceBinding: {
      digestEqual: sourceDigestEqual,
      byteCountEqual: sourceByteCountEqual
    },
    status: hasSemanticDivergence && hasRepresentationDifference
      ? "mixed-divergence"
      : hasSemanticDivergence
        ? "semantic-divergence"
        : hasRepresentationDifference ? "representation-difference" : "equal",
    features,
    divergentFeatureIDs: featureDivergences.map((feature) => feature.id),
    semanticDivergenceFeatureIDs: featureDivergences
      .filter((feature) => feature.status === "semantic-divergence")
      .map((feature) => feature.id),
    representationDifferenceFeatureIDs: featureDivergences
      .filter((feature) => feature.status === "representation-difference")
      .map((feature) => feature.id)
  };
}

export function fingerprintReportForBundles({ sourcePath, nativeBundle, browserBundle }) {
  const native = buildStructuralFingerprint(nativeBundle);
  const browser = buildStructuralFingerprint(browserBundle);
  return {
    sourcePath,
    sourceDigest: native.source.sha256 || browser.source.sha256 || null,
    expectedFailure: Boolean(nativeBundle?.expectedFailure || browserBundle?.expectedFailure),
    native,
    browser,
    comparison: compareStructuralFingerprints(native, browser)
  };
}
