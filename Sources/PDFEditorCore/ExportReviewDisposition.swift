import Foundation

/// The user's explicit disposition after a derived export has been validated
/// with warnings or failed validation.
public enum ExportReviewDisposition: String, Codable, Equatable, Hashable, Sendable {
  case rework
  case acceptAsVariance
  case discard
}

/// The actions a host may offer for the current export report. This is a pure
/// contract so a UI cannot offer an unsafe disposition by accident.
public struct ExportReviewDispositionOptions: Codable, Equatable, Hashable, Sendable {
  public let canRework: Bool
  public let canAcceptAsVariance: Bool
  public let canDiscard: Bool

  public init(
    canRework: Bool,
    canAcceptAsVariance: Bool,
    canDiscard: Bool
  ) {
    self.canRework = canRework
    self.canAcceptAsVariance = canAcceptAsVariance
    self.canDiscard = canDiscard
  }

  public static func make(
    report: ValidationReport?,
    outputIsPresent: Bool
  ) -> ExportReviewDispositionOptions {
    guard let report else {
      return ExportReviewDispositionOptions(
        canRework: false,
        canAcceptAsVariance: false,
        canDiscard: false
      )
    }

    return ExportReviewDispositionOptions(
      canRework: true,
      canAcceptAsVariance: report.status == .validatedWithWarnings && outputIsPresent,
      canDiscard: outputIsPresent
    )
  }
}
