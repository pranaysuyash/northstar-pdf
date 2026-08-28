import AppKit
import CoreGraphics
import Foundation
import PDFKit

/// Comic reading mode: panel-zoom navigation with optional right-to-left order.
///
/// First principle: comics are not read like text. The content unit is the
/// *panel*, not the paragraph. Reading is spatial (tap panel → fill screen)
/// not linear (scroll down). RTL for manga reverses the page and panel order.
///
/// Architecture:
/// - `ComicPanel` — a detected rectangular region on a page
/// - `PanelDetector` — analyzes a rendered page image for panel boundaries
/// - `ComicModeConfig` — RTL toggle, panel ordering preferences
/// - `ComicReadingState` — current page + panel position in the reading flow
///
/// Doctrine alignment:
/// - §3: Do things smartly — route to the right display for the content type
/// - §8: Capability routing — comic mode is activated when document type = graphic
/// - Long-term: Foundation for spread view, panel annotations, reading progress

// MARK: - Comic Panel

/// A detected rectangular panel on a page.
public struct ComicPanel: Sendable, Identifiable {
  public let id: String
  public let pageIndex: Int
  public let bounds: CGRect // in page coordinates (points)
  public let index: Int // order within the page

  public init(pageIndex: Int, bounds: CGRect, index: Int) {
    self.id = "\(pageIndex)-\(index)"
    self.pageIndex = pageIndex
    self.bounds = bounds
    self.index = index
  }
}

// MARK: - Comic Mode Configuration

/// Configuration for comic reading mode.
public struct ComicModeConfig: Sendable {
  /// Whether to read pages right-to-left (manga mode).
  public var isRTL: Bool
  /// Whether to auto-detect panels or treat each page as one panel.
  public var autoDetectPanels: Bool
  /// Whether to show page numbers.
  public var showPageNumbers: Bool

  public init(
    isRTL: Bool = false,
    autoDetectPanels: Bool = true,
    showPageNumbers: Bool = true
  ) {
    self.isRTL = isRTL
    self.autoDetectPanels = autoDetectPanels
    self.showPageNumbers = showPageNumbers
  }

  /// Default manga configuration.
  public static let manga = ComicModeConfig(isRTL: true, autoDetectPanels: true)
  /// Default western comic configuration.
  public static let western = ComicModeConfig(isRTL: false, autoDetectPanels: true)
  /// Full-page mode (no panel detection, each page = one panel).
  public static let fullPage = ComicModeConfig(isRTL: false, autoDetectPanels: false)
}

// MARK: - Panel Detector

/// Detects panel boundaries from a rendered page image.
///
/// Strategy: find horizontal and vertical whitespace runs that span most of
/// the page width/height, then intersect them to find panel rectangles.
/// This is a heuristic that works well for typical comic layouts (grid panels,
/// irregular panels with gutters).
public struct PanelDetector: Sendable {

  public init() {}

  /// Detect panels from a rendered page image.
  ///
  /// - Parameters:
  ///   - image: The rendered page as a CGImage
  ///   - pageIndex: The page index this image is from
  ///   - pageBounds: The page bounds in points
  /// - Returns: Array of detected panels, sorted in reading order
  public func detectPanels(
    image: CGImage,
    pageIndex: Int,
    pageBounds: CGRect
  ) -> [ComicPanel] {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return [] }

    // Get pixel data
    guard let dataProvider = image.dataProvider,
          let pixelData = dataProvider.data,
          let pixels = CFDataGetBytePtr(pixelData) else {
      return []
    }

    let bytesPerPixel = 4
    let bytesPerRow = image.bytesPerRow

    // Find horizontal whitespace rows (rows where most pixels are white/light)
    let whitespaceThreshold: UInt8 = 240 // near-white
    let minRunFraction = 0.7 // row must be 70%+ white to be a gutter

    var whiteRows: [Int] = []
    for y in 0..<height {
      var whiteCount = 0
      let rowStart = y * bytesPerRow
      for x in stride(from: 0, to: width, by: max(1, width / 20)) { // sample 20 columns
        let idx = rowStart + x * bytesPerPixel
        if idx + 2 < CFDataGetLength(pixelData) {
          let r = pixels[idx]
          let g = pixels[idx + 1]
          let b = pixels[idx + 2]
          if r > whitespaceThreshold && g > whitespaceThreshold && b > whitespaceThreshold {
            whiteCount += 1
          }
        }
      }
      let sampled = width / max(1, width / 20)
      if Double(whiteCount) / Double(max(1, sampled)) >= minRunFraction {
        whiteRows.append(y)
      }
    }

    // Find vertical whitespace columns
    var whiteCols: [Int] = []
    for x in stride(from: 0, to: width, by: max(1, width / 20)) {
      var whiteCount = 0
      for y in stride(from: 0, to: height, by: max(1, height / 20)) {
        let idx = y * bytesPerRow + x * bytesPerPixel
        if idx + 2 < CFDataGetLength(pixelData) {
          let r = pixels[idx]
          let g = pixels[idx + 1]
          let b = pixels[idx + 2]
          if r > whitespaceThreshold && g > whitespaceThreshold && b > whitespaceThreshold {
            whiteCount += 1
          }
        }
      }
      let sampled = height / max(1, height / 20)
      if Double(whiteCount) / Double(max(1, sampled)) >= minRunFraction {
        whiteCols.append(x)
      }
    }

    // Find gaps in white rows (these are panel strips)
    let hGaps = findGaps(in: whiteRows, maxValue: height)
    let vGaps = findGaps(in: whiteCols, maxValue: width)

    // If no gaps found, treat the entire page as one panel
    if hGaps.isEmpty && vGaps.isEmpty {
      return [ComicPanel(pageIndex: pageIndex, bounds: pageBounds, index: 0)]
    }

    // Find gaps in the gap lists (these are the panel regions)
    let hRanges = findRanges(in: hGaps, max: height)
    let vRanges = findRanges(in: vGaps, max: width)

    // Intersect horizontal and vertical ranges to get panel rectangles
    var panels: [ComicPanel] = []
    var panelIndex = 0

    for hRange in hRanges {
      for vRange in vRanges {
        let panelRect = CGRect(
          x: pageBounds.origin.x + (CGFloat(vRange.lowerBound) / CGFloat(width)) * pageBounds.width,
          y: pageBounds.origin.y + (CGFloat(hRange.lowerBound) / CGFloat(height)) * pageBounds.height,
          width: (CGFloat(vRange.count) / CGFloat(width)) * pageBounds.width,
          height: (CGFloat(hRange.count) / CGFloat(height)) * pageBounds.height
        )

        // Skip very small panels (< 5% of page area)
        let panelArea = panelRect.width * panelRect.height
        let pageArea = pageBounds.width * pageBounds.height
        guard panelArea / pageArea > 0.05 else { continue }

        panels.append(ComicPanel(pageIndex: pageIndex, bounds: panelRect, index: panelIndex))
        panelIndex += 1
      }
    }

    // If no panels detected from intersection, fall back to horizontal strips
    if panels.isEmpty && !hRanges.isEmpty {
      for (i, hRange) in hRanges.enumerated() {
        let panelRect = CGRect(
          x: pageBounds.origin.x,
          y: pageBounds.origin.y + (CGFloat(hRange.lowerBound) / CGFloat(height)) * pageBounds.height,
          width: pageBounds.width,
          height: (CGFloat(hRange.count) / CGFloat(height)) * pageBounds.height
        )
        panels.append(ComicPanel(pageIndex: pageIndex, bounds: panelRect, index: i))
      }
    }

    // Final fallback: whole page
    if panels.isEmpty {
      return [ComicPanel(pageIndex: pageIndex, bounds: pageBounds, index: 0)]
    }

    return panels
  }

  // MARK: - Private Helpers

  /// Find gaps (runs of non-white) in a list of white positions.
  private func findGaps(in whites: [Int], maxValue: Int) -> [Int] {
    guard !whites.isEmpty else { return [] }
    var gaps: [Int] = []
    let whiteSet = Set(whites)
    for i in 0..<maxValue {
      if !whiteSet.contains(i) {
        gaps.append(i)
      }
    }
    return gaps
  }

  /// Find contiguous ranges in a list of values.
  private func findRanges(in values: [Int], max: Int) -> [Range<Int>] {
    guard !values.isEmpty else { return [] }
    var ranges: [Range<Int>] = []
    var start = values[0]
    var prev = values[0]

    for v in values.dropFirst() {
      if v == prev + 1 {
        prev = v
      } else {
        if start < prev {
          ranges.append(start..<prev + 1)
        }
        start = v
        prev = v
      }
    }
    if start < prev {
      ranges.append(start..<prev + 1)
    }
    return ranges
  }
}

// MARK: - Comic Reading State

/// Tracks the current position in a comic reading flow.
public struct ComicReadingState: Sendable {
  /// The ordered list of panels across all pages (the reading flow).
  public let panels: [ComicPanel]
  /// Index into the panels array (current position in reading flow).
  public var currentPanelIndex: Int
  /// Configuration.
  public let config: ComicModeConfig

  public var currentPanel: ComicPanel? {
    guard currentPanelIndex >= 0, currentPanelIndex < panels.count else { return nil }
    return panels[currentPanelIndex]
  }

  public var totalPanels: Int { panels.count }
  public var progress: Double {
    guard totalPanels > 0 else { return 0 }
    return Double(currentPanelIndex + 1) / Double(totalPanels)
  }

  public init(panels: [ComicPanel], config: ComicModeConfig = ComicModeConfig()) {
    self.config = config
    self.currentPanelIndex = 0

    // Apply RTL ordering if configured
    if config.isRTL {
      // Group panels by page, reverse page order, reverse within each page
      let grouped = Dictionary(grouping: panels, by: \.pageIndex)
      let sortedPages = grouped.keys.sorted(by: >) // RTL: highest page first
      var orderedPanels: [ComicPanel] = []
      for pageIndex in sortedPages {
        let pagePanels = grouped[pageIndex]!
          .sorted { $0.index > $1.index } // RTL: reverse panel order within page
        orderedPanels.append(contentsOf: pagePanels)
      }
      self.panels = orderedPanels
    } else {
      self.panels = panels.sorted {
        $0.pageIndex < $1.pageIndex || ($0.pageIndex == $1.pageIndex && $0.index < $1.index)
      }
    }
  }

  /// Advance to the next panel. Returns false if at the end.
  public mutating func advance() -> Bool {
    guard currentPanelIndex + 1 < panels.count else { return false }
    currentPanelIndex += 1
    return true
  }

  /// Go to the previous panel. Returns false if at the start.
  public mutating func goBack() -> Bool {
    guard currentPanelIndex > 0 else { return false }
    currentPanelIndex -= 1
    return true
  }

  /// Jump to a specific panel index.
  public mutating func jumpTo(panelIndex: Int) {
    currentPanelIndex = max(0, min(panelIndex, panels.count - 1))
  }
}
