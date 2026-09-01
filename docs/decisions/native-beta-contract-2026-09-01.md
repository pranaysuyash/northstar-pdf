# Proposed Native Beta Contract

**Date:** 2026-09-01  
**Status:** Proposed; owner/release acceptance required  
**Primary lens:** PER-0926, Product Evolution Architect  
**Review lens:** PER-0428, Feedback and Evidence Steward  
**Related task:** NM-T27 / NM-R10  
**Gate authority:** [`../release-gates.md`](../release-gates.md)

## Purpose

Define the smallest native macOS PDF experience that can feel coherent and
valuable without presenting partial provider work as unrestricted PDF editing.
This is a versioned beta boundary, not a permanent capability non-goal and not
a release approval.

The beta is organized around user jobs:

```text
open -> read -> understand -> review -> complete -> export a separate copy
```

The source PDF remains untouched. A beta claim is valid only when the relevant
source class, provider state, operation ledger, output reopenability, and
independent validation evidence satisfy the release registry.

## Product promise

The native app should feel like one calm document workbench:

- The home surface invites the user to open, drop, or create a document.
- The document window supports Mac-native navigation, sidebar/rail context,
  keyboard commands, adaptive contextual actions, and a focused inspector.
- The evidence rail explains what the app knows, how it knows it, and what the
  user can safely do next.
- Export is a reviewed transition to a new copy, never an implicit overwrite.
- Recovery explains available actions without silently restoring or deleting a
  document or output.

This promise describes the interaction model. It does not bypass any PDF
fidelity, provider, security, accessibility, or distribution gate.

## Candidate beta scope

| User job | Candidate beta behavior | Required evidence before claiming supported |
|---|---|---|
| Open a PDF | Open a local PDF, report password/permission/unsupported states, and show the source-bound session | T2 current-source open tests plus T4 packaged open/error walkthrough |
| Read and navigate | Render, scroll, zoom, rotate as view state, jump pages, search where text permission exists, and preserve the original source | T2 reader/reopen checks plus T4 keyboard, resize, appearance, and accessibility walkthrough |
| Understand | Show document capability/passport facts, selected-object evidence, source-linked annotations, and bounded local understanding actions | T2 contract/state checks plus T4 comprehension and unverified-state observation |
| Review | Select native fields, reviewed candidates, annotations, and page thumbnails; show limitations and next valid action | T2 target/permission matrix plus T4 field, candidate, annotation, and page-rail walkthrough |
| Complete | Apply only explicitly reviewed, source-bound bounded operations supported by the admitted provider and capability registry | T2 operation/replay tests, T3 provider/independent validation, and T4 failed/retry walkthrough |
| Export | Present the value-minimized review receipt, write a separate copy, reopen and validate it, then show explicit disposition options | T2 receipt/disposition tests, T3 output validation, T4 export/review walkthrough |
| Recover | Offer Inspect, Restore when source identity matches, and Discard with explicit confirmation; fail closed on mismatch | T2 interruption/recovery tests and T4 kill/reopen/source-mismatch walkthrough |
| Personalize | Allow bounded local command ranking, explicit pins, disable, and clear controls; direct target and capability still decide eligibility | T2 policy/history tests and T4 discoverability/reset walkthrough |

The current repository has source-level or focused-test increments for much of
this table. The required T4 and provider evidence is intentionally not implied
by those increments.

## Explicit beta non-goals

These are **not permanent product exclusions**. They remain active long-term
capability obligations in the full build program and may enter a later beta
only after their own gates pass:

- Unrestricted arbitrary text reflow or in-place editing of every existing PDF
  text run, font, glyph, ligature, reading order, or writing system.
- Existing image/object editing without a reliable native target detector and
  an admitted writer with independent preservation proof.
- Permanent content removal/redaction without irreversible-operation review,
  independent reopen validation, and a dedicated security evidence lane.
- Unverified automatic field creation, automatic candidate acceptance, or AI
  output treated as document truth.
- Radio, choice, text, XFA, signature, tagged-PDF/PDF/UA, repair, conversion,
  and other provider-sensitive operations unless their current release gates
  explicitly admit the relevant source class and writer.
- Multilingual, handwriting, or unrestricted scanned-document OCR claims.
- Silent cloud processing, background document upload, or behavior telemetry
  outside the local value-free command-preference boundary.
- Durable post-restart output deletion, acceptance, or replacement based only
  on a remembered path, receipt, or digest. The output identity decision keeps
  explicit re-selection as the beta fallback until scoped bookmark evidence
  passes.
- Collaboration, sync, or companion-provider claims without handshake,
  privacy, license, version, timeout, rollback, and independent validation
  evidence.
- Public distribution claims before codesign, notarization, update, support,
  and release-contract gates pass.

## Evidence and promotion rules

1. A source implementation can be shown in internal builds only as
   `implemented-source` or `partial` until its task oracle passes.
2. A focused test lane proves only the contracts included in that lane. It
   cannot prove full-suite health, arbitrary-PDF fidelity, native GUI quality,
   or release readiness.
3. Every native user-facing claim requires T4 evidence for the relevant
   window, input method, appearance, accessibility, and recovery path.
4. Every provider-sensitive mutation requires source binding, capability
   admission, operation identity, independent reopen validation, and explicit
   unresolved-warning handling.
5. A failed, unknown, partial, or unsupported state remains visible at the
   point of action. It cannot be converted into a beta promise by renaming it.
6. The beta contract is revised only through a dated decision record and a
   corresponding release-gate update. This document must not become a second
   gate registry.

## Current evidence boundary

As of 2026-09-01:

- Native adaptive command policy, bounded local history, target-confidence
  abstention, capability passport, export receipt/disposition contracts,
  action-first recovery, recent-document continuity, responsive home layout,
  and reduced-motion source behavior have focused source/test evidence.
- The isolated native policy/export/privacy/recovery lane passes 38 tests in
  seven suites.
- The unsigned arm64 preview package is structurally valid and registers PDF
  documents.
- Fresh GUI, drag/drop, VoiceOver, keyboard-only, reduced-motion runtime,
  narrow-window, split-view, multi-window, output-identity, provider, full
  suite, profile-writer, contract-to-view, codesign, and notarization evidence
  remain open or separately gated.
- The current worktree is dirty and concurrent. The dated native audit snapshot
  is the evidence boundary, not a claim that the checkout is frozen.

## Acceptance matrix

| Area | Entry criterion | Current disposition |
|---|---|---|
| Native shell | T4 wide/narrow toolbar, sidebar, inspector, resize, and hidden-control recovery | Open |
| Home | T4 open/new/drop/recent flow, no-overlap narrow layout, reduced motion, and accessibility | Source slice exists; T4 open |
| Context menus | T2 target/capability policy plus T4 fixed/direct/ranked/pinned discoverability study | Policy slice exists; T4 study open |
| Session ownership | T1 ownership matrix plus independent-window T2/T4 proof | Open |
| Reading | T2 source/reopen checks plus T4 keyboard/accessibility/appearance proof | Partial |
| Bounded completion | Provider-specific T3 preservation and output validation for each admitted operation | Partial/gated |
| Export review | Receipt/disposition contracts and T4 failed/reviewed export flow | Partial |
| Recovery | T2 interruption tests and T4 source-match/mismatch/forget flow | Partial |
| Distribution | Codesign, notarization, update, diagnostics, and support contract | Blocked/open external gate |

## Decision request

Adopt this as the proposed native beta boundary for internal planning, subject
to owner acceptance and release-registry reconciliation. Do not use it to
claim public support, close full-capability obligations, or bypass provider,
security, accessibility, or distribution gates.

## Revisit triggers

- The native T4 matrix reveals that the current shell cannot support keyboard,
  VoiceOver, narrow-window, or multi-window workflows without architectural
  change.
- A provider passes a new source class with independent preservation evidence.
- The output identity/bookmark research passes and changes recovery semantics.
- The owner chooses a different beta user job, supported platform, or
  distribution model.
- The full capability program or canonical release registry changes.
