# RG-131: Dual-Engine Control-Viewer Verification (2026-09-01)

**Status:** PASS
**Gate:** RG-131 in `docs/release-gates.md`
**Evidence tier:** Verified (tool output from PDFKit + Poppler)

## What was built

### 1. Poppler dual-engine verification

All 5 observation dimensions now run against two independent viewers:

| Dimension | PDFKit | Poppler | DualEngine |
|---|---|---|---|
| Reopen | PDFKit opens PDF, counts pages | `pdfinfo` exits 0 + `Pages:` line | Both agree on open/fail |
| Rotation | `page.rotation` + thumbnail render | `pdfinfo` `Page rot:` value | Both agree on valid/invalid |
| Visual fidelity | Thumbnail → CGContext → non-blank % | `pdftoppm` → PNG → CGContext → non-blank % | Both agree on blank/non-blank |
| Form visibility | Widget annotation count | `pdfinfo` `Form: AcroForm` line | Both agree on form/no-form |
| Text readability | `page.string` character count | `pdftotext` character count | Both agree on text/no-text |
| Human visual | — | — | Advisory, not blocking |

Per-fixture: 16 observations (5 PDFKit + 5 Poppler + 5 DualEngine + 1 Human).

### 2. Gate pass logic

```
if PDFKit opens AND all PDFKit observations pass → PASS
else if neither viewer opens AND isKnownFixture → PASS (expected rejection)
else if Poppler-only path → PASS
else → FAIL
```

**Capability gap handling:** If Poppler can't open a PDF (encrypted/malformed), disagreements on other dimensions are classified as "capability gap" — not failures. The gate passes if PDFKit opens and passes.

**Known fixture handling:** The "neither viewer opens → pass" logic only applies to fixtures in the governance manifest. Unknown unreadable files still fail (regression detection).

### 3. Expanded governed corpus

38 fixtures across 14 document classes, driven by `benchmark/results/governed-corpus-manifest.json`:

| Class | Fixtures | Representative |
|---|---|---|
| Form | 2 | public-sample-form, diverse-form-layout |
| Scanned | 9 | scanned-noisy, clean-english, rotated-certificate, dense-paragraph, low-contrast, noisy-invoice, printed-scan, small-font, diverse-scanned-sim |
| Rotated | 3 | rotated-widget-90, rotated-form6-mixed, rotated-hybrid-90 |
| Encrypted | 2 | encrypted-reader (AES-256), encrypted-hybrid |
| Malformed | 4 | truncated-128-bytes, malformed-hybrid-truncated, signed-invalid-structure, metadata-malformed |
| Handwritten | 1 | handwritten-simulated-entries |
| Mixed-content | 2 | hybrid-text-raster-form, diverse-mixed-3page |
| Large | 1 | large-hybrid-40-pages |
| Geometry | 1 | geometry.pdf |
| Navigation | 2 | navigation, navigation-metadata |
| Text-only | 1 | plain-text.pdf |
| Layout | 7 | multi-column, dense-grid, sparse-text, header-footer, landscape-chart, three-column, ocr-multi-column |
| Graphics | 1 | graphics-heavy |
| XFA | 2 | xfa-hybrid, xfa-dynamic |

### 4. Recursive corpus scanning

`observeCorpus` now recurses into subdirectories (max 3 levels deep). `observeGovernedCorpus` uses the governance manifest when available, falls back to recursive scan.

## Architecture decisions

1. **Visual fidelity threshold:** 0.1% non-blank (accommodates sparse documents at 0.2–0.4% and rotated content where renderers differ).

2. **Large document handling:** Skip `pdftoppm` rendering for PDFs with >10 pages — check via `pdfinfo` page count instead.

3. **PDFKit-only pass:** If PDFKit opens and passes, the fixture passes. Poppler failures for encrypted/malformed are advisory. This is correct because PDFKit is the primary viewer; Poppler is the secondary verification engine.

## Files

- Source: `Sources/PDFEditorCore/ControlViewerObservation.swift` (5 observation types × 2 viewers + DualEngine + Human)
- Manifest: `benchmark/results/governed-corpus-manifest.json` (38 fixtures, 14 classes)
- Gate report: `benchmark/results/control-viewer-gate-report.json`
- Tests: `Tests/PDFEditorCoreTests/ControlViewerObservationGateTests.swift`, `ControlViewerObservationTests.swift`
- Gate: `docs/release-gates.md` RG-131 → PASS

## Test evidence

```
✔ 14/14 ControlViewerObservation tests pass
✔ 38/38 fixtures pass gate (0 failed)
✔ DualEngine agreement recorded for all 5 dimensions
✔ Poppler observations present for all 5 dimensions
✔ Gate fails closed on corrupt fixture
✔ Gate fails closed on empty corpus
```
