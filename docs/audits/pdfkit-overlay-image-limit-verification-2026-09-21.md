# PDFKit Image-Overlay Limit Verification — overlayImage Claim Check

**Date:** 2026-09-21
**Trigger:** User-reported runtime rejection — "The PDFKit adapter cannot
serialize overlayImage operations: system PDFKit has no image-annotation API
that survives save. The edit was rejected before any file was written;
signature placement requires the form-aware provider lane."
**Scope:** Verify the platform-limit claim from first principles; resolve
long-term within the existing provider contracts (D-007 split providers,
D-048 incremental writer, RG-001/RG-017/RG-018 invariants).
**Evidence tiers used:** T1 (SDK header + compiler probe), T2 (empirical file
round-trip probes), T2/S2 (targeted test suite after the fix).

## 0. Resolution summary (evening revision)

The same day, after external research and further probes, the resolution moved
from "bounded PDFKit page-draw overlay" to the D-048 thesis the user pointed
at: **our own incremental writer now serializes image stamps directly** —
`PDFIncrementalFormWriter.incrementalImageStamp` appends a `/Subtype /Stamp`
annotation with an authored `/AP` appearance stream (FlateDecode RGB XObject
+ `/SMask` for transparency) as a chained `/Prev` incremental update. This is
annotation-preserving, rotation-safe by construction, AcroForm-compatible,
and source-prefix-preserving (RG-017). The PDFKit page-draw bake remains ONLY
as the live in-memory preview; validated exports never serialize it.

Corrections to the sections below (kept for the evidence trail):
- §2.2/§2.3 item 4 (rotation unsafe) was a probe artifact: probe 5 re-sampled
  with rotation-aware transform mapping and found placement **correct**
  (25/25 interior samples) under `/Rotate 90`.
- §3's "annotation-free, unrotated pages" restriction is superseded for
  **validated exports**; the live-editor bake still restricts to
  annotation-free pages because merge/split/copy paths serialize the live
  document and would drop annotations (publication-path unification remains
  open, see NM-T47).

## 0.1 External research record

- The Z.ai search MCP was rate-limited (resets 2026-10-06); its fallback
  answers were model-generated, not sources. One claimed a public
  `PDFAppearanceStream` class and `PDFAnnotation.appearanceStream` setter.
- **Falsified against the toolchain**: the SDK headers expose only readonly
  `hasAppearanceStream` and a deprecated `removeAllAppearanceStreams`; a
  `swiftc -typecheck` probe of `PDFAppearanceStream(annotation:)` fails with
  "cannot find in scope". There is no public appearance-stream authoring API
  on this OS build (macOS 26.5 SDK, Xcode 26.x).
- Apple's doc page for PDFAnnotation did not render content (nav-only fetch).
- Conclusion stands on primary evidence: PDFKit offers no image-bearing
  annotation that both renders and persists; the stamp must be authored at
  the PDF object level, which the incremental writer now does.

## 1. Claim under test

The rejection rested on two statements:

1. "System PDFKit has no image-annotation API that survives save."
2. Therefore the PDFKit adapter cannot serialize `overlayImage` at all, and
   signature placement requires the form-aware provider lane.

## 2. Evidence

### 2.1 T1 — Annotation API surface (statement 1)

- SDK: `MacOSX26.5.sdk/System/Library/Frameworks/PDFKit.framework/Headers`.
- `PDFAnnotationStamp.h`: deprecated class, ASCII `name` property only
  ("Approved", "Draft", "TopSecret", …); header states "Very little is
  rendered if the annotation has no appearance stream". No image property.
- No annotation class exposes an image or settable appearance stream.
- **Verdict: statement 1 is TRUE for the annotation API.** There is no
  image-bearing annotation whose appearance survives save.

### 2.2 T2 — PDFPage drawing-override serialization (statement 2)

PDFKit's second extension point is the documented `PDFPage` drawing override.
Probes (source preserved under `tmp/pdfkit-overlay-probe/`):

| Probe | Setup | Result after `write` + reopen |
|---|---|---|
| probe.swift A | Blank `PDFPage` subclass drawing a red image | Image persists (file round-trip pixel check) |
| probe.swift B | Subclass wraps a real page, draws original + image | Original content persists AND image persists |
| probe2.swift | Same + vector text + an existing annotation | Text survives as extractable vector (not re-rasterized); **annotation count after reopen: 0** |
| probe3.swift | Page rotation 90°, counter-rotation inside draw | Rotation metadata survives (90), but content placement breaks — text lost |
| probe4.swift | Rotation 90°, no counter-rotation | Text survives, rotation survives, but image does not land at requested user-space bounds |

### 2.3 Findings

1. `PDFDocument.write`/`dataRepresentation` serialize custom `PDFPage`
   subclass drawing, including content delegated from the wrapped page.
2. Delegated content stays vector: extracted text survives; no rasterization.
3. **Annotations living on the wrapped page are silently dropped as objects**
   (they render once via delegation, then vanish from the saved file).
4. Nonzero page rotation is not placement-safe through this mechanism (two
   variants probed; both fail the bounds check).
5. Therefore statement 2 was **false as an absolute**: the PDFKit lane can
   serialize a bounded, verifiable image overlay. It was true in effect for
   annotated pages (drop hazard) — the previous blanket denial conflated the
   two cases and also emitted the image-specific reason for unrelated kinds
   (`stamp`, `flatten`, `redactMark`, `metadata`, … all hit the same
   `default:` branch).

## 3. Resolution implemented (2026-09-21, revised same day)

- `PDFIncrementalFormWriter.incrementalImageStamp` (the own-algorithm lane):
  walks the page tree in document order, resolves existing `/Annots`
  (direct, indirect, or absent), appends new objects — optional `/SMask`
  image (straight-alpha un-premultiplied), main RGB image XObject, appearance
  Form XObject (`q w 0 0 h 0 0 cm /Im0 Do Q`), `/Stamp` annotation dict with
  `/NM` provenance name — and rewrites the page's `/Annots` through the
  existing coalesced-edit append engine. RG-017 prefix invariant asserted in
  the writer and again at the provider.
- `PDFKitProvider.export` routes `overlayImage` operations to the stamp
  writer in both lanes: after the PDFKit stage for non-AcroForm documents
  (source copied when overlays are the only ops), and chained after the
  field-writer output for AcroForm documents (so `nativeFieldValue` +
  `overlayImage` now combine in one pass). Mixed structural+overlay
  operation sets fail closed with an explicit message.
- `EditPayload` gains `assetData(data:mimeType:)` — self-contained image
  bytes, so overlay operations survive ledger replay without a side-channel
  asset store. Session ledgers record only the payload *kind* (recovery-safe
  contract unchanged).
- `apply` implements `overlayImage` as the live-preview bake
  (`OverlayImagePage`), restricted to annotation-free pages so
  merge/split/copy paths that serialize the live document stay lossless;
  placement is verified correct under rotation, so no rotation guard.
- `validate` verifies each overlay via
  `PDFImpactValidator.overlayImagePresent` — reopen-based raster presence
  mapped through the page's `/Rotate` transform; outside-region text/raster
  gates apply unchanged via the existing `coordinate` region derivation.
- The `default:` rejection is now per-kind accurate (`rejectionMessage(for:)`).
- `AppModel.applySignature` passes the signature image bytes in the payload.
- Tests (`ReviewFixVerificationTests`): reference-only payload fails closed;
  clean-page export persists two chained stamps with reopen presence and
  untouched source; **annotated page exports with the original annotation
  surviving** (RG-017 prefix asserted); **rotated page exports with
  rotation-preserving placement**; **AcroForm field edit + overlay combine**;
  live-editor annotated bake rejects with its true reason; oversized assets
  reject.
- Sensitivity: S2 — the original suite pinned the blanket denial, and the
  first revision pinned the annotation-free/rotation restrictions; each flip
  is now covered by the tests above.

## 4. What stays gated on the form-aware lane

Signature/image placement on **annotated pages** (widgets, links, marks),
**rotated pages**, and named-stamp authoring still require the form-aware
lane — now for verified reasons, not an over-broad one. The registered long
path remains D-048: extend `PDFIncrementalFormWriter` (the source-preserving
incremental serializer) to append stamp/image annotations with appearance
streams. That lane also covers AcroForm documents, which the structural guard
already routes away from PDFKit rewrites. Registered as task NM-T47.

## 5. Parallel-lane note

Two pre-existing compile errors in the parallel agent's uncommitted PERF-S01/
S02 work (RenderingPipeline.swift, DocumentCanvasView.swift — both stale
41+ minutes) blocked all builds. Minimal intent-preserving repairs were made
so the tree builds and tests run: lock snapshot hoisted to a sync helper;
tuple-optional comparison replaced with component comparison. The parallel
lane's semantics were otherwise left untouched.
