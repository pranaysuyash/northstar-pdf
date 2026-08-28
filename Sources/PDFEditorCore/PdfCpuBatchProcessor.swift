import Foundation

/// E-004: pdfcpu Batch Operations
///
/// First-principle: Use the best tool for batch operations — pdfcpu is a
/// Go-based PDF processor with excellent batch capabilities and Apache-2.0 license.
///
/// Architecture:
/// - Wraps `pdfcpu` CLI for batch operations (merge, split, rotate, watermark)
/// - Conforms to `CascadeProvider` for use in library cascades
/// - Produces structured batch results
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Capability routing — pdfcpu for batch operations
/// - OPERATING_DOCTRINE §3: Verify at right evidence level
/// - License: Apache-2.0 (permissive, no copyleft concerns)
/// - Long-term: pdfcpu is the best Go-based PDF batch processor
///
/// Note: pdfcpu must be installed separately (`go install github.com/pdfcpu/pdfcpu/cmd/pdfcpu@latest`).

/// A batch operation that can be performed on PDFs.
public enum PdfCpuBatchOperation: Sendable {
  case merge([Data])
  case split(Data, pages: String) // e.g., "1-5" or "1,3,5-7"
  case rotate(Data, angle: Int) // 90, 180, 270
  case watermark(Data, text: String)
  case validate(Data)
  case encrypt(Data, password: String)
  case decrypt(Data, password: String)
}

/// Result from a pdfcpu batch operation.
public struct PdfCpuBatchResult: Sendable {
  public let success: Bool
  public let outputData: Data?
  public let operation: String
  public let rawOutput: String
  public let timeMs: Double

  public init(
    success: Bool,
    outputData: Data? = nil,
    operation: String,
    rawOutput: String = "",
    timeMs: Double = 0
  ) {
    self.success = success
    self.outputData = outputData
    self.operation = operation
    self.rawOutput = rawOutput
    self.timeMs = timeMs
  }
}

/// pdfcpu-based batch processor.
/// Conforms to CascadeProvider for use in library cascades.
public struct PdfCpuBatchProcessor: CascadeProvider {
  public let name = "pdfcpu"
  public let priority = 25 // Between QPDF (20) and pdf_oxide (30)

  public var isAvailable: Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["pdfcpu"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus == 0
    } catch {
      return false
    }
  }

  public init() {}

  /// CascadeProvider conformance
  public func execute<T>(input: Data) throws -> T {
    let result = try validate(input: input)
    guard let output = result as? T else {
      throw NSError(domain: "PdfCpuBatchProcessor", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Type mismatch: expected \(T.self), got PdfCpuBatchResult"
      ])
    }
    return output
  }

  /// Validate PDF structure using pdfcpu.
  public func validate(input: Data) throws -> PdfCpuBatchResult {
    let start = CFAbsoluteTimeGetCurrent()

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfcpu-validate-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    try input.write(to: tempURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["pdfcpu", "validate", tempURL.path]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
    let combined = stdout + "\n" + stderr

    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    return PdfCpuBatchResult(
      success: process.terminationStatus == 0,
      operation: "validate",
      rawOutput: combined,
      timeMs: elapsed
    )
  }

  /// Merge multiple PDFs into one.
  public func merge(inputs: [Data]) throws -> PdfCpuBatchResult {
    let start = CFAbsoluteTimeGetCurrent()

    var tempURLs: [URL] = []
    for (index, input) in inputs.enumerated() {
      let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("pdfcpu-merge-\(UUID().uuidString)-\(index).pdf")
      try input.write(to: url)
      tempURLs.append(url)
    }
    defer {
      for url in tempURLs {
        try? FileManager.default.removeItem(at: url)
      }
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfcpu-merged-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["pdfcpu", "merge"] + tempURLs.map(\.path) + [outputURL.path]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let outputData = try? Data(contentsOf: outputURL)
    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    return PdfCpuBatchResult(
      success: process.terminationStatus == 0,
      outputData: outputData,
      operation: "merge",
      timeMs: elapsed
    )
  }

  /// Split a PDF into individual pages.
  public func split(input: Data, pages: String) throws -> PdfCpuBatchResult {
    let start = CFAbsoluteTimeGetCurrent()

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfcpu-split-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    try input.write(to: tempURL)

    let outputDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfcpu-split-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: outputDir) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["pdfcpu", "split", tempURL.path, outputDir.path, pages]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    return PdfCpuBatchResult(
      success: process.terminationStatus == 0,
      operation: "split",
      timeMs: elapsed
    )
  }
}
