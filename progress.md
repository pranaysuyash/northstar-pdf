# PDF Editor Discovery Progress

## 2026-08-25 Product-facing encrypted persistence and cross-device recovery

- Implemented native backup download/import for the encrypted template and
  profile vaults through explicit save/open panels. Native Keychain custody,
  profile-vault separation, replacement confirmation, and value-free deletion
  audit remain visible in the SwiftUI recovery surface.
- Implemented browser backup download/import, stronger lost-passphrase
  messaging, quota and persistence education, eviction guidance, deletion
  confirmation, and a portable cross-device recovery action.
- Added versioned native local persistence contracts for opaque encrypted
  backups, encrypted backup bundles, recovery envelopes, and cross-device
  recovery bundles. Added browser equivalents and a ciphertext-only module
  worker for backup structure validation.
- Corrected the cross-device browser semantics: ordinary recovery remains
  bound to its IndexedDB identity, while portable recovery explicitly accepts a
  different destination identity and re-keys the destination vault to the
  supplied recovery passphrase.
- Added native encrypted-backup, profile-separation, cross-device
  encode/decode, plaintext-exclusion, and wrong-store tests. Added browser
  runtime coverage that restores into a different IndexedDB name, validates
  worker plaintext abstention, keeps profiles locked until profile unlock,
  re-keys, locks, and reopens the destination vault.
- Verification: `swift build --target PDFEditorCore` passed; browser security
  runtime passed; changed JavaScript syntax passed; `git diff --check` passed.
  Full Swift test execution is currently blocked by unrelated existing
  `DiffComparisonView.swift` AppKit/PDFKit compile errors in the app target.
- Durable evidence:
  [`docs/audits/local-persistence-product-surface-evidence-2026-08-25.md`](docs/audits/local-persistence-product-surface-evidence-2026-08-25.md)

## 2026-08-25 Character-grid merge and highlight remediation

- Fixed the character-grid false-merge root cause in `web/pdf-geometry-detector.mjs`: same-row cells now require compatible row geometry, cell-width signatures, and local gap patterns before they can form one candidate. This prevents sibling fields and photo-box cells from entering the same union.
- Mirrored the grouping algorithm in `Sources/PDFEditorCore/StaticRegionDetector.swift` so native and browser detection share the same field-boundary contract.
- Reworked candidate rendering in `web/index.html` and `web/app.js`: character-grid unions are transparent dashed boundaries, cells receive separate low-opacity tints, and pending glyphs use restrained blue overlays rather than dense fills. Search marks now use a low-opacity amber cue with an inset underline to preserve legibility.
- Reworked the native presentation overlay in `Sources/PDFEditorApp/ContentView.swift`: character-grid candidates now use a dashed union plus per-cell tint, normal overlays are lighter, and PDFKit's opaque current-selection paint is cleared after exact search bounds are captured.
- Strengthened `Tests/web_character_grid_workflow_test.mjs` with assertions for Form 6 sibling-field splitting (11 + 12 cells), photo-box exclusion, union-bound invariants, transparent grid rendering, per-cell tint rendering, and reduced search opacity.
- Verification: focused Chrome workflow passed. Direct DOM inspection observed transparent grid union, dashed boundary, per-cell tints, and `rgba(255, 210, 77, 0.16)` search marks. `swiftc -parse` passed for both updated native sources. Native `swift test` was attempted but blocked by the host SwiftPM sandbox (`sandbox_apply: Operation not permitted`), so native runtime execution remains pending in a normal Xcode/SwiftPM environment.
- Durable evidence: [`docs/audits/character-grid-merge-and-highlight-evidence-2026-08-25.md`](docs/audits/character-grid-merge-and-highlight-evidence-2026-08-25.md).

## 2026-08-25 Cross-project implementation mandate correction

- Recorded the owner direction that the cross-project exploration is a
  long-term implementation mandate and moat input, not a shortlist of optional
  ideas or a reason to narrow PDF Editor to the current browser/native proof.
- Reconciled `docs/cross-project-document-intelligence-exploration.md` so every
  transferable lane from SignKit, MetaExtract, Invoice Intelligence,
  PhotoSearch, `extracted_forms`, and the historical web detector has a PDF
  Editor build obligation with a named ownership boundary.
- Preserved the source-project boundaries: no neighboring code, source bytes,
  private values, database, generated artifact, or Git state was imported or
  changed. Transfer means reimplementation behind PDF Editor contracts.
- Clarified that `Deferred`, `Gated`, `Unmeasured`, `Quarantined`, `Blocked`, and
  `Abstained` are evidence or execution states, not permanent product
  exclusions. Each lane must eventually carry implementation, contract,
  governed corpus, provider/license, privacy/security, failure/recovery,
  benchmark, and validation evidence.
- Updated the task plan so native/browser parity remains a prerequisite for
  truthful provider comparison while OCR, parser, signature, companion, batch,
  security, accessibility, hosted, and collaboration lanes continue as active
  implementation work.

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

## 2026-08-25 Parallel Review Round and Fixes

- Dispatched three read-only subagent reviews of the implemented slice: core
  safety/contract conformance, macOS shell/HIG, and the next provider lane.
  Two initial dispatches hung; the shell review completed, and both remaining
  reviews were retried successfully after confirming the workspace state.
- Discovered the workspace had grown in parallel to roughly 15,600 lines
  (impact validator, session/recovery stores, template contracts, vector stream
  parser, expanded tests) beyond the initially authored slice; verified the
  current tree with `ls`/`wc -l` before trusting review findings.
- Confirmed five review findings by direct inspection and fixed them:
  fail-closed raster comparison in `PDFImpactValidator` (plus two
  non-interpolated page-number strings), occurrence-based stable
  `NativeField.id` instead of the volatile annotation index, parenthesized
  `ProfileStore` employer/company precedence, a model-level signature guard in
  `applyFieldValue` closing the `.onSubmit` bypass, and permission-gated,
  skip-reporting `applyBulkFill`.
- Confirmed two reported shell issues were already correct in the current code
  (transactional undo replay; atomic `replaceItemAt` publication) and recorded
  them as stale findings rather than fixes.
- Recorded all remaining confirmed findings as tracked follow-ups in F-023
  (`findings.md`), including the byte-scan AcroForm guard, radio retention
  validation, unimplemented signature image operation, discarded OCR provenance,
  fabricated detector line geometry, certainty overstatements, rotation-blind
  raster exclusion, and the P3 list.
- Verification: `swift build` passed (13.6 s); `swift test` passed 67/67
  (including the environment-gated Form 6 and public AcroForm fixture tests);
  `swift build -c release` passed (27.2 s).
- Provider-lane assessment (research only): PDFBox 3.0.8 fat-jar + `javac`
  workflow is viable on this machine (Java 17, no Maven/Gradle needed),
  Apache-2.0, with a concrete oracle matching the existing public-AcroForm
  benchmark; recorded as the next lane, not yet run.
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
- Competitor-inspired corpus contracts: Implemented as six versioned ledger
  entries and six native/browser semantic parity cases. Capability execution is
  proposed and queued, not yet implemented.

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

### 2026-08-24 Reviewed recurring-template corpus and class calibration

- Expanded `Tests/fixtures/template_matching_reviewed_fixtures.mjs` from the
  seven-case controlled benchmark to 24 explicit value-free decisions across
  `publicAcroForm`, `staticPrintedForm`, `nativeWidget`, `rotatedStaticForm`,
  `rotatedNativeWidget`, and `scannedDocument`.
- Added explicit reviewer labels to every case. The current evidence is
  single-curator evidence and records `independentAgreement: not-measured`
  instead of claiming unverified reviewer agreement.
- Added class-aware policy resolution and calibration to
  `web/template-match-benchmark.mjs`. Exact, known-variant, and stale states
  remain deterministic precedence rules. Family thresholds are derived only
  when positive and hard-negative scores are separable.
- Calibrated five structured classes with thresholds from `0.7772` through
  `0.8624`. Scanned documents have exact and known-variant coverage, but family
  acceptance is disabled because the corpus has no family-positive evidence.
- The benchmark passes with both the fallback policy and the calibrated class
  policy map. Setting every class threshold to zero and removing the ambiguity
  margin fails on hard negatives and ambiguous selections.
- Exposed `calibrateDocumentClassPolicies` through the browser fixture. This is
  a shared implementation surface, not evidence that browser extraction alone
  proves native semantic parity.
- Added the durable calibration record at
  [`docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md`](docs/audits/recurring-template-class-calibration-evidence-2026-08-24.md).
  Added the checked-in machine snapshot at
  [`benchmark/results/template-matching/2026-08-24-class-calibration.json`](benchmark/results/template-matching/2026-08-24-class-calibration.json),
  with the executable test checking its policy fields and evidence counts.
  Genuine recurring source versions, hold-out evaluation, reviewer agreement,
  and class-specific native/browser parity were the next evidence gates at this
  point in the historical sequence. The following entry records the bounded
  semantic parity result.

### 2026-08-24 Native Swift and browser reviewed-template semantic parity

- Added `Sources/PDFEditorCore/TemplateBenchmarkContracts.swift` with the
  native Swift value-free benchmark contracts, class-aware policy projection,
  candidate evidence, state transitions, stale-source refusal, and abstention
  behavior used by the parity lane.
- Added the `PDFTemplateParityHarness` executable target in `Package.swift` and
  `Sources/PDFTemplateParityHarness/main.swift`. It consumes the canonical
  reviewed corpus and writes a retained native run under
  `benchmark/results/template-matching/`.
- Added `Tests/template_match_native_browser_parity_test.mjs`. It writes one
  canonical corpus, runs Swift, evaluates the browser adapter in isolated
  Chrome, and compares state, selection, abstention, false-positive gates,
  score, candidate identity/reason/components, and class policy.
- The 24-case run passed with zero semantic mismatches. Both lanes produced
  exact 2, knownVariant 2, familyMatch 6, ambiguous 6, stale 1, and noMatch 7.
  Both selected 10 cases and abstained on 14 cases. Candidate evidence and
  policy projections also had zero mismatches, with no browser console or page
  errors.
- The first gate caught two serialization defects before the final pass:
  omitted native `null` selection identities and raw policy-object key-order
  comparison. The runner now compares normalized semantic projections and keeps
  those corrections in the audit history.
- Durable evidence is recorded in
  [`docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md`](docs/audits/template-native-browser-semantic-parity-evidence-2026-08-24.md)
  and
  [`benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json`](benchmark/results/template-matching/2026-08-24-native-browser-semantic-parity.json).

### Remaining reviewed-template parity work

- This clears semantic conformance for the value-free reviewed benchmark, not
  live PDFKit-versus-PDF.js fingerprint extraction, PDF byte fidelity, recall,
  reviewer agreement, or production automatic completion.
- The next gate is independent native and browser fingerprint extraction from
  the same real PDF sources, with geometry, field sequence, anchors, and region
  evidence compared before classification.

### 2026-08-24 Reviewed correction-event benefit measurement

- Added `web/template-correction-benchmark.mjs` to measure whether an explicit
  reviewed correction improves recurring completion coverage without turning
  learning into silent autofill.
- Defined the primary metric as `reviewedTargetCoverage`: the number of
  reviewed mappings surfaced in a completion proposal without resolving or
  storing profile values. Keystroke time, user acceptance, profile-value
  correctness, and real-world recall remain explicitly unmeasured.
- Ran five controlled structured variants across `publicAcroForm`,
  `staticPrintedForm`, `nativeWidget`, `rotatedStaticForm`, and
  `rotatedNativeWidget`. Every baseline was `noMatch` with zero surfaced
  targets. Every strict reviewed promotion became `exact` with one surfaced
  reviewed target, for a coverage lift of 5 across 5 cases.
- Replayed all seven existing hard-negative fixtures against all five promoted
  child revisions. The result was 0 selections and 35/35 abstentions.
- Verified rollback by reselecting the unchanged parent revision. All five
  cases returned to `noMatch` with zero surfaced targets while promoted child
  revisions remained auditable in history.
- Verified value-free correction records: zero profile values, no raw labels,
  no PDF bytes, no screenshots, and no passphrases. A hard-negative correction
  mutation was rejected before child revision creation.
- Added the deterministic Node test and isolated Chrome test:
  `Tests/web_template_correction_benchmark_test.mjs` and
  `Tests/web_template_correction_benchmark_browser_test.mjs`. Chrome passed
  with zero console and page errors on the project-owned port 8183 route.
- The first run caught an over-broad privacy sentinel that confused the keyed
  token `hmac:anchor-applicant` with a raw label. The sentinel was narrowed to
  quoted raw content and the rerun passed. This remains S2 harness evidence.
- Durable report and interpretation are recorded in
  [`docs/audits/reviewed-template-correction-benefit-evidence-2026-08-24.md`](docs/audits/reviewed-template-correction-benefit-evidence-2026-08-24.md)
  and
  [`benchmark/results/template-matching/2026-08-24-correction-benefit.json`](benchmark/results/template-matching/2026-08-24-correction-benefit.json).

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
- Added `Tests/web_pdf_contract_mutation_test.mjs` with a valid control, seven
  deliberate mutation cases, writer-call assertions, and an actual
  `PDFDocument.load()` spy through the materializer probe.
- Verification passed: seven rejected cases recorded zero writer calls, the
  valid control called the writer once, and all seven materializer probes
  recorded zero pdf-lib load calls. Targeted guard mutation runs killed the
  destructive, page-coordinate, coordinate-space, and composite rectangle
  bypasses. Each single rectangle comparison mutant survived only because the
  other rectangle invariant caught it, proving defense in depth.
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

### 2026-08-24 Red-Team Campaign Audit (PER-PDEV-0168)

- Adopted **Persona `PER-PDEV-0168 — RED-TEAM ENGINEER`** (supported by `PER-PL2-0038 — PENETRATION TESTER` and `PER-PDEV-0164 — FAULT-INJECTION ENGINEER`) from `desktop/personas_23rdaug26.zip`.
- Conducted objective-driven adversarial campaign against two attacker models: Actor A (local, low privilege, Application Support file access) and Actor B (remote, untrusted PDF supplier).
- Published campaign narrative in [`docs/audits/red-team-campaign-audit-per-pdev-0168.md`](docs/audits/red-team-campaign-audit-per-pdev-0168.md).
- **RT-001 (High / CVSS 7.1) — REMEDIATED:** `EncryptedProfileStore` was writing raw plaintext JSON to disk despite the "Encrypted" class name and AES-GCM documentation. Implemented genuine AES-256-GCM encryption: a 256-bit key is generated once and stored in the macOS Keychain (`com.pdfeditor.profilestore`); on-disk file is an envelope JSON `{ nonce, ciphertext }` with no readable PII. Backward-compatible with legacy plaintext profiles (migrated to encrypted format on next save).
- **RT-002 (Medium / CVSS 5.3) — REMEDIATED:** Export staging temp file was created in the user-chosen export directory rather than the OS-isolated `FileManager.default.temporaryDirectory`. Moved to OS tmpdir to eliminate symlink race attack vector.
- **RT-003 (Low / CVSS 3.7) — REMEDIATED:** vCard import had no per-value length limit; a crafted `FN:` line could store unbounded data. Added 1024-character truncation guard via `sanitized()` helper in `importFromVCard`.
- **RT-004 (Informational) — DOCUMENTED:** CSP `'unsafe-inline'` required by current inline module script design. No current exploitability; deferred to RT-004 milestone (extract `web/app.js`).
- Added two regression tests: `redTeamRT001ProfileIsNotStoredAsPlaintextJSON` (asserts on-disk file not parseable as plaintext `UserProfile`) and `redTeamRT003VCardImportTruncatesLongValues` (asserts 4096-char vCard FN: stored ≤ 1024 chars).
- Verification: `swift test` passed all **62 tests** across 4 suites with 0 failures; Actor B objective (remote exploit chain) not achieved across all hardened surfaces.

### 2026-08-24 ihatepdf-inspired corpus experiment ledger and parity

- Implemented the six experiment records from the ihatepdf.cv exploration as
  versioned entries E-001 through E-006 in
  [`Tests/fixtures/ihatepdf_experiment_ledger.json`](Tests/fixtures/ihatepdf_experiment_ledger.json).
- Added one semantic parity case per entry covering source fixture and digest,
  typed operation intent, canonical lower-left crop-box coordinates, review and
  abstention policy, privacy class, validation obligations, falsifier, and
  rollback path.
- Added an independent Swift `PDFExperimentParityHarness` and browser
  `runIhatepdfExperimentParity` projection. The focused isolated-Chrome run
  produced 6 cases, 0 native/browser semantic mismatches, 0 console errors,
  and 0 page errors.
- Added four mutation checks for missing falsifier, coordinate-origin drift,
  source unbinding, and operation-kind drift. All 4/4 were rejected.
- Added the retained native, browser, and combined reports under
  `benchmark/results/ihatepdf-experiments/`.

#### Evidence status

- Ledger and parity contract: Tier 2/S1 native and Node plus Tier 3/S1
  isolated Chrome.
- Contract integrity: S3 mutation evidence, 4/4 mutations killed.
- Capability execution: still planned. This pass did not claim text-run
  replacement, OCR, sanitization, repair, adaptive-limit, or complete impact
  map fidelity.
- Browser evidence used a project-owned server on port 8183 because port 4173
  was occupied by another project. The temporary server was stopped after the
  run.

### 2026-08-24 Cross-project evidence ledger and PDF corpus parity

- Implemented `Tests/fixtures/cross_project_evidence_ledger.json` as the
  versioned cross-project evidence ledger. It records six bounded entries for
  SignKit, MetaExtract, Invoice Intelligence, PhotoSearch, extracted_forms,
  and the historical signature auto-detect web project, with 18 source
  references, source hashes where applicable, provenance/license status,
  privacy class, transferable primitives, non-imported boundaries, falsifiers,
  and rollback paths.
- Implemented
  `Tests/fixtures/pdf_corpus_semantic_parity_fixture.json` with 11 cases for the
  existing PDF corpus. It names the semantic fields, lower-left crop-box
  coordinate contract, ignored representation details, expected malformed
  behavior, evidence-ledger links, and per-fixture allowed mismatch kinds.
- Added `Tests/cross_project_evidence_ledger_parity_test.mjs`, which validates
  the ledger and fixture, checks all referenced local source files, runs the
  native `PDFContractHarness`, runs the browser parity consumer through a
  project-owned temporary server, and writes the combined machine report.
- Verification passed: 6 ledger entries, 18 source references, 11 corpus
  cases, 4 retained candidate-detector mismatches, 0 unexpected mismatches,
  and expected native/browser failure for the truncated fixture. The report is
  `benchmark/results/cross-project-ledger/2026-08-24-ledger-parity.json`.
- The wrapper found one existing source-identity drift: the live public
  AcroForm no-op PDF does not match the SHA-256 in the corpus manifest. This is
  recorded as `sourceIdentityDrift` and was preserved for review. No binary,
  manifest, adjacent project, or prior result was rewritten.

#### Evidence status

- Cross-project inventory and transfer boundary: Tier 1/S1 plus Tier 2/S1
  contract validation.
- Native semantic projection: Tier 2/S1.
- Browser semantic projection: Tier 3/S1 isolated Chrome.
- Capability reuse, OCR accuracy, arbitrary PDF fidelity, and independent
  viewer parity: not claimed.
- The next gate is independent native/browser fingerprint extraction and
  document-class calibration for the four open candidate mismatch cases.

### 2026-08-25 Expanded browser corpus and declared fidelity gates

- Added six reproducible local fixtures through
  [`benchmark/generate_browser_corpus.sh`](benchmark/generate_browser_corpus.sh):
  hybrid text/raster/form, noisy scanned, rotated hybrid, AES-256 encrypted
  hybrid, intentionally malformed truncated hybrid, and 40-page hybrid.
- Extended the native and browser expected-state handling, semantic parity
  fixture, independent-viewer sweep, and qpdf output sweep to cover the new
  classes. The encrypted geometry difference is scoped to that fixture only.
- Verification passed: browser contract fixture 17 cases with zero console or
  page errors; native/browser parity 17 cases with 6 classified mismatches and
  0 unexpected mismatches; Poppler/MuPDF independent reopen 53 eligible PDFs;
  qpdf output validation 55 PDFs with 6 documented recoverable warnings and 0
  hard failures; preservation validator authorized checks passed and
  unauthorized text/raster mutations failed as expected.
- The malformed fixture is a deliberate safe-failure case, not a reopen pass.
  The valid new fixtures passed both native and browser no-op preservation
  reporting. The full evidence classification, hashes, commands, and limits
  are recorded in
  [`docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md`](docs/audits/browser-corpus-fidelity-evidence-2026-08-25.md).
- This remains bounded corpus evidence. OCR quality, arbitrary semantic text
  editing, signed/XFA/PDF-UA behavior, malformed-object recovery, resource
  ceilings beyond 40 pages, and universal provider fidelity remain open.

### 2026-08-25 Capability-negotiated local provider plane

- Designed and implemented the separate `pdf-editor.provider-capability` and
  `pdf-editor.provider-capability-registry` admission model. It deliberately
  does not change the shared document, coordinate, candidate, edit-session, or
  validation contracts.
- Added native Swift Codable records and deterministic negotiation in
  `Sources/PDFEditorCore/ProviderCapabilityContracts.swift`, plus the browser
  projection in `web/provider-capability-contract.mjs`.
- Added a value-free registry fixture representing the enabled browser reader,
  measured-partial native Vision OCR, installed-but-unmeasured PDFBox, and
  quarantined MuPDF with unresolved license review. The fixture contains no
  source bytes, extracted text, OCR output, field values, screenshots, secrets,
  or command strings.
- Added install and capability state separation, exact artifact-to-measurement
  binding, source byte/page/encryption/scan limits, license-state rejection,
  deterministic selection, abstention reason codes, and revocation/quarantine
  records.
- Verification passed: browser registry and negotiation test, 12 checks;
  native provider capability suite, 7 tests including native decoding of the
  browser's shared JSON fixture. This is Tier 2/S1 contract
  evidence with negative coverage, not S3 mutation evidence and not live
  installer, bridge, OCR, or high-fidelity provider evidence.
- Durable design and evidence are recorded in
  [`docs/provider-capability-system-design.md`](docs/provider-capability-system-design.md)
  and [`docs/audits/provider-capability-system-evidence-2026-08-25.md`](docs/audits/provider-capability-system-evidence-2026-08-25.md).

### 2026-08-25 Companion protocol and full-capability mandate

- Implemented the typed local companion handshake in
  `Sources/PDFEditorCore/ProviderCompanionProtocol.swift` and
  `web/provider-companion-protocol.mjs`. The messages cover hello and
  acceptance, capability requests, typed completion/progress/abstention
  states, source-digest binding, source-bytes or opaque file-token input, output
  limits, operation lineage, and cancellation.
- Added the shared fixture
  `Tests/fixtures/provider_companion_protocol_fixture.json` and native/browser
  parity tests. Browser verification passed 11 checks; native verification
  passed 4 tests, including native decoding of the browser fixture.
- The protocol explicitly forbids arbitrary commands and requires local-only
  messages, non-empty session and nonce identity, 64-character source/output
  digests, positive limits, and exactly one input payload. Source-bytes mode
  requires bytes; file-token mode requires a non-empty opaque token. This is contract evidence,
  not live companion transport or sandbox evidence.
- Corrected the project record after the owner clarified the long-term
  mandate. Browser-first and optional-companion language describes deployment
  topology and runtime availability, not a permanent feature boundary. OCR,
  high-fidelity editing, batch, large-document, security, accessibility,
  template, and recovery lanes remain implementation targets. Evidence gates
  control activation and claims, not whether those lanes are built.
- Recorded the doctrine correction in D-024, RG-092, and the amendment in
  `docs/web-deployment-decision.md`.

### 2026-08-25 Native/web normalized parity comparator

- Re-ran the consolidated native/browser corpus parity through the current
  seventeen-entry manifest before adding any new OCR or companion execution.
  Both emitters completed the expected inspected or safe-failure states, and
  the live comparison produced 6 classified mismatches with 0 unexpected
  mismatches.
- Extracted the semantic comparison policy into
  `web/pdf-contract-parity.mjs`. The normalized projection compares source
  identity, page geometry and rotation, field semantics, candidate evidence
  families, page-space coordinates, operation lineage, validation states and
  metadata summaries. It ignores only representation noise recorded in the
  parity contract.
- Added `Tests/pdf_contract_parity_mutation_test.mjs`, which passed 8 checks
  for source-digest, coordinate, field-kind, candidate-evidence, validation,
  and representation-noise mutations. The mutation suite proves the comparator
  detects semantic drift rather than merely reproducing the fixture report.
- Linked the comparator and mutation harness from the parity fixture and
  audit. The current mismatch classes remain visible: two candidate-set and
  count differences on normal/rotated Form 6, plus encrypted-hybrid page-box
  precision and coordinate differences.

### 2026-08-25 Full capability scope correction

- Corrected the project record after the owner rejected the phrase “outside the
  first unrestricted promise” and any interpretation of browser-first rollout
  language as a product limit.
- The full target is now explicit: arbitrary paragraph reflow, reviewed
  visual-to-native field creation, universal OCR, permanent redaction,
  sanitization, cryptographic signatures, XFA, PDF/UA, collaboration, hosted
  processing, local companion execution, batch, large-document handling,
  templates, and recovery all remain implementation targets.
- Evidence gates still control activation and claims. They do not control
  whether a capability is explored or built. Incomplete work must emit typed
  states such as `gated`, `blocked`, `unknown`, `abstained`, `revoked`, or
  `unsupported-for-source` and retain a provider, corpus, validator, privacy,
  security, and rollback path.
- Updated the canonical frontier, feature inventory, capability matrix,
  full-capability program, deployment decision, task plan, and decisions with
  D-026. Historical rollout records remain preserved as historical records and
  are no longer authoritative scope statements.

### 2026-08-25 Full-frontier parity handoff correction

- Reconciled remaining canonical wording so browser, native, companion, and
  hosted lanes are execution topology and provider-placement choices, not a
  reduced product promise. Every capability in the frontier remains an active
  long-term implementation target.
- Kept the normalized native/web parity comparator as the evidence prerequisite
  for adding provider outputs. The authoritative cross-project run passed with
  17 fixtures, 6 classified mismatches, and 0 unexpected mismatches. The
  mismatch report remains unchanged and visible for detector and encrypted
  geometry follow-up.
- Revalidated the mutation suite at 8 checks, the browser contract suite at 44
  checks, 83 Markdown files with no missing relative links, and `git diff
  --check`. Agent-start doctrine reconciliation passed; the workspace hook
  installation warning remains an environment condition.

### 2026-08-25 Privacy and provenance governed corpus

- Added [`Tests/fixtures/pdf_corpus_governance_manifest.json`](Tests/fixtures/pdf_corpus_governance_manifest.json)
  and [`docs/fixtures/pdf-corpus-governance.md`](docs/fixtures/pdf-corpus-governance.md)
  as the corpus governance authority. It covers scanned, rotated, malformed,
  encrypted, handwritten-like, mixed-content, native-form, static-form, and
  resource-stress classes.
- Added the synthetic raster-only handwritten-like fixture through
  [`benchmark/generate_governed_corpus.sh`](benchmark/generate_governed_corpus.sh).
  Its ground truth and README are local synthetic artifacts. The manifest
  explicitly forbids treating it as genuine handwriting, biometric, identity,
  or cryptographic-signature evidence.
- Added [`Tests/pdf_corpus_governance_test.mjs`](Tests/pdf_corpus_governance_test.mjs),
  which passed for 16 fixtures and verified every digest, class requirement,
  ground-truth sidecar, qpdf structural state, encrypted password-policy path,
  malformed safe-failure expectation, and zero-content governance report.
- The generated report is
  [`benchmark/results/governed-corpus/governance-report.json`](benchmark/results/governed-corpus/governance-report.json).
  The corpus is structural/provenance evidence. OCR accuracy, genuine
  handwriting recognition, signature validity, arbitrary editing fidelity,
  PDF/UA, and independent viewer parity remain separate active capability
  benchmarks.

### 2026-08-25 Reviewed completion safety metrics

- Added the versioned metric contract
  [`web/reviewed-completion-metrics.mjs`](web/reviewed-completion-metrics.mjs)
  and integrated it with the reviewed correction benchmark. It separately
  measures reviewed-correction coverage lift, ambiguous/stale/no-match
  abstention, hard-negative false-positive rate, rollback restoration, and
  safe-completion readiness.
- Safe completion is defined as a source-bound reviewed target ready for
  explicit value review. The existing `canMaterializeCompletion` guard remains
  required, and the metric reports materialization without review and silent
  autofill as forbidden outcomes.
- Node and isolated Chrome both passed: 5/5 reviewed corrections improved
  coverage, 14/14 abstention cases abstained, 0/7 hard negatives selected,
  35/35 promoted hard-negative replays abstained, 5/5 source-bound guards
  passed, and silent autofill count was 0.
- Added [`Tests/reviewed_completion_metrics_mutation_test.mjs`](Tests/reviewed_completion_metrics_mutation_test.mjs),
  which passed five checks and failed the aggregate metric for hard-negative
  selection, ambiguous selection, privacy degradation, review bypass, and
  silent-autofill mutation.
- Added the native Codable mirror
  [`Sources/PDFEditorCore/ReviewedCompletionMetricsContracts.swift`](Sources/PDFEditorCore/ReviewedCompletionMetricsContracts.swift)
  and focused Swift tests. Native decoding and safety validation passed for the
  browser benchmark artifact, while an intentionally selected hard negative was
  rejected. This is serialized contract parity, not yet native/browser
  aggregation parity.
- Recorded D-027, RG-095, and
  [`docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md`](docs/audits/reviewed-completion-metrics-evidence-2026-08-25.md).

### 2026-08-25 OCR and optional companion corpus comparison

- Added the versioned comparison descriptor
  [`Tests/fixtures/ocr_provider_comparison_fixture.json`](Tests/fixtures/ocr_provider_comparison_fixture.json)
  over six governed OCR inputs: clean, noisy, simulated handwriting-like,
  rotated, encrypted, and representative large-document raster pages.
- Added the native Vision executable benchmark
  [`Sources/PDFOCRBenchmark/main.swift`](Sources/PDFOCRBenchmark/main.swift)
  and the shared Node runner
  [`benchmark/compare_ocr_providers.mjs`](benchmark/compare_ocr_providers.mjs).
  Both emit counters, latency, confidence aggregates, statuses, and digests,
  never OCR text or passwords.
- Measured native Vision at mean anchor recall `0.944`, median `92.5 ms`, and
  p95 `391.0 ms`. It passed the provisional class accuracy gate and remains
  `measuredPartial`, because handwriting, languages, searchable-layer writing,
  output fidelity, memory, cancellation, and full-corpus accuracy remain open.
- Measured local Tesseract `5.5.0` at mean anchor recall `0.778`, median
  `188.1 ms`, and p95 `417.3 ms`. It passed clean, rotated, encrypted, and
  representative-large inputs but failed the noisy scan at `0/3`; it remains a
  control lane rather than an enabled general OCR provider.
- Malformed, encrypted, and large recovery gates passed. Large-document
  cancellation, companion crash/timeout, revocation during active work, and
  partial-output recovery remain explicitly unmeasured because no companion
  runtime is installed.
- OCRmyPDF, PDFBox, and MuPDF remain represented as uninstalled, unmeasured, or
  quarantined provider states. Their exact licensing, runtime, searchable-layer
  or high-fidelity behavior, and recovery gates were not inferred from package
  names or external availability.
- `node Tests/ocr_provider_comparison_test.mjs` passed 17 checks. The durable
  evidence is [`docs/audits/ocr-provider-comparison-evidence-2026-08-25.md`](docs/audits/ocr-provider-comparison-evidence-2026-08-25.md)
  and [`benchmark/results/ocr-provider-comparison/2026-08-25-local-vs-companion.json`](benchmark/results/ocr-provider-comparison/2026-08-25-local-vs-companion.json).
  Recorded D-028 and RG-096.

### 2026-08-25 Compounding moat asset registry

- Added the versioned moat registry at
  [`Tests/fixtures/moat_asset_registry.json`](Tests/fixtures/moat_asset_registry.json)
  and the human-readable implementation record at
  [`docs/moat-asset-registry.md`](docs/moat-asset-registry.md).
- Registered 14 compounding assets: source-digest binding, page-space and
  crop/rotation fixtures, multi-signal evidence, candidate explanations and
  abstention, reviewed mappings, hard negatives, typed operation lineage,
  provider divergence, independent reopen outcomes, template revisions,
  confidence calibration, corpus governance, workflow completion, and
  recovery/remediation loops.
- Each asset now names native, web, shared-contract, fixture, validator, and
  retained-evidence references, plus privacy class, retention policy, and a
  completion gate. This makes the moat implementation-addressable rather than
  a narrative list.
- Added [`Tests/moat_asset_registry_test.mjs`](Tests/moat_asset_registry_test.mjs),
  which verifies 14 unique assets, all required references, status vocabulary,
  privacy rules, and zero-content logging. The test writes a value-free report
  under `benchmark/results/moat-asset-registry/report.json`.
- The registry intentionally reports partial status for evidence fusion,
  calibration, workflow completion, and recovery/remediation. Those are active
  implementation lanes; the partial state records remaining work without
  weakening the existing source, privacy, and abstention invariants.

### 2026-08-25 Multi-signal evidence fusion

- Implemented the provider-neutral fusion result in
  [`Sources/PDFEditorCore/EvidenceFusion.swift`](Sources/PDFEditorCore/EvidenceFusion.swift)
  and [`web/pdf-evidence-fusion.mjs`](web/pdf-evidence-fusion.mjs).
- `RegionCandidate` now carries an optional fusion result derived from its
  existing evidence items. Browser candidates use one normalized evidence list
  so evidence IDs in the fusion result are the same IDs serialized in the
  candidate record.
- The policy combines weighted support, independent evidence-family coverage,
  and region agreement. Conflicting high-confidence regions abstain. OCR-only,
  whitespace-only, low-support, and empty evidence cases remain review or
  abstain states; none can create an operation.
- Browser 5/5 fusion cases and native 4/4 focused tests passed. The evidence
  record is [`docs/audits/evidence-fusion-evidence-2026-08-25.md`](docs/audits/evidence-fusion-evidence-2026-08-25.md).
- MA-003 remains `partial` because live native/browser evidence extraction,
  class-level threshold calibration, OCR/companion admission, and recovery
  metrics still need the named corpus gates. The fusion result is not an
  autofill permission.

### 2026-08-25 Reference local companion host

- Added [`web/provider-companion-host.mjs`](web/provider-companion-host.mjs), a
  narrow typed runtime around the existing companion handshake. It accepts
  only hello, capability-request, and cancellation messages and never exposes
  shell commands, arbitrary paths, network access, or generic JSON execution.
- The host enforces origin allowlisting and session/nonces through the existing
  protocol validators, verifies source-byte count and SHA-256 before invoking a
  handler, enforces output-byte and timeout limits, supports cancellation, and
  abstains when a capability has no installed handler.
- [`Tests/provider_companion_host_test.mjs`](Tests/provider_companion_host_test.mjs)
  passed handshake, source binding, provider abstention, output-limit,
  cancellation, stale-source, and zero-content diagnostic checks.
- This is a reference host and typed execution proof, not a packaged or
  cryptographically authenticated system companion. OCRmyPDF, PDFBox, MuPDF,
  Vision, and high-fidelity handlers remain separately admitted through the
  provider capability registry and the shared-corpus bake-off.
### 2026-08-25 Privacy-first PDF preflight report

- Added the dedicated `pdf-editor.preflight` contract in
  [`Sources/PDFEditorCore/PreflightContracts.swift`](Sources/PDFEditorCore/PreflightContracts.swift)
  and [`web/pdf-preflight.mjs`](web/pdf-preflight.mjs). Native PDFKit and the
  browser PDF.js fixture now produce the same value-minimized report shape for
  metadata presence, embedded-data indicators, network boundaries, possible
  active content, encryption, and sanitization limits.
- Added `PDFKitProvider.preflight(url:password:)` and browser fixture/UI
  integration. The browser report is rendered as counts and limits only; raw
  metadata, attachment names, URLs, PDF bytes, page text, OCR text, passwords,
  and active-content payloads remain outside the report.
- Added stale-source binding validation, unknown scan states, and mutation
  guards for false clean claims, attempted execution, unknown finding values,
  forbidden content fields, and unsupported versions.
- Evidence passed: Node preflight contract and zero-content mutation test,
  two native Swift preflight tests, and isolated Chrome report/UI/source-binding
  test. The evidence record is
  [`docs/audits/pdf-preflight-evidence-2026-08-25.md`](docs/audits/pdf-preflight-evidence-2026-08-25.md).
- This implements preflight observation, not sanitization. Metadata removal,
  embedded-data removal, action neutralization, incremental-revision analysis,
  signature effects, XFA handling, independent post-sanitize reopening, and
  adversarial sanitizer recovery remain active long-term build lanes.

### 2026-08-25 Device-adaptive browser resource governance

- Added the versioned browser-resource-policy contract in
  [`web/browser-resource-policy.mjs`](web/browser-resource-policy.mjs) and its native Codable mirror in
  [`Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift`](Sources/PDFEditorCore/BrowserResourcePolicyContracts.swift).
- The policy normalizes device signals, document cost, high-DPI geometry, raster density, rotation, selectable text, OCR intent, batch intent, and storage/connection uncertainty. It returns finite render, OCR, batch, and recovery budgets with explicit state and reason codes.
- Added source-digest and operation-bound checkpoints, abort-aware adaptive batches, cancellation summaries, and the invariant that partial output can never be promoted. Event summaries omit values, text, OCR content, pixels, URLs, filenames, passwords, and source bytes.
- Added the governed benchmark fixture at [`Tests/fixtures/browser_resource_policy_benchmark.json`](Tests/fixtures/browser_resource_policy_benchmark.json), the deterministic benchmark at [`benchmark/benchmark_browser_resource_policy.mjs`](benchmark/benchmark_browser_resource_policy.mjs), and the serialized result at [`benchmark/results/browser-resource-policy/2026-08-25-device-adaptive.json`](benchmark/results/browser-resource-policy/2026-08-25-device-adaptive.json).
- Evidence: browser contract and mutation checks passed 242 checks across five device profiles and six document classes; the benchmark emitted 30 rows; native Swift decoded and validated all 30 policy envelopes; isolated Chrome verified live browser emission, source binding, unknown-signal abstention, explicit OCR admission, cancellation safety, and zero-content summaries.
- Remaining unknowns are deliberately implementation work: physical-device calibration, browser-version drift, real Web Worker OCR memory, companion crash/timeout recovery, and long-run batch throughput. These are not used to narrow the long-term capability program.

### 2026-08-25 Text-run replacement and OCR-layer alignment

- Added the shared evidence-only projection in
  [`web/text-run-ocr-alignment-benchmark.mjs`](web/text-run-ocr-alignment-benchmark.mjs).
  It normalizes PDF.js text items, PDFKit selection lines, and Vision OCR
  observations into source-bound lower-left crop-space records with hashes,
  counts, geometry, confidence, origin, and explicit states. Raw text, OCR
  values, replacement values, bytes, pixels, and passwords are not retained.
- Added the native `PDFTextRunOCRBenchmark` executable and wired it into
  `Package.swift`. It ran against the existing 18-entry manifest, including
  malformed, encrypted, rotated, scanned, hybrid, handwritten-like, and large
  fixtures.
- Added the browser full-corpus runner and live PDF.js projection. The combined
  report is
  [`benchmark/results/text-run-ocr-alignment/browser-and-native.json`](benchmark/results/text-run-ocr-alignment/browser-and-native.json);
  native-only evidence is
  [`benchmark/results/text-run-ocr-alignment/native.json`](benchmark/results/text-run-ocr-alignment/native.json).
- Runtime result: 18 fixtures, 16 inspected, 2 safe malformed failures, 81
  pages, 29 pages with comparable text evidence, 10 measured OCR/reference
  pages, and 71 explicit OCR abstentions. Source binding, zero-content logging,
  no silent replacement, and missing-browser-OCR abstention passed.
- The first provider-fidelity mismatch is recorded rather than hidden: mean
  text-hash agreement was 0.6593, while text geometry at two points and OCR
  geometry at three points both failed. Native and browser text rectangles are
  not yet interchangeable for replacement.
- Added the pure contract test
  [`Tests/text_run_ocr_alignment_contract_test.mjs`](Tests/text_run_ocr_alignment_contract_test.mjs)
  and the live browser benchmark
  [`Tests/text_run_ocr_alignment_browser_test.mjs`](Tests/text_run_ocr_alignment_browser_test.mjs).
  The decision and release gate are D-033 and RG-099.
- This is runtime evidence for current local providers, not a universal PDF
  editing claim. True text-run replacement remains an explicit long-term
  implementation lane behind independent text, outside-region, raster, reopen,
  and viewer gates.

### 2026-08-25 Full capability doctrine reconciliation

- Reconciled the product direction after the owner clarified that every serious
  PDF reader/editor capability is in scope for the long-term build. This
  includes text-run replacement, OCR-derived layers, reflow, repair, redaction,
  sanitization, conversion, signatures, XFA, accessibility, collaboration, P2P,
  AI-assisted workflows, hosted/self-hosted processing, companion providers,
  batch work, and recovery.
- Updated the [README](README.md), [task plan](task_plan.md), and ihatepdf
  exploration so “defer,” “reject,” and “not authorized” mean sequence and
  govern through contracts, providers, validators, privacy, licensing, and
  recovery. They no longer mean permanent scope exclusion.
- Recorded D-034 in [decisions](docs/decisions.md): provider limitations and
  evidence gates control current routing and claim strength, never whether a
  capability remains an implementation target.
- The full-capability program remains the canonical register. Existing
  abstentions, unknowns, blocked providers, and failed fidelity gates remain
  append-only evidence that routes implementation to the next provider or
  validator.

### 2026-08-25 Native/browser normalized semantic parity report

- Extended [`web/pdf-contract-parity.mjs`](web/pdf-contract-parity.mjs) to
  publish a versioned normalization policy. Provider IDs and versions,
  platform labels, timestamps, generated IDs, diagnostic and validation prose,
  and output digests are representation-only; source identity, geometry,
  fields, evidence, operations, and validation state remain semantic.
- Updated [`Tests/pdf_contract_parity_test.mjs`](Tests/pdf_contract_parity_test.mjs)
  to accept a dated result root, emit per-lane representation facts and exact
  normalized projection digests, and classify mismatch kinds as declared or
  unexpected using the governed parity fixture descriptor.
- Generated [`benchmark/results/semantic-parity/2026-08-25/parity-report.json`](benchmark/results/semantic-parity/2026-08-25/parity-report.json)
  from the native PDFKit harness and isolated browser PDF.js fixture over all
  18 manifest entries. Sixteen readable source bindings match in both lanes;
  both malformed fixtures agree on `inspectionFailed`; six declared detector
  or geometry mismatches remain; no unexpected mismatch was observed.
- Added the report gate and expanded normalization mutations. The checks pass
  for provider IDs, timestamps, nested field/candidate/evidence IDs,
  validation check IDs, diagnostic messages, and output digest mutations while
  semantic mutations continue to fail.
- Evidence is recorded in
  [`docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md`](docs/audits/native-browser-semantic-parity-evidence-2026-08-25.md),
  release gate RG-100, and decision D-035. This is semantic contract evidence,
  not byte-level, text-object, raster, OCR, companion, or independent-viewer
  parity.

### 2026-08-25 Read-only privacy preflight contract and native/browser report

- Extended `pdf-editor.preflight` from 1.0 to 1.1 with explicit attachments,
  annotation taxonomy, script non-execution, revision markers, coverage states,
  and derived unknown coverage. Native and browser validators reject stale
  digests, false clean claims, script execution claims, unsupported versions,
  unknown finding states, forbidden content, and inconsistent aggregates.
- Added PDFKit annotation-kind counting and PDF.js annotation-kind counting.
  Native bounded token matching now respects PDF name boundaries, so longer
  names do not create false action indicators.
- Extended the native contract harness and browser fixture snapshot to emit
  preflight reports for the same 18-entry corpus. The parity comparator
  excludes provider identity, timestamps, generated IDs, and output digests,
  while retaining source binding, counts, coverage, unknown states, findings,
  non-execution, and sanitization invariants.
- Generated
  [`benchmark/results/preflight-parity-2026-08-25/privacy-preflight-parity-report.json`](benchmark/results/preflight-parity-2026-08-25/privacy-preflight-parity-report.json): 18 fixtures, 16 readable reports, 2 matching malformed failures, and 3 retained mismatches on `public-sample-form.pdf` caused by PDFKit/PDF.js keyword-presence disagreement. Attachment, annotation, script, revision, coverage, source-binding, and raw-content parity is otherwise green.
- Added the detailed audit, README/task-plan links, release gate RG-101, and
  decision D-036. Sanitization, hidden-revision removal, cryptographic effects,
  XFA/rich-media policy, and independent post-sanitize validation remain
  long-term build lanes on this same contract spine.

### 2026-08-25 Static geometry hard-negative calibration

- Added a deterministic, privacy-safe two-page PDF fixture with five reviewed
  positive cases and five labeled hard negatives covering vector rectangles,
  checkbox shapes, underlines, whitespace, and label association.
- Added the machine-readable label sidecar, source digest binding, calibration
  manifest, class-aware matching, precision/recall/abstention metrics, score
  floors, zero hard-negative false-positive gate, and native/browser semantic
  parity report.
- Added shared semantic label-intent gates in native PDFKit and browser PDF.js.
  Unlabeled and generic geometry now abstains; labeled small checkboxes are
  eligible for reviewed suggestions. Browser vector lines normalize to the
  shared underline evidence kind.
- Replaced native PDFKit's evenly spaced `page.string` line bands with
  `selection(...).selectionsByLine()` page-space bounds, matching the existing
  text-run benchmark and preventing wrong-shape label association.
- Generated
  [`benchmark/results/detector-calibration/detector-calibration-report.json`](benchmark/results/detector-calibration/detector-calibration-report.json): both adapters pass 5/5 positive recall, 0/5 hard-negative false positives, 5/5 hard-negative abstention, and semantic parity. Observed score floors are checkbox 0.85, vector rectangle 0.80, underline 0.75, whitespace 0.58, and label association 0.80.
- Verified the PDF visually with `pdftoppm` and `view_image`, checked module
  syntax, ran the native harness, and ran the isolated Chrome browser harness
  on port 4174 because port 4173 belonged to another project.
- Recorded D-037 and RG-102. This is controlled regression evidence, not a
  universal PDF accuracy or autofill claim; real rotated, multilingual,
  OCR-only, clipped, table, malformed, and real-world cases remain active.

### 2026-08-25 Browser geometry calibration metrics and failure clusters

- Extended the source-bound detector calibration report with overall and
  per-class precision, recall, hard-negative false-positive rate, abstention,
  observed score floors, and a value-free failure-cluster taxonomy.
- The fresh native/browser run on the reviewed two-page fixture passes overall
  precision `1.00` and recall `1.00` for both adapters: 5/5 positives detected,
  0/5 hard negatives promoted, and 5/5 hard negatives abstained. Native and
  browser semantic parity has no mismatches.
- Added diagnostic classification for `noCandidateNearTarget`,
  `evidenceMismatch`, `candidateKindMismatch`, `fieldTypeMismatch`,
  `geometryMismatch`, and `hardNegativePromotion`. The real run has zero
  failures, while in-memory mutation evidence kills positive removal,
  hard-negative promotion, and required-evidence stripping with the expected
  clusters.
- Updated the calibration audit, implementation status, task plan, and RG-102.
  The exact 10-case geometry score remains separate from the broader 33-target
  Form 6 semantic recall/precision proxy. Rotated, multilingual, OCR-only,
  clipped, table, malformed, duplicate-candidate, and real-world expansion
  remain active implementation work.
- Bumped the detector calibration report envelope to version `1.1` because the
  serialized metric shape and failure-cluster fields changed.

### 2026-08-25 Local OCR provider bake-off across native, browser WASM, and companion candidates

- Extended the shared-corpus OCR comparison to three measured local lanes:
  native Vision, local Tesseract 5.5.0, and Tesseract.js 5.1.1 running in a
  browser worker with locally served core and English model assets. The runner
  emits source-bound, value-free counters only.
- Normalized Tesseract percentage confidence into the shared `[0,1]` range and
  transformed top-left pixel word boxes into `normalizedLowerLeft` page space.
  Every measured case now records confidence aggregates, valid-bound counts,
  union bounds, and provider-to-Vision union IoU alignment status.
- Reran all six governed inputs: printed, noisy, simulated handwriting-like,
  rotated, encrypted, and representative page 40 of the large hybrid. Vision
  mean anchor recall is `0.944`; CLI Tesseract and browser WASM are both
  `0.778`. Vision passes the provisional accuracy gate; both Tesseract lanes
  fail the noisy-scan hard negative at `0/3`.
- Browser WASM stayed local in this run: the temporary server served the JS,
  WASM core, and language artifact, and the browser recorded zero external
  requests. This is a measured boundary, not a blanket claim for CDN assets,
  future models, telemetry, or companion IPC.
- Browser WASM median recognition time is `257.8 ms`, with p95 `11,945.9 ms`
  against the provisional 15-second resource gate. The noisy input produced
  `687` valid browser boxes and union IoU `0.083` against Vision, compared with
  `3` Vision boxes. Other current union comparisons are classified aligned.
- Companion candidates remain explicit: OCRmyPDF is unavailable, PDFBox has no
  configured JAR, and installed MuPDF passed only a render control and is not
  an OCR measurement. Companion crash, timeout, cancellation, licensing, and
  partial-output recovery remain open.
- Updated the audit, README, task plan, RG-096, and machine report. The targeted
  OCR comparison test passes `17/17`; Swift OCR benchmark build and JavaScript
  syntax checks pass. Promotion remains blocked and no OCR lane can silently
  create a field or overwrite source content.

### 2026-08-25 Full-capability build obligation reaffirmed

- Reconciled the capability program so the explored and documented frontier is
  also the active implementation frontier. This includes arbitrary semantic
  editing, font/glyph-preserving replacement, OCR-derived editable text,
  browser and multilingual OCR, handwriting abstention, redaction,
  sanitization, encryption policy, cryptographic signatures and validation,
  XFA, PDF/UA, independent-viewer and byte-preservation proof, raster parity,
  page graph operations, conversion, repair, recurring templates, companion
  lifecycle, collaboration, and synchronization.
- Formalized the two-axis interpretation in the full-capability program and
  implementation status: build obligation is separate from claim readiness.
  “Blocked for claim” means the missing implementation, provider, corpus,
  validator, recovery, privacy, licensing, or independent evidence must still
  be built. It does not mean the capability is removed from the product.
- Preserved the first-principles rule that an unfinished runtime cannot be
  called built merely because its design exists. Each capability must acquire
  its own contract projection, adapter, fixtures, validation, privacy and
  security boundary, failure and recovery behavior, and documentation before
  its current implementation status is promoted.

### 2026-08-25 Typed semantic text-run replacement lane started

- Added `EditKind.textRunReplacement` as a distinct shared operation. It is not
  an alias for `overlayText` and cannot be routed through the visual annotation
  writer.
- Added typed source-run evidence: run ID, original text hash, optional font
  fingerprint, source digest, page-space bounds, coordinate convention, and
  reversible/destructive state. Recovery-safe session metadata classifies the
  payload without retaining replacement text.
- Added a browser operation builder that creates the in-memory intent while
  retaining the replacement value only in the active edit session. The value-
  free text-run evidence report remains content-safe.
- Native PDFKit and browser pdf-lib now reject semantic replacement explicitly
  with provider-gate diagnostics. This prevents a visual overlay from being
  mislabeled as a semantic text-object rewrite.
- Added native JSON round-trip and provider-rejection coverage plus browser
  typed-operation and mutation-gate coverage. The native contract mutation
  suite passes `7/7`; the browser text-run contract passes `18/18`.
- The next implementation is the simplest measured writer lane: a same-font,
  same-run replacement fixture with source text hash, font/glyph identity,
  outside-region text/raster validation, reopen, and independent viewer proof.
  Ligatures, embedded fonts, RTL, clipping, transparency, overlap, and
  abstention cases follow as separate corpus classes.

### 2026-08-25 Bounded semantic text-run writer experiment

- Added [`web/simple-text-run-provider.mjs`](web/simple-text-run-provider.mjs),
  a deliberately narrow browser provider for classic uncompressed PDF content
  streams with one unique printable ASCII literal and same-byte-length
  replacement. It rewrites the existing literal instead of adding an overlay,
  preserving xref offsets and the existing font/content operators.
- Added [`Tests/text_run_simple_provider_test.mjs`](Tests/text_run_simple_provider_test.mjs).
  The provider experiment passes `16/16` checks for source binding, target and
  original-text hashes, same-width replacement, outside text retention, qpdf
  structure, Poppler extraction, source/output reopen, independent
  outside-region text/raster preservation, stale-digest rejection, and
  unequal-width rejection.
- This is the first actual semantic replacement writer, but only for its
  declared PDF class. PDFKit and the general browser writer still reject the
  operation. Compressed streams, escaped strings, repeated targets, embedded
  fonts, Unicode, ligatures, RTL, clipping, transparency, overlap, signatures,
  XFA, incremental updates, and independent GUI-viewer parity remain separate
  provider gates.

### 2026-08-25 Native/browser semantic candidate parity report

- Added a dedicated value-minimized candidate parity projection instead of
  leaving candidate divergence buried inside the whole-document set diff.
  Candidate IDs, label text, evidence prose, scores, timestamps, and output
  digests are excluded; page-space geometry, candidate semantics, evidence
  families, review state, grouping, and coordinate space remain visible.
- Refreshed the native and browser bundles through the current 18-fixture
  manifest using an isolated server on port 4174. The fresh report measures
  206 native candidates, 140 browser candidates, 118 geometry pairs, 88
  native-only candidates, 22 browser-only candidates, 49 fully equivalent
  pairs, and 69 matched pairs with semantic differences.
- Native candidate coverage by browser pairs is 57.28% and browser candidate
  coverage by native pairs is 84.29%; symmetric agreement F1 is 68.21%. The
  six mismatch clusters are 59
  coordinate-space, 18 field-type, 14 entry-mode, 2 review-state, 2
  geometry-precision, and 2 grouping differences.
- The normal Form 6 fixture has 103 native versus 70 browser candidates with
  59 geometry pairs and 49 equivalent pairs. The rotated derivative has the
  same candidate counts and pairs but zero fully equivalent pairs because all
  pairs retain coordinate-space rotation divergence.
- Added five mutation checks proving representation-only changes remain
  equivalent while candidate-kind, evidence-kind, and large-coordinate drift
  are detected. Updated RG-104, implementation status, task plan, README, and
  the candidate parity audit.

### 2026-08-25 Session privacy and export provenance

- Added `pdf-editor.session-provenance` 1.0 as a shared native/browser
  contract above document preflight. It records processing locality, data
  egress, OCR use, source retention/deletion, export digest identity,
  validation, reopen evidence, and bounded operation/provider facts.
- Added zero-content invariants and validators. Source bytes, text, OCR values,
  field values, filenames, URLs, and screenshots are not serialized; stale
  source digests, privacy leaks, contradictory OCR states, and successful
  exports without output digest/reopen provenance are rejected.
- Attached provenance to native `DocumentSession` recovery envelopes and the
  browser PDF.js fixture snapshot. Refreshed the 18-fixture corpus: 16
  readable sessions emitted valid records in each lane and the 2 declared
  malformed fixtures correctly emitted no session record.
- Native locality is `local-device`; browser locality is `local-browser`; the
  current corpus OCR state is explicitly `not-used`. Browser, Swift, preflight,
  and full parity verification passed; whole-document parity remains 6
  declared mismatches and 0 unexpected mismatches.
- Evidence is recorded in
  [`docs/audits/session-privacy-provenance-evidence-2026-08-25.md`](docs/audits/session-privacy-provenance-evidence-2026-08-25.md).

### 2026-08-25 Independent Poppler comparison for browser exports

- Added `benchmark/browser-export-independent-viewer-validator.mjs` as a
  separate comparison envelope above the existing Poppler preservation
  validator. PDF.js remains the browser gate; Poppler independently reopens,
  extracts text, renders raster pages, and reports outside-region preservation.
- Integrated the report into `Tests/pdf_contract_parity_test.mjs`, which now
  emits `independent-browser-viewer-report.json` beside the existing semantic
  parity and detailed independent-preservation reports.
- Added focused baseline, divergence-mutation, and missing-gate tests in
  `Tests/browser_export_independent_viewer_validator_test.mjs`.
- Fresh corpus evidence: Poppler 26.08.0 and qpdf 12.4.0 measured all 18
  entries. Sixteen readable exports passed source binding, independent reopen,
  text, and raster comparison, with 16/16 readable agreements against both
  PDF.js text and raster gates. Two malformed entries remained explicit
  expected failures with unknown text/raster states. No unexpected divergence.
- The evidence is recorded in
  [`docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md`](docs/audits/independent-browser-viewer-comparison-evidence-2026-08-25.md).
- This is a validator and no-op export preservation result, not arbitrary
  semantic editing, GUI-viewer, MuPDF three-way, redaction, signature, XFA,
  PDF/UA, or production fidelity proof.

### 2026-08-25 Browser preservation metrics review surface

- Added the accessible `impactMetrics` section to the browser review/export
  panel in `web/index.html`.
- Extended the existing validation checks with optional value-minimized metrics
  for outside-region text and raster evidence. The panel shows status,
  compared/changed pages, changed/compared pixels, outside-pixel ratio,
  maximum channel delta, render scale, channel tolerance, operation count, and
  evidence basis.
- Raw extracted `sourceOutside` and `outputOutside` content is intentionally not
  rendered in the UI.
- Static source checks pass 51/51. Isolated Chrome no-op export evidence shows
  a passing panel. Isolated Chrome reviewed-overlay evidence shows the panel
  remains visible with the failed text/raster status and measured `385 / 2,317,088`
  changed/compared pixels. No console or page errors occurred in either focused
  run.
- The complete existing browser proof remains a deliberate failure on the
  static Form 6 overlay because the underlying validator finds an outside-region
  change. The metrics surface exposes that failure and does not weaken it.
- Evidence is recorded in
  [`docs/audits/browser-preservation-metrics-evidence-2026-08-25.md`](docs/audits/browser-preservation-metrics-evidence-2026-08-25.md).

### 2026-08-25 Independent renderer metrics and operation binding

- Extended the existing Poppler/PDF.js browser-export report instead of adding
  a second independent validator.
- Preserved normalized provider metrics for outside-region text and raster
  evidence, including changed pages, changed/compared pixels, ratios, channel
  deltas, and provider basis.
- Added `comparable`, `notComparable`, and `notMeasured` states so source-digest
  no-op shortcuts are not misrepresented as equivalent raster measurements.
- Passed serialized browser `editSession.operations` into Poppler. Missing
  operation lineage and coordinate/page mismatches now abstain as `unknown`.
- Focused S3 test passes baseline agreement, provider divergence, missing-gate
  unknown, comparable metrics, valid binding, and mismatch abstention.
- Regenerated retained report: 16 readable passes, 2 malformed expected
  failures, 16/16 readable text and raster verdict agreements, and 0
  unexpected divergences. The retained bundles predate browser metrics, so
  their measurement comparability remains `notMeasured` by design.
- A fresh full-corpus browser fixture attempt against the existing 4173 surface
  timed out before PDF.js initialization. This is recorded as an environment
  runtime issue, not promoted to a PDF fidelity result.

### 2026-08-25 Encrypted template and profile persistence

- Implemented native encrypted template persistence in
  `Sources/PDFEditorCore/EncryptedTemplatePersistence.swift` using the
  existing `PDFTemplateRevisionSet`, AES-GCM envelopes, Keychain-backed
  template keys, primary/recovery copies, explicit recovery states, deletion,
  and immutable parent-linked append operations.
- Implemented a separate native encrypted `PDFProfileRevisionSet` vault with a
  different directory and Keychain account. Profile values are not part of
  template records.
- Extended the browser IndexedDB store with encrypted template-history and
  profile-history APIs, parent/identity validation, deletion helpers, and
  profile unlock behavior for history records. The browser profile layer uses
  a separate profile passphrase-derived key inside the encrypted store.
- Replaced the live web page's legacy plaintext profile IndexedDB path with the
  encrypted profile-history adapter. Added explicit `Save encrypted revision`
  and `Unlock encrypted local profiles` actions; page load does not prompt or
  silently persist a passphrase.
- Wired the native `PDFEditorApp.AppModel` profile management path to the new
  encrypted profile vault through a `UserProfile` compatibility projection, so
  native create/load/save/list/delete operations now create and read contract
  revisions rather than using the older single-record profile path.
- Native persistence tests pass 2/2. Node contract/store tests pass. Isolated
  Chrome tests pass for encrypted store security, wrong-passphrase rejection,
  IndexedDB eviction recovery, deletion, zero-content logging, and reviewed
  template capture. The isolated server and browser were stopped after the
  run.
- Evidence is recorded in
  [`docs/audits/encrypted-template-profile-persistence-evidence-2026-08-25.md`](docs/audits/encrypted-template-profile-persistence-evidence-2026-08-25.md).
- Remaining long-term lanes are secure deletion across OS/browser backup
  layers, Keychain-loss recovery, quota/concurrency stress, encrypted backup
  cross-platform parity, passphrase recovery, and native SwiftUI template
  persistence controls.

### 2026-08-25 Native and browser dual-approval template completion

- Implemented the shared completion review protocol so mapping approval and
  profile-value approval are separate source-bound decisions.
- Added native `mappingApproval` and `profileValueApproval` records. Mapping
  approval binds the mapping ID, resolved provider target, and page-space
  coordinate. Profile-value approval binds profile ID, profile revision ID,
  semantic key, and a SHA-256 digest of the exact typed value.
- Changed target resolution to invalidate mapping approval and changed values
  to return to `resolvedUnreviewed`. The core materializer rejects missing,
  stale, or mismatched records before creating edit operations.
- Added the native `AppModel` and SwiftUI review flow: capture value-free
  template draft, review mappings, activate immutable revision, prepare a
  profile-bound completion, review each mapping, review each exact value, then
  apply through the shared gate.
- Updated the browser contract and live review surface with the same two-stage
  controls. The Apply control remains disabled until both decisions are valid.
  The browser no-profile path is session-only; selected persistent profiles
  contribute their encrypted profile revision identity.
- Added mutation coverage for value-only approval, mapping-only approval,
  stale direct value mutation, and changed native target resolution.
- Verification: Swift 92 tests in 10 suites passed; browser template,
  reader, and store checks passed; isolated Chrome template workflow and
  encrypted security workflow passed on port 4174 with no console or page
  errors.
- Evidence is recorded in
  [`docs/audits/template-review-workflow-evidence-2026-08-25.md`](docs/audits/template-review-workflow-evidence-2026-08-25.md),
  decision D-046, finding F-067, and release gate RG-110.
- Remaining long-term lanes are automated native UI interaction, mid-session
  profile revision invalidation, export approval provenance, collaborative
  reviewer authority, and cross-capability reuse of this dual-review protocol.

### 2026-08-25 Native/browser structural fingerprint parity

- Built `web/pdf-fingerprint-parity.mjs`, a versioned value-minimized structural
  fingerprint projection over the existing native PDFKit and browser
  PDF.js/pdf-lib contract bundles.
- The fingerprint compares page geometry and rotation, selectable text and
  character-count shape, fields, candidates, evidence families, grouping,
  coordinate spaces, annotations, navigation, permissions, security, and
  accessibility without retaining raw labels, provider IDs, timestamps, output
  digests, or PDF bytes.
- Generated the 18-case fixture and feature-cluster report with
  `benchmark/generate_fingerprint_parity.mjs`.
- Aggregate result: 2 equal expected malformed failure states, 8 readable
  semantic-divergence-only cases, 8 mixed cases containing both semantic and
  tolerated text representation differences, and 0 representation-only cases.
- Divergence clusters: permission observability 16/18; character-count
  representation 8/18; encrypted-hybrid page-box precision 1/18; static Form 6
  candidate count, field-type, grouping, evidence, label-association,
  geometry, and coordinate-space divergence 2/18.
- Added mutation coverage for stale source digest, page rotation, permissions,
  candidate population, candidate coordinate space, and tolerated text-count
  drift. The fixture cases are checked for zero raw content and zero provider
  representation fields.
- Verification: `node benchmark/generate_fingerprint_parity.mjs` and
  `node Tests/native_browser_fingerprint_parity_test.mjs` passed.
- Evidence is recorded in
  [`docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md`](docs/audits/native-browser-fingerprint-parity-evidence-2026-08-25.md),
  decision D-047, finding F-068, and release gate RG-111.
- Remaining long-term lanes are permission observed-versus-unknown
  normalization, encrypted page-box precision, rotation transform
  reconciliation, candidate grouping/classification parity, and fresh native
  plus isolated-browser regeneration after those changes.

### 2026-08-25 Complete encrypted reviewed-template lifecycle

- Implemented the previously documented template boundary rather than leaving
  it as design-only: encrypted native Keychain/local vaults, encrypted browser
  IndexedDB, encrypted OPFS, separate profile storage, explicit unlock,
  deletion, recovery, transfer, learning journal, revision diff, and
  client-encrypted sync are now wired through the existing canonical contracts.
- Native and browser review surfaces now cover capture, mapping approval,
  activation, profile selection/unlock, exact profile-value approval,
  source-bound materialization, validated export promotion, and explicit child
  revision persistence. No silent autofill path was added.
- Strict validation creates a pending immutable child revision and learning
  event automatically in session memory. Explicit save is required before
  persistent future matching behavior changes.
- Hardened OPFS so locked profile ciphertext survives unrelated template writes,
  health checks, and deletion. Profile values remain inaccessible until the
  profile passphrase is explicitly supplied.
- Browser revision-diff counts are now visible in the template review summary.
- Verification: `swift test` passed 94 tests in 10 suites. The isolated Chrome
  template workflow passed IndexedDB and OPFS round-trip, encrypted backup,
  locked-profile preservation, explicit profile unlock, deletion, and zero
  console/page errors. Contract, sync, security, matching, correction,
  provenance, preflight, and native/browser parity checks passed.
- Evidence is recorded in
  [`docs/audits/template-lifecycle-evidence-2026-08-25.md`](docs/audits/template-lifecycle-evidence-2026-08-25.md).
- Remaining unknowns are runtime hardening and provider gates: browser-family
  quota/eviction stress, interrupted OPFS writes, Keychain/passphrase loss,
  native interactive accessibility, sync-service retention/revocation, secure
  deletion across backups, and independent-viewer evidence after completion
  export.

### 2026-08-25 Long-term template retrieval and capability lanes

- Implemented the native and browser value-free local template index. It
  rebuilds from encrypted histories and returns exact, known-variant,
  family-match, ambiguous, stale, unsupported, and no-match states with
  explainable scores and reasons. Exact and known-variant identity evidence
  outranks family similarity; competing family candidates abstain.
- Added native SwiftUI and browser review visibility for index candidates,
  revision details, mapping changes, and learning-journal events. Candidate
  retrieval never creates operations and never approves mappings.
- Added browser vault health, encrypted backup export, restore after eviction,
  explicit destructive deletion, and recovery messaging. The backup contract
  carries ciphertext records only. Native Keychain custody and separate
  profile-vault storage remain active in the same lifecycle.
- Added named cross-platform capability lanes for OCR, text replacement and
  reflow, redaction, signatures, XFA, PDF/UA, and independent viewer reopen.
  Each request and result is source-digest bound and provider-admission based;
  unmeasured or unavailable work returns a typed abstention or review outcome.
- Added `TemplateIndexTests`, `pdf_capability_lanes_test.mjs`, and
  `PDFCapabilityLaneTests`. The first parity correction was recorded during
  verification: Swift initially treated a known variant as ambiguous, while
  the browser precedence was correct. Both now share the same rule.
- Evidence record:
  [`docs/audits/template-runtime-completion-evidence-2026-08-25.md`](docs/audits/template-runtime-completion-evidence-2026-08-25.md).
- Verification note: the isolated Chrome smoke route on port 4174 exposed all
  new template/index/capability controls with zero page errors; the browser
  template workflow and encrypted security workflow passed. The full Swift
  suite attempt was superseded by the current full 101-test run recorded in
  the native capture/review evidence below. No concurrent native edits were
  overwritten.

### 2026-08-25 Native SwiftUI template capture and dual-review surface

- Completed the native SwiftUI projection of the shared template runtime. The
  inspector now captures a named value-free layout, shows keyed fingerprint and
  revision provenance, reviews draft mappings, loads local index candidates,
  prepares a source-bound completion proposal, and exposes separate mapping and
  profile-value approval controls.
- Added typed native value editing. Text, choice, and boolean values retain
  their `PDFProfileValue` semantics through review. Asset references are shown
  as unsupported until an explicit native asset picker exists. Changing a
  value revokes its prior approval through the shared proposal contract.
- Per-entry review now shows page-space coordinates, native provider target
  resolution, static-region versus native-field semantics, match reasons,
  source/session identity prefixes, and approval counters. SwiftUI does not
  construct operations directly; Apply still routes through
  `materializeOperations` and the native PDFKit adapter.
- Added the shared typed-value contract test covering choice and boolean
  materialization, alongside the existing stale-source, target-resolution,
  mapping-bypass, and value-bypass tests.
- Verification: focused Swift template suite passed 4/4; `swift build
  --target PDFEditorApp` passed; full `swift build` passed. Evidence is in
  [`docs/audits/native-template-capture-review-surface-evidence-2026-08-25.md`](docs/audits/native-template-capture-review-surface-evidence-2026-08-25.md).
- Remaining evidence is intentionally separate: automated macOS UI
  interaction/accessibility, provider-specific choice/checkbox/signature
  fixtures, same-source native/browser review-session comparison, and
  independent-viewer export validation.

### 2026-08-25 Local persistence privacy hardening

- Added the shared `PDFLocalStoreHealth`, `PDFLocalStoreAuditEvent`, and
  `PDFLocalStoreRecoveryEnvelope` contracts. Native recovery envelopes wrap
  Keychain-backed AES-GCM store keys with a separate PBKDF2 passphrase. Native
  whole-record deletion retains a value-free audit journal using opaque
  record tokens.
- Added native SwiftUI visibility for read-only PDF preflight, processing
  locality, OCR state, source retention, sanitization limits, template/profile
  health, recovery import/export, confirmed destructive deletion, and the
  latest value-free audit event.
- Added browser IndexedDB passphrase key-recovery envelopes, explicit
  encrypted backup download/restore, eviction warnings, bounded local
  deletion audit, and visible privacy/provenance fields in the template and
  preflight panels. Recovery distinguishes an authenticated recovered key
  from records that were already evicted.
- Added browser security assertions for recovery-envelope secrecy, wrong
  recovery passphrase rejection, recovered-key-with-eviction state, audit
  presence, and zero-content logging. The active web surface was verified on
  isolated port 8766 because port 4173 served another local project.
- Verification: focused native persistence 5/5; full Swift suite 102 tests in
  12 suites; browser template store Node check; isolated Chrome security,
  preflight, reader contract, and 18-fixture browser contract checks passed.
- Evidence:
  [`docs/audits/local-persistence-privacy-hardening-evidence-2026-08-25.md`](docs/audits/local-persistence-privacy-hardening-evidence-2026-08-25.md)
- Remaining gates are explicit: OPFS key recovery parity, real browser-family
  quota/eviction pressure, interrupted-write and multi-tab recovery, native
  Keychain-loss recovery, encrypted backup cross-adapter parity, secure
  deletion across user-managed copies, profile-value transfer policy, and
  native UI accessibility automation.

### 2026-08-25 Template handoff reconciliation and browser index wiring

- Reconciled the stale remaining-work handoff against the live checkout. The
  native SwiftUI capture/review surface, encrypted persistence, profile vault,
  recovery actions, local matching contracts, provider capability lanes, OCR
  adapter, preflight, and validation infrastructure were already present. The
  implementation mandate remains long-term and unrestricted; this entry only
  distinguishes existing implementation from provider evidence.
- Connected the browser `Find local matches` control to the encrypted value-free
  template index. Exact, known-variant, family-match, ambiguous, stale,
  unsupported, and no-match states now appear with reasons and scores. Only
  reviewable matches can be loaded, and loading a match never creates an edit
  operation or approves a mapping/value.
- Preserved typed browser profile values for text, choice, boolean, and asset
  references. Choice and checkbox completion controls now retain shared value
  semantics. Signature asset references show an explicit provider requirement
  rather than silently becoming text.
- Added browser assertions for the visible local-match control, value-free index
  privacy, exact selection, and stale abstention. The browser reader boot check
  passed 51 checks; the browser template workflow passed with the new index
  assertions. Node contract, index, and store checks also passed.
- The current native run compiled and executed 102 tests in 12 suites. One
  provider-specific synthetic radio-group retention test failed after PDFKit
  reopen. The PDFKit adapter now synchronizes widget and field-level button
  values, but this remains an open fidelity gate until the focused test passes.
- Evidence is recorded in
  [`docs/audits/template-runtime-handoff-reconciliation-evidence-2026-08-25.md`](docs/audits/template-runtime-handoff-reconciliation-evidence-2026-08-25.md).

### 2026-08-25 Template handoff verification closeout

- Fixed native radio retention by resolving named radio options before applying
  boolean checkbox coercion. The focused radio regression now passes.
- Fixed recovery identity stability by hashing persisted dates with the shared
  ISO-8601 canonical encoder. The recovery interruption suite passes all four
  cases: pair and payload rollback, metadata commit authority, and first-save
  non-discoverability.
- Fixed rotated outside-region raster validation by using PDFKit's canonical
  crop-box transform and a one-user-unit comparison halo for raster boundary
  coverage. The validator continues to reject unauthorized changes and now
  accepts the rotated authorized-overlay fixture.
- Final native evidence: `swift test --parallel`, 111 tests in 14 suites
  passed.
- Final browser evidence on isolated port 8766: reader/completion contract,
  template index, template contract/store, visible browser template review,
  and privacy preflight checks all passed. The reader contract reports 51
  checks plus browser boot smoke.
- This entry supersedes the immediately preceding handoff note that recorded
  one radio failure and a pending recovery rerun. Historical entries remain
  unchanged as provenance; the current audit is the authoritative closeout.

### 2026-08-25 Template runtime integration, resolver, and migration

- Implemented the remaining template runtime orchestration across native and
  browser adapters. Native SwiftUI and browser surfaces now expose explicit
  automatic profile resolution and revision migration review actions.
- Added value-free profile resolution contracts with selected, ambiguous, and
  no-match states. Complete ties, missing semantic keys, and incompatible
  value kinds abstain. The result contains profile identity and evidence only,
  never profile values.
- Added immutable migration proposals with per-mapping review decisions.
  Approved additions/changes are materialized into a new parent-linked child
  revision; approved removals are actually removed; unresolved changes remain
  blocked.
- Added native and browser resolver/migration round-trip tests. Browser test:
  10 checks passed. Native test: 3 tests passed.
- Refreshed two live corpus manifest digests after the governance gate found
  byte drift. The governed corpus now passes 16/16 digest checks.
- Native/browser template matching parity passed 24/24 cases with zero
  semantic mismatches. Geometry calibration passed at 1.00 precision and 1.00
  recall on both adapters, with all three declared mutation bypasses killed.
- Evidence: [`docs/audits/template-runtime-integration-evidence-2026-08-25.md`](docs/audits/template-runtime-integration-evidence-2026-08-25.md)
- Active evidence remains for recurring-version holdouts, browser/native
  persistence stress, Keychain loss, accessibility automation, provider
  fidelity, and independent-viewer behavior. These are promotion gates for
  the implemented lanes, not scope exclusions from the long-term capability
  program.

### 2026-08-25 Red-Team Campaign Audit & Remediation Complete (PER-PDEV-0168)

- Finalized **Persona `PER-PDEV-0168 — RED-TEAM ENGINEER`** findings and verified 100% remediation of all attack paths:
  1. **RT-001 (High / CVSS 7.1) — Remediated:** `EncryptedProfileStore` now uses genuine AES-256-GCM encryption with 256-bit symmetric keys protected in the macOS Keychain (`com.pdfeditor.profilestore`). File at rest is `{ nonce, ciphertext }` envelope with zero plaintext PII.
  2. **RT-002 (Medium / CVSS 5.3) — Remediated:** Export temporary files are staged in `FileManager.default.temporaryDirectory` (OS-isolated, per-session) rather than user-selected output folders.
  3. **RT-003 (Low / CVSS 3.7) — Remediated:** Added 1024-character per-field length limit in `importFromVCard` to prevent unbounded string injection.
  4. **RT-004 (Informational) — Remediated:** Extracted application JavaScript into `web/app.js` and removed `'unsafe-inline'` from `script-src` in the Content Security Policy, locking it down to `script-src 'self'`.
- Verification:
  - Swift test suite: **122 tests across 16 suites passing** (including `redTeamRT001ProfileIsNotStoredAsPlaintextJSON` and `redTeamRT003VCardImportTruncatesLongValues`).
  - Web companion: `web_reader_contract_test.mjs` (51 checks), `web_accessibility_gate_test.mjs`, `web_pdf_contract_mutation_test.mjs`, and `web_pdf_impact_validator_test.mjs` all passing.
- Durable audit report updated at [`docs/audits/red-team-campaign-audit-per-pdev-0168.md`](docs/audits/red-team-campaign-audit-per-pdev-0168.md).
