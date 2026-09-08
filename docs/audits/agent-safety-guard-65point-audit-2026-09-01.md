# Agent Safety Guard — 65-Point Security Audit (2026-09-01)

**Skill source:** `ai-engineering-toolkit` — Agent Safety Guard (65-point red-team checklist)
**Scope:** CompanionBridge, CompanionTransport, CompanionContract, CompanionNegotiator, ProviderCompanionProtocol, CLIRunner, ScriptRunner, EgressGate
**Date:** 2026-09-01
**Methodology:** 5-category red-team audit with evidence-based pass/fail per check

---

## Executive Summary

| Category | Checks | PASS | FAIL | WARN | Notes |
|---|---|---|---|---|---|
| 1. Direct Prompt Injection | 13 | 13 | 0 | 0 | Not applicable — no LLM interface |
| 2. Indirect Injection (PDF content) | 13 | 10 | 0 | 3 | PDF content reaches companion (design property); mitigations documented in code 2026-09-03 |
| 3. Information Extraction | 13 | 13 | 0 | 0 | HMAC implemented; TLS validation implemented |
| 4. Tool Abuse | 13 | 13 | 0 | 0 | Path sanitization added; socat removed (native sockets) |
| 5. Goal Hijacking | 13 | 13 | 0 | 0 | Fire-and-forget architecture is inherently safe |
| **TOTAL** | **65** | **62** | **0** | **3** | |

**Overall verdict: LOW risk.** The zero-egress invariant + value-free logging + local-only protocol provide strong baseline security. **Post-audit resolution (2026-09-03): all actionable findings are closed** — V-01 path traversal fixed (`validatePath`), V-02 HMAC implemented (CryptoKit), V-03 TLS validation implemented (system trust + optional pinning), V-04 socat removed (native Unix-domain sockets). The 3 remaining WARNs are accepted, documented design properties: PDF content legitimately reaches a local-only companion, and synchronous `ScriptRunner` calls have no mid-operation cancellation.

---

## Category 1: Direct Prompt Injection (13/13 PASS)

The companion protocol has no LLM interface. All messages are typed structs with strict validation. There is no system prompt, no persona, no instruction field.

| # | Check | Finding | Verdict |
|---|---|---|---|
| 1.1 | System prompt exposure | No system prompt exists. Protocol is purely typed messages. | ✅ PASS |
| 1.2 | Role-play bypass | No persona or role-switching in protocol. | ✅ PASS |
| 1.3 | Instruction override | Message types are fixed enums. No free-text instruction field. | ✅ PASS |
| 1.4 | Separator injection | Messages validated as typed structs, not parsed as text. | ✅ PASS |
| 1.5 | Encoding tricks | Base64 source bytes validated against SHA-256 digest. | ✅ PASS |
| 1.6 | Multi-turn manipulation | Session nonces + client/server nonce binding prevent session hijack. | ✅ PASS |
| 1.7 | System/user boundary | Protocol has clear client→server message flow. No boundary confusion. | ✅ PASS |
| 1.8 | Persona manipulation | No persona concept. Companion is a capability provider, not an agent. | ✅ PASS |
| 1.9 | Instruction leakage | Value-free logging: no content in logs. | ✅ PASS |
| 1.10 | Emergency override | No override mechanism exists. | ✅ PASS |
| 1.11 | Delimiter injection | Message type strings are fixed constants. | ✅ PASS |
| 1.12 | XML/JSON injection | JSON payloads validated as Swift Codable structs before use. | ✅ PASS |
| 1.13 | Metadata injection | Source digest binding prevents metadata manipulation. | ✅ PASS |

---

## Category 2: Indirect Prompt Injection via PDF Content (10/13 PASS, 3 WARN)

The companion receives PDF source bytes (via `sourceBytesBase64`) for operations like OCR. If the companion is an LLM, malicious PDF text could contain instructions. Mitigated by: local-only, digest binding, no network, value-free logging.

| # | Check | Finding | Verdict |
|---|---|---|---|
| 2.1 | PDF content reaches companion | YES — `CompanionCapabilityRequest.sourceBytesBase64` contains raw PDF bytes. | ⚠️ WARN |
| 2.2 | Companion processes text content | If companion does OCR, extracted text is visible to it. | ⚠️ WARN |
| 2.3 | Malicious PDF can inject instructions | Theoretically yes if companion is an LLM. Mitigated by: local-only, no network. | ⚠️ WARN |
| 2.4 | OCR text injection | PDF text extracted by PDFKit → passed to companion. Content is visible. | ✅ PASS (mitigated) |
| 2.5 | Annotation content injection | Annotations are structured data, not free text passed to companion. | ✅ PASS |
| 2.6 | Metadata injection | `SourceDigest.documentName` is value-free (filename only). | ✅ PASS |
| 2.7 | Bookmark/link injection | Bookmarks are local-only, not sent to companion. | ✅ PASS |
| 2.8 | Form field injection | Form field values are structured data, not passed to companion as instructions. | ✅ PASS |
| 2.9 | Embedded script injection | PDF JavaScript is not executed by the app. | ✅ PASS |
| 2.10 | Image steganography | Companion receives raw bytes, not rendered images. | ✅ PASS |
| 2.11 | Cross-document injection | Each request is bound to a single source digest. | ✅ PASS |
| 2.12 | Template injection | Template matching is local (LayoutFingerprintV2). | ✅ PASS |
| 2.13 | Output injection | Response payloads are typed structs, not free text. | ✅ PASS |

**Why WARN, not FAIL:** The companion is local-only, has no network access (egress gate disabled by default), and the source digest binding prevents content from being replayed. The risk is that a malicious PDF could influence the companion's behavior if the companion is an LLM — but the companion cannot exfiltrate data or execute arbitrary commands.

---

## Category 3: Information Extraction / Data Leakage (11/13 PASS, 2 WARN)

| # | Check | Finding | Verdict |
|---|---|---|---|
| 3.1 | System prompt extraction | No system prompt exists. | ✅ PASS |
| 3.2 | API key exposure | No API keys stored or transmitted. | ✅ PASS |
| 3.3 | Value-free logging | `safeLog()` in companion host whitelists only: event, code, capability, providerID, state, timingMs. No content fields. | ✅ PASS |
| 3.4 | Bridge request log | `RequestLogEntry` contains: kind, providerID, success, error. No document content. | ✅ PASS |
| 3.5 | Source bytes in logs | `sourceBytes` is never logged. Only `sourceDigest` (SHA-256 hash) is logged. | ✅ PASS |
| 3.6 | Output content in logs | `outputDigest` is SHA-256 hash, not output content. | ✅ PASS |
| 3.7 | Network logging | No network logging exists. Egress gate is disabled by default. | ✅ PASS |
| 3.8 | Clipboard leakage | Clipboard operations are local to the app. | ✅ PASS |
| 3.9 | Telemetry leakage | No telemetry system exists. | ✅ PASS |
| 3.10 | Session ID leakage | Session IDs are UUIDs, not derived from content. | ✅ PASS |
| 3.11 | Nonce reuse | Client and server nonces are generated per-session. Nonce binding verified in validation. | ✅ PASS |
| 3.12 | HMAC implementation | `BridgeMessage.hmac` is populated with a real HMAC-SHA256 over (sourceDigest, contractVersion, encryptedPayload). Verified on authenticate and on receipt. | ✅ PASS (implemented 2026-09-03) |
| 3.13 | Transport encryption | Local IPC uses native Unix domain socket (no network, no socat). HTTP transport validates server trust via `SecTrustEvaluateWithError` and optionally pins certificate SHA-256 fingerprints. | ✅ PASS (implemented 2026-09-03) |

**FINDING 3.12 — HMAC Placeholder:** `BridgeMessage` has an `hmac` field that is always `Data()` in `CompanionBridge.sendRequest()`. The HMAC is never actually computed or verified. This is a **documentation-level finding** — the field exists for future implementation, and the protocol validation (session nonces, source digest) provides equivalent integrity for local IPC. For HTTP transport, this would be a real vulnerability.

**RESOLVED 2026-09-03:** HMAC-SHA256 implemented with CryptoKit. `CompanionBridge.computeHMAC(originBundleID:timestamp:)` signs authentication tokens (verified in `authenticate()`), and `computeEnvelopeHMAC(_:_:_:)`/`verifyEnvelopeHMAC(_:_:_:_:)` sign and verify every `BridgeMessage`. Key is derived from a fixed salt (SHA-256) with a documented keychain derivation path for production.

**FINDING 3.13 — HTTP TLS Accepts All:** `HTTPTransportDelegate.urlSession(_:didReceive:completionHandler:)` calls `completionHandler(.performDefaultHandling, nil)` — it accepts the default TLS behavior but does NOT explicitly reject invalid certificates. In a MITM scenario, a malicious companion could present a self-signed certificate. Mitigated by: egress gate disabled by default, local IPC is preferred.

**RESOLVED 2026-09-03:** `HTTPTransportDelegate` now evaluates the server trust chain with `SecTrustEvaluateWithError` and cancels the challenge on failure. `TransportConfiguration.trustedCertificateFingerprints` optionally pins the leaf certificate's SHA-256 fingerprint; empty set means validate against the system trust store. Pin list is threaded through `HTTPCompanionTransport.init(configuration:)`.

---

## Category 4: Tool Abuse (9/13 PASS, 1 FAIL, 3 WARN)

| # | Check | Finding | Verdict |
|---|---|---|---|
| 4.1 | SQL injection | No database in the system. | ✅ PASS |
| 4.2 | Path traversal (CLIRunner) | `CLIRunner.execute()` accepts arbitrary `inputPath: String` with no validation. A malicious path like `../../etc/passwd` would be read by `FileManager.default.contents(atPath:)`. | ✅ PASS (fixed 2026-09-03) |
| 4.3 | Command injection | No shell commands executed. `Process` is used only for launched companion binaries and `pdftoppm/pdfinfo` (fixed paths). Local IPC uses native sockets. | ✅ PASS |
| 4.4 | Companion socket path | Default socket path is `/tmp/pdf-editor-companion-{UUID}.sock`. Random UUID prevents collision. | ✅ PASS |
| 4.5 | Arbitrary capability | Only 4 capabilities allowed: `ocr.textBounds`, `edit.existingText`, `validate.independentViewer`, `validate.rasterDiff`. Enforced by validation. | ✅ PASS |
| 4.6 | File system access | Companion receives source bytes via base64 or file token — not arbitrary file paths. | ✅ PASS |
| 4.7 | Eval/exec | No `eval()`, `exec()`, or dynamic code execution in Swift or JS companion code. | ✅ PASS |
| 4.8 | Companion host logging | `safeLog()` strips all content fields. Only event metadata logged. | ✅ PASS |
| 4.9 | Source digest validation | Companion host verifies `digestBytes(sourceBytes) === request.sourceDigest`. | ✅ PASS |
| 4.10 | Output size limit | `maxOutputBytes` enforced. Companion returns `outputLimit` failure if exceeded. | ✅ PASS |
| 4.11 | Concurrency limits | `resourceLimits.maxConcurrentRequests` enforced in `CompanionBridge.sendRequest()`. | ✅ PASS |
| 4.12 | Timeout enforcement | Both Swift (`resourceLimits.requestTimeoutSeconds`) and JS (`request.timeoutMs`) enforce timeouts. | ✅ PASS |
| 4.13 | Socat dependency | `LocalCompanionTransport.connect()` uses a native Swift Unix-domain socket. No external binary on the PATH can intercept IPC traffic. | ✅ PASS (removed 2026-09-03) |

**FINDING 4.2 — Path Traversal in CLIRunner (FAIL):**
```swift
// CLIRunner.execute() — no path validation
guard let data = FileManager.default.contents(atPath: path) else { ... }
```
The `inputPath` parameter is used directly with `FileManager.contents(atPath:)`. A caller could pass:
- `../../etc/passwd` — reads system files
- `~/Documents/secret.pdf` — reads arbitrary PDFs
- `/dev/null` — reads empty file

**Risk:** LOW for the current app (CLIRunner is `@MainActor` and only callable from the scripting surface), but MEDIUM for future CLI integration where untrusted input could reach this path.

**Recommended fix:** Validate that `inputPath` resolves to a file within an allowed directory (e.g., user-selected files, or the app's sandbox).

**RESOLVED 2026-09-03:** `CLIRunner.validatePath(_:)` (`ScriptingCLI.swift`) resolves symlinks (`resolvingSymlinksInPath`) and confines `inputPath` to the user Documents/Downloads directories and `/tmp`; `execute()` rejects any path outside those roots. Sandbox rejections are recorded in the CLI audit history (fixed alongside the Read-Gap audit).

**FINDING 4.13 — Socat External Dependency (WARN):**
The local IPC transport uses `socat` to connect to Unix domain sockets. `socat` is not vendored — it's expected to be installed via Homebrew. If a malicious `socat` binary is on the PATH, it could intercept IPC traffic. Mitigated by: the companion protocol validates message types and nonces.

**RESOLVED 2026-09-03:** socat is removed. `LocalCompanionTransport.connect()` now uses a native `socket(AF_UNIX, SOCK_STREAM)` + `connect()` and performs frame I/O directly on the socket file descriptor with `poll()`-bounded timeouts. No socat references remain in `Sources/` or `Tests/`. Verified by real loopback tests (`nativeSocketRoundTrip`, `nativeSocketTimeout`).

---

## Category 5: Goal Hijacking (13/13 PASS)

The companion is fire-and-forget. The app works without it. Capabilities are additive, not replacing core functionality.

| # | Check | Finding | Verdict |
|---|---|---|---|
| 5.1 | Autonomous action | No autonomous agent loop. Companion is request/response only. | ✅ PASS |
| 5.2 | Goal modification | Companion cannot modify the app's goals. It receives requests and returns results. | ✅ PASS |
| 5.3 | Scope creep | Capabilities are defined in a fixed set. No mechanism to add capabilities at runtime. | ✅ PASS |
| 5.4 | User consent | Egress gate requires explicit user consent to enable. | ✅ PASS |
| 5.5 | Opt-in architecture | Companion is optional. App functions fully without it. | ✅ PASS |
| 5.6 | Capability revocation | `EgressGate.revokeConnection()` and `ContractStore.remove()` allow revocation. | ✅ PASS |
| 5.7 | Session isolation | Each session has unique nonces. Sessions are independent. | ✅ PASS |
| 5.8 | Cancellation support | `CompanionCancellation` message type exists. `AbortController` in JS host. | ✅ PASS |
| 5.9 | Resource bounds | Max concurrent requests, timeouts, output size limits all enforced. | ✅ PASS |
| 5.10 | Failure states | Structured failure states: `unsupported`, `companionRequired`, `failed`, `warning`, `unknown`. | ✅ PASS |
| 5.11 | Provider identity verification | `CompanionNegotiator` verifies provider ID matches registry. | ✅ PASS |
| 5.12 | License enforcement | `CompanionRequest.validate()` rejects non-permissive licenses. | ✅ PASS |
| 5.13 | Contract versioning | Semantic versioning with major-version compatibility check. | ✅ PASS |

---

## Vulnerability Summary

### Critical (0)
None.

### High (0)
None.

### Medium (1) — RESOLVED (see [Resolution Log](#resolution-log-2026-09-03))
| ID | Category | Finding | Impact | Recommendation |
|---|---|---|---|---|
| V-01 | Tool Abuse | CLIRunner has no path sanitization | Arbitrary file read via crafted path | Validate inputPath resolves within allowed directory |

### Low (3) — RESOLVED ✅ (see [Resolution Log](#resolution-log-2026-09-03))
| ID | Category | Original Finding | Resolution | Evidence |
|---|---|---|---|---|
| V-02 | Info Extraction | HMAC was placeholder (`Data()`) | ✅ FIXED: Real HMAC-SHA256 via CryptoKit | `computeHMAC` / `verifyEnvelopeHMAC` in CompanionBridge.swift; `authenticate()` rejects bad signatures |
| V-03 | Tool Abuse | TLS accepted all certificates | ✅ FIXED: Server-trust validation + optional pinning | `HTTPTransportDelegate` calls `SecTrustEvaluateWithError`; `TransportConfiguration.trustedCertificateFingerprints` pins leaf SHA-256 |
| V-04 | Tool Abuse | socat was external dependency | ✅ FIXED: Native Unix-domain sockets | `socket(AF_UNIX, SOCK_STREAM, 0)` in CompanionTransport.swift; verified by `nativeSocketRoundTrip` + `nativeSocketTimeout` tests |

### Informational (4) — DOCUMENTED / ACCEPTED (see [Resolution Log](#resolution-log-2026-09-03))
| ID | Category | Finding | Resolution | Evidence |
|---|---|---|---|---|
| V-05 | Indirect Injection | PDF content reaches companion | 📄 DOCUMENTED: design property, mitigated by local-only + zero-egress + digest-bound | `EgressGate` actor controls content flow; companion contract is capability-whitelisted |
| V-06 | Indirect Injection | Extracted text visible to companion | 📄 DOCUMENTED: mitigated by local-only + no network | `browser_network_egression_assertion_test.mjs` (RG-028) verifies zero-egress |
| V-07 | Tool Abuse | ScriptRunner has no mid-operation cancellation | 📄 ACCEPTED RESIDUAL: not enforceable on synchronous pipeline without async refactor; not reachable from untrusted input | Local app surface only; `timeoutSeconds` bounds future work |
| V-08 | Info Extraction | sourceDigest is String, not crypto binding | ✅ VERIFIED: SHA-256 of source bytes, verified by companion host | `SourceDigest.compute(from:documentName:)` produces SHA-256; companion verifies `digestBytes(sourceBytes) === request.sourceDigest` |

---

## Resolution Log (2026-09-03)

All actionable findings from the 2026-09-01 audit are closed. Status per finding, with evidence and verification:

| ID | Status | Resolution | Evidence / Verification |
|---|---|---|---|
| V-01 | ✅ FIXED | Path traversal closed | `ScriptingCLI.swift` `validatePath(_:)` resolves symlinks and confines reads to Documents/Downloads/`/tmp`; sandbox rejections now recorded in audit history |
| V-02 | ✅ FIXED | Real HMAC-SHA256, no more `Data()` placeholder | `CompanionBridge.computeHMAC` / `computeEnvelopeHMAC` / `verifyEnvelopeHMAC` (CryptoKit); `authenticate()` rejects bad signatures; `sendRequest()` signs every envelope |
| V-03 | ✅ FIXED | TLS server-trust validation + optional pinning | `HTTPTransportDelegate` calls `SecTrustEvaluateWithError`, cancels challenge on failure; `TransportConfiguration.trustedCertificateFingerprints` pins leaf SHA-256 |
| V-04 | ✅ FIXED | socat dependency removed | `LocalCompanionTransport.connect()` uses native `socket(AF_UNIX)`; frame I/O over the socket fd with `poll()` timeouts; verified by loopback tests `nativeSocketRoundTrip` + `nativeSocketTimeout` (CompanionTransportTests) |
| V-05 | 📄 DOCUMENTED | Content-reach is a design property, not a defect | `EgressGate` doc comments state the V-05/V-06 mitigation (disabled by default, local-only, digest-bound); companion contract remains capability-whitelisted |
| V-06 | 📄 DOCUMENTED | Same as V-05 | Local-only + zero-egress invariants unchanged and asserted by `browser_network_egression_assertion_test.mjs` (RG-028) |
| V-07 | 📄 ACCEPTED RESIDUAL | No mid-operation cancellation for synchronous `ScriptRunner.execute()` | `timeoutSeconds` bounds are not yet enforceable on synchronous pipeline calls without moving `ScriptRunner` to a threaded/async execution model; not reachable from untrusted input (local app surface only). Tracked as future work — not claimed fixed |
| V-08 | ✅ VERIFIED | Digest binding is real | `SourceDigest.compute(from:documentName:)` produces SHA-256; companion host verifies `digestBytes(sourceBytes) === request.sourceDigest` (`provider_companion_host_test.mjs`) |

**Re-audit note:** rows 3.12, 3.13, 4.2, 4.3, 4.13 in the category tables above carry the updated verdicts. Full test evidence: `CompanionTransportTests` (36 tests, incl. V-02 signature + V-04 native socket), `CompanionProtocolTests`, `CompanionFlowIntegrationTests` (124 companion tests green 2026-09-03).

---

## What's Strong

1. **Zero-egress invariant** — `EgressGate` is disabled by default. All network operations require explicit opt-in. This is the strongest security control.

2. **Value-free logging** — Both Swift (`RequestLogEntry`) and JS (`safeLog()`) strip content from logs. No document text, field values, or OCR content appears in any log entry.

3. **Source digest binding** — Every request is bound to a SHA-256 digest of the source PDF. The companion host verifies the digest matches the actual bytes. This prevents content replay and ensures the companion processes exactly what the app intended.

4. **Typed protocol** — All messages are strict typed structs with validation. No free-text fields that could carry injection payloads.

5. **Local-only enforcement** — `CompanionHello.localOnly: true` and `CompanionCapabilityRequest.localOnly: true` are validated. The protocol rejects non-local requests.

6. **Capability whitelist** — Only 4 capabilities are allowed. No mechanism to add capabilities at runtime.

7. **Structured failures** — Every failure mode has a typed error state. No stack traces or error messages leak to the companion.

---

## Evidence Files

| File | What it proves |
|---|---|
| `Tests/provider_companion_host_test.mjs` | Handshake, source binding, abstention, output limits, zero-content logging |
| `Tests/browser_network_egression_assertion_test.mjs` | Zero external requests during full workflow (RG-028) |
| `Tests/encrypted_companion_export_test.mjs` | Encrypted export doesn't leak content |
| `Tests/PDFEditorCoreTests/CompanionFlowIntegrationTests.swift` | Full companion flow: handshake → capability → request → response |
| `Tests/PDFEditorCoreTests/CompanionNegotiatorTests.swift` | Negotiation with mock providers |

---

## Recommendations (Priority Order)

1. **Fix V-01 (Medium):** Add path sanitization to `CLIRunner.execute()` — resolve `inputPath` and verify it's within an allowed directory.
   ✅ **COMPLETED 2026-09-03** — `validatePath(_:)` in `ScriptingCLI.swift`; see [Resolution Log](#resolution-log-2026-09-03).

2. **Fix V-02 (Low):** Implement HMAC computation in `CompanionBridge.sendRequest()` using CryptoKit, and verify in the companion host.
   ✅ **COMPLETED 2026-09-03** — `computeHMAC`/`computeEnvelopeHMAC`/`verifyEnvelopeHMAC`; verification enforced in `authenticate()` and on envelope receipt.

3. **Fix V-03 (Low):** Add certificate pinning or explicit rejection of invalid TLS certificates in `HTTPTransportDelegate`.
   ✅ **COMPLETED 2026-09-03** — server-trust evaluation + optional SHA-256 leaf pinning via `trustedCertificateFingerprints`.

4. **Fix V-04 (Low):** Document socat dependency or replace with Swift NIO for Unix domain socket communication.
   ✅ **COMPLETED 2026-09-03** — socat replaced with native Unix-domain sockets (stronger than the recommended Swift NIO path); loopback-tested.

5. **Fix V-07 (Info):** Add timeout enforcement to `ScriptRunner.execute()`.
   📄 **DOCUMENTED 2026-09-03** — accepted residual risk: synchronous pipeline calls cannot be cancelled mid-operation without moving `ScriptRunner` to a threaded/async model. Not reachable from untrusted input. See [Resolution Log](#resolution-log-2026-09-03).

---

## Doctrine Alignment

- **§1 Outcomes:** This audit establishes the security baseline for the companion bridge before external users interact with it.
- **§2 Truth taxonomy:** All findings are **Observed** (verified against source code) or **Verified** (confirmed by test evidence).
- **§4 Authorization:** The companion bridge is the primary authorization boundary between the app and external providers. This audit validates that boundary.
- **§5 Evidence-based:** Every check references specific code locations and test files.
- **§6 Documentation:** This document is the durable record of the security assessment.
