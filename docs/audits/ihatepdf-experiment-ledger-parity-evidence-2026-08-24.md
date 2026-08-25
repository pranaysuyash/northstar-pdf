# ihatepdf-Inspired Experiment Ledger and Native/Web Semantic Parity

**Date:** 2026-08-24  
**Status:** Implemented as versioned evidence and parity contracts; capability
execution remains queued per experiment  
**Evidence tier:** Tier 2/S1 deterministic native and Node checks plus Tier 3/S1
isolated Chrome contract execution; mutation sensitivity S3 for four ledger
invariants  
**Scope:** E-001 through E-006 from the ihatepdf.cv exploration record

## Outcome

The six competitor-inspired experiments are now represented as one canonical,
versioned machine-readable ledger and six linked semantic parity cases. The
native Swift and browser lanes independently project the same records and agree
with zero semantic mismatches.

This closes the evidence-definition and contract-parity step. It does not claim
that arbitrary text replacement, OCR layer creation, privacy sanitization,
repair, adaptive browser limits, or complete impact mapping is implemented or
production-ready.

## Canonical artifacts

| Artifact | Role |
| --- | --- |
| `Tests/fixtures/ihatepdf_experiment_ledger.json` | Canonical ledger, schema version 1.0, six entries, six linked cases |
| `web/ihatepdf-experiment-contract.mjs` | Browser validator and semantic projection |
| `Sources/PDFExperimentParityHarness/main.swift` | Independent Swift decoder, source hashing, and native projection |
| `Tests/ihatepdf_experiment_parity_test.mjs` | Node orchestration, mutation checks, isolated Chrome run, and comparison |
| `benchmark/results/ihatepdf-experiments/2026-08-24-native-parity.json` | Native projection with current source digests |
| `benchmark/results/ihatepdf-experiments/2026-08-24-browser-parity.json` | Browser projection with current source digests |
| `benchmark/results/ihatepdf-experiments/2026-08-24-semantic-parity-report.json` | Native/browser result and mutation summary |

The ledger points back to
[`docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`](../competitor-ihatepdf-cv-exploration-2026-08-24.md),
which remains the source of the competitor observations and claim boundaries.

## Ledger shape

Every experiment entry contains:

- stable ID and independent entry version;
- source URL references and the local source fixture;
- provenance and license status, owner, truth status, corpus class, operation
  kind, and privacy class;
- canonical page-space coordinate policy;
- review, confirmation, silent-mutation, and unsupported-state policy;
- validation check kinds;
- named hard negatives;
- falsifier and rollback path;
- linked semantic parity case.

The current ledger version is `{ major: 1, minor: 0 }`. The common coordinate
policy is PDF user space in points, lower-left origin, crop box, and zero page
rotation. Providers may use other internal coordinates, but the parity output
must project to this contract before comparison.

## Six entries

| ID | Experiment | Fixture class | Current status | Main safety question |
| --- | --- | --- | --- | --- |
| E-001 | Text-run replacement preservation | Digital text | Planned | Does replacing one reviewed run leave unrelated text and pixels unchanged? |
| E-002 | OCR layer alignment | Raster OCR | Planned | Are recognized words, bounds, confidence, and accessibility effects separable from field truth? |
| E-003 | Privacy preflight and sanitization | Metadata/security | Planned | Can the report distinguish detected, removed, retained, and unverified content? |
| E-004 | Repair and recovery | Malformed/recovery | Planned | Can a new recovered copy enumerate recovered and unrecovered content and reopen independently? |
| E-005 | Device-adaptive browser limits | Resource limit | Planned | Do memory and batching limits fail visibly and recoverably rather than silently degrading? |
| E-006 | Compare and operation impact map | Edited-output impact | Planned | Does the impact map identify intentional versus outside-region changes and unknown checks? |

The `planned` state is deliberate. It prevents a contract fixture from being
misread as execution evidence for a capability whose engine, corpus oracle, or
independent validator has not yet been built.

## Semantic parity contract

Each case emits:

- case and experiment identity;
- source fixture and current SHA-256 digest;
- typed operation intent;
- canonical coordinate space;
- planned execution state;
- source binding, review, and unsupported-state rules;
- privacy class;
- sorted validation obligations;
- ledger version;
- semantic projection of operation kind, source fixture, coordinate policy, and
  review policy.

The native harness uses its own Swift Codable model and CryptoKit hashing. The
browser lane uses its own JavaScript projection exposed through
`window.__pdfEditorContractFixture`. The test compares normalized semantic
records, not JSON key order or PDF bytes.

## Mutation evidence

The test deliberately mutates four independent invariants and requires each to
be rejected:

| Mutation | Rejected invariant | Result |
| --- | --- | --- |
| Remove E-001 falsifier | Evidence ledger must retain a falsifier | Killed |
| Change E-002 origin to upper-left | Coordinate policy must remain canonical | Killed |
| Remove E-003 source binding | Every semantic case must bind to source identity | Killed |
| Drift E-004 operation kind | Entry and parity case must describe the same intent | Killed |

This is contract-integrity evidence. It is not a substitute for mutating PDF
providers or running the six capability experiments.

## Verification

The focused command was run with a project-owned server on port 8183 because
the shared port 4173 was occupied by another project:

```text
swift build --product PDFExperimentParityHarness
PDF_PROOF_BASE_URL=http://127.0.0.1:8183/web/index.html \
  node Tests/ihatepdf_experiment_parity_test.mjs
```

Observed result:

```text
ledger version: 1.0
entries: 6
semantic parity cases: 6
native/browser mismatches: 0
ledger mutations killed: 4/4
browser console errors: 0
browser page errors: 0
```

The native projection resolved current source digests for the public form,
printed scan, truncated malformed input, and repeated-page resource fixture.
The malformed fixture is referenced as a future recovery input; this run did
not attempt to repair it.

## Remaining gates

The next implementation for each entry is separate and must retain this
ledger/case identity:

1. E-001 needs run-level font/glyph evidence, bounded replacement, and outside
   region text/raster validation.
2. E-002 needs OCR provider/model provenance, word-level calibration, multilingual
   and handwriting hard negatives, and searchable-layer/accessibility checks.
3. E-003 needs a privacy finding taxonomy, sanitization output contract,
   irreversible-action warning, and independent metadata/security checks.
4. E-004 needs multiple controlled corruption fixtures, partial-recovery
   accounting, and independent reopen evidence.
5. E-005 needs Safari/Chromium/Firefox and representative low-memory device
   measurements with cancellation and recovery evidence.
6. E-006 needs real edited outputs, independent text/raster/object comparison,
   rotated-page coverage, and explicit unknown-state handling.

No Ghostscript, Tesseract.js, Gemini, P2P signaling, service worker, or broad
converter suite was introduced by this work. The ledger is the admission point
for those future experiments, not approval to add them.
