# Comprehensive ADHD Audit — Round 5 — 2026-09-17

**Problem P (continuation of R4's provocation):** assume Northstar's differentiator may be the
**mutation ledger** — every proposed/approved/executed/disputed/reverted change recorded,
receipted, replayable ("every change provable, reversible, attributable") — rather than the agent
itself. What products, capabilities, trust mechanics, business moves, or identities does a
first-class document mutation ledger enable — and what would falsify the ledger-as-product thesis?

**Frames (all composed — the skill table's 15 frames were exhausted by rounds 1–4):**
Git historian / VCS archaeologist · Notary & legal clerk · Accountant / auditor · Platform
economist · Music-producer & film-editor (non-destructive craft). Five isolated parallel
divergent agents (6 ideas each), then scoring (novelty .35 / viability .40 / fit .25),
clustering, trap flags, three focus agents on the top branches.

**Ban-list compliance:** full R1–R4 union (113 slots) supplied as already-known — including
R4's rehearsal mode, claim settlement, field testimony, what-if branches, rehearse-the-undo,
capability riders; D-078 mechanics; the obvious three. Collisions declared in §4.

---

## 1. Branch outputs (verbatim)

### Frame: Git historian
1. **Redline rebase** — replay an approved mutation chain onto a freshly updated upstream template; surface only the hunks that no longer apply cleanly.
2. **Patch bundles as the travel format** — export a mutation series as a self-verifying bundle any instance can apply offline; the diff moves instead of the document.
3. **Ledger reflog** — denied, discarded, and superseded proposals stay addressable forever; "I lost the version" becomes impossible by construction.
4. **Pinned clause submodules** — documents embed other documents at a specific ledger hash; edits to a shared clause library require an explicit bump to propagate.
5. **Ledger bisect** — hand the system one bad state and one good state; it binary-searches the ledger to the exact mutation where the defect entered.
6. **Pre-approval hooks** — before a mutation lands, lint gates run on the ledger entry itself: protected terms touched, totals changed, whitespace-only diffs, forbidden regions edited.

### Frame: Notary / legal clerk
1. **Liber-and-folio citation** — every document state registered with a volume/page citation so courts and counterparties can reference exact states.
2. **Exemplified-copy issuance** — export any historical state as a clerk-style exemplified copy whose certification page attests conformity between copy and recorded state.
3. **Codicil amendment protocol** — in-place edits forbidden by the data model; every change is an appended codicil instrument; the document exists only as a stack of instruments.
4. **Abstract-of-title generator** — a one-page clerk-authored abstract tracing chain of custody, formatted for counterparties or courts.
5. **Witnessed execution ceremony** — a two-device witnessing mode where a second person countersigns the ledger entry at execution, offline via local handoff.
6. **Executor custody succession** — a designated successor custodian whose sealed key-material can open and attest the ledger on incapacity, death, or business transfer.

### Frame: Accountant / auditor
1. **Balanced-entry enforcement** — no mutation commits unless its offsetting counter-entry exists; unbalanced proposals rejected like unbalanced journal entries.
2. **Trial balance self-audit** — one-click reconciliation: replay every ledger entry, assert the sum reproduces the current export bytes; drift marks the document "out of balance" and quarantines agent writes until resolved.
3. **Fiscal closing of a document** — the owner "closes the books" on a period (e.g., post-signature), freezing those pages; later changes are dated adjusting entries that name what they reopened.
4. **Provision register** — known future obligations (renewals, expiring terms) booked now as accruals; the ledger carries planned mutations before they happen.
5. **Depreciation with write-down events** — each field's support decays as its source ages; each write-down is a recorded event ("clause support depreciated to 40% — revaluation required").
6. **Audit season as product ritual** — a periodic close where the ledger is sealed, a locally signed attestation generated with materiality-noted exceptions, exportable to a counterparty, auditor, or court.

### Frame: Platform economist
1. **Provenance sidecar format (.pdoc)** — rival editors read and write it; documents travel with their mutation receipts across tools.
2. **Sneakernet marketplace** — signed local policy packs, clause libraries, and validation macros traded as files, verified by the ledger on ingest.
3. **E-discovery / PREMIS export** — native load-file and preservation-record formats so archivists and litigation vendors ingest ledgers with existing pipelines.
4. **Ledger-examiner credential** — certified paralegals, CPAs, notaries trained to replay and verify receipts offline.
5. **Receipt-stamping firmware** — scanners and printers stamp physical documents into the ledger at the device.
6. **Agent conformance mark** — third-party AI vendors earn a trust label when their outputs emit ledger-native receipts.

### Frame: Music producer / film editor
1. **Stems export** — per-contributor stems (owner / agent / import); one-click "export without the agent stem"; counterparties receive exactly the provenance you chose to expose.
2. **Turnover as EDL** — deliver the edit decision list, not the document: a signed, machine-readable change list courts, auditors, and co-signers consume.
3. **Automation write modes as agent permissions** — every agent lane runs in READ, TOUCH, LATCH, or WRITE, never a flat "can edit."
4. **Insert chain** — each mutation flows through a bypassable plugin chain (fact-check, tone, policy inserts); "bypassed inserts" become a first-class audit question.
5. **Multicam sync** — the emailed PDF, the Slack paste, and the drive copy ingest as synced camera angles; reconciliation becomes angle-switching, each switch recorded.
6. **Room tone** — when the agent deletes a sentence, backfill the gap with the author's own phrasing mined from their ledger history.

---

## 2. Scoring, clusters, converge

### Cluster F — Runnable ledger integrity (the ledger checks itself)
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R5-14 | Trial balance self-audit ★ | [N9 V9 F10] | 9.25 | deepened |
| R5-06 | Pre-approval hooks | [N8 V8 F9] | 8.25 | parked-implementable |
| R5-18 | Audit season ritual | [N8 V8 F8] | 8.00 | parked-implementable |
| R5-13 | Balanced-entry enforcement | [N9 V6 F8] | 7.55 | parked-explorable |

### Cluster G — Third-party trust artifacts & interchange
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R5-10 | Abstract-of-title generator | [N9 V8 F10] | 8.85 | parked-implementable |
| R5-08 | Exemplified-copy issuance | [N9 V8 F9] | 8.60 | parked-implementable |
| R5-02 | Patch bundles as travel format | [N8 V8 F9] | 8.25 | parked-implementable |
| R5-21 | E-discovery / PREMIS export | [N9 V8 F8] | 8.35 | parked-implementable |
| R5-26 | Turnover as EDL | [N9 V8 F9] | 8.60 | parked-implementable |
| R5-01 | Redline rebase | [N9 V7 F10] | 8.45 | parked-explorable |
| R5-07 | Liber/folio citation | [N8 V8 F7] | 7.75 | parked-implementable |

### Cluster H — State forensics & recovery
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R5-05 | Ledger bisect ★ | [N10 V8 F9] | 8.95 | deepened |
| R5-03 | Ledger reflog | [N7 V9 F8] | 8.05 | parked-implementable |
| R5-29 | Multicam sync | [N9 V6 F7] | 7.30 | parked-explorable |

### Cluster I — Graduated autonomy & signal paths
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R5-27 | Automation write modes (READ/TOUCH/LATCH/WRITE) | [N10 V8 F9] | 8.95 | parked-implementable |
| R5-28 | Insert chain with bypass audit | [N9 V7 F9] | 8.20 | parked-implementable |
| R5-30 | Room tone (voice-continuity backfill) | [N10 V5 F8] | 7.50 | parked-conditional |

### Cluster J — Lifecycle governance, custody & ecosystem
| ID | Idea | Chips | Weighted | Status |
|---|---|---|---|---|
| R5-09 | Codicil amendment protocol | [N7 V9 F8] | 8.05 | parked-implementable |
| R5-15 | Fiscal closing of a document | [N9 V8 F9] | 8.60 | parked-implementable |
| R5-19 | .pdoc sidecar format | [N9 V7 F8] | 7.95 | parked-explorable |
| R5-16 | Provision register | [N9 V7 F8] | 7.95 | parked-conditional (R4-07 collision) |
| R5-12 | Executor custody succession | [N10 V6 F7] | 7.65 | parked-explorable |
| R5-20 | Sneakernet marketplace | [N9 V7 F7] | 7.70 | parked-explorable |
| R5-11 | Witnessed execution ceremony | [N9 V5 F7] | 6.90 | parked-explorable |
| R5-04 | Pinned clause submodules | [N9 V6 F7] | 7.30 | parked-conditional (NM-T39 adjacency) |
| R5-24 | Agent conformance mark | [N9 V5 F7] | 6.90 | parked-conditional |
| R5-22 | Ledger-examiner credential | [N10 V4 F6] | 6.60 | parked-conditional — TRAP at zero cohort |
| R5-17 | Depreciation write-downs | [N8 V5 F6] | 6.30 | parked-conditional |
| R5-23 | Receipt-stamping firmware | [N10 V2 F6] | 5.80 | parked-conditional — TRAP |

### Traps and conditions (recorded, not deleted)
- **R5-23 firmware, R5-22 credential** — ecosystem fantasies at zero users; each carries its explicit promote condition (committed hardware partner / cohort + examiner demand).
- **R5-04 submodules** — document-fleet composition is NM-T39 adjacency; the single clause-library case is viable now, the fleet case waits on the NM-T39 falsifier.
- **R5-16 provisions** — merges with R4-07 standing orders on pickup (same substrate: forward-bound ledger intents).
- **R5-17, R5-30** — need judgment beyond the deterministic core; promote when ratified model assistance (LocalAssistLane pattern) exists for that surface.

---

## 3. Deepened branches (focus-agent output; full JSONs in session)

### R5-14 Trial balance self-audit (cluster F) ★ — top of pool (9.25)
**Sketch:** One-click Reconcile reusing the existing deterministic replay pipeline: replay the ledger from source via `VersionStore`, digest replayed result vs current export bytes with `computeDigest`. Match → write a signed attestation through the existing `ReceiptSigning.swift` path — {sourceDigest, ledgerHead, replayedDigest, engineVersion, timestamp} in deterministic canonical encoding. Mismatch → "out of balance" flag; the D-078 agent write path refuses to bind new plans against a drifted document while human export/inspection stay available. Escape hatch: "Accept current bytes as new baseline" appends a rebaseline marker to the ledger itself and clears quarantine after re-verification. Bounded via persisted (ledgerIndex, digest) checkpoints; the seal's claim text comes from a fixed D-067 vocabulary ("ledger replay reproduces current export bytes under engine vX") — it structurally cannot overclaim correctness.
**Load-bearing risk:** replay determinism across app versions — a future release changing replay semantics false-positives old ledgers into quarantine. Survivable only if the seal pins `engineVersion`, version transitions are a first-class rebaseline case, and quarantine never blocks human export.
**First concrete step:** `ReconciliationAudit.swift` exposing `auditBalance(document:)` (inBalance/reason enum, no UI, no quarantine), plus an XCTest modeled on `RotatedReplayFixtureTests`: known fixture replays to its export bytes (in balance); byte-flipped export returns out-of-balance. Prove the invariant in isolation before touching the agent gate.
**Children:** signed balance seal on every export (portable integrity proof) · checkpointed incremental reconcile with divergence localization (names the first diverging op — pairs with R5-05) · agent-write pre-flight balance gate (D-078 plan binding refuses out-of-balance documents; every successful run auto-appends a fresh seal) · balance-timeline ledger inspector (human-visual-gate report schema) · library-level trial balance (portfolio roll-up catching out-of-band file edits).

### R5-25 Stems export (cluster G→I boundary; scored under contributor partition) ★ — 9.2
**Sketch:** A new ExportReviewReceipt profile that partitions the operations ledger by contributor class (owner / agent / import) before replay — any export is "source + the stems you selected." Two exactly-named modes close the honesty gap: **Revert stem** (replay excluding the stem's operations — agent edits literally absent) and **Strip attribution** (replay everything; signed receipt covers only selected stems, with unconditional disclosure that unselected-stem content remains). ReceiptSigning composes: each export attests which stems were applied and in which mode. Flatten does not compose with partial stems — flattenedCopy stays denied for stem exports (or permitted only as a labeled "full mix, provenance-free" render). The $79 story in one click, no network: ledger partitioning over existing local replay.
**Load-bearing risk:** the attribution/revert ambiguity IS the product — if any surface lets a user believe "without the agent stem" removed the agent's words when it only removed attribution, that is a fabricated privacy claim under D-067. Survives only if both modes are hard-named everywhere, the strip-attribution disclosure cannot be skipped, and the signed receipt encodes the mode.
**First concrete step:** contributor-class grouping predicate + a pure `stems(selecting:deselecting:)` filter over ledger entries; unit test asserting replay of source + non-agent stems yields a document hash distinct from the full-mix export — prove the primitive before any UI.
**Children:** stem diff preview (the disclosure becomes the decision interface) · signed stems bundle (full mix + each stem as its own signed PDF — the strongest trust demo) · unmix as an editing feature (one-click "revert all agent edits" reuses the same primitive) · pseudonymized stems (Contributor A/B, structure preserved) · flatten policy codification (a precise citable rule instead of blanket denial).

### R5-05 Ledger bisect (cluster H) ★ — 8.95
**Sketch:** Two user-marked anchors (good G, bad B, G earlier in the append-only ledger); binary-search the range: each probe m reconstructs state S_m by replaying source + ledger prefix through the existing `VersionStore` replay + `computeDigest`, evaluates the predicate, narrows. Predicate modes: automated (field value, page count, digest equality) or interactive (render S_m or a `DocumentDiffReport` vs good; user answers good/bad/skip). Bounded via incremental replay from the nearest cached checkpoint and page-scoped materialization with non-local-effect fallback. Honest verdict: "the first replayed state in which your marker appears is the state produced after op k" — attached to the op's execution-receipt metadata with a one-click diff of S_k vs S_k+1; a boundary finding, not a causal claim. Non-monotonic markers → "nearest transition boundary" instead of "the introduction."
**Load-bearing risk:** comparator monotonicity — bisect is valid only if the judgment flips exactly once; one inconsistent tap yields a confidently wrong verdict. Replay determinism is already verified in the repo; the human factor is the unverified part — budget for it structurally (mandatory side-by-side confirmation of the final boundary pair, full probe-history export).
**First concrete step:** headless `LedgerBisect` — `bisect(source:ledger:good:bad:predicate:) -> BisectResult` on the existing replay paths; fixture with ~15 ops and a defect injected at a known position, asserting convergence within 4 probes and incremental-digests == full-replay-digests, before any interactive UI.
**Children:** diff-hunk-to-predicate compiler (select a hunk from the existing DocumentDiffReport → automated predicate → unattended bisect — neutralizes the monotonicity risk) · verdict verification + forensics receipt (final boundary pair side-by-side; every probe exported in D-078 receipt style) · page-local op classification at write time (cheap invariant enabling page-scoped materialization) · portable bisect package (self-contained {source digest, range, anchors, predicate, verdict history} any instance re-verifies — "send me your bad state" forensics, zero egress) · bisect history mining (most-frequently-guilty op types; on-device).

---

## 4. Cross-round deltas (declare, don't silently collide)

- **R5-14 vs R2-A1 VerificationState:** A1 made claim-state honest; R5-14 makes replay-integrity *runnable*. Different layers; compose.
- **R5-05 bisect vs R4-01's divergence-localization child and R5-14's checkpoint child:** the same binary-search mechanism appears three times — R5-05 is the user-facing forensic product; the others are internal diagnostics. Compose into one `LedgerBisect` substrate.
- **R5-16 provisions vs R4-07 standing orders:** merge on pickup (forward-bound ledger intents).
- **R5-25 stems vs R3-05 ReceiptSigning / R4-20 settlement / R4-01 rehearsal:** all ledger-partition + replay compositions; stems is the export-side partition. Composes; not colliding.
- **R5-26 EDL vs R1 audit-trail export:** different audience (counterparties consume decisions; compliance exports go to auditors). Adjacent; one build item if picked up together.
- **R5-09 codicil framing vs D-068/export-only:** the architecture already forbids in-place edits; R5-09 is the naming/architecture-claim surface, not new mechanics.
- **D-083 alignment:** R5-14's agent pre-flight gate rides the wired loop directly (slice-compatible); R5-25/R5-26 strengthen the $79 trust story; R5-27 gives D-083's claim discipline its real vocabulary (graduated autonomy instead of flat "can edit").

---

## 5. Provocation

Across R4+R5 the ledger has become the product's **legal-grade spine**: runnable integrity (trial balance, bisect), portable trust (stems, EDL, exemplified copies, abstracts), earned autonomy (riders, write modes), governance rites (fiscal closing, audit season). Wildcard: Northstar is not a PDF editor with a history feature — it is a **registry clerk that happens to render PDFs**. The identity question that follows: would you open-source the interchange format (`.pdoc` / EDL) to make "ledger-grade" the industry adjective for document tools — betting that the standard, not the app, is the moat?

---

## 6. Persistence

All 30 candidates registered in `docs/explorations/adhd-exploration-pool-ledger.md` §"Round 5 pool"
with statuses and frame tags; ban list extended. Counts: 3 deepened, 13 parked-implementable,
7 parked-explorable, 7 parked-conditional (2 traps). No graduations this round; deltas above
declare compositions with R3-05, R4-01/07/20, and D-083 slices.
