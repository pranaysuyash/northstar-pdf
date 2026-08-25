# PDF Output Validation Policy

**Status:** Active release policy
**Scope:** Generated PDF artifacts from native and web providers

## Principle

PDF output validation distinguishes structural warnings that an independent
viewer can recover from semantic failures that can change document meaning.
The distinction is recorded rather than hidden.

## Classification

### Recoverable warning

qpdf may report an object offset of zero while also stating that the operation
succeeded and that the condition is commonly handled by qpdf and most PDF
applications. These artifacts remain warning-bearing evidence. They are not
treated as structurally clean, and they require independent Poppler and MuPDF
reopen evidence before they can be used for bounded development benchmarks.

The current Form 6 PDFKit artifacts fall into this class. A temporary qpdf
rewrite probe repairs the offsets without changing page count, page size, or
rotation, but the application does not silently shell out to qpdf at runtime.
The browser and native no-op paths preserve these source bytes rather than
rewriting hidden structure. Runtime normalization remains a provider
implementation decision.

### Hard failure

Warnings about unreachable AcroForm widgets, syntax errors, stream errors,
failed decryption, incomplete page facts, or any qpdf diagnostic other than
the explicitly classified offset warning remain release failures.

An unreachable widget is a semantic failure because the form field may no
longer be reachable through the document's AcroForm field tree. qpdf rewriting
does not repair that provider-level meaning and must not be presented as an
AcroForm provider.

The native PDFKit provider therefore rejects non-empty edit sessions when the
source bytes contain a document-level `/AcroForm` marker. It still supports
byte-preserving no-op export, and synthetic page-annotation fixtures continue
to exercise the bounded native widget path. This is an explicit read-only
boundary, not a claim of external AcroForm editing support.

## Gate behavior

`benchmark/test_qpdf_outputs.sh` reports the two classes separately. It accepts
only the exact recoverable offset-warning signature and fails for every other
qpdf warning or diagnostic. The independent viewer gate remains separate and
must reopen every valid source and derived artifact through Poppler and MuPDF.

The release rule remains strict: any hard failure keeps unrestricted release
at `NO-GO`, even when all artifacts reopen successfully.

## Evidence

- qpdf version: `12.4.0`
- Independent viewers: Poppler `26.08.0` and MuPDF `1.28.2`
- Current hard-failure examples: malformed output, unknown-password encrypted
  output, and public or synthetic external AcroForm widget reachability after
  PDFKit serialization
- Encrypted contract-parity exports are checked with the fixture password based
  on the source fixture name, not on the generated output's final filename
- Current warning-only examples: Form 6 cross-reference offset diagnostics
