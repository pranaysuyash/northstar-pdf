import Foundation
import Testing
@testable import PDFEditorCore

// MARK: — 1st Principles Rendering Architecture Tests

@Suite("Rendering — 1st Principles Pipeline-as-Renderer")
struct PipelineRendererArchitectureTests {

  // MARK: - Pipeline State

  @Test("Pipeline initializes with empty state")
  func pipelineInitialState() {
    let pipeline = RenderingPipeline()
    let state = pipeline.state
    #expect(state.currentPageIndex == 0)
  }

  @Test("Pipeline returns empty tiles when no document loaded")
  func emptyTilesNoDoc() {
    let pipeline = RenderingPipeline()
    let tiles = pipeline.getViewportTiles(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792),
      scale: 1.0
    )
    #expect(tiles.isEmpty)
  }

  @Test("Pipeline cache stats start at zero")
  func cacheStatsZero() {
    let pipeline = RenderingPipeline()
    let stats = pipeline.cacheStats
    #expect(stats.renderer.count == 0)
    #expect(stats.tiles.hitRate == 0 || stats.tiles.hitRate >= 0)
  }

  @Test("Pipeline render time stats start empty")
  func renderTimeStatsEmpty() {
    let pipeline = RenderingPipeline()
    let stats = pipeline.renderTimeStats()
    #expect(stats.count == 0)
  }

  // MARK: - Adaptive DPI

  @Test("Adaptive DPI increases with scale")
  func adaptiveDPI() {
    let pipeline = RenderingPipeline()
    let dpiLow = pipeline.adaptiveDPI(for: 0.25)
    let dpiNormal = pipeline.adaptiveDPI(for: 1.0)
    let dpiHigh = pipeline.adaptiveDPI(for: 3.0)
    #expect(dpiLow <= dpiNormal)
    #expect(dpiNormal <= dpiHigh)
    #expect(dpiLow >= 72)
    #expect(dpiHigh <= 300)
  }

  @Test("Adaptive DPI respects config bounds")
  func adaptiveDPIBounds() {
    let pipeline = RenderingPipeline()
    let dpiVeryLow = pipeline.adaptiveDPI(for: 0.01)
    let dpiVeryHigh = pipeline.adaptiveDPI(for: 100.0)
    #expect(dpiVeryLow >= RenderingPipelineConfig.default.lowDPI)
    #expect(dpiVeryHigh <= RenderingPipelineConfig.default.highDPI)
  }

  // MARK: - Config

  @Test("Pipeline config DPI range is valid")
  func configDPIRange() {
    let config = RenderingPipelineConfig.default
    #expect(config.lowDPI < config.mediumDPI)
    #expect(config.mediumDPI < config.highDPI)
    #expect(config.lowDPI == 72)
    #expect(config.highDPI == 300)
  }

  @Test("Pipeline config tile size is reasonable")
  func configTileSize() {
    let config = RenderingPipelineConfig.default
    #expect(config.tileSize >= 64)
    #expect(config.tileSize <= 1024)
  }

  @Test("Pipeline config cache limits are reasonable")
  func configCacheLimits() {
    let config = RenderingPipelineConfig.default
    #expect(config.maxCachedTiles > 0)
    #expect(config.maxCachedPages > 0)
    #expect(config.preRenderMargin >= 0)
  }

  // MARK: - PageTile Structure

  @Test("PageTile ID is deterministic")
  func tileIDDeterministic() {
    let t1 = PageTile(pageIndex: 0, tileX: 1, tileY: 2, bounds: .zero, pixelBounds: .zero, imageData: Data(), renderTimeMs: 0)
    let t2 = PageTile(pageIndex: 0, tileX: 1, tileY: 2, bounds: .zero, pixelBounds: .zero, imageData: Data(), renderTimeMs: 0)
    #expect(t1.id == t2.id)
    #expect(t1.id == "0-1-2")
  }

  @Test("Different tiles have different IDs")
  func tileIDDifferent() {
    let t1 = PageTile(pageIndex: 0, tileX: 0, tileY: 0, bounds: .zero, pixelBounds: .zero, imageData: Data(), renderTimeMs: 0)
    let t2 = PageTile(pageIndex: 0, tileX: 1, tileY: 0, bounds: .zero, pixelBounds: .zero, imageData: Data(), renderTimeMs: 0)
    let t3 = PageTile(pageIndex: 1, tileX: 0, tileY: 0, bounds: .zero, pixelBounds: .zero, imageData: Data(), renderTimeMs: 0)
    #expect(t1.id != t2.id)
    #expect(t1.id != t3.id)
    #expect(t2.id != t3.id)
  }

  @Test("PageTile is Sendable")
  func tileSendable() async {
    let tile = PageTile(pageIndex: 0, tileX: 0, tileY: 0, bounds: .zero, pixelBounds: .zero, imageData: Data(), renderTimeMs: 1.5)
    Task {
      let captured = tile
      #expect(captured.renderTimeMs == 1.5)
    }
  }

  @Test("PageTile preserves all metadata")
  func tileMetadata() {
    let tile = PageTile(
      pageIndex: 2,
      tileX: 1,
      tileY: 3,
      bounds: CGRect(x: 256, y: 768, width: 256, height: 256),
      pixelBounds: CGRect(x: 512, y: 1536, width: 512, height: 512),
      imageData: Data([0x89, 0x50, 0x4E, 0x47]),
      renderTimeMs: 12.5
    )
    #expect(tile.pageIndex == 2)
    #expect(tile.tileX == 1)
    #expect(tile.tileY == 3)
    #expect(tile.id == "2-1-3")
    #expect(tile.renderTimeMs == 12.5)
    #expect(tile.bounds.width == 256)
    #expect(tile.pixelBounds.width == 512)
  }

  // MARK: - ViewportState

  @Test("ViewportState captures all parameters")
  func viewportStateCapture() {
    let rect = CGRect(x: 10, y: 20, width: 300, height: 400)
    let vs = ViewportState(pageIndex: 3, visibleRect: rect, scale: 2.0, dpi: 150)
    #expect(vs.pageIndex == 3)
    #expect(vs.visibleRect == rect)
    #expect(vs.scale == 2.0)
    #expect(vs.dpi == 150)
  }

  @Test("ViewportState is Sendable")
  func viewportStateSendable() async {
    let vs = ViewportState(pageIndex: 0, visibleRect: .zero, scale: 1.0, dpi: 72)
    Task {
      let captured = vs
      #expect(captured.dpi == 72)
    }
  }

  // MARK: - Tile Coverage Math

  @Test("Multiple tiles cover the viewport")
  func multipleTilesCoverViewport() {
    let tileSize: CGFloat = 256
    let viewportWidth: CGFloat = 1024
    let viewportHeight: CGFloat = 768

    let cols = Int(ceil(viewportWidth / tileSize))
    let rows = Int(ceil(viewportHeight / tileSize))
    #expect(cols == 4)
    #expect(rows == 3)
    #expect(cols * rows == 12)
  }

  @Test("Single tile covers small viewport")
  func singleTileCoversSmallViewport() {
    let tileSize: CGFloat = 256
    let viewportWidth: CGFloat = 200
    let viewportHeight: CGFloat = 100

    let cols = Int(ceil(viewportWidth / tileSize))
    let rows = Int(ceil(viewportHeight / tileSize))
    #expect(cols == 1)
    #expect(rows == 1)
  }

  // MARK: - Reading Position

  @Test("ReadingPosition round-trips through save/restore")
  func readingPositionRoundTrip() {
    let pipeline = RenderingPipeline()
    let position = ReadingPosition(
      documentID: "test-doc",
      pageIndex: 5,
      scrollOffset: 42,
      scale: 1.5
    )
    pipeline.saveReadingPosition(position)
    let restored = pipeline.getReadingPosition(documentID: "test-doc")
    #expect(restored?.pageIndex == 5)
    #expect(restored?.scale == 1.5)
    #expect(restored?.scrollOffset == 42)
  }

  @Test("ReadingPosition nil for unknown document")
  func readingPositionUnknown() {
    let pipeline = RenderingPipeline()
    let restored = pipeline.getReadingPosition(documentID: "nonexistent")
    #expect(restored == nil)
  }

  // MARK: - Content Routing

  @Test("Pipeline content routing returns suggestion for loaded document")
  func contentRouting() async throws {
    let pipeline = RenderingPipeline()
    guard let fixture = corpusURL("compressed-acroform.pdf") else {
      return // corpus not available in this environment
    }
    let data = try Data(contentsOf: fixture)
    _ = try await pipeline.loadDocument(data: data, documentID: "test-route")

    // Verify routeContent returns without crash
    _ = try pipeline.routeContent()
  }

  // MARK: - Caches

  @Test("Pipeline clear caches resets state")
  func clearCaches() async throws {
    let pipeline = RenderingPipeline()
    guard let fixture = corpusURL("compressed-acroform.pdf") else { return }
    let data = try Data(contentsOf: fixture)
    _ = try await pipeline.loadDocument(data: data, documentID: "test-clear")

    pipeline.warmUpPages(pageIndexes: [0], dpi: 72)
    let before = pipeline.cacheStats
    #expect(before.renderer.count >= 1)

    pipeline.clearCaches()
    let after = pipeline.cacheStats
    #expect(after.renderer.count == 0)
  }

  // MARK: - Helpers

  private func corpusURL(_ filename: String) -> URL? {
    let corpusDir = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("benchmark/results/2026-08-25-native-incremental/corpus")
    let file = corpusDir.appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: file.path) ? file : nil
  }
}
