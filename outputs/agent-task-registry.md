# PDF Editor Agent Task Registry

**Date:** 2026-08-25
**Product:** Northstar PDF Editor — local-first native macOS and browser surfaces
**Purpose:** Exhaustive working inventory of explicit and implicit tasks that agents can execute or prepare from the Delightful Experience redesign audit and the current macOS application audit.

## How to use this registry

This is a task-discovery and coordination document, not permission to modify product code, run external actions, commit, deploy, or promote evidence. Each task remains subject to the project's normal authorization and evidence rules.

Truth labels:

- **Observed:** directly supported by inspected source or existing project documentation.
- **Verified:** supported by an existing recorded test/runtime artifact in the named lane.
- **Inferred:** a likely consequence of observed behavior; verify before calling it a defect.
- **Proposed:** a design, implementation, research, or measurement task requested by the redesign direction.
- **Unknown:** the current material does not establish the behavior.
- **Decision:** requires product/architecture/security owner input before implementation.

Work types:

- **Build:** edit product code or styles.
- **Test:** add or run deterministic, UI, accessibility, performance, or runtime evidence.
- **Research:** establish missing knowledge or compare options.
- **Design:** define interaction, copy, motion, or information architecture.
- **Docs:** preserve decisions, contracts, runbooks, and evidence.
- **Decision:** resolve a product, architecture, security, privacy, or release question.

Priority:

- **P0:** high-impact, low-restructure, or correctness/recovery work that should start first.
- **P1:** high-value follow-up with a bounded implementation path.
- **P2:** valuable power-user, parity, measurement, or hardening work.
- **P3:** useful polish or lower-risk information architecture work after core flow stability.
- **GATE:** prerequisite decision or evidence gate; not a substitute for implementation.

## Scope boundary

This registry covers:

1. Every explicit recommendation and rollout item in `outputs/delightful-experience-redesign-report.md`.
2. Every implementation, proof, research, and decision task implied by those recommendations.
3. The open native interaction/recovery/accessibility tasks in `docs/audits/macos-app-design-review-and-todo-2026-08-24.md` that materially affect delight, trust, or cross-surface consistency.
4. The current open source-level and runtime evidence tasks in that audit's implementation-wave status.

It does **not** re-list the entire long-term PDF capability program (OCR, XFA, arbitrary text editing, collaboration, conversion, and other capability lanes) unless that work directly changes one of the user touchpoints below. Those capabilities have their own canonical plans and evidence ledgers.

## Product outcome to preserve

Make the product feel **reassuringly precise**:

```text
technical state -> user interpretation -> action
                          becomes
clear decision -> safe action -> concise evidence on demand
```

Preserve these invariants while adding delight:

- The source PDF remains untouched until explicit export.
- Inferred regions remain review-gated.
- Reversible actions remain visibly reversible.
- Unknown and unmeasured states are never presented as pass or success.
- Native and browser surfaces use the same semantic state vocabulary.
- Motion explains state change; it never delays, obscures, or substitutes for feedback.
- Reduced motion, keyboard use, VoiceOver, and screen-reader paths retain equivalent meaning.

---

# 1. P0 execution queue

These are the best first tasks for agents because they combine high user impact, existing state/contracts, and low feature restructuring.

| ID | Task | Type | Surface | Truth | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-P0-01` | Implement the candidate-review decision-card hierarchy | Build / Design | Web + native | Proposed | None | Each selected candidate presents what was found, why it was suggested, evidence strength, available actions, and reversibility before the user acts. |
| `DE-P0-02` | Add synchronized candidate focus behavior | Build / Test | Web + native | Proposed | `DE-P0-01` | Selecting a candidate scrolls it into view, synchronizes inspector and page highlight, and preserves focus semantics. |
| `DE-P0-03` | Add `Review next`, `Dismiss and next`, and `Undo` actions | Build / Test | Web + native | Proposed | `DE-P0-01`, `DE-P0-02` | A user can process the candidate queue without returning to the list after every item; keyboard and assistive labels are present. |
| `DE-P0-04` | Replace probability-like confidence copy with evidence-strength language | Design / Build / Research | Web + native | Inferred + Proposed | Candidate calibration decision | Default copy says `Review required` and evidence family/strength; percentage labels remain only if calibrated and explicitly defined. |
| `DE-P0-05` | Persist candidate dismissal and restore state immediately | Build / Test | Web | Observed gap to verify | None | `dismissSelectedCandidate()` and restore paths persist session state; reload preserves the review state; a regression test fails if persistence is removed. |
| `DE-P0-06` | Add a recovery/activity strip | Build / Design | Web + native | Proposed | Existing operation/recovery state | The UI shows pending edit count, source-preservation state, local-save state, and a path to activity/history without crowding the document. |
| `DE-P0-07` | Add an undo/dismiss/restore toast pattern | Build / Accessibility test | Web + native | Proposed | `DE-P0-05` | Routine actions produce a polite, non-blocking toast with an accessible Undo path; focus does not jump unexpectedly. |
| `DE-P0-08` | Redesign export as a visible three-stage progress rail | Build / Design | Web + native | Proposed | Existing export/validation state | Users can see `Preparing new copy`, `Checking applied edits`, and `Reopening and comparing`, with reduced-motion equivalents. |
| `DE-P0-09` | Add plain-language export outcome summaries | Build / Copy / Test | Web + native | Proposed | `DE-P0-08` | Validated, warning, and failed outcomes expose output identity, source-preservation behavior, reopen status, and the next safe action before technical details. |
| `DE-P0-10` | Add export failure recovery actions | Build / Test | Web + native | Proposed | `DE-P0-09` | Failed export keeps the editing session intact and offers retry plus failed-check details; no untrusted output downloads. |
| `DE-P0-11` | Add a validation-details disclosure | Build / Design | Web + native | Proposed | `DE-P0-09` | Technical checks remain available but do not dominate the first completion message; status semantics remain exact. |
| `DE-P0-12` | Define and implement the shared interaction-state vocabulary | Design / Docs / Build | Web + native | Proposed | None | A shared table maps `suggested`, `review required`, `applied`, `validated`, `warning`, `unknown`, `blocked`, `failed`, and `reader-only` to copy, color, icon, action, and accessibility treatment. |

### P0 acceptance bar

A P0 slice is not complete because the screen looks better. It must prove:

- The user can identify the next safe action without reading raw provider terminology.
- Candidate review, dismissal, undo, and export failure preserve existing contracts and source-binding rules.
- Status is visible to sighted users and announced appropriately to assistive technology.
- Reduced motion preserves meaning through text, focus, borders, and icons.
- Web regression tests cover the state transition, persistence, and recovery behavior.

---

# 2. Open and first-readiness workstream

## Explicit tasks from the redesign

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-OPEN-01` | Create a calm welcome/open surface with one primary `Open a PDF` action | Build / Design | P1 | Web | None | The empty state makes opening a PDF the clear first action and retains drag/drop or file-picker access without toolbar competition. |
| `DE-OPEN-02` | Add compact trust cues: on-device processing, source unchanged until export, review before applying | Build / Copy | P1 | Web + native | Shared state vocabulary | Trust cues are visible near opening/first readiness and do not overclaim network or privacy behavior. |
| `DE-OPEN-03` | Add staged loading states: reading, mapping, finding regions, ready | Build / Test | P1 | Web + native | `DE-OPEN-01` | Long loads expose truthful phase status, page 1 becomes usable as soon as safe, and later work does not block the first useful action. |
| `DE-OPEN-04` | Surface a direct `Start review` action when candidates exist | Build / Design | P1 | Web + native | `DE-P0-01` | The readiness summary includes candidate count, review state, and a focusable start action without auto-entering Fill/Edit mode. |
| `DE-OPEN-05` | Add browser pending-work protection before file replacement | Build / Test | P1 | Web | Existing operation/review state | A replacement with pending edits or reviews offers keep-current-work and explicit discard paths; no silent reset. |
| `DE-OPEN-06` | Align native and web Open wording around non-destructive lifecycle semantics | Build / Copy / Test | P1 | Web + native | Native lifecycle implementation | All Open entry points use consistent `Continue to Open`/preservation language; no path says `Discard` when it preserves the document. |
| `DE-OPEN-07` | Add drag-and-drop admission and visible rejection feedback | Build / Test | P2 | Web | `DE-OPEN-01` | Valid PDFs show an admitted state; non-PDF or malformed input explains the next safe action without replacing the current document. |
| `DE-OPEN-08` | Define first-load performance budget and progressive rendering behavior | Research / Test / Docs | P1 | Web + native | Existing resource-policy data | Budgets exist for page 1, thumbnails, candidate inspection, and metadata; measurements are retained by fixture class. |

## Implicit tasks

- `DE-OPEN-09` — Define which readiness states are data-driven versus cosmetic; no fake progress steps.
- `DE-OPEN-10` — Ensure stale asynchronous loads cannot overwrite a newer document state; test the existing load-generation boundary.
- `DE-OPEN-11` — Verify password prompt focus entry, cancellation, retry, and focus restoration during staged loading.
- `DE-OPEN-12` — Define the exact claim boundary for `processed on this device` across browser fallback/runtime failure paths.
- `DE-OPEN-13` — Add empty-state copy for no fields, no candidates, protected PDF, malformed PDF, oversized PDF, and runtime-unavailable states.

---

# 3. Mode navigation and orientation workstream

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-MODE-01` | Add a contextual next-safe-action line to each mode | Build / Copy | P1 | Web + native | `DE-P0-12` | Reader, Understand, Complete, Organize, and Review each expose a state-aware next action. |
| `DE-MODE-02` | Separate capability state from next action | Build / Design | P1 | Web + native | `DE-MODE-01` | `Available`, `Review required`, `Reader only`, `Unavailable here`, and similar states are secondary to the action, not the action itself. |
| `DE-MODE-03` | Add workflow progress only when a workflow is active | Build / Test | P1 | Web + native | Candidate state model | Counts do not imply completion or provider readiness; progress updates from authoritative review/operation state. |
| `DE-MODE-04` | Animate inspector-only mode transitions | Build / Motion test | P1 | Web + native | Shared motion tokens | Canvas remains stable; inspector uses a short crossfade/translate; reduced motion uses an instant state swap. |
| `DE-MODE-05` | Move focus to the active mode heading or first actionable control | Build / Accessibility test | P1 | Web + native | `DE-MODE-04` | Keyboard and VoiceOver users understand the mode change without losing document context. |
| `DE-MODE-06` | Define mobile/tablet mode-rail behavior | Design / Build / Responsive test | P2 | Web | Existing breakpoints | Labels remain reachable at 360, 390, 430, 600, and 820 widths with no horizontal overflow. |
| `DE-MODE-07` | Define mode transition copy contract across native and web | Docs / Build | P2 | Web + native | `DE-P0-12` | Same semantic transition is expressed with platform-appropriate controls and identical meaning. |

---

# 4. Candidate review and completion workstream

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-CAND-01` | Rewrite candidate cards around `What we found`, `Why`, `Review stance`, and `What happens next` | Build / Copy | P0 | Web + native | `DE-P0-01` | Technical evidence is available but not the first reading layer; actions name their consequences. |
| `DE-CAND-02` | Add evidence-family labels instead of raw score-first presentation | Design / Build | P0 | Web + native | `DE-P0-04` | Users can distinguish native field, geometry, OCR, grouping, and manual placement evidence. |
| `DE-CAND-03` | Add `Review and next` flow | Build / Test | P0 | Web + native | `DE-P0-03` | After applying or confirming a candidate, the next reviewable candidate is selected predictably. |
| `DE-CAND-04` | Add `Dismiss and next` flow | Build / Test | P0 | Web + native | `DE-P0-03`, `DE-P0-05` | Dismissal is reversible, persisted, and advances without losing the current queue position. |
| `DE-CAND-05` | Add candidate selection pulse and scroll-to-region behavior | Build / Motion test | P0 | Web + native | `DE-P0-02` | The active page region is visible and emphasized without obscuring source text or causing viewport fighting. |
| `DE-CAND-06` | Add live target preview while typing | Build / Test | P1 | Web + native | Existing overlay projection | The input previews the value inside the target without mutating source bytes or creating an untracked operation. |
| `DE-CAND-07` | Make the entry label target-specific | Build / Copy | P1 | Web + native | Candidate/field identity | Generic `Value` becomes a meaningful target label when the target identity is known. |
| `DE-CAND-08` | Add Enter-to-apply and Escape-to-cancel semantics | Build / Accessibility test | P1 | Web + native | `DE-CAND-06` | Keyboard behavior is documented, visible, and does not confirm a value merely because focus changed. |
| `DE-CAND-09` | Add `Applied · reversible` state beside the selected target | Build / Copy | P1 | Web + native | Existing operations | Applied state is distinct from exported/validated state and remains undoable. |
| `DE-CAND-10` | Add review progress line | Build / Design | P1 | Web + native | Candidate status authority | Progress counts only reviewed/confirmed/dismissed candidates according to an explicit definition. |
| `DE-CAND-11` | Keep character-grid placement comprehensible but non-blocking | Build / Motion test | P1 | Web + native | Existing grid projection | Per-cell feedback is optional and short; reduced motion shows the final placement directly. |
| `DE-CAND-12` | Add candidate correction and hard-negative review instrumentation | Test / Research / Docs | P2 | Web + native | Existing metrics | Value-free events can measure review correction, abstention, dismissal, and false-positive patterns without logging document content. |
| `DE-CAND-13` | Calibrate evidence-strength labels against reviewed fixtures | Research / Test | P2 | Native + browser contracts | Existing benchmark corpus | Labels are tied to measured class behavior, or the product formally uses evidence-strength language instead of confidence probability. |
| `DE-CAND-14` | Expand candidate fixtures for known geometry gaps | Test / Research | P2 | Native + web | Existing detector calibration | One/two-cell groups, columns, unusual spacing, rotated/vertical text, ligatures, scans, crop boxes, and hard negatives are represented. |
| `DE-CAND-15` | Make manual placement crop-box-aware and keyboard reachable | Build / Test | P2 | Native first, web parity | View/overlay semantics | Placement remains inside the selected page box for supported rotations, sizes, display modes, and keyboard flows. |
| `DE-CAND-16` | Separate `suggested`, `confirmed`, `applied`, `dismissed`, and `validated` visual states | Build / Design | P1 | Web + native | `DE-P0-12` | State color, icon, border, and copy never rely on color alone and never imply inference is validation. |

---

# 5. Editing, undo, and recovery workstream

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-REC-01` | Implement the shared activity strip | Build | P0 | Web + native | `DE-P0-06` | Pending operation count, source state, save state, and activity access are visible in one stable region. |
| `DE-REC-02` | Implement polite undo toast with timeout and accessible action | Build / Test | P0 | Web + native | `DE-P0-07` | Toast is non-blocking, keyboard reachable, screen-reader announced politely, and does not steal focus. |
| `DE-REC-03` | Persist dismissal and restore actions | Build / Test | P0 | Web | `DE-P0-05` | Reload and recovery restore the review status and review journal consistently. |
| `DE-REC-04` | Add local-save freshness status | Build / Design | P1 | Web + native | Existing recovery envelope | Users can tell whether the latest review/operation state is saved, pending, or failed, without exposing sensitive values. |
| `DE-REC-05` | Add source-mismatch recovery copy | Design / Build / Test | P1 | Web + native | Recovery contract | A mismatched source offers review, discard, or safe recovery paths; it never silently replays operations. |
| `DE-REC-06` | Add transactional close/discard operation | Build / Test | P1 | Native | Existing close flow | Recovery deletion cannot happen before the target window close is admitted; failed close leaves recoverable state. |
| `DE-REC-07` | Define payload integrity threat model | Decision / Security research / Docs | GATE | Native | None | Product decides between authenticated encryption, Keychain-backed protection, or explicit local-trust boundary; the claim is documented. |
| `DE-REC-08` | Add bounded retention for value-bearing recovery generations | Build / Test | P1 | Native | `DE-REC-07` | Active generation plus bounded known-good predecessors are retained; orphan cleanup failures are reported. |
| `DE-REC-09` | Define/migrate recovery payload schema version 2 | Build / Docs / Test | P2 | Native | Recovery schema | Unsupported history is distinguished from corruption; legacy records do not get guessed migrations. |
| `DE-REC-10` | Make authoritative recovery status visible | Build / Test | P2 | Native | Existing `RecoveryStatus` | Valid, restored, metadata-only, corrupted, and save-failed states map to distinct UI and actions. |
| `DE-REC-11` | Narrow lossy recovery compatibility APIs | Build / Docs / Test | P2 | Native | Recovery status authority | App-facing discovery uses diagnostic-preserving APIs rather than a compatibility projection that hides corruption. |
| `DE-REC-12` | Maintain one recovery-generation contract | Architecture / Build / Test | P2 | Native | `DE-REC-07`, `DE-REC-10` | Candidate status, view state, metadata, payload, and pair generation cannot silently diverge. |
| `DE-REC-13` | Define generation commit-pointer durability claim | Decision / Research / Docs | GATE | Native | `DE-REC-07` | Product records whether current commit-pointer semantics are sufficient or a stronger OS-level transaction boundary is required. |
| `DE-REC-14` | Verify/develop model-owned debounced view-state autosave | Build / Test | P1 | Native | Recovery contract | Page, reader mode, scale, zoom, rotation, and selection autosave without marking document content dirty. |
| `DE-REC-15` | Add recovery failure injection tests | Test | P1 | Native | `DE-REC-06` to `DE-REC-14` | Payload, pair, metadata, replacement, cleanup, source mismatch, and replay failure paths leave the active ledger unchanged on failure. |

---

# 6. Export, validation, and trust workstream

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-EXP-01` | Map export lifecycle to explicit UI phases | Build / Design | P0 | Web + native | `DE-P0-08` | Preparing, materializing, reopening, comparing, and outcome states are distinct and truthful. |
| `DE-EXP-02` | Add plain-language validated outcome | Build / Copy | P0 | Web + native | `DE-EXP-01` | Outcome says what was produced, how many operations applied, and what source-preservation claim is established. |
| `DE-EXP-03` | Add warning outcome and acknowledgement path | Build / Test | P0 | Web + native | Structured validation | Warning does not collapse to failure or success; user can inspect the warning and continue only under defined policy. |
| `DE-EXP-04` | Add failed outcome and retry path | Build / Test | P0 | Web + native | `DE-EXP-01` | No artifact downloads on failed trust checks; edit session remains intact; retry is safe. |
| `DE-EXP-05` | Add output identity summary | Build / Copy | P1 | Web + native | Existing download/export metadata | Filename/output identity, new-copy behavior, reopen result, changed pages, and remaining warnings are visible. |
| `DE-EXP-06` | Add technical validation disclosure | Build / Design | P1 | Web + native | `DE-EXP-02` | Full checks and evidence basis remain inspectable without being the default first reading layer. |
| `DE-EXP-07` | Preserve distinct claims for reopen, source preservation, and outside-region validation | Docs / Test | P0 | Web + native | Existing validators | User copy never calls an output clean based only on reopenability; claims map to exact evidence. |
| `DE-EXP-08` | Replace fragile validation matching with structured result linkage | Build / Test | P1 | Native | Existing validation audit | Pass, pass-with-warnings, fail, operation identity, and recovery action are typed and mutation-tested. |
| `DE-EXP-09` | Define warning/block/confirm policy | Decision / Docs | GATE | Web + native | `DE-EXP-03` | Each warning category has a documented export policy and user-facing next action. |
| `DE-EXP-10` | Test export performance on large/scanned/annotation-heavy files | Test / Performance | P2 | Web + native | `DE-EXP-01` | Budgets and fallback behavior are measured by fixture class, not inferred from small PDFs. |

---

# 7. Empty, blocked, unsupported, and error-state workstream

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-STATE-01` | Create a reusable three-part state pattern: state, meaning, next action | Build / Design | P1 | Web + native | `DE-P0-12` | Empty/blocked/unknown/error surfaces share consistent hierarchy and recovery behavior. |
| `DE-STATE-02` | Rewrite no-native-field state with static-region fallback | Copy / Build | P1 | Web + native | `DE-STATE-01` | User can move to suggestions or manual text without interpreting a dead-end message. |
| `DE-STATE-03` | Rewrite protected-PDF editing state | Copy / Build | P1 | Web + native | Capability contracts | Reading and unchanged export remain visible when editing is unavailable; no false promise of editability. |
| `DE-STATE-04` | Rewrite no-search-match state | Copy / Build | P2 | Web + native | `DE-STATE-01` | Query is reflected, result count is clear, and useful retry guidance is available. |
| `DE-STATE-05` | Rewrite unmeasured/provider-abstained state | Copy / Build | P1 | Web + native | Provider capability semantics | User sees why a capability is unavailable and the safe fallback; unmeasured is never green. |
| `DE-STATE-06` | Standardize runtime, password, malformed, page-limit, and export errors | Build / Copy / Test | P1 | Web + native | Shared error vocabulary | Error messages preserve stable codes internally and expose non-blaming recovery language externally. |
| `DE-STATE-07` | Verify external-link safety policy at the model boundary | Test / Security | P1 | Native | Existing link UI | Unsafe links are blocked or explicitly confirmed; warning icon alone is never the permission boundary. |
| `DE-STATE-08` | Add focus and modal recovery behavior to all error/dialog states | Build / Accessibility test | P1 | Web + native | `DE-STATE-06` | Focus enters, remains, and returns predictably for password, confirmation, provider, and failure surfaces. |

---

# 8. Template, provider, privacy, and advanced-control workstream

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-ADV-01` | Group template controls into task-first progressive disclosure | Build / Design | P2 | Web + native | Existing template state | Completing a document starts with match/review/apply; storage and sync controls are secondary. |
| `DE-ADV-02` | Create `Manage local data` boundary for backup/restore/sync/delete | Build / Copy / Security review | P2 | Web + native | `DE-ADV-01` | Destructive vault actions are clearly scoped and separated from completion actions. |
| `DE-ADV-03` | Map template lifecycle states to recovery actions | Build / Copy | P2 | Web + native | Template lifecycle contract | Draft, active, stale, archived, and revoked states each expose deliberate review/migrate/stop behavior. |
| `DE-ADV-04` | Hide technical IDs/digests behind technical details | Build / Design | P2 | Web + native | `DE-ADV-01` | Provenance remains available without crowding the primary decision layer. |
| `DE-ADV-05` | Preview matched page regions without auto-applying | Build / Test | P2 | Web + native | Existing template match | Match preview highlights safe regions, reports mapping count, and never silently materializes operations. |
| `DE-ADV-06` | Preserve scroll position and announce expanded advanced sections | Build / Accessibility test | P2 | Web + native | `DE-ADV-01` | Disclosure changes do not disorient keyboard/screen-reader users. |
| `DE-ADV-07` | Test template migration/revocation privacy boundary | Test / Security research | P2 | Web + native | Lifecycle state | No raw template values appear in logs/recovery artifacts; revoked data cannot materialize edits. |
| `DE-ADV-08` | Define provider capability copy and fallback matrix | Design / Docs | P1 | Web + native | Provider contracts | Installed, measured, enabled, partial, revoked, quarantined, abstained, and unmeasured states have exact user-facing copy and action. |
| `DE-ADV-09` | Evaluate a second provider only after native core proof | Research / Provider gate | GATE | Native | Existing provider constraints, native evidence | Provider comparison covers preserved AcroForm, Form 6, rotation, encrypted, malformed, scanned, and large fixtures plus licensing/security/packaging. |

---

# 9. Native Mac citizenship and cross-surface parity

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-NATIVE-01` | Build against the supported macOS deployment target | Build / Test | GATE | Native | Current source state | SDK/API availability issues are resolved and build results are retained. |
| `DE-NATIVE-02` | Exercise two independent document windows | Runtime test | P1 | Native | Scene/window ownership | Different documents preserve independent operations, search, selection, recovery, undo, permissions, and export targets. |
| `DE-NATIVE-03` | Exercise focused command routing and document lifecycle | Runtime test | P1 | Native | Command inventory | New/Open/Close/Export/Undo/Search/Navigation commands target the focused window with correct enablement. |
| `DE-NATIVE-04` | Exercise importer and password sheets | Runtime / Accessibility test | P1 | Native | Open/readiness state | Admission, password retry/cancel, focus restoration, and failure recovery are observed and retained. |
| `DE-NATIVE-05` | Exercise close-keep and close-discard flows | Runtime test | P1 | Native | `DE-REC-06` | Close choices preserve or discard recovery according to explicit policy and failure behavior. |
| `DE-NATIVE-06` | Exercise PDFKit projection with rotation, overlays, search, scrolling, zoom, and replacement | Runtime test | P1 | Native | Viewer/overlay semantics | No visual projection mutation changes export truth; no stale highlight or viewport fight is observed. |
| `DE-NATIVE-07` | Create native accessibility matrix | Docs / Design / Test | P1 | Native | Native interaction surface | Matrix covers labels, traits, focus order, VoiceOver, keyboard, dialogs, overlays, search, validation, and Settings. |
| `DE-NATIVE-08` | Capture VoiceOver and full-keyboard workflow | Runtime accessibility test | P1 | Native | `DE-NATIVE-07` | Open, navigate, find, select, place, apply, undo, validate, export, and recover without a mouse; evidence names OS, fixture, and residual limits. |
| `DE-NATIVE-09` | Verify reduced-motion behavior | Runtime accessibility test | P1 | Native + web | Motion system | Essential state remains understandable with non-essential motion removed. |
| `DE-NATIVE-10` | Add native UI/AppKit tests for core interaction gates | Test | P1 | Native | `DE-NATIVE-01` to `DE-NATIVE-08` | Two-window, permissions, undo/redo, search identity, export recovery, and overlay non-persistence are exercised at S2/S3. |
| `DE-NATIVE-11` | Align toolbar, Settings, and advanced command IA | Design / Build | P2 | Native | Command inventory | Toolbar preserves frequent actions; advanced commands live in menus/inspectors; Settings rows are genuinely configurable or relabeled. |
| `DE-NATIVE-12` | Add native keyboard shortcuts for review-next, dismiss, undo, apply | Build / Test | P1 | Native | Candidate review state | Shortcuts are discoverable, visible controls remain available, and conflicts with system commands are resolved. |
| `DE-NATIVE-13` | Establish shared copy and state semantics across web/native | Docs / Build / Test | P1 | Web + native | `DE-P0-12` | Same action has the same meaning and recovery outcome on both surfaces. |

---

# 10. Motion, visual, and microcopy implementation tasks

| ID | Task | Type | Priority | Surface | Dependencies | Done when |
|---|---|---|---|---|---|---|
| `DE-MOTION-01` | Add shared motion tokens and timing documentation | Design / Docs / Build | P1 | Web + native | None | Instant feedback, state change, layout change, easing, and reduced-motion rules are named and reused. |
| `DE-MOTION-02` | Implement button/focus/selection feedback | Build / Test | P1 | Web + native | Motion tokens | Controls acknowledge interaction without bounce, delay, or layout shift. |
| `DE-MOTION-03` | Implement inspector reveal and disclosure transitions | Build / Test | P1 | Web + native | Motion tokens | Only transform/opacity animate where possible; document/page geometry stays stable. |
| `DE-MOTION-04` | Implement apply confirmation pulse | Build / Test | P1 | Web + native | Candidate state | One meaningful confirmation per operation; no repeated animation fatigue. |
| `DE-MOTION-05` | Implement export checkmark/warning transition | Build / Test | P0 | Web + native | Export outcome | Completion feels conclusive without confetti, sound, or blocking animation. |
| `DE-MOTION-06` | Add reduced-motion test coverage | Test | P1 | Web + native | Motion implementation | CSS and native behavior remove nonessential movement while retaining equivalent status. |
| `DE-MOTION-07` | Audit animation performance on target fixtures/devices | Test / Performance | P2 | Web + native | Motion implementation | No meaningful frame-rate or input-latency regression on representative PDFs and window sizes. |
| `DE-COPY-01` | Create canonical warm/exact microcopy library | Design / Docs | P1 | Web + native | Shared state vocabulary | Copy covers loading, success, warning, failure, empty, blocked, review, undo, and recovery states without overclaiming. |
| `DE-COPY-02` | Remove anthropomorphic or certainty-overclaiming language | Copy / Test | P1 | Web + native | `DE-COPY-01` | No `magic`, `AI knows`, or probability-like confidence language appears where evidence does not support it. |
| `DE-COPY-03` | Add copy lint/check for status vocabulary | Test / Docs | P2 | Web + native | `DE-COPY-01` | A deterministic check catches forbidden status terms and inconsistent action labels. |

---

# 11. Measurement, research, and product decisions

These tasks are not optional decoration. They prevent agents from claiming delight or satisfaction improvement without evidence.

| ID | Task | Type | Priority | Dependencies | Done when |
|---|---|---|---:|---|---|
| `DE-MEASURE-01` | Establish baseline time from open to first reviewed candidate | Research / Instrumentation | P1 | Readiness events | Baseline exists by surface and fixture class. |
| `DE-MEASURE-02` | Measure candidate review completion and time per candidate | Research / Instrumentation | Candidate event model | Median, distribution, apply/dismiss/restore, and queue abandonment are available without document content. |
| `DE-MEASURE-03` | Measure apply-to-undo and dismissal-to-restore behavior | Research / Instrumentation | Recovery events | Events distinguish correction from normal use and preserve privacy. |
| `DE-MEASURE-04` | Measure export success, warnings, retries, and abandonment | Research / Instrumentation | Export state model | Outcomes are separated into validated, warning, failed, retry, and no-download states. |
| `DE-MEASURE-05` | Test first-time comprehension of source preservation and review required | User research | Copy/state design | Users can explain both concepts without being taught the answer. |
| `DE-MEASURE-06` | Collect task-level satisfaction after review and export | User research | Baseline instrumentation | Short 1-5 ratings are attached to task moments, not only end-of-session sentiment. |
| `DE-MEASURE-07` | Measure keyboard-only and VoiceOver completion | Accessibility research | Native/web proof lane | Completion and failure points are recorded with exact workflow and environment. |
| `DE-MEASURE-08` | Decide primary target audience and flagship surface | Product decision | None | Product owner records whether priority is occasional form fillers, professional operators, privacy-sensitive repeat users, browser-first, or native-first. |
| `DE-MEASURE-09` | Decide the satisfaction outcome to optimize | Product decision | `DE-MEASURE-08` | Team selects task completion, trust, speed, learnability, perceived polish, or a weighted set as the primary outcome. |
| `DE-MEASURE-10` | Decide whether reviewed corrections become a reusable dataset | Product/privacy decision | Existing correction metrics | Retention, privacy, consent, rollback, and measurement policy are documented before implementation. |
| `DE-MEASURE-11` | Decide whether native accessibility is a release gate | Product/release decision | Native evidence plan | Release policy explicitly treats accessibility as pass, conditional, or blocker. |
| `DE-MEASURE-12` | Decide warning severity policy | Product/release decision | `DE-EXP-09` | Advisory, confirmation-required, and blocking warning classes are approved and documented. |

---

# 12. Documentation and evidence tasks

| ID | Task | Type | Priority | Dependencies | Done when |
|---|---|---|---|---|---|
| `DE-DOC-01` | Create shared interaction contract document | Docs | P0 | `DE-P0-12` | Native/web state, copy, action, motion, focus, and evidence semantics live in one canonical document. |
| `DE-DOC-02` | Add UX decision records for candidate review and export finish line | Docs | P0 | Product direction | Each record contains context, alternatives, rationale, tradeoffs, assumptions, evidence plan, rollback, owner, and revisit trigger. |
| `DE-DOC-03` | Maintain an evidence index for delight claims | Docs | P1 | Measurement plan | Every satisfaction, speed, accessibility, and trust claim names its tier, sensitivity, fixture/user population, and boundary. |
| `DE-DOC-04` | Add runbook for web interaction verification | Docs / Test | P1 | Existing web tests | Agents can reproduce candidate review, dismissal persistence, undo, export outcomes, reduced motion, and accessibility checks. |
| `DE-DOC-05` | Add runbook for native interaction verification | Docs / Test | P1 | Native runtime access | Agents can reproduce window, lifecycle, recovery, search, candidate, export, VoiceOver, keyboard, and reduced-motion flows. |
| `DE-DOC-06` | Update DESIGN.md with adopted delight rules | Docs | P1 | Approved interaction contract | Design system includes next-action hierarchy, review stance, progress, recovery, motion, and copy rules without creating a competing palette. |
| `DE-DOC-07` | Keep the task registry status current | Docs / Coordination | P0 | None | Every task has owner, status, evidence, blockers, and next action; completed tasks link to artifacts. |
| `DE-DOC-08` | Preserve rejected/deferred directions | Docs | P1 | Decisions | No broad rewrite, no reflexive second provider, no auto-field conversion, no decorative toolbar, and no unsupported certainty claims remain explicit constraints. |

---

# 13. Agent roles and suggested ownership

| Role | Best-fit tasks | Must return |
|---|---|---|
| **UX interaction designer** | `DE-P0-01` to `DE-P0-04`, mode, candidate, empty-state, and copy tasks | Before/after flow, state model, interaction rules, edge cases, accessibility intent, and design decision record. |
| **Web UI engineer** | Web build tasks, persistence, activity strip, export states, motion, responsive behavior | Exact files changed, tests run, browser evidence, and unverified runtime limits. |
| **Native SwiftUI/AppKit engineer** | Native mode, candidate, recovery, command, lifecycle, toolbar, and parity tasks | Exact ownership boundaries, source-of-truth impact, native tests, and window/runtime caveats. |
| **Accessibility specialist** | Keyboard, VoiceOver, focus, dialog, reduced-motion, semantic state tasks | Workflow matrix, observed announcements, keyboard sequence, environment, and residual failures. |
| **PDF/contracts engineer** | Candidate provenance, export validation, overlay identity, source binding, provider gates | Contract changes, mutation tests, fixture coverage, and evidence-tier boundaries. |
| **Security/privacy engineer** | Recovery threat model, vault boundary, provider/locality claims, external links | Threat model, safe-failure behavior, privacy/logging review, and explicit unresolved risk. |
| **Performance engineer** | Open/readiness, rendering, projection, undo/recovery, export budgets | Fixture matrix, measurement method, budgets, regressions, and fallback behavior. |
| **Researcher / evaluator** | Calibration, user comprehension, satisfaction, interaction analytics, provider comparison | Source/protocol, sample, metric definitions, counter-evidence, and uncertainty. |
| **Documentation/release owner** | Decision records, runbooks, evidence index, release gates, task registry | Canonical doc path, status, provenance, evidence links, and follow-up owner. |

## Safe parallelization

These tracks can proceed in parallel once shared vocabulary and ownership are agreed:

1. **Web interaction lane:** candidate card, undo toast, dismissal persistence, export states.
2. **Native proof lane:** build, two-window, commands, recovery, accessibility runtime checks.
3. **Design/copy lane:** state vocabulary, microcopy, motion tokens, decision records.
4. **Measurement lane:** event taxonomy, baseline protocol, comprehension/satisfaction study.
5. **Security/recovery lane:** payload threat model, retention, transaction semantics, failure injection.

Do not edit the same shared component or contract concurrently without a named owner and a re-read of live state before each edit.

## Hard dependencies and gates

```text
DE-P0-12 shared state vocabulary
  -> candidate/export/empty-state copy and implementation

candidate state authority
  -> review-next, dismiss-next, progress, recovery strip, measurement

recovery threat model + lifecycle policy
  -> payload retention, encryption, transaction, recovery claims

native scene/window ownership + command contract
  -> native runtime accessibility and two-window evidence

structured validation policy
  -> export outcome copy, warning handling, release claims

user/audience decision
  -> final tone, pacing, measurement priority, rollout order
```

## Do-not-start list

Agents should not begin these as “delight” workarounds:

- A broad native rewrite before source/session ownership and evidence boundaries are settled.
- A second PDF provider as a reflexive response to UX dissatisfaction.
- Automatic conversion of every detected region into a native field.
- Decorative gradients, glassmorphism, confetti, sound, or gamification in the core document workbench.
- Probability-like candidate confidence labels without calibration evidence.
- Export-success copy based only on provider-local reopenability.
- Telemetry that records raw PDF text, values, signatures, template values, or sensitive recovery payloads.
- A second competing state store, event pipeline, palette, or interaction vocabulary.

## Completion contract for every agent task

Every completed task must report:

1. Exact user-facing behavior changed or evidence produced.
2. User, team/business, and internal value.
3. Exact files changed or artifacts created.
4. Commands/checks run and outcomes.
5. Evidence tier and test sensitivity.
6. Observed, verified, inferred, proposed, unknown, and contested claims.
7. Remaining risks and a concrete hardening path.
8. Documentation and task-registry updates.
9. Uncommitted work preserved; no Git mutation unless separately authorized.
10. Follow-up decisions, approvals, or runtime gates still required.

## Initial recommended assignment order

1. `DE-P0-12` — shared interaction-state vocabulary.
2. `DE-P0-05` — verify/fix browser dismissal persistence.
3. `DE-P0-01` + `DE-P0-02` — candidate decision card and synchronized focus.
4. `DE-P0-03` + `DE-P0-07` — review-next/dismiss-next/undo rhythm.
5. `DE-P0-08` + `DE-P0-09` — export progress and outcome summary.
6. `DE-P0-10` + `DE-P0-11` — export recovery and technical disclosure.
7. `DE-OPEN-05` — browser pending-work protection.
8. `DE-NATIVE-01` through `DE-NATIVE-10` — native evidence and accessibility lane.
9. `DE-MEASURE-01` through `DE-MEASURE-07` — measurement and user validation.
10. `DE-ADV-01` through `DE-ADV-09` — advanced controls and provider lifecycle after the core loop is stable.

## Registry status

- **Inventory status:** Complete for the redesign audit and current native application audit scope.
- **Product implementation status:** Not changed by this document.
- **Evidence status:** Primarily T1/static planning, informed by existing T2/T3 artifacts; native T4 workflow proof remains open.
- **Next registry action:** Assign owners and move only the approved tasks to `in_progress`; preserve dependencies and evidence boundaries.
