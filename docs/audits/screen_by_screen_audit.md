# Northstar (PDF Editor) — Screen-by-Screen Visual & Functional Audit

**Date:** September 7, 2026  
**Target Application:** `Northstar.app` (`com.northstar.pdf`, packaged from `/Users/pranay/Projects/pdf_editor/dist/Northstar.app`)  
**Evidence Directory:** `docs/simulations/evidence/screen-audit-2026-09-07/`  
**Artifact Directory Mirror:** `screenshots/`  

---

## Executive Summary

As requested, we launched the native macOS application simulation in live graphical mode and captured screen-by-screen, feature-by-feature high-resolution window screenshots across all primary surfaces, inspector tabs, contextual panels, and secondary modal sheets. Every interface element was systematically exercised via native macOS Accessibility (`AXUIElement`) automation and AppleScript to evaluate layout integrity, visual hierarchy, user ergonomics, accessibility compliance, and runtime behavior before making any code modifications.

This comprehensive audit catalogs **17 interface states**, identifying several critical visual glitches, layout regressions, accessibility label leaks, and window lifecycle anomalies.

---

## 1. Screen-by-Screen Interface Evidence

### 1.1 First-Run Welcome Surface (Start Workspace)
**Asset:** `01_welcome_empty_state.png`  
![First Run Welcome Surface](screenshots/01_welcome_empty_state.png)

- **Purpose & Scope:** The launchpad for new sessions when no document is open. Presents product branding ("A calmer place for PDFs — Open, understand, and shape a document without losing sight of the original"), primary CTA buttons ("Open a PDF...", "New blank · Letter ⌵"), a prominent drag-and-drop target zone ("Drop a PDF anywhere in this window"), quick-creation cards (Images, Clipboard, Markdown), and recent document history ("Continue where you left off").
- **Visual Observations:** Clean, airy aesthetic adhering to macOS Human Interface Guidelines. Fluid continuous-corner geometry with subtle accent-color tinting (`Color.accentColor.opacity(0.045)`).
- **Verified Behaviors:** Drag-and-drop highlights correctly on target; keyboard shortcuts and recent item jump targets resolve accurately.

---

### 1.2 Main Document View — Complete Inspector Tab
**Asset:** `02_document_complete_inspector.png`  
![Main Document Complete Inspector](screenshots/02_document_complete_inspector.png)

- **Purpose & Scope:** The core reading and editing workspace displaying document canvas, page thumbnail rail, floating bottom zoom/rotation HUD, and contextual inspector sidebar (`Complete` tab).
- **Visual Observations:**
  - **Critical Layout Bug (Defect #1):** In `ContextualInspectorView.swift`, the segmented picker `Picker("Inspector Section", selection: $selectedTab)` lacks `.labelsHidden()`. The label text `"Inspector Section"` wraps into an unsightly vertical column (`In / sp / ec / to / r / Se / ct / i / on`) on the left of the tabs (`Complete | Understand | Organize | Reader | Review`), compressing tab widths.
  - Page navigation rail correctly renders single-page thumbnail badge with character count, field count, and suggestion count.
  - Evidence rail prominently anchors trust indicators (`Source`, `Provider`, `Confidence`, and limitations).
  - Authoring tools row (`Add Text`, `Sign`, `OCR Page`) and Profile Autofill card are easily accessible.

---

### 1.3 Recovery Session Notification Banner
**Asset:** `03_recovery_banner_expanded.png`  
![Recovery Banner Expanded](screenshots/03_recovery_banner_expanded.png)

- **Purpose & Scope:** Appears when crash-recovery or auto-save records exist in the local snapshot store (`PDFEditorRecovery`).
- **Visual Observations:** Persistent orange status indicator displaying `"Recovery session available — 3 local record(s)"`. Right-hand controls allow inspecting recovery details (`chevron.down`) or discarding session records (`trash`).
- **Verified Behaviors:** Non-destructive preservation guarantee; does not overwrite original PDF bytes.

---

### 1.4 Contextual Inspector — Understand Tab
**Asset:** `04_inspector_understand.png`  
![Inspector Understand Tab](screenshots/04_inspector_understand.png)

- **Purpose & Scope:** Document intelligence and semantic extraction workspace.
- **Visual Observations:** Displays "Document Analysis — Extract key points, entities, and form fields using local on-device heuristics or companion LLM." Presents an "Analyze Document" CTA button and empty state illustration when analysis has not yet been triggered.

---

### 1.5 Contextual Inspector — Organize Tab
**Asset:** `05_inspector_organize.png`  
![Inspector Organize Tab](screenshots/05_inspector_organize.png)

- **Purpose & Scope:** Study loop, annotations organizer, and active recall deck.
- **Visual Observations:** Displays "Study Your Marks — Active recall and flashcards generated from your highlights and annotation marks." Explains requirement for at least one annotation mark before study cards can be synthesized.

---

### 1.6 Contextual Inspector — Reader Tab (Capability Passport)
**Asset:** `06_inspector_reader.png`  
![Inspector Reader Tab](screenshots/06_inspector_reader.png)

- **Purpose & Scope:** Security boundary and document rights inspection surface.
- **Visual Observations:** Displays the "Capability Passport (LOCAL)" card, cryptographic SHA-256 digest, access level permissions (Text Search: Granted, Annotations: Granted, Modifications: Granted, Form Fill: Granted), and active reader configuration.

---

### 1.7 Contextual Inspector — Review Tab (Local Privacy & Provenance)
**Asset:** `07_inspector_review.png`  
![Inspector Review Tab](screenshots/07_inspector_review.png)

- **Purpose & Scope:** Hardware security, privacy provenance, preflight hygiene, and link to vault.
- **Visual Observations:** Prominently highlights "Local Privacy & Provenance — Zero network egress · Hardware isolated stores". Details source preflight findings (18 findings, 0 meta, 0 embeds, 0 unsafe external URLs, unencrypted). Provides quick action button to "Open Security & Privacy Vault...".

---

### 1.8 Security & Privacy Vault — Overview & Health
**Asset:** `08_security_vault_sheet.png`  
![Security Vault Overview](screenshots/08_security_vault_sheet.png)

- **Purpose & Scope:** Comprehensive security posture sheet for local keys, redaction templates, and hardware integrity.
- **Visual Observations:** Clean modal header with Secure Enclave badge, tabbed navigation (`Overview & Health`, `Profiles & Keys`, `Templates`, `Audit Trail`), biometric status ("Secure Enclave: Available"), and Done dismissal button.

---

### 1.9 Security & Privacy Vault — Profiles & Keys
**Asset:** `09_security_vault_profiles.png`  
![Security Vault Profiles](screenshots/09_security_vault_profiles.png)

- **Purpose & Scope:** Local credential manager, cryptographic identity keys, and autofill persona profiles.
- **Visual Observations:** Displays master vault status, key management policies, and autofill credential storage options with hardware-backed encryption.

---

### 1.10 Security & Privacy Vault — Templates
**Asset:** `10_security_vault_templates.png`  
![Security Vault Templates](screenshots/10_security_vault_templates.png)

- **Purpose & Scope:** Data redaction and sanitization rule presets (e.g. SSN, PII, financial info, medical identifiers).
- **Visual Observations:** Structured table of redaction patterns with active toggle switches for zero-leak sanitization export pipelines.

---

### 1.11 Security & Privacy Vault — Audit Trail
**Asset:** `11_security_vault_audit_trail.png`  
![Security Vault Audit Trail](screenshots/11_security_vault_audit_trail.png)

- **Purpose & Scope:** Immutable forensic log of all document modifications, export operations, and cryptographic signatures.
- **Visual Observations:** Chronological timestamped event ledger with provenance SHA-256 hashes and tamper-evident signatures.

---

### 1.12 Agent Command Palette (Command HUD)
**Asset:** `12_agent_command_hud.png`  
![Agent Command HUD](screenshots/12_agent_command_hud.png)

- **Purpose & Scope:** Keyboard-centric rapid action palette (`⌘K`).
- **Visual Observations:** Centered spotlight HUD with search field ("Type a command or ask a question..."), grouped actions (Fill, Annotate, Export, Navigate), keyboard shortcut hints, and intent classification.

---

### 1.13 Visual Diff Sheet (Original vs. Filled)
**Asset:** `13_visual_diff_sheet.png`  
![Visual Diff Sheet](screenshots/13_visual_diff_sheet.png)

- **Purpose & Scope:** Side-by-side or split slider comparison between the untouched original PDF and modified buffer before export (`⌘⌥D`).
- **Visual Observations:** Clean split preview with difference highlighting overlay, zoom sync, and explicit change summary badges.

---

### 1.14 Document Browser & Tagging Sheet
**Asset:** `14_document_browser_sheet.png`  
![Document Browser Sheet](screenshots/14_document_browser_sheet.png)

- **Purpose & Scope:** Corpus-level document library manager with tag categorization, duplicate detection, and batch selection.
- **Visual Observations:**
  - **Critical Sizing & Overlap Bug (Defect #2):** When presented via `.sheet(isPresented: $isDocumentBrowserPresented)`, `DocumentBrowserView` lacks an explicit `.frame(minWidth: ..., minHeight: ...)` and dismiss button. It renders into a compressed dialog (~400x120pt) where the `.searchable` search field directly overlaps document titles and sidebar tags.

---

### 1.15 Version History & Revert Sheet
**Asset:** `15_version_history_sheet.png`  
![Version History Sheet](screenshots/15_version_history_sheet.png)

- **Purpose & Scope:** Allows timeline rollback, checkpoint browsing, and version branching for sidecar annotations.
- **Visual Observations:** Shares the same sheet presentation hierarchy as Document Browser and exhibits identical constraint shrinkage if presented without a document version store populated.

---

### 1.16 Structured Signing Flow Sheet (CommitFlowSheet)
**Asset:** `16_sign_flow_sheet.png`  
![Structured Sign Flow Sheet](screenshots/16_sign_flow_sheet.png)

- **Purpose & Scope:** Legally-grounded document signing flow.
- **Visual Observations:**
  - Displays document identity card ("What you're signing", Document name, Page count, File size, SHA-256 hash).
  - Document Integrity check ("Document has no existing signatures. Safe to sign.").
  - Identity input fields ("Your name (required for audit record)", "Reason for signing").
  - Signature capture canvas with segmented modes (`Draw`, `Type`, `Image`), clear button, and "Use signature" action.
  - Proper "Cancel" button in header dismissing back to editing.

---

### 1.17 External Open & Multi-Page Navigation Fixture
**Asset:** `17_multipage_navigation_fixture.png`  
![External Open Fixture](screenshots/17_multipage_navigation_fixture.png)

- **Purpose & Scope:** Verification of external document opening (`open -a Northstar <path>`) and window reuse semantics.
- **Visual Observations:** Confirms the existence of **GAP-B** (Duplicate Window bug). Opening an external document while Northstar is running opens a new window (`WindowID 23520`) rather than seamlessly adopting the existing scratch/welcome window or routing into the focused window.

---

## 2. Comprehensive Defect & Improvement Catalog

| # | Severity | Component / File | Issue Description | Root Cause | Proposed Fix |
|---|---|---|---|---|---|
| **1** | **High (Visual)** | `ContextualInspectorView.swift` | **Segmented Picker Label Bug:** The text `"Inspector Section"` wraps into a vertical single-letter column to the left of the tabs, breaking horizontal alignment and truncating tab titles. | `Picker("Inspector Section", selection: $selectedTab)` lacks `.labelsHidden()` in SwiftUI on macOS. | Add `.labelsHidden()` to the picker in `ContextualInspectorView`. |
| **2** | **High (UI/UX)** | `DocumentBrowserView.swift` | **Modal Sizing & Overlap Bug:** Sheet collapses into an unusable 400x120 box with search field overlapping items; no dismiss button. | View lacks `.frame(minWidth: 800, minHeight: 500)` and `@Environment(\.dismiss)` navigation toolbar. | Add standard window frame constraints, title, and a "Done" button in `.toolbar`. |
| **3** | **Medium (Architecture)** | `PDFEditorApp.swift` | **External Open Duplicate Window (GAP-B):** Calling `open <file>` spawns a secondary window instead of reusing the initial scratch window. | `PDFEditorExternalOpenRouter` does not synchronously claim the existing key window before SwiftUI's default `WindowGroup` instantiates a second scene. | Enforce single-window reuse in `PDFEditorExternalOpenRouter` and close empty scratch windows immediately upon external open. |
| **4** | **Medium (Accessibility)** | `ContentView.swift` | **Accessibility Label Leak (GAP-E):** Fill mode button in the editor toolbar announces raw SF symbol name `"pencil.and.list.clipboard"`. | Picker or button item does not provide explicit `.accessibilityLabel("Fill form fields")`. | Add explicit `.accessibilityLabel("Fill")` and descriptive hint to the editor mode selector. |
| **5** | **Low (UX/Ergonomics)** | `ContentView.swift` | **Toolbar Overflow Menu Clutter:** Secondary items like `Workspace` and `Export` overflow into a generic `>>` menu on standard 1280x820 displays. | Toolbar item placement uses default priorities without `.secondaryAction` consolidation. | Group tools logically and specify `.help` / compact representations so primary actions remain directly visible. |
| **6** | **Low (Diagnostics)** | `AppModel.swift` | **Memory Pressure Cleared Warning (GAP-C):** Rapid scans or inspector switches trigger a yellow warning banner `"Memory pressure: cleared non-essential caches"`. | Cache evacuation threshold is tuned conservatively for large corpus runs. | Adjust cache budget thresholds and add a debounce to thumbnail generation. |

---

## 3. Next Steps & Recommended Path

With all 17 interface screens captured, verified, and cataloged, we have a clear, evidence-based baseline. We can now proceed to implement fixes in a clean, isolated sequence:
1. Fix the `ContextualInspectorView` segmented picker label bug (`.labelsHidden()`).
2. Fix `DocumentBrowserView` and `VersionCompareView` frame constraints and add dismiss buttons.
3. Fix the Accessibility label leak on the Fill mode button.
4. Improve window routing in `PDFEditorExternalOpenRouter` to eliminate duplicate window spawning.
5. Re-run simulations to capture updated "After" screenshots confirming resolution.
