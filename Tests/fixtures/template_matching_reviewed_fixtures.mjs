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
  rotationDegrees = 0,
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
  rotationDegrees,
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

const reviewerLabel = (decision, evidence) => ({
  decision,
  reviewer: "corpus-curator",
  reviewedAt: "2026-08-24",
  evidence,
  independentAgreement: "not-measured"
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

const classCorpusDefinitions = [
  {
    documentClass: "publicAcroForm",
    source: "benchmark/results/public-sample-form.pdf",
    templateID: "template-class-public-acroform",
    templateLayout: fingerprint({
      layoutFingerprint: "hmac:class-public-acroform-template",
      nativeFieldKinds: ["text", "choice"],
      nativeFieldNameTokens: ["hmac:public-name", "hmac:public-date"],
      anchorTokens: ["hmac:public-name", "hmac:public-date"]
    }),
    positiveLayout: fingerprint({
      layoutFingerprint: "hmac:class-public-acroform-family",
      widthPoints: 601,
      heightPoints: 799,
      nativeFieldNameTokens: ["hmac:public-name", "hmac:public-date-v2"],
      anchorTokens: ["hmac:public-name", "hmac:public-date"]
    }),
    negativeLayout: fingerprint({
      layoutFingerprint: "hmac:class-public-acroform-negative",
      nativeFieldKinds: ["signature", "choice"],
      nativeFieldNameTokens: ["hmac:signature", "hmac:public-date"],
      anchorTokens: ["hmac:signature", "hmac:public-date"]
    }),
    ambiguousLayout: fingerprint({
      layoutFingerprint: "hmac:class-public-acroform-ambiguous-input",
      nativeFieldKinds: ["text", "choice"],
      nativeFieldNameTokens: ["hmac:public-name", "hmac:public-date"],
      anchorTokens: ["hmac:public-name", "hmac:public-date"]
    }),
    ambiguousTemplates: [
      fingerprint({
        layoutFingerprint: "hmac:class-public-acroform-ambiguous-a",
        nativeFieldKinds: ["text", "choice"],
        nativeFieldNameTokens: ["hmac:public-name", "hmac:public-date"],
        anchorTokens: ["hmac:public-name", "hmac:public-date"]
      }),
      fingerprint({
        layoutFingerprint: "hmac:class-public-acroform-ambiguous-b",
        nativeFieldKinds: ["text", "choice"],
        nativeFieldNameTokens: ["hmac:public-name", "hmac:public-date"],
        anchorTokens: ["hmac:public-name", "hmac:public-date"]
      })
    ]
  },
  {
    documentClass: "staticPrintedForm",
    source: "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf",
    templateID: "template-class-static-printed",
    templateLayout: fingerprint({
      layoutFingerprint: "hmac:class-static-printed-template",
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:printed-name", "hmac:printed-date"]
    }),
    positiveLayout: fingerprint({
      layoutFingerprint: "hmac:class-static-printed-family",
      widthPoints: 601,
      heightPoints: 799,
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:printed-name", "hmac:printed-date"]
    }),
    negativeLayout: fingerprint({
      layoutFingerprint: "hmac:class-static-printed-negative",
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:printed-signature", "hmac:printed-other"],
      regionSignatures: nearFamilyNegative.pageSignatures[0].regionSignatures
    }),
    ambiguousLayout: fingerprint({
      layoutFingerprint: "hmac:class-static-printed-ambiguous-input",
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:printed-name", "hmac:printed-date"]
    }),
    ambiguousTemplates: [
      fingerprint({
        layoutFingerprint: "hmac:class-static-printed-ambiguous-a",
        nativeFieldKinds: [],
        nativeFieldNameTokens: [],
        anchorTokens: ["hmac:printed-name", "hmac:printed-date"]
      }),
      fingerprint({
        layoutFingerprint: "hmac:class-static-printed-ambiguous-b",
        nativeFieldKinds: [],
        nativeFieldNameTokens: [],
        anchorTokens: ["hmac:printed-name", "hmac:printed-date"]
      })
    ]
  },
  {
    documentClass: "nativeWidget",
    source: "benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf",
    templateID: "template-class-native-widget",
    templateLayout: fingerprint({
      layoutFingerprint: "hmac:class-native-widget-template",
      nativeFieldKinds: ["text", "checkbox", "radio"],
      nativeFieldNameTokens: ["hmac:widget-name", "hmac:widget-check", "hmac:widget-choice"],
      anchorTokens: ["hmac:widget-name", "hmac:widget-choice"]
    }),
    positiveLayout: fingerprint({
      layoutFingerprint: "hmac:class-native-widget-family",
      widthPoints: 600,
      heightPoints: 801,
      nativeFieldKinds: ["text", "checkbox", "radio"],
      nativeFieldNameTokens: ["hmac:widget-name-v2", "hmac:widget-check", "hmac:widget-choice"],
      anchorTokens: ["hmac:widget-name", "hmac:widget-choice"]
    }),
    negativeLayout: fingerprint({
      layoutFingerprint: "hmac:class-native-widget-negative",
      nativeFieldKinds: ["text", "signature", "radio"],
      nativeFieldNameTokens: ["hmac:widget-name", "hmac:widget-signature", "hmac:widget-choice"],
      anchorTokens: ["hmac:widget-signature", "hmac:widget-choice"]
    }),
    ambiguousLayout: fingerprint({
      layoutFingerprint: "hmac:class-native-widget-ambiguous-input",
      nativeFieldKinds: ["text", "checkbox", "radio"],
      nativeFieldNameTokens: ["hmac:widget-name", "hmac:widget-check", "hmac:widget-choice"],
      anchorTokens: ["hmac:widget-name", "hmac:widget-choice"]
    }),
    ambiguousTemplates: [
      fingerprint({
        layoutFingerprint: "hmac:class-native-widget-ambiguous-a",
        nativeFieldKinds: ["text", "checkbox", "radio"],
        nativeFieldNameTokens: ["hmac:widget-name", "hmac:widget-check", "hmac:widget-choice"],
        anchorTokens: ["hmac:widget-name", "hmac:widget-choice"]
      }),
      fingerprint({
        layoutFingerprint: "hmac:class-native-widget-ambiguous-b",
        nativeFieldKinds: ["text", "checkbox", "radio"],
        nativeFieldNameTokens: ["hmac:widget-name", "hmac:widget-check", "hmac:widget-choice"],
        anchorTokens: ["hmac:widget-name", "hmac:widget-choice"]
      })
    ]
  },
  {
    documentClass: "rotatedStaticForm",
    source: "benchmark/results/rotation-corpus/rotated-form6-mixed.pdf",
    templateID: "template-class-rotated-static",
    templateLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-static-template",
      rotationDegrees: 90,
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:rotated-name", "hmac:rotated-date"]
    }),
    positiveLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-static-family",
      widthPoints: 601,
      heightPoints: 799,
      rotationDegrees: 90,
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:rotated-name", "hmac:rotated-date"]
    }),
    negativeLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-static-negative",
      widthPoints: 612,
      heightPoints: 1008,
      rotationDegrees: 90,
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:rotated-signature"],
      regionSignatures: unrelatedInput.pageSignatures[0].regionSignatures
    }),
    ambiguousLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-static-ambiguous-input",
      rotationDegrees: 90,
      nativeFieldKinds: [],
      nativeFieldNameTokens: [],
      anchorTokens: ["hmac:rotated-name", "hmac:rotated-date"]
    }),
    ambiguousTemplates: [
      fingerprint({
        layoutFingerprint: "hmac:class-rotated-static-ambiguous-a",
        rotationDegrees: 90,
        nativeFieldKinds: [],
        nativeFieldNameTokens: [],
        anchorTokens: ["hmac:rotated-name", "hmac:rotated-date"]
      }),
      fingerprint({
        layoutFingerprint: "hmac:class-rotated-static-ambiguous-b",
        rotationDegrees: 90,
        nativeFieldKinds: [],
        nativeFieldNameTokens: [],
        anchorTokens: ["hmac:rotated-name", "hmac:rotated-date"]
      })
    ]
  },
  {
    documentClass: "rotatedNativeWidget",
    source: "benchmark/results/rotation-corpus/rotated-widget-90.pdf",
    templateID: "template-class-rotated-widget",
    templateLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-widget-template",
      rotationDegrees: 90,
      nativeFieldKinds: ["text", "checkbox", "radio"],
      nativeFieldNameTokens: ["hmac:rotwidget-name", "hmac:rotwidget-check", "hmac:rotwidget-choice"],
      anchorTokens: ["hmac:rotwidget-name", "hmac:rotwidget-choice"]
    }),
    positiveLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-widget-family",
      widthPoints: 599,
      heightPoints: 802,
      rotationDegrees: 90,
      nativeFieldKinds: ["text", "checkbox", "radio"],
      nativeFieldNameTokens: ["hmac:rotwidget-name", "hmac:rotwidget-check-v2", "hmac:rotwidget-choice"],
      anchorTokens: ["hmac:rotwidget-name", "hmac:rotwidget-choice"]
    }),
    negativeLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-widget-negative",
      rotationDegrees: 90,
      nativeFieldKinds: ["text", "signature", "radio"],
      nativeFieldNameTokens: ["hmac:rotwidget-name", "hmac:rotwidget-signature", "hmac:rotwidget-choice"],
      anchorTokens: ["hmac:rotwidget-signature", "hmac:rotwidget-choice"]
    }),
    ambiguousLayout: fingerprint({
      layoutFingerprint: "hmac:class-rotated-widget-ambiguous-input",
      rotationDegrees: 90,
      nativeFieldKinds: ["text", "checkbox", "radio"],
      nativeFieldNameTokens: ["hmac:rotwidget-name", "hmac:rotwidget-check", "hmac:rotwidget-choice"],
      anchorTokens: ["hmac:rotwidget-name", "hmac:rotwidget-choice"]
    }),
    ambiguousTemplates: [
      fingerprint({
        layoutFingerprint: "hmac:class-rotated-widget-ambiguous-a",
        rotationDegrees: 90,
        nativeFieldKinds: ["text", "checkbox", "radio"],
        nativeFieldNameTokens: ["hmac:rotwidget-name", "hmac:rotwidget-check", "hmac:rotwidget-choice"],
        anchorTokens: ["hmac:rotwidget-name", "hmac:rotwidget-choice"]
      }),
      fingerprint({
        layoutFingerprint: "hmac:class-rotated-widget-ambiguous-b",
        rotationDegrees: 90,
        nativeFieldKinds: ["text", "checkbox", "radio"],
        nativeFieldNameTokens: ["hmac:rotwidget-name", "hmac:rotwidget-check", "hmac:rotwidget-choice"],
        anchorTokens: ["hmac:rotwidget-name", "hmac:rotwidget-choice"]
      })
    ]
  }
];

const classCorpusFixtures = classCorpusDefinitions.flatMap((definition) => {
  const prefix = definition.documentClass.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);
  const familyTemplate = template(definition.templateID, definition.templateLayout);
  const familyCase = {
    id: `${prefix}-family-positive`,
    label: `${definition.documentClass} reviewed family positive`,
    documentClass: definition.documentClass,
    source: definition.source,
    review: "curator accepted bounded structural drift as the same document family",
    reviewLabel: reviewerLabel("family-positive", "value-free geometry and keyed structural evidence"),
    input: {
      templates: [familyTemplate],
      fingerprint: definition.positiveLayout,
      sourceDigest: `sha256:${prefix}-family-source`
    },
    expected: {
      state: "familyMatch",
      selectedTemplateID: definition.templateID
    }
  };
  const negativeCase = {
    id: `${prefix}-hard-negative`,
    label: `${definition.documentClass} reviewed hard negative`,
    documentClass: definition.documentClass,
    source: definition.source,
    review: "curator rejected the visually or geometrically nearby candidate as a different family",
    reviewLabel: reviewerLabel("hard-negative", "incompatible field, anchor, region, or page evidence"),
    input: {
      templates: [familyTemplate],
      fingerprint: definition.negativeLayout,
      sourceDigest: `sha256:${prefix}-negative-source`
    },
    expected: {
      state: "noMatch",
      mustNotSelect: true,
      forbiddenStates: ["exact", "knownVariant", "familyMatch"]
    }
  };
  const ambiguousCase = {
    id: `${prefix}-ambiguous`,
    label: `${definition.documentClass} reviewed ambiguous candidates`,
    documentClass: definition.documentClass,
    source: definition.source,
    review: "curator withheld selection because the top family candidates had equivalent evidence",
    reviewLabel: reviewerLabel("ambiguous", "equivalent value-free structural evidence"),
    input: {
      templates: definition.ambiguousTemplates.map((layout, index) =>
        template(`${definition.templateID}-ambiguous-${index + 1}`, layout)
      ),
      fingerprint: definition.ambiguousLayout,
      sourceDigest: `sha256:${prefix}-ambiguous-source`
    },
    expected: {
      state: "ambiguous",
      mustNotSelect: true,
      forbiddenStates: ["exact", "knownVariant", "familyMatch"]
    }
  };
  return [familyCase, negativeCase, ambiguousCase];
});

const scannedTemplateLayout = fingerprint({
  layoutFingerprint: "hmac:class-scanned-template",
  exactSourceDigests: ["sha256:corpus-printed-scan"],
  nativeFieldKinds: [],
  nativeFieldNameTokens: [],
  anchorTokens: [],
  regionSignatures: []
});
const scannedVariantLayout = fingerprint({
  layoutFingerprint: "hmac:class-scanned-template",
  nativeFieldKinds: [],
  nativeFieldNameTokens: [],
  anchorTokens: [],
  regionSignatures: []
});
const scannedTemplate = template("template-class-scanned", scannedTemplateLayout);
const scannedDocumentFixtures = [
  {
    id: "scanned-exact-source",
    label: "Scanned document exact digest match",
    documentClass: "scannedDocument",
    source: "benchmark/results/ocr-corpus/printed-scan.pdf",
    review: "curator accepted exact source identity while keeping family matching disabled",
    reviewLabel: reviewerLabel("exact", "exact source digest with no family inference"),
    input: {
      templates: [scannedTemplate],
      fingerprint: scannedTemplateLayout,
      sourceDigest: "sha256:corpus-printed-scan"
    },
    expected: {
      state: "exact",
      selectedTemplateID: "template-class-scanned"
    }
  },
  {
    id: "scanned-known-variant",
    label: "Scanned document known layout variant",
    documentClass: "scannedDocument",
    source: "benchmark/results/ocr-corpus/printed-scan.pdf",
    review: "curator accepted a known layout variant without enabling family inference",
    reviewLabel: reviewerLabel("known-variant", "same keyed layout and distinct source digest"),
    input: {
      templates: [scannedTemplate],
      fingerprint: scannedVariantLayout,
      sourceDigest: "sha256:corpus-printed-scan-variant"
    },
    expected: {
      state: "knownVariant",
      selectedTemplateID: "template-class-scanned"
    }
  }
];

export const REVIEWED_TEMPLATE_FIXTURES = [
  {
    id: "exact-public-sample",
    label: "Exact source digest match",
    documentClass: "publicAcroForm",
    source: "benchmark/results/public-sample-form.pdf",
    review: "curator accepted the source digest and mapping set",
    reviewLabel: reviewerLabel("exact", "exact source digest and reviewed mapping identity"),
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
    documentClass: "publicAcroForm",
    source: "benchmark/results/2026-08-23-public-acroform/noop.pdf",
    review: "same keyed layout reviewed as a source variant; values still require review",
    reviewLabel: reviewerLabel("known-variant", "same keyed layout with a distinct source digest"),
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
    documentClass: "staticPrintedForm",
    source: "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf",
    review: "same reviewed field and region structure with small page and box drift",
    reviewLabel: reviewerLabel("family-positive", "bounded geometry drift and matching keyed structure"),
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
    documentClass: "staticPrintedForm",
    source: "benchmark/results/public-sample-form.pdf",
    review: "curator withheld template selection because both families had equal evidence",
    reviewLabel: reviewerLabel("ambiguous", "equal structural evidence between reviewed candidates"),
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
    documentClass: "publicAcroForm",
    source: "benchmark/results/2026-08-23-public-acroform/noop.pdf",
    review: "the session was reviewed against the public source, then input bytes changed",
    reviewLabel: reviewerLabel("stale", "session digest differs from current source digest"),
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
    documentClass: "staticPrintedForm",
    source: "benchmark/results/2026-08-23-pdfkit-widgets/native-widgets.pdf",
    review: "same page geometry but incompatible field, anchor, and region semantics",
    reviewLabel: reviewerLabel("hard-negative", "same geometry with incompatible semantic evidence"),
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
    documentClass: "scannedDocument",
    source: "benchmark/results/security-corpus/repeated-20-pages.pdf",
    review: "page count, geometry, field sequence, and regions are incompatible",
    reviewLabel: reviewerLabel("hard-negative", "incompatible page count, geometry, and region evidence"),
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
  },
  ...scannedDocumentFixtures,
  ...classCorpusFixtures
];

export const REVIEWED_TEMPLATE_BENCHMARK_METADATA = Object.freeze({
  corpus: [
    "benchmark/results/public-sample-form.pdf",
    "benchmark/results/2026-08-23-public-acroform/noop.pdf",
    "docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf",
    "benchmark/results/2026-08-23-pdfkit-widgets/native-widgets.pdf",
    "benchmark/results/security-corpus/repeated-20-pages.pdf",
    "benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf",
    "benchmark/results/rotation-corpus/rotated-form6-mixed.pdf",
    "benchmark/results/rotation-corpus/rotated-widget-90.pdf",
    "benchmark/results/ocr-corpus/printed-scan.pdf"
  ],
  privacy: "Fingerprints contain keyed tokens and geometry only. No labels, values, source bytes, or screenshots are embedded.",
  reviewPolicy: "A benchmark case is accepted only when its document class, reviewer label, expected state, and selection or abstention decision are explicit.",
  reviewer: "corpus-curator",
  independentAgreement: "not-measured",
  calibration: "Class thresholds are derived only from this value-free reviewed corpus. A class without separable positive and hard-negative evidence disables family acceptance."
});
