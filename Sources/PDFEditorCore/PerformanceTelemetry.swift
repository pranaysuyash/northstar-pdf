import CoreGraphics
import Foundation
import PDFKit
import os

/// The small, value-free set of operations that the native performance lane tracks.
///
/// The enum deliberately contains no document identifiers, paths, text, or error
/// details. A caller supplies those values to its own benchmark manifest, never to
/// this production instrumentation path.
public enum PerformanceStage: String, Codable, CaseIterable, Sendable {
  case openLoad = "open_load"
  case pageRender = "page_render"
  case detection
  case undo = "undo"
  case redo = "redo"
  case save
  case impactValidation = "impact_validation"
  case ocr
  case vectorParse = "vector_parse"
  case diff
  case templateMatch = "template_match"
}

public enum PerformanceOutcome: String, Codable, Sendable {
  case success
  case failure
}

/// One bounded, value-free timing sample.
public struct PerformanceSample: Codable, Equatable, Sendable {
  public let stage: PerformanceStage
  public let durationMilliseconds: Double
  public let outcome: PerformanceOutcome

  public init(
    stage: PerformanceStage,
    durationNanoseconds: UInt64,
    outcome: PerformanceOutcome = .success
  ) {
    self.stage = stage
    self.durationMilliseconds = Double(durationNanoseconds) / 1_000_000
    self.outcome = outcome
  }
}

/// Percentiles are computed from completed samples, including failed samples.
/// Failure count is reported separately so a fast failure cannot be mistaken for
/// a successful performance improvement.
public struct PerformanceSummary: Codable, Equatable, Sendable {
  public let stage: PerformanceStage
  public let sampleCount: Int
  public let successfulSampleCount: Int
  public let failedSampleCount: Int
  public let minimumMilliseconds: Double?
  public let p50Milliseconds: Double?
  public let p95Milliseconds: Double?
  public let maximumMilliseconds: Double?

  public init(stage: PerformanceStage, samples: [PerformanceSample]) {
    let stageSamples = samples.filter { $0.stage == stage }
    let durations = stageSamples.map(\.durationMilliseconds).sorted()
    self.stage = stage
    self.sampleCount = stageSamples.count
    self.successfulSampleCount = stageSamples.filter { $0.outcome == .success }.count
    self.failedSampleCount = stageSamples.filter { $0.outcome == .failure }.count
    self.minimumMilliseconds = durations.first
    self.p50Milliseconds = Self.percentile(durations, fraction: 0.50)
    self.p95Milliseconds = Self.percentile(durations, fraction: 0.95)
    self.maximumMilliseconds = durations.last
  }

  private static func percentile(_ values: [Double], fraction: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    let oneBasedRank = max(1, Int(ceil(Double(values.count) * fraction)))
    return values[min(oneBasedRank - 1, values.count - 1)]
  }
}

/// A production-safe, opt-in recorder for native timing spans.
///
/// The recorder is disabled unless `PDF_EDITOR_PERF_TELEMETRY=1` is present, or
/// the caller explicitly creates it with `enabled: true` for a benchmark. When
/// enabled it keeps only a bounded in-memory ring and emits value-free signposts.
/// It never writes files, retains document objects, or serializes error details.
public final class PerformanceTelemetry: @unchecked Sendable {
  public static let shared = PerformanceTelemetry()

  public let enabled: Bool
  public let capacity: Int

  private static let log = OSLog(
    subsystem: "com.pdfeditor.native",
    category: "performance"
  )

  private let lock = NSLock()
  private var ring: [PerformanceSample] = []
  private var nextIndex = 0

  public init(
    capacity: Int = 512,
    enabled: Bool = ProcessInfo.processInfo.environment["PDF_EDITOR_PERF_TELEMETRY"] == "1"
  ) {
    self.capacity = max(1, capacity)
    self.enabled = enabled
    self.ring.reserveCapacity(max(1, capacity))
  }

  @discardableResult
  public func measure<T>(
    _ stage: PerformanceStage,
    operation: () throws -> T
  ) rethrows -> T {
    let measurement = begin(stage)
    do {
      let result = try operation()
      measurement.end()
      return result
    } catch {
      measurement.end(outcome: .failure)
      throw error
    }
  }

  public func measureOpenLoad<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.openLoad, operation: operation)
  }

  public func measurePageRender<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.pageRender, operation: operation)
  }

  public func measureDetection<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.detection, operation: operation)
  }

  public func measureUndo<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.undo, operation: operation)
  }

  public func measureRedo<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.redo, operation: operation)
  }

  public func measureSave<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.save, operation: operation)
  }

  public func measureImpactValidation<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.impactValidation, operation: operation)
  }

  public func measureOCR<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.ocr, operation: operation)
  }

  public func measureVectorParse<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.vectorParse, operation: operation)
  }

  public func measureDiff<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.diff, operation: operation)
  }

  public func measureTemplateMatch<T>(_ operation: () throws -> T) rethrows -> T {
    try measure(.templateMatch, operation: operation)
  }

  public func begin(_ stage: PerformanceStage) -> PerformanceMeasurement {
    let start = DispatchTime.now().uptimeNanoseconds
    let signpostID = OSSignpostID(log: Self.log)
    if enabled {
      os_signpost(
        .begin,
        log: Self.log,
        name: "PDF editor stage",
        signpostID: signpostID
      )
    }
    return PerformanceMeasurement(
      telemetry: self,
      stage: stage,
      startNanoseconds: start,
      signpostID: signpostID
    )
  }

  public func record(
    stage: PerformanceStage,
    durationNanoseconds: UInt64,
    outcome: PerformanceOutcome = .success
  ) {
    guard enabled else { return }
    let sample = PerformanceSample(
      stage: stage,
      durationNanoseconds: durationNanoseconds,
      outcome: outcome
    )
    lock.lock()
    defer { lock.unlock() }
    if ring.count < capacity {
      ring.append(sample)
    } else {
      ring[nextIndex] = sample
      nextIndex = (nextIndex + 1) % capacity
    }
  }

  public func samples() -> [PerformanceSample] {
    guard enabled else { return [] }
    lock.lock()
    defer { lock.unlock() }
    guard ring.count == capacity else { return ring }
    return Array(ring[nextIndex...]) + Array(ring[..<nextIndex])
  }

  public func summaries() -> [PerformanceSummary] {
    let currentSamples = samples()
    return PerformanceStage.allCases.map {
      PerformanceSummary(stage: $0, samples: currentSamples)
    }
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    ring.removeAll(keepingCapacity: true)
    nextIndex = 0
  }

  fileprivate func finish(
    stage: PerformanceStage,
    startNanoseconds: UInt64,
    signpostID: OSSignpostID,
    outcome: PerformanceOutcome
  ) {
    let end = DispatchTime.now().uptimeNanoseconds
    if enabled {
      os_signpost(
        .end,
        log: Self.log,
        name: "PDF editor stage",
        signpostID: signpostID
      )
      record(
        stage: stage,
        durationNanoseconds: end >= startNanoseconds ? end - startNanoseconds : 0,
        outcome: outcome
      )
    }
  }
}

/// A span handle is useful when an operation cannot be expressed as one closure,
/// such as a UI callback with early returns.
public final class PerformanceMeasurement: @unchecked Sendable {
  private let telemetry: PerformanceTelemetry
  private let stage: PerformanceStage
  private let startNanoseconds: UInt64
  private let signpostID: OSSignpostID
  private let lock = NSLock()
  private var didEnd = false

  fileprivate init(
    telemetry: PerformanceTelemetry,
    stage: PerformanceStage,
    startNanoseconds: UInt64,
    signpostID: OSSignpostID
  ) {
    self.telemetry = telemetry
    self.stage = stage
    self.startNanoseconds = startNanoseconds
    self.signpostID = signpostID
  }

  public func end(outcome: PerformanceOutcome = .success) {
    lock.lock()
    guard !didEnd else {
      lock.unlock()
      return
    }
    didEnd = true
    lock.unlock()
    telemetry.finish(
      stage: stage,
      startNanoseconds: startNanoseconds,
      signpostID: signpostID,
      outcome: outcome
    )
  }
}

/// The native page-draw seam used by the app and standalone PDFKit benchmarks.
/// Encoding a PNG or publishing an output file belongs in a separate save span.
public enum PDFPerformancePageRenderer {
  public static func draw(
    page: PDFPage,
    in context: CGContext,
    box: PDFDisplayBox = .mediaBox,
    telemetry: PerformanceTelemetry = .shared
  ) {
    telemetry.measurePageRender {
      page.draw(with: box, to: context)
    }
  }
}
