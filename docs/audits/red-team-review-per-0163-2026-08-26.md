# Red-Team Review — PER-0163 — 2026-08-26

**Persona:** `PER-0163 — Red-Team Reviewer`
**Scope:** Full codebase — source, tests, docs, CI, architecture
**Independence声明:** This review adopts a deliberately adversarial lens. The reviewer's goal is to find failure modes the builder missed, challenge assumptions the builder takes for granted, and identify paths to incorrect behavior that the test suite doesn't cover.

---

## 1. Attack surface analysis

### 1.1 Source-byte immutability (the core invariant)

**Claim:** Original PDF bytes are never mutated. Exports create new copies.

**Red-team challenge:** What if a provider adapter accidentally writes to the source file path?

**Evidence checked:** `PDFKitProvider.export()` creates a new URL for output. `pdf-lib` in the browser writes to a new buffer. The incremental writer appends to a `Data` object, not the file.

**Finding:** ✅ Hold. The invariant is enforced at the adapter level, not the file-system level. A buggy adapter could write to the source path, but current adapters don't. The `sourceDigest` check in the mutation gate catches stale-source attacks.

**Residual risk:** If a new provider adapter is added without the source-digest check, the invariant breaks silently. The mutation gate is the single point of enforcement.

### 1.2 Candidate auto-application

**Claim:** Candidates are never auto-applied. User review is required.

**Red-team challenge:** Does the learning loop ever skip the review step?

**Evidence checked:** `recordCandidateLearningEvent` is called AFTER `updateCandidate` changes the status. The learning event records the decision, it doesn't make it. `candidatePriors` only affects ranking, not application.

**Finding:** ✅ Hold. The learning loop is ranking-only. Candidates still require explicit user action to confirm.

### 1.3 Fail-closed guards

**Claim:** Encrypted, XFA, signature, malformed documents are refused.

**Red-team challenge:** Are there code paths that bypass the guards?

**Evidence checked:** `PDFKitProvider.export()` calls `walkAcroFormModel()` which checks `/Encrypt`. The signature guard runs on every export. XFA detection runs via `XFAFormProcessor.inspectXFA`.

**Finding:** ⚠️ Partial hold. The guards are in the export path, not the inspect path. A document could be inspected (read) even if it's encrypted/XFA/signed — the guard only fires at export time. This is correct behavior (reading should work), but a user might not realize their edits will be refused until they try to export.

### 1.4 Learning loop privacy

**Claim:** Learning events are value-free and privacy-safe.

**Red-team challenge:** Do learning events leak sensitive information?

**Evidence checked:** `CandidateReviewLearningEvent` stores: candidateID, decision (confirmed/rejected), pageIndex, geometry, sourceDigest. No user-entered values, no file content, no text. The store is encrypted (AES-256-GCM on native, IndexedDB on browser).

**Finding:** ✅ Hold. The events are structural (geometry + decision), not content-based. The encryption boundary is correct.

---

## 2. Test coverage gaps

### 2.1 What the test suite DOESN'T cover

| Gap | Risk | Why it's not caught |
|---|---|---|
| **Real-world PDF corruption** | Malformed PDFs could crash the parser | Tests use synthetic fixtures only |
| **Race conditions in learning loop** | Concurrent document opens could corrupt priors | Single-threaded by design, but no explicit lock |
| **Memory pressure with large PDFs** | 40-page hybrid fixture is the largest tested | No soak test for 100+ page documents |
| **Provider adapter license compliance** | AGPL code could be linked incorrectly | License check is manual, not automated |
| **Cross-session state corruption** | Two app instances editing the same file | Not tested; file locking is OS-dependent |

### 2.2 What the test suite DOES well

- S3 mutation tests prove guards kill specific tampering (31 mutations)
- Source-prefix byte-exact check catches mutation-gate bypasses
- Independent viewer (Poppler/MuPDF) confirms output isn't provider-local
- Network-egression assertion proves zero external requests
- Contract parity tests catch native/browser semantic divergence

---

## 3. Architecture risks

### 3.1 Single point of failure: mutation gate

The browser mutation gate (`web/pdf-contract-mutation-gate.mjs`) is the single point where all edits are validated before reaching pdf-lib. If this gate has a bug, every browser edit could be unsafe.

**Mitigation:** The gate is tested by `pdf_contract_parity_mutation_test.mjs` (10 mutation checks) and the negative test suite. But a bypass in the gate would be catastrophic.

**Recommendation:** Add a redundant validation layer inside the pdf-lib writer itself, so even if the gate is bypassed, the writer rejects unsafe operations.

### 3.2 Provider adapter leak

The shared contracts are designed to be provider-neutral, but in practice:
- `PDFKitProvider` exposes PDFKit-specific types in some internal methods
- The browser adapter uses pdf-lib-specific APIs in the writer

If a new provider adapter accidentally uses a provider-specific type in a shared contract, the contract neutrality breaks.

**Mitigation:** The contract parity tests catch semantic divergence, but not type-level leaks.

**Recommendation:** Add a Swift protocol that all provider adapters must conform to, with a CI check that no provider-specific types appear in shared contract files.

### 3.3 Learning loop drift

The learning loop records decisions per source digest. If the same PDF is edited multiple times (different sessions), the priors accumulate. Over time, priors from an old session could influence ranking for a new session on a different version of the same PDF.

**Mitigation:** Source digest binding means priors are per-version, not per-file. A new version starts fresh.

**Finding:** ✅ Hold. The digest binding is correct.

---

## 4. What the builder got right

1. **Source immutability is load-bearing** — every design decision traces back to it
2. **Fail-closed is the default** — no guard is optional
3. **Evidence before claims** — no capability is advertised without proof
4. **Privacy is per-capability** — no universal "private" claim
5. **Abstention is a runtime state** — not an apology, not a missing feature
6. **Documentation is durable** — decisions, gates, audits are all versioned and linked

---

## 5. Recommendations (prioritized)

| # | Recommendation | Effort | Impact |
|---|---|---|---|
| 1 | Add redundant validation in pdf-lib writer | 2 hours | High — defense in depth |
| 2 | Add Swift protocol for provider adapters | 1 hour | Medium — prevents type leaks |
| 3 | Add soak test for 100+ page PDFs | 1 hour | Medium — catches memory issues |
| 4 | Automate license compliance check | 2 hours | Medium — prevents legal risk |
| 5 | Add file-locking test for concurrent sessions | 2 hours | Low — edge case |

---

*Review performed under PER-0163 — Red-Team Reviewer lens. This is an adversarial assessment, not an implementation plan. Findings are evidence-backed challenges, not directives.*
