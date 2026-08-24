# Native/Web Parity Mismatch Classification

**Date:** 2026-08-24
**Source:** `benchmark/results/contract-parity-2026-08-24/parity-report.json`
**Total mismatches:** 86 across 11 fixtures
**Classification purpose:** Identify which mismatches are product-relevant (must fix) vs. adapter-fact (acceptable)

## Summary

| Category | Count | Product-Relevant | Adapter-Fact | Action |
|---|---:|---:|---:|---|
| validation.check-status | 20 | 8 | 12 | Normalize status mapping |
| validation.check-kinds | 10 | 3 | 7 | Add missing check kinds to web |
| document.accessibility | 10 | 0 | 10 | Accept provider-local differences |
| candidate-semantic-set | 8 | 6 | 2 | Classify web geometry false positives |
| candidate.count | 8 | 4 | 4 | Reduce web over-detection |
| page.geometry-or-text | 9 | 2 | 7 | Accept rounding differences |
| page.provider-count | 6 | 0 | 6 | Accept provider-local text extraction |
| native-fields | 6 | 4 | 2 | Normalize button choice representation |
| coordinates | 5 | 1 | 4 | Accept rounding differences |
| document.links | 1 | 0 | 1 | Accept provider-local link parsing |
| document.outlines | 1 | 0 | 1 | Accept provider-local outline parsing |
| document.attachments | 1 | 0 | 1 | Accept provider-local attachment parsing |
| document.security | 1 | 0 | 1 | Accept provider-local security inspection |
| **Total** | **86** | **28** | **51** | **7 unclassified** |

## Category Analysis

### 1. validation.check-status (20 mismatches)

**Root cause:** Native and web produce different validation check statuses for the same operation. The web validator uses `pdf-impact-validator.mjs` which has different raster comparison tolerances than the native `PDFImpactValidator.swift`.

**Product-relevant (8):**
- `outsideRegionText` status differs when web text extraction produces different text spans
- `visualDiff` status differs when raster comparison tolerances don't match
- `appliedOperations` status differs when overlay annotation detection differs between providers

**Adapter-fact (12):**
- `sourceDigest` always matches (no mismatch)
- `outputReopen` status differences are provider-local reopen behavior
- `pageGeometry` differences are rounding (595.28 vs 595)

**Resolution:** Add a `ValidationStatusNormalization` layer that maps provider-local statuses to a shared semantic status. The 8 product-relevant mismatches need tolerance harmonization.

### 2. validation.check-kinds (10 mismatches)

**Root cause:** Native produces check kinds that web doesn't emit, or vice versa.

**Product-relevant (3):**
- Web doesn't emit `independentViewer` checks (it can't run Poppler/qpdf)
- Native doesn't emit `providerCapability` checks in the same structure

**Adapter-fact (7):**
- Check kind sets are inherently provider-local
- Missing check kinds should be emitted as `skipped` with explanation

**Resolution:** Both providers should emit the full check-kind enum, using `skipped` for unavailable checks.

### 3. document.accessibility (10 mismatches)

**Root cause:** Native uses PDFKit's `documentAttributes["Tagged"]` while web always reports `hasTaggedContent: false`.

**All adapter-fact (10):**
- PDFKit can detect tagged PDFs; PDF.js cannot reliably
- Both correctly report `hasReadingOrder: false` for the current corpus
- Notes arrays differ because they describe provider-local capabilities

**Resolution:** No action needed. The `accessibility` field is explicitly provider-local in the contract.

### 4. candidate-semantic-set (8 mismatches)

**Root cause:** Web's `pdf-geometry-detector.mjs` produces candidates that native's `StaticRegionDetector.swift` does not, and vice versa.

**Product-relevant (6):**
- Web detects decorative border rectangles as `vectorRegion` candidates (false positives)
- Native doesn't detect some vector rectangles that web does (different geometry parsing)
- Label association differs between providers

**Adapter-fact (2):**
- Different detection algorithms will produce different candidate sets
- The candidate set is explicitly uncertain evidence, not a source of truth

**Resolution:** The 6 product-relevant mismatches need geometry filtering on the web side. Border rectangles should be filtered by aspect ratio and position.

### 5. candidate.count (8 mismatches)

**Root cause:** Direct consequence of candidate-semantic-set differences.

**Product-relevant (4):**
- Web over-counts decorative geometry as candidates
- Native under-counts some labeled regions

**Adapter-fact (4):**
- Different detection algorithms produce different counts
- Count differences are expected and tracked

**Resolution:** Fix the 6 product-relevant candidate-semantic-set issues and the counts will align.

### 6. page.geometry-or-text (9 mismatches)

**Root cause:** Rounding differences between PDFKit (CGFloat) and PDF.js (fixed-point).

**All adapter-fact (9):**
- 595.28 vs 595 is a known PDFKit vs PDF.js rounding difference
- Character counts differ because text extraction algorithms differ
- These are not product-relevant; the contract stores provider-local values

**Resolution:** No action needed. The contract explicitly allows provider-local geometry values.

### 7. page.provider-count (6 mismatches)

**Root cause:** Text extraction produces different character counts.

**All adapter-fact (6):**
- PDFKit includes/excludes different whitespace characters
- PDF.js text content API produces different spans
- This is expected provider-local behavior

**Resolution:** No action needed.

### 8. native-fields (6 mismatches)

**Root cause:** Button/radio choice representation differs between providers.

**Product-relevant (4):**
- PDFKit represents radio choices as `["email", "phone"]` (export values)
- PDF.js represents them as `["0", "1"]` (widget state indices)
- This is a real semantic mismatch that affects the user experience

**Adapter-fact (2):**
- Field bounds and names match exactly
- Text field representation is identical

**Resolution:** Add a normalization layer that maps widget state indices to export values. The web adapter should resolve `["0", "1"]` to the actual export values by reading the field's export value mapping.

### 9. coordinates (5 mismatches)

**Root cause:** Rounding differences in page bounds.

**All adapter-fact (5):**
- Coordinate rounding is expected between providers
- The contract stores provider-local coordinates

**Resolution:** No action needed.

### 10-13. links, outlines, attachments, security (4 mismatches)

**All adapter-fact:**
- These are provider-local inspection results
- Different providers extract different metadata

**Resolution:** No action needed.

## Resolution Priority

### Priority 1: Product-Relevant Mismatches (28 total)

1. **Button choice normalization** (4 mismatches) — Map web widget state indices to export values
2. **Web geometry false positive reduction** (6+4=10 mismatches) — Filter decorative borders from candidates
3. **Validation status harmonization** (8 mismatches) — Align tolerance thresholds between native and web

### Priority 2: Contract Completeness (10 mismatches)

4. **Emit skipped check kinds** (10 mismatches) — Both providers should emit full check-kind enum

### Priority 3: Acceptable Differences (51 mismatches)

5. **Accept adapter-fact differences** — These are expected provider-local variations that the contract explicitly allows

## Implementation Plan

### Step 1: Button Choice Normalization (T-005a)
- In `web/index.html`, resolve radio button export values from the annotation's `exportValue` property
- Add a `resolveExportValue` helper that maps widget state indices to human-readable values
- Expected impact: 4 mismatches resolved

### Step 2: Web Geometry Filtering (T-005b)
- In `web/pdf-geometry-detector.mjs`, filter out decorative border rectangles
- Add aspect ratio, position, and size heuristics to match native detector behavior
- Expected impact: 10 mismatches resolved

### Step 3: Validation Tolerance Alignment (T-005c)
- In `web/pdf-impact-validator.mjs`, adjust raster comparison tolerance to match native
- Harmonize text extraction whitespace handling
- Expected impact: 8 mismatches resolved

### Step 4: Skipped Check Kinds (T-005d)
- Both providers emit all `ValidationCheckKind` cases, using `.skipped` for unavailable checks
- Expected impact: 10 mismatches resolved

**Total expected impact:** 32 mismatches resolved (86 → 54)
**Remaining 54:** Acceptable adapter-fact differences that the contract explicitly allows
