import CoreGraphics
import Testing
@testable import PDFEditorCore

@Suite("FreezePaneInteractiveResize")
struct FreezePaneInteractiveResizeTests {
  // MARK: - FreezePaneState.resize

  @Test("State resize updates config")
  func stateResize() {
    let state = FreezePaneState()
    state.activate(config: FreezePaneConfig(pinnedRows: 1, pinnedColumns: 0))

    let newConfig = FreezePaneConfig(pinnedRows: 2, pinnedColumns: 1)
    state.resize(config: newConfig)

    #expect(state.config.pinnedRows == 2)
    #expect(state.config.pinnedColumns == 1)
    #expect(state.isVisible == true)
  }

  @Test("State resize to inactive deactivates")
  func stateResizeDeactivate() {
    let state = FreezePaneState()
    state.activate(config: FreezePaneConfig(pinnedRows: 2, pinnedColumns: 1))

    state.resize(config: .none)

    #expect(state.config == .none)
    #expect(state.isVisible == false)
  }

  // MARK: - FreezePaneConfig with drag-set values

  @Test("Config from drag: pinnedRows and pinnedColumns set correctly")
  func dragConfig() {
    let config = FreezePaneConfig(pinnedRows: 3, pinnedColumns: 2, isAutoDetected: false)
    #expect(config.pinnedRows == 3)
    #expect(config.pinnedColumns == 2)
    #expect(config.isAutoDetected == false)
    #expect(config.isActive == true)
  }

  @Test("Config from drag: zero rows + zero columns = inactive")
  func dragConfigInactive() {
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 0, isAutoDetected: false)
    #expect(config.isActive == false)
  }

  // MARK: - FreezePaneLayout with custom drag configs

  @Test("Layout with 3 pinned rows from drag")
  func layoutDragRows() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 3, pinnedColumns: 0, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    // 3 rows out of 10 → 792 * 3/10 ≈ 237
    let pinnedH = Int(layout.pinnedRect.height)
    let scrollH = Int(layout.scrollableRect.height)
    #expect(pinnedH == 237)
    // Invariant: pinned + scrollable ≈ total (within 1pt of float truncation)
    #expect(abs(pinnedH + scrollH - 792) <= 1)
    #expect(layout.isActive == true)
  }

  @Test("Layout with 3 pinned columns from drag")
  func layoutDragColumns() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 3, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    // 3 columns out of 5 → 612 * 3/5 ≈ 367
    let pinnedW = Int(layout.pinnedRect.width)
    let scrollW = Int(layout.scrollableRect.width)
    #expect(pinnedW == 367)
    #expect(abs(pinnedW + scrollW - 612) <= 1)
    #expect(layout.isActive == true)
  }

  @Test("Layout with drag-set rows + columns")
  func layoutDragBoth() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 2, pinnedColumns: 2, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    // 2 rows → 792*2/10 ≈ 158
    // 2 cols → 612*2/5 ≈ 244
    let cornerW = Int(layout.cornerRect.width)
    let cornerH = Int(layout.cornerRect.height)
    let scrollW = Int(layout.scrollableRect.width)
    let scrollH = Int(layout.scrollableRect.height)
    #expect(cornerW == 244)
    #expect(cornerH == 158)
    #expect(abs(cornerW + scrollW - 612) <= 1)
    #expect(abs(cornerH + scrollH - 792) <= 1)
  }

  // MARK: - Edge cases

  @Test("Config: all rows pinned")
  func allRowsPinned() {
    let config = FreezePaneConfig(pinnedRows: 10, pinnedColumns: 0)
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    #expect(Int(layout.pinnedRect.height) == 792)
    #expect(Int(layout.scrollableRect.height) <= 1) // may be 0 or 1 due to float truncation
  }

  @Test("Config: all columns pinned")
  func allColumnsPinned() {
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 5)
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    #expect(Int(layout.pinnedRect.width) == 612)
    #expect(Int(layout.scrollableRect.width) <= 1) // may be 0 or 1 due to float truncation
  }

  @Test("Config: custom row heights respected by drag")
  func dragCustomRowHeights() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let rowHeights: [CGFloat] = [20, 20, 20, 80, 80, 80, 80, 80, 80, 80]
    let config = FreezePaneConfig(pinnedRows: 3, pinnedColumns: 0, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      rowHeights: rowHeights,
      totalRows: 10,
      totalColumns: 5
    )
    // 3 rows with heights 20+20+20 = 60
    let pinnedH = Int(layout.pinnedRect.height)
    let scrollH = Int(layout.scrollableRect.height)
    #expect(pinnedH == 60)
    #expect(abs(pinnedH + scrollH - 792) <= 1)
  }

  @Test("Config: custom column widths respected by drag")
  func dragCustomColumnWidths() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let columnWidths: [CGFloat] = [50, 100, 100, 100, 262]
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 3, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      columnWidths: columnWidths,
      totalRows: 10,
      totalColumns: 5
    )
    // 3 columns with widths 50+100+100 = 250
    let pinnedW = Int(layout.pinnedRect.width)
    let scrollW = Int(layout.scrollableRect.width)
    #expect(pinnedW == 250)
    #expect(abs(pinnedW + scrollW - 612) <= 1)
  }

  // MARK: - Unfreeze after drag

  @Test("Unfreeze after drag clears state")
  func unfreezeAfterDrag() {
    let state = FreezePaneState()
    state.activate(config: FreezePaneConfig(pinnedRows: 3, pinnedColumns: 2))
    state.resize(config: FreezePaneConfig(pinnedRows: 0, pinnedColumns: 0))
    #expect(state.isVisible == false)
    #expect(state.config == .none)
  }

  // MARK: - Real Measurements

  @Test("Layout uses real row heights when provided")
  func realRowHeights() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    // Real row heights: header is 40pt, body rows are 25pt each
    let realHeights: [CGFloat] = [40, 25, 25, 25, 25, 25, 25, 25, 25, 25]
    let config = FreezePaneConfig(pinnedRows: 1, pinnedColumns: 0, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      rowHeights: realHeights,
      totalRows: 10,
      totalColumns: 5
    )
    // With real heights, pinned row = 40 (not 79.2 average)
    let pinnedH = Int(layout.pinnedRect.height)
    #expect(pinnedH == 40)
    let scrollH = Int(layout.scrollableRect.height)
    #expect(abs(pinnedH + scrollH - 792) <= 1)
  }

  @Test("Layout uses real column widths when provided")
  func realColumnWidths() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    // Real column widths: first column is 150pt (labels), rest are ~115pt each
    let realWidths: [CGFloat] = [150, 115, 115, 115, 117]
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 1, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      columnWidths: realWidths,
      totalRows: 10,
      totalColumns: 5
    )
    // With real widths, pinned column = 150 (not 122.4 average)
    let pinnedW = Int(layout.pinnedRect.width)
    #expect(pinnedW == 150)
    let scrollW = Int(layout.scrollableRect.width)
    #expect(abs(pinnedW + scrollW - 612) <= 1)
  }

  @Test("Layout with real measurements and both rows+columns")
  func realMeasurementsBoth() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let realHeights: [CGFloat] = [30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
    let realWidths: [CGFloat] = [100, 100, 100, 100, 212]
    let config = FreezePaneConfig(pinnedRows: 2, pinnedColumns: 2, isAutoDetected: false)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      rowHeights: realHeights,
      columnWidths: realWidths,
      totalRows: 10,
      totalColumns: 5
    )
    #expect(Int(layout.cornerRect.width) == 200)
    #expect(Int(layout.cornerRect.height) == 60)
  }

  // MARK: - Sendable

  @Test("Resize config is Sendable")
  func resizeSendable() {
    let config = FreezePaneConfig(pinnedRows: 5, pinnedColumns: 3, isAutoDetected: false)
    Task {
      let captured = config
      #expect(captured.pinnedRows == 5)
      #expect(captured.pinnedColumns == 3)
      #expect(captured.isAutoDetected == false)
    }
  }
}
