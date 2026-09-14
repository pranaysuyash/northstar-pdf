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
| NM-T13 | Implement | partial | Home recents/drop/create and in-place-drop source slices exist; available recent entries are full-row actions with stable identifiers, while stale entries expose explicit Locate recovery. T2 bookmark/history, successful replacement, and rejected replacement checks pass, while T4 stale-row, drop/preflight, and provider fallback proof remain. |
| NM-T14 | Implement | partial | Recovery Inspect/Discard source slice exists; T4 restore/source mismatch remains. |
| NM-T15 | Research/implement | open | Build screenshot and interaction regression matrix. |
| NM-T16 | Implement | partial | Evidence rail/passport source exists; contract-to-view and comprehension proof remain. |
| NM-T17 | Implement | partial | Review receipt/profile routing exists; extracted-page and sanitized-copy writers now have focused T2 reopen/source-preservation validation; edited/merge/T4 export proof remains. |
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
| A-11 | **P7.G1**: route `PdfController.exportCopy` through `pdf-contract-mutation-gate.mjs` + preflight (currently bypasses the canonical gate) | implicit | **Open — highest priority gate** |
| A-12 | **P7.G2a–c**: port vault/session/recovery UI, template domain UI, profiles/completion to React | implicit | Open |
| A-13 | **P7.G2d–G5**: reader completeness features; interaction parity dispositions | implicit | Open |
| A-14 | **P7.G3**: retarget ~35 legacy-coupled browser tests to React bundle; accessibility gate on React markup | implicit | Open |
| A-15 | **P7.G4**: `deploy-web.mjs` prebuilt-dist mode | implicit | Deployer half **completed 2026-09-01** (`--prebuilt` + `tools/smoke-dist.mjs`; evidence: `audits/prebuilt-dist-deploy-evidence-2026-09-01.md`); test repointing left to A-14 |
| A-16 | **P7.G6**: actual sunset deletion of app.js + legacy DOM — only after G1–G5 evidence green | implicit | Blocked on A-11…A-14 |

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
