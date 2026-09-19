# Localizability Survey — 2026-09-17 (MAD-R6)

**Question:** what would localization cost, and what does it gate? (Input to decision MAD-D4.)

## Measured state (2026-09-17, static inspection)

| Measure | Count | Note |
|---|---|---|
| `Text("` literals in `Sources/PDFEditorApp` | 409 | UI strings hardcoded English |
| `Button("` literals in `Sources/PDFEditorApp` | 180 | Menus + toolbar |
| `NSLocalizedString` / `String(localized:)` uses | **0** | No extraction infrastructure |
| `.strings` / `.xcstrings` / `.lproj` resources | **0** | No catalogs exist |
| Semantic fonts vs fixed sizes | 762 vs ~51 | Fixed chrome sizes (MAD-I13) compound layout risk under text expansion |

**Cost model:** ~600 user-facing literals in the app target (Core's user-visible strings — status
messages, intent result strings, error copy — add more but many are developer-facing). Extraction
to a String Catalog is mechanical for `Text`/`Button`; the real cost is (a) the ~600 review
pass for context/comments, (b) layout verification under German (+30% width) and Japanese
(height/wrapping) in the densest surfaces.

## Highest layout-risk surfaces (in order)

1. `ContextualInspectorView` (2,930 lines, 20+ fixed-width cards) — worst case; another reason
   MAD-I7 (de-card to flexible grouped sections) is prerequisite work, not just aesthetics.
2. Toolbar/overflow menus (MAD-006 density) — German labels will overflow faster.
3. Settings (fixed 580×480 frame) — frame is hardcoded; localization needs flexible sizing.

## Recommended path if MAD-D4 lands "localize"

1. Adopt a String Catalog (`Localizable.xcstrings`) — zero-cost migration path from literals
   (Xcode auto-extracts; for SwiftPM, strings compile into the catalog at build).
2. First slice: menus/commands + Settings + help window (small, high-visibility, low layout risk).
3. Second slice: inspector + dashboards *after* MAD-I7/MAD-I13 (do not localize fixed-card
   layouts you are about to delete).
4. Keep App Intent result strings out of scope initially (they're already semi-technical output).

**Sequencing note:** localization before MAD-I7 would double-touch every inspector string. The
cheap order is de-card → font pass → localize.
