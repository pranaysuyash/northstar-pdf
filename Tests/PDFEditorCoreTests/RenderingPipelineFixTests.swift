import Foundation
import PDFEditorCore
import PDFKit
import Testing

// MARK: - Mutation-first tests for the rendering pipeline fixes
//
// Each test here failed against the pre-fix implementation:
//   - Tile grid derived from a hardcoded 612×792 letter assumption
//   - cacheStats.hitRate and cacheStats.totalSize always returned 0
//   - A fresh PDFDocument re-parse on every tile render
//   - No per-DPI render API on ProgressiveRenderer
//   - No thumbnail / warm-up / cache-probe API on RenderingPipeline

@Suite("Rendering Pipeline Fixes (mutation-first)")
struct RenderingPipelineFixTests {

  private func fixtureData(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: "benchmark/results/\(name)")
    return try Data(contentsOf: url)
  }

  @Test("Tile grid derives from real page bounds, not a hardcoded 612×792 assumption")
  func tileGridFromRealPageBounds() throws {
    // scanned-noisy.pdf is 1600×700 — far from the letter assumption.
    let data = try fixtureData("browser-corpus/scanned-noisy.pdf")
    let display = TileBasedDisplay(tileSize: 256, maxCacheTiles: 500)

    guard let document = PDFDocument(data: data),
      let page = document.page(at: 0)
    else {
      Issue.record("Fixture must be a parseable PDF")
      return
    }
    let pageBounds = page.bounds(for: .mediaBox)

    // Expected grid computed from the REAL page size at 150 dpi.
    let span = 256.0 / (150.0 / 72.0)
    let expectedColumns = Int(ceil(pageBounds.width / span))
    let expectedRows = Int(ceil(pageBounds.height / span))

    let viewport = ViewportState(
      pageIndex: 0,
      visibleRect: pageBounds,
      dpi: 150
    )
    let tiles = display.getTiles(data: data, viewport: viewport)

    // A full-page viewport must cover the whole page. The pre-fix code
    // assumed 612×792 and returned a much smaller grid for a 1600×700 page.
    #expect(tiles.count == expectedColumns * expectedRows)

    // Tile grid must reach the real page edge (last tile may overhang).
    if let lastTile = tiles.last {
      #expect(lastTile.bounds.maxX >= pageBounds.width - 1)
      #expect(lastTile.bounds.maxY >= pageBounds.height - 1)
    }
  }

  @Test("Cache hit rate is tracked, not always zero")
  func hitRateTracked() throws {
    let data = try fixtureData("public-sample-form.pdf")
    let display = TileBasedDisplay()
    let viewport = ViewportState(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792)
    )

    _ = display.getTiles(data: data, viewport: viewport)
    #expect(display.cacheStats.hitRate == 0)

    // Second call must hit the cache for every tile.
    _ = display.getTiles(data: data, viewport: viewport)
    #expect(display.cacheStats.hitRate > 0)
  }

  @Test("Renderer cacheSize reflects actual bytes, not always zero")
  func totalSizeTracked() throws {
    let data = try fixtureData("public-sample-form.pdf")
    let renderer = ProgressiveRenderer()

    let rendered = renderer.renderPage(data: data, pageIndex: 0, level: .low)
    #expect(rendered != nil)

    let stats = renderer.cacheStats
    #expect(stats.count == 1)
    #expect(stats.totalSize > 0)
  }

  @Test("Renderer supports exact-DPI rendering and caching")
  func exactDPIRender() throws {
    let data = try fixtureData("public-sample-form.pdf")
    let renderer = ProgressiveRenderer()

    let rendered = renderer.renderPage(data: data, pageIndex: 0, dpi: 72)
    #expect(rendered != nil)
    #expect(rendered?.pageIndex == 0)
    #expect(rendered?.imageData.isEmpty == false)

    let cached = renderer.getCached(pageIndex: 0, dpi: 72)
    #expect(cached != nil)
    #expect(cached?.imageData == rendered?.imageData)
  }

  @Test("LRU cache eviction keeps exactly maxCacheTiles entries")
  func lruEviction() throws {
    let data = try fixtureData("browser-corpus/scanned-noisy.pdf")
    let display = TileBasedDisplay(tileSize: 256, maxCacheTiles: 2)
    let viewport = ViewportState(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 1600, height: 700),
      dpi: 150
    )

    _ = display.getTiles(data: data, viewport: viewport)

    // Pre-fix code wiped the entire cache on every eviction, so after
    // rendering 84 tiles with maxCacheTiles=2 it held only 1. LRU keeps 2.
    #expect(display.cacheStats.count == 2)
  }

  @Test("Pipeline renders thumbnails asynchronously")
  func thumbnailRendering() async throws {
    let pipeline = RenderingPipeline()
    let data = try fixtureData("public-sample-form.pdf")
    _ = try await pipeline.loadDocument(data: data, documentID: "thumb-test")

    let thumbnail = await pipeline.renderThumbnailAsync(pageIndex: 0, maxPixelWidth: 110)
    #expect(thumbnail != nil)
    #expect(thumbnail?.imageData.isEmpty == false)
    #expect(thumbnail?.width ?? 0 > 0)
  }

  @Test("Pipeline warm-up populates the render cache")
  func warmUpPopulatesCache() async throws {
    // repeated-20-pages.pdf has 20 pages, so pages 0 and 1 both exist.
    let pipeline = RenderingPipeline()
    let data = try fixtureData("security-corpus/repeated-20-pages.pdf")
    _ = try await pipeline.loadDocument(data: data, documentID: "warm-test")

    pipeline.warmUpPages(pageIndexes: [0, 1], dpi: 72)

    // Warm-up runs off the main thread; poll briefly for the cache to fill.
    let deadline = Date().addingTimeInterval(10)
    var warmed = false
    while Date() < deadline {
      if pipeline.isCached(pageIndex: 0, dpi: 72)
        && pipeline.isCached(pageIndex: 1, dpi: 72)
      {
        warmed = true
        break
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    #expect(warmed)
  }

  @Test("Pipeline cache probe reports misses before renders")
  func cacheProbe() async throws {
    let pipeline = RenderingPipeline()
    let data = try fixtureData("public-sample-form.pdf")
    _ = try await pipeline.loadDocument(data: data, documentID: "probe-test")

    #expect(pipeline.isCached(pageIndex: 0, dpi: 72) == false)

    _ = await pipeline.renderThumbnailAsync(pageIndex: 0, maxPixelWidth: 110)
    // Thumbnail render caches at its computed DPI; probe must now report a hit.
    let thumbnailDPI = pipeline.isCached(pageIndex: 0, dpi: 12)
      || pipeline.isCached(pageIndex: 0, dpi: 13)
    #expect(thumbnailDPI)
  }
}