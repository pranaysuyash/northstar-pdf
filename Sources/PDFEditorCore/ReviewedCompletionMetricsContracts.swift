import Foundation

/// The shared, value-free metrics envelope emitted by reviewed template
/// adapters. This is an evidence contract, not an authorization to apply a
/// completion proposal.
public struct PDFReviewedCompletionMetricsPrivacy: Codable, Equatable, Sendable {
  public let valueFree: Bool
  public let sourceBytesStored: Bool
  public let rawLabelsStored: Bool
  public let profileValuesStored: Bool
  public let contentLogged: Bool

  public init(
    valueFree: Bool,
    sourceBytesStored: Bool,
    rawLabelsStored: Bool,
    profileValuesStored: Bool,
    contentLogged: Bool
  ) {
    self.valueFree = valueFree
    self.sourceBytesStored = sourceBytesStored
    self.rawLabelsStored = rawLabelsStored
    self.profileValuesStored = profileValuesStored
    self.contentLogged = contentLogged
  }
}

public struct PDFReviewedCorrectionMetrics: Codable, Equatable, Sendable {
  public let eligibleCaseCount: Int
  public let promotedCorrectionCount: Int
  public let baselineReviewedTargetCount: Int
  public let promotedReviewedTargetCount: Int
  public let reviewedTargetCoverageLift: Int
  public let improvedCaseCount: Int
  public let improvementRate: Double
  public let rollbackRestoredCount: Int
  public let rollbackRestorationRate: Double
}

public struct PDFReviewedAbstentionMetrics: Codable, Equatable, Sendable {
  public let eligibleCaseCount: Int
  public let abstainedCount: Int
  public let abstentionRate: Double
  public let failureCount: Int
  public let expectedStateCounts: [String: Int]
}

public struct PDFReviewedHardNegativeMetrics: Codable, Equatable, Sendable {
  public let fixtureCount: Int
  public let selectedCount: Int
  public let abstainedCount: Int
  public let abstentionRate: Double
  public let falsePositiveRate: Double
  public let promotionReplayCount: Int
  public let promotionReplaySelectedCount: Int
  public let promotionReplayAbstentionRate: Double
}

public struct PDFReviewedSafeCompletionMetrics: Codable, Equatable, Sendable {
  public let eligibleCaseCount: Int
  public let sourceBoundValidatedCount: Int
  public let sourceBoundValidatedRate: Double
  public let explicitReviewGuardedCount: Int
  public let explicitReviewGuardedRate: Double
  public let materializationAllowedWithoutReviewCount: Int
  public let silentAutofillCount: Int
  public let safeCompletionReadyCount: Int
  public let safeCompletionReadyRate: Double
}

public enum PDFReviewedCompletionMetricsError: Error, Equatable, Sendable {
  case invalid(String)
}

/// Shared semantic report for browser and native reviewed-completion runs.
///
/// A safe-completion-ready case is only a reviewed target that is ready for
/// explicit value review. It is never equivalent to a filled value.
public struct PDFReviewedCompletionMetrics: Codable, Equatable, Sendable {
  public static let schema = "pdf-editor.reviewed-completion-metrics"
  public static let version = PDFContractVersion(major: 1, minor: 0)

  public let schema: String
  public let version: PDFContractVersion
  public let privacy: PDFReviewedCompletionMetricsPrivacy
  public let reviewedCorrection: PDFReviewedCorrectionMetrics
  public let abstention: PDFReviewedAbstentionMetrics
  public let hardNegative: PDFReviewedHardNegativeMetrics
  public let safeCompletion: PDFReviewedSafeCompletionMetrics
  public let passed: Bool

  public init(
    schema: String = PDFReviewedCompletionMetrics.schema,
    version: PDFContractVersion = PDFReviewedCompletionMetrics.version,
    privacy: PDFReviewedCompletionMetricsPrivacy,
    reviewedCorrection: PDFReviewedCorrectionMetrics,
    abstention: PDFReviewedAbstentionMetrics,
    hardNegative: PDFReviewedHardNegativeMetrics,
    safeCompletion: PDFReviewedSafeCompletionMetrics,
    passed: Bool
  ) {
    self.schema = schema
    self.version = version
    self.privacy = privacy
    self.reviewedCorrection = reviewedCorrection
    self.abstention = abstention
    self.hardNegative = hardNegative
    self.safeCompletion = safeCompletion
    self.passed = passed
  }

  /// Validates the non-negotiable safety invariants of a passing report.
  /// This deliberately does not inspect or accept profile values.
  public func validate() throws {
    guard schema == Self.schema else {
      throw PDFReviewedCompletionMetricsError.invalid("unexpected metrics schema")
    }
    guard version.isReadableBy(Self.version) else {
      throw PDFReviewedCompletionMetricsError.invalid("unsupported metrics version")
    }
    guard privacy.valueFree,
      !privacy.sourceBytesStored,
      !privacy.rawLabelsStored,
      !privacy.profileValuesStored,
      !privacy.contentLogged
    else {
      throw PDFReviewedCompletionMetricsError.invalid("metrics contain prohibited content evidence")
    }
    guard abstention.failureCount == 0 else {
      throw PDFReviewedCompletionMetricsError.invalid("abstention failure detected")
    }
    guard hardNegative.selectedCount == 0,
      hardNegative.promotionReplaySelectedCount == 0
    else {
      throw PDFReviewedCompletionMetricsError.invalid("hard negative was selected")
    }
    guard safeCompletion.materializationAllowedWithoutReviewCount == 0,
      safeCompletion.silentAutofillCount == 0
    else {
      throw PDFReviewedCompletionMetricsError.invalid("silent autofill or unreviewed materialization detected")
    }
    guard passed else {
      throw PDFReviewedCompletionMetricsError.invalid("metrics report did not pass")
    }
  }
}
