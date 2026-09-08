# Native macOS Visual Grammar and Home Surface Exploration

Date: 2026-09-01
Status: active implementation companion
Scope: PDF Editor native macOS app

## Intent

Make PDF Editor feel contemporary and inviting without turning it into a web
landing page. The app should be clean because hierarchy is strong, not because
the interface is empty. Animation, infographic structure, and illustration are
allowed when they explain state, reveal capability, or make the next useful
action easier to recognize.

The product boundary remains local-first PDF reading and editing. Visual
novelty must not invent document facts, imply unsupported capabilities, or
replace the menu bar, keyboard commands, accessibility tree, or ordinary
window behavior.

## Source Evidence

### Platform evidence

- Apple macOS layout guidance prioritizes visual hierarchy, reading order,
  adaptive layouts, progressive disclosure, and resizable windows. Source:
  https://developer.apple.com/design/human-interface-guidelines/layout
- Apple sidebar guidance treats the sidebar as a broad peer-level navigation
  surface, supports hiding it from View, recommends a shallow hierarchy, and
  expects content to extend beneath the sidebar when appropriate. Source:
  https://developer.apple.com/design/human-interface-guidelines/sidebars?changes=_8
- Apple window guidance assumes several apps and windows may be visible and
  that users move, resize, minimize, and reveal windows. Source:
  https://developer.apple.com/design/human-interface-guidelines/windows
- Apple toolbar guidance keeps the top bar sparse, makes toolbar actions
  available through the menu bar, and treats overflow/customization as part of
  the design. Source:
  https://developer.apple.com/design/human-interface-guidelines/toolbars?changes=la

### Product and practice evidence

- The requested macOS design skill emphasizes a system tool that appears when
  needed, progressive disclosure, keyboard parity, drag and drop, light/dark
  design, and micro-animation as state feedback. Installed locally at
  `/Users/pranay/.codex/skills/macos-design` from
  https://github.com/ceorkm/macos-design-skill
- A curated macOS app survey highlights Raycast's keyboard-first command
  model, Obsidian's distraction-free workspace, and local-first utility
  patterns. Source:
  https://switowski.com/blog/my-favorite-macos-apps-2024/
- The macOS app design discussion repeatedly values native behavior, coherent
  motion, Craft's visual polish, CleanShot's direct manipulation, and
  CleanMyMac's legible simplicity, while also warning that visual polish must
  not hide questionable product behavior. Source:
  https://www.reddit.com/r/macapps/comments/174ntjz/best_designed_best_looking_mac_apps/
- The supplied galleries and app roundups are inspiration leads, not product
  truth. They are useful for visual vocabulary and interaction discovery, but
  their claims require validation against Apple's platform conventions and
  this repository's actual capability contracts:
  https://dribbble.com/tags/mac-app
  https://www.seesaw.website/category/mac-os-apps
  https://macautomationtips.com/my-20-favorite-apps-2025/
  https://setapp.com/app-reviews/best-mac-apps
  https://woorkup.com/best-mac-apps/
  https://apps.apple.com/in/mac/discover

## First-Principles Findings

### 1. Clean means low ambiguity, not low information

The main question on launch is "what can I do with a PDF right now?" The home
surface should answer with a clear primary action, a small set of honest
creation paths, and continuity from files the user actually opened. Decorative
elements should sit behind that decision, not compete with it.

### 2. Motion must describe a state transition

Use motion for opening, dropping, selecting, preparing, validating, and
revealing. Do not continuously animate a decorative hero. Every animation must
have a reduced-motion outcome and should never be the only way to understand
the state.

### 3. Infographics must be evidence views

For an editor, useful visual summaries include page count, text presence,
form-field presence, annotation state, export readiness, and privacy/preflight
state. These values must come from `DocumentInspection`, `ExportReviewReceipt`,
or another named authority. Never use invented health scores, fake progress,
or generic "AI-powered" badges.

### 4. Illustration should be product-shaped

The home illustration should suggest a document moving from source to review
to separate export copy. It should use native SwiftUI shapes and SF Symbols,
remain legible in light and dark appearances, and expose an accessibility label
that states its meaning. A generic sparkle logo is not enough evidence of what
the app does.

### 5. The Mac window is a workspace, not a mobile screen

Keep global actions in the toolbar/menu bar, preserve window resizability and
multiple-window semantics, and let the central document remain the dominant
surface once a file is open. The home surface can be more editorial because
there is no document competing for attention, but it must still behave like an
app workspace with real commands and drop targets.

### 6. Contextual menus should be adaptive but stable

The user's contextual-menu proposal is directionally right: while scrolling,
reader actions should dominate; with a text, form, annotation, image, or page
target, the available actions should change. The stronger rule is evidence
gating, not raw behavior tracking. History may rank already-valid commands, but
selection, permissions, and document capability must determine validity. Menu
items need stable recovery paths through the toolbar, menu bar, Command-K, and
keyboard shortcuts.

## Visual Grammar

### Composition

- Home: unframed central composition with a document-shaped illustration,
  primary Open action, compact creation rail, and a recent-document band only
  when real recent entries exist.
- Open document: sidebar/page rail, central canvas, optional inspector. Avoid
  adding a permanent dashboard layer over the document.
- Empty home: hide the document window toolbar entirely; keep the standard
  titlebar/menu bar and let the welcome workspace own admission and creation.
- Secondary information: inspector or sheet for detail; no cards inside cards.
- Toolbars: sparse, with icon and label only when the command is ambiguous.
- Repeated files and capabilities may use compact cards or rows; page sections
  remain unframed layouts.

### Color and depth

- Use system semantic colors and accent color only for actions, selection,
  focus, and measured status.
- Keep the canvas and document content opaque and readable.
- Reserve material/vibrancy for the toolbar, sidebar, popovers, and transient
  status surfaces.
- Design light and dark appearances independently. Do not invert a palette.
- Avoid a single purple/blue gradient language, decorative orbs, and large
  atmospheric backgrounds.

### Type and controls

- Use native system typography and semantic roles.
- Make the primary action visually clear without turning the home surface into
  a marketing hero.
- Preserve mouse/trackpad precision and keyboard access; tooltips are for
  unfamiliar icon-only controls.
- Every primary home action must map to an existing menu/command path.

## Motion, Illustration, and Infographic Matrix

| Element | Purpose | Allowed motion | Evidence source | Reduced motion |
| --- | --- | --- | --- | --- |
| Document illustration | Orient the user to the product | One-time settle on appear | Product meaning only | Static illustration |
| Drop target | Show accepted drag state | Border/scale transition on drag enter | Accepted UTType | Immediate state change |
| Recent file row | Confirm selection/opening | Short insertion or press feedback | `recentDocuments` | Immediate |
| Capability strip | Summarize a loaded PDF | No ambient motion; update on state change | `DocumentInspection` | Same semantic content |
| Export readiness | Explain why export is/is not available | Progress only while work is active | `ExportReviewReceipt` | Text/status only |
| Context menu | Reduce search cost | None required | Adaptive policy input | Same menu |

## Explicit and Implicit Task Inventory

### Implement now

- [x] Preserve the evidence-gated adaptive command policy and use history only
  for ranking valid actions.
- [x] Show bounded denial explanations in the native inspector.
- [x] Persist the value-minimized export review receipt.
- [x] Make successful PDF opens populate the local recent-document surface.
- [x] Make the home surface show real open/create/drop paths with a
  product-shaped illustration and reduced-motion behavior.
- [x] Make the whole welcome workspace a PDF drop target; keep creation paths
  inside the same surface and move blank-page-size choice next to New blank.
- [x] Keep the evidence-backed capability strip in the existing inspector
  passport instead of duplicating it over the canvas.
- [x] Partition the native toolbar into navigation, history, primary export,
  workspace, secondary intent/view, and status regions while retaining menu-bar
  recovery.
- [x] Make recovery status action-first with bounded Inspect details and
  explicit Discard confirmation, while keeping persisted recovery authority in
  `AppModel`.
- [x] Give the home surface explicit wide/narrow compositions with
  `ViewThatFits`, and honor reduced motion for home drop-state and recovery
  detail feedback.
- [x] Hide the document toolbar when no PDF is open; preserve menu-bar recovery
  and restore the document or skim toolbar after admission.
- [x] Record contextual command history only after the native adapter accepts
  execution; unsupported image/object and canvas page-organization cases
  abstain instead of recording a false success.
- [x] Add focused recovery coverage for recent history.
- [ ] Add native UI verification for home actions, drop state, keyboard
  activation, and accessibility labels.

- [x] Give the redesigned home actions stable accessibility identifiers and
  keep replacement admission transactional so invalid or gated recent-file
  choices preserve recovery state.

### Explore and document before broad implementation

- [x] Use security-scoped bookmark records for successful user-owned opens and
  in-place drops, with legacy URL compatibility and explicit re-selection when
  a bookmark cannot resolve without UI.
- [ ] Verify moved, revoked, inaccessible, and reselected recent-file states in
  a packaged sandboxed app. The source now shows an explicit Locate action for
  stale or missing entries and only adopts a replacement after successful
  admission; packaged bookmark lifecycle and temporary-provider identity
  behavior remain open.
- [ ] Define the native visual token set for spacing, semantic color, type,
  material, elevation, and motion durations.
- [ ] Map every major action to menu-bar command, toolbar exposure, shortcut,
  contextual-menu eligibility, and accessibility label.
- [ ] Evaluate whether a document capability strip belongs in the home surface,
  inspector, or export review sheet for each user task.
- [ ] Compare `DocumentBrowserView` corpus indexing with `recentDocuments` so
  two local histories do not become competing sources of truth.
- [ ] Validate light/dark, high-contrast, reduced-motion, narrow-window,
  split-view, multi-window, and VoiceOver behavior on a real packaged app.
- [ ] Observe the home-to-document-to-home toolbar transition in the packaged
  app, including skim mode, close/reopen, menu recovery, and narrow resize.
- [ ] Research licensed/provenance-safe illustration and icon assets if native
  shapes stop being sufficient; do not copy gallery screenshots or branding.

### Release and doctrine gates

- [ ] Close the unresolved full-suite Swift Testing run and distinguish a test
  failure from a hanging or resource-bound lane.
- [ ] Resolve the remaining profile-writer, provider, contract-to-view, runtime
  accessibility, output-identity, codesign, notarization, and packaging gates
  in the existing audit rather than treating a visual pass as release proof.
  Extracted-page and authored-metadata-scrubbed copy writers now have focused
  T2 validation; edited/merge governance, form-aware flattening, and packaged
  export observation remain open.
- [ ] Record screenshots and accessibility trees as evidence, with command,
  fixture, viewport/window size, appearance, and motion setting.

## Implementation Plan

1. **Home continuity**: repair recent-document recording and bounded storage;
   show only existing/reopenable local URLs and preserve error handling.
2. **Home composition**: replace the generic welcome block with a responsive
   native home workspace. Keep Open as the default action, expose creation
   choices, make the whole workspace drop-accepting, and keep the page-size
   choice attached to New blank.
3. **Product illustration**: build a small native document-flow illustration
   from semantic shapes and symbols. Add one-shot motion and a static reduced-
   motion variant.
4. **Evidence strip**: retain the existing `DocumentCapabilityPassport` in the
   inspector as the single compact capability authority; do not duplicate it
   over the canvas.
5. **Contextual refinement**: apply the same visual grammar to adaptive menus,
   inspector denial, export review, and command palette so progressive
   disclosure is consistent rather than screen-specific.
6. **Native shell refinement**: keep toolbar placements semantic and bounded;
   move low-frequency utilities into menus and verify collapse behavior at
   narrow widths before adding more controls.
7. **Verification**: compile/package, run focused tests, inspect accessibility,
   exercise keyboard/drop/resize/appearance paths, and update the audit ledger
   with evidence tiers and residual gaps.

## Decision

Proceed with the home continuity and home composition slice first. It is a
bounded user-visible improvement that can be verified locally and does not
require inventing a new document model. Defer a broad visual redesign until
the home, canvas, inspector, command palette, and contextual menu share the
same semantic tokens and evidence rules.
