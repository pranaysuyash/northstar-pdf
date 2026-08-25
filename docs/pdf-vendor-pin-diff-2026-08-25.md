# PDF Vendor Pin and SignKit Bundle Diff

**Date:** 2026-08-25
**Scope:** Current artifacts inside `/Users/pranay/Projects`
**Status:** Static inspection complete; SignKit embedded PyMuPDF exact version remains unknown

## 1. Version table

| Surface | Path | Component | Observed version | License signal | Evidence |
|---|---|---|---:|---|---|
| PDF Editor browser | `/Users/pranay/Projects/pdf_editor/web/app.js` and `web/index.html` | PDF.js runtime/vendor | `4.2.67` | Apache-2.0 | CDN/local fallback URLs, runtime status string, vendored minified bundle contains `4.2.67` |
| PDF Editor browser | `/Users/pranay/Projects/pdf_editor/web/app.js` and `web/index.html` | pdf-lib | `1.17.1` | MIT | runtime status string and prior inventory; vendor bundle itself does not expose a simple version string |
| SentinelTwin | `/Users/pranay/Projects/SentinelTwin/node_modules/.pnpm/pdf-lib@1.17.1/node_modules/pdf-lib/package.json` | pdf-lib | `1.17.1` | MIT | package metadata |
| Travel Agency Agent | `/Users/pranay/Projects/travel_agency_agent/frontend/node_modules/.pnpm/pdfjs-dist@5.7.284/node_modules/pdfjs-dist/package.json` | PDF.js distribution | `5.7.284` | Apache-2.0 | package metadata; Node engine `>=22.13.0 || >=24` |
| SignKit.app | `/Users/pranay/Projects/extracted_forms/signkit-macos-arm64/SignKit.app/Contents/Frameworks/pymupdf/` | PyMuPDF/MuPDF framework directory | MuPDF binary `1.26.10`; exact PyMuPDF wrapper release not separately exposed | AGPL/commercial family | `_mupdf.so` and `libmupdf.dylib` contain the embedded `1.26.10` marker; no adjacent Python metadata for the wrapper |
| CoverWise | `/Users/pranay/Projects/medpiper/insurance_app/requirements.txt` | PyMuPDF | `1.23.8` declared | AGPL/commercial family | requirements file; current installed venv inventory separately reports later package contents and requires reconciliation |
| oc-mobile bridge | `/Users/pranay/Projects/oc-mobile/apps/extract-bridge/requirements.txt` | PyMuPDF | `1.27.2.3` | AGPL/commercial family | pinned requirement and lockstep rationale |
| orbitcover-d2c | `/Users/pranay/Projects/orbitcover-d2c/.venv` | PyMuPDF | `1.27.2.3` | AGPL/commercial family | Projects package inventory |
| SignKit/Data Science | `/Users/pranay/Projects/Data_Science/.../signature-extractor-app/.venv` | PyMuPDF | `1.26.5` | AGPL/commercial family | Projects package inventory |
| CoverWise local venv | `/Users/pranay/Projects/medpiper/insurance_app/venv` | PyMuPDF / pymupdf4llm | `1.28.0` | AGPL/commercial family | Projects package inventory; bounded METADATA check found PyMuPDFb `1.23.7` metadata in this venv, indicating package/runtime metadata drift requiring a clean venv audit |

## 2. What the diff says

### 2.1 Browser pins are inconsistent across Projects

PDF Editor is pinned to PDF.js `4.2.67`; Travel Agency Agent has `5.7.284`. The newer package is a valid local reference, but not an automatic upgrade target. PDF Editor's worker and main bundle must be upgraded together, and the following product-owned surfaces must be re-run:

- PDF.js reader initialization and worker loading;
- `web/pdf-geometry-detector.mjs` output and candidate taxonomy;
- `web/pdf-contract-parity.mjs` semantic projection;
- `web/pdf-contract-mutation-gate.mjs` fail-closed behavior;
- browser resource policy and cancellation checkpoints;
- Form 6, rotated, encrypted, malformed, hybrid, noisy-scan, and 40-page fixtures;
- pdf-lib export/reopen and independent viewer preservation checks.

The safe migration boundary is to preserve the existing 4.2.67 vendor snapshot, stage the 5.7.284 candidate separately, run the same reports, and only then update the canonical runtime strings/URLs.

### 2.2 pdf-lib is aligned

PDF Editor and SentinelTwin both use pdf-lib `1.17.1`. This is a permissive reuse signal, but pdf-lib is a bounded writer/overlay/form tool rather than a renderer or general semantic editor. It does not remove the need for PDF.js, native PDFKit, structural validation, or independent viewer checks.

### 2.3 PyMuPDF is widely duplicated and version-drifted

The Projects tree contains several PyMuPDF versions. The declared and installed versions do not form one clean portfolio-wide pin. This increases:

- behavior drift in extraction/rendering and save semantics;
- difficulty reproducing benchmark results;
- license inventory ambiguity;
- risk that a package metadata claim does not match the actual bundled binary;
- maintenance burden for arm64 and packaged-app builds.

The SignKit framework bundle is especially important: binary inspection found MuPDF `1.26.10` markers in `_mupdf.so` and `libmupdf.dylib`, but the exact PyMuPDF Python wrapper release is not separately exposed by adjacent metadata. Treat the engine version as observed while keeping the wrapper/package version and full license notice as separate review items.

## 3. Recommended canonical policy

1. PDF Editor owns its browser pins in one source-of-truth manifest, not duplicated literals across `app.js`, `index.html`, and reports.
2. Keep PDF.js main and worker versions identical and record an artifact digest.
3. Treat `travel_agency_agent` `5.7.284` as a migration fixture source only until PDF Editor's own parity reports pass.
4. Keep pdf-lib `1.17.1` as the current writer pin unless a separate compatibility/security review selects another release.
5. Reconcile declared versus installed PyMuPDF versions per project before any distribution decision.
6. Extract the SignKit build manifest or rebuild provenance; binary-only inference is insufficient for a legal or reproducibility claim.
7. Do not consolidate PyMuPDF into the shared permissive utility environment; its AGPL/commercial gate is separate.

## 4. Verification commands and limits

Observed commands included package metadata reads, bounded `find`/`grep` inspection, and binary directory/string probes. The SignKit probe established the framework contents and the embedded MuPDF `1.26.10` marker, but did not establish the exact Python wrapper version. No binary modification, extraction, code signing, app launch, or Git mutation was performed.
