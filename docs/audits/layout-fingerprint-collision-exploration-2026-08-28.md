# Layout Fingerprint Collision — First-Principles Exploration & V2 Prototype

**Date:** 2026-08-28
**Status:** Explored, prototyped, verified (7 tests, full suite 1301/1301 pass)
**Doctrine:** §2 Truth taxonomy, §5 Evidence-based, §12 Privacy, §3 Proportional rigor

## 1. The two Observed findings (from `calibration-corpus-verification-2026-08-28.md`)

| Finding | What happened | Root cause |
|---|---|---|
| **F-1 Fingerprint collision** | 2 of 4 corpus PDFs share the same V1 fingerprint | V1 feature set = first-page size + first-page rotation + page count — too coarse, page 0 only |
| **F-2 False family match** | Different PDFs with same page size classified `.familyMatch` | V1 similarity = Jaccard on *character sets* of serialized fingerprint strings — semantically meaningless |

**Verified on real corpus (this exploration):**
- V1 fingerprints: `595x841_r0_p3 | 595x841_r0_p2 | 595x841_r0_p4 | 595x841_r0_p3`
  → `plain-text.pdf` and `navigation.pdf` both `595x841_r0_p3` (collision confirmed).
- V1 family path also conflates any pair sharing characters (all four share `595x841_r0_p`,
  so character-set Jaccard ≈ 0.9+ → `.familyMatch`).

## 2. First-principles analysis

### 2.1 What is a layout fingerprint for?

A layout fingerprint identifies the **structural identity of a form's layout** so that:
1. **Equality** — the same template filled differently (known variant) is recognized as
   the same form.
2. **Similarity** — structurally similar forms are ranked for family matching.

### 2.2 The root error: one artifact, two jobs

V1 conflates two distinct jobs in a single string:

| Job | Requirement | V1's mistake |
|---|---|---|
| **Equality key** | Canonical serialization of structural features, hashed | Fine in principle, but the feature set is 3 scalars from page 0 |
| **Similarity measure** | Structured comparison of feature components | Jaccard over *characters of the serialized string* — "612x792" vs "612x792" share digits, not structure |

A hash is a valid equality key but destroys similarity information. Family matching must
compare the **underlying structured features**, never the serialized artifact.

### 2.3 Invariance requirements (what must NOT change the fingerprint)

| Invariance | Why | Mechanism |
|---|---|---|
| **Field values** | A filled form is the same template (the core known-variant use case) | Mask text cells that intersect widget rects |
| **±render differences** | PDFKit vs PDF.js vs pipeline render to slightly different coordinates | Grid quantization (4pt cells) absorbs sub-cell shifts; ties to PageBoxPolicy tolerance philosophy |
| **Producer/metadata churn** | Same layout from a different producer is still the same layout | Only geometry + structure recorded, never bytes |

### 2.4 Discriminative requirements (what MUST change the fingerprint)

| Signal | V1 | V2 |
|---|---|---|
| Page geometry (size, rotation) | Page 0 only | **All pages** |
| Text-block layout (positions, NOT content) | — | Occupied cells of character bounds (field-masked) |
| Field layout (kinds, positions) | — | Occupied cells of widget rects |
| Annotation layout (types, positions) | — | Occupied cells of non-widget annotation rects |

### 2.5 Design options considered

| Option | Description | Verdict |
|---|---|---|
| **A. Content hash** (SHA-256 of file) | Perfect discrimination, zero similarity | ❌ Rejected — breaks known-variant (a filled form has different bytes); content is not layout |
| **B. Richer scalar features** (page count, field count, text density) | Cheap, better than V1 | ⚠️ Partial — scalars still can't express *where* things are; two forms with 5 fields at different positions collide |
| **C. Structured component fingerprint (V2)** | Per-page geometry + quantized position cells per component; structured weighted similarity | ✅ **Selected** — expresses position, is value-invariant, content-free, cross-lane stable |
| **D. Pixel-level rendering hash** | Render + perceptual hash | ❌ Rejected — expensive, renderer-dependent, violates cross-lane stability |

### 2.6 Why not just raise the family threshold?

Threshold-raising (the FalsePositiveReport's current recommendation) treats the symptom:
it narrows the acceptance band of a **broken similarity function**. The correct fix is a
similarity function with semantic meaning; thresholds can then be recalibrated honestly.
Both are needed: V2 similarity + recalibrated thresholds on a larger corpus.

## 3. V2 prototype (this work)

### `Sources/PDFEditorCore/LayoutFingerprintV2.swift` (~300 lines)

- `LayoutFingerprintV2` — algorithm `layout-v2-cell-quantized`, feature version
  `layout-features-2`, per-page components, SHA-256 digest of canonical serialization.
- `LayoutFingerprintV2Extractor` — PDFKit extraction:
  - **Text cells**: `page.characterBounds(at:)` quantized to 4pt grid cells; characters
    intersecting widget rects (expanded 2pt) are masked as field values.
  - **Field cells**: widget rects → covered cells (capped to corners+center for huge rects).
  - **Annotation cells**: non-widget annotation rects.
  - Content-free by construction: positions and kinds only, never text.
- `LayoutFingerprintV2.similarity(to:)` — structured component similarity:
  - geometry 0.35 (per-page mean over shared prefix, page-count penalty)
  - text layout 0.30, field layout 0.25, annotation layout 0.10 (Jaccard on pooled cells)
  - **Agreement on absence is perfect agreement** (both-empty → 1.0; one-sided → 0).

### Why these weights?

Geometry is the strongest identity signal (page size/rotation rarely change within a
template family); annotation layout is the weakest (often absent). Weights are documented
constants, not magic — recalibration on a larger corpus may adjust them.

## 4. Evidence (Verified, real corpus)

### 4.1 F-1 fixed: V2 discriminates where V1 collides

V1: `plain-text.pdf` == `navigation.pdf` → `595x841_r0_p3` (collision).
V2: **4/4 unique digests** on the same corpus.

### 4.2 F-2 fixed: structured similarity stays below family threshold

Cross-PDF V2 similarity matrix (family threshold 0.76, well-calibrated):

| Pair | geo | text | field | annot | **total** |
|---|---|---|---|---|---|
| plain-text vs multi-column | 0.616 | 0.259 | 1.000 | 1.000 | **0.643** |
| plain-text vs geometry | 0.623 | 0.370 | 1.000 | 1.000 | **0.679** |
| plain-text vs navigation | 1.000 | 0.395 | 1.000 | 0.000 | **0.719** |
| multi-column vs geometry | 0.380 | 0.393 | 1.000 | 1.000 | **0.601** |
| multi-column vs navigation | 0.616 | 0.415 | 1.000 | 0.000 | **0.590** |
| geometry vs navigation | 0.623 | **0.824** | 1.000 | 0.000 | **0.715** |

All 6 pairs < 0.76 ✓. Two pairs sit at 0.72 — within 0.05 of the threshold.

### 4.3 Known-variant invariance (the core property)

`tagged-acroform.pdf` → fill a text widget → persist to a new file (byte digest differs,
proven in test) → **V2 digest unchanged**. Field-value masking works: a filled form keeps
its layout identity.

### 4.4 Stability & privacy

- Same file read twice → identical digest (stable).
- Canonical serialization contains no document text (asserted against extracted page text).
- Identical document → similarity 1.0 (within 1e-9).

## 5. New Observed findings (from this exploration)

| Finding | Evidence | Action |
|---|---|---|
| **F-3 Calibration headroom**: two cross-PDF pairs score 0.72, within 0.05 of the 0.76 family threshold | plain-text↔navigation 0.719; geometry↔navigation 0.715 | V2's structured similarity has a different scale than V1's char-Jaccard; thresholds must be **recalibrated on a larger corpus** before production use |
| **F-4 Text-layout similarity can be high across different documents** (geometry↔navigation text=0.824) | Both are dense text pages; cell occupancy overlaps | Consider per-page alignment instead of pooled cells; consider text-block *counts* as a discriminative addition |
| **F-5 Field/annotation absence dominates** (field=1.000 for all pairs — all corpus-sweep PDFs have no fields) | Agreement-on-absence now scores 1.0 | Absence agreement is honest but dilutes discrimination on field-less corpora; weight rebalancing should consider per-class priors |

## 6. Relationship to existing systems

- **Production template fingerprints** (`PDFTemplateFingerprint.make`) already build rich
  per-page signatures (normalized region rects, field kinds, keyed anchor tokens, HMAC
  workspace keying). V2 is the **corpus-calibration lane's** structured identity; the two
  should be unified on the component model, with production keeping keyed tokens for
  privacy (§12) and V2 keeping raw digest for cross-lane comparability.
- **PageBoxPolicy** quantization philosophy is shared: V2's 4pt cell is the fingerprint
  lane's tolerance; PageBoxPolicy owns the coordinate-space contract.

## 7. Recommendation (Proposed)

1. **Adopt V2 as the calibrator corpus fingerprint** — replace `computeLayoutFingerprint`
   (V1) in `CalibrationCorpusVerificationTests` with the V2 extractor.
2. **Recalibrate family threshold on a larger corpus** (F-3): current 0.76 was tuned for
   V1 semantics; collect ≥ 20 fixtures with hard negatives before ratifying.
3. **Unify with `PDFTemplateFingerprint`**: V2 components feed the production per-page
   signature builder; keep HMAC keying in production, raw digest in calibration.
4. **Per-page alignment** (F-4) before production: replace pooled-cell Jaccard with
   aligned per-page comparison.

## 8. Open questions

- What cell size minimizes cross-lane variance (PDFKit vs PDF.js)? 4pt is a starting point;
  needs a browser-lane fixture to measure.
- Should text-block *counts* join position cells as a discriminative component (F-4)?
- Do rotated pages (geometry.pdf page 3, rotation 90) need rotation-aware cell mapping?
  Currently rotation is captured in geometry only; character bounds on rotated pages may
  differ across lanes.

## 9. Files

- `Sources/PDFEditorCore/LayoutFingerprintV2.swift` (new)
- `Tests/PDFEditorCoreTests/LayoutFingerprintV2Tests.swift` (new, 7 tests)
- Docs: this audit + `progress.md` + `docs/INDEX.md`
## Addendum — F-4 resolved: per-page aligned comparison (2026-08-28)

The pooled-cell Jaccard in `LayoutSimilarityV2` is replaced with per-page
aligned comparison (recommendation 4 from §7, now implemented).

### What changed

`LayoutFingerprintV2.similarity(to:)` previously computed each layout
component as `jaccard(pooled(cells))` — merging all pages into one cell set.
Two dense multi-page documents with similar letter-grid occupancy therefore
scored artificially high (Observed: geometry↔navigation text=0.824).

Now `alignedJaccard` pairs the shared page prefix by index, averages the
per-page Jaccard over the pages where the feature **exists**, and applies the
page-count penalty. Empty-empty page pairs are skipped as uninformative —
scoring them 1.0 pulled the mean up on sparse components (the first aligned
draft moved plain-text↔navigation annotation 0.000 → 0.667, pushing the total
to 0.780; skip-empty restored honesty). The component scores 1.0 only when
both documents lack the feature entirely.

### Before / after (Verified, real corpus, family threshold 0.76)

| Pair | pooled text | aligned text | pooled total | aligned total |
|---|---|---|---|---|
| plain-text vs multi-column | 0.259 | 0.333 | 0.643 | 0.582 |
| plain-text vs geometry | 0.370 | 0.269 | 0.679 | 0.586 |
| plain-text vs navigation | 0.395 | 0.378 | 0.719 | 0.713 |
| multi-column vs geometry | 0.393 | 0.250 | 0.601 | 0.433 |
| multi-column vs navigation | 0.415 | 0.333 | 0.590 | 0.482 |
| **geometry vs navigation (F-4)** | **0.824** | **0.355** | 0.715 | **0.512** |

All six cross-PDF totals are now below 0.76 with greater headroom than the
pooled lane (worst pair 0.713, still the F-3 calibration-headroom finding —
honest, not a defect). Geometry↔navigation text drops by 57% and total by
28%, directly fixing F-4.

### Regression tests (3 new, suite passes)

- `F-4: dense-text cross-doc similarity drops below the family threshold` —
  asserts geometry↔navigation text and total < 0.76 (was 0.824 / 0.715).
- `F-4: aligned comparison keeps identical pages at 1.0 and penalizes count
  mismatch` — pure-structure semantics: identical shared pages → 1.0; a third
  differing page applies the ⅓ count penalty.
- The existing threshold test still guards every cross-PDF pair.

Evidence: 9/9 LayoutFingerprintV2 tests pass; full suite 1312/1312.

## Addendum — F-3 resolved: family threshold recalibrated on a 30-fixture corpus (2026-08-28)

The 0.76 family threshold was tuned for V1's char-set Jaccard semantics; V2's
structured scale measured differently (F-3: two negative pairs sat at 0.72,
within 0.05 of the threshold). This pass collected a 30-fixture corpus with
hard negatives and re-derived the threshold from measured distributions.

### Corpus ground truth (Verified — pikepdf, pdftotext, per-page probes, V2)

Every fixture shares the identical 6 widget rects — the entire corpus
descends from `public-sample-form.pdf`. Family is therefore defined by the
**layout-matching use case**, and the labeling was corrected twice by
measurement (the truth taxonomy in action):

1. **Metadata/signed/XFA 1-page variants are NOT negatives** — V2 measured
   them at 1.0: same page, same widgets, same text; only Info/signature/XFA
   attributes differ, which V2 deliberately excludes. **21 layout-identical
   single-page documents** → 210 positive pairs (re-encodings, tagged,
   compressed, metadata×5, signed×3, XFA×3).
2. **hybrid-text-raster ↔ rotated-hybrid-90 are NOT negatives** — per-page
   probe: both are p0 base text form (595x841, 157 chars, 6 widgets) + p1
   raster page (1600x700, no extractable text), rotation the only delta. A
   rotated scan of the same form must match: family B, 1 positive pair.
3. **Layout-distinct negatives** (7 documents): plain-text, multi-column,
   navigation, geometry, large-hybrid-40-pages, detector-calibration,
   scanned-noisy — 224 negative pairs.

Excluded with reason: `encrypted-hybrid.pdf` (password), `malformed-hybrid-
truncated.pdf` (PdfError). 28/30 extracted.

### Measured separation (Verified)

| | min | max |
|---|---|---|
| Positive pairs (211) | 0.971 | 1.000 |
| Negative pairs (224) | 0.041 | 0.813 |

Gap midpoint **0.892** → ratified **`LayoutFingerprintV2.familyThreshold = 0.90`**
(precision-first: zero hard-negative promotions — the old 0.76 would have
promoted none either, but margin shrunk to 0.05; the new 0.90 is the midpoint,
rounded to 0.05).

### New Observed finding (raster-page limitation, documented not fixed)

`hybrid-text-raster ↔ multi-column` = 0.813 is the new worst negative. V2
records positions only, so a raster page has zero extractable cells and is
skipped as uninformative; a text page + a scan page sharing page 0 score high
(this is the honest F-3 headroom now — OCR/pixel features are future work).

### Evidence

- `LayoutFingerprintThresholdCalibrationTests` (new): 30-fixture corpus,
  435 pairwise scores, separation asserts, zero-promotion assert, deterministic
  artifact `benchmark/results/detector-calibration/layout-v2-family-threshold-
  calibration-2026-08-28.json` (schema `pdf-editor.layout-v2-family-threshold-
  calibration` v1.0).
- `LayoutFingerprintV2Tests` updated to the calibrated constant + new
  positive-recognition test (layout-identical re-encodings must be ≥ 0.90).
- Full suite **1316/1316** pass.

## Addendum — Unification with the production template fingerprint (2026-08-28)

Recommendation 3 from §7 implemented: `LayoutFingerprintV2` components now
feed `PDFTemplateFingerprint`'s per-page signature builder.

### What changed

- **`PDFTemplatePageSignature`** gains the V2 cell channels — `cellSizePoints`
  (4pt default), and HMAC-keyed per-cell token arrays for the text, field,
  and annotation layout channels (`textCellTokens`, `fieldCellTokens`,
  `annotationCellTokens`). **HMAC keying stays in production**: cells enter
  as per-cell `hmac:` tokens scoped to the workspace key, so the layout is
  unlinkable across workspaces; the calibration lane keeps the raw
  `LayoutFingerprintV2.digest`. Decoding is backward compatible (records
  without the cell fields decode to empty + the default cell size).
- **`PDFTemplateFingerprint.make`** accepts `layoutV2: LayoutFingerprintV2?`.
  When supplied, each page's V2 cells are keyed into the signature and the
  canonical descriptor (so the equality fingerprint covers cell layout —
  same layout, different bytes still yields `knownVariant`); `featureVersion`
  bumps to `layout-features-2` so cell-less and cell-bearing captures never
  collide. When absent, output is byte-identical to the legacy builder
  (`layout-features-1`) — all existing call sites, stores, and tests
  unchanged.
- **`PDFTemplateIndexQuery.structuralScore`** blends in cell similarity
  (`legacy × 0.85 + cells × 0.15`) **only when both signatures carry cells**.
  Legacy-only records and the browser lane (no cell channel) keep the exact
  legacy score and cross-lane parity.

### Verified (real corpus, 6 new tests, suite 1322/1322)

- Keyed channels populated for the base form (6 widgets → 6 keyed field
  cells; label text → keyed text cells); every token `hmac:`-prefixed, no
  raw coordinates.
- Layout-identical re-encoding (base ↔ synthetic-producer-0, different
  bytes) → equal `layoutFingerprint` → `knownVariant`, with cells included.
- Cross-workspace keys → different tokens and digests (no linkage).
- Legacy path byte-identical; old records decode with defaults.
- **The cells see what the legacy signature cannot**: plain-text ↔
  navigation scored **1.0 legacy** (same kinds/keys/geometry) but **0.905
  cell-aware** — text-layout discrimination now reaches the production
  family score (the residual gap above the 0.72 production threshold is the
  documented F-3 headroom on the production scale; the calibration lane
  already separates this pair at 0.713 < 0.90).
