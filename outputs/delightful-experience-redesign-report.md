# PDF Editor Delightful Experience Redesign

**Date:** 2026-08-25
**Product:** Northstar PDF Editor, local-first native macOS and browser surfaces
**Review type:** Static UX and interaction audit with implementation-oriented recommendations

## Executive summary

The product already has a strong trust foundation: source-bound operations, review-first suggestions, reversible edits, explicit provider states, export validation, local processing, and broad accessibility semantics in the web lane. The satisfaction problem is not missing capability. It is that users must currently interpret too much system machinery before they feel momentum.

The central redesign direction is **reassuring precision**:

- Make the next safe action obvious without hiding evidence.
- Turn status text into visible progress, confirmation, and recovery.
- Treat uncertainty as a calm review invitation, not as a confidence score users must decode.
- Add motion only where it explains a state change: focus, selection, progress, validation, and recovery.
- Keep the tone professional and warm. Do not add consumer-app confetti, sound, gradients, or decorative gamification to a high-trust document tool.

The highest-impact, lowest-structure changes are:

1. A clearer open-to-first-action experience with loading, locality, and capability reassurance.
2. A candidate-review loop that focuses the page, explains evidence, and supports rapid accept/dismiss/undo.
3. A staged export-validation experience that turns waiting and validation into a legible finish line.
4. Persistent recovery feedback: autosave state, undo toast, restore paths, and dirty-work protection.
5. Progressive disclosure for template, provider, privacy, and validation detail.
6. Native/web interaction parity and a real keyboard/VoiceOver proof lane.

## Scope and evidence boundary

This review covers the existing web prototype and native SwiftUI/AppKit shell. It is based on static inspection of source, design documentation, tests, and existing audit records. It does not claim live-user behavior, production satisfaction uplift, or device-level animation performance.

**Observed evidence:**

- The canonical journey is `Reader -> Understand -> Complete -> Organize -> Review` (`DESIGN.md:21-38`).
- The browser exposes file import, navigation, search, candidate review, overlays, undo, export, validation, templates, privacy preflight, and provider states (`web/index.html:124-303`).
- Browser operation feedback is primarily status text such as `Queued native field fill`, `Dismissed the suggested area`, and `Exporting with pdf-lib and validating with PDF.js` (`web/app.js:2062, 2230, 3625`).
- Candidate rows display evidence and labels such as `High`, `Medium`, or `Low` confidence (`web/app.js:1908-1915`; `Sources/PDFEditorApp/ContentView.swift:1978-1982`).
- The browser inspector contains a large number of template, vault, sync, backup, restore, health, and deletion controls in one review card (`web/index.html:252-276`).
- Candidate dismissal does not currently call `saveWebSession`, unlike edits and undo (`web/app.js:2216-2233`). This is a concrete persistence/recovery gap to verify and fix.
- The existing project audit records native accessibility and keyboard interaction as not yet established, including mouse-oriented manual placement and missing native VoiceOver/reduced-motion proof (`docs/audits/macos-app-design-review-and-todo-2026-08-24.md:351-383`).
- Current static suggestion quality is explicitly uncertain: the documented reviewed baseline is a 21.21% label-associated recall proxy and 11.96% labeled-candidate precision proxy (`docs/implementation-status.md:219-225`). This makes confidence language especially important.

## Design health score

Scores are static-review judgments, not user-test measurements. `4` means genuinely excellent and consistent across both surfaces.

| Heuristic | Score / 4 | Key issue |
|---|---:|---|
| Visibility of system status | 3 | Status exists, but important changes are often compressed into a single line or dense inspector text. |
| Match to real-world language | 3 | PDF concepts are mostly accurate, but provider and evidence terminology still leaks into primary actions. |
| User control and freedom | 3 | Undo, dismiss, restore, and source preservation are strong; file replacement and session recovery need clearer protection. |
| Consistency and standards | 2 | Web and native express similar semantics with different interaction models and different proof strength. |
| Error prevention | 3 | Review gates and fail-closed contracts are strong; the UI does not always preview consequences before the action. |
| Recognition over recall | 2 | Users must remember what `confidence`, `review-only`, lifecycle states, and validation codes mean. |
| Flexibility and efficiency | 3 | Keyboard commands and rapid candidate navigation exist, but the highest-frequency loop is not optimized visually. |
| Aesthetic and minimalist design | 2 | The document-first system is coherent, but toolbar density and the template control wall increase cognitive load. |
| Error recovery | 3 | Recovery primitives exist; feedback and persistence are not consistently visible at the moment of risk. |
| Help and documentation | 2 | Hints are present, but contextual “what happens next” guidance is distributed rather than staged. |
| **Total** | **26 / 40** | **Solid safety foundation; moderate interaction friction and low emotional momentum.** |

## The core experience diagnosis

### What is already working

1. **Trust is encoded in the product model.** Reversible operations, source immutability until export, explicit validation, and provider abstention are rare strengths. Keep them.
2. **Evidence is adjacent to actions.** Candidate evidence, geometry, permissions, and validation are not hidden in a separate help system.
3. **The visual direction is distinctive and appropriate.** Warm paper, slate canvas, dark command frame, and restrained blue action language support a precise workbench rather than generic SaaS styling.

### Main friction pattern

The interface often makes the user perform the work of translating internal state into a decision:

`technical state -> user interpretation -> action`

The target is:

`clear decision -> safe action -> concise evidence on demand`

This does not mean hiding evidence. It means putting a plain-language decision summary first and the technical basis behind a disclosure or secondary view.

## Recommendations by key touchpoint

### 1. Open, import, and first readiness

**Current friction:** The browser begins with a file input in a dense toolbar and uses a generic status line. A new file load resets the session state in `loadPdf`; native has stronger admission and dirty-work protection than the browser. The user does not immediately see what the product will do locally or what capability state to expect.

**Before:** `PDF` file picker -> wait -> `Loaded N page(s).` The document appears, but the first useful action is not framed.

**After:** Use a calm welcome/open surface with one primary action, three small reassurance facts, and a short staged load state:

- **Open a PDF** as the primary action; drag-and-drop as a secondary affordance.
- `Processed on this device` / `Source unchanged until export` / `Review before applying` as compact trust cues.
- Loading sequence: `Reading document` -> `Mapping pages` -> `Finding editable areas` -> `Ready to review`.
- If suggestions are available, surface `12 areas to review` with a direct `Start review` action.
- Before replacing a document with pending operations, show `Keep current work` / `Discard pending work` explicitly, matching native behavior.

**Micro-interaction:** Fade the document shell in after page 1 is usable, then reveal the inspector summary. Do not block interaction on later page thumbnails. Use a 180-240ms opacity/translate transition; reduced motion uses instant state changes.

**Expected impact:** High improvement to first-session confidence and time-to-first-edit; lower abandonment caused by uncertainty about whether the document is loaded, private, or editable.

**Feasibility:** High. Mostly existing DOM regions, status state, and load-generation hooks; no feature restructuring.

**Suggested surfaces:** `web/index.html`, `web/app.js`, `web/design-system.css`, `Sources/PDFEditorApp/ContentView.swift`.

---

### 2. Mode choice and task orientation

**Current friction:** The five-mode rail is conceptually strong, but states such as `Partial`, `Reader only`, and `Ready` make users decode product capability before acting. The rail can feel like a capability inventory instead of a guided work path.

**Before:** Five modes with technical state labels and a status sentence such as `Reader is the active document surface.`

**After:** Keep the five modes, but add a single contextual “next safe action” beneath the active mode:

- `Reader`: `Find a page or search for text`.
- `Understand`: `Review 12 suggested areas`.
- `Complete`: `3 of 12 reviewed`.
- `Review`: `Export a new copy when all checks pass`.

Display capability state as a quiet secondary line: `Available`, `Review required`, `Reader only`, or `Unavailable here`. Add a small progress indicator only when a workflow is active; never imply that a partially implemented provider is complete.

**Micro-interaction:** On mode change, keep the document canvas stable and animate only the inspector content with a 180ms crossfade plus a 6px vertical shift. Move focus to the active mode heading or first actionable control.

**Expected impact:** Lower cognitive load and stronger orientation without changing the underlying product model. Users should know what to do next within two seconds.

**Feasibility:** High. Existing `productModeStatus`, mode state, and shared design tokens are sufficient.

**Suggested surfaces:** `web/app.js`, `web/product-modes.mjs`, `web/design-system.css`, native mode/status views in `ContentView.swift`.

---

### 3. Candidate discovery and review

**Current friction:** The candidate loop is the product's signature interaction, but the UI makes the user compare technical labels, evidence prose, percentages, and separate controls. Confidence labels risk sounding more certain than the documented benchmark supports.

**Before:** Candidate row -> `Review candidate` -> highlighted region -> evidence sentence -> `Add text here`, `Create native field`, or `Dismiss`.

**After:** Make each candidate a decision card with an explicit review stance:

- **What we found:** `Possible text entry area on page 3`.
- **Why it was suggested:** `Underlined region next to “Phone”` (evidence family, not a raw score first).
- **How certain:** `Review required` with optional `Evidence strength: medium`, not a probability-like `78%` unless calibrated and clearly labeled.
- **What happens next:** `Add a reversible overlay` / `Create a native field` / `Dismiss suggestion`.
- **Navigation:** `Review and next`, `Dismiss and next`, and `Undo` as a compact action cluster.

When a user selects a candidate, scroll it into view, briefly pulse its boundary, and synchronize the card and page highlight. Do not use a persistent opaque fill over source text.

**Micro-interaction:** Selection gets a 120ms outline emphasis; the inspector card enters with 180ms fade/slide. `Dismiss` immediately removes the candidate from the active list and shows a non-blocking toast: `Suggestion dismissed. Undo` for 4-6 seconds. Restore remains available in the dismissed disclosure.

**Expected impact:** High. Faster candidate triage, better trust calibration, fewer accidental applications, and a more satisfying review rhythm.

**Feasibility:** High to medium. Existing candidate state and render paths already support selection, dismissal, restoration, and operation lineage. The main work is copy hierarchy, state presentation, and keyboard flow.

**Suggested surfaces:** `web/app.js:1891-1978, 2216-2233, 2254-2300`, `web/index.html:239-250`, native `candidateSection` and `selectedCandidateCard`.

---

### 4. Field entry, overlay editing, and apply feedback

**Current friction:** The user enters a value in a shared `Value` field and receives a status sentence after applying. The action is safe, but the moment does not feel direct or visibly complete. The user also has to decide whether to continue manually or discover candidate navigation shortcuts.

**Before:** Select field/area -> type into a generic field -> click `Fill field` or `Add text here` -> status line changes.

**After:** Turn the selected region into a focused editing moment:

- Rename the input label to the specific target: `Phone number`, `Text for page 2`, or `Choice to mark` when available.
- Show a live, low-opacity preview inside the target region while typing.
- Use `Enter` to apply and `Escape` to cancel, with explicit helper text.
- After applying, show `Applied · reversible` beside the target and offer `Review next`.
- Keep a compact progress line: `4 of 12 reviewed`.

**Micro-interaction:** On apply, animate the preview from input state to the page region with a 160ms transform/opacity transition, then give the target a single 220ms confirmation pulse. Avoid bouncing controls. For character grids, briefly reveal the per-cell placement as a sequential 20-30ms stagger only when it improves comprehension; reduced motion collapses directly to the final state.

**Expected impact:** High. More immediate confirmation, fewer repeated clicks, and a stronger sense of progress without changing editing semantics.

**Feasibility:** High. Existing operation creation and preview overlays are already present.

**Suggested surfaces:** `web/app.js:2013-2214`, `Sources/PDFEditorApp/ContentView.swift:1857-1904`, shared CSS.

---

### 5. Undo, dismissal, persistence, and recovery

**Current friction:** Undo exists as `Undo last` / toolbar undo, and restore exists for dismissed suggestions, but recovery is not consistently surfaced at the exact moment the user needs reassurance. Browser dismissal appears not to persist immediately because `dismissSelectedCandidate()` omits `saveWebSession()`.

**Before:** Apply or dismiss -> status line -> user must find `Undo last` or open `Show dismissed`.

**After:** Add a persistent, quiet activity strip near the document or inspector footer:

- `3 pending edits · source unchanged`.
- `Saved locally just now` or `Not saved yet` with a reason.
- `Undo` available for the most recent action, plus `View activity` for the full ledger.
- Dismissal and restore both create a reversible toast and persist the review state.
- When opening a new file with pending work, show the same recovery language in both native and web.

**Micro-interaction:** Toast enters from the bottom of the inspector, stays long enough to read, and exits faster than it enters. Focus remains on the user's current control unless they explicitly activate Undo. Use `aria-live="polite"` for the toast and keep the full ledger available to screen readers without interrupting typing.

**Expected impact:** High trust and recovery improvement; fewer fears of lost work and fewer repeated checks of whether an action really applied.

**Feasibility:** High to medium. Immediate persistence for dismissal is a small correctness fix; the activity strip can reuse the operation/review/session state already present.

**Suggested surfaces:** `web/app.js:2216-2252`, `web/index.html:285-301`, `Sources/PDFEditorApp/AppModel.swift`, `ContentView.swift`.

---

### 6. Export, validation, and the finish line

**Current friction:** Export performs meaningful work and validation, but the user sees a generic wait message and then a dense list of checks. The product's strongest trust feature is therefore experienced as a technical report instead of a confident completion moment.

**Before:** Click `Export + validate` -> `Exporting with pdf-lib and validating with PDF.js...` -> dense `validated`, `warning`, or `failed` rows.

**After:** Use a three-step export rail:

1. `Preparing new copy`.
2. `Checking applied edits`.
3. `Reopening and comparing`.

Then present one plain-language outcome at the top:

- **Validated:** `Your new copy is ready. 3 edits applied; source unchanged.`
- **Validated with warnings:** `Your new copy is ready, with 1 item to review.`
- **Failed:** `Nothing was downloaded because the output could not be trusted.`

Keep technical checks behind `See validation details`, but expose the important facts immediately: output filename, new-copy behavior, reopen result, changed pages, and remaining warnings. Add `Open output folder` only where the host can guarantee the action; otherwise use a clear downloaded-file confirmation.

**Micro-interaction:** Progress steps switch with a 120ms checkmark draw/fade. The final outcome uses a restrained checkmark or warning icon, not confetti. On failure, keep the document and edit session intact; offer `Try export again` and `View failed check`.

**Expected impact:** Very high for end-of-task satisfaction and trust. The user sees a clear finish instead of wondering whether a technical validation log means success.

**Feasibility:** High. `lastValidation`, `validationBox`, `impactMetricsContent`, and export status already exist.

**Suggested surfaces:** `web/app.js:3400-3660`, `web/index.html:293-301`, native `validationSection` and export status handling.

---

### 7. Empty, no-match, blocked, and unsupported states

**Current friction:** Empty states such as `No AcroForm widgets detected`, `No active suggestions`, and `No matches yet` are accurate but largely passive. Unsupported and provider states can feel like a dead end even when a safe fallback exists.

**Before:** State label -> technical explanation -> user searches elsewhere for a next action.

**After:** Give every non-success state a three-part structure:

- **State:** what is true now.
- **Meaning:** what the product can and cannot do.
- **Next action:** the safest useful fallback.

Examples:

- `No native fields found` -> `This PDF may use static entry regions` -> `Review suggestions` / `Add text manually`.
- `Editing is unavailable for this protected PDF` -> `Reading and byte-preserving export still work` -> `Export unchanged copy` / `Open an editable copy`.
- `No search matches` -> `Nothing matched “phone”` -> `Try a shorter term` / `Search page labels`.
- `Provider not measured` -> `This capability is not enabled for this source class` -> `Continue with review-only mode`.

**Micro-interaction:** Reveal the fallback action at the same time as the state, not after a modal. Use a neutral info treatment for unknown/reader-only states; reserve red for failed or irreversible conditions.

**Expected impact:** Medium to high. Lower emotional valleys and fewer abandoned flows when the product correctly abstains.

**Feasibility:** High. This is primarily copy, hierarchy, and state-component reuse.

**Suggested surfaces:** `web/app.js` error/status renderers, `web/index.html` empty regions, native `ContentView.swift` empty sections and alerts.

---

### 8. Template, provider, privacy, and advanced controls

**Current friction:** The template review card contains capture, search, persistence, import/export, sync, health, backup, restore, deletion, activation, preparation, and apply controls in one region (`web/index.html:252-276`). This is feature-complete but reads like an operator console. Users must understand storage and lifecycle mechanics before they can complete a document.

**Before:** One expanded card with many controls and technical state labels.

**After:** Progressive disclosure with a task-first order:

1. `Use a saved template` (only if a safe match exists).
2. `Review mappings`.
3. `Review values`.
4. `Apply reviewed completion`.
5. `Template history and storage` disclosure.
6. `Backup, restore, sync, and delete vault` under a deliberate `Manage local data` boundary.

Use a compact lifecycle badge with plain-language mapping: `Draft · needs review`, `Active · ready to prepare`, `Stale · review changes`, `Revoked · cannot apply`. Keep revision IDs, digests, and provider details available under `Technical details` rather than in the first decision layer.

**Micro-interaction:** When a match is found, animate only the matched page regions and preview the number of mappings; do not auto-apply. When a user expands advanced storage controls, preserve scroll position and announce the section heading.

**Expected impact:** High reduction in cognitive load, especially for repeat workflows and privacy-sensitive users. Higher perceived quality because power features feel intentional rather than crowded.

**Feasibility:** Medium. Requires grouping existing controls and a small amount of stateful disclosure; no contract or storage redesign.

**Suggested surfaces:** `web/index.html:252-276`, `web/app.js` template render functions, native template review sections around `ContentView.swift:1425-1568`.

---

### 9. Native/web parity and accessibility as a delight multiplier

**Current friction:** The semantic model is shared, but the interaction experience differs: web has explicit status/live-region coverage and workflow tests, while native accessibility, keyboard-only placement, focus restoration, and reduced-motion behavior remain insufficiently proven. A user who switches surfaces may feel they are using two products.

**Before:** Similar concepts, different interaction vocabulary and proof coverage.

**After:** Define and test a cross-surface interaction contract for the top loop:

- Open/import and pending-work protection.
- Navigate to page and candidate.
- Select field or suggestion.
- Enter/apply value.
- Undo/dismiss/restore.
- Export, validation outcome, and recovery.
- Dialog focus entry/exit.
- VoiceOver/keyboard announcements for candidate evidence and validation severity.

Use the same plain-language labels and status semantics in both surfaces. Add native keyboard shortcuts for `Review next`, `Dismiss`, `Undo`, and `Apply`, while retaining visible controls. Make manual placement reachable without a mouse, or provide a keyboard-confirmed placement target.

**Micro-interaction:** Keep motion language consistent: selection outline, inspector reveal, applied confirmation, export progress, and warning/failure recovery. The reduced-motion variant should still provide a state change through text, border, and focus.

**Expected impact:** High for perceived coherence and inclusive satisfaction; also lowers support cost by making behaviors predictable.

**Feasibility:** Medium. Web changes are high feasibility; native requires a focused UI/accessibility test lane and some focus-model work.

**Suggested surfaces:** `Tests/web_accessibility_gate_test.mjs`, native UI test target, `Sources/PDFEditorApp/ContentView.swift`, `AppCommands.swift`.

---

## Prioritized implementation backlog

| Priority | Recommendation | Impact | Feasibility | Why first |
|---|---|---:|---:|---|
| P0 | Candidate review decision card + Review/Dismiss/Undo rhythm | Very high | High | Core differentiator; directly affects task completion and trust. |
| P0 | Export progress/outcome redesign | Very high | High | Converts the highest-anxiety moment into a clear, validated finish. |
| P0 | Immediate dismissal persistence and consistent recovery strip | High | High | Correctness and confidence issue with a small implementation surface. |
| P1 | Open/readiness staging and pending-work protection in web | High | High | Improves first-use confidence and prevents avoidable loss. |
| P1 | Contextual next-action guidance in the five-mode rail | High | High | Reduces orientation cost without changing the architecture. |
| P1 | Target-specific entry feedback and live overlay preview | High | High | Makes every edit feel direct and confirmed. |
| P1 | Empty/blocked state component with actionable fallback | Medium-high | High | Improves recovery across many existing states at once. |
| P2 | Progressive disclosure for templates/provider/privacy controls | High | Medium | Large satisfaction gain, but touches the broadest information architecture. |
| P2 | Native/web interaction parity and accessibility proof lane | High | Medium | Essential long-term quality; requires runtime/UI validation. |

## Motion and micro-interaction system

Keep the system restrained and purposeful:

- **Instant feedback:** 100-150ms for button press, focus, toggle, and selection outline.
- **State change:** 180-280ms for inspector reveal, toast, validation step, and disclosure.
- **Layout change:** 300-450ms for sheets, drawers, and major panel reflow.
- **Easing:** use an ease-out quart/quint curve; avoid bounce and elastic effects.
- **Properties:** animate `transform` and `opacity` first; do not animate document layout or page geometry.
- **Frequency:** a confirmation pulse once per meaningful operation, not on every keystroke.
- **Reduced motion:** remove movement but preserve text, border, icon, and focus changes.
- **Assistive technology:** use polite live regions for routine status; assertive announcements only for failure, blocked export, or data-loss risk.
- **Performance:** render page 1 and the active candidate first; lazy-load thumbnail and metadata work where possible.

## Voice and microcopy direction

The right voice is **warm, exact, and quietly encouraging**. It should acknowledge effort without joking about documents or implying certainty the evidence does not support.

Prefer:

- `Ready to review 12 suggested areas.`
- `Applied as a reversible overlay. The source page is unchanged.`
- `Suggestion dismissed. Undo`.
- `Your new copy is ready. Validation passed with 1 warning.`
- `This capability is unavailable for this PDF, but reading and unchanged export remain available.`

Avoid:

- `Magic`, `AI knows`, `Boom`, `Oopsie`, or anthropomorphic jokes in high-stakes states.
- `High confidence` when the number is only a heuristic evidence score.
- `Success` when the output is only reopened by one provider or contains unknown checks.
- `Delete` without describing local-vault scope and recovery limits.

## Measurement plan

These recommendations are proposals until tested with users. Instrument value-free interaction events and run a small comparative study across native and web:

1. Time from open to first reviewed candidate.
2. Candidate review completion rate and median time per candidate.
3. Apply-to-undo rate, dismissal-to-restore rate, and accidental-apply reports.
4. Export success, warning acknowledgement, retry, and abandonment rates.
5. Percentage of sessions with a visible recovery action used successfully.
6. First-time user comprehension: can users explain “source unchanged until export” and “review required” without prompting?
7. Satisfaction after the review loop and after export, using a short 1-5 task-level rating rather than only an end-of-session survey.
8. Accessibility completion rate for keyboard-only and VoiceOver workflows.

Do not treat an interaction increase as delight by itself. Validate that faster interactions also preserve review correctness, source binding, warnings, and recovery.

## Recommended rollout sequence

### Slice A: Make the core loop feel complete

- Candidate decision card.
- Active candidate focus and synchronized highlight.
- Review/Dismiss/Undo/Next actions.
- Immediate dismissal persistence.
- Applied/reversible state and progress line.

### Slice B: Make completion feel trustworthy

- Export progress rail.
- Plain-language validation outcome.
- Warning/failure recovery actions.
- Output identity and source-preservation summary.

### Slice C: Make the product easier to enter and recover

- Welcome/readiness staging.
- Web pending-work protection.
- Empty/blocked state component.
- Activity strip and local-save status.

### Slice D: Make power features feel intentional

- Template/provider/privacy progressive disclosure.
- Lifecycle copy and migration/recovery actions.
- Native/web parity pass.
- Native keyboard and VoiceOver proof lane.

## Open questions and follow-up validation

- Which user group is the primary satisfaction target: occasional form fillers, professional document operators, or privacy-sensitive repeat users? The static product direction supports all three, but emphasis changes copy and pacing.
- Is the browser intended to be the primary surface for first-time users, or is native macOS the flagship? The recommendation favors parity, but rollout order should follow product strategy.
- Which satisfaction signal currently underperforms: task completion, trust in output, speed, learnability, or perceived polish? Baseline product analytics or user interviews are needed before claiming uplift.
- Native VoiceOver, keyboard-only, and reduced-motion behavior remain **Unknown** until observed on the target macOS runtime.
- Candidate confidence wording should remain review-oriented until calibration and held-out corpus evidence justify probability-like language.

## Completion note

This document is a design proposal and static review artifact. It does not modify product source files, does not claim production readiness, and does not claim measured user-satisfaction improvement. The recommended first implementation is the candidate review and export finish-line pair because it compounds the existing trust model instead of adding a second interaction system.