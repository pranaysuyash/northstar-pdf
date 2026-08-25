# Native/browser privacy preflight parity evidence

**Date:** 2026-08-25  
**Status:** Implemented and measured  
**Contract:** `pdf-editor.preflight` 1.1  
**Corpus:** `docs/fixtures/manifest.md`, 18 entries  
**Evidence tier:** Native Swift harness plus isolated Chrome browser harness

## Result

The native PDFKit and browser PDF.js adapters emit the same read-only preflight
contract for metadata presence, attachments, annotation taxonomy, script and
action indicators, revision markers, coverage states, unknown coverage,
source binding, and sanitization limits. No action is executed and no source
bytes or sensitive values are placed in the report.

The implementation is in
[`web/pdf-preflight.mjs`](../../web/pdf-preflight.mjs),
[`PreflightContracts.swift`](../../Sources/PDFEditorCore/PreflightContracts.swift),
and the PDFKit/browser fixture surfaces. The parity wiring is in
[`Tests/pdf_contract_parity_test.mjs`](../../Tests/pdf_contract_parity_test.mjs).

## Normalization policy

The comparator removes only representation noise: provider ID, version,
platform, and generated timestamp; provider-specific finding IDs; provider
annotation-enumeration labels; and output-file digests. It retains source
SHA-256, all privacy counts, metadata presence, annotation kinds, action
counts, revision evidence, coverage states, unknown reasons, finding
severity/state, `executionAttempted`, and sanitization state.

## Corpus result

Machine report:
[`privacy-preflight-parity-report.json`](../../benchmark/results/preflight-parity-2026-08-25/privacy-preflight-parity-report.json)

| Measure | Result |
|---|---:|
| Manifest entries | 18 |
| Native/browser readable reports | 16 / 16 |
| Matching malformed failures | 2 / 2 |
| Semantic mismatches | 3 |
| Fixtures with mismatches | 1 |
| Unknown coverage disagreement | 0 |
| Annotation/script/revision disagreement | 0 |
| Source binding disagreement | 0 |

All three mismatches are on `public-sample-form.pdf` and represent one
underlying adapter difference: PDFKit does not report a keyword as present
while PDF.js does. The mismatch remains open evidence rather than being
normalized away.

## Verification

```text
node Tests/preflight_contract_test.mjs
swift test --filter PreflightContractTests
PDF_PROOF_BASE_URL=http://127.0.0.1:4174/web/index.html \
PDF_PARITY_RESULT_ROOT=benchmark/results/preflight-parity-2026-08-25 \
node Tests/pdf_contract_parity_test.mjs
```

The browser run used an isolated project server because port 4173 belonged to
another local project. The temporary server and browser process were stopped
after verification. The report contains no PDF bytes, metadata values,
attachment names, URLs, page text, OCR values, passwords, or active-content
payloads.

## Remaining long-term build lanes

This is read-only preflight and semantic parity evidence, not proof that a PDF
is safe or sanitized. Metadata/XMP removal, embedded-data policy, action
neutralization, incremental-revision parsing, cryptographic signature effects,
XFA/rich-media policy, independent-viewer checks, and partial sanitization
recovery remain to be implemented on the same source-bound spine.
