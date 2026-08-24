# Performance Lane B: Edit State and Undo Scalability

**Date:** 2026-08-24  
**Scope:** native Swift edit pipeline, undo replay, and future redo seam  
**Owner:** Performance Lane B  
**Evidence level:** Tier 1 static inspection; no tests or verification commands run by request

## Outcome

The native preview now keeps a bounded ring of in-memory PDFKit replay
checkpoints. Every eighth successful edit may create one checkpoint, and at most
eight checkpoints are retained. Undo restores the newest checkpoint at or before
the target history position and replays only the short tail after that point.
When no usable checkpoint exists, the existing cached-source replay path remains
the correctness fallback.

This removes the common recent-history case where undo must reopen the whole
source document and replay the entire edit log. It does not claim that PDFKit
copying or export validation is constant-time: checkpoint creation is a bounded,
periodic full-document copy, and export still intentionally reopens and validates
the staged output.

## Current architecture observed

- [`AppModel.swift`](/Users/pranay/Projects/pdf_editor/Sources/PDFEditorApp/AppModel.swift) owns the live `PDFDocument`, the append-only `operations` array, cached source bytes, and the native undo action.
- Each successful native-field, synthesized-field, or overlay mutation applies directly to the live PDFKit document and then appends its typed `EditOperation`.
- Before this lane, undo removed the last operation, reopened a new `PDFDocument` from cached source bytes, replayed every remaining operation, and replaced the live document.
- [`DocumentModel.swift`](/Users/pranay/Projects/pdf_editor/Sources/PDFEditorCore/DocumentModel.swift) defines the provider-neutral `EditOperation` and `PDFProvider` contracts. `EditOperation` carries `previousValue`, but that is sufficient only for some native field inverses, not for every supported mutation.
- [`PDFKitProvider.swift`](/Users/pranay/Projects/pdf_editor/Sources/PDFEditorCore/PDFKitProvider.swift) represents overlays and synthesized widgets through PDFKit annotations. The current operations do not persist a provider-owned annotation identity that would make direct inverse mutation unambiguous.
- Export intentionally loads the source, applies the complete operation list, writes a temporary copy, reopens both source and output for validation, and publishes only after fail-closed checks pass. This lane leaves that contract unchanged.

## Implemented bounded improvement

The checkpoint cache has these properties:

- Checkpoints are created only after a mutation has successfully applied and been appended to history.
- A checkpoint stores an in-memory copy of the already-mutated PDFKit document plus its operation count.
- Undo selects the latest checkpoint not newer than the target cursor and replays only operations after that checkpoint.
- The cache is capped at eight checkpoints, so retained document snapshots have a fixed upper bound independent of edit-history length.
- If a checkpoint cannot be copied or replaying from it fails, undo falls back to the pre-existing cached-source replay path.
- Undo commits atomically: the operation and candidate state are removed only after the replacement document has been rebuilt successfully.
- Viewer rotation is reapplied after restoration because it is derived reader state, not part of the edit log.
- Opening a new source clears the checkpoint cache with the operation log.

The implementation does not change operation meaning, export ordering, source
binding, provider validation, output publication, or the user-visible PDF
content produced by a given retained operation sequence.

## Invariants preserved

1. The original source bytes remain immutable and cached for recovery.
2. The operation log remains the canonical semantic history; checkpoints are disposable derived state.
3. Provider application remains the only mutation path for the native preview.
4. Replay uses the exact original operation order and the existing provider validation behavior.
5. Unsupported or destructive operation kinds remain rejected by the provider.
6. Failed undo reconstruction does not discard the operation or candidate state.
7. Export still uses a new output path, validates source digest and output reopenability, and refuses publication when validation fails.
8. Existing PDF fidelity behavior remains governed by PDFKit and the current save/reopen and outside-region checks.

## Why direct inverse mutation is not yet safe

Directly calling an inverse on the current PDFKit document would be faster, but
the present contract does not make that generally safe:

- Native field value edits have a `previousValue`, but widget state can be typed and provider-normalized.
- Overlay text and character-grid edits create one or more new annotations without a durable annotation ID in `EditOperation`.
- Choice marks are matched by visual contents and bounds during validation, which is not a unique identity if the source already contains an equivalent annotation.
- Synthesized fields have deterministic names, but a direct removal policy would still need a provider-owned creation token and collision rules.
- A failed partial inverse could leave a PDFKit document in a state that no longer corresponds to the operation log, which would violate fail-closed recovery.

For these reasons, checkpoints are the smallest safe optimization available at
the current boundary. They reduce replay work without inventing semantics for
inverse operations.

## Exact future integration seam for redo and deeper scaling

The next architectural step should be additive and provider-neutral:

1. Introduce an edit-history cursor with `applied`, `undone`, and `redo` operation sequences. A new edit after undo truncates redo history.
2. Change the provider mutation result from `Void` to a typed, non-persisted `AppliedMutation` containing the operation ID, provider-local mutation token(s), and an explicit inverse capability.
3. Require each provider to declare whether its inverse is exact, recoverable by checkpoint replay, or unsupported. Unknown inverse capability must fail closed to replay.
4. Give created annotations and synthesized widgets provider-owned identities that are scoped to the current in-memory document, without changing the persisted `EditOperation` contract until cross-provider semantics are agreed.
5. Move checkpointing behind a core `EditHistory` abstraction with a bounded memory budget and source-digest/session identity. The native adapter can use PDFKit copies; a web adapter can choose an equivalent provider-native snapshot or replay strategy.
6. Add an export seam that accepts an already-bound document session only after the provider can prove source identity and validation equivalence. Keep the existing URL-based export as the fallback and do not bypass source/output reopen validation.

The falsifier for this design is a provider/document combination where PDFKit
copies are not independent mutable snapshots, or where checkpoint restore
changes page geometry, widget state, annotation ordering, or outside-region
rendering relative to source replay. That requires targeted provider evidence
before the checkpoint path can be promoted beyond its fallback role.

## Follow-up risks

- Checkpoint creation itself performs a periodic full-document copy and may increase peak memory for large PDFs. The eight-checkpoint cap bounds retained snapshots but does not guarantee a fixed byte budget because document sizes vary.
- Older history beyond the retained checkpoint ring still falls back to full source replay.
- No redo command is currently exposed in the native UI or shared provider contract. Adding redo safely depends on the provider-owned inverse/recoverability seam above.
- Export remains O(file size + operation replay + validation), by design. Optimizing that path requires a source-bound provider session and independent proof that validation semantics are unchanged.
- No tests or verification commands were run in this lane, so checkpoint independence, memory behavior, and replay equivalence remain unverified claims pending focused coverage.

## Changed files

- [`Sources/PDFEditorApp/AppModel.swift`](/Users/pranay/Projects/pdf_editor/Sources/PDFEditorApp/AppModel.swift): bounded replay checkpoint ring, source fallback, atomic undo commit, and rotation preservation.
- [`docs/roadmaps/performance-lane-b-edit-state.md`](/Users/pranay/Projects/pdf_editor/docs/roadmaps/performance-lane-b-edit-state.md): this design, implementation record, invariants, integration seam, and risks.
