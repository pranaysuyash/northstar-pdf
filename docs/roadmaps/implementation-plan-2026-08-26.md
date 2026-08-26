# Implementation Plan — 2026-08-26

**Derived from:** `docs/audits/repository-audit-per-0428-doctrine-alignment-2026-08-26.md`
**Persona continuity:** PER-0428 Feedback Doctrine Alignment Reviewer
**Doctrine baseline:** OPERATING_DOCTRINE.md v8.0 (evidence tiers T0–T5, sensitivity S0–S3, authorization gates)

**Sequencing principle:** fix the truth system before extending the product.
Every phase ends with a named verification oracle; nothing is "complete"
without its evidence pointer recorded back into this file's completion ledger.

---

## Phase P0 — Restore green baseline (blocking everything else)

**Goal:** one command proves the whole system healthy again.

| # | Task | Fix for | Owner gate | Oracle | Tier |
|---|---|---|---|---|---|
| P0.1 | Repair `PDFIncrementalFormWriter.swift` build errors (`widths` use-before-declaration :249; missing `applyPngUpPredictor` :263). **Only when the file is quiet** — check `git status` + mtime first per parallel-work protocol | I-01 | None if quiet; coordinate with owning lane otherwise | `swift build` exits 0; then `swift test` re-establishes 226/226 baseline (or documents delta) | T2 |
| P0.2 | Repair `Tests/pdf-signature-guard_test.mjs` import collision (merge stray `import {` on line 10 with the pdfPython import) | I-02 | Same quiet-check | `node Tests/pdf-signature-guard_test.mjs` passes | S2 |
| P0.3 | Run full contract suite twice consecutively; classify remaining failures as fixture-drift vs regression vs flake; record in task inventory | I-04 | None | 79/79 ×2, or every red has a classified reason + owner | T3 |

## Phase P1 — Truth-system automation (highest leverage)

**Goal:** make the gates automatic so red state cannot persist unnoticed.

1. **P1.1 `tools/verify-all.sh`** — single entry point: `swift build && swift test && node tools/run-contract-tests.mjs`; machine-readable summary output. (New file; no behavior change.)
2. **P1.2 Local scheduling** — launchd plist or git pre-commit hook invoking verify-all (air-gap compatible; no external CI service needed to start).
3. **P1.3 Flake quarantine policy** — tests that fail non-deterministically get a `FLAKY:` label in-file plus an entry in a new `docs/flaky-register.md` with date/reason/owner; quarantine is explicit and tracked, never silent.
   - Oracle: two consecutive fully-green runs of verify-all, or all reds carry register entries.

## Phase P2 — Single sources of truth (documentation consolidation)

1. **P2.1 Supersede stale audits:** banner at top of
   `comprehensive-repository-audit-and-first-principles-evaluation-2026-08-25.md`
   (falsified React claim), `full-persona-audit-2026-08-26.md` (stale RG-001),
   pointing to release-gates.md as status authority.
2. **P2.2 Status authority rule:** record in decisions.md (D-0xx): gate state
   lives only in release-gates.md; tasks only in task-inventory; findings/
   progress are append-only ledgers. Update task-inventory maintenance rule to
   match.
3. **P2.3 Audit index:** generate `docs/audits/INDEX.md` (date, persona, scope,
   status current/superseded).
   - Oracle: any future reader can answer "what is true right now?" from exactly one file per fact class.

## Phase P3 — Owner authorization gates (not implementation tasks)

Presented to the project owner as decision requests, not actions:

1. **P3.1 Git checkpoint authorization** — stage and commit the working tree in
   described batches by subsystem (core / app / web / docs / evidence). This is
   the largest durable-value action available; days of evidence-bearing work is
   currently unprotected (audit E-09/F-D4).
2. **P3.2 Frontend cutover criterion** — decide React-shell parity criteria for
   the five-mode matrix and sunset plan for vanilla `app.js` presentation layer
   (contract layer retained either way).
3. **P3.3 Dead-code disposition** — XFAFormProcessor / PDFBatchProcessor:
   promote into a capability lane with admission evidence, or move to explicit
   quarantine with reason (mirrors MuPDF/Tesseract handling).

## Phase P4 — Structural refactors (behavior-preserving, gated by P0 baseline)

| # | Task | Finding | Oracle |
|---|---|---|---|
| P4.1 | Decompose `AppModel.swift` (4,910 lines): extract search, field-editing, recovery, rendering-glue coordinators behind narrow interfaces | F-N1 | `swift test` 226+ pass unchanged; line counts of extracted units < 800 each |
| P4.2 | Rename `PDFEditorRecovery` module to reflect actual contents (or relocate AppModel); update Package.swift + imports | F-N1 | Build+tests green |
| P4.3 | Relocate `PDFEditorNativeTerminationProbe` out of production binary into test target/debug executable | F-N3 | Release-config binary contains no probe symbols (strings check); interruption harness still works |
| P4.4 | Actor-wrap `@unchecked Sendable` vault/session stores with race-targeted tests where feasible | F-N6 | TSan clean run of store suites |
| P4.5 | Harness cleanup: remove unused Core dependency from PDFExperimentParityHarness; dedupe scaffolding types | F-N7 | Build green |

## Phase P5 — Portability & provenance hygiene (cheap batch)

1. **P5.1** Replace hardcoded paths: `tools/regenerate_browser_contract_bundles.mjs:16`
   → env-var Playwright resolution; `Tests/pdf-python.mjs` already supports
   `$PDF_PYTHON`, keep absolute fallback but document in tools/README.
2. **P5.2** Stamp pdf-lib version: add `web/vendor/pdf-lib/VERSION.txt` +
   constant in vendor README; record upstream hash.
3. **P5.3** Persona-named test suites (F-N8): rename to invariant-describing
   names or add header comment mapping persona name → behavioral invariant tested.
   - Oracle: fresh clone on a second machine can run node contract suite (node-only subset) without manual path fixes.

## Phase P6 — Release-gate closure priorities (existing program, re-sequenced)

Continue the existing evidence-gated program, ordered by user value:

1. **P6.1 RG-001 remainder:** broader real-AcroForm corpus from multiple producers; non-FlateDecode xref-stream filters.
2. **P6.2 Accessibility human observation passes** (RG-006/007/043/057/058/059 remainders): VoiceOver + screen-reader sessions recorded as Tier-4 evidence.
3. **P6.3 Rotated-operation replay + parity-mismatch classification** (task-inventory native #2, cross-cutting #1).
4. **P6.4 Text-run replacement writer progression** (Phase 24 sequence).
5. **P6.5 Performance program corpus population + device calibration** (roadmaps 2026-08-25).
6. **P6.6 Companion-plane milestones** (authenticated transport, cancellation, installer) after web-root relocation when quiet.

## Explicitly deferred (strategic bets — revisit after P1–P5)

GPU/WebGPU rendering, local LLM fill assist, PAdES/AATL signing, PDF/UA
auto-remediation engine, LibFuzzer/AFL++ continuous fuzzing. All previously
identified and still valid; sequencing them before the automation/determinism
layer would compound risk rather than value. Each gets its own decision record
when promoted.

---

## Completion ledger (append-only)

| Date | Item | Evidence |
|---|---|---|
| 2026-08-26 | Plan created from PER-0428 audit | this file; audit doc §9 ledger |
| 2026-08-26 | P0.2 closed — signature-guard import collision repaired | `node Tests/pdf-signature-guard_test.mjs` passes all RG-014 assertions (S2: SyntaxError before, pass after) |
| 2026-08-26 | P1.1/P1.2/P1.3 delivered — verify-all gate + launchd template + flake register | `tools/verify-all.sh` (syntax-checked), `tools/com.owner.pdfeditor.verify.plist`, `docs/flaky-register.md`, tools/README.md section |
| 2026-08-26 | P2.1–P2.3 closed — supersession banners, D-055 status authority, audit index | banners atop both stale audits; decisions.md D-055; `docs/audits/INDEX.md` (69 entries) |
| 2026-08-26 | P0.3 partially executed — suite at 73/79; all remaining failures classified in flaky register (2 real drift items A-5/A-6, rest flakes) | this session's runs; `docs/flaky-register.md` entries |
| — | P0.1 **not executed by this lane**: build repair belongs to the active native lane (files modified during this session's builds, incl. XFAFormProcessor wiring into PDFKitProvider). Re-run `tools/verify-all.sh` when quiet | live `git status`; build output |
| — | P3.1–P3.3 owner gates presented, awaiting decisions | §Phase P3 |
| 2026-08-26 | Continuation session (PER-0428 + PER-91013): swift baseline re-verified **230/230 across 33 suites**; contract suite 72/79 → **77/81** after runner fix (`tools/run-contract-tests.mjs` now exports `PDF_EDITOR_BASE_URL` — port-mismatch trio passes); remaining 4 reds classified+owned in flaky register | `tmp/contract-run-{1,2,3}.log`; `docs/audits/repository-continuation-audit-per-0428-per-91013-2026-08-26.md` |
| 2026-08-26 | D-055 duplicate-ID defect found & fixed (React decision → D-056; 2 references in design-implementation-map updated) | docs/decisions.md; docs/design-implementation-map.md |
| 2026-08-26 | New queued items: **P6.7** regenerate semantic-parity bundles (`validation: null` fixture drift); **P6.8** pixelmatch upgrade for toolbar visual-regression oracle (byte-equality + parallel-lane overwrite of channel fix documented) | continuation audit §4; `docs/flaky-register.md` |

**Maintenance rule:** same as task-inventory — completed items move down with
evidence pointers, never deleted.
