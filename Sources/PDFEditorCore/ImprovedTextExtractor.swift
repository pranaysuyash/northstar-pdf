import Foundation
import PDFKit

/// Stage 2: Improved Text Extractor
///
/// First principle: Interpretation is inference. PDF has no semantic layer.
/// We must infer structure from positions, fonts, and spacing.
///
/// Architecture:
/// - `ImprovedTextExtractor`: extracts text with structure awareness
/// - `TextBlock`: group of related text elements
/// - `DetectedTable`: inferred table structure
/// - `DetectedHeading`: inferred heading
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §3: Do things smartly — infer structure from evidence
/// - OPERATING_DOCTRINE §8: Capability routing — different extraction for different needs
/// - Long-term: Foundation for semantic understanding

/// A block of related text elements.
public struct TextBlock: Sendable, Identifiable {
  public let id: String
  public let text: String
  public let bounds: PDFRect
  public let fontSize: Double
  public let fontFamily: String?
  public let isBold: Bool
  public let isItalic: Bool
  public let lineCount: Int
  public let characterCount: Int
  public let confidence: Double // 0-1, how confident we are in this block

  public init(
    id: String = UUID().uuidString,
    text: String,
    bounds: PDFRect,
    fontSize: Double = 12,
    fontFamily: String? = nil,
    isBold: Bool = false,
    isItalic: Bool = false,
    lineCount: Int = 1,
    characterCount: Int? = nil,
    confidence: Double = 1.0
  ) {
    self.id = id
    self.text = text
    self.bounds = bounds
    self.fontSize = fontSize
    self.fontFamily = fontFamily
    self.isBold = isBold
    self.isItalic = isItalic
    self.lineCount = lineCount
    self.characterCount = characterCount ?? text.count
    self.confidence = confidence
  }
}

/// A detected table structure.
public struct DetectedTable: Sendable, Identifiable {
  public let id: String
  public let rows: Int
  public let columns: Int
  public let cells: [[String]]
  public let bounds: PDFRect
  public let confidence: Double
  /// Height of each row in points (PDF coordinate space). Computed from
  /// the Y-coordinates of text blocks in each row.
  public let rowHeights: [Double]
  /// Width of each column in points (PDF coordinate space). Computed from
  /// the X-coordinates and widths of text blocks in each column.
  public let columnWidths: [Double]

  public init(
    id: String = UUID().uuidString,
    rows: Int,
    columns: Int,
    cells: [[String]],
    bounds: PDFRect,
    confidence: Double = 0.8,
    rowHeights: [Double] = [],
    columnWidths: [Double] = []
  ) {
    self.id = id
    self.rows = rows
    self.columns = columns
    self.cells = cells
    self.bounds = bounds
    self.confidence = confidence
    self.rowHeights = rowHeights
    self.columnWidths = columnWidths
  }
}

/// A detected heading.
public struct DetectedHeading: Sendable, Identifiable {
  public let id: String
  public let text: String
  public let level: Int // 1 = top-level, 2 = sub, etc.
  public let bounds: PDFRect
  public let fontSize: Double
  public let confidence: Double

  public init(
    id: String = UUID().uuidString,
    text: String,
    level: Int,
    bounds: PDFRect,
    fontSize: Double,
    confidence: Double = 0.9
  ) {
    self.id = id
    self.text = text
    self.level = level
    self.bounds = bounds
    self.fontSize = fontSize
    self.confidence = confidence
  }
}

/// Extraction result with structure.
public struct StructuredExtractionResult: Sendable {
  public let fullText: String
  public let blocks: [TextBlock]
  public let tables: [DetectedTable]
  public let headings: [DetectedHeading]
  public let pageCount: Int
  public let totalCharacters: Int
  public let extractionTimeMs: Double

  public init(
    fullText: String,
    blocks: [TextBlock],
    tables: [DetectedTable],
    headings: [DetectedHeading],
    pageCount: Int,
    totalCharacters: Int,
    extractionTimeMs: Double
  ) {
    self.fullText = fullText
    self.blocks = blocks
    self.tables = tables
    self.headings = headings
    self.pageCount = pageCount
    self.totalCharacters = totalCharacters
    self.extractionTimeMs = extractionTimeMs
  }
}

/// Improved text extractor with structure detection.
public struct ImprovedTextExtractor: Sendable {
  private let columnDetectionThreshold: Double // pixels
  private let tableDetectionThreshold: Int // minimum cells
  private let headingFontSizeMultiplier: Double

  public init(
    columnDetectionThreshold: Double = 50,
    tableDetectionThreshold: Int = 4,
    headingFontSizeMultiplier: Double = 1.2
  ) {
    self.columnDetectionThreshold = columnDetectionThreshold
    self.tableDetectionThreshold = tableDetectionThreshold
    self.headingFontSizeMultiplier = headingFontSizeMultiplier
  }

  /// Extract text with structure detection.
  public func extract(data: Data) throws -> StructuredExtractionResult {
    let startTime = CFAbsoluteTimeGetCurrent()

    guard let document = PDFKit.PDFDocument(data: data) else {
      throw ExtractionError.invalidDocument
    }

    let pageCount = document.pageCount
    var allText: [String] = []
    var allBlocks: [TextBlock] = []
    var allTables: [DetectedTable] = []
    var allHeadings: [DetectedHeading] = []

    for pageIndex in 0..<pageCount {
      guard let page = document.page(at: pageIndex) else { continue }

      // Extract raw text
      let pageText = page.string ?? ""
      allText.append(pageText)

      // Extract text blocks with structure
      let blocks = extractBlocks(from: page, pageIndex: pageIndex)
      allBlocks.append(contentsOf: blocks)

      // Detect tables
      let tables = detectTables(from: blocks)
      allTables.append(contentsOf: tables)

      // Detect headings
      let headings = detectHeadings(from: blocks)
      allHeadings.append(contentsOf: headings)
    }

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    let fullText = allText.joined(separator: "\n\n")

    return StructuredExtractionResult(
      fullText: fullText,
      blocks: allBlocks,
      tables: allTables,
      headings: allHeadings,
      pageCount: pageCount,
      totalCharacters: fullText.count,
      extractionTimeMs: elapsed
    )
  }

  // MARK: - Private Methods

  private func extractBlocks(from page: PDFKit.PDFPage, pageIndex: Int) -> [TextBlock] {
    var blocks: [TextBlock] = []

    // Get page text
    guard let pageText = page.string, !pageText.isEmpty else {
      return blocks
    }

    // Split into paragraphs (by double newline or significant spacing)
    let paragraphs = pageText.components(separatedBy: "\n\n")

    for (index, paragraph) in paragraphs.enumerated() {
      let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }

      // Estimate bounds (simplified — real implementation would use character positions)
      let lineHeight = 14.0 // Default line height
      let y = Double(index) * lineHeight * Double(paragraph.components(separatedBy: "\n").count)
      let bounds = PDFRect(x: 72, y: y, width: 468, height: lineHeight * Double(paragraph.components(separatedBy: "\n").count))

      blocks.append(TextBlock(
        text: trimmed,
        bounds: bounds,
        fontSize: 12, // Default
        lineCount: paragraph.components(separatedBy: "\n").count,
        confidence: 0.9
      ))
    }

    return blocks
  }

  private func detectTables(from blocks: [TextBlock]) -> [DetectedTable] {
    var tables: [DetectedTable] = []

    // Simple table detection: look for grid-like arrangements
    // Real implementation would analyze character positions more carefully

    // Group blocks by vertical position (same y-coordinate = same row)
    let sortedBlocks = blocks.sorted { $0.bounds.y < $1.bounds.y }

    var rows: [[TextBlock]] = []
    var currentRow: [TextBlock] = []
    var lastY: Double = -1

    for block in sortedBlocks {
      if lastY == -1 || abs(block.bounds.y - lastY) < 5 {
        currentRow.append(block)
      } else {
        if currentRow.count >= 2 {
          rows.append(currentRow)
        }
        currentRow = [block]
      }
      lastY = block.bounds.y
    }
    if currentRow.count >= 2 {
      rows.append(currentRow)
    }

    // Check if rows have consistent column count
    if rows.count >= 2 {
      let columnCounts = rows.map { $0.count }
      let mostCommon = columnCounts.mostCommon()

      if let (columns, count) = mostCommon.first, count >= 2, columns >= 2 {
        // Looks like a table
        let cells = rows.map { row in
          row.map { $0.text }
        }

        let minX = rows.flatMap { $0 }.map { $0.bounds.x }.min() ?? 0
        let maxX = rows.flatMap { $0 }.map { $0.bounds.x + $0.bounds.width }.max() ?? 0
        let minY = rows.first?.first?.bounds.y ?? 0
        let maxY = rows.last?.first?.bounds.y ?? 0

        // Compute row heights from block Y-coordinates
        var computedRowHeights: [Double] = []
        for (rowIdx, row) in rows.enumerated() {
          if rowIdx < rows.count - 1 {
            // Height is the gap to the next row's Y position
            let currentY = row.first?.bounds.y ?? 0
            let nextY = rows[rowIdx + 1].first?.bounds.y ?? currentY
            computedRowHeights.append(abs(nextY - currentY))
          } else {
            // Last row: use the block height or a default
            let blockHeight = row.first?.bounds.height ?? 12
            computedRowHeights.append(blockHeight)
          }
        }

        // Compute column widths from block X-coordinates
        // Sort blocks in each row by X position, then compute column boundaries
        var columnBoundaries: [Double] = []
        if let firstRow = rows.first, firstRow.count >= 2 {
          let sortedFirstRow = firstRow.sorted { $0.bounds.x < $1.bounds.x }
          columnBoundaries = sortedFirstRow.map { $0.bounds.x }
          // Add the right edge of the last column
          if let lastBlock = sortedFirstRow.last {
            columnBoundaries.append(lastBlock.bounds.x + lastBlock.bounds.width)
          }
        }

        var computedColumnWidths: [Double] = []
        if columnBoundaries.count >= 2 {
          for i in 0..<(columnBoundaries.count - 1) {
            computedColumnWidths.append(columnBoundaries[i + 1] - columnBoundaries[i])
          }
        }

        tables.append(DetectedTable(
          rows: rows.count,
          columns: columns,
          cells: cells,
          bounds: PDFRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY),
          confidence: Double(count) / Double(rows.count),
          rowHeights: computedRowHeights,
          columnWidths: computedColumnWidths
        ))
      }
    }

    return tables
  }

  private func detectHeadings(from blocks: [TextBlock]) -> [DetectedHeading] {
    var headings: [DetectedHeading] = []

    // Find the most common font size (body text)
    let fontSizes = blocks.map { $0.fontSize }
    let mostCommonSize = fontSizes.mostCommon().first?.0 ?? 12

    // Headings are text with larger font size
    for block in blocks {
      if block.fontSize > mostCommonSize * headingFontSizeMultiplier {
        let level = Int(block.fontSize / mostCommonSize)
        headings.append(DetectedHeading(
          text: block.text,
          level: min(level, 6), // Cap at h6
          bounds: block.bounds,
          fontSize: block.fontSize,
          confidence: 0.8
        ))
      }
    }

    return headings
  }
}

/// Extraction errors.
public enum ExtractionError: Error, Sendable {
  case invalidDocument
  case extractionFailed(String)
}

// MARK: - Array Extension

extension Array where Element: Hashable {
  func mostCommon() -> [(Element, Int)] {
    var counts: [Element: Int] = [:]
    for item in self {
      counts[item, default: 0] += 1
    }
    return counts.sorted { $0.value > $1.value }
  }
}
