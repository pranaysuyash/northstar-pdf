# Native macOS Modernization Plan

**Date:** 2026-08-31
**Derived from:** [`docs/audits/native-macos-product-audit-per-0926-2026-08-31.md`](../audits/native-macos-product-audit-per-0926-2026-08-31.md)
**Primary persona:** PER-0926 - Product Evolution Architect
**Doctrine baseline:** `OPERATING_DOCTRINE.md` v8.0 with Review, Exploration, Architecture, Testing, and Documentation routing
**Status:** Proposed implementation sequence; no code changes authorized by this plan alone

## Outcome

Make the native macOS app feel like one coherent, premium document workbench while preserving the project’s local-first, source-preserving, evidence-aware contracts.

The plan has one ordering rule:

```text
reproducible evidence -> session ownership -> native shell -> evidence-aware completion -> spatial deep work -> provider breadth -> distribution
```

Each phase has a behavior goal, bounded files, an owner boundary, an oracle, and a stop condition. A phase is not complete because its SwiftUI code compiles.

## Non-negotiable invariants

1. The original source is never overwritten by an export or recovery action.
2. Every accepted document mutation has a typed operation ID, source/session binding, and reversible or explicitly irreversible disposition.
3. View-only page, zoom, scroll, and focus state cannot silently become exportable document mutation.
4. Native widgets, inferred candidates, OCR evidence, AI suggestions, and user-confirmed operations remain distinct types.
5. Permission and capability denial happens in the action/domain layer before ledger mutation.
6. A new provider or UI surface projects through the canonical contracts and does not create a shadow pipeline.
7. The app states what is verified, unverified, partial, failed, blocked, or unsupported at the point of action.
8. Every native release claim includes Tier-4 runtime evidence for the relevant workflow.

## Phase P0 - Evidence snapshot and ownership contract

**Goal:** Establish a reproducible current baseline before changing the native shell.

| Task | Scope | Oracle | Stop condition |
|---|---|---|---|
| P0.1 | Create an audit snapshot manifest containing branch, status, file mtimes, source hashes for relied-on files, command versions, and active process/lock notes | T1 manifest can be regenerated and compared without Git mutation | Any relied-on file changes during capture; reclassify before proceeding |
| P0.2 | Classify the current calibration/fingerprint test failures as concurrent drift, regression, fixture issue, or stale expectation | S2 unique report with exact failing tests and owner | Do not use detector-derived UI claims while failures are unexplained |
| P0.3 | Define `DocumentSession` ownership matrix: artifact, inspection, operation ledger, view session, admission, recovery, workspace | T1 architecture record reviewed against `AppModel`, `ContentView`, `DocumentModel`, and providers | Any property cannot be assigned to exactly one owner |
| P0.4 | Define window identity and document lifecycle events | T1 event table covering open, new, close, export, discard, restore, source mismatch, and second window | Lifecycle action has no command owner or recovery behavior |

**Files likely touched:** new contract/docs first; later `Sources/PDFEditorRecovery/AppModel.swift`, `Sources/PDFEditorApp/PDFEditorApp.swift`, and `Sources/PDFEditorCore/DocumentModel.swift` only after ownership is clear.

## Phase P1 - Native shell and intent lens

**Goal:** Make the default document window calm, discoverable, and recognizably Mac-native.

Status: in progress. The adaptive canvas projection, typed availability
decisions, local command history, shared availability bridge for Search, Export,
Undo, and Redo, page-rail organization projection, selected-field inspector
projection, command-palette Current Context projection, and user reset controls
are implemented; native shell
consolidation and full runtime proof remain open.

| Task | Scope | Oracle | Stop condition |
|---|---|---|---|
| P1.1 | Group toolbar into document/navigation, current intent, and review/export | T4 observation at wide and narrow window sizes; no accidental default overflow | More than one visually competing primary action or commands missing from menu bar |
| P1.2 | Add one user-facing intent lens derived from internal editor/reading states | T2 mapping tests; T4 first-use walkthrough | Users must understand internal enum distinctions to choose a task |
| P1.3 | Add system toolbar/sidebar/inspector command support and customization/recovery paths | T2 command inventory; T4 menu tree and hidden-sidebar recovery | Any toolbar-only command lacks a menu path |
| P1.4 | Replace generic Manager label with document/workspace outcomes | T4 task discoverability observation | A user must browse internal feature categories to find a common action |
| P1.5 | Rework empty state around recents, drag/drop, and preflight capability preview | Source slice delivered in `ContentView.swift`; T4 empty/open/drop flow remains required | Empty state still describes product breadth without giving a useful first action, or drop/reduced-motion/accessibility behavior is not comprehensible |
| P1.6 | Add user controls for adaptive-command history, pins, and reset | T2 preference contract; T4 privacy/reset walkthrough | Local personalization cannot be inspected, disabled, or cleared |
| P1.7 | Compare fixed, direct-context, and user-pinned contextual menu projections; define bounded history aging, stale-pin behavior, target-confidence abstention, and quiet-menu recovery | T2 projection matrix plus aging/reset/abstention tests; T4 task completion, recall, and discoverability observation | Policy-level target-confidence abstention is implemented; users cannot predict or recover an action, ranking changes a high-risk decision, or a stale preference persists without clear control |

Implemented increment: `AdaptiveCommandPolicy` plus the native canvas context
menu promote reader actions while scrolling and selection-specific actions
after text selection, with deterministic overflow. The policy now exposes
typed availability decisions and bounded local recency/pinning, and the native
router shares policy availability for Search, Export, Undo, and Redo. The next
increment is to adapt real provider/evidence states, extend the bounded
denial/review disclosure to provider-specific reasons, and
add stable native field and image/object target extraction; sidecar annotation
targets are now directly selectable. Menu-bar, toolbar, page,
inspector, and palette eligibility now share the native adapter; their remaining
work is runtime proof and coverage of commands that still lack concrete handlers.

The page rail now uses the `pageThumbnail` target and explicit
`canOrganizePages` capability to gate its existing concrete operations beneath
an `Organize Page` submenu. The command policy remains the authority for
availability while `AppModel` remains the authority for mutation and
permission enforcement.
The existing Settings scene now provides a visible disable and clear path for
local command personalization. The focused decision record for this behavior
is [`docs/decisions/adaptive-contextual-command-doctrine-2026-08-31.md`](../decisions/adaptive-contextual-command-doctrine-2026-08-31.md);
it records the user's behavior-aware menu proposal, the accepted target-first
model, rejected behavior-only interpretations, and the remaining NM-R11,
NM-R13, and NM-R14 research questions. NM-R12 now has a command-distance
aging and explicit-pin policy; its reset comprehension evidence remains open.

The Focus inspector now begins with a selected-object evidence rail. It shows
source page, provider or extraction module, confidence or source-structure
status, a limitation, and one next action for a detected suggestion, native
field, or document with no selected object. It intentionally does not invent a
provider verdict or copy document content into a new store.

`AdaptiveCommandContext` now owns the native-to-Core capability mapping for all
adaptive surfaces. This keeps action eligibility consistent across the menu bar,
canvas menu, page rail, field inspector, and command palette while leaving
mutation authority in `AppModel`.

Behavior ranking remains an experiment, not a hidden authority. Direct
interaction state controls eligibility; recent or pinned semantic IDs may only
rank actions that are already valid. The default projection must stay
recoverable through the menu bar and command palette, and promotion must be
bounded by stable context, explicit capability state, and user pins. P1.7/NM-R11
must compare fixed, contextual, and user-pinned projections before making
recency the default for high-risk actions.

**Files likely touched:** `Sources/PDFEditorApp/ContentView.swift`, `AppCommands.swift`, `PDFEditorApp.swift`, `PageThumbnailRailView.swift`, and native design tokens. Avoid adding a second navigation rail.

## Phase P2 - Context and evidence surfaces

**Goal:** Make the product’s evidence moat visible without creating another dashboard.

Status: in progress. P2.2 now has a compact selected-object rail in the Focus
inspector, P2.3 has a compact document capability passport, P2.4 has a
durable, value-minimized pre-export receipt for the canonical Export Copy path,
and P2.5 has an explicit
Rework / Accept Variance / Discard contract and native controls. These are backed
by typed contracts and existing provenance, confidence, permission, and
validation facts; alternate-profile writer proof, native
comprehension/accessibility observation, post-export output identity/disposition
recovery, and T4 evidence remain open.

| Task | Scope | Oracle | Stop condition |
|---|---|---|---|
| P2.1 | Decompose `ContextualInspectorView` by selected object and next valid action | T2 view-model tests; T4 field/candidate/search/permission walkthrough | Inspector still renders every field for every selection |
| P2.2 | Add compact evidence rail with source, provider, confidence, limitations, and next action | T2 contract-to-view test; T4 comprehension check | Users confuse inferred, native, OCR, and verified states |
| P2.3 | Add document capability passport at open or on demand | T2 preflight projection; T4 open-flow observation | Passport becomes a technical dump or makes unsupported claims |
| P2.4 | Add review receipt before export | T2 mutation/receipt test; T4 export observation | Receipt hides unverified or unsupported conditions |
| P2.5 | Add rework/variance/discard disposition for failed review items | T2 state machine and recovery tests | A failed validation leaves the user with only a generic alert |

**Files likely touched:** `ContextualInspectorView.swift`, new native presentation view models, `PreflightContracts.swift`, capability contracts, and `ContentView.swift` export flow.

## Phase P3 - Lifecycle, accessibility, and multi-window proof

**Goal:** Close native behavior gaps that static source and package tests cannot prove.

| Task | Scope | Oracle | Stop condition |
|---|---|---|---|
| P3.1 | Prove two independent windows | T2 targeted tests plus T4 manual observation | Source digest, selection, undo, or recovery leaks across windows |
| P3.2 | Make recovery Restore/Inspect/Discard action-oriented | T2 interruption tests plus T4 kill/reopen flow | Source mismatch or discard outcome is ambiguous |
| P3.3 | Verify permission policy across menu, toolbar, command palette, and inspector | T2 denial matrix; T4 locked/restricted PDF flow | Any action can append a mutation after denial |
| P3.4 | Verify keyboard-only focus and VoiceOver labels | T4 evidence with OS version, build, window size, and exact path | Any critical flow requires pointer-only interaction or loses focus |
| P3.5 | Verify reduced motion, increased contrast, 200% text, narrow resize, full screen, and hidden UI recovery | T4 matrix with screenshots and findings | Layout occlusion, inaccessible control, or unbounded resize failure |
| P3.6 | Package the executable or provide a supported native host harness for observation | T4/S3 window, menu, accessibility, and resize evidence | SwiftPM process cannot expose a verifiable native window |

**Files likely touched:** `PDFEditorApp.swift`, `AppCommands.swift`, `ContentView.swift`, focusable subviews, and test targets. This phase is not complete from source annotations alone.

## Phase P4 - Spatial deep-work prototype

**Goal:** Test the differentiated experience without destabilizing the default reader.

| Task | Scope | Oracle | Stop condition |
|---|---|---|---|
| P4.1 | Prototype evidence card contract linking source page/region to note, citation, study prompt, and review state | T1 contract review; T2 round-trip fixture | Card cannot return to exact source context or leaks value-free/privacy boundary |
| P4.2 | Prototype optional spatial board for excerpts and comparison anchors | T4 task observation with reader, student, legal, and operations scenarios | Board increases setup burden or fragments the document session |
| P4.3 | Promote existing split/diff surfaces into a coherent compare job | T2 compare contract; T4 synchronized two-document flow | Compare requires switching between unrelated modal sheets |
| P4.4 | Prototype immersive/recall posture with accessibility escape paths | T4 accessibility-aware observation and retention hypothesis | Visual novelty is not paired with measurable comprehension or recall value |

No spatial prototype becomes default product behavior without a documented retain/reject decision.

## Phase P5 - Provider breadth and long-term capability program

**Goal:** Continue the full capability obligation after the native product foundation is coherent.

Sequence:

1. Resolve current detector/calibration drift and restore unique green evidence.
2. Complete permission, rotated replay, and independent preservation lanes.
3. Admit providers one capability at a time through the capability registry.
4. Progress OCR, text-run replacement, redaction, sanitization, page operations, signatures, XFA, PDF/UA, conversion, repair, templates, batch, companion, and collaboration according to existing build program gates.
5. Keep provider license, privacy, resource-limit, failure, rollback, and native/web parity evidence attached to each capability.

This phase must not be used to postpone P0-P3 native product proof.

## Phase P6 - Distribution and operational hardening

**Goal:** Make the chosen native slice responsibly distributable.

| Task | Evidence |
|---|---|
| Codesign and notarization | Apple account/credential gate plus signed artifact verification |
| Auto-update | Provider and hosting decision, signed update artifact, rollback path |
| Crash/support diagnostics | Local-only, redacted, value-free bundle with user control |
| Performance | Large-document latency, memory, cancellation, and main-thread stall evidence |
| Release contract | Versioned supported source classes, unsupported formats, and no-go claims |

These are separate release gates. A beautiful shell does not clear them.

## Decision gates

| Gate | Decision | Owner | Revisit trigger |
|---|---|---|---|
| G-01 | Is `DocumentSession` the sole native session boundary? | Product/architecture owner | Any new state added directly to `ContentView` or global `AppModel` |
| G-02 | Is the intent lens user-facing while editor/reading modes remain internal? | Product owner | User testing shows discoverability or power-user loss |
| G-03 | Which surfaces are inspectors, utility windows, or sheets? | Native UX owner | A new recurring workflow needs document context |
| G-04 | Is evidence card the durable atom for study/understanding? | Product/architecture owner | Source-link, privacy, or migration falsifier fails |
| G-05 | What is native beta scope? | Product/release owner | Any claim, pricing, distribution, or external pilot discussion |
| G-06 | Which provider capabilities are admitted? | Provider/release owner | New corpus, license, OS, or fidelity evidence |

## Verification protocol

Before each phase closes:

1. Re-read the exact current files and check status/mtime for concurrent changes.
2. Run focused tests first, then the relevant broader suite.
3. Run architecture review: one owner, one source of truth, no duplicate authority.
4. Run rule-compliance review: permissions, privacy, evidence labels, authorization, and docs.
5. Capture runtime evidence separately from source/test evidence.
6. Record failures, unknowns, and rollback path in the completion ledger.

## Completion ledger

| Date | Phase/item | Evidence | Status |
|---|---|---|---|
| 2026-08-31 | Plan created from native macOS audit under PER-0926 | `docs/audits/native-macos-product-audit-per-0926-2026-08-31.md` | Proposed |
| 2026-09-01 | Native toolbar grouping increment | `ContentView.appToolbar` now uses semantic navigation, history, primary export, workspace, secondary intent/view, and shared status regions; menu-bar recovery paths remain unchanged | Native build passes; T4 wide/narrow placement, collapse, and hidden-control recovery observation remains open |
| 2026-09-01 | Recovery banner action increment | `RecoveryStatusBanner` now offers bounded Inspect details and explicit Discard confirmation backed by `AppModel.discardRecovery()` | Native build passes; T4 restore/source-mismatch and kill/reopen comprehension observation remains open |
| 2026-09-01 | Contextual history integrity increment | `AdaptiveDocumentContextMenu` records local command hints only after its adapter accepts execution; unsupported canvas targets abstain while page organization remains on the executable page rail | Native build passes; direct menu interaction, accessibility, and image/object target proof remain open |
| 2026-09-01 | Responsive and motion-accessibility increment | `WelcomeView` uses `ViewThatFits` for wide/narrow home compositions; home drop-state and recovery-detail feedback honor `accessibilityReduceMotion` | Native build passes; real packaged narrow-window, reduced-motion, and VoiceOver observation remains open |
| 2026-09-01 | Preview package revalidation | Rebuilt `.build/native-preview/PDFEditor.app` after responsive home, reduced-motion, and contextual-history changes; inspected arm64 executable, bundle identity, PDF registration, and macOS 15 minimum | T2 package metadata green; launch, control-level accessibility, multi-window, and release signing/notarization remain open |
| 2026-09-01 | Native audit snapshot increment | Added `tools/native-audit-snapshot.mjs` and generated `docs/audits/native-macos-snapshot-2026-09-01.json` with branch/status, relied-on hashes and mtimes, command versions, and explicit process/lock availability | T1 reproducibility boundary captured; owner/mtime drift classification after capture and concurrent-work reconciliation remain open |
| 2026-09-04 | Explicit stale recent-file re-selection increment | Recent rows remain visible when their source is missing; Locate opens the PDF picker, and `AppModel.reselectRecentDocument` restores the old record on failure, returns admission to the caller, and adopts a replacement only after successful admission | `RecentDocumentHistoryTests` passes moved-source, successful replacement, and rejected replacement flows; packaged sandbox bookmark lifecycle, revoked/inaccessible cases, and drag/drop proof remain open |
| 2026-09-05 | Recent-document hit-target and recovery affordance increment | Available recent entries are full-row open actions with stable identifiers; missing entries keep the identity visible and reserve the row action for an explicit Locate recovery control | Native build and package rebuild pass; packaged keyboard/VoiceOver traversal and moved/revoked/inaccessible runtime cases remain open |
| 2026-09-05 | Native product identity increment | Promoted Northstar to the SwiftUI scene title, visible native identity, and preview bundle display/name metadata while retaining PDFEditor for technical target and artifact compatibility | Current-source build and unsigned arm64 package rebuild pass; fresh app-menu/window-title and distribution migration proof remain open |
| 2026-09-05 | Empty-state toolbar boundary increment | Hide the document window toolbar when no PDF is admitted; keep the menu bar and welcome workspace actions, and restore the existing full or skim toolbar for an open document | Source change is bounded to `ContentView` and the native macOS 15 toolbar visibility API; packaged home/document/home, skim, resize, and menu-recovery observation remain open |
| 2026-09-01 | Bookmark-backed recent/drop identity increment | `AppModel` persists bounded bookmark records for successful opens; home drop requests an in-place file representation and falls back to an app-owned temporary copy when the provider cannot grant one; provider failures now surface an alert | T2 history/bookmark/moved-source fallback checks pass; explicit packaged Locate/re-selection, revoked/inaccessible source cases, and packaged drop proof remain open |
| 2026-09-01 | Proposed native beta contract | Added `docs/decisions/native-beta-contract-2026-09-01.md` with user-job scope, explicit non-goals, evidence thresholds, and promotion rules for NM-T27/NM-R10 | Source decision exists; owner acceptance and canonical release-registry reconciliation remain open |
| 2026-09-01 | Session ownership matrix | Added `docs/decisions/document-session-ownership-matrix-2026-09-01.md` assigning document, view, recovery, provider, preference, and utility-window facts to one target owner each | T1 architecture boundary captured; field migration, two-window isolation, and unchanged-contract proof remain open |
| 2026-09-01 | Model-level multi-window isolation increment | Added `Tests/PDFEditorAppRecoveryTests/DocumentWindowIsolationTests.swift`; two independently injected `AppModel` sessions keep source URLs/digests, session IDs, page geometry, selection, zoom, and status state separate | T2/S1 one-test lane passes; packaged two-window source/operation/undo/selection/export/recovery walkthrough remains open |
| 2026-09-01 | Fresh packaged window and menu observation | Launched `.build/native-preview/PDFEditor.app`, observed one `AXStandardWindow` titled `PDF Editor`, captured the resized home surface, and enumerated the standard menu/File commands | T4 window/menu/first-viewport evidence captured; System Events returned no named descendant controls, so control-level AX, VoiceOver, keyboard, resize matrix, reduced-motion, and multi-window proof remain open |
| 2026-09-01 | Whole-workspace drop and home creation dock increment | Moved PDF drop ownership to the welcome workspace, added a full-surface target state, grouped Images/Clipboard/Markdown creation inside the target, and moved blank page size into the New blank menu | Native build and foreground package screenshot pass; actual drag/drop, keyboard activation, narrow-window, reduced-motion, and control-level accessibility walkthroughs remain open |
| 2026-08-31 | Adaptive command surfaces | `AdaptiveCommandPolicy`, typed decisions, `AdaptiveCommandHistory`, `AdaptiveTargetConfidence`, canvas/page-rail/field/command-palette projections, Settings reset controls, and native-router bridge | Source/executable build and 18 focused adaptive tests pass, including provisional/ambiguous target abstention and command-distance aging; direct process launch was observed, but T4/S3 native window/menu interaction remains open |
| 2026-08-31 | Evidence rail increment | `ContextualInspectorView` selected-object rail using existing provenance, confidence, limitations, and next-action facts | Native build passes; T4 comprehension/accessibility observation and a dedicated contract-to-view test remain open |
| 2026-08-31 | Native preview packaging increment | `tools/build-native-preview-app.sh` plus `tools/native-preview-Info.plist` produce `.build/native-preview/PDFEditor.app` with validated arm64 executable and PDF document metadata | Package structure passes; current packaged observation shows one `AXWindow` at `1280x820` and the standard menu/File tree; signing, control-level accessibility, keyboard/focus, resize, and multi-window proof remain open |
| 2026-08-31 | Native capability-mapping consolidation | `Sources/PDFEditorApp/AdaptiveCommandContext.swift` is consumed by the menu bar, canvas menu, page rail, inspector, and command palette | Native build and 18 focused adaptive tests pass; native field/image target extraction and full runtime parity remain open |
| 2026-08-31 | Sidecar annotation target increment | `AnnotationMarksOverlay`, `selectedAnnotationID`, direct mark context menu, selected annotation evidence card, and sidecar-only Hide/Copy actions | Native build passes; annotation sidecar tests and the combined 100-test annotation/adaptive/disposition lane pass; native PDF annotation/image targeting and T4 observation remain open |
| 2026-08-31 | Native accessibility landmark increment | Stable identifiers and labels for page navigation, document canvas, and document inspector | Native build and packaged arm64 verification pass; VoiceOver traversal, keyboard focus, resize, reduced-motion, and multi-window runtime evidence remain open |
| 2026-08-31 | Export authority consolidation and corpus verification | `ContentView` export eligibility now resolves through `AdaptiveCommandContext`; focused calibration and V2 fingerprint lanes | Native build passes; 15 calibration tests and 13 V2 fingerprint tests pass; detector gate and full-suite runtime remain unresolved |
| 2026-09-01 | Export profile writer validation increment | `AppModel` profile-specific extracted-page and sanitized-copy writers now publish separate outputs and validate reopenability, page count, source preservation, and authored metadata scrubbing; flattened profile remains fail-closed | `ExportProfileValidationTests` passes 3 tests with low-parallelism SwiftPM; PDFKit serializer provenance (`Producer`, `CreationDate`, `ModDate`) is documented as framework-generated; edited/merge governance, provider bake-off, and T4 export observation remain open |
| 2026-08-31 | Export review receipt and profile routing increment | `ExportReviewReceipt`, `ExportReviewProfile`, `ExportReviewReceiptView`, profile-specific routing for edited, sanitized, extracted-page, and flattened copy requests, and optional `DocumentSession.exportReviewReceipt` persistence | Native build passes; 6 receipt contract tests plus the durable session round-trip pass; profile-specific writer validation is now partial through the 2026-09-01 extracted/sanitized slice, while merge governance and T4 export observation remain open |
| 2026-08-31 | Export review disposition increment | `ExportReviewDisposition`, `ExportReviewDispositionOptions`, `AppModel` output identity, native Rework / Accept Variance / Discard controls, and `ExportReviewDispositionTests` | Native build passes; 4 disposition contract tests pass with `--jobs 2`; output identity/disposition recovery policy and T4 failed-review observation remain open |
| 2026-08-31 | Document capability passport increment | `DocumentCapabilityPassport` plus the native Document inspector projection | Native build passes; 4 passport contract tests pass; T4 comprehension and accessibility observation remain open |
| 2026-08-31 | Contextual-command doctrine increment | `docs/decisions/adaptive-contextual-command-doctrine-2026-08-31.md`, audit task `NM-T36`, and research questions `NM-R12` through `NM-R14` | User proposal and implementation boundary documented; direct-context policy and weak-target abstention are tested; retention, target extraction, and native comprehension research remain open |
| 2026-09-01 | Full-suite verification attempt | `swift test --disable-sandbox --jobs 2` rebuilt the package, passed the initial 10-test XCTest layer, launched the Swift Testing matrix, then produced no output for five minutes and was stopped at the exact boundary with exit 130 | Full-suite status remains unresolved; focused native policy/export/privacy/recovery lane is independently green |
| 2026-09-01 | Focused cross-boundary verification | Isolated low-parallelism `swift test` filter passed 38 tests in seven suites after the adaptive menu and home/recovery changes | T2 green for the selected contracts; full-suite and T4 native interaction remain unresolved |

## Uncommitted work

This plan does not stage or commit anything. The repository already contains concurrent dirty changes and untracked evidence artifacts; preserve them and re-audit ownership before implementing any overlapping task.
