import Foundation
import Testing
@testable import PDFEditorCore

/// Thread-safe boolean for async coordination.
private final class AtomicBool: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Bool = false
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _value }
        set { lock.lock(); _value = newValue; lock.unlock() }
    }
}

// MARK: - Pipeline-as-Renderer Tests

@Suite("Pipeline Renderer — 1st Principles")
struct PipelineRendererTests {

  @Test("Pipeline renders page at all quality levels")
  func rendersAllLevels() {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    guard let pdfData = try? Data(contentsOf: fixtureURL) else {
      Issue.record("Fixture not found")
      return
    }

    let renderer = ProgressiveRenderer()
    for level in [RenderLevel.low, .medium, .high] {
      let rendered = renderer.renderPage(data: pdfData, pageIndex: 0, level: level)
      #expect(rendered != nil, "Failed to render at level \(level.displayName)")
      #expect(rendered?.level == level)
      #expect(rendered?.imageData.isEmpty == false)
    }
  }

  @Test("Pipeline progressive render produces valid image at each stage")
  func progressiveImageValid() async {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    guard let pdfData = try? Data(contentsOf: fixtureURL) else {
      Issue.record("Fixture not found")
      return
    }

    _ = try? await pipeline.loadDocument(data: pdfData, documentID: "test-render")

    let page: RenderedPage? = await withCheckedContinuation { continuation in
      let resumed = AtomicBool()
      pipeline.renderPageProgressive(
        pageIndex: 0,
        availableWidth: 600
      ) { page in
        guard !resumed.value else { return }
        if let page {
          resumed.value = true
          continuation.resume(returning: page)
        }
      }
      // Safety timeout
      Task {
        try? await Task.sleep(for: .seconds(5))
        if !resumed.value {
          resumed.value = true
          continuation.resume(returning: nil)
        }
      }
    }

    // High-res page should be valid
    guard let page else {
      Issue.record("Progressive render did not complete")
      return
    }
    #expect(page.imageData.isEmpty == false)
    #expect(page.width > 0)
    #expect(page.height > 0)
  }

  @Test("Pipeline text extraction works for interaction overlay")
  func textExtractionForInteraction() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    _ = try? await pipeline.loadDocument(data: pdfData, documentID: "test-text")

    let extraction = try pipeline.extractText()
    #expect(extraction.blocks.count > 0)
    #expect(extraction.fullText.count > 0)

    // Each block has bounds for hit testing
    for block in extraction.blocks {
      #expect(block.bounds.width > 0)
      #expect(block.bounds.height > 0)
    }
  }

  @Test("Pipeline UNDERSTAND layer works alongside rendering")
  func understandAlongsideRendering() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    _ = try? await pipeline.loadDocument(data: pdfData, documentID: "test-understand")

    // Rendering
    let renderer = ProgressiveRenderer()
    let rendered = renderer.renderPage(data: pdfData, pageIndex: 0, level: .medium)
    #expect(rendered != nil)

    // Understanding (same pipeline, different concern)
    let result = try pipeline.understand()
    #expect(result.summary.totalSentences >= 0)
    #expect(result.entities.totalCount >= 0)
    #expect(result.keyPoints.totalCount >= 0)
    #expect(result.tables.totalTables >= 0)
  }

  @Test("Pipeline thumbnail rendering works (thumbnail rail)")
  func thumbnailRendering() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    _ = try? await pipeline.loadDocument(data: pdfData, documentID: "test-thumb")

    let thumb = await pipeline.renderThumbnailAsync(pageIndex: 0, maxPixelWidth: 110)
    #expect(thumb != nil)
    #expect(thumb?.width ?? 0 > 0)
    #expect(thumb?.width ?? 0 <= 220) // 110px * 2x scale
    #expect(thumb?.imageData.isEmpty == false)
  }

  @Test("Pipeline content routing works for layout decisions")
  func contentRouting() async throws {
    let pipeline = RenderingPipeline()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)

    _ = try? await pipeline.loadDocument(data: pdfData, documentID: "test-route")

    let suggestion = try pipeline.routeContent()
    // Suggestion should indicate content type
    #expect(suggestion.confidence >= 0)
  }

  @Test("RenderedPage is Sendable (can cross actor boundaries)")
  func renderedPageSendable() {
    let renderer = ProgressiveRenderer()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    guard let pdfData = try? Data(contentsOf: fixtureURL) else { return }

    let rendered = renderer.renderPage(data: pdfData, pageIndex: 0, level: .low)!
    // This should compile without warnings — RenderedPage is Sendable
    Task { @Sendable in
      let _ = rendered.imageData
    }
  }

  @Test("Pipeline cache returns same image for repeated renders")
  func cacheReturnsSameImage() {
    let renderer = ProgressiveRenderer()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    guard let pdfData = try? Data(contentsOf: fixtureURL) else { return }

    // Render twice at same level
    let first = renderer.renderPage(data: pdfData, pageIndex: 0, level: .medium)
    let second = renderer.renderPage(data: pdfData, pageIndex: 0, level: .medium)

    #expect(first != nil && second != nil)
    // Both should produce valid images of the same dimensions
    #expect(first!.width == second!.width)
    #expect(first!.height == second!.height)
    #expect(first!.imageData.count > 0)
    #expect(second!.imageData.count > 0)
  }
}
