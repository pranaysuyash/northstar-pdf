# Native Signature Extraction — Capabilities, Limits, and Roadmap

**Date:** 2026-08-26
**Status:** Implemented in-tree (no external SignKit dependency)
**Source:**
- `Sources/PDFEditorCore/SignatureExtractor.swift` — extractor + erase tool
- `Sources/PDFEditorCore/DocumentModel.swift` — `SavedSignature` + `SignatureSource`
- `Sources/PDFEditorApp/ContentView.swift` — `SignatureImageTab` (UI)
- `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift` — `signatureExtractor*` tests

## What it does

A photo or scan of a signature is turned into a transparent PNG in native Swift,
no runtime dependency on SignKit (which is a separate, weaker v1 prototype).

1. **Deskew** — document-rectangle perspective correction (`CIDetector` +
   `CIPerspectiveCorrection`), then PCA stroke-angle rotation so tilted
   handwriting straightens.
2. **Ink separation**
   - *Photos/scans (opaque):* combined **local adaptive threshold** (integral-image
     box-mean) **+ global-darkness term**. The local term makes it robust to
     uneven lighting/shadows; the global term keeps solid dark regions (stamps,
     filled blobs) from losing their interior.
   - *Graphics (already transparent):* an **alpha-mask path** so premultiplied
     transparent PNGs are not misread as solid ink.
   - Color-agnostic: black/blue/red ink all extract because the signal is
     "darker than surroundings," not "dark."
3. **Cleanup** — speck filter (drops isolated ink pixels), tight crop to ink bbox,
   original ink color preserved.
4. **Erase tool** — `applyingErase(strokes:brush:)` zeroes pixels under
   free-hand strokes (normalized coords, resolution-independent).
5. **Reusable library** — `SavedSignature` records `source`
   (.drawn/.typed/.image/.extracted), `useCount`, `lastUsedAt`; Image tab carries
   a removal-strength slider + live preview + erase brush.

## HONEST LIMITATION — deterministic CV, no ML

Extraction is **classical computer vision only**. It is good at *separating ink
from paper* but has **no learned understanding** of what the ink represents.

It therefore **cannot**:
- **Distinguish a signature from a random mark, doodle, or stray line.** If the
  user imports a photo of a cat, the extractor will happily "extract the cat" as
  if it were a signature. There is no classifier judging "is this a signature?"
- **Heal broken or gappy strokes** (inpainting), or thicken/fill faded ink.
- **Super-resolve** a low-quality capture, or semantically clean a smudge that
  overlaps real ink (the erase brush is manual).
- **Understand structure** (baseline, slant, individual glyphs) beyond the crude
  PCA tilt estimate.

These are **ML problems**, not CV-tuning problems. They require a dataset, a
model, and on-device inference (e.g. CoreML). That is an explicitly **separate
workstream**, out of scope for the current deterministic pipeline, and should be
evaluated on its own evidence before being added.

What classical CV *does* give us long-term value for free: resolution-independent
output (see roadmap) and trustworthy, explainable, offline behavior.

## What is left (no-ML gaps, in priority order)

1. **Vectorization.** Trace extracted ink contours → vector paths (SVG/PDF
   annotation), so placed signatures scale infinitely and stay tiny. Pure
   geometry, no ML — a natural "best approach" next step.
2. **Auto-detect signature region on a form / scanned page.** Reuse the app's
   existing form-field detection to locate the signing area, pre-crop, and
   one-tap extract, instead of forcing a manual image import.
3. **Quality / confidence signal.** Report extraction confidence and give guidance
   ("too much shadow," "low contrast," "no ink found") instead of silently
   returning a bad stamp.
4. **Library UX.** Thumbnails in the apply-picker, rename, tags/folders, search;
   undo/redo inside the sign sheet; non-linear / lasso erase; adjustable brush.
5. **Performance hygiene.** Throttle/defer re-extraction while dragging the
   strength slider; downscale very large photos for preview.

## What is next (recommended sequence)

- **Next, no-ML:** vectorize the extracted stamp (#1) — the highest
  long-term-value, lowest-risk improvement, and it makes every placed signature
  resolution-independent.
- **Then:** auto-detect + pre-crop on forms (#2), then quality signal (#3).
- **Separate ML workstream (only with its own evidence):** signature-vs-noise
  classifier, stroke healing, super-resolution. Do **not** bolt ML onto the
  deterministic path until each capability has a dataset and an evaluated model.

## Tests covering this

`signatureExtractorSeparatesInkFromPaper`, `signatureExtractorKeepsTransparentGraphic`,
`signatureExtractorPreservesColoredInk`, `signatureExtractorHandlesUnevenLighting`,
`signatureExtractorEraseRemovesInk`, plus `savedSignatureInitializesAndEncodes` and
`keychainSignatureStoreRoundTrips`.
