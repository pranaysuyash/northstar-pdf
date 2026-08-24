# PDF Editor

Research and provider-evaluation workspace for a local-first PDF reader and editor.

## Current Phase

Implementation is authorized for the long-term local-first PDF platform. The
research and benchmark artifacts remain canonical evidence; native macOS,
browser, and optional companion surfaces are being built behind provider-neutral
contracts while final provider adoption remains evidence-gated.

## Product Problem

Build a PDF reader/editor that can:

- Detect interactive PDF form fields when they already exist.
- Detect likely blank boxes and entry regions in otherwise static PDFs.
- Make filling those regions fast without changing surrounding document text.
- Support ordinary PDF reading and editing workflows.
- Preserve document fidelity, provenance, and the ability to undo or recover.

## Durable Research Artifacts

- [`task_plan.md`](task_plan.md): phase plan and stopping conditions.
- [`findings.md`](findings.md): sourced technical research and open questions.
- [`progress.md`](progress.md): session and verification log.
- [`docs/`](docs/): research maps, comparisons, decisions, and proposed design.

The working product direction is a complete native macOS and web PDF platform.
The browser is the zero-install local core. An explicitly installed companion
is the long-term provider plane for OCR, high-fidelity editing, large-document
work, batch operations, and other capabilities that require native runtime,
filesystem, model, or provider support. The browser core remains useful without
the companion, and final provider adoption remains evidence-gated.

## Current working slice

The app now has a usable bounded-completion loop in both surfaces. Native fields
are edited as native fields. Static suggestions are highlighted on the page and
must be reviewed before becoming reversible text overlays. A user can edit an
overlay, undo it, dismiss or restore a suggestion, or manually place text when
the detector is not useful. The original PDF remains untouched.

This is deliberately a review-first editor, not an automatic form converter.
The current implementation proves the interaction loop on local fixtures; it
does not yet claim arbitrary PDF object fidelity, OCR quality, accessibility
conformance, signature preservation, or production packaging.

Run both local surfaces:

```bash
swift run PDFEditor
python3 -m http.server 4173 --bind 127.0.0.1
open http://127.0.0.1:4173/web/
```

The focused browser workflow check is:

```bash
node Tests/web_editor_workflow_test.mjs
```

Current durable research artifacts:

- [`docs/pdf-engine-comparison.md`](docs/pdf-engine-comparison.md): source-backed
  candidate comparison and platform options.
- [`docs/pdf-feature-frontier.md`](docs/pdf-feature-frontier.md): broad PDF feature
  taxonomy, native/web parity rules, product surfaces, and discovery exit criteria.
- [`docs/native-web-platform-matrix.md`](docs/native-web-platform-matrix.md): shared
  contract, platform adapter, storage, worker, and deployment-shape map.
- [`docs/open-source-landscape.md`](docs/open-source-landscape.md): current
  open-source shortlist, license signals, roles, and provider adoption gates.
- [`docs/shared-contracts.md`](docs/shared-contracts.md): versioned document,
  coordinate, candidate-evidence, edit-operation, and validation contracts for
  native and web adapters.
- [`docs/browser-pdf-proof.md`](docs/browser-pdf-proof.md): browser-only PDF.js +
  pdf-lib proof for inspection, native field fill, reviewed static overlays,
  export, and reopen validation across the existing corpus.
- [`docs/audits/browser-contract-fixture-evidence-2026-08-24.md`](docs/audits/browser-contract-fixture-evidence-2026-08-24.md): emitted shared document, coordinate, candidate, edit-session, and validation bundles from the manifest corpus, including preserved provider failures.
- [`docs/audits/native-web-contract-parity-evidence-2026-08-24.md`](docs/audits/native-web-contract-parity-evidence-2026-08-24.md): first serialized native/PDFKit versus browser/PDF.js semantic parity baseline, mismatch taxonomy, and provider capability gaps.
- [`docs/audits/contract-negative-test-evidence-2026-08-24.md`](docs/audits/contract-negative-test-evidence-2026-08-24.md): negative and mutation-sensitive evidence for source binding, unsupported/destructive operations, validation states, and coordinate integrity.
- [`Tests/web_pdf_contract_mutation_test.mjs`](Tests/web_pdf_contract_mutation_test.mjs): browser-side mutation tests proving unsafe contracts stop before the pdf-lib writer.
- [`docs/template-system-design.md`](docs/template-system-design.md): privacy-first
  recurring-layout templates, keyed fingerprints, reviewed mappings, local
  profile references, revisioning, storage, recovery, and sync boundaries.
- [`web/template-match-benchmark.mjs`](web/template-match-benchmark.mjs) and
  [`Tests/web_template_match_benchmark_test.mjs`](Tests/web_template_match_benchmark_test.mjs):
  reviewed exact, known-variant, family, ambiguous, stale, and hard-negative
  matching benchmark with a deliberate threshold mutation gate.
- [`Tests/web_template_match_benchmark_browser_test.mjs`](Tests/web_template_match_benchmark_browser_test.mjs):
  live PDF.js fingerprint smoke gate against the public AcroForm and Form 6
  corpus.
- [`Tests/pdf_contract_parity_test.mjs`](Tests/pdf_contract_parity_test.mjs):
  native/web serialized contract parity harness that emits both bundles and
  records normalized mismatches without comparing PDF bytes.
- [`benchmark/independent-preservation-validator.mjs`](benchmark/independent-preservation-validator.mjs):
  Poppler text/raster outside-region comparison plus qpdf structural evidence,
  kept separate from the PDF.js reader; [`Tests/pdf_independent_preservation_test.mjs`](Tests/pdf_independent_preservation_test.mjs)
  adds unauthorized/authorized mutation sensitivity and rotated-fixture reopen
  checks.
- [`docs/cross-project-document-intelligence-exploration.md`](docs/cross-project-document-intelligence-exploration.md): local OCR, parser,
  signature, provenance, validation, corpus, and privacy exploration across
  SignKit, MetaExtract, Invoice Intelligence, PhotoSearch, and related projects.
- [`docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`](docs/competitor-ihatepdf-cv-exploration-2026-08-24.md): detailed current-source
  exploration of ihatepdf.cv's product surface, browser architecture, privacy
  boundaries, competitive lessons, and proposed corpus experiments.
- [`docs/full-capability-build-program.md`](docs/full-capability-build-program.md): living native/web capability matrix, first-principles invariants,
  provider rules, evidence gates, build order, exclusions, and completion rule.
- [`docs/web-deployment-decision.md`](docs/web-deployment-decision.md): accepted
  long-term browser-core and optional local-companion architecture, OCR and
  high-fidelity provider placement, license/runtime implications, falsifiers,
  and gates.
- [`docs/audits/exploration-closure-evidence-2026-08-24.md`](docs/audits/exploration-closure-evidence-2026-08-24.md): dated closure record for the original research-only boundary, exact browser decision point, and later bounded-proof supersession.
- [`docs/audits/grouped-regions-and-direct-editing-exploration-2026-08-24.md`](docs/audits/grouped-regions-and-direct-editing-exploration-2026-08-24.md): group-first static-region semantics, direct-on-page editing, PDF/CV capability boundaries, and falsifiable follow-up experiments.
- [`docs/proposed-architecture.md`](docs/proposed-architecture.md): long-term
  product architecture, document model, mutation safety boundary, and
  validation gates.
- [`docs/form6-benchmark.md`](docs/form6-benchmark.md): structural fingerprint and
  reviewed logical target inventory for the attached Form 6 fixture.
- [`docs/autoresearch-adaptation.md`](docs/autoresearch-adaptation.md): proposed
  fixed-corpus, safety-gated experiment protocol.
- [`docs/platform-options.md`](docs/platform-options.md): native-first platform
  options and the remaining engine decision.
- [`docs/market-strategy.md`](docs/market-strategy.md): proposed market segments,
  sizing assumptions, product wedge, pricing hypotheses, and falsifiers.
- [`docs/decisions.md`](docs/decisions.md): canonical decision records, approvals,
  alternatives, risks, and revisit triggers.
- [`docs/pdfkit-benchmark.md`](docs/pdfkit-benchmark.md): benchmark claims, oracles,
  runtime results, failure history, and residual risk.
- [`docs/pdfkit-widget-benchmark.md`](docs/pdfkit-widget-benchmark.md): synthetic
  widget and public external-AcroForm results, including the current PDFKit failure.
- [`docs/implementation-status.md`](docs/implementation-status.md): implemented
  native vertical slice, verification evidence, and remaining release gates.
- [`docs/release-gates.md`](docs/release-gates.md): canonical release gate registry,
  completion oracles, current disposition, and evidence links.
- [`docs/capability-matrix.md`](docs/capability-matrix.md): native/web/provider/OCR/
  validator capability boundary and product claim policy.
- [`docs/runbooks/release-gates.md`](docs/runbooks/release-gates.md): reproducible
  release gate command sequence and evidence procedure.
- [`docs/fixtures/manifest.md`](docs/fixtures/manifest.md): fixture hashes,
  provenance state, characteristics, and consuming gate IDs.
- [`docs/dependencies/manifest.md`](docs/dependencies/manifest.md): vendored runtime
  versions, source URLs, hashes, licenses, and upgrade-policy boundary.
- [`docs/runbooks/pdfkit-benchmark.md`](docs/runbooks/pdfkit-benchmark.md): repeatable
  benchmark procedure and recovery branches.
- [`docs/runbooks/pdfkit-widget-benchmark.md`](docs/runbooks/pdfkit-widget-benchmark.md):
  repeatable widget/AcroForm procedures and failure handling.
- [`benchmark/PDFKitBenchmark.swift`](benchmark/PDFKitBenchmark.swift): headless
  PDFKit evaluation harness, not product code.
- [`benchmark/PDFKitWidgetBenchmark.swift`](benchmark/PDFKitWidgetBenchmark.swift):
  native text, button, choice, and signature widget fixture harness.
- [`benchmark/test_pdfkit_widget_benchmark.sh`](benchmark/test_pdfkit_widget_benchmark.sh):
  repeatable native-widget benchmark command.
- [`benchmark/results/2026-08-23-pdfkit-form6/result.json`](benchmark/results/2026-08-23-pdfkit-form6/result.json):
  preserved machine-readable result and adjacent output artifacts.
- [`benchmark/results/2026-08-23-public-acroform/result.json`](benchmark/results/2026-08-23-public-acroform/result.json):
  preserved external-AcroForm failure result.
- [`Package.swift`](Package.swift): macOS 15 Swift Package with core library,
  native executable, and tests.
- [`Sources/PDFEditorCore/`](Sources/PDFEditorCore/): provider-neutral contracts,
  PDFKit adapter, conservative static detector, and Vision OCR adapter.
- [`Sources/PDFEditorApp/`](Sources/PDFEditorApp/): native SwiftUI/AppKit shell.
- [`Tests/PDFEditorCoreTests/`](Tests/PDFEditorCoreTests/): unit, round-trip,
  safety-limit, real Form 6, and preserved public AcroForm regression tests.

## Scope Boundary

This workspace is intentionally separate from `/Users/pranay/Projects/fieldcanvas`.
The current request authorizes research, documentation, implementation, and
filesystem verification in this directory. Git mutations, production deployment,
external service writes, and legally binding signature claims remain separate
gates. Final PDF provider adoption also remains evidence-gated.
