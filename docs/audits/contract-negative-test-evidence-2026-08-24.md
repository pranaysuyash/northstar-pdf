# Shared Contract Negative-Test Evidence

**Date:** 2026-08-24  
**Surface:** native PDFKit provider, shared Swift contracts, and browser PDF.js/pdf-lib adapter
**Evidence tier:** Tier 2/S1 targeted regression evidence, Tier 3/S1 browser integration evidence, and S3 mutation evidence for source binding
**Disposition:** contract safety negatives pass in native and browser lanes; provider parity and broader fidelity remain open

## Claims tested

The provider must fail closed when an edit session is stale, unsupported,
destructive without policy, geometrically inconsistent, or semantically
unknown. A rejected operation must not publish a destination or leave a staged
temporary export behind.

## Negative cases

| Case | Test | Expected result | Evidence |
|---|---|---|---|
| Stale source digest | `staleSourceDigestIsRejectedBeforeMutationAndPublication` | Reject before mutation; preserve destination sentinel and staging directory | Pass S1; deliberate bypass mutation failed the test and overwrote the sentinel, S3 |
| Unsupported operation | `unsupportedOperationIsRejectedAndDiagnosticNamesKind` | Reject `sanitize` and name the unsupported operation | Pass S1 |
| Destructive edit | `destructiveFlagIsRejectedUntilProviderPolicyExists` | Reject a destructive overlay until a provider policy exists | Pass S1 |
| Coordinate page mismatch | `coordinatePageMismatchIsRejectedBeforeMutation` | Reject coordinate page different from operation page | Pass S1 |
| Coordinate bounds mismatch | `coordinateBoundsMismatchIsRejectedBeforeMutation` | Reject bounds different from persisted page-space coordinate | Pass S1 |
| Explicit unknown validation state | `unknownValidationStateRemainsUnknownAndFutureStateFailsClosed` | Preserve `unknown`; never promote it to `passed`; reject an unrecognized future enum value | Pass S1 |

## Implementation boundary

`PDFKitProvider.export` now validates an operation's non-nil source digest
against the freshly inspected source before applying it. The provider also
validates operation shape through `apply`, which is important because the
native app uses `apply` for live preview mutations before export:

- destructive operations are rejected until an explicit provider policy exists;
- a coordinate page index must equal the operation page index;
- when both are present, operation bounds must equal the page-space coordinate
  rectangle;
- unsupported operation kinds continue to fail visibly, with the operation kind
  included in the diagnostic.

Legacy operations with a nil source digest remain readable for compatibility,
but newly created native operations continue to bind to the inspected digest.
The direct `apply` API cannot verify a source digest because it receives a
`PDFDocument`, not a source identity. Export is the source-binding authority.

## Verification

```sh
swift test --filter ContractMutationTests
swift test
```

Results:

- focused negative suite: 6 tests passed;
- full native suite: 36 tests passed in 3 suites;
- deliberate source-binding mutation: focused suite failed with the stale
  operation exporting and overwriting the sentinel destination;
- source-binding guard restored and full suite rerun successfully.

The mutation run is recorded as S3 evidence for the source-digest invariant.
The other negative cases currently have S1 evidence and should receive
targeted mutation runs if they become release-blocking invariants.

## Browser mutation evidence

`Tests/web_pdf_contract_mutation_test.mjs` exercises the local browser fixture
against `benchmark/results/public-sample-form.pdf`. It calls the same
`guardedPdfLibExport()` seam exposed by the fixture and then probes the actual
`materializeOperations()` path with a temporary mutation of the operation list.

| Case | Browser assertion | Result |
|---|---|---|
| Stale source digest | `ContractMutationError` with `staleSourceDigest`; writer callback count remains zero | Pass |
| Unsupported operation | `sanitize` is rejected with `unsupportedOperation` | Pass |
| Destructive operation | `destructive: true` is rejected with `destructiveOperation` | Pass |
| Unknown validation state | an `unknown` `visualDiff` check is rejected with `unknownValidationState` | Pass |
| Coordinate page mismatch | coordinate page differs from operation page and is rejected | Pass |
| Coordinate bounds mismatch | coordinate rectangle differs from operation bounds and is rejected | Pass |

The integration probes then spy on `window.PDFLib.PDFDocument.load` while
submitting each of the six mutations to `runMaterializationProbe()`. Every
observed `loadCalls` value is `0`, proving the browser gate runs before pdf-lib
rather than merely failing during post-export validation. A valid control
operation calls the writer once.

Verification command:

```sh
node Tests/web_pdf_contract_mutation_test.mjs
```

Observed result: six mutation cases passed with zero writer calls, the valid
control called the writer once, and all six actual pdf-lib load probes recorded
zero calls. This is Tier 3/S1 browser integration evidence,
with deliberate input mutation providing S3-style sensitivity for the browser
source-binding invariant. It does not establish provider fidelity, semantic
parity, independent-viewer equivalence, or permission enforcement.

## Residual risks

These tests do not prove native/web serialized parity, PDF byte fidelity,
outside-region object preservation, independent-viewer reopening, cryptographic
redaction, signatures, XFA behavior, or all provider-specific form semantics.
The browser fixture separately records that PDF.js may inspect widgets that
pdf-lib cannot mutate.
