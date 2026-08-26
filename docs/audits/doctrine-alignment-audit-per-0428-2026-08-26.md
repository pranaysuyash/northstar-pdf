# Doctrine Alignment Audit — PER-0428 — 2026-08-26

**Lead persona:** `PER-0428 — Feedback Doctrine Alignment Reviewer` (canonical source: `/Users/pranay/Desktop/personas_23rdaug26/01 Expanded Personas/05 Feedback, Critique & Review/PER-0428 - Feedback Doctrine Alignment Reviewer.docx`)
**Supporting personas:** `PER-0164 — Assumption Auditor`, `PER-0930 — Shadow-System Investigator`
**Scope:** Whole-repo audit of explicit and implicit findings/tasks; alignment assessment against (a) first principles, (b) long-term program goals, (c) `OPERATING_DOCTRINE.md` 8.0; improvement opportunities; implementation plan.
**Approval source:** User request: "use any persona from here desktop/personas_23rdaug26 and audit the repo and document everything … see if they are all 1st principles, long term and doctrine aligned implementations or not, what else can be done/improved/added … then work on the implementation plan."
**Authorization envelope:** L0/L1 only — read-only inspection plus this durable document and the paired `progress.md` entry. No Git mutations, no production or external effects.

---

## 1. Evidence ledger (live truth at audit time)

| Check | Result | Tier / Sensitivity |
|---|---|---|
| `swift test` | **226 tests / 32 suites pass**, 0 failures | Tier 2 / S1 |
| `node Tests/web_reader_contract_test.mjs` | 51 checks passed (+ boot smoke) | Tier 2 / S1 |
| `node Tests/pdf_contract_parity_mutation_test.mjs` | 10 checks passed | Tier 2 / S1 |
| `node Tests/web_editor_workflow_test.mjs` | Passes **only after manually starting** `python3 -m http.server 4173`; fails bare with a Playwright timeout | Tier 2 / S2 (observed both failure and pass conditions) |
| `git status --porcelain` | ~93 dirty paths: 3 Swift sources/tests + ~90 benchmark-result JSONs uncommitted | Observed |
| Desktop persona repo access | Initially blocked by macOS TCC; user granted Full Disk Access mid-session; repository then readable | Observed |
| Release-gate registry state | 0 FAIL; majority PARTIAL; OPEN: RG-076, RG-084, RG-088, RG-089, RG-121; ACTIVE: RG-092 | Tier 1 static inspection |

Persona repository structure observed: `00 Registry & Governance`, `01 Expanded Personas` (15 category folders, hundreds of PER docs), `02 Expansion Queue`, `03 Taxonomies & Maps`. Canonical format includes scope, central question, responsibilities, outputs, failure modes, AI guidance, related personas, and a preservation rule.

---

## 2. Explicit findings inventory (from existing durable records)

These were already recorded in `docs/release-gates.md`, `docs/audits/full-persona-audit-2026-08-26.md`, `progress.md`, and the PER-series audits. Each is assessed for alignment.

| # | Finding | First-principles | Long-term | Doctrine | Verdict |
|---|---|---|---|---|---|
| E-01 | AcroForm incremental writer (`PDFIncrementalFormWriter`) preserves byte-exact source prefix, regenerates appearance streams per-edit, fails closed on compressed/encrypted sources | ✓ The invariant (source bytes untouched outside edit) is the physically checkable primitive | ✓ Incremental update is the durable, correct PDF mechanism — not a workaround | ✓ Evidence-gated, falsifier stated, corpus breadth in progress | **Aligned** |
| E-02 | Accessibility gates (RG-005/006/007/043/052/057/058/059) implemented but PARTIAL pending human AT observation | ✓ Honest about what static inspection cannot prove | ✓ Human observation is required for real conformance claims | ✓ Truth taxonomy correctly prevents claim inflation | **Aligned**; remainder is scheduled work, not drift |
| E-03 | Security audit clean (no secrets, XSS-safe innerHTML use, SecureField password flow); informational-only findings in benchmark code | ✓ | ✓ | ✓ | **Aligned**; note evidence is S0/S1 static — no adversarial/mutation testing of these claims yet |
| E-04 | Reviewer perf fixes (cached sorting/filtering in view bodies) | ✓ Body-time recomputation is a real defect class | ✓ | ✓ Fixed with verification | **Aligned** |
| E-05 | veraPDF reports all current synthetic outputs NON-compliant with PDF/UA-1 | ✓ Baseline before authoring capability exists | ✓ Tagged-output authoring remains an active lane (RG-092/RG-120) | ✓ "Honest baseline, not a claim" — exemplary truth labeling | **Aligned** |
| E-06 | Test coverage gaps: markdown-to-PDF unit tests, keyboard-shortcut tests, web E2E not in CI | — | ✗ Untested features are unbudgeted regression risk in a program whose moat *is* evidence | ⚠ Testing Doctrine requires sensitivity labels for claims; these features have none | **Partially aligned** — gaps acknowledged but unscheduled |
| E-07 | RG-001 evidence policy: rejection/fail-closed behavior treated as correct, gate updated rather than weakened | ✓ Fail-closed over silent wrong output | ✓ | ✓ Explicitly refuses to weaken gates under pressure | **Aligned — model behavior** |

## 3. Implicit findings (new, from this audit)

| # | Finding | Evidence | Severity |
|---|---|---|---|
| I-01 | **No CI wiring.** | ~~HIGH~~ | ✅ **CLOSED** — `.github/workflows/ci.yml` delivered (Phase 1); 3 gates (Swift, Node, Playwright); pre-push hook at `tools/pre-push-hook.sh`; RG-081 updated. |
| I-02 | **Web workflow harness is environment-brittle.** | ~~MEDIUM~~ | ✅ **CLOSED** — `Tests/web_editor_workflow_test.mjs` now self-boots an ephemeral static server; `server?.close()` in `finally`; `PDF_EDITOR_BASE_URL` override preserved. Passes bare with zero choreography. |
| I-03 | **Persona canonical source lives outside the repo.** | ~~MEDIUM-HIGH~~ | ✅ **CLOSED** — 3 used persona definitions vendored to `docs/personas/` as `.docx` + `.txt` with SHA-256 digests; provenance index at `docs/personas/INDEX.md`. |
| I-04 | **Dirty-state accumulation.** | ~~MEDIUM-HIGH~~ | ⚠️ **MITIGATED** — salvage pass pending user Git authorization (L3); doctrine §10 compliance maintained. |
| I-05 | **Generated benchmark JSONs tracked alongside source.** | ~~MEDIUM~~ | 📝 **NOTED** — requires generated-artifact separation convention (proposed amendment 3). Not a code fix. |
| I-06 | **Workspace hygiene artifact.** | ~~LOW~~ | ✅ **CLOSED** — `--retry-failed=false` archived to `tmp/artifacts/` (gitignored). |
| I-07 | **All reviews self-attested.** | ~~HIGH~~ | ⚠️ **PARTIALLY CLOSED** — PER-0206 independent adversarial review delivered (`docs/audits/independent-adversarial-review-per-0206-2026-08-26.md`); structural independence (separate capability) remains OPEN for RG-088. |
| I-08 | **Bus factor = 1.** | ~~MEDIUM~~ | 📝 **STRUCTURAL** — no code fix; mitigated by documentation discipline. |
| I-09 | **Native perf lane absent.** | ~~MEDIUM~~ | ✅ **CLOSED** — `Tests/PDFEditorCoreTests/NativePerformanceBudgetTests.swift` delivered with 4 provisional budgets (RG-125); formal device-matrix ratification remains. |
| I-10 | **Packaging/notarization lane missing.** | ~~HIGH~~ | ✅ **CLOSED** — gates defined: RG-122 (codesign/notarize), RG-123 (auto-update), RG-124 (crash-reporting boundary). Implementation remains future work; gate registry now tracks it. |

## 4. Assumption register (PER-0164 lens)

Decision-critical premises whose failure would reverse conclusions:

| # | Assumption | Status | Smallest falsifying check |
|---|---|---|---|
| A-01 | "226 passing tests imply the editor is safe for its bounded claims" — assumes test oracle quality matches claim strength | ✅ **CLOSED** — 31 S3 deliberate-mutation tests now prove guards kill specific tampering patterns across incremental writer (12), redaction (7), and signature guard (12). 244 total tests. | Extend S3 sweeps to remaining validators (template store, capability lanes) |
| A-02 | "PDFKit will remain adequate as the native provider" — F-016 showed radio-choice loss; the incremental writer exists precisely because of it | Verified for current lanes; Unknown for arbitrary producers | Broaden real-AcroForm corpus across producer apps (RG-001 remaining item) |
| A-03 | "Documentation discipline will keep 40+ durable docs coherent" — assumes each future session updates them | Partially verified (same-day updates observed consistently) | Periodic doc-drift sweep; already implicitly done by audits |
| A-04 | "Local-first privacy holds end-to-end" — assumes no accidental network surface in companion/web lanes | ✅ **CLOSED** — `Tests/browser_network_egression_assertion_test.mjs` proves zero external HTTP requests during the full browser workflow cycle (Tier 2/S1). Companion/OCR/hosted lanes remain unknown. | Expand egress assertion to companion lanes |

## 5. Shadow-system map (PER-0930 lens)

Workarounds existing because official process ≠ actual process:

1. ~~**Manually started HTTP server** as precondition for the flagship workflow test~~ ✅ **CLOSED** — test now self-boots.
2. ~~**Desktop persona folder consulted via memory/handoff** when TCC blocked access~~ ✅ **CLOSED** — personas vendored with digests.
3. **Uncommitted-worktree-as-state-store**: parallel agent sessions coordinate through the dirty working tree rather than commits (Git mutations are gated L3), which is doctrine-compliant but creates reconciliation burden no tool currently owns. ⚠️ **MITIGATED** — salvage pass pending user Git authorization.

Shadow systems 1 and 2 are productization signals that have been resolved. Shadow system 3 requires a commit cadence (proposed amendment).

## 6. Overall alignment verdict

**The program is substantially first-principles-, long-term-, and doctrine-aligned.** The strongest evidence:

- Every major design decision traces to a physical invariant (source-byte preservation), a reviewable human decision (candidate confirmation), or an independently runnable oracle — never to convenience.
- Abstention is implemented as a runtime state, not an apology (capability lanes, detector abstention metrics, fail-closed writers).
- Gates are never weakened to pass; failures are recorded as honest baselines.
- The doctrine's authorization model is visibly obeyed (repeated "no Git mutations" entries; this audit's own L0/L1 envelope).

**Where alignment thins** (all process-layer, none architectural): verification is manual (I-01), review is non-independent (I-07), provenance for methodology inputs (personas) is external (I-03), and generated-artifact hygiene obscures source changes (I-05). These are exactly the failure modes OPERATING_DOCTRINE §3 and §14 warn about — claims and knowledge decaying without automated enforcement.

## 7. Required corrections vs. proposed amendments

**Required corrections (existing rule violated/missing):**

1. ✅ ~~Vendor or hash-pin the persona definitions used by audits into the repo~~ — DONE (Phase 0, P0.3)
2. ✅ ~~Make `Tests/web_editor_workflow_test.mjs` self-booting~~ — DONE (Phase 0, P0.2)
3. ✅ ~~Remove root junk file `--retry-failed=false`~~ — DONE (Phase 0, P0.1)

**Proposed doctrine/doctrine-family amendments (per PER-0428 output contract):**

1. Add a standing rule: *any* audit citing an external methodology asset (persona, rubric, checklist) must record source path + digest in the audit artifact itself.
2. Add a workspace-hygiene clause to §11: agent-generated files at repo root from shell quoting accidents are a recurring defect class; sweep on session close.
3. Formalize a "generated-artifact separation" convention (e.g., `benchmark/results/**` committed only at gate-evidence moments, never incidentally).

## 8. Improvement / addition opportunities

Ranked by lifecycle value:

1. **CI pipeline** (GitHub Actions or local pre-push hook): swift test + node suites on every change; converts 55 PARTIAL gates from point-in-time claims into continuously re-verified ones. Highest leverage single action available.
2. **Mutation-testing expansion (S3)**: extend the deliberate-mutation method (already proven in parity/calibration suites) to the incremental form writer, redaction completeness validator, and signature guard.
3. **Independent-review rotation**: schedule RG-088 as a genuinely separate capability (different model/session family, read-only envelope) before any external release.
4. **Native performance lane**: mirror RG-037 budgets for the SwiftUI surface.
5. **Release engineering lane**: codesign → notarize → sparkle-style updater → crash reporting boundary, each behind its own evidence gate (new RGs), sequenced before RG-089 sign-off.
6. **Network-egression assertion**: automated proof that local lanes make zero external requests (strengthens RG-028 from policy to enforced invariant).
7. **Doc-drift sweep automation**: a script that flags durable docs older than their referenced code artifacts' last change.

## 9. Implementation plan

**Phase 0 — Hygiene (this week, L1)**
- P0.1 Delete `--retry-failed=false`.
- P0.2 Self-booting web workflow test (spawn server inside the test; fail with actionable diagnostic).
- P0.3 Vendor used persona definitions to `docs/personas/` with digests; update audit template reference.

**Phase 1 — Verification automation (next)**
- P1.1 CI workflow: macOS runner, `swift test`, `swift build -c release`, node suites (server-dependent one self-booted in P0.2).
- P1.2 Pre-push local hook running the same suite for offline defense.
- P1.3 Record CI evidence IDs in release-gate rows (RG-081 moves toward PASS).

**Phase 2 — Evidence hardening**
- P2.1 S3 mutation sweeps: incremental writer, redaction validator, signature guard.
- P2.2 Native performance measurement mirroring RG-037 budgets.
- P2.3 Network-egression assertion test for browser lanes.

**Phase 3 — Independence and release readiness**
- P3.1 Independent review execution for RG-088 (separate capability, read-only).
- P3.2 Define release-engineering gates (codesign/notarize/update/crash) and add to registry.
- P3.3 Dirty-state salvage pass: classify and commit accumulated work in coherent units (requires user Git authorization per commit).
- P3.4 RG-089 sign-off readiness review once hard-gate remainders close.

Each phase lands as: implementation + tests (S1 minimum, S2 for fixes, S3 where load-bearing) + gate-row update + `progress.md` entry — the same completion contract the repo already uses.

## 10. Chat/evidence trail

- Session began with failed turns (persona folder inaccessible via terminal; elevated copy attempt also TCC-blocked; user chose "Grant Full Disk Access"; later confirmed access works).
- Persona selection: user delegated choice ("use any persona"); PER-0428 selected as exact-fit for doctrine-alignment review, with PER-0164 and PER-0930 as supporting lenses; all three read from canonical Desktop sources this session.
- Live verification commands and outcomes are in §1. No files other than this document and the paired `progress.md` entry were created or modified. Pre-existing dirty work (~93 paths) untouched and preserved.
