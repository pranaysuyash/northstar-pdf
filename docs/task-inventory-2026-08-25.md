# Task Inventory — 2026-08-25

**Purpose:** one durable, current queue of every explicit task (named in
`task_plan.md`, `progress.md`, `docs/roadmaps/`, `docs/decisions.md`) and
implicit task (gaps surfaced by audits) across the native and web planes.
Sources were reconciled against the live tree on 2026-08-25 evening; a second
agent is working in parallel and several items closed underneath this audit —
those are recorded as completed rather than re-queued.

**Maintenance rule:** when a task completes, move it to the completed section
with its evidence pointer rather than deleting it. New implicit tasks get
appended with a discovery date.

---

## Completed this session / this day (2026-08-25)

| Task | Discovered in | Closed by | Evidence |
|---|---|---|---|
| Extract inline script to `app.js` (RT-004) | web audit | parallel agent | `web/index.html` (325 lines) loads `./app.js`; `Tests/web_reader_contract_test.mjs` passes 51 checks + boot smoke |
| Remove unreachable CDN fallbacks for PDF.js (CSP `script-src 'self'` / `connect-src 'none'` made them dead code) | web separation audit | parallel agent | `web/app.js` pins vendored-only runtime, `PDFJS_PINNED_VERSION = "4.2.67"` |
| Add static boot-smoke check to the reader contract test | web audit (memory) | parallel agent | test output `(+ boot smoke)` |
| Declare `PDFEditorRecovery` + `PDFRecoveryInterruptionHarness` in `Package.swift` | separation audit | parallel agent | `Package.swift` targets list |
| Node local preview server for `web/` | runbooks | parallel agent | `Tests/serve-web.mjs` (port 8090) |
| Aggregate contract-test runner | this audit (implicit) | this session | `tools/run-contract-tests.mjs`, baseline in `tmp/test-results-baseline.json` |
| Static web deploy packager enforcing the D-009 browser/companion boundary | this audit (implicit) | this session | `tools/deploy-web.mjs`; 31-file closure staged to `dist/web`, end-to-end Playwright proof passed against the staged output |
| Tools documentation | workspace rules | this session | `tools/README.md` |

## Open — native plane

1. **`Sources/PDFEditorRecovery/AppModel.swift` compile error** (contested
   file, actively edited): `context.beginPDFPage(nil)` at ~line 1280 reports
   "'nil' requires a contextual type". Package-wide `swift build`/`swift test`
   is blocked on it. Likely minimal repair: `nil as CFDictionary?` — but the
   file is under live parallel edit; repair only when quiet (task_plan Phase
   35 already records the same blocker).
2. Rotated reviewed-operation replay; accepted qpdf-variance classification
   (Phase 12 next units; `Tests/rotated_operation_replay_test.mjs` already
   in flight as untracked work).
3. General text-run replacement writer: same-font simple-run case, then
   ligatures, embedded fonts, Unicode, RTL, columns, tables, clipping,
   transparency, overlapping objects, negative abstention cases (Phase 24).
4. Real signed-CMS corpus generation; signature integrity lanes (Phase
   continuation).
5. Permanent image/vector redaction (`Tests/redaction_completeness_validator_test.mjs`
   in flight); tagged PDF/UA authoring; production-scale arbitrary-PDF
   recovery (Phase continuation).
6. MuPDF three-way comparison (`benchmark/mupdf-independent-validator.mjs` in
   flight) — MuPDF remains license-gated (AGPL/commercial, D-003).
7. PDFBox lane remaining: signed/XFA/password-policy corpus, Bouncy Castle
   notice bundling, jlink minimization, IPC hardening, JVM-helper notarization
   (latest `progress.md` "Remaining open").
8. Performance program: populate
   `benchmark/performance-corpus-manifest.json` measurement fields; Lane A
   page-render/detection/undo/redo coverage; Lane B real redo transition and
   direct inverse mutation; physical-device calibration (roadmaps 2026-08-25).

## Open — web plane

1. Move Node-only server/companion modules out of `web/` into a dedicated
   companion/server plane (target end-state). Currently 20 modules
   (`provider-companion-host.mjs`, `pdf-sanitize.mjs`, `pdf-signature-guard.mjs`,
   `pdf-incremental-form-writer.mjs`, …) live in the static root; the deploy
   boundary is enforced by `tools/deploy-web.mjs` closure walking instead.
   Blocked on: companion lane is under active parallel development; move when
   quiet, then update `Tests/provider_companion_host_test.mjs`,
   `Tests/provider_companion_protocol_test.mjs`, the moat-registry fixture
   reference, and task_plan Phase 16 paths.
2. Companion runtime milestones: authenticated transport, cancellation /
   resource enforcement, zero-content diagnostics, local measurement runner,
   installer + sandboxing + real provider handlers (Phases 13/16).
3. Browser UI design completeness: Northstar 5-mode design
   (`Web-Prototype.zip`, `DESIGN-HANDOFF.md`) landed only as a first pass
   (`design-system.css`, `product-modes.mjs`); componentization incomplete.
4. Real-device/browser-matrix calibration for the resource policy (Phase 18).
5. Web deployment host decision: `tools/deploy-web.mjs` is host-agnostic by
   design; choosing a host/CDN is a release-gate decision, not tooling.

## Open — cross-cutting / evidence

1. Parity-mismatch classification + contract/provider remediation (Phase 7/20
   next units; preserve mismatches as evidence per D-015).
2. Independent fingerprint extraction from real PDFs; geometry and privacy
   hardening (Phase 7 next unit).
3. Held-out recurring-version calibration, reviewer agreement, value
   correctness, user-time benefit (template lane, Phases 30–35).
4. Secure deletion, Keychain-loss recovery, quota/multi-tab stress,
   cross-adapter backup parity, OPFS UI/audit parity, production recovery UX.
5. OCR promotion gates: accuracy, latency boundary, licensing, recovery
   evidence (Phase 23; Tesseract failed the noisy-scan gate; OCRmyPDF /
   PDFBox / MuPDF quarantined).
6. Commit the working tree: ~68 changed/untracked files with git mutations
   unauthorized — accumulate consciously, not indefinitely.
7. Repo weight decision: 5.3 MB `Web-Prototype.zip` + 315 benchmark evidence
   artifacts tracked in git (deliberate evidence preservation; revisit only if
   clone weight becomes a real cost).

## Owner-decision gates (not implementation tasks)

- First supported PDF-class promise / support corpus matrix.
- OCR languages and document types priority.
- AGPL/commercial licensing acceptability (MuPDF path).
- Authoritative independent-viewer/validator set.
- Companion transport choice when C1 opens.
- Companion justification per workflow.

## Parallel-work protocol (doctrine §10)

- Before editing any file: check mtime and `git status`; the second agent's
  active files on 2026-08-25 evening included `Sources/PDFEditorRecovery/AppModel.swift`,
  `Sources/PDFEditorApp/*` views, and the growing Node module set under `web/`.
- Verify-before-duplicate: several audit items closed while being queued
  (RT-004 extraction, CDN fix, Package wiring). Always re-check live truth.
- Never race a live editor on a contested file; document precisely instead
  (error text + location) so the owning session can repair in one step.

---

## Appended 2026-08-26 (PER-0428 doctrine-alignment audit)

Discovered by `docs/audits/repository-audit-per-0428-doctrine-alignment-2026-08-26.md`;
full plan in `docs/roadmaps/implementation-plan-2026-08-26.md`.

| # | Task | Type | Status |
|---|---|---|---|
| A-1 | Repair `Tests/pdf-signature-guard_test.mjs` malformed import collision | implicit | **Closed 2026-08-26** — fixed, S2 verified (`node Tests/pdf-signature-guard_test.mjs` passes all RG-014 assertions) |
| A-2 | `tools/verify-all.sh` whole-system gate + launchd template + flake register | implicit | **Closed 2026-08-26** — `tools/verify-all.sh`, `tools/com.owner.pdfeditor.verify.plist`, `docs/flaky-register.md` |
| A-3 | Supersession banners on stale audits; status-authority decision; audit index | implicit | **Closed 2026-08-26** — banners on 2026-08-25 comprehensive + full-persona audits; D-055 in decisions.md; `docs/audits/INDEX.md` |
| A-4 | Owner Git-checkpoint authorization (commit working tree in described batches) | owner gate | Open — awaiting owner decision |
| A-5 | Regenerate semantic-parity bundles (fixes `browser_export_independent_viewer_validator_test`); blocked on removing machine-local Playwright path in the regen tool | implicit | Open |
| A-6 | Reconcile contract-parity ledger after native lane goes quiet (fixes `cross_project_evidence_ledger_parity_test`) | implicit | Open |
| A-7 | De-flake browser suite (condition-based waits); target two consecutive 79/79 runs | implicit | Open |
| A-8 | Portability: remove machine-local paths (`tools/regenerate_browser_contract_bundles.mjs:16`, document `Tests/pdf-python.mjs` fallback); stamp pdf-lib version | implicit | Open |
| A-9 | AppModel decomposition + module-rename evaluation (behavior-preserving, gated on green build) | implicit | Open |
| A-10 | Termination probe relocation out of production binary; dead-code disposition for XFAFormProcessor/PDFBatchProcessor (**note:** parallel lane appears to be wiring XFAFormProcessor into PDFKitProvider — re-verify before acting) | implicit | Open |

Live-truth snapshot at append time: `swift build` red on in-flight
PDFIncrementalFormWriter/PDFKitProvider edits (parallel lane active, hands off);
contract suite 73/79 with remaining failures classified in
`docs/flaky-register.md`.
