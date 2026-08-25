# Release Gate Runbook

Run from `/Users/pranay/Projects/pdf_editor` with no Git mutations.

## 1. Source and native gates

```sh
swift test
swift build -c release
bash benchmark/test_pdfkit_benchmark.sh
bash benchmark/test_pdfkit_widget_benchmark.sh
bash benchmark/test_pdfkit_acroform_benchmark.sh
bash benchmark/test_qpdf_structure.sh
bash benchmark/test_qpdf_outputs.sh
bash benchmark/test_independent_viewer.sh
node Tests/pdf_independent_preservation_test.mjs
node Tests/pdf_contract_parity_test.mjs
```

The AcroForm benchmark is expected to remain a release blocker until RG-001 is resolved. A failed result must be preserved, not masked.

## 2. Web static gates

```sh
node Tests/web_reader_contract_test.mjs
node Tests/provenance_contract_test.mjs
node Tests/web_accessibility_gate_test.mjs
tmpfile=$(mktemp /tmp/pdf-editor-web-XXXXXX.mjs)
sed -n '/<script type="module">/,/<\/script>/p' web/index.html | sed '1d;$d' > "$tmpfile"
node --check "$tmpfile"
rm -f "$tmpfile"
```

## 3. Local web interaction gate

Start a local server:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Use an isolated Playwright browser context to verify:

- Public text-bearing fixture opens.
- Canvas and DOM text layer render.
- Search marks appear.
- Metadata and permission panels populate without null crashes.
- Single-page, fit-page, rotate, and page-jump controls work.
- Skip-link focus works.
- No page errors or console errors occur.

Stop the server after the run. Do not use a shared daemon attached to another project as release evidence.

## 4. Fixture and provenance gate

Regenerate the deterministic security fixtures before their gate:

```sh
bash benchmark/generate_security_fixtures.sh
bash benchmark/test_security_fixtures.sh
bash benchmark/generate_ocr_fixture.sh
bash benchmark/test_ocr_fixture.sh
```

Every fixture must record:

- Exact source path or acquisition source.
- License or permitted-use basis.
- SHA-256 digest.
- Page count and relevant characteristics.
- Expected provider facts.
- Expected failures and unsupported behavior.
- The gate IDs that consume it.

## 5. Independent validation gate

Run the chosen independent validator against source and output fixtures. Record tool version, command, result, warnings, and limitations. Do not convert a passing reopen into a structural or PDF/UA conformance claim.

The source-only qpdf gate is:

```sh
bash benchmark/test_qpdf_structure.sh
```

The generated-output gate is deliberately separate and stricter:

```sh
bash benchmark/test_qpdf_outputs.sh
```

For output files, treat any qpdf warning as a release failure until the provider
or output path is corrected. The current corpus is expected to fail this gate;
that failure is evidence for the provider-fidelity NO-GO, not a reason to weaken
the gate. Intentionally encrypted, malformed, OCR-source, and stress-input
fixtures are consumed by their dedicated gates and are excluded from this
generated-output sweep.

The independent viewer gate uses Poppler `pdfinfo`/`pdftotext` and MuPDF
`mutool info` to verify reopenability through two independent viewer/parser
paths, separately from qpdf structure checks:

```sh
bash benchmark/test_independent_viewer.sh
```

The preservation-sensitive gate is separate from the broad reopen sweep. It
compares Poppler text and `pdftoppm` raster output outside the source-bound
operation region, exercises an unauthorized mutation that must fail, and
verifies 90-degree and mixed 90/180-degree rotated fixtures:

```sh
node Tests/pdf_independent_preservation_test.mjs
```

The native/web parity runner retains validated no-op output bytes and writes
the machine-readable report to
`benchmark/results/contract-parity-2026-08-24/independent-preservation-report.json`.

The browser-export cross-renderer gate is a separate comparison report. It
joins the PDF.js `outsideRegionText` and `visualDiff` checks with Poppler's
outside-region text/raster result and fails on a provider divergence. It keeps
malformed expected failures as `expectedFailure` plus `unknown` comparison,
never as a pass:

```sh
node Tests/browser_export_independent_viewer_validator_test.mjs
node benchmark/browser-export-independent-viewer-validator.mjs \
  --result-root benchmark/results/semantic-parity/2026-08-25 \
  --report benchmark/results/semantic-parity/2026-08-25/independent-browser-viewer-report.json
```

The full `Tests/pdf_contract_parity_test.mjs` runner emits this report beside
the existing independent-preservation report. Poppler is the independent
renderer for this lane; MuPDF remains a separate control and is not silently
merged into the result.

The joined report also retains normalized Poppler and PDF.js metrics. A
`comparable` measurement means both providers rendered comparable pages;
`notComparable` identifies a source-digest or no-op shortcut, and
`notMeasured` identifies a missing provider payload. For edited browser
exports, `editSession.operations` must be serialized and source-bound. Missing
operation lineage or a coordinate/page mismatch is `unknown`, never an empty
authorization region or a pass.

The browser review/export panel exposes the same PDF.js outside-region metrics
to the reviewer. Verify both a passing no-op export and a failed reviewed
operation. The panel must show text and raster status, compared/changed page
counts, changed/compared pixels when rendered, ratio, maximum channel delta,
scale/tolerance, and the evidence basis without displaying extracted outside
text.

## 6. Accessibility gate

Capture separate evidence for:

- Keyboard-only operation.
- Native VoiceOver observation.
- Browser screen-reader observation.
- Reading-order behavior.
- Tagged-content preservation.
- PDF/UA validator result.

## 7. Release disposition

The release report must contain a gate table, failed gates, blocked gates, evidence links, supported subset, known limitations, rollback/recovery path, and a final `GO`, `NO-GO`, or scoped `GO` decision.
