# Native, Browser, and Companion Rejection-Ledger Evidence

**Date:** 2026-08-31  
**Status:** current implementation evidence  
**Sensitivity:** S1 synthetic, value-free fixture plus S2 local protocol execution  
**Evidence tier:** Tier 2 focused contract evidence, with one Tier 3 local companion-host path

## Objective

Build a shared rejection-ledger oracle for the native PDFKit lane, the browser
PDF.js/pdf-lib lane, and an explicitly installed local companion lane. The
oracle must make provider failures comparable without pretending that provider
IDs, timestamps, raw diagnostics, or output bytes are product semantics.

This is a long-term foundation. It is not a claim that every live PDF provider
has already been wired to emit every rejection code. The fixture and adapters
establish the shared contract that future OCR, text replacement, page
operation, redaction, signature, XFA, PDF/UA, repair, and high-fidelity lanes
must use.

## Contract

The canonical contract is `pdf-editor.rejection-ledger`, version 1.0. The
browser implementation is [`web/provider-rejection-ledger.mjs`](../../web/provider-rejection-ledger.mjs);
the native mirror is
[`Sources/PDFEditorCore/ProviderRejectionLedger.swift`](../../Sources/PDFEditorCore/ProviderRejectionLedger.swift).

Each normalized attempt contains:

- logical `caseID` and capability;
- provider kind (`native`, `browser`, or `companion`) and provider ID;
- phase and state (`rejected`, `abstained`, `failed`, `cancelled`, or
  `completed`);
- source SHA-256 digest;
- the typed operation lineage and a deterministic lineage signature;
- canonical rejection code, category, retryability, and recovery action;
- counts of known and unknown provider reason codes.

The normalizer rejects malformed source digests, mismatched lineage digests,
empty operation lineages, invalid states, and invalid code syntax. It accepts
provider aliases only through the explicit alias map. Unknown provider reasons
become `unknownRejection`; they never become an equivalent successful result.

The shared error vocabulary includes source binding, input, operation,
provider, runtime, licensing, resource, cancellation, export, and validation
classes:

```text
staleSourceDigest sourceByteCountMismatch inputMissing inputTooLarge
cannotOpen passwordRequired passwordIncorrect invalidPage invalidOperation
unsupportedOperation destructiveOperation unknownValidationState
coordinateMismatch providerUnavailable runtimeUnavailable providerFailure
providerRevoked licenseUnapproved sourceOutsideProviderLimits outputLimit
timeout cancelled exportFailed validationFailed unknownRejection
```

The report is value-minimized. It excludes `observedAt`, output digests, raw
provider messages, document text, field values, passwords, screenshots, and
PDF bytes. Provider reason-code counts remain because they are useful for
adapter diagnostics without making the report content-bearing.

## Comparison semantics

Comparison is pairwise by logical `caseID` and provider pair. The report keeps
these predicates separate:

| Predicate | Meaning |
|---|---|
| `sameLineage` | Both attempts refer to the same source-bound operation intent |
| `sameOutcome` | Both attempts have the same normalized outcome |
| `sameCode` | Both attempts have the same canonical rejection code |
| `sameRecovery` | Both attempts prescribe the same recovery action |
| `comparable` | Both attempts are structurally valid and have the required shared semantics |
| `equivalent` | Comparable attempts agree on lineage, outcome, code, and recovery |

This distinction is the oracle's main safety property. A native and browser
stale-source rejection should converge even if their raw provider reasons
differ. A companion that is not installed must remain a provider-availability
divergence, not be counted as proof that the companion performed the same
operation.

## Fixture matrix

The source-bound fixture is
[`Tests/fixtures/provider_rejection_ledger_fixture.json`](../../Tests/fixtures/provider_rejection_ledger_fixture.json).
It contains one shared operation lineage and two failure cases across all
three provider kinds:

| Case | Native | Browser | Companion | Expected interpretation |
|---|---|---|---|---|
| stale source | `sourceDigestMismatch` -> `staleSourceDigest` | `staleSourceDigest` | `sourceDigestMismatch` -> `staleSourceDigest` | equivalent safety rejection across all providers |
| unsupported capability | `capabilityNotSupported` -> `unsupportedOperation` | `unsupportedOperation` | `noHandler`/`providerUnavailable` -> `providerUnavailable` | explicit companion capability divergence |

The fixture deliberately varies timestamps and includes one output digest so
the report proves those fields are not part of semantic equality.

## Evidence

The browser oracle test creates all three normalized ledgers, compares them,
re-normalizes an already-normalized attempt, tests malformed source and
lineage rejection, and exercises the actual companion host's unavailable
capability response:

[`Tests/provider_rejection_ledger_oracle_test.mjs`](../../Tests/provider_rejection_ledger_oracle_test.mjs)

The native Swift test decodes the same fixture and runs the native mirror over
the same provider cases:

[`Tests/PDFEditorCoreTests/ProviderRejectionLedgerTests.swift`](../../Tests/PDFEditorCoreTests/ProviderRejectionLedgerTests.swift)

The generated semantic comparison is retained at
[`benchmark/results/rejection-ledger/2026-08-31/report.json`](../../benchmark/results/rejection-ledger/2026-08-31/report.json).
The measured result is:

- 3 provider kinds represented;
- 2 logical cases;
- 6 pairwise provider comparisons;
- 6 comparable comparisons;
- 4 equivalent comparisons;
- 2 explicit capability divergences;
- 0 unknown comparisons;
- no raw output digest or timestamp in the report.

The two explicit divergences are the companion's `providerUnavailable` result
for the unsupported capability compared with the native/browser
`unsupportedOperation` result. This is expected evidence, not a failed safety
gate.

## Invariants and recovery

- Source bytes remain immutable and every operation attempt is source-digest
  bound.
- A rejected or abstained attempt cannot publish an output.
- Provider-specific reasons are retained only as bounded counts in the
  comparison surface.
- Unknown reason codes and unknown validation states fail closed.
- The companion path is a typed protocol boundary, not an arbitrary shell or
  filesystem API.
- A provider can be revoked or unavailable without changing shared document,
  coordinate, candidate, operation, or validation contracts.
- The ledger is append-oriented evidence. It does not rewrite the operation
  history or turn a provider failure into a new operation.

## Verification

```text
node --check web/provider-rejection-ledger.mjs                         PASS
node --check Tests/provider_rejection_ledger_oracle_test.mjs            PASS
node Tests/provider_rejection_ledger_oracle_test.mjs                    PASS
swift test --filter ProviderRejectionLedgerTests                         PASS (4 tests)
```

The browser run reports:

```text
provider rejection ledger oracle: 3 providers, 2 cases,
4/6 equivalent comparisons, 2 explicit divergences
```

The Swift run compiles the native mirror and validates the same fixture. A
previous focused run exposed only nondeterministic dictionary iteration in the
test assertion; the assertion was changed to address providers by stable ID,
then the focused suite passed. No concurrent SwiftPM process was terminated.

## Current limits and next wiring

The oracle is implemented and tested, but the live PDFKit and browser app
error sites are not yet universally emitting ledger entries. The companion
evidence currently proves the unavailable-capability path, not PDFBox or MuPDF
fidelity. Pre-operation failures without a source digest or operation lineage
also need a future admission-envelope extension rather than being smuggled
into this operation-bound schema.

The next wiring work is to emit one ledger entry at every provider boundary,
including OCR, text-run replacement, page operations, redaction, signatures,
XFA, PDF/UA, repair, cancellation, resource limits, and independent-validator
failures. Each provider report must then be joined to this oracle without
adding raw content or weakening the fail-closed rules.

## Reproducibility and ownership

This evidence was produced locally in the PDF Editor workspace. It did not
upload a PDF, install a provider, mutate Git, or change unrelated concurrent
work. The generated report is a derived artifact and can be regenerated from
the fixture and tests.
