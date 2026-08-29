# Feature Exploration: Intent-Driven Modes for PDF Editor

## What We're Exploring

The idea: instead of surfacing a flat set of tools ("Add text", "OCR page", "Native fields"), the
app reads **what the user is doing** and activates the right mode automatically — or offers the
right contextual affordances at the right moment.

This is the same mental model Adobe Acrobat uses with its floating toolbar, but we can do it more
gracefully in a native SwiftUI/macOS app because we own the full interaction graph.

---

## The Four Intent Modes

```
┌─────────────────────────────────────────────────────────────────────┐
│  READ        VIEW only. No overlays, no field highlights.           │
│              Default on open. Zero cognitive noise.                 │
├─────────────────────────────────────────────────────────────────────┤
│  FILL        Highlight every editable region (native fields +       │
│              detected candidates). Click one → edit inline.         │
│              Tab/Return moves to the next unfilled region.          │
├─────────────────────────────────────────────────────────────────────┤
│  SIGN        Show detected signature regions. Opens draw/type/      │
│              image-upload sheet. Stamps the result as a reversible  │
│              overlay. May synthesize a native Sig widget.           │
├─────────────────────────────────────────────────────────────────────┤
│  EDIT        Full authoring surface. Drag new text boxes, images,   │
│              stamps, redaction marks. All EditKinds available.      │
│              Dangerous ops (redact, flatten) require confirmation.  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Intent Inference: How We Read the User

The key insight is that intent signals arrive **before** the user picks a tool.

| Signal | Inferred Intent | Trigger |
|---|---|---|
| Opens a document that has ≥1 native field | **Fill** offer | Banner: "This form has fields — start filling?" |
| Clicks directly on a `RegionCandidate` (blank zone) | **Fill** | Activate inline editor at that spot immediately |
| Clicks on a `suggestedFieldType == .signature` candidate | **Sign** | Open signature sheet directly |
| Double-clicks free space with no candidate nearby | **Edit** | Drop a text cursor at tap point (existing `onDirectEdit`) |
| Clicks outside any candidate (scroll/read motion) | **Read** | No mode change; keep current mode |
| User opens a document with zero fields and zero candidates | **Edit** offer | "No form fields detected. Add text manually?" |
| Toolbar mode pill selection | Explicit override | Overrides inference |

---

## Mode Pill (Toolbar UI)

Replace the current flat toolbar with a **mode segmented control**:

```
[ Read ]  [ Fill ▼ ]  [ Sign ]  [ Edit ]
```

- **Read** — clears all overlays, restores passive scroll
- **Fill** — highlights all editable regions, walks them in tab order
- **Sign** — narrows to signature regions; activates draw sheet
- **Edit** — full authoring palette appears in inspector

Current toolbar items (Open, Undo, Export, Reader mode, Scale) move to a **secondary row**
so they don't compete visually with the intent pill.

---

## Fill Mode: The Core Flow

### Entry
- User opens a PDF that has ≥1 field or candidate → status bar shows offer chip
- User clicks mode pill → Fill
- Clicking any blank-looking region without selecting a mode first → infer Fill, enter it

### In-mode behaviour
1. Every `NativeField` gets a **tinted overlay** (blue border, fill badge)
2. Every active `RegionCandidate` gets a **dashed border** (orange when unfilled, green when filled)
3. A **progress bar** in the control bar: "4 / 11 fields filled"
4. Clicking a tinted region:
   - Native text field → inline `TextField` pops up at the field location (no sheet)
   - Native checkbox/radio → toggle immediately
   - Candidate text region → `overlayDraft` TextField appears inline at that location
   - Candidate signature region → short-circuits to Sign sheet
5. **Tab** advances to the next unfilled region (reading-order: top-to-bottom, left-to-right, page-by-page)
6. **Return** confirms current entry and advances (same as Tab)
7. Right-click / long-press on any filled region → context menu: Edit, Clear, Dismiss

### Smart "fill all empty" shortcut
A button: **"Fill all blank fields"** → iterates all candidates in order, activating
the first unfilled one. Users can step through without ever clicking the PDF.

---

## Sign Mode: The Signature Flow

### Entry triggers
- Mode pill → Sign
- Click on a `suggestedFieldType == .signature` region
- `CandidateEntryMode == .signature` candidate selected in inspector

### In-mode behaviour
1. **Signature sheet** appears (draw pad, type-name, or image upload)
2. User creates/selects a signature
3. App stamps it as an `EditKind.overlayImage` on the candidate bounds
4. Optionally: "Convert to native signature field" → `synthesizeNativeField()`
5. A **date stamp** can be auto-placed adjacent to the signature region
6. Re-opening Sign mode shows the existing stamp, allows replacement

### Signature panel tabs (within the sheet)
- **Draw** — NSView-based freehand canvas (or a SwiftUI `Canvas`)
- **Type** — stylized name in 3 font choices (script-like)
- **Image** — drag-drop or file picker for a .png/.jpg signature scan
- **Saved** — reuse a previously stored signature (stored in Keychain or app sandbox, not in PDF)

---

## Edit Mode: Full Authoring

This maps directly to existing capabilities, just surfaced more clearly.

| Tool | EditKind | Current state |
|---|---|---|
| Add text | `overlayText` | ✅ exists (ManualTextSheet) |
| Add image | `overlayImage` | model enum defined, needs PDFKitProvider wiring |
| Stamp | `stamp` | model enum defined, needs stamp library |
| Redact (mark) | `redactMark` | model enum defined, needs PDFKitProvider wiring |
| Apply redaction | `applyRedaction` | model enum defined, irreversible gate needed |
| Flatten | `flatten` | model enum defined, irreversible gate needed |
| Delete page | `pageDelete` | model enum defined |
| Rotate page | `pageTransform` | ✅ exists (rotateLeft/rotateRight) |
| Insert page | `pageInsert` | model enum defined |

**New surface:** An **edit palette** sidebar section that replaces the current inline
"Add text manually" button with a proper tool grid.

---

## Interaction Graph: Click-to-Intent Map

```
User clicks on the page
        │
        ├─ Hits a NativeField rect?
        │       ├─ YES → inline field editor (Fill mode affordance)
        │       └─ NO  ↓
        │
        ├─ Hits a RegionCandidate rect?
        │       ├─ kind == .signature → Sign sheet
        │       ├─ isDirectlyEditable → inline overlay TextField
        │       ├─ .checkbox/.radioGroup → toggle/pick affordance
        │       └─ otherwise → select candidate, show inspector card
        │
        ├─ Hits free space?
        │       ├─ Current mode == .fill → ignore (no accidental text drops)
        │       ├─ Current mode == .edit → begin text placement (onDirectEdit)
        │       └─ Current mode == .read → no action
        │
        └─ Double-click on free space?
                └─ Always → intent=.edit, begin text placement (consistent with desktop affordance)
```

---

## AppModel Changes Required

### New state

```swift
enum EditorMode: String, Codable, CaseIterable, Sendable {
    case read
    case fill
    case sign
    case edit
}

var editorMode: EditorMode = .read
var fillProgress: FillProgress?          // current / total counts
var signatureImageData: Data?            // pending signature
var isSignatureSheetPresented = false
```

### New computed helpers

```swift
// All regions that should be highlighted in Fill mode
var editableRegions: [EditableRegion] { … }

// Next unfilled region in reading order
var nextUnfilledRegion: EditableRegion? { … }

// Infer mode from a click point on a page
func inferMode(for point: CGPoint, on pageIndex: Int) -> EditorMode { … }
```

### New actions

```swift
func setMode(_ mode: EditorMode)
func advanceToNextField()        // Tab / Return handler
func applySignature(_ data: Data, to candidate: RegionCandidate)
func autofillFromProfile()       // stretch: fill known fields from a stored profile
```

---

## Key Design Decisions (Open Questions)

> [!IMPORTANT]
> These need resolution before implementation begins.

1. **Mode persistence across documents** — should Fill mode stay active when a second PDF is
   opened, or always reset to Read? Recommendation: reset to Read; Fill offer re-appears if fields detected.

2. **Inline vs. sheet editing** — for candidate regions, does clicking trigger a floating
   inline editor positioned at the click point (better spatial mapping), or does it always use
   the inspector sidebar (simpler, already built)?  
   *Recommendation: inline for Fill mode, sidebar for Edit mode.*

3. **Tab order authority** — for static candidates (no native AcroForm tab order), we derive
   reading order ourselves. Should this be user-reorderable, or always automatic?
   *Recommendation: automatic first; user-reorder is a v2 feature.*

4. **Signature storage** — where do we persist saved signatures?
   macOS Keychain (most secure), app-sandboxed file (simplest), or in-document (exported PDF)?
   *Recommendation: app-sandboxed file, with an explicit "Store signature" checkbox on the sheet.*

5. **Redaction gate** — `applyRedaction` is irreversible. Should it require a separate
   "Commit redactions" confirmation step with a destructive alert, or be blocked behind
   an Edit mode sub-mode?
   *Recommendation: two-phase: mark first (reversible), then explicit commit (alert).*

6. **Auto-infer on open vs. explicit trigger** — should a document with ≥1 field auto-enter
   Fill mode, or show a non-intrusive offer chip? 
   *Recommendation: offer chip, not auto-enter — avoids surprising mode changes.*

---

## What Already Exists vs. What's New

| Capability | Status | Location |
|---|---|---|
| Native field inline editing (text, checkbox, choice) | ✅ Built | `InspectorView.fieldSection` |
| Overlay text placement | ✅ Built | `ManualTextSheet`, `applyManualText()` |
| OCR-detected candidates | ✅ Built | `StaticRegionDetector`, `RegionCandidate` |
| Candidate tab-walk | ⚠️ Partial | `selectPreviousCandidate` / `selectNextCandidate` |
| Signature region detection | ✅ Detected | `CandidateEntryMode.signature` |
| Signature stamp UI | ❌ Missing | Needs: draw pad + synthesize stamp |
| Mode pill toolbar | ❌ Missing | Needs: `editorMode` state + mode-aware PDFKitView overlays |
| Fill progress bar | ❌ Missing | Needs: `FillProgress` computed from candidates |
| Inline editor at click point | ❌ Missing | Would require a PDFKitView overlay layer |
| Redaction workflow | ❌ Missing | `redactMark` defined, PDFKitProvider not wired |
| Stamp library | ❌ Missing | `stamp` EditKind defined, no UI or library |
| Overlay image / add image | ❌ Missing | `overlayImage` defined, not wired |

---

## Suggested Phased Delivery

### Phase 1 — Mode Pill + Fill Mode (low-risk, high-value)
- Add `EditorMode` enum and `editorMode` to AppModel
- Add mode segmented control to toolbar
- In Fill mode: highlight native fields + candidates with tinted borders in PDFKitView
- Fill progress chip in status bar
- Tab/Return advances through unfilled regions
- Offer chip on open when fields detected

### Phase 2 — Sign Mode
- Signature sheet with Draw / Type / Image tabs
- Stamp result as `overlayImage` on candidate bounds
- Date-stamp affordance

### Phase 3 — Edit Mode Palette
- Replace "Add text manually" with a proper tool grid
- Wire `overlayImage` (add image) in PDFKitProvider
- Wire `stamp` (stamp library with common stamps: Approved, Draft, Confidential)
- Redaction two-phase workflow

### Phase 4 — Intent Inference
- Click-to-mode inference (`inferMode(for:on:)`)
- Auto-advance to next field after confirming a fill
- Autofill from profile (stored name, date, address)
