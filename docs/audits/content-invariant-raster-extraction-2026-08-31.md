# Content-Invariant Raster Extraction (2026-08-31)

**Status:** Observed + Verified  
**Doctrine ref:** §5 Evidence-based, §2 Truth taxonomy  
**Finding:** Cell-level content-invariant approaches (structural occupancy, edge detection) don't improve family matching because the binding constraint is corpus composition. However, **projection profiles** (region-level approach) DO improve matching: they replace cell-level Jaccard for the raster channel, widening the separation gap from 0.8081..0.9477 to 0.7875..0.9507. The raster weight remains at 0.04.

## Updated evidence (2026-08-31)

### Projection profiles — the breakthrough

Projection profiles project content density onto x/y axes, producing horizontal and vertical histograms. These capture macro-level layout structure (where columns are, where headers end, where sidebars begin) and are inherently content-invariant.

| Measurement | Cell-level Jaccard | Projection profiles |
|---|---|---|
| Re-encoding raster similarity | 1.000 | 1.000 |
| minPositive | 0.9477 | 0.9507 |
| maxHardNegative | 0.8081 | 0.7875 |
| Separation gap | 0.8081..0.9477 | 0.7875..0.9507 |

The projection approach works because it operates at a higher structural level than individual cells. Two documents with the same column structure but different text content have similar projection profiles because text occupies the same structural regions.

### Region-based extraction (connected components)

Also implemented: `extractRegions()` groups adjacent occupied cells into contiguous regions using flood-fill. Region similarity uses greedy centroid matching + bounding-box IoU + density/aspect ratio comparison. This is effective for detecting structural zones (headers, footers, sidebars) but too aggressive for family matching (different-layout documents with 1 vs 14 regions score 0.0).

### Diverse-layout corpus (14 fixtures)

Generated 14 genuinely diverse-layout PDFs: single-column, two-column, three-column, graphics-heavy, form fields, table grid, scanned sim, header/footer, landscape chart, sparse text, dense grid, mixed multi-page, single-column variant, two-column square. These stress-test the raster channel with real structural diversity.

### What still doesn't work

Cell-level approaches (structural occupancy, edge detection) at the 4pt grid level remain too sensitive to content differences. The F-5b experiment (neutral values for empty channels when raster exists) broke self-similarity (identical documents scored below 1.0). The correct approach is projection profiles at the region level, which is now the production raster similarity method.

## 1. Problem statement

The current binary occupancy raster extraction treats a single non-blank pixel the same as a fully filled cell. This makes it sensitive to content differences: a cell with one character vs. a cell with an image both register as "occupied."

Family members (same layout, different content) have near-zero raster similarity (0.00–0.08), which caps the raster weight at 0.02.

**Goal:** Make raster extraction content-invariant — detect WHERE content exists, not WHAT content exists.

## 2. Approaches explored

### 2.1 Structural occupancy
- Counts cells where >30% of sampled pixels are non-blank
- Less sensitive to sparse content (single characters, thin lines)
- Uses 5×5 sample cluster for better density estimation

### 2.2 Edge detection (Sobel)
- Applies 3×3 Sobel operator to grayscale rendering
- Counts cells where >30% of samples have edge magnitude >30
- Captures layout structure (lines, borders, regions) rather than content fill

### 2.3 Combined (edge + structural)
- Union of edge detection and structural occupancy
- More robust than either approach alone

## 3. Evidence

### 3.1 Re-encoding pairs (positive)
All approaches produce perfect 1.0 similarity:
```
binary:      1.0000 (3633↔3633 cells)
structural:  1.0000 (1626↔1626 cells)
edge:        1.0000 (4630↔4630 cells)
combined:    1.0000 (4795↔4795 cells)
```

### 3.2 Same-form "negative" pairs
The corpus fixtures plain-text.pdf, navigation.pdf, and multi-column.pdf are **variants of the same base form** with different content. All approaches return 1.0:
```
binary:      1.0000 (3633↔3633 cells)
structural:  1.0000 (1626↔1626 cells)
edge:        1.0000 (4630↔4630 cells)
combined:    1.0000 (4795↔4795 cells)
```

### 3.3 Truly different document (scanned-noisy)
Only genuinely different documents show discrimination:
```
binary:      0.0519 (3633↔70000 cells)
structural:  0.0232 (1626↔70000 cells)
edge:        0.0622 (4630↔58973 cells)
combined:    0.0685 (4795↔70000 cells)
```

### 3.4 Full corpus calibration (36 fixtures, 233 positive / 397 negative)
```
binary:      minPos=0.0582  maxNeg=1.0000  gap=-0.9418
structural:  minPos=0.0000  maxNeg=1.0000  gap=-1.0000
edge:        minPos=0.0671  maxNeg=1.0000  gap=-0.9329
combined:    minPos=0.0671  maxNeg=1.0000  gap=-0.9329
```

## 4. Analysis

### Why content-invariant approaches don't help

The binding constraint is **corpus composition**, not extraction method:

1. **Positive pairs are already perfect** (1.0) — re-encodings produce identical raster patterns
2. **Same-form "negatives" also score 1.0** — plain-text.pdf, navigation.pdf are variants of the same base form with identical cell structures
3. **Only truly different documents show discrimination** — scanned-noisy.pdf (70000 cells vs 3633) is the only pair that differentiates

The corpus has **21 layout-identical fixtures** (family "A") that all produce identical cell counts. When comparing any two "A" fixtures, all approaches return 1.0 because the cells are identical.

### The real constraint

To improve family matching, we need:
1. **A corpus with genuinely different-layout family members** — same layout structure, different content (e.g., same form template with different field values)
2. **Or extraction that makes different-content family members score higher** — this requires detecting structural regions (headers, footers, sidebars) rather than individual cells

### What would work

| Approach | How | Expected improvement |
|---|---|---|
| **Region-based extraction** | Detect large structural regions (page zones) instead of individual cells | High — regions are content-invariant |
| **Projection profiles** | Project content onto x/y axes, compare histograms | High — captures layout structure |
| **Connected component analysis** | Group nearby cells into regions, compare region shapes | Moderate — more robust than cell-level |
| **Layout template matching** | Match against a template of expected structural regions | High — explicit content-invariance |

## 5. Decision

**Keep binary occupancy at 0.02 weight.** The content-invariant approaches explored here don't improve family matching because the corpus composition is the binding constraint, not the extraction method.

**To unlock higher raster weight**, the next step is region-based extraction or projection profiles — approaches that operate at a higher structural level than individual cells.

## Files

- Source: `Sources/PDFEditorCore/ContentInvariantRasterExtractor.swift`
- Tests: `Tests/PDFEditorCoreTests/ContentInvariantRasterTests.swift`
- Previous analysis: `docs/audits/raster-weight-analysis-2026-08-30.md`
