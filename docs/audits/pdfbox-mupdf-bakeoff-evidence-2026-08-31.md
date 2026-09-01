# PDFBox versus MuPDF Provider Bake-off Evidence

**Date:** 2026-08-31
**Status:** Verified local bake-off; provider adoption remains undecided
**Owner:** `pdf_editor` provider and fidelity lanes
**Evidence artifact:** [`../../benchmark/results/pdfbox-mupdf-bakeoff-2026-08-31/report.json`](../../benchmark/results/pdfbox-mupdf-bakeoff-2026-08-31/report.json)
**Runner:** [`../../benchmark/pdfbox-mupdf-bakeoff.mjs`](../../benchmark/pdfbox-mupdf-bakeoff.mjs)
**Focused test:** [`../../Tests/pdfbox_mupdf_bakeoff_test.mjs`](../../Tests/pdfbox_mupdf_bakeoff_test.mjs)

## Purpose

This experiment compares two optional high-fidelity provider candidates against
the same privacy-governed PDF corpus:

- Apache PDFBox 3.0.8, the permissive Java control lane already used for
  external AcroForm inspection and form-preserving load/save experiments.
- MuPDF 1.28.2, the locally installed native command-line lane used for
  independent rendering, text extraction, rewriting, and form-baking
  capability exploration.

The purpose is not to pick a winner from feature count. It is to measure which
provider can preserve the project’s actual invariants, how each provider fails,
what packaging and licensing obligations it creates, and whether a failed or
interrupted operation can be recovered without exposing a partial output.

The experiment is an implementation and evidence lane for the long-term PDF
capability program. It does not reduce the program’s target surface or turn a
provider’s local availability into a shipping approval.

## Contract and normalization

The runner emits `pdf-editor.provider-bakeoff` version `1.0`. Each fixture case
contains:

- governed fixture identity, source SHA-256, byte count, provenance and privacy
  class;
- qpdf structural check and value-minimized page facts;
- provider identity, version, runtime shape, artifact digest and license state;
- inspection outcome;
- no-op rewrite and reopen outcome;
- normalized text and independent raster comparison;
- supported-operation states and explicit unsupported states;
- malformed-input recovery and staged-output behavior.

The comparison intentionally ignores provider representation noise:

- object IDs;
- xref offsets;
- creation and modification timestamps;
- provider-specific output digests;
- provider-specific field identifiers.

Text comparison uses normalized whitespace and a digest. Raster comparison uses
the same Poppler page-1 PNG oracle for both provider outputs. This is not a
claim that Poppler is the only correct renderer. It is an independent common
oracle; the existing PDF.js, PDFKit and MuPDF independent-viewer lanes remain
separate evidence sources.

No raw page text, OCR values, screenshots, PDF bytes, field values, or fixture
passwords are written into the report. The report records structural facts,
digests, counts, statuses and bounded diagnostics only. The source corpus is
read-only during the run.

## Corpus coverage

The live governance manifest contains 16 entries, and all 16 referenced
artifacts were present and exercised in this run. The report records any absent
manifest entries in `run.skippedManifestFixtures` so a future corpus revision
cannot silently change the denominator.

The exercised set includes:

- public and native AcroForm fixtures;
- navigation and metadata fixtures;
- rotated widget and mixed-content fixtures;
- encrypted reader and encrypted hybrid fixtures;
- malformed and truncated fixtures;
- printed and noisy scans;
- hybrid text/raster/form documents;
- simulated handwritten content;
- a 20-page repeated document and a 40-page large hybrid document.

This corpus is synthetic or locally derived except where the governance
manifest says that acquisition or license status remains unresolved. It is not
real-user or production-distribution evidence.

## Observed results

The recorded full run exercised 16 fixtures.

### PDFBox 3.0.8

- Inspection: 12 `passed`, 2 `unsupported` for encrypted inputs without a
  supplied password, 1 `unknown` malformed input, and 1
  `recovered-with-warning` malformed input.
- No-op rewrite/reopen: 12 `passed`, 2 `unsupported`, 1 `unknown`, and 1
  `recovered-with-warning`.
- Independent Poppler text preservation: 12 `passed`, 3 `unknown`, 1 not
  applicable to a malformed or refused case.
- Independent Poppler raster preservation: 12 `passed`, 3 `unknown`, 1 not
  applicable to a malformed or refused case.
- Recovery probes: 13 `passed` with no qpdf-valid malformed output, and 3
  `passed-with-invalid-staged-artifact`. No qpdf-valid malformed output was
  publishable in this run.
- AcroForm semantics: the public sample retained its inspected field state
  through the no-op reopen path. The existing PDFBox radio/choice result
  remains the control evidence for provider-aware form preservation.

PDFBox’s Java2D raster phase from the older probe was deliberately not used as
the common raster oracle. On this host it exceeded the bounded probe timeout
in an isolated run, while the PDFBox load, field inspection, save and reopen
path completed. That runtime observation is retained by the runner as the
`providerRasterAE: not-run-java2d-phase` marker. It is a packaging/runtime
finding, not evidence that PDFBox’s PDF rendering is generally broken.

### MuPDF 1.28.2

- Inspection: 12 `passed` and 4 `unknown` or unsupported encrypted/malformed
  cases, depending on whether the command could establish a readable document
  without a password.
- No-op rewrite/reopen: 12 `passed`, 3 `unknown`, and 1 `failed` on the
  malformed class.
- Independent Poppler text preservation: 12 `passed`, 1 `unknown`, with the
  remaining refused cases not measured.
- Independent Poppler raster preservation: 12 `passed`, 1 `unknown`, with the
  remaining refused cases not measured.
- Recovery probes: 10 `passed` with no staged artifact, and 6
  `passed-with-invalid-staged-artifact`. No qpdf-valid malformed output was
  publishable in this run.
- The CLI can expose form baking and content sanitization commands, but the
  bake-off does not treat either command as equivalent to typed native-field
  filling or complete redaction. Those remain separate capability contracts
  and validators.
- The CLI lane has no typed existing-text replacement operation. The report
  records this as `unsupported-by-cli-lane`, rather than treating a rewrite or
  form bake as arbitrary semantic editing.

### Cross-provider interpretation

Both providers reached the same normalized no-op text/raster preservation state
on the 12 readable cases where the common oracle was applicable. This supports
the narrower claim that both can perform locally observed no-op rewrites that
reopen and render equivalently under this corpus and oracle.

It does not establish byte preservation, complete annotation/form/XFA/signature
preservation, arbitrary text editing, redaction completeness, PDF/UA
conformance, or parity in an independent GUI viewer.

The first meaningful provider divergence is recovery behavior. PDFBox staged
invalid artifacts on three truncation probes; MuPDF staged invalid artifacts on
six. Both require a caller-side publish protocol that validates a staged output
with qpdf and the appropriate semantic, raster and provider-specific checks
before making it visible as an export. A provider process exiting zero is not a
publish authorization.

## Licensing evidence

### PDFBox

The local fat jar is `benchmark/pdfbox-lane/pdfbox-app-3.0.8.jar`.

- Version observed locally: `3.0.8`.
- SHA-256 observed locally:
  `f6b3a80c39747ff0ef5d06708bc03882152403de58dbef4a1fbffbee568eceb1`.
- SHA-512 observed locally and matched the retained `.sha512` file:
  `768847238f683568507bf73570a2b6fedcbe58b25c7b4f97fba536ba110b290fe96ba065aed58629d41fb94857d76bc1978c2f31d294b553c69f287f71ee9600`.
- License observed: Apache License 2.0.
- The existing artifact review identifies bundled notices and Bouncy Castle
  license/notice review as remaining redistribution work. A permissive primary
  license does not eliminate dependency-notice obligations.
- Packaging observed: fat jar plus Java runtime; no native library was used by
  the provider lane.

Apache’s official download page identifies PDFBox 3.0.8, Apache License 2.0,
SHA-512 distribution checksums and Bouncy Castle’s role in encryption:
[Apache PDFBox download and license information](https://pdfbox.apache.org/download.cgi).

### MuPDF

The local executable is `mutool`, observed at `/opt/homebrew/bin/mutool`.

- Version observed locally: `1.28.2`.
- SHA-256 observed locally:
  `8a1023714e8076a8ffa75e5ed1cf59b54e089e9990b9a9df52682a5c5616d7cd`.
- License observed: AGPL-3.0 or commercial licensing.
- Packaging observed: native executable plus runtime libraries, not a
  self-contained permissive library artifact.
- Commercial licensing decision: open. No commercial license was purchased or
  inferred.

The official MuPDF repository and release page identify the AGPL licensing
surface and commercial-license path:
[Artifex MuPDF repository and license](https://github.com/ArtifexSoftware/mupdf),
[MuPDF releases and licensing](https://mupdf.com/releases).

The official MuPDF.js repository describes the same dual-license boundary for
the JavaScript wrapper and WebAssembly binary:
[MuPDF.js licensing and packaging](https://github.com/ArtifexSoftware/mupdf.js/).

These are source and provenance observations, not legal advice or a completed
distribution review.

## Packaging and recovery gates

### PDFBox package path

The current evidence supports a local helper shape, not a system-Java
requirement. Before distribution, the package must add:

1. a reproducible or at least auditable JVM/runtime packaging recipe;
2. complete Apache, FontBox, Bouncy Castle, Unicode and other bundled notices;
3. helper signing, notarization and update behavior;
4. process timeout, memory and file-handle limits;
5. JSON-only typed IPC with source-digest binding;
6. staged-output validation and cleanup after crash or termination.

### MuPDF package path

The current evidence supports an installed local companion experiment only
behind an explicit licensing decision. Before distribution, the package must
add:

1. a source or binary provenance chain for the exact `mutool` build;
2. native-library packaging and architecture coverage for supported macOS
   targets;
3. AGPL compliance or a completed commercial-license path;
4. signed, notarized installation and update behavior;
5. typed IPC and capability revocation when the license or package is invalid;
6. staged-output validation, crash cleanup and recovery from partial writes.

### Recovery invariant

Both providers are subject to the same canonical output protocol:

```text
immutable source
  -> provider reads source
  -> provider writes an isolated staged output
  -> qpdf structural check
  -> provider-specific reopen
  -> semantic and raster validation
  -> publish a new export only if all required gates pass
```

Failure at any stage leaves the source untouched and must not replace a prior
export. Invalid staged files are diagnostic artifacts only and must not be
presented as user exports.

## Decision and next engineering lanes

This bake-off does not choose a universal provider. It establishes a
capability-negotiated strategy:

- PDFBox is the permissive control lane for AcroForm inspection, form-aware
  operations and companion experiments.
- MuPDF is the high-fidelity rendering/rewrite candidate and a possible broad
  editing provider, subject to AGPL/commercial licensing and separate typed
  operation adapters.
- The shared PDF contracts remain provider-neutral. Provider IDs, output bytes,
  timestamps and object numbering do not enter the semantic contract.
- Existing browser PDF.js/pdf-lib and native PDFKit lanes remain valid
  providers. This experiment does not replace or silently route around them.

Required follow-up evidence:

- implement a typed MuPDF form-field and text-run adapter rather than relying
  on CLI form baking or generic rewrites;
- repeat the bake-off with encrypted fixtures after explicit password-bound
  companion protocol support exists;
- add PDFBox and MuPDF page-operation, annotation, signature, redaction, XFA
  and accessibility case families;
- run independent GUI-viewer and PDFium comparisons;
- measure cold start, memory, throughput, cancellation and crash recovery on
  device-adaptive limits;
- complete package signing, notices, licensing and rollback evidence before
  either provider can be treated as distributable.

## Evidence classification

- **Verified, Tier 3 / S1:** local integration runner completed across 16
  available governed fixtures; both provider lanes and independent Poppler
  checks produced normalized reports.
- **S2/S3 support:** focused test checks provider identity, artifact digest
  matching, no-content reporting, normalized preservation states, and recovery
  outcomes. Deliberate report-digest mutation is visible and the original
  evidence remains unchanged.
- **Not established:** production performance, real-user data, legal approval,
  commercial licensing, notarized packaging, arbitrary PDF fidelity, all-page
  raster equivalence, independent GUI parity, PDF/UA, XFA, digital-signature
  validity, complete redaction, or cloud/hosted behavior.
