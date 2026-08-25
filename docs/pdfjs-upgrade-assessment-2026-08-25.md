# PDF.js 4.2.67 to 5.7.284 Upgrade Assessment

**Date:** 2026-08-25
**Scope:** `/Users/pranay/Projects/pdf_editor` browser surface
**Status:** Assessment and migration checklist complete; no runtime pin changed and no Git branch/commit created

## 1. Current and reference pins

| Surface | Current/reference | Evidence |
|---|---:|---|
| PDF Editor browser | PDF.js `4.2.67` | `web/app.js`, `web/index.html`, `web/vendor/pdfjs/pdf.min.mjs`, `web/vendor/pdfjs/pdf.worker.min.mjs` |
| PDF Editor browser writer | pdf-lib `1.17.1` | runtime status strings and vendor inventory |
| Local upgrade reference | `pdfjs-dist 5.7.284` | `/Users/pranay/Projects/travel_agency_agent/frontend/node_modules/.pnpm/pdfjs-dist@5.7.284/node_modules/pdfjs-dist/package.json` |

The reference package is Apache-2.0 and declares Node `>=22.13.0 || >=24`. That declaration is relevant to the reference project's Node tooling, not a browser compatibility guarantee for PDF Editor.

## 2. Exact surfaces that must move together

PDF Editor currently repeats the PDF.js version in both browser entry paths:

- `web/app.js`: local vendor first, then unpkg/jsdelivr `4.2.67` main and worker URLs, plus runtime status `pdfjs-4.2.67+pdf-lib-1.17.1`.
- `web/index.html`: same local/CDN fallback list and same runtime status.
- `web/vendor/pdfjs/pdf.min.mjs` and `pdf.worker.min.mjs`: bundled `4.2.67` API/worker pair.

A safe migration must update the main bundle, worker bundle, fallback URLs, and diagnostic/version status as one atomic browser-runtime change. Updating only the CDN URL or only the worker creates an API/worker mismatch and must be treated as a failed migration.

## 3. Product-owned compatibility surfaces

Before promotion, re-run and compare the current 4.2.67 baseline against the 5.7.284 candidate for:

1. `web/pdf-geometry-detector.mjs` — operator-list extraction, text/geometry evidence, line normalization, character-cell grouping, and candidate taxonomy.
2. `web/pdf-contract-parity.mjs` — source identity, page geometry, fields, candidates, operations, navigation, security, accessibility, and validation projection.
3. `web/pdf-contract-mutation-gate.mjs` — fail-closed behavior for unsupported/malformed provider state.
4. `web/browser-resource-policy.mjs` — budget, worker, cancellation, checkpoint, and no-partial-output invariants.
5. PDF.js loading fallback and runtime failure handling in `app.js` and `index.html`.
6. pdf-lib export/reopen path and independent preservation checks.

## 4. Required corpus regression set

The existing governed corpus must remain the same so results are comparable:

- public AcroForm and Form 6;
- rotated Form 6 and rotated widget fixtures;
- hybrid selectable-text/raster PDFs;
- noisy scan and simulated handwriting fixtures;
- encrypted hybrid with explicit password;
- malformed/truncated PDFs;
- navigation metadata and annotations;
- repeated 20-page and large 40-page documents;
- detector calibration and hard-negative fixtures;
- OCR provider comparison fixtures;
- browser resource-policy device/document profiles.

Compare semantic reports, candidate mismatch classes, error codes, page-box precision, render output, export reopenability, and resource/recovery behavior. Do not use byte identity as the sole oracle because provider serialization may legitimately differ.

## 5. Migration procedure

1. Preserve the existing `web/vendor/pdfjs` directory as the rollback artifact; do not overwrite it before capturing a digest and baseline report.
2. Obtain the exact 5.7.284 browser artifacts from the local reference package or official package source. Verify main/worker version equality and Apache notices.
3. Replace the browser vendor pair in one controlled workspace change.
4. Update both `app.js` and `index.html` fallback URLs and runtime status strings.
5. Run JavaScript syntax checks and the focused detector/parity/mutation/resource tests.
6. Run the full native/browser semantic parity harness against the unchanged corpus.
7. Run detector calibration and hard-negative mutation checks.
8. Run browser OCR/resource checks and export/reopen preservation checks.
9. Inspect representative pages in an isolated browser run; record console/page errors and worker failures.
10. Compare 4.2.67 and 5.7.284 reports. Keep the candidate only if no unexpected mismatch or new failure appears, or if every difference is explicitly classified and accepted in a dated decision record.
11. Keep the old vendor artifact and a documented rollback until the new result is promoted by the project owner.

## 6. Known decision blockers

- The existing parity report has six declared mismatches, including Form 6/rotated candidate divergence and encrypted page-box precision. An upgrade must not hide these by changing normalization.
- Browser OCR WASM remains evidence-only; a PDF.js upgrade does not improve OCR accuracy by itself.
- The current browser runtime uses a local vendor first with CDN fallbacks. A claim of offline support requires the local vendor path to work; CDN availability cannot be part of the proof.
- No browser-runtime upgrade was performed in this assessment because the current checkout is dirty and shared files are owned by concurrent work. This is an assessment, not a completed migration.

## 7. Recommendation

**Proceed as a controlled migration experiment, not as an unverified pin bump.** The local `5.7.284` reference makes the experiment practical, but the canonical PDF Editor runtime should remain `4.2.67` until the full report set is generated on the candidate. The highest-value first comparison is detector output plus semantic parity on Form 6, rotated Form 6, encrypted hybrid, malformed, and hard-negative fixtures.

## 8. Verification boundary

This report is Tier 1 static inspection and migration planning. It establishes the exact surfaces and checks required; it does not establish that PDF.js `5.7.284` is compatible with PDF Editor, nor does it claim browser/device/production readiness.
