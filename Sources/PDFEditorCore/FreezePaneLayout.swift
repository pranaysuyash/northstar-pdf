import CoreGraphics
import Foundation

/// Freeze-pane layout for tables: pin header rows or first columns so they
/// stay visible while the body scrolls.
///
/// First principle: reference context (headers, labels) should be spatially
/// stable while detail scrolls. This is the same principle as reading modes —
/// layout is a viewport routing decision.
///
/// Architecture:
/// - `FreezePaneConfig` describes what to pin (rows, columns, or both)
/// - `FreezePaneLayout` splits the viewport into pinned + scrollable regions
/// - The tile renderer composites pinned tiles at fixed positions
///
/// Doctrine alignment:
/// - §3: Do things smartly — freeze what's reference, scroll what's detail
/// - §8: Capability routing — freeze-panes is a layout capability activated
///        when tables are detected
/// - Long-term: Foundation for sortable grid, column resize, cell selection

// MARK: - Freeze Pane Configuration

/// What to pin in a freeze-pane layout.
public struct FreezePaneConfig: Sendable, Equatable, Hashable {
  /// Number of header rows to pin at the top (0 = no row freeze).
  public let pinnedRows: Int
  /// Number of columns to pin at the left (0 = no column freeze).
  public let pinnedColumns: Int
  /// Whether the freeze was auto-detected (from table structure) or user-set.
  public let isAutoDetected: Bool

  public init(
    pinnedRows: Int = 0,
    pinnedColumns: Int = 0,
    isAutoDetected: Bool = false
  ) {
    self.pinnedRows = max(0, pinnedRows)
    self.pinnedColumns = max(0, pinnedColumns)
    self.isAutoDetected = isAutoDetected
  }

  /// Whether any freeze is active.
  public var isActive: Bool {
    pinnedRows > 0 || pinnedColumns > 0
  }

  /// No freeze — default state.
  public static let none = FreezePaneConfig()

  /// Auto-detect freeze from a DetectedTable's structure.
  ///
  /// Convention: if the table has more than 1 row, freeze the first row
  /// (header). If it has more than 2 columns, also freeze the first column
  /// (row labels).
  public static func autoDetect(
    rows: Int,
    columns: Int,
    confidence: Double
  ) -> FreezePaneConfig {
    guard confidence >= 0.6 else { return .none }
    let pinnedRows = rows > 1 ? 1 : 0
    let pinnedColumns = columns > 2 ? 1 : 0
    return FreezePaneConfig(
      pinnedRows: pinnedRows,
      pinnedColumns: pinnedColumns,
      isAutoDetected: true
    )
  }
}

// MARK: - Freeze Pane Layout

/// Computes pinned and scrollable viewport regions from a freeze config
/// and the current scroll position.
public struct FreezePaneLayout: Sendable {
  /// The pinned region (top rows, left columns) — rendered at fixed position.
  public let pinnedRect: CGRect
  /// The scrollable region (everything else) — translates with scroll.
  public let scrollableRect: CGRect
  /// The intersection corner where pinned rows and columns overlap.
  public let cornerRect: CGRect
  /// The full page bounds.
  public let pageBounds: CGRect

  /// Compute the freeze-pane layout for a given page and scroll state.
  ///
  /// - Parameters:
  ///   - pageBounds: The full page bounds in points (from mediaBox).
  ///   - config: The freeze configuration (rows/columns to pin).
  ///   - rowHeights: Height of each row in points. If nil, rows are
  ///     evenly divided.
  ///   - columnWidths: Width of each column in points. If nil, columns
  ///     are evenly divided.
  ///   - totalRows: Total number of rows in the table.
  ///   - totalColumns: Total number of columns in the table.
  public init(
    pageBounds: CGRect,
    config: FreezePaneConfig,
    rowHeights: [CGFloat]? = nil,
    columnWidths: [CGFloat]? = nil,
    totalRows: Int,
    totalColumns: Int
  ) {
    self.pageBounds = pageBounds

    // Compute pinned row height
    let pinnedRowHeight: CGFloat
    if config.pinnedRows > 0, totalRows > 0 {
      if let heights = rowHeights, heights.count >= config.pinnedRows {
        pinnedRowHeight = heights.prefix(config.pinnedRows).reduce(0, +)
      } else {
        let avgHeight = pageBounds.height / CGFloat(totalRows)
        pinnedRowHeight = avgHeight * CGFloat(config.pinnedRows)
      }
    } else {
      pinnedRowHeight = 0
    }

    // Compute pinned column width
    let pinnedColumnWidth: CGFloat
    if config.pinnedColumns > 0, totalColumns > 0 {
      if let widths = columnWidths, widths.count >= config.pinnedColumns {
        pinnedColumnWidth = widths.prefix(config.pinnedColumns).reduce(0, +)
      } else {
        let avgWidth = pageBounds.width / CGFloat(totalColumns)
        pinnedColumnWidth = avgWidth * CGFloat(config.pinnedColumns)
      }
    } else {
      pinnedColumnWidth = 0
    }

    // Pinned region: top-left corner (rows × columns)
    self.pinnedRect = CGRect(
      x: pageBounds.origin.x,
      y: pageBounds.origin.y,
      width: pinnedColumnWidth > 0 ? pinnedColumnWidth : pageBounds.width,
      height: pinnedRowHeight > 0 ? pinnedRowHeight : pageBounds.height
    )

    // Corner rect: where pinned rows and columns overlap
    self.cornerRect = CGRect(
      x: pageBounds.origin.x,
      y: pageBounds.origin.y,
      width: pinnedColumnWidth,
      height: pinnedRowHeight
    )

    // Scrollable region: everything below pinned rows and right of pinned columns.
    // When nothing is pinned, the entire page scrolls.
    if config.pinnedRows == 0 && config.pinnedColumns == 0 {
      self.scrollableRect = pageBounds
    } else {
      let scrollableX = pageBounds.origin.x + pinnedColumnWidth
      let scrollableY = pageBounds.origin.y + pinnedRowHeight
      let scrollableWidth = pageBounds.width - pinnedColumnWidth
      let scrollableHeight = pageBounds.height - pinnedRowHeight

      self.scrollableRect = CGRect(
        x: scrollableX,
        y: scrollableY,
        width: max(0, scrollableWidth),
        height: max(0, scrollableHeight)
      )
    }
  }

  /// Whether any freeze is active.
  public var isActive: Bool {
    pinnedRect.width < pageBounds.width || pinnedRect.height < pageBounds.height
  }
}

// MARK: - Freeze Pane State

/// Mutable state for the freeze-pane interaction.
public final class FreezePaneState: @unchecked Sendable, ObservableObject {
  /// Current freeze configuration.
  @Published public var config: FreezePaneConfig = .none
  /// Whether the freeze pane is visible.
  @Published public var isVisible: Bool = false
  /// Scroll offset within the scrollable region.
  @Published public var scrollOffset: CGPoint = .zero

  private let lock = NSLock()

  public init() {}

  /// Toggle freeze on/off.
  public func toggle() {
    lock.lock()
    defer { lock.unlock() }
    isVisible.toggle()
    if !isVisible {
      config = .none
      scrollOffset = .zero
    }
  }

  /// Set a new freeze configuration and activate.
  public func activate(config: FreezePaneConfig) {
    lock.lock()
    defer { lock.unlock() }
    self.config = config
    self.isVisible = true
  }

  /// Deactivate freeze.
  public func deactivate() {
    lock.lock()
    defer { lock.unlock() }
    config = .none
    isVisible = false
    scrollOffset = .zero
  }

  /// Resize freeze to a new configuration (from interactive drag).
  public func resize(config: FreezePaneConfig) {
    lock.lock()
    defer { lock.unlock() }
    self.config = config
    // Keep isVisible true if the new config is active; deactivate if not.
    if config.isActive {
      isVisible = true
    } else {
      isVisible = false
      scrollOffset = .zero
    }
  }
}
