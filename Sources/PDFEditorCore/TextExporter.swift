import Foundation

/// Structured text export — export extracted text as JSON/CSV with
/// structure preservation (headings, paragraphs, tables, lists).
///
/// First principle: text extraction should preserve structure, not just
/// characters. A heading is not a paragraph; a table is not a list.
///
/// Doctrine alignment:
/// - §3: Do things smartly — export the structure, not just the text
/// - §5: Evidence-based — preserve page numbers, positions, and types

// MARK: - Text Export Format

/// Format for exporting extracted text.
public enum TextExportFormat: String, Sendable, CaseIterable, Identifiable {
  case json = "json"
  case csv = "csv"
  case markdown = "markdown"
  case plainText = "txt"

  public var id: String { rawValue }
  public var displayName: String {
    switch self {
    case .json: return "JSON"
    case .csv: return "CSV"
    case .markdown: return "Markdown"
    case .plainText: return "Plain Text"
    }
  }
  public var fileExtension: String { rawValue }
}

// MARK: - Text Export Result

/// Result of exporting extracted text.
public struct TextExportResult: Sendable {
  /// The exported data.
  public let data: Data
  /// The format used.
  public let format: TextExportFormat
  /// Number of blocks exported.
  public let blockCount: Int
  /// Number of pages.
  public let pageCount: Int
  /// Suggested file name.
  public let suggestedFileName: String

  public init(data: Data, format: TextExportFormat, blockCount: Int, pageCount: Int, suggestedFileName: String) {
    self.data = data
    self.format = format
    self.blockCount = blockCount
    self.pageCount = pageCount
    self.suggestedFileName = suggestedFileName
  }
}

// MARK: - Text Exporter

/// Exports structured extraction results into various formats.
public struct TextExporter {

  /// Export a structured extraction result.
  public static func export(
    extraction: StructuredExtractionResult,
    format: TextExportFormat,
    fileName: String = "document"
  ) -> TextExportResult {
    let data: Data

    switch format {
    case .json:
      data = exportJSON(extraction: extraction)
    case .csv:
      data = exportCSV(extraction: extraction)
    case .markdown:
      data = exportMarkdown(extraction: extraction)
    case .plainText:
      data = exportPlainText(extraction: extraction)
    }

    return TextExportResult(
      data: data,
      format: format,
      blockCount: extraction.blocks.count,
      pageCount: extraction.pageCount,
      suggestedFileName: "\(fileName).\(format.fileExtension)"
    )
  }

  // MARK: - JSON Export

  private static func exportJSON(extraction: StructuredExtractionResult) -> Data {
    var json: [String: Any] = [
      "pageCount": extraction.pageCount,
      "blockCount": extraction.blocks.count,
      "tableCount": extraction.tables.count,
      "headingCount": extraction.headings.count,
      "extractionTimeMs": extraction.extractionTimeMs
    ]

    // Blocks with structure
    var blocksArray: [[String: Any]] = []
    for block in extraction.blocks {
      var blockDict: [String: Any] = [
        "text": block.text,
        "id": block.id
      ]
      let bounds = block.bounds
      blockDict["bounds"] = [
        "x": bounds.x,
        "y": bounds.y,
        "width": bounds.width,
        "height": bounds.height
      ]
      blocksArray.append(blockDict)
    }
    json["blocks"] = blocksArray

    // Tables
    var tablesArray: [[String: Any]] = []
    for table in extraction.tables {
      tablesArray.append([
        "rows": table.rows,
        "columns": table.columns,
        "confidence": table.confidence,
        "cells": table.cells
      ])
    }
    json["tables"] = tablesArray

    // Headings
    json["headings"] = extraction.headings.map { heading in
      ["text": heading.text, "level": heading.level, "id": heading.id] as [String: Any]
    }

    return (try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])) ?? Data()
  }

  // MARK: - CSV Export

  private static func exportCSV(extraction: StructuredExtractionResult) -> Data {
    var csv = "Type,Text\n"

    for block in extraction.blocks {
      let escapedText = block.text.replacingOccurrences(of: "\"", with: "\"\"")
      csv += "block,\"\(escapedText)\"\n"
    }

    for heading in extraction.headings {
      let escapedText = heading.text.replacingOccurrences(of: "\"", with: "\"\"")
      csv += "heading_h\(heading.level),\"\(escapedText)\"\n"
    }

    for (index, table) in extraction.tables.enumerated() {
      for (rowIdx, row) in table.cells.enumerated() {
        let cells = row.map { $0.replacingOccurrences(of: "\"", with: "\"\"") }.joined(separator: "\",\"")
        csv += "table_\(index + 1)_row_\(rowIdx + 1),table,\"\(cells)\"\n"
      }
    }

    return csv.data(using: .utf8) ?? Data()
  }

  // MARK: - Markdown Export

  private static func exportMarkdown(extraction: StructuredExtractionResult) -> Data {
    var md = "# Extracted Text\n\n"

    // All blocks
    for block in extraction.blocks {
      md += "\(block.text)\n\n"
    }

    // Tables
    if !extraction.tables.isEmpty {
      md += "\n## Tables\n\n"
      for (index, table) in extraction.tables.enumerated() {
        md += "### Table \(index + 1)\n\n"
        guard let firstRow = table.cells.first else { continue }
        md += "| " + firstRow.joined(separator: " | ") + " |\n"
        md += "| " + firstRow.map { _ in "---" }.joined(separator: " | ") + " |\n"
        for row in table.cells.dropFirst() {
          md += "| " + row.joined(separator: " | ") + " |\n"
        }
        md += "\n"
      }
    }

    return md.data(using: .utf8) ?? Data()
  }

  // MARK: - Plain Text Export

  private static func exportPlainText(extraction: StructuredExtractionResult) -> Data {
    var text = ""
    for block in extraction.blocks {
      text += "\(block.text)\n\n"
    }

    return text.data(using: .utf8) ?? Data()
  }
}
