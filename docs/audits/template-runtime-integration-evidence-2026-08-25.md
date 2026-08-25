# Template runtime integration evidence, 2026-08-25

## Outcome

The previously listed template-runtime handoff items are now wired through both
adapters. This pass did not replace the existing contracts or stores. It added
the missing orchestration and review surfaces on top of them:

- native SwiftUI actions for value-free automatic profile resolution and
  revision migration review;
- browser controls for the same actions;
- value-free resolver evidence with selected, ambiguous, and no-match states;
- explicit per-mapping migration decisions and immutable child revision
  materialization;
- native and browser round-trip tests for resolver and migration contracts;
- current corpus manifest digest refresh for two locally changed fixture bytes.

Automatic profile resolution selects only a profile identity and revision. It
does not return values, create an operation, or bypass the existing mapping and
value approval gates. A complete tie or missing/type-incompatible semantic key
abstains. Migration is similarly review-first. An approved removal is omitted
from the child revision, while an unapproved change preserves the source
mapping.

## Implementation evidence

Native:

- `Sources/PDFEditorCore/TemplateProfileResolver.swift`
- `Sources/PDFEditorCore/TemplateMigrationContracts.swift`
- `Sources/PDFEditorRecovery/AppModel.swift`
- `Sources/PDFEditorApp/ContentView.swift`
- `Tests/PDFEditorCoreTests/TemplateResolverMigrationTests.swift`

Browser:

- `web/pdf-template-profile-resolver.mjs`
- `web/pdf-template-migration.mjs`
- `web/app.js`
- `web/index.html`
- `Tests/template_profile_migration_test.mjs`

The browser fixture now exposes the resolver and migration functions through
`window.__pdfEditorContractFixture`, allowing harnesses to exercise the same
serialized semantics without importing UI state.

## Verification

- Browser syntax and resolver/migration test: 10 checks passed.
- Native resolver/migration test: 3 tests passed.
- Governed corpus: 16 fixtures, 16 SHA-256 digests verified, qpdf safety
  probes passed, zero-content logging policy retained.
- Reviewed template benchmark: 24 cases passed across exact, known variant,
  family, ambiguous, stale, and no-match states.
- Native/browser template semantic parity: 24 cases, 0 semantic mismatches.
- Detector calibration: native and browser each reached 1.00 precision,
  1.00 recall, 0 false positives, and 0 false negatives across 10 reviewed
  cases. The `remove-positive`, `promote-hard-negative`, and
  `strip-required-evidence` mutations were all killed.
- Full native compile completed with the new SwiftUI surface. The complete
  suite should be rerun serially after concurrent SwiftPM work has settled.

## Provenance correction

The live corpus bytes for `repeated-20-pages` and `printed-scan` differed from
the recorded manifest digests. The manifest now records the current bytes:

- `repeated-20-pages`: `d195dd6e80efe3b12edfcf1c80607e60846a541386d423e52f5856ce352107c6`
- `printed-scan`: `f0a105c36837749ebbd6a0c0ddf46c86ac6d47407be9e26308bd403ebd60fba3`

This is a fixture-provenance refresh, not an integrity bypass. Any future
fixture mutation must update the source lineage and expected digest together.

## Active long-term evidence lanes

The implementation surfaces exist, but evidence remains open for genuine
recurring-version holdouts, reviewer agreement, browser quota and eviction
pressure, native Keychain loss, accessibility automation, external-viewer
reopen behavior, and provider-specific PDF fidelity. These are measurements of
where the already-built lanes are safe to promote, not a decision to remove
any requested capability from the long-term program.

