# Reading Modes, Dark Mode, Freeze Panes, Tile Overlay

**Date:** 2026-08-28
**Status:** Observed + Verified
**Evidence tier:** Tier 3 (integration — all wired into UI, tests pass)
**Test sensitivity:** S1 (all tests pass)

## 1. Decision context

The READ job analysis identified these as HIGH-priority gaps:
- R-05: Dark mode — no theme support
- R-06: Reading modes — no study/skim/reference/review modes
- R-14: Layout modes — freeze panes, content-routed modes

**Question:** How do we implement these features while maintaining the privacy doctrine and first principles?

## 2. Reading Modes

### Architecture
- 4 modes: Study, Skim, Reference, Review
- Each mode configures: inspector visibility, thumbnails, toolbar, annotations, spacing, background
- Mode stored in `ReadingMode` enum, persisted via `ReadingDisplayParams`

### Mode configurations
| Mode | Inspector | Thumbnails | Toolbar | Annotations | Spacing | Background | Progress |
|---|---|---|---|---|---|---|---|
| Study | ✅ | ✅ | ✅ | ✅ | 1.15x | None | ✅ |
| Skim | ❌ | ❌ | ❌ | ❌ | 1.0x | None | ✅ |
| Reference | ✅ | ✅ | ✅ | ✅ | 1.05x | Yellow tint | ❌ |
| Review | ✅ | ✅ | ✅ | ✅ | 1.0x | None | ✅ |

### First principle
Reading modes are presets for attention management. Study mode maximizes context (inspector + thumbnails + annotations). Skim mode minimizes distraction (no chrome). Reference mode optimizes for long reading (yellow tint reduces eye strain).

## 3. Dark Mode

### Architecture
- `ThemeManager` with system-following, manual override, high-contrast variant
- Colors defined as `NSColor` with light/dark/high-contrast variants
- Applied via `@Environment(\.colorScheme)` in SwiftUI

### Key decisions
- System-following by default (matches macOS convention)
- High-contrast variant for accessibility (RG-057/058/059)
- No custom theme engine — uses native AppKit/SwiftUI dark mode

## 4. Freeze Panes

### Architecture
- `FreezePaneOverlayView` — NSView overlaying PDFKit at zPosition 100
- Pins header rows and/or left columns while body scrolls
- Presets for common table types (spreadsheet, financial report, invoice)
- Column sort on frozen tables

### First principle
Freeze panes solve the "lost context" problem. When scrolling through a long table, the header row provides column labels. Without it, data becomes meaningless.

### Implementation
- Frozen region rendered as separate CALayer
- Body scrolls underneath
- Sort arrows on frozen header columns
- Interactive resize (future: drag boundary)

## 5. Tile Overlay

### Architecture
- `PipelineTileOverlayView` — NSView compositing pipeline tiles as CALayers
- Positioned at zPosition 50 (above PDFKit, below freeze panes)
- Debounced reload on scroll/zoom (50ms)
- Viewport-aware: only renders visible tiles

### First principle
Tile overlay is the pragmatic hybrid between "PDFKit renders everything" and "pipeline renders everything." It lets the pipeline provide visual quality while PDFKit handles interactions.

## 6. Evidence

- Reading mode tests pass
- Dark mode verified visually
- Freeze pane tests pass
- Tile overlay tests pass (10 tests)
- Full suite: 1199/1199 pass

## 7. Doctrine alignment

- §1 Outcomes: reading modes improve comprehension, dark mode reduces eye strain, freeze panes preserve context
- §5 Evidence-based: mode configurations verified, tile render times tracked
- §8 Capability activation: reading modes are opt-in
- §12 Privacy stays value-free: dark mode uses system colors, no content inspection

## 8. Risks

- Dark mode colors may not match all PDF backgrounds
- Freeze panes assume regular table structure (irregular tables may not work)
- Tile overlay adds memory overhead (pipeline tiles + PDFKit data)

## 9. Open questions

- Should freeze panes auto-detect table structure?
- Should dark mode invert PDF images or keep them as-is?
- Should reading modes be per-document or global?
