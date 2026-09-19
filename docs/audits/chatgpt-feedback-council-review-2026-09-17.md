# Council Review — External ChatGPT Architectural Feedback (HEAD edb8379)

**Date:** 2026-09-17 · **Method:** council-orchestrator (dynamic council) · **Doctrine:** OPERATING_DOCTRINE v8.0 (sha256 ff848618…3466a)
**Input:** External ChatGPT re-review of the live `main` push (`edb8379`, "feat(workspace): ship inspector workflow and review gates"), processed as untrusted external evidence: every load-bearing claim was re-verified against source before adoption.
**Companion ledgers:** `docs/task-inventory.md` (task state, D-055), `docs/release-gates.md` (gate state), `docs/decisions.md` (decisions).

---

## 1. Council manifest

### Lead
**PER-0926 Product Evolution Architect** (canonical persona, `~/Desktop/Understanding_Personas_sept6`, resolver confidence high).
Reason: the feedback asks what the next architectural program should be — decision ownership over product evolution sequencing and stability/variability boundaries.

### Supporting seats (independent read-only passes, parallel)
| Seat | Persona / speciality | Mission | Distinct contribution |
|---|---|---|---|
| Epistemic Integrity | PER-0922 | Judge the provenance/status claim violations against repo doctrine; correct shape for route provenance; audit the feedback's own epistemics | Found fabricated `passed: true` checks (AppModel:490/573, AgentCommandHUD:886), unconditional receipt trailer, ANE claim with zero Neural Engine usage in Sources; confirmed the feedback's "receipt not wired" claim is stale |
| JTBD Researcher | PER-0315 | Map the feedback's five outcome-jobs onto the repo JTBD ledger; judge sequencing | Job (c) recurring-forms is the only evidenced job; cross-document work is the *lowest*-scored gap (G-29, score 3); "workspace canonical" is an architecture dressed as an outcome; step 3 (semantic selection, wedge-scoped) is the cheaper lever |
| Product Thesis Guardian | PER-0172 | Reconcile the 10-step program against task matrix, launch audit, D-066/D-078/D-052; classify thesis impact | Steps 1,3,5,8,9 = extensions/duplicates of ledgered work; **step 2 conflicts with D-066** (bounded completion editor with named falsifier) and has no SKU; step 4-as-model-planner conflicts with D-078 until a planner harness exists; matrix doc carries D-055 status drift ("Completed" vs task-inventory `partial`) |

### Rejected candidates
PER-91013 No-Go Adversarial Reviewer (overlaps PER-0922 here) · PER-0173 Scope Integrity Guardian (subsumed by PER-0172) · PER-0001 Refactor Decision Architect (code-level; orchestrator did Tier-1 verification directly).

### Coverage and known gaps
Decision ownership ✓ (Lead) · domain ✓ · user/stakeholder ✓ (JTBD) · implementation ✓ (orchestrator verification) · risk/counterposition ✓ (PER-0922 + PER-0172). **Gap:** no VoC/interview corpus exists in the repo; all demand judgments rest on repo ledgers only (flagged as Unknown with named resolving checks — cohort instruments PL-D09/PL-I15).

---

## 2. Claim verification (feedback → repository truth)

| Feedback claim | Verdict | Evidence |
|---|---|---|
| "Compare Side-by-Side" drop option doesn't use the dropped document | **Verified defect** | `ContentView.swift:361-364` called `openDiffComparison()`; `AppModel.openDiffComparison()` recomputes source↔live only |
| "Switch Document" drop option = warning label, not approval boundary | **Verified defect** | `ContentView.swift:369-372` called `model.open(url:)` directly; `open()` *cancelled* the pending content autosave (debounce-window loss) |
| Drop flow is second-document disambiguation, not multi-document (`providers.first`) | **Verified** | `ContentView.swift:543-544` |
| Planner = 3 goal families via string containment; `scope: .single` hardcoded | **Verified** | `AgentLoopContracts.swift:434,474`; `AgentCommandHUD.swift:767` |
| ExecutionReceipt "not wired into AppModel or inspector" | **Stale — refuted** | Wired: `AppModel.swift:472+`, `AgentCommandHUD.swift:881`, `ContextualInspectorView.swift:2666`. The *consolidation* point (no shared plan/trace identity with `ExportReviewReceipt`) stands |
| "Cryptographically verified on-device. Zero network egress." is too strong as a default | **Verified** | `ExecutionReceipt.swift:25,89` (pre-fix); fabricated `passed:true` checks at `AppModel.swift:490,573`, `AgentCommandHUD.swift:886`; ANE claim at `StandaloneWindows.swift:58` with no Neural Engine usage in Sources |
| Single green "Ready" collapses capability richness | **Verified** | `ContextualInspectorView.swift:315` |
| "100% COMPLIANT" language must go | **Verified (spec-level)** | `modern_workspace_vision.md:83`, `screen_improvement_log.md:738/744` (design docs; shipped UI shows a "Compliant" ring only) |
| ContentView is an 87KB workspace coordinator | **Verified** | 87,066 bytes / 2,530 lines |
| Human visual gate still 0/38 | **Verified** | `human-review-gate-report.json`: confirmedCount 0, all fixtures pending (2026-09-10) |

---

## 3. Cross-examined disagreement

**"Drop workflow already done" (JTBD seat, citing PL-V04/D-081) vs "fix drop workflow first" (feedback).**
Resolution: two different flows. Drop→open (G-081/D-081) is fixed and sim-proven. The drop *disambiguation HUD* (TASK-A5, shipped Sep 9) introduced two new semantic defects (compare not bound to the dropped document; switch without preservation discipline). The feedback is right about the HUD; JTBD is right that drop→open is done. Both fixed this session (§5).

---

## 4. Council decision on the 10-step program

**Overall verdict: thesis-supporting on architecture, thesis-conflicting on scope, not thesis-invalidating. Adopt ~7 of 10 steps as ledger extensions; modify priority; reject 2 as-stated.**

| Step | Disposition |
|---|---|
| 1 Fix drop workflow | **Adopt (done this session)** — see §5 |
| 2 Workspace canonical | **Reject as priority; adopt as hypothesis** — conflicts with D-066's falsifier; no cohort evidence (G-29 scores lowest of substantive gaps); no SKU (Team/Hosted deferred, D-052). Routed to NM-T39 (decision brief + cohort instrument). The launch critical path (§10.10: PL-I01→PL-D01∥PL-R02→PL-I02/PL-D02→PL-I04→PL-I05→PL-I09∥PL-D06→PL-D09) remains the sole P0 ordering owner per D-055 |
| 3 Semantic selection | **Adopt as ledgered extension** — wedge-scoped (form-fill) first; reuse `AdaptiveInteractionTarget`/`DocumentModel` family (TASK-B1 doctrine constraint); NM-T23 |
| 4 Planner intent compiler | **Adopt only the pattern D-078 already selects** (model proposes, deterministic validator authorizes). A model-assisted planner before a planning-quality harness exists is rejected |
| 5 Unify receipts | **Adopt (partially done this session)** — one lifecycle, plan/trace identity; NM-T17 remainder + follow-up |
| 6 Multi-doc Evidence Workspace | **Defer behind NM-T39 evidence** — adjacent value (cross-doc grounding), "canonical" framing declined |
| 7 Intelligent transformation | **Neutral/late** — matches Category C anti-pattern guardrails already in doctrine |
| 8 Recurring workflow memory | **Adopt as UX packaging of TASK-B4 substrate** — also strengthens the D-052 renewal story; *this*, not workspace, is the prioritized adjacency |
| 9 Mac-native scenes | **Adopt as ledgered extension** — TASK-A4 remainder (App Intents/Spotlight, B5; NM-T09) |
| 10 Freeze capability expansion | **Already doctrine** (Category C) — affirmed |
| Meta: ContentView decomposition | **Adopt under NM-T06's existing gate** (after T01 ownership matrix) — not an interrupt |
| Meta: claims hygiene | **Adopt (done this session)** — see §5 |

## 5. Implemented this session (P1 set, all built + tested)

**Drop workflow (feedback step 1):**
- `AppModel.openDiffComparison(against:)` — parses the dropped PDF and diffs it against the live document with an empty operations ledger (every difference is honestly a difference); `externalDiffComparison` state, cleared on `open()` and on the regular diff path; report export honors cross-doc mode (`AppModel.swift`).
- Preservation gate: `open(url:)` now **flushes** the pending debounced content autosave before replacing the session (was: cancel → silent loss of the debounce window); the drop sheet's Switch action on a dirty session stages a `confirmationDialog` approval boundary ("Preserve Work & Switch" / Cancel) instead of a warning label (`ContentView.swift`, `AppModel.swift`).
- `DiffComparisonView` gained `title`/`emptySummaryText`; cross-doc mode is labeled as such, and the unconditional "Preserved non-destructive audit view (0 unexpected mutations)" claim was removed.

**Receipt/provenance epistemics (feedback meta-point + PER-0922 seat):**
- `ExecutionReceipt`: `executionRoute` and new `ExecutionDataBoundary` (`onDeviceIsolated` / `onDeviceWithEgress`, mandatory, default-less) are observed provenance facts; the unconditional "Cryptographically verified on-device. Zero network egress." trailer removed; status "VERIFIED SUCCESS" → "COMPLETED". (The parallel codex lane landed the enum/plumbing at 08:10; this session landed the honest check derivations on top.)
- Fabricated `passed: true` checks replaced with observed-only checks: egress boundary scoped to the executing path; content-stream integrity derived from a computed diff **only when one exists** (omitted otherwise); metadata from preflight; round-trip from live document. Keychain-storage claim in `teachNorthstarWorkflow` (a session-registration stub) replaced with what actually happens.
- Inspector "Ready" → "Opened"; inspector/standalone/intents claim strings scoped (ANE claim removed — no Neural Engine usage exists in Sources); `CapabilityRoute.onDeviceNeuralEngine` → `.onDeviceLocal` with badges stripped of absolute guarantees.
- Vision doc badge spec changed from `100% COMPLIANT` to scoped count-backed checks.

**Validation:** `swift build` clean; `DeferredContentAutosaveTests` 2/2 pass (exercises the flush path); `DocumentEvidenceGraphTests` 5/5 pass (S2: the disclosure-badge assertion failed after the claim was scoped, then passed under the corrected contract). Remaining "Zero Network Egress" strings in Sources are the doctrine comment banning them.

## 6. Ledger updates
- `docs/task-inventory.md`: NM-T13 (drop-disambiguation semantic defects fixed; T4 proof still open), NM-T17 (receipt epistemic set landed; lifecycle unification remains), new NM-T39 (workspace-canonical falsifier decision brief), new NM-T40 (wire shared EgressGate state into receipt derivation).
- `docs/audits/chatgpt_architectural_review_task_matrix.md`: supersession banner added (its "Completed" claims for A2/A4/A5 are not status authority — D-055; task-inventory owns state).

## 7. Unknowns and falsifiers (unchanged demand-side risks)
- Multi-document workspace demand: resolve via PL-D09 cohort intake question + PL-V03/PL-I15 funnel observation after `DocumentBrowserView` is fed (NM-T39). **Falsifier for step 2:** if no cohort buyer opens a second document while one is open, D-066 stands and workspace-canonical is declined.
- "Materially changed" semantic diff demand: cohort compare task judging text-diff sufficiency.
- Table extraction demand: wire the orphaned `TableExporter` behind the UNDERSTAND tab and count invocations (PL-D12) before writing new extraction code.

## 8. Revisit triggers
Cohort evidence of multi-document sessions (promotes NM-T39) · planner-quality harness existing (unblocks feedback step 4) · D-066 falsifier firing (thesis revision required, not cosmetic).
