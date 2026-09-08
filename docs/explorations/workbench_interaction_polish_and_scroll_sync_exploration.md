# Exploration & Architectural Doctrine: Workbench Interaction Polish, Drop Ingestion & Bidirectional Scroll Sync

> **Status:** Canonical Exploration & Implementation Blueprint  
> **Topic:** Canvas-to-Sidebar Scroll Synchronization, In-Document Drop Disambiguation, Form Interaction Fluidity, and Distraction-Free Recovery  
> **Date:** September 2026  
> **Target Subsystems:** `DocumentCanvasView`, `PageThumbnailRailView`, `ContentView`, `AppModel`  

---

## 1. Problem Space & First-Principles Deconstruction

### Friction 1: Canvas-to-Sidebar Scroll Desynchronization (The "Ghost Rail" Bug)
* **Symptom:** In continuous reading mode, scrolling through multi-page documents (e.g. Form-6, 2-page voter registration) moves the canvas through pages 1 and 2, but the left filmstrip rail remains statically locked to Page 1.
* **Root Cause Diagnosis:**
  1. `PDFKitView.Coordinator` installs an observer for `Notification.Name.PDFViewPageChanged`.
  2. When the user scrolls past a page boundary, `PDFKit` fires this notification.
  3. The coordinator receives it, calculates the new `pageIndex`, and updates internal pre-rendering caches (`renderingPipeline?.updateReadingPosition`).
  4. **The Critical Omission:** The coordinator never mutates `model.selectedPageIndex` or triggers any callback to SwiftUI. `model.selectedPageIndex` remains 0.
  5. Furthermore, `PageThumbnailRailView` wraps its items in a raw `ScrollView` without a `ScrollViewReader` or `.id(page.pageIndex)` tags, meaning even if `selectedPageIndex` changed, the scroll view had no programmatic hook to follow the viewport.
* **First-Principles Solution:**
  - Establish a single bidirectional synchronization protocol:
    $$\text{Canvas Scroll Viewport Page} \longleftrightarrow \text{model.selectedPageIndex} \longleftrightarrow \text{Sidebar ScrollViewReader Anchor}$$
  - Guard against cyclic feedback loops using a debounce / change guard (`if model.selectedPageIndex != newPageIndex`).

---

### Friction 2: In-Document Multi-Document Drag-and-Drop Handling
* **Symptom:** Dropping a file onto an open document results in a dead canvas cursor ($\oslash$).
* **Architecture:** Wire `.onDrop(of: [UTType.pdf.identifier], ...)` onto the active document canvas container in `ContentView.swift`.
* **Behavior Matrix:**
  1. If current document is **dirty** (unsaved edits/annotations): Display glass Disambiguation HUD:
     - "Open in New Window" (Non-destructive / Default)
     - "Compare Side-by-Side" (Visual Diff against current state)
     - "Append Pages to Current Document" (`insertPages`)
     - "Save & Switch"
  2. If current document is **clean**: Default to non-destructive prompt or switch with option key override.

---

### Friction 3: Form-Filling Interaction Polish (AcroForm & Candidates)
* **Symptom:** Clicking fields enters Fill mode, but navigating between candidates and native AcroForm fields requires repetitive mouse targeting.
* **Enhancements:**
  1. **Keyboard Tab Order:** `Tab` and `Shift+Tab` smoothly advance `model.tabCursorIndex` through available fields/candidates on the current page.
  2. **Active Field Highlighting:** Give the focused field a distinctive macOS native selection ring with subtle pulse animation, distinguishing it from passive detected boxes.
  3. **Instant Value Injection:** Direct typing when a candidate/field is focused immediately routes into inline text or checkbox toggle.

---

### Friction 4: Persistent Recovery Banner & Session State
* **Symptom:** The green/amber "Recovery session available / restored" banner at the top of the canvas takes up valuable vertical screen real estate once acknowledged.
* **First-Principles UX:**
  - Make the banner dismissible via a clean close button (`xmark`).
  - Add auto-receding behavior: after 8 seconds of active user interaction (scrolling or field selection), smoothly transition the banner into a minimal compact badge in the status bar.

---

### Friction 5: Toolbar & Floating HUD Refinements
* **Enhancements:**
  - Unify HUD floating styles with macOS Liquid Glass / translucent ultra-thin material.
  - Elevate ⌘K into the Action Composer / Command Palette.

