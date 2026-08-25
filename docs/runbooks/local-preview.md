# Local Native Preview

## Build and Test

From `/Users/pranay/Projects/pdf_editor`:

```bash
swift test
swift build -c release
node Tests/web_reader_contract_test.mjs
node Tests/provenance_contract_test.mjs
node Tests/web_editor_workflow_test.mjs
node Tests/web_pdf_proof_playwright_test.mjs
node Tests/web_pdf_contract_fixture_test.mjs
```

The environment-gated fixture checks can be run with:

```bash
PDF_EDITOR_FORM6_INPUT="/Users/pranay/Desktop/RAr0Lq2Avu.pdf" \
PDF_EDITOR_PUBLIC_ACROFORM_INPUT="/Users/pranay/Projects/pdf_editor/benchmark/results/public-sample-form.pdf" \
swift test --filter PDFEditorCoreTests
```

The public AcroForm check is expected to report a failed validation because the
current PDFKit lane loses radio-choice metadata. That failure is a release gate,
not a test to weaken.

## Launch

```bash
swift run PDFEditor
```

In another terminal, launch the local web companion:

```bash
python3 -m http.server 4173 --bind 127.0.0.1
open http://127.0.0.1:4173/web/
```

The browser workflow is intentionally local and air-gapped. It loads the
vendored PDF.js and pdf-lib bundles from `web/vendor/`; it does not upload the
PDF.

### Design system verification

After any typography, color, spacing, or layout change, open the living specimen
pages to visually verify the tokens:

- http://127.0.0.1:4173/web/typography-specimen.html — type scale, weights, font stacks
- http://127.0.0.1:4173/web/typography-regression.html — responsive viewport widths

See [`docs/design-system-specimen.md`](../design-system-specimen.md) for details.

Open a PDF, inspect native fields or tentative suggestions, select a highlighted
suggestion, review its evidence, add text, dismiss/restore candidates, or choose
`Add text manually` and click a page. Use `Undo` to recover the last operation,
then export a new copy. Export reports remain visible when validation fails; the
source file is never a valid export target.

For a quick manual smoke pass, verify this sequence in both lanes:

1. Open a static PDF with no native fields.
2. Select a highlighted suggestion and confirm the review card identifies it as
   a suggestion rather than a field.
3. Add text, click the overlay to edit it, then undo it.
4. Dismiss a candidate, reveal dismissed candidates, and restore it.
5. Enter manual placement, click the page, add text, and export.

The current manual placement and candidate actions are session-local. Export
and reopen validation remain provider-specific evidence, not a blanket promise
that every PDF preserves all unrelated objects.

## Scope

This is a local native preview. It does not sign, notarize, deploy, upload, or make
claims about signature validity, redaction, XFA, or arbitrary text reflow.
