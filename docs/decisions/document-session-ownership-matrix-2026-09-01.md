# Document Session Ownership Matrix

**Date:** 2026-09-01  
**Status:** Proposed architecture boundary; extraction not yet authorized as a
separate refactor slice  
**Related tasks:** NM-T01, NM-T03, NM-T06, P0.3, P0.4  
**Primary lens:** PER-0926, Product Evolution Architect  
**Review lens:** PER-0428, Feedback and Evidence Steward

## Purpose

Define one owner for each important fact in the native PDF session before
further decomposition of `AppModel` or `ContentView`. The matrix responds to
NMAC-001 and NMAC-020. It is an architecture decision aid, not evidence that
the future boundaries have already been implemented.

## First-principles rules

1. A fact has one authoritative owner and may have read-only projections.
2. Document identity, source bytes, inspection, operation lineage, and recovery
   are session-bound; they must not be recreated by a view or provider.
3. View state such as zoom, selection, focus, and pane visibility may persist
   through the session contract, but it must never become an export mutation.
4. Capability and permission facts are observations. An action policy may
   project them, but a toolbar or menu cannot grant them.
5. Durable persistence stores facts through versioned envelopes. UI state may
   request persistence but cannot write an independent shadow record.
6. Every boundary must preserve source digest, session ID, operation IDs, and
   evidence status across open, export, restore, mismatch, and discard paths.

## Current-to-target matrix

| Fact family | Current owner | Target owner | Read-only projections | Migration state and oracle |
|---|---|---|---|---|
| Source URL and admitted source identity | `AppModel` | `DocumentSession` admission boundary | Home, title, inspector, export receipt | Open; source digest must remain stable across open/reopen tests |
| Cached source bytes | `AppModel` | Session source store owned by `DocumentSession` | Provider/replay/export adapters | Open; no copy may become a second mutable source |
| Source inspection | `AppModel.inspection` and `sourceInspection` | `DocumentSession.inspection` with explicit original/current meaning | Passport, inspector, policy bridge | Partial; add invariants for original versus current inspection |
| Live provider document | `AppModel.liveDocument` | Provider session behind `DocumentSession` | Canvas renderer and field views | Open; provider remains replaceable and session-bound |
| Provider admission and negotiation | `AppModel` services and properties | Session capability boundary | Policy, passport, health/denial views | Partial; preserve provider-neutral outcomes and reason codes |
| Permission facts | Inspection/provider result | Capability policy input derived by session | Menu, toolbar, inspector, command palette | Implemented-source; denial must precede operation append |
| Ordered edit operations | `AppModel.operations` | `DocumentSession.operationLedger` | Undo/redo, receipt, diff, recovery | Partial; operation identity and source binding are already typed |
| Operation application and replay | `AppModel` plus provider | Provider adapter invoked by session command boundary | Export, undo, preview | Open; prove view transforms never append operations |
| Undo/redo availability | Derived from `operations` in `AppModel` | Session operation ledger projection | Menu, toolbar, palette | Implemented-source; broad command parity remains |
| Selected page | `AppModel.selectedPageIndex` | `ViewSession` | Rail, canvas, inspector, status | Partial; selection must be window-local |
| Selected field/candidate/annotation | `AppModel` selection properties | `ViewSession` target selection | Inspector, contextual menu, canvas overlays | Partial; target confidence and source digest remain required |
| Search query/matches/history | `AppModel` | Search session owned by document `ViewSession` | Search HUD, menu, accessibility announcements | Open; do not duplicate the existing reading history store |
| Zoom, scale, rotation, reader layout | `AppModel` | `ViewSession` layout state | Canvas, toolbar, layout persistence | Partial; view-only transforms must not enter export ledger |
| Reading posture | `AppModel.readingMode` | `ViewSession` intent/read posture | Toolbar, canvas, command palette | Open; coordinate with the proposed intent lens |
| Editor intent | `AppModel.editorMode` | User-facing intent projection over session/view state | Toolbar, command surfaces | Open; do not expose competing taxonomies without study |
| Recovery metadata and payload authority | `AppModel` recovery stores | Session recovery boundary | Recovery banner, recovery inspector | Partial; source/session/digest mismatch must fail closed |
| Pre-export review receipt | Derived from `AppModel` session | `DocumentSession.exportReviewReceipt` | Export review UI, recovery explanation | Implemented-source; durable output disposition remains separate |
| Post-export output identity/disposition | Host memory in `AppModel` | Separate governed output-record boundary, if approved | Inspect/forget/reselect UI | Proposed; bookmark/reselection research must pass first |
| Recent document list | Bookmark-backed `UserDefaults` records through `AppModel` | App-level local recent-file service | Home, open/recent UI | Partial; new successful opens persist opaque bookmarks with legacy URL fallback; moved/revoked sources remain explicit re-selection cases until T4 behavior is designed |
| Adaptive command history/pins | `AdaptiveCommandHistory.shared` | App-level value-free preference service | Policy bridge, Settings | Implemented-source; user reset and quiet-menu comprehension remain |
| Annotation sidecar marks | `AnnotationStore` in `ContentView` | Session-bound annotation store | Canvas overlay, inspector, context menu | Partial; avoid creating a second annotation authority in `AppModel` |
| Reading history/bookmarks | `ReadingHistoryManager` in `ContentView` | App/session reading-history service | Reader, bookmarks, study surfaces | Open; identity and retention policy must be explicit |
| Document index | `DocumentIndex` in `ContentView` | App-level index with one recent/history contract | Browser and home | Open; compare against `recentDocuments` before expanding |
| Theme and appearance | `ThemeManager` in `ContentView` | App appearance service | All native views | Partial; light/dark/high-contrast runtime proof remains |
| Utility-window presentation flags | `ContentView` | Scene/window coordinator | Menu and toolbar commands | Open; recurring tools should not become sheet-only state |
| Companion health and bridge | `AppModel` companion services | Session-independent companion service plus session negotiation | Health dashboard, policy, export | Partial; TTL/build-aware handshakes remain open |

## Window and lifecycle contract

Each native document window must own or reference a distinct session identity.
The following values must never leak between windows:

- source URL and source digest;
- live provider document and cached source bytes;
- ordered operations, undo/redo, and export receipt;
- page/field/candidate/annotation selection;
- recovery records and source-mismatch state;
- pending export output and disposition state.

App-level values may be shared only when their contract explicitly says so:
theme, bounded value-free adaptive preferences, capability catalog, provider
registry, and non-document UI preferences. Shared services must not use a
document URL, content value, or source digest as an implicit global key unless
the owning contract requires it.

Lifecycle events that need one command owner are:

| Event | Session authority | Required behavior |
|---|---|---|
| Open | Admission boundary | Bind source identity, inspect, capability state, and session ID before UI projection |
| New | Session factory | Confirm dirty work before replacing state; do not clear the old session silently |
| Close | Window/session coordinator | Keep or explicitly discard recoverable work according to the existing confirmation path |
| Export | Operation/export boundary | Build a new output, validate it, and keep source untouched |
| Restore | Recovery boundary | Match source/session/operation identity before applying state |
| Source mismatch | Recovery boundary | Inspect or forget only; no automatic mutation or disposition |
| Discard | Explicit user action | Remove the intended recovery record only after confirmation |
| Second window | New session/window boundary | Prove all document-bound values are independent |

## Safe extraction order

1. Add contract-level ownership assertions and snapshot helpers without moving
   fields.
2. Extract read-only projections for capability, export review, and recovery;
   keep mutation authority in `AppModel` until parity is proven.
3. Introduce a window/session coordinator and test two independent sessions.
4. Move view transforms and selection into a `ViewSession` boundary.
5. Move provider admission and operation replay behind session-facing APIs.
6. Remove duplicate view-owned stores only after all callers and tests are
   source-bound.

Do not split `AppModel.swift` by line count, create a second persistence store,
or rename a service while its ownership remains ambiguous.

## Verification obligations

- T1: every mutable fact in the matrix has one owner and one persistence path.
- T2: session/open/restore/operation tests preserve source digest and identity.
- T2: two session instances cannot mutate each other's operations or recovery.
- T2/S3: view-only rotation, zoom, page changes, and focus changes do not alter
  export operation lineage.
- T3: export/reopen/independent validation uses the session's source and
  operation identity.
- T4: two native windows, recovery mismatch, hidden UI recovery, keyboard
  focus, VoiceOver, and resize are observed on the packaged application.

## Current decision

Adopt this matrix as the architecture boundary for planning and review. Keep
the current implementation in place until the required tests and a quiet,
source-bound refactor slice are available. The matrix is aligned with the
local-first, source-preserving, evidence-aware doctrine; it does not close
NM-T01, NM-T02, NM-T03, or NM-T06 by itself.
