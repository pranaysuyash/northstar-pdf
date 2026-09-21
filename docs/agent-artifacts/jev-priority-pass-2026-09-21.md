# Jev priority pass over the open-items ledger — 2026-09-21

**Run:** `node tools/jev-prioritize/prioritize.mjs` — 101 items, 0 API errors, served model `jev-1.13.0` on every call (request id `jev-latest`; see model-pin amendment in the Jev living doc). Raw per-call captures: `tools/jev-replay/raw/` (gitignored). Full machine results: `tools/jev-prioritize/results-2026-09-21.json`. Item extract: `tools/jev-prioritize/open-items-2026-09-21.json`. Cost: ~60k input tokens total, well under $0.01.

## 1. Validity ceiling — read this before the ranking

The EXP-JEV-1 calibration replay (`docs/research/jev-expjev1-report-2026-09-21.md`), run immediately before this pass with the same key, hit its **pre-registered KILL SIGNAL**: on the security-triage smoke corpus Jev scored 0.208 accuracy / 0.201 Brier against the deterministic baseline's 0.542 / 0.142, collapsing the close class (1/13) into "contain". That verdict does not automatically transfer — this pass is a different task shape (explicit 9-point score ladder, structured per-item states, two typed questions) and the probe behavior was face-valid — but it means **nothing below is calibrated evidence**. Treat the whole pass as an exploratory advisory reading, per the D-067 doctrine discussion: a model judgment is a lower evidence tier than mechanism, and today that tier has a negative calibration result on record.

Confidence structure supports reading only the top of the table: the top 10 items carry priority-confidence 0.54–0.97, the middle band (ranks ~40–75) is mostly 0.1–0.4, and 16 items fall below 0.1 (do not act on those from this pass alone).

## 2. What was judged

All 101 open items from the canonical ledger `docs/task-inventory.md` (NM-T01–T45, MDEV, NM-R01–R15, PERF-S01–S14, JEV-0–6, carried-over A-4..A-16) plus the three launch-critical external gates from `docs/release-gates.md` (RG-122, RG-123, RG-135).

Deliberate exclusions (recorded in the items file): the crosswalk tables in task-inventory.md (each row maps 1:1 onto a canonical NM-T/MDEV task already judged), steady-state PARTIAL proof-obligation gates in release-gates.md (gate state, not priority units), A-15 (absorbed by A-14), MDEV-I5 (no stated remainder). Also outside this pass because they live outside the canonical ledger: commerce/monetization build-out (0% started, planned $79 tier) and the bounded-cohort recruitment instruments (PL-D) — two launch-critical lanes Jev never saw.

## 3. Method

Two questions per item, one API call, identical project-state preamble for comparability:

- **Score** on a 9-point ladder: "Priority 2: defer indefinitely — cosmetic only" through "Priority 10: launch-blocking — do now". Reported P-level = returned ladder index + 2 (can land between levels, e.g. 7.55 → 9.55).
- **Choice** of execution lane: `do-now` / `do-next` / `do-later` / `owner-decision` / `park`, each with a one-line criterion.

## 4. Full ranked table

| Rank | Item | P-level | Lane (lane-conf) | P-conf |
|---|---|---|---|---|
| 1 | RG-135 | 9.93 | do-now (0.26) | 0.97 |
| 2 | JEV-2 | 9.89 | do-now (0.57) | 0.95 |
| 3 | NM-T32 | 9.71 | owner-decision (1) | 0.87 |
| 4 | RG-122 | 9.68 | owner-decision (0.99) | 0.86 |
| 5 | MDEV-I1 | 9.35 | owner-decision (0.67) | 0.71 |
| 6 | RG-123 | 9.24 | owner-decision (0.98) | 0.66 |
| 7 | PERF-S02 | 9.13 | do-now (0.98) | 0.61 |
| 8 | PERF-S01 | 9.07 | do-now (0.97) | 0.58 |
| 9 | NM-T21 | 9.06 | do-now (0.21) | 0.58 |
| 10 | NM-R10 | 8.99 | owner-decision (0.93) | 0.54 |
| 11 | A-4 | 8.93 | owner-decision (0.99) | 0.68 |
| 12 | NM-T34 | 8.86 | do-now (0.43) | 0.59 |
| 13 | NM-T39 | 8.72 | owner-decision (0.71) | 0.77 |
| 14 | NM-T27 | 8.70 | owner-decision (0.97) | 0.6 |
| 15 | MDEV-I6 | 8.67 | do-now (0.42) | 0.57 |
| 16 | NM-T15 | 8.59 | do-next (0.31) | 0.52 |
| 17 | NM-T03 | 8.54 | do-now (0.41) | 0.34 |
| 18 | PERF-S14 | 8.52 | do-now (0.6) | 0.57 |
| 19 | PERF-S12 | 8.47 | do-now (0.57) | 0.5 |
| 20 | A-12 | 8.42 | do-next (0.38) | 0.58 |
| 21 | PERF-S03 | 8.35 | do-now (0.88) | 0.28 |
| 22 | PERF-S11 | 8.35 | do-now (0.8) | 0.53 |
| 23 | JEV-1 | 8.35 | owner-decision (1) | 0.26 |
| 24 | A-16 | 8.35 | do-next (0.29) | 0.57 |
| 25 | NM-T40 | 8.27 | do-next (0.38) | 0.44 |
| 26 | NM-T01 | 8.23 | owner-decision (0.57) | 0.49 |
| 27 | NM-T29 | 8.16 | owner-decision (0.26) | 0.45 |
| 28 | PERF-S10 | 8.15 | do-now (0.69) | 0.31 |
| 29 | NM-T18 | 8.13 | do-now (0.58) | 0.4 |
| 30 | PERF-S07 | 8.13 | do-now (0.75) | 0.4 |
| 31 | PERF-S04 | 8.10 | do-now (0.61) | 0.39 |
| 32 | A-9 | 8.10 | do-next (0.44) | 0.5 |
| 33 | NM-T14 | 8.06 | do-now (0.36) | 0.35 |
| 34 | JEV-5 | 8.01 | owner-decision (0.72) | 0.32 |
| 35 | MDEV-I3 | 8.00 | owner-decision (0.85) | 0.67 |
| 36 | PERF-S05 | 7.97 | do-now (0.84) | 0.43 |
| 37 | PERF-S13 | 7.95 | do-now (0.38) | 0.52 |
| 38 | A-11 | 7.93 | do-next (0.4) | 0.52 |
| 39 | NM-T28 | 7.92 | do-next (0.36) | 0.33 |
| 40 | NM-T30 | 7.88 | do-next (0.39) | 0.33 |
| 41 | NM-T16 | 7.80 | do-next (0.37) | 0.3 |
| 42 | MDEV-I2 | 7.77 | do-next (0.36) | 0.27 |
| 43 | PERF-S06 | 7.71 | do-now (0.7) | 0.54 |
| 44 | A-10 | 7.71 | do-next (0.54) | 0.3 |
| 45 | JEV-6 | 7.69 | owner-decision (0.9) | 0.29 |
| 46 | NM-R12 | 7.67 | do-next (0.15) | 0.22 |
| 47 | NM-T41 | 7.65 | do-next (0.27) | 0.33 |
| 48 | A-8 | 7.59 | do-now (0.32) | 0.45 |
| 49 | NM-T42 | 7.51 | do-next (0.56) | 0.3 |
| 50 | PERF-S09 | 7.51 | do-next (0.34) | 0.52 |
| 51 | NM-T04 | 7.49 | do-next (0.35) | 0.21 |
| 52 | NM-T17 | 7.49 | do-next (0.25) | 0.41 |
| 53 | NM-T20 | 7.49 | do-now (0.29) | 0.18 |
| 54 | PERF-S08 | 7.48 | do-now (0.63) | 0.54 |
| 55 | A-5 | 7.45 | do-now (0.5) | 0.5 |
| 56 | NM-R15 | 7.36 | owner-decision (0.99) | 0.08 |
| 57 | NM-T13 | 7.34 | do-next (0.32) | 0.32 |
| 58 | JEV-3 | 7.34 | owner-decision (0.32) | 0.38 |
| 59 | NM-T06 | 7.33 | do-next (0.58) | 0.47 |
| 60 | NM-R13 | 7.27 | do-next (0.2) | 0.06 |
| 61 | A-14 | 7.26 | do-next (0.48) | 0.36 |
| 62 | A-6 | 7.20 | do-next (0.25) | 0.36 |
| 63 | NM-T07 | 7.19 | do-next (0.31) | 0.28 |
| 64 | NM-T12 | 7.16 | do-next (0.47) | 0 |
| 65 | NM-T10 | 7.14 | do-next (0.42) | 0.42 |
| 66 | NM-T25 | 7.14 | do-next (0.37) | 0.3 |
| 67 | A-13 | 7.13 | owner-decision (0.37) | 0 |
| 68 | NM-R04 | 7.09 | do-next (0.18) | 0.02 |
| 69 | NM-R08 | 7.06 | owner-decision (0.22) | 0.08 |
| 70 | NM-T23 | 7.00 | do-next (0.4) | 0.31 |
| 71 | JEV-4 | 6.98 | do-next (0.59) | 0.38 |
| 72 | A-7 | 6.90 | do-now (0.31) | 0.34 |
| 73 | MDEV-I4 | 6.80 | do-next (0.17) | 0.23 |
| 74 | NM-T35 | 6.77 | do-next (0.29) | 0.24 |
| 75 | NM-R05 | 6.66 | owner-decision (0.7) | 0.32 |
| 76 | NM-T37 | 6.49 | owner-decision (0.15) | 0.02 |
| 77 | NM-T43 | 6.39 | owner-decision (0.2) | 0 |
| 78 | NM-T24 | 6.38 | do-next (0.35) | 0 |
| 79 | NM-T05 | 6.37 | do-next (0.19) | 0.36 |
| 80 | NM-T44 | 6.36 | owner-decision (0.28) | 0 |
| 81 | NM-T02 | 6.33 | do-next (0.27) | 0.35 |
| 82 | NM-T38 | 6.33 | do-now (0.22) | 0.19 |
| 83 | JEV-0 | 6.17 | do-now (0.7) | 0.32 |
| 84 | NM-R11 | 6.15 | do-later (0.17) | 0 |
| 85 | NM-T08 | 6.13 | do-next (0.42) | 0.29 |
| 86 | NM-T31 | 6.13 | do-next (0.28) | 0 |
| 87 | NM-R06 | 6.04 | do-next (0.26) | 0.3 |
| 88 | NM-T19 | 6.01 | do-next (0.36) | 0.05 |
| 89 | NM-T45 | 6.01 | owner-decision (0.36) | 0 |
| 90 | NM-T33 | 5.97 | do-now (0.48) | 0.11 |
| 91 | NM-R02 | 5.93 | do-later (0.2) | 0.05 |
| 92 | NM-R14 | 5.86 | do-later (0.31) | 0.05 |
| 93 | NM-R01 | 5.74 | do-later (0.2) | 0.12 |
| 94 | NM-R09 | 5.62 | do-later (0.24) | 0.17 |
| 95 | NM-T11 | 5.61 | do-next (0.21) | 0.19 |
| 96 | NM-T09 | 5.49 | do-next (0.22) | 0.21 |
| 97 | NM-R07 | 5.41 | do-later (0.37) | 0.25 |
| 98 | NM-R03 | 5.36 | do-later (0.26) | 0.29 |
| 99 | NM-T36 | 5.18 | do-later (0.26) | 0.29 |
| 100 | NM-T22 | 4.59 | owner-decision (0.15) | 0.5 |
| 101 | NM-T26 | 4.59 | do-later (0.48) | 0.63 |

## 5. Reading the top of the table

1. **RG-135 (P9.93, conf 0.97)** — human visual confirmation gate, 0/38 fixtures, fails closed on any release. The one launch blocker that needs no money and no decision, only reviewer passes. Unambiguous top rank.
2. **JEV-2 (P9.89, conf 0.95)** — prompt-injection red-team, ranked high because its state text says "hard gate before any customer-facing use" and Jev reads literally. **Interpret with the kill signal:** whether the Jev program continues at all is NM-R15/JEV-1, an owner kill-or-continue call Jev itself routed to `owner-decision` with lane-confidence 1.00. This rank is conditional on that call, not ahead of it.
3. **NM-T32 + RG-122 (P~9.7, owner-lane conf 0.99–1.00)** — codesign/notarization, blocked on the Apple Developer account. Correct lane routing: this is the owner's $99 and decision.
4. **MDEV-I1 (P9.35)** — sandbox default-on, honestly gated on the signing decision.
5. **RG-123 (P9.24, owner-lane conf 0.98)** — auto-update hosting + EdDSA keys.
6. **PERF-S02 + PERF-S01 (P~9.1, do-now conf 0.97–0.98)** — the two critical snappiness stalls. Highest-confidence *agent-executable* items in the whole run.
7. **NM-T21 (P9.06)** — preflight surface verification, but lane-confidence 0.21; the weakest high-P item, do not act on it without a human re-read.
8. **NM-R10 (P8.99, owner-lane conf 0.93)** — beta-contract acceptance.

Emergent checks worth noting: the D-083 shell slices ranked in exactly their intended order (slice 0 NM-T41 7.65 → slice 1 7.51 → slice 2 6.39 → slice 3 6.36 → slice 4 6.01), the owner-gate items (A-4 commit authorization, MDEV-I3, NM-T27, NM-T39) all landed in the `owner-decision` lane, and the bottom of the table is the speculative research pool (spatial board, citation export, recall posture) — all face-valid.

## 6. Practical take

Highest-leverage sequence implied by the pass (mine, using Jev as input):

1. Owner: the three external unlocks — Apple Developer account (RG-122/NM-T32), auto-update hosting + keys (RG-123), and the NM-R15 Jev kill-or-continue call (this pass's own validity depends on it).
2. Agents: PERF-S01 + PERF-S02 (critical, agent-executable, high-confidence do-now), then PERF-S14 Instruments before/after as the register's oracle.
3. Reviewer time: RG-135 fixture passes — the cheapest launch-critical path item that only a human can do.
4. Jev program: EXP-JEV-1's kill criterion fired; per the register, that is an owner decision, not a silent continuation.
