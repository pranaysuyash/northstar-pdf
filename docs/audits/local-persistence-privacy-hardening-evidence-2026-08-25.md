# Local persistence privacy hardening evidence, 2026-08-25

## Outcome

Native and browser local persistence now expose an explicit recovery and
privacy boundary instead of treating encrypted storage as self-describing
backup.

The implemented lifecycle is:

```text
read-only PDF preflight
  -> local encrypted store health
  -> explicit unlock
  -> reviewed record write
  -> encrypted backup and separate key-recovery export
  -> explicit import or restore
  -> value-free deletion audit
```

The source PDF remains outside the template and profile stores. No recovery
operation mutates the source PDF, creates a PDF edit operation, or approves a
template mapping or profile value.

## Native implementation

The native adapter uses separate encrypted template and profile directories,
AES-GCM record encryption, and Keychain-backed key custody.

Implemented contracts and behavior:

- `PDFLocalStoreHealth` reports `uninitialized`, `ready`, `recovered`,
  `deleted`, and `unknown` states, plus primary/backup availability, record
  count, audit count, recovery-envelope availability, and a message code.
- `PDFLocalStoreRecoveryEnvelope` is a versioned
  `pdf-editor.local-store-recovery` envelope. It wraps the native store key
  with a separate PBKDF2-HMAC-SHA256 passphrase and AES-GCM authentication.
- Recovery passphrases require at least 12 characters. The app never stores,
  logs, or displays the passphrase after the modal action completes.
- Template transfer remains value-free and explicit. Profile recovery is a
  key-recovery operation and does not create a readable profile export.
- Record deletion and whole-vault record deletion append a value-free audit
  event. The audit uses a one-way SHA-256 record token rather than a raw
  template/profile identifier.
- Whole-vault record deletion retains the audit journal while deleting
  templates, learning events, or profile records. This is deletion evidence,
  not a claim of forensic erasure from Keychain, filesystem snapshots, or
  operating-system backups.
- The SwiftUI inspector visibly reports source preflight, processing
  locality, OCR state, source retention, sanitization limits, encrypted-store
  health, recovery availability, and the latest value-free audit action.
- Recovery and destructive deletion are confirmation-gated actions. A
  recovery envelope cannot silently replace a different existing Keychain
  key.

Primary files:

- `Sources/PDFEditorCore/LocalPersistenceContracts.swift`
- `Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`
- `Sources/PDFEditorRecovery/AppModel.swift`
- `Sources/PDFEditorApp/ContentView.swift`

## Browser implementation

The active browser product path uses an encrypted IndexedDB store. The store
uses a random AES-GCM key, a passphrase-derived metadata key, and a separate
passphrase-derived recovery key.

Implemented browser behavior:

- Explicit encrypted vault backup export and replace-confirmed restore.
- Separate passphrase key-recovery envelope export and import.
- Recovery after IndexedDB eviction distinguishes key recovery from record
  recovery. A recovered key with missing records remains `evicted` and tells
  the user to restore the encrypted backup.
- A non-sensitive presence marker detects the common eviction case. If the
  browser removes both the database and marker, the platform cannot prove
  whether the state was first use or eviction, so the UI retains an unknown
  state rather than inventing certainty.
- Value-free deletion audit entries are kept in a bounded local audit journal.
  Entries contain an opaque record token, action, outcome, state, reason code,
  and timestamp. They contain no document text, filename, PDF bytes, profile
  value, URL, screenshot, or passphrase.
- Health reports include `evictionWarning`, `recoveryEnvelopeAvailable`,
  `sourceRetention: "none"`, `contentLogging: "zero-content"`, quota/usage
  estimates when available, and a recommended recovery action.
- The template panel exposes store health, encrypted backup export/restore,
  key-recovery export/import, and confirmed vault deletion.
- The visible PDF preflight panel states local-browser processing, network
  and companion request counts, OCR state, source retention, sanitization
  limits, and the zero-content diagnostic boundary.

Primary files:

- `web/pdf-template-store.mjs`
- `web/app.js`
- `web/index.html`
- `Tests/web_template_security_browser_test.mjs`

The separate OPFS adapter now exposes the same passphrase key-recovery
envelope shape, store binding, wrong-passphrase rejection, and evicted-record
state as the IndexedDB adapter. Its recovery-envelope availability is also
reported by OPFS health after an explicit export. The active product panel is
still wired to IndexedDB, so OPFS recovery UI, durable OPFS audit persistence,
and cross-browser runtime evidence are not promoted as equivalent yet.

## Privacy and provenance rules

The visible preflight and persistence health surfaces use different contracts:

- PDF preflight describes observed metadata, embedded-data indicators,
  annotations, scripts, revisions, network boundaries, active-content tokens,
  encryption, unknown coverage, and sanitization limits.
- Session provenance describes processing locality, OCR use, source retention,
  export provenance, and validation state.
- Persistence health describes encrypted local record custody, backup and
  recovery state, quota/eviction condition, and value-free deletion audit.

None of these reports is allowed to claim that a PDF is sanitized merely
because it was inspected or stored encrypted. Sanitization remains a new-copy
operation with its own provider, reopen, independent-viewer, and data-loss
gates.

## Evidence run

Native:

```text
swift test --filter EncryptedTemplatePersistenceTests --parallel
5 tests passed

swift test --parallel
102 tests passed in 12 suites
```

The native recovery test proves wrong-passphrase rejection, recovery-envelope
passphrase exclusion, recovered-key access, health reporting, whole-record
deletion, retained audit evidence, and absence of raw identifiers in audit
tokens.

The 102-test, 12-suite native run recorded before the concurrent recovery
target was introduced was green. A later whole-package rerun in the current
dirty checkout was not promotable because the separate `PDFEditorRecovery`
target now fails to compile: its public `AppModel` initializer exposes
internal `SessionPayloadStore` and `RecoveryPairStore` types. This is retained
as a current workspace integration failure, not attributed to the local
template persistence tests.

Browser source and isolated runtime:

```text
node --check web/app.js
node --check web/pdf-template-store.mjs
node Tests/web_template_store_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:8766/web/index.html \
  node Tests/web_template_security_browser_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:8766/web/index.html \
  node Tests/web_preflight_browser_test.mjs
PDF_PROOF_BASE_URL=http://127.0.0.1:8766/web/index.html \
  node Tests/web_reader_contract_test.mjs
```

Results:

- Browser security fixture passed store unlock/lock, separate profile unlock,
  encrypted backup exclusion, key-recovery export/import, wrong-recovery
  rejection, simulated IndexedDB eviction, key recovery with evicted records,
  backup restore, deletion, audit presence, and zero-content logging.
- Browser preflight fixture passed source binding, report emission, visible
  UI boundary, and zero-content provenance checks.
- Browser reader and completion contract passed 51 checks and boot smoke.
- A transient isolated Chrome OPFS probe passed recovery-envelope availability,
  wrong-passphrase rejection, recovered-key state, and explicit-deletion state.
  This is adapter evidence only, not cross-browser or product-panel evidence.
- Port 4173 was intentionally rejected as evidence because it served another
  Vite project. The isolated static server on port 8766 served this checkout's
  `/web/index.html` and the expected fixture surface.

## Remaining gates

These are implementation and evidence gates, not product-scope exclusions:

- OPFS recovery UI, durable OPFS audit persistence, and cross-browser runtime
  evidence equivalent to the active IndexedDB path.
- Browser-family quota pressure and real eviction across Safari, Chromium,
  Firefox, and low-storage mobile profiles.
- Interrupted IndexedDB/OPFS writes, multi-tab conflicts, and crash recovery.
- Native Keychain item loss or replacement recovery after the user has only a
  recovery envelope and no live Keychain key.
- Encrypted backup interoperability between native and browser adapters.
- Explicit profile-value export/import policy. Current profile recovery wraps
  the vault key, while readable values remain inside the separately encrypted
  profile vault.
- Secure deletion behavior across filesystem snapshots, browser backups,
  Keychain history, exported files, and user-managed copies.
- Automated native SwiftUI accessibility interaction and passphrase modal
  coverage.
- A user-visible recovery checklist and backup freshness reminder based on
  the health/audit contracts.

This record is evidence for the local persistence hardening slice. It does
not promote encrypted local storage into a universal privacy, sanitization,
secure-erasure, or account-recovery claim.
