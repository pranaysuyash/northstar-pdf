# Native macOS Product Audit and Evolution Map

**Date:** 2026-08-31
**Primary persona:** PER-0926 - Product Evolution Architect
**Secondary lens:** PER-0428 - Feedback Doctrine Alignment Reviewer
**Persona provenance:** `/Users/pranay/Desktop/personas_23rdaug26/01 Expanded Personas/14 Meta-Reasoning & Decision Systems/PER-0926 - Product Evolution Architect.docx`; SHA-256 `86180e3f95e0c00b56fbed71d66a06645005cf89299f3fc4a110a78d3a825007`; verified against `docs/personas/PER-0926 - Product Evolution Architect.docx`
**Scope:** Native macOS product design, native architecture as it affects UX, current shared contracts, evidence/release posture, new-age interaction opportunities, and implementation planning.
**Status:** Current audit and planning authority for the native macOS design program. It does not replace `docs/release-gates.md` as gate-state authority.

## 1. User request captured

This document records the complete request that initiated the audit:

| Request | Handling in this audit |
|---|---|
| Use any persona from `Desktop/Understanding_Personas_29aug26` | Used PER-0926, Product Evolution Architect; source and vendored hash verified. |
| Audit the repository and document everything | Reconstructed the native product, shared contracts, status/gate model, design artifacts, tests, dirty state, and known gaps. |
| List all implicit and explicit findings/tasks | Section 6 lists findings and the exploration, research, documentation, and implementation ledger. |
| Check whether work is first-principles, long-term, and doctrine aligned | Section 7 evaluates each major design/architecture direction on all three axes. |
| Identify what else can be improved or added | Section 9 provides a new-age macOS direction and bounded opportunity set. |
| Document chat material and full evidence | This request ledger, evidence register, current command results, source references, and uncertainty labels preserve the audit provenance. |
| Work on the implementation plan | `docs/roadmaps/native-macos-modernization-plan-2026-08-31.md` is the staged plan with dependencies and oracles. |
| Focus on a non-boring macOS app design | The recommendation centers on document sessions, intent lenses, evidence rails, spatial synthesis, review receipts, and calm native composition rather than a conventional toolbar redesign. |

## 2. Executive outcome

The repository contains a strong local-first PDF contract and evidence program, but the native macOS app is still a collection of capable surfaces rather than one coherent document product.

The most important conclusion is:

> Keep source identity, inspection provenance, operation lineage, provider capability state, and recovery as stable product primitives. Let navigation, visual composition, and task-specific tools evolve around those primitives.

The current direction is **architecturally promising, interactionally overloaded, and runtime-proven only in part**.

The app should evolve toward a native **document cockpit**:

```text
Document session
  source + inspection + capabilities + operations + recovery
       |
       +-- calm reader canvas
       +-- intent lens: read / complete / organize / review
       +-- evidence rail: what was detected, why, and with what confidence
       +-- context inspector: the selected thing's next valid actions
       +-- optional spatial board: compare, synthesize, or plan across sources
       +-- review receipt: exactly what will be exported and what was verified
```

This is not a request to build all of those surfaces immediately. It is the stable composition model that prevents each new capability from becoming another toolbar item, modal sheet, or manager dashboard.

### Current verdict by dimension

| Dimension | Verdict | Reason |
|---|---|---|
| First principles | **Mostly aligned** | Source-preserving export, typed operations, review-before-trust, and provider boundaries are sound. The UI still exposes capability taxonomy more than user intent. |
| Long term | **Partially aligned** | Contracts and evidence can evolve, but `AppModel`, scene ownership, native/web presentation, and multiple UI domains remain coupled. |
| Doctrine | **Aligned in intent; incomplete in proof** | The repo labels uncertainty and preserves evidence well. Native runtime, accessibility, multi-window, and current full-suite state are not closed. |
| Native macOS quality | **Conditional** | Menus and commands exist, but the default toolbar is crowded, advanced work is modalized, and native user-flow evidence is thin. |
| Release readiness | **No-go for unrestricted claims** | Current gate authority retains open/blocked gates and this audit observed current test drift in the dirty tree. |

## 3. Evidence method and snapshot

### Truth taxonomy

- **Observed:** directly present in current source, docs, or filesystem state.
- **Verified:** supported by a command or existing evidence artifact run in the declared lane.
- **Inferred:** a reasoned consequence of observed structure that still needs a focused experiment.
- **Proposed:** a recommendation, not current behavior.
- **Unknown:** not established by the available evidence.
- **Contested:** current sources disagree or concurrent work makes a single state unsafe to infer.

### Evidence tiers

The project doctrine defines Tier 0 through Tier 5. This audit uses them as follows:

- **T0:** user intent and design request.
- **T1:** static source, contract, documentation, and filesystem inspection.
- **T2:** focused local build, unit, fixture, or harness result.
- **T3:** cross-component or independent-engine proof.
- **T4:** native macOS or operator observation.
- **T5:** production-like or external real-data proof.

Test sensitivity is recorded as `S0` static, `S1` deterministic test, `S2` filesystem/rendering/cross-component behavior, and `S3` human interaction/accessibility/device behavior.

### Current command evidence

| Command or inspection | Result | Evidence interpretation |
|---|---|---|
| `git status --short --branch` | The initial snapshot reported `main...origin/main [ahead 5]`; live revalidation now reports `main...origin/main [ahead 7]`, with 50+ tracked modifications, many untracked artifacts, and at least one deleted benchmark export | T1/S0. The checkout changed concurrently and remains uncommitted. The delta is preserved as provenance; this is not a coherent release snapshot. |
| `shasum -a 256` on Desktop and vendored PER-0926 `.docx` | Exact match: `86180e3f95e0c00b56fbed71d66a06645005cf89299f3fc4a110a78d3a825007` | T1/S0. Persona provenance is verified. |
| `swift build --disable-sandbox` | `Build complete! (755.04s)`; arm64 executable present at `.build/arm64-apple-macosx/debug/PDFEditor` | T2/S2. Current source builds, but this does not prove native interaction quality. |
| `npm run typecheck` in `web/app` | Exit 0, `tsc -b --noEmit` | T2/S1. Web type contracts are currently clean in this lane. |
| `swift test --disable-sandbox --filter 'PDFEditorCoreTests|PDFEditorAppRecoveryTests|PDFEditorInlineEditorTests'` | The SwiftPM build completed, then the run exposed failures in active calibration/fingerprint expectations; the command was stopped after capture with exit 130 because the filter started a broad suite and the shared environment had concurrent helpers | T2/S1/S2. Current test state is not green evidence. Observed failures included `CalibrationPolicyTests`, `LayoutFingerprintV2Tests`, and `CapabilityMaturityTests`. |
| Current `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift test --disable-sandbox` | The initial XCTest layer passed 10/10. The Swift Testing layer started the full corpus and integration matrix but produced no further output for repeated bounded waits; the process was stopped after observation with exit 130 | T2/S1 unresolved. This run proves neither full-suite green nor a specific failure; retain the focused adaptive result separately. |
| Native app launch and human interaction | Fresh launch of current unsigned `.build/native-preview/PDFEditor.app` exposed one `AXWindow` with `AXStandardWindow`, title `PDF Editor`; the resized-window screenshot is retained at `audits/native-preview-home-2026-09-01.png`; System Events returned menu bar `Apple, PDF Editor, File, Edit, View, Window, Help`, and File entries including `New Document`, `New Window`, `Open...`, `Close Window`, `Save This Layout`, `Clear Saved Layout`, and `Export Copy...` | T4 window/menu existence and first-viewport rendering are observed for the current package. Control-level AX names, keyboard/focus, VoiceOver, resize matrix, reduced-motion, and multi-window behavior remain open. Earlier raw/packaged probe attempts that returned no window are retained as host/runtime variance evidence. |

The SwiftPM lock/concurrency condition is itself evidence. Existing helper processes were using the shared `.build` directory, so no process was killed and no cache was reset.

## 4. Product and architecture reconstruction

### 4.1 Stable foundations worth preserving

The following are genuine assets and should survive any redesign:

1. `DocumentInspection` represents source-derived page, field, link, metadata, permission, security, and accessibility facts.
2. `EditOperation` provides a typed, ordered mutation ledger with source/session binding.
3. The export path is intended to rebuild from source bytes plus operations, then reopen and validate a new copy.
4. Native widgets and inferred visual candidates are distinct semantic types.
5. Preflight, capability maturity, provider negotiation, provenance, privacy, and independent validation are explicit contracts.
6. Recovery, encrypted profile/template stores, version history, and companion health are already treated as domains rather than untyped UI state.
7. The project keeps unsupported capabilities visible as partial, blocked, reader-only, failed, or abstained instead of silently claiming success.

These foundations are aligned with PER-0926 because they define stable concepts while leaving provider implementations variable.

### 4.2 Current native composition

The active native path is:

```text
PDFEditorApp
  -> WindowGroup("Northstar")
  -> PDFEditorWindow
  -> ContentView
  -> RecoveryStatusBanner
  -> HSplitView
       PageThumbnailRailView
       DocumentCanvasView
       ContextualInspectorView
```

The main toolbar currently exposes or reaches:

- New, Open, Undo, Redo, Export, Manager;
- Editor mode picker;
- Agent command palette;
- Reader view mode;
- Diff;
- Reading mode;
- Freeze pane;
- Bookmarks;
- content suggestions, fill progress, and status.

This composition is visible in `Sources/PDFEditorApp/ContentView.swift:104-320` and `:337-758`. The three-pane structure is useful, but presenting the thumbnail rail, canvas, inspector, large toolbar, recovery status, and progress status together makes the app feel like a control center before the user has chosen a job.

### 4.3 Native lifecycle and state ownership

`Sources/PDFEditorRecovery/AppModel.swift:65-180` and `:390-497` show that `AppModel` owns source URL/data-related state, live document, inspection, operations, page selection, candidate and field selection, reader state, recovery, profiles, templates, provider negotiation, and many presentation flags.

`PDFEditorApp.swift:184-250` creates a stateful model inside the `WindowGroup` content and routes commands through focused values. That is a good start for focus-aware commands, but two-window independence and service ownership are not established by static inspection alone.

The evolution-safe split should be:

| Boundary | Owns | Must not own |
|---|---|---|
| `DocumentArtifact` | immutable source bytes, digest, URL identity, security facts | viewport, transient selection, UI presentation |
| `DocumentInspection` | derived facts and evidence origins | mutable user decisions or visual transforms |
| `OperationLedger` | ordered accepted/rejected/staged mutations | toolbar state or scroll position |
| `ViewSession` | window identity, focus, page, zoom, layout, selection | PDF serialization or source mutation |
| `CapabilityAdmission` | provider availability, limits, claim state, denial reasons | ad hoc button enablement |
| `RecoveryJournal` | versioned recoverable session envelope and export attempts | raw secrets, uncontrolled document copies |
| `DocumentWorkspace` | cross-document cards, citations, comparison links, spatial layout | source-byte mutation without an operation |

## 5. Design review

### 5.1 What is already good

The current design system has a clear document-first posture, warm paper versus slate canvas separation, evidence overlays, explicit capability states, and a five-stage product vocabulary. The existing design documents also call for direct manipulation, keyboard access, local-first behavior, and reversible operations.

The reference images in the repository point toward several useful patterns:

- PDF Expert: recognizable task grouping and clear visual examples, but also a conventional feature-catalog approach.
- Raycast and Dia: strong command-first identity and an opinionated “open this often” posture.
- Craft and Granola: calm editorial hierarchy and a product that feels like a place for work, not a toolbox wall.
- ChatDOC: source-linked intelligence as a visible product promise.
- Cursor: a reviewable work surface where actions, context, and generated changes remain visible together.

The product should synthesize those patterns without copying their branding or landing-page styling.

### 5.2 Findings ledger

| ID | Finding | Kind | Priority | Evidence | Current assessment |
|---|---|---|---|---|---|
| NMAC-001 | Source, live PDFKit document, inspection, operation ledger, and view state are all close to `AppModel` | Implicit | P0 | T1/S0; `AppModel.swift:65-180`, `:390-497`; `ContentView.swift:231-325` | Establish a state ownership matrix before adding more UI or providers. |
| NMAC-002 | Multi-window isolation is not fully proven | Explicit/implicit | P0 | T1/S0 plus T2/S1 model check; `PDFEditorApp.swift:184-250`, `Tests/PDFEditorAppRecoveryTests/DocumentWindowIsolationTests.swift` | The injected `AppModel` stores and per-model document state are isolated in a passing test; still require a packaged two-window T4 walkthrough for source digest, operations, undo, selection, export, and recovery independence. |
| NMAC-003 | The toolbar exposes too many unrelated action families at once | Explicit | P0 | T1/S0; `ContentView.swift:337-758`; Apple toolbar guidance | Source slice now separates navigation, history, primary export, workspace, secondary intent/view, and status regions; narrow-window/T4 collapse proof remains open. |
| NMAC-004 | `EditorMode` and `ReadingMode` are separate taxonomies that can compete for attention | Implicit | T1/S0; `DocumentModel.swift:477-530`, `ReadingMode.swift:22-220`, `ContentView.swift:461-576` | Keep both as internal capability/state concepts, but expose a single user intent lens. |
| NMAC-005 | Contextual inspector is the right anchor but contains too many domains | Explicit | T1/S0; `ContextualInspectorView.swift`; existing interface-density audit | Decompose by selected object and next valid action, with advanced details collapsed. |
| NMAC-006 | Advanced tools are presented as modal sheets even when users need document context | Explicit | T1/S0; `ContentView.swift:148-203`; `DocumentBrowserView.swift:57-72` | Use inspector/utility-window surfaces for history, browser, compare, and health; reserve sheets for bounded commitments. |
| NMAC-007 | The “Manager” menu hides high-value workflows behind a generic label | Explicit | T1/S0; `ContentView.swift:432-458` | Rename by user outcome or move to a document/workspace utility surface. |
| NMAC-008 | Empty state is functional but generic and not yet the product’s strongest identity | Explicit | T1/S0; `ContentView.swift:975-1300`; `EMPTY-STATE-SKETCHES*.html` | Source slice now provides recent work, bookmark-backed drop-to-open, a whole welcome-workspace drop target, integrated creation paths, and a product-shaped illustration; Tier-4 drop interaction proof remains open. |
| NMAC-009 | Recovery is represented, but the main banner is status-first rather than action-first | Implicit | T1/S0; `ContentView.swift:846-980`; `AppModel.swift:398-419` | Source slice now provides bounded Inspect details and explicit Discard confirmation; restore/source-mismatch and T4 kill/reopen comprehension proof remain open. |
| NMAC-010 | Native permission facts and action enablement need one domain policy | Explicit | T1/S0; `AppModel.swift:463-480`; prior macOS audit; current `ContentView` gates | Every action should ask the capability policy for a denial reason; UI-only disabling is insufficient. |
| NMAC-011 | Viewer rotation/navigation can blur view-only state and exportable mutation | Explicit | T1/S0; `DocumentSplitView.swift`; prior native design audit; operation/export contracts | Make presentation transforms distinct from document operations and add state-transition evidence. |
| NMAC-012 | The app has a strong command router but not yet a command-centered product identity | Implicit | T1/S0; `AppCommands.swift:287-570`, `AgentCommandHUD.swift` | Use commands as the fast path, but pair them with visible context and honest preview of consequences. |
| NMAC-013 | The app is visually “native-inspired” but native UX proof is incomplete | Explicit | T1/S0 plus current T4 packaged observation | Window existence, frame, standard menu bar, File-menu routing, and source-level accessibility landmarks are observed; add control-level AX labels, VoiceOver, keyboard-only work, focus restoration, resize, reduced-motion, and multi-window evidence. |
| NMAC-014 | The repository has many specialized dashboards and sheets that risk concept proliferation | Implicit | T1/S0; `find Sources/PDFEditorApp -maxdepth 1`; `ContentView` sheet list | Consolidate around document session, workspace, and utility-window boundaries. |
| NMAC-015 | Evidence-rich capability state is not yet a first-class visual layer in the native reader | Implicit | T1/S0; `DocumentCapabilityPassport`; preflight/capability contracts | The existing inspector passport is the single evidence rail; avoid duplicating it over the canvas and add Tier-4 comprehension proof. |
| NMAC-016 | Spatial reading/comparison is specified but not the default mental model | Explicit opportunity | T1/S0; `DocumentSplitView.swift`, `DiffComparisonView.swift`, `StudyLoopView.swift` | Promote an optional spatial board for research, comparison, and synthesis; keep the reader calm by default. |
| NMAC-017 | Knowledge and study capabilities are additive but lack one durable cross-document atom | Implicit | T1/S0; `ReadingHistory`, `AnnotationStore`, `StudyLoop`, citations, FSRS, document index | Explore a source-linked “evidence card” that can render as highlight, note, citation, study prompt, or review item. |
| NMAC-018 | The current gate registry can report many partials without forcing a product slice decision | Explicit | T1/S0; `docs/status-whats-next-2026-08-30.md`, `docs/release-gates.md` | Define a versioned native beta contract while retaining full capability obligations. |
| NMAC-019 | Dirty concurrent work makes current evidence non-reproducible as a single snapshot | Explicit | T1/S0; `git status`; modified calibration/parity files | Snapshot utility and dated manifest now capture branch/status, relied-on file hashes/mtimes, tool versions, and process/lock availability; owner classification and post-capture drift checks remain open. |
| NMAC-020 | Native source files contain a large amount of UI/domain responsibility in a few types | Explicit | T1/S0; `AppModel.swift`, `ContentView.swift` line counts and declarations | Extract session, command, inspector, and utility-window boundaries without changing contracts first. |
| NMAC-021 | Custom capsules and tinted toolbar controls compete with the native visual hierarchy | Explicit | T1/S0; `ContentView.swift:479-503`, `:680-755`; `DESIGN.md`; Apple toolbar guidance | Prefer standard symbols, system toolbar behavior, and a single prominent action; use custom color for evidence semantics. |
| NMAC-022 | The product’s strongest differentiation is not yet reflected in first-run language | Implicit | T1/S0; `WelcomeView`, `DESIGN.md`, evidence contracts | Lead with “open, understand, complete, and verify locally” rather than a generic PDF editor label. |
| NMAC-023 | “Agent” can be useful but requires a grounded interaction boundary | Implicit | T1/S0; `AgentCommandHUD.swift`, capability/evidence contracts | Make it a document-grounded command surface that previews sources, operations, permissions, and validation before execution. |
| NMAC-024 | No native design evidence currently proves 200% zoom, narrow resize, or reduced-motion behavior in the full app | Explicit | T1/S0; source modifiers and test inventory | Add screenshot and interaction matrix on real macOS windows; static modifiers are not proof. |
| NMAC-025 | Current build success and historical green counts can be confused with product completeness | Explicit | T2/S1/S2; current build/test results; `docs/status-whats-next-2026-08-30.md` | Every report must separate build, focused tests, live UX, capability claim, and release status. |
| NMAC-026 | Canonical product identity and native implementation name diverge in user-facing surfaces | Explicit | T1/S0; `DESIGN.md`, Northstar product-direction records, `PDFEditorApp.swift`, `native-preview-Info.plist` | Show Northstar in the native app menu, window scene, and bundle display metadata; retain PDFEditor only for technical compatibility until a separate migration is justified. |
| NMAC-027 | The document toolbar remains visible as a disabled control inventory when no document is open | Explicit | User screenshot `Screenshot 2026-09-01 at 3.29.19 PM.png`; T1/S0 `ContentView.swift:111-126`, `:249-256` | Hide the window toolbar in the home state. Keep the macOS menu bar and the welcome surface's Open, New blank, recent, and drop actions as the global/recovery paths. Restore the document or skim toolbar only after `model.inspection` exists. |

### Implemented slice: adaptive command surfaces and local behavior hints

The first implementation slice from this audit is now present in the current
worktree:

- `Sources/PDFEditorCore/AdaptiveCommandPolicy.swift` defines a pure,
  framework-neutral policy over intent lens, interaction target, capability
  facts, provider outcomes, provider reason codes, and local recent/pinned
  command IDs. Its `assess` projection distinguishes available, needs review,
  blocked, and unavailable states; `resolve` remains action-only for compact
  contextual surfaces.
- `Sources/PDFEditorCore/AdaptiveCommandHistory.swift` stores at most eight
  semantic command IDs and explicit pins in local `UserDefaults`. Recent hints
  expire after twelve later command interactions by command-distance age;
  explicit pins are separate, persist until cleared, and never bypass current
  eligibility. It records no document content, names, URLs, regions, timestamps,
  or network telemetry.
- `Tests/PDFEditorCoreTests/AdaptiveCommandPolicyTests.swift` covers fourteen
  cases: quiet scrolling, text selection, provisional and ambiguous target
  abstention, form fields, capability gating, page organization, pinning,
  deterministic overflow, immutability, stable anchors, explainable denial
  reasons, and the available/needs-review/blocked decision states. The history
  contract adds bounded recency, explicit pinning, and unrelated-default
  preservation tests, for eighteen focused tests across two suites.
- `Sources/PDFEditorApp/AdaptiveDocumentContextMenu.swift` projects the Core
  result into a native SwiftUI context menu and routes explicit actions to
  existing model/store APIs.
- `Sources/PDFEditorApp/PageThumbnailRailView.swift` projects the
  `pageThumbnail` target into a policy-gated `Organize Page` submenu containing
  the existing rotate, move, insert, and delete model actions.
- `Sources/PDFEditorApp/ContextualInspectorView.swift` projects the
  `formField` target into a compact field menu for Fill, Export, Undo, and
  Redo, using only commands with real handlers on that surface.
- `Sources/PDFEditorApp/ContentView.swift` exposes a Settings control to stop
  local adaptive ranking and clear recent command IDs and pins.
- `Sources/PDFEditorApp/AgentCommandHUD.swift` adds a policy-backed Current
  Context section to the command palette for Search, reading, field
  completion, Undo, and Redo, while retaining the broader specialist command
  inventory.
- `Sources/PDFEditorApp/DocumentCanvasView.swift` attaches the same menu to
  both PDFKit and pipeline canvas paths; `ContentView.swift` supplies the
  focused command-palette binding.
- `Sources/PDFEditorApp/ContextualInspectorView.swift` exposes a compact
  selected-object evidence rail using existing source page, extraction
  provenance, candidate confidence, limitations, and next-action facts.
- `Sources/PDFEditorApp/AdaptiveCommandContext.swift` is the single native
  adapter from `AppModel` permissions, live-document state, export eligibility,
  page capability, and local personalization into `AdaptiveCommandPolicyInput`.
- `Sources/PDFEditorApp/AnnotationCreationToolbar.swift` now makes visible
  user-authored sidecar marks reliable annotation targets. Each mark can be
  selected by pointer or assistive navigation and receives a policy-backed
  direct context menu for inspection plus sidecar-only copy/hide actions.
- `PageThumbnailRailView`, `DocumentCanvasView`, and
  `ContextualInspectorView` now expose stable native accessibility landmarks
  and identifiers for page navigation, document canvas, and document
  inspector. This is source/build evidence; VoiceOver traversal and keyboard
  focus behavior still require Tier-4 observation.
- `Sources/PDFEditorApp/ContextualInspectorView.swift` exposes the Core
  assessment as a collapsed "Why actions are quiet" disclosure. It shows a
  bounded set of unavailable, blocked, or needs-review reasons while leaving
  the canvas context menu action-only; menu-bar and Command-K recovery remain
  explicit. When an operation is denied by the authoritative model, the same
  rail now shows a bounded read-only denial explanation and requirement.
- `Sources/PDFEditorCore/ExportReviewReceipt.swift` defines the value-minimized
  pre-export review contract. It groups typed operations without payloads,
  distinguishes pending validation from verified post-export evidence, and
  fails closed on denied export or duplicate operation IDs.
- `Sources/PDFEditorApp/ExportReviewReceiptView.swift` is the native review
  moment for the canonical Export Copy path. Menu-bar, toolbar, command-palette,
  canvas, and selected-field entry points converge on it before the save panel;
  only its explicit continuation calls `AppModel.export()`.
- `Sources/PDFEditorCore/DocumentCapabilityPassport.swift` and the Document
  inspector projection expose a compact local capability passport. It uses
  available, pending, needs-review, blocked, and not-applicable states so an
  unknown permission is not confused with a source that lacks a feature.
- `Sources/PDFEditorCore/ExportReviewDisposition.swift` and the inspector
  disposition controls expose explicit Rework, Accept Variance, and Discard
  paths after a derived export report. Rework is available for a report;
  variance acceptance requires a validated-with-warnings report plus a
  present output; discard requires a present output. The value-minimized
  pre-export receipt is now carried in `DocumentSession` and remains
  migration-safe for older recovery envelopes; output URLs, output bytes, and
  post-export disposition remain in-memory host state until a separate output
  identity and recovery policy is approved.

The window scene now has a diagnostic-only `PDF_EDITOR_NATIVE_WINDOW_PROBE`
path. When enabled with `PDF_EDITOR_NATIVE_WINDOW_RESULT`, it records whether
the SwiftUI `WindowGroup` reaches an attached visible `NSWindow`, including the
observed frame. It does not load a document, mutate the operation ledger, or
change normal app behavior.

The evidence rail is a bounded P2.2 increment, not a new dashboard. It reports
the existing deterministic detector/provider identity and confidence for a
selected suggestion, the field inspector for a native field, or document-level
source context when nothing is selected. Its language preserves the distinction
between source structure, inference, and user confirmation; T4 comprehension
and accessibility observation remain open.

This slice intentionally does not infer edit intent from a click, persist raw
behavior, or bypass `AppModel` permission checks. It records only bounded,
value-free semantic command preferences and is a presentation projection only.
The native router now consults the same Core policy for Search, Export, Undo,
and Redo, while shell-specific page and zoom commands remain native. Remaining
alignment work is explicit: adapt real provider/evidence contracts at each host,
extend the new inspector denial/review disclosure to provider-specific flows,
add native field and image/object target extraction, and prove the menu through native
runtime tests rather than static compilation alone.

The repeated native capability mapping was consolidated into
`AdaptiveCommandContext`. This closes an architecture drift risk in NMAC-010:
the canvas menu, menu bar, page rail, selected-field inspector, and command
palette now share the same live-document, permission, export, organization,
and personalization facts before the Core policy evaluates them.

The policy also enforces the interaction invariant behind this direction:
scrolling cannot expose selection-only Edit Text, Annotate, or Extract Text
actions, and a form action requires a form-field target. These commands become
valid only after their corresponding target exists, so contextual menus do not
show visible no-op actions merely because the document has broad capabilities.

The page-thumbnail rail now projects the same capability authority into its
existing concrete rotate, move, insert, and delete operations. Those actions
are grouped beneath a native `Organize Page` submenu only when the page target
and modify capability are both present; read-only documents receive an honest
unavailable state instead of clickable no-op mutations. Settings now lets a
user disable ranking and clear the stored semantic IDs and pins without
touching unrelated preferences. The command palette receives the same current
context projection, with specialist actions remaining separate until they have
stable semantic IDs and evidence contracts.

Observed verification for this slice:

- `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift build --disable-sandbox` passed and linked `PDFEditor` after the typed policy, history store, native-router bridge, and page-rail projection.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache tools/build-native-preview-app.sh` produced `.build/native-preview/PDFEditor.app`; `file` confirmed an arm64 Mach-O executable and `plutil -p` confirmed a valid macOS app plist with PDF document registration. This is package/artifact evidence only.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift test --disable-sandbox --jobs 2 --filter 'AdaptiveCommandHistory|AdaptiveCommand'` passed with 18 tests in 2 suites: 14 policy tests and 4 history tests. The policy cases include provisional and ambiguous target abstention; the history cases include command-distance aging and explicit-pin persistence. The test runner also compiled the current OCR companion benchmark sources successfully.
- Revalidation at 2026-08-31 17:21 IST with `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift test --disable-sandbox --no-parallel --filter 'AdaptiveCommand|AdaptiveCommandHistory'` again passed with 14 tests in 2 suites. SwiftPM emitted only the known read-only user-cache warnings; no test failure was observed.
- The export surface now has an explicit `ExportReviewProfile` for edited, sanitized, extracted-page, and flattened copies. Sanitized and page-extraction actions route through the review receipt without inheriting the edited-operation permission gate; flattening opens a blocked receipt because the PDFKit lane cannot prove baking safely. Focused T2 validation now proves extracted-page and sanitized-copy reopen/page-count/source-preservation behavior. Sanitized validation checks authored title, author, subject, and creator fields; PDFKit-generated `Producer`, `CreationDate`, and `ModDate` remain serializer provenance and are documented rather than falsely treated as removable author data. Edited/merge writer governance and post-export T4 observation remain open.
- Derived export disposition now has a typed Core contract and native controls:
  Rework removes the last derived copy and returns the user to live document
  operations; Accept Variance is limited to validated-with-warnings output;
  Discard requires an output and asks for confirmation. The focused
  `ExportReviewDispositionTests` lane now passes all 4 tests with
  `--jobs 2`; an earlier high-parallelism attempt exited 137 during broad
  relinking, so low-parallelism rerun is the authoritative result.
- Focused corpus verification is green for `CalibrationCorpusVerificationTests` (15 tests) and `LayoutFingerprintV2Tests` (13 tests), including real-corpus calibration, V2 stability, cross-document rejection, false-positive artifact round-tripping, and content-free digests.
- `NativeDetectorGateTests` was attempted with `--disable-sandbox --no-parallel`; after repeated bounded waits it produced no test output and was stopped at the exact session boundary. It remains unresolved evidence, not a pass or a classified failure.
- `ExportReviewReceiptTests` passed with 6 tests covering clean pending-validation state, warning/destructive review, denied export, validated output, duplicate ledger IDs, payload-free serialization, and explicit copy-profile preservation. `SessionPrivacyProvenanceTests` also passed the durable receipt round-trip, including decoding an older envelope without the optional receipt field.
- `DocumentCapabilityPassportTests` passed with 4 tests covering unrestricted capabilities, no-field not-applicable state, restricted permissions, warnings, and no-document fail-closed behavior.
- The export toolbar now resolves eligibility through `AdaptiveCommandContext` and `AdaptiveCommandPolicy`, closing the remaining duplicated export-permission decision in the native shell. The help copy remains presentation-local; capability authority is shared.
- A current unfiltered `swift test --disable-sandbox` run passed the initial 10-test XCTest layer, then remained silent while the Swift Testing matrix was live; it was stopped with exit 130 after repeated bounded waits. No full-suite pass is claimed.
- On 2026-09-01, `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift test --disable-sandbox --jobs 2` rebuilt the package, passed the initial 10-test XCTest layer, launched the Swift Testing matrix, and produced no additional output for five minutes. It was stopped at that exact observation boundary with exit 130; this is a second unresolved full-suite run, not a failure diagnosis or a pass.
- An earlier focused `ExportReviewDispositionTests` attempt was blocked by unrelated `RasterWeightSweepTests.swift` compile errors. After the concurrent raster source was corrected, the authoritative low-parallelism rerun passed all 4 disposition tests; the earlier failure remains historical test-target evidence, not current behavior.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift test --disable-sandbox --jobs 2 --filter ExportReviewDispositionTests` passed with 4 tests in 1 suite after the concurrent raster sweep source was corrected. The package still emits known read-only SwiftPM cache warnings.
- `CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache swift test --disable-sandbox --scratch-path /private/tmp/pdf-editor-export-profile-test-4 --jobs 2 --filter 'ExportProfileValidationTests'` passed with 3 tests in 1 suite. The lane proves a standalone two-page extraction, a source-preserving authored-metadata-scrubbed copy, and explicit fail-closed flattening. An earlier run exposed PDFKit serializer-generated `Producer`, `CreationDate`, and `ModDate`; the implementation now treats those as framework provenance and validates user-controlled title, author, subject, and creator fields separately.
- The first test attempt failed only because the managed environment denied Swift's default module-cache path; the rerun used a writable temporary cache.
- Direct SwiftPM executable launch was observed as a live `PDFEditor` process, but
  an external System Events query reported no accessible application window
  (`false, 0,`) for both a terminal launch and `open` activation. Both probe
  processes were terminated after observation; no unrelated process was touched.
  The diagnostic window probe recorded `process-started` but never advanced to
  an attached or visible-window state; the process also emitted LaunchServices
  and `com.apple.hiservices-xpcservice` connection errors. This remains T2/S1
  executable evidence and is retained as host/runtime variance. A later exact
  System Events query against the current packaged preview observed one
  `AXWindow`/`AXStandardWindow` titled `PDF Editor` at `1280x820`, with the
  standard menu bar `Apple, PDF Editor, File, Edit, View, Window, Help` and a
  File menu containing `New Document`, `Open...`, `Close Window`, and
  `Export Copy...`. This closes window/menu existence for the current package,
  but not control-level accessibility or the rest of the T4 matrix.
- Fresh packaged launch on 2026-09-01 exposed one `AXWindow` titled `PDF Editor`
  with `AXStandardWindow`; after a bounded resize request, a screenshot of the
  live home surface was captured at
  `docs/audits/native-preview-home-2026-09-01.png`. The screenshot shows the
  responsive home composition rendering with Open/New actions, a drop surface,
  alternate creation paths, and the Letter/A4/Legal choice. A System Events
  traversal of the window returned no named descendant controls, so source
  labels are not promoted to control-level VoiceOver/keyboard proof. The native
  menu bar and File menu remained discoverable, including New Window and the
  export/recovery-adjacent commands. This is T4 visual/window/menu evidence,
  not a completed accessibility or interaction walkthrough.

## 6. Explicit and implicit task inventory

The following is the complete task pool from this audit. Task IDs are intentionally new and do not mutate existing gate IDs.

### Foundation and ownership

| ID | Type | Task | Why now | Exit evidence |
|---|---|---|---|---|
| NM-T01 | Implement | Define `DocumentSession` ownership matrix and migrate `AppModel` responsibilities behind session-facing interfaces | Prevent UI and provider growth from entrenching shared mutable state | T1 contract plus T2 unit tests; every mutable field assigned exactly once |
| NM-T02 | Implement | Prove independent windows with separate source, operation, undo, selection, recovery, and export state | Core Mac document behavior | T2 two-session tests and T4 manual two-window observation |
| NM-T03 | Implement | Separate `ViewSession` transforms from exportable `EditOperation` mutations | Prevent rotation/navigation/view updates from changing export semantics | T2 replay and no-op export tests; T4 rotation/navigation observation |
| NM-T04 | Implement | Introduce a typed capability/permission action policy with denial reasons | Make action availability consistent across menus, toolbar, inspector, and commands | T2 matrix tests; all denied actions fail before ledger mutation |
| NM-T05 | Explore/implement | Create a versioned snapshot manifest for dirty work, source digests, generated artifacts, and evidence commands | Restore reproducibility while concurrent agents are active | T1 manifest plus repeatable status/mtime/hash report |
| NM-T06 | Implement | Decompose `AppModel` and `ContentView` by ownership, not by arbitrary line count | Reduce coupling without creating duplicate stores | T2 unchanged contract suite; architecture review records boundaries |

### Native shell and interaction model

| ID | Type | Task | Why now | Exit evidence |
|---|---|---|---|---|
| NM-T07 | Implement | Replace flat toolbar composition with three groups: document/navigation, current intent, and review/export | Align with Mac conventions and reduce cognitive load | T4 toolbar observation at wide/narrow sizes; shortcut/menu parity |
| NM-T08 | Implement | Add a single intent lens: Read, Complete, Organize, Review; derive internal editor/reading states from it | Give users one understandable axis of control | T2 state mapping tests; T4 first-use and mode-switch observation |
| NM-T09 | Implement | Make advanced tools inspector or utility-window destinations instead of default sheets | Preserve document context and reduce modal interruption | T4 flows for history, browser, compare, governance, and companion health |
| NM-T10 | Implement | Add native `SidebarCommands`, `InspectorCommands`, and `ToolbarCommands` where appropriate | Make hidden/closed UI recoverable through the menu bar | T2 command inventory plus T4 menu-tree observation |
| NM-T11 | Implement | Replace generic “Manager” with outcome-based document/workspace utilities | Improve discoverability without adding top-level navigation | T4 first-use task completion observation |
| NM-T12 | Implement | Add explicit focus restoration and keyboard traversal contracts for every sheet, rail, inspector, and command palette | Make the app viable for keyboard and assistive users | T2 focus tests plus T4 VoiceOver/keyboard walkthrough |
| NM-T13 | Implement | Make the empty state a recent-work and drop-to-open surface with capability preflight preview | Turn first launch into product value | Source slice delivered in `ContentView.swift`, including visible stale recent rows and Locate; T2 replacement test passes, while T4 empty/open/drop flow at 1280x820 and narrow window remains open |
| NM-T14 | Implement | Surface recovery as Restore / Inspect / Discard actions, not only a banner | Protect user effort and explain consequences | T2 interruption tests plus T4 kill/reopen observation |
| NM-T15 | Research/implement | Build a native screenshot and interaction regression matrix | Static source cannot prove visual quality | T2 image diff for stable surfaces; T4 human review for behavior |
| NM-T35 | Research/implement | Define and evaluate a context-projection matrix where direct interaction state controls eligibility, bounded local history only ranks eligible actions, and fixed anchors preserve recovery | Make menus feel alive without turning behavior tracking into hidden authority | T2 projection matrix tests; T4 comparison of fixed, contextual, and user-pinned menus under NM-R11 |
| NM-T36 | Research/implement | Define bounded local command-history aging, stale-pin behavior, target-confidence abstention, and quiet-menu discoverability | Keep behavior-aware presentation useful over time without creating an indefinite user profile or hiding capability | Core target-confidence abstention is implemented and covered by T2 policy tests; T1 aging/stale-pin contract and T4 comprehension observation remain under NM-R12/NM-R14 |
| NM-T38 | Implement/verify | Hide the document toolbar while the home state has no admitted document, while preserving menu-bar and welcome-surface actions | Prevent disabled editor controls from competing with Northstar's first-run admission and creation flow | T2/source build plus T4 home-to-document-to-home observation at wide/narrow sizes, with skim-mode restoration and no loss of menu-bar recovery |

### Evidence-aware completion and review

| ID | Type | Task | Why now | Exit evidence |
|---|---|---|---|---|
| NM-T16 | Implement | Add an evidence rail showing source, provider, confidence, limitations, and next valid action for the selected object | Make the moat visible and actionable | T2 contract-to-view test; T4 selected field/candidate/permission flows |
| NM-T17 | Implement | Add a review receipt before export: operations, permissions, provider states, validation, and unresolved warnings | Turn trust into a user-verifiable moment | T2 receipt contract and mutation tests; T4 export flow |
| NM-T18 | Implement | Add rework / accept-as-variance / discard disposition to failed review items | Give failures a workflow instead of a dead end | T2 state-machine tests; T4 failed export/review observation |
| NM-T19 | Implement | Add WIP-limited candidate review and page-local waves | Reduce review fatigue on dense forms | T2 ordering/queue tests; T4 reviewer walkthrough |
| NM-T20 | Research | Define a document capability passport presented at open | Help users decide what is safe before investing effort | Research memo plus falsifiers; no UI claim until source facts are stable |
| NM-T21 | Implement | Make “unverified” a visible state wherever multi-engine or provider evidence is insufficient | Prevent evidence inflation | T2 serialized-state tests; T4 preflight display |

### New-age reading and synthesis

| ID | Type | Task | Why now | Exit evidence |
|---|---|---|---|---|
| NM-T22 | Research/prototype | Prototype an optional spatial board for excerpts, notes, citations, and comparison anchors | Differentiates deep work without polluting the default reader | T1 interaction spec plus T4 prototype study; retain/reject decision |
| NM-T23 | Explore/implement | Define a source-linked evidence card as a stable atom across highlight, note, citation, study prompt, and review item | Gives reading, understanding, and learning one evolution path | T1 contract; T2 round-trip and source-link tests |
| NM-T24 | Research | Evaluate recall/immersive reading as a distinct posture with explicit reveal and accessibility behavior | New-age focus should be useful, not decorative | T1 research with cognitive/accessibility falsifiers; no implementation without evidence |
| NM-T25 | Implement | Add cross-document compare with synchronized scroll, source-linked selections, and operation-safe annotations | Turns existing split/diff work into a coherent user job | T2 compare contract; T4 two-document walkthrough |
| NM-T26 | Explore | Add a citation/export workspace with Markdown/OPML/structured references | Makes understanding produce durable external value | T1 interoperability research; T2 source-link export tests |

### Capability and release hardening

| ID | Type | Task | Why now | Exit evidence |
|---|---|---|---|---|
| NM-T27 | Implement | Freeze a bounded native beta contract and explicitly version its non-goals | Convert permanent-looking partials into an honest release slice | Decision record, gate mapping, and release runbook |
| NM-T28 | Implement | Reconcile current calibration/fingerprint failures before relying on detector-derived UI claims | Current dirty evidence is not green | S2 red-to-green run with unique report and source digest |
| NM-T29 | Research/implement | Run provider bake-offs only behind current capability and privacy gates | Avoid provider-led product drift | T3 provider matrix with licenses, latency, fidelity, and abstention |
| NM-T30 | Implement | Add real native accessibility, resize, reduced-motion, and focus evidence | Native quality is currently under-observed | T4 evidence bundle with exact OS/build/viewport and findings |
| NM-T31 | Implement | Make companion handshakes TTL/build-aware and show stale/degraded state in UI | Long-term provider evolution requires version boundaries | T2 schema and stale-handshake tests; T4 health surface |
| NM-T32 | Research | Assess signing, notarization, update, and distribution implications for the chosen provider set | Release and licensing are separate gates | T1 legal/packaging decision record; no claim until approved |
| NM-T33 | Implement | Add a visible preference to disable or clear local adaptive-command history and pins | Behavior-aware presentation must remain user-controlled and inspectable | T2 preference tests; T4 settings and reset walkthrough |
| NM-T34 | Implement/verify | Package the native executable or provide a supported host harness for window, menu, accessibility, and resize observation | A SwiftPM process is not sufficient native UX evidence | T4/S3 visible-window observation with exact OS, build, frame, menu path, and interaction result |

## 7. First-principles, long-term, and doctrine alignment

### Alignment rubric

- **1P:** Does the direction solve the underlying user/system problem with the minimum truthful primitive rather than a surface patch?
- **LT:** Can it evolve across providers, document classes, versions, windows, and storage formats without breaking the user’s mental model?
- **DOC:** Does it preserve authority, evidence tiers, privacy, test sensitivity, ownership, documentation, and authorization boundaries?

| Direction | 1P | LT | DOC | Verdict and correction |
|---|---|---|---|---|
| Source bytes plus ordered operation ledger | Yes | Yes | Yes | Keep as the mutation foundation. Add explicit session/view boundaries. |
| Native PDFKit as the only permanent provider | Partial | No | Partial | Keep PDFKit behind an adapter; preserve provider admission and independent validation. |
| Five product modes as a visible permanent navigation rail | Partial | Partial | Yes | Keep as planning taxonomy; expose a single intent lens in the app. |
| Flat all-capabilities toolbar | No | No | Partial | Replace with task grouping, menus, command palette, and contextual inspector. |
| Contextual inspector | Yes | Yes | Yes | Keep, but narrow content by selected object and progressive disclosure. |
| Behavior-ranked contextual menus | Yes when target-state-first | Yes when history is bounded and resettable | Yes when local-only, explainable, and recoverable | Use selection/form/page state to decide what may appear; use recent commands only to order valid actions. Never infer permission or high-risk intent from clicks or history. |
| Weak target inference | Yes when uncertain targets abstain | Yes when confidence can improve without changing command meaning | Yes when the abstention is explainable and recoverable | Keep reader/document anchors available, but suppress target-bound mutation, extraction, and annotation actions for provisional or ambiguous targets. |
| Many modal sheets for advanced surfaces | Partial | No | Partial | Reserve sheets for bounded commitments; move recurring context into inspectors/utility windows. |
| Generic Manager menu | No | No | Partial | Rename by outcome and attach to document/workspace context. |
| Agent command palette | Yes if grounded | Yes if contract-backed | Yes if previewed and audited | Make the agent a typed client of the same command/evidence registry, not a parallel authority. |
| Automatic inferred field application | No | No | No | Preserve review-only candidates and explicit human confirmation. |
| Capability passport at document open | Yes | Yes | Yes | Good candidate for implementation after contract ownership is clear. |
| Evidence rail and export receipt | Yes | Yes | Yes | High-value signature experience; make it compact and human-readable. |
| Spatial board for excerpts and comparison | Yes for deep work | Yes if optional | Yes if source-linked and export-safe | Prototype first; do not make it the default reader. |
| Evidence card as cross-document atom | Yes | Yes | Yes if value-free provenance is enforced | Strong long-term primitive; requires schema and migration design. |
| AI summary/quiz with user review | Partial | Yes if provider-neutral | Yes only with source links and abstention | Treat generated output as proposal, never as source truth. |
| Permanent redaction as a toolbar action | Partial | Yes only with a dedicated provider lane | Yes only with irreversible confirmation and independent proof | Keep high-friction and receipt-backed. |
| Full capability registry as the release plan | No | Partial | Partial | Separate build obligation from claim readiness and create versioned beta slices. |
| Current green historical test counts | No | No | No | Re-run against the current source snapshot and state exact lane. |

### Stable versus variable map

**Stable concepts:** source digest, document/session identity, inspection provenance, operation IDs and order, capability admission, denial reason, evidence state, recovery envelope, export receipt, user-authored confirmation, and explicit unsupported status.

**Variable concepts:** PDF provider, OCR engine, candidate detector, layout algorithm, visual chrome, toolbar arrangement, board layout, local companion transport, hosted optional processing, and model choice.

**Migration rule:** A new provider or UX surface may replace a variable implementation only if it can project into the stable contracts, preserve prior source links and operation history, declare capability differences, and provide a rollback or downgrade path.

## 8. New-age macOS direction

### 8.1 Document cockpit, not toolbox wall

On open, show the document and a small capability strip:

```text
W-4 2026.pdf     2 pages     Local     Text + fields     3 suggestions     Ready to review
```

The strip is not a dashboard. It is a compact answer to “what is this, what can I do, and what is uncertain?” Clicking a state opens the evidence rail or capability passport.

### 8.2 Intent lens, not mode management

The user chooses an intent only when needed:

- **Read:** quiet canvas, page rail, find, zoom, bookmarks.
- **Complete:** selected field/candidate, keyboard tab order, evidence and next action.
- **Organize:** page board, multi-select, reorder, rotate, extract, merge.
- **Review:** operation ledger, diff, warnings, validation receipt, export.

The internal `EditorMode` and `ReadingMode` can still drive capabilities. The user should not need to understand their distinction.

### 8.3 Evidence rail as a native design element

When a user selects a field, candidate, search result, or warning, the right rail answers:

1. What is selected?
2. Where did it come from?
3. Which provider observed it?
4. What is known, inferred, unverified, or blocked?
5. What action is safe next?
6. How can the user undo, reject, or inspect it?

This is the product’s distinct visual language: not “AI magic,” but visible evidence and control.

### 8.4 Contextual menus as a state machine, not a surveillance feature

The preferred contextual-menu model is a three-layer projection:

1. **Eligibility comes from direct state.** Scrolling a PDF exposes reader actions. A text selection exposes selection actions. A form-field target exposes completion actions. A page thumbnail exposes page-organization actions. Permission and provider state can remove or downgrade an action, but a click alone cannot authorize an edit.
2. **Ranking comes from bounded preference.** Recent or pinned semantic command IDs may move already-valid actions toward the top. The app stores no raw clicks, cursor paths, document names, regions, or network telemetry. The user can disable and clear this local preference.
3. **Recovery comes from stable anchors.** Search, Command-K, menu-bar commands, keyboard shortcuts, and a deterministic “More Actions” path remain available even when the contextual projection changes.

This is stronger than a purely fixed menu for repeated work because the surface can become quieter while the document is being read, and more useful when a real target exists. It is safer than behavior-only personalization because visibility is explained by the current target and capability state, while behavior only affects ordering. The open research question is whether the ranking benefit is worth any discoverability cost; NM-R11 compares fixed, contextual, and user-pinned projections before high-risk actions receive any personalization.

### 8.5 Spatial board as an optional posture

Use a board for comparison and synthesis, not as a permanent canvas. A board item is a source-linked card with page, region, text/raster provenance, user note, and optional relation. Dragging a card changes workspace structure, not the source PDF. Double-clicking always returns to the exact source location.

This borrows the useful part of spatial tools such as MarginNote’s highlight-to-card-to-map relationship while keeping PDF mutation and knowledge-work state separate. MarginNote’s official product pages describe highlights, source-linked cards, mind maps, recall mode, and cross-document research as one workflow; those are current competitor observations, not proof that the same implementation should be copied.

### 8.6 Review receipt as the export moment

Before the user exports, make the result inspectable:

```text
Export copy
  4 accepted operations
  0 source-byte overwrite attempts
  Native fields: validated
  Inferred overlays: reviewed by you
  Independent reopen: passed
  Unverified: OCR layer not cross-checked
  [Export Copy] [Return to review]
```

The receipt should be concise in the normal path and expandable for power users. It should never imply that “validated” means “all PDF features are preserved.”

### 8.7 Calm focus and recall

Study and immersive modes can hide chrome temporarily, but the escape path, accessibility labels, and current posture must remain obvious. Blur/reveal, focus mode, and “one task at a time” patterns are worth prototyping only if they improve comprehension or recall, not because they look modern.

### 8.8 Command surface with grounded preview

`Cmd-K` should search the same command registry as the menu bar and toolbar. Each result should state target, permission, evidence requirement, and consequence before execution. Example:

```text
Extract page 4 as a new copy
Target: current document, page 4
Requires: read access
Creates: new PDF copy
```

The command palette is a speed layer, not an alternate product authority.

### 8.9 Native visual principles

- Use the system toolbar and menu bar as structural anchors.
- Keep the document canvas visually quiet and let the source paper carry visual weight.
- Use one prominent action per moment, especially in review and export.
- Use semantic colors for evidence states, not brand decoration.
- Prefer standard SF Symbols without custom pill borders when the system already communicates the action.
- Keep panels flat and connected to the document; avoid dashboard-card nesting.
- Make sidebar, inspector, and toolbar visibility recoverable through commands.
- Prefer utility windows or inspectors over sheets for recurring context.
- Test dark/light appearance, reduced motion, increased contrast, 200% text, and narrow resize on the native app.

## 9. Research and exploration agenda

These are deliberately not automatic implementation approvals.

| Research ID | Question | Falsifier | Deliverable |
|---|---|---|---|
| NM-R01 | Does the intent lens reduce time-to-first-success versus exposing editor and reading mode pickers? | Users choose the wrong posture or cannot find a needed command in a task walkthrough | Comparative native prototype study |
| NM-R02 | Does an evidence rail improve trust and correction without overwhelming casual readers? | Users ignore it, misread confidence, or take longer on simple fill tasks | 3-state inspector prototype with task timing and comprehension notes |
| NM-R03 | Is the spatial board valuable for more than research-heavy users? | It increases setup burden or fragments source context | Prototype with reader, student, legal, and operations tasks |
| NM-R04 | Should evidence cards be the canonical cross-document atom? | Migration cannot preserve source links, privacy, or operation boundaries | Contract proposal plus round-trip fixture |
| NM-R05 | Which native window model is best: one document per window, tabs, or a workspace window with document tabs? | Users lose source identity or multi-document compare becomes slower | Window-model decision record with T4 observation |
| NM-R06 | Which tasks merit a utility window instead of inspector content? | Window switching loses context or creates multiple sources of truth | Surface ownership map |
| NM-R07 | Can a capability passport predict safe action better than a generic preflight report? | Users cannot translate facts into a next action | Copy and interaction study |
| NM-R08 | Does local-only AI assistance create measurable value after privacy and provenance costs? | Suggestions do not improve accepted-output quality or require too much review | Provider-neutral bake-off and review metrics |
| NM-R09 | Is recall/immersive mode accessible and useful across visual, auditory, and keyboard workflows? | Blur/reveal blocks access or does not improve retention | Accessibility-aware prototype and study result |
| NM-R10 | What is the smallest native beta that feels complete? | The beta still requires users to understand provider/gate internals | Versioned beta contract and task-based acceptance matrix |
| NM-R11 | Does behavior-ranked contextual promotion improve task completion without reducing command discoverability or predictability? | Users hunt for relocated actions, distrust the menu, or cannot recover a hidden command | Comparative native prototype with fixed, contextual, and user-pinned projections |
| NM-R12 | What aging rule keeps local command history useful without becoming a permanent profile? | A command remains promoted after the workflow changes, or clearing is not trusted | Preference contract with bounded retention, stale-pin behavior, and reset walkthrough |
| NM-R13 | Which target signals are reliable enough for annotation and image/object menus? | False targets expose risky actions or target changes are visually ambiguous | Target-detection evidence matrix with abstention cases |
| NM-R14 | How should a quiet contextual menu communicate recovery without becoming a help panel? | Users interpret absence as lack of capability rather than current context | Native comprehension study with menu-bar and command-palette recovery |

## 10. Evidence register

### Current repository sources

- `DESIGN.md` - active design system, product posture, capability-state language, and new-age idea pool.
- `Sources/PDFEditorApp/PDFEditorApp.swift` - native scene, window controller, termination handling, focused values, and app activation.
- `tools/build-native-preview-app.sh` and `tools/native-preview-Info.plist` -
  deterministic unsigned local `.app` packaging for LaunchServices/runtime
  observation; signing and notarization remain separate release gates.
- `Sources/PDFEditorApp/ContentView.swift` - current native composition, toolbar, sheets, empty state, recovery banner, and status surface.
- `Sources/PDFEditorApp/AppCommands.swift` - native command/menu surface and keyboard shortcuts.
- `Sources/PDFEditorApp/ContextualInspectorView.swift` - context-sensitive field/candidate/action surface.
- `Sources/PDFEditorApp/PageThumbnailRailView.swift` - page rail, badges, and page context actions.
- `Sources/PDFEditorApp/DocumentSplitView.swift` and `DiffComparisonView.swift` - existing spatial comparison primitives.
- `Sources/PDFEditorRecovery/AppModel.swift` - current state, lifecycle, recovery, permission, operations, and provider orchestration.
- `Sources/PDFEditorCore/DocumentModel.swift` - `EditOperation`, `EditorMode`, and document contracts.
- `Sources/PDFEditorCore/ReadingMode.swift` - reading posture state.
- `Sources/PDFEditorCore/PreflightContracts.swift` and `CanonicalCapabilityMatrix.swift` - capability/evidence foundations.
- `docs/northstar-macos-landscape-and-product-direction-2026-08-25.md` - earlier native landscape and flow design.
- `docs/audits/macos-app-design-review-and-todo-2026-08-24.md` - earlier native architecture findings.
- `docs/audits/interface-density-control-surface-discoverability-audit-per-0088-0090-0092.md` - earlier density/discoverability findings.
- `docs/status-whats-next-2026-08-30.md` and `docs/release-gates.md` - current status and gate authority.
- `docs/audits/comprehensive-adhd-audit-round2-2026-08-30.md` - recent evidence-honesty and pipeline findings.
- `docs/audits/pda-audit-2026-08-28.md` - broad findings register, including orphaned inspector and UI aggregation concerns.
- `docs/personas/INDEX.md` and `docs/personas/PER-0926 - Product Evolution Architect.txt` - persona provenance and operating lens.
- `ref-*.jpeg` - local visual references supplied or preserved in the workspace; inspected as design evidence, not product requirements.

The local packaging path was exercised with
`CLANG_MODULE_CACHE_PATH=/private/tmp/pdf-editor-clang-module-cache ./tools/build-native-preview-app.sh`.
It produced `.build/native-preview/PDFEditor.app`; `file` confirmed an arm64
Mach-O executable and `plutil -p` confirmed the expected `APPL` metadata and PDF
document declaration. This proves package structure only. The app is unsigned,
and the host still needs to prove visible-window and interaction behavior. The
packaged executable was then launched with
`PDF_EDITOR_NATIVE_WINDOW_PROBE=1`; its result reached `process-started` but did
not reach a window state. The diagnostic terminal session was interrupted after
the bounded observation; this is not evidence of normal AppKit quit behavior.

### External design research

- [Apple Human Interface Guidelines: Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) - toolbars should be deliberate, grouped, customizable where useful, and kept from overcrowding; system overflow should be allowed to work.
- [Apple SwiftUI `ToolbarCommands`](https://developer.apple.com/documentation/swiftui/toolbarcommands) - native command support for toolbar and sidebar manipulation.
- [MarginNote official product page](https://www.marginnote.com/en/index.html) - current competitor description of source-linked cards, mind maps, recall, and deep-reading workflows.
- [MarginNote official research workflow](https://www.marginnote.com/en/scenarios/research.html) - current competitor description of highlights becoming searchable cards, cross-document synthesis, and source-linked retrieval.
- [MarginNote official featured features](https://www.marginnote.com/en/features/index.html) - current competitor description of cards as a shared atom across document, map, and recall surfaces.

External sources inform exploration and do not establish integration, licensing approval, user demand, or product parity.

## 11. Decisions and stop conditions

### Visual grammar and home slice (2026-09-01)

The current worktree now includes a bounded visual refresh derived from the
platform and product research recorded in
`docs/explorations/native-macos-visual-grammar-2026-09-01.md`:

- `WelcomeView` is now a native workspace composition with a primary Open
  action, honest creation paths, a single PDF drop target spanning the welcome
  workspace, and a recent-document continuation band.
- `DocumentFlowIllustration` uses native SwiftUI shapes and SF Symbols to
  communicate the real product lifecycle: Read, Shape, Export. It has a
  reduced-motion-safe static outcome and an accessibility label.
- `AppModel.open(url:)` records only successfully admitted PDFs through
  `rememberRecentDocument`; the local history is unique, newest-first, and
  capped at four entries. `RecentDocumentHistoryTests` covers persistence and
  the moved-source explicit re-selection fallback.
- Recent successful opens now persist a bounded bookmark-backed local record
  with a legacy URL projection. Drops first request an in-place provider
  representation so the original source can be admitted and bookmarked; when
  a provider exposes only a temporary representation, the app-owned copy
  fallback remains. A focused test records the current moved-file behavior as
  explicit re-selection rather than claiming automatic move tracking. This is
  T2/source evidence, not yet proof for moved, revoked, inaccessible, or
  reselected files in a packaged sandboxed run.
- The home recent list now keeps stale identities visible with an explicit
  Locate action. `AppModel.reselectRecentDocument` restores the original record
  when replacement admission fails and adopts a replacement only after the
  normal open pipeline succeeds. It returns an explicit admission result, so a
  rejected or password-gated replacement cannot create a false reading-history
  event. `RecentDocumentHistoryTests` passes the moved source, successful
  replacement, and rejected replacement flows at T2; packaged sandbox and
  revoked bookmark behavior remain open.
- `RecoveryStatusBanner` now exposes a compact status title, bounded details,
  diagnostics, and explicit Discard confirmation. It calls the existing
  `AppModel.discardRecovery()` authority and does not alter the recovery store
  contract. Restore/source-mismatch behavior remains in the existing lifecycle
  path and still needs T4 observation.
- `AdaptiveDocumentContextMenu` now records a semantic command only after its
  adapter accepts execution. Guarded or unsupported routes do not personalize
  later menus from a failed invocation; page organization remains owned by the
  executable page-rail menu, while native image/object targeting remains open.
- `WelcomeView` now uses `ViewThatFits` for wide/narrow hero and continuation
  arrangements, and both home drop-state and recovery-detail feedback disable
  their short animations when the system requests reduced motion.
- The lower welcome area is now one drop-or-create surface rather than a
  detached "Start another way" strip. Images, Clipboard, and Markdown remain
  explicit native actions inside the drop surface, while blank page size is
  selected from the adjacent New blank menu. The outer welcome workspace owns
  the PDF `onDrop` handler, so the hero, creation surface, and open whitespace
  share one drop interaction contract.
- The home surface exposes stable accessibility identifiers for the Open action,
  New blank menu, start workspace, and recent-document region. These are
  verification anchors only; a packaged control-level AX and VoiceOver
  walkthrough is still required before treating the home as fully accessible.

Evidence captured:

- T1 source inspection confirms the home action and model call paths.
- T1 snapshot capture uses `tools/native-audit-snapshot.mjs` and records the
  current evidence boundary in
  `docs/audits/native-macos-snapshot-2026-09-01.json`; it is a dirty-worktree
  manifest, not a freeze or backup.
- T2 focused recovery test passes: one test in one suite.
- T2 focused native policy/export/privacy/recovery lane passes 38 tests in
  seven suites, including adaptive target abstention, command-history aging,
  export receipt/disposition, capability passport, privacy provenance, and
  recent-document continuity.
- T2 native build passes and `tools/build-native-preview-app.sh` emits an
  arm64 unsigned preview at `.build/native-preview/PDFEditor.app`.
- 2026-09-05 refresh: the current-source `swift build --disable-sandbox`
  completed successfully after the home/recent interaction increment;
  `tools/build-native-preview-app.sh` rebuilt the exact preview bundle, and
  `RecentDocumentHistoryTests` passed 3 tests in 1 suite. The package remains
  unsigned, and this evidence does not close packaged drag/drop, keyboard,
  VoiceOver, resize, reduced-motion, multi-window, bookmark-lifecycle, or
  signing/notarization gates.
- The same refresh promotes Northstar to the native scene title, visible alert
  and accessibility identity, and preview bundle display/name metadata;
  `PDFEditor` remains the technical executable and artifact-path name. The
  historical T4 row above intentionally retains the pre-rebrand “PDF Editor”
  observation and must be re-run for runtime naming proof.
- A fresh launch of the rebuilt preview succeeded, but the follow-up System
  Events query was denied Assistive Access (`osascript ... System Events ...
  error -1728`). Therefore the current evidence verifies the bundle metadata
  and source path only; it does not verify the visible app-menu or window title.
- T2 package inspection confirms an arm64 Mach-O executable, bundle identifier
  `com.northstar.pdf`, PDF document registration, and minimum
  system version 15.0. Host process inspection was denied by macOS privacy,
  so the state of any separate full-suite process is unknown.
- T4 visual, drag/drop, VoiceOver, reduced-motion, narrow-window, and
  packaged two-window observation remain open because a fresh GUI launch was
  not authorized in this run. The new model-level isolation check is T2/S1
  evidence only and does not substitute for the GUI walkthrough.
- The unfiltered Swift Testing matrix remains unresolved and is being run by a
  separate concurrent process; it is not included in this slice's green claim.

### Decisions made by this audit

1. Use PER-0926 as the primary product-evolution lens and PER-0428 as the doctrine check.
2. Treat source identity, operation lineage, evidence state, capability admission, and recovery as stable concepts.
3. Treat the five-mode journey as a planning taxonomy and derive a simpler user-facing intent lens.
4. Prioritize native shell, state ownership, permission policy, evidence rail, and export receipt before adding more provider breadth.
5. Prototype the spatial board and evidence card before committing them to the main native flow.
6. Preserve all current gate obligations; do not convert sequencing into permanent scope exclusions.

### Stop conditions for implementation

- Do not change shared state ownership while another process is actively modifying the same source files without fresh status/mtime inspection.
- Do not call a native design slice complete without Tier-4 observation on the target macOS runtime.
- Do not present inferred candidates, AI output, OCR output, or provider agreement as source truth without evidence state.
- Do not replace the current provider or add external services without capability, privacy, license, failure, and rollback records.
- Do not stage, commit, push, reset, checkout, stash, or prune the existing dirty work without separate explicit authorization.

## 12. Handoff

The implementation sequence is in [`docs/roadmaps/native-macos-modernization-plan-2026-08-31.md`](../roadmaps/native-macos-modernization-plan-2026-08-31.md). The current coherent unit has delivered the P1 adaptive-command slice, export-authority consolidation, a bounded P2 evidence rail, text-selection and sidecar-annotation target projections, the document capability passport, the canonical Export Copy review receipt, explicit alternate export-profile routing, focused T2 validation for extracted-page and authored-metadata-scrubbed copies, a bounded native denial/review disclosure, and an unsigned native preview package. Provider/evidence adapters, provider-specific denial rendering, native field and image/object target extraction, contract-to-view tests, edited/merge writer governance, flattening, window-host proof, and Tier-4 native evidence remain open. The completed source and focused-test proof must not be promoted to native UX or release proof without those gates.
