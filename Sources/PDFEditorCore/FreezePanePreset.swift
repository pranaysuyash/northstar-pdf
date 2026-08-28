import Foundation

/// Freeze pane presets for common table types.
///
/// Each preset describes a freeze configuration optimized for a specific
/// table layout pattern. Presets are matched from table structure (row/column
/// counts, content patterns) and can be applied manually or auto-suggested.
///
/// First principle: different table genres have different reference contexts.
/// A spreadsheet's header row is the reference; an invoice's line-item table
/// has no meaningful header to freeze. The preset encodes domain knowledge
/// about what "reference" means for each genre.
///
/// Doctrine alignment:
/// - §3: Do things smartly — presets encode expert knowledge about table layouts
/// - §8: Capability routing — preset suggestion is a capability activated when
///        table structure matches a known pattern
/// - Long-term: Foundation for content-type-aware layout, smart defaults

// MARK: - Freeze Pane Preset

/// A named freeze configuration optimized for a specific table genre.
public struct FreezePanePreset: Sendable, Identifiable, Hashable {
  public let id: String
  /// Human-readable name (e.g., "Spreadsheet", "Financial Report").
  public let name: String
  /// SF Symbol icon name.
  public let icon: String
  /// Description of when this preset applies.
  public let description: String
  /// The freeze configuration to apply.
  public let config: FreezePaneConfig
  /// Minimum number of rows required for this preset to match.
  public let minRows: Int
  /// Minimum number of columns required for this preset to match.
  public let minColumns: Int
  /// Maximum number of columns for this preset to match (nil = no limit).
  public let maxColumns: Int?
  /// Content hints — keywords in cell text that strengthen the match.
  public let contentHints: [String]
  /// Match weight when structure matches (0.0–1.0).
  public let structuralWeight: Double
  /// Match weight when content hints match (0.0–1.0).
  public let contentWeight: Double

  public init(
    id: String,
    name: String,
    icon: String,
    description: String,
    config: FreezePaneConfig,
    minRows: Int,
    minColumns: Int,
    maxColumns: Int? = nil,
    contentHints: [String] = [],
    structuralWeight: Double = 0.7,
    contentWeight: Double = 0.3
  ) {
    self.id = id
    self.name = name
    self.icon = icon
    self.description = description
    self.config = config
    self.minRows = minRows
    self.minColumns = minColumns
    self.maxColumns = maxColumns
    self.contentHints = contentHints
    self.structuralWeight = structuralWeight
    self.contentWeight = contentWeight
  }

  // MARK: - Built-in Presets

  /// Spreadsheet: freeze header row + first column (row labels).
  /// Typical: ≥3 rows, ≥3 columns, first row is headers.
  public static let spreadsheet = FreezePanePreset(
    id: "spreadsheet",
    name: "Spreadsheet",
    icon: "tablecells",
    description: "Freeze header row and first column for tabular data with row labels",
    config: FreezePaneConfig(pinnedRows: 1, pinnedColumns: 1),
    minRows: 3,
    minColumns: 3,
    contentHints: ["Q1", "Q2", "Q3", "Q4", "Total", "Sum", "Jan", "Feb", "Mar",
                   "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
                   "FY", "Revenue", "Expenses"],
    structuralWeight: 0.6,
    contentWeight: 0.4
  )

  /// Financial report: freeze header row + first 2 columns (category + subcategory).
  /// Typical: ≥5 rows, ≥4 columns, financial terminology in headers.
  public static let financialReport = FreezePanePreset(
    id: "financial_report",
    name: "Financial Report",
    icon: "dollarsign.circle",
    description: "Freeze header row and category columns for financial statements",
    config: FreezePaneConfig(pinnedRows: 1, pinnedColumns: 2),
    minRows: 5,
    minColumns: 4,
    contentHints: ["Revenue", "Expense", "Profit", "Loss", "Assets", "Liabilities",
                   "Equity", "Cash Flow", "Balance Sheet", "Income",
                   "EBITDA", "Net Income", "Gross", "Operating"],
    structuralWeight: 0.5,
    contentWeight: 0.5
  )

  /// Invoice: freeze header row only (line items scroll vertically).
  /// Typical: ≥3 rows, ≥3 columns, contains price/quantity keywords.
  public static let invoice = FreezePanePreset(
    id: "invoice",
    name: "Invoice",
    icon: "doc.text",
    description: "Freeze header row for line-item tables with prices",
    config: FreezePaneConfig(pinnedRows: 1, pinnedColumns: 0),
    minRows: 3,
    minColumns: 3,
    maxColumns: 8,
    contentHints: ["Item", "Description", "Qty", "Quantity", "Price", "Amount",
                   "Unit", "Total", "Subtotal", "Tax", "Discount",
                   "Product", "Service", "Rate"],
    structuralWeight: 0.4,
    contentWeight: 0.6
  )

  /// Simple list: freeze header row only (no column freeze needed).
  /// Typical: 2–4 columns, long row count, simple structure.
  public static let simpleList = FreezePanePreset(
    id: "simple_list",
    name: "Simple List",
    icon: "list.bullet",
    description: "Freeze header row for long lists with few columns",
    config: FreezePaneConfig(pinnedRows: 1, pinnedColumns: 0),
    minRows: 5,
    minColumns: 2,
    maxColumns: 4,
    contentHints: [],
    structuralWeight: 0.8,
    contentWeight: 0.2
  )

  /// Wide data: freeze first column only (row labels scroll horizontally).
  /// Typical: ≥5 columns, first column is identifiers/labels.
  public static let wideData = FreezePanePreset(
    id: "wide_data",
    name: "Wide Data",
    icon: "rectangle.expand.vertical",
    description: "Freeze first column for wide tables with row identifiers",
    config: FreezePaneConfig(pinnedRows: 0, pinnedColumns: 1),
    minRows: 3,
    minColumns: 5,
    contentHints: ["ID", "Name", "Label", "Category", "Type", "Status"],
    structuralWeight: 0.7,
    contentWeight: 0.3
  )

  /// No freeze: table doesn't benefit from freezing.
  /// Fallback when no preset matches well.
  public static let none = FreezePanePreset(
    id: "none",
    name: "No Freeze",
    icon: "pin.slash",
    description: "Don't freeze any rows or columns",
    config: .none,
    minRows: 0,
    minColumns: 0,
    structuralWeight: 1.0,
    contentWeight: 0.0
  )

  /// All built-in presets (excluding .none).
  public static let allPresets: [FreezePanePreset] = [
    .spreadsheet, .financialReport, .invoice, .simpleList, .wideData,
  ]

  // MARK: - Matching

  /// Compute a match score for a table with the given structure.
  ///
  /// Returns a value from 0.0 (no match) to 1.0 (perfect match).
  public func matchScore(
    rows: Int,
    columns: Int,
    cellTexts: [String] = []
  ) -> Double {
    // Structural check: row/column bounds
    guard rows >= minRows, columns >= minColumns else { return 0 }
    if let max = maxColumns, columns > max { return 0 }

    // Structural score: how close the table is to ideal dimensions
    let structuralScore: Double
    if rows >= minRows && columns >= minColumns {
      structuralScore = 1.0
    } else {
      structuralScore = 0
    }

    // Content score: fraction of hints found in cell text
    let contentScore: Double
    if contentHints.isEmpty {
      contentScore = 0
    } else {
      let lowerCells = cellTexts.map { $0.lowercased() }
      let matchedHints = contentHints.filter { hint in
        lowerCells.contains { $0.contains(hint.lowercased()) }
      }
      contentScore = Double(matchedHints.count) / Double(contentHints.count)
    }

    return structuralScore * structuralWeight + contentScore * contentWeight
  }
}

// MARK: - Preset Matcher

/// Matches a detected table against known presets and returns ranked suggestions.
public struct FreezePanePresetMatcher: Sendable {
  public init() {}

  /// Match a table against all presets and return candidates sorted by score.
  ///
  /// - Parameters:
  ///   - rows: Number of rows in the detected table.
  ///   - columns: Number of columns in the detected table.
  ///   - cellTexts: All cell text content (for content-based matching).
  ///   - threshold: Minimum score to include in results (default 0.3).
  /// - Returns: Matched presets sorted by score descending.
  public func match(
    rows: Int,
    columns: Int,
    cellTexts: [String] = [],
    threshold: Double = 0.3
  ) -> [(preset: FreezePanePreset, score: Double)] {
    var results: [(preset: FreezePanePreset, score: Double)] = []

    for preset in FreezePanePreset.allPresets {
      let score = preset.matchScore(rows: rows, columns: columns, cellTexts: cellTexts)
      if score >= threshold {
        results.append((preset: preset, score: score))
      }
    }

    return results.sorted { $0.score > $1.score }
  }

  /// Return the best matching preset, or nil if nothing scores above threshold.
  public func bestMatch(
    rows: Int,
    columns: Int,
    cellTexts: [String] = [],
    threshold: Double = 0.3
  ) -> FreezePanePreset? {
    match(rows: rows, columns: columns, cellTexts: cellTexts, threshold: threshold).first?.preset
  }
}
