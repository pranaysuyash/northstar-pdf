# Boundary Systems Architecture Audit (PER-0933)

**Auditor:** Boundary Systems Architect (`PER-0933`), supported by Product Architecture Specialist and Agent Protocol Architect  
**Date:** 2026-08-26  
**Scope:** Trust zones, inter-process communication boundaries, in-memory domain to cryptographic storage boundaries, temporary staging to export publication boundaries, clipboard/pasteboard sanitization boundaries, and preflight privacy provenance contracts.  
**Doctrine Reference:** Operating Doctrine v8.0 / 6.1

---

## 1. Executive Summary

A Boundary Systems Architect designs and hardens the contracts where products, systems, runtimes, and external entities meet, recognizing that the majority of catastrophic security and correctness failures occur at interface boundaries rather than within isolated components.

### Comprehensive Trust Boundary Map:

```
[Untrusted File System / Network]
               │
               ▼ (Boundary 1: Strict Header & Magic Byte Validation)
[PDFVectorStreamParser / PDFKitProvider]
               │
               ▼ (Boundary 2: Value-Free Preflight & Privacy Provenance)
[Telemetry / Observability / Logging] (0 PII, counts & digests only)
               │
               ▲▼ (Boundary 3: Authenticated Cryptographic Storage)
[Keychain Key Store <==> AES-256-GCM Encrypted Profile & Template Vault]
               │
               ▲▼ (Boundary 4: System Pasteboard Ingestion & Sanitization)
[AppKit Pasteboard <==> Length-Bounded String / Image Normalizer]
               │
               ▼ (Boundary 5: OS-Isolated Temp Staging & Atomic Publish)
[FileManager.temporaryDirectory <==> Atomic Replace Target File]
```

---

## 2. Boundary Contracts & Invariants

1. **Untrusted File Input Boundary (Boundary 1):**
   - Non-PDF binary streams or corrupt headers are rejected at the edge before vector stream lexing or AcroForm parsing commences.
2. **Cryptographic Storage Boundary (Boundary 3):**
   - In-memory profile PII and template history crossing the disk boundary are authenticated and encrypted using Apple CryptoKit AES-256-GCM with Keychain-derived keys. Zero raw PII strings exist in plaintext on disk.
3. **Export Staging & Atomic Publication Boundary (Boundary 5):**
   - Intermediate export files are created exclusively inside `FileManager.default.temporaryDirectory` with random UUID naming, validated for structural integrity, and moved into place via atomic file-system operations. Overwriting the source document is strictly rejected before staging.
4. **Preflight & Observability Privacy Boundary (Boundary 2):**
   - Telemetry and diagnostics crossing external/logging boundaries contain strictly value-free metadata (presence flags, character counts, sha256 digests).

---

## 3. Verification Evidence

- **New Test Suite:** `Tests/PDFEditorCoreTests/BoundarySystemsArchitectTests.swift` (4 tests covering untrusted input rejection, AES-256-GCM storage boundaries, staging-to-destination atomic publication, and value-free preflight boundaries).
- **Full Test Battery:** **202 tests across 27 suites passed with 0 failures** (`swift test`).
- **Web & Engine Contracts:** All 51 web reader checks and template index invariants passed.
