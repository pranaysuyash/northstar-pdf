import Foundation

/// Table extraction and export — provides structured access to detected tables
/// with JSON, CSV, and Markdown export.
///
/// First principle: Tables in PDFs are structured data that users need to
/// extract, analyze, and reuse. The extractor transforms visual table layout
/// into portable structured formats.
///
/// Doctrine alignment:
/// - §3: Do things smartly — leverages existing DetectedTable from ImprovedTextExtractor
/// - §5: Evidence-based — confidence scores for each table
/// - §8: Capability routing — works standalone, no external services

// MARK: - Extracted Table

/// A table extracted from the PDF with enriched metadata.
public struct ExtractedTable: Sendable, Identifiable {
    public let id: String
    public let rows: Int
    public let columns: Int
    public let cells: [[String]]
    public let headers: [String]?
    public let bounds: PDFRect
    public let confidence: Double
    public let pageIndex: Int
    public let rowHeights: [Double]
    public let columnWidths: [Double]

    public init(
        id: String = UUID().uuidString,
        rows: Int,
        columns: Int,
        cells: [[String]],
        headers: [String]? = nil,
        bounds: PDFRect,
        confidence: Double = 0.8,
        pageIndex: Int = 0,
        rowHeights: [Double] = [],
        columnWidths: [Double] = []
    ) {
        self.id = id
        self.rows = rows
        self.columns = columns
        self.cells = cells
        self.headers = headers
        self.bounds = bounds
        self.confidence = confidence
        self.pageIndex = pageIndex
        self.rowHeights = rowHeights
        self.columnWidths = columnWidths
    }

    /// Create from a DetectedTable.
    public init(detected: DetectedTable, pageIndex: Int = 0) {
        self.id = detected.id
        self.rows = detected.rows
        self.columns = detected.columns
        self.cells = detected.cells
        // Heuristic: first row is headers if all cells are short text
        self.headers = detected.rows > 1 ? detected.cells.first : nil
        self.bounds = detected.bounds
        self.confidence = detected.confidence
        self.pageIndex = pageIndex
        self.rowHeights = detected.rowHeights
        self.columnWidths = detected.columnWidths
    }

    /// Whether this table has headers.
    public var hasHeaders: Bool { headers != nil }

    /// Data rows (excluding headers).
    public var dataRows: [[String]] {
        hasHeaders ? Array(cells.dropFirst()) : cells
    }
}

// MARK: - Table Extraction Result

/// Result of table extraction from a document.
public struct TableExtractionResult: Sendable {
    public let tables: [ExtractedTable]
    public let totalTables: Int
    public let totalPages: Int
    public let averageConfidence: Double
    public let extractionTimeMs: Double

    public init(
        tables: [ExtractedTable],
        totalTables: Int,
        totalPages: Int,
        averageConfidence: Double,
        extractionTimeMs: Double
    ) {
        self.tables = tables
        self.totalTables = totalTables
        self.totalPages = totalPages
        self.averageConfidence = averageConfidence
        self.extractionTimeMs = extractionTimeMs
    }
}

// MARK: - Table Extractor

/// Extracts and exports tables from PDF extraction results.
public struct TableExtractor: Sendable {
    /// Minimum confidence to include a table.
    private let minConfidence: Double

    public init(minConfidence: Double = 0.5) {
        self.minConfidence = minConfidence
    }

    /// Extract tables from an extraction result.
    public func extract(extraction: StructuredExtractionResult) -> TableExtractionResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        let tables = extraction.tables
            .filter { $0.confidence >= minConfidence }
            .map { ExtractedTable(detected: $0) }

        let avgConfidence = tables.isEmpty ? 0 : tables.reduce(0) { $0 + $1.confidence } / Double(tables.count)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        return TableExtractionResult(
            tables: tables,
            totalTables: tables.count,
            totalPages: extraction.pageCount,
            averageConfidence: avgConfidence,
            extractionTimeMs: elapsed
        )
    }

    // MARK: - Export Formats

    /// Export a table as JSON.
    public func exportJSON(_ table: ExtractedTable) -> Data? {
        let structure: [String: Any] = [
            "id": table.id,
            "rows": table.rows,
            "columns": table.columns,
            "headers": table.headers ?? [],
            "cells": table.cells,
            "confidence": table.confidence,
            "pageIndex": table.pageIndex
        ]
        return try? JSONSerialization.data(withJSONObject: structure, options: [.prettyPrinted, .sortedKeys])
    }

    /// Export a table as CSV.
    public func exportCSV(_ table: ExtractedTable) -> String {
        var lines: [String] = []

        // Headers
        if let headers = table.headers {
            lines.append(headers.map { escapeCSV($0) }.joined(separator: ","))
        }

        // Data rows
        let rows = table.hasHeaders ? table.dataRows : table.cells
        for row in rows {
            lines.append(row.map { escapeCSV($0) }.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// Export a table as Markdown.
    public func exportMarkdown(_ table: ExtractedTable) -> String {
        var lines: [String] = []

        if let headers = table.headers {
            lines.append("| " + headers.joined(separator: " | ") + " |")
            lines.append("| " + headers.map { _ in "---" }.joined(separator: " | ") + " |")
        }

        let rows = table.hasHeaders ? table.dataRows : table.cells
        for row in rows {
            lines.append("| " + row.joined(separator: " | ") + " |")
        }

        return lines.joined(separator: "\n")
    }

    /// Export all tables as a combined JSON array.
    public func exportAllJSON(_ result: TableExtractionResult) -> Data? {
        let structures: [[String: Any]] = result.tables.map { table in
            [
                "id": table.id,
                "rows": table.rows,
                "columns": table.columns,
                "headers": table.headers ?? [],
                "cells": table.cells,
                "confidence": table.confidence,
                "pageIndex": table.pageIndex
            ]
        }
        return try? JSONSerialization.data(withJSONObject: structures, options: [.prettyPrinted, .sortedKeys])
    }

    /// Export all tables as a single CSV (separated by blank lines).
    public func exportAllCSV(_ result: TableExtractionResult) -> String {
        result.tables.enumerated().map { index, table in
            let label = "Table \(index + 1) (Page \(table.pageIndex + 1), \(table.rows)x\(table.columns))"
            return label + "\n" + exportCSV(table)
        }.joined(separator: "\n\n")
    }

    // MARK: - Helpers

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
