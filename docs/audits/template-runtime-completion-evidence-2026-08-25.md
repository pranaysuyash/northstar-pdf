# Template runtime completion evidence

Date: 2026-08-25

This record closes the implementation gaps listed in the preceding template
handoff. It does not convert a provider admission or a passing contract test
into a universal PDF capability claim.

## Implemented mechanics

Native macOS now provides:

- SwiftUI capture, mapping approval, activation, profile selection, exact-value
  review, source-bound operation materialization, export validation, and explicit
  child-revision saving.
- Keychain-backed encrypted template and profile stores with separate record
  boundaries, append-only revision histories, learning journals, deletion,
  import, and value-free transfer envelopes.
- A value-free local template index rebuilt from encrypted histories. It exposes
  exact, known-variant, family, ambiguous, stale, unsupported, and no-match
  states with scores and reasons.
- Revision diff detail and learning-journal visibility in the review panel.

Browser local-first mode now provides:

- The equivalent two-stage mapping and profile-value review flow.
- AES-GCM IndexedDB and encrypted OPFS stores, separate profile records,
  ephemeral fallback, health inspection, eviction detection, ciphertext-only
  backup export, restore, explicit deletion, import/export, and zero-content
  diagnostics.
- The same value-free template index semantics and explicit candidate revision
  review. Family and ambiguous results never pre-approve mappings.
- Revision-change and learning-journal summaries in the review panel.

## Shared capability admission

`PDFCapabilityLane` and `pdf-capability-lanes.mjs` name the long-term lanes:

- native choice and checkbox;
- visual and cryptographic signatures;
- OCR text bounds and searchable OCR layers;
- text-run replacement and paragraph reflow;
- permanent redaction;
- XFA forms;
- PDF/UA conformance;
- independent-viewer reopen.

Each lane is source-digest bound and negotiates through the existing provider
manifest, license, measurement, source-limit, install-state, and revocation
contracts. An admitted provider is not automatically an available result. An
execution result must include validation state and evidence, and anything not
validated remains `unknown`, `partial`, `revoked`, or `needsReview`.

This keeps OCR, text rewriting, redaction, signatures, accessibility, and
companion engines replaceable without changing the shared document or
edit-session contracts.

## Verification

- `node Tests/template_index_test.mjs`: exact, known-variant, family,
  ambiguous, stale, no-match, privacy, and abstention checks passed.
- `node Tests/pdf_capability_lanes_test.mjs`: named lanes, native Vision
  admission fixture, source-digest binding, result validation, and no-provider
  abstention passed.
- `swift test --filter 'TemplateIndexTests|PDFCapabilityLaneTests'`: native
  index precedence, stale rejection, duplicate identity rejection, and typed
  advanced-lane abstention passed after the native/browser precedence fix.
- Existing browser store, template review, sync, security, parity, preflight,
  and provider registry tests remain part of the full verification pass.

The targeted native run passed. A later full `swift test --parallel` attempt was
not accepted as release evidence because the shared checkout changed during
the build and reported unrelated concurrent native errors in `AppStorage`,
redaction action wiring, safe-subscript syntax, and a MainActor notification
closure. Those source changes belong to the concurrent workspace state and
were not overwritten here.

## Deliberate evidence boundary

The runtime and contracts are built. The following are still measured claims,
not missing architecture:

- Keychain loss and OS-level secure deletion recovery behavior.
- Browser quota and eviction behavior across browser families and devices.
- Native interactive accessibility and independent-viewer reopen evidence for
  every newly introduced operation.
- Corpus-backed provider evidence for OCR accuracy, text-run preservation,
  permanent redaction, cryptographic signature validity, XFA, PDF/UA, and
  companion engines.

Those gates remain active implementation and measurement work. They do not
remove any lane from the long-term PDF reader/editor program.
