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
the companion. All of these lanes are implementation targets. Final provider
activation and release claims remain evidence-gated, so an abstained capability
is a truthful runtime state rather than a reason to omit its adapter or tests.

This is a full capability program, not a bounded feature subset. Text-run
replacement, OCR-derived layers, paragraph reflow, redaction, sanitization,
repair, conversion, signatures, XFA, accessibility, collaboration, P2P,
AI-assisted workflows, companion providers, hosted/self-hosted modes, batch
processing, and every other reader/editor capability remain build targets.
Sequencing and evidence gates control implementation order and claim strength;
they do not remove capabilities from the program.

## Current working slice

The app now has a usable bounded-completion loop in both surfaces. Native fields
are edited as native fields, including checkbox and radio-group controls. Static
choice suggestions expose reviewed member cells for reversible marks. Text-like
static suggestions can become either reversible overlays or explicitly synthesized
native text fields after review. A user can edit an overlay, undo it, dismiss or
restore a suggestion, or manually place text when the detector is not useful. The
original PDF remains untouched until an explicit export.

This is deliberately a review-first editor while the complete capability
program is being built. The current implementation proves one interaction and
export vertical slice on local fixtures. The remaining fidelity, OCR,
accessibility, signature, XFA, packaging, collaboration, and conversion lanes
are implementation work still to be completed, not permanent exclusions.

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
- [`benchmark/generate_browser_corpus.sh`](benchmark/generate_browser_corpus.sh) and [`docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md`](docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md): six derived scanned, rotated, encrypted, malformed, large, and hybrid fixtures with browser contract, native/browser parity, qpdf, independent-viewer, and preservation evidence.
- [`docs/audits/native-web-contract-parity-evidence-2026-08-24.md`](docs/audits/native-web-contract-parity-evidence-2026-08-24.md): first serialized native/PDFKit versus browser/PDF.js semantic parity baseline, mismatch taxonomy, and provider capability gaps.
- [`web/pdf-contract-parity.mjs`](web/pdf-contract-parity.mjs) and [`Tests/pdf_contract_parity_mutation_test.mjs`](Tests/pdf_contract_parity_mutation_test.mjs): reusable native/web semantic projection and mutation checks that protect source identity, coordinates, field semantics, candidate evidence, operations, and validation state.
- [`web/pdf-fingerprint-parity.mjs`](web/pdf-fingerprint-parity.mjs), [`Tests/fixtures/pdf_fingerprint_parity_fixture.json`](Tests/fixtures/pdf_fingerprint_parity_fixture.json), and [`benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json`](benchmark/results/semantic-parity/2026-08-25/fingerprint-parity-report.json): value-minimized native/browser structural fingerprint parity for page geometry, text shape, fields, candidates, evidence, coordinate spaces, permissions, navigation, security, and accessibility, with feature-level divergence clusters and mutation guards.
- [`docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md`](docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md): current fingerprint evidence, privacy boundary, malformed controls, and the remaining permission, rotation, page-box, text segmentation, and candidate-family divergence clusters.
- [`docs/audits/contract-negative-test-evidence-2026-08-24.md`](docs/audits/contract-negative-test-evidence-2026-08-24.md): negative and mutation-sensitive evidence for source binding, unsupported/destructive operations, validation states, and coordinate integrity.
- [`Tests/web_pdf_contract_mutation_test.mjs`](Tests/web_pdf_contract_mutation_test.mjs): browser-side mutation tests proving unsafe contracts stop before the pdf-lib writer.
- [`docs/template-system-design.md`](docs/template-system-design.md): privacy-first
  recurring-layout templates, keyed fingerprints, reviewed mappings, local
  profile references, revisioning, storage, recovery, and sync boundaries.
- [`docs/audits/encrypted-template-profile-persistence-evidence-2026-08-25.md`](docs/audits/encrypted-template-profile-persistence-evidence-2026-08-25.md),
  [`Sources/PDFEditorCore/EncryptedTemplatePersistence.swift`](Sources/PDFEditorCore/EncryptedTemplatePersistence.swift),
  and [`web/pdf-template-store.mjs`](web/pdf-template-store.mjs): encrypted
  native/browser template revision history, separate profile-vault storage,
  deletion, recovery, eviction handling, and zero-content persistence tests.
- [`docs/audits/local-persistence-privacy-hardening-evidence-2026-08-25.md`](docs/audits/local-persistence-privacy-hardening-evidence-2026-08-25.md): passphrase
  key recovery, explicit encrypted backup import/export, visible native/browser
  privacy preflight, eviction warnings, and value-free deletion audit evidence.
- [`docs/audits/local-persistence-product-surface-evidence-2026-08-25.md`](docs/audits/local-persistence-product-surface-evidence-2026-08-25.md): native and browser
  backup UI, lost-passphrase guidance, quota education, Keychain/profile
  unlock, ciphertext-only worker validation, and portable cross-device recovery.
- [`docs/audits/template-review-workflow-evidence-2026-08-25.md`](docs/audits/template-review-workflow-evidence-2026-08-25.md),
  [`Sources/PDFEditorCore/TemplateRuntimeContracts.swift`](Sources/PDFEditorCore/TemplateRuntimeContracts.swift),
  and [`web/pdf-template-contract.mjs`](web/pdf-template-contract.mjs): native
  and browser reviewed completion workflow with separate mapping approval and
  exact profile-value approval, target/value invalidation, source binding, and
  mutation-tested materialization gates.
- [`docs/audits/native-template-capture-review-surface-evidence-2026-08-25.md`](docs/audits/native-template-capture-review-surface-evidence-2026-08-25.md): native
  SwiftUI capture, immutable revision review, target evidence, typed
  mapping/value approval, and current native build evidence.
- [`docs/audits/template-lifecycle-evidence-2026-08-25.md`](docs/audits/template-lifecycle-evidence-2026-08-25.md),
  [`Sources/PDFEditorCore/TemplateLifecycleContracts.swift`](Sources/PDFEditorCore/TemplateLifecycleContracts.swift),
  [`Sources/PDFEditorCore/TemplateSyncContracts.swift`](Sources/PDFEditorCore/TemplateSyncContracts.swift),
  and [`web/pdf-template-sync.mjs`](web/pdf-template-sync.mjs): complete
  encrypted native/browser template lifecycle with OPFS, IndexedDB, Keychain,
  separate profile unlock, deletion and recovery, value-free transfer,
  revision diffs, learning journals, and client-encrypted sync.
- [`docs/audits/template-runtime-completion-evidence-2026-08-25.md`](docs/audits/template-runtime-completion-evidence-2026-08-25.md),
  [`Sources/PDFEditorCore/TemplateIndexContracts.swift`](Sources/PDFEditorCore/TemplateIndexContracts.swift),
  [`web/template-index.mjs`](web/template-index.mjs), and
  [`web/pdf-capability-lanes.mjs`](web/pdf-capability-lanes.mjs): native/browser
  value-free exact, variant, family, ambiguous, stale, and no-match retrieval,
  encrypted-store recovery controls, learning/revision review visibility, and
  named source-bound lanes for OCR, text editing, redaction, signatures, XFA,
  PDF/UA, and independent-viewer validation.
- [`docs/audits/template-runtime-integration-evidence-2026-08-25.md`](docs/audits/template-runtime-integration-evidence-2026-08-25.md),
  [`Sources/PDFEditorCore/TemplateProfileResolver.swift`](Sources/PDFEditorCore/TemplateProfileResolver.swift),
  [`web/pdf-template-profile-resolver.mjs`](web/pdf-template-profile-resolver.mjs),
  and [`web/pdf-template-migration.mjs`](web/pdf-template-migration.mjs): native/browser
  value-free automatic profile-resolution abstention, immutable revision
  migration review, removed-mapping semantics, and parity tests.
- [`web/template-match-benchmark.mjs`](web/template-match-benchmark.mjs) and
  [`Tests/web_template_match_benchmark_test.mjs`](Tests/web_template_match_benchmark_test.mjs):
  reviewer-labeled 24-case exact, known-variant, family, ambiguous, stale, and
  hard-negative matching benchmark with class-specific calibration and a
  deliberate threshold mutation gate.
- [`Tests/web_template_match_benchmark_browser_test.mjs`](Tests/web_template_match_benchmark_browser_test.mjs):
  live PDF.js fingerprint smoke gate against the public AcroForm and Form 6
  corpus.
- [`docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md`](docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md):
  reviewer-labeled 24-case corpus, class-specific thresholds, scanned-class
  abstention, false-positive gates, mutation evidence, and remaining real-world
  recurring-version requirements.
- [`web/reviewed-completion-metrics.mjs`](web/reviewed-completion-metrics.mjs),
  [`Sources/PDFEditorCore/ReviewedCompletionMetricsContracts.swift`](Sources/PDFEditorCore/ReviewedCompletionMetricsContracts.swift),
  [`Tests/reviewed_completion_metrics_mutation_test.mjs`](Tests/reviewed_completion_metrics_mutation_test.mjs),
  and [`docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md`](docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md):
  versioned reviewed-correction lift, abstention, hard-negative, and
  safe-completion metrics with silent-autofill mutation guards.
- [`benchmark/results/template-matching/2026-08-24-class-calibration.json`](benchmark/results/template-matching/2026-08-24-class-calibration.json):
  value-free machine-readable calibration snapshot checked by the benchmark test.
- [`Tests/template_match_native_browser_parity_test.mjs`](Tests/template_match_native_browser_parity_test.mjs) and
  [`docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md`](docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md):
  native/browser template state, evidence, and abstention parity.
- [`web/pdf-evidence-fusion.mjs`](web/pdf-evidence-fusion.mjs),
  [`Sources/PDFEditorCore/EvidenceFusion.swift`](Sources/PDFEditorCore/EvidenceFusion.swift),
  and [`docs/audits/evidence-fusion-evidence-2026-08-25.md`](docs/audits/evidence-fusion-evidence-2026-08-25.md):
  deterministic multi-signal evidence support, review, conflict abstention,
  and native/browser tests without raw-content logging.
- [`web/provider-companion-host.mjs`](web/provider-companion-host.mjs) and
  [`Tests/provider_companion_host_test.mjs`](Tests/provider_companion_host_test.mjs):
  narrow local companion-host reference runtime with typed session binding,
  source/output limits, cancellation, abstention, and zero-content logs.
  native Swift versus isolated Chrome semantic parity for all 24 reviewed
  template cases, including candidate evidence and abstention agreement.
- [`benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json`](benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json):
  value-free machine report with state, evidence, policy, and abstention parity.
- [`web/template-correction-benchmark.mjs`](web/template-correction-benchmark.mjs),
  [`Tests/web_template_correction_benchmark_test.mjs`](Tests/web_template_correction_benchmark_test.mjs), and
  [`docs/audits/reviewed-template-correction-benefit-evidence-2026-08-24.md`](docs/audits/reviewed-template-correction-benefit-evidence-2026-08-24.md):
  value-free correction-event benefit measurement with immutable promotion,
  rollback, privacy, and hard-negative abstention gates.
- [`benchmark/results/template-matching/2026-08-24-correction-benefit.json`](benchmark/results/template-matching/2026-08-24-correction-benefit.json):
  machine report showing reviewed-target coverage before, after, and after
  rollback.
- [`benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json`](benchmark/results/template-matching/2026-08-24-correction-benefit-browser.json):
  isolated Chrome execution summary for the same correction, rollback, privacy,
  and hard-negative gates.
- [`Tests/pdf_contract_parity_test.mjs`](Tests/pdf_contract_parity_test.mjs):
  native/web serialized contract parity harness that emits both bundles and
  records normalized mismatches without comparing PDF bytes.
- [`web/pdf-contract-parity.mjs`](web/pdf-contract-parity.mjs),
  [`Tests/native_browser_semantic_parity_report_test.mjs`](Tests/native_browser_semantic_parity_report_test.mjs),
  and [`docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md`](docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md):
  fresh native PDFKit versus browser PDF.js/pdf-lib semantic parity report for
  all 18 corpus fixtures, with provider IDs, timestamps, generated IDs, and
  output digests normalized out of equality while retained as provenance
  presence facts.
- [`benchmark/results/semantic-parity/2026-08-25/parity-report.json`](benchmark/results/semantic-parity/2026-08-25/parity-report.json):
  machine report with 18 fixtures, 6 declared mismatches, and 0 unexpected
  mismatches.
- [`web/candidate-parity.mjs`](web/candidate-parity.mjs),
  [`Tests/native_browser_candidate_parity_report_test.mjs`](Tests/native_browser_candidate_parity_report_test.mjs),
  and [`docs/audits/native-browser-candidate-parity-evidence-2026-08-25.md`](docs/audits/native-browser-candidate-parity-evidence-2026-08-25.md):
  native/browser candidate geometry pairing, directional coverage, semantic
  mismatch clusters, value-minimized reporting, and mutation evidence across
  the current corpus.
- [`Tests/fixtures/cross_project_evidence_ledger.json`](Tests/fixtures/cross_project_evidence_ledger.json),
  [`Tests/fixtures/pdf_corpus_semantic_parity_fixture.json`](Tests/fixtures/pdf_corpus_semantic_parity_fixture.json),
  and [`Tests/cross_project_evidence_ledger_parity_test.mjs`](Tests/cross_project_evidence_ledger_parity_test.mjs):
  versioned cross-project evidence inventory and eighteen-case native/browser
  semantic parity gate across the existing PDF corpus.
- [`docs/audits/cross-project-evidence-ledger-parity-evidence-2026-08-24.md`](docs/audits/cross-project-evidence-ledger-parity-evidence-2026-08-24.md)
  and [`benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json`](benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json):
  retained evidence, six ledger entries, 18 source references, six classified
  parity mismatches, and the preserved source-identity drift.
- [`benchmark/compare_ocr_providers.mjs`](benchmark/compare_ocr_providers.mjs),
  [`benchmark/browser_wasm_ocr.mjs`](benchmark/browser_wasm_ocr.mjs),
  [`Tests/ocr_provider_comparison_test.mjs`](Tests/ocr_provider_comparison_test.mjs),
  and [`docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`](docs/audits/ocr-provider-comparison-evidence-2026-08-25.md):
  shared-corpus native Vision, local Tesseract CLI, and browser WASM accuracy,
  latency, normalized bounds/confidence, union-alignment, and zero-content
  privacy measurements; malformed/encrypted/large recovery gates; and explicit
  unmeasured or control-only states for OCRmyPDF, PDFBox, and MuPDF companion
  lanes. The current machine report is
  [`benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json`](benchmark/results/ocr-provider-comparison/2026-08-25-local-wasm-companion.json).
- [`benchmark/independent-preservation-validator.mjs`](benchmark/independent-preservation-validator.mjs):
  Poppler text/raster outside-region comparison plus qpdf structural evidence,
  kept separate from the PDF.js reader; [`Tests/pdf_independent_preservation_test.mjs`](Tests/pdf_independent_preservation_test.mjs)
  adds unauthorized/authorized mutation sensitivity and rotated-fixture reopen
  checks.
- [`benchmark/browser-export-independent-viewer-validator.mjs`](benchmark/browser-export-independent-viewer-validator.mjs),
  [`Tests/browser_export_independent_viewer_validator_test.mjs`](Tests/browser_export_independent_viewer_validator_test.mjs),
  and [`docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md`](docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md):
  versioned Poppler text/raster comparison against the PDF.js browser gate,
  with explicit agreement, divergence, unknown, expected-failure, source
  digest, output reopen, normalized provider-metric, and reviewed-operation
  binding states across the readable browser export corpus. Missing operation
  regions and coordinate mismatches abstain before independent validation.
- [`docs/audits/browser-preservation-metrics-evidence-2026-08-25.md`](docs/audits/browser-preservation-metrics-evidence-2026-08-25.md):
  browser review/export-panel metrics for outside-region text and raster
  checks, including changed pages, changed/compared pixels, ratios, channel
  deltas, tolerances, evidence basis, and value-minimized failure visibility.
- [`docs/cross-project-document-intelligence-exploration.md`](docs/cross-project-document-intelligence-exploration.md): local OCR, parser,
  signature, provenance, validation, corpus, and privacy exploration across
  SignKit, MetaExtract, Invoice Intelligence, PhotoSearch, and related projects.
  Per [D-029](docs/decisions.md#d-029-cross-project-exploration-is-a-full-implementation-mandate),
  every transferable capability is an active PDF Editor build lane; provider
  gates control activation and claims, not whether the lane is built.
- [`docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`](docs/competitor-ihatepdf-cv-exploration-2026-08-24.md): detailed current-source
  exploration of ihatepdf.cv's product surface, browser architecture, privacy
  boundaries, competitive lessons, and proposed corpus experiments.
- [`Tests/fixtures/ihatepdf_experiment_ledger.json`](Tests/fixtures/ihatepdf_experiment_ledger.json): versioned evidence-ledger entries for the six ihatepdf-inspired corpus experiments and their semantic parity cases.
- [`Tests/ihatepdf_experiment_parity_test.mjs`](Tests/ihatepdf_experiment_parity_test.mjs), [`Sources/PDFExperimentParityHarness/main.swift`](Sources/PDFExperimentParityHarness/main.swift), and [`docs/audits/ihatepdf-experiment-ledger-parity-evidence-2026-08-24.md`](docs/audits/ihatepdf-experiment-ledger-parity-evidence-2026-08-24.md): native/browser semantic parity, source-digest binding, and mutation evidence for the six versioned experiment contracts.
- [`docs/full-capability-build-program.md`](docs/full-capability-build-program.md): living native/web capability matrix, first-principles invariants,
  provider rules, evidence gates, build order, exclusions, and completion rule.
- [`docs/moat-asset-registry.md`](docs/moat-asset-registry.md) and
  [`Tests/fixtures/moat_asset_registry.json`](Tests/fixtures/moat_asset_registry.json):
  versioned registry for the compounding assets that make provider replacement
  and long-term native/web parity durable, with zero-content logging rules and
  executable reference validation.
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
- [`docs/provider-capability-system-design.md`](docs/provider-capability-system-design.md)
  and [`docs/audits/provider-capability-system-evidence-2026-08-25.md`](docs/audits/provider-capability-system-evidence-2026-08-25.md): capability-negotiated local provider admission, install/measure/revoke lifecycle, privacy boundary, registry fixture, and native/browser contract evidence.
- [`web/provider-companion-protocol.mjs`](web/provider-companion-protocol.mjs),
  [`Sources/PDFEditorCore/ProviderCompanionProtocol.swift`](Sources/PDFEditorCore/ProviderCompanionProtocol.swift), and the companion protocol evidence section in the provider audit: typed local handshake, source binding, limits, cancellation, and native/browser wire parity.
- [`web/pdf-preflight.mjs`](web/pdf-preflight.mjs),
  [`Sources/PDFEditorCore/PreflightContracts.swift`](Sources/PDFEditorCore/PreflightContracts.swift),
  and [`docs/audits/pdf-preflight-evidence-2026-08-25.md`](docs/audits/pdf-preflight-evidence-2026-08-25.md): value-minimized native/browser privacy preflight reports for metadata presence, embedded-data indicators, network boundaries, possible active content, encryption, source binding, and explicit sanitization limits. The report is observational and never claims that the PDF is clean.
- [`docs/audits/native-browser-privacy-preflight-parity-evidence-2026-08-25.md`](docs/audits/native-browser-privacy-preflight-parity-evidence-2026-08-25.md) and [`benchmark/results/preflight-parity-2026-08-25/privacy-preflight-parity-report.json`](benchmark/results/preflight-parity-2026-08-25/privacy-preflight-parity-report.json): native/browser parity for metadata, attachments, annotations, scripts, revisions, unknown coverage, source binding, non-execution, and read-only sanitization limits.
- [`web/pdf-session-provenance.mjs`](web/pdf-session-provenance.mjs), [`Sources/PDFEditorCore/SessionPrivacyProvenanceContracts.swift`](Sources/PDFEditorCore/SessionPrivacyProvenanceContracts.swift), and [`docs/audits/session-privacy-provenance-evidence-2026-08-25.md`](docs/audits/session-privacy-provenance-evidence-2026-08-25.md): privacy-first provenance for every successfully opened PDF session, including processing locality, OCR use, source retention, export identity, validation, reopen evidence, and zero-content invariants.
- [`benchmark/generate_detector_calibration_fixture.py`](benchmark/generate_detector_calibration_fixture.py), [`web/detector-calibration.mjs`](web/detector-calibration.mjs), and [`Tests/detector_calibration_parity_test.mjs`](Tests/detector_calibration_parity_test.mjs): source-bound labeled hard-negative fixtures and native/browser calibration for vector rectangles, checkbox shapes, underlines, whitespace, and label association.
- [`docs/audits/detector-hard-negative-calibration-evidence-2026-08-25.md`](docs/audits/detector-hard-negative-calibration-evidence-2026-08-25.md): controlled calibration evidence, score floors, abstention gates, provider mismatch correction, and remaining corpus expansion.
- [`web/browser-resource-policy.mjs`](web/browser-resource-policy.mjs), [`Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift`](Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift), [`benchmark/benchmark_browser_resource_policy.mjs`](benchmark/benchmark_browser_resource_policy.mjs), and [`docs/audits/browser-resource-policy-evidence-2026-08-25.md`](docs/audits/browser-resource-policy-evidence-2026-08-25.md): device-adaptive browser limits for high-DPI rendering, OCR, batching, cancellation, and source-digest recovery with zero-content telemetry.
- [`web/text-run-ocr-alignment-benchmark.mjs`](web/text-run-ocr-alignment-benchmark.mjs), [`Sources/PDFTextRunOCRBenchmark/main.swift`](Sources/PDFTextRunOCRBenchmark/main.swift), and [`docs/audits/text-run-ocr-alignment-evidence-2026-08-25.md`](docs/audits/text-run-ocr-alignment-evidence-2026-08-25.md): native PDFKit/Vision and browser PDF.js text-run fingerprints, page-space geometry, OCR alignment, replacement abstention, and first provider-fidelity mismatches across the complete current fixture execution list.
- [`web/simple-text-run-provider.mjs`](web/simple-text-run-provider.mjs) and [`Tests/text_run_simple_provider_test.mjs`](Tests/text_run_simple_provider_test.mjs): the first bounded semantic text-run writer for same-width ASCII literals, with source binding, qpdf/Poppler reopen, and independent outside-region text/raster evidence. It is a controlled provider experiment, not general PDF text-editing proof.
- [`docs/runbooks/release-gates.md`](docs/runbooks/release-gates.md): reproducible
  release gate command sequence and evidence procedure.
- [`docs/fixtures/manifest.md`](docs/fixtures/manifest.md): fixture hashes,
  provenance state, characteristics, and consuming gate IDs.
- [`docs/fixtures/pdf-corpus-governance.md`](docs/fixtures/pdf-corpus-governance.md),
  [`Tests/fixtures/pdf_corpus_governance_manifest.json`](Tests/fixtures/pdf_corpus_governance_manifest.json),
  and [`Tests/pdf_corpus_governance_test.mjs`](Tests/pdf_corpus_governance_test.mjs):
  privacy/provenance governed corpus covering scanned, rotated, malformed,
  encrypted, handwritten-like, mixed-content, native-form, and large documents,
  with digest, qpdf, password-policy, safe-failure, and zero-content logging
  checks.
- [`docs/audits/pdf-corpus-governance-evidence-2026-08-25.md`](docs/audits/pdf-corpus-governance-evidence-2026-08-25.md):
  retained governance result, qpdf safe-failure/password evidence, handwritten
  fixture boundary, and native/web parity result.
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

## Workspace and claim boundary

This workspace is intentionally separate from `/Users/pranay/Projects/fieldcanvas`.
The current request authorizes research, documentation, implementation, and
filesystem verification in this directory. This is an authorization and claim
boundary, not a product capability boundary. Git mutations, production
deployment, external service writes, and legally binding signature claims remain
separate gates, while every PDF capability remains an active long-term
implementation target with typed evidence states.
