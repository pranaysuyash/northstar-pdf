import AppKit
import CoreGraphics
import Foundation
import PDFKit

/// Stage 4: Tile-Based Display
///
/// First principle: Display is perception. The best display is invisible.
/// Tile-based: divide pages into tiles, render visible tiles first, cache aggressively.
///
/// Architecture:
/// - `TileBasedDisplay`: orchestrates tile-based rendering
/// - `PageTile`: a tile of a page (e.g., 256×256 pixels)
/// - `TileCache`: caches rendered tiles across pages
/// - `ViewportState`: tracks what's visible
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §3: Do things smartly — render only what's visible
/// - OPERATING_DOCTRINE §8: Capability routing — different quality for different contexts
/// - Long-term: Foundation for smooth scrolling and zoom

/// A tile of a page.
public struct PageTile: Sendable, Identifiable {
  public let id: String // "page-x-y"
  public let pageIndex: Int
  public let tileX: Int
  public let tileY: Int
  public let bounds: CGRect // in page coordinates
  public let pixelBounds: CGRect // in pixel coordinates
  public let imageData: Data
  public let renderTimeMs: Double

  public init(
    pageIndex: Int,
    tileX: Int,
    tileY: Int,
    bounds: CGRect,
    pixelBounds: CGRect,
    imageData: Data,
    renderTimeMs: Double
  ) {
    self.id = "\(pageIndex)-\(tileX)-\(tileY)"
    self.pageIndex = pageIndex
    self.tileX = tileX
    self.tileY = tileY
    self.bounds = bounds
    self.pixelBounds = pixelBounds
    self.imageData = imageData
    self.renderTimeMs = renderTimeMs
  }
}

/// Viewport state tracking.
public struct ViewportState: Sendable {
  public let pageIndex: Int
  public let visibleRect: CGRect // in page coordinates
  public let scale: CGFloat
  public let dpi: Int

  public init(
    pageIndex: Int,
    visibleRect: CGRect,
    scale: CGFloat = 1.0,
    dpi: Int = 150
  ) {
    self.pageIndex = pageIndex
    self.visibleRect = visibleRect
    self.scale = scale
    self.dpi = dpi
  }
}

/// Tile-based display with caching.
public final class TileBasedDisplay: @unchecked Sendable {
  private let tileSize: Int // pixels
  private var cache: [String: PageTile] = [:]
  /// Insertion order of cache keys; oldest first. Drives LRU eviction.
  private var cacheOrder: [String] = []
  private let maxCacheTiles: Int
  private let lock = NSLock()
  private var hitCount = 0
  private var missCount = 0

  public init(tileSize: Int = 256, maxCacheTiles: Int = 200) {
    self.tileSize = tileSize
    self.maxCacheTiles = maxCacheTiles
  }

  /// Get tiles needed for current viewport.
  ///
  /// The page is parsed once per call (not once per tile), and the tile grid
  /// is derived from the page's real media box instead of a hardcoded
  /// 612×792 letter assumption.
  public func getTiles(
    data: Data,
    viewport: ViewportState
  ) -> [PageTile] {
    guard let document = PDFDocument(data: data),
      viewport.pageIndex >= 0,
      viewport.pageIndex < document.pageCount,
      let page = document.page(at: viewport.pageIndex)
    else {
      return []
    }

    let pageBounds = page.bounds(for: .mediaBox)
    let grid = tileGrid(pageBounds: pageBounds, dpi: viewport.dpi)
    var tiles: [PageTile] = []

    for tileY in 0..<grid.rows {
      for tileX in 0..<grid.columns {
        let tileBounds = tileBounds(
          tileX: tileX,
          tileY: tileY,
          tileSize: tileSize,
          dpi: viewport.dpi
        )
        guard tileBounds.intersects(viewport.visibleRect) else { continue }
        let tile = tileFor(
          document: document,
          page: page,
          pageIndex: viewport.pageIndex,
          tileX: tileX,
          tileY: tileY,
          tileBounds: tileBounds,
          dpi: viewport.dpi
        )
        tiles.append(tile)
      }
    }

    return tiles
  }

  /// Pre-render tiles around viewport for smooth scrolling.
  ///
  /// Runs off the main thread and only renders tiles that are not already
  /// cached. The expanded region is the viewport grown by
  /// `preRenderMargin` tiles on every side.
  public func preRenderTiles(
    data: Data,
    viewport: ViewportState,
    preRenderMargin: Int = 1
  ) {
    guard let document = PDFDocument(data: data),
      viewport.pageIndex >= 0,
      viewport.pageIndex < document.pageCount,
      let page = document.page(at: viewport.pageIndex)
    else {
      return
    }

    let pageBounds = page.bounds(for: .mediaBox)
    let grid = tileGrid(pageBounds: pageBounds, dpi: viewport.dpi)
    let tileSpan = tileSizeInPoints(dpi: viewport.dpi)
    let expanded = viewport.visibleRect.insetBy(
      dx: -CGFloat(preRenderMargin) * tileSpan,
      dy: -CGFloat(preRenderMargin) * tileSpan
    )

    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }

      for tileY in 0..<grid.rows {
        for tileX in 0..<grid.columns {
          let tileBounds = self.tileBounds(
            tileX: tileX,
            tileY: tileY,
            tileSize: self.tileSize,
            dpi: viewport.dpi
          )
          guard tileBounds.intersects(expanded) else { continue }

          let key = "\(viewport.pageIndex)-\(tileX)-\(tileY)-\(viewport.dpi)"
          self.lock.lock()
          let isCached = self.cache[key] != nil
          self.lock.unlock()
          if isCached { continue }

          _ = self.tileFor(
            document: document,
            page: page,
            pageIndex: viewport.pageIndex,
            tileX: tileX,
            tileY: tileY,
            tileBounds: tileBounds,
            dpi: viewport.dpi
          )
        }
      }
    }
  }

  /// Clear cache.
  public func clearCache() {
    lock.lock()
    defer { lock.unlock() }
    cache.removeAll()
    cacheOrder.removeAll()
    hitCount = 0
    missCount = 0
  }

  /// Get cache stats.
  public var cacheStats: (count: Int, hitRate: Double) {
    lock.lock()
    defer { lock.unlock() }
    let total = hitCount + missCount
    let hitRate = total > 0 ? Double(hitCount) / Double(total) : 0
    return (count: cache.count, hitRate: hitRate)
  }

  // MARK: - Private

  private struct TileGrid {
    let columns: Int
    let rows: Int
  }

  private func tileGrid(pageBounds: CGRect, dpi: Int) -> TileGrid {
    let span = tileSizeInPoints(dpi: dpi)
    let columns = max(1, Int(ceil(pageBounds.width / span)))
    let rows = max(1, Int(ceil(pageBounds.height / span)))
    return TileGrid(columns: columns, rows: rows)
  }

  private func tileSizeInPoints(dpi: Int) -> CGFloat {
    let scale = CGFloat(dpi) / 72.0
    return CGFloat(tileSize) / scale
  }

  private func tileBounds(
    tileX: Int,
    tileY: Int,
    tileSize: Int,
    dpi: Int
  ) -> CGRect {
    let span = tileSizeInPoints(dpi: dpi)
    return CGRect(
      x: CGFloat(tileX) * span,
      y: CGFloat(tileY) * span,
      width: span,
      height: span
    )
  }

  private func tileFor(
    document: PDFDocument,
    page: PDFPage,
    pageIndex: Int,
    tileX: Int,
    tileY: Int,
    tileBounds: CGRect,
    dpi: Int
  ) -> PageTile {
    let tileID = "\(pageIndex)-\(tileX)-\(tileY)-\(dpi)"

    // Check cache
    lock.lock()
    if let cached = cache[tileID] {
      hitCount += 1
      lock.unlock()
      return cached
    }
    missCount += 1
    lock.unlock()

    // Render tile
    let startTime = CFAbsoluteTimeGetCurrent()
    let scale = CGFloat(dpi) / 72.0
    let pixelWidth = tileSize
    let pixelHeight = tileSize

    // Create bitmap context for tile
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
      return PageTile(
        pageIndex: pageIndex,
        tileX: tileX,
        tileY: tileY,
        bounds: tileBounds,
        pixelBounds: CGRect(x: 0, y: 0, width: tileSize, height: tileSize),
        imageData: Data(),
        renderTimeMs: 0
      )
    }

    // Fill white background
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    // Translate to tile position and scale
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -tileBounds.origin.x, y: -tileBounds.origin.y)

    // Draw page
    page.draw(with: .mediaBox, to: context)

    guard let image = context.makeImage() else {
      return PageTile(
        pageIndex: pageIndex,
        tileX: tileX,
        tileY: tileY,
        bounds: tileBounds,
        pixelBounds: CGRect(x: 0, y: 0, width: tileSize, height: tileSize),
        imageData: Data(),
        renderTimeMs: 0
      )
    }

    // Convert to PNG
    let mutableData = NSMutableData()
    if let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) {
      CGImageDestinationAddImage(destination, image, nil)
      CGImageDestinationFinalize(destination)
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    let tile = PageTile(
      pageIndex: pageIndex,
      tileX: tileX,
      tileY: tileY,
      bounds: tileBounds,
      pixelBounds: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight),
      imageData: mutableData as Data,
      renderTimeMs: elapsed
    )

    // Cache tile (LRU eviction)
    lock.lock()
    if cache[tileID] == nil {
      if cache.count >= maxCacheTiles, let oldest = cacheOrder.first {
        cache.removeValue(forKey: oldest)
        cacheOrder.removeFirst()
      }
      cache[tileID] = tile
      cacheOrder.append(tileID)
    }
    lock.unlock()

    return tile
  }
}