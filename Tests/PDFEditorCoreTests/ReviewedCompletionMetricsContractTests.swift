import Foundation
import Testing

@testable import PDFEditorCore

struct ReviewedCompletionMetricsContractTests {
  @Test func nativeDecodesAndValidatesBrowserMetricsArtifact() throws {
    struct CorrectionBenchmarkArtifact: Decodable {
      let metrics: PDFReviewedCompletionMetrics
    }

    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let artifact = repositoryRoot
      .appendingPathComponent("benchmark/results/template-matching/2026-08-24-correction-benefit.json")
    let artifactPayload = try JSONDecoder().decode(
      CorrectionBenchmarkArtifact.self,
      from: Data(contentsOf: artifact)
    )
    let metrics = artifactPayload.metrics

    try metrics.validate()
    #expect(metrics.version == PDFReviewedCompletionMetrics.version)
    #expect(metrics.reviewedCorrection.reviewedTargetCoverageLift == 5)
    #expect(metrics.abstention.abstentionRate == 1)
    #expect(metrics.hardNegative.falsePositiveRate == 0)
    #expect(metrics.safeCompletion.silentAutofillCount == 0)
  }

  @Test func nativeRejectsUnsafeMetricStatesBeforeParityAcceptance() throws {
    let metrics = PDFReviewedCompletionMetrics(
      privacy: PDFReviewedCompletionMetricsPrivacy(
        valueFree: true,
        sourceBytesStored: false,
        rawLabelsStored: false,
        profileValuesStored: false,
        contentLogged: false
      ),
      reviewedCorrection: PDFReviewedCorrectionMetrics(
        eligibleCaseCount: 1,
        promotedCorrectionCount: 1,
        baselineReviewedTargetCount: 0,
        promotedReviewedTargetCount: 1,
        reviewedTargetCoverageLift: 1,
        improvedCaseCount: 1,
        improvementRate: 1,
        rollbackRestoredCount: 1,
        rollbackRestorationRate: 1
      ),
      abstention: PDFReviewedAbstentionMetrics(
        eligibleCaseCount: 1,
        abstainedCount: 0,
        abstentionRate: 0,
        failureCount: 0,
        expectedStateCounts: ["noMatch": 1]
      ),
      hardNegative: PDFReviewedHardNegativeMetrics(
        fixtureCount: 1,
        selectedCount: 1,
        abstainedCount: 0,
        abstentionRate: 0,
        falsePositiveRate: 1,
        promotionReplayCount: 1,
        promotionReplaySelectedCount: 0,
        promotionReplayAbstentionRate: 1
      ),
      safeCompletion: PDFReviewedSafeCompletionMetrics(
        eligibleCaseCount: 1,
        sourceBoundValidatedCount: 1,
        sourceBoundValidatedRate: 1,
        explicitReviewGuardedCount: 1,
        explicitReviewGuardedRate: 1,
        materializationAllowedWithoutReviewCount: 0,
        silentAutofillCount: 0,
        safeCompletionReadyCount: 1,
        safeCompletionReadyRate: 1
      ),
      passed: true
    )

    #expect(throws: PDFReviewedCompletionMetricsError.invalid("hard negative was selected")) {
      try metrics.validate()
    }
  }
}
