# PDF Editor Discovery Progress

## 2026-08-23

- Confirmed the active workspace is `/Users/pranay/Projects/fieldcanvas` but the
  requested PDF project belongs at `/Users/pranay/Projects/pdf_editor`.
- Inspected the global and Projects execution instructions before mutation.
- Created `/Users/pranay/Projects/pdf_editor` as a research-only workspace.
- Preserved the pre-existing hidden `.freebuff/project-id` file without changes.
- Added the initial README and persistent discovery planning files.
- No application code, dependencies, Git state, or runtime were changed.
- Completed a primary-source capability map for PDF.js, PDFBox, qpdf, pdf-lib,
  MuPDF, Poppler, PoDoFo, and pikepdf.
- Added the candidate comparison and proposed architecture under `docs/`.
- Recorded the main remaining unknowns: platform, license/distribution, runtime
  fidelity, OCR, and real-corpus validation.

## Verification Notes

- Initial workspace evidence tier: Tier 1, filesystem and instruction inspection.
- Research artifact evidence tier: Tier 1, static source inspection.
- Test sensitivity: S0; no implementation behavior exists to test yet.
- No implementation behavior has been tested; test sensitivity remains S0 because
  no application test exists.
- The platform is not confirmed in this conversation; native macOS, browser/local
  web, and shared-core options remain the user review gate. Exact provider,
  distribution model, and engine acceptance are also unresolved.

## 2026-08-23 Continued Discovery

- Inspected `/Users/pranay/Desktop/RAr0Lq2Avu.pdf` without modifying it.
- Verified the fixture is a two-page, text-extractable, unencrypted static PDF with
  no AcroForm fields, no JavaScript, and one embedded JPEG logo.
- Recorded the fixture SHA-256 and a 33-group semantic target inventory in
  [`docs/form6-benchmark.md`](docs/form6-benchmark.md).
- Added the upstream/local autoresearch adaptation protocol with immutable inputs,
  safety gates, reviewed ground truth, and keep/discard run records.
- Added native macOS PDFKit evidence and documented native, browser, and
  shared-core platform options without selecting a final platform or engine.
- Updated the comparison, proposed architecture, findings, plan, and README.

## 2026-08-23 OCR Follow-up

- Reviewed official documentation and license files for Apple Vision text
  recognition, Tesseract 5.x, PaddleOCR, and Docling.
- Recorded OCR as a fallback evidence adapter rather than a field-truth source in
  F-014 and the proposed architecture.
- Confirmed that Form 6 is text-extractable, so its first benchmark lane does not
  require OCR. A separate scanned-document lane is still needed before selecting
  an OCR provider.
- No OCR runtime, model package, dependency, or benchmark was installed or run.
- Re-ran `agent-start --project pdf_editor --skip-index` after the documentation
  update. The doctrine family passed integrity checks; project retrieval remained
  skipped because its store was busy, and workspace pre-commit hook installation
  still reported a warning. Generated context was refreshed with provenance.

## Continued Verification Notes

- Form 6 evidence tier: Tier 1 static inspection; test sensitivity S0.
- Metadata tools used: `pdfinfo`, `pdffonts`, `pdftotext -layout`, `pdfimages -list`.
- `qpdf` is not installed in the current environment, so qpdf validation remains
  an unrun future check.
- No product application code, dependencies, Git state, or source PDF bytes were
  changed; the bounded benchmark harness and its test artifacts were added under
  this research workspace.

## 2026-08-23 PDFKit Benchmark

- Recorded D-001 through D-004 in [`docs/decisions.md`](docs/decisions.md), including
  the user approval interpretation, selected defaults, alternatives, rollback path,
  and revisit triggers.
- Added the test-first harness at
  [`benchmark/PDFKitBenchmark.swift`](benchmark/PDFKitBenchmark.swift), its red/green
  shell test, the protocol, and the repeatable runbook.
- RED evidence: the shell test failed because the harness source was initially
  absent. Compile diagnostics and a runtime rectangle-equality failure were fixed;
  the exact history is preserved in [`docs/pdfkit-benchmark.md`](docs/pdfkit-benchmark.md).
- GREEN evidence: `bash benchmark/test_pdfkit_benchmark.sh` passed with Tier 2/S1
  evidence. The durable JSON and PDF/PNG artifacts are under
  `benchmark/results/2026-08-23-pdfkit-form6/`.
- PDFKit observed two pages, zero native widgets, successful no-op reopen, exact
  provider-local original/no-op render equality, one reopened bounded annotation,
  unchanged provider text, and unchanged source digest.
- Independent Poppler observed matching original/no-op text, expected annotation
  text in the overlay extraction, page 1 absolute error `0`, and page 2 absolute
  error `85` at 144 DPI. This remains a cross-renderer fidelity risk.

## Current Handoff

- **Established:** Candidate capabilities and major license constraints are
  mapped well enough to compare compositions.
- **Proposed:** A provider-neutral document/edit contract, custom detection
  pipeline, immutable source bytes, append-only edit operations, and export
  validation. Native-first with a secondary browser surface is the accepted
  working direction; final provider adoption remains open.
- **Unknown:** Runtime fidelity, detection quality, OCR quality, exact packaging,
  and legal clearance.
- **Next safe action:** Expand the provider corpus with native text/checkbox/radio/
  choice/signature-widget fixtures, rotated pages, malformed/encrypted inputs, and
  independent viewer checks. Do not select a final provider or build the product UI
  until those gates are evaluated.

## Final Verification Pass 2026-08-23

- Re-ran `/Users/pranay/Projects/agent-start/bin/agent-start --project pdf_editor
  --skip-index`; doctrine generation passed with the collection bootstrap skipped
  on timeout and the existing workspace pre-commit-hook warning preserved.
- Re-ran the durable command:
  `PDF_EDITOR_BENCHMARK_OUTPUT_DIR=benchmark/results/2026-08-23-pdfkit-form6 bash
  benchmark/test_pdfkit_benchmark.sh`; exit status `0`.
- `jq` assertions passed for provider, page count, zero widgets, reopen flags,
  unchanged output, and the recorded input digest.
- `shasum -a 256` matched the fixture digest. Poppler text comparison for source vs
  no-op produced no differences. Poppler raster comparison produced AE `0` on page
  1 and AE `85` (`4.12378e-05`) on page 2. Overlay extraction showed the expected
  `PDFKit benchmark` annotation contents.
- `bash -n benchmark/test_pdfkit_benchmark.sh` passed. The project directory is not
  a Git repository, so Git status/diff checks are not applicable; no Git command was
  used to mutate state.

## 2026-08-23 Widget and AcroForm Evaluation

- Added the test-first synthetic widget lane. RED was the missing
  `PDFKitWidgetBenchmark.swift` source; after correcting Swift 6.2.4 PDFKit enum
  names and simplifying a slow type-checking expression, the lane passed.
- Synthetic result: six PDFKit-created widget annotations (`/Tx`, `/Btn`, `/Ch`,
  `/Sig`), successful reopen, and successful text, checkbox, radio, choice, and
  signature-field checks. Poppler reports `Form: none` for the generated input, so
  it is only a PDFKit object-model smoke test, not external AcroForm evidence.
- Added the public sample from `https://pdftoolskit.org/samples/sample-form.pdf`
  with recorded SHA-256 `5a681d44622f2ee577808e77f034525314d48a628b9cad26f7788564c9e922e8`.
- Public AcroForm result: PDFKit reopened six widgets and preserved text mutation,
  source digest, and text extraction, but dropped the `choices` array from both
  `applicant.contact` radio widgets on no-op save. The PDFKit raster comparison also
  differed by AE `166` (`8.27664e-05` normalized). The benchmark correctly exited
  nonzero and preserved the failed JSON result.
- The public failure is now F-016 and a D-002 amendment. Final provider selection
  remains open; the next provider lane must reproduce the same external AcroForm
  contract before comparison.
- The user confirmed `/Users/pranay/Desktop/RAr0Lq2Avu.pdf` as the real-document
  target. It is the already-benchmarked Form 6 fixture; no other Desktop or workspace
  PDFs were processed.

## 2026-08-24 Market Strategy Synthesis

- Added [`docs/market-strategy.md`](docs/market-strategy.md) as a proposed,
  source-backed commercial strategy artifact.
- Added official Census 2022 nonemployer data as a transparent establishment
  proxy: 29,811,495 total U.S. nonemployer establishments and 13,876,756 across
  selected finance, real-estate, professional, administrative, education, and
  healthcare sectors.
- Kept the resulting revenue range explicitly assumption-based rather than
  presenting it as PDF-editor TAM.
- Recorded Adobe pricing and historical Document Cloud metrics, government
  accessibility evidence, and Google/Azure document-processing cost anchors.
- Preserved the existing product boundary and provider uncertainty: PDFKit's
  public AcroForm radio-choice failure and cross-renderer raster delta remain
  release-blocking evidence for final provider selection.

## 2026-08-24 Native and Commercial Source Follow-up

- Completed targeted primary-source follow-up for PDFBox, PDFium, MuPDF, Poppler,
  PoDoFo, Nutrient, and Apryse.
- Added F-017 through F-022 to [`findings.md`](findings.md), covering current release
  signals, public API boundaries, license/distribution implications, and the
  distinction between open-source candidates and commercial control cases.
- Updated [`docs/pdf-engine-comparison.md`](docs/pdf-engine-comparison.md) with
  PDFium and commercial rows, maintenance/version signals, and the unchanged
  recommendation.
- Appended the evidence update to [`docs/decisions.md`](docs/decisions.md). No final
  provider was selected.
- No application code, dependencies, runtime, Git state, or source PDFs were changed.
- Re-ran `agent-start --project pdf_editor --skip-index`; doctrine integrity passed,
  project indexing remained skipped after a timeout, and the existing workspace
  pre-commit/Git-guard installation warnings were preserved.

## Current Handoff After Source Follow-up

- **Established:** Candidate capability, current-source, and major distribution
  signals are mapped well enough to compare compositions and define the next corpus.
- **Proposed:** Native macOS first with a secondary browser surface; PDFKit remains a
  benchmark candidate, not an accepted provider. PDFBox is the permissive JVM control
  lane; PDFium is a low-level native lane; commercial SDKs are optional controls.
- **Unknown:** Cross-provider save fidelity, static detection quality, OCR quality,
  exact package/license obligations, signature preservation, and provider behavior on
  malformed, encrypted, signed, and hybrid documents.
- **Next safe action:** Build or run the next provider lane only after selecting the
  first comparison provider and corpus fixtures. Preserve the current PDFKit radio
  choice failure as a hard gate.

## 2026-08-24 Implementation Scope Reconciled

- Re-ran `agent-start --project pdf_editor --skip-index`; doctrine integrity passed.
  Project collection bootstrap timed out, and the existing workspace hook warning
  remained visible.
- Reconciled the stale discovery-only language in `README.md`, `task_plan.md`, and
  `docs/proposed-architecture.md` with D-001 and the user's explicit implementation
  authorization.
- Recorded D-006: implement a native macOS vertical slice behind provider-neutral
  contracts while preserving the unresolved provider, license, security, and
  independent-viewer gates.
- Confirmed the environment has Xcode 26.3, Swift 6.2.4, and `pdfinfo`; `qpdf`
  remains unavailable.
- No Git mutations, production deployment, external service writes, or legally
  binding signature claims were made.

## 2026-08-24 Native Vertical Slice

- Added `Package.swift` targeting macOS 15 with `PDFEditorCore`, `PDFEditorApp`,
  and `PDFEditorCoreTests` targets.
- Added provider-neutral contracts for immutable sources, page snapshots, native
  fields, uncertain static candidates, append-only edit operations, exports, and
  validation reports.
- Added the PDFKit adapter with input-size/page-count limits, native widget
  inspection, bounded native-field and FreeText edits, temporary-file export,
  reopen checks, field-choice preservation checks, text/geometry checks, source
  digest verification, and explicit failed reports.
- Added a native SwiftUI/AppKit shell with file import, PDFView rendering, page
  navigation, field review/editing, tentative-candidate review, overlays, undo,
  export, validation status, settings, and keyboard commands.
- Added a conservative text-only static detector and a local Apple Vision OCR
  adapter. OCR output remains normalized evidence and cannot directly create fields.
- Added malformed-input and input-size safety tests.
- `swift test` passed with 7 tests; configured real-fixture tests passed for Form 6
  and the expected public AcroForm choice-loss report.
- `swift build -c release` passed. Existing Form 6 and synthetic widget benchmark
  scripts passed; the public AcroForm benchmark continued to exit nonzero with the
  known radio-choice regression.
- Added [`docs/implementation-status.md`](docs/implementation-status.md) and the
  local preview runbook. Remaining provider, corpus, independent-viewer, security,
  packaging, and legal gates remain explicitly open.

## 2026-08-24 Cross-Platform PDF Feature Frontier

- Reconciled the existing `/Users/pranay/Projects/pdf_editor` workspace before
  extending it. It already contained native macOS code, provider benchmarks, and
  research artifacts; no duplicate project was created and no prior artifacts were
  overwritten.
- Added [`docs/pdf-feature-frontier.md`](docs/pdf-feature-frontier.md), covering
  reading, native forms, static blank-region assistance, bounded editing,
  annotations, redaction, signatures, page operations, OCR, extraction, storage,
  accessibility, and discovery exit criteria for both native and web surfaces.
- Added [`docs/native-web-platform-matrix.md`](docs/native-web-platform-matrix.md),
  separating shared contracts from platform adapters and comparing local-first,
  companion-backed, and hosted deployment shapes.
- Added [`docs/open-source-landscape.md`](docs/open-source-landscape.md), comparing
  PDF.js, pdf-lib, PDFBox, qpdf, pikepdf, MuPDF/MuPDF.js, Poppler, PoDoFo,
  OCRmyPDF, Tesseract, and Stirling PDF as implementation candidates or references.
- Appended the cross-platform decision record to
  [`docs/decisions.md`](docs/decisions.md): shared provider-neutral operations and
  coordinates, PDF.js plus pdf-lib as the first web composition, PDFKit retained for
  the native macOS lane, and MuPDF/PDFBox kept behind license and corpus gates.
- Current recommendation: build the first web slice only after reviewing the shared
  contract, starting with a PDF.js reader and a browser-only bounded overlay/form
  experiment. Keep arbitrary text reflow, permanent redaction, cryptographic
  signatures, and silent static-field conversion out of the initial promise.
- Evidence: Tier 1 current-source research and project-local static inspection.
  No new application code, dependency, runtime, external service, or Git mutation
  was performed during this exploration pass. Existing native runtime evidence and
  the known PDFKit external-radio-choice failure remain unchanged.

## 2026-08-24 Shared Native/Web Contracts

- Added [`Sources/PDFEditorCore/SharedContracts.swift`](Sources/PDFEditorCore/SharedContracts.swift)
  with `PDFContractVersion`, `PDFContractHeader`, generic contract envelopes,
  provider provenance, page-space coordinate regions, structured candidate
  evidence, review decisions, typed edit payloads, validation checks, and the
  edit-session contract.
- Extended [`Sources/PDFEditorCore/DocumentModel.swift`](Sources/PDFEditorCore/DocumentModel.swift)
  additively. Existing `RegionCandidate`, `EditOperation`, and
  `ValidationReport` compatibility fields remain available for the current
  PDFKit adapter and native UI, while new structured evidence, source binding,
  payload, lineage, and validation fields are now serializable.
- Updated the PDFKit adapter to reject and report unsupported future operation
  kinds rather than interpreting them as text overlays.
- Added [`docs/shared-contracts.md`](docs/shared-contracts.md) with the JSON
  envelope, compatibility policy, invariants, native/web mapping, and migration
  rules.
- Added three focused contract tests: versioned document round-trip and
  negotiation, backward decoding of older candidate data, and edit-session plus
  validation-report structured payload round-trip.
- `swift test` passed 11 tests. The test build initially waited for another
  SwiftPM release build holding `.build`; the lock was preserved and the test
  completed after that process progressed. No Git mutation or external write was
  performed.

## 2026-08-24 Privacy-First Template System Design

- Added [`docs/template-system-design.md`](docs/template-system-design.md), a
  native/web design for recurring PDF layouts that separates exact source
  identity, keyed local layout fingerprints, reviewed mappings, local profile
  references, completion sessions, and immutable template revisions.
- Defined the privacy boundary: templates do not contain raw PDFs, raw labels,
  screenshots, or profile values by default. Browser persistence is opt-in,
  local sync is not part of the core, and future sync requires client-side
  encryption and key-recovery design.
- Defined match states for exact, known variant, family, ambiguous, stale,
  unsupported, and no-match cases. Ambiguous or stale mappings abstain rather
  than silently applying values.
- Appended decision D-008 to [`docs/decisions.md`](docs/decisions.md) and
  reconciled the feature frontier, native/web matrix, README, and task plan.
- Evidence tier: Tier 1 design/static inspection. The existing browser proof is
  the lower-layer Tier 3/4 evidence for source binding, candidate evidence,
  reviewed operations, export, reopen, and validation. Template runtime and
  privacy storage behavior remain unimplemented and unverified.

## 2026-08-24 Exploration Closure Evidence Addendum

- Added [`docs/audits/exploration-closure-evidence-2026-08-24.md`](docs/audits/exploration-closure-evidence-2026-08-24.md)
  so the research-only close has its own dated evidence record instead of being
  inferred from several feature documents.
- Recorded the historical boundary explicitly: the native slice existed, the
  web surface was paused pending shared-contract review, and the exact open
  platform decision was browser-only first release versus an explicitly
  installed local companion for OCR/high-fidelity editing.
- Recorded the later supersession chain: shared contracts, bounded browser
  PDF.js/pdf-lib proof, and recurring-template design are later phases. They do
  not claim full web/native parity or settle the companion decision.
- Updated [`README.md`](README.md) and [`task_plan.md`](task_plan.md) to link the
  closure record and keep the next decision point visible.
- Verification: web source contract test passed 28 checks; no Git mutation,
  service start, external write, or native runtime change was performed for this
  documentation repair.

## 2026-08-24 Browser Shared-Contract Fixture

- Added a fixture snapshot boundary to `web/index.html` at
  `window.__pdfEditorContractFixture.snapshot()`. It reuses the existing
  PDF.js inspection, page-space coordinate conversion, candidate evidence,
  review, operation, and validation state without exposing source PDF bytes.
- Added `Tests/web_pdf_contract_fixture_test.mjs`, which reads all four PDF
  paths from `docs/fixtures/manifest.md`, drives the browser reader in isolated
  Chrome, emits JSON bundles, and asserts document identity, coordinate
  conventions, candidate evidence, operation source binding, edit-session
  lineage, and validation outcomes.
- Browser fixture evidence: two successful bounded flows reported
  `validatedWithWarnings`; two AcroForm-derived fixtures preserved explicit
  pdf-lib field-resolution failures. The failure outcomes remain part of the
  emitted validation contracts.
- Added [`docs/audits/browser-contract-fixture-evidence-2026-08-24.md`](docs/audits/browser-contract-fixture-evidence-2026-08-24.md).
- Verification: web source contract test passed 32 checks; fixture source and
  browser module syntax checks passed; the manifest corpus fixture runner passed
  with the two documented provider failures represented as valid failed reports.
- The fixture does not close native/web parity or PDF fidelity gates. The next
  implementation is a canonical native JSON fixture and normalized parity
  comparison.

## 2026-08-24 Shared Contract Negative and Mutation Tests

- Added `Tests/PDFEditorCoreTests/ContractMutationTests.swift` with negative
  coverage for stale source digests, unsupported operation kinds, destructive
  edits, unknown and future validation states, coordinate page mismatches, and
  coordinate bounds mismatches.
- Hardened `PDFKitProvider` so export rejects stale non-nil source digests before
  applying operations, while direct `apply` rejects destructive and malformed
  coordinate shapes. Unsupported diagnostics now include the operation kind.
- All rejected exports preserve a destination sentinel and leave no staged
  `.pdf-editor-*` artifact.
- Verification: the focused suite passed 6 tests; the full native suite passed
  23 tests in 3 suites. A deliberate source-binding bypass caused the stale
  digest test to fail and overwrite the sentinel, then the guard was restored
  and the full suite passed again. This is S3 mutation evidence for source
  binding; the other negatives are currently S1.
- Added [`docs/audits/contract-negative-test-evidence-2026-08-24.md`](docs/audits/contract-negative-test-evidence-2026-08-24.md).

## 2026-08-24 Persona Audit & First-Principles Implementation Pass

- Adopted **Persona `PER-0001 — REFACTOR DECISION ARCHITECT`** from `desktop/personas_23rdaug26.zip` (`01 Expanded Personas/01 Engineering & Architecture/PER-0001 - Refactor Decision Architect.docx`).
- Conducted full architectural, evidence, contract, and resilience audit of `/Users/pranay/Projects/pdf_editor` and documented findings in [`docs/audits/repository-audit-per-0001-refactor-decision-architect.md`](docs/audits/repository-audit-per-0001-refactor-decision-architect.md).
- Inventoried all implicit/explicit findings (F-000 to F-022, F-IMP-01 to F-IMP-04) and tasks (T-P1 to T-P8, T-IMP-01 to T-IMP-06) and evaluated each against 1st principles, long-term viability, and Operating Doctrine 8.0/6.1 in [`docs/audits/comprehensive-findings-tasks-and-first-principles-audit.md`](docs/audits/comprehensive-findings-tasks-and-first-principles-audit.md).
- Implemented pure Swift `PDFVectorStreamParser` using `CGPDFScanner` to capture exact vector boxes, checkboxes, and underlines directly from PDF graphic state operators (`re`, `m`, `l`, `cm`, `q`, `Q`, `S`, `f`, `B`).
- Upgraded `StaticRegionDetector` with spatial proximity matching between text labels and neighboring vector boxes.
- Integrated Apple Vision OCR page rendering and coordinate transformation into `OCR.swift`.
- Optimized `AppModel` undo state replay with in-memory source caching ($O(1)$ disk I/O) and added Guided Next-Blank navigation and OCR page triggers in `ContentView.swift`.
- Hardened `web/index.html` with an air-gapped Content Security Policy (`default-src 'self' 'unsafe-inline' blob: data:;`).
- Verified all 16 automated Swift tests in 2 suites (`swift test`), 28 Node.js contract checks (`node Tests/web_reader_contract_test.mjs`), and release compilation (`swift build -c release`). All checks passed with zero errors.

## 2026-08-24 Web Deployment Decision Exploration

- Completed a focused current-source exploration of the remaining deployment
  decision: browser-only first web release versus an explicitly installed local
  companion for OCR and high-fidelity editing.
- Added [`docs/web-deployment-decision.md`](docs/web-deployment-decision.md) as
  the detailed canonical analysis and appended D-009 to
  [`docs/decisions.md`](docs/decisions.md). The recommendation is proposed, not
  owner-approved: browser-only first for the bounded reader/completion/export
  promise, with a separate optional companion lane for OCR, batch, large-file,
  and high-fidelity provider work.
- Recorded F-023 through F-028 in [`findings.md`](findings.md), covering browser
  storage permissions and quotas, Tesseract.js PDF/OCR boundaries, PDFBox,
  MuPDF.js licensing, OCRmyPDF dependencies/security, and native-messaging
  installation/lifecycle.
- Added RG-090 to [`docs/release-gates.md`](docs/release-gates.md). The gate is
  open until the product owner accepts the deployment shape and records the
  supported capability boundary.
- Reconciled the README, native/web platform matrix, and task plan so the
  companion is not inferred from the existing native app or browser proof.
- Evidence status: current-source research is Tier 1; local project evidence is
  linked but not upgraded by this pass. No OCR benchmark, companion package,
  installer, legal review, user research, dependency addition, or runtime
  change was performed.
- Exact next decision: accept the browser-only first web recommendation, approve
  an optional companion beta, or require the companion for first web release.

## 2026-08-24 Consolidated Exploration Record

- Confirmed that the substance of the earlier exploration report existed across
  several canonical documents, but that the complete pass was not retrievable
  from one record.
- Added a consolidated exploration-pass section to
  [`docs/audits/exploration-closure-evidence-2026-08-24.md`](docs/audits/exploration-closure-evidence-2026-08-24.md).
  It records the established workspace state, feature frontier, shared/native/
  web/companion architecture, provider roles, product boundary, implementation
  evidence, non-goals, and verification outcome in one place.
- Kept detailed ownership with the existing canonical sources rather than
  creating a duplicate feature matrix, provider landscape, or deployment ADR.
- Evidence status remains unchanged: contract and bounded workflow evidence is
  verified; full PDF fidelity, OCR accuracy, native/web parity, independent
  viewer preservation, and companion readiness remain open.

## 2026-08-24 Cross-Project Document Intelligence Exploration

- Inspected the current local evidence surfaces in SignKit, MetaExtract, Invoice
  Intelligence, PhotoSearch, extracted_forms, and the historical web signature
  detector project. Adjacent repositories were read only; no source, fixture,
  dependency, database, generated artifact, or Git state was changed.
- Added [`docs/cross-project-document-intelligence-exploration.md`](docs/cross-project-document-intelligence-exploration.md), which records the
  source inventory, transferable primitives, ownership boundaries, moat
  hypothesis, exploration roadmap, falsifiers, and source register.
- Recorded F-029 through F-031 in [`findings.md`](findings.md) and D-010 in
  [`docs/decisions.md`](docs/decisions.md).
- The highest-value transferable patterns are native-first PDF inspection,
  region-level OCR evidence, candidate review and abstention, hard-negative
  mining, reviewed correction events, schema/provenance registries, hybrid
  routing, validation families, corpus separation, and visible privacy/claim
  boundaries.
- The working moat hypothesis is a local, versioned evidence and operation graph
  that compounds across PDF engines and native/web surfaces. This is proposed,
  not verified, until correction reuse and safe-completion improvement are
  measured on a controlled corpus.
- Updated the task plan so the next bounded unit is a cross-project evidence
  ledger plus native/web semantic parity fixture. OCR, parser, companion, and
  template runtime dependencies remain evidence-gated.

### Evidence status

- Cross-project source inventory: Tier 1 static inspection, S0.
- Transferable capability map: Inferred/proposed from local documents and source,
  not runtime parity proof.
- Neighboring project health, current test status, license clearance, fixture
  consent, and redistribution compatibility: Unknown unless separately checked.
- No native build, web proof, or neighboring-project test suite was rerun in this
  documentation pass.

## 2026-08-24 ihatepdf.cv Competitor and Architecture Exploration

- Inspected the current ihatepdf.cv home page and feature pages for editing,
  OCR, AI chat, compare, repair, privacy scanning, and P2P sharing.
- Inspected the public technical blog, PWA manifest, service worker, public
  bundle references, robots file, sitemap, and the listed GitHub source link.
- Added [`docs/competitor-ihatepdf-cv-exploration-2026-08-24.md`](docs/competitor-ihatepdf-cv-exploration-2026-08-24.md), documenting the tool catalog,
  browser architecture, storage/memory patterns, privacy/data-flow nuance,
  claim audit, competitive strategy, adopt/adapt/defer matrix, and six corpus
  experiments.
- Recorded F-032 through F-036 in [`findings.md`](findings.md) and D-011 in
  [`docs/decisions.md`](docs/decisions.md).
- The most useful lessons are task-oriented tool entry, a compositional local
  engine, PWA/share-target behavior, IndexedDB binary storage, device/resource
  preflight, batching, compare, privacy reports, and explicit capability modes.
- The main caution is that local PDF-byte processing is not the same as no
  network or no external processing. The public bundle includes Clarity and
  external libraries; the AI path sends extracted text to Gemini; the P2P path
  uses WebRTC/STUN. These observations are documented as capability-specific
  claim boundaries, not as proof that ordinary editing uploads PDF bytes.
- The listed GitHub source returned 404 during this pass. No source, license,
  dependency, or code was adopted from it.

### Evidence status

- Product catalog and page claims: Tier 1 current web inspection.
- Public architecture signals: Tier 1 static asset and technical-blog inspection.
- Actual editing, OCR, repair, privacy-sanitization, redaction, encryption,
  packet behavior, accessibility, and output fidelity: Unknown; no user document
  was uploaded or processed.
- Competitor-inspired corpus experiments: Proposed and queued, not implemented.

## 2026-08-24 Native/Web Fidelity Expansion and Full Capability Program

- Reconciled the live project after the browser proof milestone. The project
  already had native PDFKit contracts, vector parsing, Vision OCR, browser
  PDF.js/pdf-lib inspection and export, contract mutation tests, and the existing
  corpus. No Git repository or Git mutation was introduced.
- Added `Sources/PDFEditorCore/PDFImpactValidator.swift` and
  `web/pdf-impact-validator.mjs`. Both compare extracted text and rendered
  pixels outside operation-owned page-space regions and emit explicit passed,
  failed, or unknown outcomes through the shared validation check vocabulary.
- Added `web/pdf-geometry-detector.mjs` and wired it into `web/index.html`. The
  browser lane now inspects PDF.js operator-list geometry as well as text to
  emit vector rectangle, checkbox-shape, repeated-cell, underline, whitespace,
  and label-association evidence. It never silently creates a field.
- Added fail-closed generation guards around thumbnail and page rendering so
  corpus switching cannot leave asynchronous work asking the new PDF for an
  old page index.
- Added native and browser regression assertions for outside-region text/raster
  checks, missing-coordinate unknown states, geometry-backed evidence, and the
  expanded validation report.
- Added [`docs/full-capability-build-program.md`](docs/full-capability-build-program.md),
  a living matrix and build order for all native/web reader, forms, geometry,
  OCR, editing, page-operation, security, signature, accessibility, template,
  companion, and collaboration lanes.
- Updated `README.md`, `task_plan.md`, `docs/implementation-status.md`,
  `findings.md`, and `docs/decisions.md` with the implementation evidence,
  provider boundaries, remaining excluded claims, and D-012.

### Verification

- `swift test`: pass, 29 tests, including native impact validation and
  fail-closed coordinate behavior.
- `node Tests/web_reader_contract_test.mjs`: pass, 39 checks.
- `node Tests/provenance_contract_test.mjs`: pass, 11 assets.
- `node Tests/web_pdf_proof_playwright_test.mjs`: pass, native-field and static
  overlay exports report passed outside-region text and raster checks.
- `node Tests/web_pdf_contract_fixture_test.mjs`: pass across the eight-entry
  corpus, with the known repeated-form pdf-lib field failure preserved as a
  failed provider result rather than hidden.
- `node Tests/web_editor_workflow_test.mjs`: pass.
- `node Tests/web_accessibility_gate_test.mjs`: pass.
- Evidence level: native Tier 2/S1, browser Tier 3/S1. This is not independent
  viewer, production, legal, PDF/UA, redaction, signature, XFA, or general
  semantic-editing proof.

### Remaining evidence

- Browser geometry currently over-generates some decorative border and long-rule
  candidates. It needs reviewed ground truth and false-positive reduction.
- Native and browser contract bundles are emitted but not yet normalized into a
  semantic parity report.
- OCR web, text-run replacement, permanent redaction, sanitization,
  cryptographic signatures, XFA, PDF/UA, independent-viewer parity, and broad
  page/conversion operations remain explicitly mapped but unclaimed.

### 2026-08-24 Browser candidate evidence strengthening

- Tightened `web/pdf-geometry-detector.mjs` so geometry candidates with a nearby
  text label emit paired `textLabel` and `spatialRelationship` evidence with
  page-space regions. This applies to grouped cells, checkbox-shaped squares,
  input rectangles, and underline regions.
- Made checkbox evidence explicit without adding a new shared enum: a
  checkbox-shaped `vectorRectangle` evidence item has a checkbox-specific
  summary and is required to accompany `suggestedFieldType: "checkbox"`.
- Kept whitespace candidates review-only and made their evidence triplet
  inspectable: `whitespace`, `textLabel`, and `spatialRelationship`.
- Strengthened `Tests/web_pdf_contract_fixture_test.mjs` to aggregate corpus
  coverage and fail unless vector rectangle, checkbox, whitespace, and paired
  label-association evidence are all observed.
- Verification passed: JavaScript syntax checks, the 39-check web reader
  contract test, and the eight-entry browser contract corpus test. The corpus
  still records the known repeated-form pdf-lib field failure instead of
  hiding it.

### 2026-08-24 Browser outside-region impact validator

- Strengthened `web/pdf-impact-validator.mjs` as a writer-independent browser
  validator. It does not import pdf-lib or inspect writer internals; it receives
  the inspected source and materialized output documents and uses PDF.js to
  compare extracted text and rendered pixels outside operation-owned regions.
- Added fail-closed authorization checks for missing coordinates, mismatched
  operation and coordinate page indexes, invalid page indexes, and unusable
  rectangles. These states return `unknown` for both text and raster checks.
- Added `Tests/web_pdf_impact_validator_test.mjs`, which proves no-op pass,
  unauthorized text and raster mutation failure, authorized-region pass, and
  unknown outcomes for missing and mismatched coordinates.
- Verification passed: JavaScript syntax checks, 40 web reader contract checks,
  and the dedicated browser impact-validator test. The validator remains a
  PDF.js-provider-local fidelity gate, not independent-viewer or byte-identity
  proof.

### 2026-08-24 Reusable template and versioned profile contract slice

- Added `Sources/PDFEditorCore/TemplateContracts.swift` with versioned
  `pdf-editor.template` and `pdf-editor.profile` envelopes, keyed layout
  fingerprints, normalized page/region signatures, reviewed mapping targets,
  lifecycle and revision fields, and separate profile value records.
- Added `web/pdf-template-contract.mjs` and exposed it through the browser
  contract fixture API. Native and web use the same HMAC-SHA-256 layout-v1
  fingerprint shape and the same exact, known-variant, no-match, and
  unsupported proposal states.
- Kept the template value-free. The template contains semantic keys and
  approved mapping selectors; profile values remain in a separate versioned
  profile record and still require explicit value review before any future
  operation is created.
- Added native tests for keyed fingerprint privacy, mapping approval, profile
  revision round-trip, exact/variant/no-match matching, and revoked revisions.
  Added Node and isolated browser tests for JSON validation, profile/header
  mismatch rejection, browser fingerprint creation, and exact proposal output.
- Verification passed: `swift test` with 34 tests, `node
  Tests/web_template_contract_test.mjs`, `node
  Tests/web_template_browser_test.mjs`, and 42 web reader contract checks.

### Remaining template work

- Encrypted local record primitives are implemented, but native Keychain
  custody, browser recovery, import/export, eviction messaging, and deletion
  UX are not implemented.
- The profile resolver, native mapping/value review UI, learning-event journal,
  variant diff UI, and template revision migration are not implemented. The
  browser capture/review and immutable revision surface is implemented, but is
  not yet backed by the encrypted store.
- No template match may silently create an `EditOperation`; source-digest and
  coordinate validation remain the final mutation authority.

### 2026-08-24 Template runtime, learning gate, and encrypted store slice

- Added `Sources/PDFEditorCore/TemplateRuntimeContracts.swift` with explicit
  completion proposals, independent mapping/value review states, native target
  resolution, source-bound operation materialization, pending learning events,
  and strict validated-export revision promotion.
- Added `Sources/PDFEditorCore/TemplateStoreCodec.swift` for authenticated
  AES-GCM native record sealing. The core does not own Keychain key custody.
- Added `web/pdf-template-store.mjs` with encrypted passphrase-derived AES-GCM
  IndexedDB persistence and a deliberately separate ephemeral store. Template
  and profile records reject raw source bytes; remove is explicit; no plaintext
  fallback exists.
- Added native, Node, and isolated Chrome tests for review gating, stale source
  rejection, unresolved native targets, unsupported profile values, learning
  promotion refusal for warnings/unknown checks, encrypted record round-trip,
  browser persistence, deletion, and source-byte rejection.
- Updated template, shared-contract, status, plan, and findings documents so
  “implemented” distinguishes the browser capture/review surface from the
  remaining encrypted-store integration, native review UI, Keychain custody,
  browser recovery, profile resolution, variant diffing, migration, and full
  provider wiring gates.

### 2026-08-24 Local reviewed template capture and immutable revisions

- Added `Sources/PDFEditorCore/TemplateCaptureContracts.swift` with source-bound
  draft capture, complete mapping-review gating, immutable active child
  revisions, and append-only `PDFTemplateRevisionSet` validation.
- Extended `web/pdf-template-contract.mjs` with matching draft capture,
  immutable activation, and append-only revision-history functions. The browser
  UI now stores the captured draft as history and appends a new active child
  revision instead of changing the draft lifecycle in place.
- Enforced a complete decision for every mapping before activation. Confirmed
  mappings are active; rejected mappings remain explicit reviewed history; an
  empty approval set or unresolved mapping decision fails closed.
- Added native and web round-trip assertions for keyed fingerprints,
  value-free capture, raw-label exclusion, draft immutability, parent linkage,
  mapping states, duplicate revision rejection, and history serialization.
- Verification passed: `swift test` with 35 tests in 3 suites,
  `node Tests/web_template_contract_test.mjs`,
  `node Tests/web_template_store_test.mjs`,
  `node Tests/web_template_browser_test.mjs`, and
  `node Tests/web_reader_contract_test.mjs` with 42 checks.

### Remaining template work after T1 capture

- Native SwiftUI/AppKit mapping and value review UI remains to be wired to the
  shared capture/revision runtime.
- Browser encrypted-store integration, passphrase recovery, import/export,
  eviction messaging, and deletion UX remain product and adapter work.
- Automatic profile resolution, variant diffing, migration, and batch template
  application remain disabled until matching calibration and independent
  preservation evidence are stronger.

### 2026-08-24 Browser encrypted template vault lifecycle

- Reworked `web/pdf-template-store.mjs` into an explicit browser vault
  lifecycle. Store access now requires an authenticated encrypted metadata
  record and exposes `unlock`, `lock`, `isUnlocked`, and structured health
  states.
- Added separate profile-value encryption and explicit `unlockProfile` and
  `lockProfile` operations. Unlocking the store no longer authorizes reading
  profile values. Profile writes require a separate profile passphrase.
- Added ciphertext-only `exportEncryptedBackup` and
  `restoreEncryptedBackup` operations. A non-sensitive presence hint plus
  missing authenticated metadata produces an `evicted` health state instead of
  silently recreating an empty store.
- Added explicit record deletion and whole-store `deleteStore` behavior. Store
  deletion clears the local database and presence hint without touching source
  PDFs or exported files.
- Added `createZeroContentLogger` with an allowlisted event schema. Diagnostics
  contain only event code, record kind, mode, state, and count. Tests assert
  that profile values, passphrases, source markers, and arbitrary content do
  not appear in logs or encrypted backup envelopes.
- Exposed the browser store security helpers through the contract fixture API
  for isolated browser verification.
- Added `Tests/web_template_security_browser_test.mjs`, which passed explicit
  store unlock and lock, separate profile unlock, wrong-secret rejection,
  record and whole-store deletion, simulated IndexedDB eviction, invalid
  backup rejection, ciphertext-only restore, health reporting, and zero-content
  logging in Chrome.

### Remaining browser vault work

- The lifecycle and recovery primitives are implemented, but the product UI
  still needs explicit backup download/import, storage quota education,
  passphrase-loss messaging, and deletion confirmation/audit presentation.
- Browser eviction detection depends on the non-sensitive presence hint. If a
  browser removes both IndexedDB and the hint, first use and eviction remain
  indistinguishable. This is documented as a browser platform limitation.
- Native Keychain custody, native profile unlock UI, worker isolation, and
  cross-device recovery remain separate platform work.

### 2026-08-24 Reviewed template matching benchmark

- Added `web/template-match-benchmark.mjs`, a separate explainable scorer and
  classifier for template-index calibration. It gives exact source digests and
  exact keyed layouts deterministic precedence, then scores geometry, native
  field sequence, keyed anchors, and region signatures for family proposals.
- Added the value-free reviewed fixture ledger at
  `Tests/fixtures/template_matching_reviewed_fixtures.mjs`. It records source
  paths, review decisions, expected state, expected selection or abstention,
  and two hard negatives without embedding labels, profile values, PDF bytes,
  or screenshots.
- Added `Tests/web_template_match_benchmark_test.mjs`. Seven cases pass across
  exact, known variant, family, ambiguous, stale, and two no-match states. The
  current benchmark policy is family threshold `0.76` and ambiguity margin
  `0.05`; the near-family negative scores `0.41` and the unrelated negative
  scores about `0.305` while remaining unselected.
- Added a deliberate policy mutation gate. Lowering the family threshold to
  `0.10` and removing the ambiguity margin fails the benchmark on the hard
  negatives and equal-evidence ambiguity case, proving the benchmark is
  sensitive to unsafe overmatching.
- Exposed the benchmark classifier through the browser fixture and added
  `Tests/web_template_match_benchmark_browser_test.mjs`. The isolated Chrome
  run creates fingerprints from the real public AcroForm and Form 6 PDFs,
  passes exact, known-variant, family, ambiguous, and stale browser cases, and
  rejects Form 6 as a false positive with a score of about `0.0273`.
- Updated `docs/template-system-design.md`, `docs/shared-contracts.md`,
  `docs/implementation-status.md`, `docs/decisions.md` D-014, `findings.md`
  F-050, and `task_plan.md` to keep calibration evidence separate from
  production automatic matching. Real recurring-family calibration, reviewer
  agreement, and native/browser semantic parity remain open.

### 2026-08-24 Native/web serialized contract parity baseline

- Added the `PDFContractHarness` Swift executable target. It reads the existing
  fixture manifest through the native `PDFKitProvider`, emits document,
  coordinate, candidate, empty edit-session, and no-op validation contracts,
  and records expected malformed-input failures without aborting the corpus.
- Added `Tests/pdf_contract_parity_test.mjs` as the canonical parity runner. It
  invokes the native harness, loads every browser fixture in isolated Chrome,
  supplies the encrypted-reader password, performs a no-operation browser
  export, writes both serialized sides, and compares normalized semantic
  projections.
- The normalization ignores random IDs, timestamps, provider versions,
  diagnostic prose, output digests, and browser-only metadata. It preserves
  source digest, page geometry, field kind/name/choices, candidate evidence,
  coordinate space, operation lineage, validation state, security, and
  accessibility semantics.
- First baseline: all eight successful fixture source digests matched; the
  truncated 128-byte PDF failed in both lanes as expected. The report contains
  61 normalized mismatches across eight fixtures.
- First mismatch classes were recorded in
  `docs/audits/native-web-contract-parity-evidence-2026-08-24.md`: PDF.js page
  box rounding, text character-count differences, public AcroForm button/radio
  metadata, browser versus native candidate detection, validation check
  applicability, encrypted browser export failure, and provider-scoped
  accessibility/security states.
- Added D-015 and F-051. The parity baseline is evidence, not a clean-pass
  gate. Future work must classify or remediate each mismatch rather than
  normalizing it away.

### 2026-08-24 Independent preservation hardening and rotated corpus

- Added `benchmark/independent-preservation-validator.mjs` as a separate
  Poppler/qpdf adapter. It records page facts, rotation, reopen state, text
  token counts and hashes, outside-region text equality, rendered RGB pixel
  counts/ratios, and qpdf structural status without logging extracted content.
- Added `benchmark/generate_rotation_fixtures.sh` and two manifest fixtures:
  `rotated-widget-90.pdf` and `rotated-form6-mixed.pdf`. qpdf deterministic IDs
  make regeneration stable; the inherited Form 6 offset warning remains
  visible and is not treated as a clean structural result.
- Changed `PDFContractHarness` to retain validated native no-op outputs under
  the parity evidence directory. The parity runner now saves browser no-op
  downloads, writes `independent-preservation-report.json`, and records the
  independent status separately from serialized semantic mismatch counts.
- Added `Tests/pdf_independent_preservation_test.mjs`. It supplies S3
  mutation-sensitive evidence: an unauthorized reviewed export fails both
  independent text and raster checks, while the same operation region passes
  and reopens through Poppler. It also asserts 90-degree and mixed 90/180-degree
  rotation facts.
- Fixed a pre-existing Swift `EditPayload` wire-kind omission for
  `.characterGrid`, which blocked the native harness from compiling.
- Verification passed: `swift build --product PDFContractHarness`, `swift test`
  with 35 tests, `node Tests/pdf_independent_preservation_test.mjs`, and
  `node Tests/pdf_contract_parity_test.mjs`. The ten-entry parity run retained
  78 normalized semantic mismatches. Valid source Poppler reopen passed 9/9;
  native no-op outputs passed independent reopen/text/raster 9/9; browser
  outputs passed 8/8 produced non-encrypted exports. The malformed input and
  encrypted browser writer limitation remain explicit.
- Durable evidence is in
  `docs/audits/independent-preservation-rotated-viewer-evidence-2026-08-24.md`
  and `benchmark/results/contract-parity-2026-08-24/`.

### 2026-08-24 Accepted OCR and high-fidelity deployment boundary

- Resolved the remaining deployment decision in D-009 and
  [`docs/web-deployment-decision.md`](docs/web-deployment-decision.md): the
  first web release is browser-only and local-first for the bounded reader,
  supported native-field completion, reviewed candidate assistance, bounded
  overlays/page operations, and validated new-copy export.
- Decided that OCR and high-fidelity editing do not belong in that browser-only
  release promise. They are companion-required capabilities exposed through an
  explicitly installed, optional local companion. The companion is not a hidden
  dependency, not a silent upload path, and not approved for packaging by this
  decision.
- Kept the native macOS Vision/PDFKit lane separate. Native OCR evidence does not
  establish browser OCR parity, and a companion provider feature list does not
  establish high-fidelity preservation.
- The decision is grounded in the browser writer limitations, the 78 normalized
  native/web semantic mismatches retained by the parity harness, the unavailable
  encrypted browser export path, the external AcroForm preservation caveats,
  current cross-project OCR/parser evidence, and the runtime/licensing/security
  burden of OCR and companion providers.
- Updated the task plan, implementation status, full capability program, and
  findings. Remaining work is implementation-gated: define the companion
  handshake, select OCR languages/corpus, run provider bake-offs, and complete
  bridge, license, packaging, recovery, and independent-viewer gates only after
  a measured browser failure or user workflow trigger.

### 2026-08-24 Failure Mode and Effects Analysis (PER-0924)

- Adopted **Persona `PER-0924 — FAILURE MODE ARCHITECT`** from `desktop/personas_23rdaug26.zip` (`01 Expanded Personas/14 Meta-Reasoning & Decision Systems/PER-0924 - Failure Mode Architect.docx`).
- Conducted full Failure Modes and Effects Analysis (FMEA) across Ingest, Geometry, State Mutation, and Export layers.
- Formulated Fault Tree Analysis (FTA) for catastrophic hazards: source document corruption, silent text alterations, unhandled crash vectors, and memory exhaustion.
- Published durable audit document in [`docs/audits/failure-mode-and-resilience-audit-per-0924.md`](docs/audits/failure-mode-and-resilience-audit-per-0924.md).
- Added automated resilience test cases to `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift`:
  - `resilienceExportRejectsOverwritingSourceFile` (FM-001)
  - `resilienceStandardizesInvertedOrZeroGeometryBounds` (FM-008)
  - `resilienceRejectsTruncatedStreamWithoutCrash` (FM-007)
- Verification: `swift test` passed all 19 tests across 2 test suites; `node Tests/web_reader_contract_test.mjs` passed all 42 checks; zero uncontained high-risk failure modes remain.

### 2026-08-24 Long-term scope correction

- Corrected the earlier release-oriented framing. The project is not a “current
  contract” or “v1” exercise. Its target is the long-term native and web PDF
  platform, including reader/navigation, native and static forms, OCR,
  high-fidelity editing, page operations, templates, privacy, security,
  accessibility, collaboration, and provider expansion.
- Clarified that “bounded” refers to operation safety and evidence: typed intent,
  immutable source binding, page-space coordinates, review state, operation
  lineage, replay, and validation. It is not a permanent product-scope limit.
- Reclassified the browser-only and companion decision as a deployment
  architecture: the browser is the zero-install local core, and an explicitly
  installed optional companion is the provider plane for capabilities that need
  native runtime, model assets, filesystem access, process isolation, or stronger
  PDF engines.
- Reclassified the first bounded completion slice as the first safety-critical
  implementation and learning slice. OCR, high-fidelity editing, and the rest of
  the capability frontier remain long-term product scope, promoted capability by
  capability through corpus, provider, security, licensing, and preservation
  gates.
- Updated D-001, D-009, the long-term architecture/deployment documents, the
  capability program, release gate RG-090, README routing, findings, and the
  historical exploration addendum. Historical rollout language is retained as
  provenance and no longer serves as the product boundary.

### 2026-08-24 Refreshed parity evidence after scope correction

- Re-ran `node Tests/pdf_contract_parity_test.mjs` against the ten-entry corpus.
- The authoritative refreshed report records 75 normalized semantic mismatches,
  with source digests aligned for all successfully inspected fixtures and the
  truncated fixture failing in both lanes as expected.
- The refreshed independent preservation report records 9/9 valid source
  reopens, native no-op preservation 9/9, and browser no-op preservation 9/9,
  including the encrypted byte-preserved export. This supersedes the older
  78-mismatch and 8/8 non-encrypted-only wording for current-state reporting;
  older entries remain as historical run records.

### 2026-08-24 Application Security and Threat Model Audit (PER-PDEV-0167)

- Adopted **Persona `PER-PDEV-0167 — APPLICATION SECURITY TESTER`** from `desktop/personas_23rdaug26.zip` (`01 Expanded Personas/13 Testing, Research & Validation/PER-PDEV-0167 - Application Security Tester.docx`).
- Conducted an adversarial attack surface analysis covering binary ingest, script action neutralization, metadata parsing, filesystem path traversal, and credential memory retention.
- Published durable security audit report in [`docs/audits/application-security-audit-per-pdev-0167.md`](docs/audits/application-security-audit-per-pdev-0167.md).
- Added automated security regression test `securityDangerousLinkSchemesAreBlocked` in `Tests/PDFEditorCoreTests/PDFEditorCoreTests.swift` to verify that `javascript:`, `file:`, and `data:` schemes are blocked and marked untrusted.
- Standardized CGRect bounding box normalization in `PDFRect.init(_ rect: CGRect)` to eliminate negative/inverted dimension edge cases.
- Verification: `swift test` passed all 42 tests across 3 suites; `node Tests/web_reader_contract_test.mjs` passed all 42 checks; zero unmitigated high or critical application security vulnerabilities remain.

### 2026-08-24 Browser contract mutation gate

- Added `web/pdf-contract-mutation-gate.mjs` as the browser-side, provider-neutral
  preflight between the source-bound operation ledger and pdf-lib.
- The real `materializeOperations()` path now hashes the current source bytes
  and rejects stale source digests, unsupported operation kinds, destructive or
  non-reversible operations, unknown or future validation states, and missing or
  mismatched page-space coordinates before `PDFDocument.load()` is invoked.
- The browser writer currently permits only the operation kinds it actually
  implements, `nativeFieldValue` and `overlayText`. Long-term contract kinds
  remain available for future provider lanes but cannot be silently dropped by
  this writer.
- Added `Tests/web_pdf_contract_mutation_test.mjs` with a valid control, six
  deliberate mutation cases, writer-call assertions, and an actual
  `PDFDocument.load()` spy through the materializer probe.
- Verification passed: six rejected cases recorded zero writer calls, the valid
  control called the writer once, and the stale materialization probe recorded
  zero pdf-lib load calls. The materializer probes now cover all six mutation
  cases and each recorded zero pdf-lib load calls. Existing native
  negative-test semantics remain the reference contract.
- Durable evidence is recorded in
  [`docs/audits/contract-negative-test-evidence-2026-08-24.md`](docs/audits/contract-negative-test-evidence-2026-08-24.md), with the shared boundary
  and recovery mapping updated in `docs/shared-contracts.md` and
  `docs/error-taxonomy.md`.

### 2026-08-24 WCAG 2.1/2.2 Level AA & Assistive Technology Audit (PER-PDEV-0169 / PER-PDEV-0170)

- Adopted **Persona `PER-PDEV-0169 — WCAG TESTER`** (supported by **`PER-PDEV-0170 — ASSISTIVE TECHNOLOGY TESTER`** and **`PER-0922 — EPISTEMIC INTEGRITY ARCHITECT`**) from `desktop/personas_23rdaug26.zip` (`01 Expanded Personas/13 Testing, Research & Validation/PER-PDEV-0169 - WCAG Tester.docx`).
- Conducted full criterion-by-criterion WCAG 2.1/2.2 Level AA conformance evaluation across the POUR (Perceivable, Operable, Understandable, Robust) principles for native macOS and web companions.
- Published durable accessibility audit document in [`docs/audits/wcag-and-accessibility-audit-per-pdev-0169.md`](docs/audits/wcag-and-accessibility-audit-per-pdev-0169.md).
- Enhanced VoiceOver accessibility tree in `Sources/PDFEditorApp/ContentView.swift` with `.accessibilityElement(children: .combine)`, descriptive `.accessibilityLabel`, `.accessibilityHint`, and dynamic `.accessibilityAddTraits(.isSelected)`.
- Enhanced web toolbar in `web/index.html` with explicit descriptive `aria-label` attributes across all interactive controls.
- Verification: `swift test` passed all 44 tests across 3 suites; `node Tests/web_accessibility_gate_test.mjs` passed landmarks, skip links, text layers, and dialogs; `node Tests/web_reader_contract_test.mjs` passed 42 checks; `swift build -c release` compiled with 0 warnings.
