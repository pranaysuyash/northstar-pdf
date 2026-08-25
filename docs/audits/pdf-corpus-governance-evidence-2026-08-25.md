# Privacy and Provenance Governed Corpus Evidence

**Date:** 2026-08-25  
**Status:** PASS for governance and structural evidence  
**Manifest:** [`Tests/fixtures/pdf_corpus_governance_manifest.json`](../../Tests/fixtures/pdf_corpus_governance_manifest.json)  
**Harness:** [`Tests/pdf_corpus_governance_test.mjs`](../../Tests/pdf_corpus_governance_test.mjs)

## Result

The governed corpus contains 16 retained artifacts covering:

- scanned printed and degraded raster PDFs;
- rotated native and static forms;
- malformed truncated PDFs;
- encrypted native and hybrid PDFs;
- a synthetic handwritten-like raster PDF;
- mixed text/form/raster PDFs;
- native forms, static forms, and large resource-stress PDFs.

All 16 fixture digests were verified against the manifest. The structural qpdf
gate passed for every valid fixture. The two malformed fixtures returned the
expected non-zero qpdf status and remain safe-failure inputs rather than repaired
documents. Both encrypted fixtures passed qpdf validation only when the
explicit fixture password was supplied to the validator.

The synthetic handwritten-like fixture is:

[`benchmark/results/governed-corpus/handwritten-simulated-entries.pdf`](../../benchmark/results/governed-corpus/handwritten-simulated-entries.pdf)

Its image, ground truth, and README are retained beside it. The image was
visually inspected. Tesseract completed an OCR probe with 221 output bytes, but
the output was not logged and no accuracy claim was made. The fixture is not
evidence for genuine handwriting recognition, biometrics, identity, or signature
validity.

## Adapter execution

The handwritten fixture was added to the native/web parity manifest and exercised
through both adapters.

```text
corpusFixtureCount: 18
parityMismatchCount: 6
unexpectedMismatchCount: 0
handwritten fixture mismatchCount: 0
passed: true
```

The overall six classified mismatches remain the previously documented Form 6
candidate differences and encrypted-hybrid geometry/coordinate precision
difference. Adding the handwritten fixture did not introduce a new semantic
mismatch.

## Privacy controls verified

- The manifest assigns every artifact a privacy class.
- Existing external sample acquisition/license uncertainty remains explicit.
- Synthetic artifacts name their generator and source chain.
- Ground truth is a sidecar with a declared local-only policy.
- Encrypted fixture passwords are not placed in reports or contracts.
- Malformed fixtures cannot be exported by the allowed-operation policy.
- Handwritten-like output is explicitly excluded from biometric and signature
  claims.
- The governance report contains fixture IDs, statuses, counters, and provider
  state only. It does not contain page text, OCR text, image pixels, passwords,
  signatures, or profile values.

## Commands and retained evidence

```text
bash benchmark/generate_governed_corpus.sh
node Tests/pdf_corpus_governance_test.mjs
node Tests/provenance_contract_test.mjs
bash benchmark/test_ocr_fixture.sh
node Tests/cross_project_evidence_ledger_parity_test.mjs
```

Machine-readable result:
[`benchmark/results/governed-corpus/governance-report.json`](../../benchmark/results/governed-corpus/governance-report.json)

The corpus governance result is structural/provenance evidence. It does not
close OCR accuracy, handwritten recognition, multilingual OCR, arbitrary PDF
editing, redaction, signature validity, XFA, PDF/UA, collaboration, hosted
processing, or universal fidelity gates. Those are active capability lanes and
must add their own governed fixtures and validators.
