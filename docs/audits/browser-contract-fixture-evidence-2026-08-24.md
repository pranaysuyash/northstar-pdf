# Browser Contract Fixture Evidence

**Date:** 2026-08-24  
**Surface:** local web companion, isolated Chrome, Playwright  
**Evidence tier:** Tier 3/S1 integration evidence for browser contract emission  
**Disposition:** historical pre-expansion baseline. This report emitted contracts across the ten-entry manifest snapshot used on 2026-08-24. The current 17-entry result, including scanned, hybrid, encrypted, malformed, rotated, and large fixtures, is recorded in [`browser-corpus-fidelity-evidence-2026-08-25.md`](browser-corpus-fidelity-evidence-2026-08-25.md).

## Purpose

This fixture exercises the existing PDF.js reader and pdf-lib export path and
emits the shared contract families needed by later native/web comparison work.
It deliberately reuses the browser reader's inspection, coordinate conversion,
candidate detector, operation ledger, and validation implementation rather than
creating a second detector or a second coordinate system.

The fixture bundle contains:

- `document`: the versioned `pdf-editor.document` envelope;
- `coordinates`: explicit page `PDFPageRegion` projections for every inspected
  page;
- `candidates`: the document candidate records, including evidence items;
- `editSession`: the versioned `pdf-editor.edit-session` envelope with reviews
  and operations;
- `validation`: the browser validation report, including warnings and failures.

The bundle carries source filename, byte count, and SHA-256 digest. It never
includes the source PDF bytes.

Independent reopenability is recorded separately by
`benchmark/test_independent_viewer.sh`; Poppler reopening a file is not treated
as proof of structural validity, semantic form preservation, visual fidelity,
or PDF/UA conformance.

## Commands

From the project root, with the local server running:

```sh
node Tests/web_reader_contract_test.mjs
node --check Tests/web_pdf_contract_fixture_test.mjs
node --check /dev/stdin < <(sed -n '/<script type="module">/,/<\/script>/p' web/index.html | sed '1d;$d')
node Tests/web_pdf_contract_fixture_test.mjs
```

The fixture runner reads corpus paths from
[`docs/fixtures/manifest.md`](../fixtures/manifest.md) and emits the complete
JSON bundle to stdout. Set
`PDF_CONTRACT_FIXTURE_OUTPUT_DIR=/path/to/output` to write one JSON file per
corpus entry. Generated JSON is intentionally not a checked-in source of truth
because IDs and timestamps are session-specific.

## Observed corpus results

| Corpus entry | Pages | Native fields | Candidates | Reviews | Operations | Validation |
|---|---:|---:|---:|---:|---:|---|
| `benchmark/results/public-sample-form.pdf` | 1 | 6 | 0 | 0 | 1 | `validatedWithWarnings` |
| `benchmark/results/2026-08-23-pdfkit-widgets/fixture.pdf` | 1 | 4 | 0 | 0 | 1 | `failed` |
| `benchmark/results/2026-08-23-public-acroform/noop.pdf` | 1 | 6 | 0 | 0 | 1 | `failed` |
| `docs/benchmarks/pdfkit-form6-run-2026-08-23/noop.pdf` | 2 | 0 | 15 | 1 | 1 | `validatedWithWarnings` |
| `benchmark/results/security-corpus/encrypted-reader.pdf` | 1 | provider-derived | provider-derived | provider-derived | provider-derived | password flow; provider result preserved |
| `benchmark/results/security-corpus/truncated-128-bytes.pdf` | unavailable | unavailable | unavailable | none | none | expected `cannot-open` |
| `benchmark/results/security-corpus/repeated-20-pages.pdf` | 20 | provider-derived | provider-derived | provider-derived | provider-derived | provider result preserved |
| `benchmark/results/ocr-corpus/printed-scan.pdf` | 1 | 0 | 0 | 0 | 0 | `validatedWithWarnings` or provider result preserved |
| `benchmark/results/security-corpus/encrypted-reader.pdf` | 1 | provider-dependent after password | provider-dependent | expected password flow | byte-preserving no-op export; encrypted edits explicitly rejected | `validated` for no-op; edit failure is expected |
| `benchmark/results/security-corpus/truncated-128-bytes.pdf` | unavailable | unavailable | unavailable | none | none | expected `cannot-open` failure |
| `benchmark/results/security-corpus/repeated-20-pages.pdf` | 20 | provider-derived | provider-derived | provider-derived | provider-derived | provider-derived |

The successful native-field export round-tripped the public sample through
pdf-lib and PDF.js. The static Form 6 export carried a confirmed candidate,
`overlayText` operation, page-space coordinate, and reopen validation.

The two failed native-field exports are useful evidence, not test noise:

- the generated widget fixture exposed `fullName` through PDF.js, but pdf-lib
  reported that it had no form field with that name;
- the PDFKit public-AcroForm no-op output exposed `applicant.name` through
  PDF.js, but pdf-lib reported that it had no form field with that name.

The security corpus adds three explicit boundaries: the encrypted fixture must
pass through the password dialog before inspection; unchanged encrypted export
must download the exact source bytes; and any encrypted edit must fail before
download. The truncated fixture must stop at `cannot-open` and never emit a
document contract.

These results show why “PDF.js can inspect a widget,” “pdf-lib can mutate that
widget,” and “the browser can preserve an unchanged protected source” must
remain separate provider capabilities. The emitted validation contract
preserves each boundary instead of labeling unsupported editing as validated.

## Contract assertions

The runner asserts that:

1. the document header and source payload carry the same digest;
2. every page has a zero-based page-space coordinate region;
3. page, candidate, evidence, and operation coordinates use points, lower-left
   origin, and crop-box-relative geometry;
4. candidates retain their typed evidence items and source digest;
5. operations carry source binding, coordinate geometry, and typed payloads;
6. the edit-session header uses the shared version and source digest;
7. successful validations reopen the export and emit page geometry, applied
   operation, source digest, and provider capability checks;
8. failed validations carry at least one explicit failed check;
9. validation operation IDs preserve the emitted operation lineage.

## What this proves and does not prove

The runner asserts zero browser console errors and zero page errors across the
corpus. PDF.js warnings for malformed or unusual source objects remain visible
in the captured run output and are not treated as conformance evidence.

This is browser integration evidence for contract emission and the bounded
PDF.js plus pdf-lib path. It proves that the browser lane can produce a
structured document inspection, coordinate records, candidate evidence,
reviewed operations, and validation report over the existing manifest corpus.

It does not yet prove:

- native/web serialized semantic parity;
- byte-identical or pixel-identical output;
- outside-region object preservation;
- independent-viewer reopening;
- broad AcroForm, XFA, encrypted, signed, scanned, rotated, malformed, or
  large-document fidelity;
- that every PDF.js-visible widget is writable by pdf-lib.

The next parity artifact should consume these emitted bundles alongside native
JSON fixtures and compare normalized semantics while allowing provider IDs,
timestamps, generated IDs, and PDF bytes to differ.
