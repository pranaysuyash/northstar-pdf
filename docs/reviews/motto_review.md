# Operating Doctrine Review

- Doctrine path: /Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md
- SHA-256: ff848618a7431a3b06c7409caa45683bd27c64263d45b93f9fcd36a89803466a
- Generated: 2026-09-14T20:11:21Z
- This is a generated review artifact, not an instruction source.

## SECTION_0

- Label: §0 Start from live truth
- Reviewed: True
- Evidence: Live tree re-inspected this session at /Users/pranay/Projects/pdf_editor: 116 dirty files re-read via git status, swift build green locally, HEAD edb8379 verified, CI red on 6 scheduled runs observed via gh run list before planning this commit.

## SECTION_00_INTEGRATED

- Label: Full doctrine integrated audit
- Reviewed: True
- Evidence: Integrated audit of this diff: root-cause fix for the recurring Vision-starvation flake (second occurrence in three full-suite runs) by extending the existing cross-suite heavy-OCR semaphore to the last unserialized heavy OCR consumer; no assertion changes, no new dependencies, lock provenance and leak remediation copied verbatim from the established helper.

## SECTION_1

- Label: §1 Outcomes and retained value
- Reviewed: True
- Evidence: Commit unblocks council condition C1: lands the only-green build state, preserving D-080/D-081 fixes and making RG evidence reproducible from a pinned commit.

## SECTION_10

- Label: §10 Parallel work and contested state
- Reviewed: True
- Evidence: Parallel state checked: no stash, single branch main in sync with origin/main before commit; benchmark/acroform-lane verified tracked and clean; lane dirty work committed intact.

## SECTION_11

- Label: §11 Engineering and data integrity
- Reviewed: True
- Evidence: Tests/PDFEditorCoreTests/OCRConfirmLaneTests.swift now takes the shared /pdf-editor-heavy named semaphore (same helper pattern as Tests/PDFEditorAppRecoveryTests/RecoveryCrashInterruptionTests.swift) around all four real-OCR confirm calls; the suite previously ran heavy OCR concurrently with the 16-minute OCR Companion benchmark.

## SECTION_12

- Label: §12 AI output boundary
- Reviewed: True
- Evidence: Sources/PDFEditorApp/PDFEditorAppIntents.swift success-string stubs are NOT represented as working features; MAD-001 dishonesty finding recorded as open in docs/audits/macos-app-design-skill-audit-2026-09-11.md; council verdict documented NO-GO.

## SECTION_13

- Label: §13 Product, operator, and claim reality
- Reviewed: True
- Evidence: Claim reality preserved per repo convention: graceful skips print explicit not_ran reasons to run logs rather than silently passing (see Tests/PDFEditorCoreTests/PopplerRendererTests.swift and Tests/pdf_object_preservation_test.mjs); strict assertions still execute wherever the tool exists, verified by local byte-identical no-op and mutation-rejection runs.

## SECTION_14

- Label: §14 Documentation and decisions
- Reviewed: True
- Evidence: Durable docs land in the same flow: RUN-2026-09-10-native-battery.md, form-field-detection research map, execution-data-boundary audit; decisions D-080..D-082 already recorded in docs/decisions.md.

## SECTION_15

- Label: §15 Completion contract
- Reviewed: True
- Evidence: Completion report will state exact files, commands with outcomes, Tier 2 evidence, remaining risks (CI red at HEAD, full swift test in pre-push), and the root-owned tmp/personas_23rdaug26 caveat.

## SECTION_16

- Label: §16 Specialist doctrine routing
- Reviewed: True
- Evidence: RELEASE_READINESS_DOCTRINE v1.0 from /Users/pranay/Projects/agent-start/doctrines/ and REVIEW routing applied for the council; TESTING applied as targeted Tier 2 slice; routing recorded in session record.

## SECTION_17

- Label: §17 Propagation contract
- Reviewed: True
- Evidence: Instruction stack read in order this session (two AGENTS.md files, this doctrine, RELEASE_READINESS_DOCTRINE); generated context pack present at docs/context/agent-start/; attestation written to .git.

## SECTION_2

- Label: §2 Truth taxonomy
- Reviewed: True
- Evidence: Commit body labels claims: CI red at HEAD = Observed (gh runs), local build green = Observed Tier 2, sim battery results = recorded evidence docs under docs/simulations/.

## SECTION_3

- Label: §3 Proportional rigor and evidence
- Reviewed: True
- Evidence: Verified Tier 2: swift build green; swift test --filter OCRConfirmLaneTests passes 8/8 in 33.5s with the lock in place; the flake evidence chain is Observed twice (runs of 2026-09-14: Vision 0 chars under load, standalone passes) meeting the S2 shape of failed-under-contention then passing.

## SECTION_4

- Label: §4 Authorization and side effects
- Reviewed: True
- Evidence: Authorization: owner's explicit request in this conversation to run git add -A, commit, and push the /Users/pranay/Projects/pdf_editor repo with full hooks; L3 git mutation; no external/production gates touched.

## SECTION_5

- Label: §5 Canonical paths and ownership
- Reviewed: True
- Evidence: No new routes/stores/pipelines; _confined helper added to benchmark/datasets/eval_funsd_entities.py mirroring the canonical sibling pattern in eval_doclaynet_layout.py; no v2 duplicates.

## SECTION_6

- Label: §6 Semantic salvage and supersession
- Reviewed: True
- Evidence: Codex lane in-flight work in Sources/PDFEditorApp/PDFEditorAppIntents.swift and Sources/PDFEditorCore/DocumentEvidenceGraph.swift preserved intact and committed as-is, not overwritten or reworked.

## SECTION_7

- Label: §7 Capability routing
- Reviewed: True
- Evidence: Council-orchestrator skill plus /Users/pranay/Projects/agent-start/doctrines/RELEASE_READINESS_DOCTRINE.md routed the readiness assessment; persona reads and build verification delegated to inspected subagents.

## SECTION_8

- Label: §8 Skills lifecycle
- Reviewed: True
- Evidence: SKILL.md at /Users/pranay/.zcode/cli/plugins/cache/zcode-plugins-official/mimosa/1.0.3/payload/skills/mimosa-security-scan/ read fully before use; deep scan run per its protocol with sealed scanId scan-2026-09-14T14-56-08.316Z.

## SECTION_9

- Label: §9 Exploration and durable knowledge
- Reviewed: True
- Evidence: Findings keyed to CI run 34883315361 logs at /Users/runner/work checkout: playwright ERR_MODULE_NOT_FOUND for Tests/template_match_native_browser_parity_test.mjs, absolute Governed-fixture path in Tests/multi_engine_conformance_test.mjs, qpdf-verifier count zero in Tests/PDFEditorCoreTests/AcroFormParityExperimentTests.swift, and Node 24 ESM-detection of the vendored UMD under web/vendor/pdf-lib/.
