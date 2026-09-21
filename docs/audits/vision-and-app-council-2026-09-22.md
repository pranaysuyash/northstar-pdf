# Vision & App Council — designers / experimenters / out-of-the-box review of the AI-native thesis

- **Date:** 2026-09-22
- **Requested outcome:** review (assess) — the owner's vision (`IDEA.md`: "a modern new age ai native pdf reader/editor made from 1st principles"), the app as built, the docs, and whether the decision stack serves the vision.
- **Governing skill:** `council-orchestrator` (persona source: `/Users/pranay/Desktop/Understanding_Personas_sept6`, canonical pointer, confidence high).
- **Doctrine routing:** REVIEW_DOCTRINE mode (review/judge); evidence tiers per OPERATING_DOCTRINE §2–3. Read-only council (L0); the only mutation is this artifact.
- **Method note:** all seats read the live repo (T1 static evidence) on 2026-09-22. No runtime, visual, or user-behavior evidence was produced by this council. Frontier/product-wave claims are marked external inference (training knowledge, cutoff-limited).

## Council Manifest

**Lead:** PER-0926 Product Evolution Architect — product-direction ownership; continuity with the MAD-D1 council (2026-09-17) that produced D-083.

**Supporting seats**

| Seat | Type | Mission | Why needed |
|---|---|---|---|
| PER-0755 Principal Product Designer | Persona | Judge app-as-built vs four-pillar vision; is "styling track" sufficient | Design craft lens the owner explicitly requested |
| PER-1228 Workspace UX Architect | Persona | Does the workspace *shape* (agentic spine vs document desk) cohere | Thesis-vs-visual-language structural question |
| PER-0749 UX Researcher for Expert Tools | Persona (experimenter) | Audit D-083's kill-test measurability; design cheapest real experiments | "Experimenters" lens requested by owner |
| PER-0436 Technology & Innovation Scout | Persona (out-of-box) | Transfer 2025–26 wave patterns; generate non-obvious directions | "Thinks out of the box" lens requested by owner |
| PER-0172 Product Thesis Guardian | Persona | Is the owner's AI-native thesis being executed, deferred, or drift-washed | Protects owner-directed direction from council dilution |
| PER-91013 No Go Adversarial Reviewer | Persona (skeptic) | Falsify both the direction and the status quo | Consequential decision ⇒ skeptic pass warranted |

**Coverage:** decision ownership = Lead · domain/design = PER-0755 + PER-1228 · methods/instruments = PER-0749 · frontier/counterposition-generative = PER-0436 · thesis protection = PER-0172 · risk/falsification = PER-91013.

**Rejected candidates:** PER-0752 HCI Researcher (overlaps experimenter), PER-0162 Contrarian Strategist (overlaps adversarial seat), PER-0725 Spatial UX Designer (folded into PER-1228), PER-0315 JTBD Researcher (prior council seat; demand questions routed to instruments instead of another voice).

**Known gaps (stated, not hidden):** no user-behavior evidence exists anywhere (PL-D09 never ran; cohort gated behind commerce PL-I04 at ~0%); no rendered-app observation in this session (design claims are T1 static + the vision doc's 2026-09-06 one-shot screenshot); launch-gate *current* state inferred from the 2026-09-07 launch audit, not re-verified against `docs/release-gates.md`; frontier claims are external inference.

## Input ground truth (observed)

- `IDEA.md:1` — owner thesis, unchanged since first written.
- `docs/decisions.md:3386-3411` — D-083: AI-native agentic review-first shell; "Agent Desk" (A1) over library (R1); slices NM-T41…45; per-slice falsifiers "never on the direction"; D-055 remains sole P0 ordering owner; "AI-native" banned from UI until a second model lane exists.
- `docs/audits/modern_workspace_vision.md` — four-pillar aspiration blueprint (T0, owner-directed); phases 2–5 "Ready to Execute"; every phase gated on MAD-R1/R2 + human-visual evidence.
- `docs/task-inventory.md:109-115,137-138` — **all shell slices NM-T39…45 `open`**; NM-T46 (signature overlay writer) landed and NM-T47 partial on 2026-09-21.
- `git log` (read-only) — commits 2026-09-14→09-19: CI repair, perf S-register, App Intents, Jev spike unblock. **Zero commits advance any D-083 slice**; the directive is dated 2026-09-17.
- `Sources/PDFEditorApp/` — the four-pillar vocabulary exists only as fragments (HUD capsule `DocumentCanvasView.swift:436-445`, segmented tabs `ContextualInspectorView.swift:6-26`, semantic badges); toolbar still ~13 elements (`ContentView.swift:663`, MAD-006); rail leaks `chars · W×H` diagnostics the vision bans (`PageThumbnailRailView.swift:243`); zero `reduceTransparency`/`increaseContrast` handling (MAD-008).
- `AgentRunJournal` is in-memory only (`Sources/PDFEditorCore/AgentLoopContracts.swift:532`); receipts lack a plan/trace join id (NM-T17, `task-inventory.md:108`).
- Launch context (from `docs/audits/persona-launch-acceptance-audit-2026-09-07.md:13`): NO-GO for GA; RG-135 human-visual gate historically 0/38; commerce ~0%.

## Seat findings (condensed; full reports in session transcript)

- **PER-0755 (design craft):** Pillar *fragments* exist; pillars do not. Top gaps: toolbar density (the most "2004" surface), no page paper elevation (pillar 1's core effect), rail/inspector metadata clutter. Styling track is sound **only if scoped to include chrome demotion and hierarchy restructuring** — re-skin-in-place yields "a beautifully rendered 20-year-old reader." A11y substrate (MAD-008) must precede all glass work. Five ordered moves: shared a11y `WorkspaceChrome` → page paper elevation → rail declutter → toolbar demotion into first real island → inspector two-tier hierarchy. Confidence: medium-high.
- **PER-1228 (workspace shape):** Topology is coherent on paper ("agent workspace over a bounded document completion core") but structurally disconnected: the loop presents as a modal sheet inside a 2,607-line monolith — today's real topology is "one document window, everything else modal." Spine move: make the plan/journal a **persistent spatial lane** beside the document stage, not a sheet. Library question needs its own pre-registered observables; PL-D09's thresholds measure loop adoption, not library demand. Confidence: medium-high.
- **PER-0749 (experimenter):** The slice-0 kill test is **unmeasurable as written** — no cohort exists; PL-D09 is gated on commerce (critical path); pooled session rates would be dominated by heavy users. Fixes: per-user operationalization, GUI-only rows, owner self-tests excluded from thresholds, named consumption date, journal persistence (NM-T41) + NM-T17 join as the ~1–2 day minimum instrument. Three cheap experiments: E1 switch interviews (5–8, guide already written) · E2 instrument shakedown (owner, 10 sessions) · E3 styling forced-choice test (merge recruiting with the owed RG-135 pass). Fastest path to a real cohort is PL-I04 commerce, not more instrument design. Confidence: high on gaps.
- **PER-0436 (out-of-box):** Transferable patterns (external inference): diff-as-artifact (Cursor), ghost-capture-then-structure (Granola), omnibox-with-honest-degradation (Raycast — already encoded in D-083 slice 2), personality-as-trust (Dia). **Bet: the "won't-change map"** — render the impact validator's proof as a per-page disturbance map users see before approving bulk fills; nobody in the category can *prove* non-disturbance, and it de-risks every agentic slice. Ledger-as-product (browse/revert/export notarized history) rides the real Ed25519 receipt chain. Kill: Rewind-class ambient capture (privacy/cost tar pit; zero-egress already forbids it). Ages badly: deterministic-planner-first if Apple's on-device models subsume typed planning — revisit trigger exists but is under-specified. Confidence: medium-high grounding, medium frontier.
- **PER-0172 (thesis guardian):** Verdict: **drift-washed** — superbly documented, zero execution atoms. D-083 ¶6 ("paraxial, not interrupts") + D-055 sole-P0 make every launch lane indefinitely outrank the owner's stated direction; five days post-directive, capacity went to the stamp writer, not the slice requiring only documents and journal persistence. `docs/INDEX.md` omits D-083 entirely. Smallest thesis-visible increment: **NM-T41 now** (no UI gate), then T01 matrix + A-9 seams, then slice 1 (NM-T42) — the first surface that *looks* like the thesis using only D-052 §5 "review-first" vocabulary. Recommended amendment: a **thesis reservation** — dated slice-0 checkpoint plus a standing lane allocation. Confidence: high on the observed facts, medium on intent.
- **PER-91013 (skeptic):** Against the direction: it cannot ship its claim (no second model lane exists or is funded; Jev dead) and cannot fail its test (cohort unreachable pre-GA) — currently *unfalsifiable and invisible*. Against the status quo: launch is blocked on human-visual review, not engine quality, so polishing moves nothing, and the owner's own quote means the status quo fails the vision by assertion. Second-order risk: for a one-off form, the loop is strictly slower than the already-implemented Guided Next Blank path. Settlement test: run slice-1's outcome test at n=1 (owner as cohort) with the added bar **faster than Guided Next Blank**; write it into task-inventory. Confidence: medium-high.

## Cross-examination of material disagreements

| Issue | Position A | Position B | Type | Resolution |
|---|---|---|---|---|
| Direction-level falsifiability | PER-91013: "per slice, never on the direction" is unfalsifiable by construction; kill test unreachable pre-GA | PER-0172: rails protect honesty but have become a deferral mechanism | Evidentiary + value | **Both right; not a direction vote.** The direction is owner-asserted (D-083 explicitly) and is not re-litigated. The council amends the *falsifier regime* to be reachable (see Decision R4) and adds the dated checkpoint (R1). The honest failure signal now has an owner-date. |
| Agent loop vs Guided Next Blank | PER-91013: loop strictly slower for one-off forms; slice-1 "<2 min" oracle too weak | D-083 slice-1 oracle as written | Evidentiary | Adopt the sharper bar: slice 1 must beat the direct path on time for the same task, at n=1, recorded in task-inventory (Decision R4b). If it cannot, that is real evidence about the spine's wedge scope — not a direction kill. |
| Styling track scope | PER-0755/PER-1228: as-scoped "styling" re-skins 2004; must include chrome demotion + hierarchy | Vision doc phases 2–5 as written | Evidentiary (what "styling" means) | "Styling" is reinterpreted for the record as **chrome restructuring + hierarchy on existing surfaces** (Decision R3); pure re-skin is out. This is consistent with, not an amendment of, D-083's intent ("styling on existing surfaces" was never "re-skin in place"). |
| Library/corpus demand | PER-1228: PL-D09 can never answer the library "whether" question | D-083 ¶3 re-scopes NM-T39 to cohort instruments | Evidentiary | Keep the re-scope; add library-demand observables (recents re-find rate, multi-document session recurrence) to the instrument so NM-T39's question can actually fire (Decision R5). |

## Council Decision

### Recommendation

**The vision stands and is executed, not re-litigated — but it gets a dated heartbeat, a sharper test, and one headline surface.** Six reconciled actions:

1. **R1 — Thesis reservation (D-083 amendment candidate, owner ratifies):** slice 0 (NM-T41) ships by a dated checkpoint — propose **2026-09-30** — regardless of launch-path pressure, and the shell slices receive a standing lane allocation instead of pure paraxial status. Rationale: the observed execution pattern (all slices open, zero thesis commits post-directive) is the failure mode the adversarial and guardian seats independently identified. NM-T41 has no UI gate and is executable in days (X7 doc + persist `AgentRunJournal` + PL-D09 instrument).
2. **R2 — Fix the falsifier regime so it can actually fire:** per-user operationalization of PL-D09 thresholds (≥30% of *users* opening the loop within first 5 GUI sessions/14 days; abandonment = approved plan with no terminal receipt/journal row), GUI-only rows, owner self-tests excluded from threshold counts, named consumption date. Record plainly in D-083 that the direction-level cohort test is unreachable pre-GA/commerce and name the reachable proxies until then (E1 interviews, E3 styling test, n=1 outcome test).
3. **R3 — Restate the styling track as chrome restructuring:** pillar work = demoting the 13-element toolbar into real islands, two-tier inspector hierarchy, rail declutter, page paper elevation — all built on one shared accessibility-aware chrome component that closes MAD-008 first. Pure re-skin is declined for the record: it reproduces the exact "20-year-old reader" the owner rejected, in nicer materials.
4. **R4 — Adopt the sharper spine tests:** (a) slice-1 outcome test at n=1: one stated goal → validated receipted mutation in <2 minutes **and faster than Guided Next Blank** for the same task; (b) E1 switch interviews (5–8, using the already-written guide) before slice-1 spend; (c) E3 styling forced-choice test merged with the owed RG-135 recruiting. The loop-vs-direct-path question becomes measurable this week, not after a cohort exists.
5. **R5 — Headline the provable-ledger surface (the bet):** make the "won't-change map" — the impact validator's non-disturbance proof rendered per-page before bulk-fill approval — the first thesis-visible *differentiator*, and move the plan/journal from a modal sheet to a persistent spatial lane beside the document stage (the spine move). Both ride capabilities that already work (impact validator, receipt chain, journal contracts) and unify the two independent "this is the real product" calls from the scout and the workspace architect. No claim-discipline violation: it is review-first vocabulary and evidence, not "AI-native."
6. **R6 — Documentation repairs:** register D-083 and slice status in `docs/INDEX.md`; add library-demand observables to NM-T39's instrument spec; record the D-078 revisit trigger's concrete trip condition (a named on-device capability benchmark, not a vague "planning-quality harness change").

### Why

Four of six seats independently converged on the same diagnosis from different mandates: the thesis is decided but invisible, the falsifiers cannot fire, and the styling track as literally scoped would fail the owner's own acceptance test. The two genuinely adversarial positions (skeptic vs guardian) resolve without a direction vote because the owner's directive governs at vision level (standing directive; D-083 ¶"direction is owner-asserted") — what changes is reachability, measurability, and sequencing pressure, not the destination.

### Evidence tiers

All factual claims above: T1 (static inspection, file:line cited) except the 2026-09-06 rendering observation (T4 one-shot, per vision doc §4) and frontier/product-wave claims (external inference, cutoff-limited). No T2+ evidence was produced by this council. The n=1 slice-1 outcome test (R4a) is the designated first Tier-2/3 check.

### Important trade-offs

- The dated checkpoint (R1) taxes the launch critical path by design; that is the point of a reservation — D-055 keeps ordering authority for everything else.
- Restructuring chrome (R3) is slower per surface than re-skinning; it is also the only version that survives the owner's critique.
- The n=1 speed bar (R4a) can return a result the spine doesn't want; that risk is accepted because an unfireable test is worse (skeptic's finding).

### Material dissent (preserved)

PER-91013 maintains that absent a second model lane the direction cannot ship its own name and may be a "deterministic automation script wearing spatial styling"; PER-0172 maintains the rails, not the direction, are the current failure point. Both positions are recorded in full above; the Lead's reconciliation is R1–R6, which requires execution to occur before either verdict can be tested.

### Unknowns / what would change the recommendation

- Whether the owner's next owner-hours go to commerce (PL-I04) — if yes, R2's cohort path accelerates and the interview proxies matter less.
- T01 ownership-matrix and A-9 seam-extraction state (unknown at council time; gates slice 1, not slice 0).
- D-078 loop internals unread by this council; the R4a speed measurement is the resolving check.
- Current `docs/release-gates.md` state not re-verified (2026-09-07 audit used as source).

### Next action

Owner ratifies R1's checkpoint date and R4's amended oracle, then NM-T41 executes (it needs no ratification to *start* — it is unblocked work). Falsifier for this council's own recommendation: if NM-T41 + the n=1 slice-1 test do not happen by the ratified checkpoint, the guardian's "drift-washed" verdict stands as the council's standing finding and R1's reservation has failed.

**RATIFIED 2026-09-22:** the owner directed "do all" the same day; R1–R6 are accepted as **D-083 Amendment 1** (`docs/decisions.md`). Slice-0 instrument landed same day (`AgentRunJournalLog` + AppModel/HUD wiring + tests); R3 first tranche landed (rail declutter + halo, page shadows, HUD reduce-transparency fallbacks) with before/after captures in `docs/audits/screenshots/2026-09-22_workspace_*.png`. X7 doc remains the NM-T41 item due at the 2026-09-30 checkpoint.

**Roster history:** no expansion or contraction after initial dispatch. **Unverified remainder:** everything tagged Unknown above; no user-behavior, runtime, or visual evidence was generated in this session.
