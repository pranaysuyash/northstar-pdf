import AppKit
import CoreGraphics
import Foundation
import PDFKit

/// Unified Rendering Pipeline
///
/// Chains all 4 stages into a single coherent pipeline:
/// Parse → Interpret → Rasterize → Display
///
/// Provides:
/// - Progressive rendering (low-res first, high-res upgrade)
/// - Viewport-aware tile rendering
/// - Reading position persistence
/// - Adaptive quality based on zoom level
///
/// Doctrine alignment:
/// - §3: Do things smartly — right quality for right context
/// - §5: Evidence-based — track render times, cache hit rates
/// - §8: Capability routing — different quality for different needs

// MARK: - Pipeline Configuration

/// Configuration for the rendering pipeline.
public struct RenderingPipelineConfig: Sendable {
  /// Low resolution DPI (preview quality)
  public let lowDPI: Int
  /// Medium resolution DPI (standard quality)
  public let mediumDPI: Int
  /// High resolution DPI (print quality)
  public let highDPI: Int
  /// Tile size in pixels
  public let tileSize: Int
  /// Maximum cached tiles
  public let maxCachedTiles: Int
  /// Maximum cached pages
  public let maxCachedPages: Int
  /// Pre-render margin (tiles around viewport)
  public let preRenderMargin: Int

  public static let `default` = RenderingPipelineConfig(
    lowDPI: 72,
    mediumDPI: 150,
    highDPI: 300,
    tileSize: 256,
    maxCachedTiles: 500,
    maxCachedPages: 20,
    preRenderMargin: 1
  )
}

// MARK: - Pipeline State

/// Current state of the rendering pipeline.
public struct RenderingPipelineState: Sendable {
  /// Current page index
  public let currentPageIndex: Int
  /// Current zoom scale
  public let scale: CGFloat
  /// Current rendering quality
  public let quality: RenderLevel
  /// Whether progressive rendering is active
  public let isProgressiveRendering: Bool
  /// Whether high-res rendering is complete
  public let isHighResComplete: Bool
  /// Render time for current view (ms)
  public let currentRenderTimeMs: Double
  /// Cache hit rate
  public let cacheHitRate: Double

  public init(
    currentPageIndex: Int = 0,
    scale: CGFloat = 1.0,
    quality: RenderLevel = .low,
    isProgressiveRendering: Bool = false,
    isHighResComplete: Bool = false,
    currentRenderTimeMs: Double = 0,
    cacheHitRate: Double = 0
  ) {
    self.currentPageIndex = currentPageIndex
    self.scale = scale
    self.quality = quality
    self.isProgressiveRendering = isProgressiveRendering
    self.isHighResComplete = isHighResComplete
    self.currentRenderTimeMs = currentRenderTimeMs
    self.cacheHitRate = cacheHitRate
  }
}

// MARK: - Reading Position

/// Persisted reading position for a document.
public struct ReadingPosition: Codable, Sendable {
  /// Document identifier (path or hash)
  public let documentID: String
  /// Page index
  public let pageIndex: Int
  /// Scroll position within page (0-1)
  public let scrollOffset: CGFloat
  /// Zoom scale
  public let scale: CGFloat
  /// Timestamp
  public let timestamp: Date

  public init(documentID: String, pageIndex: Int, scrollOffset: CGFloat = 0, scale: CGFloat = 1.0) {
    self.documentID = documentID
    self.pageIndex = pageIndex
    self.scrollOffset = scrollOffset
    self.scale = scale
    self.timestamp = Date()
  }
}

// MARK: - Pipeline Delegate

/// Delegate for pipeline events.
@MainActor
public protocol RenderingPipelineDelegate: AnyObject {
  /// Called when a page starts rendering.
  func pipeline(_ pipeline: RenderingPipeline, didStartRenderingPage pageIndex: Int, level: RenderLevel)

  /// Called when a page finishes rendering.
  func pipeline(_ pipeline: RenderingPipeline, didCompleteRenderingPage pageIndex: Int, level: RenderLevel, timeMs: Double)

  /// Called when progressive rendering completes (all visible pages at target quality).
  func pipelineDidCompleteProgressiveRendering(_ pipeline: RenderingPipeline)

  /// Called when reading position changes.
  func pipeline(_ pipeline: RenderingPipeline, didUpdateReadingPosition position: ReadingPosition)

  /// Called when pipeline state changes.
  func pipeline(_ pipeline: RenderingPipeline, didUpdateState state: RenderingPipelineState)
}

// MARK: - Rendering Pipeline

/// Unified rendering pipeline that chains Parse → Interpret → Rasterize → Display.
public final class RenderingPipeline: @unchecked Sendable {
  private let config: RenderingPipelineConfig
  private let parser: HybridPDFParser
  private let extractor: ImprovedTextExtractor
  private let renderer: ProgressiveRenderer
  private let tileDisplay: TileBasedDisplay
  private let lock = NSLock()

  // State
  private var currentState = RenderingPipelineState()
  private var documentData: Data?
  private var documentModel: PDFDocumentModel?
  private var readingPositions: [String: ReadingPosition] = [:]
  private var renderTimes: [String: [Double]] = [:]

  @MainActor public weak var delegate: RenderingPipelineDelegate?

  public init(config: RenderingPipelineConfig = .default) {
    self.config = config
    self.parser = HybridPDFParser()
    self.extractor = ImprovedTextExtractor()
    self.renderer = ProgressiveRenderer()
    self.tileDisplay = TileBasedDisplay(
      tileSize: config.tileSize,
      maxCacheTiles: config.maxCachedTiles
    )
  }

  // MARK: - Document Loading

  /// Load a document into the pipeline.
  public func loadDocument(data: Data, documentID: String) async throws -> PDFDocumentModel {
    self.documentData = data

    // Stage 1: Parse
    let model = try parser.parse(data: data, strategy: .adaptive)
    self.documentModel = model

    // Restore reading position if available
    if let position = readingPositions[documentID] {
      await MainActor.run {
        self.currentState = RenderingPipelineState(
          currentPageIndex: position.pageIndex,
          scale: position.scale,
          quality: .low,
          isProgressiveRendering: true,
          isHighResComplete: false
        )
      }
    }

    return model
  }

  // MARK: - Progressive Rendering

  /// Render a page progressively: low-res first, then upgrade to high-res.
  public func renderPageProgressive(
    pageIndex: Int,
    availableWidth: CGFloat,
    completion: @escaping @MainActor @Sendable (RenderedPage?) -> Void
  ) {
    guard let data = documentData else {
      Task { @MainActor in
        completion(nil)
      }
      return
    }

    // Determine initial quality based on available width
    let initialLevel: RenderLevel
    if availableWidth < 400 {
      initialLevel = .low
    } else if availableWidth < 800 {
      initialLevel = .medium
    } else {
      initialLevel = .high
    }

    // Render at initial quality (synchronous, fast for low-res)
    let startTime = CFAbsoluteTimeGetCurrent()
    let rendered = renderer.renderPage(data: data, pageIndex: pageIndex, level: initialLevel)
    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    // Track render time
    trackRenderTime(pageIndex: pageIndex, level: initialLevel, timeMs: elapsed)

    // Update state
    Task { @MainActor in
      self.currentState = RenderingPipelineState(
        currentPageIndex: pageIndex,
        scale: self.currentState.scale,
        quality: initialLevel,
        isProgressiveRendering: initialLevel != .high,
        isHighResComplete: initialLevel == .high,
        currentRenderTimeMs: elapsed,
        cacheHitRate: self.currentState.cacheHitRate
      )
      self.delegate?.pipeline(self, didStartRenderingPage: pageIndex, level: initialLevel)
    }

    Task { @MainActor in
      completion(rendered)
    }

    // If not at high-res, schedule upgrade
    if initialLevel != .high {
      Task { @MainActor in
        self.delegate?.pipeline(self, didCompleteRenderingPage: pageIndex, level: initialLevel, timeMs: elapsed)
      }

      // Upgrade to higher quality in background
      let targetLevel: RenderLevel = initialLevel == .low ? .medium : .high
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        let upgradeStart = CFAbsoluteTimeGetCurrent()
        let upgraded = self.renderer.renderPage(data: data, pageIndex: pageIndex, level: targetLevel)
        let upgradeElapsed = (CFAbsoluteTimeGetCurrent() - upgradeStart) * 1000

        self.trackRenderTime(pageIndex: pageIndex, level: targetLevel, timeMs: upgradeElapsed)

        if targetLevel != .high {
          // Final upgrade to high-res
          DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let finalStart = CFAbsoluteTimeGetCurrent()
            _ = self.renderer.renderPage(data: data, pageIndex: pageIndex, level: .high)
            let finalElapsed = (CFAbsoluteTimeGetCurrent() - finalStart) * 1000

            self.trackRenderTime(pageIndex: pageIndex, level: .high, timeMs: finalElapsed)

            Task { @MainActor in
              self.currentState = RenderingPipelineState(
                currentPageIndex: pageIndex,
                scale: self.currentState.scale,
                quality: .high,
                isProgressiveRendering: false,
                isHighResComplete: true,
                currentRenderTimeMs: finalElapsed,
                cacheHitRate: self.currentState.cacheHitRate
              )
              self.delegate?.pipelineDidCompleteProgressiveRendering(self)
            }
          }
        } else {
          Task { @MainActor in
            self.currentState = RenderingPipelineState(
              currentPageIndex: pageIndex,
              scale: self.currentState.scale,
              quality: .high,
              isProgressiveRendering: false,
              isHighResComplete: true,
              currentRenderTimeMs: upgradeElapsed,
              cacheHitRate: self.currentState.cacheHitRate
            )
            self.delegate?.pipelineDidCompleteProgressiveRendering(self)
          }
        }
      }
    }
  }

  // MARK: - Viewport Rendering

  /// Get tiles needed for current viewport.
  public func getViewportTiles(
    pageIndex: Int,
    visibleRect: CGRect,
    scale: CGFloat = 1.0
  ) -> [PageTile] {
    guard let data = documentData else { return [] }

    let dpi = dpiForScale(scale)
    let viewport = ViewportState(
      pageIndex: pageIndex,
      visibleRect: visibleRect,
      scale: scale,
      dpi: dpi
    )

    // Get tiles for viewport
    let tiles = tileDisplay.getTiles(data: data, viewport: viewport)

    // Pre-render surrounding tiles for smooth scrolling
    tileDisplay.preRenderTiles(data: data, viewport: viewport, preRenderMargin: config.preRenderMargin)

    return tiles
  }

  // MARK: - Thumbnail Rendering

  /// Render a page thumbnail sized to a pixel budget (for rail views).
  ///
  /// The DPI is derived from the budget against a nominal 612pt page width,
  /// clamped to a sane range. Cached renders are returned without re-rendering.
  public func renderThumbnail(pageIndex: Int, maxPixelWidth: Int = 110) -> RenderedPage? {
    lock.lock()
    let data = documentData
    lock.unlock()
    guard let data else { return nil }

    let dpi = min(300, max(12, Int((Double(maxPixelWidth) * 72.0) / 612.0)))
    if let cached = renderer.getCached(pageIndex: pageIndex, dpi: dpi) {
      return cached
    }
    return renderer.renderPage(data: data, pageIndex: pageIndex, dpi: dpi)
  }

  /// Async variant of `renderThumbnail` for UI surfaces that must not block
  /// the main thread (e.g. a thumbnail rail).
  public func renderThumbnailAsync(pageIndex: Int, maxPixelWidth: Int = 110) async -> RenderedPage? {
    await Task.detached(priority: .utility) { [self] in
      self.renderThumbnail(pageIndex: pageIndex, maxPixelWidth: maxPixelWidth)
    }.value
  }

  /// Whether a page render at the given DPI is already in the cache.
  public func isCached(pageIndex: Int, dpi: Int) -> Bool {
    renderer.getCached(pageIndex: pageIndex, dpi: dpi) != nil
  }

  /// Warm the render cache for a set of pages at a given DPI.
  ///
  /// Runs off the main thread so document open does not pay the cost. Used
  /// right after load so the first visible pages paint from cache.
  public func warmUpPages(pageIndexes: [Int], dpi: Int = 72) {
    lock.lock()
    let data = documentData
    lock.unlock()
    guard let data else { return }

    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }
      for pageIndex in pageIndexes {
        if self.renderer.getCached(pageIndex: pageIndex, dpi: dpi) == nil {
          _ = self.renderer.renderPage(data: data, pageIndex: pageIndex, dpi: dpi)
        }
      }
    }
  }

  // MARK: - Adaptive Quality

  /// Returns the optimal DPI for the given zoom scale.
  /// Low zoom (≤0.5) → 72 DPI, medium zoom (0.5–1.5) → 150 DPI, high zoom (>1.5) → 300 DPI.
  public func adaptiveDPI(for scale: CGFloat) -> Int {
    if scale <= 0.5 { return config.lowDPI }
    if scale <= 1.5 { return config.mediumDPI }
    return config.highDPI
  }

  /// Pre-render tiles around the current viewport for smooth scrolling.
  /// Called on page change and scale change to keep the cache warm.
  public func preRenderForViewport(pageIndex: Int, scale: CGFloat) {
    lock.lock()
    let data = documentData
    let pageCount = documentModel?.pageCount ?? 0
    lock.unlock()
    guard let data, pageIndex >= 0, pageIndex < pageCount else { return }

    let dpi = adaptiveDPI(for: scale)
    let margin = config.preRenderMargin
    let startPage = max(0, pageIndex - margin)
    let endPage = min(pageCount - 1, pageIndex + margin)

    DispatchQueue.global(qos: .utility).async { [weak self] in
      guard let self = self else { return }
      for idx in startPage...endPage {
        if self.renderer.getCached(pageIndex: idx, dpi: dpi) == nil {
          _ = self.renderer.renderPage(data: data, pageIndex: idx, dpi: dpi)
        }
      }
    }
  }

  // MARK: - Text Extraction

  /// Extract text from the document.
  public func extractText() throws -> StructuredExtractionResult {
    guard let data = documentData else {
      throw ExtractionError.invalidDocument
    }
    return try extractor.extract(data: data)
  }

  // MARK: - Content Routing

  /// Detect dominant content type and suggest the optimal reading mode.
  public func routeContent() throws -> ContentSuggestion {
    let extraction = try extractText()
    let router = ContentRouter()
    return router.route(extraction: extraction)
  }

  // MARK: - UNDERSTAND: Document Summarization

  /// Summarize the document: key points, structure, importance scoring.
  public func summarize() throws -> DocumentSummary {
    let extraction = try extractText()
    let summarizer = DocumentSummarizer()
    return summarizer.summarize(extraction: extraction)
  }

  // MARK: - UNDERSTAND: Entity Recognition

  /// Recognize entities in the document: dates, amounts, emails, URLs, etc.
  public func recognizeEntities() throws -> EntityRecognitionResult {
    let extraction = try extractText()
    let recognizer = EntityRecognizer()
    return recognizer.recognize(extraction: extraction)
  }

  // MARK: - UNDERSTAND: Key Point Extraction

  /// Extract key points from the document: obligations, definitions, conclusions, etc.
  public func extractKeyPoints() throws -> KeyPointExtractionResult {
    let extraction = try extractText()
    let kpExtractor = KeyPointExtractor()
    return kpExtractor.extract(extraction: extraction)
  }

  // MARK: - UNDERSTAND: Combined Analysis

  /// Full UNDERSTAND analysis: summary + entities + key points in one call.
  public func understand() throws -> (summary: DocumentSummary, entities: EntityRecognitionResult, keyPoints: KeyPointExtractionResult, nerEntities: NERResult, tables: TableExtractionResult, enhancedSummary: EnhancedSummary) {
    let extraction = try extractText()
    let summarizer = DocumentSummarizer()
    let recognizer = EntityRecognizer()
    let kpExtractor = KeyPointExtractor()
    let nerExtractor = NERExtractor()
    let tableExtractor = TableExtractor()
    let aiSummarizer = AISummarizer()
    return (
      summary: summarizer.summarize(extraction: extraction),
      entities: recognizer.recognize(extraction: extraction),
      keyPoints: kpExtractor.extract(extraction: extraction),
      nerEntities: nerExtractor.extract(extraction: extraction),
      tables: tableExtractor.extract(extraction: extraction),
      enhancedSummary: aiSummarizer.summarize(extraction: extraction)
    )
  }

  // MARK: - Reading Position

  /// Save reading position for a document.
  public func saveReadingPosition(_ position: ReadingPosition) {
    lock.lock()
    readingPositions[position.documentID] = position
    lock.unlock()

    // Persist to disk
    persistReadingPositions()

    Task { @MainActor in
      self.delegate?.pipeline(self, didUpdateReadingPosition: position)
    }
  }

  /// Get saved reading position for a document.
  public func getReadingPosition(documentID: String) -> ReadingPosition? {
    lock.lock()
    defer { lock.unlock() }
    return readingPositions[documentID]
  }

  /// Update reading position for current view.
  public func updateReadingPosition(
    documentID: String,
    pageIndex: Int,
    scrollOffset: CGFloat,
    scale: CGFloat
  ) {
    let position = ReadingPosition(
      documentID: documentID,
      pageIndex: pageIndex,
      scrollOffset: scrollOffset,
      scale: scale
    )
    saveReadingPosition(position)
  }

  // MARK: - State

  /// Get current pipeline state.
  public var state: RenderingPipelineState {
    lock.lock()
    defer { lock.unlock() }
    return currentState
  }

  /// Get render time statistics.
  public func renderTimeStats() -> (average: Double, min: Double, max: Double, count: Int) {
    lock.lock()
    defer { lock.unlock() }

    let allTimes = renderTimes.values.flatMap { $0 }
    guard !allTimes.isEmpty else { return (0, 0, 0, 0) }

    let average = allTimes.reduce(0, +) / Double(allTimes.count)
    let min = allTimes.min() ?? 0
    let max = allTimes.max() ?? 0
    return (average: average, min: min, max: max, count: allTimes.count)
  }

  /// Get cache statistics.
  public var cacheStats: (renderer: (count: Int, totalSize: Int), tiles: (count: Int, hitRate: Double)) {
    return (
      renderer: renderer.cacheStats,
      tiles: tileDisplay.cacheStats
    )
  }

  /// Clear all caches.
  public func clearCaches() {
    renderer.clearCache()
    tileDisplay.clearCache()
    lock.lock()
    renderTimes.removeAll()
    lock.unlock()
  }

  // MARK: - Private Helpers

  private func dpiForScale(_ scale: CGFloat) -> Int {
    if scale < 0.5 {
      return config.lowDPI
    } else if scale < 1.5 {
      return config.mediumDPI
    } else {
      return config.highDPI
    }
  }

  private func trackRenderTime(pageIndex: Int, level: RenderLevel, timeMs: Double) {
    let key = "\(pageIndex)-\(level.rawValue)"
    lock.lock()
    if renderTimes[key] == nil {
      renderTimes[key] = []
    }
    renderTimes[key]?.append(timeMs)
    lock.unlock()
  }

  private func persistReadingPositions() {
    // Persist reading positions to UserDefaults
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(readingPositions) {
      UserDefaults.standard.set(data, forKey: "readingPositions")
    }
  }

  private func loadReadingPositions() {
    // Load reading positions from UserDefaults
    guard let data = UserDefaults.standard.data(forKey: "readingPositions"),
          let positions = try? JSONDecoder().decode([String: ReadingPosition].self, from: data)
    else { return }

    lock.lock()
    readingPositions = positions
    lock.unlock()
  }
}


