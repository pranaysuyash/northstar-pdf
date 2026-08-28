import Foundation

/// Table extraction export — converts DetectedTable data into JSON and CSV formats.
///
/// First principle: tables are structured data; they should export as structured data,
/// not as text. A table in a PDF is not just text — it has rows, columns, and cells.
///
/// Doctrine alignment:
/// - §3: Do things smartly — export the structure, not just the text
/// - §5: Evidence-based — preserve cell-level data with coordinates

// MARK: - Table Export Format

/// Format for exporting table data.
public enum TableExportFormat: String, Sendable, CaseIterable, Identifiable {
  case json = "json"
  case csv = "csv"
  case markdown = "markdown"

  public var id: String { rawValue }
  public var displayName: String { rawValue.uppercased() }
  public var fileExtension: String { rawValue }
}

// MARK: - Table Export Result

/// Result of exporting a table.
public struct TableExportResult: Sendable {
  /// The exported data.
  public let data: Data
  /// The format used.
  public let format: TableExportFormat
  /// Number of rows.
  public let rowCount: Int
  /// Number of columns.
  public let columnCount: Int
  /// Suggested file name.
  public let suggestedFileName: String

  public init(data: Data, format: TableExportFormat, rowCount: Int, columnCount: Int, suggestedFileName: String) {
    self.data = data
    self.format = format
    self.rowCount = rowCount
    self.columnCount = columnCount
    self.suggestedFileName = suggestedFileName
  }
}

// MARK: - Table Exporter

/// Exports DetectedTable data into various formats.
public struct TableExporter {

  /// Export a single table in the specified format.
  public static func export(
    table: DetectedTable,
    format: TableExportFormat,
    tableName: String = "table"
  ) -> TableExportResult {
    let data: Data

    switch format {
    case .json:
      data = exportJSON(table: table)
    case .csv:
      data = exportCSV(table: table)
    case .markdown:
      data = exportMarkdown(table: table)
    }

    return TableExportResult(
      data: data,
      format: format,
      rowCount: table.rows,
      columnCount: table.columns,
      suggestedFileName: "\(tableName).\(format.fileExtension)"
    )
  }

  /// Export all tables from an extraction result.
  public static func exportAll(
    tables: [DetectedTable],
    format: TableExportFormat
  ) -> [TableExportResult] {
    tables.enumerated().map { index, table in
      export(table: table, format: format, tableName: "table_\(index + 1)")
    }
  }

  // MARK: - JSON Export

  private static func exportJSON(table: DetectedTable) -> Data {
    let json: [String: Any] = [
      "rows": table.rows,
      "columns": table.columns,
      "confidence": table.confidence,
      "cells": table.cells.map { row in
        row.map { cell in
          ["text": cell]
        }
      }
    ]

    return (try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])) ?? Data()
  }

  // MARK: - CSV Export

  private static func exportCSV(table: DetectedTable) -> Data {
    var csv = ""

    for row in table.cells {
      let line = row.map { cell in
        // Escape CSV: quote if contains comma, quote, or newline
        if cell.contains(",") || cell.contains("\"") || cell.contains("\n") {
          return "\"\(cell.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return cell
      }.joined(separator: ",")
      csv += line + "\n"
    }

    return csv.data(using: .utf8) ?? Data()
  }

  // MARK: - Markdown Export

  private static func exportMarkdown(table: DetectedTable) -> Data {
    var md = ""

    guard !table.cells.isEmpty else {
      return md.data(using: .utf8) ?? Data()
    }

    // Header row
    if let firstRow = table.cells.first {
      md += "| " + firstRow.joined(separator: " | ") + " |\n"
      md += "| " + firstRow.map { _ in "---" }.joined(separator: " | ") + " |\n"
    }

    // Data rows
    for row in table.cells.dropFirst() {
      md += "| " + row.joined(separator: " | ") + " |\n"
    }

    return md.data(using: .utf8) ?? Data()
  }
}
