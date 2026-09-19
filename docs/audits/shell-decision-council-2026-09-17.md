# Council Decision — MAD-D1 App Shell (AI-Native Direction) — 2026-09-17

**Method:** council-orchestrator (dynamic council). **Doctrine:** OPERATING_DOCTRINE v8.0; decision record lands as **D-083** in `docs/decisions.md`.
**Trigger:** owner directive 2026-09-17 — rejected "stay document-first + gather evidence" as the MAD-D1 answer: *"i have been asking for ai native, new age not some 20 yr old pdf reader thing… think, explore, convene council or multiple councils, document everything."*

---

## 1. Council manifest

### Lead
**PER-0926 Product Evolution Architect** — decision ownership over product evolution sequencing and stability/variability boundaries; same Lead as the 2026-09-17 council (continuity).

### Supporting seats (independent read-only passes, parallel)
| Seat | Persona / basis | Mission | Distinct contribution |
|---|---|---|---|
| Product Thesis Guardian | PER-0172 (`Understanding_Personas_sept6`, docx verified) | Classify conflict vs supersession vs amendment against D-066/D-078/D-071/NM-T39; blast radius | The A-split: D-066's archetype sentence is superseded as thesis; its constraint set survives as invariants; drafted decision language |
| Epistemic Integrity | PER-0922 standard (`docs/audits/epistemic-integrity-audit-per-0922-2026-09-06.md`) | Make vision-led direction claim-honest: slice oracles, tiers, instruments; audit the vision doc itself | Coherence structure (vision selects *what*, falsifiers govern *what may be claimed*); vision doc typed T0 aspiration; 6-slice oracle design; claim-risk findings (§4 "100% native vector fidelity" violation; "Verification & Proof" self-certification) |
| JTBD Researcher | PER-0315 (docx verified) | Jobs, demand instruments under vision-led, sequencing | Job ranking (recurring-forms evidenced > surgery thesis+substrate > understanding thesis > evaluation derivative); outcome test for slice 1; "architecture dressed as outcome" trap named |
| Skeptic | PER-91013 No-Go Adversarial Reviewer (bounded adversarial seat) | Falsify the emerging recommendation; cheapest kill-tests | Thesis-slippage catch (vision §1 critique is spatial, zero AI mentions); "AI-native has almost no AI in it" (sole model runtime = `LocalAssistLane.swift:118-152` label-assist); $4.99 SKU is a cloud product with no lane; 5 Go conditions; visual pillars unconditionally defensible |

### Rejected candidates
PER-0001 Refactor Decision Architect (code-level; orchestrator held implementation evidence directly) · duplicate UX personas (JTBD + vision doc cover the user lens).

### Coverage
Decision ownership ✓ · domain ✓ · user/stakeholder ✓ (JTBD + owner verbatim) · implementation ✓ (orchestrator source verification) · risk/counterposition ✓ (PER-91013) · epistemics ✓ (PER-0922 standard).
**Gap:** no VoC/interview corpus exists (standing repo gap; flagged, instruments carry it — switch interviews recommended before marketing claims).

---

## 2. Ground truth established (verified this session, T1–T2)

- Owner's spatial critique is documented verbatim: `docs/audits/modern_workspace_vision.md:10` — *"the same 20 year old pdf reader as everyone else's"* — and is **about visual/spatial cramping** (four pillars: glass islands, card studio, filmstrip; phases 2–5 "Ready to Execute").
- The agentic substrate is real, wired, and tested: D-078 (`docs/decisions.md:3167`) — deterministic planner/executor (`AgentLoopContracts.swift`, 540 LOC; `AgentLoopTests`), HUD plan sheet, six gate invariants; wired at `AppModel.swift:472+`, `AgentCommandHUD.swift:881`, `ContextualInspectorView.swift:2666`.
- The Agent-Desk trigger is already pulled: D-071 addendum — *"D-073's Agent-Desk trigger is pulled by the D-078 agent loop"* (`DeferredSurfaceRegistry.swift:133-142, 206-212`).
- X7 (`docs/explorations/post-audit-exploration-ledger-2026-09-06.md:66-72`) pre-registered the unification ask + falsifier (ledger-reuse unusable → parallel side panel); its "untracked SessionSidePanel.tsx" note is stale — the file is tracked (`web/app/src/modes/SessionSidePanel.tsx`, companion lane).
- Commercial paper exists: D-052 §5 — "review-first agents whose output is a validated document mutation with provenance — never silent chat output. First lane is agentic form completion."
- The one model runtime in all of Sources is `LocalAssistLane.swift:118-152` (Foundation Models label-assist, macOS 26+, deterministic validator, nil-fallback). Planner is substring matching with `scope: .single` hardcoded (`AgentLoopContracts.swift:434,474`; `AgentCommandHUD.swift:767`).
- The prior council's workspace-canonical demotion (`chatgpt-feedback-council-review-2026-09-17.md` §4 step 2 → NM-T39) governed **multi-document machinery depth**, not shell visual/interaction direction.
- Launch critical path still red: human visual gate regenerated today, `confirmedCount: 0` (0/38); AppModel at 6,550 lines and growing; 70 uncommitted files.

---

## 3. Cross-examined disagreements

| Issue | Position A | Position B | Type | Resolution |
|---|---|---|---|---|
| First slice | EI: read-only agent journal spine (anti-fabrication first) | JTBD: "Teach Northstar" outcome through the loop (2-minute demo) | Sequencing/value | **Composed:** slice 0 = document + instrumentation (Skeptic condition — no new UI); slice 1 = Teach-Northstar through the wired loop *with* the inspectable journal/plan surface, satisfying EI's anti-fabrication oracle and JTBD's outcome test in one demoable thing |
| D-066 disposition | Thesis Guardian: amend, keep falsifier attached to direction | Skeptic: no informal supersession — formalize or withdraw | Governance | **Formalized:** D-083 is the dated owner-directed record (owner directive = approval source, D-078 precedent); D-066 amended (thesis sentence superseded, constraint set retained); NM-T39 re-scoped to own the surviving "whether" questions |
| "AI-native" naming | Owner: AI-native is the identity | Skeptic: claim cannot be cashed (one label-assist lane; $4.99 = cloud credits, no lane) | Value/trade-off | **Split by layer:** direction is AI-native (owner's thesis language, decision record); user-facing claims use D-052 §5 vocabulary ("agentic review-first"); "Agent Desk" name ships only after the spine oracle passes; "AI-native" stays out of UI/marketing until a second model lane exists |
| Is this workspace-canonical re-entering? | JTBD/Thesis: no — loop terminates in validated mutations, has degradation path, X7 falsifier pre-registered | Skeptic: same move through a different door unless gated | Governance | **Skeptic's test adopted:** name the gate each slice rides. Every slice rides the wired D-078 loop (extension) or ships instruments first; multi-document machinery stays declined behind NM-T39 unchanged |

---

## 4. Council verdict

**Conditional Go — recorded as D-083.** The shell's organizing surface is the D-078 agent loop rendered in the spatial language of the vision doc (A1 "Agent Desk" over R1 library). Five non-negotiable conditions (full text in D-083):

1. **Ordering:** D-055 launch critical path stays sole P0 owner; shell slices are paraxial extensions on the wired loop — never interrupts.
2. **Slice 0 is a document + instrumentation, not UI:** X7 unification doc (vocabulary, authority boundaries, **execution-route table** — on-device/deterministic/absent/deferred-cloud per capability), run-journal persistence, PL-D09 cohort instrument with **pre-registered kill thresholds** (<30% of cohort sessions open the loop, or >50% approved-plan abandonment ⇒ organizing-surface falsified; loop remains a wedge tool).
3. **Supersession formalized:** D-066 amended; NM-T39 re-scoped to the surviving whether-questions (library/corpus demand; agentic-organizer demand).
4. **Claim discipline:** D-052 §5 vocabulary for user-facing claims; no "AI-native" in UI/marketing until a second model lane ships; zero-egress default untouched; the $4.99 cloud lane stays a separate decision gate with its margin math re-run.
5. **Decomposition rides first:** T01 ownership matrix accepted + the AppModel seams the shell touches extracted (A-9/X6) before the first new shell surface — the shell is the pressure evidence X6 required.

**Unconditionally unblocked (separate track):** the visual pillars (glass islands, filmstrip rail, card studio styling) as styling on existing surfaces — they answer the owner's verbatim spatial critique, are low-coupling and recoverable, and are not held hostage to the agentic bet. Each surface still passes MAD-R1/R2 accessibility + human-visual evidence.

---

## 5. What remains unverified / open

- PL-D09 cohort instrument is designed but unrun (gated on commerce PL-I04 per launch audit).
- Run-journal persistence unverified (slice-0 check: `AgentRunJournal` is an in-memory struct today).
- No VoC/switch-interview corpus — demand judgments remain repo-ledger-based; 5–10 switch interviews with PDF Expert/PDFpen emigrants recommended before marketing claims.
- Cohort hardware mix vs macOS 26 (Foundation Models availability) unknown — add to PL-D09 intake.
- Line counts drift under the parallel lane; re-pin at implementation time.

## 6. Roster history
No expansions or contractions; 4 seats + Lead as dispatched. Skeptic joined conditionally-Go rather than No-Go on the strength of the wired-loop evidence.

## 7. Next action
Owner ratifies D-083 (this record) → slice 0 begins: NM-T41 (X7 unification doc + journal persistence + PL-D09 instrument + thresholds). Then decision discussion #2 (MDEV-I6 sequencing) from the standing decision list.
