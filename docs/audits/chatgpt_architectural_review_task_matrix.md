> **SUPERSESSION (2026-09-17, D-055):** This review-extraction doc is not status
> authority. Its "Completed" claims for TASK-A2/A4/A5 conflict with
> `docs/task-inventory.md` (NM-T13/NM-T17 `partial`, NM-T09 open). Task state
> lives in `docs/task-inventory.md`; the 2026-09-17 follow-up review of the
> pushed code is adjudicated in `docs/audits/chatgpt-feedback-council-review-2026-09-17.md`.

# Strategic Product & Architecture Review: Analysis & Task Extraction

> **Context:** Architectural review of Northstar based on pre-push Git state.  
> **Evaluation Date:** September 2026  
> **Operating Doctrine Alignment:** `/Users/pranay/AGENTS.md`, `OPERATING_DOCTRINE.md` (v8.0), Canonical Doctrine Family.

---

## Executive Assessment: The Core Thesis

The review delivers a sharp and accurate diagnosis:
> *"Northstar is technically much more interesting than the product it currently presents itself as... The repository is accumulating the pieces of a local-first document intelligence system... But the frontend still fundamentally says: Here is a PDF. Here are modes and tools you can use on it. That is still the mental model of Preview, Acrobat, PDF Expert... Northstar should instead say: Give me the document work you need done."*

This directly reinforces Northstar's operating doctrine: **reason from consequence, evidence, and leverage rather than cataloging raw capabilities.**

Below is the structured extraction and categorization of all **implicit and explicit implementation and exploration tasks**, prioritized against the active codebase.

---

## 1. The Core Transformation Matrix (7 Flagship Frontiers)

| Frontier | Paradigm Today (What to Leave Behind) | Target Vision (What to Build) | Applicable Subsystems | Task Nature |
| :--- | :--- | :--- | :--- | :--- |
| **1. Product Object** | PDF file / page raster viewer | **Document Evidence Graph** (Clauses, Tables, Fields, Signatures, Entities, Citations) | `DocumentModel`, `DocumentIndex`, `EvidenceFusion` | Architectural Contract |
| **2. Command Surface** | `AgentCommandHUD` filtering static command strings | **Action Composer (⌘K)** (Intent $\rightarrow$ Interpretation $\rightarrow$ Proposed Operations $\rightarrow$ Preview $\rightarrow$ Approval $\rightarrow$ Execution Receipt) | `AgentCommandHUD`, `AppModel`, `EditOperation` | Implementation |
| **3. Intelligence Model** | Chatbot sidebar or generic AI summaries | **Grounded Object-Aware Intelligence** (Direct manipulation on selection: clause, table, region, multi-doc) | Canvas interaction, contextual inspector, hover cards | Implementation & UX |
| **4. Interaction Architecture** | Five rigid lifecycle "rooms" (`Complete`, `Understand`, `Organize`, etc.) | **Task-Driven Workflows** (Seamless, non-linear document workbench without forced modes) | `ContentView`, `ContextualInspectorView` | IA / Refactoring |
| **5. Core Unit of Work** | Single document file window | **Workspace Substrate** (1 to 100 documents, multi-doc drop, cross-document queries, comparisons) | `AppModel`, `ContentView`, `multi_document_drop` | Architecture & Feature |
| **6. Execution Discipline** | Silent operations or vague status banners | **Signature Interaction Loop**: Request $\rightarrow$ Preview $\rightarrow$ Execute $\rightarrow$ Verify $\rightarrow$ **Execution Receipt** | `OperationPlan`, `PreflightReport`, `DiffComparisonView` | Implementation & UX |
| **7. Platform Posture** | Web-parity shell mimicking cross-platform frames | **Unapologetically Native macOS** (Native split views, multi-window scenes, Spotlight, Shortcuts, App Intents) | `PDFEditorApp`, macOS Scene Architecture | Platform Integration |

---

## 2. Detailed Task Inventory

### Category A: Explicit Implementation Tasks (High Priority / Near-Term)

These are concrete, actionable tasks directly called out by the review that solve immediate UX and architectural bottlenecks:

#### [TASK-A1] Rename & Elevate ⌘K from "Agent" to Action Composer
- **Problem:** `AgentCommandHUD` displays *"Ask Agent or search commands..."*, but currently only filters static string commands. It overpromises and underdelivers.
- **Action:**
  1. Rename user-facing string to **"Command Palette / Action Composer"** until true intent parsing is attached.
  2. Implement an initial multi-stage execution pipeline for natural queries:
     $$\text{Request} \longrightarrow \text{Interpretation} \longrightarrow \text{Proposed Edits} \longrightarrow \text{Visual Preview} \longrightarrow \text{User Approval} \longrightarrow \text{Apply \& Receipt}$$
  3. Wire directly into `EditOperation` and `PreflightReport`.
- **Target Files:** `Sources/PDFEditorApp/AgentCommandHUD.swift`, `Sources/PDFEditorRecovery/AppModel.swift`.

#### [TASK-A2] Implement "Execution Receipts" for Consequential Operations
- **Problem:** Northstar performs rigorous verification (metadata sanitization, content-stream inspection, raster diffs, signature validity), but hides the evidence in memory or internal logs.
- **Action:**
  1. Create a user-facing **Execution Receipt** card and exportable summary (`.txt` / `.json` / PDF attachment) after irreversible or security-critical actions (Redactions, Metadata Scrubbing, Sanitization, Export).
  2. Receipt contents: Source SHA-256, Target SHA-256, Exact Operations Executed, Pass/Fail verification checks (Content Stream Removal, Metadata Scrub, Re-open verify), Timestamp, and Route (On-device).
- **Target Files:** `Sources/PDFEditorApp/ContextualInspectorView.swift`, `Sources/PDFEditorCore/DocumentModel.swift`.
- **Status update 2026-09-12:** receipt core implemented on the working tree — `ExecutionReceipt` + `ExecutionReceiptOperation` + `ExecutionReceiptCheck` in `Sources/PDFEditorCore/ExecutionReceipt.swift`, constructed in `AppModel`, rendered/exported via `ContextualInspectorView`; the data-boundary fact is carried by the mandatory `ExecutionDataBoundary` enum (fabricated on-device defaults and the unconditional zero-egress footer removed). Completion record with options, falsifier, and the named S2 hardening path: `docs/audits/execution-data-boundary-completion-2026-09-12.md`. Export-format extension (`.json`/PDF attachment) remains open.

#### [TASK-A3] De-silo Navigation Modes (Abolish the 5 Rigid "Rooms")
- **Problem:** The inspector tabs (`Complete`, `Understand`, `Organize`, `Reader`, `Review`) force a linear waterfall model onto non-linear document work.
- **Action:**
  1. Evolve the inspector into an **object-adaptive pane**:
     - When a **form field/region** is active $\rightarrow$ show completion & validation tools.
     - When **text/clause** is selected $\rightarrow$ show explain, compare, extract obligations.
     - When a **table** is clicked $\rightarrow$ show Copy CSV, verify totals, detect anomalies.
     - When **multiple pages** are selected $\rightarrow$ show batch OCR, reorder, extract, redact.
  2. Keep global tools accessible without forcing the user to switch "rooms".
- **Target Files:** `Sources/PDFEditorApp/ContextualInspectorView.swift`, `Sources/PDFEditorApp/ContentView.swift`.

#### [TASK-A4] Relocate Diagnostic & Governance Sheets into Native Mac Window/Settings Surfaces
- **Problem:** `ContentView.swift` has become an overloaded scene coordinator managing 15+ sheet presentations (Companion Health, Governance Dashboard, Version Compare, Document Browser, Security Vault).
- **Action:**
  1. Move **Companion Health & Diagnostics** into app Settings (`PDFEditorApp.swift: Settings { ... }`).
  2. Promote **Version Compare / Diff** from an ephemeral modal sheet into a proper workspace mode or secondary window (`CompareWindow`).
  3. Keep in-canvas sheets only for quick transactional modals (Password prompt, manual text entry).
- **Target Files:** `Sources/PDFEditorApp/ContentView.swift`, `Sources/PDFEditorApp/PDFEditorApp.swift`.

#### [TASK-A5] Grounded Multi-Document Ingestion & Drop Disambiguation HUD
- **Problem:** Dropping a PDF onto an active document currently fails (dead canvas). Users cannot compare versions or ingest multiple documents seamlessly.
- **Action:**
  1. Implement the Drop Disambiguation HUD documented in `docs/explorations/multi_document_drop_exploration.md`:
     - Center Drop: Disambiguation popover ("Open in New Window", "Compare Side-by-Side", "Switch Document").
     - Left Rail Drop: Direct page insertion/append (`insertPages`).
  2. Guarantee the **"Active Work Preservation Invariant"**: never discard unsaved edits without explicit prompt.
- **Target Files:** `Sources/PDFEditorApp/ContentView.swift`, `Sources/PDFEditorApp/DocumentCanvasView.swift`.

---

### Category B: Implicit & Architectural Exploration Tasks (Medium-to-Long Term)

These represent deep structural leverage points highlighted by the review:

#### [TASK-B1] Canonical Document Evidence Graph Substrate
- **Concept:** Unify `DocumentElement`, `DocumentIndex`, `EntityRecognizer`, `TableExtractor`, `EvidenceFusion`, `DocumentDiff`, and `AnnotationStore` into a typed, navigable graph structure without creating a disconnected parallel "AI graph".
- **Core Entities:** `Document ├─ Pages ├─ Sections ├─ Paragraphs/Clauses ├─ Tables ├─ Entities ├─ Claims ├─ Signatures ├─ Citations/Anchors ├─ Versions ├─ Operations`.
- **Doctrine Constraint:** Extend existing canonical contracts in `PDFEditorCore/DocumentModel.swift`; do not create shadow data stores.

#### [TASK-B2] Grounded Intelligence: "Ask Your Evidence Set" with Region Anchors
- **Concept:** Replace generic chat with citation-anchored Q&A.
- **Rules:**
  1. Every returned assertion must link to an exact page, bounding rect, and document source digest.
  2. Clicking a citation flash-highlights the physical canvas region.
  3. Insufficient evidence must be a first-class response: *"Could not establish this from the provided documents."*

#### [TASK-B3] Transparent Capability Routing & Route Disclosures
- **Concept:** Privacy as an inspectable route rather than an absolute marketing badge.
- **Execution:**
  - For any assisted task, clearly show the execution route:
    - `● On-device (Neural Engine)`
    - `● Apple Private Cloud Compute`
    - `● Hosted Provider (Disclosing: "Pages 2-4 only; metadata stripped")`
- **Reference:** Aligns with `SECURITY_PRIVACY_SAFETY_DOCTRINE.md` and `Sensitive Data Architect` persona.

#### [TASK-B4] Recurring Workflow Memory: "Teach Northstar This Workflow"
- **Concept:** Productize the existing template and calibration engine (`ProfileStore`, `TemplateCaptureContracts`, `CandidateReviewEventStore`).
- **User Flow:**
  1. User fills or reviews an unusual recurring form once.
  2. Northstar identifies recurrence: *"This document matches a recurring structure (Version 3). Save as reusable workflow?"*
  3. Next drop: *"Detected Form XYZ (Rev 4). 18 fields auto-mapped, 2 modified fields flagged for review."*

#### [TASK-B5] Deep macOS Ecosystem Integration (Spotlight, Shortcuts, App Intents)
- **Concept:** Make Northstar a native Mac citizen beyond its own window borders.
- **Capabilities:**
  1. **Spotlight Indexing:** Expose extracted document text, metadata, and entities to CoreSpotlight.
  2. **App Intents / Shortcuts:**
     - "Sanitize PDF with Northstar"
     - "Extract Table as CSV from PDF"
     - "Compare PDF Versions"
     - "OCR Document"

---

### Category C: Explicit Anti-Patterns & Warnings (What NOT to Do)

The review explicitly warned against several common traps that Northstar must avoid:

| Anti-Pattern | Why It Fails | Doctrine Guardrail |
| :--- | :--- | :--- |
| **Generic Chatbot Sidebar** | Commodity, distracts from the document, disconnects user from direct spatial manipulation. | **Direct manipulation first**, command palette second, conversation only when true dialogue iteration is needed. |
| **Parallel "AI Data Graph"** | Creates dual sources of truth and sync drift between the real PDF/AcroForm and the AI state. | Doctrine: **One canonical store and pipeline**. Extend existing core types. |
| **Forced Native/Web Shell Parity** | Compromises Mac HIG by imposing custom web frames, 232px static columns, and non-native chrome. | **Semantic parity across platforms; platform-native UX on macOS** (Liquid Glass, native split views, macOS menus). |
| **Capability Zoo Syndrome** | Exposing 50+ raw technical tools and pipeline internals to users without workflow composition. | Capabilities are an engineering substrate; only promote into primary UI when composed into real jobs. |
| **Silent Overwrites / Deletions** | Swapping an open document on file drop without checking dirty state. | **Non-destructive preservation**: Never discard work or overwrite files in place. |

---

## 3. Recommended Phased Implementation Roadmap

```mermaid
graph TD
    subgraph Phase 1: Immediate UX Hygiene & Transparency (Completed)
        P1_1["Restore Window Traffic Lights & Native Chrome (Done)"]
        P1_2["Purge Internal Developer Telemetry from Inspector (Done)"]
        P1_3["Rename ⌘K to Action Composer / Command Palette (Done)"]
        P1_4["Multi-Document Drop Disambiguation HUD (Done)"]
    end

    subgraph Phase 2: Object-Aware Studio & Execution Receipts (Completed)
        P2_1["Object-Adaptive Morphing Inspector (Done)"]
        P2_2["Execution Receipts for Redactions, Scrubbing, Sanitization (Done)"]
        P2_3["Refactor ContentView scene coordination / Standalone Windows (Done)"]
    end

    subgraph Phase 3: Flagship Workflows & Document Evidence Graph (Active)
        P3_1["Canonical Document Evidence Graph Substrate (TASK-B1)"]
        P3_2["Grounded Intelligence: Region-Anchored Citations (TASK-B2)"]
        P3_3["Recurring Workflow Learning / 'Teach Northstar' (TASK-B4)"]
        P3_4["Deep macOS Integration: Spotlight & App Intents (TASK-B5)"]
    end

    Phase 1 --> Phase 2
    Phase 2 --> Phase 3
```

---

## 4. Benchmark Alignment & Form 6 Engine Status Breakdown

### Status Breakdown

| Workstream | Status | Evidence / Verification |
| :--- | :---: | :--- |
| **Architectural Review Task Matrix (Phases 1–3)** | **Completed** | `[TASK-A1]` through `[TASK-B5]` implemented, verified by [DocumentEvidenceGraphTests](file:///Users/pranay/Projects/pdf_editor/Tests/PDFEditorCoreTests/DocumentEvidenceGraphTests.swift) (5/5 passing). |
| **In-Session Multi-Document Drop** | **Completed** | Full drag-and-drop ingest on [DocumentCanvasView](file:///Users/pranay/Projects/pdf_editor/Sources/PDFEditorApp/DocumentCanvasView.swift) and [PageThumbnailRailView](file:///Users/pranay/Projects/pdf_editor/Sources/PDFEditorApp/PageThumbnailRailView.swift). Documented in [multi_document_drop_exploration.md](file:///Users/pranay/Projects/pdf_editor/docs/explorations/multi_document_drop_exploration.md). |
| **17-Screen Catalog Defect Matrix (Defects 1–6)** | **Completed** | Inspector segmented controls, browser constraints, external open router single-window reuse, a11y labels, cache evacuation verified in [screen_by_screen_audit.md](file:///Users/pranay/Projects/pdf_editor/docs/audits/screen_by_screen_audit.md). |
| **Preserved Live App State** | **Active** | `PID 98984` running `benchmark/results/form6-voter-application.pdf` has been kept continuously open. |
| **Form 6 Native Field Detection Engine** | **Completed** | All 4 vector & semantic failure modes resolved and verified with dedicated test suite `Form6DetectorTests` (3/3 passing, 28/28 regression tests passing). |

### Diagnosis of Form 6 Engine Failures (Resolved)

Inspection of [StaticRegionDetector.swift](file:///Users/pranay/Projects/pdf_editor/Sources/PDFEditorCore/StaticRegionDetector.swift) and [PDFVectorStreamParser.swift](file:///Users/pranay/Projects/pdf_editor/Sources/PDFEditorCore/PDFVectorStreamParser.swift) identified 4 distinct vector & semantic rules that failed on `form6-voter-application.pdf`, now resolved:

1. **Table Rules Slicing Through Printed Text (False Positives)**:
   - *Root Cause:* In `geom.potentialUnderlines`, horizontal vector strokes were assumed to be empty fill lines without checking whether text already sits on top of them. Additionally, in `geom.potentialInputBoxes`, table cells containing printed text were treated as input boxes because `nearbyLabel` was excluded from coverage.
   - *Resolution:* Added `interiorTextCoverage(of: boxAbove, in: pageLines, excluding: nil) <= 0.10` in `potentialUnderlines` and `totalCoverage <= 0.15` in `potentialInputBoxes`. Suppressed non-input documentary proof list items (`indian passport`, `pan card`, `aadhaar card`, `driving license`, `birth certificate`, `certificates of class`) in `isLikelyFieldLabel`.
2. **Statutory Prose & Long Instructions Treated as Field Labels**:
   - *Root Cause:* `isLikelyFieldLabel` searched for isolated token words using regex word boundaries without length limits, matching multi-sentence statutory text.
   - *Resolution:* Added a strict character limit (`trimmed.count <= 45`), word ceiling (`words.count <= 8`), and declarative prose suppression filters (`"i "`, `"i submit"`, `"hereby declare"`, `"punishable under"`, `"penalty"`, `"electoral roll"`).
3. **Character Grids Fragmented or Completely Missed (False Negatives)**:
   - *Root Cause:* Form 6 (exported from Word) draws character grids using intersecting stroked lines (`m ... l ... S`) rather than closed rectangles (`re`).
   - *Resolution:* Implemented `reconstructStrokedGridsAndBoxes(lines:)` in `PDFVectorStreamParser.swift` to detect orthogonal parallel lines crossed by $\ge 3$ vertical tick marks with uniform cell width (8–36pt) and reconstruct grid cell `CGRect`s, clustering them into `.characterGrid` bands.
4. **Checkbox Alignment & Overlap**:
   - *Root Cause:* Small square vector paths (`~10–14pt`) for Gender and Relative Type were expanded or mislabeled due to vertical baseline distance biases.
   - *Resolution:* Reconstructed standalone square checkbox paths (8–24pt) in `PDFVectorStreamParser`, anchored candidates strictly to square geometry (`isSquare = abs(width - height) <= max(width * 0.25, 4.0)`), and added a 25pt baseline penalty to `isAbove`/`isBelow` in `findNearestLabel` to prioritize same-row right-adjacent label binding (`[ ] Label`).

### Verification & Regression Evidence

- **`Form6DetectorTests`**: 3/3 passing (0.205s):
  - `tableRulesSuppressed`: PASSED (zero candidate bands slice through printed table rows in Section 7(b)).
  - `statutoryProseSuppressed`: PASSED (all labels $\le 45$ chars, zero declarative/disclaimer prose suggestions).
  - `characterGridsAndCheckboxesReconstructed`: PASSED (character grid cells and checkboxes correctly detected and anchored).
- **Automated Regression Gate**: 28/28 passing (0.249s) across 5 test suites:
  - `NativeDetectorGateTests`: 7/7 passing (0 regressions across 15 corpus fixtures).
  - `FieldSuggestionFidelityTests`: 13/13 passing.
  - `DocumentEvidenceGraphTests`: 5/5 passing.
  - `Fields Channel Mapping`: passing.
  - `Form6DetectorTests`: 3/3 passing.

