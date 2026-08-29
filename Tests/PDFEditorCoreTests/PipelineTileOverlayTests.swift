import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Pipeline Tile Overlay Tests

@Suite("Pipeline — Tile Overlay Compositing")
struct PipelineTileOverlayTests {

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

  @Test("Pipeline config DPI range is valid")
  func configDPIRange() {
    let config = RenderingPipelineConfig.default
    #expect(config.lowDPI < config.mediumDPI)
    #expect(config.mediumDPI < config.highDPI)
    #expect(config.lowDPI == 72)
    #expect(config.highDPI == 300)
  }

  @Test("Pipeline returns empty tiles when no document loaded")
  func emptyTilesNoDocument() {
    let pipeline = RenderingPipeline()
    let tiles = pipeline.getViewportTiles(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792),
      scale: 1.0
    )
    #expect(tiles.isEmpty)
  }

  @Test("Tile bounds are in page coordinates")
  func tileBoundsPageCoords() {
    let tile = PageTile(
      pageIndex: 0,
      tileX: 0,
      tileY: 0,
      bounds: CGRect(x: 0, y: 0, width: 256, height: 256),
      pixelBounds: CGRect(x: 0, y: 0, width: 512, height: 512),
      imageData: Data(),
      renderTimeMs: 1.0
    )
    // Page coordinates (points) should be smaller than pixel coordinates at DPI > 72
    #expect(tile.bounds.width <= tile.pixelBounds.width)
  }

  @Test("Tile render time is tracked")
  func tileRenderTimeTracking() {
    let tile = PageTile(
      pageIndex: 0,
      tileX: 0,
      tileY: 0,
      bounds: .zero,
      pixelBounds: .zero,
      imageData: Data(),
      renderTimeMs: 42.7
    )
    #expect(tile.renderTimeMs == 42.7)
  }

  @Test("Multiple tiles cover the viewport")
  func multipleTilesCoverViewport() {
    // Simulate a 1024x768 viewport with 256px tiles
    let tileSize: CGFloat = 256
    let viewportWidth: CGFloat = 1024
    let viewportHeight: CGFloat = 768

    let cols = Int(ceil(viewportWidth / tileSize))
    let rows = Int(ceil(viewportHeight / tileSize))
    #expect(cols == 4)
    #expect(rows == 3)
    #expect(cols * rows == 12) // 12 tiles to cover viewport
  }
}
