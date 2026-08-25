# Design System Specimen — Living Reference

**Status:** Active  
**Last updated:** 2026-08-25  
**Scope:** Web typography tokens, font stacks, responsive layout, and visual regression

## Purpose

This document links the interactive specimen and regression pages that let you
**visually verify** the design system tokens at render time. These pages are
the single source of truth for how the type scale, font stacks, spacing, and
responsive breakpoints actually render — not how they look in code.

## Specimen Pages

| Page | Path | What it shows |
|---|---|---|
| **Type Scale Specimen** | `web/typography-specimen.html` | All 7 type scale tokens at every weight, font stacks, hierarchy comparison, tabular numbers, letter spacing, and role usage examples |
| **Viewport Regression** | `web/typography-regression.html` | Toolbar + sidebar rendered at 5 viewport widths (1200px, 1000px, 750px, 500px) with a before→after token comparison table |

## How to View

From the project root:

```bash
python3 -m http.server 4173 --bind 127.0.0.1
```

Then open:
- http://127.0.0.1:4173/web/typography-specimen.html
- http://127.0.0.1:4173/web/typography-regression.html

Both pages are self-contained (inline CSS tokens) and work without a build step.

## Type Scale Tokens

```css
:root {
  --type-3xs: 0.5625rem;   /* 9px  — kickers, index numbers */
  --type-2xs: 0.625rem;    /* 10px — status labels, small meta */
  --type-xs:  0.6875rem;   /* 11px — buttons, labels, body-sm */
  --type-sm:  0.75rem;     /* 12px — captions, list titles */
  --type-body: 0.8125rem;  /* 13px — body UI text */
  --type-heading: 1.0625rem; /* 17px — panel headings */
  --type-display: 1.1875rem; /* 19px — overlay titles */
}
```

All sizes use `rem` and scale with the browser's base font size. The type scale
is defined in `web/design-system.css` and referenced by 30+ declarations across
the web editor.

## Font Stacks

| Role | Stack | Use |
|---|---|---|
| **Body** | `ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif` | Controls, body copy, dense data |
| **Display** | `Iowan Old Style, Baskerville, Palatino Linotype, Georgia, serif` | Product title, inspector headings, editorial |
| **Mono** | `ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace` | IDs, hashes, coordinates, uppercase labels |

## Responsive Breakpoints

| Width | Behavior |
|---|---|
| **≥1100px** | 3-column: rail (232px) + viewer + inspector (310px) |
| **<1100px** | 2-column: rail (180px) + viewer; inspector stacks below |
| **<900px** | Rail narrows to 150px; mode descriptions hide |
| **<760px** | Mobile: toolbar wraps, inputs forced to 16px (iOS zoom floor), mode rail becomes 5-column grid |
| **<600px** | Compact: tighter padding, context line shrinks |

## Key Principles Verified

- **Font smoothing:** `-webkit-font-smoothing: antialiased` at root
- **rem units:** All type scale values in `rem` (scales with user preferences)
- **tabular-nums:** On zoom %, candidate scores, docmap counts, mode context line
- **text-wrap: balance:** On `.mode-panel-title`, `.analysis-title`
- **text-wrap: pretty:** On `.analysis-copy`
- **letter-spacing:** 0.13em on 9px uppercase mono kickers, 0.01em on 12px body
- **iOS input zoom floor:** 16px on all inputs at <760px viewport
- **Logical properties:** All margins use `margin-inline-start/end`, text alignment uses `start/end`
- **Scale on press:** `scale(0.96)` on all 8 button types
- **Reduced motion:** `prefers-reduced-motion` disables all transitions/animations

## When to Re-check

Re-run the specimen and regression pages when:
- Adding or changing a type scale token
- Modifying font stack fallbacks
- Changing responsive breakpoints
- Adding new interactive elements (verify press feedback)
- Updating color tokens (verify contrast in specimen)
- Before any release (regression page catches visual drift)

## Related Documents

- `DESIGN.md` — Complete design system specification
- `docs/design-implementation-map.md` — Web product design implementation map
- `docs/runbooks/local-preview.md` — How to build, test, and launch locally
