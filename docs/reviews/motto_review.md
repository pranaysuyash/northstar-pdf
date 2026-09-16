# Operating Doctrine Review

- Doctrine path: /Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md
- SHA-256: ff848618a7431a3b06c7409caa45683bd27c64263d45b93f9fcd36a89803466a
- Generated: 2026-09-15T16:58:19Z
- This is a generated review artifact, not an instruction source.

## SECTION_0

- Label: §0 Start from live truth
- Reviewed: True
- Evidence: Live tree verified before commit: calibration-gate fix c2eb7fa committed locally and unpushed (origin at 4aef84a); /tmp/push_cal.out and CI logs re-read; disk at 12G free with no ENOSPC this round.

## SECTION_00_INTEGRATED

- Label: Full doctrine integrated audit
- Reviewed: True
- Evidence: Integrated audit of this diff: raises the shared heavy-test semaphore acquire bound above the longest legitimate hold (Marker benchmark 330-530s) now that the confirm lane also contends, unblocking the push of the calibration-gate repair whose own pre-push gate failed solely on this timeout; no assertion or production changes; both pending commits verified locally; RG-135 remains fail-closed owner work.

## SECTION_1

- Label: §1 Outcomes and retained value
- Reviewed: True
- Evidence: Outcome: unblocks the push of the calibration-gate repair so /Users/pranay/Projects/pdf_editor main returns green; retains the serialisation guarantees all three heavy suites rely on.

## SECTION_10

- Label: §10 Parallel work and contested state
- Reviewed: True
- Evidence: Contention math from observed runs: the OCR Companion suite holds/reacquires the /pdf-editor-heavy semaphore continuously across its 74-minute run (4462.6s Observed in /tmp/pdf-editor-swift-test-last.log), so the confirm-lane e2e waiter hit the 600s bound at 602.3s; any fixed bound below a full suite duration fails under this contention pattern — 5400s covers a full suite plus margin in all three lock copies.

## SECTION_11

- Label: §11 Engineering and data integrity
- Reviewed: True
- Evidence: Deadline constant 600s to 5400s in Tests/PDFEditorCoreTests/OCRCompanionBenchmarkTests.swift, Tests/PDFEditorCoreTests/OCRConfirmLaneTests.swift, Tests/PDFEditorAppRecoveryTests/RecoveryCrashInterruptionTests.swift; each file's comment records the observed evidence chain (330-530s single hold, then 74-minute suite hold chain).

## SECTION_12

- Label: §12 AI output boundary
- Reviewed: True
- Evidence: The bound raise in Tests/PDFEditorAppRecoveryTests/RecoveryCrashInterruptionTests.swift and the other two lock copies is grounded in observed hold times from gh run logs, not optimism; a leaked lock still fails closed with the documented remediation message.

## SECTION_13

- Label: §13 Product, operator, and claim reality
- Reviewed: True
- Evidence: Operator reality: a timeout firing behind legitimate work is an unactionable false failure; the 600s bound in Tests/PDFEditorCoreTests/OCRCompanionBenchmarkTests.swift removes the false timeout while the failure message still names leak remediation.

## SECTION_14

- Label: §14 Documentation and decisions
- Reviewed: True
- Evidence: docs/flaky-register.md is the durable record for this flake class; the commit message and comments cite it with the 2026-09-12 bounded-acquire provenance.

## SECTION_15

- Label: §15 Completion contract
- Reviewed: True
- Evidence: Completion report will state files changed, commands with outcomes recorded under /tmp/, Tier 2 evidence, remaining risks (RG-135 fail-closed by design needs owner review of 38 fixtures; disk at 12G free), and uncommitted work.

## SECTION_16

- Label: §16 Specialist doctrine routing
- Reviewed: True
- Evidence: TESTING_DOCTRINE routing for the flake/serialization decision; RELEASE_READINESS_DOCTRINE was applied for the earlier council verdict; routing unchanged.

## SECTION_17

- Label: §17 Propagation contract
- Reviewed: True
- Evidence: Instruction stack re-checked this session; OPERATING_DOCTRINE.md SHA ff848618... attested in the commit trailers per /Users/pranay/AGENTS.md order.

## SECTION_2

- Label: §2 Truth taxonomy
- Reviewed: True
- Evidence: Claims labeled: Marker hold 330-530s = Observed in run logs; Code=3 timeout in /tmp/push_cal.out = Observed; 600s adequacy = Inferred from max observed hold plus margin, with the bound still fail-closed.

## SECTION_3

- Label: §3 Proportional rigor and evidence
- Reviewed: True
- Evidence: Verified Tier 2: swift build green at 260s with the 5400s bound; the 600s bound's insufficiency is Observed in /tmp/pdf-editor-swift-test-last.log (Code=3 at 602.296s wait, immediately after the OCR Companion suite's 4462s hold chain).

## SECTION_4

- Label: §4 Authorization and side effects
- Reviewed: True
- Evidence: Owner authorized commit protocol with full hook/gate and push earlier in this conversation and said continue after each failure; this commit continues that same named scope.

## SECTION_5

- Label: §5 Canonical paths and ownership
- Reviewed: True
- Evidence: No new canonical paths created; the semaphore lock helper remains the established per-file pattern in Tests/PDFEditorCoreTests/ and Tests/PDFEditorAppRecoveryTests/ (consolidation into one shared helper is ledgered follow-up since the targets differ).

## SECTION_6

- Label: §6 Semantic salvage and supersession
- Reviewed: True
- Evidence: The three lock copies in Tests/PDFEditorCoreTests/ and Tests/PDFEditorAppRecoveryTests/ stay semantically identical; only the deadline constant and its justification comment change, preserving each file's provenance notes.

## SECTION_7

- Label: §7 Capability routing
- Reviewed: True
- Evidence: Diagnosis routed through gh run logs for .github/workflows/ci.yml plus local reproduction; no capability mismatch required rerouting.

## SECTION_8

- Label: §8 Skills lifecycle
- Reviewed: True
- Evidence: mimosa plugin at /Users/pranay/.zcode/cli/plugins/cache/zcode-plugins-official/mimosa/ and council-orchestrator were used earlier this session per their SKILL.md protocols; this commit uses only the repo's own gates.

## SECTION_9

- Label: §9 Exploration and durable knowledge
- Reviewed: True
- Evidence: Findings recorded in commit message and comments with citations: /tmp/push_cal.out Code=3, Marker hold 330-530s Observed in run 34893161466 logs, docs/flaky-register.md precedent for the bounded-acquire design.
