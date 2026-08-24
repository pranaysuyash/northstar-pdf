/*
 * Reviewed template-matching fixtures.
 *
 * These are value-free structural records. The corpus paths below identify the
 * source family used when the review decision was made, while the fingerprint
 * tokens remain keyed placeholders and never contain document labels.
 */

const page = ({
  widthPoints = 600,
  heightPoints = 800,
  nativeFieldKinds = ["text", "choice"],
  nativeFieldNameTokens = ["hmac:field-name", "hmac:field-date"],
  anchorTokens = ["hmac:anchor-applicant", "hmac:anchor-date"],
  regionSignatures = [
    {
      kind: "textAnchored",
      suggestedFieldType: "text",
      normalizedRect: { x: 0.15, y: 0.70, width: 0.40, height: 0.03 },
      anchorToken: "hmac:anchor-applicant",
      groupMemberCount: 1
    },
    {
      kind: "checkboxShape",
      suggestedFieldType: "checkbox",
      normalizedRect: { x: 0.70, y: 0.70, width: 0.03, height: 0.03 },
      anchorToken: "hmac:anchor-date",
      groupMemberCount: 1
    }
  ]
} = {}) => ({
  pageIndex: 0,
  widthPoints,
  heightPoints,
  rotationDegrees: 0,
  nativeFieldKinds,
  nativeFieldNameTokens,
  anchorTokens,
  regionSignatures
});

const fingerprint = ({
  layoutFingerprint,
  exactSourceDigests = [],
  ...pageOptions
}) => ({
  algorithm: "layout-v1+hmac-sha256",
  keyScope: "review-benchmark-workspace",
  featureVersion: "layout-features-1",
  layoutFingerprint,
  exactSourceDigests,
  pageSignatures: [page(pageOptions)]
});

const template = (templateID, layout) => ({
  header: {
    contractName: "pdf-editor.template",
    version: { major: 1, minor: 0 },
    templateDigest: layout.layoutFingerprint,
    generatedAt: "2026-08-24T00:00:00.000Z",
    provider: { id: "reviewed-template-benchmark", version: "1", platform: "shared", capabilities: [] }
  },
  payload: {
    templateID,
    revisionID: `${templateID}-revision-1`,
    parentRevisionID: null,
    displayName: `Reviewed fixture ${templateID}`,
    lifecycle: "active",
    privacyMode: "localMinimized",
    fingerprint: layout,
    mappings: [],
    reviewPolicy: {
      defaultMappingPolicy: "alwaysReviewMappingAndValue",
      requireValueReview: true,
      allowBatchMappingApproval: false
    }
  }
});

const base = fingerprint({
  layoutFingerprint: "hmac:layout-base",
  exactSourceDigests: ["sha256:corpus-public-sample"]
});

const knownVariantInput = fingerprint({
  layoutFingerprint: "hmac:layout-base"
});

const familyInput = fingerprint({
  layoutFingerprint: "hmac:layout-family-drift",
  widthPoints: 601,
  heightPoints: 799,
  regionSignatures: [
    {
      kind: "textAnchored",
      suggestedFieldType: "text",
      normalizedRect: { x: 0.152, y: 0.698, width: 0.399, height: 0.031 },
      anchorToken: "hmac:anchor-applicant",
      groupMemberCount: 1
    },
    {
      kind: "checkboxShape",
      suggestedFieldType: "checkbox",
      normalizedRect: { x: 0.701, y: 0.700, width: 0.030, height: 0.030 },
      anchorToken: "hmac:anchor-date",
      groupMemberCount: 1
    }
  ]
});

const ambiguousInput = fingerprint({
  layoutFingerprint: "hmac:layout-ambiguous-input"
});

const ambiguousTemplateA = fingerprint({ layoutFingerprint: "hmac:layout-ambiguous-a" });
const ambiguousTemplateB = fingerprint({ layoutFingerprint: "hmac:layout-ambiguous-b" });

const nearFamilyNegative = fingerprint({
  layoutFingerprint: "hmac:layout-near-negative",
  nativeFieldKinds: ["signature"],
  nativeFieldNameTokens: ["hmac:field-signature"],
  anchorTokens: ["hmac:anchor-signature"],
  regionSignatures: [
    {
      kind: "signatureLine",
      suggestedFieldType: "signature",
      normalizedRect: { x: 0.15, y: 0.70, width: 0.40, height: 0.03 },
      anchorToken: "hmac:anchor-signature",
      groupMemberCount: 1
    },
    {
      kind: "checkboxShape",
      suggestedFieldType: "checkbox",
      normalizedRect: { x: 0.70, y: 0.70, width: 0.03, height: 0.03 },
      anchorToken: "hmac:anchor-other",
      groupMemberCount: 1
    }
  ]
});

const unrelatedInput = fingerprint({
  layoutFingerprint: "hmac:layout-unrelated",
  widthPoints: 612,
  heightPoints: 1008,
  nativeFieldKinds: ["signature"],
  nativeFieldNameTokens: ["hmac:field-signature"],
  anchorTokens: ["hmac:anchor-unrelated"],
  regionSignatures: [
    {
      kind: "signatureLine",
      suggestedFieldType: "signature",
      normalizedRect: { x: 0.10, y: 0.20, width: 0.70, height: 0.05 },
      anchorToken: "hmac:anchor-unrelated",
      groupMemberCount: 1
    }
  ]
});

export const REVIEWED_TEMPLATE_FIXTURES = [
  {
    id: "exact-public-sample",
    label: "Exact source digest match",
    source: "benchmark/results/public-sample-form.pdf",
    review: "two reviewers accepted the source digest and mapping set",
    input: {
      templates: [template("template-public-sample", base)],
      fingerprint: base,
      sourceDigest: "sha256:corpus-public-sample"
    },
    expected: {
      state: "exact",
      selectedTemplateID: "template-public-sample"
    }
  },
  {
    id: "known-variant-public-sample",
    label: "Known layout with a different source digest",
    source: "benchmark/results/2026-08-23-public-acroform/noop.pdf",
    review: "same keyed layout reviewed as a source variant; values still require review",
    input: {
      templates: [template("template-public-sample", base)],
      fingerprint: knownVariantInput,
      sourceDigest: "sha256:corpus-public-sample-noop"
    },
    expected: {
      state: "knownVariant",
      selectedTemplateID: "template-public-sample"
    }
  },
  {
    id: "family-form6-drift",
    label: "Structural family with bounded geometry drift",
    source: "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf",
    review: "same reviewed field and region structure with small page and box drift",
    input: {
      templates: [template("template-public-sample", base)],
      fingerprint: familyInput,
      sourceDigest: "sha256:corpus-form6-family"
    },
    expected: {
      state: "familyMatch",
      selectedTemplateID: "template-public-sample"
    }
  },
  {
    id: "ambiguous-family-choice",
    label: "Two equally scored family candidates",
    source: "benchmark/results/public-sample-form.pdf",
    review: "reviewers withheld template selection because both families had equal evidence",
    input: {
      templates: [
        template("template-family-a", ambiguousTemplateA),
        template("template-family-b", ambiguousTemplateB)
      ],
      fingerprint: ambiguousInput,
      sourceDigest: "sha256:corpus-ambiguous"
    },
    expected: {
      state: "ambiguous",
      mustNotSelect: true,
      forbiddenStates: ["exact", "knownVariant", "familyMatch"]
    }
  },
  {
    id: "stale-source-session",
    label: "Stale source digest refuses replay",
    source: "benchmark/results/2026-08-23-public-acroform/noop.pdf",
    review: "the session was reviewed against the public source, then input bytes changed",
    input: {
      templates: [template("template-public-sample", base)],
      fingerprint: base,
      sourceDigest: "sha256:corpus-public-sample-noop",
      expectedSourceDigest: "sha256:corpus-public-sample"
    },
    expected: {
      state: "stale",
      mustNotSelect: true,
      forbiddenStates: ["exact", "knownVariant", "familyMatch"]
    }
  },
  {
    id: "near-family-negative",
    label: "Near-family false positive is rejected",
    source: "benchmark/results/2026-08-23-pdfkit-widgets/native-widgets.pdf",
    review: "same page geometry but incompatible field, anchor, and region semantics",
    input: {
      templates: [template("template-public-sample", base)],
      fingerprint: nearFamilyNegative,
      sourceDigest: "sha256:corpus-widgets-negative"
    },
    expected: {
      state: "noMatch",
      mustNotSelect: true,
      forbiddenStates: ["exact", "knownVariant", "familyMatch"]
    }
  },
  {
    id: "unrelated-corpus-negative",
    label: "Unrelated corpus shape is rejected",
    source: "benchmark/results/security-corpus/repeated-20-pages.pdf",
    review: "page count, geometry, field sequence, and regions are incompatible",
    input: {
      templates: [template("template-public-sample", base)],
      fingerprint: unrelatedInput,
      sourceDigest: "sha256:corpus-repeated-pages"
    },
    expected: {
      state: "noMatch",
      mustNotSelect: true,
      forbiddenStates: ["exact", "knownVariant", "familyMatch"]
    }
  }
];

export const REVIEWED_TEMPLATE_BENCHMARK_METADATA = Object.freeze({
  corpus: [
    "benchmark/results/public-sample-form.pdf",
    "benchmark/results/2026-08-23-public-acroform/noop.pdf",
    "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf",
    "benchmark/results/2026-08-23-pdfkit-widgets/native-widgets.pdf",
    "benchmark/results/security-corpus/repeated-20-pages.pdf"
  ],
  privacy: "Fingerprints contain keyed tokens and geometry only. No labels, values, source bytes, or screenshots are embedded.",
  reviewPolicy: "A benchmark case is accepted only when its expected state and selection or abstention decision are explicit."
});
