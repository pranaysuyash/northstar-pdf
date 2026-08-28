import Testing
import CoreGraphics
@testable import PDFEditorCore

@Suite("FreezePaneLayout")
struct FreezePaneLayoutTests {
  // MARK: - FreezePaneConfig

  @Test("Default config is none")
  func defaultConfig() {
    let config = FreezePaneConfig.none
    #expect(config.pinnedRows == 0)
    #expect(config.pinnedColumns == 0)
    #expect(config.isAutoDetected == false)
  }

  @Test("Manual config with rows and columns")
  func manualConfig() {
    let config = FreezePaneConfig(pinnedRows: 2, pinnedColumns: 1)
    #expect(config.pinnedRows == 2)
    #expect(config.pinnedColumns == 1)
    #expect(config.isAutoDetected == false)
  }

  @Test("Negative values clamped to 0")
  func negativeClamped() {
    let config = FreezePaneConfig(pinnedRows: -1, pinnedColumns: -5)
    #expect(config.pinnedRows == 0)
    #expect(config.pinnedColumns == 0)
  }

  @Test("Auto-detect: 5 rows, 4 columns → freeze header row + first column")
  func autoDetectStandard() {
    let config = FreezePaneConfig.autoDetect(rows: 5, columns: 4, confidence: 0.9)
    #expect(config.pinnedRows == 1)
    #expect(config.pinnedColumns == 1)
    #expect(config.isAutoDetected == true)
  }

  @Test("Auto-detect: 1 row → no row freeze")
  func autoDetectSingleRow() {
    let config = FreezePaneConfig.autoDetect(rows: 1, columns: 4, confidence: 0.9)
    #expect(config.pinnedRows == 0)
    #expect(config.pinnedColumns == 1)
  }

  @Test("Auto-detect: 2 columns → no column freeze")
  func autoDetectFewColumns() {
    let config = FreezePaneConfig.autoDetect(rows: 5, columns: 2, confidence: 0.9)
    #expect(config.pinnedRows == 1)
    #expect(config.pinnedColumns == 0)
  }

  @Test("Auto-detect: low confidence → none")
  func autoDetectLowConfidence() {
    let config = FreezePaneConfig.autoDetect(rows: 5, columns: 4, confidence: 0.3)
    #expect(config == .none)
  }

  // MARK: - FreezePaneLayout

  @Test("Layout with no freeze covers full page")
  func layoutNoFreeze() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: .none,
      totalRows: 10,
      totalColumns: 5
    )
    #expect(layout.pinnedRect.width == pageBounds.width)
    #expect(layout.pinnedRect.height == pageBounds.height)
    // When no freeze, scrollableRect is the full page (everything scrolls)
    #expect(layout.scrollableRect.width == pageBounds.width)
    #expect(layout.scrollableRect.height == pageBounds.height)
    #expect(layout.isActive == false)
  }

  @Test("Layout with 1 pinned row")
  func layoutPinnedRow() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 1, pinnedColumns: 0)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    let pinnedH = Int(layout.pinnedRect.height)
    let scrollH = Int(layout.scrollableRect.height)
    #expect(pinnedH == 79)
    #expect(scrollH == 712)
    #expect(layout.pinnedRect.width == pageBounds.width)
    #expect(layout.isActive == true)
  }

  @Test("Layout with 1 pinned column")
  func layoutPinnedColumn() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 1)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    let pinnedW = Int(layout.pinnedRect.width)
    let scrollW = Int(layout.scrollableRect.width)
    #expect(pinnedW == 122)
    #expect(scrollW == 489)
    #expect(layout.pinnedRect.height == pageBounds.height)
    #expect(layout.isActive == true)
  }

  @Test("Layout with pinned rows AND columns")
  func layoutPinnedBoth() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 1, pinnedColumns: 1)
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      totalRows: 10,
      totalColumns: 5
    )
    #expect(Int(layout.cornerRect.width) == 122)
    #expect(Int(layout.cornerRect.height) == 79)
    #expect(Int(layout.scrollableRect.width) == 489)
    #expect(Int(layout.scrollableRect.height) == 712)
    #expect(layout.isActive == true)
  }

  @Test("Layout with custom row heights")
  func layoutCustomRowHeights() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 2, pinnedColumns: 0)
    let rowHeights: [CGFloat] = [40, 30, 50, 50, 50]
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      rowHeights: rowHeights,
      totalRows: 5,
      totalColumns: 3
    )
    #expect(Int(layout.pinnedRect.height) == 70) // 40 + 30
    #expect(Int(layout.scrollableRect.height) == 722) // 792 - 70
  }

  @Test("Layout with custom column widths")
  func layoutCustomColumnWidths() {
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    let config = FreezePaneConfig(pinnedRows: 0, pinnedColumns: 2)
    let columnWidths: [CGFloat] = [100, 150, 200, 162]
    let layout = FreezePaneLayout(
      pageBounds: pageBounds,
      config: config,
      columnWidths: columnWidths,
      totalRows: 5,
      totalColumns: 4
    )
    #expect(Int(layout.pinnedRect.width) == 250) // 100 + 150
    #expect(Int(layout.scrollableRect.width) == 362) // 612 - 250
  }

  // MARK: - FreezePaneState

  @Test("State starts inactive")
  func stateDefault() {
    let state = FreezePaneState()
    #expect(state.config == .none)
    #expect(state.isVisible == false)
  }

  @Test("State toggle activates and deactivates")
  func stateToggle() {
    let state = FreezePaneState()
    state.toggle()
    #expect(state.isVisible == true)
    state.toggle()
    #expect(state.isVisible == false)
    #expect(state.config == .none)
  }

  @Test("State activate sets config and visibility")
  func stateActivate() {
    let state = FreezePaneState()
    let config = FreezePaneConfig(pinnedRows: 1, pinnedColumns: 1)
    state.activate(config: config)
    #expect(state.isVisible == true)
    #expect(state.config.pinnedRows == 1)
    #expect(state.config.pinnedColumns == 1)
  }

  @Test("State deactivate clears everything")
  func stateDeactivate() {
    let state = FreezePaneState()
    state.activate(config: FreezePaneConfig(pinnedRows: 2, pinnedColumns: 1))
    state.deactivate()
    #expect(state.isVisible == false)
    #expect(state.config == .none)
  }

  // MARK: - Sendable

  @Test("FreezePaneConfig is Sendable + Equatable")
  func configSendable() {
    let a = FreezePaneConfig(pinnedRows: 1, pinnedColumns: 1)
    let b = FreezePaneConfig(pinnedRows: 1, pinnedColumns: 1)
    #expect(a == b)
    Task {
      let captured = a
      #expect(captured.pinnedRows == 1)
    }
  }
}
