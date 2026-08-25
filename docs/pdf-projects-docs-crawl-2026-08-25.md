# Projects PDF Documentation, Evals, and Explorations Crawl

**Date:** 2026-08-25
**Scope:** `/Users/pranay/Projects` only
**Owner:** `/Users/pranay/Projects/pdf_editor`
**Status:** Completed broad evidence crawl; implementation and admission gates remain separate

## 1. What this pass covers

The earlier Projects inventory found installed PDF engines. This pass goes further: it reads the durable documentation, evaluation reports, exploration maps, benchmark result envelopes, runbooks, architecture notes, issue reviews, and relevant source-level design records inside the Projects tree.

It is specifically intended to answer:

- Which PDF/OCR/parser/extraction/signing/layout ideas have already been explored locally?
- Which claims are backed by an evaluation, and which are only proposals or historical notes?
- Which projects already contain reusable contracts, fixtures, fallback behavior, or failure taxonomies?
- Where do docs and live code disagree?
- What should PDF Editor adopt as a concept, and what must remain owned by another project?

This is not a license clearance, production-readiness sign-off, or claim that every generated artifact is independently meaningful. Generated dependency documentation, package caches, and repeated per-fixture JSON are inventoried and aggregated by family; the decision-relevant source docs and result envelopes are individually called out.

## 2. Crawl method and evidence rules

### 2.1 Files and directories inspected

The crawl used bounded per-project filesystem walks over documentation-like files (`.md`, `.markdown`, `.txt`, `.rst`, `.json`, `.csv`, `.yaml`, `.yml`, `.html`) plus targeted reads of PDF-related source and test files. Priority names and content terms included:

`pdf`, `mupdf`, `fitz`, `pdfium`, `pdf.js`, `pdfjs`, `pdf-lib`, `pdfkit`, `pypdf`, `pikepdf`, `pdfplumber`, `pdfminer`, `ocrmypdf`, `tesseract`, `ocr`, `surya`, `marker`, `camelot`, `poppler`, `qpdf`, `acroform`, `xfa`, `signature`, `signing`, `annotation`, `layout`, `table extraction`, `document intelligence`, `form fill`, `parity`, `calibration`, and `provenance`.

Vendor/dependency trees such as `node_modules`, `site-packages`, `.venv`, `venv`, `.build`, `dist`, model checkpoints, and `.git` internals were not semantically treated as project documentation. They were handled by the separate installed-tooling crawl and the Projects package inventory.

### 2.2 Truth labels used in this report

- **Observed:** a current file, code path, test, or result artifact exists.
- **Verified:** a relevant check or benchmark is recorded and its scope is explicit.
- **Inferred:** a reusable architectural implication supported by the observed material.
- **Proposed:** a design or roadmap item not established as implemented.
- **Unknown:** the repository does not establish the claim; the next check is named.
- **Superseded:** an older document is retained but an append-only addendum or newer source changes its authority.

A benchmark number is never silently promoted to production accuracy. A local smoke test is not a deployment, device, legal, or real-user proof.

## 3. Coverage summary

The targeted crawl covered the following PDF-adjacent projects and source families:

| Project / source family | What was found | Decision relevance |
|---|---|---|
| `pdf_editor` | Canonical native/web PDF contracts, 18-fixture corpus, parity reports, OCR comparison, detector calibration, resource policy, failure audits, runbooks, engine research, and cross-project synthesis | Primary source of truth for the PDF product |
| `Data_Science/.../signature-extractor-app` | SignKit PDF field detector, PyMuPDF/pikepdf signing plan, CV/OCR/ML explorations, coordinate mapping, Stirling-PDF plan, calibration notes, packaging and product docs | Prior art for signatures, candidate evidence, coordinate handling, and licensing risk |
| `metaextract` | PDF/document extractor registry, provenance and sensitive-field observability, parser integration, pending registry plan, security and performance records | Prior art for normalized fields, provenance, shadow mode, and parser admission |
| `invoice-intelligence` | PDF/image ingestion, PyMuPDF/PDF text, PaddleOCR, LlamaParse, Unstructured, hybrid routing, synthetic corpus, human-reviewed labels, benchmark and autoresearch loop | Prior art for parser/OCR routing, validation, corpus separation, and measurable experimentation |
| `medpiper/insurance_app` | PDF direct-text path, optional DocTR OCR, PyMuPDF, PDFium/Surya environments, RAG/eval corpus, privacy/owner isolation tests, local model comparison | Prior art for insurance-PDF extraction, local OCR gating, and sensitive-data handling |
| `extracted_forms` / `SignKit.app` | Packaged app, legal/EULA/third-party notices, bundled MuPDF/PyMuPDF/PDFium/qpdf artifacts | Supply-chain and distribution evidence; not canonical source |
| `oc-mobile` | Vendored PDF extraction bridge, pinned PyMuPDF runtime, contract tests, lockstep manifest, fail-closed provider behavior | Prior art for provider isolation, version pinning, and structured failure |
| `orbitcover-d2c` | Upstream extraction library used by the oc-mobile vendor snapshot and PDF text tiering | Upstream ownership boundary; do not silently fork |
| `travel_agency_agent` | Local `pdfjs-dist` 5.7.284 reference plus broad extraction/eval architecture material | Browser-version migration reference; not a PDF Editor dependency |
| `SentinelTwin` | Duplicate `pdf-lib` 1.17.1 installation and document/scene evaluation material | Confirms local reuse/version pin; not a PDF Editor runtime owner |
| `invoice_exp` | Source corpus and invoice/PDF inputs used by invoice intelligence | Data provenance and corpus boundary |
| `document extraction by chatgpt` | Small extraction output/QA artifacts | Historical evidence only; no engine authority established |
| `Photosearch_experiment` and `Web_dev/signature_auto_detect_v1` | OCR region, confidence, and historical signature-detection ideas | Conceptual prior art; requires adapter and fresh validation |

### 3.1 Enumeration notes

The tree is large and contains many generated result envelopes. The per-project inventory observed documentation-like artifacts in the hundreds for `pdf_editor`, `metaextract`, `medpiper`, `oc-mobile`, `orbitcover-d2c`, and `SentinelTwin`, and tens of thousands of text/config artifacts in the very large `travel_agency_agent` tree. Counts produced by name/content classification are useful for coverage checking, but not a substitute for semantic reading: package lockfiles, generated JSON, and agent context files can contain PDF/OCR terms without being product decisions.

The authoritative conclusions below are therefore based on the current source docs and targeted result reports, with repeated generated result files grouped by benchmark family.

## 4. `pdf_editor`: canonical PDF product evidence

### 4.1 Product and engine direction

**Files:**

- `/Users/pranay/Projects/pdf_editor/README.md`
- `/Users/pranay/Projects/pdf_editor/docs/pdf-feature-frontier.md`
- `/Users/pranay/Projects/pdf_editor/docs/pdf-engine-comparison.md`
- `/Users/pranay/Projects/pdf_editor/docs/platform-options.md`
- `/Users/pranay/Projects/pdf_editor/docs/native-web-platform-matrix.md`
- `/Users/pranay/Projects/pdf_editor/docs/provider-capability-system-design.md`
- `/Users/pranay/Projects/pdf_editor/docs/shared-contracts.md`
- `/Users/pranay/Projects/pdf_editor/docs/decisions.md`

**Finding:** The canonical direction is one provider-neutral contract with native macOS PDFKit and browser PDF.js + pdf-lib adapters. The first safe shared slice is reader/navigation, native fields, reviewed static candidates, reversible overlays/annotations, page operations, export, reopen, extraction, rendering, and independent validation. Arbitrary text reflow, XFA, cryptographic signatures, permanent redaction, full OCR layers, collaboration, and companion execution remain implementation lanes rather than deleted goals.

**Important architecture rule:** engines produce evidence and provider facts; PDF Editor owns normalized meaning, review state, typed operations, operation lineage, source binding, and validation. A provider being installed does not make it admitted or supported.

### 4.2 Feature frontier and capability matrix

**Files:**

- `docs/pdf-feature-frontier.md`
- `docs/capability-matrix.md`
- `docs/pdf-engine-comparison.md`
- `docs/full-capability-build-program.md`
- `docs/feature-expansion-inventory.md`
- `docs/feature-expansion-implementation-log-a.md`
- `docs/design-implementation-map.md`
- `docs/proposed-architecture.md`
- `docs/provider-capability-system-design.md`

**Finding:** The project explicitly maintains a full capability program. Current provider status is narrower than the long-term feature list. The matrix records native PDFKit, browser PDF.js, pdf-lib bounded writing, Vision OCR, and future companion/provider lanes separately. This prevents accidental scope deletion while keeping claims evidence-gated.

### 4.3 Detector calibration and hard negatives

**Files:**

- `docs/audits/detector-hard-negative-calibration-evidence-2026-08-25.md`
- `docs/fixtures/detector-calibration-manifest.md`
- `benchmark/results/detector-calibration/detector-calibration-report.json`
- `benchmark/results/detector-calibration/detector_calibration_labels.json`
- `Tests/detector_calibration_parity_test.mjs`
- `web/pdf-geometry-detector.mjs`
- `Sources/PDFEditorCore/StaticRegionDetector.swift`

**Verified result:** On the controlled 10-case calibration fixture, native PDFKit and browser PDF.js both recorded precision `1.00`, recall `1.00`, hard-negative false-positive rate `0.00`, and hard-negative abstention `1.00`. Mutation checks killed positive removal, hard-negative promotion, and required-evidence stripping.

**Boundary:** This is a contract regression oracle, not general PDF accuracy. Rotated transforms, clipped paths, table borders, nested forms, multilingual labels, handwriting, OCR-only labels, transparency, malformed streams, and multi-column reading order remain open corpus work.

**Reusable primitive:** labels must be semantically plausible; geometry alone is not an input field. Evidence includes text label and spatial relationship; suggestions remain review-gated.

### 4.4 Native/browser semantic parity

**Files:**

- `docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md`
- `benchmark/results/semantic-parity/2026-08-25/parity-report.json`
- `web/pdf-contract-parity.mjs`
- `Tests/pdf_contract_parity_test.mjs`
- `Tests/native_browser_semantic_parity_report_test.mjs`

**Verified result:** 18 governed fixtures, 16 readable, 2 expected malformed failures, and native/browser status agreement on 18/18. Six mismatches were explicitly classified; zero were unexpected.

**Open mismatches:** native/browser static candidate sets differ on Form 6 and rotated Form 6; page-box precision differs on an encrypted hybrid. The comparator intentionally keeps these as declared open mismatches instead of normalizing them away.

**Implication:** the semantic spine is functioning, but native and browser adapters are not interchangeable. The next gate is reconciliation of candidate taxonomy and coordinate precision, then extension to edited sessions, OCR evidence, companions, and independent viewer outcomes.

### 4.5 OCR and companion comparison

**Files:**

- `docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`
- `benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json`
- `benchmark/results/ocr-provider-comparison/2026-08-25-local-vs-companion.json`
- `benchmark/compare_ocr_providers.mjs`
- `Sources/PDFOCRBenchmark/main.swift`
- `Tests/ocr_provider_comparison_test.mjs`

**Verified partial result:**

| Provider | Mean anchor recall | Median | p95 | Current state |
|---|---:|---:|---:|---|
| Native Vision | `0.944` | `97.5 ms` | `425.1 ms` | measured partial; candidate evidence only |
| Tesseract 5.5.0 | `0.778` | `189.1 ms` | `401.3 ms` | permissive control; noisy-scan class failed |
| Browser WASM Tesseract.js 5.1.1 | `0.778` | `257.8 ms` | `11,945.9 ms` | local-only evidence; p95 near gate and noisy boxes diverged |
| OCRmyPDF | not measured | not measured | not measured | unavailable/uninstalled |
| PDFBox | not measured | not measured | not measured | installed-unmeasured registry entry |
| MuPDF | not measured | not measured | not measured | quarantined pending license |

The aggregate OCR promotion gate is blocked intentionally. Native Vision passes the controlled noisy-scan threshold; Tesseract and browser WASM do not. Browser WASM made no external requests in this run, but its noisy-scan output diverged sharply from Vision (`687` versus `3` boxes). Companion crash, timeout, cancellation, revocation, and partial-output recovery are still open.

### 4.6 Resource policy and resilience

**Files:**

- `docs/audits/browser-resource-policy-evidence-2026-08-25.md`
- `web/browser-resource-policy.mjs`
- `Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift`
- `benchmark/results/browser-resource-policy/2026-08-25-device-adaptive.json`
- `docs/audits/failure-mode-and-resilience-audit-per-0924.md`
- `docs/error-taxonomy.md`
- `docs/policies/pdf-output-validation.md`
- `docs/runbooks/release-gates.md`

**Verified result:** the browser/native resource-policy contract passed 242 checks across five device profiles and six document classes, emitted 30 benchmark cases, decoded natively, and passed an isolated Chrome check. It is value-free and source-bound. Cancellation retains a valid checkpoint while keeping `partialOutputPromoted=false`.

**Failure audit:** the FMEA identifies source overwrite, partial export, radio metadata loss, surrounding-text mutation, resource exhaustion, rotated coordinates, malformed input, unsafe links, undo divergence, CDN outage, and OCR coordinate hallucination. The most important known provider defect is PDFKit radio-choice metadata loss on no-op export; it is contained by validation but not fixed by the provider.

### 4.7 Cross-project intelligence synthesis

**Files:**

- `docs/cross-project-document-intelligence-exploration.md`
- `docs/audits/signkit-capability-crosswalk-2026-08-24.md`
- `docs/audits/cross-project-evidence-ledger-parity-evidence-2026-08-24.md`
- `Tests/fixtures/cross_project_evidence_ledger.json`
- `docs/moat-asset-registry.md`
- `docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`

**Finding:** The durable moat is not a single PDF engine or OCR model. It is the source-bound evidence and operation graph: immutable bytes → multi-provider inspection → normalized evidence → reviewed candidate → typed operation → new-copy export → independent validation → reviewed correction/hard negative/template event.

The six-entry cross-project evidence ledger and its 18 source references are reference-only. No neighboring runtime, source bytes, profile values, or unreviewed dependency was imported.

## 5. SignKit / Data_Science: signature, field detection, and PDF prior art

### 5.1 PDF field detection

**Files:**

- `/Users/pranay/Projects/Data_Science/computer_vision/proj6/signature-extractor-app/docs/AUTO_DETECTION_ML.md`
- `desktop_app/pdf/field_detection.py`
- `desktop_app/tests/test_pdf_field_detection.py`
- `desktop_app/tests/test_pdf_bulk_field_detection.py`

**Observed implementation:** three signals are combined and deduplicated per page:

1. AcroForm/widget inspection via pikepdf (highest-confidence real field evidence).
2. OpenCV layout heuristics for signature lines and field-like boxes.
3. OCR keyword hints for labels such as “Signature”, “Sign here”, and “Initials”.

Candidates are bounded per page and shown for operator confirmation. Confidence values are explicitly uncalibrated except for synthetic calibration and a labeled-field IoU check.

**Transfer:** use the decomposition, shared transform, overlap dedupe, bounded candidates, and review gate. Do not copy the detector or treat its scores as probabilities.

### 5.2 Signing and rendering plans

**Files:**

- `docs/LIGHTWEIGHT_PDF_SIGNING.md`
- `docs/EXPORT_OPTIONS.md`
- `docs/STIRLING_PDF_INTEGRATION.md`
- `docs/ARCHITECTURE_FINAL_DECISION.md`
- `docs/COORDINATE_MAPPING.md`
- `docs/ISSUE_ANALYSIS.md`

**Historical proposal:** PyMuPDF for rendering and pikepdf for manipulation was recommended over Stirling-PDF because a local desktop bundle was estimated at roughly `171 MB` versus `800–1000 MB` for a Java/Stirling bundle. The plan supports image signature overlays and flattening, but it predates the current AGPL risk inventory and must not be treated as an approved distribution architecture.

**Stirling-PDF plan:** a Docker/FastAPI microservice proposal covers merge, split, rotate, compress, OCR, watermark, flatten, and sanitize endpoints. It is a proposal with unchecked API/version assumptions, not a running local provider.

**Coordinate lesson:** the image app found that coordinate transforms, rotation, fit-to-window, zoom, letterboxing, clamping, and selection persistence must be explicit. The current PDF Editor coordinate contracts generalize this to page space, crop box, rotation, and provider transforms.

### 5.3 ML and OCR exploration

**Files:**

- `docs/AUTO_DETECTION_ML.md`
- `docs/ADVANCED_FEATURES_RESEARCH.md`
- `docs/DOC_UNDERSTANDING_ADDON.md`
- `docs/LOCAL_RAG_IMPLEMENTATION.md`
- `docs/calibration_dataset_spec.md`
- `docs/research/auto_detection_synthetic_baseline_2026-08-13.md`

**Finding:** Phase 1 traditional CV is shipped; YOLO/segmentation/foundation-model/cloud phases remain future-only. There is no approved dataset, model, or ML dependency for those phases. Synthetic calibration showed image detector ECE improving from `0.30` to `0.03` and AUC `0.83`, while the PDF detector's confidence was a weak ranking signal around AUC `0.60`; this is synthetic/internal evidence only.

**Important reusable rule:** calibration can fix probability interpretation but cannot repair weak discrimination. A default threshold needs a permissioned held-out labeled set, an agreed accuracy bar, and privacy/consent/retention gates.

### 5.4 Distribution and legal docs

**Files:**

- `extracted_forms/signkit-macos-arm64/SignKit.app/Contents/Resources/legal/THIRD_PARTY_LICENSES.md`
- `.../EULA.md`
- `.../PRIVACY_POLICY.md`
- `.../TERMS_OF_SERVICE.md`
- `docs/BUNDLING_ANALYSIS.md`
- `docs/LAUNCH_EXECUTIVE_SUMMARY.md`
- `docs/WHATS_LEFT_FOR_LAUNCH.md`

**Finding:** the packaged app is useful supply-chain evidence, but bundled resources and legal text are not automatically reusable in PDF Editor. Exact engine version and packaged dependency provenance must be recorded before any distribution decision.

## 6. MetaExtract: parser registry, provenance, and security patterns

### 6.1 Extraction architecture

**Files:**

- `/Users/pranay/Projects/metaextract/docs/EXTRACTION_ENGINE_INTEGRATION.md`
- `docs/EXTRACTOR_REGISTRY.md`
- `docs/SPECIALIZED_ENGINES.md`
- `docs/COMPREHENSIVE_ENGINE_API.md`
- `docs/MODULE_DISCOVERY_SYSTEM.md`
- `docs/PENDING_EXTRACTION_PLAN.md`
- `docs/REGISTRY_SOURCE_CATALOG.md`

**Observed architecture:** Node/Express upload/API → temporary file → Python extraction subprocess → structured JSON. It has file validation, timeouts, health checks, tier-based access, and cleanup. The document extractor uses pypdf and has a broad multi-format registry; PDF is one format inside a much larger metadata platform.

**Transfer:** PDF Editor can reuse the registry concept, provider metadata, normalization discipline, and explicit “source list incomplete” state. It should not copy MetaExtract's broad metadata catalog or make it a runtime dependency.

### 6.2 Observability and sensitive fields

**File:** `docs/EXTRACTION_OBSERVABILITY.md`

**Verified design:** provenance records which module produced each top-level key; conflicts are explicit; sensitive-field detection emits paths and categories without values; shadow mode runs a comparison path under a bounded timeout; observability failures are non-fatal; lists and recursion are capped.

**Transfer:** PDF Editor's provider evidence should retain producer identity, method, coordinate space, confidence semantics, and failure state, while reports remain value-free by default. The same distinction between extraction payload and observability metadata is directly useful.

### 6.3 Security evidence caveat

**File:** `docs/SECURITY_TESTING_COMPLETE.md`

The document reports 35 security tests and broad OWASP coverage, but its “enterprise grade / approved for production” conclusion is historical project wording. For PDF Editor, only the tested file validation, path traversal, size, embedded script, and error-surface patterns should be salvaged, and they must be re-run against the PDF Editor runtime. Do not inherit the claim wholesale.

## 7. Invoice Intelligence: parser/OCR routing and benchmark discipline

### 7.1 Pipeline and dependencies

**Files:**

- `/Users/pranay/Projects/invoice-intelligence/docs/IMPLEMENTATION_WRITEUP.md`
- `backend/app/services/text_extract.py`
- `requirements-ocr.txt`
- `requirements-parsers.txt`
- `experiments/SYNTHETIC_DATA_PLAN.md`
- `experiments/MODEL_BENCHMARKING.md`
- `experiments/AUTORESEARCH_OUTSIDE_ML.md`

**Observed pipelines:**

1. OpenAI vision direct, with PDF rendering to images.
2. PaddleOCR + LLM.
3. LlamaParse + LLM.
4. Unstructured + LLM.
5. Hybrid router: digital-versus-scanned classification, parser/OCR route, validation, and vision fallback.

`text_extract.py` currently tries PyMuPDF, then pdfplumber, then `pdftotext`; image OCR tries PaddleOCR then Tesseract. It renders up to three PDF pages for OCR fallback.

**Dependencies:** PaddleOCR `2.9.1`, PaddlePaddle `2.6.2`, Unstructured PDF `0.16.12`, and LlamaParse `0.5.19` are declared in separate optional requirement files. The fallback hierarchy is a useful pattern but needs explicit source-content privacy and license admission in PDF Editor.

### 7.2 Benchmark evidence

**Files:**

- `experiments/MODEL_BENCHMARKING.md`
- `experiments/results.tsv`
- `experiments/candidates/*/summary.json`
- `experiments/candidates/*/error_analysis.json`
- `backend/data/benchmark/manifest.json`
- `backend/data/benchmark/ground_truth/*`
- `backend/data/benchmark/draft_labels/*`
- `backend/data/benchmark/runs/*`

**Verified but weak result:** one human-reviewed invoice produced a smoke winner of `gpt-4.1-mini` with weighted accuracy `0.7857`, average latency `2.6445s`, and objective `0.7328`. The document explicitly warns that one reviewed invoice is not statistically meaningful.

**Synthetic result:** digital synthetic sample weighted accuracy `0.9464`; handwritten-like PNG sample weighted accuracy `0.5476`. The docs correctly separate synthetic regression evidence from human-reviewed real-document claims.

**Transfer:** adopt the separation of draft versus reviewed labels, fixed evaluator, schema/validation gates, cost/latency/failure metrics, and hard-case error analysis. Never use a synthetic score as a general PDF/OCR claim.

### 7.3 Autoresearch discipline

**File:** `experiments/AUTORESEARCH_OUTSIDE_ML.md`

The repository maps fixed data/evaluator + one mutable candidate surface + machine-readable result + keep/discard/crash to prompts, routing, models, validation thresholds, and OCR/parser choices. It explicitly forbids mutating the evaluator, manifest, reviewed labels, or metric formula inside the loop. This is reusable for PDF provider bake-offs.

## 8. Medpiper / CoverWise: insurance-PDF extraction and local OCR

### 8.1 Current production/local split

**Files:**

- `/Users/pranay/Projects/medpiper/insurance_app/README.md`
- `requirements.txt`
- `requirements-local.txt`
- `requirements-production-ocr.txt`
- `README_ENHANCED.md`
- `src/services/document_processing_service.py`
- `src/ocr/pipeline.py`
- `src/ocr/pdf_processor.py`

**Observed split:** production requirements pin PyMuPDF `1.23.8` for direct text extraction and deliberately exclude heavy OCR models; the production OCR profile adds `pdf2image`, Torch, TorchVision, and `python-doctr==1.0.1`. Local development adds sentence-transformers and RAG evaluation dependencies.

The live service distinguishes direct embedded text from scanned/image-only PDFs. In the slim build, scanned PDFs and images receive an explicit OCR-unavailable state; local builds can use the OCR pipeline. Original document content remains authoritative; mobile/on-device OCR is supplementary and does not overwrite embedded PDF text.

### 8.2 Fallback and evaluation evidence

**Files:**

- `tests/test_fallbacks.py`
- `tests/test_ocr_runtime_selection.py`
- `tests/test_document_state_derivation.py`
- `tests/test_pdf_access.py`
- `tests/evals/run_evals.py`
- `tests/evals/live_fixture.py`
- `tools/evaluate_local_document_models.py`
- `tools/benchmark_chunking.py`
- `tools/explore_global_pdfs.py`
- `tools/explore_global_pdfs2.py`
- `tools/explore_global_pdfs3.py`

**Observed behavior:** tests cover direct PDF text, DocTR-to-PyMuPDF fallback, image OCR, shared OCR pipeline initialization, encrypted PDF access, source-text versus retrieval-text separation, citation verification, and owner-isolation/privacy payloads. The local document-model evaluator renders pages with PyMuPDF, compares expected token presence without persisting text by default, and optionally calls local Ollama vision models.

**Transfer:** explicit state derivation, no content in reports, source-text immutability, citation-bearing chunks, password handling, and owner isolation are highly relevant to PDF Editor's OCR/companion lane.

### 8.3 Product/documentation supersession

**Files:**

- `UX_AUDIT_FIRST_PRINCIPLES.md`
- `docs/decisions/ADR-2026-07-29-02-doctrine-stack-reconciliation.md`
- `coverwise_native_mobile_platform_store_readiness_audit_2026-07-21.md`
- `coverwise_launch_readiness_review_2026-07-22.md`

The UX audit contains strong engineering observations about upload friction, citations, and local OCR, but its camera-first, demo-policy, “what-if”, advisor-marketplace, and broad claim-assistant recommendations are explicitly superseded or narrowed by later product doctrine. This is a concrete example of why historical exploration must be read together with append-only supersession notes.

## 9. oc-mobile and orbitcover-d2c: extraction ownership and lockstep

### 9.1 Vendored bridge

**Files:**

- `/Users/pranay/Projects/oc-mobile/apps/extract-bridge/README.md`
- `apps/extract-bridge/requirements.txt`
- `bridge/vendor/extraction/MANIFEST.md`
- `docs/07_M0_ACCEPTANCE.md`
- `docs/11_MOBILE_PRODUCT_ARCHITECTURE_AUDIT_2026-08-19.md`
- `docs/12_MOBILE_ARCHITECTURE_IMPLEMENTATION_2026-08-19.md`

**Observed:** the bridge runs PDF-text tiering → model chain → gap-fill → normalize; its dedicated venv pins PyMuPDF `1.27.2.3`. The vendored snapshot is pinned to d2c commit `f3f26d3`, and contract tests enforce the public extraction shape. Without an OpenRouter key, current intended behavior is fail-closed provider unavailability with `extraction: null`.

**Verified in the implementation record:** keyless extraction tests pass with no invented PNR/passenger/route/date/fare values; local provider parity was tested through d2c → vendored bridge → authenticated API proxy. Deployment credentials, provider quota, cancellation, and production runtime remain separate gates.

**Transfer:** provider isolation, version lockstep, structured failure, no fabricated defaults, and a contract test that fails on drift are directly reusable. The d2c library remains upstream-owned; PDF Editor should not copy it.

### 9.2 Historical contradiction to preserve

The M0 acceptance doc calls the bridge a stub, while its append-only 2026-08-19 correction records real orchestration and the fail-closed behavior. The current implementation record is the newer authority. Similar contradictions exist in older OrbitCover audits; current code plus dated correction wins over stale status prose.

## 10. travel_agency_agent and SentinelTwin

### 10.1 PDF.js version reference

**Observed package:**

`/Users/pranay/Projects/travel_agency_agent/frontend/node_modules/.pnpm/pdfjs-dist@5.7.284/node_modules/pdfjs-dist/package.json`

It is `pdfjs-dist` `5.7.284`, Apache-2.0, with package engine declaration `node >=22.13.0 || >=24`. This is a local upgrade reference for PDF Editor's vendored PDF.js `4.2.67`, not evidence that PDF Editor should blindly adopt the version.

### 10.2 SentinelTwin

**Observed package:**

`/Users/pranay/Projects/SentinelTwin/node_modules/.pnpm/pdf-lib@1.17.1/node_modules/pdf-lib/package.json`

It confirms the local `pdf-lib` `1.17.1` pin is reused elsewhere. The duplication is harmless from a license perspective but should not create two PDF Editor sources of truth.

## 11. Cross-project findings that change PDF Editor decisions

### 11.1 The portfolio has a document-intelligence system, not isolated libraries

Across SignKit, MetaExtract, Invoice Intelligence, CoverWise, oc-mobile, and PDF Editor, the recurring primitives are:

- immutable source identity and SHA-256 binding;
- page-space coordinate contracts with rotation/crop-box transforms;
- native text/widgets first, raster/OCR only when structural evidence is insufficient;
- evidence items with provider/method/confidence/bounds;
- candidate ranking plus human review and abstention;
- parser/OCR/vision fallback with explicit failure state;
- provenance and source citation;
- fixed evaluators and human-reviewed ground truth;
- separate synthetic, public, packaged, private, and real-world corpus populations;
- no fabricated fields when the provider is unavailable;
- output reopen, structural, visual, semantic, and privacy validation.

This is more valuable than adopting another engine without integrating these contracts.

### 11.2 The most important local weaknesses

1. **License drift:** PyMuPDF/AGPL and Surya restrictions are spread across Projects and a packaged app.
2. **Version drift:** PDF.js `4.2.67` in PDF Editor versus `5.7.284` in travel_agency_agent; PyMuPDF versions range from `1.23.7/1.23.8` to `1.28.0` across projects.
3. **Evidence drift:** many historical docs use “complete”, “production-ready”, or “very high confidence” language that later addenda narrow.
4. **Generated-artifact volume:** benchmark outputs are rich but easy to misread as independent evidence; manifests and reports must remain canonical.
5. **Runtime ownership:** neighboring projects have useful patterns but their source, secrets, fixtures, models, and legal terms cannot become PDF Editor dependencies by implication.

### 11.3 What PDF Editor should own

PDF Editor should own one canonical set of:

- document/page/coordinate contracts;
- provider capability and license registry;
- evidence graph and confidence semantics;
- candidate review and abstention states;
- typed mutations and operation lineage;
- source-bound export and validation;
- governed corpus/benchmark manifests;
- cross-provider parity and mismatch taxonomy;
- privacy-safe result envelopes;
- companion lifecycle, cancellation, timeout, crash, and revocation contracts.

## 12. Prioritized next work from the crawl

### P0 — License and provenance

- Complete the per-install Artifex/datalab/packaged-framework inventory in `docs/pdf-license-hygiene-sweep-2026-08-25.md`.
- Do not route PDF Editor through PyMuPDF, MuPDF, OCRmyPDF, Surya, PaddleOCR, DocTR, LlamaParse, or Unstructured until exact artifact and distribution state is recorded.
- Preserve legal notices and packaged-app evidence; do not copy legal text across projects.

### P0 — Canonical contract and evidence

- Reconcile native/browser candidate taxonomy on Form 6 and rotated Form 6.
- Establish page-box precision policy.
- Extend parity to non-noop edits, OCR observations, companion results, and independent viewer outcomes.
- Keep reports value-free by default.

### P1 — OCR/parser bake-off

- Run the same governed corpus through Vision, Tesseract variants, browser WASM, DocTR, PDFium/PDFBox candidates, and local companion paths.
- Measure anchor recall, bounds, abstention, memory, cancellation, and output preservation separately.
- Keep synthetic and human-reviewed results in separate ledgers.

### P1 — Cross-project salvage

- Convert the strongest neighboring concepts into PDF Editor-owned fixtures/contracts, not copied code:
  - SignKit evidence fusion and hard negatives;
  - MetaExtract provenance and shadow mode;
  - Invoice Intelligence routing and evaluator discipline;
  - CoverWise source-text/citation/privacy states;
  - oc-mobile lockstep and fail-closed provider contract.

### P1 — Browser-version migration

- Use the 5.7.284 local package as a controlled reference.
- Upgrade only after PDF.js API/worker parity, detector output, coordinate normalization, browser resource policy, and export validation are checked.
- Keep the old vendor snapshot and rollback path until the new report is green.

## 13. Exact source register

The following files were read as decision-relevant evidence in this pass. Repeated per-fixture result JSON is grouped above by family and remains on disk under the paths named there.

### PDF Editor

- `pdf_editor/docs/pdf-feature-frontier.md`
- `pdf_editor/docs/pdf-engine-comparison.md`
- `pdf_editor/docs/capability-matrix.md`
- `pdf_editor/docs/cross-project-document-intelligence-exploration.md`
- `pdf_editor/docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`
- `pdf_editor/docs/audits/detector-hard-negative-calibration-evidence-2026-08-25.md`
- `pdf_editor/docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md`
- `pdf_editor/docs/audits/browser-resource-policy-evidence-2026-08-25.md`
- `pdf_editor/docs/audits/failure-mode-and-resilience-audit-per-0924.md`
- `pdf_editor/docs/audits/signkit-capability-crosswalk-2026-08-24.md`
- `pdf_editor/docs/pdf-projects-folder-crawl-2026-08-25.md`
- `pdf_editor/benchmark/results/README.md`
- `pdf_editor/benchmark/results/*/README.txt`
- `pdf_editor/README.md`, `progress.md`, `findings.md`, `task_plan.md`

### SignKit / Data Science

- `Data_Science/computer_vision/proj6/signature-extractor-app/docs/AUTO_DETECTION_ML.md`
- `.../docs/STIRLING_PDF_INTEGRATION.md`
- `.../docs/LIGHTWEIGHT_PDF_SIGNING.md`
- `.../docs/ARCHITECTURE_FINAL_DECISION.md`
- `.../docs/COORDINATE_MAPPING.md`
- `.../docs/ISSUE_ANALYSIS.md`
- `.../docs/DOC_UNDERSTANDING_ADDON.md`
- `.../docs/LOCAL_RAG_IMPLEMENTATION.md`
- `.../docs/BUNDLING_ANALYSIS.md`
- `extracted_forms/signkit-macos-arm64/SignKit.app/Contents/Resources/legal/THIRD_PARTY_LICENSES.md`

### MetaExtract

- `metaextract/docs/EXTRACTION_ENGINE_INTEGRATION.md`
- `metaextract/docs/EXTRACTOR_REGISTRY.md`
- `metaextract/docs/EXTRACTION_OBSERVABILITY.md`
- `metaextract/docs/FIELD_INVENTORY_SYSTEM.md`
- `metaextract/docs/REGISTRY_SOURCE_CATALOG.md`
- `metaextract/docs/PENDING_EXTRACTION_PLAN.md`
- `metaextract/docs/SECURITY_TESTING_COMPLETE.md`

### Invoice Intelligence

- `invoice-intelligence/docs/IMPLEMENTATION_WRITEUP.md`
- `invoice-intelligence/experiments/MODEL_BENCHMARKING.md`
- `invoice-intelligence/experiments/SYNTHETIC_DATA_PLAN.md`
- `invoice-intelligence/experiments/AUTORESEARCH_OUTSIDE_ML.md`
- `invoice-intelligence/backend/app/services/text_extract.py`
- `invoice-intelligence/requirements-ocr.txt`
- `invoice-intelligence/requirements-parsers.txt`

### CoverWise / Medpiper

- `medpiper/insurance_app/README.md`
- `medpiper/insurance_app/README_ENHANCED.md`
- `medpiper/insurance_app/requirements.txt`
- `medpiper/insurance_app/requirements-local.txt`
- `medpiper/insurance_app/requirements-production-ocr.txt`
- `medpiper/insurance_app/UX_AUDIT_FIRST_PRINCIPLES.md`
- `medpiper/insurance_app/tools/evaluate_local_document_models.py`
- `medpiper/insurance_app/tests/test_fallbacks.py`
- `medpiper/docs/technical/implementation/rag_optimization.md`

### OrbitCover / oc-mobile

- `oc-mobile/apps/extract-bridge/README.md`
- `oc-mobile/apps/extract-bridge/requirements.txt`
- `oc-mobile/bridge/vendor/extraction/MANIFEST.md`
- `oc-mobile/docs/07_M0_ACCEPTANCE.md`
- `oc-mobile/docs/11_MOBILE_PRODUCT_ARCHITECTURE_AUDIT_2026-08-19.md`
- `oc-mobile/docs/12_MOBILE_ARCHITECTURE_IMPLEMENTATION_2026-08-19.md`

### Local version references

- `travel_agency_agent/frontend/node_modules/.pnpm/pdfjs-dist@5.7.284/node_modules/pdfjs-dist/package.json`
- `SentinelTwin/node_modules/.pnpm/pdf-lib@1.17.1/node_modules/pdf-lib/package.json`
- `invoice_exp/README.md` and its benchmark/corpus manifest material
- `document extraction by chatgpt/README (1).md`, `OUTPUT_PARAMETERS.md`, `QA_REPORT.md`

## 14. Final conclusion

The Projects folder contains substantial PDF/document-intelligence prior art. The correct synthesis is not “pick the library that appears most often.” It is:

1. Keep PDF Editor's provider-neutral contract and evidence graph canonical.
2. Rebuild transferable concepts behind that contract.
3. Treat installed engines, neighboring code, packaged apps, benchmark artifacts, and historical docs as evidence with explicit ownership and truth status.
4. Prefer permissive providers for default distribution, with exact artifact-level license gates.
5. Keep OCR, signing, parser, layout, and companion lanes active but fail closed until their corpus, privacy, recovery, and licensing evidence is complete.

The deeper crawl validates the PDF Editor direction and exposes the real work: consolidation of evidence and ownership, not another unbounded list of PDF packages.
