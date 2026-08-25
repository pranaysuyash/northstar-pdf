# Native SwiftUI template capture and review surface evidence

Date: 2026-08-25

Status: Implemented against the shared template runtime contracts. Native
source/build and focused contract evidence are green. Automated macOS UI
interaction and provider-wide PDF fidelity remain separate evidence lanes.

## User-facing workflow

The native inspector now exposes the complete reviewed-template lifecycle:

1. Name and capture a value-free layout template from the current PDFKit
   inspection.
2. Review each proposed native-field or static-region mapping.
3. Activate an immutable child revision only after every mapping decision is
   explicit and at least one mapping is approved.
4. Unlock and select a separate local profile vault.
5. Prepare a source-bound completion proposal without creating operations.
6. Review mapping identity and exact profile values independently.
7. Apply only when the shared materialization gate accepts every entry.
8. Export and pass strict validation before the UI offers saving a child
   template revision and applying a learning event.

The source PDF remains immutable throughout this workflow. A static visual
candidate remains an overlay target and is never silently converted into a
native AcroForm field.

## Native SwiftUI surface

`Sources/PDFEditorApp/ContentView.swift` now presents:

- a local template display-name field and capture action;
- lifecycle, mapping count, keyed layout-fingerprint prefix, source-digest
  count, revision ID, parent revision ID, and privacy mode;
- mapping toggles for draft capture, with explicit page, target kind, and
  review state;
- local index candidates and review loading;
- completion match state, reasons, source-digest prefix, and session identity;
- per-entry page-space geometry and native target resolution status;
- separate `Approve mapping` and `Approve exact value for this profile
  revision` controls;
- typed value editors for text, choice, and boolean profile values;
- a visible unsupported state for asset references until an explicit asset
  picker exists;
- mapping/value approval counters and a disabled Apply action until the shared
  proposal reports readiness;
- strict-validation and explicit-save messaging for immutable child revisions.

`Sources/PDFEditorApp/AppModel.swift` remains the native state-machine owner.
The UI calls `captureTemplateReview`, `reviewTemplateMapping`,
`activateTemplateReview`, `prepareTemplateCompletionReview`,
`reviewTemplateCompletionMapping`, `reviewTemplateCompletionValue`, and
`applyTemplateCompletion`; it does not construct `EditOperation` values.

Typed value editing preserves the original `PDFProfileValue` case. Editing a
value always returns it to `resolvedUnreviewed`, so a previous approval digest
cannot authorize a changed value. Native target resolution also resets mapping
approval when the provider field identity changes.

## Shared contract boundary

The surface projects `PDFTemplateCompletionProposal` and
`PDFTemplateCompletionEntry` from
`Sources/PDFEditorCore/TemplateRuntimeContracts.swift`.

Materialization still requires all of the following:

- exact current source digest;
- reviewable match state;
- approved mapping state;
- mapping approval bound to mapping ID, target ID, and page-space coordinate;
- approved value state;
- profile ID, profile revision ID, semantic key, and typed-value digest;
- a value supported by the target operation;
- page/region coordinate consistency;
- resolved provider target for native fields.

This keeps SwiftUI presentation, native PDFKit adaptation, browser rendering,
and typed operation creation as separate layers while preserving semantic
parity at the contract boundary.

## Verification

The following checks were run against the current checkout:

- The focused Swift template suite passed 4/4, covering stale source,
  target-resolution, mapping/value bypass, and typed choice/boolean payloads.
- `swift build --target PDFEditorApp` passed.
- `swift build` passed for the package targets.
- The added typed-value test proves choice and boolean values retain their
  semantic payloads through review and materialize the corresponding edit
  payloads.

Evidence tier: Tier 2/S1 for shared contract and negative-state behavior;
Tier 3/S1 for native target compilation. No automated macOS accessibility or
pointer/keyboard interaction run was performed in this pass, so visual
interaction evidence remains open.

## Remaining native evidence

- Run the native executable against the governed corpus and exercise capture,
  mapping review, profile unlock, typed value review, apply, export, and
  explicit revision save with macOS UI automation.
- Add native UI accessibility identifiers and an automation harness for every
  approval and disabled-state gate.
- Exercise native choice, checkbox, radio, signature, and unsupported profile
  value mappings against provider fixtures.
- Compare the native review session and resulting operation provenance with the
  browser review session on the same source digest.
- Retain independent-viewer and outside-region validation evidence before
  promoting any provider-specific completion claim.

## Rollback

If the native surface regresses, disable only the template Apply action and
preserve the encrypted template/profile stores and review history. Do not
restore a direct profile-to-operation shortcut and do not delete immutable
revision evidence.
