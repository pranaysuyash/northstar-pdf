# Expanded Browser Corpus and Fidelity Gate Evidence

**Date:** 2026-08-25  
**Scope:** Browser PDF.js and pdf-lib proof over scanned, rotated, encrypted, malformed, large, and hybrid PDFs  
**Status:** Expanded corpus executed; fidelity boundaries remain explicit

## Result

The browser corpus initially expanded from 11 to 17 manifest entries. This
section is the retained 17-entry baseline before the governance extension;
the current 18-entry result is recorded below. Six new local derived fixtures
cover the original risk classes:

| Fixture | Class | Pages | Digest | Result |
| --- | --- | ---: | --- | --- |
| `hybrid-text-raster-form.pdf` | Text, form, and raster hybrid | 2 | `91d7ede0c6f942df47df9d284d96ffebab323fecc3a710f758047d24a53bf4b9` | Browser, native, qpdf, and independent viewer gates passed |
| `scanned-noisy.pdf` | Degraded raster-only scan | 1 | `f0c1a8d988db267d177079c7530fab7670969b64ed153f891e4997ec725fd4f1` | Browser, native, qpdf, and independent viewer gates passed |
| `rotated-hybrid-90.pdf` | Rotated hybrid | 2 | `cb8e3bd42a1b9d3731fc85d71cda88970b2c0ec1c87892a9adaf338e08c55ed3` | Browser, native, qpdf, and independent viewer gates passed |
| `encrypted-hybrid.pdf` | AES-256 encrypted hybrid | 2 | `7aa4e042cb249c5dc36fce672a91c7ca43c39fd7fce1dc43e70f8890212abacf` | Password open, no-op preservation, qpdf, and independent viewer gates passed; edits rejected |
| `malformed-hybrid-truncated.pdf` | Intentionally malformed hybrid | unavailable | `98f9a51e4cbdef0e146f52f2658b1f2d4d3a1d5b057f85791aae7cf2d8b99bfe` | Native and browser inspection failed safely as expected |
| `large-hybrid-40-pages.pdf` | Large hybrid resource and navigation stress | 40 | `8f035f4c742116710f17d2d2470e1b1931df4983faa8382847374e5853b02049` | Browser, native, qpdf, and independent viewer gates passed |

The generator is [`benchmark/generate_browser_corpus.sh`](../../benchmark/generate_browser_corpus.sh).
The source chain is local and explicit:

```text
public-sample-form.pdf + printed-scan.pdf
  -> hybrid-text-raster-form.pdf
  -> rotated-hybrid-90.pdf
  -> encrypted-hybrid.pdf
  -> malformed-hybrid-truncated.pdf
  -> large-hybrid-40-pages.pdf

printed-scan.png
  -> scanned-noisy.pdf
```

The hybrid fixture contains an authored text and AcroForm page plus a separate
raster-only page. The noisy scan is generated from the existing raster source
with grayscale conversion, Gaussian noise, blur, and contrast stretching. No
external document was downloaded or added.

## Browser contract gate

Command:

```text
PDF_PROOF_BASE_URL=http://127.0.0.1:8185/web/index.html \
  node Tests/web_pdf_contract_fixture_test.mjs
```

Baseline result: 17 fixtures, zero browser console errors, and zero browser page errors.

The gate verified source SHA-256 binding, lower-left crop-box coordinates,
typed operation payloads, export reopenability, page geometry, outside-region
text and visual checks, and operation lineage. It also verified that encrypted
hybrid opens with `reader-password`, no-op export preserves exact source bytes,
encrypted edits fail before download, malformed input stops at open failure,
and the 40-page hybrid reopens with all pages.

PDF.js emitted warnings for unusual existing metadata and malformed or
provider-generated annotation objects. These remained visible warnings, not
console-error failures or conformance claims.

## Native and browser semantic parity

Command:

```text
node Tests/cross_project_evidence_ledger_parity_test.mjs
```

Result:

```text
ledgerEntryCount: 6
baselineCorpusFixtureCount: 17
sourceEvidenceCount: 18
parityMismatchCount: 6
unexpectedMismatchCount: 0
passed: true
```

Retained report:
[`benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json`](../../benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json)

The six mismatches are classified as follows:

| Fixture class | Mismatch kinds | Interpretation |
| --- | --- | --- |
| Static Form 6 | 2 `candidate-semantic-set`, 2 `candidate.count` | Existing native/browser detector disagreement retained from the earlier corpus |
| Encrypted hybrid | 1 `page.geometry-or-text`, 1 `coordinates` | PDFKit reports 595.28 by 841.89 points while PDF.js reports 595 by 841 points for the encrypted first page |

No new hybrid, noisy-scan, rotated-hybrid, malformed, or large-hybrid fixture
introduced an unexpected semantic mismatch. The encrypted geometry difference
is allowed only for that fixture. No global geometry tolerance was added.

## Independent viewer and structural gates

### Independent viewer reopen

`bash benchmark/test_independent_viewer.sh` passed with:

```text
PASS: Poppler independently reopened and inspected 53 corpus PDF(s).
```

The sweep used Poppler `pdfinfo` and `pdftotext` plus MuPDF `mutool info`. It
included all five valid new browser-corpus fixtures and their retained native
and browser no-op outputs. The malformed fixture was excluded from the valid
reopen sweep and is covered by safe-failure assertions.

### qpdf source structure

`bash benchmark/test_qpdf_structure.sh` passed for the two existing source
fixtures checked by that deliberately narrow gate. The expanded browser
fixtures were separately checked through qpdf output validation and independent
viewer reopen.

### qpdf generated-output validation

`bash benchmark/test_qpdf_outputs.sh` passed for 55 generated PDFs, with six
already-classified recoverable Form 6 cross-reference warnings and zero hard
failures. Encrypted inputs and outputs were checked with the fixture password.
The malformed input was excluded because safe rejection is its expected gate
behavior.

### Preservation-sensitive gate

`PDF_PROOF_BASE_URL=http://127.0.0.1:8186/web/index.html node Tests/pdf_independent_preservation_test.mjs`
produced the expected mutation-sensitive result:

| Check | Result |
| --- | --- |
| Unauthorized text mutation | Failed, expected |
| Unauthorized raster mutation | Failed, expected |
| Authorized text preservation | Passed |
| Authorized raster preservation | Passed |
| Authorized output reopen | Passed |
| Rotated widget facts | `[90]` |
| Mixed Form 6 facts | `[90, 180]` |

The expanded parity report records source, native-output, and browser-output
preservation for the five valid new fixtures as passed in both lanes. The
malformed fixture has an expected failed source reopen and no published output.

## Evidence classification

| Evidence | Tier | Sensitivity | Scope |
| --- | --- | --- | --- |
| Fixture generation, hashes, and manifest | Tier 1/S1 | Low, local paths and digests | Reproducible local corpus provenance |
| Browser contract run | Tier 3/S1 | Medium, local PDFs in isolated Chrome | Browser contract emission, export, reopen, and validation |
| Native/browser parity | Tier 2/S1 plus Tier 3/S1 | Medium | Semantic agreement with six classified mismatches and zero unexpected mismatches |
| Poppler and MuPDF reopen | Tier 2/S1 | Medium | Independent parser/viewer reopenability |
| qpdf structure and output checks | Tier 2/S1 | Medium | Structural diagnostics and warning classification |
| Outside-region text/raster comparison | Tier 3/S3 | Medium | Mutation-sensitive preservation for the bounded reviewed operation |
| Visual inspection of rendered fixtures | Tier 2/S1 | Low, rendered local artifacts | Hybrid, noisy scan, rotated, and large fixture appearance sanity |

## Limits

This expansion does not prove OCR accuracy on the noisy scan, production scan
recall, arbitrary semantic text editing, XFA support, signed-PDF preservation,
PDF/UA conformance, byte-for-byte semantic object preservation, independent GUI
viewer parity, large-document memory or time limits beyond 40 pages, resolution
of the existing Form 6 detector mismatches, or resolution of the encrypted
geometry serialization mismatch.

The next fidelity gate is a measured class matrix for large images, rotated
scans, malformed xref/object/stream variants, restricted and unsupported
encryption, signed PDFs, and richer hybrid documents with tables and
annotations. Current browser claims remain evidence-gated until those gates
produce enough evidence for a document-class support decision; the corresponding
capability implementation lanes remain active.

## Governance corpus extension, 2026-08-25

The privacy/provenance governed corpus added the synthetic handwritten-like
raster fixture. The shared native/web parity run now covers 18 fixtures. Its
result remains 6 classified mismatches and 0 unexpected mismatches, with zero
mismatches for the handwritten fixture. The dedicated governance evidence is in
[`pdf-corpus-governance-evidence-2026-08-25.md`](pdf-corpus-governance-evidence-2026-08-25.md).
