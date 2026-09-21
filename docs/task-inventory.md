# Canonical Task Inventory

**Canonical owner:** `/Users/pranay/Projects/pdf_editor/docs/task-inventory.md`
**Reviewed:** 2026-09-05
**Primary product lens:** PER-0926, Product Evolution Architect
**Review lens:** PER-0428, Feedback and Evidence Steward
**Scope:** Native macOS product design, interaction model, document-session
architecture, evidence-aware workflows, provider breadth, verification, and
release hardening.

## Authority and status rules

This file owns task state. The native audit owns detailed findings, rationale,
and research questions. `docs/decisions.md` owns durable decisions. The release
registry at `docs/release-gates.md` owns gate state and must not be replaced by
this task list. A task marked `implemented` here means its source or contract
work has landed with the evidence stated below; it does not automatically mean
the corresponding release gate is passed.

Status vocabulary:

- `implemented-source`: source or contract work exists; runtime or broader
  evidence may still be required.
- `verified`: the task's stated oracle has passed at its required evidence tier.
- `partial`: a bounded slice exists, but an explicit remainder is open.
- `open`: not yet implemented or researched to the required boundary.
- `blocked`: progress requires a named external capability or owner decision.
- `deferred`: deliberately sequenced later, with a documented revisit trigger.

Evidence tiers are T0 assumption, T1 static inspection, T2 targeted test,
T3 integration or mutation-verified flow, T4 live native/browser/device
observation, and T5 production-like proof. Test sensitivity is S0 test exists,
S1 passes, S2 defect then fix, and S3 deliberate mutation failure.

## Annotated open-gate crosswalk

The following list directly answers the annotated completion review. These are
not all separate features; they are proof obligations attached to the canonical
tasks and release gates.

| Explicit or implicit gap | Current state | Canonical task or gate | Required evidence |
|---|---|---|---|
| Fresh GUI window observation | Observed for current package; control-level AX enumeration remains open | NM-T30, NM-T34 | T4 packaged-app launch with OS, build, frame, window state, screenshot, and control-level interaction evidence |
| Native drag-and-drop runtime proof | Partial; in-place and fallback source paths exist | NM-T13, NM-T15, NM-T30, NM-T34 | T4 drop/open flow, rejected input, source identity, and visible result |
| VoiceOver walkthrough | Open; source labels exist | NM-T12, NM-T30 | T4 traversal of home, rail, canvas, inspector, menus, sheets, and recovery |
| Keyboard-only walkthrough | Open | NM-T12, NM-T30 | T4 command, focus, shortcut, escape, restore-focus, and no-pointer flow |
| Reduced-motion runtime observation | Open; source modifiers exist | NM-T15, NM-T30 | T4 system setting plus before/after state evidence |
| Narrow-window and split-view observation | Open; `ViewThatFits` source path exists | NM-T07, NM-T15, NM-T30, NM-T34 | T4 resize matrix with no occlusion, overflow recovery, and screenshots |
| Multi-window isolation proof | Partial; model-level check passes | NM-T02, P3.1, RG multi-window requirements | T2 independent-session checks plus T4 two-window walkthrough |
| Durable security-scoped bookmarks or deliberate reselection | Partial; bookmark-backed source path and explicit Locate/Re-select flow exist. Replacement admission is transactional: rejected or password-gated replacements preserve the stale record, and only admitted replacements start downstream reading history | EOR-01/EOR-02, P1.5, recent-file identity follow-up | T2 bookmark persistence/moved-source/rejected-replacement checks plus T4 saved, moved, revoked, inaccessible, and reselected file cases |
| Full unfiltered Swift Testing suite | **Resolved 2026-09-12 — full-suite verification debt closed.** Single-process `swift test --skip OCRCompanionBenchmark` run: 176/180 suites completed in-window with **0 failures, 0 errors, 0 hangs**; the 4 suites in flight at the tool-window wall passed individually on the same binary (10 tests). Companion suite completed provider-batched on the same binary: 19 light + 5 fullBenchmark sweeps (PDFKit 0.001s legitimate raster-only baseline, Tesseract 5.8s, Vision 5.4s, PaddleOCR 212s, Marker 300s) — all 24 pass. **184/184 suites green.** Method note: one-process full `swift test` including companion needs >580s (serialized heavy sweeps), so the verified-equivalent completion is in-window slices on one binary; logs under `.build/testrun/`. Prerequisites that made this run possible are documented in `docs/flaky-register.md` (bounded semaphore acquire 2026-09-12; ENOSPC trap 2026-09-12). Historical 09-01 run (1522 tests / 160 suites / 448 issues) superseded: the FUNSD case-mismatch, manifest-presence, moved-recent-file, and payload-interruption items it lists were all subsequently fixed and are green in the 2026-09-12 run | P0.2, full-suite release verification | None — closed; rerun on release candidate per evidence-pack cadence |
| Profile-specific writer validation | Partial; extracted-page and sanitized-copy T2 proofs pass; flattening remains explicitly denied | NM-T17, NM-T18, NM-T29, export gates | T2/T3 edited, sanitized, flattened, split, and merge writer/reopen proof; sanitized validation covers authored metadata and documents PDFKit serializer provenance |
| Provider capability and privacy gates | Partial across current lanes | NM-T29, NM-T31, `docs/release-gates.md` | T3 provider matrix with license, privacy, latency, fidelity, failure, and rollback evidence |
| Contract-to-view release gates | Partial; contracts and several views exist | NM-T16, NM-T21, P2 contract-to-view work | T2 contract-to-view tests plus T4 evidence comprehension |
| Codesign and notarization proof | Blocked/open external gate | NM-T32, P6, RG-122 | Apple signing, notarization, staple, `spctl`, and artifact verification |

## Native findings and task state

Detailed finding definitions and source rationale remain in
[`audits/native-macos-product-audit-per-0926-2026-08-31.md`](audits/native-macos-product-audit-per-0926-2026-08-31.md), section 5.2. The findings below are the current task crosswalk:

| Finding IDs | Finding area | State | Follow-up |
|---|---|---|---|
| NMAC-001, NMAC-020 | Session ownership and oversized native types | implemented-source | NM-T01, NM-T06; matrix exists, field migration and unchanged-contract proof remain open |
| NMAC-002 | Multi-window isolation | partial | NM-T02, P3.1; model-level independent-session test passes, GUI two-window proof remains open |
| NMAC-003, NMAC-021 | Toolbar density and native hierarchy | partial | NM-T07, NM-T30 |
| NMAC-004 | Competing editor/reading taxonomies | open | NM-T08, NM-R01 |
| NMAC-005, NMAC-006, NMAC-014 | Inspector, sheets, utility boundaries | open | NM-T09, NM-T12, NM-R06 |
| NMAC-007 | Generic Manager surface | open | NM-T11 |
| NMAC-008, NMAC-022 | Empty state and first-run identity | partial | NM-T13, NM-R10, NM-T30 |
| NMAC-009 | Recovery discoverability | partial | NM-T14, EOR-03 |
| NMAC-010, NMAC-012 | Shared permission and command policy | implemented-source | NM-T04, NM-T35, NM-T36; runtime parity remains open |
| NMAC-011 | View transforms versus export mutations | open/partial | NM-T03, P0.3 |
| NMAC-013, NMAC-024 | Native UX and accessibility proof | open | NM-T15, NM-T30, NM-T34 |
| NMAC-015 | Evidence-rich capability layer | partial | NM-T16, NM-T20, NM-T21 |
| NMAC-016, NMAC-017 | Spatial synthesis and cross-document atom | open | NM-T22, NM-T23, NM-T25, NM-R03/NM-R04 |
| NMAC-018 | Versioned native beta boundary | implemented-source | NM-T27, NM-R10; owner acceptance and release-registry reconciliation remain open |
| NMAC-019 | Dirty-worktree reproducibility | implemented-source | NM-T05; owner classification and drift reconciliation remain open |
| NMAC-023 | Grounded agent command surface | partial | NM-T12, NM-R08 |
| NMAC-025 | Build/test claims versus completeness | active control | P0.2, NM-T28, release registry |
| NMAC-026 | Product identity drift between Northstar strategy and PDFEditor implementation surfaces | implemented-source | NM-T37; fresh packaged app-menu/window-title observation and distribution identity reconciliation remain open |
| NMAC-027 | Empty home state shows a disabled document toolbar | implemented-source | NM-T38; source hides the window toolbar when no document is admitted; packaged home/document/home transition, resize, skim restoration, and menu recovery remain open |

## Implementation task ledger

The detailed task descriptions, rationale, and exit oracles are maintained in
the native audit's section 6. This table owns the current state and the next
required action.

| ID | Type | State | Current evidence or next action |
|---|---|---|---|
| NM-T01 | Implement | implemented-source | Proposed ownership matrix exists; field migration and T2 unchanged-contract proof remain open. |
| NM-T02 | Implement | partial | `DocumentWindowIsolationTests` passes one T2 independent-session check; add a two-window T4 walkthrough covering source, operation, undo, selection, export, and recovery. |
| NM-T03 | Implement | open | Prove view-only transforms do not become export mutations. |
| NM-T04 | Implement | implemented-source | Shared typed policy and denial reasons exist; run broader parity proof. |
| NM-T05 | Explore/implement | implemented-source | `tools/native-audit-snapshot.mjs` and dated manifest exist; add post-capture drift classification. |
| NM-T06 | Implement | open | Decompose by ownership only after the T01 matrix is accepted and concurrent ownership is quiet. |
| NM-T07 | Implement | partial | Semantic toolbar groups exist; verify wide/narrow collapse and parity. |
| NM-T08 | Implement | open | Compare one user-facing intent lens with current editor/reading controls. |
| NM-T09 | Implement | open | Assign recurring tools to inspector or utility windows. |
| NM-T10 | Implement | partial | Menu/command routing exists; complete sidebar/inspector/toolbar recovery inventory. |
| NM-T11 | Implement | open | Replace or reorganize the generic Manager entry by outcome. |
| NM-T12 | Implement | open | Define focus restoration and keyboard traversal contracts. |
| NM-T13 | Implement | partial | Home recents/drop/create and in-place-drop source slices exist; available recent entries are full-row actions with stable identifiers, while stale entries expose explicit Locate recovery. T2 bookmark/history, successful replacement, and rejected replacement checks pass. Drop-disambiguation semantic defects found by the 2026-09-17 council review (compare not bound to the dropped document; switch without preservation gate) are fixed — `openDiffComparison(against:)` cross-document diff plus flush-before-open preservation and a dirty-session confirmation boundary — while T4 stale-row, drop/preflight, and provider fallback proof remain. |
| NM-T14 | Implement | partial | Recovery Inspect/Discard source slice exists; T4 restore/source mismatch remains. |
| NM-T15 | Research/implement | open | Build screenshot and interaction regression matrix. |
| NM-T16 | Implement | partial | Evidence rail/passport source exists; contract-to-view and comprehension proof remain. |
| NM-T17 | Implement | partial | Review receipt/profile routing exists; extracted-page and sanitized-copy writers now have focused T2 reopen/source-preservation validation; edited/merge/T4 export proof remains. 2026-09-17: execution receipts now carry observed-only provenance (`executionRoute` + mandatory `ExecutionDataBoundary`, no defaults; unconditional trailer and fabricated `passed:true` checks removed) — one plan/trace identity across proposal→receipt remains open. |
| NM-T39 | Decide | open | **Re-scoped by D-083 (2026-09-17):** owns the surviving "whether" questions via cohort instruments — library/corpus demand AND agentic-organizer demand (pre-registered kill thresholds: <30% of cohort sessions open the agent loop, or >50% of approved plans abandoned ⇒ organizing-surface thesis falsified; loop remains a wedge tool). Multi-document workspace machinery stays declined; NM-T39 no longer gates shell interaction/visual direction (D-083 owns that). **2026-09-22 (D-083 Amend 1):** pre-registered library-demand observables added (recents re-find rate; multi-document session recurrence) so this question can actually fire; PL-D09's loop-adoption thresholds alone never answer it. |
| NM-T40 | Implement | open | Wire shared EgressGate/transport state into execution-receipt derivation so data-boundary disclosure reflects live session state instead of the executing path's static scope (council review 2026-09-17 §5, epistemic seat). |
| NM-T41 | Research/implement | partial | **D-083 slice 0 (no new UI):** X7 unification design doc — vocabulary, authority boundaries, execution-route table per capability (on-device Foundation Models / deterministic / absent / deferred-cloud). **2026-09-22 (D-083 Amend 1):** run-journal persistence LANDED — `AgentRunJournalLog` append-only JSONL (Application Support/PDFEditor/Instrumentation; `session-open` + `agent-run` rows, capability facts only, `isHealthy` flag per the X2 rule), wired via `AppModel.recordSessionOpen`/`recordAgentRun` + HUD terminal runs; T2/S1 (`Tests/PDFEditorCoreTests/AgentRunJournalLogTests.swift`). Kill thresholds per-user operationalized (GUI rows only, owner self-tests excluded, unreachable-until-cohort recorded, interim proxies named). **Checkpoint: X7 doc ships by 2026-09-30 regardless of launch-path pressure.** |
| NM-T42 | Implement | open | **D-083 slice 1:** "Teach Northstar this workflow" through the wired D-078 loop (drop → recurrence → plan sheet → per-step approval → bulk fill → receipt → save as workflow) with the inspectable journal/plan surface. Oracle: every rendered entry traces to a journal/receipt row. Outcome test: validated receipted mutation or saved workflow in under two minutes. **2026-09-22 (D-083 Amend 1):** the n=1 outcome test must also record the same task via Guided Next Blank and the loop must not be slower — a slower loop is recorded evidence scoping the spine to recurring workflows, not a direction kill. Gate: T01 matrix accepted + touched AppModel seams extracted (A-9) before new surface work. |
| NM-T43 | Implement | open | **D-083 slice 2:** goal capture as the shell's organizing input; open-ended goals degrade honestly to ranked command search (every offered step maps to an `AdaptiveCommandID` with a live `assess()` projection). |
| NM-T44 | Implement | open | **D-083 slice 3:** escalation/retry honesty surface — reason codes derived only from journal entries; visible "ledger unchanged" terminal state after escalated runs. |
| NM-T45 | Implement | open | **D-083 slice 4:** AI-native empty state; CTAs only to planner-supported goals (every CTA completes a real loop end-to-end); "Agent Desk" name ships here at the earliest. |
| NM-T18 | Implement | partial | Rework/variance/discard state machine exists; failed-review T4 remains. |
| NM-T19 | Implement | open | Add WIP-limited, page-local candidate review waves. |
| NM-T20 | Research | partial | Capability passport exists; document the research falsifiers and open-flow result. |
| NM-T21 | Implement | partial | Unverified/provider states exist in contracts; verify every native preflight surface. |
| NM-T22 | Research/prototype | open | Prototype optional spatial board and retain/reject it by task evidence. |
| NM-T23 | Explore/implement | open | Propose source-linked evidence-card schema and migration boundary. |
| NM-T24 | Research | open | Evaluate immersive/recall posture with accessibility falsifiers. |
| NM-T25 | Implement | partial | Existing diff/split primitives need a coherent synchronized compare job. |
| NM-T26 | Explore | open | Research Markdown/OPML/structured citation export interoperability. |
| NM-T27 | Implement | implemented-source | Proposed beta contract exists; owner acceptance and release-registry reconciliation remain open. |
| NM-T28 | Implement | open | Reconcile current calibration/fingerprint drift before detector-derived claims. |
| NM-T29 | Research/implement | partial | Current PDFKit lane proves extracted-page and authored-metadata-scrubbed copies; flattening is fail-closed; run provider bake-offs behind capability, privacy, license, and rollback gates for remaining profiles. |
| NM-T30 | Implement | open | Capture native accessibility, resize, focus, reduced-motion, and window evidence. |
| NM-T31 | Implement | open | Add TTL/build-aware companion handshakes and stale/degraded UI. |
| NM-T32 | Research | blocked | Requires approved signing/distribution credentials and owner decision. |
| NM-T33 | Implement | implemented-source | Settings disable/clear path and focused preference tests exist; T4 walkthrough remains. |
| NM-T34 | Implement/verify | partial | Unsigned arm64 preview package exists; visible-window and control-level T4/S3 proof remains. |
| NM-T35 | Research/implement | partial | Direct-context projection and recovery path exist; comparative T4 study remains. |
| NM-T36 | Research/implement | partial | Bounded aging, pins, and target abstention exist; stale-pin and quiet-menu comprehension remain. |
| NM-T37 | Implement | implemented-source | Northstar is now the native user-facing name through `ProductIdentity` and preview bundle metadata; `PDFEditor` remains the technical target name. Fresh packaged app-menu/window-title and release identity verification remain open. |
| NM-T38 | Implement/verify | implemented-source | The document toolbar is hidden when `model.inspection` is absent and restored for open-document reading modes; fresh packaged home/document/home, narrow-window, skim, and menu recovery observation remains open. |
| NM-T46 | Implement/verify | implemented-source | **Native `overlayImage` (signature placement)** landed 2026-09-21: `EditPayload.assetData` self-contained bytes; exports serialize through `PDFIncrementalFormWriter.incrementalImageStamp` (authored `/AP` stamp, annotation- and rotation-preserving, RG-017 prefix); live preview uses a verified page-draw bake. T2/S2 (`ReviewFixVerificationTests`). Probe record: `docs/audits/pdfkit-overlay-image-limit-verification-2026-09-21.md`; decision: D-048 amendment. |
| NM-T47 | Implement | partial | **Stamp writer landed; publication-path unification remains.** Done 2026-09-21: image-stamp serialization for annotated pages, rotated pages, and AcroForm documents (`nativeFieldValue` + `overlayImage` in one pass). Remaining: route merge/split/copy (which serialize the live document) through the provider so the interactive annotation-free restriction can lift; structural+overlay ordering semantics; independent-viewer (Poppler/qpdf) oracle pass over stamped output. |

## 2026-09-17 macos-development skill audit crosswalk

Findings, rationale, and skill-verdict detail:
[`audits/macos-development-skill-audit-2026-09-17.md`](audits/macos-development-skill-audit-2026-09-17.md).
**MAD-D1 resolved 2026-09-17 by D-083** (owner-directed AI-native agentic workspace;
council: [`audits/shell-decision-council-2026-09-17.md`](audits/shell-decision-council-2026-09-17.md))
— MAD-I6 (toolbar declutter) is unblocked, and the vision doc's spatial phases 2–5
proceed as D-083's parallel styling track (each surface ships only with
MAD-R1/R2 accessibility + human-visual evidence).
Delta on the MAD-001..018 ledger (macos-app-design audit 2026-09-11): MAD-001
resolved (commit `aa7e2da`). **Landed 2026-09-17 (implemented-source, built +
targeted tests green):** MAD-I2 real print (PDFView-based `NSPrintOperation` in
`PublishPipeline` + ⌘P `Print…` via `CommandGroup(replacing: .printItem)`,
routed through `AppModel.printDocument` so print shares the export lane);
MAD-I5 Help (⌘⇧/ + `northstar-help` Window scene, static honest content);
MAD-I8 reduce-motion gates (ContextualInspectorView, DocumentSplitView,
FreezePaneDragHandle, PageThumbnailRailView) + stale §12 comment removed;
MAD-I10 (⌘0 Actual Size; Confirm/Reject Field moved to a new Form Review menu;
Reject Field re-mapped ⌘⌫ → ⇧⌘⌫); MAD-I12 (Governance severity icons —
CollaborationHistoryView re-inspection found existing symbol+text redundancy);
MAD-003 partial (`LSApplicationCategoryType`; `scripts/package_mac_app.sh`
collapsed onto the canonical `tools/native-preview-Info.plist` so the dist
bundle can no longer drift — dist rebuilt with document types present).
Remaining open as stated in the audit: MAD-003 icon pass (design decision),
MAD-004 (main-actor parse), MAD-I7/I9/I11/I13, MAD-R1/R2/R5/R8.

| ID | Type | State | Current evidence or next action |
|---|---|---|---|
| MDEV-I1 | Research/implement | partial | `tools/native-preview.entitlements` (minimal set, no network) + `PDF_EDITOR_ENABLE_SANDBOX=1` signing flag in `build-native-preview-app.sh` + plan doc (`docs/research/sandbox-entitlements-plan-2026-09-17.md`) landed. Default-on remains gated on: companion child-process design under sandbox, recents/bookmark T4 round-trip, and NM-T32 signing decision. |
| MDEV-I2 | Implement | partial | Sweep verified all 26 bypass sites; ledger at `docs/research/sendability-invariant-ledger-2026-09-17.md` + drift check `tools/check-unchecked-concurrency.mjs` (green). CompanionNegotiator's dead-lock race **fixed** (lock now guards all three properties); OCRConfirmLane comment reconciled to the real semaphore mechanism; 5 unsafe sites carry inline UNSAFE markers. Remediation = MDEV-I6. |
| MDEV-I3 | Decide | open | Merge into A-9: AppModel.swift (6,527 lines, `@MainActor`) is the primary decomposition debt, not ContentView (NM-T06); coordinate with NM-T01 ownership matrix and MAD-I4 async open. |
| MDEV-I4 | Implement | implemented-source | App Intent failures now `throw` (`NorthstarIntentFailure`) instead of returning failure-shaped success strings; Shortcuts shows real errors. Shortcuts runtime T4 still open. |
| MDEV-I5 | Implement | implemented-source | `scripts/package_mac_app.sh` now consumes the canonical plist (executable/version stamped via `plutil`); dist rebuilt 2026-09-17 — `CFBundleDocumentTypes` + category verified in the packaged Info.plist. |
| MDEV-I6 | Implement | open | Fix the five race-flagged sites from the sendability ledger (RenderingPipeline mixed discipline; HTTPCompanionTransport + LocalCompanionTransport unsynchronized `connected`/handles; StudyLoopManager unlocked dictionary; FreezePaneState property-bypass) and give the PDFPage cross-actor handoff (AppModel:3961/:4003, DocumentCanvasView:607) a real enforcement mechanism. CompanionTransport pair + StudyLoopManager are small standalone fixes; RenderingPipeline should ride MAD-I4/A-9. |

## Research and exploration ledger

| ID | State | Research deliverable |
|---|---|---|
| NM-R01 | open | Intent-lens versus mode-picker task study. |
| NM-R02 | open | Evidence-rail trust/comprehension study. |
| NM-R03 | open | Spatial-board task study across reader, student, legal, and operations work. |
| NM-R04 | open | Evidence-card contract and round-trip/privacy falsifiers. |
| NM-R05 | open | One-window, tabs, or workspace-window decision record. |
| NM-R06 | open | Surface ownership map for inspector, utility windows, and sheets. |
| NM-R07 | open | Capability-passport copy and action-prediction study. |
| NM-R08 | open | Provider-neutral local-AI value/privacy/provenance bake-off. |
| NM-R09 | open | Accessible recall/immersive posture prototype and study. |
| NM-R10 | partial | Proposed versioned native beta contract and acceptance matrix exist; owner/release acceptance remains open. |
| NM-R11 | open | Fixed versus direct-context versus ranked versus pinned menu comparison. |
| NM-R12 | partial | Aging and explicit-pin contract exists; reset/stale-pin comprehension remains. |
| NM-R13 | open | Target-detection evidence matrix with annotation/image abstention cases. |
| NM-R14 | open | Quiet-menu recovery and absence-versus-capability comprehension study. |
| NM-R15 | open | External decision-tier model (TypeSafe AI Jev / System One) shadow-mode calibration spike replaying labeled security-finding history. **EXP-JEV-1 executed 2026-09-21 — KILL SIGNAL** (0.208/0.201 vs baseline 0.542/0.142); model-pin amendment recorded (request id `jev-latest`, served `jev-1.13.0`). Living doc: `docs/research/jev-system-one-model-capability-map-2026-09-18.md`; exploration map entry 10; increments in the JEV register below. Next: owner kill-or-continue call. |

## Snappiness + Jev work register (opened 2026-09-19)

Registered from [`audits/swiftui-performance-audit-2026-09-19.md`](audits/swiftui-performance-audit-2026-09-19.md)
(12 confirmed findings, 2 critical, code-backed; all file:line refs live there)
and the Jev product-fit map (J-01…J-06 + EXP-JEV-1…5 agenda). Promotion rule
unchanged: implementation slices land here first; Jev exploration results write
back to the research doc's change log before any promotion.

### PERF-S — SwiftUI snappiness fixes (implementation, payoff-ordered)

| ID | Type | Status | Task |
|---|---|---|---|
| PERF-S01 | Implement | implemented-source | **Landed 2026-09-21/22.** `RenderingPipeline.extractTextAsync()` (snapshot + detached extraction) + `ContentView` cache (`cachedTableExtraction`) with revision guard; both `matchedPresets` and `onAutoDetect` read the cache only. Trigger = `RenderingPipeline.didLoadDocumentNotification` (projection-revision trigger raced the canvas `loadDocument` and never fired — caught by probe). Audit mechanism corrected: the extractor is `ImprovedTextExtractor` (in-process PDFKit re-parse), not pdf_oxide — 0 child-process spawns before and after (shim-counted). Frame evidence: `extractText` absent from main thread after; once-per-load on a background thread. Evidence: `docs/audits/swiftui-performance-audit-2026-09-19.md` §fix pass. |
| PERF-S02 | Implement | implemented-source | **Landed 2026-09-21/22.** `scheduleViewportDrain()` coalesces bounds/frame/PDFView notifications to one drain per runloop tick; `freezePaneOverlay.needsDisplay` guarded on (page, scale) key; `forceReload()` → `reloadTiles()` (tile debounce restored; single caller); `persistReadingPositions()` debounced 1 s (no sync-persistence dependency found). Quiet-machine CPU deltas: idle churn −81% (+1.93 s → +0.36 s per 20 s), interaction +0.13 s → +0.00 s. Formal Instruments capture still pending (PERF-S14). |
| PERF-S03 | Implement | open | One-liner: `HumanReviewPanelView.updateNSView` compares `view.document !== document` instead of two full `dataRepresentation()` serializations per SwiftUI pass (HumanReviewPanelView.swift:367-371). |
| PERF-S04 | Implement | open | Root-body fan-out: extract status pill / redaction badge / export-enabled into leaf views taking narrow inputs; precompute `AdaptiveCommandContext.input` on mutating operations instead of per body eval (ContentView.swift:673-674, 1053-1115; `statusMessage` written from ~200 sites). |
| PERF-S05 | Implement | open | AgentCommandHUD: build `allCommands` once (cached), compute `filteredCommands` once per body eval, resolve adaptive context on open/selection-change — currently rebuilt+rescored 2-4× per keystroke (AgentCommandHUD.swift:60-544). |
| PERF-S06 | Implement | open | Guard nil→nil selection writes so a plain click stops invalidating the ~2.9k-line ContextualInspectorView (DocumentCanvasView.swift:202-206, 245-248). |
| PERF-S07 | Implement | open | DocumentCanvasView.updateNSView: incremental rotation on the presentation document; drop the full `document.copy()` + `dataRepresentation()` round-trip per revision change (DocumentCanvasView.swift:1413-1423). |
| PERF-S08 | Implement | open | Precompute page-rail badge counts in the model on operations/candidates change; cache `canOrganizePages` policy assessment — currently 3 dict builds + policy resolve per rail body eval (PageThumbnailRailView.swift:145-167). |
| PERF-S09 | Implement | open | Pipeline mode (opt-in): extract text once per revision; feed renderer document bytes once per open (currently full re-parse per render, 8 parses/open via warmUp); enforce cache eviction (maxCachedPages never enforced, clearCaches uncalled) + invalidate on revision; align warm-up DPI 72 with rail request DPI 12 so the warm cache actually hits (PipelineCanvasView.swift:275-347; ProgressiveRenderer.swift:85-161; RenderingPipeline.swift:315-384). |
| PERF-S10 | Implement | open | Comic mode: move panel detection + 150 DPI page render off the main actor (ComicPanelZoomView.swift:136-255). |
| PERF-S11 | Implement | open | Authoring canvas: decode/downsample image elements once per element (cached by id+data hash) instead of `NSImage(data:)` in body per drag frame (AuthoringCanvasView.swift:338-358). |
| PERF-S12 | Implement | open | Assorted lows: split-view per-pane full reparse + no-op updateNSView (correctness: pane page nav silently dead, DocumentSplitView.swift:223-237); browser `filteredDocuments` 3× per body; cache `fillProgressLabel`/`rankedActiveCandidates`; static Date/ByteCount formatters; remove leaked NotificationCenter observer (ContentView.swift:137-146); per-keystroke autosave Task churn. |
| PERF-S13 | Implement | open | Latent-path hardening BEFORE wiring: FreezePaneCompositeView drag double-publish + equality-free `config` didSet; PipelineTileOverlayView would sync-render tiles on main if ever wired (fix while unwired = cheap insurance). |
| PERF-S14 | Verify | partial | **Headless protocol established 2026-09-21** (`tools/perf-s14-capture/capture.sh`): 120-page reportlab fixture (generated via uv-installed reportlab in `benchmark/datasets/.venv`), `PDF_EDITOR_OPEN_SOURCE` launch (bare-binary argv suppresses windows, PL-I30), `sample` call-tree capture at open + interaction, cputime checkpoints, pdf_oxide PATH-shim spawn counter. Before/after evidence recorded in the audit's fix-pass section; primary oracle met at frame level (extraction off main thread). **Remaining:** formal Instruments (Time Profiler + SwiftUI View Body templates) and an in-app handler-invocation counter for the O(ticks×3)→O(1) claim; final CPU numbers need a quiet-machine re-capture (last attempt ran during a parallel-agent build storm). Artifacts: `benchmark/results/2026-09-21-perf-s01s02/{before,after}/`. Complements MAD-004 (main-actor open parse, still open). |

### JEV — TypeSafe Jev (exploration; access granted 2026-09-19)

| ID | Type | Status | Task |
|---|---|---|---|
| JEV-0 | Bookkeeping | closed | **Completed 2026-09-21.** Research-doc access state updated (granted 2026-09-19); key placed in repo `.env` (never tracked, chmod 600); pin instruction resolved against the live API: `jev-1.13` is not a valid request id (400), `/v1/models` exposes only `jev-latest`/`jev-preview`, responses report served `jev-1.13.0` — pin recorded as served-version + raw captures in the living doc and `tools/jev-replay/jev-client.mjs`. §1-2 claims remain sourced-only (first-party evidence now exists only for the triage corpus). |
| JEV-1 | Research | open | **EXP-JEV-1 / NM-R15 EXECUTED 2026-09-21 with live key — KILL SIGNAL fired** (pre-registered criterion): Jev 0.208 accuracy / 0.201 Brier vs deterministic baseline 0.542 / 0.142 on 24 scoreable cases; escalation class matched baseline (4/11), close class collapsed to 1/13 into "contain"; FP-class confidence deflated (0.407), not inflated. Report: `docs/research/jev-expjev1-report-2026-09-21.md`. Remainder (owner): kill the program per the criterion, or fund corpus expansion (raw Mimosa text recovery, synthetic FP/stale generation) + label-mapping ratification and re-run. Harness documented in `tools/README.md`; internal backlog priority pass (101 items) ran the same day under this caveat: `docs/agent-artifacts/jev-priority-pass-2026-09-21.md`. |
| JEV-2 | Research | partial | **EXP-JEV-4 executed 2026-09-21:** injection red-team on `state` (8 styles × 3 primitives × raw/framed, paired benign controls) — **zero genuine steering** (noul 0/8, choice 0/8 after mode-collapse correction, score max-injections 0/6), one drift signal from base64-obfuscated directives, framing free. Corroborating finding: Jev mode-collapses on long document-text states (do-later 15/16) — Jev-on-extracted-document-text falsified on attack AND utility grounds; short structured states remain the only viable lane. Report: `docs/research/jev-expjev4-injection-report-2026-09-21.md`. Remainder: full clearance suite (repetition per cell, second task, DoS shapes) only if the program survives the JEV-1 kill-or-continue call. |
| JEV-3 | Research | open | EXP-JEV-2: agent-trace "needs human review" replay over ExecutionReceipt corpora. Depends: JEV-1 pass + D-067 evidence-tier decision (JEV-6). |
| JEV-4 | Research | open | EXP-JEV-3: OCR confirm-queue ordering simulation on OCREvalHarness corpora (J-04). Most product-adjacent increment; waits for JEV-1 per agenda. |
| JEV-5 | Decide | open | EXP-JEV-5: doctrine §7 zero-egress amendment draft (opt-in egress lane, disclosure, dark-session exclusion). Owner call, informed by JEV-1/JEV-2. |
| JEV-6 | Decide | open | D-067 evidence-tier amendment: define `asserted-by-calibrated-model(confidence, model-version, prompt-version)` as a recorded-but-not-proof tier. Gates J-01 (agent lane) / J-02 (receipt risk column) promotion. |
| JEV-NOT | Note | closed | **Recorded verdict: Jev does not help the snappiness criticals.** PERF-S01/S02 are deterministic code defects. The hot-path decision seams (FreezePanePresetMatcher.match, AdaptiveCommandPolicy.resolve, ContentRouter.route) are Choice-primitive candidates ONLY after PERF-S caching lands — a 70-500ms network judgment inside a body eval would worsen finding 1. Shadow-first if ever pursued. |


## Carried-over open items (from the archived 2026-08-25 inventory)

Migrated 2026-09-06 from [`task-inventory-2026-08-25.md`](task-inventory-2026-08-25.md)
(now archived) so open work does not live only in a non-canonical file.
Discovered by the 2026-08-25/26 audits; statuses re-verified 2026-09-06 in
`docs/audits/epistemic-integrity-audit-per-0922-2026-09-06.md` (§7.1).

| # | Task | Type | Status |
|---|---|---|---|
| A-4 | Owner Git-checkpoint authorization (commit working tree in described batches) | owner gate | Open — now release-relevant: CI depends on untracked `benchmark/acroform-lane/` |
| A-5 | Regenerate semantic-parity bundles (fixes `browser_export_independent_viewer_validator_test`); blocked on removing machine-local Playwright path in the regen tool (now `tools/regenerate_browser_contract_bundles.mjs:20`) | implicit | Open |
| A-6 | Reconcile contract-parity ledger after native lane goes quiet (fixes `cross_project_evidence_ledger_parity_test`) | implicit | Open |
| A-7 | De-flake browser suite (condition-based waits); target two consecutive 79/79 runs | implicit | Open |
| A-8 | Portability: remove machine-local paths (28 Swift test paths + 14 mjs; `#filePath`-derived `AcroFormExternalEngines.projectRoot`; `/opt/homebrew/bin` hardcodes); document `Tests/pdf-python.mjs` fallback; stamp pdf-lib version | implicit | Open |
| A-9 | AppModel decomposition + module-rename evaluation (behavior-preserving, gated on green build) | implicit | Open — see epistemic audit §9 item 6 (X6) |
| A-10 | Termination probe relocation out of production binary; dead-code disposition for XFAFormProcessor/PDFBatchProcessor (re-verify parallel-lane wiring before acting) | implicit | Open |
| A-11 | **P7.G1**: route `PdfController.exportCopy` through `pdf-contract-mutation-gate.mjs` + preflight (currently bypasses the canonical gate) | implicit | **Implemented-source 2026-09-18 (T2)**: React lane now imports the canonical gate; `exportCopy` runs `assertExportableContract` with digest binding + per-page rotation facts before any pdf-lib usage; all three op-creation paths stamp `sourceDigest`+`bounds`+crop-space coordinates at creation; `web/operation-history.d.mts` + new `web/pdf-contract-mutation-gate.d.mts` carry the canonical types. Typecheck clean, `npm run build` green, gate tests pass. Remainder (P7.G1 completion): preflight reports (`sourcePreflight`/`expectedPreflightTransitions`) not yet passed from the React lane — app.js parity gap, fold into A-12; browser-driven export test (S2/T3) absent — named next check. |
| A-12 | **P7.G2a–c**: port vault/session/recovery UI, template domain UI, profiles/completion to React | implicit | Open |
| A-13 | **P7.G2d–G5**: reader completeness features; interaction parity dispositions | implicit | Open |
| A-14 | **P7.G3**: retarget ~35 legacy-coupled browser tests to React bundle; accessibility gate on React markup | implicit | Open |
| A-15 | **P7.G4**: `deploy-web.mjs` prebuilt-dist mode | implicit | Deployer half **completed 2026-09-01** (`--prebuilt` + `tools/smoke-dist.mjs`; evidence: `audits/prebuilt-dist-deploy-evidence-2026-09-01.md`); test repointing left to A-14 |
| A-16 | **P7.G6**: actual sunset deletion of app.js + legacy DOM — only after G1–G5 evidence green | implicit | Blocked on A-11…A-14. **2026-09-18 supersession finding (audit):** app.js (5,743 lines) is the editor of record and the repo's *only* implementation of session/draft persistence (IndexedDB `sessions` store keyed by sourceDigest, `web/app.js:441-533`), static-candidate detection pipeline, preflight integration, and the source-preserving export lane — the React lane has none of these. Deletion before porting those capabilities would destroy them. Salvage order: draft persistence → React first (this is audit IMP-1), then candidates/preflight (A-12/A-13 scope). X4 retirement-timing decision should explicitly sequence the port before any deletion. |

## Execution order

1. Re-run the snapshot immediately before each contested source/test claim and
   classify owner/mtime drift.
2. Establish `DocumentSession` and window ownership before further UI/domain
   extraction.
3. Complete native T4 evidence for the current home, toolbar, adaptive menu,
   inspector, recovery, keyboard, appearance, resize, and multi-window slice.
4. Exercise the bookmark-backed recent/drop identity path against moved,
   revoked, inaccessible, and reselected files; use explicit re-selection as
   the beta fallback whenever a bookmark cannot resolve without UI.
5. Close contract-to-view, profile-writer, provider, calibration, and full-suite
   gates with fresh source-bound evidence.
6. Only then prototype evidence cards, spatial synthesis, and immersive reading.
7. Finish signing, notarization, update, diagnostics, and release-contract work
   as separate distribution gates.

## Source map

- Detailed native findings and task definitions:
  [`audits/native-macos-product-audit-per-0926-2026-08-31.md`](audits/native-macos-product-audit-per-0926-2026-08-31.md)
- Native implementation sequence:
  [`roadmaps/native-macos-modernization-plan-2026-08-31.md`](roadmaps/native-macos-modernization-plan-2026-08-31.md)
- Contextual-menu decision:
  [`decisions/adaptive-contextual-command-doctrine-2026-08-31.md`](decisions/adaptive-contextual-command-doctrine-2026-08-31.md)
- Export output identity decision:
  [`decisions/export-output-disposition-recovery-2026-09-01.md`](decisions/export-output-disposition-recovery-2026-09-01.md)
- Visual grammar and design research:
  [`explorations/native-macos-visual-grammar-2026-09-01.md`](explorations/native-macos-visual-grammar-2026-09-01.md)
- Release/gate authority:
  [`release-gates.md`](release-gates.md)
- Proposed native beta boundary:
  [`decisions/native-beta-contract-2026-09-01.md`](decisions/native-beta-contract-2026-09-01.md)
- Proposed session ownership boundary:
  [`decisions/document-session-ownership-matrix-2026-09-01.md`](decisions/document-session-ownership-matrix-2026-09-01.md)
- Reproducibility snapshot tool and current artifact:
  [`../tools/native-audit-snapshot.mjs`](../tools/native-audit-snapshot.mjs),
  [`audits/native-macos-snapshot-2026-09-01.json`](audits/native-macos-snapshot-2026-09-01.json)

This inventory is intentionally uncommitted. The current worktree contains
concurrent changes and untracked artifacts; preserve them and re-run the
snapshot before any future ownership or release decision.
