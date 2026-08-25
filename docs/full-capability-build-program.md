# Full Native and Web PDF Capability Build Program

**Date:** 2026-08-24  
**Status:** Living implementation and exploration program  
**Scope:** Native macOS app, browser app, shared contracts, local companion
providers, corpus evidence, and release claims

**Full-capability rule:** Every capability expected from a serious PDF
reader/editor remains an implementation target. Current provider support,
licensing, resource limits, and evidence strength determine sequencing and
runtime admission, never permanent scope.

## Build obligation versus claim readiness

The capability rows in this program have two independent axes:

1. **Build obligation:** whether the native, browser, companion, hosted,
   validator, fixture, recovery, and documentation work still has to be built.
2. **Claim readiness:** whether the current provider and evidence can safely
   expose that capability for a specific document class or make a user-facing
   fidelity, security, legal, or accessibility claim.

Every capability listed below remains an active build obligation, including
arbitrary semantic text editing, font/glyph-preserving text-run replacement,
OCR-derived editable text, web and multilingual OCR, handwriting abstention,
permanent redaction, metadata and embedded-object sanitization,
password/encryption policy, cryptographic signatures and validation, XFA,
PDF/UA, independent-viewer and byte-level preservation evidence, raster parity,
page graph operations, conversion, repair, recurring templates, companion
lifecycle, collaboration, and synchronization.

“Explicitly explored,” “not yet promoted,” “deferred,” “gated,” “blocked for
claim,” and “unsupported by the current provider” are therefore implementation
states or claim states. They are not permanent product exclusions. A blocked
claim requires us to continue building the missing operation, provider,
corpus, validator, recovery path, privacy boundary, and documentation. A
capability becomes `Built` only when its implementation exists and its current
evidence supports that status; the program must never call an unimplemented
runtime built merely because its design is documented.

## Purpose

The product goal is a high-trust PDF reader and editor that makes difficult
forms easier to complete without silently changing surrounding source content,
while also growing into a normal PDF reader/editor for ordinary documents.

“Everything” is treated as a program of capability lanes. A lane is complete
only when its user behavior, shared contract, provider adapter, failure state,
validation evidence, privacy boundary, and native/web parity status are recorded.
A feature advertised by a competitor, exposed by a library, or visible in the
UI is not complete by itself.

The cross-project exploration is part of this implementation program, not a
research-only appendix. D-029 requires PDF Editor to rebuild every transferable
capability pattern found in SignKit, MetaExtract, Invoice Intelligence,
PhotoSearch, `extracted_forms`, and the historical web detector behind its own
contracts and evidence. Source ownership, privacy, licensing, and provenance
boundaries remain intact, and a provider gate controls activation rather than
removing the capability lane.

## First-principles invariants

1. The source PDF is immutable by default and identified by byte count and
   SHA-256 digest.
2. A native AcroForm field and a visually inferred blank region are different
   product objects and different operation kinds.
3. Every persisted coordinate names its unit, origin, page box, page index, and
   rotation convention.
4. Detector output is evidence with confidence and abstention, never silent
   authority.
5. Every mutation is typed, source-bound, reviewable, replayable, and exported
   to a new copy.
6. Validation distinguishes passed, warning, failed, skipped, and unknown.
7. “Outside-region unchanged” is a bounded proof for a known operation set. It
   is not a claim of general semantic editing safety, byte identity, or viewer
   parity.
8. OCR is geometry-bearing evidence until reviewed. It must not silently replace
   the source image or create a field.
9. A visual signature is not a cryptographic signature. A whiteout is not
   permanent redaction. A metadata scan is not a sanitization proof.
10. Native and web providers may produce different bytes. They must agree on
    user intent, evidence, coordinates, operation lineage, and validation state.
11. Provider installation, measurement, and revocation are admission concerns,
    not PDF document semantics. They must be versioned separately so an engine
    can be replaced without changing the shared PDF contracts.

## Capability matrix

Status vocabulary:

- **Built:** implementation exists and has current focused evidence.
- **Partial:** useful behavior exists, but a required fidelity or provider gate
  remains open.
- **Exploration:** contracts, alternatives, and corpus work are defined, but
  the capability is not yet enabled in the product path, while its
  implementation and evidence lane remains active.
- **Blocked:** a provider, legal, security, licensing, or runtime constraint
  prevents a safe claim in the current lane.

| Capability lane | Shared contract | Native macOS | Browser web | Evidence gate | Status |
| --- | --- | --- | --- | --- | --- |
| Open, identify, digest, and error handling | Document source, security, provider, error code | PDFKit | PDF.js | malformed, encrypted, stale-source, size/page limits | Built |
| Page rendering and navigation | Page snapshot, page-space coordinate | PDFKit/PDFView | PDF.js canvas and text layer | page count, boxes, rotation, search, links, outlines | Built |
| Thumbnails and view modes | Reader view and scale models | SwiftUI/PDFView | Canvas stack | interaction and accessibility runtime checks | Built |
| Metadata, permissions, attachments | Document inspection | PDFKit | PDF.js | null-safe inspection, privacy report coverage | Partial |
| Native AcroForm inspection | Native field contract | PDFKit widgets | PDF.js annotations | text, button, choice, radio, required, appearance, reopen | Partial |
| Native AcroForm filling | Native-field operation | PDFKit mutation | pdf-lib supported form mutation | same corpus, field value/choice/radio preservation | Partial |
| XFA | Explicit capability/unknown state | Provider-specific investigation | Unsupported unless companion proves it | XFA corpus and independent viewer | Blocked |
| Vector rectangles and checkbox shapes | Candidate/evidence/coordinate | PDF content-stream parser | PDF.js operator-list adapter | labeled, unlabeled, decorative, rotated, transformed geometry | Partial |
| Whitespace and label association | Candidate evidence graph | Swift text/geometry detector | Browser text/geometry detector | precision/recall and review acceptance | Partial |
| OCR text and bounds | OCR evidence, confidence, model identity | Vision adapter | Future local WASM/companion adapter | multilingual, skew, noise, handwriting abstention, calibration | Partial |
| OCR-derived search layer | OCR artifact and provenance | Vision plus local writer lane | Future bounded writer/companion | reopen, alignment, accessibility, source image unchanged | Exploration |
| Reviewed static text overlay | Overlay operation | PDFKit annotation | pdf-lib drawing | source digest, text impact, raster impact, reopen | Built |
| Text-run replacement | Text target evidence and typed replacement operation | Typed native/browser operation slice; writer gate explicit | Typed browser operation slice; writer gate explicit | outside text/raster diff, font/glyph/RTL/ligature corpus | Partial, provider-gated |
| Images, stamps, checkmarks, dates | Typed asset/stamp operations | PDFKit annotation/drawing | pdf-lib bounded drawing | asset provenance, bounds, reopen, outside-region diff | Partial |
| Annotations and review markup | Annotation operation | PDFKit | pdf-lib/PDF.js inspection | annotation round-trip, flatten distinction | Partial |
| Undo, replay, and session history | Edit session, parent operation, review | AppModel | Browser session state | replay, stale digest, retry, recovery | Built |
| Page rotate, reorder, insert, delete, extract | Page operation family | Provider lane | pdf-lib/page-copy lane | page identity, geometry, bookmarks, links, output reopen | Exploration |
| Merge, split, and batch operations | Batch operation and lineage | Native provider/companion | Browser bounded lane | source list, ordering, page labels, failure recovery | Exploration |
| Compare PDFs | Semantic and visual impact report | PDFKit plus validator | PDF.js plus validator | intentional versus unexpected changes | Partial |
| Outside-region text validation | Validation check | PDFKit character bounds | PDF.js text items | edited corpus and unknown-coordinate tests | Built |
| Outside-region raster validation | Visual-diff validation | PDFKit raster | PDF.js canvas | fixed scale, tolerance, expected regions, metrics | Built |
| Independent viewer parity | Independent-viewer check | qpdf/Poppler/control viewer | Companion or external control lane | PDFKit, PDF.js, qpdf, Poppler, control viewer | Exploration |
| Privacy preflight | Security/privacy findings | PDFKit metadata/object lane | PDF.js metadata/annotation lane | EXIF, attachments, scripts, revisions, unknowns | Partial |
| Metadata sanitization | Destructive sanitation operation | Companion/provider lane | Bounded browser or companion | removal coverage, residual scan, rollback/new copy | Exploration |
| Permanent redaction | Redaction mark/application operations | High-risk provider lane | Companion/high-fidelity lane | object, text, image, annotation, search, reopen, independent viewer | Blocked for claim |
| Password/encryption | Security operation and policy | PDFKit/companion | pdf-lib supported subset | KDF, interoperability, metadata leakage, recovery | Exploration |
| Visual signatures | Asset and review operation | Native local asset lane | Browser local asset lane | provenance, placement, no legal claim | Partial |
| Cryptographic signatures | Signature object and validation report | Dedicated crypto/PDF provider | Companion/WebCrypto plus PDF provider | trust chain, byte ranges, invalidation, independent validation | Blocked for claim |
| PDF/UA and screen-reader structure | Accessibility report | PDFKit inspection plus AT | PDF.js structure plus AT | VoiceOver/Chrome/Firefox/independent AT observation | Exploration |
| Recurring privacy-first templates | Versioned template contract | Local app storage | IndexedDB/OPFS | layout fingerprint, stale source, review, deletion, no values | Partial |
| OCR/parser evidence graph | Evidence-ledger contract | Existing adjacent adapters | Browser/companion adapters | provider bake-off, provenance, hard negatives | Exploration |
| Collaboration and sync | Session/identity/conflict contract | Local-first first | Optional later service | auth, conflict, retention, audit, deletion | Deferred |

## Build order

### B0: Contract and preservation foundation

Already built or in active hardening:

- versioned document, coordinate, candidate, edit-session, and validation
  envelopes;
- stale source, unsupported operation, destructive flag, unknown validation,
  and coordinate mismatch tests;
- immutable source handling and new-copy export;
- native/web fixture emission;
- outside-region text and raster validators;
- provider capability and failure reporting.

The next hardening requirement is to compare the native and browser JSON bundles
on the same corpus using normalized IDs and provider-neutral fields. Provider
IDs, byte digests of outputs, and generated timestamps must remain adapter facts,
not parity requirements.

### B1: Reader and safe completion core

Complete the first learning and safety-critical value in both apps while
preserving the long-term capability frontier:

- reader/navigation/search/outlines/links;
- native fields with required-field and choice/radio review;
- vector rectangle, checkbox, underline, whitespace, and label candidates;
- evidence review, abstention, dismissal, restoration, and manual placement;
- reversible text/image/checkmark/date/signature overlays;
- undo/replay and export validation;
- browser resource preflight and cancellation.

Exit gate: the same reviewed session can be serialized from native and web,
replayed against its source digest, exported to new copies, and compared for
semantic intent and bounded visual impact.

### B2: Extraction and geometry intelligence

Build the evidence moat before adding silent automation:

- unify vector paths, text runs, whitespace, OCR bounds, and page structure into
  evidence records;
- add multilingual and hard-negative corpora;
- measure candidate precision, recall, calibration, review acceptance, and
  dismissal reasons;
- add local provider bake-offs for Vision, Tesseract-family WASM, OCRmyPDF,
  PDFBox, Poppler, pikepdf, and any permitted high-fidelity control lane;
- learn recurring layouts only from reviewed corrections and without profile
  values or source content by default.

Exit gate: every suggestion has reproducible evidence, provider provenance,
coordinate confidence, and a safe abstention path.

### B3: General editing and page operations

Add operation families one at a time:

- text-run replacement;
- images, stamps, annotations, page transforms;
- insert/delete/reorder/split/merge/extract;
- compare and operation impact maps;
- companion support when browser or PDFKit fidelity is insufficient.

Exit gate: each operation has a corpus, a typed operation, outside-region text
and raster checks where applicable, independent reopen checks, and a documented
unsupported state.

### B4: Security and privacy lanes

Keep these separate from ordinary editing:

- privacy preflight report;
- metadata and embedded-object sanitation;
- password/encryption policy;
- permanent redaction;
- cryptographic signatures and validation;
- attachments, scripts, incremental revisions, and forensic recovery.

Exit gate: independent security review, negative corpus, residual scan, new-copy
publication, rollback/recovery, and claim-language review. No security feature
should be marketed because a library exposes a method with a similar name.

### B5: Accessibility and deployment parity

- PDF/UA inspection and claims boundaries;
- VoiceOver, keyboard, browser AT, and text-layer accessibility verification;
- PWA/share-target behavior and local asset vendoring;
- native packaging, update, recovery, and local companion protocol;
- performance/resource budgets on representative machines and browsers.

Exit gate: observed assistive-technology flows, not source-level accessibility
assertions alone; clear browser-only versus companion-required capability labels.

## Provider rules

### Native macOS

Continue PDFKit as the native reader, field, annotation, and baseline adapter.
Keep PDFKit's public AcroForm regression visible. Use Vision for a local OCR
adapter, but retain OCR as evidence until a writer and validation lane proves the
searchable layer. Use a companion provider only when the corpus demonstrates a
specific gap that PDFKit cannot safely cover.

### Browser

Use PDF.js for reading, rendering, text, annotations, and evidence. Use pdf-lib
for bounded writing, forms, page copying, overlays, and saving where the corpus
passes. Use Web Workers, IndexedDB/OPFS, resource preflight, cancellation, and
explicit browser capability modes. Do not turn pdf-lib into an arbitrary
semantic editor by wrapping it in a larger UI.

### Optional local companion

Keep PDFBox, qpdf, pikepdf, Poppler, OCRmyPDF, Tesseract-family OCR, and MuPDF
behind separate provider experiments. Record license, distribution, runtime,
security, performance, output fidelity, and fallback evidence before adoption.

### Provider admission plane

The companion and built-in native/browser providers are routed through the
separate [`provider-capability-system-design.md`](provider-capability-system-design.md)
contract. The registry distinguishes installed, measured, enabled, partial,
quarantined, revoked, and expired states. The default route requires an exact
artifact digest, approved license state, capability-specific corpus evidence,
source-limit compatibility, and no active revocation. This is now a contract
slice with native/browser tests; no installer or live bridge is claimed.

## Evidence-gated claims and their build conditions

The following claims remain intentionally unmade until their gates close:

- general semantic editing of arbitrary existing text;
- OCR or scanned-box detection in the web lane;
- production-grade vector/checkbox detection recall;
- permanent redaction or complete sanitization;
- digital signature validity;
- XFA support;
- PDF/UA conformance;
- independent viewer parity;
- byte-for-byte unchanged text-object proof;
- general raster parity across viewers or providers.

These lanes must be implemented as explicit tracks. An incomplete track must
emit evidence, unknown, blocked, or abstained states and must never silently
upgrade a UI affordance into a product claim. “Not supported for editing
claims” and “explicitly unsupported until proven” are current evidence states,
not permanent product exclusions.

## Current next unit

The next coherent implementation unit is:

1. classify the retained native and browser semantic mismatches in the shared
   parity report without normalizing away product-relevant differences;
2. reduce browser geometry false positives from page borders and decorative
   lines while preserving labeled fields and checkbox shapes;
3. expand the implemented privacy preflight contract into a source-bound
   sanitizer operation with removed/preserved/unknown inventory for metadata,
   attachments, annotations, scripts, hidden revisions, signatures, and
   unknown coverage;
4. add OCR alignment fixtures and keep browser OCR as an explicitly bounded
   capability experiment, without source-image mutation or silent field creation;
5. define the companion capability handshake and run OCR/high-fidelity provider
   bake-offs as part of the long-term capability program;
6. run the provider bake-off against the existing OCR and security corpus with
   license, packaging, bridge, recovery, and independent-viewer gates.
7. keep provider admission versioned independently from the shared PDF
   contracts; enable one capability at a time and preserve abstention when no
   measured local provider qualifies.

The accepted long-term deployment architecture is a browser-first local core
plus an explicitly installed optional companion capability plane. OCR and
high-fidelity editing belong in that plane when their provider, security,
licensing, packaging, and validation gates close. The companion must not be a
hidden runtime dependency.

This order keeps the original trust promise in the center while expanding the
reader/editor surface in both native and web lanes.

## Completion rule

The program is complete only when every capability in the matrix is either:

- built and supported by current evidence;
- explicitly blocked with a named provider, legal, security, licensing, or
  runtime reason; or
- implemented with a typed runtime state and a current enablement decision;
  if blocked, the blocker, provider path, corpus, and recovery plan remain
  active and visible.

No capability may be converted into a permanent non-goal merely because its
provider, licensing, runtime, or evidence gate is not closed yet. “Deferred” is
an execution sequence state. “Blocked” is an evidence or external-constraint
state. Both require continued implementation planning and preserved recovery
paths.

No capability is considered complete because it is listed in a menu, passes a
single synthetic fixture, or works in one provider without a shared contract.
