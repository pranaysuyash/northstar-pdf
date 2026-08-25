# Northstar macOS Landscape and Product Design Direction

**Date:** 2026-08-25
**Status:** Design research synthesis; recommended direction, not a release approval
**Product:** Northstar — local-first native macOS PDF reader/editor
**Research scope:** Current Mac PDF apps, macOS design conventions, Northstar's existing architecture and prototype, and product/UI/UX opportunities.

## Executive recommendation

Northstar should not compete as a smaller Acrobat. The category already has broad suites, lightweight editors, and research-oriented readers. The strongest defensible position is:

> **A calm, native Mac document workbench for completing difficult PDFs without disturbing the source — with reviewable suggestions, reversible edits, local processing, and proof of what changed.**

The product should feel like a serious Mac document editor first, and an intelligent PDF system second. That means:

1. Open into a familiar document window, not a dashboard.
2. Keep the PDF page visually dominant.
3. Make the next safe action obvious without hiding capability.
4. Treat inferred regions as reviewable evidence, never as silent truth.
5. Separate reading posture, completion posture, organization posture, and review posture.
6. Make source preservation, local processing, recovery, and validation visible at the moment they matter.
7. Use native macOS commands, menus, focus behavior, multi-window semantics, sheets, inspectors, and accessibility rather than recreating a web shell in SwiftUI.

The existing Northstar design system is directionally right: document-first, evidence-visible, reversible, calm, and local. The main opportunity is to translate that system into a more recognizably Mac-native product architecture and a more focused first-run flow.

## 1. Landscape map

### 1.1 Apple Preview: the baseline users already understand

Apple's current Preview guide for macOS Tahoe positions Preview as the default document utility: open and inspect files, use a sidebar for navigation, fill forms, add signatures, annotate, rotate/crop/merge, protect with a password, and export. It is intentionally broad and low-friction, but it does not provide true PDF text editing or a deep completion/review model.

**Pattern to borrow**

- Immediate open-and-read posture.
- Familiar sidebar and toolbar behaviors.
- Lightweight markup and signature entry.
- Strong system integration and low cognitive load.
- No account or workflow ceremony for ordinary local files.

**Gap Northstar can own**

- Make static form regions understandable and reviewable.
- Explain exactly what is native, inferred, OCR-derived, applied, validated, blocked, or unknown.
- Provide repeatable completion and recovery without turning the app into a generic suite.

### 1.2 PDF Expert: the polished all-purpose Mac editor

PDF Expert combines reading layouts, full-text search, editing text/images/links, annotations, forms, signatures, OCR, scan enhancement, page organization, conversion, and customization of frequently used tools. Its product language is fast, direct, and consumer-friendly. It also leans into Apple platform continuity across Mac, iPad, and iPhone.

**Signature patterns**

- A compact, high-frequency toolbar for reading and markup.
- Multiple reading modes, including continuous and single-page views.
- Annotation tools kept close to the document rather than buried in a settings surface.
- Page organization as a direct thumbnail manipulation task.
- OCR and scan cleanup presented as practical actions rather than infrastructure.
- User-customizable tool access for repeated work.

**What Northstar should borrow**

- Tool immediacy and low ceremony.
- A visible, fast completion posture.
- Strong direct manipulation for pages and overlays.
- A customizable tool set later, after the command model is stable.

**What Northstar should not copy**

- The broad "anything PDF" promise before fidelity evidence exists.
- Any UI that makes an inferred static region look identical to a native form field.
- A toolbar that becomes the entire product architecture.

### 1.3 Adobe Acrobat: the breadth and workflow incumbent

Acrobat remains the broad suite benchmark: edit, create, convert, organize, fill, sign, review, compare, protect, redact, collaborate, and increasingly use AI and Adobe Express. Current desktop updates also push PDF Spaces, translation, generated cover pages, audio/podcast experiences, and AI assistance.

**Signature patterns**

- Large feature surface organized around task families.
- Strong review/comment/share workflows.
- Multiple document and cloud-oriented states.
- AI increasingly presented as an always-available assistant layer.
- Enterprise and collaboration concepts mixed with ordinary document editing.

**Strategic implication**

Northstar should explicitly avoid a feature-count race. Its advantage is not that it has more buttons; it is that it is more trustworthy for bounded completion. Northstar can make a smaller set of actions materially safer and faster:

- inspect;
- understand;
- complete;
- organize;
- review/export.

Acrobat's breadth is a useful future capability map, not the first UI hierarchy.

### 1.4 PDFgear: simplicity, free access, and AI expectations

PDFgear positions itself as a free Mac editor with local editing, OCR, forms, signatures, page operations, batch conversion, and an AI assistant for summarization, explanation, translation, and question answering. It explicitly distinguishes local editing from online AI/services.

**Signature patterns**

- Start without sign-up or ads.
- All-in-one utility framing.
- AI chat alongside the document.
- Batch actions and direct page manipulation.
- Local versus online processing called out in product copy.

**Northstar opportunity**

The category is teaching users to expect AI assistance. Northstar should support intelligence without allowing an assistant to become an authority. Any future assistant should produce a proposed explanation, evidence card, or operation plan that remains reviewable and source-bound. It should not silently modify the document or blur local and remote processing.

### 1.5 Skim: the high-value lightweight research reader

Skim remains a small, native-feeling Mac PDF reader and note-taker. Its distinctive features include notes, one-swipe highlighting, snapshots, table-of-contents and thumbnail navigation, visual history, reading bar focus, magnification, smart cropping, bookmarks, AppleScript, Spotlight support, LaTeX/PDFSync integration, and note export.

**Patterns to borrow**

- A reader can be powerful without looking like a suite.
- Visual history is a useful recovery/navigation primitive.
- Notes and annotations benefit from a dedicated list view.
- Native automation and system integration are differentiators for Mac power users.
- Focus modes can reduce visual noise during deep reading.

**Northstar opportunity**

Add a lightweight "reading history" and "review queue" concept without adding another permanent navigation rail. Search hits, candidates, comments, and validation findings can all become navigable, source-linked items.

### 1.6 Highlights: annotation-to-output workflow

Highlights focuses on research reading and annotation. Its current product surface includes annotation export to Markdown, HTML, TextBundle, PDF, and other note tools; citation lookup; smart copy; on-device multilingual OCR; and standard annotations that do not lock PDFs into a proprietary container.

**Patterns to borrow**

- An annotation is valuable when it can leave the app in a useful form.
- Smart copy should preserve semantic intent: tables as data, citations as citations, images as images.
- On-device OCR can be a user-facing trust feature, not just a hidden provider.
- Standard PDF annotations preserve interoperability.

**Northstar opportunity**

Make the operation ledger exportable as a human-readable review report, not only a machine contract. A user should be able to send the output PDF with a concise "what changed" report when the document matters.

### 1.7 LiquidText: spatial, context-preserving reading

LiquidText places a workspace beside the document for excerpts, notes, cross-page connections, and ink. It lets users link separated areas while preserving a route back to the original source, and supports multi-document import/export and collaboration.

**Patterns to borrow**

- Keep extracted context adjacent to the source.
- Treat a selected region as a durable object with a backlink to its page and bounds.
- Support multi-region review without forcing the user to repeatedly search the document.
- Use spatial layout when the task is comparison or synthesis rather than simple reading.

**Northstar opportunity**

Create a temporary, task-scoped Review tray or Evidence tray rather than a permanent whiteboard. It can collect selected fields, suggested regions, validation findings, and source snippets for a completion session, then disappear when the task is complete.

### 1.8 MarginNote: turning reading into structured knowledge

MarginNote connects PDF/EPUB reading with excerpts, notes, mind maps, outlines, flashcards, global search, bidirectional links, and review. Its current messaging emphasizes a single highlight becoming a card, a mind-map node, and later a review item.

**Patterns to borrow**

- A source selection can have multiple useful projections.
- Bidirectional links reduce context loss.
- Workflows should be designed around real user postures, not a giant feature list.
- Immersive mode can remove chrome when the task is reading or recall.

**Northstar opportunity**

Use one canonical source-bound object for a detected region or operation, then project it into:

- page overlay;
- inspector detail;
- completion queue;
- operation history;
- export/review report.

Do not create separate unsynchronized objects for each surface.

## 2. Design patterns that are now table stakes

### Table-stakes patterns to include

- Standard document windows with multiple independent documents.
- Open, New Window, Close, Export/Save Copy, Print, Share, Find, and Settings in the menu bar.
- Sidebar with thumbnails, outline, bookmarks, search results, and review items.
- Document canvas with continuous, single-page, and two-page modes.
- Search with exact result identity, next/previous navigation, and visible result count.
- Fast keyboard navigation and standard shortcuts.
- Native file import/export and security-scoped file access.
- Annotations, signatures, form filling, page organization, OCR, and structured warnings as separate capability lanes.
- Visible dark mode support and accessible focus behavior.
- Undo/redo that restores both the document action and the user's working context.
- A clear distinction between source content, annotation/overlay, and destructive operation.

### Patterns that are differentiators for Northstar

- Review-first suggestions for static regions.
- Explicit source identity and local processing boundary.
- A source-bound evidence explanation for every inferred target.
- New-copy export with reopen validation and preservation findings.
- Honest provider states: available, partial, reader-only, blocked, abstained, failed, unknown.
- Recovery as a first-class workflow rather than a hidden autosave.
- Privacy preflight before export or sharing.
- Templates that remember reviewed mappings without silently storing profile values or auto-applying them.
- A compact, source-linked operation report users can inspect or share.

## 3. Recommended Northstar information architecture

### App archetype

**Document-based editor with independent document windows and a temporary task inspector.**

This is not a library-first app and not a single-window utility. Finder/Open With, recent documents, multiple independent windows, and document-scoped recovery should feel native. A future library or template browser can exist as a secondary surface, but it should not replace the document window as the primary experience.

### Window model

Each document window owns:

- immutable source artifact and source digest;
- derived inspection;
- operation ledger and undo/redo;
- view session: page, zoom, display mode, selection, search, focus;
- recovery identity and export history.

App-scoped services own only shared concerns such as settings, provider registry, recent documents, and file coordination.

### Sidebar model

Use a single macOS sidebar with two compact groups rather than a permanent five-item dark rail:

**Document**

- Thumbnails
- Outline
- Search results
- Attachments / links (when present)

**Work**

- Complete
- Organize
- Review

The current five-mode model remains valuable as product language and state vocabulary, but it should not force five large navigation buttons into every window. Use a top-level posture selector in the toolbar or inspector, while the sidebar remains oriented around document navigation and active work.

Apple's current HIG supports hiding/showing the sidebar, letting users customize its contents when practical, and automatically collapsing it as a window narrows. Northstar should preserve those behaviors rather than implementing a fixed-width web rail.

### Inspector model

The trailing inspector should be context-sensitive and relatively quiet:

- no selection: document facts and next safe actions;
- native field selected: field value, required/format state, field provenance;
- suggested region selected: evidence, rationale, candidate type, review actions;
- operation selected: source binding, scope, reversibility, undo, validation;
- export review: validation findings, output identity, warnings, and recovery path.

Avoid showing every system fact at once. Keep raw coordinates, provider IDs, hashes, and diagnostic detail behind a disclosure section or a dedicated "Evidence details" sheet.

## 4. Recommended visual direction

### Keep

- Warm paper against a cool neutral canvas.
- Dark command frame only where it helps frame global context.
- Restrained action blue.
- Amber for review-required evidence, green only for validated outcomes, red only for destructive/failure semantics.
- Thin rules, light shadows, minimal decorative surfaces.
- System typography for controls and dense information.

### Change for native Mac

- Prefer system toolbar materials and standard controls over a fully custom dark toolbar.
- Let the title bar and toolbar participate in the system appearance.
- Use Liquid Glass only for the navigation/controls layer when the deployment target supports it; keep the PDF page and inspector content opaque and stable.
- Use SF Symbols with system accent behavior instead of fixed-color iconography except where a semantic exception is deliberate.
- Replace large persistent mode cards with compact segmented or toolbar posture controls.
- Avoid a permanent "dashboard" feeling. The PDF should remain the largest uninterrupted region.

### Visual hierarchy

```text
system window chrome
  -> compact toolbar / posture selector
    -> document navigation sidebar
      -> PDF page canvas (dominant)
        -> contextual inspector
          -> sheets / dialogs for focused or risky operations
```

## 5. Core flows

### Flow A: First open

1. User opens a PDF from Finder, Open With, or Cmd-O.
2. Northstar admits the document and immediately shows the first readable page.
3. A compact status line says: `Local · source preserved · inspecting`.
4. Inspection progresses in the background or in a calm, cancellable reveal; reading is never blocked longer than necessary.
5. When findings arrive, show a non-modal banner or inspector summary:
   - `3 native fields found`;
   - `7 suggested regions to review`;
   - `OCR available for 2 scanned pages`;
   - `No editable targets found`.
6. Offer `Start Completing` only when there is a clear next action. Never auto-switch the user into an editing mode merely because fields exist.

**Design goal:** the first ten seconds should feel like Preview, then reveal Northstar's deeper value without a mode explosion.

### Flow B: Read and search

- Cmd-F focuses a single search field in the toolbar or sidebar.
- Search results become a navigable list with page number, snippet, extraction provenance, and exact/approximate/unavailable projection state.
- Cmd-G and Shift-Cmd-G move through stable result IDs.
- Selecting a result changes the page only when intentional; scrolling and unrelated inspector updates must not fight the user's viewport.
- A reading-focus option hides the inspector and minimizes chrome without hiding the standard escape path.

### Flow C: Complete a document

1. User chooses `Complete` or clicks a visible native field.
2. A progress indicator shows `2 of 9 completed`, but distinguishes native fields from reviewed suggestions.
3. Tab moves in deterministic reading order; Shift-Tab reverses.
4. Native fields are blue/neutral and directly editable.
5. Suggested regions are amber/dashed and require a short review step.
6. The inspector explains why a suggestion exists, shows evidence sources, and offers `Apply`, `Edit target`, `Dismiss`, and `Inspect evidence`.
7. After apply, the target becomes `Applied` and remains undoable.
8. A completion tray can show `Next`, `Previous`, `Dismissed`, and `Needs review` without making the user repeatedly scan the page.
9. When the user finishes, `Review changes` becomes the next safe action.

### Flow D: Place an overlay or signature

- Start from the contextual toolbar or a direct page action.
- Show a lightweight placement preview on the page.
- Use a sheet for creating the asset (text, signature, image, stamp), not for every placement.
- Keep the placement itself direct and reversible.
- State explicitly whether the result is a visual overlay or a cryptographic signature.
- For saved signatures, require explicit save and keep storage policy visible.

### Flow E: Organize pages

1. Choose `Organize` from the toolbar posture menu or sidebar.
2. The left sidebar expands into a larger thumbnail grid/filmstrip; the document canvas remains visible when useful.
3. Drag to reorder; use context menu and toolbar for rotate, insert, extract, delete, merge, split, and page labels.
4. Treat operations as a staged plan with visible order changes.
5. Keep destructive page deletion behind a deliberate confirmation that lists affected pages and output behavior.
6. Return to the prior reading page after the operation unless the user intentionally selects a new page.

### Flow F: Review and export

1. Choose `Review` or click `Review changes`.
2. Present a compact change summary:
   - operations by page;
   - native fields versus overlays;
   - source digest and output identity;
   - validation status;
   - warnings, blockers, and unknown checks.
3. Primary action: `Export Copy…`.
4. Export creates a new file and reopens it through the validation pipeline.
5. Show `Validated`, `Validated with warnings`, or `Validation failed` as distinct outcomes.
6. Every finding has a next action: inspect, retry, export anyway with explicit acknowledgement, or keep working.
7. Offer `Save report…` beside the output file, not as a hidden diagnostic.

### Flow G: Recovery

If a recoverable session exists for the same source digest:

- show a non-blocking recovery banner on open;
- state the operation count and last activity date;
- offer `Restore session`, `Open clean source`, and `Inspect recovery details`;
- never silently apply recovered edits;
- if the source digest differs, explain that the session is bound to another source and offer a safe branch rather than replaying.

## 6. Command map for a good Mac citizen

### File

- New Window
- Open…
- Open Recent
- Close Window
- Export Copy…
- Export Review Report…
- Print…
- Share
- Revert View / Restore Session where applicable

### Edit

- Undo / Redo
- Cut / Copy / Paste where the focused control supports it
- Select All
- Add Text
- Add Annotation
- Add Signature
- Dismiss Suggestion
- Restore Dismissed Suggestion

### View

- Show/Hide Sidebar
- Show/Hide Inspector
- Single Page / Continuous / Two Pages
- Fit Page / Fit Width / Actual Size
- Zoom In / Zoom Out
- Rotate View Left / Rotate View Right
- Enter Reading Focus

### Navigate

- Find…
- Find Next / Previous
- First / Previous / Next / Last Page
- Go to Page…
- Next Field / Previous Field in Complete posture
- Next Review Item / Previous Review Item

### Window

- New Window
- Move Tab to New Window when tabs are supported
- Bring All to Front
- Standard macOS window commands

### Help

- Northstar Help
- Completion and evidence vocabulary
- Export validation explanation
- Keyboard shortcuts
- Privacy and local-processing explanation

Menu items should remain discoverable and become disabled with a reason when unavailable. Do not hide a capability because a provider is absent; expose `Reader only`, `Blocked`, `Abstained`, or `Needs review` with a fallback.

## 7. Accessibility and interaction requirements

Treat native accessibility as a release gate, not a polish pass.

- Every toolbar and inspector action has a spoken label, state, and hint.
- Candidate overlays have a synchronized accessible list representation; the canvas is not the only way to discover them.
- VoiceOver can announce current document, page, selected object, evidence state, validation severity, and next action.
- Full Keyboard Access can complete a document without a mouse.
- Tab order follows the user's task order, not view implementation order.
- Direct manipulation always has a menu/keyboard alternative.
- No status is communicated by color alone; pair color with label, icon, outline, or pattern.
- Respect Increase Contrast, larger text, reduced motion, and system accent colors.
- Restore focus after sheets, alerts, password prompts, and export panels.
- Keep controls at or above native macOS sizing guidance; do not squeeze high-frequency actions into tiny custom buttons.

## 8. Product language and trust semantics

Use the following vocabulary consistently:

| State | User-facing meaning | Visual treatment |
|---|---|---|
| Native field | Existing interactive PDF field | Blue/system accent, solid outline |
| Suggested | Product inference that needs review | Amber, dashed outline, explanation |
| Applied | User-approved reversible operation | Strong action outline, undo affordance |
| Validated | Output passed named checks | Green only with evidence basis |
| Reader only | Can inspect but not safely mutate in current lane | Neutral gray |
| Abstained | System deliberately refused to guess | Neutral/amber, reason and fallback |
| Blocked | Capability cannot run under current provider/permissions | Danger/neutral according to cause, recovery path |
| Failed | An attempted action did not complete safely | Danger, specific finding and retry/undo path |
| Unknown | Not measured or not supported by current evidence | Neutral, never implied as pass |

Avoid the word `confidence` unless it is explicitly an evidence-strength score or calibrated metric. Prefer `Evidence strength`, `Why this was suggested`, or `Review required`.

## 9. Architecture-to-UX alignment

The UI should map directly to the product's existing source-of-truth model:

```text
DocumentArtifact       -> title, source identity, privacy/locality status
DocumentInspection     -> document facts, fields, candidates, warnings
OperationLedger        -> undo, review list, provenance, change summary
ViewSession            -> page, zoom, display mode, focus, search selection
ExportProjection       -> output identity, validation report, warnings
```

Important consequences:

- Reader rotation remains view-only unless invoked as an explicit document operation.
- Transient highlights remain outside the PDF document model.
- Export never reads view state as document mutation.
- A window must own its document session; no cross-window undo/search leakage.
- Provider capability state belongs in the inspector and review surfaces, not as hidden disabled controls.
- Every risky action should answer `What changes?`, `What does not change?`, `Why is this allowed?`, and `What can I do if it fails?`.

## 10. Recommended next design/implementation sequence

### P0: Native shell correctness before visual polish

1. Prove independent document windows and focused command routing.
2. Finish lifecycle language for Open, Close, New Window, recovery, and export-only semantics.
3. Keep the canonical source/session/ledger/view/export boundaries explicit.
4. Add native runtime evidence for keyboard, VoiceOver, reduced motion, search projection, and overlay non-persistence.

### P1: Make the current product feel like a Mac app

1. Convert the current toolbar into a standard, grouped macOS toolbar with a compact posture selector.
2. Use a native sidebar for thumbnails, outline, search, and work queues.
3. Move advanced evidence and diagnostics behind disclosure or a sheet.
4. Add a real contextual inspector state model rather than rendering every section at once.
5. Preserve the current design tokens but let system materials, accent colors, and window chrome do more of the work.

### P2: Make completion the signature experience

1. Build a dedicated completion queue with exact progress and next-field navigation.
2. Add an evidence tray for suggested regions and review findings.
3. Add explicit `Review changes` and `Export Copy…` transitions.
4. Make recovery and validation readable to non-technical users.
5. Add a human-readable export report.

### P3: Expand the moat without expanding ambiguity

1. Add page organization and compare as typed operation workflows.
2. Add local OCR and scan cleanup with visible provenance.
3. Add templates with stale/revoked/mismatch recovery states.
4. Add AI only as source-bound proposals, summaries, or operation plans.
5. Add a second provider only after the native shell and preservation gates are runtime-proven.

## 11. Anti-patterns to reject

- A permanent dashboard or five-card mode launcher after a document is open.
- A fixed dark custom shell that fights macOS window materials and system accent colors.
- A toolbar that contains every capability and collapses at compact widths.
- Treating static suggestions as equivalent to AcroForm fields.
- Silent autofill or silent template application.
- A generic green checkmark for detector confidence.
- Calling an overlay a redaction, a visual signature a digital signature, or a metadata scan a sanitization proof.
- Hiding blocked capabilities instead of explaining them.
- Modal dialogs for routine page navigation or field completion.
- A PDF canvas that is only mouse-accessible.
- A viewer that jumps pages because an unrelated SwiftUI state changed.
- Export success defined only by reopenability.
- A separate web-like navigation system that duplicates the Mac menu bar.

## 12. Open questions to validate with user observation

These should be answered through observed tasks, not preference debate:

1. Do users understand the difference between a native field and a suggested region after one explanation?
2. Does a completion queue reduce time-to-finish versus direct page scanning?
3. Does the evidence tray help repeated paperwork or add clutter?
4. Do users prefer a single `Complete` posture or explicit `Fill`, `Sign`, and `Edit` tools in the toolbar?
5. How often do users need page organization while completing a form?
6. Which validation findings change behavior, and which are too technical to surface by default?
7. Is a human-readable export report valuable enough to make it a primary output?
8. Which recurring templates are frequent enough to justify the extra review step?
9. When users ask for AI help, do they want explanation, extraction, or an operation plan?
10. Does the dark-shell prototype feel native enough in a real macOS window, or does the system toolbar/window chrome earn more trust?

## 13. Sources

### Current product sources

- Apple Preview User Guide for Mac, current macOS Tahoe guide: https://support.apple.com/guide/preview/welcome/mac
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Apple HIG — Sidebars: https://developer.apple.com/design/human-interface-guidelines/sidebars
- Apple HIG — Menus: https://developer.apple.com/design/human-interface-guidelines/menus
- Apple HIG — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- PDF Expert for Mac: https://pdfexpert.com/
- PDF Expert Mac App Store listing: https://apps.apple.com/cn/app/pdf-expert-edit-sign-pdfs/id1055273043?l=en-GB&mt=12
- Adobe Acrobat feature overview: https://www.adobe.com/acrobat/features.html
- Adobe Acrobat desktop updates: https://helpx.adobe.com/acrobat/desktop/whats-new/whats-new-acrobat-desktop.html
- PDFgear for Mac: https://www.pdfgear.com/pdfgear-for-mac/
- Skim: https://skim-app.sourceforge.io/
- Skim current project listing: https://sourceforge.net/projects/skim-app/
- Highlights: https://highlightsapp.net/
- LiquidText features: https://www.liquidtext.net/features
- MarginNote: https://www.marginnote.com/
- MarginNote Mac listing: https://apps.apple.com/cn/app/marginnote-3/id1423522373?l=en

### Northstar project sources

- `DESIGN.md` — current cross-platform visual system and five-mode product journey.
- `docs/market-strategy.md` — local-first completion wedge and positioning.
- `docs/pdf-feature-frontier.md` — capability taxonomy and implementation ordering.
- `docs/audits/macos-app-design-review-and-todo-2026-08-24.md` — native shell findings, source-of-truth model, command gaps, accessibility and runtime evidence gates.
- `docs/pdf-ecosystem-deep-research-2026-08-25.md` — provider, OCR, engine, licensing, and native/web capability research.
- `Sources/PDFEditorApp/ContentView.swift` — current native shell, toolbar, reader, inspector, completion, signature, and recovery UI.
- `Sources/PDFEditorApp/AppCommands.swift` — current focused command routing and menu surface.
- `Sources/PDFEditorApp/AppModel.swift` — current session, operation, recovery, completion, template, and provider state.
- `web/index.html` and `web/design-system.css` — current Northstar five-mode prototype and visual token implementation.

## Bottom line

Northstar should be the Mac PDF app users trust when the document matters and the cost of a bad edit is high. The winning experience is not more chrome or more AI. It is a native, quiet, source-first workbench that makes difficult completion tasks feel obvious, keeps every inference reviewable, and shows exactly what will leave the session.
