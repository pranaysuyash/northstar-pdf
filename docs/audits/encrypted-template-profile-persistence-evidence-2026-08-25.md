# Encrypted Template and Profile Persistence Evidence

Date: 2026-08-25  
Scope: native macOS and browser local persistence for reviewed PDF templates and separate profile values  
Evidence class: implementation plus focused runtime tests

## Result

Encrypted local persistence is implemented in both adapters.

The shared rule is:

```text
reviewed contract
  -> append-only revision set
  -> authenticated encrypted local record
  -> primary plus recovery copy
  -> explicit load state
```

The source PDF is not part of either store. A template stores layout evidence,
fingerprints, and reviewed mappings. A profile vault stores semantic values.
The two stores use different storage namespaces and different encryption keys.

## Native implementation

Native persistence is in
[`Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`](../../Sources/PDFEditorCore/EncryptedTemplatePersistence.swift).

`EncryptedPDFTemplateStore` persists the existing
`PDFTemplateRevisionSet` contract. It does not introduce a parallel template
history type. `EncryptedPDFProfileVault` persists a separate
`PDFProfileRevisionSet` containing `PDFProfileContract` revisions.
`PDFEditorApp.AppModel` now uses this vault through a `UserProfile`
compatibility projection, so native profile creation, loading, saving, listing,
and deletion take the revision-preserving vault path. The older
`EncryptedProfileStore` remains as a compatibility implementation and test
fixture, but is no longer the app model's active profile path.

Both stores use the existing `PDFTemplateStoreCodec` AES-GCM implementation.
Production keys are generated and retrieved through Keychain accounts:

| Store | Directory | Keychain service | Record kind |
|---|---|---|---|
| Templates | `PDFEditor/Templates` | `com.pdfeditor.template-store` | `template` |
| Profile vault | `PDFEditor/ProfileVault` | `com.pdfeditor.profile-vault` | `profile` |

Tests inject deterministic 256-bit keys so the behavior is testable without
making test results depend on Keychain state. Production initialization uses
Keychain when no test key is supplied.

Each record is written as an authenticated encrypted envelope. The primary
record is copied to a `.backup.json` recovery file before a new primary is
atomically installed. A failed primary read attempts the backup, promotes the
authenticated backup back to primary, and returns
`recoveredFromBackup`. If both copies fail authentication, the store returns a
fail-closed corruption error.

## Browser implementation

Browser persistence is in
[`web/pdf-template-store.mjs`](../../web/pdf-template-store.mjs).

The browser store uses IndexedDB for encrypted records. The store passphrase is
expanded with PBKDF2-HMAC-SHA-256 and used for AES-256-GCM record envelopes.
Profile and profile-history payloads are additionally sealed with a
profile-specific PBKDF2/AES-GCM key. Browser profile values therefore do not
become readable merely because the template-store envelope was opened.

The live page no longer writes plaintext profile objects to the former
`pdf-editor-profiles` IndexedDB database. The profile panel now uses the
encrypted profile-history API. Persistence is explicit:

- `Save encrypted revision` persists a reviewed template revision.
- `Unlock encrypted local profiles` unlocks the profile vault.
- Profile edits append a new profile contract revision.
- Page load does not prompt for or silently retain a passphrase.
- Zero-content diagnostics retain only approved event, code, kind, mode, state,
  and count fields.

The existing browser health model reports `uninitialized`, `ready`, `locked`,
`evicted`, `closed`, and `deleted` states. Encrypted backups can be exported
and restored after IndexedDB eviction. Restore is explicit and refuses to
overwrite a non-empty store unless `replace` is requested.

## Revision and deletion invariants

Both adapters enforce these invariants before persistence:

1. A revision ID is unique within its history.
2. A child revision names a parent already present in history.
3. Template and profile identity cannot change across a history.
4. Earlier revisions are not rewritten when a correction is appended.
5. Template payloads cannot contain source PDF bytes.
6. Profile values are not copied into template records.
7. Deleting a template removes the aggregate and its recovery copy.
8. Deleting a profile removes the profile aggregate and its recovery copy.
9. Wrong keys or passphrases cannot be converted into an empty result.
10. Recovery is visible as a state, not silently presented as a healthy primary.

Deletion removes the local persistence artifact. It does not claim secure
forensic erasure from storage media, browser snapshots, operating-system
backups, or Keychain history. That remains a separate sanitization and secure
deletion capability lane.

## Evidence

Native:

```text
swift test --filter EncryptedTemplatePersistenceTests
2 tests passed
```

The native tests prove:

- AES-GCM ciphertext does not contain template or profile values;
- two template revisions round-trip as immutable history;
- missing revision parents are rejected;
- primary corruption recovers the last authenticated backup;
- the recovery state is `recoveredFromBackup`;
- a reopened store sees the promoted recovery copy;
- template deletion removes the history and ID;
- profile history uses a separate directory and key;
- a wrong profile key cannot read the vault;
- profile deletion removes the profile history;
- template and profile stores remain independent.

Browser:

```text
node Tests/web_template_store_test.mjs
node Tests/web_template_contract_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html node Tests/web_template_security_browser_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html node Tests/web_template_browser_test.mjs
```

The focused browser result passed for:

- template and profile revision history APIs;
- stale parent rejection;
- separate profile unlock and wrong-passphrase rejection;
- encrypted backup content exclusion;
- IndexedDB eviction detection and encrypted backup recovery;
- template/profile deletion;
- zero-content event filtering;
- live page loading after replacing plaintext profile persistence;
- reviewed template capture and exact reviewed proposal behavior.

## Limits and next gates

This evidence does not claim:

- secure deletion from all OS or browser backup layers;
- recovery after a damaged Keychain item;
- multi-device synchronization;
- cross-platform encrypted backup byte parity;
- passphrase recovery or account recovery;
- browser quota exhaustion under large real-world histories;
- concurrent multi-tab conflict resolution;
- native SwiftUI template/profile persistence screens;
- hardware-backed Keychain access controls beyond the configured Keychain
  accessibility class.

These are active implementation lanes. They do not weaken the current
invariants: source bytes stay outside the stores, profile values stay outside
template records, and persistence never grants permission to mutate a future
PDF without a new reviewed source-bound session.
