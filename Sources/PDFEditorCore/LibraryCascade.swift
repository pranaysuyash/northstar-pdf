import Foundation

/// F-001: Library Cascade Pattern
///
/// First-principle: Try the best tool first, fall back gracefully, always produce a result.
/// Adopted from invoice-intelligence cascade (fitz → pdfplumber → Poppler CLI).
///
/// Architecture:
/// - `CascadeProvider` protocol: any extraction/validation tool
/// - `LibraryCascade`: tries providers in priority order, returns first success
/// - `CascadeResult`: includes which provider succeeded and fallback history
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Capability routing with evidence tiers
/// - OPERATING_DOCTRINE §3: Do things smartly — verify at right evidence level
/// - Long-term: Adding a new provider is one conformance declaration

/// A provider that can attempt an extraction or validation task.
public protocol CascadeProvider: Sendable {
  /// Human-readable name for this provider (e.g., "PDFKit", "QPDF", "pdf_oxide")
  var name: String { get }

  /// Priority order (lower = tried first). PDFKit=10, QPDF=20, pdf_oxide=30.
  var priority: Int { get }

  /// Whether this provider is available on the current system.
  var isAvailable: Bool { get }

  /// Attempt the task. Throw to signal failure and cascade to next provider.
  func execute<T>(input: Data) throws -> T
}

/// Result of a cascade execution, including which provider succeeded.
public struct CascadeResult<T: Sendable>: Sendable {
  /// The successful result
  public let value: T

  /// Which provider produced this result
  public let providerName: String

  /// Providers that were tried before this one (in order)
  public let fallbackHistory: [CascadeFallback]

  /// Total time across all attempts
  public let totalTimeMs: Double

  public init(
    value: T,
    providerName: String,
    fallbackHistory: [CascadeFallback] = [],
    totalTimeMs: Double = 0
  ) {
    self.value = value
    self.providerName = providerName
    self.fallbackHistory = fallbackHistory
    self.totalTimeMs = totalTimeMs
  }
}

/// Record of a failed provider attempt during cascade.
public struct CascadeFallback: Sendable {
  public let providerName: String
  public let error: String
  public let timeMs: Double

  public init(providerName: String, error: String, timeMs: Double) {
    self.providerName = providerName
    self.error = error
    self.timeMs = timeMs
  }
}

/// Cascade error when all providers fail.
public struct CascadeExhaustedError: Error, Sendable {
  public let attemptedProviders: [CascadeFallback]
  public let lastError: Error?

  public init(attemptedProviders: [CascadeFallback], lastError: Error? = nil) {
    self.attemptedProviders = attemptedProviders
    self.lastError = lastError
  }

  public var localizedDescription: String {
    let names = attemptedProviders.map(\.providerName).joined(separator: ", ")
    return "All cascade providers exhausted (attempted: \(names))"
  }
}

/// Executes a cascade of providers, returning the first successful result.
///
/// Usage:
/// ```swift
/// let cascade = LibraryCascade<TextExtractionResult>(providers: [
///   PDFKitTextProvider(),   // priority 10 — native, fastest
///   QPDFTextProvider(),     // priority 20 — structural, license-safe
///   PdfOxideTextProvider(), // priority 30 — Rust-based, fastest extraction
/// ])
/// let result = try cascade.execute(input: pdfData)
/// print("Used: \(result.providerName)") // "PDFKit"
/// print("Fallbacks: \(result.fallbackHistory.count)") // 0
/// ```
public struct LibraryCascade<T: Sendable>: Sendable {
  private let providers: [any CascadeProvider]

  public init(providers: [any CascadeProvider]) {
    // Sort by priority (lower = tried first)
    self.providers = providers.sorted { $0.priority < $1.priority }
  }

  /// Execute the cascade: try each provider in priority order until one succeeds.
  public func execute(input: Data) throws -> CascadeResult<T> {
    var fallbackHistory: [CascadeFallback] = []
    let startTime = CFAbsoluteTimeGetCurrent()

    for provider in providers {
      // Skip unavailable providers
      guard provider.isAvailable else {
        fallbackHistory.append(CascadeFallback(
          providerName: provider.name,
          error: "Provider not available on this system",
          timeMs: 0
        ))
        continue
      }

      let attemptStart = CFAbsoluteTimeGetCurrent()
      do {
        let result: T = try provider.execute(input: input)
        let elapsed = (CFAbsoluteTimeGetCurrent() - attemptStart) * 1000
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return CascadeResult(
          value: result,
          providerName: provider.name,
          fallbackHistory: fallbackHistory,
          totalTimeMs: totalTime
        )
      } catch {
        let elapsed = (CFAbsoluteTimeGetCurrent() - attemptStart) * 1000
        fallbackHistory.append(CascadeFallback(
          providerName: provider.name,
          error: error.localizedDescription,
          timeMs: elapsed
        ))
      }
    }

    // All providers exhausted
    throw CascadeExhaustedError(
      attemptedProviders: fallbackHistory,
      lastError: fallbackHistory.last.map { NSError(domain: $0.providerName, code: -1, userInfo: [NSLocalizedDescriptionKey: $0.error]) }
    )
  }
}
