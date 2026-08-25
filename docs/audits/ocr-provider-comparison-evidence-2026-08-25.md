# Local OCR and Optional Companion Comparison

**Date:** 2026-08-25  
**Status:** Measured partial, promotion blocked  
**Comparison contract:** `pdf-editor.ocr-provider-comparison` version `1.0`  
**Corpus manifest:** [`Tests/fixtures/pdf_corpus_governance_manifest.json`](../../Tests/fixtures/pdf_corpus_governance_manifest.json)  
**Comparison fixture:** [`Tests/fixtures/ocr_provider_comparison_fixture.json`](../../Tests/fixtures/ocr_provider_comparison_fixture.json)  
**Runner:** [`benchmark/compare_ocr_providers.mjs`](../../benchmark/compare_ocr_providers.mjs)  
**Native Vision runner:** [`Sources/PDFOCRBenchmark/main.swift`](../../Sources/PDFOCRBenchmark/main.swift)  
**Machine report:** [`benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json`](../../benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json)  
**Test:** [`Tests/ocr_provider_comparison_test.mjs`](../../Tests/ocr_provider_comparison_test.mjs)

## Executive result

The shared corpus comparison is implemented and reproducible. It measured three
local OCR lanes, including a browser WASM worker served entirely from local
assets, and recorded explicit non-measurement or control-only states for
optional companions:

| Provider | Capability | Corpus result | Latency result | Privacy | License/admission | Disposition |
|---|---|---:|---:|---|---|---|
| Native Vision | `ocr.textBounds` | Mean anchor recall `0.944`; class gate passed | Median `97.5 ms`; p95 `425.1 ms`; budget passed | Passed | Local system framework use | `measuredPartial`, candidate-evidence lane only |
| Tesseract 5.5.0 | `ocr.textBounds` | Mean anchor recall `0.778`; noisy-scan gate failed | Median `189.1 ms`; p95 `401.3 ms`; budget passed | Passed | Apache-2.0 engine and models are permissive signals; exact package/traineddata review remains open | `measuredPartial`, not enabled |
| Browser WASM Tesseract.js 5.1.1 | `ocr.textBounds` | Mean anchor recall `0.778`; noisy-scan gate failed | Median `257.8 ms`; p95 `11,945.9 ms`; provisional budget passed | Local-only asset boundary passed | Package/core/model license recorded; distribution review remains open | `measuredPartial`, not enabled |
| OCRmyPDF | `ocr.searchableLayer` | Not measured, executable unavailable | Not measured | Not measured | MPL-2.0 core with dependency and security review required | `unavailable-uninstalled` |
| Apache PDFBox | PDF text extraction/forms/editing | Not measured, package/JAR unavailable | Not measured | Not measured | Apache-2.0, exact package review required | `installedUnmeasured` in registry; no runtime evidence |
| MuPDF | High-fidelity PDF operations | Not measured as a provider | Not measured | Not measured | AGPL-3.0 or commercial license | `quarantined`, no routing |

The aggregate promotion gate is **blocked**. The failure is intentional and
evidence-led:

- Tesseract missed all three anchors on the degraded noisy scan, producing
  `0.0` recall against the declared `0.66` class threshold.
- Native Vision reached exactly `2/3` on the same noisy scan and passed the
  calibrated `0.66` threshold.
- Simulated handwriting-like text was measured, but no provider is allowed to
  turn that result into a genuine handwriting, identity, or signature claim.
- Licensing is not cleared for packaged Tesseract or any optional companion.
- Companion crash, timeout, cancellation, and partial-output recovery remain
  unmeasured because no companion runtime is installed.
- Browser WASM made no external requests in this run, but its noisy-scan box
  count diverged sharply from Vision (`687` versus `3`) and its p95 recognition
  time approached the 15-second resource gate. It remains evidence-only.

This is a provider measurement result, not a product scope reduction. OCR,
searchable-layer generation, PDFBox, MuPDF, and companion execution remain
long-term implementation lanes behind the same shared contracts and admission
gates.

## Corpus and method

The comparison uses the governed corpus digest recorded in the machine report:

```text
corpus manifest:       16 governed fixtures
corpus digest:         de862e182b2b6f9f3e68387cfb20dbeb51fd4bdc6158f0ef53c735d5817971b4
comparison descriptor:  bf595f86ea25f0e6951fa827eb0cadf0bb7e953e707ddad95dbb550942777afd
```

The OCR subset contains six inputs:

| Input | Class exercised | Ground-truth use |
|---|---|---|
| `printed-scan` | Clean raster scan | Three line anchors |
| `scanned-noisy` | Noise, blur, contrast degradation | Three line anchors and abstention pressure |
| `handwritten-simulated-entries` | Simulated handwriting-like glyphs | Six anchors, evidence only |
| `rotated-hybrid-90-raster-page` | Rotated raster page inside a hybrid PDF | Three anchors and coordinate-transform context |
| `encrypted-hybrid-raster-page` | Explicit-password encrypted hybrid | Three anchors after local unlock |
| `large-hybrid-raster-page-40` | Representative page from 40-page hybrid | Three anchors and page-budget context |

Accuracy is measured as line-anchor recall, not character-level truth and not
field-completion accuracy. The runner reads ground truth locally, emits only
counters, and never writes recognized text to the report. Word confidence is
normalized to `[0,1]` at each provider boundary. Word boxes are normalized to
the shared `normalizedLowerLeft` page space; the source Tesseract coordinates
are top-left pixel coordinates and are transformed before serialization.

The latency budget is a provisional resource-safety gate of 15 seconds per
provider request. It is not a user-facing performance SLA. Tesseract timings
include local process startup. Vision timings include the native request and
image analysis, with model warm-up visible in the first request. Browser WASM
timings cover recognition after the local worker and model are ready; cold
worker startup, model download, peak memory, and all-page throughput remain
separate open measurements.

## Accuracy evidence

| Fixture | Native Vision | Tesseract CLI | Browser WASM | Interpretation |
|---|---:|---:|---:|---|
| Clean printed scan | `3/3` | `3/3` | `3/3` | All measured lanes pass clean English anchors |
| Noisy scan | `2/3` | `0/3` | `0/3` | Vision passes the provisional class gate; both Tesseract lanes fail and must abstain or use stronger preprocessing/model lanes |
| Simulated handwriting-like | `6/6` | `4/6` | `4/6` | Synthetic calibration only; no genuine handwriting or signature claim |
| Rotated hybrid raster page | `3/3` | `3/3` | `2/3` | Browser result remains evidence-only pending rotation/preprocessing calibration |
| Encrypted hybrid raster page | `3/3` | `3/3` | `3/3` | All lanes pass only after explicit local unlock |
| Large hybrid page 40 | `3/3` | `3/3` | `3/3` | Representative page passes; this is not full 40-page OCR accuracy |

The native Vision gate passed for this controlled subset. Its registry state
remains `measuredPartial` because the measurement does not cover language
breadth, real handwriting, full-page OCR layer writing, output fidelity, or
all governed scan variants.

Tesseract remains useful as a permissive local and companion control lane, but
the noisy-scan failure prevents the project from treating the installed binary
as an enabled general OCR provider. The next Tesseract experiment should
compare `tessdata_fast` and `tessdata_best`, preprocessing variants, language
packs, and confidence-calibrated abstention without changing the shared OCR
evidence contract.

The browser WASM lane proves that the same evidence contract can run in a local
browser worker without a network dependency. It does not prove browser-wide
performance or accuracy: the noisy fixture produced `687` valid word boxes and
union IoU `0.083` against Vision, while the other five union comparisons were
classified aligned at the current threshold. Its package, core, and language
artifact digest is recorded in the machine report as
`232a7fb32ee0bd57470bc57ad348be394859c52eeb5abbec35180402317a6f05`.

## Bounds, confidence, and alignment evidence

All three measured lanes serialize `normalizedLowerLeft` bounds, valid-bound
counts, union bounds, and aggregate confidence in `[0,1]`. The comparison is
not claiming word-level geometric equivalence: providers may segment the same
line differently. The current value-free union control reports:

| Fixture | CLI versus Vision IoU | Browser WASM versus Vision IoU | Status |
|---|---:|---:|---|
| `printed-scan` | `0.948` | `0.948` | aligned |
| `scanned-noisy` | `0.116` | `0.083` | divergent hard negative |
| `handwritten-simulated-entries` | `0.592` | `0.592` | aligned at current control threshold |
| `rotated-hybrid-90-raster-page` | `0.963` | `0.962` | aligned |
| `encrypted-hybrid-raster-page` | `0.936` | `0.936` | aligned |
| `large-hybrid-raster-page-40` | `0.936` | `0.936` | aligned |

The noisy case is retained as a provider-divergence and abstention fixture. A
confidence score or aligned union must never create a field without candidate
evidence, human review, source binding, and downstream export validation.

## Latency and resource evidence

| Provider | Mean anchor recall | Median request time | p95 request time | 15-second gate |
|---|---:|---:|---:|---|
| Native Vision | `0.944` | `97.5 ms` | `425.1 ms` | Pass |
| Tesseract 5.5.0 | `0.778` | `189.1 ms` | `401.3 ms` | Pass |
| Browser WASM Tesseract.js | `0.778` | `257.8 ms` | `11,945.9 ms` | Pass, near boundary |

The run did not yet measure peak memory, sustained all-page OCR throughput,
worker cancellation, thermal throttling, or concurrent requests. The 40-page
fixture check verified page count and rendered page 40, but did not OCR all 40
pages or prove cancellation recovery.

## Privacy gates

The machine report records all of the following as false:

- source bytes logged;
- page text logged;
- OCR text logged;
- ground-truth text logged;
- passwords logged;
- profile values logged;
- report contains content.

The report stores fixture IDs, provider IDs, artifact/corpus digests, counts,
timing numbers, confidence aggregates, statuses, and error codes. It does not
store OCR transcripts, screenshots, page paths, passwords, field values, or
profile values. The native Vision executable compares recognized text with
ground truth in memory and serializes only counters.

The privacy gate is therefore a local benchmark and zero-content-report gate.
It is not proof that every future OCR library, worker, diagnostic exporter, or
companion process will preserve the same boundary. Each provider must pass the
same audit before admission.

The browser runner served Tesseract.js, its WASM core, and English language
data from a local temporary origin and recorded `browserExternalNetworkRequests`
as an empty list. This proves the boundary of this run, not every future model
loading mode. A CDN, telemetry library, remote model, companion IPC endpoint,
or diagnostic exporter would require a new privacy record.

## Recovery gates

| Recovery case | Observed result | Gate |
|---|---|---|
| Malformed hybrid | qpdf rejected it, rasterization rejected it, and no output was published | Pass |
| Encrypted hybrid without password | Rasterization rejected it | Pass |
| Encrypted hybrid after explicit unlock | Page rendered locally; password was not logged | Pass |
| Large 40-page hybrid | Page count `40` observed and representative page rendered | Pass, partial |
| Large-document cancellation | Not measured | Open |
| Companion crash/timeout | No companion installed | Open |
| Partial companion output publication | No live companion path exercised | Open |
| Revocation during active OCR | No live companion path exercised | Open |

The recovery rule remains fail-closed: a provider failure cannot create a
candidate, field, text layer, or export. A fallback provider must receive the
original source-bound intent and must produce a new provider-attributed result;
it must not treat an untrusted partial output as new source truth.

## Licensing and supply-chain gates

The current primary sources support the following facts, while exact
distribution approval remains a separate project gate:

- [Tesseract documentation](https://tesseract-ocr.github.io/tessdoc/) identifies
  Tesseract as Apache-2.0 and documents direct command-line/API use.
- [Tesseract fast traineddata](https://github.com/tesseract-ocr/tessdata_fast)
  identifies the model repository as Apache-2.0, but the exact installed
  package and model provenance must still be recorded for distribution.
- [Tesseract.js](https://github.com/naptha/tesseract.js/) documents the
  WebAssembly and worker browser path. The measured package and core were
  served locally, with package/core Apache-2.0 metadata and the installed
  `@tesseract.js-data/eng` language artifact recorded as MIT in the machine
  report. The exact artifact digest is evidence, not a blanket redistribution
  approval.
- [Apple Vision text recognition](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)
  provides native text observations, bounds, confidence, and recognition-level
  controls. It is a system-framework capability, not a redistributable OCR
  binary in the project bundle.
- [Apache PDFBox](https://pdfbox.apache.org/) is Apache-2.0 and documents text
  extraction, forms, page operations, rendering, and signing. It is not an OCR
  engine by itself, so PDFBox evidence cannot be substituted for OCR evidence.
- [OCRmyPDF](https://github.com/ocrmypdf/OCRmyPDF) is MPL-2.0 at the project
  level, while its documented dependency and security boundary requires review.
  The [OCRmyPDF security documentation](https://ocrmypdf.readthedocs.io/en/stable/introduction.html)
  warns that it is not designed to defend against malware-bearing PDFs or
  arbitrary public-web uploads.
- [MuPDF licensing](https://mupdf.com/releases) states the AGPL or commercial
  licensing path. The local registry therefore keeps the MuPDF provider
  quarantined until the distribution choice is explicit.

No provider is promoted based on an engine-family string alone. The provider
admission contract still requires an exact artifact digest, corpus digest,
report digest, license state, and capability-specific gates.

## Decision and next gates

The current evidence supports this long-term implementation direction:

1. Keep native Vision as the first measured native OCR evidence provider, with
   candidate bounds and confidence only. Do not create fields silently.
2. Retain Tesseract as a permissive local/companion control lane and improve it
   through preprocessing, model, language, and abstention experiments. Do not
   enable the current binary for general scanned completion because noisy-scan
   accuracy failed.
3. Retain Browser WASM Tesseract.js as a local browser evidence lane, but do
   not enable it for general scanned completion until noisy-scan accuracy,
   rotation behavior, full-page memory, cancellation, and model loading policy
   are measured.
4. Implement OCRmyPDF as an isolated companion capability only after package,
   dependency, malware-input, PDF/A, output-preservation, and recovery gates
   are executable.
5. Measure PDFBox as a companion document-structure and high-fidelity control
   lane, not as an OCR substitute.
6. Keep MuPDF behind the existing capability registry and licensing gate. Its
   high-fidelity potential does not override the AGPL/commercial decision.

The next measurement units are:

- held-out scan pages with independent labels and class-balanced error analysis;
- `tessdata_fast` versus `tessdata_best` and preprocessing comparisons;
- multilingual and rotated-scan language policy;
- browser WASM model loading, preprocessing, worker memory, cancellation, and
  all-page throughput;
- all-page large-document OCR with peak memory, cancellation, retry, and
  partial-output recovery;
- an installed PDFBox runner against the same malformed, encrypted, rotated,
  form, and outside-region fidelity corpus;
- an authenticated companion crash/timeout/revocation harness;
- searchable-layer output validation, independent extraction, raster
  preservation, and PDF/UA checks for OCRmyPDF or another writer.

The comparison is currently Tier 3/S1 for local OCR and recovery, with S2
threshold calibration evidence and no Tier 4 companion-runtime evidence.
