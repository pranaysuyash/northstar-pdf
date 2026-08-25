# PDF Editor Design System

**Status:** Active product design system
**Version:** 1.0
**Last reviewed:** 2026-08-25
**Product:** Local-first PDF reader and editor for native macOS and browser surfaces
**Working visual name:** Northstar

This system is the visual contract for the current product and the long-term capability
program. It is intentionally more durable than the current provider implementation: UI
states must remain coherent when a capability moves from `reader-only` to `available`,
when a companion provider is installed, or when a future operation is gated for safety.

## Product posture

PDF Editor is a high-trust document workbench. The source PDF is the primary surface;
application chrome explains location, intent, evidence, and recovery without competing
with the document. The product starts as a local-first reader and reviewed completion
flow and grows into a complete native/web PDF platform.

The canonical product journey is:

```text
Reader -> Understand -> Complete -> Organize -> Review
```

- **Reader:** open, navigate, search, select, inspect, and recover from unsupported input.
- **Understand:** map page structure, native fields, evidence, candidates, and limitations.
- **Complete:** review and fill native fields, suggestions, overlays, templates, and signatures.
- **Organize:** arrange pages, templates, batches, conversions, and repeatable workflows.
- **Review:** inspect operation lineage, preservation metrics, warnings, and export a new copy.

The current experience already supports reading, navigation, native-field editing, reviewed
static candidates, reversible overlays, manual placement, undo, export, and validation in
native and browser slices. The long-term system also reserves coherent surfaces for OCR,
text-run editing, reflow, redaction, sanitization, signatures, XFA, PDF/UA, templates,
batch work, local companions, collaboration, and optional hosted processing. A capability
may be partial, blocked, failed, or abstained; it must never disappear or imply success.

### Design references and synthesis

- **Current prototype:** dark shell, slate canvas, warm paper, evidence-oriented inspector,
  compact controls, and a restrained blue action language.
- **Linear:** clear mode ownership, dense but calm productivity surfaces, and explicit state.
- **Apple:** native macOS calm, direct manipulation, system typography, and progressive reveal.
- **IBM Carbon:** operational clarity, keyboard accessibility, status semantics, and auditability.

These are references, not brand copies. PDF Editor owns the combination: document-first,
local, reversible, evidence-aware, and deliberately quiet.

## 1. Visual Theme & Atmosphere

### Design philosophy

Make the document feel trustworthy and legible before making the tool feel powerful.
The interface should resemble a precise workbench: dark command frame, cool slate stage,
and warm paper artifact. Controls are compact, surfaces are mostly flat, and depth is used
to separate the source document from application chrome rather than to decorate.

### Core visual characteristics

1. **Document-first:** paper and text carry visual weight; chrome stays subordinate.
2. **Evidence-visible:** confidence, provenance, validation, and capability state are legible.
3. **Calm precision:** short labels, stable alignment, restrained color, tabular metrics.
4. **Reversible by default:** pending work looks provisional; committed work looks recorded.
5. **Local and private:** locality, source identity, and provider boundaries are explicit.

### Light and texture

- Use a light document stage and a warm near-white paper surface.
- Use the dark shell only for global navigation, session context, and command framing.
- Prefer 1px rules and small shadows over floating-card stacks.
- Avoid gradients, glossy surfaces, decorative blobs, and heavy glassmorphism.
- Motion should explain state change: focus, selection, progress, validation, or recovery.

### Surface hierarchy

```text
shell        = global navigation and session context
canvas       = neutral stage around the PDF
paper        = source document boundary
inspector    = evidence, actions, and state explanation
overlay      = modal, confirmation, or provider/install boundary
```

## 2. Color Palette & Roles

Hex values are the design-token contract. Runtime CSS may use equivalent OKLCH values,
but visual regression tests should resolve back to these named roles.

### Primary, brand, and interactive

| Role | Value | Variable | Use |
|---|---|---|---|
| Action blue | #2563EB | `--color-action` | Primary actions, focus, selected regions |
| Action deep | #1D4ED8 | `--color-action-deep` | Primary button fill, active navigation |
| Action wash | #DBEAFE | `--color-action-wash` | Selected candidate background, soft status |
| Shell ink | #242A37 | `--color-shell` | Global command frame and mode rail |
| Shell raised | #303848 | `--color-shell-raised` | Hover, selected, raised shell controls |
| Shell rule | #465062 | `--color-shell-border` | Dark-surface dividers |

### Neutral scale and surfaces

| Role | Value | Variable | Use |
|---|---|---|---|
| Ink | #172033 | `--color-ink` | Primary text on light surfaces |
| Ink soft | #475569 | `--color-ink-soft` | Supporting text and descriptions |
| Ink faint | #64748B | `--color-ink-faint` | Metadata, labels, low-emphasis copy |
| Canvas | #E9EDF2 | `--color-canvas` | Workspace around the page |
| Paper | #FCFBF8 | `--color-paper` | PDF page boundary and paper proxy |
| Surface | #FFFFFF | `--color-surface` | Inspector and control surfaces |
| Surface soft | #F5F7FA | `--color-surface-soft` | Secondary cards and rows |
| Border | #D7DDE5 | `--color-border` | Light dividers and control borders |
| Border strong | #B8C2D0 | `--color-border-strong` | Selected inputs and structural rules |

### Semantic and evidence colors

| Role | Value | Variable | Use |
|---|---|---|---|
| Evidence amber | #B7791F | `--color-evidence` | Suggested, uncertain, review-required |
| Evidence wash | #FFF7E6 | `--color-evidence-wash` | Candidate review card and warning background |
| Success | #15803D | `--color-success` | Validated, saved, accepted, reopened |
| Success wash | #EAF7EE | `--color-success-wash` | Positive validation summary |
| Danger | #B42318 | `--color-danger` | Destructive action, failed, revoked |
| Danger wash | #FDECEC | `--color-danger-wash` | Error and irreversible-operation warning |
| Info | #0369A1 | `--color-info` | Neutral explanatory status |
| Neutral status | #64748B | `--color-neutral-status` | Unknown, reader-only, not measured |
| Redaction mark | #C2413A | `--color-redaction` | Reversible redaction mark only |

### Shadow colors

| Role | Value | Variable | Use |
|---|---|---|---|
| Quiet shadow | rgba(23, 32, 51, 0.06) | `--shadow-color-quiet` | Small control elevation |
| Page shadow | rgba(23, 32, 51, 0.14) | `--shadow-color-page` | PDF page against canvas |
| Overlay shadow | rgba(15, 23, 42, 0.22) | `--shadow-color-overlay` | Dialogs and command sheets |

### Status mapping rules

- `available` and `validated` use action blue or success only when the action is safe.
- `partial`, `suggested`, and `review required` use amber; never use green for inference.
- `reader-only`, `unknown`, and `unmeasured` use neutral gray, not danger red.
- `blocked`, `failed`, `revoked`, and `destructive` use danger with a reason and recovery path.
- Red is reserved for irreversible semantics and redaction marks; it is not a general accent.
- Never use color alone: pair every status with text, iconography, or a shape change.

## 3. Typography Rules

### Font families

```css
--font-display: Iowan Old Style, Baskerville, Palatino Linotype, Georgia, serif;
--font-body: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
--font-mono: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
```

Use the display face for product title, inspector headings, and editorial summaries. Use
system sans for controls, body copy, and dense data. Use mono for IDs, hashes, coordinates,
provider versions, evidence codes, and compact uppercase labels.

### Type scale

| Level | Size / line | Weight | Tracking | Use |
|---|---:|---:|---:|---|
| Display | 32px / 36px | 600 | -0.03em | Empty-state or launch title |
| H1 | 24px / 29px | 600 | -0.025em | Workspace section title |
| H2 | 18px / 22px | 600 | -0.02em | Inspector and modal title |
| H3 | 14px / 19px | 700 | -0.01em | Card and review heading |
| Body large | 15px / 22px | 400 | 0 | Explanatory copy |
| Body | 13px / 19px | 400 | 0 | Default product copy |
| Control | 12px / 16px | 600 | 0 | Buttons, selects, labels |
| Small | 11px / 15px | 400 | 0 | Supporting detail |
| Caption | 10px / 13px | 700 | 0.08em | Section kicker, uppercase metadata |
| Nano | 9px / 12px | 600 | 0.10em | Status code, mode index |

Typography rules:

- Keep body copy at 13px or larger except compact status metadata.
- Use tabular numerals for counts, ratios, page numbers, and metrics.
- Use sentence case for actions; reserve uppercase for metadata and labels.
- Do not use display serif for long paragraphs, table cells, or error details.
- Long explanatory copy should stay under 68 characters per line in the inspector.

## 4. Component Stylings

### Buttons

```css
.button {
  min-height: 34px;
  padding: 7px 10px;
  border: 1px solid var(--color-border-strong);
  border-radius: 5px;
  font: 600 12px/16px var(--font-body);
  transition: background-color 120ms ease, border-color 120ms ease, transform 120ms ease;
}
.button-primary { color: #FFFFFF; background: var(--color-action-deep); border-color: var(--color-action-deep); }
.button-secondary { color: var(--color-ink); background: var(--color-surface); }
.button-ghost { color: var(--color-ink-soft); background: transparent; border-color: transparent; }
.button-danger { color: var(--color-danger); background: var(--color-danger-wash); border-color: #E8A7A1; }
.button:hover:not(:disabled) { background: var(--color-action-wash); border-color: var(--color-action); }
.button-primary:hover:not(:disabled) { background: var(--color-action); }
.button:active:not(:disabled) { transform: translateY(1px); }
.button:disabled { opacity: 0.48; cursor: not-allowed; }
```

Primary is for the next safe action, not every important action. Destructive buttons are
never the default focus target and must include a consequence statement.

### Cards, rows, and panels

- Cards: `background: #FFFFFF`, border `#D7DDE5`, radius `6px`, padding `12px`.
- Review card: `#FFF7E6` with amber border `#E5C27A`; use only for uncertain evidence.
- Validation card: `#EAF7EE` with green border `#9AD0A7`; include evidence basis.
- Failed card: `#FDECEC` with danger border `#E8A7A1`; include next action.
- Avoid nested cards deeper than two levels. Prefer a divider and a heading.
- Dense inspector rows use 10px vertical padding and a 1px bottom rule.

### Inputs and selects

- Height: 34px minimum; text inputs may grow to 40px for primary completion fields.
- Background: `#FFFFFF`; border: `#B8C2D0`; radius: 5px; horizontal padding: 9px.
- Placeholder: `#64748B`; never use placeholder as the only label.
- Focus: 2px `#2563EB` outline with 2px offset; do not remove browser focus.
- Invalid: danger border plus concise message below; preserve entered value.
- Password and provider actions require explicit labels and a visible cancel path.

### Navigation and mode rail

- Desktop shell: dark left rail, 232px wide; active mode gets a 3px blue inset bar.
- Mode order is always Reader, Understand, Complete, Organize, Review.
- Each mode shows label, short description, and capability state.
- Active mode changes the available tools; it never mutates the PDF source.
- The document canvas remains visually continuous while inspector content changes.
- On mobile, mode navigation becomes a horizontally scrollable or 5-column compact rail.

### Badges and tags

- Height: 20px; padding `2px 7px`; radius: 999px; 10px mono or 11px body.
- `Field`: blue outline / blue wash; native provider-backed.
- `Suggested`: amber outline / amber wash; evidence-backed and review-only.
- `Applied`: blue fill or strong border; user-confirmed operation.
- `Validated`: green outline / green wash; backed by a named check.
- `Reader only`, `Unknown`, `Blocked`: neutral or danger according to reason.

### Modal and dialog

- Backdrop: `rgba(15, 23, 42, 0.38)`; no blur by default.
- Panel: white, radius 8px, padding 20px, max-width 460px, overlay shadow.
- Destructive dialog lists scope, permanence, output behavior, and recovery limits.
- Cancel is the default action. Destructive confirmation is explicit and non-ambiguous.
- Use sheets for signature creation, provider installation, and review details on macOS;
  use centered dialogs on web when the viewport is narrow.

### PDF canvas and evidence overlays

- PDF page has warm paper background, 1px neutral border, and page shadow.
- Native field: solid blue border, blue wash, `Field` label.
- Suggested region: dashed amber border, amber wash only when selected.
- Selected candidate: solid action border plus synchronized inspector detail.
- Applied overlay: thin blue border and translucent blue fill; never obscure source text.
- Redaction mark: red translucent mark with explicit `Marked, not removed` label.
- Search match: amber underline or wash behind text, never an opaque block.

### Operation history and validation

Every operation row shows type, page, target summary, state, undo availability, and source
binding. Validation summaries show `passed`, `warning`, `failed`, `skipped`, or `unknown`;
never collapse unknown into pass. A successful export always exposes the output identity,
reopen result, and remaining warnings.

## 5. Layout Principles

### Spacing system

Use a 4px base with an 8px rhythm for structural spacing.

```text
4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 64px
```

- Control gaps: 8px.
- Inline group gaps: 12px.
- Panel padding: 16px desktop, 12px compact.
- Page-to-page gap: 28px desktop, 20px tablet, 14px mobile.
- Section spacing: 24px; major mode transitions: 32px.

### Grid and containers

- Desktop workspace: `232px minmax(0, 1fr) 310px`, no outer card gap.
- Wide desktop may grow inspector to 340px but never squeeze the document below 560px.
- Main document column is centered with a max page width of 820px for reading comfort.
- Canvas gutters: 28px desktop, 20px tablet, 14px mobile.
- Inspector content is edge-aligned; do not wrap every section in a floating card.
- Use CSS grid for shell structure and flex for control groups.

### Composition rules

1. The document is the largest uninterrupted region.
2. Page thumbnails provide orientation, not a second command center.
3. Inspector actions follow the selected object and current mode.
4. Evidence explanation sits adjacent to the action it qualifies.
5. Empty, loading, blocked, failed, and success states reserve the same region.
6. Never hide a capability solely because its provider is not connected.

## 6. Depth & Elevation

### Shadow system

```css
--shadow-xs: 0 1px 2px rgba(23, 32, 51, 0.06);
--shadow-sm: 0 2px 8px rgba(23, 32, 51, 0.08);
--shadow-md: 0 8px 20px rgba(23, 32, 51, 0.10);
--shadow-lg: 0 14px 32px rgba(23, 32, 51, 0.12);
--shadow-page: 0 18px 45px rgba(23, 32, 51, 0.14);
--shadow-overlay: 0 20px 56px rgba(15, 23, 42, 0.22);
```

Use `shadow-page` for PDF pages, `shadow-overlay` for dialogs, and no shadow for the dark
shell or inspector boundaries unless a temporary popover needs separation.

### Surface layers and z-index

| Layer | Value | Meaning |
|---|---:|---|
| Document content | 0 | PDF page and text layers |
| Evidence overlays | 5 | Candidates, highlights, pending edits |
| Sticky controls | 20 | Toolbar, mobile action bar |
| Popovers | 40 | Menus, tooltips, inline inspectors |
| Modal backdrop | 50 | Password, confirmation, provider sheets |
| Modal content | 60 | Dialog and destructive confirmation |
| Critical alert | 80 | Session loss or security boundary |

Use backdrop blur only for transient overlays at `backdrop-filter: blur(8px)`; never blur the
PDF document itself. Keep source content visually stable during panel and mode changes.

## 7. Do's and Don'ts

### Do

1. Keep source content, app chrome, and derived overlays visibly distinct.
2. Show whether a fact came from a native field, detector, OCR, provider, or validator.
3. Make the next safe action prominent and the irreversible action deliberate.
4. Preserve focus, keyboard order, and visible focus rings across every mode.
5. Explain blocked and abstained states with a reason and a fallback when available.
6. Use page-space geometry and stable IDs in inspector details and recovery views.
7. Treat local processing and source preservation as visible product value.
8. Validate at mobile compact, tablet, laptop, desktop, and wide desktop sizes.

### Don't

1. Do not auto-enter Fill, Sign, or Edit mode on document open.
2. Do not use green to mean "the detector is confident" or "the AI is right."
3. Do not call a visual overlay a redaction, a drawn signature a digital signature,
   or a metadata scan a sanitization proof.
4. Do not hide a capability because a provider is missing; show `reader-only`, `blocked`,
   or `abstained` with scope.
5. Do not use gradients, dashboard-style metric tiles, or generic marketing cards in the workbench.
6. Do not place destructive controls beside primary completion controls without separation.
7. Do not overwrite the source file or imply byte-level preservation from a local check alone.
8. Do not let a dense inspector become the visual center of gravity.

## 8. Responsive Behavior

### Breakpoints

| Token | Width | Behavior |
|---|---:|---|
| `--bp-mobile` | 0-599px | Single column; canvas first; rails become compact sections |
| `--bp-tablet` | 600-1099px | Thumbnails plus canvas; inspector moves below |
| `--bp-desktop` | 1100-1359px | Three regions; compact 180px thumbnail rail |
| `--bp-laptop` | 1360-1599px | Full 232px / canvas / 310px workspace |
| `--bp-wide` | 1600px+ | Full workspace with more canvas breathing room |

Validate the supplied viewport matrix: 360x800, 390x844, 430x932, 600x960, 820x1180,
1024x768, 1366x768, 1440x900, and 1920x1080. No horizontal overflow is allowed.

### Reflow rules

- At mobile widths, toolbar groups wrap; title remains full-width and actions stay reachable.
- The PDF canvas comes first, followed by thumbnails and inspector sections.
- Mode rail becomes a compact five-item strip; descriptions may collapse but labels remain.
- Inspector cards become full-width sections with sticky action controls near the bottom.
- Completion fields use 40px controls and preserve inline editing where the viewport allows.
- At tablet widths, keep document and thumbnails adjacent; move evidence below the canvas.
- At desktop widths, maintain the 3-region workbench and keep the document centered.
- Use `clamp()` for page gutters and display headings; do not scale controls below 34px.

### Touch, keyboard, and assistive technology

- Minimum touch target: 44x44px on mobile; 34px controls are acceptable on pointer desktop.
- Keyboard focus order follows mode rail, document navigation, page canvas, inspector, actions.
- Tab in Complete mode advances fields; it never confirms a value by itself.
- Provide a skip link to the document viewer and live regions for status and validation.
- Keep canvas overlays discoverable through text alternatives and synchronized inspector content.
- Respect `prefers-reduced-motion`; use no motion to communicate essential state.

## 9. Agent Prompt Guide

### Quick reference

Use `--color-action` for safe primary actions, `--color-evidence` for uncertain findings,
`--color-success` only for validated outcomes, and `--color-danger` for irreversible or
failed states. Preserve the five modes and their order. The source PDF is immutable until
explicit export. Inferred findings require review; provider states remain visible.

### Component prompts

1. **Workbench shell:** "Build the PDF Editor five-mode workbench with a dark 232px mode rail,
   slate document canvas, warm paper page, and evidence inspector. Keep the document dominant."
2. **Candidate review:** "Create a suggested-region overlay using dashed amber geometry,
   synchronized inspector evidence, explicit Apply/Dismiss actions, and a neutral abstention state."
3. **Validation panel:** "Create a Review panel that lists operation lineage, reopen status,
   outside-region metrics, warnings, failures, and unknown checks without claiming clean output."
4. **Provider state:** "Create a capability row with installed/measured/enabled/partial/
   revoked/abstained states, exact reason codes, local-only policy, and a safe fallback."
5. **Template review:** "Create a privacy-first template flow with mapping approval separate
   from profile-value approval, encrypted-local status, revision history, and no silent autofill."
6. **Destructive redaction:** "Create a two-phase redaction UI: reversible red marks first,
   then an explicit commit dialog listing pages, permanence, new-copy behavior, and audit entry."

### Iteration guide

1. Start from the document surface and layout regions before individual atoms.
2. Reuse the token names in this document; do not introduce a second palette.
3. Keep `suggested`, `applied`, `validated`, `blocked`, and `unknown` visually distinct.
4. Test native and browser surfaces against the same intent and safety semantics.
5. Preserve the current prototype geometry before refactoring component internals.
6. Add loading, empty, failed, partial, reader-only, and success states to every major module.
7. Verify all controls at 360px, 820px, 1024px, 1440px, and 1920px widths.
8. Run keyboard and assistive-technology checks before polishing motion.
9. Never infer product capability from a provider API; bind the UI to the capability manifest.
10. Record new design decisions, rejected alternatives, and evidence in project documentation.

### Long-term visual extension rules

- New capability lanes must plug into the same mode, state, evidence, and validation language.
- Companion and hosted processing get a visible locality/provider boundary, never a hidden spinner.
- Collaboration adds identity, presence, conflict, and audit surfaces without changing the source-first model.
- AI assistance is framed as proposed evidence or an operation plan until reviewed and validated.
- The design system is complete only when broad capability increases do not increase ambiguity.

## Adoption notes

The current CSS bridge in `web/design-system.css` is the first implementation of this system.
Future React and native SwiftUI/AppKit work should consume the same token meanings rather than
copying selectors. Preserve the existing semantic DOM and contract modules while migrating.

### Living specimen

Interactive pages that render the type scale, font stacks, and responsive breakpoints at
actual render time are linked from [`docs/design-system-specimen.md`](docs/design-system-specimen.md).
Run them after any typography, color, spacing, or layout change to visually verify the
tokens before committing.

When a capability or provider is not ready, keep the surface present with an honest state.
The visual system must make it easy to understand what is available now, what is being
measured, what requires review, and what will happen on export.
