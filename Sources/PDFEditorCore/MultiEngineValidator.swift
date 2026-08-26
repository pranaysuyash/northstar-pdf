import Foundation

/// Multi-Engine Conformance Validator: compares extraction and geometry across
/// independent PDF rendering engines (Apple PDFKit, PDF.js, Poppler/MuPDF).
public struct MultiEngineValidator: Sendable {
  public struct EngineObservation: Sendable, Equatable {
    public let engineName: String
    public let pageCount: Int
    public let characterCount: Int
    public let fieldCount: Int
    public let hasSelectableText: Bool

    public init(
      engineName: String,
      pageCount: Int,
      characterCount: Int,
      fieldCount: Int,
      hasSelectableText: Bool
    ) {
      self.engineName = engineName
      self.pageCount = pageCount
      self.characterCount = characterCount
      self.fieldCount = fieldCount
      self.hasSelectableText = hasSelectableText
    }
  }

  public struct ConformanceReport: Sendable, Equatable {
    public let engineCount: Int
    public let pageCountAgreed: Bool
    public let textPresenceAgreed: Bool
    public let characterCountVariance: Double
    public let fieldCountAgreed: Bool
    public let overallAgreementRatio: Double
    public let discrepancies: [String]

    public init(
      engineCount: Int,
      pageCountAgreed: Bool,
      textPresenceAgreed: Bool,
      characterCountVariance: Double,
      fieldCountAgreed: Bool,
      overallAgreementRatio: Double,
      discrepancies: [String]
    ) {
      self.engineCount = engineCount
      self.pageCountAgreed = pageCountAgreed
      self.textPresenceAgreed = textPresenceAgreed
      self.characterCountVariance = characterCountVariance
      self.fieldCountAgreed = fieldCountAgreed
      self.overallAgreementRatio = overallAgreementRatio
      self.discrepancies = discrepancies
    }
  }

  public init() {}

  /// Evaluates 3-way multi-engine observations and generates a mathematical conformance report.
  public func evaluate(observations: [EngineObservation]) -> ConformanceReport {
    guard observations.count >= 2 else {
      return ConformanceReport(
        engineCount: observations.count,
        pageCountAgreed: true,
        textPresenceAgreed: true,
        characterCountVariance: 0,
        fieldCountAgreed: true,
        overallAgreementRatio: 1.0,
        discrepancies: ["Single engine observation - cross-engine comparison requires >= 2 engines"]
      )
    }

    var discrepancies: [String] = []

    // 1. Page Count Agreement
    let firstPageCount = observations[0].pageCount
    let pageCountAgreed = observations.allSatisfy { $0.pageCount == firstPageCount }
    if !pageCountAgreed {
      discrepancies.append("Page count discrepancy between engines: \(observations.map { "\($0.engineName)=\($0.pageCount)" }.joined(separator: ", "))")
    }

    // 2. Text Presence Agreement
    let firstTextPresence = observations[0].hasSelectableText
    let textPresenceAgreed = observations.allSatisfy { $0.hasSelectableText == firstTextPresence }
    if !textPresenceAgreed {
      discrepancies.append("Selectable text presence disagreement across engines")
    }

    // 3. Character Count Variance
    let charCounts = observations.map { Double($0.characterCount) }
    let avgChars = charCounts.reduce(0, +) / Double(charCounts.count)
    let variance = avgChars > 0
      ? (charCounts.map { abs($0 - avgChars) }.max() ?? 0) / avgChars
      : 0

    if variance > 0.15 {
      discrepancies.append("Character count variance exceeds 15%: \(observations.map { "\($0.engineName)=\($0.characterCount)" }.joined(separator: ", "))")
    }

    // 4. Form Field Count Agreement
    let firstFieldCount = observations[0].fieldCount
    let fieldCountAgreed = observations.allSatisfy { $0.fieldCount == firstFieldCount }
    if !fieldCountAgreed {
      discrepancies.append("Field count discrepancy: \(observations.map { "\($0.engineName)=\($0.fieldCount)" }.joined(separator: ", "))")
    }

    // 5. Compute Overall Score
    var score = 1.0
    if !pageCountAgreed { score -= 0.3 }
    if !textPresenceAgreed { score -= 0.3 }
    if variance > 0.05 { score -= min(0.2, variance) }
    if !fieldCountAgreed { score -= 0.2 }

    let overallRatio = max(0.0, min(1.0, score))

    return ConformanceReport(
      engineCount: observations.count,
      pageCountAgreed: pageCountAgreed,
      textPresenceAgreed: textPresenceAgreed,
      characterCountVariance: variance,
      fieldCountAgreed: fieldCountAgreed,
      overallAgreementRatio: overallRatio,
      discrepancies: discrepancies
    )
  }
}
