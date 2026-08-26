# Product Evolution Map — PER-0926 — 2026-08-26

**Persona:** `PER-0926 — Product Evolution Architect`
**Core question:** What must remain stable, what should be allowed to evolve, and how do we preserve coherence and user value across successive product generations?
**Scope:** Full product surface — native macOS, web companion, provider contracts, capability lanes, evidence gates.

---

## 1. Stable contracts (must NOT change)

These are the architectural load-bearing walls. Breaking them requires a major version bump, a migration guide, and a deprecated-path grace period.

| Contract | Why stable | Breaking change cost |
|---|---|---|
| **Source-byte immutability** (invariant 1) | Every edit, undo, recovery, and validation claim depends on the original bytes being recoverable. This is the safety boundary. | Catastrophic — invalidates all export validation, undo, and provenance claims |
| **Edit-operation typing** (`EditOperation` enum) | Every provider adapter, mutation gate, validation pipeline, and template system consumes this. Adding a variant is safe; removing or reinterpreting one breaks all adapters. | High — every adapter, gate, and test must be updated |
| **Source-digest binding** (SHA-256 per document) | Stale-source rejection, export validation, and provider admission all depend on this. | High — silent data corruption if relaxed |
| **Candidate evidence model** (suggested/confirmed/rejected/unknown) | User review workflow, completion metrics, and mutation guards depend on these states. Promoting `suggested` to `confirmed` without review violates the safety boundary. | Medium — breaks review workflow and metric gates |
| **Contract envelope versioning** (`major.minor`) | Forward/reject semantics protect against enum-meaning drift. | Medium — breaks cross-version adapter compatibility |
| **Fail-closed default** | Every guard (signature, XFA, encrypted, compressed, malformed) fails closed. Relaxing this for convenience creates a silent-failure surface. | High — security and integrity regression |
| **Privacy-first default** (local processing, zero external requests) | RG-028 is PASS; the network-egression assertion proves this invariant. Relaxing it for any feature requires a new consent flow and egress proof. | High — trust regression |

## 2. Evolution seams (designed for change)

These surfaces are explicitly designed to accommodate new capabilities without breaking existing contracts.

| Seam | Current state | Evolution path |
|---|---|---|
| **Provider adapter registry** | PDFKit (native) + PDF.js/pdf-lib (browser) behind `PDFContractEnvelope` | Add PDFBox, MuPDF, Vision OCR, Tesseract adapters without changing shared contracts |
| **Capability lane registry** | `PDFCapabilityLaneContracts.swift` + `web/pdf-capability-lanes.mjs` with typed states (available/blocked/unknown/unsupported) | Activate lanes as providers prove evidence gates; never remove a lane from the registry |
| **Edit operation kinds** | `.overlayText`, `.nativeFieldValue`, `.textRunReplacement`, `.annotation`, `.pageInsert`, `.applyRedaction`, `.pageDelete`, `.pageRotate` | Add new operation kinds with new enum cases; old adapters reject unknown kinds (fail-closed) |
| **Template system** | Keyed fingerprints, profile stores, revision histories, encrypted persistence | Extend with new matching strategies, sync protocols, and profile-value types |
| **Validation pipeline** | `ValidationReport` with typed checks (source, text, raster, reopen, accessibility) | Add new check kinds; existing checks remain unchanged |
| **UI mode system** | `.read`, `.fill`, `.sign`, `.edit` with preference persistence | Add new modes (e.g., `.review`, `.batch`) without changing existing mode behavior |
| **Corpus governance** | 18-entry manifest with digest binding, privacy/provenance fields | Add new fixture categories; manifest version bumps for schema changes |

## 3. Evolution scenarios (likely product generations)

### Gen 1: Bounded Completion Editor (CURRENT)
- Reader + native field filling + reviewed static suggestions + overlays + export validation
- Provider: PDFKit (native) + PDF.js/pdf-lib (browser)
- Evidence: 244/244 Swift tests, 31 S3 mutations, CI with 4 gates
- Claim: "Bounded local-first completion editor for reviewed PDF forms"

### Gen 2: Companion-Backed Editor (NEXT)
- Add: OCR fallback (Vision + Tesseract), text-run replacement (simple ASCII), batch merge, signature capture, redaction
- Provider: Gen 1 + Vision OCR adapter + Tesseract WASM + companion protocol
- Evidence needed: RG-008/009 (OCR corpus), RG-099 (text-run), RG-118 (redaction), RG-014 (signature), RG-122 (codesign)
- Claim: "Local-first editor with OCR, text replacement, redaction, and signature capture"
- Migration: No contract breaks; new operation kinds + capability lane activations

### Gen 3: Full Platform (MEDIUM-TERM)
- Add: Arbitrary text reflow, XFA handling, PDF/UA authoring, collaboration, hosted processing option
- Provider: Gen 2 + PDFBox/MuPDF adapter + companion installer + hosted lane
- Evidence needed: RG-121 (arbitrary-PDF preservation), RG-120 (PDF/UA authoring), RG-091 (provider admission)
- Claim: "Complete local-first PDF platform with editing, accessibility, and collaboration"
- Migration: Possible contract version bump if enum semantics change; deprecation path for Gen 2 APIs

### Gen 4: Ecosystem (LONG-TERM)
- Add: Plugin system, third-party provider marketplace, cross-device sync, AI-assisted workflows
- Provider: Gen 3 + plugin architecture + sync protocol + AI integration
- Evidence needed: New gates for plugin security, sync integrity, AI output boundaries
- Claim: "PDF platform with extensible provider ecosystem"
- Migration: Major version bump likely; plugin API stability contract needed

## 4. Migration and deprecation policy

### Deprecation rules
1. A capability is never removed from the registry — its state changes to `deprecated` with a migration note.
2. Deprecated capabilities emit a visible runtime warning for 2 major versions before removal.
3. No silent deprecation: every deprecated feature has a documented replacement path.

### Migration strategy
| From → To | Strategy |
|---|---|
| Gen 1 → Gen 2 | Additive: new operation kinds, new adapters, new capability lanes. No existing contract breaks. |
| Gen 2 → Gen 3 | Possible contract version bump (1.x → 2.0) if enum semantics change. Deprecation grace period for any changed payloads. |
| Provider swap (PDFKit → PDFBox) | Provider adapter pattern: shared contracts remain; adapter implementation changes. No user-facing migration. |
| Web companion → standalone | Companion protocol is already designed for independent operation. Browser core remains useful without companion. |

### Concept lifecycle
| Concept | Birth | Maturity | Expected deprecation |
|---|---|---|---|
| `EditOperation` enum | Gen 1 | Gen 1–3 | Never (core contract) |
| `overlayText` kind | Gen 1 | Gen 1–2 | Possibly replaced by text-run replacement for text-like regions |
| `nativeFieldValue` kind | Gen 1 | Gen 1–4 | Never (core form interaction) |
| `textRunReplacement` kind | Gen 2 | Gen 2–4 | May evolve to handle richer text operations |
| Provider adapter interface | Gen 1 | Gen 1–4 | Never (extensibility seam) |
| Template fingerprint matching | Gen 1 | Gen 2–3 | May be superseded by ML-based matching |

## 5. Architectural guardrails

These are fitness functions that prevent architectural drift across generations:

1. **Source immutability is non-negotiable.** No generation may relax this. Every new operation kind must prove it doesn't mutate source bytes outside its declared region.

2. **Provider adapters are interchangeable.** The shared contract must never leak provider-specific types. Adding a provider must not require changes to the UI, edit log, or validation pipeline.

3. **Capability claims require evidence.** A capability is not advertised until its provider, fixture, validator, and failure behavior are all identified. This rule survives every generation.

4. **Fail-closed is the default.** New guards may add pass paths, but removing a fail-closed path requires a documented risk acceptance.

5. **Privacy is per-capability.** Each capability declares its own data-flow boundary (source bytes, extracted text, OCR output, telemetry). No universal "private" claim covers all capabilities.

6. **Contract versions are monotonic.** A contract may only move forward. Reading an older version is always supported; writing an older version is never supported.

7. **Deprecation is visible.** No capability may be deprecated without a runtime warning, a migration guide, and a grace period.

8. **Test coverage tracks capability claims.** Every promoted capability must have at least S1 test evidence; every production claim must have S2 or S3.

## 6. Capability lineage

```
Gen 1 (current)
├── Reader (PDFKit / PDF.js)                    [PASS]
├── Native field filling (incremental writer)    [PARTIAL → PASS for bounded corpus]
├── Static region detection                      [S3 calibrated]
├── Reviewed overlays                            [PASS]
├── Export validation                            [PARTIAL]
├── Undo/recovery                                [PASS]
├── Templates (encrypted, lifecycle)             [PARTIAL]
└── Privacy boundary (egression assertion)       [PASS]

Gen 2 (companion-backed)
├── OCR fallback (Vision + Tesseract)            [OPEN → PARTIAL]
├── Text-run replacement (simple ASCII)          [PARTIAL]
├── Redaction (content removal)                  [PARTIAL]
├── Signature capture (Keychain vault)           [PARTIAL]
├── Batch merge                                  [PARTIAL]
├── Codesign + notarize                          [OPEN]
└── Auto-update                                  [OPEN]

Gen 3 (full platform)
├── Arbitrary text reflow                        [OPEN]
├── XFA handling                                 [PARTIAL]
├── PDF/UA authoring                             [PARTIAL]
├── Collaboration                                [OPEN]
└── Hosted processing option                     [OPEN]

Gen 4 (ecosystem)
├── Plugin system                                [OPEN]
├── Provider marketplace                         [OPEN]
├── Cross-device sync                            [OPEN]
└── AI-assisted workflows                        [OPEN]
```

## 7. Risks and falsifiers

| Risk | Falsifier | Mitigation |
|---|---|---|
| Additive-only growth creates bloat | User-facing complexity exceeds comprehension threshold | Capability activation is opt-in; UI modes scope visible features |
| Provider adapter leaks provider types | Shared contract test fails on a new provider | Contract parity tests run on every provider |
| Deprecation warnings cause alert fatigue | Users stop reading warnings | Warnings are per-feature, not per-session; max 3 concurrent |
| Gen 3 contract bump breaks Gen 2 adapters | Gen 2 adapter fails to decode Gen 3 payloads | Contract envelope rejects future major versions with clear error |
| Privacy boundary erodes as features grow | Network-egression assertion fails | Egress assertion runs in CI; any failure blocks release |

---

*Produced under PER-0926 — Product Evolution Architect lens. This is a strategic evolution map, not an implementation plan. Implementation sequencing is governed by the release gates and evidence thresholds.*
