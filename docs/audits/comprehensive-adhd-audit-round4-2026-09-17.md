# Comprehensive ADHD Audit — Round 4 — 2026-09-17

**Problem P (post-D-083):** Northstar is now an owner-directed AI-native agentic document
workspace (D-083): the agent loop (plan → preview → approve → execute → validate → receipt) is
the organizing surface; every mutation is human-approved and leaves provenance; zero network
egress; single-user trust product ($79 + $4.99 AI). What capabilities, interactions, trust
mechanics, or identity moves would make it genuinely new-age — past the obvious answers?

**Frames (disjoint from rounds 1–3 where possible):** Inversion (the one untouched table frame),
Time traveler, The document's perspective (wild), Insurance underwriter, Museum curator — four
composed frames because 14 of the table's 15 were consumed by rounds 1–3. Five isolated parallel
divergent agents (6 ideas each, JSON-only, no cross-contamination), then critic phase: scoring
(novelty 0.35 / viability 0.40 / fit 0.25), clustering, trap flags, three focus agents on the top
branches (one per cluster for breadth).

**Ban-list compliance:** the full R1–R3 union (83 slots) was supplied to every branch as
already-known; the obvious three (chat sidebar, generic autofill, AI summaries) were banned.
D-078 mechanics flagged as collisions where they resurfaced (R4-03, R4-06).

---

## 1. Branch outputs (verbatim)

### Frame: Inversion
1. **Rehearsal mode by default** — every plan first executes on a throwaway copy, and only the inspected diff graduates to the real document. *(Mechanism negated: approvals made irreversible so users fear experimenting → experimentation becomes free.)*
2. **Confidence quarantine** — any field the agent cannot prove gets abstained and parked for human entry, never filled with a guess. *(Negates silent wrong fills poisoning future approvals.)*
3. **Drift lock** — if the document changes underneath a running plan, the plan visibly invalidates and re-baselines instead of proceeding. *(Negates executing against stale snapshots.)*
4. **Redline zones** — user-declared fields/pages/sections the agent is structurally incapable of proposing against, enforced at loop level. *(Negates auditing every pixel every time.)*
5. **Challenge-and-replay** — any executed step can be flagged after the fact, and the agent must re-derive it live in front of you from the source. *(Negates orphaned users with no appeal.)*
6. **Single-use authority** — approvals never bank; each grant authorizes exactly one execution and expires. *(Negates all-or-nothing trust.)*

### Frame: Time traveler
1. **Standing orders** — approvals can carry dated conditional intents ("if the statute rate changes, reopen this clause") that bind future sessions.
2. **Assumption-TTL approvals** — every approved mutation records the assumptions it was approved under, and they visibly expire.
3. **Agent succession memo** — on model/app upgrade the outgoing agent writes a handover the new agent must read and the owner countersign before its first mutation.
4. **Retroactive validation sweeps** — as local rule packs version up, old approved edits are re-judged against today's rules; a "would-this-pass-now" heat surface appears.
5. **Charter ratification** — each session opens by ratifying a short versioned intent charter; drift between charter and document trajectory is the first agenda item.
6. **Dormancy rehearsal gate** — before touching a long-idle document the agent must narrate its reconstructed understanding of the prior arc; the owner marks each error, feeding a correction log.

### Frame: The document's perspective
1. **Consent interview at open** — the document cross-examines the agent before granting workspace rights.
2. **Field testimony** — fields carry spoken constraints ("I am the lease start date, not today's date") and can veto a specific fill even when the overall edit is approved.
3. **Anatomy-based counterproposal** — when the document refuses a planned edit, it argues from its own body and offers alternative placement.
4. **End-of-life petition** — a document approaching its destiny asks for disposition: be filed, be returned, be deleted.
5. **Twin tribunal** — near-duplicate detection demands the agent determine original vs impostor.
6. **Stale-section recanting** — the document nominates its own outdated parts and asks the agent to sever them.

### Frame: Insurance underwriter
1. **Experience-rated autonomy** — revert history per document class prices a local rate card; consecutive clean sessions auto-pass advisory-level confirmations like a no-claims bonus.
2. **Deductible absorption** — the first N low-cost mistakes are auto-reverted; above the deductible, every mutation demands countersignature. *(Branch wording said "silently" — flagged, see traps.)*
3. **Claim settlement as scoped counter-mutation** — a claim reconstructs before/after state from receipts; the payout is a targeted revert of just the loss.
4. **Capability riders** — high-blast-radius operations require attaching a per-job rider that pre-commits extra validation checkpoints; unriddered batch jobs are refused at quote time.
5. **Void conditions contract** — user and agent co-author the policy's exclusion schedule; a voided document visibly exits insured state until re-underwritten.
6. **Subrogation ledger** — every claim is attributed to a responsible party (importer, agent, owner) via receipt-chain analysis.

### Frame: Museum curator
1. **Acquisition charter** — the agent refuses intake outside a user-authored collection scope.
2. **Conservator mode** — the agent never edits in place; reversible annotation layers over a sacrosanct original, each deeper intervention priced in escalating consent.
3. **Tombstone labels** — museum-style label (maker, date, medium, why acquired) drafted by the agent, corrected by the curator, shown before content.
4. **Gallery rotation** — the agent rehangs a finite "on view" shelf on a schedule.
5. **Deaccession ceremony** — deletion becomes a formal rite: retire to deep storage, export-and-forget, or destroy — each its own approval.
6. **Original order** — the agent never auto-organizes; it preserves the user's arrangement as evidence and offers views over it instead of moves.

---

## 2. Scoring, clusters, converge

Scores: `[N novelty / V viability / F fit]`, weighted = 0.35N + 0.40V + 0.25F.

### Cluster A — Earned autonomy & priced risk (trust as computed currency)
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R4-19 | Experience-rated autonomy | [N9 V7 F9] | 8.20 | parked-explorable (child of R4-20) |
| R4-22 | Capability riders | [N8 V8 F9] | 8.25 | parked-implementable |
| R4-21 | Deductible absorption | [N8 V6 F8] | 7.20 | parked-conditional — TRAP as worded |
| R4-24 | Subrogation ledger | [N8 V6 F7] | 6.95 | parked-explorable |
| R4-06 | Single-use authority | [N6 V9 F8] | 7.70 | parked-conditional (D-078 collision) |

### Cluster B — Rehearsal & reversibility (nothing real until inspected)
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R4-01 | Rehearsal mode ★ | [N9 V8 F9] | 8.85 | deepened |
| R4-20 | Claim settlement ★ | [N9 V8 F9] | 8.55 | deepened |
| R4-26 | Conservator mode | [N8 V8 F9] | 8.25 | parked-implementable |
| R4-23 | Void conditions | [N7 V5 F7] | 6.20 | parked-conditional |

### Cluster C — Visible uncertainty & refusal (the agent shows what it doesn't know)
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R4-14 | Field testimony ★ | [N9 V7 F9] | 8.20 | deepened |
| R4-02 | Confidence quarantine | [N7 V9 F9] | 8.30 | parked-implementable |
| R4-04 | Redline zones | [N8 V7 F9] | 7.85 | parked-explorable |
| R4-03 | Drift-lock surfacing | [N4 V9 F8] | 7.00 | parked-conditional (D-078 collision) |

### Cluster D — Accountability across time
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R4-08 | Assumption-TTL approvals | [N9 V7 F8] | 7.95 | parked-explorable |
| R4-05 | Challenge-and-replay | [N9 V7 F9] | 8.20 | parked-implementable |
| R4-09 | Agent succession memo | [N10 V6 F7] | 7.65 | parked-explorable |
| R4-10 | Retroactive validation sweeps | [N9 V6 F8] | 7.55 | parked-explorable |
| R4-12 | Dormancy rehearsal gate | [N9 V6 F8] | 7.55 | parked-explorable |
| R4-07 | Standing orders | [N9 V5 F8] | 7.15 | parked-explorable |
| R4-11 | Charter ratification | [N8 V6 F7] | 6.95 | parked-conditional |

### Cluster E — Document dignity & governance rites
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R4-27 | Tombstone labels | [N8 V8 F7] | 7.75 | parked-implementable |
| R4-30 | Original order | [N8 V8 F7] | 7.75 | parked-implementable |
| R4-17 | Twin tribunal | [N9 V6 F6] | 7.05 | parked-explorable |
| R4-15 | Anatomy counterproposal | [N9 V5 F8] | 7.15 | parked-explorable |
| R4-25 | Acquisition charter | [N8 V7 F6] | 7.10 | parked-explorable |
| R4-29 | Deaccession ceremony | [N8 V7 F6] | 7.10 | parked-explorable |
| R4-16 | End-of-life petition | [N8 V6 F6] | 6.70 | parked-conditional |
| R4-13 | Consent interview | [N10 V4 F7] | 6.85 | parked-conditional — TRAP as worded |
| R4-18 | Stale-section recanting | [N8 V4 F6] | 5.90 | parked-conditional |
| R4-28 | Gallery rotation | [N7 V7 F5] | 6.50 | parked-conditional — TRAP |

### Traps (recorded, not deleted)
- **R4-28 Gallery rotation** — multi-document corpus management sits inside NM-T39's declined scope (D-083 boundary). Promote only when NM-T39's cohort falsifier fires.
- **R4-21 Deductible absorption** — "silently auto-reverted" violates the honesty doctrine (never silent). Viable only reframed as *logged* micro-reverts with visible receipts; promote under that reframe.
- **R4-13 Consent interview** — literal document-persona UX is gimmick-risk; the salvageable core (open-time interrogation of capabilities vs document) collides with R3-02/R3-24's operating-envelope open-time wiring. Promote through that lane, not as a persona.

### D-078 collision notes (already-known mechanics, new UX)
- R4-03 drift lock: digest-binding exists (D-078 invariant 4); the idea's value is the *visible re-plan experience* — rides slice 2.
- R4-06 single-use authority: per-step approval exists (invariant 5); expiring grants are a policy twist — promote only if approval-banking demand is observed.

---

## 3. Deepened branches (focus-agent output, verbatim-condensed; full JSONs in session)

### R4-01 Rehearsal mode (cluster B) ★
**Sketch:** Export-only architecture makes rehearsal nearly free — a document is (source + operations ledger), so a throwaway copy is an in-memory ledger fork, not a file copy. The D-078 loop gains a rehearsal phase: plan mutations apply to the forked ledger; the existing export builder renders current vs candidate; approval presents a page-pair diff plus the op list — the user approves an inspected diff, not a promise. Graduation is a second deterministic execution onto the live ledger with render-hash comparison: identical means "applied bit-identical to what you inspected" (identity claim, not "verified safe" — D-067). Receipts embed the diff artifact as evidence of what the human actually saw. Any rehearsal/graduation divergence aborts graduation.
**Load-bearing risk:** drift between inspection and graduation — graduation must bind to the rehearsal's exact (source digest + ledger digest) and refuse on mismatch; secondary risk is rubber-stamping, countered by per-op graduation granularity for destructive steps.
**First concrete step:** add an in-memory ledger fork (`Ledger.clone()`) + a `dryRun` flag on the D-078 executor routing mutations to the fork; invoke the export builder twice inside the existing preview stage to emit a page-pair diff from real plans — prove deterministic rehearsal render + hash comparison on current `AgentLoopContracts.swift` contracts before any graduation UI.
**Children:** per-op graduation (blast-radius-matched granularity) · hash-gated graduation with honest identity language · inspected-diff artifact embedded in receipts · rehearse-the-undo (compute and show each plan's inverse up front) · what-if branches (named candidate forks diffed against each other — git-like scratch space, nearly free in this architecture).

### R4-20 Claim settlement as scoped counter-mutation (cluster B) ★
**Sketch:** A claim is filed against a single ledger step (run id + step id from the D-078 journal, cross-checked against the ExecutionReceipt). Intake is read-only: replay source+ledger[:k] vs source+ledger[:k+1] through the deterministic replay path, emit a pre/post diff artifact — the adjuster's report. Payout scope: full revert of the disputed op or a narrower slice over touched pages/annotations. Settlement executes NOT as history surgery but as a new append-only counter-mutation entry, so the ledger stays append-only, replay stays deterministic, and D-078 invariants are untouched; the settlement itself is receipted (existing `ReceiptSigning` path). Presents reconstructed digests and diffs as evidence — never asserts verification beyond receipts (D-067).
**Load-bearing risk:** mid-history counter-mutation has no dependency semantics today — `VersionStore.operationsForRevert` only reverses a suffix; scoped payouts for arbitrary positions need a per-operation dependency/touched-resource graph that does not exist yet. Without it, settlements are safe only for suffix-adjacent or independent ops.
**First concrete step:** read-only claim-intake primitive beside `Sources/PDFEditorCore/VersionStore.swift` — `reconstructPair(at k)` returning pre/post state digests via existing `computeDigest` + `DocumentDiffReport`, with a golden test modeled on `RotatedReplayFixtureTests` asserting digests on a hand-built two-op fixture and no ledger mutation.
**Children:** experience-rated autonomy (settlement history = loss-ratio dataset; rate-card policy layer over `AgentRunJournal` — zero new instrumentation) · capability riders (pre-committed checkpoints per high-blast-radius op; failed checkpoint auto-files a claim) · claim preview before filing (read path over the same reconstruction) · resource-scoped payouts (declare touched-resource sets per op — doubles as the dependency graph that mitigates the risk) · settlements are claimable too (bounded chain depth; approval receipts become evidence in contested-authorization disputes).

### R4-14 Field testimony (cluster C) ★
**Sketch:** A testimony is a persisted, typed constraint bound to a field by (source digest, field FQN): {predicate, origin: user-authored|user-ratified, verdict history}. Predicates ship as a closed enum matching D-076 launch scope — date/window and numeric bounds for text, enum-membership for choice, pairwise must-stay-empty-when/must-equal cross-field — pure and deterministic. `LocalAssistLane` may *draft* proposals, inert until user ratification. At plan time, validation consults active testimonies per mutating fill step; a violation converts the step into a structured abstention (field, testimony id, proposed value, plain-language reason) surfaced during plan review. Post-fill, the same predicate re-asserts as defense in depth. Testimonies live per-document by digest; ratification hooks into the existing candidate-review flow as one-tap "make this a rule."
**Load-bearing risk:** cold start + veto noise — if capture is a separate chore it never happens, and one false veto blocking an approved plan erodes trust faster than ten silent fills. Lives or dies on (a) one-tap promotion of corrections into ratifiable proposals and (b) every veto legible, quoted verbatim, overridable (waive once / retire).
**First concrete step:** `Sources/PDFEditorCore/FieldTestimonyContracts.swift` (FieldTestimony, closed predicate enum, FieldTestimonyStore keyed by digest+FQN); extend plan validation in `AgentLoopContracts.swift` so a violating fill step emits a structured abstention; unit test driving one fixture's money field past its bound.
**Children:** correction-to-rule promotion (via `CandidateReviewLearningEvents`, prior-weighted suggestions) · template-carried testimonies (semantic-name keys, exact-then-alias binding with explicit rebind confirmation) · structured objection panel (quote verbatim; supply value / waive once / retire) · dry-run testimony sweep (plan-time flagging, planner re-proposes) · cross-field constraint graph (cycle + contradiction detection at ratification time).

---

## 4. Provocation

The deepest pattern across all five frames: every trusted-agent mechanic here is a **rehearse-then-settle** loop — inspect on a fork, graduate by hash, dispute by counter-mutation, constrain by testimony. That means the app's real differentiator is not the agent; it is the **mutation ledger** — a database of every proposed, approved, executed, disputed, and reverted change to a document. No PDF competitor has that as a first-class product. Wildcard: would you position Northstar as *"the first document tool where every change is provable, reversible, and attributable"* — selling the ledger, with the agent as merely its most convenient writer?

---

## 5. Persistence

All 30 candidates (incl. traps and rejects) are registered in
`docs/explorations/adhd-exploration-pool-ledger.md` §"Round 4 pool" with statuses and frame tags;
the ban list there is extended to this pool. No graduations this round; two delta notes recorded
(R4-13 ↔ R3-02/R3-24 envelope wiring; R4-26 conservator mode formalizes D-068 as UX and should be
re-read against the vision doc's styling track). Statuses: 3 deepened, 6 parked-implementable,
11 parked-explorable, 10 parked-conditional.
