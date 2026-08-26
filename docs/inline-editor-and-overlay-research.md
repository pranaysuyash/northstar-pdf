# Inline Field Editor & Overlay — Research & Diagnosis

Scope: the macOS `pdf_editor` app (SwiftUI + PDFKit), specifically the on-canvas
editable field overlay and the inline text editor that appears when filling a
detected region. Focus of this doc: (1) is the detected-field overlay clean, and
(2) why does typing a value and pressing Enter do nothing.

## 1. How the overlay is rendered

The on-page overlay is drawn by `PDFPresentationOverlayView` (an `NSView` hosted
over the `PDFView`) in `Sources/PDFEditorApp/DocumentCanvasView.swift`. The
highlights it draws come from `AppModel.fillHighlightRegions`
(`Sources/PDFEditorRecovery/AppModel.swift:1975`):

- In `.fill` mode it emits **one highlight for every native field AND every
  active candidate**, unconditionally.
- Each highlight carries a text `label` — `field.name` for native fields,
  `candidate.effectiveDisplayName` for candidates.
- `effectiveDisplayName` (`DocumentModel.swift:333`) falls back to
  `FieldLabelCanonicalizer.displayName(labelText:)` when there is no stored
  display name. For Form-6-style scanned forms the detector assigns the nearest
  text line as `labelText` (`StaticRegionDetector.swift:107,210`).

The inline editor itself is `InlineEditorTextFieldHost` (an `NSView` with an
`NSTextField` + a name chip), also created in `DocumentCanvasView.swift`
(`updateNSView` at lines 1088–1129).

## 2. Is the overlay clean? — No.

For a flat, form-style PDF like the Form-6 voter application, the overlay is
cluttered and not clean, for two compounding reasons:

1. **Every candidate is drawn at once.** `fillHighlightRegions` returns all
   candidates with no deduplication, no "one at a time" cap, and no minimum
   spacing. A single page with many rows (name, address, dozens of checkbox
   rows) produces dozens of overlapping orange boxes.

2. **Long neighbor labels are repeated on every box.** The static region
   detector (`StaticRegionDetector.swift`) attaches the *nearest* text line as
   `labelText`. On a dense form the nearest line is often a shared section
   header (e.g. "First Name followed by Middle Name", or "I submit application
   for inclusion of my name in the electoral roll …"). Because every grouped
   cell row in that section resolves to the same nearby header, the overlay
   shows many stacked boxes all labeled with that long sentence — exactly the
   visual noise in the screenshot.

Net effect: overlapping boundaries and duplicated long captions make the overlay
look messy and obscure the actual form text. The detector's intent (group cells
into one region per logical field, lines 86–99) is reasonable, but the
label-attachment and the "draw everything" presentation defeat it.

Recommended direction (not yet implemented):
- Cap visible highlight labels, shorten/clip long `labelText`, and prefer a
  stable per-field canonical name over the raw nearest line.
- De-emphasize non-focused candidates (faint outline, label only on hover/focus)
  instead of drawing full-strength boxes + captions for all of them.
- Merge candidates whose bounds substantially overlap and share a label.

## 3. Why Enter does nothing — root cause found

The inline editor host never sets itself as the text field's delegate.

In `InlineEditorTextFieldHost.init` (`DocumentCanvasView.swift:382`), the field is
created and configured, but there is **no `textField.delegate = self`**. The only
occurrence of `.delegate` anywhere in the app is unrelated
(`PDFEditorApp.swift:117`). As a result:

- `control(_:textView:doCommandBy:)` (`DocumentCanvasView.swift:452`) — the
  handler for `insertNewline:` (Return/Enter) — is **never called**.
- `controlTextDidEndEditing(_:)` (`DocumentCanvasView.swift:463`) — the
  alternative commit path that fires when editing ends — is **also never called**.

So when the user types a value and presses Enter, no commit is ever triggered.
The value sits in the field and nothing is applied. This also means clicking away
from the field (which would normally end editing and commit) does not commit
either.

The intended commit chain (which is correct downstream) is:
`Enter → host.onCommit → model.commitInlineEditor(text:) → applyOverlay/applyFieldValue → provider.apply → PDF annotation added to the live document`.

The downstream chain itself works: the side-panel "Place Text" button
(`ContextualInspectorView.swift:234`) calls `model.applyOverlay(...)` directly and
does fill the field. Only the on-canvas Enter path is dead because the delegate
is missing.

### Why the perceived symptom is "nothing happens"
`commitInlineEditor` (`AppModel.swift:2272`) guards on `selectedCandidate` /
`selectedField` and calls `applyOverlay` / `applyFieldValue`. Those emit a
`statusMessage` or `alertMessage` on success/failure — but because the delegate
is missing, execution never reaches them. There is no error, no alert, no
visible change: exactly "nothing happens."

## 4. Supporting evidence (file/line map)

| Concern | Location |
| --- | --- |
| Overlay drawing for all candidates/fields | `DocumentCanvasView.swift:470` (`PDFPresentationOverlayView.draw`), driven by `AppModel.fillHighlightRegions:1975` |
| Candidate label source | `StaticRegionDetector.swift:107,210` (`labelText = nearbyLabel.text`); fallback `DocumentModel.swift:333` → `FieldLabelCanonicalizer.displayName` |
| Inline editor host (no delegate set) | `DocumentCanvasView.swift:382` (`InlineEditorTextFieldHost`); `textField` created at line 392, no `delegate` assignment |
| Enter handler that never fires | `DocumentCanvasView.swift:452` (`control(_:textView:doCommandBy:)`) |
| End-editing handler that never fires | `DocumentCanvasView.swift:463` (`controlTextDidEndEditing`) |
| Commit entry point | `AppModel.commitInlineEditor:2272`; `applyOverlay:1599`; `applyFieldValue:1572` |
| Provider that writes the annotation | `PDFKitProvider.apply overlayText/.annotation:475`, `nativeFieldValue:425` |
| Side-panel button that works (proves pipeline) | `ContextualInspectorView.swift:234` ("Place Text") |

## 5. Conclusion

- The overlay is **not clean**: it draws every candidate at full strength with
  long, often-duplicated neighbor-line labels, producing overlapping boxes that
  obscure the form.
- Enter does nothing because `InlineEditorTextFieldHost` never assigns
  `textField.delegate = self`, so neither the Enter command nor the
  end-editing callback ever reaches `model.commitInlineEditor`.

Both are fixable without touching the (working) apply pipeline. The overlay
cleanliness fix is a presentation/detector-label change; the Enter fix is a
one-line delegate assignment plus verifying the two delegate methods drive
commit correctly.

(No code was changed in this pass — exploration/research/documentation only, per
the request to document first.)
