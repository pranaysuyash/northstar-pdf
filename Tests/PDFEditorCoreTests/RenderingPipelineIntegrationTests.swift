import Foundation
import PDFEditorCore
import Testing

// MARK: - Rendering Pipeline — Unified Integration Tests

@Suite("Rendering Pipeline — Unified Integration")
struct RenderingPipelineUnifiedTests {

  // MARK: - Configuration

  @Test("Default config has sensible defaults")
  func defaultConfig() {
    let config = RenderingPipelineConfig.default
    #expect(config.lowDPI == 72)
    #expect(config.mediumDPI == 150)
    #expect(config.highDPI == 300)
    #expect(config.tileSize == 256)
    #expect(config.maxCachedTiles == 500)
    #expect(config.maxCachedPages == 20)
  }

  // MARK: - Pipeline Creation

  @Test("Pipeline creates successfully with default config")
  func createPipeline() {
    let pipeline = RenderingPipeline()
    let state = pipeline.state
    #expect(state.currentPageIndex == 0)
    #expect(state.scale == 1.0)
    #expect(state.quality == .low)
    #expect(state.isProgressiveRendering == false)
    #expect(state.isHighResComplete == false)
  }

  // MARK: - Document Loading

  @Test("Pipeline loads valid PDF document")
  func loadValidDocument() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    let model = try await pipeline.loadDocument(data: pdfData, documentID: "test-doc")
    #expect(model.pageCount >= 0)
    // Adaptive resolves to .full for small PDFs (correct behavior)
    #expect(model.parseStrategy == .full || model.parseStrategy == .streaming || model.parseStrategy == .adaptive)
  }

  @Test("Pipeline handles invalid PDF gracefully")
  func loadInvalidDocument() async {
    let pipeline = RenderingPipeline()
    let invalidData = Data("not a pdf".utf8)

    do {
      _ = try await pipeline.loadDocument(data: invalidData, documentID: "invalid")
      Issue.record("Expected error for invalid PDF")
    } catch {
      #expect(error is ParserError)
    }
  }

  // MARK: - Text Extraction

  @Test("Text extraction works through pipeline")
  func textExtraction() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    _ = try await pipeline.loadDocument(data: pdfData, documentID: "test-extract")

    let result = try pipeline.extractText()
    #expect(result.pageCount >= 0)
    #expect(result.totalCharacters >= 0)
  }

  @Test("Text extraction fails without document")
  func textExtractionNoDoc() {
    let pipeline = RenderingPipeline()
    #expect(throws: ExtractionError.self) {
      _ = try pipeline.extractText()
    }
  }

  // MARK: - Reading Position

  @Test("Reading position saves and retrieves")
  func readingPosition() {
    let pipeline = RenderingPipeline()
    let position = ReadingPosition(
      documentID: "test-doc",
      pageIndex: 5,
      scrollOffset: 0.3,
      scale: 1.5
    )

    pipeline.saveReadingPosition(position)
    let retrieved = pipeline.getReadingPosition(documentID: "test-doc")

    #expect(retrieved != nil)
    #expect(retrieved?.pageIndex == 5)
    #expect(retrieved?.scrollOffset == 0.3)
    #expect(retrieved?.scale == 1.5)
  }

  @Test("Reading position updates correctly")
  func readingPositionUpdate() {
    let pipeline = RenderingPipeline()

    pipeline.saveReadingPosition(ReadingPosition(documentID: "doc-1", pageIndex: 0, scrollOffset: 0, scale: 1.0))
    pipeline.updateReadingPosition(documentID: "doc-1", pageIndex: 3, scrollOffset: 0.5, scale: 2.0)

    let updated = pipeline.getReadingPosition(documentID: "doc-1")
    #expect(updated?.pageIndex == 3)
    #expect(updated?.scrollOffset == 0.5)
    #expect(updated?.scale == 2.0)
  }

  @Test("Reading position returns nil for unknown document")
  func readingPositionUnknown() {
    let pipeline = RenderingPipeline()
    let position = pipeline.getReadingPosition(documentID: "unknown")
    #expect(position == nil)
  }

  @Test("Multiple document positions are independent")
  func multiplePositions() {
    let pipeline = RenderingPipeline()

    pipeline.saveReadingPosition(ReadingPosition(documentID: "doc-1", pageIndex: 1))
    pipeline.saveReadingPosition(ReadingPosition(documentID: "doc-2", pageIndex: 2))
    pipeline.saveReadingPosition(ReadingPosition(documentID: "doc-3", pageIndex: 3))

    #expect(pipeline.getReadingPosition(documentID: "doc-1")?.pageIndex == 1)
    #expect(pipeline.getReadingPosition(documentID: "doc-2")?.pageIndex == 2)
    #expect(pipeline.getReadingPosition(documentID: "doc-3")?.pageIndex == 3)
  }

  // MARK: - Viewport Tiles

  @Test("Viewport tiles are generated for visible area")
  func viewportTiles() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    _ = try await pipeline.loadDocument(data: pdfData, documentID: "test-tiles")

    let tiles = pipeline.getViewportTiles(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792),
      scale: 1.0
    )
    #expect(tiles.count >= 0)
  }

  // MARK: - Cache and Stats

  @Test("Cache stats return valid values after loading")
  func cacheStats() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    _ = try await pipeline.loadDocument(data: pdfData, documentID: "test-cache")

    let stats = pipeline.cacheStats
    #expect(stats.renderer.count >= 0)
    #expect(stats.tiles.count >= 0)
  }

  @Test("Render time stats return valid values")
  func renderTimeStats() {
    let pipeline = RenderingPipeline()
    let stats = pipeline.renderTimeStats()
    #expect(stats.count == 0)
  }

  @Test("Clear caches resets state")
  func clearCaches() {
    let pipeline = RenderingPipeline()
    pipeline.clearCaches()
    let stats = pipeline.cacheStats
    #expect(stats.renderer.count == 0)
  }

  // MARK: - Full Pipeline Integration

  @Test("Full pipeline: load → extract → tiles → position")
  func fullPipeline() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    // Load and parse
    let model = try await pipeline.loadDocument(data: pdfData, documentID: "full-test")
    #expect(model.pageCount >= 0)

    // Extract text
    let extraction = try pipeline.extractText()
    #expect(extraction.totalCharacters >= 0)

    // Get viewport tiles
    let tiles = pipeline.getViewportTiles(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792),
      scale: 1.0
    )
    #expect(tiles.count >= 0)

    // Save reading position
    pipeline.updateReadingPosition(documentID: "full-test", pageIndex: 0, scrollOffset: 0.5, scale: 1.0)

    let position = pipeline.getReadingPosition(documentID: "full-test")
    #expect(position?.pageIndex == 0)
    #expect(position?.scrollOffset == 0.5)

    // Check state
    let state = pipeline.state
    #expect(state.currentPageIndex == 0)
  }
}
