# Local Persistence Product Surface Evidence

**Date:** 2026-08-25  
**Status:** Implemented native and browser product surfaces; browser runtime
proof passed; native package-wide verification is currently blocked by an
unrelated pre-existing AppKit/PDFKit compile failure.  
**Scope:** backup download/import, lost-passphrase messaging, quota and
persistence education, deletion confirmation and audit presentation, native
Keychain custody, native profile unlock, ciphertext-only worker validation,
and cross-device recovery.

## Product result

The native and web apps now expose the recovery lifecycle as explicit user
actions. A vault is never silently recreated after a wrong passphrase or
suspected browser eviction, and no recovery action mutates the source PDF.

The shared lifecycle is:

```text
encrypted local records
        |
        +--> encrypted backup export/import
        |
        +--> separate key-recovery envelope
        |
        +--> cross-device bundle
                 |
                 +--> validate ciphertext structure
                 +--> recover vault key with recovery passphrase
                 +--> restore encrypted records
                 +--> re-key destination vault
                 +--> unlock profiles separately
```

The cross-device bundle is a transport envelope, not a sync service. It
contains encrypted records and a separately passphrase-protected key envelope;
it contains no source PDF bytes, plaintext template values, plaintext profile
values, or recovery passphrase.

## Surface inventory

| Surface | Native macOS | Browser | Evidence state |
| --- | --- | --- | --- |
| Encrypted template backup export | `NSSavePanel`, Keychain-backed store | JSON download | Implemented |
| Encrypted template backup import | `NSOpenPanel`, replace confirmation | File picker, replace confirmation | Implemented |
| Profile vault backup | Separate Keychain account and file | Profile records remain encrypted inside the local vault backup | Implemented |
| Lost store-passphrase guidance | Native alert and status message | Visible danger status and prompts | Implemented |
| Quota and eviction education | Local-store health and recovery explanation | Usage/quota estimate, eviction warning, backup recommendation | Implemented |
| Deletion confirmation | Native destructive alert | Browser confirmation | Implemented |
| Deletion audit | Value-free native journal presentation | Value-free browser audit snapshot and logging | Implemented |
| Profile unlock | Keychain-authenticated vault plus explicit profile selection | Separate profile passphrase and unlock action | Implemented |
| Backup structure inspection | Native contract validation before import | Ciphertext-only module worker validation | Implemented |
| Cross-device recovery | Paired encrypted backup and recovery file in one explicit bundle | Portable bundle with destination re-key | Implemented |

The native UI keeps template and profile stores separate. The browser local
vault can contain both encrypted template and profile records, but profile
payloads remain protected by a distinct profile passphrase inside the encrypted
record envelope. A template-store passphrase does not unlock profile values.

## Contract and provenance rules

Native contracts are defined in
[`Sources/PDFEditorCore/LocalPersistenceContracts.swift`](../../Sources/PDFEditorCore/LocalPersistenceContracts.swift):

- `pdf-editor.local-store-backup` contains opaque encrypted records only.
- `pdf-editor.encrypted-backup-bundle` groups template records and its
  optional learning stream, or profile records alone.
- `pdf-editor.local-store-recovery` contains encrypted key material and KDF
  metadata, never the passphrase.
- `pdf-editor.local-cross-device-recovery` binds the encrypted backup and
  recovery envelope to one explicitly selected store kind.

Browser counterparts are implemented in
[`web/pdf-template-store.mjs`](../../web/pdf-template-store.mjs),
[`web/pdf-cross-device-recovery.mjs`](../../web/pdf-cross-device-recovery.mjs),
and [`web/pdf-vault-worker-client.mjs`](../../web/pdf-vault-worker-client.mjs).

The following invariants are enforced:

- The source PDF remains outside template/profile persistence.
- Exported records are ciphertext and authenticated metadata, not decoded
  contract payloads.
- Wrong local-store kinds, malformed versions, duplicate record IDs, and
  unauthenticated recovery envelopes are rejected before replacement.
- Native ordinary recovery remains bound to the configured Keychain identity.
- Browser ordinary recovery remains bound to its IndexedDB name.
- Browser cross-device recovery explicitly opts into portability, then
  re-encrypts the destination vault under the supplied recovery passphrase.
- Profile values remain separately locked after template recovery.
- Deletion requires an explicit confirmation and retains only a value-free
  audit event.
- Worker inspection receives encrypted backup structure only. It does not
  receive a passphrase, WebCrypto key, IndexedDB handle, PDF bytes, or
  decrypted record payload.
- Diagnostics are restricted to counters, modes, states, and reason codes.

## Lost passphrase and recovery UX

The UI distinguishes three failure states:

1. A wrong active passphrase. The app keeps the store and asks for the
   passphrase again.
2. A likely browser eviction. The app reports that records are missing and
   directs the user to restore an encrypted backup. It does not create a new
   empty store behind the user’s back.
3. A lost passphrase. The app explains that recovery requires the separately
   exported recovery envelope or cross-device bundle. If both the encrypted
   artifact and its recovery passphrase are lost, the encrypted records are
   intentionally unrecoverable.

The browser education panel exposes current state, usage/quota when the
browser provides it, source retention, eviction behavior, backup guidance,
lost-passphrase behavior, and the worker privacy boundary. The native
preflight panel presents vault health, Keychain-backed access, recovery
availability, and the value-free deletion audit.

## Validation evidence

### Browser runtime

Command:

```text
PDF_PROOF_BASE_URL=http://127.0.0.1:8767/web/index.html \
  node Tests/web_template_security_browser_test.mjs
```

Result:

```text
web template security: store unlock, profile unlock, deletion, eviction recovery, and zero-content logging passed
```

This test now additionally proves:

- a different IndexedDB name can receive a cross-device bundle;
- the ciphertext-only worker reports `plaintextInspected: false`;
- encrypted template and profile records round-trip;
- profile access remains locked until the profile passphrase is supplied;
- the destination vault can be locked and reopened with the recovery
  passphrase after re-keying;
- wrong passphrases, eviction, deletion, and zero-content logging remain
  covered.

JavaScript syntax checks passed for the changed browser modules. The
temporary server was stopped after the run.

### Native source and tests

`swift build --target PDFEditorCore` passed. The new native test coverage is in
[`Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift`](../../Tests/PDFEditorCoreTests/EncryptedTemplatePersistenceTests.swift)
and covers encrypted backup round trips, cross-device bundle encode/decode,
separate profile restoration, plaintext exclusion, and wrong-store rejection.

The package-wide Swift test command currently cannot reach those test cases
because the existing app target fails to compile in
`Sources/PDFEditorApp/DiffComparisonView.swift` with unrelated API errors:
`GroupBoxStyle.inline`, `PDFRect.maxY`, and outdated `NSGraphicsContext`/
`PDFPage.draw` calls. This is recorded as a verification limitation, not a
feature pass. The core target build is the current native source-level proof;
full native runtime evidence must be rerun after that app-target blocker is
repaired.

## Recovery and security limitations

- A downloaded JSON bundle is still sensitive encrypted material and must be
  stored like a password backup. The UI does not claim that encryption makes
  the artifact harmless.
- Browser quota estimates are advisory and can be absent or inaccurate.
- Browser eviction detection relies on a non-sensitive presence marker and
  cannot distinguish every browser storage failure.
- The worker validates structure and does not decrypt. It is not a substitute
  for authenticated restore validation.
- Native Keychain behavior still needs an automated test on a signed,
  sandboxed app installation, including Keychain deletion and reinstall.
- Cross-device recovery is file-mediated. Multi-device synchronization,
  conflict resolution, cloud backup, and account recovery are not implied by
  this implementation.
- Recovery passphrase rotation is supported for the browser destination
  re-key path. Native Keychain key rotation and hardware-backed recovery
  policy remain a separate operational hardening lane.

## Next evidence gates

1. Repair the unrelated native app target compile errors and execute the new
   native backup/profile/cross-device tests.
2. Run signed-app Keychain loss, reinstall, and access-group tests.
3. Exercise browser quota pressure, multi-tab races, interrupted writes, and
   import cancellation.
4. Add corrupt ciphertext, truncated bundle, and wrong recovery-key mutation
   cases to the browser worker and native import suites.
5. Keep all future sync or cloud recovery behind a separate threat model,
   client-encryption design, deletion model, and metadata-leakage review.

