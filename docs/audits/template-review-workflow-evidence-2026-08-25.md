# Reviewed template completion workflow evidence

Date: 2026-08-25

Status: Implemented in the shared native/browser completion runtime and both
review surfaces. The workflow is source-bound and fail-closed. This record is
an implementation and test result, not a claim of universal PDF fidelity.

## User outcome

Recurring completion now has two visible approvals before any
`EditOperation` is created:

1. Mapping approval: the reviewer confirms that a specific template mapping
   points at the correct native field or static page region.
2. Profile-value approval: the reviewer confirms the exact value from a
   specific profile revision for that already-reviewed mapping.

The source PDF remains immutable. Approved values are materialized into the
existing typed operation ledger only after both approvals, source-digest
validation, coordinate validation, provider target resolution, and payload
support checks pass.

## Contract behavior

The completion entry keeps the existing status projections
`mappingReview` and `valueReview`, and adds two explicit provenance records:

- `mappingApproval`: mapping ID, resolved target ID, page-space coordinate, and
  review time;
- `profileValueApproval`: profile ID, profile revision ID, semantic key,
  SHA-256 digest of the typed value, state, and review time.

This is an additive runtime extension. Older template and profile envelopes
remain readable because the approval records are optional at decode time, but
an old completion proposal without the new binding records cannot materialize
operations. That is the safe compatibility direction.

The native implementation is in
`Sources/PDFEditorCore/TemplateRuntimeContracts.swift`. The browser projection
is in `web/pdf-template-contract.mjs`. Both use the same state transitions:

| Stage | Required state | What it authorizes |
| --- | --- | --- |
| Proposal | mapping pending, value unresolved or resolved-unreviewed | review only |
| Mapping review | mapping approved plus target-bound approval | value review for that target |
| Profile-value review | value approved plus profile/revision/value digest binding | materialization eligibility |
| Materializable | both approvals, source and coordinates valid, supported payload | creation of typed edit operations |
| Changed value or target | affected approval invalidated | re-review only |

The target-resolution rule is important for native fields. Resolving an opaque
template token to a provider field name after a mapping approval resets mapping
approval to `pending`. The reviewer must approve the actual provider target,
not only the abstract template region.

The value rule is equally important. Editing an approved value resets it to
`resolvedUnreviewed`. A direct mutation of the value object without changing
the approval record fails because the recomputed digest no longer matches.

## Native workflow

`Sources/PDFEditorApp/AppModel.swift` owns the native state machine:

- `captureTemplateReview()` creates a value-free draft from the PDFKit
  inspection and keyed layout fingerprint;
- `reviewTemplateMapping` records mapping decisions;
- `activateTemplateReview` creates an immutable active child revision;
- `prepareTemplateCompletionReview` resolves the current native profile
  revision and provider field targets without creating operations;
- `reviewTemplateCompletionMapping` and
  `reviewTemplateCompletionValue` mutate only the in-memory review proposal;
- `applyTemplateCompletion` calls the core materialization gate before sending
  any operation to PDFKit.

`Sources/PDFEditorApp/ContentView.swift` exposes the same state machine in the
native inspector. Mapping controls and exact-profile-value controls are
separate SwiftUI controls. The apply button remains disabled unless the core
proposal reports both approvals as valid.

The encrypted native template store and encrypted profile vault remain
separate. The template review can therefore retain mapping and layout history
without copying profile values into template persistence.

## Browser workflow

`web/index.html` exposes the browser sequence:

- capture layout;
- review mapping proposals;
- activate the reviewed template revision;
- prepare a completion proposal from the current browser profile when one is
  unlocked, or from explicitly entered session values when no persistent
  profile is selected;
- review `Approve mapping` and `Approve exact profile value` independently;
- apply only after `canMaterializeCompletion` returns success.

The encrypted browser profile vault supplies a profile revision ID when a
profile is selected. The no-profile path is deliberately session-scoped and
does not create a persistent profile record. It still requires the same exact
value approval and digest binding before materialization.

The browser `web/app.js` projection uses the same contract helpers and visible
labels. No route is allowed to bypass `materializeCompletionOperations`.

## Negative and mutation evidence

Native `completionApprovalStagesRejectValueOrMappingBypassAndInvalidateChangedInputs`
proves:

- value approval without mapping approval throws `mappingReviewRequired`;
- changing an approved value while retaining the old approval throws
  `profileValueApprovalRequired`;
- changing provider target resolution resets mapping approval and blocks
  materialization.

`Tests/web_template_contract_test.mjs` proves the equivalent browser states,
including digest mismatch and target mutation. The isolated Chrome test
`Tests/web_template_browser_test.mjs` captures a live template, checks the
draft mapping controls, activates the revision, prepares completion, confirms
the apply control is disabled for unreviewed entries, and asserts that mapping
approval and exact profile-value approval are separately visible. The focused
runtime had no console or page errors.

## Verification

- Swift package: 92 tests in 10 suites passed.
- Browser contract: fingerprint, mapping, profile, matcher, dual-review, and
  negative checks passed.
- Browser store and reader contract checks passed, including 51 reader and
  completion checks.
- Isolated Chrome template browser workflow passed on port 4174.
- Isolated Chrome encrypted template/profile security workflow passed on port
  4174.
- Native executable compiled as part of the Swift test build.
- Value digest implementation was cross-checked against Node's SHA-256 for the
  canonical `text:Ada Lovelace` value.

Evidence tier: Tier 2/S2 for the new negative tests, Tier 3/S1 for native
build and browser contract execution, and Tier 4/S1 for the isolated Chrome
review surface. This does not prove visual fidelity of every provider export.

## Residual risks and next hardening

- Native SwiftUI UI proof is source/build evidence; automated macOS interaction
  coverage for every control is still open.
- The browser no-profile path is session-only and must remain visibly distinct
  from encrypted persistent profiles.
- Profile revision changes after a proposal is prepared must require a fresh
  proposal; future persistent profile selection should enforce this through a
  vault revision lookup rather than only UI state.
- Operation-level approval provenance is currently carried in the completion
  proposal and the resulting source-bound operation session. A future export
  audit projection should retain value-free approval IDs and digest references
  alongside the operation lineage.
- Multi-user review, remote profile synchronization, and collaborative
  conflict resolution require separate authority and deletion models.

## Rollback

If the review UI regresses, disable the template apply action while preserving
the encrypted revision history and the core fail-closed materialization gate.
Do not restore a direct profile-to-operation path. Existing manual and native
field workflows remain independent of this template review state.
