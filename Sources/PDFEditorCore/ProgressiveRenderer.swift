import AppKit
import CoreGraphics
import Foundation
import PDFKit

/// Stage 3: Progressive Renderer
///
/// First principle: Rasterization is lossy. Convert vectors to pixels at exact DPI needed.
/// Progressive: low-res first (instant feedback), high-res in background (quality).
///
/// Architecture:
/// - `ProgressiveRenderer`: orchestrates progressive rendering
/// - `RenderLevel`: low, medium, high resolution
/// - `RenderedPage`: page at specific resolution
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §3: Do things smartly — render what's needed, when needed
/// - OPERATING_DOCTRINE §8: Capability routing — different quality for different contexts
/// - Long-term: Foundation for adaptive rendering

/// Rendering quality level.
public enum RenderLevel: Int, Sendable, Comparable {
  case low = 72      // Screen preview
  case medium = 150  // Good screen quality
  case high = 300    // Print quality

  public static func < (lhs: RenderLevel, rhs: RenderLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public var dpi: Int { rawValue }

  public var displayName: String {
    switch self {
    case .low: return "Preview"
    case .medium: return "Standard"
    case .high: return "High Quality"
    }
  }
}

/// A rendered page at specific resolution.
public struct RenderedPage: Sendable {
  public let pageIndex: Int
  public let level: RenderLevel
  public let width: Int // pixels
  public let height: Int // pixels
  public let imageData: Data // PNG or TIFF
  public let renderTimeMs: Double

  public init(
    pageIndex: Int,
    level: RenderLevel,
    width: Int,
    height: Int,
    imageData: Data,
    renderTimeMs: Double
  ) {
    self.pageIndex = pageIndex
    self.level = level
    self.width = width
    self.height = height
    self.imageData = imageData
    self.renderTimeMs = renderTimeMs
  }
}

/// Progressive renderer with caching.
public final class ProgressiveRenderer: @unchecked Sendable {
  private var cache: [Int: [Int: RenderedPage]] = [:] // [pageIndex][level] -> RenderedPage
  private let lock = NSLock()

  public init() {}

  /// Render page at specific level (synchronous).
  public func renderPage(data: Data, pageIndex: Int, level: RenderLevel) -> RenderedPage? {
    renderPage(data: data, pageIndex: pageIndex, dpi: level.dpi)
  }

  /// Render page at an exact DPI (synchronous).
  ///
  /// This is the core rasterizer. `renderPage(data:pageIndex:level:)` maps a
  /// named quality level onto it; callers that need a specific pixel budget
  /// (e.g. thumbnail rails) pass the DPI directly.
  public func renderPage(data: Data, pageIndex: Int, dpi: Int) -> RenderedPage? {
    let startTime = CFAbsoluteTimeGetCurrent()

    guard let document = PDFDocument(data: data) else {
      return nil
    }

    guard pageIndex >= 0, pageIndex < document.pageCount else {
      return nil
    }

    guard let page = document.page(at: pageIndex) else {
      return nil
    }

    let bounds = page.bounds(for: .mediaBox)
    let scale = CGFloat(dpi) / 72.0 // 72 DPI is PDF default
    let pixelWidth = max(1, Int(bounds.width * scale))
    let pixelHeight = max(1, Int(bounds.height * scale))

    // Create bitmap context
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
      data: nil,
      width: pixelWidth,
      height: pixelHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: bitmapInfo
    ) else {
      return nil
    }

    // Fill white background
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    // Scale and draw page
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)

    guard let image = context.makeImage() else {
      return nil
    }

    // Convert to PNG data
    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else {
      return nil
    }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    let rendered = RenderedPage(
      pageIndex: pageIndex,
      level: RenderLevel(rawValue: dpi) ?? .medium,
      width: pixelWidth,
      height: pixelHeight,
      imageData: mutableData as Data,
      renderTimeMs: elapsed
    )

    // Cache the result
    lock.lock()
    if cache[pageIndex] == nil {
      cache[pageIndex] = [:]
    }
    cache[pageIndex]?[dpi] = rendered
    lock.unlock()

    return rendered
  }

  /// Get cached render if available.
  public func getCached(pageIndex: Int, level: RenderLevel) -> RenderedPage? {
    lock.lock()
    defer { lock.unlock() }
    return cache[pageIndex]?[level.rawValue]
  }

  /// Get cached render if available at an exact DPI.
  public func getCached(pageIndex: Int, dpi: Int) -> RenderedPage? {
    lock.lock()
    defer { lock.unlock() }
    return cache[pageIndex]?[dpi]
  }

  /// Clear cache.
  public func clearCache() {
    lock.lock()
    defer { lock.unlock() }
    cache.removeAll()
  }

  /// Get cache stats.
  public var cacheStats: (count: Int, totalSize: Int) {
    lock.lock()
    defer { lock.unlock() }
    let count = cache.values.reduce(0) { $0 + $1.count }
    let totalSize = cache.values.reduce(0) { partial, byLevel in
      partial + byLevel.values.reduce(0) { $0 + $1.imageData.count }
    }
    return (count: count, totalSize: totalSize)
  }
}
