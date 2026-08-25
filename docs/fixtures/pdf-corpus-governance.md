# Privacy and Provenance Governed PDF Corpus

**Date:** 2026-08-25  
**Status:** Implemented local governance manifest and structural verification  
**Machine-readable authority:** [`Tests/fixtures/pdf_corpus_governance_manifest.json`](../../Tests/fixtures/pdf_corpus_governance_manifest.json)  
**Verification:** [`Tests/pdf_corpus_governance_test.mjs`](../../Tests/pdf_corpus_governance_test.mjs)

## Purpose

This corpus is the shared evidence substrate for the native macOS app, browser
app, OCR workers, installed local providers, hosted providers, independent
viewers, semantic parity, and preservation validators.

It is intentionally broader than the currently enabled browser or native slice.
The corpus does not decide which capability belongs in the product. It records
the source classes, privacy conditions, expected provider states, and evidence
needed to build and eventually enable every capability lane.

## Governing rules

Every artifact has:

- a stable fixture ID;
- a retained relative path;
- a SHA-256 digest over the exact bytes under test;
- a source kind and lineage statement;
- a privacy classification;
- one or more document classes;
- an expected inspection state;
- allowed operations and prohibited silent behavior;
- required validators;
- a refresh policy.

The default policy is local regression use. Source bytes, rendered images, OCR
results, ground truth, profile values, passwords, and derived exports must not
be uploaded or placed in telemetry without a separate experiment record.

Machine-readable logs may contain fixture IDs, digests, provider IDs, statuses,
counters, timings, and error codes. They must not contain page text, OCR text,
ground-truth content, image pixels, passwords, signatures, or profile values.

The manifest distinguishes four privacy/provenance classes:

| Class | Meaning | Default handling |
| --- | --- | --- |
| `synthetic-local` | Generated entirely from synthetic content or local test primitives | Safe for local regression; still do not upload by default |
| `local-derived-no-personal-content` | Derived from a local fixture after the project has recorded that it contains no personal content | Local regression and controlled provider tests |
| `local-derived-unknown-acquisition` | Local artifact whose acquisition or upstream license has not been fully established | Do not redistribute or use in public examples |
| `external-sample-license-unresolved` | External sample retained locally while acquisition/license facts remain open | Do not publish, sync, or package without a separate review |

## Coverage matrix

| Class | Representative fixture | Expected state | Important gates |
| --- | --- | --- | --- |
| Scanned printed | `ocr-corpus/printed-scan.pdf` | Inspectable raster-only PDF, no authored text layer | OCR evidence, searchable-layer provenance, no silent field creation |
| Scanned noisy | `browser-corpus/scanned-noisy.pdf` | Inspectable raster-only PDF with degraded image quality | OCR calibration, low-confidence abstention, preservation |
| Rotated native form | `rotation-corpus/rotated-widget-90.pdf` | Inspectable 90-degree widget PDF | Coordinate transforms, field bounds, rotated reopen |
| Rotated static form | `rotation-corpus/rotated-form6-mixed.pdf` | Inspectable with provider warning allowed | Outside-region comparison, coordinate parity, detector disagreement |
| Malformed truncated | `security-corpus/truncated-128-bytes.pdf` | Safe inspection failure | No crash, no hang, no export, typed error |
| Malformed hybrid | `browser-corpus/malformed-hybrid-truncated.pdf` | Safe inspection failure | Same fail-closed behavior across providers |
| Encrypted native form | `security-corpus/encrypted-reader.pdf` | Opens only after explicit password | Password non-persistence, permission handling, no unauthorized write |
| Encrypted hybrid | `browser-corpus/encrypted-hybrid.pdf` | Opens only after explicit password | Browser write capability state, source binding, geometry precision |
| Handwritten-like | `governed-corpus/handwritten-simulated-entries.pdf` | Raster-only synthetic handwriting-like image | OCR probe, handwriting abstention, no biometric or signature claim |
| Mixed content | `browser-corpus/hybrid-text-raster-form.pdf` | Authored text/form page plus raster page | Per-page extraction origin, OCR provenance, native/web parity |
| Large mixed content | `browser-corpus/large-hybrid-40-pages.pdf` | 40-page inspectable stress input | Cancellation, memory/resource budget, lazy thumbnails, recovery |

## Handwritten fixture boundary

The handwritten fixture is intentionally synthetic. It uses a local handwriting-
like system font to create visual variation while keeping the ground truth
known and privacy-safe. It is useful for testing:

- raster-only inspection;
- handwriting-like segmentation and OCR routing;
- abstention when a provider cannot establish reliable recognition;
- label-to-region association;
- reviewed overlay placement;
- outside-region raster comparison;
- zero-content diagnostic logging.

It is not evidence for genuine handwriting recognition, author identity,
biometrics, signature validity, or legal execution. The visible “signature
appearance” is an image-like test string, not a cryptographic signature.

## Provenance and refresh

Existing artifacts are referenced rather than copied into a second corpus. New
derived artifacts name their generator and source chain. A changed digest must
create a new manifest revision or an explicit refresh record. Existing parity,
OCR, preservation, and template results must never be relabeled as results for
new bytes.

The handwritten fixture is generated by:

```text
bash benchmark/generate_governed_corpus.sh
```

The script records the synthetic fixture README and ground truth beside the
artifact. It does not access the network or any personal document.

## Verification

Run:

```text
node Tests/pdf_corpus_governance_test.mjs
```

The test verifies:

- manifest schema and required governance fields;
- unique IDs and paths;
- artifact existence and SHA-256 digests;
- required class coverage;
- ground-truth sidecar presence;
- encrypted password-policy metadata;
- handwritten abstention-policy metadata;
- qpdf structural validation for every artifact;
- expected non-zero qpdf status for malformed inputs;
- explicit password use for encrypted structural checks;
- machine-readable zero-content governance reporting.

The report is written to [`benchmark/results/governed-corpus/governance-report.json`](../../benchmark/results/governed-corpus/governance-report.json).

This is structural and provenance evidence. It does not establish OCR accuracy,
handwriting recognition, arbitrary editing fidelity, PDF/UA conformance,
signature validity, or independent viewer parity. Those remain active capability
lanes with their own contracts, corpus labels, and validators.
