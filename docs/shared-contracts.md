# Shared Native/Web PDF Contracts

**Status:** Version 1.0 design and Swift implementation
**Date:** 2026-08-24
**Canonical implementation:** `Sources/PDFEditorCore/SharedContracts.swift`, `Sources/PDFEditorCore/TemplateContracts.swift`, additive fields in `DocumentModel.swift`, and browser adapters under `web/`

## Purpose

The native macOS app and the web app should share intent and safety semantics without requiring the same PDF engine. PDFKit, PDF.js, pdf-lib, PDFBox, and a future companion provider can each translate their own object model into these contracts.

The contracts cover:

- document inspection and provenance;
- page-space coordinates;
- uncertain static-field candidates and their evidence;
- user review decisions;
- typed edit operations;
- structured validation checks and reports.

The original PDF bytes remain outside the JSON contract. The contract carries the source filename, byte count, and SHA-256 digest so an adapter can detect stale or mismatched input before applying an operation.

## Version envelope

Every cross-platform payload is wrapped in `PDFContractEnvelope`:

```json
{
  "header": {
    "contractName": "pdf-editor.document",
    "version": { "major": 1, "minor": 0 },
    "sourceDigest": "<sha256>",
    "generatedAt": "2026-08-24T00:00:00Z",
    "provider": {
      "id": "pdfkit",
      "version": "macOS",
      "platform": "macOS",
      "capabilities": ["render", "forms"]
    }
  },
  "payload": {}
}
```

The initial compatibility rule is deliberately conservative:

- same major version is required;
- incoming minor version must be less than or equal to the reader’s supported minor version;
- a future major or minor version is rejected before PDF mutation;
- additive Swift fields decode with safe defaults when reading an older candidate record;
- unknown enum values remain a hard decode error until the adapter explicitly maps them to an `unknown` or `unsupported` state.

This rule favors safety over permissive forward decoding because an enum value can change mutation semantics, especially for redaction, flattening, signatures, or page operations.

## Browser pre-export mutation gate

The browser adapter has a single fail-closed preflight at the boundary between
the edit ledger and pdf-lib. It is implemented in
[`web/pdf-contract-mutation-gate.mjs`](../web/pdf-contract-mutation-gate.mjs)
and is called by `materializeOperations()` before `PDFDocument.load()` or
`PDFDocument.save()`.

The gate checks, in one place:

- every operation's source digest against the freshly hashed source bytes;
- operation kind against the browser writer's actually implemented set;
- explicit `destructive` and non-reversible flags;
- the presence and page identity of page-space coordinates;
- bounds equality between the operation and its coordinate region;
- points, lower-left, crop-box coordinate space and page rotation;
- known validation report and check statuses, with `unknown` and future values
  rejected before writing.

The current browser writer set is intentionally exact rather than aspirational:
`nativeFieldValue` and `overlayText` are the only operation kinds permitted to
reach pdf-lib today. Long-term operation kinds remain part of the shared
contract vocabulary, but they cannot cross this provider boundary until their
writer and validation paths exist. This prevents a queued operation from being
silently ignored by a provider that only implements a subset of the contract.

Stable browser rejection codes are `staleSourceDigest`,
`unsupportedOperation`, `destructiveOperation`, `unknownValidationState`, and
`coordinateMismatch`. `ContractMutationError` retains all issue codes and
operation IDs for user-visible recovery and test assertions. The exported
`guardedPdfLibExport()` seam runs the same preflight before a writer callback,
which lets browser tests prove that rejected mutations do not call the writer.

## Document contract

`PDFDocumentContract` is an envelope around the existing `DocumentInspection` model. It includes:

- immutable source identity and digest;
- provider and platform provenance;
- page count, labels, boxes, rotation, text presence, and annotation counts;
- native fields and choices;
- static candidates;
- warnings, links, outlines, metadata, permissions, attachments, accessibility, and security summaries.

The provider descriptor is evidence metadata. It is not a promise that two providers have identical behavior.

## Template and profile contracts

Recurring completion uses two separate versioned envelopes:

- `pdf-editor.template` contains a keyed layout fingerprint, reviewed mapping
  selectors, revision lineage, lifecycle, and review policy. It does not store
  raw source bytes, raw labels by default, or profile values.
- `pdf-editor.profile` contains versioned semantic-key values in a separate
  local storage scope. A completion session may resolve a value from a profile,
  but the value is copied only into the user-approved operation and never back
  into the template.

The native implementation is in
[`TemplateContracts.swift`](../Sources/PDFEditorCore/TemplateContracts.swift).
The browser adapter is in
[`pdf-template-contract.mjs`](../web/pdf-template-contract.mjs) and is exposed
through the browser fixture API for native/web JSON and matching experiments.

The shared template match state space includes `exact`, `knownVariant`,
`familyMatch`, `ambiguous`, `stale`, `noMatch`, and `unsupported`. The current
production browser/native proposal matcher is deterministic for exact,
known-variant, no-match, and lifecycle states; thresholded family and ambiguity
classification is currently exercised by the separate reviewed benchmark
adapter. Even an exact match has
`requiresMappingReview: true` and `requiresValueReview: true`. A matcher result
cannot authorize mutation and cannot replace the source-bound `EditOperation`
precondition.

The reviewed matching benchmark uses a separate report shape rather than
changing the document or template envelope:

```text
TemplateMatchBenchmarkReport
  benchmarkVersion
  policy
  fixtureCount
  counts by expected state
  cases[]
    fixture ID
    expected and actual state
    expected and actual selection
    score components
    false-positive and no-selection gates
```

This report is calibration evidence. It does not become a template record and
cannot authorize an edit operation. `ambiguous`, `stale`, and `noMatch` cases
must have a null selection. The report also supports a deliberate weakened-
policy mutation, which must fail on the hard-negative and ambiguity fixtures.

### Native/web parity bundle

The native and browser adapters emit a common fixture bundle for corpus parity:

```text
pdf-editor.browser-fixture
  document: PDFDocumentContract
  coordinates: PDFCoordinateEnvelope
  candidates: RegionCandidate[]
  editSession: PDFEditSessionEnvelope
  validation: ValidationReport | null
```

`Tests/pdf_contract_parity_test.mjs` compares normalized semantic projections
of both bundles. It ignores random IDs, timestamps, provider versions,
diagnostic prose, output digests, and browser-only metadata, but it does not
ignore source digest, page geometry, field semantics, candidate evidence,
operation lineage, validation state, security, or accessibility state. The
first corpus baseline is preserved in
[`docs/audits/native-web-contract-parity-evidence-2026-08-24.md`](audits/native-web-contract-parity-evidence-2026-08-24.md).

The runtime completion contract adds a second envelope in memory, rather than
changing the template payload:

```text
PDFTemplateContract + PDFProfileContract + PDFTemplateMatchProposal
  -> PDFTemplateCompletionProposal
  -> mapping review + value review + native target resolution
  -> EditOperation[] bound to the current sourceDigest
```

`PDFTemplateCompletionProposal` is the authority for one document session. It
records the match state, template/revision IDs, source digest, mapping review
state, profile revision reference, resolved value review state, page-space
target, and current native target resolution. It refuses stale sources,
unreviewed mappings, unreviewed values, coordinate page mismatches, missing
native target IDs, and unsupported value kinds. It never mutates PDF bytes.

`PDFTemplateLearningEvent` is append-only and starts `pending`. The strict
revision gate accepts only a validated and reopenable export whose source
digest matches, source remains unchanged, and whose checks contain no failed
or unknown state. `validatedWithWarnings` is not sufficient to change future
template behavior.

### Capture and revision lineage

The shared T1 capture sequence is intentionally explicit:

```text
DocumentInspection + keyed fingerprint
  -> draft PDFTemplateContract
  -> complete mapping review decisions
  -> new active child PDFTemplateContract
  -> append to PDFTemplateRevisionSet / browser revision history
```

`PDFTemplateCapture.captureDraft` and browser `captureTemplateDraft` require a
source digest and produce value-free proposed mappings. Activation is a pure
value transition that returns a new revision. It does not mutate the draft,
reuse its revision ID, or treat an incomplete review as approval. Native
`PDFTemplateRevisionSet` and browser `appendTemplateRevision` reject duplicate
revision IDs, mismatched template IDs, and missing parent revisions.

The native and browser implementations deliberately share the serialized
shape and invariants, not provider APIs or byte output. The native round-trip
test and Node/browser round-trip tests cover keyed fingerprints, no-raw-content
capture, draft immutability, parent linkage, confirmed/rejected mapping states,
and append-only history.

### Browser encrypted storage lifecycle

The browser store is a separate persistence contract around the template and
profile envelopes. It does not change their JSON shape or copy source PDF
bytes.

```text
locked
  -> unlock(store passphrase)
  -> ready
  -> unlockProfile(profile passphrase)
  -> profile-readable session
  -> lockProfile / lock

ready + missing authenticated metadata + presence hint
  -> evicted
  -> restoreEncryptedBackup(ciphertext backup)
  -> ready
```

Store records use an authenticated AES-GCM envelope. The store metadata record
authenticates the PBKDF2-derived store key. Profile values use a second
profile-specific AES-GCM envelope and a separate unlock passphrase. `list`
returns record identity metadata only; `get(profile, ...)` refuses to return
values until the profile is unlocked.

`exportEncryptedBackup` and `restoreEncryptedBackup` operate on ciphertext
records, never parsed template or profile values. `deleteStore` removes the
IndexedDB database and its non-sensitive presence hint. The store health result
uses `uninitialized`, `locked`, `ready`, and `evicted` states, with quota
estimates treated as advisory browser telemetry rather than a durability
guarantee.

Diagnostics use an allowlisted zero-content event schema. Events may contain
only event code, record kind, storage mode, state, and count. They must not
contain document IDs, labels, profile values, PDF bytes, passphrases, stack
traces, or arbitrary exception messages.

Native encrypted records are sealed by
[`TemplateStoreCodec.swift`](../Sources/PDFEditorCore/TemplateStoreCodec.swift)
using AES-GCM; Keychain custody remains a native-app concern. The browser
store in [`pdf-template-store.mjs`](../web/pdf-template-store.mjs) uses
passphrase-derived AES-GCM ciphertext in opt-in IndexedDB, with an explicit
ephemeral mode and no plaintext fallback. Neither store accepts raw PDF bytes
inside template/profile records.

## Coordinate contract

`PDFPageRegion` is the canonical coordinate-bearing type:

```text
PDFPageRegion
  pageIndex
  rect: PDFRect
  coordinateSpace
    unit: points
    origin: lowerLeft or upperLeft
    pageBox: media, crop, bleed, trim, or art
    rotationDegrees
```

The default is PDF user space: points, lower-left origin, crop box, and zero rotation. Browser viewport coordinates must be converted at the adapter boundary. A web canvas or native `PDFView` must never become the source of truth for persisted edit geometry.

The page index is zero-based and the rectangle is expressed in the coordinate system named in the same object. This prevents a rotated page or a top-left browser canvas from being mistaken for unrotated PDF page coordinates.

## Candidate and evidence contract

`RegionCandidate` remains the existing product model, with additive structured fields:

- `kind`: where the candidate came from, such as vector region, text anchor, OCR, or manual input;
- `status`: suggested, confirmed, rejected, or unknown;
- `score`: a detector score, never proof;
- `suggestedFieldType`: text, date, number, checkbox, radio, choice, signature, or unknown;
- `coordinate`: page-space region when available;
- `sourceDigest`: document fingerprint that produced the candidate;
- `evidenceItems`: typed evidence records.

Each `CandidateEvidence` record identifies:

- evidence kind, such as label text, underline, vector rectangle, OCR text, or repeated pattern;
- origin, such as provider, text extraction, geometry extraction, OCR, or user;
- human-readable summary;
- optional source text;
- optional page-space region;
- optional evidence score;
- optional provider descriptor.

This keeps “why was this suggested?” available to both UIs. A static detector may emit a candidate, but only a user review decision may confirm, move, resize, retype, or manually create it.

## Edit operation contract

`EditOperation` is append-only and carries:

- stable operation ID;
- target page and optional target field ID;
- operation kind;
- legacy `value` for current provider compatibility;
- optional structured `payload` for text, boolean, choice, asset, or stamp data;
- optional candidate and session IDs;
- parent operation ID for replay lineage;
- source digest and page-space coordinate;
- previous value when available;
- `reversible` and `destructive` flags;
- creation timestamp.

The operation vocabulary includes current native values, text overlays, images, stamps, annotations, page transforms, page insertion/deletion/move, flattening, redaction marking/application, metadata, and sanitation. The PDFKit provider currently implements only native values and text-like overlays. Unsupported kinds fail visibly.

The `destructive` flag is descriptive and must not be trusted as the only guard. The export pipeline still needs an explicit policy for flattening, redaction, sanitation, and signature operations.

## Validation contract

`ValidationReport` keeps the current compatibility fields:

- overall status;
- user-facing messages;
- source unchanged;
- output reopenable.

It now also carries:

- structured `ValidationCheck` records;
- source and output digests;
- provider descriptor;
- validation timestamp;
- operation IDs covered by the report.

Validation checks distinguish passed, warning, failed, skipped, and unknown states. Check kinds include source digest, output reopen, page geometry, native fields, applied operations, outside-region text, visual diff, independent viewer, security, accessibility, and provider capability.

This prevents a single green boolean from hiding the difference between “not run,” “not supported,” “passed locally,” and “independently verified.”

## Native and web mapping

| Contract | Native macOS | Web |
|---|---|---|
| Document envelope | PDFKit inspection adapter | PDF.js inspection adapter |
| Coordinate region | PDFKit page bounds and crop/rotation conversion | PDF.js viewport conversion back to page space |
| Candidate evidence | Swift geometry/text/Vision adapters | TypeScript geometry/text/OCR worker adapters |
| Edit operation | PDFKit mutation adapter | pdf-lib or companion writer adapter |
| Validation report | PDFKit reopen plus independent checks | pdf-lib/PDF.js reopen plus companion or independent checks |
| Session persistence | File-backed local session | IndexedDB/OPFS or explicit export/download |

The shared contract does not claim byte-identical output. It claims that both surfaces can explain the same user intent and validation result.

## Required invariants

1. Never apply an operation to a source digest different from the one recorded in the session.
2. Never convert a suggested candidate into a mutation without a review decision.
3. Never use viewport coordinates as persisted page coordinates.
4. Never call a cover/whiteout operation redaction unless permanent removal was independently verified.
5. Never treat a visual signature as a cryptographic signature.
6. Never report a skipped or unknown validation check as passed.
7. Never overwrite source bytes by default.
8. Preserve the operation log when export or validation fails.

The native provider enforces the source-digest invariant during export and the
coordinate/destructive shape invariants during direct application as well as
export. Operations with a nil digest remain a compatibility path; a non-nil
stale digest is rejected before PDF mutation or publication. An explicit
`unknown` validation-check state remains distinct from `passed`, while an
unrecognized future enum value is rejected during decoding.

## Test coverage added

The core tests cover:

- document envelope JSON round-trip and version negotiation;
- backward decoding of an older candidate record without additive evidence fields;
- rotated page-space coordinate preservation;
- structured choice payload round-trip;
- edit-session source binding;
- validation-check and operation lineage round-trip.
- stale source-digest rejection before mutation and publication;
- unsupported operation rejection with named diagnostics;
- destructive-operation rejection without provider policy;
- coordinate page and bounds mismatch rejection;
- explicit unknown validation state preservation and future enum rejection.

The negative and mutation-sensitive evidence is recorded in
[`docs/audits/contract-negative-test-evidence-2026-08-24.md`](audits/contract-negative-test-evidence-2026-08-24.md).

The remaining proof is adapter-level: native and browser providers must be run against the same fixtures and must produce reports that satisfy the same invariants.

## Session privacy and export provenance contract

`pdf-editor.session-provenance` is the lifecycle-level contract above document
preflight. It binds one session to one source digest and records:

- processing locality and source input class;
- data egress state, including runtime-only network activity;
- OCR use, provider IDs, processed page count, and OCR retention flags;
- source retention class, session-end retention, deletion state, and bounded
  source-copy count;
- export state, source/output digests, storage class, validation state, reopen
  evidence, operation count, and exporter/validator IDs.

The contract serializes explicit false privacy flags for source bytes, document
text, OCR text, field values, filenames, and URLs. These fields make the
zero-content policy machine-checkable; they do not carry any of those values.
Unknown states remain explicit. Successful export requires output identity,
validation, and reopen evidence. A stale digest, privacy leak flag,
contradictory OCR state, or incomplete successful export is rejected.

Native recovery envelopes carry the contract as `privacyProvenance`, while the
browser fixture exposes `sessionProvenance`. The full evidence is in
[`audits/session-privacy-provenance-evidence-2026-08-25.md`](audits/session-privacy-provenance-evidence-2026-08-25.md).
