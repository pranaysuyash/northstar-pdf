import Foundation

/// F-009: pdf_oxide Text Extraction
///
/// First-principle: Use the fastest available text extraction engine that's
/// license-safe (MIT) and doesn't share code with the renderer.
///
/// Architecture:
/// - Wraps `pdf_oxide` CLI for text extraction
/// - Conforms to `CascadeProvider` and `ShadowExtractor`
/// - Produces structured extraction results
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Capability routing — pdf_oxide as fast extractor
/// - OPERATING_DOCTRINE §3: Verify at right evidence level
/// - License: MIT (permissive, no copyleft concerns)
/// - Long-term: pdf_oxide is the fastest Rust-based PDF text extractor
///
/// Note: pdf_oxide must be installed separately (`cargo install pdf_oxide`).
/// If not available, the cascade falls through to the next provider.

/// Structured result from pdf_oxide text extraction.
public struct PdfOxideExtractionResult: Sendable, Equatable {
  public let text: String
  public let pageCount: Int
  public let characterCount: Int
  public let pageTexts: [String] // text per page
  public let rawOutput: String

  public init(
    text: String,
    pageCount: Int,
    characterCount: Int,
    pageTexts: [String] = [],
    rawOutput: String = ""
  ) {
    self.text = text
    self.pageCount = pageCount
    self.characterCount = characterCount
    self.pageTexts = pageTexts
    self.rawOutput = rawOutput
  }
}

/// pdf_oxide-based text extractor.
/// Conforms to CascadeProvider and ShadowExtractor for use in cascades and shadow mode.
public struct PdfOxideExtractor: CascadeProvider, ShadowExtractor {
  public let name = "pdf_oxide"
  public let priority = 30 // After PDFKit (10), QPDF (20)

  public var isAvailable: Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["pdf_oxide"]
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
    let result = try extract(input: input)
    guard let output = result as? T else {
      throw NSError(domain: "PdfOxideExtractor", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Type mismatch: expected \(T.self), got PdfOxideExtractionResult"
      ])
    }
    return output
  }

  /// ShadowExtractor conformance
  public func extractText(from data: Data) throws -> ShadowExtractionResult {
    let start = CFAbsoluteTimeGetCurrent()
    let result = try extract(input: data)
    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    return ShadowExtractionResult(
      pageCount: result.pageCount,
      characterCount: result.characterCount,
      text: result.text,
      timeMs: elapsed
    )
  }

  /// Extract text using pdf_oxide CLI.
  public func extract(input: Data) throws -> PdfOxideExtractionResult {
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-oxide-extract-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    try input.write(to: tempURL)

    // Try `pdf_oxide extract-text` first (if available)
    let result = try extractTextCLI(url: tempURL)
    return result
  }

  private func extractTextCLI(url: URL) throws -> PdfOxideExtractionResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["pdf_oxide", "extract-text", url.path]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
      try process.run()
    } catch {
      throw NSError(domain: "PdfOxideExtractor", code: -2, userInfo: [
        NSLocalizedDescriptionKey: "Failed to launch pdf_oxide: \(error.localizedDescription)"
      ])
    }

    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

    guard process.terminationStatus == 0 else {
      throw NSError(domain: "PdfOxideExtractor", code: Int(process.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "pdf_oxide failed: \(stderr)"
      ])
    }

    let text = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    let pageCount = countPages(from: url)
    let characterCount = text.count

    return PdfOxideExtractionResult(
      text: text,
      pageCount: pageCount,
      characterCount: characterCount,
      rawOutput: stdout
    )
  }

  private func countPages(from url: URL) -> Int {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["pdf_oxide", "info", url.path]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
      process.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""

      // Try to find page count in output (format varies by version)
      for line in output.components(separatedBy: "\n") {
        if line.lowercased().contains("pages") {
          let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
          if let count = numbers.first, count > 0 {
            return count
          }
        }
      }
      return 1 // Default to 1 page if we can't determine
    } catch {
      return 1
    }
  }
}
