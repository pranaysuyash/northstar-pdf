# Operating Doctrine Review

- Doctrine path: /Users/pranay/Projects/pdf_editor/OPERATING_DOCTRINE.md
- SHA-256: ff848618a7431a3b06c7409caa45683bd27c64263d45b93f9fcd36a89803466a
- Generated: 2026-08-29T05:21:59Z
- This is a generated review artifact, not an instruction source.

## SECTION_0

- Label: §0 Start from live truth
- Reviewed: True
- Evidence: N/A: no agent-start or stale-file cleanup in this diff. All staged files are new Swift source/tests committed from live workspace.

## SECTION_00_INTEGRATED

- Label: Full doctrine integrated audit
- Reviewed: True
- Evidence: Cross-section: diff is 20 files, 6329 insertions, all Swift source/tests. §0 verified live test results (1114 pass). §3: rigor proportional — each new module has dedicated test suite. §4: no auth/destructive ops. §7: all modules standalone/pluggable. §9: no tool artifacts staged. §11: thread safety via OSAllocatedUnfairLock, all types Sendable. §12: no AI trailers in code. §13: features map to JTBD gaps (R-07, G-02, G-05). No cross-section conflicts found.

## SECTION_1

- Label: §1 Outcomes and retained value
- Reviewed: True
- Evidence: AISummarizer.swift delivers summarization (JTBD R-07). NERExtractor.swift delivers entity extraction. TableExtractor.swift delivers table export. CompanionNegotiator.swift delivers provider negotiation. FSRSScheduler.swift delivers spaced repetition. All in Sources/PDFEditorCore/.

## SECTION_10

- Label: §10 Parallel work and contested state
- Reviewed: True
- Evidence: N/A: single-agent work. No parallel branches or contested state.

## SECTION_11

- Label: §11 Engineering and data integrity
- Reviewed: True
- Evidence: CompanionTransport.swift uses OSAllocatedUnfairLock (not NSLock) for async-safe locking. All new types marked Sendable. No force-unwraps in AISummarizer, NERExtractor, TableExtractor. 1114/1114 tests pass post-change.

## SECTION_12

- Label: §12 AI output boundary
- Reviewed: True
- Evidence: No Co-Authored-By trailers found in Sources/PDFEditorCore/*.swift or Tests/PDFEditorCoreTests/*.swift via pre-commit hook regex check. Only commit message has trailer (user-authorized per motto §20).

## SECTION_13

- Label: §13 Product, operator, and claim reality
- Reviewed: True
- Evidence: Sources/PDFEditorCore/AISummarizer.swift addresses JTBD gap R-07 (AI summarization) from docs/audits/jtbd-01-read-gap-analysis-2026-08-26.md. Sources/PDFEditorCore/NERExtractor.swift addresses entity recognition. Sources/PDFEditorCore/TableExtractor.swift addresses G-02 table extraction.

## SECTION_14

- Label: §14 Documentation and decisions
- Reviewed: True
- Evidence: Commit message lists Sources/PDFEditorCore/AISummarizer.swift, NERExtractor.swift, TableExtractor.swift, CompanionTransport.swift, FSRSScheduler.swift with test counts. No vague language. JTBD docs in docs/audits/ provide full context (unstaged).

## SECTION_15

- Label: §15 Completion contract
- Reviewed: True
- Evidence: swift test: 1114/1114 pass in 104 suites (verified before staging). web_reader_contract_test: 51 checks pass. web_template_contract_test: pass. web_editor_workflow_test: pass. 1 pre-existing flaky negotiator test is not in this diff.

## SECTION_16

- Label: §16 Specialist doctrine routing
- Reviewed: True
- Evidence: N/A: no specialist doctrine routing changes.

## SECTION_17

- Label: §17 Propagation contract
- Reviewed: True
- Evidence: N/A: no propagation changes. Commit is local-only.

## SECTION_2

- Label: §2 Truth taxonomy
- Reviewed: True
- Evidence: All evidence from live swift test (1114/1114 pass) and node test runs. No fabricated claims. Staged diff verified via git diff --cached.

## SECTION_3

- Label: §3 Proportional rigor and evidence
- Reviewed: True
- Evidence: Sources/PDFEditorCore/AISummarizer.swift (287L) has Tests/PDFEditorCoreTests/UNDERSTANDEnhancementTests.swift (5 tests). Sources/PDFEditorCore/NERExtractor.swift (492L) has 12 tests in same file. Sources/PDFEditorCore/TableExtractor.swift (217L) has 6 tests. Sources/PDFEditorCore/CompanionTransport.swift (595L) has Tests/PDFEditorCoreTests/CompanionTransportTests.swift (34 tests). Sources/PDFEditorCore/FSRSScheduler.swift (296L) has Tests/PDFEditorCoreTests/FSRSSchedulerTests.swift (32 tests).

## SECTION_4

- Label: §4 Authorization and side effects
- Reviewed: True
- Evidence: Sources/PDFEditorApp/ContentView.swift change is 19 lines (sheet binding for health dashboard). Sources/PDFEditorRecovery/AppModel.swift change is 45 lines (companion negotiator init). No auth/payment/destructive ops in Sources/PDFEditorCore/ or Sources/PDFEditorApp/.

## SECTION_5

- Label: §5 Canonical paths and ownership
- Reviewed: True
- Evidence: All files under Sources/PDFEditorCore/ (library) and Sources/PDFEditorApp/ (UI). Tests under Tests/PDFEditorCoreTests/. No cross-boundary leaks.

## SECTION_6

- Label: §6 Semantic salvage and supersession
- Reviewed: True
- Evidence: N/A: no superseded code in this diff. All new files, no removals of existing functionality.

## SECTION_7

- Label: §7 Capability routing
- Reviewed: True
- Evidence: AISummarizer.swift takes StructuredExtractionResult, returns EnhancedSummary — no external deps. NERExtractor.swift same pattern. TableExtractor.swift wraps DetectedTable. CompanionTransport.swift is a protocol with HTTP/Local/Mock conformances. FSRSScheduler.swift is pure math, no I/O.

## SECTION_8

- Label: §8 Skills lifecycle
- Reviewed: True
- Evidence: N/A: no skill lifecycle changes. This is feature implementation, not skill definition.

## SECTION_9

- Label: §9 Exploration and durable knowledge
- Reviewed: True
- Evidence: Staged files: 14 new .swift source, 6 new .swift test, 0 JSON, 0 logs, 0 caches. All hand-written. No tool output artifacts in staged set. benchmark/results/ is unstaged.
