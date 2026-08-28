import AppKit
import CoreGraphics
import PDFEditorCore
import PDFKit
import SwiftUI

/// Excel-style freeze pane overlay: renders pinned header rows and/or
/// left columns at fixed positions on top of the PDFView.
///
/// Architecture:
/// - Sits as a subview of the PDFView's scroll content view
/// - Renders pinned tiles from the tile renderer at fixed positions
/// - Clips to the pinned region (top strip for rows, left strip for columns)
/// - Shows a corner widget where pinned rows × columns intersect
/// - Updates on page change, scroll, and zoom
///
/// First principle: reference context (headers, labels) should be spatially
/// stable while detail scrolls. The overlay composites the same page region
/// at the same scale while the PDFView translates underneath.
///
/// Doctrine alignment:
/// - §3: Do things smartly — only render the pinned region, not the whole page
/// - §8: Capability routing — freeze-panes is activated when tables are detected

// MARK: - Freeze Pane Overlay View

/// NSView that renders frozen header rows and columns over the PDFView.
@MainActor
public final class FreezePaneOverlayView: NSView {
  // MARK: - Configuration

  /// Current freeze configuration.
  public var config: FreezePaneConfig = .none {
    didSet { needsDisplay = true }
  }

  /// The PDF document to render tiles from.
  public weak var pdfDocument: PDFDocument?

  /// Current page index (for rendering the correct page's tiles).
  public var currentPageIndex: Int = 0 {
    didSet { if currentPageIndex != oldValue { needsDisplay = true } }
  }

  /// Current zoom scale of the PDFView.
  public var zoomScale: CGFloat = 1.0 {
    didSet { if zoomScale != oldValue { needsDisplay = true } }
  }

  /// Real row heights from table extraction (in PDF points). Falls back to averaging if nil.
  public var rowHeights: [CGFloat]?
  /// Real column widths from table extraction (in PDF points). Falls back to averaging if nil.
  public var columnWidths: [CGFloat]?
  /// Total rows in the detected table (for averaging fallback).
  public var totalTableRows: Int = 10
  /// Total columns in the detected table (for averaging fallback).
  public var totalTableColumns: Int = 5
  /// Sort state — tracks which column header is sorted.
  public weak var sortState: TableSortState?
  /// Callback when a header cell is clicked.
  public var onHeaderClick: ((Int) -> Void)?

  /// Tile cache for per-cell compositing.
  private var tileCache: [String: CGImage] = [:]
  /// Cache key for the current page+zoom combination.
  private var currentCacheKey: String = ""

  /// Page cache for getting page bounds.
  private var pageBounds: CGRect = .zero

  // MARK: - Init

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.masksToBounds = true
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    wantsLayer = true
    layer?.masksToBounds = true
  }

  // MARK: - Drawing

  public override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    guard config.isActive,
          let document = pdfDocument,
          currentPageIndex >= 0,
          currentPageIndex < document.pageCount,
          let page = document.page(at: currentPageIndex)
    else {
      return
    }

    let mediaBox = page.bounds(for: .mediaBox)
    pageBounds = mediaBox

    // Compute tile DPI from zoom scale
    let dpi = Int(72.0 * zoomScale)
    let scale = CGFloat(dpi) / 72.0

    // Draw pinned rows (top strip)
    if config.pinnedRows > 0 {
      drawPinnedRows(
        page: page, mediaBox: mediaBox, scale: scale, dpi: dpi,
        in: dirtyRect
      )
    }

    // Draw pinned columns (left strip)
    if config.pinnedColumns > 0 {
      drawPinnedColumns(
        page: page, mediaBox: mediaBox, scale: scale, dpi: dpi,
        in: dirtyRect
      )
    }

    // Draw corner widget (where rows × columns overlap)
    if config.pinnedRows > 0 && config.pinnedColumns > 0 {
      drawCornerWidget(
        page: page, mediaBox: mediaBox, scale: scale, dpi: dpi,
        in: dirtyRect
      )
    }

    // Draw sort indicators on frozen header columns
    if config.pinnedRows > 0, let sort = sortState, sort.isSorted {
      drawSortIndicators(
        page: page, mediaBox: mediaBox, scale: scale, dpi: dpi,
        in: dirtyRect
      )
    }
  }

  // MARK: - Mouse Events (Header Click Detection)

  public override func mouseDown(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)

    // Only handle clicks in the pinned row region (top strip)
    guard config.pinnedRows > 0 else {
      super.mouseDown(with: event)
      return
    }

    let pinnedHeight = computePinnedRowHeight()
    let pinnedHeightPixels = pinnedHeight * zoomScale

    // Check if click is in the header row area (top of view)
    let headerBottom = bounds.height - pinnedHeightPixels
    guard location.y >= headerBottom else {
      super.mouseDown(with: event)
      return
    }

    // Determine which column was clicked
    let clickedColumn = columnAtIndex(location.x)
    if clickedColumn >= 0 {
      onHeaderClick?(clickedColumn)
    } else {
      super.mouseDown(with: event)
    }
  }

  /// Compute which column index a view-space X coordinate falls in.
  private func columnAtIndex(_ viewX: CGFloat) -> Int {
    // Compute column boundaries in view coordinates
    let totalWidth = bounds.width
    let avgColWidth = totalWidth / max(1, CGFloat(totalTableColumns))

    if let widths = columnWidths, !widths.isEmpty {
      var cumulative: CGFloat = 0
      for (idx, width) in widths.enumerated() {
        let viewWidth = width * zoomScale
        if viewX < cumulative + viewWidth {
          return idx
        }
        cumulative += viewWidth
      }
      return widths.count // past last column
    } else {
      let col = Int(viewX / avgColWidth)
      return min(col, totalTableColumns - 1)
    }
  }

  // MARK: - Sort Indicators

  private func drawSortIndicators(
    page: PDFPage, mediaBox: CGRect, scale: CGFloat, dpi: Int,
    in dirtyRect: NSRect
  ) {
    guard let sort = sortState, let sortedCol = sort.sortedColumn else { return }

    // Compute column X position in view coordinates
    let columnX: CGFloat
    if let widths = columnWidths, sortedCol < widths.count {
      let prefixWidths = widths.prefix(sortedCol)
      let offset = prefixWidths.reduce(0, +)
      columnX = offset * zoomScale
    } else {
      let avgColWidth = bounds.width / max(1, CGFloat(totalTableColumns))
      columnX = CGFloat(sortedCol) * avgColWidth
    }

    let pinnedHeight = computePinnedRowHeight()
    let pinnedHeightPixels = pinnedHeight * zoomScale

    // Draw sort arrow in the right side of the header cell
    let arrowSize: CGFloat = 10
    let arrowX = columnX + (bounds.width / CGFloat(totalTableColumns) * zoomScale) - arrowSize - 4
    let arrowY = bounds.height - pinnedHeightPixels / 2 - arrowSize / 2

    let arrowRect = NSRect(x: arrowX, y: arrowY, width: arrowSize, height: arrowSize)

    NSColor.controlAccentColor.withAlphaComponent(0.8).setFill()
    let path = NSBezierPath(ovalIn: arrowRect)
    path.fill()

    // Draw arrow symbol
    let symbolName = sort.sortDirection == .ascending ? "arrow.up" : "arrow.down"
    if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
      let config = NSImage.SymbolConfiguration(pointSize: 7, weight: .bold)
      let configuredImage = image.withSymbolConfiguration(config)
      configuredImage?.draw(in: arrowRect.insetBy(dx: 1.5, dy: 1.5))
    }
  }

  /// Compute pinned row height from measurements.
  private func computePinnedRowHeight() -> CGFloat {
    if let heights = rowHeights, heights.count >= config.pinnedRows {
      return CGFloat(heights.prefix(config.pinnedRows).reduce(0, +))
    } else {
      let mediaBoxHeight = pageBounds.height > 0 ? pageBounds.height : 792
      let avgRowHeight = mediaBoxHeight / max(1, CGFloat(totalTableRows))
      return avgRowHeight * CGFloat(config.pinnedRows)
    }
  }

  // MARK: - Pinned Rows (top strip)

  private func drawPinnedRows(
    page: PDFPage, mediaBox: CGRect, scale: CGFloat, dpi: Int,
    in dirtyRect: NSRect
  ) {
    let pinnedHeight: CGFloat
    if let heights = rowHeights, heights.count >= config.pinnedRows {
      pinnedHeight = CGFloat(heights.prefix(config.pinnedRows).reduce(0, +))
    } else {
      let avgRowHeight = mediaBox.height / max(1, CGFloat(totalTableRows))
      pinnedHeight = avgRowHeight * CGFloat(config.pinnedRows)
    }
    let pinnedHeightPixels = Int(pinnedHeight * scale)

    // Invalidate cache if page or zoom changed
    let cacheKey = "rows-\(currentPageIndex)-\(dpi)-\(pinnedHeightPixels)"
    if cacheKey != currentCacheKey {
      tileCache.removeAll()
      currentCacheKey = cacheKey
    }

    // Compute column boundaries for per-cell tiling
    let columnBounds = computeColumnBounds(mediaBox: mediaBox)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let cgContext = NSGraphicsContext.current!.cgContext

    // Render each column cell as a separate cached tile
    for (colIdx, colBounds) in columnBounds.enumerated() {
      let tileKey = "row-\(currentPageIndex)-\(colIdx)-\(dpi)"

      let image: CGImage
      if let cached = tileCache[tileKey] {
        image = cached
      } else {
        guard let rendered = renderRowTile(
          page: page, mediaBox: mediaBox,
          colBounds: colBounds, pinnedHeight: pinnedHeight,
          scale: scale, dpi: dpi
        ) else { continue }
        image = rendered
        tileCache[tileKey] = rendered
      }

      // Draw the tile at the correct view position
      let viewX = colBounds.origin.x * scale
      let tileWidth = colBounds.width * scale
      let tileHeight = CGFloat(pinnedHeightPixels)

      let drawRect = NSRect(
        x: viewX,
        y: bounds.height - tileHeight,
        width: tileWidth,
        height: tileHeight
      )
      cgContext.draw(image, in: drawRect)
    }

    // Separator line below pinned rows
    let separatorY = bounds.height - CGFloat(pinnedHeightPixels)
    NSColor.separatorColor.setStroke()
    let separatorPath = NSBezierPath()
    separatorPath.move(to: NSPoint(x: 0, y: separatorY))
    separatorPath.line(to: NSPoint(x: bounds.width, y: separatorY))
    separatorPath.lineWidth = 1.0
    separatorPath.stroke()
  }

  /// Render a single column tile for the pinned row strip.
  private func renderRowTile(
    page: PDFPage, mediaBox: CGRect,
    colBounds: CGRect, pinnedHeight: CGFloat,
    scale: CGFloat, dpi: Int
  ) -> CGImage? {
    let pixelWidth = max(1, Int(colBounds.width * scale))
    let pixelHeight = max(1, Int(pinnedHeight * scale))

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
      data: nil,
      width: pixelWidth,
      height: pixelHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    context.scaleBy(x: scale, y: scale)
    // Clip to the column's pinned-row region
    let clipRect = CGRect(
      x: colBounds.origin.x,
      y: mediaBox.origin.y + mediaBox.height - pinnedHeight,
      width: colBounds.width,
      height: pinnedHeight
    )
    context.clip(to: clipRect)
    page.draw(with: .mediaBox, to: context)

    return context.makeImage()
  }

  /// Compute column boundary rectangles from column widths.
  private func computeColumnBounds(mediaBox: CGRect) -> [CGRect] {
    if let widths = columnWidths, !widths.isEmpty {
      var bounds: [CGRect] = []
      var x: CGFloat = mediaBox.origin.x
      for width in widths {
        bounds.append(CGRect(x: x, y: mediaBox.origin.y, width: width, height: mediaBox.height))
        x += width
      }
      // Extend last column to page edge if needed
      if let last = bounds.last, x < mediaBox.maxX {
        bounds[bounds.count - 1] = CGRect(
          x: last.origin.x, y: last.origin.y,
          width: last.width + (mediaBox.maxX - x),
          height: last.height
        )
      }
      return bounds
    } else {
      // Fallback: evenly spaced columns
      let avgWidth = mediaBox.width / max(1, CGFloat(totalTableColumns))
      return (0..<totalTableColumns).map { idx in
        CGRect(
          x: mediaBox.origin.x + CGFloat(idx) * avgWidth,
          y: mediaBox.origin.y,
          width: avgWidth,
          height: mediaBox.height
        )
      }
    }
  }

  // MARK: - Pinned Columns (left strip)

  private func drawPinnedColumns(
    page: PDFPage, mediaBox: CGRect, scale: CGFloat, dpi: Int,
    in dirtyRect: NSRect
  ) {
    let pinnedWidth: CGFloat
    if let widths = columnWidths, widths.count >= config.pinnedColumns {
      pinnedWidth = CGFloat(widths.prefix(config.pinnedColumns).reduce(0, +))
    } else {
      let avgColWidth = mediaBox.width / max(1, CGFloat(totalTableColumns))
      pinnedWidth = avgColWidth * CGFloat(config.pinnedColumns)
    }
    let pinnedWidthPixels = Int(pinnedWidth * scale)

    // Compute row boundaries for per-row tiling
    let rowBounds = computeRowBounds(mediaBox: mediaBox)
    let cgContext = NSGraphicsContext.current!.cgContext

    // Render each pinned row as a separate cached tile
    for (rowIdx, rowHeight) in rowBounds.enumerated() {
      guard rowIdx < config.pinnedRows else { break }

      let tileKey = "col-\(currentPageIndex)-\(rowIdx)-\(dpi)"

      let image: CGImage
      if let cached = tileCache[tileKey] {
        image = cached
      } else {
        guard let rendered = renderColumnTile(
          page: page, mediaBox: mediaBox,
          rowBounds: rowHeight, pinnedWidth: pinnedWidth,
          scale: scale, dpi: dpi
        ) else { continue }
        image = rendered
        tileCache[tileKey] = rendered
      }

      // Draw the tile at the correct view position
      let rowY = rowBounds.prefix(rowIdx).reduce(0, +)
      let tileHeight = rowHeight * scale
      let tileWidth = CGFloat(pinnedWidthPixels)

      let drawRect = NSRect(
        x: 0,
        y: bounds.height - (rowY * scale) - tileHeight,
        width: tileWidth,
        height: tileHeight
      )
      cgContext.draw(image, in: drawRect)
    }

    // Separator line to the right of pinned columns
    let separatorX = CGFloat(pinnedWidthPixels)
    NSColor.separatorColor.setStroke()
    let separatorPath = NSBezierPath()
    separatorPath.move(to: NSPoint(x: separatorX, y: 0))
    separatorPath.line(to: NSPoint(x: separatorX, y: bounds.height))
    separatorPath.lineWidth = 1.0
    separatorPath.stroke()
  }

  /// Render a single row tile for the pinned column strip.
  private func renderColumnTile(
    page: PDFPage, mediaBox: CGRect,
    rowBounds: CGFloat, pinnedWidth: CGFloat,
    scale: CGFloat, dpi: Int
  ) -> CGImage? {
    let pixelWidth = max(1, Int(pinnedWidth * scale))
    let pixelHeight = max(1, Int(rowBounds * scale))

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
      data: nil,
      width: pixelWidth,
      height: pixelHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    context.scaleBy(x: scale, y: scale)
    let clipRect = CGRect(
      x: mediaBox.origin.x,
      y: mediaBox.origin.y,
      width: pinnedWidth,
      height: rowBounds
    )
    context.clip(to: clipRect)
    page.draw(with: .mediaBox, to: context)

    return context.makeImage()
  }

  /// Compute row heights for per-row tiling in the column strip.
  private func computeRowBounds(mediaBox: CGRect) -> [CGFloat] {
    if let heights = rowHeights, !heights.isEmpty {
      return heights.map { CGFloat($0) }
    } else {
      let avgHeight = mediaBox.height / max(1, CGFloat(totalTableRows))
      return (0..<totalTableRows).map { _ in avgHeight }
    }
  }

  // MARK: - Corner Widget

  private func drawCornerWidget(
    page: PDFPage, mediaBox: CGRect, scale: CGFloat, dpi: Int,
    in dirtyRect: NSRect
  ) {
    // The corner is where pinned rows × columns overlap — top-left
    // Render per-cell tiles: row × column intersections
    let columnBounds = computeColumnBounds(mediaBox: mediaBox)
    let rowBounds = computeRowBounds(mediaBox: mediaBox)
    let cgContext = NSGraphicsContext.current!.cgContext

    var yOffset: CGFloat = 0
    for rowIdx in 0..<min(config.pinnedRows, rowBounds.count) {
      let rh = rowBounds[rowIdx]
      var xOffset: CGFloat = 0
      for colIdx in 0..<min(config.pinnedColumns, columnBounds.count) {
        let cw = columnBounds[colIdx].width

        let tileKey = "corner-\(currentPageIndex)-\(rowIdx)-\(colIdx)-\(dpi)"

        let image: CGImage
        if let cached = tileCache[tileKey] {
          image = cached
        } else {
          guard let rendered = renderCornerTile(
            page: page, mediaBox: mediaBox,
            colBounds: columnBounds[colIdx], rowHeight: rh,
            scale: scale, dpi: dpi
          ) else { continue }
          image = rendered
          tileCache[tileKey] = rendered
        }

        let drawRect = NSRect(
          x: xOffset * scale,
          y: bounds.height - (yOffset + rh) * scale,
          width: cw * scale,
          height: rh * scale
        )
        cgContext.draw(image, in: drawRect)
        xOffset += cw
      }
      yOffset += rh
    }

    // Corner border
    let cornerW = columnBounds.prefix(config.pinnedColumns).reduce(0) { $0 + $1.width } * scale
    let cornerH = rowBounds.prefix(config.pinnedRows).reduce(0, +) * scale
    NSColor.separatorColor.setStroke()
    let cornerRect = NSRect(x: 0, y: bounds.height - cornerH, width: cornerW, height: cornerH)
    NSBezierPath(rect: cornerRect).stroke()
  }

  /// Render a single cell tile for the corner widget.
  private func renderCornerTile(
    page: PDFPage, mediaBox: CGRect,
    colBounds: CGRect, rowHeight: CGFloat,
    scale: CGFloat, dpi: Int
  ) -> CGImage? {
    let pixelWidth = max(1, Int(colBounds.width * scale))
    let pixelHeight = max(1, Int(rowHeight * scale))

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
      data: nil,
      width: pixelWidth,
      height: pixelHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    context.scaleBy(x: scale, y: scale)
    // Clip to the intersection of column and row bounds
    let clipRect = CGRect(
      x: colBounds.origin.x,
      y: mediaBox.origin.y + mediaBox.height - rowHeight,
      width: colBounds.width,
      height: rowHeight
    )
    context.clip(to: clipRect)
    page.draw(with: .mediaBox, to: context)

    return context.makeImage()
  }

  // MARK: - Sizing

  /// Update the overlay size to match the PDFView.
  public func updateFrame(for pdfViewFrame: CGRect) {
    frame = NSRect(origin: .zero, size: pdfViewFrame.size)
  }
}

// MARK: - Freeze Pane Composite View

/// SwiftUI wrapper that composites the NSView overlay with interactive drag handles.
/// This is the main entry point for integrating freeze panes into the document canvas.
public struct FreezePaneCompositeView: View {
  @ObservedObject var state: FreezePaneState
  @ObservedObject var resizeCoordinator: FreezePaneResizeCoordinator
  let pdfDocument: PDFDocument?
  let currentPageIndex: Int
  let zoomScale: CGFloat
  let tableRowCount: Int
  let tableColumnCount: Int
  let pageBounds: CGRect
  let realRowHeights: [CGFloat]?
  let realColumnWidths: [CGFloat]?

  @State private var overlayView: FreezePaneOverlayView?
  @State private var rowSeparatorY: CGFloat?
  @State private var columnSeparatorX: CGFloat?
  @State private var isDragging: Bool = false

  public init(
    state: FreezePaneState,
    resizeCoordinator: FreezePaneResizeCoordinator,
    pdfDocument: PDFDocument?,
    currentPageIndex: Int,
    zoomScale: CGFloat,
    tableRowCount: Int,
    tableColumnCount: Int,
    pageBounds: CGRect,
    realRowHeights: [CGFloat]? = nil,
    realColumnWidths: [CGFloat]? = nil
  ) {
    self.state = state
    self.resizeCoordinator = resizeCoordinator
    self.pdfDocument = pdfDocument
    self.currentPageIndex = currentPageIndex
    self.zoomScale = zoomScale
    self.tableRowCount = tableRowCount
    self.tableColumnCount = tableColumnCount
    self.pageBounds = pageBounds
    self.realRowHeights = realRowHeights
    self.realColumnWidths = realColumnWidths
  }

  public var body: some View {
    GeometryReader { geo in
      ZStack {
        // The NSView overlay (renders the frozen region)
        FreezePaneOverlayRepresentable(
          state: state,
          pdfDocument: pdfDocument,
          currentPageIndex: currentPageIndex,
          zoomScale: zoomScale,
          viewSize: geo.size,
          rowHeights: realRowHeights,
          columnWidths: realColumnWidths,
          totalTableRows: tableRowCount,
          totalTableColumns: tableColumnCount
        )
        .allowsHitTesting(false) // Let drag handles receive events

        // Interactive drag handles (on top of the overlay)
        if state.isVisible, state.config.isActive {
          FreezePaneDragHandleView(
            rowSeparatorY: $rowSeparatorY,
            columnSeparatorX: $columnSeparatorX,
            isDragging: $isDragging,
            viewHeight: geo.size.height,
            viewWidth: geo.size.width,
            coordinator: resizeCoordinator
          )
          .onAppear {
            updateSeparatorPositions(viewHeight: geo.size.height, viewWidth: geo.size.width)
          }
          .onChange(of: state.config) { _, newConfig in
            updateSeparatorPositions(viewHeight: geo.size.height, viewWidth: geo.size.width)
          }
          .onChange(of: zoomScale) { _, _ in
            updateSeparatorPositions(viewHeight: geo.size.height, viewWidth: geo.size.width)
          }
        }
      }
    }
    .clipped()
  }

  /// Compute initial separator positions from the current config.
  private func updateSeparatorPositions(viewHeight: CGFloat, viewWidth: CGFloat) {
    resizeCoordinator.totalRows = tableRowCount
    resizeCoordinator.totalColumns = tableColumnCount
    resizeCoordinator.pageBounds = pageBounds
    resizeCoordinator.zoomScale = zoomScale
    resizeCoordinator.estimatedRowHeights = realRowHeights ?? []
    resizeCoordinator.estimatedColumnWidths = realColumnWidths ?? []
    resizeCoordinator.onConfigChange = { newConfig in
      state.resize(config: newConfig)
    }

    if state.config.pinnedRows > 0 {
      rowSeparatorY = resizeCoordinator.yForPinnedRows(
        state.config.pinnedRows, viewHeight: viewHeight
      )
    } else {
      rowSeparatorY = nil
    }

    if state.config.pinnedColumns > 0 {
      columnSeparatorX = resizeCoordinator.xForPinnedColumns(
        state.config.pinnedColumns
      )
    } else {
      columnSeparatorX = nil
    }
  }
}

// MARK: - NSView Representable Wrapper

/// Bridges the NSView-based overlay into SwiftUI.
@MainActor
private struct FreezePaneOverlayRepresentable: NSViewRepresentable {
  let state: FreezePaneState
  let pdfDocument: PDFDocument?
  let currentPageIndex: Int
  let zoomScale: CGFloat
  let viewSize: CGSize
  let rowHeights: [CGFloat]?
  let columnWidths: [CGFloat]?
  let totalTableRows: Int
  let totalTableColumns: Int

  func makeNSView(context: Context) -> FreezePaneOverlayView {
    let overlay = FreezePaneOverlayView(frame: NSRect(origin: .zero, size: viewSize))
    overlay.pdfDocument = pdfDocument
    overlay.currentPageIndex = currentPageIndex
    overlay.zoomScale = zoomScale
    overlay.config = state.config
    overlay.rowHeights = rowHeights
    overlay.columnWidths = columnWidths
    overlay.totalTableRows = totalTableRows
    overlay.totalTableColumns = totalTableColumns
    return overlay
  }

  func updateNSView(_ nsView: FreezePaneOverlayView, context: Context) {
    nsView.pdfDocument = pdfDocument
    nsView.currentPageIndex = currentPageIndex
    nsView.zoomScale = zoomScale
    nsView.config = state.config
    nsView.rowHeights = rowHeights
    nsView.columnWidths = columnWidths
    nsView.totalTableRows = totalTableRows
    nsView.totalTableColumns = totalTableColumns
    nsView.updateFrame(for: CGRect(origin: .zero, size: viewSize))
  }
}

// MARK: - Freeze Pane Toggle Button

/// Toolbar button for toggling freeze panes with presets and auto-detect.
public struct FreezePaneToggleButton: View {
  @Binding var isFrozen: Bool
  let onAutoDetect: () -> Void
  let onApplyPreset: (FreezePanePreset) -> Void
  let onToggle: () -> Void
  let matchedPresets: [(preset: FreezePanePreset, score: Double)]

  public init(
    isFrozen: Binding<Bool>,
    onAutoDetect: @escaping () -> Void,
    onApplyPreset: @escaping (FreezePanePreset) -> Void,
    onToggle: @escaping () -> Void,
    matchedPresets: [(preset: FreezePanePreset, score: Double)] = []
  ) {
    self._isFrozen = isFrozen
    self.onAutoDetect = onAutoDetect
    self.onApplyPreset = onApplyPreset
    self.onToggle = onToggle
    self.matchedPresets = matchedPresets
  }

  public var body: some View {
    Menu {
      Button {
        onAutoDetect()
      } label: {
        Label("Auto-detect from table", systemImage: "wand.and.stars")
      }

      Divider()

      // Preset suggestions (if any match)
      if !matchedPresets.isEmpty {
        Section("Suggested Presets") {
          ForEach(matchedPresets, id: \.preset.id) { match in
            Button {
              onApplyPreset(match.preset)
            } label: {
              Label {
                Text(match.preset.name)
              } icon: {
                Image(systemName: match.preset.icon)
              }
            }
            .help(match.preset.description)
          }
        }

        Divider()
      }

      // All built-in presets
      Section("All Presets") {
        ForEach(FreezePanePreset.allPresets) { preset in
          Button {
            onApplyPreset(preset)
          } label: {
            Label {
              Text(preset.name)
            } icon: {
              Image(systemName: preset.icon)
            }
          }
          .help(preset.description)
        }
      }

      Divider()

      Button {
        isFrozen = true
        onToggle()
      } label: {
        Label("Freeze header row", systemImage: "pin")
      }

      Button {
        isFrozen = false
        onToggle()
      } label: {
        Label("Unfreeze", systemImage: "pin.slash")
      }
    } label: {
      Image(systemName: isFrozen ? "pin.fill" : "pin")
        .font(.caption)
    }
    .menuStyle(.borderlessButton)
    .help(isFrozen ? "Freeze panes active — click to manage" : "Freeze header rows/columns")
  }
}
