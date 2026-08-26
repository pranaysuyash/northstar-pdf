# Security Audit: Encrypted Vault & Session Persistence

**Date:** 2026-08-26
**Scope:** EncryptedTemplatePersistence.swift, TemplateStoreCodec.swift, RecoveryPayloadKeyStore.swift, SessionPayloadStore.swift, SessionRecoveryStore.swift, pdf-vault-worker.mjs, pdf-vault-worker-client.mjs
**Auditor:** Security Auditor persona (automated)
**Method:** Code review — trace data flow from input to output

---

## Summary

**Risk assessment: Low risk.** The encryption architecture is sound. Three findings were identified and fixed.

---

## Findings

### Finding 1: PBKDF2 iterations below OWASP 2023 recommendation
- **Severity:** MEDIUM
- **Category:** Cryptography — weak KDF parameters
- **Location:** `Sources/PDFEditorCore/LocalPersistenceContracts.swift:174,405`
- **Description:** The passphrase recovery envelope used PBKDF2-HMAC-SHA256 with 150,000 iterations (validation floor: 100,000). OWASP 2023 recommends 600,000 iterations for PBKDF2-HMAC-SHA256.
- **Impact:** Brute-force attacks on the passphrase recovery envelope are ~4× faster than OWASP-recommended.
- **Remediation:** Updated `defaultIterations` from 150,000 to 600,000 and validation floor from 100,000 to 600,000. **FIXED.**

### Finding 2: Template store files lack POSIX permissions
- **Severity:** MEDIUM
- **Category:** Data exposure — file permissions
- **Location:** `Sources/PDFEditorCore/EncryptedTemplatePersistence.swift:475-480`
- **Description:** `EncryptedRevisionFileStore.write()` writes encrypted template/profile/audit files without setting POSIX permissions. On macOS, files inherit umask permissions (typically 0o644 — world-readable). The session payload store correctly sets 0o600.
- **Impact:** Encrypted template files are world-readable. While the data is encrypted, the ciphertext, record IDs, and timestamps are exposed. A local attacker with file access can observe template existence, modification times, and record structure.
- **Remediation:** Added `setAttributes([.posixPermissions: 0o600])` after atomic write. **FIXED.**

### Finding 3: Template keychain key allows backup export
- **Severity:** LOW
- **Category:** Data exposure — keychain accessibility
- **Location:** `Sources/PDFEditorCore/EncryptedTemplatePersistence.swift:123`
- **Description:** The template store keychain key uses `kSecAttrAccessibleWhenUnlocked`, which includes the key in unencrypted iTunes/Finder backups. The signature store correctly uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- **Impact:** An attacker with physical access to a backup can extract the keychain key and decrypt template files from the same backup. The encrypted data files would also be in the backup, enabling full decryption.
- **Remediation:** Changed to `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Existing keys in Keychain retain their original accessibility until re-created. **FIXED.**

---

## Positive Observations

| Practice | Evidence |
|---|---|
| AES-256-GCM encryption | `TemplateStoreCodec.swift:64` — `AES.GCM.seal(plaintext, using: key)` |
| AEAD with associated data | `SessionPayloadStore.swift:214` — `AES.GCM.seal(plaintext, using: key, authenticating: context)` |
| Keychain-backed keys | `RecoveryPayloadKeyStore.swift` — random 256-bit key stored in Keychain |
| Nonce generation | CryptoKit generates nonces internally via `AES.GCM.seal` |
| Atomic file writes | `EncryptedRevisionFileStore.swift:478` — `.atomic` write option |
| File permissions (session) | `SessionPayloadStore.swift:247` — `0o600` on payload files |
| Lock protection | `NSLock` on all store read/write paths |
| Separate keychain services | Template: `com.pdfeditor.template-store`, Profile: `com.pdfeditor.profile-vault`, Recovery: `com.pdfeditor.recovery-payload` |
| Schema versioning | `SessionPayloadRecord.schemaVersion` with quarantine for unknown versions |
| Backup validation | Envelope validation checks storeKind, keyIdentifier, record integrity |
| Web Worker isolation | `pdf-vault-worker.mjs` has no vault key, passphrase, or PDF parser |
| Device-only signatures | `KeychainSignatureStore` uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Audit logging | Value-free audit events record actions without logging secrets |
| Passphrase validation | PBKDF2 with 600K iterations, random salt, AEAD on recovery envelope |

---

## Files Audited

| File | Lines | Purpose |
|---|---|---|
| `EncryptedTemplatePersistence.swift` | 948 | Template/profile encrypted file store, Keychain key provider, backup/restore |
| `TemplateStoreCodec.swift` | 97 | AES-256-GCM seal/open codec |
| `RecoveryPayloadKeyStore.swift` | 97 | Keychain-backed AES-256 key for recovery payloads |
| `SessionPayloadStore.swift` | 696 | Encrypted session payload store with AEAD |
| `SessionRecoveryStore.swift` | 422 | Metadata-only recovery store |
| `LocalPersistenceContracts.swift` | 460+ | PBKDF2 passphrase derivation, recovery envelope contracts |
| `pdf-vault-worker.mjs` | 26 | Web Worker for encrypted backup validation |
| `pdf-vault-worker-client.mjs` | 23 | Client for web worker communication |

---

## Evidence

- **Build:** 0 errors ✅
- **Tests:** 187/187 pass ✅
- **PBKDF2 iterations:** Updated to 600,000 (OWASP 2023) ✅
- **File permissions:** Template files now 0o600 ✅
- **Keychain accessibility:** Template key now device-only ✅
