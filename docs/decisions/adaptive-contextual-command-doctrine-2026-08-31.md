# Adaptive Contextual Command Doctrine

**Date:** 2026-08-31  
**Scope:** native macOS PDF document window, contextual menus, command palette, page rail, inspector, and menu-bar command parity  
**Primary persona:** PER-0926 - Product Evolution Architect  
**Review persona:** PER-0428 - Review and Evidence Steward  
**Status:** implemented first slice, with native observation and comparative research still open

## Decision in one sentence

Contextual menus may become quieter or more useful as the current document
interaction changes, but direct interaction state decides which actions are
eligible, capability and permission state decides whether an action is allowed,
and bounded local command history can only rank already-valid actions.

## Conversation evidence

The user proposed a behavior-aware PDF menu: while a PDF is being opened and
scrolled, show reader actions; after the user clicks or selects content, reveal
marking and editing actions. The intent is a context-sensitive Mac surface that
does not present the entire product at every moment.

The proposal is accepted with one precise correction: a click without a stable
target is still reading context. Text editing and marking become eligible only
when the document reports a text selection, form field, annotation, image/object,
or page-thumbnail target. A click cannot grant permission, infer intent, or
create an operation.

## Comparison with the fixed-menu recommendation

| Model | Strength | Failure mode | Decision |
|---|---|---|---|
| Fixed all-capabilities menu | Strong recall and predictability | High noise; reading becomes a toolbox inspection task | Keep only for stable menu-bar recovery and command inventory |
| Direct-context menu | Quiet, task-relevant, explainable | Can hide an action if the target detector is weak | Use as the visibility authority for contextual surfaces |
| Behavior-only menu | Feels personalized | Hidden profiling, unpredictable relocation, risky intent inference | Reject |
| Direct-context plus bounded local ranking | Quiet and useful, while preserving recovery | Needs a reset path and discoverability study | Adopt |
| User-pinned commands | Explicit personalization and strong recall | Pins can become stale after capability changes | Adopt as a user-controlled ordering hint; never bypass eligibility |

## First-principles test

The underlying problem is not “how do we make menus dynamic?” It is “which
action is truthful and useful at this exact interaction point?” The minimum
truthful primitive is therefore a projection of:

```text
direct target + document capability + permission/provider outcome
```

Only after that projection is valid may presentation order use a small local
preference. This keeps visibility explainable and prevents a previous action
from becoming an authorization mechanism.

## Long-term test

The contract is stable across PDFKit, a form-aware provider, OCR, and future
local companions because the policy consumes capability facts and typed
outcomes rather than provider names. The target vocabulary can grow with
annotation and image/object detection without changing the meaning of existing
reader, selection, form, page, and recovery anchors.

The current history implementation is intentionally an LRU-like list of at
most eight semantic command IDs. Recent hints expire after twelve later
command interactions, without storing wall-clock timestamps. Explicit pins
are separate and persist until the user clears them, but capability and target
eligibility still filter them before promotion. The store records no PDF
content, document names, URLs, cursor paths, regions, or network telemetry.
The remaining long-term questions are whether twelve interactions are
comprehensible in practice, how stale pins should be surfaced after catalog or
capability changes, and whether reset controls are discoverable.

## Doctrine test

The implementation preserves the project control plane:

- `AdaptiveCommandPolicy` is framework-neutral and does not mutate a document.
- `AdaptiveCommandContext` is the only native-to-core capability mapping for
  the current surfaces.
- `AppModel` remains the mutation and permission authority.
- `AppModel.ActionDenial` exposes only read-only action, requirement, and
  explanation projections to the native inspector. The inspector can explain
  a concrete permission denial without changing the policy result or granting
  a capability.
- `resolve` returns only actionable commands for compact contextual menus.
- `assess` retains explainable unavailable, blocked, and needs-review states for
  host surfaces that must explain why a command is absent or disabled.
- menu-bar commands, shortcuts, command palette, and `More Actions` remain
  recovery paths when a contextual projection is quiet.
- local personalization is visible in Settings and can be disabled or cleared.
- post-export disposition is explicit: Rework returns to live operations,
  Accept Variance preserves the warning state and requires a present output,
  and Discard requires a present output plus confirmation. These controls are
  recovery actions, not a claim that failed or warning validation became
  verified. The value-minimized pre-export receipt is durable in
  `DocumentSession`, while output URL, output bytes, and post-export
  disposition remain host-memory state until a separate output identity and
  recovery policy is approved.

## Current source evidence

| Claim | Evidence |
|---|---|
| Selection-specific visibility is target-gated | `Sources/PDFEditorApp/AdaptiveDocumentContextMenu.swift`: target is `textSelection` only for non-empty PDFKit selection; otherwise it is `documentScrolling` |
| Policy validity precedes ranking | `Sources/PDFEditorCore/AdaptiveCommandPolicy.swift`: `resolve` calls `assess`, filters to actionable decisions, then ranks the valid set |
| Behavior cannot authorize | `AdaptiveCommandHistory` stores semantic IDs only; `AppModel` still performs final permission and ledger checks |
| Pre-export review facts survive recovery without resumable output authority | `DocumentSession.exportReviewReceipt` is optional and value-minimized; the session privacy round-trip proves older envelopes still decode and no output path/bytes are persisted |
| Weak target inference abstains | `AdaptiveTargetConfidence` plus `targetNeedsConfirmation`; provisional or ambiguous target-bound commands are withheld while reader/document anchors remain available |
| Stable recovery exists | `Sources/PDFEditorApp/AppCommands.swift`, command palette, menu-bar commands, and contextual-menu `More Actions` projection |
| User control exists | `Sources/PDFEditorApp/ContentView.swift` Settings projection plus `AdaptiveCommandHistory.setPersonalizationEnabled` and `clear` |
| Focused contract proof exists | `AdaptiveCommandPolicyTests` and `AdaptiveCommandHistoryTests`; build and focused adaptive test lane passed on 2026-08-31 |
| Native UX proof is partial | The current packaged preview exposes one `AXWindow`/`AXStandardWindow` at `1280x820` and the standard menu/File tree; source-level landmarks now identify page navigation, document canvas, and inspector, while control-level AX labels, keyboard/focus, VoiceOver, resize, reduced-motion, and multi-window evidence remain open |

## Guardrails

1. Never record raw clicks, scroll depth, pointer movement, document identity,
   selected text, or page regions for menu personalization.
2. Never use history to reveal a command whose direct target or capability
   contract is absent.
3. Never use history to bypass permission, provider admission, review, or
   export validation.
4. Never remove the menu-bar, shortcut, command-palette, or deterministic
   overflow recovery path because an action is not recently used.
5. Keep high-impact actions such as export, permanent redaction, flattening,
   sanitization, and destructive page operations behind their own review and
   confirmation contracts. Recency may not silently promote execution.
6. If target detection is uncertain, show a safe reader/document projection and
   an explainable path to inspect or choose more actions.

## Open work to research and document

| ID | Question | Falsifier | Required artifact |
|---|---|---|---|
| NM-R11 | Does bounded ranking improve completion without reducing recall or predictability? | Users cannot find a command after it moves, or cannot explain why it appears | Fixed vs direct-context vs ranked vs pinned comparison matrix |
| NM-R12 | What aging rule keeps local command history useful without becoming a permanent profile? | A command remains promoted after the workflow has changed, or clearing is not trusted | Preference contract with bounded retention, stale-pin behavior, and reset walkthrough |
| NM-R13 | Which target signals are reliable enough for annotation and image/object menus? | False targets expose risky actions or target changes are visually ambiguous | Target-detection evidence matrix with abstention cases |
| NM-R14 | How should menus communicate a quiet projection without adding help text? | Users interpret absence as lack of capability rather than current context | Native comprehension study with menu-bar and palette recovery |

## Implementation queue

| Priority | Task | Current state | Exit evidence |
|---|---|---|---|
| P0 | Keep direct target and permission policy separate | Implemented for scrolling, text selection, form field, and page thumbnail surfaces | Policy tests plus source trace |
| P1 | Keep all valid actions recoverable through stable anchors | Implemented through `More Actions`, menu bar, shortcuts, and command palette | Projection matrix and menu-tree observation |
| P1 | Add reliable annotation and image/object targets | Sidecar annotation targets implemented; native PDF annotation and image/object extraction remain open | T2 target matrix, false-positive abstention cases, and native observation |
| P1 | Render denial and needs-review reasons in host surfaces | Core decisions plus a bounded native inspector disclosure are implemented; provider-specific presentation remains open | Permission/provider denial walkthrough, contract-to-view test, and accessibility observation |
| P1 | Keep failed export review actionable | Rework / Accept Variance / Discard contract, native controls, and 4 focused state tests implemented; durable pre-export receipt now persists | T4 failed-review observation plus output identity/disposition recovery decision |
| P1 | Define bounded history aging and stale-pin behavior | Command-distance aging and separate explicit pins are implemented; comprehension and capability-change handling remain open | NM-R12 decision record, aging/reset tests, and T4 reset walkthrough |
| P2 | Compare fixed, direct-context, ranked, and pinned variants | Open | NM-R11 study artifact and retain/reject decision |
| P2 | Add native VoiceOver, keyboard, resize, reduced-motion, and narrow-window proof | Packaging exists; supported host observation is open | T4/S3 evidence bundle |

## Rejected interpretations

- “The user clicked, so show edit.” Rejected because a click has no stable
  semantic target and can be accidental.
- “The user used export before, so export should appear first everywhere.”
  Rejected because export remains a separate review-backed workflow.
- “Hide everything the user has not used.” Rejected because hidden commands need
  stable recovery and because absence should not be mistaken for incapability.
- “Collect telemetry to learn the best menu.” Rejected for this local-first
  beta until a separately approved privacy and product-research boundary exists.

## Relationship to the native audit and roadmap

This decision supplies the doctrine for `NMAC-010`, `NMAC-012`, `NMAC-015`,
`NMAC-021`, and `NMAC-025`, and operationalizes `NM-T35` and `NM-R11` from the
native audit. It does not close the open native runtime or comparative research
gates. The source audit remains the complete findings and task inventory; this
record is the focused decision for contextual command behavior.
