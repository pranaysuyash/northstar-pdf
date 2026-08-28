import Foundation

/// F-003: Shadow Mode for Extraction
///
/// First-principle: Run multiple independent extractors, diff their results,
/// produce evidence of agreement or discrepancy.
///
/// Architecture:
/// - `ShadowExtractor` protocol: any extraction engine that can run in shadow mode
/// - `ShadowModeRunner`: executes extractors in parallel, diffs results
/// - `ShadowReport`: evidence of which engines agree/disagree
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Multi-engine validation with evidence tiers
/// - OPERATING_DOCTRINE §3: Verify at right evidence level
/// - Long-term: Adding an engine is one conformance declaration
///
/// Pattern source: invoice-intelligence shadow mode (fitz vs pdftotext vs Vision)

/// A text extraction engine that can run in shadow mode.
public protocol ShadowExtractor: Sendable {
  /// Engine name for reporting (e.g., "PDFKit", "pdf_oxide", "QPDF")
  var name: String { get }

  /// Whether this engine is available on the current system
  var isAvailable: Bool { get }

  /// Extract text from PDF data. Throw to signal failure.
  func extractText(from data: Data) throws -> ShadowExtractionResult
}

/// Result from a single extraction engine.
public struct ShadowExtractionResult: Sendable, Equatable {
  public let pageCount: Int
  public let characterCount: Int
  public let text: String
  public let timeMs: Double

  public init(pageCount: Int, characterCount: Int, text: String, timeMs: Double = 0) {
    self.pageCount = pageCount
    self.characterCount = characterCount
    self.text = text
    self.timeMs = timeMs
  }
}

/// Report from shadow mode execution comparing multiple engines.
public struct ShadowReport: Sendable {
  public let engineCount: Int
  public let agreementScore: Double // 0.0–1.0
  public let pageCounts: [String: Int]
  public let characterCounts: [String: Int]
  public let discrepancies: [ShadowDiscrepancy]
  public let timing: [String: Double]
  public let allSucceeded: Bool

  public init(
    engineCount: Int,
    agreementScore: Double,
    pageCounts: [String: Int],
    characterCounts: [String: Int],
    discrepancies: [ShadowDiscrepancy],
    timing: [String: Double],
    allSucceeded: Bool
  ) {
    self.engineCount = engineCount
    self.agreementScore = agreementScore
    self.pageCounts = pageCounts
    self.characterCounts = characterCounts
    self.discrepancies = discrepancies
    self.timing = timing
    self.allSucceeded = allSucceeded
  }
}

/// A specific discrepancy between engines.
public struct ShadowDiscrepancy: Sendable, Equatable {
  public enum Kind: String, Sendable {
    case pageCountMismatch
    case characterCountVariance
    case textPresenceDisagreement
  }

  public let kind: Kind
  public let engines: [String]
  public let details: String

  public init(kind: Kind, engines: [String], details: String) {
    self.kind = kind
    self.engines = engines
    self.details = details
  }
}

/// Executes shadow mode extraction: runs all available engines, diffs results.
public struct ShadowModeRunner: Sendable {
  private let engines: [any ShadowExtractor]
  private let characterCountVarianceThreshold: Double

  public init(
    engines: [any ShadowExtractor],
    characterCountVarianceThreshold: Double = 0.15
  ) {
    self.engines = engines
    self.characterCountVarianceThreshold = characterCountVarianceThreshold
  }

  /// Run all available engines against the same input and produce a comparison report.
  public func runShadowMode(input: Data) -> ShadowModeResult {
    let availableEngines = engines.filter(\.isAvailable)

    guard availableEngines.count >= 2 else {
      return ShadowModeResult(
        report: ShadowReport(
          engineCount: availableEngines.count,
          agreementScore: 1.0,
          pageCounts: [:],
          characterCounts: [:],
          discrepancies: [],
          timing: [:],
          allSucceeded: false
        ),
        results: [:]
      )
    }

    var results: [String: ShadowExtractionResult] = [:]
    var timing: [String: Double] = [:]
    var errors: [String: String] = [:]

    for engine in availableEngines {
      let start = CFAbsoluteTimeGetCurrent()
      do {
        let result = try engine.extractText(from: input)
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        results[engine.name] = result
        timing[engine.name] = elapsed
      } catch {
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        errors[engine.name] = error.localizedDescription
        timing[engine.name] = elapsed
      }
    }

    let allSucceeded = errors.isEmpty

    // Compute discrepancies
    var discrepancies: [ShadowDiscrepancy] = []
    let resultValues = Array(results.values)

    // Page count agreement
    let pageCounts = results.mapValues(\.pageCount)
    let firstPageCount = resultValues.first?.pageCount ?? 0
    if !resultValues.allSatisfy({ $0.pageCount == firstPageCount }) {
      discrepancies.append(ShadowDiscrepancy(
        kind: .pageCountMismatch,
        engines: Array(results.keys),
        details: "Page counts: \(pageCounts)"
      ))
    }

    // Character count variance
    let charCounts = results.mapValues(\.characterCount)
    let charValues = resultValues.map(\.characterCount).map(Double.init)
    if let avg = charValues.first.map({ val in
      charValues.reduce(0, +) / Double(charValues.count)
    }), avg > 0 {
      let maxVariance = charValues.map { abs($0 - avg) / avg }.max() ?? 0
      if maxVariance > characterCountVarianceThreshold {
        discrepancies.append(ShadowDiscrepancy(
          kind: .characterCountVariance,
          engines: Array(results.keys),
          details: "Character counts: \(charCounts), variance: \(String(format: "%.1f%%", maxVariance * 100))"
        ))
      }
    }

    // Text presence agreement
    let textPresence = results.mapValues { !$0.text.isEmpty }
    let firstHasText = resultValues.first.map { !$0.text.isEmpty } ?? false
    if !resultValues.allSatisfy({ !$0.text.isEmpty == firstHasText }) {
      discrepancies.append(ShadowDiscrepancy(
        kind: .textPresenceDisagreement,
        engines: Array(results.keys),
        details: "Text presence: \(textPresence)"
      ))
    }

    // Compute agreement score
    var score = 1.0
    for d in discrepancies {
      switch d.kind {
      case .pageCountMismatch: score -= 0.3
      case .characterCountVariance: score -= 0.2
      case .textPresenceDisagreement: score -= 0.3
      }
    }
    let agreementScore = max(0.0, min(1.0, score))

    let report = ShadowReport(
      engineCount: availableEngines.count,
      agreementScore: agreementScore,
      pageCounts: pageCounts,
      characterCounts: charCounts,
      discrepancies: discrepancies,
      timing: timing,
      allSucceeded: allSucceeded
    )

    return ShadowModeResult(report: report, results: results)
  }
}

/// Combined result of shadow mode execution.
public struct ShadowModeResult: Sendable {
  public let report: ShadowReport
  public let results: [String: ShadowExtractionResult]

  public init(report: ShadowReport, results: [String: ShadowExtractionResult]) {
    self.report = report
    self.results = results
  }
}
