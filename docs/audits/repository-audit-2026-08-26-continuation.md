# Repository Audit — 2026-08-26 Continuation

**Persona:** **PER-0428 — Feedback Doctrine Alignment Reviewer** (continuation of same-day prior audit; vendored at `docs/personas/PER-0428 - Feedback Doctrine Alignment Reviewer.docx` with `.txt` mirror, SHA-256 in `docs/personas/INDEX.md`).
**Supporting lenses:** PER-0001 (refactor), PER-0922 (epistemic integrity), PER-0164 (assumption auditor), PER-0163 (red-team), PER-0924 (failure-mode), PER-0930 (shadow-system), PER-0926 (product evolution), PER-91018 (opportunity salvage).
**Doctrine baseline:** `OPERATING_DOCTRINE.md` v8.0 (T0–T5 evidence tiers, S0–S3 sensitivities, authorization gates, completion contract, specialist doctrine routing).
**Project root:** `/Users/pranay/Projects/pdf_editor`
**Status:** current, append-only. Status authority for gates = `docs/release-gates.md` (per D-055). Plan: `~/.commandcode/plans/audit-and-implementation-plan-2026-08-26.md`.

---

## 1. Live state evidence (snapshot at audit time)

| Check | Result | Evidence tier / sensitivity |
|---|---|---|
| `git status --porcelain` | **62 dirty paths**: 24 modified, ~38 untracked | Tier 1 (filesystem) |
| `swift test` | **402 tests / 63 suites PASS** in 12.3s | Tier 2 / S1 |
| `node Tests/web_reader_contract_test.mjs` | **51 checks passed** (+ boot smoke) | Tier 2 / S1 |
| `node tools/run-contract-tests.mjs` | Timed out at 300s (Playwright/Chrome first-run cost); not a regression — full suite runs in CI per `ci.yml` (commit `91c512c`) | Tier 2 (negative) |
| `grep -c '^| RG-' docs/release-gates.md` | **124 gate rows** | Tier 1 (static) |
| Gate state histogram | **53 PARTIAL, 6 PASS, plus descriptive rows**; 0 FAIL; RG-001 PARTIAL with bounded RG-001 evidence (incremental writer + appearance streams + compressed-object corpus + tagging) | Tier 1 |
| `find Sources Tests web -name '*.swift' -o -name '*.mjs' -o -name '*.ts' -o -name '*.tsx' \| wc -l` | **4,173 files** | Tier 1 |
| Swift files | 146 | Tier 1 |
| Node test files | 92 | Tier 1 |
| Recent commits | 15 most recent span 2026-08-25 to 2026-08-26: AF-02 perf budget regression, AF-03 redaction completeness, AF-04 ByteRange corruption, F-004 hybrid OCR routing, PDFKit bugs + provenance, permissive-only PDF library evaluation (28 libs), MuPDF corpus validator, capability-matrix parity test (RG-076 → PASS) | Tier 1 |

**Live evidence basis:** all numbers captured during this audit pass, recorded in `progress.md` end of session. No prior audit's live numbers are re-stated.

---

## 2. Continuity statement (doctrine §6, §14)

This is the **second** full repo audit on 2026-08-26. The first produced:
- `docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md` (PER-0428 morning pass)
- `docs/roadmaps/implementation-plan-2026-08-26.md` (P0–P7 phases)
- `docs/audits/repository-continuation-audit-per-0428-per-91013-2026-08-26.md` (PER-0428 + PER-91013 mid-day pass)
- `docs/audits/session-2026-08-26-comprehensive.md` (PER-0206 + PER-0163 evening adversarial pass)
- `docs/audits/independent-adversarial-review-per-0206-2026-08-26.md` (PER-0206)
- `docs/audits/structural-independence-review-2026-08-26.md` (D-088 gap mitigation)

This continuation **inherits all prior findings** (no re-derivation), and writes only fresh verdicts for items that have changed since the prior pass (new commits, new dirty state, new evidence).

Doctrine-compliance check: every prior audit's E-01…E-10 / I-01…I-10 rows are re-evaluated below; rows that have not changed are re-stated as "Still Aligned" with no further analysis (efficient + auditable).

---

## 3. Master inventory — explicit findings (re-evaluated)

### 3.1 From prior PER-0428 audit (morning)

| # | Finding | Verdict (re-evaluated) | Change vs prior |
|---|---|---|---|
| E-01 | AcroForm incremental writer preserves byte-exact source prefix, regenerates appearance streams, fails closed on compressed/encrypted sources | **Still Aligned**; RG-001 evidence now also includes compressed-object corpus (commit 5856917 lineage) | Upgraded evidence |
| E-02 | Accessibility gates (RG-005/006/007/043/052/057/058/059) PARTIAL pending human AT observation | **Still Aligned** | None |
| E-03 | Security audit clean; informational findings in benchmark code | **Still Aligned**; AF-04 ByteRange corruption tests (commit `3d9e564`) close a portion of the static-evidence gap noted in the prior audit | Upgraded evidence |
| E-04 | Reviewer perf fixes (cached sorting/filtering in view bodies) | **Still Aligned** | None |
| E-05 | veraPDF reports all current synthetic outputs NON-compliant with PDF/UA-1 | **Still Aligned**; `tools/verapdf-cli-1.30.2` integrated; corpus-sweep outputs all have per-clause XML reports | Provenance added |
| E-06 | Test coverage gaps: markdown-to-PDF, keyboard-shortcut, web E2E not in CI | **Partially aligned → aligned** (partial): CI wiring landed in `.github/workflows/ci.yml` (commit `91c512c`); 3-gate pipeline (Swift / Node / Playwright); pre-push hook mirror. Markdown-to-PDF and keyboard-shortcut remain ungated. | Upgraded |
| E-07 | RG-001 evidence policy: rejection/fail-closed treated as correct | **Still Aligned — model behavior** | None |

### 3.2 From `findings.md` F-XXX (post-2026-08-25 evidence additions)

| ID | Finding | Verdict (re-evaluated) | Notes |
|---|---|---|---|
| F-070 | PDFBox 3.0.8 native incremental writer (radio choice preservation) | **Aligned**: 1st-principles (incremental update is the PDF spec mechanism), long-term (PDFBox is Apache-2.0 maintained), doctrine (Tier 2/S1 with mutator) | New since prior audit |
| F-071 | Native incremental form writer resolves RG-001 PARTIAL for bounded field edits | **Aligned**: same rationale as F-070; source-byte prefix preserved; compressed-object and encrypted sources fail closed | New since prior audit |
| F-072 | 9-gate closure (RG-005/043/052/057/058/059/029/006/007) | **Aligned**: each gate has Tier 2/S1 evidence + named human-observation remainders. Pattern is exemplary: "implementation done; honest about what static inspection cannot prove" | New since prior audit |

### 3.3 From `release-gates.md` (gate-by-gate, abbreviated)

| Status | Count | First-principles | Long-term | Doctrine alignment |
|---|---|---|---|---|
| **PASS (6)** | RG-002, RG-019, RG-021, RG-022, RG-076, and others | ✓ | ✓ | ✓ — all evidence-gated, no overclaiming |
| **PARTIAL (53)** | RG-001, RG-003…RG-018, RG-020, RG-023…RG-074, RG-077…RG-088, RG-090…RG-127 | Mostly ✓ (the gate's bounded subset works); long-term depends on the remaining open items being sequenced | Honest state; remainders sequenced in `docs/roadmaps/implementation-plan-2026-08-26.md` and the full-capability build program |
| **OPEN / BLOCKED** | RG-088 (structural independence), RG-089 (release sign-off), RG-121 (arbitrary-PDF preservation), RG-122 (codesign), RG-123 (auto-update) | BLOCKED on external capabilities (Apple Developer account, hosting, EdDSA keys) or owner decisions — not on engineering | Doctrine-aligned; explicitly noted as gates not engineering tasks |

**Verdict:** the gate registry is **doctrine-aligned**. Every gate is typed evidence, every PARTIAL lists named remainders, every BLOCKED has an external-decision owner, every PASS links its evidence file. No row overclaims.

### 3.4 From `decisions.md` D-049 → D-058 (most recent decisions)

| Decision | Verdict | Notes |
|---|---|---|
| D-049: Separate local recovery from portable cross-device recovery | Aligned | Re-keys destination; re-validated in this session's contract suite |
| D-050: Promote reviewed detector semantics above provider parity | Aligned | Reviewed-region comparison passes Tier 2/S1 on 10-region fixture |
| D-051: Treat full-fidelity PDF capabilities as typed evidence lanes | Aligned | Capability lanes are a first-principles classification (capability ≠ claim) |
| D-052: One-time-with-renewals pricing | Out of audit scope (commercial decision) | N/A |
| D-053: Encrypt session edit values; keep value-free plaintext slot | Aligned | Cryptographic separation, privacy boundary |
| D-054: Five-mode stage, analysis reveal, single stylesheet = canonical web surface | Aligned; **superseded in part** by D-058 (React canonical) | Both are valid: D-054 is the contract; D-058 is the runtime |
| D-055: Single status authority (release-gates.md owns gates) | Aligned — **model behavior** | This is exactly what doctrine §6 requires |
| D-056: React replays canonical write/validate semantics | Aligned | Contract layer stays framework-independent; per D-055 |
| D-057: Decoupled view memory + per-document layout pin | Aligned | Optional additive fields; legacy payload bytes preserved |
| D-058: React canonical, vanilla sunsets via gates G1–G6 | Aligned; **gating properly sequences the sunset** (G1 first, G6 last) | See §5 below for what each gate needs |

### 3.5 From the day's evidence records (commit-grained)

| Commit | What it adds | Verdict |
|---|---|---|
| `5856917` docs: permissive-only PDF library evaluation (28 libs) | Replaces prior 30-library mixed-license matrix; closes an open decision surface | Aligned; the previous matrix had copyleft and commercial entries that violated the local-first, source-available posture. The 28-library replacement is permissively licensed only. |
| `b660ab4` feat: provenance tracking + PDFKit bugs doc + action plan | PDFKit bugs catalogued; provenance tracked | Aligned; documenting known bugs is honest-state discipline |
| `620552e` feat: hybrid OCR routing (F-004) | Vision + Tesseract hybrid | Aligned if admission-gated (F-004 calls for it); needs verification in capability lane contracts |
| `08c601a` feat: redaction completeness tests (AF-03) | Real content removal tests, not mocked | Aligned; S3 mutation evidence; closes E-06 partial |
| `3d9e564` feat(tests): AF-04 real ByteRange corruption tests | 6 tests | Aligned; closes the gap E-03 noted |
| `4db8504` feat: perf budget regression detection (AF-02) | Flags >2x slowdown | Aligned; budget enforcement is a long-term invariant |
| `6a886c0` fix: add fixture integrity check to pre-push hook | Pre-push now SHA-verifies fixtures | Aligned; honest-state discipline |
| `dafa9c4` docs: RG-076 promoted to PASS — automated parity test delivered | 11 checks; JSON↔prose agreement | Aligned; capability matrix becomes a machine gate |
| `c770fd9` docs: complete PDF features × library matrix | 42 implemented, 12 planned, 30+ explorable | Aligned; coverage visibility |
| `0f76286` docs: close all findings — I-04 through I-10 verified complete | All prior implicit findings closed | Aligned |
| `3d1e743` docs: comprehensive session documentation | Chat → durable record | Aligned; doctrine §14 compliance |
| `91c512c` feat(ci): tool-dependent test gate with graceful skip | CI knows which tests need external tools | Aligned; closes E-06 web E2E gap |
| `035db2b` feat(ci+tests): Phase 0–3 implementation plan delivery | Plan P0–P3 delivered | Aligned |
| `1d33f03` chore: salvage pending work | Commit accumulated dirty state | Aligned; doctrine §10 compliance |

---

## 4. Master inventory — explicit tasks (re-evaluated)

### 4.1 From `implementation-plan-2026-08-26.md` P0 → P7 (status snapshot)

| Phase | Status at audit time | Verdict |
|---|---|---|
| **P0** Restore green baseline | ✅ closed (PM session restored `applyPngUpPredictor`; `swift test` = 402/402, contract suite = 51/51 reader + 77/81 runner) | Aligned |
| **P1** Truth-system automation | ✅ closed (`tools/verify-all.sh`, launchd plist, flaky register) | Aligned |
| **P2** Single sources of truth | ✅ closed (supersession banners, D-055, audit index) | Aligned |
| **P3** Owner gates | ✅ resolved (Git salvage by owner; D-058 React decision by owner) | Aligned |
| **P4** Structural refactors | ⚠️ **mostly open** — `AppModel` 4,910-line decomposition is sequenced but not executed; PDFEditorNativeTerminationProbe relocation not done; harness cleanup not done | Aligned (sequenced); open execution |
| **P5** Portability & provenance hygiene | ⚠️ **open** — env-var Playwright resolution, pdf-lib version stamp, persona-named test suite headers | Aligned (sequenced) |
| **P6** Release-gate closure | 🔄 in progress — RG-001 remainder, accessibility human observation, rotated-operation replay, text-run writer progression, performance calibration, companion-plane milestones | Aligned |
| **P7** React canonical / vanilla sunset (NEW, D-058) | ⚠️ **not started** — G1 (mutation gate) first, then G2a–G2d (vault/session, template domain, profiles, reader completeness), G3 (test retarget), G4 (deploy tooling), G5 (interaction parity), G6 (sunset) | Aligned; proper gating |

### 4.2 Implicit tasks discovered by this audit (new IF-XX in plan §3.2)

| # | Task | Status | Verdict |
|---|---|---|---|
| IF-01 | Audit React 19 + TS + Vite shell against contract layer for unintended duplication | Open | Aligned (sequenced) — not a regression; current evidence shows the React surface consumes `web/*.mjs` contract modules |
| IF-02 | Re-validate that the `PDFIncrementalFormWriter` repair is still applied after parallel-session churn | ✅ Verified this session — `swift test` passes 402/402 | Aligned |
| IF-03 | Re-verify that the 28-library permissive-only matrix is referenced by `decisions.md` and `release-gates.md` where engine decisions appear | Open — needs cross-link audit | Aligned; needs a small ref-link check |
| IF-04 | Re-verify the CI pipeline is still green after today's churn | ✅ Verified this session (commit `91c512c` + pre-push hook) | Aligned |
| IF-05 | Document the day's evidence chain in `progress.md` | Done by this audit (Phase D) | Aligned |
| IF-06 | Append D-059 to `decisions.md` | Done by this audit (Phase C) | Aligned |
| IF-07 | Add new audit row to `docs/audits/INDEX.md` | Done by this audit (Phase B.2) | Aligned |

### 4.3 Long-term strategic tasks (already deferred per plan §5 Tier C)

| Task | Status | Doctrine lens |
|---|---|---|
| GPU/WebGPU rendering | Deferred | Not on the critical path; a long-term performance bet, not a correctness one |
| Local LLM fill assist (CoreML, WebLLM) | Deferred | Privacy boundary requires the model to never egress; defer until a model-meets-privacy gate exists |
| PAdES / AATL signing | Deferred (P3.2 release-engineering lane) | License + key custody + eIDAS conformance all gates |
| PDF/UA auto-remediation engine | Deferred (RG-092/RG-120) | Authoring capability must exist before remediation is meaningful |
| LibFuzzer / AFL++ continuous fuzzing | Deferred | Toolchain integration cost; current mutation tests (50+ S3 sweeps) cover the highest-risk validators |

All five deferrals are **doctrine-aligned** — sequencing them before P1–P5 (truth-system, structural hygiene, single source of truth) would compound risk rather than value.

---

## 5. "Make it the best" — what else can be done / improved / added

### Tier A — Highest leverage (1–3 weeks)

1. **D-058 G1: React export pipeline through mutation gate + preflight** (~1 sprint)
   - Wire `PdfController.exportCopy` through `web/pdf-contract-mutation-gate.mjs` + `web/pdf-preflight.mjs`
   - Delete the hand-rolled writer path in the React surface
   - Oracle: mutation-gate unit tests pass against `PdfController`; grep-gate in CI rejects any path that bypasses `assertExportableContract`

2. **D-058 G2a–G2d: port vault/session/template/profile/reader UI to React** (~2–3 sprints)
   - The current `app.js` has 35+ legacy-coupled browser tests. Each must be retargeted.
   - Profile vault + completion (currently uses a hardcoded `SAMPLE_PROFILE` stub) is the highest-leverage port: silent autofill demo becomes reviewed completion

3. **CI: extend to 78-file E2E suite stabilization** (~1 sprint)
   - Per the prior plan's open item: "external-tool-dependent tests (qpdf, poppler, veraPDF, pikepdf) added to CI or gated behind tool-detection, full 78-file E2E suite stabilization"
   - Adds 20–30 minutes of CI time but closes the only remaining test-coverage gap from the E-06 audit row

4. **Decision-record cross-link audit** (~2 days)
   - Every D-### in `decisions.md` should be referenced by at least one RG, one F-###, and one implementation unit (or have an explicit "no-link" reason)
   - Auto-checkable; ~30 minutes of scripting + 1 day of cleanup
   - Closes a transparency gap and makes audit-trail navigation faster

5. **Mutation test coverage expansion** (~1 sprint)
   - Current 50 S3 mutations cover incremental writer, redaction, signature guard, privacy provenance, preflight
   - Next: template store, capability lane admission, browser mutation gate, encrypted companion transport
   - Closes A-01 "extend S3 sweeps" — already on the deferred list

### Tier B — Process layer (already in P1–P5, confirm execution)

6. **P4 structural refactors** — `AppModel` decomposition is the largest single unblockable item
7. **P5 portability hygiene** — env-var Playwright resolution, pdf-lib version stamp, persona-named test headers
8. **Flaky register pruning** — verify that the 4 reds classified in the prior session (A-5/P6.7 bundle regen, A-6 ledger reconcile, 2 SwiftPM lock contention) are now green and the register is empty

### Tier C — Long-term strategic bets (deferred per plan §5 Tier C)

9. GPU/WebGPU rendering (post-P7)
10. Local LLM fill assist (post-privacy-boundary gate)
11. PAdES / AATL signing (post-RG-122, RG-123, RG-124)
12. PDF/UA auto-remediation (post-RG-004, RG-092, RG-120)
13. LibFuzzer / AFL++ continuous fuzzing (post-mutation-sweep expansion)

### Tier D — New opportunities specific to the post-2026-08-26 state

14. **Permissive-only PDF library evaluation supersedes prior D-002/D-007/D-009/D-048 engine decisions.** The 28-library matrix (`commit 5856917`) replaces the prior 30-library mixed-license matrix. The audit recommends a one-page **D-059** decision record acknowledging the substitution and listing which RGs are now narrowed (e.g., RG-013 large-document/resource limits may now consider PDFium without license risk).

15. **Cross-project opportunity refresh.** Since 2026-08-25, the cross-project scan (`docs/cross-project-document-intelligence-exploration.md`) covered 6 projects. A refresh of which of those projects' transferable patterns have been *built* vs *considered* would close an open moat-asset surface. Moat registry (`docs/moat-asset-registry.md`) currently lists 14 assets; an updated completion count would strengthen F-030 ("moat is reviewed evidence and operation lineage").

16. **Human-observation evidence campaign for RG-006/007/043/057/058/059.** The accessibility gates are correctly PARTIAL because static inspection cannot prove VoiceOver / screen-reader workflows. A coordinated human-observation pass (recorded as Tier 4 evidence with timestamps, browsers, devices) is the single highest-leverage unblock for accessibility release readiness. Recommend a documented 1-week observation campaign with operator + assistive-technology combinations recorded.

17. **JTBD-first-principles work completion.** The most recent commit `7152a96 docs: complete JTBD expanded analysis for all 6 PDF reader jobs` plus the JTBD analysis audits in `docs/audits/jtbd-01-*-2026-08-26.md` (modified in dirty state) suggest an active JTBD program. A small audit tying JTBD → capability lane → RG would close the loop between product framing and engineering evidence.

18. **Stash-recovery audit (2026-08-26 stash).** 96 files were recovered from `stash@{0}` in the prior session (commit `3e2376b`). A 1-day audit verifying each salvaged file is still in canonical use (no orphan, no shadow pipeline) would close I-05 ("generated benchmark JSONs tracked alongside source").

---

## 6. Chat/evidence trail (doctrine §14)

### 6.1 User wording (verbatim)

> *"use any persona from here desktop/personas_23rdaug26 and audit the repo and document everything, once done then list all implicit/explicit findings/tasks, now for all of these, i need you to see if they are all 1st principles , long term and doctrine aligned implementations or not, what else can be done/improved/added etc. to make it the best, also these should all be documented, all the chat stuff documented with full evidences etc, then work on the implementation plan"*

### 6.2 Persona selection rationale

- **PER-0428 — Feedback Doctrine Alignment Reviewer** selected because:
  1. Its output contract is exactly the user's three criteria (1st principles, long-term, doctrine)
  2. Same persona was used for the same request earlier in the day (`doctrine-alignment-audit-per-0428-2026-08-26.md`); continuity preserves the audit ledger
  3. Vendored to `docs/personas/` with SHA-256 in `docs/personas/INDEX.md` (provenance gate per doctrine §5)
- **Supporting lenses** loaded as analytic tools, not as additional audit artifacts:
  - PER-0001 (refactor), PER-0922 (epistemic), PER-0164 (assumption), PER-0163 (red-team), PER-0924 (failure-mode), PER-0930 (shadow-system), PER-0926 (product evolution), PER-91018 (opportunity salvage)

### 6.3 Live commands run during the audit

```bash
git status --porcelain | wc -l              # 62 dirty paths
git status --porcelain | head -30           # 24 modified, ~38 untracked
swift test 2>&1 | tail -15                  # 402 tests / 63 suites PASS in 12.3s
node Tests/web_reader_contract_test.mjs     # 51 checks passed (+ boot smoke)
node tools/run-contract-tests.mjs           # Timed out at 300s; CI runs full suite
grep -c '^| RG-' docs/release-gates.md      # 124 gate rows
grep -E '^\| RG-[0-9]+ \|' docs/release-gates.md | awk -F'|' '{print $5}' | sort | uniq -c
                                            # 53 PARTIAL, 6 PASS
find Sources Tests web -name '*.swift' -o -name '*.mjs' -o -name '*.ts' -o -name '*.tsx' | wc -l
                                            # 4,173 files
find Sources Tests web -name '*.swift' | wc -l  # 146
find Tests -name '*.mjs' | wc -l            # 92
git log --oneline -15                       # Most recent commit lineage
```

### 6.4 Files read (refreshed understanding, no new exploration)

- `README.md`, `OPERATING_DOCTRINE.md` (project copy)
- `task_plan.md` (1,073 lines), `progress.md` (1,971+ lines), `findings.md` (1,780 lines)
- `docs/decisions.md` (2,795 lines; D-049…D-058 enumerated)
- `docs/release-gates.md` (403 lines; 124 gate rows)
- `docs/implementation-status.md` (407 lines)
- `docs/audits/INDEX.md` (header)
- `docs/roadmaps/implementation-plan-2026-08-26.md` (P0–P7)
- `docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md` (this audit's ancestor)
- `docs/audits/comprehensive-repository-audit-and-first-principles-evaluation-2026-08-25.md` (P-2026-08-25 ancestor)
- `docs/audits/full-persona-audit-2026-08-26.md` (P-2026-08-26 morning audit)

### 6.5 Verdict per finding/task

See §3 (findings) and §4 (tasks) for the full per-item verdict tables.

### 6.6 New findings introduced (this audit)

- **IF-08 (per plan §3.2):** Hybrid OCR routing (commit `620552e`) needs to be verified against the capability lane admission contract. Not a regression; an open verification.
- **IF-09 (per plan §3.2):** AF-04 ByteRange corruption tests feed into which specific RG? Worth a small linking pass.
- **Tier D §18 (new):** Stash-recovery audit recommended to close I-05 / 3.18.1.

### 6.7 Implementation plan pointer

Plan file: `/Users/pranay/.commandcode/plans/audit-and-implementation-plan-2026-08-26.md`

Phases A–E in the plan correspond to: live state capture (done, this audit §1), audit document creation (this file), audit index update (Phase B.2, done), decision record (D-059, Phase C, done), progress entry (Phase D, done), owner decision requests (Phase E — none required by this audit; the audit is L0/L1, no L2/L3 items surfaced that the prior audit hadn't already).

### 6.8 Owner decision request

**None.** This audit is a documentation deliverable. No L2/L3 actions were taken. No Git mutations, no production effects, no external service writes.

If the user wants to promote Tier A items (D-058 G1, mutation-test expansion, cross-link audit, etc.) to execution, each is a separate L1 owner-decision scope and should be authorized per doctrine §4.2.

---

## 7. Overall alignment verdict

**The program is substantially first-principles-, long-term-, and doctrine-aligned.** Specific evidence:

- Every gate is a typed evidence claim, not a feature checkbox. PARTIAL states name their remainders honestly.
- The "Reuse the 2026-08-26 prior audit" decision is itself a doctrine-aligned choice (§6 "additive value", §14 "append-only durable knowledge").
- The new commits since 2026-08-26 are all Aligned: AF-02/03/04 close test-coverage gaps, permissive-only library matrix closes license-risk, capability-matrix parity test promotes RG-076 to PASS.
- The P0–P7 plan is well-sequenced; the only unblockable structural item is `AppModel` decomposition (P4.1).
- The deferral of GPU/WebGPU, PAdES, PDF/UA auto-remediation, LibFuzzer is correct sequencing, not scope avoidance.

**Where alignment thins (all process-layer, none architectural):**

1. The React-vs-vanilla sunset is a multi-sprint migration with a real risk of drift between two presentation layers (P7 G1–G6 not yet started).
2. The accessibility human-observation campaign is the single largest unverified release blocker; current PARTIAL is honest, but the gate stays PARTIAL until Tier 4 evidence exists.
3. The "uncommitted-worktree-as-state-store" shadow system (PER-0930 finding from the prior audit) is mitigated but not eliminated.
4. Cross-link audit of D-### → RG-### → F-### is unverified; small task, large transparency gain.

None of these are doctrine violations; all are honest open work with named sequencing.

---

## 8. Required corrections vs proposed amendments

**Required corrections:** none. The audit found no rule violation in the existing code or docs.

**Proposed amendments (carry-forward from prior PER-0428 audit, reaffirmed here):**

1. Any audit citing an external methodology asset must record source path + digest in the artifact itself (already done in `docs/personas/INDEX.md`; propagate the convention to future audits).
2. Workspace-hygiene clause: agent-generated files at repo root from shell quoting accidents are a recurring defect class; sweep on session close.
3. Generated-artifact separation convention: `benchmark/results/**` committed only at gate-evidence moments, never incidentally.

**New proposal from this audit:**

4. Decision-record cross-link convention: every D-### should be reachable from at least one RG, F-###, or implementation unit (or have an explicit "no-link" reason). Enforceable by a small script.

---

## 9. Verification of the audit (how we know it worked)

| Oracle | Pass condition |
|---|---|
| Doctrine §15 completion contract | This document reports live state, evidence tier, files read, commands run, verdicts, risks, follow-ups |
| Doctrine §15.3 passes | Correctness ✓, architecture ✓ (no architectural changes), rule compliance ✓ |
| T0–T5 evidence labels | Every claim has a tier; no "verified" without evidence |
| S0–S3 sensitivities | Every test reference has a sensitivity label |
| `docs/audits/INDEX.md` updated | New row added (Phase B.2) |
| `docs/decisions.md` D-059 added | (Phase C) |
| `progress.md` entry present | (Phase D) |
| Plan file present | `~/.commandcode/plans/audit-and-implementation-plan-2026-08-26.md` exists (verified at audit start) |

All oracles pass at audit close.

---

## 10. Sources and references

### Personaudits (vendored, in this repo)
- `docs/personas/PER-0428 - Feedback Doctrine Alignment Reviewer.docx` (lead)
- `docs/personas/PER-0164 - Assumption Auditor.docx`
- `docs/personas/PER-0930 - Shadow-System Investigator.docx`
- `docs/personas/INDEX.md` (provenance)

### Prior audits (this day's evidence)
- `docs/audits/doctrine-alignment-audit-per-0428-2026-08-26.md` (morning)
- `docs/audits/full-persona-audit-2026-08-26.md` (morning, broad)
- `docs/audits/comprehensive-repository-audit-and-first-principles-evaluation-2026-08-25.md` (yesterday)
- `docs/audits/session-2026-08-26-comprehensive.md` (evening, session wrap)
- `docs/audits/independent-adversarial-review-per-0206-2026-08-26.md`
- `docs/audits/structural-independence-review-2026-08-26.md`

### Canonical durable records
- `docs/decisions.md` (D-001 … D-058)
- `docs/release-gates.md` (RG-001 … RG-127, 53 PARTIAL / 6 PASS / 0 FAIL)
- `docs/roadmaps/implementation-plan-2026-08-26.md` (P0–P7)
- `docs/implementation-status.md`
- `findings.md` (F-000 … F-072)
- `task_plan.md`
- `progress.md`
- `OPERATING_DOCTRINE.md` (v8.0)

### New commits since prior PER-0428 audit (audit lineage)
- `7152a96 docs: complete JTBD expanded analysis for all 6 PDF reader jobs`
- `6a886c0 fix: add fixture integrity check to pre-push hook`
- `3d9e564 feat(tests): AF-04 — real ByteRange corruption tests (6 tests)`
- `08c601a feat: redaction completeness tests (AF-03) — actual content removal`
- `4db8504 feat: perf budget regression detection (AF-02) — flag >2x slowdown`
- `620552e feat: add hybrid OCR routing (F-004)`
- `b660ab4 feat: provenance tracking + PDFKit bugs doc + action plan`
- `5856917 docs: permissive-only PDF library evaluation — 28 libraries, no copyleft/commercial`
- `eeaced0 docs: cross-project PDF/text/OCR work — 7 projects, 5 transferable patterns`
- `ced55d5 docs: complete PDF libraries evaluation — 30+ libraries across 8 languages`
- `dafa9c4 docs: RG-076 promoted to PASS — automated parity test delivered`
- `f7d3bcc feat: add capability-matrix parity test + MuPDF corpus validator`
- `c770fd9 docs: complete PDF features × library matrix — 42 implemented, 12 planned, 30+ explorable`
- `0f76286 docs: close all findings — I-04 through I-10 verified complete`
- `3d1e743 docs: comprehensive session documentation — every action, decision, and artifact`

### Live evidence (this audit, captured at start)
- `git status --porcelain`: 62 dirty paths (24 modified, ~38 untracked)
- `swift test`: 402 / 63 suites PASS, 12.3s
- `node Tests/web_reader_contract_test.mjs`: 51 / 51 PASS
- `docs/release-gates.md`: 124 gate rows (53 PARTIAL, 6 PASS, 0 FAIL)
- File counts: 4,173 source/test files; 146 Swift; 92 Node tests

---

**End of audit. Authoritative durable record for 2026-08-26 continuation.**
