# Encrypted template lifecycle evidence, 2026-08-25

## Outcome

The reusable PDF completion-template lifecycle is implemented across the native
Swift and browser JavaScript adapters. The source PDF remains authoritative for
every session, while profile values remain separate from layout knowledge. A
template may propose a completion, but it cannot silently autofill, silently
change source bytes, or silently change future template behavior.

The lifecycle is:

```text
source bytes
  -> keyed layout fingerprint
  -> value-free reviewed draft
  -> mapping approval
  -> active immutable mapping revision
  -> explicit profile unlock and value approval
  -> source-digest-bound edit operations
  -> new export and strict validation
  -> pending immutable child revision + pending learning event
  -> explicit encrypted save of the child revision
```

“Automatic revision creation” means that a strictly validated completion creates
the child revision and learning event in the current session automatically. The
child is not persisted or activated for future matching until the reviewer
explicitly saves it. This separates automatic audit materialization from silent
future behavior.

## Implemented surfaces

### Native macOS

- `Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`: AES-GCM
  encrypted template histories, Keychain-backed keys, primary and recovery
  copies, append-only parent-linked revisions, encrypted learning events,
  separate encrypted profile vault, unlock/lock, deletion, import, and
  value-free export.
- `Sources/PDFEditorCore/TemplateLifecycleContracts.swift`: transfer-envelope
  validation, mapping-level revision diff, learning journal identity checks,
  and validated completion child creation.
- `Sources/PDFEditorCore/TemplateSyncContracts.swift`: client-encrypted sync
  envelope and deterministic merge/conflict rejection.
- `Sources/PDFEditorApp/AppModel.swift` and `ContentView.swift`: encrypted
  vault controls, capture, mapping review, activation, profile selection,
  value review, application, export, reopen validation, child revision
  preparation, save, import, delete, and revision-diff status.

### Browser

- `web/pdf-template-contract.mjs`: fingerprint, draft capture, mapping/value
  approval, source binding, operation materialization, validated child
  creation, revision diff, and value-free transfer import/export.
- `web/pdf-template-store.mjs`: encrypted IndexedDB with encrypted profile
  records, backup/restore, eviction detection, deletion, zero-content logs,
  transfer import/export, learning journals, and an encrypted OPFS adapter.
  OPFS preserves locked profile ciphertext while unrelated template writes
  proceed, and exposes the same recovery, deletion, transfer, and journal
  boundaries.
- `web/pdf-template-sync.mjs`: PBKDF2 plus AES-256-GCM client-encrypted sync
  envelopes, value-free validation, parent-graph checks, deterministic merge,
  and conflict abstention.
- `web/index.html`: browser capture, mapping review, profile unlock, value
  review, apply, validated promotion, encrypted persistence, transfer, sync,
  and revision-diff review summary.

## Privacy and provenance invariants

1. Templates contain keyed layout evidence and mapping references, not raw PDF
   bytes.
2. Template transfer envelopes validate
   `containsSourceBytes: false` and `containsProfileValues: false`.
3. Profile values are stored in a separate native vault or separately keyed
   browser records. Templates store semantic references, never resolved values.
4. Profile values require explicit unlock and are not exposed merely because a
   profile record exists.
5. A locked profile remains opaque ciphertext during unrelated OPFS template
   writes and becomes readable only after explicit profile unlock.
6. Mapping approval is separate from profile-value approval. Editing a value or
   changing target resolution invalidates the corresponding approval.
7. Every materialized operation binds to the current source digest and page
   coordinate. Stale, ambiguous, unsupported, or mismatched proposals abstain.
8. A validated child requires strict validation, source unchanged, reopenable
   output, exact source binding, and operation-lineage equality.
9. Failed, unknown, incomplete, or unrelated exports cannot create a learning
   event or child revision.
10. Learning events are append-only, value-free, source-bound, and applied only
    when the reviewer explicitly saves the validated child.
11. Sync encrypts template history and learning events in the client. No sync
    server or network transport is implemented by this change.
12. Diagnostics record state, counters, and error codes, not filenames, labels,
    document text, profile values, source bytes, or screenshots.

## Evidence

### Tier 2 and S3 contract evidence

- `Tests/web_template_contract_test.mjs` passed fingerprint, mapping, profile,
  matcher, transfer, validated-child, diff, and negative checks.
- `Tests/web_template_store_test.mjs` passed store isolation, value-free
  transfer, learning journal, deletion, and source-byte rejection.
- `Tests/web_template_sync_test.mjs` passed client encryption, wrong-passphrase
  rejection, value-free payload checks, deterministic merge, and conflict
  abstention.
- `Tests/reviewed_completion_metrics_mutation_test.mjs` passed silent-autofill
  and invalid-learning-state mutation guards.

### Tier 3 native evidence

`swift test` passed 94 tests in 10 suites. The relevant suite covers encrypted
append-only template history, primary/recovery behavior, separate profile-vault
encryption and deletion, value-free transfer and diff, learning-journal
identity, native sync wrong-key/conflict rejection, and completion approval,
source-binding, stale-state, destructive-operation, coordinate, and unknown-
validation guards.

### Tier 4 browser evidence

An isolated Chrome run served the canonical `web/index.html` on port 4783 and
passed `Tests/web_template_browser_test.mjs`. It exercised PDF.js fingerprint
creation, visible mapping review, separate value review, source-bound operation
materialization, encrypted IndexedDB template/profile round-trip, profile
deletion, encrypted OPFS round-trip, encrypted backup, absence of the profile
value in the backup, template writes with a locked profile preserved as opaque
ciphertext, explicit profile unlock, OPFS deletion, and no console or page
errors. The isolated server and browser were stopped after verification. The
default port was not used because it was occupied by an unrelated application.

### Related parity and benchmark evidence

The broader matrix also passed reviewed 24-case matching and correction
benchmarks, hard-negative mutation gates, scanned-class abstention,
native/browser fingerprint parity over 18 fixtures, native/browser semantic
parity with 18 fixtures and 6 declared mismatches, privacy provenance,
preflight, and contract negative suites.

## Remaining unknowns and hardening

These are operational, provider, or deployment gates, not omitted contract
features:

- browser-family quota pressure and real eviction on Safari, Chromium, Firefox,
  and mobile profiles;
- OPFS concurrency and interrupted-write recovery;
- Keychain loss, passphrase loss, and recovery-key UX;
- native SwiftUI interactive accessibility evidence;
- sync transport retention, device revocation, and recovery-key design if a
  service is added;
- secure deletion guarantees across OS backups, browser snapshots, and exported
  encrypted backups;
- independent-viewer proof for exports produced after template completion;
- OCR, XFA, signed-document, redaction, and high-fidelity provider evidence.

The next hardening step is to run this lifecycle under quota loss, interrupted
writes, Keychain loss, profile revision changes, and independent-viewer export
comparison, retaining every outcome in the evidence ledger without weakening
any abstention gate.

