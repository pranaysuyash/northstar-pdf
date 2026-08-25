# Native versus browser semantic parity evidence

- Date: 2026-08-25
- Status: fresh same-corpus report generated; no unexpected semantic mismatches
- Corpus: [`docs/fixtures/manifest.md`](../fixtures/manifest.md), 18 governed PDF fixtures
- Native adapter: `PDFContractHarness` using PDFKit
- Browser adapter: PDF.js reader and browser contract fixture, with the existing pdf-lib export path
- Report: [`benchmark/results/semantic-parity/2026-08-25/parity-report.json`](../../benchmark/results/semantic-parity/2026-08-25/parity-report.json)
- Comparator: [`web/pdf-contract-parity.mjs`](../../web/pdf-contract-parity.mjs)
- Runner: [`Tests/pdf_contract_parity_test.mjs`](../../Tests/pdf_contract_parity_test.mjs)
- Report gate: [`Tests/native_browser_semantic_parity_report_test.mjs`](../../Tests/native_browser_semantic_parity_report_test.mjs)

## Purpose

This run compares the semantic contracts emitted by the native and browser
adapters for the same source bytes. It does not compare PDF bytes, provider
object identity, or generated output identity. The goal is to detect changes
that affect the product contract while preserving enough representation
provenance to explain which adapter produced each observation.

The report is a parity artifact, not a universal PDF fidelity claim. A clean
classification means that every observed difference is either absent or
covered by the fixture's declared mismatch policy. It does not mean that the
native and browser providers perform identical candidate detection, preserve
identical PDF object graphs, or render identical pixels.

## Normalization contract

The parity contract is version `1.1` in
[`web/pdf-contract-parity.mjs`](../../web/pdf-contract-parity.mjs). Its policy
has three distinct categories:

1. Product semantics retained for comparison: source SHA-256, source metadata,
   page geometry and rotation, text and annotation counts, native field
   meaning, candidate geometry and evidence families, coordinate envelopes,
   operation intent and source binding, navigation metadata, accessibility and
   security facts, and validation state/check status.
2. Representation fields excluded from semantic equality: provider IDs and
   versions, platform labels, timestamps, generated/random IDs, field,
   candidate, evidence, operation, and validation-check IDs, diagnostic prose,
   validation messages, and output digests.
3. Representation facts retained only as provenance: whether a provider ID,
   provider version, timestamp, or output digest was present. The report never
   compares or copies the output-digest value into the parity result.

The source digest is intentionally not normalized away. It identifies the
input bytes and is required for both adapters on readable fixtures. Output
digests identify derived artifacts and can differ because PDF writers
serialize different bytes even when the user intent is equivalent.

Exact normalized projection digests are retained per lane. The comparator
result is retained separately because declared character-count tolerance can
accept two projections whose exact JSON digests differ.

## Corpus result

| Measure | Result |
|---|---:|
| Manifest fixtures | 18 |
| Readable fixtures | 16 |
| Expected malformed failures | 2 |
| Native/browser status agreement | 18/18 |
| Readable source bindings matching live SHA-256 | 16/16 in both lanes |
| Total classified mismatches | 6 |
| Unexpected mismatches | 0 |
| Output digests used for semantic equality | 0 |
| Provider/timestamp/ID mutation checks | passed |

Both malformed fixtures, `truncated-128-bytes.pdf` and
`malformed-hybrid-truncated.pdf`, produce the same explicit
`inspectionFailed` state. They are not treated as successfully inspected
documents with missing source identity.

## Classified mismatches

| Source fixture | Mismatch | Native observation | Browser observation | Disposition |
|---|---|---|---|---|
| `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` | `candidate-semantic-set` | Static-region detector emits a larger, text/evidence-oriented set | Geometry detector emits a different checkbox/region-oriented set | Declared open detector mismatch |
| `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` | `candidate.count` | Provider-specific count | Provider-specific count | Declared open detector mismatch |
| `benchmark/results/rotation-corpus/rotated-form6-mixed.pdf` | `candidate-semantic-set` | Native candidate set | Browser candidate set | Declared open rotated-detector mismatch |
| `benchmark/results/rotation-corpus/rotated-form6-mixed.pdf` | `candidate.count` | 29 | 100 | Declared open rotated-detector mismatch |
| `benchmark/results/browser-corpus/encrypted-hybrid.pdf` | `page.geometry-or-text` | Page 0 is `595.28 x 841.89` points | Page 0 is `595 x 841` points | Declared precision mismatch |
| `benchmark/results/browser-corpus/encrypted-hybrid.pdf` | `coordinates` | Same precision difference in the page coordinate envelope | Same geometry rounded by browser provider | Declared precision mismatch |

No mismatch was attributed to provider IDs, timestamps, random IDs,
diagnostic messages, validation messages, or output digests. The three open
classes are preserved in the report rather than normalized away.

## Verification

The following checks passed:

```text
node Tests/native_browser_semantic_parity_report_test.mjs
native/browser semantic parity report: 18 fixtures, 6 declared mismatches, 0 unexpected

node Tests/pdf_contract_parity_mutation_test.mjs
normalized parity comparator: 10 checks passed
```

The full corpus execution was run with the repository served at
`http://127.0.0.1:8765/web/index.html`. The temporary server and isolated
Chrome run were stopped after generation. The previous dated parity artifact
under `benchmark/results/contract-parity-2026-08-24` was preserved.

## Current interpretation

The shared semantic spine is functioning for the current corpus: source
identity, readable/failure state, page inventory, form semantics, operation
shape, and validation state can be compared without treating provider-owned
representation as product meaning. The parity result is still partial because
candidate detection and point precision differ on the declared fixtures.

The next implementation work is concrete:

- reconcile native and browser static-candidate taxonomy on the Form 6 and
  rotated Form 6 fixtures;
- establish an explicit point-precision policy for page boxes and coordinate
  envelopes, including tolerance versus canonicalization evidence;
- extend the same normalization and mismatch classification to non-noop edit
  sessions, OCR observations, companion providers, and independent viewer
  outcomes;
- keep output-byte identity and provider-specific object identity as separate
  provenance lanes rather than weakening semantic equality.

This evidence does not authorize silently treating the adapters as
interchangeable. It establishes the comparison mechanism and the first
measured mismatch inventory for the long-term native/browser implementation.
