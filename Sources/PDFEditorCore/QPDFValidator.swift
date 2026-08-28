import Foundation

/// F-008: QPDF Validation Pipeline
///
/// First-principle: Validate PDF structural integrity using an independent,
/// license-safe (Apache-2.0) tool that doesn't share code with the renderer.
///
/// Architecture:
/// - Wraps `qpdf --check` for structural validation
/// - Conforms to `CascadeProvider` for use in library cascades
/// - Produces structured validation results
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Capability routing — QPDF as independent validator
/// - OPERATING_DOCTRINE §3: Verify at right evidence level
/// - License: Apache-2.0 (permissive, no copyleft concerns)
/// - Long-term: QPDF is the gold standard for PDF structural validation

/// Structured result from QPDF validation.
public struct QPDFValidationResult: Sendable, Equatable {
  public let isValid: Bool
  public let warnings: [String]
  public let errors: [String]
  public let pageNumberCount: Int?
  public let pdfVersion: String?
  public let rawOutput: String

  public init(
    isValid: Bool,
    warnings: [String] = [],
    errors: [String] = [],
    pageNumberCount: Int? = nil,
    pdfVersion: String? = nil,
    rawOutput: String = ""
  ) {
    self.isValid = isValid
    self.warnings = warnings
    self.errors = errors
    self.pageNumberCount = pageNumberCount
    self.pdfVersion = pdfVersion
    self.rawOutput = rawOutput
  }
}

/// QPDF-based PDF structural validator.
/// Conforms to CascadeProvider for use in library cascades.
public struct QPDFValidator: CascadeProvider {
  public let name = "QPDF"
  public let priority = 20 // After PDFKit (10), before pdf_oxide (30)

  public var isAvailable: Bool {
    // Check if qpdf is in PATH
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["qpdf"]
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

  /// Validate PDF structure using `qpdf --check`.
  public func execute<T>(input: Data) throws -> T {
    let result = try validate(input: input)
    guard let output = result as? T else {
      throw NSError(domain: "QPDFValidator", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Type mismatch: expected \(T.self), got QPDFValidationResult"
      ])
    }
    return output
  }

  /// Validate PDF structure using `qpdf --check`.
  public func validate(input: Data) throws -> QPDFValidationResult {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("qpdf-validate-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    try input.write(to: tempURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["qpdf", "--check", tempURL.path]

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

    let isValid = process.terminationStatus == 0

    // Parse warnings and errors
    var warnings: [String] = []
    var errors: [String] = []

    for line in combined.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.contains("WARNING") || trimmed.contains("warning") {
        warnings.append(trimmed)
      }
      if trimmed.contains("ERROR") || trimmed.contains("error") {
        errors.append(trimmed)
      }
    }

    // Try to extract page count from qpdf --show-npages
    let pageCount = extractPageCount(from: tempURL)

    return QPDFValidationResult(
      isValid: isValid,
      warnings: warnings,
      errors: errors,
      pageNumberCount: pageCount,
      rawOutput: combined
    )
  }

  private func extractPageCount(from url: URL) -> Int? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["qpdf", "--show-npages", url.path]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
      return output.flatMap { Int($0) }
    } catch {
      return nil
    }
  }
}
