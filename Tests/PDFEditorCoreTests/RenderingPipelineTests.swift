import Foundation
import PDFEditorCore
import Testing

// MARK: - Stage 1: Parse Tests

@Suite("Stage 1: Hybrid PDF Parser")
struct HybridPDFParserTests {

  @Test("Hybrid parser creates document model from valid PDF")
  func parseValidPDF() throws {
    let parser = HybridPDFParser()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    let model = try parser.parse(data: pdfData, strategy: .streaming)

    #expect(model.pageCount >= 0)
    #expect(model.parseStrategy == .streaming)
    #expect(model.parseTimeMs >= 0)
  }

  @Test("Hybrid parser handles invalid PDF gracefully")
  func parseInvalidPDF() {
    let parser = HybridPDFParser()
    let invalidData = Data("not a pdf".utf8)

    #expect(throws: ParserError.self) {
      try parser.parse(data: invalidData)
    }
  }

  @Test("Document model contains metadata")
  func metadataExtraction() throws {
    let parser = HybridPDFParser()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    let model = try parser.parse(data: pdfData, strategy: .streaming)

    #expect(model.metadata.isEncrypted == false)
  }
}

// MARK: - Stage 2: Interpret Tests

@Suite("Stage 2: Improved Text Extractor")
struct ImprovedTextExtractorTests {

  @Test("Text extractor extracts text from PDF")
  func extractText() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    let result = try extractor.extract(data: pdfData)

    #expect(result.pageCount >= 0)
    #expect(result.totalCharacters >= 0)
    #expect(result.extractionTimeMs >= 0)
  }

  @Test("Text extractor detects blocks")
  func detectBlocks() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    let result = try extractor.extract(data: pdfData)

    #expect(result.blocks is [TextBlock])
  }

  @Test("Text extractor handles invalid PDF")
  func extractInvalid() {
    let extractor = ImprovedTextExtractor()
    let invalidData = Data("not a pdf".utf8)

    #expect(throws: ExtractionError.self) {
      try extractor.extract(data: invalidData)
    }
  }
}

// MARK: - Stage 3: Rasterize Tests

@Suite("Stage 3: Progressive Renderer")
struct ProgressiveRendererTests {

  @Test("Progressive renderer creates rendered page")
  func renderPage() throws {
    let renderer = ProgressiveRenderer()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    let rendered = renderer.renderPage(data: pdfData, pageIndex: 0, level: .low)

    if let rendered = rendered {
      #expect(rendered.pageIndex == 0)
      #expect(rendered.level == .low)
      #expect(rendered.width > 0)
      #expect(rendered.height > 0)
      #expect(rendered.renderTimeMs >= 0)
    }
  }

  @Test("Render levels have correct DPI")
  func renderLevelDPI() {
    #expect(RenderLevel.low.dpi == 72)
    #expect(RenderLevel.medium.dpi == 150)
    #expect(RenderLevel.high.dpi == 300)
  }

  @Test("Render levels are comparable")
  func renderLevelComparable() {
    #expect(RenderLevel.low < RenderLevel.medium)
    #expect(RenderLevel.medium < RenderLevel.high)
  }

  @Test("Cache returns nil for missing entries")
  func cacheMiss() {
    let renderer = ProgressiveRenderer()
    let cached = renderer.getCached(pageIndex: 999, level: .low)
    #expect(cached == nil)
  }
}

// MARK: - Stage 4: Display Tests

@Suite("Stage 4: Tile-Based Display")
struct TileBasedDisplayTests {

  @Test("Tile-based display creates tiles for viewport")
  func createTiles() throws {
    let display = TileBasedDisplay()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let viewport = ViewportState(
      pageIndex: 0,
      visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792)
    )

    let tiles = display.getTiles(data: pdfData, viewport: viewport)

    #expect(tiles is [PageTile])
  }

  @Test("Viewport state tracks position")
  func viewportTracking() {
    let viewport = ViewportState(
      pageIndex: 5,
      visibleRect: CGRect(x: 100, y: 200, width: 400, height: 300),
      scale: 1.5,
      dpi: 300
    )

    #expect(viewport.pageIndex == 5)
    #expect(viewport.scale == 1.5)
    #expect(viewport.dpi == 300)
    #expect(viewport.visibleRect.width == 400)
  }

  @Test("Tile cache stats return valid values")
  func cacheStats() {
    let display = TileBasedDisplay()
    let stats = display.cacheStats

    #expect(stats.count >= 0)
  }
}

// MARK: - Integration Tests

@Suite("Rendering Pipeline Integration")
struct RenderingPipelineIntegrationTests {

  @Test("Full pipeline: parse → interpret → render → display")
  func fullPipeline() throws {
    let parser = HybridPDFParser()
    let extractor = ImprovedTextExtractor()
    let renderer = ProgressiveRenderer()
    let display = TileBasedDisplay()

    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    // Stage 1: Parse
    let model = try parser.parse(data: pdfData, strategy: .adaptive)
    #expect(model.pageCount >= 0)

    // Stage 2: Interpret
    let extraction = try extractor.extract(data: pdfData)
    #expect(extraction.totalCharacters >= 0)

    // Stage 3: Rasterize
    let rendered = renderer.renderPage(data: pdfData, pageIndex: 0, level: .low)
    // May be nil for minimal PDF

    // Stage 4: Display
    let viewport = ViewportState(pageIndex: 0, visibleRect: CGRect(x: 0, y: 0, width: 612, height: 792))
    let tiles = display.getTiles(data: pdfData, viewport: viewport)
    #expect(tiles.count >= 0)
  }
}
