# Template runtime handoff reconciliation evidence

Date: 2026-08-25

## Purpose

The implementation handoff listed native SwiftUI review, encrypted local
persistence, profile unlock, template indexing, matching, migration, typed
provider behavior, OCR, redaction, XFA, PDF/UA, signatures, and independent
viewer work as if those surfaces had not yet been built. The live checkout was
reconciled before adding code. Most of the lifecycle, contract, persistence,
native review, OCR, preflight, provider-lane, and validation infrastructure was
already present. This pass closed the browser retrieval and typed-value gaps and
recorded the remaining provider evidence honestly.

## Changes made

### Browser local template index

`web/app.js` now connects the existing `web/template-index.mjs` implementation
to the visible template card:

- `Find local matches` unlocks the encrypted template store and rebuilds a
  value-free local index from encrypted template histories.
- Exact, known-variant, family-match, ambiguous, stale, unsupported, and
  no-match states are rendered with score and reason evidence.
- A review action may load an exact, known-variant, or family-match revision.
- Stale, unsupported, and ambiguous results remain abstentions. They cannot be
  loaded as an automatic completion and cannot create operations.
- Loading a revision resets the current proposal state and retains the current
  PDF as the source authority.

The browser fixture now exports the index builder, query function, and revision
resolver for browser-side parity tests.

### Typed browser values

Browser profile serialization now preserves the shared value kinds instead of
flattening every value into text. Completion preparation coerces values against
the resolved native-field or static-region type:

- text remains text;
- choice fields use a choice value and visible option control;
- checkbox/button fields use a boolean value and visible checkbox control;
- signature values remain asset references and show an explicit provider
  requirement rather than silently becoming text.

The existing two approvals remain independent: mapping approval and current
profile-value approval. The shared materialization gate remains the only path to
source-digest-bound operations.

### Native and shared build repairs

The concurrent recovery-module move left public `AppModel` initializers unable
to expose the public default store types. The store classes, default-directory
members, shared key-store singleton, and interruption-test environment values
were made visible at the module boundary without changing persistence format or
recovery semantics.

The concurrently edited rotation-aware native impact validator required explicit
`Self.` qualification for its static comparison helpers under the current Swift
compiler. That compile repair was kept local to the helper references.

The PDFKit adapter now keeps a radio/button field-level value synchronized while
applying a widget state and can read a serialized group value when PDFKit stores
it separately from the widget appearance. The synthetic radio retention gate
now passes after the named radio option is resolved before boolean coercion.

The recovery module also now canonicalizes operation, metadata, candidate, view,
and payload dates as ISO-8601 during identity hashing. This keeps a persisted
envelope's digest stable across Codable round trips. Recovery interruption
semantics are explicit: pair and payload interruptions retain the previous
generation, metadata interruption makes the successfully written generation
authoritative, and an interrupted first save leaves no discoverable recovery.

The native raster validator now uses PDFKit's page transform for rotated crop-box
pages and applies a one-user-unit comparison halo for renderer boundary pixels.
The halo affects only the validation mask, not the authorized operation region.

## Verification

Passing evidence in this pass:

- `node --check web/app.js`
- `node --check web/template-index.mjs`
- `git diff --check`
- `node Tests/template_index_test.mjs`
- `node Tests/web_template_contract_test.mjs`
- `node Tests/web_template_store_test.mjs`
- isolated browser reader boot and completion check: 51 checks passed
- isolated browser template workflow with exact and stale index assertions:
  passed
- native focused radio retention test: passed
- native focused recovery interruption suite: 4 tests passed
- native full suite: 111 tests in 14 suites passed
- browser template index, contract, and encrypted-store checks: passed
- browser preflight adapter: passed

The earlier 102-test run and radio failure are historical evidence from before
the adapter fix. They are superseded by the focused radio pass, the 4-test
recovery interruption pass, and the final 111-test full-suite pass recorded
above.

## Current evidence boundary

Implemented contract and review behavior is not the same as provider proof.
The project now has typed, review-bound lanes for OCR, text replacement and
reflow, redaction, signatures, XFA, PDF/UA, companions, and independent
viewers. Their provider-specific execution remains represented as measured,
unknown, unsupported, revoked, or review-required until a governed fixture and
validator close each lane. The long-term capability mandate remains intact.

The next truthful gates are provider- and corpus-specific rather than missing
template lifecycle plumbing: external AcroForm choice preservation, signature
asset serialization, OCR and text-run alignment, redaction sanitization,
XFA/PDF-UA behavior, independent-viewer parity, and macOS UI automation. The
template index and review lifecycle now exercise visible exact/stale behavior;
family and ambiguous states remain abstentions by construction. Neither the
native nor browser adapter permits silent autofill.
