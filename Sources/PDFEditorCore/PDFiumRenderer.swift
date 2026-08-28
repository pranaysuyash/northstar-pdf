import AppKit
import CoreGraphics
import Foundation

/// E-001: PDFium Rendering Provider
///
/// First-principle: Use the fastest, most compatible rendering engine available.
/// PDFium (BSD-2) is Google's PDF renderer used in Chrome — the most battle-tested
/// open-source PDF renderer in existence.
///
/// Architecture:
/// - `PDFiumRenderer` protocol: abstracts rendering capability
/// - `PDFiumCLIRenderer`: wraps `pdfium` CLI when available
/// - `PDFiumFFIRenderer`: wraps PDFium C API via FFI (when linked)
/// - Falls back to PDFKit when PDFium is unavailable
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Capability routing — try best renderer first
/// - OPERATING_DOCTRINE §9: Evolution — prepare for PDFium adoption
/// - License: BSD-2 (permissive, no copyleft concerns)
/// - Long-term: PDFium is the gold standard for PDF rendering
///
/// Integration path:
/// 1. Install PDFium: `brew install pdfium` (when available) or build from source
/// 2. Link via SPM: Add PDFium as a system library dependency
/// 3. Use `PDFiumCLIRenderer` for CLI-based rendering (no linking required)
/// 4. Use `PDFiumFFIRenderer` for native rendering (requires linking)

/// A renderer that can produce images from PDF pages.
public protocol PDFiumRenderer: Sendable {
  /// Renderer name for reporting
  var name: String { get }

  /// Whether this renderer is available on the current system
  var isAvailable: Bool { get }

  /// Render a PDF page to an image
  func renderPage(
    from data: Data,
    pageIndex: Int,
    scale: Double
  ) throws -> PDFiumRenderResult

  /// Get page count from PDF data
  func pageCount(from data: Data) throws -> Int
}

/// Result from a PDFium rendering operation.
public struct PDFiumRenderResult: Sendable {
  public let image: Data // PNG or TIFF data
  public let width: Int
  public let height: Int
  public let pageIndex: Int
  public let scale: Double
  public let rendererName: String
  public let timeMs: Double

  public init(
    image: Data,
    width: Int,
    height: Int,
    pageIndex: Int,
    scale: Double,
    rendererName: String,
    timeMs: Double = 0
  ) {
    self.image = image
    self.width = width
    self.height = height
    self.pageIndex = pageIndex
    self.scale = scale
    self.rendererName = rendererName
    self.timeMs = timeMs
  }
}

/// PDFium CLI-based renderer (no linking required).
/// Requires: `pdfium` CLI tool in PATH.
public struct PDFiumCLIRenderer: PDFiumRenderer {
  public let name = "PDFium-CLI"
  public let isAvailable: Bool

  public init() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["pdfium"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
      self.isAvailable = process.terminationStatus == 0
    } catch {
      self.isAvailable = false
    }
  }

  public func renderPage(from data: Data, pageIndex: Int, scale: Double) throws -> PDFiumRenderResult {
    let start = CFAbsoluteTimeGetCurrent()

    let tempPDF = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfium-render-\(UUID().uuidString).pdf")
    let tempPNG = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfium-render-\(UUID().uuidString).png")
    defer {
      try? FileManager.default.removeItem(at: tempPDF)
      try? FileManager.default.removeItem(at: tempPNG)
    }

    try data.write(to: tempPDF)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "pdfium", "render",
      "--page", "\(pageIndex)",
      "--scale", "\(scale)",
      "--output", tempPNG.path,
      tempPDF.path
    ]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
      let error = String(data: errorData, encoding: .utf8) ?? "Unknown error"
      throw NSError(domain: "PDFiumCLIRenderer", code: Int(process.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "PDFium render failed: \(error)"
      ])
    }

    let imageData = try Data(contentsOf: tempPNG)
    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    return PDFiumRenderResult(
      image: imageData,
      width: 0, // Would need to parse PNG header
      height: 0,
      pageIndex: pageIndex,
      scale: scale,
      rendererName: name,
      timeMs: elapsed
    )
  }

  public func pageCount(from data: Data) throws -> Int {
    let tempPDF = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdfium-pages-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: tempPDF) }

    try data.write(to: tempPDF)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["pdfium", "info", tempPDF.path]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    // Parse page count from output
    for line in output.components(separatedBy: "\n") {
      if line.lowercased().contains("pages") {
        let numbers = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
          .compactMap { Int($0) }
        if let count = numbers.first, count > 0 {
          return count
        }
      }
    }
    return 1
  }
}

/// PDFKit-based renderer (system default, always available).
/// Used as fallback when PDFium is unavailable.
public struct PDFKitFallbackRenderer: PDFiumRenderer {
  public let name = "PDFKit"
  public let isAvailable = true // Always available on macOS

  public init() {}

  public func renderPage(from data: Data, pageIndex: Int, scale: Double) throws -> PDFiumRenderResult {
    let start = CFAbsoluteTimeGetCurrent()

    guard let document = PDFDocument(data: data) else {
      throw NSError(domain: "PDFKitFallbackRenderer", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Failed to open PDF document"
      ])
    }

    guard pageIndex >= 0, pageIndex < document.pageCount else {
      throw NSError(domain: "PDFKitFallbackRenderer", code: -2, userInfo: [
        NSLocalizedDescriptionKey: "Page index \(pageIndex) out of range (0..\(document.pageCount - 1))"
      ])
    }

    guard let page = document.page(at: pageIndex) else {
      throw NSError(domain: "PDFKitFallbackRenderer", code: -3, userInfo: [
        NSLocalizedDescriptionKey: "Failed to get page \(pageIndex)"
      ])
    }

    let bounds = page.bounds(for: .mediaBox)
    let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

    let image = page.thumbnail(of: size, for: .mediaBox)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
      throw NSError(domain: "PDFKitFallbackRenderer", code: -4, userInfo: [
        NSLocalizedDescriptionKey: "Failed to render page to PNG"
      ])
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

    return PDFiumRenderResult(
      image: pngData,
      width: Int(size.width),
      height: Int(size.height),
      pageIndex: pageIndex,
      scale: scale,
      rendererName: name,
      timeMs: elapsed
    )
  }

  public func pageCount(from data: Data) throws -> Int {
    guard let document = PDFDocument(data: data) else {
      throw NSError(domain: "PDFKitFallbackRenderer", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Failed to open PDF document"
      ])
    }
    return document.pageCount
  }
}

import PDFKit
