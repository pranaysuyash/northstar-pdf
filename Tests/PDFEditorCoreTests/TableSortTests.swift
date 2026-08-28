import Testing
@testable import PDFEditorCore

@Suite("TableSortState")
struct TableSortTests {
  // MARK: - Basic Sorting

  @Test("Sort ascending by text column")
  func sortAscending() async {
    let state = await TableSortState()
    let cells = [
      ["Name", "Score"],
      ["Alice", "85"],
      ["Bob", "92"],
      ["Charlie", "78"],
    ]
    await state.applySort(column: 0, cells: cells)
    let result = await state.displayCells
    #expect(result[1][0] == "Alice")
    #expect(result[2][0] == "Bob")
    #expect(result[3][0] == "Charlie")
  }

  @Test("Sort descending toggles direction")
  func sortDescending() async {
    let state = await TableSortState()
    let cells = [
      ["Name", "Score"],
      ["Alice", "85"],
      ["Bob", "92"],
      ["Charlie", "78"],
    ]
    await state.applySort(column: 0, cells: cells)
    await state.applySort(column: 0, cells: cells)
    let result = await state.displayCells
    #expect(result[1][0] == "Charlie")
    #expect(result[2][0] == "Bob")
    #expect(result[3][0] == "Alice")
  }

  @Test("Sort numeric column correctly")
  func sortNumeric() async {
    let state = await TableSortState()
    let cells = [
      ["Item", "Price"],
      ["Widget", "25.00"],
      ["Gadget", "10.00"],
      ["Doohickey", "50.00"],
    ]
    await state.applySort(column: 1, cells: cells)
    let result = await state.displayCells
    #expect(result[1][0] == "Gadget")   // 10.00
    #expect(result[2][0] == "Widget")   // 25.00
    #expect(result[3][0] == "Doohickey") // 50.00
  }

  @Test("Sort handles comma-separated numbers")
  func sortCommaNumbers() async {
    let state = await TableSortState()
    let cells = [
      ["Item", "Revenue"],
      ["A", "1,000"],
      ["B", "500"],
      ["C", "10,000"],
    ]
    await state.applySort(column: 1, cells: cells)
    let result = await state.displayCells
    #expect(result[1][0] == "B")   // 500
    #expect(result[2][0] == "A")   // 1,000
    #expect(result[3][0] == "C")   // 10,000
  }

  // MARK: - Header Preservation

  @Test("Header row stays on top after sort")
  func headerPreserved() async {
    let state = await TableSortState()
    let cells = [
      ["Name", "Score"],
      ["Bob", "92"],
      ["Alice", "85"],
    ]
    await state.applySort(column: 0, cells: cells)
    let result = await state.displayCells
    #expect(result[0][0] == "Name")
    #expect(result[0][1] == "Score")
  }

  @Test("Multiple header rows preserved")
  func multiHeaderPreserved() async {
    let state = await TableSortState()
    let cells = [
      ["Report Title", ""],
      ["Name", "Score"],
      ["Bob", "92"],
      ["Alice", "85"],
    ]
    await state.applySort(column: 0, cells: cells, headerRowCount: 2)
    let result = await state.displayCells
    #expect(result[0][0] == "Report Title")
    #expect(result[1][0] == "Name")
    #expect(result[2][0] == "Alice")
    #expect(result[3][0] == "Bob")
  }

  // MARK: - Clear Sort

  @Test("Clear sort restores original order")
  func clearSort() async {
    let state = await TableSortState()
    let cells = [
      ["Name", "Score"],
      ["Bob", "92"],
      ["Alice", "85"],
      ["Charlie", "78"],
    ]
    await state.applySort(column: 0, cells: cells)
    await state.clearSort()
    let result = await state.displayCells
    #expect(result[1][0] == "Bob")
    #expect(result[2][0] == "Alice")
    #expect(result[3][0] == "Charlie")
  }

  // MARK: - Sort State Tracking

  @Test("isSorted is true after sort")
  func isSortedTracking() async {
    let state = await TableSortState()
    #expect(await state.isSorted == false)
    await state.applySort(column: 0, cells: [["H", "V"], ["A", "1"]])
    #expect(await state.isSorted == true)
    await state.clearSort()
    #expect(await state.isSorted == false)
  }

  @Test("Sorted column and direction tracked")
  func sortTracking() async {
    let state = await TableSortState()
    await state.applySort(column: 1, cells: [["H", "V"], ["A", "1"]])
    #expect(await state.sortedColumn == 1)
    #expect(await state.sortDirection == .ascending)
    await state.applySort(column: 1, cells: [["H", "V"], ["A", "1"]])
    #expect(await state.sortDirection == .descending)
  }

  // MARK: - Edge Cases

  @Test("Sort with missing column values")
  func sortMissingValues() async {
    let state = await TableSortState()
    let cells = [
      ["Name", "Score"],
      ["Alice", "85"],
      ["Bob"],  // missing score
      ["Charlie", "78"],
    ]
    await state.applySort(column: 1, cells: cells)
    let result = await state.displayCells
    #expect(result.count == 4)
    // Bob's missing value should sort to the beginning (empty string)
    #expect(result[1][0] == "Bob")
  }

  @Test("Sort different column changes sort")
  func sortDifferentColumn() async {
    let state = await TableSortState()
    let cells = [
      ["Name", "Score"],
      ["Alice", "85"],
      ["Bob", "92"],
      ["Charlie", "78"],
    ]
    await state.applySort(column: 0, cells: cells)
    await state.applySort(column: 1, cells: cells)
    #expect(await state.sortedColumn == 1)
    let result = await state.displayCells
    #expect(result[1][0] == "Charlie") // 78
    #expect(result[2][0] == "Alice")   // 85
    #expect(result[3][0] == "Bob")     // 92
  }

  // MARK: - SortDirection

  @Test("SortDirection toggled")
  func directionToggled() {
    let up = SortDirection.ascending
    let down = up.toggled
    #expect(down == .descending)
    #expect(down.toggled == .ascending)
  }

  @Test("SortDirection symbol names")
  func directionSymbols() {
    #expect(SortDirection.ascending.symbolName == "arrow.up")
    #expect(SortDirection.descending.symbolName == "arrow.down")
  }
}
