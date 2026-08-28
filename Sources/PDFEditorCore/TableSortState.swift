import Foundation

/// Sort direction for a table column.
public enum SortDirection: Sendable, Hashable {
  case ascending
  case descending

  /// Toggle to the opposite direction.
  public var toggled: SortDirection {
    switch self {
    case .ascending: return .descending
    case .descending: return .ascending
    }
  }

  /// Arrow symbol name for display.
  public var symbolName: String {
    switch self {
    case .ascending: return "arrow.up"
    case .descending: return "arrow.down"
    }
  }
}

/// Sort state for a table — tracks which column is sorted and in what direction.
///
/// First principle: the user's reference context (header row) should also be
/// the sort control. Clicking a header sorts by that column; clicking again
/// reverses. The frozen header stays pinned while the body reorders.
///
/// Doctrine alignment:
/// - §3: Smart defaults — no sort until the user asks; ascending first click
/// - §8: Capability routing — sort is available when freeze is active with pinned rows
/// - Long-term: Foundation for multi-column sort, group-by, pivot tables
@MainActor
public final class TableSortState: ObservableObject {
  /// Column index being sorted (nil = no sort).
  @Published public var sortedColumn: Int?
  /// Current sort direction.
  @Published public var sortDirection: SortDirection = .ascending
  /// The original (unsorted) cell data.
  @Published public var originalCells: [[String]] = []
  /// The sorted cell data (body rows only, excluding header).
  @Published public var sortedCells: [[String]] = []
  /// Whether sort is active.
  public var isSorted: Bool { sortedColumn != nil }

  public init() {}

  /// Apply a sort to the given column index.
  ///
  /// If the column is already sorted, toggles direction.
  /// If a different column is clicked, sorts ascending by default.
  public func applySort(
    column: Int,
    cells: [[String]],
    headerRowCount: Int = 1
  ) {
    // Store original if not already stored
    if originalCells.isEmpty {
      originalCells = cells
    }

    // Toggle if same column
    if sortedColumn == column {
      sortDirection = sortDirection.toggled
    } else {
      sortedColumn = column
      sortDirection = .ascending
    }

    // Sort body rows (skip header rows)
    let header = Array(cells.prefix(headerRowCount))
    let body = Array(cells.dropFirst(headerRowCount))

    sortedCells = header + sortBody(body, column: column, direction: sortDirection)
  }

  /// Clear the sort and restore original order.
  public func clearSort() {
    sortedColumn = nil
    sortDirection = .ascending
    if !originalCells.isEmpty {
      sortedCells = originalCells
    }
  }

  /// Sort body rows by the given column.
  private func sortBody(
    _ body: [[String]],
    column: Int,
    direction: SortDirection
  ) -> [[String]] {
    guard column >= 0 else { return body }

    return body.sorted { row1, row2 in
      let val1 = column < row1.count ? row1[column] : ""
      let val2 = column < row2.count ? row2[column] : ""

      // Try numeric comparison first
      if let num1 = Double(val1.replacingOccurrences(of: ",", with: "")),
         let num2 = Double(val2.replacingOccurrences(of: ",", with: "")) {
        return direction == .ascending ? num1 < num2 : num1 > num2
      }

      // Fall back to string comparison
      let result = val1.localizedCaseInsensitiveCompare(val2)
      return direction == .ascending ? result == .orderedAscending : result == .orderedDescending
    }
  }

  /// Get the cells to display (sorted or original).
  public var displayCells: [[String]] {
    isSorted ? sortedCells : (originalCells.isEmpty ? sortedCells : originalCells)
  }
}
