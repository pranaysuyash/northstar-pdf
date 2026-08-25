# Projects PDF License-Hygiene Sweep

**Date:** 2026-08-25
**Scope:** PDF/OCR/document-intelligence artifacts under `/Users/pranay/Projects`
**Status:** Inventory and ship-blocker map; not legal advice or a license grant

## 1. Executive result

The Projects tree contains several license-sensitive PDF/document providers. The main operational conclusion is:

> Do not treat an installed package, a successful local test, or a bundled framework as cleared for closed-source distribution.

The portfolio-wide review set is:

- PyMuPDF / MuPDF in multiple Python environments and inside `SignKit.app`.
- `pymupdf4llm` in CoverWise.
- Surya OCR in CoverWise's evaluation environment.
- OCR/parse providers whose exact package/model/dependency obligations still need artifact-level review: PaddleOCR, DocTR, Unstructured, LlamaParse, Tesseract traineddata, and optional model/runtime packages.
- Packaged dependencies inside `SignKit.app`, including PDFium, qpdf, MuPDF, and legal notices.

The safe default for PDF Editor remains the permissive composition already reflected in its architecture: PDFKit on native macOS, PDF.js + pdf-lib in the browser, and the isolated shared utility environment using PDFium/pypdf/pdfplumber/pdfminer/pikepdf/reportlab. That is a design default, not a final distribution SBOM.

## 2. Ship-blocker table

| Artifact / provider | Projects evidence | License signal | Closed-source ship status | Required action |
|---|---|---|---|---|
| PyMuPDF / fitz | orbitcover-d2c `.venv`, oc-mobile extract bridge `.venv`, Data_Science signature extractor `.venv`, CoverWise venv, SignKit.app bundle | AGPL-3.0 or Artifex commercial path; packaged binaries inherit review obligations | **BLOCKED until Artifex decision** | Inventory exact wrapper/engine version, usage mode, notices, and whether the artifact is distributed. Choose AGPL-compatible distribution or obtain Artifex commercial licensing. |
| MuPDF binary in SignKit.app | `extracted_forms/signkit-macos-arm64/SignKit.app/Contents/Frameworks/pymupdf/{_mupdf.so,libmupdf.dylib,...}` | Embedded binary exposes MuPDF `1.26.10`; MuPDF AGPL/commercial family | **BLOCKED until packaged-app review** | Preserve third-party notice/EULA; identify wrapper release, build provenance, binary dependencies, and redistribution terms. |
| `pymupdf4llm` | CoverWise `insurance_app/venv` `1.28.0` | Metadata says dual GNU AGPL 3.0 or Artifex Commercial License | **BLOCKED until Artifex decision** | Remove from shippable closed-source path or license it; do not assume a separate wrapper avoids PyMuPDF terms. |
| Surya OCR | CoverWise `.local-tools/surya-eval`, `surya-ocr 0.21.1` | Local inventory previously flagged custom non-commercial/paid boundary; package metadata requires exact model/repo terms review | **EVAL ONLY** | Confirm current upstream model/code license and commercial terms for exact version and weights; keep quarantined until cleared. |
| PDF.js | PDF Editor `4.2.67`, Travel Agency Agent `5.7.284` | Apache-2.0 | **Generally admissible with notices** | Record exact artifact digest and bundled third-party notices; keep main/worker versions aligned. |
| pdf-lib | PDF Editor + SentinelTwin `1.17.1` | MIT | **Generally admissible with notices** | Keep one PDF Editor pin/source of truth; preserve MIT notice. |
| pypdfium2 / PDFium | LLM/rag, Data_Science signature extractor, CoverWise, shared utility venv | Apache/BSD-style package and PDFium notices; exact bundled dependency review required | **Candidate / conditional** | Generate SBOM for exact wheel and platform; preserve PDFium and dependency notices; run fidelity/security gates. |
| pypdf | multiple Projects + shared utility venv | BSD-3-Clause | **Candidate / conditional** | Include notice; validate parser behavior and security limits. |
| pdfplumber / pdfminer.six | LLM/rag, CoverWise, shared utility venv | MIT | **Candidate / conditional** | Include MIT notices and pin versions. |
| pikepdf | multiple Projects + shared utility venv | MPL-2.0 | **Candidate / conditional** | Review file-level copyleft obligations and source/notice handling for any modifications. |
| ReportLab | multiple Projects + shared utility venv | BSD-3-Clause | **Candidate / conditional** | Include notice and font/resource review. |
| Tesseract engine + traineddata | installed locally and measured in PDF Editor OCR comparison; used in SignKit/invoice fallback docs | Apache-2.0 engine/model signals, exact package and traineddata provenance required | **Measured, not promoted** | Record exact binary/model artifact and notices; noisy-scan class currently fails PDF Editor gate. |
| Tesseract.js + browser language data | PDF Editor local WASM comparison | Apache/MIT signals by artifact; exact language artifact review required | **Measured, not promoted** | Keep local assets, capture digests, review model/license terms, measure memory/cancellation. |
| PaddleOCR / PaddlePaddle | Invoice Intelligence optional requirements | Exact code/model/dependency license and distribution terms require review | **Optional eval/provider** | Do not bundle until package/model SBOM and privacy/security review passes. |
| python-doctr / Torch / TorchVision | CoverWise production OCR profile | Multiple licenses; exact model and binary dependency obligations require review | **Optional local/production OCR profile** | Generate exact SBOM, model provenance, and runtime security review; distinguish production profile from slim direct-text profile. |
| Unstructured PDF | Invoice Intelligence `requirements-parsers.txt` | Exact package plus PDF parser dependency terms require review | **Optional parser** | Pin, SBOM, and run source-byte/privacy boundary checks before admission. |
| LlamaParse | Invoice Intelligence `requirements-parsers.txt` | Hosted proprietary service/API terms | **External service gate** | Require explicit provider, privacy, retention, cost, and data-transfer approval. |
| Stirling-PDF | SignKit integration proposal only | Deployment depends on its version and transitive engines | **Proposal only** | Do not assume endpoint or license suitability; build a separate container and license/SBOM review if adopted. |

## 3. Per-repository ship-blocker checklist

### 3.1 `orbitcover-d2c`

**Observed:** `.venv` contains PyMuPDF `1.27.2.3`; Node extraction code is the upstream source for the oc-mobile vendor snapshot.

- [ ] Decide whether any PyMuPDF-backed path ships in the product artifact.
- [ ] If yes, obtain Artifex commercial clearance or adopt an AGPL-compatible distribution model.
- [ ] Record exact PyMuPDF/PyMuPDFb and MuPDF binary versions from the environment.
- [ ] Keep extraction source ownership distinct from PDF Editor; do not copy the runtime.
- [ ] Preserve the benchmark/model registry and provider terms separately from code license.

**Ship status:** **Blocked for closed-source PyMuPDF distribution; extraction concepts may be reused through a clean adapter.**

### 3.2 `oc-mobile/apps/extract-bridge`

**Observed:** `requirements.txt` pins PyMuPDF `1.27.2.3`; README and `bridge/vendor/extraction/MANIFEST.md` define lockstep ownership and structured fail-closed behavior.

- [ ] Add PyMuPDF/Artifex license state to the bridge release manifest.
- [ ] Record whether the Docker image redistributes the wheel and linked MuPDF binaries.
- [ ] Generate an image SBOM for the pinned runtime.
- [ ] Keep keyless provider-unavailable behavior and no-fabrication tests as release gates.
- [ ] Do not infer permission to reuse d2c source from the vendor pin; preserve provenance.

**Ship status:** **Behaviorally well-governed, licensing blocked until Artifex/package review.**

### 3.3 `Data_Science/.../signature-extractor-app`

**Observed:** PyMuPDF `1.26.5`, pikepdf, pypdfium2, ReportLab, signing plans, and bundled SignKit prior art.

- [ ] Separate experimental PyMuPDF/pikepdf code paths from any shippable app path.
- [ ] Review `LIGHTWEIGHT_PDF_SIGNING.md` because its recommendation predates the current AGPL inventory.
- [ ] Confirm whether signatures are visual overlays or cryptographic signatures; do not conflate them.
- [ ] Record exact packaged dependencies and notices for any `.app` release.
- [ ] Keep the traditional-CV and OCR confidence values classified as uncalibrated unless a held-out labeled corpus is passed.

**Ship status:** **PyMuPDF path blocked for closed-source packaging until Artifex decision; PDFium/pypdfium2 path remains candidate.**

### 3.4 `medpiper/insurance_app`

**Observed:** production requirements declare PyMuPDF `1.23.8`; the local venv inventory reports PyMuPDF-family `1.28.0`/PyMuPDFb metadata and `pymupdf4llm 1.28.0`; Surya `0.21.1` is isolated under `.local-tools/surya-eval`; production OCR profile adds DocTR/Torch.

- [ ] Reconcile requirements, installed dist-info, and actual runtime import versions in a clean environment.
- [ ] Decide whether the slim direct-text production profile should use a permissive parser instead of PyMuPDF.
- [ ] Keep `pymupdf4llm` out of closed-source distribution until Artifex terms are cleared.
- [ ] Keep Surya and model weights evaluation-only until exact commercial terms are confirmed.
- [ ] Generate a full SBOM for `requirements-production-ocr.txt`, including Torch/DocTR/model artifacts.
- [ ] Preserve owner isolation, no-content-report, encrypted-PDF, and OCR-state tests.

**Ship status:** **Mixed: direct-text profile is functionally mature but license/version reconciliation is open; Surya is eval-only; OCR profile requires separate supply-chain review.**

### 3.5 `extracted_forms/SignKit.app`

**Observed:** bundled framework directory contains MuPDF `1.26.10` markers and companion `pypdfium2`, qpdf, legal notices, and EULA/terms resources.

- [ ] Identify the exact PyMuPDF wrapper version and build provenance.
- [ ] Reconcile bundled `THIRD_PARTY_LICENSES.md` against every framework and dylib.
- [ ] Confirm whether the package redistributes AGPL-covered components and under what EULA.
- [ ] Preserve the app as an evidence artifact; do not treat it as a clean dependency source.
- [ ] Review code-signing/notarization implications after any dependency change.

**Ship status:** **Packaged artifact requires legal and SBOM review before redistribution or code reuse.**

### 3.6 `invoice-intelligence`

**Observed:** PyMuPDF-backed PDF rendering/text extraction, pdfplumber fallback, PaddleOCR, Tesseract-compatible path, LlamaParse, Unstructured, OpenAI vision, synthetic and reviewed benchmark artifacts.

- [ ] Mark every provider as local, hosted, or fallback in the benchmark output.
- [ ] Generate package/model/service terms per pipeline.
- [ ] Keep hosted LlamaParse/OpenAI paths behind explicit data-transfer and retention approval.
- [ ] Keep synthetic scores separate from human-reviewed real-document results.
- [ ] Use the fixed evaluator and review-label gate before model/provider promotion.

**Ship status:** **Evaluation platform; no single pipeline is automatically cleared for closed-source product distribution.**

## 4. PDF Editor release policy

### Default-admissible baseline (still requires SBOM)

- Native PDFKit and Vision as Apple platform capabilities.
- Browser PDF.js with exact Apache notices.
- pdf-lib with MIT notice.
- Shared utility candidates: pypdfium2/PDFium, pypdf, pdfplumber, pdfminer.six, pikepdf, ReportLab, with exact transitive notices.

### Quarantined until separate gates pass

- PyMuPDF/MuPDF and pymupdf4llm.
- Surya code and model weights.
- OCRmyPDF and its dependency/security boundary.
- PaddleOCR/DocTR/Torch model paths.
- Hosted parsers and vision APIs.
- Any packaged binary whose exact source/version/license cannot be reconstructed.

### Required release evidence

1. Exact dependency lockfile or artifact manifest.
2. Package and binary versions, digests, platform/architecture.
3. Direct and transitive license inventory.
4. Required notices and source-offer obligations.
5. Model/weights licenses and provenance.
6. Data-transfer, retention, and logging behavior.
7. Security review for hostile/malformed PDFs and worker/process isolation.
8. Corpus result and failure-state evidence.
9. Rollback path and provider revocation state.
10. Human legal/product owner review for any commercial or copyleft decision.

## 5. Current recommended actions

### Immediate

1. Keep PDF Editor on the permissive baseline and do not import PyMuPDF into the shared utility venv.
2. Reconcile the CoverWise requirements versus installed PyMuPDF metadata; current evidence indicates version drift.
3. Add exact SignKit MuPDF `1.26.10` and wrapper-version-unknown status to the package manifest.
4. Create one portfolio license ledger with repository, artifact, version, owner, usage, distribution status, and notice path.
5. Keep all provider benchmark reports value-free and source-digest-bound.

### Before any closed-source shipment

- Obtain Artifex or choose an AGPL-compatible distribution model for every distributed PyMuPDF/MuPDF path.
- Confirm Surya commercial terms and exact model licenses if Surya is used beyond evaluation.
- Generate platform-specific SBOMs for `.app`, Docker, and browser assets.
- Re-run PDF Editor's malformed, encrypted, rotated, OCR, candidate, export, and independent-viewer gates with the exact release artifacts.

## 6. Limits

This is an engineering inventory and ship-blocker map, not legal advice. Package metadata is evidence, not a substitute for reading the exact license text and distribution terms. A dependency used only in a local experiment may have a different consequence from the same dependency bundled into a customer application, service image, or hosted processing path.
