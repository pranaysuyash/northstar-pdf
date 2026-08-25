# Native runtime state-machine contract

**Date:** 2026-08-25
**Owner:** Native runtime state-machine lane
**Status:** contract-only; proposed orchestration boundary
**Evidence:** Tier 1 static design; no runtime, build, test, benchmark, or verification evidence
**Write set:** `Sources/PDFEditorApp/PDFWorkCoordinatorContracts.swift` and this report only

## Outcome

This change defines the small value-only policy vocabulary needed before a
future native work coordinator can be integrated. It does not integrate the
contract into `AppModel`, `PDFKitProvider`, `ContentView`, or any other runtime
surface. It does not add `Task.detached`, an executor, a queue, cancellation
implementation, a cache, or a PDFKit isolation claim.

The Swift contract contains four independent concepts:

| Type | Meaning | Deliberate boundary |
| --- | --- | --- |
| `PDFWorkRequestGeneration` | Monotonic request ordering used for race decisions | A scalar generation only; no session, URL, path, bytes, or document identity |
| `PDFWorkKind` | The bounded work categories `open` and `export` | No provider or UI object |
| `PDFWorkLifecycle` | Request state and legal lifecycle transitions | No operation payload or error object |
| `PDFWorkPublicationDecision` | Whether a result may cross into publication | Policy only; it does not perform cleanup or mutation |

All four types are `Sendable` and value-only. They contain no PDFKit/AppKit
objects, passwords, paths, PDF bytes, task handles, closures, or UI
references.

## State-machine contract

The lifecycle has two non-terminal states and four terminal states:

```text
created -> running -> completed
                    -> failed
                    -> canceled
                    -> superseded

created -> failed
        -> canceled
        -> superseded
```

`completed`, `failed`, `canceled`, and `superseded` do not transition again.
Immediate failure or cancellation from `created` is allowed because request
admission can fail before provider work starts. `superseded` is terminal because
an obsolete result must never be revived by a late completion callback.

The transition helper is a contract predicate, not a state store. A future
coordinator remains responsible for serializing lifecycle changes and for
recording the current generation alongside the request it owns.

## Latest-wins open

Each open request receives a new generation at its admission boundary. When a
newer open is accepted, older open requests become ineligible to publish and
may move to `superseded`, whether they are still `created` or already
`running`. This is a publication rule, not a promise that synchronous PDFKit
work can be interrupted.

An older open can therefore finish provider work and still be rejected by
`PDFWorkPublicationDecision.rejectStale`. The coordinator must compare the
result generation with the current open generation immediately before any
publication-side effect. Completion order is never allowed to define the
visible document order.

Open supersession is intentionally distinct from ordinary cancellation:

- `rejectStale` means a newer request owns the publication slot.
- `rejectCanceled` means the request was explicitly canceled before it became publishable.
- `rejectFailed` means the work did not produce a publishable result.

All three paths are non-publication paths. They must not replace the current
live document or publish inspection state.

## Snapshot export

Export must leave the main-actor boundary with a coherent snapshot of the
semantic inputs it is meant to export. The snapshot is captured before work
begins and is not rebuilt from mutable UI state while the export is running.
This prevents a later edit, open, or selection change from silently changing
the meaning of an already accepted export request.

The snapshot itself is deliberately not encoded by this contract. In
particular, this file does not define or transport paths, passwords, source
bytes, PDFKit objects, or UI references. A future input-snapshot type needs its
own ownership, privacy, source-integrity, and memory review.

An export is not implicitly latest-wins merely because an open is newer. Its
publication decision must reflect the export snapshot's source/session
validity and any explicit cancellation policy. If the result no longer matches
the publication authority, the coordinator must reject it rather than publish
an output derived from stale semantic inputs.

## Stale-result rejection

Publication is a separate phase after provider work has completed. The
coordinator must evaluate, at minimum:

1. Whether the request is still the current generation for the publication domain.
2. Whether its lifecycle is still publishable and not `superseded`, `canceled`, or `failed`.
3. Whether the result is complete enough for the relevant publication path.
4. Whether required cleanup and validation have completed successfully.

Only a result that passes those checks can receive `.publish`. A late success
from an older request is still a stale result. The contract intentionally makes
rejection a first-class decision so that stale work cannot be mistaken for a
provider failure or silently dropped without an explanation in future
telemetry.

## Pre-publication cleanup

Cleanup is a prerequisite to publication, not a best-effort follow-up. For an
export, staged temporary output must be removed when work is canceled, becomes
stale, fails validation, or otherwise receives a rejecting decision before
publication. The source must remain untouched on every rejecting path.

The decision enum does not perform cleanup and does not encode a temporary
resource. That separation keeps the shared contract value-only while requiring
the future coordinator to make cleanup completion observable to its own
publication gate. If cleanup cannot be established, the result remains
non-publishable and should resolve to `.rejectIncomplete` or the more specific
rejecting decision selected by the coordinator.

## Main-actor publication

The future runtime may perform only work whose executor and native-object
ownership have been established. Regardless of where a provider-neutral value
result is produced, publication of live document state and UI-facing
projections must occur on the main actor. The generation and lifecycle checks
must be repeated at that boundary because newer work can be admitted while an
older result is in flight.

The intended sequence is:

```text
admit request
  -> capture bounded semantic snapshot
  -> run owned work
  -> validate result and finish cleanup
  -> evaluate generation/lifecycle/publication decision
  -> hop to main actor
  -> re-check publication authority
  -> publish only when decision is .publish
```

This contract does not make a background result safe to publish. It only gives
the eventual coordinator stable values with which to express ordering and
decision policy.

## Why PDFKit thread safety remains unverified

The current native path owns synchronous PDFKit/AppKit behavior across
inspection, document construction, export, validation, and presentation. The
source-level contract does not establish that those objects may be used from a
background executor, moved between threads, or accessed concurrently with
`PDFView`.

Consequently, this change intentionally does not add `Task.detached`, claim
actor isolation, or infer thread safety from `Sendable` result types. A
value-only result can cross an isolation boundary without proving that the
PDFKit objects used to create it were safe on that boundary. Cancellation also
cannot be assumed to interrupt synchronous parsing, serialization, raster
comparison, or file operations merely because a request has a lifecycle state.

The unverified questions remain:

- What executor or thread affinity does each PDFKit/AppKit operation require?
- Can inspection, export, validation, and `PDFView` replacement be serialized without object races?
- Which cancellation points are real between synchronous provider calls?
- What peak memory results from source snapshots, live documents, staged output, and validation copies?
- Can cleanup and stale-result rejection be demonstrated under overlapping open/export timing?

Those questions require an explicitly owned implementation and verification
flow. They are not answered by this contract file or by the existence of the
roadmap.

## Current scope and follow-up gates

Included now:

- A monotonic request-generation value.
- `open` and `export` work-kind values.
- Lifecycle states with explicit terminality and transition predicates.
- Publication decisions that distinguish publish, stale, canceled, failed, and incomplete results.
- A durable explanation of ordering, snapshot, cleanup, publication, and uncertainty boundaries.

Excluded now:

- `AppModel` integration.
- `PDFKitProvider` integration.
- `Task.detached`, queues, actors, or executor annotations for native PDFKit work.
- Password, path, source-byte, PDFKit, AppKit, or UI-bearing request snapshots.
- Tests, builds, benchmarks, runtime launches, or verification commands.
- Any performance, thread-safety, cancellation, memory, or release claim.

Before integration, the owner should define and independently verify the
provider/session snapshot boundary, serial native ownership, cancellation
behavior, cleanup failure handling, main-actor re-check, and stale-result
scenarios. The contract should be revisited if those checks show that the
generation domain must distinguish open, export, and document-session
authority rather than relying on one shared scalar ordering.

## Rollback and revisit trigger

Rollback is additive: remove the new Swift contract and this roadmap, leaving
the existing native runtime unchanged. Revisit this document when a coordinator
owner is assigned, when the provider isolation boundary is established, or
when the first integration design needs a more specific snapshot or
publication authority than these value-only primitives provide.
