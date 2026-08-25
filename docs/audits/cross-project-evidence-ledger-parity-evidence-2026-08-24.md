# Cross-Project Evidence Ledger and Native/Web Parity Evidence

**Date:** 2026-08-24  
**Scope:** Cross-project document-intelligence evidence inventory and semantic parity over the existing PDF corpus  
**Status:** Implemented bounded evidence gate
**Owner:** PDF editor project

> Historical baseline notice: this report records the pre-expansion eleven-entry
> corpus exactly as measured on 2026-08-24. The authoritative current result is
> [`browser-corpus-fidelity-evidence-2026-08-25.md`](browser-corpus-fidelity-evidence-2026-08-25.md),
> which expands the same parity contract to 17 entries and records six
> classified mismatches with zero unexpected mismatches.

## Executive result

The project now has a versioned, machine-readable evidence ledger for six
locally relevant projects and a versioned native/web semantic parity fixture for
the eleven-entry PDF corpus. The combined harness passed:

| Check | Result |
| --- | --- |
| Cross-project ledger entries | 6 |
| Referenced source artifacts | 18 |
| PDF corpus cases | 11 |
| Native/browser parity mismatches | 4, all explicitly allowed detector mismatches |
| Unexpected parity mismatches | 0 |
| Expected malformed-input behavior | Native and browser inspection both failed for the truncated fixture |
| Ledger and fixture validity | Pass |
| Live source-identity drift | 1, preserved for review |

The passing result means the evidence definitions, source binding, fixture
membership, native/browser semantic projection, and mismatch policy are
consistent. It does not mean that neighboring runtime code has been imported,
that all PDF providers have equivalent fidelity, or that the four candidate
detection mismatches are resolved.

## Artifacts

- [`Tests/fixtures/cross_project_evidence_ledger.json`](../../Tests/fixtures/cross_project_evidence_ledger.json)
  is the canonical cross-project ledger.
- [`Tests/fixtures/pdf_corpus_semantic_parity_fixture.json`](../../Tests/fixtures/pdf_corpus_semantic_parity_fixture.json)
  is the canonical eleven-case native/web semantic fixture.
- [`Tests/cross_project_evidence_ledger_parity_test.mjs`](../../Tests/cross_project_evidence_ledger_parity_test.mjs)
  validates both contracts, verifies source files, starts an isolated
  project-owned browser server, invokes the native/browser parity runner, and
  records the combined report.
- [`benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json`](../../benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json)
  is the retained machine report.
- [`benchmark/results/contract-parity-2026-08-24/parity-report.json`](../../benchmark/results/contract-parity-2026-08-24/parity-report.json)
  is the retained native/browser semantic comparison report.

## Cross-project ledger boundary

The six entries are evidence references, not dependencies:

| ID | Project | Transferable evidence | Explicit boundary |
| --- | --- | --- | --- |
| CP-001 | SignKit | Native-first inspection, candidate ranking, review and correction loops, hard negatives, and an end-to-end benchmark ladder | No signature extractor, cleanup pipeline, vault, or legal claim was imported |
| CP-002 | MetaExtract | Extractor registry, provenance, normalization, conflict handling, shadow mode, and sensitive reporting | No general field catalog or runtime was imported |
| CP-003 | Invoice Intelligence | Digital/scanned routing, strict schemas, aliases, reviewed labels, controlled degradation, validation, and cost/latency measurement | No invoice schema, business rules, prompts, or dataset was imported |
| CP-004 | PhotoSearch | Region OCR bounds, language/confidence metadata, local model/cache behavior, and missing-engine handling | No media catalog, storage model, or model ownership was imported |
| CP-005 | extracted_forms | Artifact, editable-form, provenance, and acquisition boundaries | No bundled resources or unverified historical outputs were imported |
| CP-006 | historical signature auto-detect web | Interaction, coordinate, and manual-fallback hypotheses | No historical implementation, assets, or data were imported |

Every file source is recorded with its absolute path and SHA-256. Directory
sources are recorded as path-only evidence because hashing an entire adjacent
project would create a new inventory and ownership boundary. The ledger
contains no PDF bytes, profile values, extracted document content, screenshots,
or diagnostic payloads.

The current truth level is `local-static-evidence`. The ledger is therefore
strong enough to support design transfer and future adapter admission, but not
strong enough to claim that a neighboring project is production-ready,
license-cleared for redistribution, or semantically equivalent to this PDF
editor.

## Native/web parity fixture

The parity fixture covers:

- source SHA-256 identity;
- page geometry, crop-box, rotation, and lower-left point coordinates;
- native field facts;
- static candidate evidence;
- edit-session operation intent;
- validation status and checks;
- security and accessibility facts.

Provider version, timestamps, generated identifiers, diagnostic prose, and PDF
bytes are intentionally outside the semantic comparison. The policy is
`record-and-classify`, not normalize-away. This keeps real provider or detector
disagreement visible.

The corpus spans public and synthetic forms, native widgets, navigation and
metadata, encrypted input, malformed input, resource limits, raster OCR, and
90-degree plus mixed-rotation fixtures. The malformed fixture is expected to
fail inspection in both lanes, which is a parity result rather than a test
failure.

## First mismatches

The report contains four mismatches:

- two `candidate-semantic-set` mismatches;
- two `candidate.count` mismatches.

They occur only on the static Form 6 fixture and its mixed-rotation derivative.
Source digests, page facts, field facts, operation intent, validation state,
security, and accessibility projections remain within the accepted semantic
policy. These open mismatches are classified as detector/provider differences,
not erased by reducing the comparison surface. The next gate is independent
fingerprint extraction and candidate calibration on the same real PDFs, with
false-positive and abstention thresholds recorded by fixture class.

## Source identity drift

The live artifact
`benchmark/results/2026-08-23-public-acroform/noop.pdf` hashes to
`9ed5ff75fec3a5f51847160e81d5413d1797a84005a02a757787f477b1f934f8`, while the
existing manifest declares
`08b7ab663298627d1d4c152e1b53a51ad9a3ff688eca14f9791d993e42c2a00c`.

The harness records this as `sourceIdentityDrift` with disposition
`preserved-for-review; manifest-and-generated-artifact-were-not-rewritten`.
No binary, manifest, or prior benchmark output was silently rewritten. Until
the artifact owner resolves the provenance question, this fixture remains
usable for live native/browser agreement but not for a clean claim that the
manifest and live bytes represent the same source revision.

## Evidence classification

| Evidence | Tier | Sensitivity | Claim supported |
| --- | --- | --- | --- |
| Ledger schema and source inventory | Tier 1/S1 | Low, paths and source hashes only | The six neighboring projects were inspected at the recorded source paths and mapped to bounded transfer candidates |
| Ledger and parity contract validation | Tier 2/S1 | Low | Required identity, version, provenance, source existence, fixture membership, falsifier, rollback, and mismatch policies are machine-checked |
| Native Swift projection | Tier 2/S1 | Medium, local PDFs | The native contract harness emitted the expected semantic bundle for every corpus case, including the expected malformed failure |
| Browser projection | Tier 3/S1 | Medium, local PDFs in isolated Chrome | The browser adapter emitted comparable semantic bundles through the project-owned local proof route |
| Combined parity report | Tier 2/S1 plus Tier 3/S1 | Medium | Native and browser semantic records agree except for four explicitly classified candidate-detector mismatches |

## Verification

```text
node Tests/cross_project_evidence_ledger_parity_test.mjs
```

Observed retained result:

```text
ledgerEntryCount: 6
corpusFixtureCount: 11
sourceEvidenceCount: 18
parityMismatchCount: 4
unexpectedMismatchCount: 0
passed: true
```

The wrapper built `PDFContractHarness`, ran the native lane, started a
project-owned temporary server on port 8184 for the browser lane, ran the
existing isolated-Chrome parity consumer, wrote the combined report, and
stopped the temporary server. The existing browser service on port 4173 was
not modified.

## Limits and next gate

This milestone does not establish:

- native/web byte identity;
- arbitrary semantic text reflow;
- OCR accuracy or OCR-to-editable-field correctness;
- independent-viewer fidelity for every provider;
- license clearance for redistribution of adjacent code or data;
- production reuse of any neighboring runtime;
- resolution of the Form 6 candidate detector mismatches;
- exhaustive audit of every directory under `/Users/pranay/Projects`.

The next evidence unit is independent native and browser fingerprint extraction
from the same live PDFs, followed by class-specific candidate precision,
recall, correction distance, and hard-negative abstention gates. OCR,
companion, parser, and provider implementation decisions remain downstream of
that evidence.
