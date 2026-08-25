/**
 * Provider-neutral native/browser semantic parity projection.
 *
 * This module compares emitted contract bundles, not PDF bytes. It removes
 * representation-only fields while retaining source identity, coordinates,
 * candidate evidence families, operation intent, and validation semantics.
 */

export const PARITY_CONTRACT = Object.freeze({
  name: "pdf-editor.native-web-semantic-parity",
  version: Object.freeze({ major: 1, minor: 1 }),
  geometryTolerancePoints: 0,
  characterCountRelativeTolerance: 0.05,
  characterCountMinimumTolerance: 16,
  normalizationPolicy: Object.freeze({
    purpose: "compare-provider-neutral-product-semantics-and-retain-representation-provenance",
    sourceIdentity: Object.freeze(["document.payload.source.sha256", "document.payload.source.fileName", "document.payload.source.byteCount"]),
    ignoredRepresentationFields: Object.freeze([
      "document.header.provider.id",
      "document.header.provider.version",
      "document.header.provider.platform",
      "document.header.generatedAt",
      "document.header.randomIDs",
      "document.header.diagnosticProse",
      "document.payload.fields[].id",
      "document.payload.candidates[].id",
      "document.payload.candidates[].evidenceItems[].id",
      "editSession.operations[].id",
      "validation.checks[].id",
      "validation.messages",
      "validation.operationIDs",
      "validation.outputDigest",
      "PDFBytes",
      "browserOnlyMetadata"
    ]),
    retainedAsProvenanceOnly: Object.freeze([
      "providerIdentity",
      "providerVersion",
      "generatedAtPresence",
      "outputDigestPresence",
      "outputDigestValue"
    ]),
    outputDigestComparison: "never-semantic-equality"
  }),
  ignoredFields: Object.freeze([
    "provider.id",
    "provider.version",
    "provider.platform",
    "generatedAt",
    "randomIDs",
    "diagnosticProse",
    "fieldIDs",
    "candidateIDs",
    "evidenceIDs",
    "operationIDs",
    "validation.checkIDs",
    "validation.messages",
    "validation.operationIDs",
    "outputDigests",
    "browserOnlyMetadata"
  ])
});

/**
 * Return representation facts for the report without making them part of
 * semantic equality. The digest value is deliberately not returned here so a
 * report cannot accidentally present it as a parity signal.
 */
export function representationFacts(bundle) {
  const provider = bundle?.document?.header?.provider || {};
  return {
    providerIdentityPresent: Boolean(provider.id),
    providerVersionPresent: Boolean(provider.version),
    generatedAtPresent: Boolean(bundle?.document?.header?.generatedAt),
    outputDigestPresent: Boolean(bundle?.validation?.outputDigest),
    outputDigestCompared: false
  };
}

function round(value, places = 2) {
  if (typeof value !== "number" || !Number.isFinite(value)) return value;
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function rectProjection(rect) {
  if (!rect) return null;
  return {
    x: round(rect.x),
    y: round(rect.y),
    width: round(rect.width),
    height: round(rect.height)
  };
}

function coordinateProjection(region) {
  if (!region) return null;
  const coordinateSpace = region.coordinateSpace || {};
  return {
    pageIndex: region.pageIndex,
    rect: rectProjection(region.rect),
    coordinateSpace: {
      unit: coordinateSpace.unit,
      origin: coordinateSpace.origin,
      pageBox: coordinateSpace.pageBox,
      rotationDegrees: coordinateSpace.rotationDegrees
    }
  };
}

function multiset(values) {
  return values.map((value) => JSON.stringify(value)).sort();
}

function fieldProjection(field) {
  return {
    pageIndex: field.pageIndex,
    name: field.name,
    kind: field.kind,
    bounds: rectProjection(field.bounds),
    valuePresent: Boolean(field.value),
    choices: [...(field.choices || [])].sort()
  };
}

function candidateProjection(candidate) {
  return {
    pageIndex: candidate.pageIndex,
    kind: candidate.kind,
    suggestedFieldType: candidate.suggestedFieldType || null,
    entryMode: candidate.entryMode || "unknown",
    groupMemberCount: candidate.groupMemberCount || 1,
    bounds: rectProjection(candidate.bounds),
    coordinate: coordinateProjection(candidate.coordinate),
    evidenceKinds: [...new Set((candidate.evidenceItems || []).map((item) => item.kind))].sort(),
    labelPresent: Boolean(candidate.labelText)
  };
}

function pageProjection(page) {
  return {
    pageIndex: page.pageIndex,
    bounds: rectProjection(page.bounds),
    rotation: page.rotation,
    characterCount: page.characterCount,
    annotationCount: page.annotationCount,
    hasSelectableText: page.hasSelectableText
  };
}

function linkProjection(link) {
  return {
    pageIndex: link.pageIndex,
    label: link.label || "",
    kind: link.kind || "unknown",
    targetPageIndex: link.targetPageIndex ?? null,
    destination: link.destination ?? null,
    destinationBounds: rectProjection(link.destinationBounds),
    isSafeExternal: Boolean(link.isSafeExternal)
  };
}

function outlineProjection(items) {
  return (items || []).map((item) => ({
    title: item.title || "",
    level: item.level || 0,
    destinationPageIndex: item.destinationPageIndex ?? null,
    children: outlineProjection(item.children)
  }));
}

function accessibilityProjection(value) {
  if (!value) return null;
  return {
    hasTaggedContent: Boolean(value.hasTaggedContent),
    hasReadingOrder: Boolean(value.hasReadingOrder)
  };
}

function validationProjection(validation) {
  if (!validation) return null;
  const checks = Object.fromEntries((validation.checks || [])
    .filter((check) => check.kind !== "providerCapability")
    .map((check) => [check.kind, check.status]));
  return {
    status: validation.status,
    sourceUnchanged: validation.sourceUnchanged,
    outputReopenable: validation.outputReopenable,
    checkKinds: Object.keys(checks).sort(),
    checkStatuses: checks
  };
}

/**
 * Produce the semantic projection used by both the corpus comparator and
 * mutation tests. The original provider bundles remain untouched on disk.
 */
export function normalizeContractBundle(bundle) {
  const document = bundle?.document;
  if (!document) {
    return {
      document: null,
      coordinates: null,
      operations: [],
      validation: validationProjection(bundle?.validation)
    };
  }

  const payload = document.payload || {};
  return {
    document: {
      source: {
        sha256: payload.source?.sha256 ?? null,
        fileName: payload.source?.fileName ?? null,
        byteCount: payload.source?.byteCount ?? null
      },
      pages: (payload.pages || []).map(pageProjection),
      fields: multiset((payload.fields || []).map(fieldProjection)),
      candidates: multiset((payload.candidates || []).map(candidateProjection)),
      candidateCount: (payload.candidates || []).length,
      metadata: {
        links: (payload.links || []).map(linkProjection),
        outlines: outlineProjection(payload.outlines),
        attachments: [...(payload.attachments || [])].sort(),
        accessibility: accessibilityProjection(payload.accessibility),
        security: payload.security ? {
          isEncrypted: Boolean(payload.security.isEncrypted),
          isLocked: Boolean(payload.security.isLocked),
          requiresPassword: Boolean(payload.security.requiresPassword)
        } : null
      }
    },
    coordinates: (bundle.coordinates?.pages || []).map((entry) => ({
      pageIndex: entry.pageIndex,
      region: coordinateProjection(entry.region)
    })),
    operations: (bundle.editSession?.operations || []).map((operation) => ({
      pageIndex: operation.pageIndex,
      kind: operation.kind,
      targetIDPresent: Boolean(operation.targetID),
      coordinate: coordinateProjection(operation.coordinate),
      sourceDigest: operation.sourceDigest
    })),
    validation: validationProjection(bundle.validation)
  };
}

function pushMismatch(mismatches, kind, path, nativeValue, webValue) {
  mismatches.push({ kind, path, native: nativeValue, web: webValue });
}

function compareValue(mismatches, kind, path, nativeValue, webValue) {
  if (JSON.stringify(nativeValue) !== JSON.stringify(webValue)) {
    pushMismatch(mismatches, kind, path, nativeValue, webValue);
  }
}

function comparePageCounts(mismatches, nativePages, webPages) {
  compareValue(mismatches, "page.count", "document.payload.pages.length", nativePages.length, webPages.length);
  const pageCount = Math.min(nativePages.length, webPages.length);
  for (let index = 0; index < pageCount; index += 1) {
    const nativePage = nativePages[index];
    const webPage = webPages[index];
    for (const key of ["bounds", "rotation", "hasSelectableText"]) {
      compareValue(
        mismatches,
        "page.geometry-or-text",
        `document.payload.pages[${index}].${key}`,
        nativePage[key],
        webPage[key]
      );
    }
    for (const key of ["characterCount", "annotationCount"]) {
      if (key === "characterCount") {
        const difference = Math.abs(nativePage[key] - webPage[key]);
        const tolerance = Math.max(
          PARITY_CONTRACT.characterCountMinimumTolerance,
          Math.ceil(Math.abs(nativePage[key]) * PARITY_CONTRACT.characterCountRelativeTolerance)
        );
        if (difference <= tolerance) continue;
      }
      compareValue(
        mismatches,
        "page.provider-count",
        `document.payload.pages[${index}].${key}`,
        nativePage[key],
        webPage[key]
      );
    }
  }
}

function compareValidation(mismatches, nativeValidation, webValidation) {
  if (Boolean(nativeValidation) !== Boolean(webValidation)) {
    pushMismatch(mismatches, "validation.presence", "validation", Boolean(nativeValidation), Boolean(webValidation));
    return;
  }
  if (!nativeValidation || !webValidation) return;
  for (const key of ["status", "sourceUnchanged", "outputReopenable"]) {
    compareValue(mismatches, "validation.status", `validation.${key}`, nativeValidation[key], webValidation[key]);
  }
  compareValue(mismatches, "validation.check-kinds", "validation.checks", nativeValidation.checkKinds, webValidation.checkKinds);
  for (const kind of new Set([...nativeValidation.checkKinds, ...webValidation.checkKinds])) {
    const nativeStatus = nativeValidation.checkStatuses[kind] || null;
    const webStatus = webValidation.checkStatuses[kind] || null;
    const equivalentSkippedState = kind === "nativeFields"
      && [nativeStatus, webStatus].every((status) => ["passed", "skipped"].includes(status));
    if (!equivalentSkippedState) {
      compareValue(mismatches, "validation.check-status", `validation.checks.${kind}.status`, nativeStatus, webStatus);
    }
  }
}

/**
 * Compare native and browser bundles after semantic normalization.
 * Provider and detector mismatches are returned for classification rather than
 * hidden. The caller decides which mismatch kinds are allowed for a fixture.
 */
export function compareNormalizedContractBundles(nativeBundle, webBundle) {
  const mismatches = [];
  const native = normalizeContractBundle(nativeBundle);
  const web = normalizeContractBundle(webBundle);
  if (!native.document || !web.document) {
    if (Boolean(native.document) !== Boolean(web.document)) {
      pushMismatch(mismatches, "document.presence", "document", Boolean(native.document), Boolean(web.document));
    }
    return mismatches;
  }

  compareValue(mismatches, "source.digest", "document.payload.source.sha256", native.document.source.sha256, web.document.source.sha256);
  compareValue(mismatches, "source.metadata", "document.payload.source", native.document.source, web.document.source);
  comparePageCounts(mismatches, native.document.pages, web.document.pages);
  compareValue(mismatches, "native-fields", "document.payload.fields", native.document.fields, web.document.fields);
  compareValue(mismatches, "candidate-semantic-set", "document.payload.candidates", native.document.candidates, web.document.candidates);
  compareValue(mismatches, "candidate.count", "document.payload.candidates.length", native.document.candidateCount, web.document.candidateCount);
  compareValue(mismatches, "coordinates", "coordinates.pages", native.coordinates, web.coordinates);
  compareValue(mismatches, "operation.lineage", "editSession.operations.length", native.operations.length, web.operations.length);
  if (native.operations.length || web.operations.length) {
    compareValue(mismatches, "operation.semantic-set", "editSession.operations", multiset(native.operations), multiset(web.operations));
  }
  compareValidation(mismatches, native.validation, web.validation);
  for (const key of ["links", "outlines", "attachments", "accessibility", "security"]) {
    compareValue(mismatches, `document.${key}`, `document.payload.${key}`, native.document.metadata[key], web.document.metadata[key]);
  }
  return mismatches;
}
