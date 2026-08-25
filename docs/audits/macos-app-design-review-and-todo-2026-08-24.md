# macOS App Design Review and Long-Term TODO Ledger

**Project:** PDF Editor  
**Review date:** 2026-08-24  
**Review scope:** Full native macOS application surface, shared PDF contracts, export path, tests, and the existing project audit ledger  
**Skill applied:** `/Users/pranay/.agents/skills/macos-app-design/SKILL.md`  
**Doctrine baseline:** `OPERATING_DOCTRINE.md`, Review Doctrine, and the project's existing evidence ledgers  
**Review mode:** Read-only source review plus durable documentation; no product-code implementation was requested in this pass  
**Status:** Open, actionable, and not a release approval

## 1. Executive assessment

PDF Editor has a promising local-first bounded-mutation core. The project already separates native widgets from static visual candidates, keeps an operation ledger, rebuilds exports from source bytes, reopens output for validation, and maintains meaningful web, security, preservation, template, and contract evidence.

The native application is not yet a complete macOS document editor. The largest risks are structural rather than cosmetic:

- The source PDF, live `PDFDocument`, derived inspection, operation ledger, and transient view state do not yet have one explicit ownership model.
- A single `@State` app model is injected into a `WindowGroup`, so multi-window independence is not established.
- The command and document lifecycle surface is incomplete for a Mac document-based app.
- Permission semantics are visible in inspection but are not enforced consistently at the user action boundary; page-text copy is a confirmed example.
- Undo is replay-based, session recovery is not durable in the inspected app surface, and the live viewer can mutate PDF page rotation.
- Native accessibility, keyboard interaction, VoiceOver behavior, reduced-motion behavior, and native UI regression proof are not established by the inspected test surface.

**Review posture:** `CONDITIONAL / NATIVE HARDENING REQUIRED`. This is a review disposition, not a claim that the application cannot be used. Existing web and PDF evidence remains valuable, but it does not prove the native Mac experience.

## 2. Evidence and truth rules

This ledger uses the project's truth taxonomy:

- `Observed`: directly present in the inspected source or documentation.
- `Verified`: supported by an existing recorded runtime or test artifact. Tests were not rerun for this review.
- `Inferred`: a reasoned consequence of observed structure that still needs a targeted experiment.
- `Proposed`: a recommended design or acceptance rule, not current behavior.
- `Unknown`: not established by the inspected material.
- `Contested`: conflicting evidence or an unresolved architectural choice.

Evidence tiers used here:

- `T0`: user or project intent.
- `T1`: static source, contract, or documentation inspection.
- `T2`: existing local runtime or test evidence preserved in the repository.
- `T3`: reproducible cross-component or independent-engine evidence.
- `T4`: observed native user workflow evidence on the target OS.
- `T5`: production or long-running field evidence.

Sensitivity labels:

- `S0`: static or contract inspection.
- `S1`: deterministic unit or fixture behavior.
- `S2`: cross-component, filesystem, rendering, or performance behavior.
- `S3`: human interaction, accessibility, multi-window, or real-device behavior.

The review records a current fact separately from a recommendation. A proposed architecture is not counted as implemented, and an existing test artifact is not treated as proof outside its actual lane.

## 3. System reconstruction

The current native flow can be reconstructed as:

```text
source PDF bytes
    -> PDFKit inspection and cached source-derived records
    -> native widget inventory and static-region/OCR candidates
    -> AppModel selections, search state, reader state, and operation ledger
    -> live PDFKit PDFDocument projection for viewing
    -> export rebuild from source bytes + operations
    -> reopen and impact validation
    -> save panel / user interpretation
```

The intended invariant is sound:

```text
Export(sourceBytes, orderedOperations) -> outputBytes
```

The native UI currently weakens that invariant because the live viewer is also used as a mutable projection. For example, `PDFKitView.updateNSView` changes page rotation on the live `PDFDocument`, while export is rebuilt from `sourceData` and `operations`. That creates two potentially different truths: what the user is looking at and what the export pipeline will serialize.

The long-term architecture should make these layers explicit:

```text
DocumentArtifact
  immutable source bytes, source digest, security and permission facts

DocumentInspection
  derived page geometry, text, native widgets, candidates, provenance

OperationLedger
  ordered, typed, validated document mutations with stable operation IDs

ViewSession
  window identity, viewport, page, zoom, selection, search, overlays, focus

ExportProjection
  deterministic rendering of source artifact plus operation ledger
```

The viewer should consume the first four layers and project them visually. It should not silently become a second mutation store.

## 4. Strengths to preserve

These are positive findings and architectural assets, not TODOs to remove:

- The app is local-first in its inspected native path and presents processing as on-device.
- `DocumentModel`, shared contracts, template contracts, and runtime contracts provide a useful boundary between document facts, inferred candidates, operations, and template behavior.
- The operation-ledger approach is the correct foundation for bounded non-destructive editing and independent export validation.
- The project explicitly distinguishes native PDF form widgets from static visual overlays. That distinction should become more prominent in the UI and export report.
- Existing evidence covers independent preservation, PDF reopen behavior, contract parity, template security, provenance, browser accessibility, and reviewed template matching.
- The project retains the PDFKit public AcroForm radio-choice failure as a provider gate instead of weakening the preservation criterion.
- The web tests show a stronger contract and accessibility discipline than many early native prototypes. That discipline should be extended to AppKit and SwiftUI rather than replaced.

## 5. Detailed findings

### F-MAC-001: Multiple mutable representations lack an explicit source-of-truth contract

- **Priority:** P1
- **Category:** Architecture, provenance, correctness
- **Type:** Implicit
- **Truth:** Observed, with an Inferred cross-system risk
- **Evidence:** T1 / S0 from `Sources/PDFEditorApp/AppModel.swift`, `Sources/PDFEditorApp/ContentView.swift`, and `Sources/PDFEditorCore/PDFKitProvider.swift`
- **Current state:** `AppModel` owns source data, a live `PDFDocument`, inspection, operations, selections, search, candidate state, and reader rotation. `PDFKitView.updateNSView` mutates the live document while export rebuilds from source bytes and operations.
- **Expected state:** One canonical document/session model explicitly separates immutable input, derived inspection, document mutations, and view-only state.
- **Trigger:** A user rotates pages, searches, selects a candidate, edits a field, undoes, opens a second window, or exports after several view updates.
- **Why it matters:** Users need the page they are viewing, the page they are editing, and the page they export to agree. The current split can produce stale, surprising, or non-reproducible behavior.
- **Technical consequence:** Rotation, selection, transient annotations, and operation replay can cross representation boundaries. Future providers will inherit undocumented assumptions.
- **Immediate correction:** Write and adopt a state ownership matrix before adding more editing features.
- **Proper architecture:** `DocumentArtifact`, `DocumentInspection`, `OperationLedger`, `ViewSession`, and `ExportProjection` with explicit conversion boundaries and stable document/session IDs.
- **Acceptance criteria:** Every mutable property is assigned to exactly one layer; export can be reconstructed without reading view state; viewer updates are projection-only; a state-transition trace can explain every user-visible change.
- **Related TODOs:** T-MAC-001, T-MAC-002, T-MAC-006.

### F-MAC-002: Window state is not proven independent

- **Priority:** P1
- **Category:** macOS scene architecture, data isolation
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 at `Sources/PDFEditorApp/PDFEditorApp.swift:6`, where one `@State` model is passed into `WindowGroup` content
- **Current state:** The application creates one shared model at the app level and injects it into every window in the group.
- **Expected state:** Each document window owns an independent session and document identity, while truly global services remain shared.
- **Trigger:** Opening two PDFs, reopening a recent file, creating a new window, or switching between windows while one has unsaved operations.
- **Why it matters:** A document editor must not let search selection, undo history, candidate dismissal, current page, permission state, or export target leak between windows.
- **Technical consequence:** Shared operation arrays and source data can cause cross-window mutation or undo contamination.
- **Immediate correction:** Establish a two-window behavior matrix and make window ownership explicit before adding more scene commands.
- **Proper architecture:** Scene-scoped `DocumentSession` identified by document UUID and source digest; app-scoped services limited to file coordination, settings, and provider capabilities.
- **Acceptance criteria:** Two simultaneous documents retain independent source digests, operations, undo stacks, selections, search results, and export destinations; closing one window cannot alter the other.
- **Related TODOs:** T-MAC-001, T-MAC-003, T-MAC-010.

### F-MAC-003: The standard Mac command and document lifecycle is incomplete

- **Priority:** P1
- **Category:** macOS design, discoverability, keyboard access
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 at `Sources/PDFEditorApp/PDFEditorApp.swift:24-38` and the toolbar in `Sources/PDFEditorApp/ContentView.swift`
- **Current state:** The scene replaces New Item and adds Export Copy. The main toolbar carries Open, Undo, Export, and reader controls, but the inspected command surface does not provide a complete Edit, View, Window, Find, page navigation, or document lifecycle map.
- **Expected state:** Primary actions are available through the menu bar, standard shortcuts, toolbar affordances, and contextual state. The app behaves like a document-based Mac application rather than a single toolbar view.
- **Trigger:** A keyboard-only user tries to copy, find, go to a page, close a modified document, open a second document, or access an action when the toolbar is hidden.
- **Why it matters:** macOS users discover commands from menus and shortcuts. Toolbar-only access is not equivalent to Mac-native interaction and is especially harmful for accessibility and power users.
- **Technical consequence:** Commands lack centralized enablement, key equivalents, validation, and scene focus semantics.
- **Immediate correction:** Create a command inventory with action owner, menu placement, shortcut, enabled condition, undo behavior, and accessibility label.
- **Proper architecture:** SwiftUI `Commands` and `CommandGroup` for standard Edit, View, Window, and Help surfaces, with typed intent handlers routed to the active document session.
- **Acceptance criteria:** Open, New, Close, Save/Export, Duplicate, Revert or Discard, Undo/Redo, Copy, Find, page navigation, zoom, rotation, and Settings have discoverable menu paths and deterministic shortcuts; command enablement reflects the active session.
- **Related TODOs:** T-MAC-003, T-MAC-004, T-MAC-009.

### F-MAC-004: Permission facts are not enforced consistently at mutation boundaries

- **Priority:** P1
- **Category:** Safety, permissions, user trust
- **Type:** Explicit plus implicit matrix gap
- **Truth:** Observed for copy; Unknown for complete mutation coverage
- **Evidence:** T1 / S0. `PDFKitProvider` computes `PDFPermissionsSummary.canCopy`; `AppModel.copyCurrentPageText` does not gate on it; `ContentView` exposes `Copy page text` unconditionally.
- **Current state:** The inspection model knows permission facts, but the UI and action layer do not yet expose a single permission policy for copy, modify, annotation, form mutation, and export.
- **Expected state:** Every action has a declared permission requirement, disabled or confirmation behavior, user-readable explanation, and test case.
- **Trigger:** A password-protected, locked, or permission-restricted document is opened and the user attempts copy or edit.
- **Why it matters:** A visible action that silently fails makes the app appear unreliable and can cause users to believe a restricted document was changed when it was not.
- **Technical consequence:** Permission checks can drift between UI buttons, commands, operation constructors, and provider adapters.
- **Immediate correction:** Build a permission-action matrix and enforce it in the domain action layer, not only in SwiftUI controls.
- **Proper architecture:** Typed capability policy such as `read`, `copy`, `annotate`, `modify`, `formFill`, and `export`, with denial reasons carried through to command validation and UI.
- **Acceptance criteria:** All mutation and extraction actions have explicit policy tests; denied actions never append an operation; the UI explains the denial and offers only valid recovery paths.
- **Related TODOs:** T-MAC-004, T-MAC-010.

### F-MAC-005: Durable session recovery is not established

- **Priority:** P1
- **Category:** Data safety, persistence, recovery
- **Type:** Implicit
- **Truth:** Observed absence in the inspected app surface; exact project-wide persistence coverage remains Unknown
- **Evidence:** T1 / S0 from the inspected native app files; no durable edit-session or operation-ledger recovery path was found in the reviewed surface
- **Current state:** The app model stores source bytes and operations in memory during the session. The reviewed native surface does not show autosave, crash recovery, reopen-unsaved-work, or explicit discard/restore behavior.
- **Expected state:** A user can recover staged work after an app crash, forced quit, or reopening a document, without overwriting the source.
- **Trigger:** Large edit session, app termination, document close, OS update, provider error, or export failure after several operations.
- **Why it matters:** Bounded non-destructive editing protects the source but does not protect unsaved user effort. A local-first editor needs both guarantees.
- **Technical consequence:** In-memory operations are not sufficient for crash recovery, auditability, or long-running document workflows.
- **Immediate correction:** Decide whether persistence is a sidecar session package, autosaved document package, or explicit recovery journal, and record the privacy and cleanup rules.
- **Proper architecture:** Versioned session envelope containing source digest, operation ledger, schema version, last view state, export attempts, and recovery metadata. Never store raw secrets or template values without the project-approved encrypted store boundary.
- **Acceptance criteria:** Kill-and-reopen recovery restores the exact operation ledger; source digest mismatch forces an explicit branch; discard removes only the recovery artifact; recovery UI explains what will be restored.
- **Related TODOs:** T-MAC-002, T-MAC-005, T-MAC-012.

### F-MAC-006: Undo is replay-based and mixes document and view concerns

- **Priority:** P2
- **Category:** Correctness, performance, interaction
- **Type:** Explicit
- **Truth:** Observed, with Inferred scale risk
- **Evidence:** T1 / S0 at `Sources/PDFEditorApp/AppModel.swift:426-453`
- **Current state:** Undo rebuilds from cached source and replays the remaining operations. Search, selection, rotation, candidate dismissal, and viewport state are held alongside document operations.
- **Expected state:** Document undo is deterministic and fast enough for large PDFs; view state changes do not unexpectedly disappear or get serialized as document mutations.
- **Trigger:** Undo after several text/field placements, while the document is large or the viewer is scrolled away from the edited page.
- **Why it matters:** Users expect undo to reverse the last meaningful document action without losing their place or waiting on a full reconstruction.
- **Technical consequence:** Replay cost grows with document size and operation count, while mixed state can create confusing restoration semantics.
- **Immediate correction:** Define which events are document operations, view-session events, or ephemeral presentation state.
- **Proper architecture:** Typed command ledger with inverse operations or checkpointed projections; separate document history from viewport and focus state.
- **Acceptance criteria:** Exact operation sequences produce exact outputs; undo and redo preserve intended page/focus context; large-document latency is measured and bounded; failed replay cannot leave a partially rebuilt session.
- **Related TODOs:** T-MAC-001, T-MAC-006, T-MAC-011.

### F-MAC-007: Viewer rotation mutates the live document projection

- **Priority:** P2
- **Category:** Viewer architecture, correctness
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 in `PDFKitView.updateNSView`, where page rotation is assigned on the live `PDFDocument`
- **Current state:** SwiftUI updates loop through pages and assign `document.page(at: pageNumber)?.rotation = rotation`.
- **Expected state:** Reader rotation is either an explicit, intentional document operation or a view-only transform. It must not be an accidental side effect of rendering updates.
- **Trigger:** A user changes reader rotation, selection changes, search state changes, or any SwiftUI update causes the representable to refresh.
- **Why it matters:** A reading preference should not silently alter the export projection. If rotation is an edit, it must be visible in undo, permissions, provenance, and export validation.
- **Technical consequence:** Provider inspection and viewer state can drift from source-derived geometry and operation-ledger output.
- **Immediate correction:** Choose and document view-only rotation versus exportable rotation; remove implicit mutation from generic view updates.
- **Proper architecture:** A presentation transform layer for reader rotation, or a typed `RotatePages` operation routed through the ledger with explicit UI language.
- **Acceptance criteria:** Repeated SwiftUI updates are idempotent; view-only rotation changes no export bytes; exportable rotation appears in the ledger and is independently validated.
- **Related TODOs:** T-MAC-006, T-MAC-008.

### F-MAC-008: Page navigation can fight the user's viewport

- **Priority:** P2
- **Category:** Viewer interaction, state synchronization
- **Type:** Explicit
- **Truth:** Observed, with runtime impact to verify
- **Evidence:** T1 / S0 in `PDFKitView.updateNSView`, which calls `view.go(to: page)` during updates while continuous or two-page display modes are available
- **Current state:** Viewer updates can force navigation to a page whenever SwiftUI state changes, even when the user is scrolling in a continuous document view.
- **Expected state:** Navigation occurs only for an intentional semantic page change, search result selection, or explicit go-to-page action.
- **Trigger:** Selection, search, scale, rotation, or candidate state changes while the user is scrolling.
- **Why it matters:** Scroll position is part of the user's working context. Unexpected jumps make review and placement error-prone.
- **Technical consequence:** SwiftUI state propagation and PDFKit viewport state can form a feedback loop.
- **Immediate correction:** Track the last intentionally requested page and distinguish it from the current visible page.
- **Proper architecture:** Unidirectional navigation events with a viewport observer and an idempotent target-page policy.
- **Acceptance criteria:** Non-navigation state changes preserve viewport position; selected search hits navigate exactly once; continuous and two-page modes retain intended context.
- **Related TODOs:** T-MAC-006, T-MAC-010.

### F-MAC-009: Transient highlights are inserted as PDF annotations

- **Priority:** P2
- **Category:** Viewer presentation, accessibility, performance
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 in the `PDFKitView` coordinator and transient highlight handling in `Sources/PDFEditorApp/ContentView.swift`
- **Current state:** Temporary candidate and field highlights are represented as PDF annotations, then removed and re-added during updates. They are marked nonprinting and intended not to enter the export ledger.
- **Expected state:** Presentation-only highlights remain outside the document model and do not affect PDFKit selection, accessibility trees, repaint cost, or provider state.
- **Trigger:** Candidate selection, search selection, field selection, or repeated SwiftUI updates.
- **Why it matters:** A transient UI concern should not look like a document mutation to the viewer or assistive technology.
- **Technical consequence:** Annotation lifecycle can interfere with native selection, accessibility exposure, rendering, and future annotation features.
- **Immediate correction:** Prototype a dedicated overlay view or PDFView drawing layer and compare behavior with the annotation approach.
- **Proper architecture:** Separate overlay coordinate space anchored to page transforms, with stable overlay IDs and no mutation of `PDFDocument`.
- **Acceptance criteria:** Highlights never appear in exported bytes; native text selection and VoiceOver do not announce them as document annotations; repeated updates do not accumulate or flicker overlays.
- **Related TODOs:** T-MAC-006, T-MAC-009, T-MAC-010.

### F-MAC-010: Search result identity is weaker than the visible match model

- **Priority:** P2
- **Category:** Search, correctness, accessibility
- **Type:** Implicit
- **Truth:** Observed, with runtime mismatch Inferred
- **Evidence:** T1 / S0 from `AppModel` search state and `PDFKitView` selection mapping in `Sources/PDFEditorApp/ContentView.swift`
- **Current state:** Search stores query and selected match information, but the viewer maps the selected query to the first matching selection on the page rather than a stable character range or hit identity.
- **Expected state:** Every result has a stable page index, text range, bounding geometry, and result ordinal. The selected result and visible highlight are the same occurrence.
- **Trigger:** Repeated terms on one page, next/previous result, case-insensitive search, or search after document updates.
- **Why it matters:** A user who asks for result 3 must be shown result 3, not the first occurrence of the same query.
- **Technical consequence:** PDFKit string search can lose identity across repeated text and provider-specific extraction behavior.
- **Immediate correction:** Add explicit search-hit identity and preserve it through navigation and viewer projection.
- **Proper architecture:** Provider-neutral `SearchHit` contract with source range, page geometry, extraction provenance, and stable result ID.
- **Acceptance criteria:** Repeated-text fixtures highlight the exact selected occurrence; Cmd+G and Shift-Cmd+G traverse deterministically; search announcements identify current result and total count.
- **Related TODOs:** T-MAC-006, T-MAC-009, T-MAC-010.

### F-MAC-011: Candidate inference has uncertainty, but not enough provenance for user calibration

- **Priority:** P2
- **Category:** Inference, trust, product semantics
- **Type:** Implicit
- **Truth:** Observed and Inferred
- **Evidence:** T1 / S0 from `StaticRegionDetector`, `OCR`, `PDFVectorStreamParser`, candidate presentation, and confidence-label thresholds in `ContentView`
- **Current state:** Static regions and OCR contribute candidate evidence, and the UI labels scores as High, Medium, or Low. The user-facing surface does not make the evidence source, calibration basis, abstention condition, or disagreement between providers equally visible.
- **Expected state:** A candidate is clearly a suggestion with provenance, evidence sources, confidence semantics, and a review action. The UI never implies that a heuristic score is a probability of correctness unless calibrated.
- **Trigger:** A document has short fields, columns, scanned content, rotated pages, or conflicting text/vector/OCR signals.
- **Why it matters:** Users may over-trust a “High” label and place data into the wrong region, especially in legal, financial, or identity documents.
- **Technical consequence:** Threshold changes can alter field discovery without an explicit product contract or benchmark consequence.
- **Immediate correction:** Rename or qualify confidence labels, expose provenance, and define an abstention policy.
- **Proper architecture:** Evidence graph with source type, extraction confidence, geometry confidence, candidate rationale, threshold version, and reviewed outcome.
- **Acceptance criteria:** Every candidate can explain why it exists; confidence labels are benchmark-calibrated or explicitly called heuristic scores; low-evidence cases abstain or require confirmation; corrections feed a measured review dataset.
- **Related TODOs:** T-MAC-007, T-MAC-011, T-MAC-012.

### F-MAC-012: Heuristic geometry has known recall and coordinate risks

- **Priority:** P2
- **Category:** Detection, geometry, correctness
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 at `Sources/PDFEditorCore/StaticRegionDetector.swift:357`, `PDFKitProvider.swift:345-346`, and manual placement logic in `AppModel.swift:328-339`
- **Current state:** Candidate grouping requires at least three adjacent boxes, text line bounds are synthesized from page text with approximate line height and x/y values, and manual placement uses fixed minimum dimensions rather than crop-box-aware constraints.
- **Expected state:** Detection policy is tied to evidence and document geometry, while manual placement remains inside the page's actual usable bounds.
- **Trigger:** One- or two-cell fields, columns, unusual line spacing, rotated or vertical text, small pages, or nonstandard crop boxes.
- **Why it matters:** The app can miss legitimate fields or place an overlay outside the visible/exported page.
- **Technical consequence:** Heuristic thresholds and synthetic geometry leak into selection, candidate confidence, and export correctness.
- **Immediate correction:** Add positive and negative fixtures for short groups, columns, rotations, vertical text, ligatures, and small pages before changing thresholds.
- **Proper architecture:** Provider-neutral geometry with explicit coordinate space, page box, rotation, confidence, and evidence source; placement clamped to crop/media bounds with a policy-defined minimum.
- **Acceptance criteria:** Fixture-level recall and precision are recorded; candidate rejection is explainable; manual placement stays inside the selected page box for every supported page size and rotation.
- **Related TODOs:** T-MAC-007, T-MAC-011.

### F-MAC-013: Export validation conflates warnings with failure and uses fragile matching

- **Priority:** P2
- **Category:** Export, validation, user recovery
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 at `Sources/PDFEditorCore/PDFKitProvider.swift:581-607`, `624-653`, and `663-671`
- **Current state:** Overlay validation reopens output and compares annotations or rendered regions using bounds/content. Any validation message makes status failed, so advisory warnings are not distinct from blockers.
- **Expected state:** Validation explains whether output is valid, valid with warnings, or blocked, and each message has a recovery action.
- **Trigger:** Font/rendering drift, provider-specific annotation normalization, small coordinate tolerances, rotated pages, or a valid export with a non-fatal advisory.
- **Why it matters:** False blockers erode trust and make users retry blindly; false passes can compromise the product's preservation promise.
- **Technical consequence:** Validation criteria are coupled to renderer details without stable operation identity or tolerance policy.
- **Immediate correction:** Define validation severity, tolerance buckets, operation IDs, and deterministic export settings.
- **Proper architecture:** Structured `ValidationResult` with `passed`, `passedWithWarnings`, and `failed`, each finding linked to an operation, page, region, source digest, and next action.
- **Acceptance criteria:** A known advisory does not block export; a true unauthorized outside-region mutation blocks export; all outcomes are reproducible and rendered in user-readable language.
- **Related TODOs:** T-MAC-008, T-MAC-011, T-MAC-012.

### F-MAC-014: Template lifecycle failures lack a user recovery path

- **Priority:** P2
- **Category:** Templates, lifecycle, recovery
- **Type:** Explicit
- **Truth:** Observed
- **Evidence:** T1 / S0 at `Sources/PDFEditorCore/TemplateRuntimeContracts.swift:573-582`
- **Current state:** Non-active template lifecycle revisions are rejected as unsupported.
- **Expected state:** Draft, active, stale, archived, and revoked states have deliberate preview, migration, or fail-closed behavior.
- **Trigger:** A saved template revision changes, is revoked, becomes stale, or is opened after a schema migration.
- **Why it matters:** A user needs to know whether to review, migrate, use a prior revision, or stop. “Unsupported” does not explain the safe next step.
- **Technical consequence:** Lifecycle state is technically represented but not translated into an actionable product state.
- **Immediate correction:** Define lifecycle policy and recovery copy before native template review UI expands.
- **Proper architecture:** Revision resolver returns typed lifecycle outcome, migration requirements, provenance, and allowed operations.
- **Acceptance criteria:** Each lifecycle state has unit and UI behavior; revoked data cannot silently materialize operations; stale templates offer explicit review or migration.
- **Related TODOs:** T-MAC-007, T-MAC-012.

### F-MAC-015: Native accessibility and keyboard interaction are not established

- **Priority:** P1
- **Category:** Accessibility, interaction, macOS design
- **Type:** Explicit plus implicit
- **Truth:** Observed absence of a native proof lane; runtime defect status Unknown
- **Evidence:** T1 / S0 from `ContentView.swift` and the inspected test inventory. Existing accessibility coverage is primarily web-oriented in `Tests/web_accessibility_gate_test.mjs`.
- **Current state:** Manual placement is mouse-driven, direct edit is double-click-driven, candidate and field overlays have no demonstrated native accessibility labels or focus model, and native VoiceOver/reduced-motion tests were not found in the inspected surface.
- **Expected state:** All primary actions are keyboard reachable, candidates and fields are navigable and announced, focus is restored after dialogs, and reduced motion is respected.
- **Trigger:** VoiceOver use, full keyboard access, no-mouse editing, modal open/close, search navigation, or reduced-motion preference.
- **Why it matters:** Accessibility is part of the Mac product contract, not a later visual polish pass. Mouse-only placement also limits pro-user throughput.
- **Technical consequence:** PDFKit's internal accessibility tree, SwiftUI controls, transient overlays, and custom AppKit hit-testing may disagree.
- **Immediate correction:** Create a native interaction and accessibility matrix before designing more custom controls.
- **Proper architecture:** Native controls and accessible overlay elements with explicit labels, traits, actions, focus order, keyboard commands, and motion policy.
- **Acceptance criteria:** A keyboard-only workflow can open, navigate, find, select, place, undo, validate, and export; VoiceOver announces current page, candidate rationale, selected result, validation severity, and dialog recovery; reduced motion removes nonessential animation.
- **Related TODOs:** T-MAC-009, T-MAC-010.

### F-MAC-016: Test evidence is asymmetric between web/contracts and native interaction

- **Priority:** P1
- **Category:** Test strategy, release evidence
- **Type:** Implicit
- **Truth:** Observed from inspected test inventory
- **Evidence:** T1 / S0. Existing tests cover web accessibility, template security and matching, contract parity, independent preservation, PDF fixtures, and browser workflows. The inspected native surface does not include equivalent command, window, permission, viewer, VoiceOver, or recovery tests.
- **Current state:** The strongest proof is concentrated in the web and headless/provider lanes.
- **Expected state:** The native shell has a small deterministic test matrix for the behaviors that only AppKit/SwiftUI can prove.
- **Trigger:** Release claim, provider change, macOS SDK update, scene lifecycle change, or native UI refactor.
- **Why it matters:** A passing web contract cannot prove a native menu item is discoverable, a window is isolated, or a PDFKit overlay is accessible.
- **Technical consequence:** Regressions can pass all current gates while breaking the primary native product.
- **Immediate correction:** Define native evidence tiers and a minimum S3 smoke lane.
- **Proper architecture:** Layered tests: core contracts, provider fixtures, native unit tests, native UI tests, and manually observed accessibility/recovery evidence, each with separate claims.
- **Acceptance criteria:** Release evidence names the exact lane and sensitivity; two-window, command, permission, undo, search, export recovery, and accessibility workflows are repeatable and retained.
- **Related TODOs:** T-MAC-009, T-MAC-010, T-MAC-012.

### F-MAC-017: Toolbar and Settings information architecture is not yet intentional for a pro document tool

- **Priority:** P3
- **Category:** Product IA, macOS design
- **Type:** Explicit plus implicit
- **Truth:** Observed
- **Evidence:** T1 / S0 in the toolbar and `SettingsView` in `Sources/PDFEditorApp/ContentView.swift`
- **Current state:** The toolbar contains file actions, editing actions, reader mode, scale, and status. Settings is largely descriptive, showing local processing and provider statements rather than user-controllable preferences.
- **Expected state:** The toolbar exposes a small set of high-frequency actions; menus and secondary surfaces carry advanced commands; Settings contains actual durable preferences or is reframed as a safety/about surface.
- **Trigger:** Small windows, toolbar customization, keyboard-only use, or a user looking for default reader/export/privacy behavior.
- **Why it matters:** Overloaded toolbars reduce hierarchy and make the app feel like a prototype. A Settings window that cannot change settings creates a false expectation.
- **Technical consequence:** Product behavior, preferences, and explanatory policy are mixed in one surface.
- **Immediate correction:** Classify each control as primary, secondary, status, preference, or explanation and move it accordingly.
- **Proper architecture:** Standard macOS toolbar groups, menu commands, inspectors, and a real Settings model for durable user choices.
- **Acceptance criteria:** Toolbar remains useful at compact width; every secondary action has a discoverable menu or inspector path; Settings labels accurately describe whether a value is configurable.
- **Related TODOs:** T-MAC-003, T-MAC-009.

### F-MAC-018: Unsafe external links need an explicit action policy

- **Priority:** P3
- **Category:** Security UX, trust
- **Type:** Explicit UI condition with unresolved implementation detail
- **Truth:** Observed presentation; action enforcement Unknown
- **Evidence:** T1 / S0 from the link presentation in `ContentView.swift`; the inspected UI shows a warning state but still routes the action through `model.openLink(link)`
- **Current state:** Unsafe links are visually marked, but it is not established from the review whether the action is disabled, confirmed, or safely ignored at the model boundary.
- **Expected state:** Unsafe external links are blocked or require an explicit, explained confirmation; safe links use the system browser action.
- **Trigger:** A document contains an external URL classified as unsafe or untrusted.
- **Why it matters:** A warning icon beside an active-looking control can be interpreted as permission to proceed.
- **Technical consequence:** Security policy may be visual-only unless enforced in the model/provider boundary.
- **Immediate correction:** Verify and document the action policy, then align button state and model guard.
- **Proper architecture:** Typed external-link verdict with safe-open, blocked, and confirm-required states.
- **Acceptance criteria:** No unsafe link opens silently; the UI explains why it is blocked or what confirmation means; policy tests cover malformed and external URLs.
- **Related TODOs:** T-MAC-004, T-MAC-012.

### F-MAC-019: Product boundary and recovery language need to be visible at the moment of risk

- **Priority:** P3
- **Category:** Product semantics, trust, recovery UX
- **Type:** Implicit
- **Truth:** Inferred from current UI and architecture
- **Evidence:** T1 / S0 from the welcome, export, status, and settings surfaces in `ContentView.swift`
- **Current state:** The UI communicates bounded PDFs and local processing, but it does not yet consistently explain native widgets versus overlays, what export validation guarantees, what happens after a denied permission, or how to recover from a failed export or stale template.
- **Expected state:** The app teaches the user the safe operating boundary exactly where a decision is made.
- **Trigger:** First open, detected candidates, restricted documents, direct editing, template mismatch, export warning, or export failure.
- **Why it matters:** A technically honest architecture can still produce unsafe user interpretation if the boundary is only documented elsewhere.
- **Technical consequence:** Users may treat suggestions as fields, warnings as failures, or a successful save as proof of universal PDF fidelity.
- **Immediate correction:** Map each high-risk action to concise boundary copy and a recovery action.
- **Proper architecture:** Shared product-state vocabulary used by inspection, operation review, validation, export, and help documentation.
- **Acceptance criteria:** A user can answer “what will change,” “what will not change,” “why was this blocked,” and “what can I do next” from the current surface without reading developer documentation.
- **Related TODOs:** T-MAC-008, T-MAC-012.

## 6. Explicit findings versus implicit findings

### Explicit findings already visible in code or project artifacts

- Incomplete scene command replacement and toolbar-only access for several primary actions.
- One app-level model passed into `WindowGroup`.
- Copy action exposed without the confirmed `canCopy` gate.
- Approximate text bounds and hard-coded candidate grouping threshold.
- Non-active template lifecycle revisions returned as unsupported.
- Replay-based undo.
- Live PDF page rotation mutation in viewer updates.
- Repeated `go(to:)` navigation during representable updates.
- Temporary UI highlights implemented as PDF annotations.
- Export validation messages collapsed into failure.
- Static Settings and overloaded toolbar.

### Implicit findings that must become explicit product or architecture decisions

- The canonical relationship between source bytes, live viewer state, and export projection.
- Whether reader rotation is a preference or a document operation.
- Whether an app is a single-document viewer, a document editor, or a library plus editor. The current behavior points to a document editor and should be designed accordingly.
- Whether sessions must survive crashes and document close. For a long-lived document tool, the recommended answer is yes.
- Whether heuristic confidence is calibrated probability, rank score, or evidence strength. The recommended answer is evidence strength unless calibration is demonstrated.
- Whether candidate corrections are merely local edits or become a reviewed dataset for future matching. The recommended answer is a measured review dataset with privacy controls.
- Whether a warning blocks export, permits export with an audit note, or requires user confirmation.
- Whether native PDFKit is the product provider or only the first adapter. Existing provider evidence supports adapter status, not final clearance.
- Whether native accessibility is a release gate. The recommended answer is yes.

## 7. Long-term first-principles TODO list

The TODOs below are intentionally sequenced. Do not start with visual polish or a second provider while the canonical state and recovery contracts remain unresolved.

### Wave 0: Freeze the evidence and decision boundary

- [ ] **T-MAC-000 / P1 / prerequisite:** Add a native evidence index that names each claim, truth status, evidence tier, sensitivity, source path, and next proof. Include the existing web and provider evidence without promoting it to native proof.
  - Depends on: none.
  - Acceptance: Every P1 finding in this document has one current owner, one evidence gap, and one next artifact.
- [ ] **T-MAC-000A / P1 / prerequisite:** Record a document-archetype decision: document-based editor, library plus editor, or utility. Recommended decision: document-based editor with bounded overlay/form operations and multiple independent windows.
  - Depends on: T-MAC-000.
  - Acceptance: The decision controls scene lifecycle, commands, Settings, recent documents, save semantics, and window tests.
- [ ] **T-MAC-000B / P2 / research:** Preserve the current PDFKit public AcroForm radio-choice loss and Form 6 raster delta as provider admission constraints. Do not normalize these failures away.
  - Depends on: none.
  - Acceptance: Future provider work must state which failure it addresses and which independent evidence proves the improvement.

### Wave 1: Establish the canonical document/session architecture

- [ ] **T-MAC-001 / P1 / architecture:** Introduce explicit `DocumentSession` ownership with immutable source artifact, derived inspection, operation ledger, view session, and export projection.
  - Depends on: T-MAC-000, T-MAC-000A.
  - Acceptance: A state ownership table exists in code documentation and no view-only property is required to export.
- [ ] **T-MAC-002 / P1 / architecture:** Make document identity and window identity explicit using source digest plus session UUID; move document model ownership to the scene/window boundary.
  - Depends on: T-MAC-001.
  - Acceptance: Two windows can open different documents and preserve independent operations, search, selection, undo, permissions, and export targets.
- [ ] **T-MAC-003 / P1 / architecture:** Define the document lifecycle contract for New, Open, Close, Save/Export, Duplicate, Revert/Discard, recent documents, and unsaved changes.
  - Depends on: T-MAC-001, T-MAC-002.
  - Acceptance: Every lifecycle transition has a source-preservation rule, dirty-state rule, confirmation rule, and recovery path.
- [ ] **T-MAC-004 / P1 / safety:** Define and enforce the permission-action matrix at the domain boundary for copy, modify, annotations, native forms, overlays, and export.
  - Depends on: T-MAC-001.
  - Acceptance: UI controls, menu commands, and operation constructors all derive from the same capability policy.
- [ ] **T-MAC-005 / P1 / recovery:** Design and implement a versioned local recovery envelope for source digest, operation ledger, schema version, and safe view restoration.
  - Depends on: T-MAC-001, T-MAC-003.
  - Acceptance: Crash/relaunch, source mismatch, discard, and cleanup scenarios are documented and tested without overwriting the source PDF.

### Wave 2: Make the application a good Mac citizen

- [ ] **T-MAC-006 / P1 / commands:** Build the command inventory and route it through standard SwiftUI/AppKit command groups.
  - Depends on: T-MAC-002, T-MAC-003, T-MAC-004.
  - Acceptance: Menu and shortcut coverage exists for document, edit, view, search, navigation, window, and help actions with dynamic enablement.
- [ ] **T-MAC-007 / P2 / interaction:** Define reader rotation, zoom, page navigation, and display mode as view state or typed document operations, then implement only the chosen semantics.
  - Depends on: T-MAC-001, T-MAC-003.
  - Acceptance: Viewer refreshes are idempotent; scroll position is preserved across non-navigation updates; export behavior is explicit.
- [ ] **T-MAC-008 / P2 / validation:** Replace fragile validation status with structured pass, pass-with-warnings, and fail results, each linked to operation identity and recovery action.
  - Depends on: T-MAC-001, T-MAC-004.
  - Acceptance: Known renderer advisories do not become unexplained hard failures; unauthorized outside-region changes remain blockers.
- [ ] **T-MAC-009 / P2 / viewer:** Move transient candidate, field, and search highlights out of the PDF document model into a dedicated overlay layer.
  - Depends on: T-MAC-001, T-MAC-007.
  - Acceptance: No transient annotation enters export bytes, native selection remains stable, and overlay identity survives viewer updates.
- [ ] **T-MAC-010 / P2 / search:** Add stable `SearchHit` identity, exact range/geometry mapping, and deterministic next/previous navigation.
  - Depends on: T-MAC-001, T-MAC-006, T-MAC-009.
  - Acceptance: Repeated-text and rotated-page fixtures show the selected occurrence, not merely the first query match.

### Wave 3: Make inference honest, useful, and measurable

- [ ] **T-MAC-011 / P2 / inference:** Define candidate provenance and confidence semantics across text bounds, vector parsing, OCR, grouping, and manual placement.
  - Depends on: T-MAC-001.
  - Acceptance: Each candidate carries evidence source, geometry confidence, score version, rationale, and abstention state.
- [ ] **T-MAC-011A / P2 / detection:** Expand fixtures for one- and two-cell groups, columns, unusual line spacing, rotated/vertical text, ligatures, scanned pages, and small crop boxes.
  - Depends on: T-MAC-011.
  - Acceptance: Precision/recall and hard-negative behavior are recorded before threshold changes are accepted.
- [ ] **T-MAC-011B / P2 / placement:** Make manual placement crop-box-aware and keyboard reachable, with explicit page/coordinate conversion.
  - Depends on: T-MAC-007, T-MAC-009, T-MAC-011.
  - Acceptance: Placement remains inside the selected page box for supported page sizes, rotations, and display modes.
- [ ] **T-MAC-012 / P2 / lifecycle:** Define template lifecycle outcomes and user recovery for draft, active, stale, archived, and revoked revisions.
  - Depends on: T-MAC-001, T-MAC-011.
  - Acceptance: Lifecycle state is never reduced to a generic unsupported error when a safe review or migration action exists.

### Wave 4: Native accessibility and proof

- [ ] **T-MAC-013 / P1 / accessibility:** Create a native accessibility matrix covering labels, traits, focus order, VoiceOver announcements, keyboard commands, dialogs, overlays, search, validation, and Settings.
  - Depends on: T-MAC-006, T-MAC-009, T-MAC-010.
  - Acceptance: The matrix maps every primary workflow to an observable native behavior and an evidence artifact.
- [ ] **T-MAC-014 / P1 / native tests:** Add native UI or AppKit-level tests for two-window isolation, menu enablement, permission denial, undo/redo, search identity, export failure recovery, and overlay non-persistence.
  - Depends on: T-MAC-002, T-MAC-004, T-MAC-008, T-MAC-010.
  - Acceptance: Tests run against representative PDF fixtures and state their sensitivity as S2 or S3 rather than being counted as core-only proof.
- [ ] **T-MAC-015 / P1 / accessibility proof:** Capture an observed VoiceOver and full-keyboard workflow on the supported macOS baseline, including reduced motion.
  - Depends on: T-MAC-013, T-MAC-014.
  - Acceptance: Evidence identifies OS version, fixture, workflow, result, and residual limitations.
- [ ] **T-MAC-016 / P2 / performance:** Measure open, inspect, candidate detection, undo, search, viewer update, and export latency across small, medium, large, scanned, and annotation-heavy PDFs.
  - Depends on: T-MAC-001, T-MAC-006, T-MAC-007.
  - Acceptance: Budgets are based on observed data; replay or projection work has a defined large-document fallback.

### Wave 5: Product surface and release hardening

- [ ] **T-MAC-017 / P3 / IA:** Reduce toolbar overload and move advanced actions into standard menus, inspectors, or contextual surfaces.
  - Depends on: T-MAC-006, T-MAC-013.
  - Acceptance: Compact and expanded toolbar states preserve primary actions and status clarity.
- [ ] **T-MAC-018 / P3 / Settings:** Decide which Settings values are durable user preferences and split explanatory safety policy from configurable preferences.
  - Depends on: T-MAC-003, T-MAC-006.
  - Acceptance: Every Settings row is either configurable, actionable, or moved to Help/About with accurate language.
- [ ] **T-MAC-019 / P3 / security UX:** Make external-link verdicts enforceable and visible as safe-open, confirm-required, or blocked.
  - Depends on: T-MAC-004.
  - Acceptance: No unsafe link opens silently and malformed URL cases have deterministic behavior.
- [ ] **T-MAC-020 / P2 / provider gate:** Only after native core and proof waves, evaluate a second provider against the preserved AcroForm, Form 6, rotation, encrypted, malformed, scanned, and large-document corpus.
  - Depends on: T-MAC-000B, T-MAC-008, T-MAC-014, T-MAC-016.
  - Acceptance: Provider selection records capability, fidelity, licensing, packaging, performance, security, and rollback evidence.

## 8. Research and exploration queue

These are experiments, not implementation commitments:

- Compare a dedicated PDF overlay layer with transient PDF annotations for selection, repaint, accessibility, and export isolation.
- Measure PDFKit page rotation as a view transform versus a serialized operation and record the user-visible contract for each.
- Build a two-window native harness before changing scene ownership, so the failing or passing behavior is captured rather than inferred.
- Benchmark replay-based undo against checkpointed projections on large and annotation-heavy fixtures.
- Test exact search-hit geometry for repeated text, ligatures, columns, and rotated pages.
- Calibrate candidate score labels against reviewed fixtures, or replace probability-like labels with evidence-strength language.
- Exercise permission-restricted PDFs for copy, annotation, form mutation, overlay mutation, and export.
- Evaluate template lifecycle migration and revocation with no raw template values in logs or recovery artifacts.
- Compare native VoiceOver output for PDFKit text, SwiftUI controls, and custom overlays.
- Re-evaluate a second provider only after the native source-of-truth and preservation contracts are stable.

## 9. Rejected or deferred paths

- **No broad rewrite now:** The current operation and contract foundations are valuable. First repair ownership, lifecycle, and proof boundaries.
- **No automatic conversion of every detected region into a native form field:** Detection remains probabilistic and must stay review-gated.
- **No second PDF provider as a reflexive fix:** Provider comparison is justified by preserved failure cases and must pass licensing, packaging, corpus, and fidelity gates.
- **No custom toolbar or decorative glass layer as the first design move:** Standard macOS commands, controls, and focus behavior are higher-leverage and lower-risk.
- **No claim that web accessibility or contract parity proves native accessibility:** Those are separate evidence lanes.
- **No confidence label that implies calibrated probability without calibration data.
- **No export-success claim based only on reopenability:** Reopen, source preservation, outside-region comparison, and user-facing validation severity remain separate claims.

## 10. Open questions requiring a product decision

- Is the canonical product a bounded PDF completion editor, a general document editor, or a library plus editor? This review recommends bounded completion editor first, with the document-based Mac lifecycle.
- Should reader rotation ever change exported output? This review recommends view-only rotation by default unless the user invokes an explicit document command.
- What is the supported minimum macOS version for native accessibility and PDFKit behavior?
- What is the user-facing recovery policy when a source digest changes while a recovery session exists?
- Should Settings control default reader mode, zoom, export destination, validation verbosity, and recovery retention?
- Which warnings are advisory, which require confirmation, and which block export?
- What privacy policy governs retention of reviewed candidate corrections and session envelopes?
- What evidence is sufficient to promote PDFKit from first adapter to default provider?

## 11. Completeness statement

### Reviewed

- Native app entry point, scene commands, toolbar, settings, document model ownership, PDFKit view projection, search, manual placement, undo, export path, permission summary, candidate detection, OCR/vector contracts, template lifecycle, and the inspected Swift and JavaScript test inventory.
- Existing project audits, implementation plan, evidence reports, and research findings sufficient to avoid duplicating the provider and preservation ledger.
- The macOS app design skill checklist: standard menu bar, keyboard access, multi-window behavior, sidebar/editor composition, toolbar grouping, accessibility labels, full keyboard access, and reduced motion.

### Not established by this pass

- Native runtime behavior on a live macOS window, VoiceOver output, full-keyboard interaction, reduced-motion behavior, or two-window behavior.
- Exact project-wide persistence coverage outside the inspected native app surface.
- Performance budgets for large documents.
- Whether `openLink` enforces the warning state at the model boundary.
- Final provider choice or licensing clearance for any alternative engine.

### Evidence ceiling

This pass is primarily `T1 / S0`, informed by existing `T2` and selected `T3` artifacts. It does not create `T4` native workflow proof or `T5` field evidence. The TODO sequence is complete as a planning ledger only when each task records its own implementation and evidence status.

### Closure rule

This review should be considered closed only when the P1 tasks have either passed their acceptance criteria or have a documented, user-approved decision to defer them. A task marked “implemented,” a queued agent, a passing core test, or a web proof artifact alone is not closure for the corresponding native claim.

## 12. Implementation wave status

This section records the implementation work completed after the original review and the remaining work identified by the final static integration review. It supersedes the earlier TODO status for the items listed here, but it does not convert static evidence into runtime proof.

### Statically closed or materially implemented

- [x] `T-MAC-001` Canonical session boundaries are represented through source identity, operation-ledger identity, projection revision, view state, metadata recovery, and value-bearing payload recovery.
- [x] `T-MAC-002` AppModel ownership moved to the per-window scene boundary and commands resolve the focused scene model.
- [x] `T-MAC-003` The product now communicates an export-only lifecycle: source PDFs are not overwritten, `Export Copy` produces separate output, and close choices explicitly keep or discard recovery.
- [x] `T-MAC-004` Permission checks are enforced in AppModel action methods and are mirrored across the native controls and command enablement for the main extraction, OCR, form, annotation, overlay, mark, synthesis, and export paths.
- [x] `T-MAC-005` Two-plane recovery is active in the AppModel path: metadata envelope, generation-specific value-bearing payload, and pair manifest.
- [x] `T-MAC-006` Standard Mac commands route through typed AppModel APIs for document, edit, search, navigation, zoom, scale, reader mode, Settings, and window actions.
- [x] `T-MAC-007` Reader rotation is view-only; the live document remains in source coordinates and the PDFKit presentation copy applies rotation.
- [x] `T-MAC-009` Candidate, field, and search highlights are presentation-only overlays with viewport invalidation hooks and native accessibility descriptions.
- [x] `T-MAC-010` Search identity carries page-local range data; the viewer supports exact, approximate, unavailable, and no-selection projection states.
- [x] `T-MAC-011` Recovery payload and metadata identities use deterministic source, operation, candidate-status, view-state, generation, and pair-manifest bindings.
- [x] `T-MAC-012` Template and recovery-related failure states are surfaced through explicit status and diagnostics paths where the current UI has a corresponding surface.
- [x] `T-MAC-013` Native controls now expose keyboard, accessibility, permission, selection, and recovery-state semantics in the inspected source.
- [x] `T-MAC-014` Native command and window routing code now has explicit seams for later UI evidence; runtime native tests remain pending.
- [x] `T-MAC-019` External and export-related safety copy is more explicit about local source preservation and export-only behavior.

### P0 items

- [x] `P0-R1` Recovery replay is staged and committed only after isolated replay succeeds. Failure leaves the active operation ledger, inspection, view state, history, and live document unchanged.
- [x] `P0-R2` Recovery writes use generation-specific payload and pair files, with the metadata envelope as the reader-visible commit pointer. This is statically closed as a generation-bound commit protocol, not as an OS-level atomic transaction.

### Remaining implementation TODOs

- [ ] `P1-L1` Align every Open entry point, including toolbar and welcome flows, with the non-destructive `Continue to Open` lifecycle language. No path should say “Discard” when it preserves the current document.
- [ ] `P1-L2` Couple close-and-discard recovery deletion to window-close success, or expose a model-owned transactional `discardRecoveryAndClose` operation so a failed close cannot lose the document first.
- [ ] `P1-R3` Define the accepted payload integrity threat model. The pair manifest prevents accidental generation mixing, but it is not cryptographic authenticity. Decide whether authenticated encryption, Keychain-backed protection, or an explicit local-trust boundary is required.
- [ ] `P1-R4` Add retention policy for sensitive value-bearing payload generations. Keep only the active generation and a bounded number of known-good predecessors, then report orphan cleanup failures.
- [ ] `P2-R1` Document or implement migration for payload schema version 2. Distinguish unsupported historical recovery from corruption and define the behavior for legacy `.pdfedit` records.
- [ ] `P2-R2` Add an explicit `recoveryStatus` state for discovered valid recovery, rather than reporting `.none` while `recoveryRecords` is non-empty.
- [ ] `P2-R3` Deprecate or narrow the compatibility `list()` API so app-facing code cannot discard corruption diagnostics by default. `listRecoveries()` should be the required discovery path.
- [ ] `P2-R4` Keep candidate status, view state, metadata, payload, and pair generation under one authoritative recovery-generation contract without duplicated conflict-prone state.
- [ ] `P2-R5` Keep the recovery discovery panel synchronized with the authoritative recovery status enum and include clear actions for replayable, metadata-only, corrupted, and save-failed states.
- [ ] `P2-R6` Add a model-owned debounced `scheduleViewStateAutosave()` hook for selected page, reader mode, scale, zoom, rotation, and selection state without marking content dirty.

### Runtime and release evidence TODOs

- [ ] `T-MAC-020` Build the project against the supported macOS deployment target and resolve any SDK/API availability issues for focused scene values, command APIs, PDFKit copy behavior, and synthesized contract conformances.
- [ ] `T-MAC-021` Exercise two independent document windows, focused command routing, importer sheets, password sheets, close targeting, and New/Open/Close lifecycle transitions.
- [ ] `T-MAC-022` Exercise recovery interruption scenarios: payload write failure, pair write failure, metadata commit failure, process termination during replacement, orphan cleanup, source mismatch, and replay failure rollback.
- [ ] `T-MAC-023` Exercise PDFKit presentation behavior with rotated pages, native widgets, overlays, repeated search terms, ligatures, multi-page modes, scrolling, zoom, resizing, and document replacement.
- [ ] `T-MAC-024` Exercise native VoiceOver, full keyboard access, reduced motion, focus restoration, manual placement, candidate review, search projection states, and permission explanations.
- [ ] `T-MAC-025` Measure large-document open, projection rebuild, undo/redo, recovery autosave, recovery replay, overlay redraw, and export validation performance.
- [ ] `T-MAC-026` Decide and document whether the value-bearing payload plane requires encryption or Keychain-backed protection. Filesystem mode `0700`/`0600` is local access control, not encryption.

### Final implementation posture

The native app is substantially implemented through the P0 foundation and the primary P1 interaction and recovery seams. It is not yet release-complete because the remaining work is now concentrated in lifecycle edge semantics, sensitive payload retention and threat-model policy, recovery-state authority cleanup, view-state autosave, and T2-T4 build/runtime/accessibility evidence.

The current evidence ceiling remains `T1` static implementation review. The correct next move is an explicitly authorized validation pass, not a stronger completion claim based on agent reports or source inspection alone.

## 13. Final static cleanup pass

The following cleanup items were completed after the previous status update:

- [x] Added `currentViewStateDigest()` so coalesced view-state autosave uses the same privacy-safe digest as the metadata envelope, payload, and pair manifest.
- [x] Added authoritative `RecoveryStatus.available` handling throughout the recovery panel. Valid discovered recovery is no longer represented as `.none`.
- [x] Added readable recovery status titles, explanations, accessibility values, and status-specific visual treatment for available, restored, metadata-only, corrupted, and save-failed recovery.
- [x] Aligned toolbar, welcome, and menu Open language around non-destructive `Continue to Open` behavior.
- [x] Added bounded payload and pair-generation retention, preserving the active generation and one known-good predecessor after successful commit.
- [x] Added explicit payload schema quarantine for unsupported historical and future schemas instead of guessed migration or unsafe replay.
- [x] Deprecated the lossy recovery `list()` compatibility projection in favor of `listRecoveries()` with corruption diagnostics.
- [x] Added model-owned coalesced view-state autosave for navigation, search, reader mode, scale, zoom, rotation, and selection transitions.

### Remaining source-level decisions

- [ ] Add a model-owned transactional close/discard operation so recovery deletion cannot happen before the target window close is admitted.
- [ ] Decide whether the sensitive value-bearing payload plane requires authenticated encryption or an explicit local-trust threat model. `0700`/`0600` filesystem permissions are not encryption.
- [ ] Decide whether the generation commit-pointer protocol is sufficient for the product's durability claim or whether a stronger OS-level package/transaction boundary is required.

### Remaining evidence gates

- [ ] Build the package against the supported macOS deployment target.
- [ ] Run native two-window, importer, password-sheet, Cmd-F, close-keep, close-discard, permission, recovery-panel, and search-projection workflows.
- [ ] Exercise crash interruption between payload, pair manifest, and metadata envelope writes.
- [ ] Exercise PDFKit copy, rotated-page projection, overlays, repeated search ranges, scrolling, zoom, display modes, and document replacement.
- [ ] Exercise VoiceOver, full keyboard access, reduced motion, focus restoration, and manual placement.
- [ ] Measure recovery autosave, presentation-copy rebuild, undo/redo, and export performance on large PDFs.

The implementation is now materially complete at the source-architecture level for the primary review findings. It remains `NOT RELEASE VERIFIED` until the evidence gates above are executed and the payload threat-model decision is recorded.
## 14. Reconciliation wave and current evidence, 2026-08-25

### 14.1 Current source repairs

- Reconciled the shared checkout without reverting the current editor-mode, signature, redaction, viewer, or recovery work.
- Added a model-owned `commitRedactions()` action. It records no destructive operation when the provider has no measured permanent-redaction capability; it returns an explicit structured denial instead of presenting visual marks, flattening, or generic export as permanent redaction.
- Completed the close transaction boundary. `Close and Discard Recovery` waits for the exact window's `NSWindow.willCloseNotification` before resetting the model. A rejected close leaves the document and recovery state untouched.
- Corrected the close observer's strict-concurrency boundary. The AppKit notification callback is nonisolated and `@Sendable`, then explicitly hops to `MainActor`.
- Repaired bounded single-line web overlay writing in `web/app.js`. Text is measured with the embedded font, fitted to the authorized operation rectangle, preflighted before any draw, and rejected before export below the supported minimum size. Explicit multiline operations retain multiline behavior.
- Aligned the governed encrypted-reader digest in `Tests/fixtures/pdf_corpus_governance_manifest.json` with the stable artifact digest already enforced by `Tests/provenance_contract_test.mjs`.

### 14.2 Current validation evidence

Observed or verified on 2026-08-25:

- `swift build -c debug`: passed.
- `swift build -c debug --target PDFEditorApp -Xswiftc -strict-concurrency=complete`: passed.
- `swift test`: passed, 97 tests across 12 suites.
- `swift build -c release`: passed with no compiler diagnostics.
- `node Tests/provenance_contract_test.mjs`: passed, 14 assets verified.
- `node Tests/pdf_contract_parity_test.mjs`: passed, 18 fixtures inspected by the native PDFKit harness. The generated parity report records 26 known native/web semantic mismatches and 16 preflight-presence mismatches; those are reported differences, not silently accepted as parity.
- `PDF_PROOF_BASE_URL=http://127.0.0.1:4175/web/index.html node Tests/web_pdf_proof_playwright_test.mjs`: passed. Native-field proof and bounded-overlay proof both passed source digest, reopen, geometry, applied-operation, outside-region text, visual diff, and provider capability checks. Outside-region pixels were 0 for both exports.
- `PDF_PROOF_BASE_URL=http://127.0.0.1:4178/web/index.html node Tests/web_accessibility_gate_test.mjs`: passed. Landmarks, skip-link focus, keyboard text-layer access, password dialog, and error-free runtime passed.
- `PDF_EDITOR_BASE_URL=http://127.0.0.1:4177/web/index.html node Tests/web_editor_workflow_test.mjs`: passed. Candidate highlight, apply, edit, undo, dismiss/restore, and manual placement passed.
- `PDF_PROOF_BASE_URL=http://127.0.0.1:4180/web/index.html node Tests/web_pdf_contract_fixture_test.mjs`: passed. The 18-fixture corpus emitted explicit checkbox evidence and completed contract export validation.
- `PDF_EDITOR_PREVIEW_URL=http://127.0.0.1:4173/web/ node Tests/pdf_independent_preservation_test.mjs`: passed. Unauthorized text and raster mutation were rejected; authorized text, raster, and reopen checks passed; rotated fixtures preserved 90 and 90/180 degree rotations.
- `node Tests/web_reader_contract_test.mjs`: passed, 51 checks.

Non-fatal runtime warnings observed during browser evidence include PDF.js font/operator warnings and the existing `TT: undefined function: 32` warning. No browser console errors or page errors were reported by the proof and accessibility gates.

### 14.3 Remaining TODOs and evidence ceiling

- Native UI runtime evidence remains required for actual AppKit multi-window behavior, Cmd-W and native close-button behavior, rejected-close rollback, Cmd-F focus routing, PDFKit overlay projection after in-place revision changes, VoiceOver traversal, and reduced-motion behavior. Command-line compilation and PDFKit harness evidence do not prove those interactions.
- Recovery crash-interruption evidence remains required. The metadata envelope, sensitive payload, pair manifest, generation retention, schema quarantine, and source-digest binding are implemented, but an interrupted native process must still be observed to prove that the previous commit pointer remains readable.
- Sensitive payload encryption is closed in Section 15: AES-GCM with a stable Keychain-backed key, identity-bound associated data, quarantine on failure, and no plaintext fallback. The remaining evidence gap is controlled crash interruption, not the encryption design.
- Permanent redaction remains intentionally unavailable until a provider exposes a measured `redaction.permanent` capability and a validated `applyRedaction` implementation. The UI now states that limitation explicitly and fails closed.
- The native/web parity report continues to expose semantic differences in native field choice encodings, accessibility reading-order claims, candidate sets, encrypted security metadata, and page geometry precision. Each difference remains a review item; parity is not claimed merely because the harness exits successfully.
- Historical generated evidence reports retain their original digests. They are not rewritten to conceal the encrypted-fixture refresh; the governance manifest and executable provenance contract are the current anchors.

### 14.4 Current completion status

The implementation and command-line/browser validation waves are complete. The overall macOS design goal remains open because native UI runtime proof, recovery interruption proof, and the payload-encryption policy decision are not yet verified or resolved. No `Complete` claim should be made until those evidence and policy items are closed.
## 15. Recovery payload encryption closure, 2026-08-25

- Added `RecoveryPayloadKeyStore.swift` with a stable Keychain-backed 256-bit key for sensitive recovery payloads.
- Updated `SessionPayloadStore.swift` to use AES-GCM authenticated encryption for new value-bearing payload records.
- Associated data authenticates session identity, autosave generation, source digest, encrypted format version, and payload schema version.
- Keychain failure, authentication failure, or malformed encrypted records fail closed and quarantine the record. There is no plaintext fallback and no regenerated replacement key.
- Existing plaintext payload schema is intentionally unsupported and quarantined rather than migrated unsafely.
- Payload file permissions, generation retention, source binding, deletion, and quarantine cleanup remain in force.
- Current direct validation: `swift build -c debug`, strict `PDFEditorApp` build, `swift test` with 102 tests across 12 suites, and `swift build -c release` all passed after this change.

The remaining completion ceiling is now limited to runtime observation and provider capability rather than an unresolved local payload-security design:

- Real native AppKit window, menu, focus, VoiceOver, reduced-motion, and close-interruption observation is still not available from the current raw SwiftPM executable session. AppleScript found the process but no discoverable window, so no native UI claim is made.
- Crash-interruption recovery durability still needs a controlled process-kill/relaunch experiment to prove the previous commit pointer remains readable under interruption.
- Permanent redaction remains fail-closed until a provider exposes measured `redaction.permanent` capability and validated destructive implementation. This is an explicit capability boundary, not an accidental no-op.
## 16. Current controlled interruption proof and remaining native ceiling (2026-08-25)

### Verified implementation closure

- `Sources/PDFEditorRecovery/RecoveryInterruptionTestSupport.swift` and `Sources/PDFRecoveryInterruptionHarness/main.swift` now provide a test-only subprocess seam. It is inert unless the explicit interruption environment is present, emits phase labels only, and blocks only after a successful store write.
- `Tests/PDFEditorAppRecoveryTests/RecoveryCrashInterruptionTests.swift` now proves the real `AppModel` recovery path across payload, pair-manifest, and metadata-envelope interruption boundaries. The child is terminated with `SIGKILL`; the parent reopens the source with fresh model state and asserts only value-minimized generation, envelope, operation-count, and status outcomes.
- The payload and pair stores use generation-specific immutable filenames. A failed prepare cannot overwrite the last committed generation. The metadata envelope remains the commit pointer.
- Recovery payloads remain AES-GCM authenticated and Keychain-backed in production. The interruption harness injects a deterministic test-only 256-bit key so crash-boundary evidence does not depend on a live Keychain transaction; encryption and Keychain behavior remain covered separately.
- Recovery identity hashing now uses one explicit ISO-8601 canonical encoder for operation, metadata, and payload identities. This closes the date-precision mismatch that previously made a valid persisted operation ledger fail after decrypt/decode.

### Current evidence

- Verified: `swift test` passed 106 tests across 13 suites on 2026-08-25.
- Verified: payload interruption during an update preserved generation 1 and replayed 1 operation.
- Verified: pair-manifest interruption during an update preserved generation 1 and replayed 1 operation.
- Verified: metadata-envelope interruption during an update made generation 2 authoritative and replayed 2 operations.
- Verified: first-save interruption before the metadata commit left no discoverable recovery; interruption after the metadata commit made generation 1 with 1 operation authoritative.
- Verified: the prior recovery false negative was a real canonical identity defect, not a test-only artifact; the persisted date representation and digest representation are now aligned.

### Remaining TODO and evidence boundary

- `Unknown`: native AppKit runtime proof remains outstanding for a packaged `.app`, visible document window, standard menu bar, menu command routing, and accessibility tree. The raw SwiftPM executable is not sufficient evidence for these claims.
- `Unknown`: controlled application termination evidence remains outstanding. The current source has recovery autosave paths and view-state debounce, but no independently observed `applicationShouldTerminate` or scene teardown flush proof.
- `Proposed`: package the release executable in an isolated temporary `.app`, launch it without a document, then launch/open a public fixture and capture window, menu, and accessibility observations. Record failures as scoped runtime limitations rather than converting source or test evidence into runtime claims.
- `Proposed`: add a native termination harness only after the packaged runtime is observable, using the same generation-specific recovery contract and a controlled termination signal rather than a browser or raw executable proxy.

## 17. Packaged native runtime probe (2026-08-25)

- Verified: `swift build -c release --product PDFEditor` completed successfully.
- Observed: a temporary `.app` wrapper around the release executable launched as a native macOS process from `/tmp/PDFEditorRuntimeProbe-923364DB-7F04-438B-81CE-3F266017B99F.app`.
- Observed: System Events reported zero windows for the exact packaged process after launch.
- Observed: the menu-bar query did not return a usable menu-bar surface, and opening `benchmark/results/public-sample-form.pdf` did not produce a visible accessible document window in the bounded probe.
- Status: native window, standard-menu, command-routing, and accessibility claims remain `Unknown`. The probe is evidence that the raw executable can be launched through a temporary bundle, not evidence that the product is usable as a native app.
- TODO: inspect `PDFEditorApp.swift` scene/window lifecycle and add a packaged-runtime launch path that intentionally creates an observable document window before repeating menu and accessibility capture.
- TODO: add independently observed termination flushing after a usable native window exists. Do not treat the current raw process or temporary probe as release evidence.

## 18. Native shell hardening closure wave (2026-08-25)

### Implemented

- `AppModel()` no longer performs synchronous template/profile vault health and Keychain enumeration during native window construction. Vault state is lazy and explicit; the window can appear before optional encrypted-vault diagnostics.
- `AppModel.flushRecoveryForTermination()` cancels pending view-state debounce work and synchronously commits dirty or pending recovery state. It returns failure rather than allowing the caller to claim durable recovery when the write did not complete.
- `PDFEditorAppDelegate.applicationShouldTerminate` now calls the flush for every registered window controller and returns `.terminateCancel` if any model cannot commit recovery.
- Window controllers register weakly, retain their focused model reference, and route Finder/open-document URL events to the focused document model.
- The window has an explicit default size and the existing coalesced view-state autosave is now wired to page selection, field/candidate selection, search state, reader mode, scale mode, zoom, and rotation changes.
- Core toolbar and welcome actions have explicit accessibility labels and hints rather than relying on implicit system-image label inference.

### Current authoritative evidence

- Verified: `swift test` passed 112 tests across 15 suites on 2026-08-25.
- Verified: `RecoveryTerminationFlushTests` passed. A pending edit was flushed synchronously and replayed from fresh model state as generation 1 with one operation.
- Verified: `RecoveryCrashInterruptionTests` passed all payload, pair, metadata, and first-save boundary cases.
- Verified: `swift build -c debug --target PDFEditorApp -Xswiftc -strict-concurrency=complete` passed.
- Verified: isolated release product build passed with `swift build -c release --product PDFEditor` using a separate scratch path because another worker was mutating the shared SwiftPM cache.
- Verified: the current release binary, packaged in `/tmp/PDFEditorReleaseProbe-8248E8B5-F94E-4353-B795-846714123EAF.app`, created one frontmost `AXWindow` with `AXStandardWindow` subrole and title `PDF Editor`.
- Verified: System Events observed the release menu bar as `Apple, PDF Editor Release Probe, File, Edit, View, Window, Help`.
- Verified: the release File menu exposed `New Document`, `Open...`, `Close Window`, `Close`, `Close All`, and `Export Copy...`.

### Remaining scoped evidence

- `Verified at shell level, Unknown end to end`: the termination flush method and AppKit termination delegate compile and pass the model-level transaction test, but a real dirty native window has not yet been quit through the AppKit menu while an external observer verifies the resulting recovery generation.
- `Partial`: the native window and menu accessibility tree is observed. Direct `System Events` button-name enumeration still returns missing values for some SwiftUI-rendered controls, so full control-level accessibility naming remains unproven even though source labels and hints are explicit.
- `TODO`: add a controlled packaged-app termination probe that creates one known local edit, activates the standard Quit command, observes the delegate flush result, and reopens the resulting recovery state without printing payload values.
- `TODO`: add a native accessibility capture that asserts explicit labels for toolbar, welcome, reader-mode, editor-mode, field, candidate, search, and recovery controls through the actual AX tree rather than source-level modifiers alone.
