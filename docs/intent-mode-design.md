# Intent-Driven Editor Mode Design

**Owner:** `/Users/pranay/Projects/pdf_editor/docs/intent-mode-design.md`
**Date:** 2026-08-24
**Status:** Accepted design — implementation authorized (see D-010 in `decisions.md`)
**Relates to:** D-001, D-005, D-006, `implementation-status.md`, `feature-expansion-inventory.md`

---

## Problem

The current UI has a flat tool surface: every capability (native field editing, candidate
overlay, OCR, manual placement, undo, export) is always visible. Users must understand the
editor's internal model — "native fields vs. suggested areas vs. manual placement" — before they
can do anything. This is the right model *for the developer* but the wrong surface *for the user*.

Real users arrive with one of four concrete intentions:

1. Read a document.
2. Fill in a form or structured paperwork.
3. Sign a document.
4. Make structural edits (add text, redact, reorganize pages).

These are different jobs. They carry different risk profiles, different permission requirements,
and different visual cues on the page. Surfacing them together under one flat toolbar creates
cognitive noise that undermines the bounded-completion promise in D-001 and D-005.

---

## Proposed Solution: `EditorMode`

Introduce a typed `EditorMode` enum as a first-class model concept. The mode controls which
affordances are visible on the PDF canvas, which inspector sections are active, and what happens
when the user clicks a region of the page.

### The four modes

```
READ   Passive scroll and zoom. No overlay highlights. Zero edit affordance.
       Default on every document open (never assume intent).

FILL   All editable regions are highlighted on the canvas. Tab/Return walks
       them in reading order. Clicking one activates an inline editor.
       Fills progress is tracked and shown.

SIGN   Signature regions are highlighted. A draw/type/image sheet appears.
       The result is stamped as a reversible overlay. Date-stamp is offered.

EDIT   Full authoring palette. All EditKind operations are reachable.
       Dangerous ops (redact apply, flatten) require an explicit confirmation.
```
### Mode is not automatic

The mode is **never set without user intent**. Documents never auto-enter Fill mode.
Offer chips may appear ("This document has form fields — fill them now?"), but the user
must tap or click to enter a mode. This preserves the trust boundary from D-001 and D-004.

---

## Intent Inference (click-to-mode)

When a user clicks on a page region *while no mode is active* (i.e., `READ` mode), the app
infers what they wanted and offers a mode upgrade, rather than doing nothing or doing
something surprising.

| Click target | Inference | Affordance |
|---|---|---|
| `NativeField` rect | Wants to fill | Inline field editor appears; mode chip suggests "Fill mode" |
| `RegionCandidate` (text) | Wants to fill | Inline overlay editor appears |
| `RegionCandidate` (signature) | Wants to sign | Sign sheet opens |
| Free space | Wants to edit | Nothing (no accidental drops in Read); double-click → Edit mode |
| Toolbar mode pill | Explicit | Immediate mode switch |

**In FILL mode**, free-space clicks are blocked (no accidental text drops).  
**In EDIT mode**, single click selects, double-click starts a text cursor.  
**In SIGN mode**, only signature regions are interactive; other clicks show a tooltip.

---

## Fill Mode: Detailed Interaction Contract

### Entry conditions
- User taps mode pill → "Fill"
- User clicks an editable region from READ mode (soft entry, chip offered)
- Document has ≥1 field or active candidate when opened → status bar offer chip

### Highlight layer (on PDFKitView)
- `NativeField` rects: solid tinted border (blue/accent), badge "Field"
- Active `RegionCandidate` (unfilled): dashed orange border
- Active `RegionCandidate` (filled): solid green border
- Skipped/dismissed candidates: hidden

### Inline editor at click point
- Text fields: `FreeText` annotation overlay positioned at the region, in-place editing
- Checkboxes/radios: immediate toggle — no sheet required
- Character grids: inline with per-cell constraint validation
- Signature regions: short-circuits to Sign sheet

### Tab-order contract
1. Collect all unfilled editables: `NativeField`s first (by page, then y-desc), then active candidates (same order)
2. Tab/Return advances to next; Shift+Tab goes back
3. After last field, "All fields filled" status message; focus returns to first
4. Reading order is automatic; user reordering is deferred to v2

### Progress chip
- Status bar: "3 / 9 fields filled" — updates after each confirmed edit
- Computed from `(confirmed fields + confirmed candidates) / (total fields + active candidates)`

### Context menu on a filled region
Right-click → "Edit", "Clear", "Dismiss suggestion"

---

## Sign Mode: Detailed Interaction Contract

### Signature sheet tabs
1. **Draw** — `Canvas`-based freehand pad; supports stylus/mouse
2. **Type** — user enters name; three script-font previews; picks one
3. **Image** — drag-drop or file picker for .png / .jpg scan
4. **Saved** — reuse a prior signature from app-sandboxed store

### After signature is created
1. User positions it on the target region (may be a detected candidate or free-placed)
2. App creates `EditOperation` with `kind: .overlayImage`, `destructive: false`
3. Date-stamp offer: "Add today's date next to the signature?"
4. Optional: "Convert to native signature widget" → `synthesizeNativeField()`

### Signature storage
- Store is **app-sandboxed** (not Keychain, not in-PDF, not cloud)
- User must explicitly check "Save this signature for later use"
- Stored as data URL with a user-assigned label
- Cleared by "Forget all signatures" in Settings

### What it is not
- Not a cryptographic digital signature
- Not a legally binding e-signature
- Not a PDF/A or LTV signature
- The UI states this plainly: "This adds a visual signature. For legally binding signatures, use a certified e-signature service."

---

## Edit Mode: Detailed Interaction Contract

Edit mode exposes the full `EditKind` vocabulary through a **tool palette** in the inspector:

| Tool | EditKind | Risk class | Gate |
|---|---|---|---|
| Add text | `overlayText` | L1 reversible | Permission check only |
| Add image | `overlayImage` | L1 reversible | Permission check only |
| Add stamp | `stamp` | L1 reversible | Stamp library selection |
| Highlight / underline | `annotation` | L1 reversible | — |
| Mark for redaction | `redactMark` | L1 reversible | — |
| Apply redaction | `applyRedaction` | L3 irreversible | Explicit confirmation alert |
| Flatten overlays | `flatten` | L3 irreversible | Explicit confirmation alert |
| Rotate page | `pageTransform` | L1 reversible | — |
| Delete page | `pageDelete` | L1 reversible (undo) | — |
| Insert blank page | `pageInsert` | L1 reversible | — |

L3 operations present a destructive-action alert with:
- Clear description of what will be permanently removed
- "I understand, proceed" button (not default)
- Cancel as the default action

---

## AppModel API Sketch

### New enum (in `DocumentModel.swift`)

```swift
public enum EditorMode: String, Codable, CaseIterable, Hashable, Sendable {
    case read
    case fill
    case sign
    case edit
}
```

### New state (in `AppModel.swift`)

```swift
var editorMode: EditorMode = .read
var isSignatureSheetPresented = false
var pendingSignatureRegion: RegionCandidate?
var savedSignatures: [SavedSignature] = []
```

### New computed properties

```swift
// All regions the Fill mode highlight layer should draw
var fillHighlightRegions: [FillHighlight] { … }

// (total editable - unfilled) / total editable, nil when nothing to fill
var fillProgress: Double? { … }

// Formatted "3 / 9 fields filled" string
var fillProgressLabel: String? { … }

// Next unfilled region in reading order (for Tab)
var nextUnfilledRegion: EditableRegionRef? { … }
```

### New actions

```swift
func setEditorMode(_ mode: EditorMode)
func advanceToNextField()          // Tab / Return handler in Fill
func retreatToPreviousField()      // Shift+Tab
func handlePageTap(pageIndex: Int, point: CGPoint)  // intent inference router
func beginSign(for candidate: RegionCandidate?)
func applySignature(_ data: Data, to region: PDFRect, on pageIndex: Int)
func showFillOffer()               // status bar chip on open
```

---

## PDFKitView Changes

The `PDFKitView` NSViewRepresentable needs a new **overlay layer** that draws highlights
without modifying the `PDFDocument`. This is separate from `PDFAnnotation` — it is a purely
visual `CAShapeLayer` overlay.

Requirements:
- Receives `[FillHighlight]` as input; redraws on change
- Draws rounded-rect borders with the correct color per state
- Hit-testing routes back through `onPageTap` callback (new, analogous to existing `onManualPlacement`)
- No PDFDocument mutation — annotations are only created by `apply(operation:to:)` in PDFKitProvider

---

## Invariants (non-negotiable, doctrine-rooted)

1. **Mode never auto-mutates source.** Setting a mode never calls `provider.apply(...)`.
2. **Mode reset on open.** Every `open(url:)` resets `editorMode = .read` (no stale state).
3. **L3 gate always fires.** `applyRedaction` and `flatten` always show the confirmation alert,
   regardless of how the action is triggered (menu, palette, keyboard shortcut).
4. **Signature is always reversible until flatten.** A placed signature is `EditOperation` with
   `reversible: true`. Irreversibility requires explicit flatten.
5. **Fill progress never auto-applies.** Tab/Return advances focus; it does not confirm an entry.
   Confirmation is always an explicit user action (button tap, Return in a focused text field).

---

## What stays unchanged

- The provider-neutral contract (`EditOperation`, `PDFContractEnvelope`) is not changed.
- The `PDFKitProvider.apply(operation:to:)` path is not changed.
- Undo/redo semantics are not changed — all new operations go through `recordAppliedOperation`.
- The inspector sidebar remains for power-user access; it is not replaced by mode UI, only supplemented.
- Session persistence and recovery are not changed by this feature.

---

## Scope excluded from this design

- Digital/cryptographic signatures
- Collaborative real-time editing
- Server-side processing
- Automatic field value inference from user profile (autofill from profile is a separate feature,
  gated on user-approved mapping, not heuristic)
- Batch/pipeline mode

---

## Verification plan

| Check | Method | Target tier |
|---|---|---|
| Mode state resets on open | Unit test `AppModel.open(url:)` | Tier 2 / S1 |
| Tab order visits all fields | Unit test `nextUnfilledRegion` sequence | Tier 2 / S1 |
| L3 confirmation always fires | UI test: trigger `applyRedaction` without confirmation | Tier 2 / S2 |
| Fill progress formula | Unit test with known field/candidate counts | Tier 2 / S1 |
| Sign overlay is reversible | Undo after `applySignature`, assert annotation removed | Tier 2 / S1 |
| Overlay layer doesn't mutate PDFDocument | Assert `inspection.source.sha256` unchanged after mode switch | Tier 2 / S1 |

---

## Decisions updated 2026-08-25 (owner-resolved)

The following open questions were answered by the project owner with first-principles reasoning.
They supersede the initial draft resolutions above.

| Question | Owner decision | First-principles rationale |
|---|---|---|
| Inline vs sidebar edit in Fill mode? | **Both.** Clicking a region opens an inline editor *at the click point* AND the sidebar inspector synchronises to show the same field. | Spatial mapping is the right mental model for filling; the sidebar remains for power-user evidence review. Forcing a choice between them is a false dilemma — the two surfaces serve different cognitive needs. |
| Mode reset on open? | **User preference** (settable in Settings). Default is reset to `.read`. | Power users who fill many similar documents should not be forced back to Read every time. The default protects casual users; the pref serves professional workflows. |
| Signature storage? | **macOS Keychain** (long-term first principles). Interim: app-sandboxed file with explicit migration path to Keychain. | Signatures are sensitive biometric-adjacent data. The Keychain is the platform-native credential store — hardware-backed on Apple Silicon, sandboxed per app, cleared on uninstall, never accessible to other apps. An app-sandboxed file is weaker and is an interim step only. |
| Redaction gate? | **Two-phase with a hard irrevocability gate** (long-term first principles). Phase 1: mark regions (fully reversible, shown in red overlay). Phase 2: explicit "Commit redactions" action — presents a destructive alert listing exactly what will be removed, requires "Commit" to be typed or an explicit affirmative, and records an irrevocability audit entry. | Redaction is a legal act. Applying it accidentally or without understanding its permanence creates liability. The hard gate mirrors the discipline of physical document destruction: you must consciously choose and understand the irreversibility. |
| Auto-enter Fill on open if fields present? | **No.** Offer chip only. | Unchanged — user must consciously choose Fill mode. |
| Tab order user-reorderable? | **v2.** Automatic in v1. | Unchanged. |

### Keychain migration plan (signature storage)

1. **v1 (current implementation):** App-sandboxed file in `~/Library/Application Support/PDFEditor/signatures/`. Explicit user checkbox: "Save this signature for future use."
2. **v2:** Migrate to macOS Keychain using `kSecClassGenericPassword` with `kSecAttrService = "com.pdeditor.signatures"` and per-signature `kSecAttrAccount = signature-uuid`. Migration runs on first launch after upgrade and deletes the file store on success.
3. **iCloud Keychain:** Opt-in only. Never enabled by default — signature sync across devices requires explicit user consent.

### Redaction gate specification

```
Phase 1: Mark (reversible)
  editKind = .redactMark
  reversible = true, destructive = false
  Visual: red semi-transparent overlay rectangle
  Undo: removes the mark, no PDF content changed

Phase 2: Commit (irreversible, L3 gate)
  Trigger: explicit "Commit redactions" button or menu item
  Pre-check: at least one .redactMark operation exists
  Alert: sheet listing the count and page locations of marked regions,
         text "This action permanently removes content from the PDF.
               It cannot be undone. The original file is not modified —
               a new file will be created."
         Buttons: "Cancel" (default), "Commit Permanently"
  Post-commit: editKind = .applyRedaction, destructive = true
  Audit entry: written to session log with timestamp, page list, hash
```
