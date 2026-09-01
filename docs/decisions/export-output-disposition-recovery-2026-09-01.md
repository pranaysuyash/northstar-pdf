# Export Output and Disposition Recovery

**Date:** 2026-09-01  
**Status:** Proposed design boundary; implementation intentionally pending  
**Primary lens:** PER-0926 Product Evolution Architect  
**Doctrine check:** PER-0428 Review/Evidence Steward

## Decision question

After a derived PDF copy has been written, should Rework, Accept Variance, and
Discard survive an app restart, and what durable identity would make that safe?

This is separate from the pre-export review receipt. A review receipt explains
what the app intended to do and what it knew before export. A disposition record
would authorize a later action against an output artifact. Combining those two
records would make a descriptive recovery file look like a permission grant.

## Current evidence

- `Sources/PDFEditorCore/ExportReviewReceipt.swift` defines a value-minimized
  receipt containing the explicit copy profile, source filename and digest,
  operation IDs and summaries, validation checks, and review state. It does not
  contain output paths, output bytes, operation values, or permission to resume.
- `Sources/PDFEditorCore/DocumentSessionContracts.swift` now persists the
  optional receipt inside `DocumentSession`. The field is optional so older
  recovery envelopes remain readable.
- `Sources/PDFEditorRecovery/AppModel.swift` currently keeps
  `lastExportURL` and `lastExportDisposition` in host memory. Rework removes the
  latest output, Accept Variance requires a present validated-with-warnings
  output, and Discard requires a present output plus confirmation.
- `Tests/PDFEditorCoreTests/SessionPrivacyProvenanceTests.swift` proves the
  receipt round-trips and that an older envelope without this optional field
  still decodes. `ExportReviewDispositionTests` proves the in-session state
  machine, not restart recovery.
- The user direction for contextual behavior is adaptive presentation based on
  current context and observed intent, with explicit recovery paths. The same
  principle applies here: history and recovery may assist, but neither may
  silently authorize a high-impact file action.

## First-principles invariants

1. **Description is not authority.** A receipt can explain a pending review;
   it cannot authorize deleting, replacing, or modifying an output.
2. **Source identity is not output identity.** Matching the source digest proves
   only that the input is the same. It says nothing about the output path or
   whether the output was replaced by another process.
3. **Byte identity is not user intent.** A matching output digest proves bytes,
   not that the user still wants to accept or delete them.
4. **Existence is not ownership.** A file at a remembered path may have been
   moved, replaced, or created by another application.
5. **Restart must fail closed.** If capability, identity, permission, or
   validation is unavailable, the app may show Inspect and Forget, but must not
   perform Rework, Accept Variance, or Discard automatically.
6. **Disposition is an explicit event.** Accept Variance and Discard must carry
   a fresh user action after the artifact and its current validation state are
   rechecked.
7. **Recovery must be bounded.** The app should retain at most one active
   pending output record per session and must provide a visible Forget/Clear
   path without retaining output bytes.

## Options

| Option | Benefit | Failure mode | Decision |
|---|---|---|---|
| Persist raw output URL | Simple restart lookup and familiar file behavior | Leaks local path structure; path may now identify a different file; no ownership proof | Reject as sole identity |
| Persist output digest only | Low disclosure and strong byte comparison | Cannot locate output; cannot offer useful recovery without a new file picker | Retain as an integrity component |
| Persist URL plus digest and re-check | Usable recovery with replacement detection | Still has path disclosure and no durable authorization; aliases and moves remain difficult | Insufficient alone |
| Persist a scoped security-scoped bookmark plus digest | Can recover a user-selected file while preserving macOS access boundaries | Bookmark lifecycle, revocation, stale resolution, and sandbox behavior need host proof | Recommended candidate |
| Persist a user-visible export record and require re-selection after restart | Strongest ownership and consent semantics; works after moves | Adds friction and cannot automatically discard an output | Recommended beta fallback |
| Persist output bytes in recovery | Makes recovery self-contained | Violates value-minimized recovery and can duplicate sensitive documents | Reject |

## Proposed long-term shape

Keep the existing `DocumentSession.exportReviewReceipt` as the durable
pre-export explanation. Add a separate, optional `ExportOutputRecord` only
after the macOS access model is proven. The record should contain:

- session ID and source digest;
- explicit export profile;
- output digest and page-count observation;
- a user-visible display name, not an arbitrary source-derived path;
- validation state and validation report identity;
- creation and last-observed dates for retention, not for ranking behavior;
- a revocation/forget state;
- a security-scoped bookmark or equivalent governed access reference, kept out
  of the general-purpose receipt and protected by the app's local persistence
  policy.

The record must not contain source text, operation values, annotations,
provider payloads, or a flag that means "resume without review." On recovery,
the app should resolve the access reference, compare the current output digest,
revalidate existence and file type, and present an Inspect state. Only a fresh
user action can then choose Rework, Accept Variance, or Discard. If the access
reference is stale, the output digest mismatches, or validation is missing, the
only automatic outcomes are Inspect, Forget, or Ask the user to locate the
artifact.

## Product behavior

The normal path remains quiet and direct:

1. Pre-export receipt explains the selected profile and unresolved checks.
2. User explicitly continues to the save panel.
3. Output is written to a separate destination and independently reopened.
4. The inspector presents the validation result and disposition controls.
5. On restart, an unresolved output appears as a recoverable review item, never
   as an implicit mutation or delete operation.

The compact native UI should show one bounded row such as "Export review
available" with Inspect and Forget. It should not show a file-management
dashboard or surface a stale path as if it were authoritative.

## Required research and tests

| ID | Question | Evidence required | Falsifier |
|---|---|---|---|
| EOR-01 | Can a sandboxed native app resolve and release a scoped bookmark safely? | T4 host test across saved, moved, revoked, and inaccessible files | Bookmark resolves to a replacement or cannot be revoked |
| EOR-02 | Does digest revalidation detect replacement without reading content into recovery? | T2 record test plus T4 replacement walkthrough | Same path and wrong bytes remain actionable |
| EOR-03 | Is post-restart disposition understandable and consentful? | T4 Inspect/Forget/Rework walkthrough with keyboard and VoiceOver | User interprets Inspect as automatic acceptance or deletion |
| EOR-04 | Does retention stay bounded and inspectable? | T2 one-record-per-session and clear tests; local persistence inspection | Multiple stale outputs accumulate or cannot be forgotten |
| EOR-05 | Does the output profile remain tied to validation obligations? | T2 profile mismatch and state-transition tests | A sanitized/flattened output can inherit edited-copy validation |

## Stop conditions

Do not implement durable Rework or Discard until EOR-01 and EOR-02 have
passing host evidence. Do not implement durable Accept Variance until EOR-03
proves a fresh explicit consent step and the output's warning state is still
visible. Do not claim release readiness from a successful serialization test;
the current package still lacks control-level accessibility, keyboard/focus,
resize, multi-window, and post-export Tier-4 evidence.

## Decision

**Adopt the split now:** durable value-minimized pre-export receipts are
allowed and implemented; durable post-export disposition remains proposed.
Use a scoped access reference plus digest as the long-term candidate, with
explicit re-selection as the beta fallback. Keep output identity and
disposition out of `DocumentSession` until the separate privacy, access,
replacement, and consent gates pass.
