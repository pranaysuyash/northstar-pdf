# Council Review: Floating Glass Islands UI Design & Implementation Plan

**Date:** 2026-09-24  
**Governing Skill:** `council-orchestrator` (`OPERATING_DOCTRINE.md` v8.1 / `REVIEW_DOCTRINE`)  
**Target:** Visual Specimen `docs/visual_specimens/toolbar_islands_before_after_specimen.html` & Implementation Plan (`MAD-I6` / Pillar 2)  
**Lead:** **PER-0755 Principal Product Designer**  

---

## 1. Council Manifest & Seat Coverage

| Seat ID | Role | Focus Lens | Mandate in this Review |
|---|---|---|---|
| **PER-0755** *(Lead)* | **Principal Product Designer** | Design Craft & Visual System | Evaluates spatial balance, material hierarchy, typography, and whether the 2004 utility syndrome is solved. |
| **PER-1228** | **Workspace UX Architect** | Workspace Topology & Layout | Evaluates spatial layering, multi-window split behavior, and page occlusion edge cases. |
| **PER-0796** | **A11y & Inclusive Design Specialist**| Accessibility & VoiceOver | Evaluates WCAG contrast, `.reduceTransparency` fallbacks, VoiceOver traversal order, and hit targets. |
| **PER-PDEV-0162**| **macOS Native & SwiftUI Architect**| Implementation & Performance | Evaluates native AppKit/SwiftUI integration, `.principal` titlebar placement, window dragging, and 120fps scrolling. |
| **PER-0749** | **UX Researcher for Expert Tools** | Ergonomics & Operator Speed | Evaluates operator muscle memory, mode mapping (`Read`/`Review`/`Audit`), and accidental click traps. |

---

## 2. Seat Findings & Critical Cross-Examination

### Seat 1: PER-0755 (Lead, Principal Product Designer)
- **Verdict: Strongly Approved with Craft Hardening.**
- **Visual Assessment:** The transformation from the monolithic 13-element gray toolbar to floating glass islands completely alters the product’s perceived era. It turns a cluttered 2004 utility into an elevated, calm workspace.
- **Craft Hardening Directives:**
  1. *Hairline Borders:* Use `Color.white.opacity(0.18)` in Dark Mode, and `Color.black.opacity(0.12)` in Light Mode, rendered with `.strokeBorder(lineWidth: 0.5)` to mimic native macOS Sequoia Liquid Glass styling.
  2. *Accent Glow:* The `⌘K Ask Northstar` button must have a subtle ambient cyan/blue backlight glow (`rgba(10, 132, 255, 0.25)`) to serve as the signature visual beacon of the interface.

### Seat 2: PER-1228 (Workspace UX Architect)
- **Critical Risk Discovered: Bottom Page Occlusion.**
  - *The Defect:* The floating bottom island (`Page 1 of 4 | - 100% + | ↔ ↻`) hovers over the bottom of the canvas. If a PDF has signatures, footnotes, or legal disclaimers at the bottom of the page, the island will occlude the text when scrolled to the end.
  - *Mandatory Architectural Fix:* The underlying `DocumentCanvasView` scrollview MUST configure an automatic content bottom inset (`bottomInset: 72pt`). This guarantees that when the user reaches the end of the document, the page can scroll completely past the island with generous breathing room.
- **Window Collapse Rule:** When the window width is resized below 780pt, Island 1 (Mode Switcher) must collapse mode labels to icons-only (`Read` $\rightarrow$ Book icon, `Review` $\rightarrow$ Pencil icon, `Audit` $\rightarrow$ Shield icon) to prevent horizontal collision with the traffic lights or Export dock.

### Seat 3: PER-0796 (Accessibility & Inclusive Design Specialist)
- **A11y Substrate Requirements (`MAD-008` Compliance):**
  1. *Reduce Transparency:* When `accessibilityReduceTransparency` is active in macOS System Settings, the islands must NOT use translucent materials. They must seamlessly fall back to an opaque solid background: `Color(nsColor: .windowBackgroundColor)` with standard separator borders.
  2. *Reduce Motion:* Island expansion and mode indicator transitions must bypass spring animations when `accessibilityReduceMotion` is enabled, using instantaneous state snaps.
  3. *VoiceOver Reading Order:* Do not let floating ZStack order confuse assistive technology. The VoiceOver traversal order must remain logical: Titlebar / Mode Switcher $\rightarrow$ Document Page Canvas $\rightarrow$ Canvas Stepper $\rightarrow$ Inspector.
  4. *Hit Target Sizing:* Ensure all circular buttons in the bottom island have a minimum interactive tap frame of `32x32pt` (with `28x28pt` visible bounds).

### Seat 4: PER-PDEV-0162 (macOS Native & SwiftUI Architect)
- **Native SwiftUI Architecture Discovery:**
  - *Avoid Pure Custom Drag Overlays:* If the top island is rendered purely as a floating `ZStack` over a borderless window, standard macOS window dragging from the titlebar becomes awkward and buggy.
  - *The Idiomatic Solution:*
    - **Island 1 (Mode + HUD):** Place inside `ToolbarItem(placement: .principal)`. SwiftUI and AppKit automatically center `.principal` items in the window titlebar and preserve native macOS window dragging across empty titlebar regions!
    - **Island 2 (Action Dock):** Place inside `ToolbarItemGroup(placement: .primaryAction)`. This positions the Undo/Redo and Verified Export button docked right, exactly where Mac users expect.
    - **Island 3 (Bottom Stepper):** Implement as an `.overlay(alignment: .bottom)` directly on `DocumentCanvasView`, equipped with a `.padding(.bottom, 16)` constraint.
  - *Rendering Performance:* Isolate island state so that typing in the canvas or zooming does not invalidate or re-render the entire window chrome. Keep islands in dedicated standalone views: `NavigationIslandView`, `ModeSelectorIslandView`, and `ActionIslandView`.

### Seat 5: PER-0749 (UX Researcher for Expert Tools)
- **Ergonomics & Mental Model Mapping:**
  - *Mode Simplification:* The current app has 4 modes: `Read`, `Fill`, `Sign`, `Edit`. The new design streamlines these into 3: **Read**, **Review**, and **Audit**.
  - *Operator Clarity:*
    - `Read`: Skim mode, continuous scroll, text selection.
    - `Review`: Combines AcroForm `Fill`, `Sign` stamps, and candidate overlay placements.
    - `Audit`: Focuses on cryptographic signature verification, PII redactions, and diff validation.
  - *Recommendation:* When the user switches to `Review`, the right inspector automatically highlights form filling and signing tiles. No capability is lost; the mental model is simply organized by operator intent rather than granular tools.

---

## 3. Reconciled Architectural Implementation Plan

### Step 1: Component Extraction (`Sources/PDFEditorApp/`)
1. Create `ModeSelectorIslandView.swift`:
   - Contains 3-segment switcher (`Read`, `Review`, `Audit`) and `Ask Northstar` (`⌘K`) HUD trigger.
   - Implements `.reduceTransparency` solid background fallback.
2. Create `ActionIslandView.swift`:
   - Contains `Undo`, `Redo`, and high-visibility `Verified Export` pill button with progress indicator.
3. Create `NavigationIslandView.swift`:
   - Contains thumbnail rail toggle, `Page X of Y` badge, `- 100% +` zoom stepper, Fit Width (`↔`), and rotate (`↻`).
   - Floats anchored to the bottom-center of the canvas.

### Step 2: Canvas Scroll Inset Adjustment
- In `DocumentCanvasView.swift`, inject `72pt` of bottom content inset to prevent page content from ever being occluded by `NavigationIslandView`.

### Step 3: ContentView Refactoring
- Replace the 366-line legacy `appToolbar` builder in `ContentView.swift` with clean calls to the new island components mapped to `.principal` and `.primaryAction`.

---

## 4. Council Decision & Actionable Verdict

**Unanimous Council Recommendation: APPROVED for Implementation.**

The design specimen [`toolbar_islands_before_after_specimen.html`](file:///Users/pranay/Projects/pdf_editor/docs/visual_specimens/toolbar_islands_before_after_specimen.html) is ratified with the following three mandatory inclusions in the code implementation:
1. **Titlebar Integration:** Island 1 and Island 2 will be mounted via native SwiftUI `.principal` and `.primaryAction` toolbar placements to preserve macOS window dragging and titlebar ergonomics.
2. **Bottom Inset Protection:** `DocumentCanvasView` will enforce a `72pt` bottom scroll inset so the bottom island never occludes document content.
3. **Accessibility Substrate:** Full `.accessibilityReduceTransparency` and `.accessibilityReduceMotion` fallbacks will be included on Day 1.
