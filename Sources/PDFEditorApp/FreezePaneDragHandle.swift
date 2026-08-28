import AppKit
import CoreGraphics
import PDFEditorCore
import SwiftUI

/// Interactive drag handles for freeze-pane boundaries.
///
/// Renders a horizontal drag line (for row freeze) and a vertical drag line
/// (for column freeze). Users can drag these lines to change how many rows
/// or columns are pinned. The handle snaps to row/column boundaries based on
/// estimated row heights and column widths.
///
/// First principle: spatial reference (headers) should be adjustable, not
/// locked to auto-detection. The user knows their document better than the
/// algorithm.
///
/// Doctrine alignment:
/// - §3: Smart defaults (auto-detect) + manual override (drag)
/// - §8: Capability routing — drag handles appear only when freeze is active
/// - Long-term: foundation for interactive grid editing, column resize

// MARK: - Freeze Pane Resize Coordinator

/// Tracks the drag state and computes snap positions for freeze boundary resize.
@MainActor
public final class FreezePaneResizeCoordinator: ObservableObject {
  /// The row separator Y position (in view coordinates).
  @Published public var rowSeparatorY: CGFloat?
  /// The column separator X position (in view coordinates).
  @Published public var columnSeparatorX: CGFloat?
  /// Whether a drag is in progress.
  @Published public var isDragging: Bool = false
  /// The drag axis being resized.
  @Published public var activeDragAxis: DragAxis = .none

  public enum DragAxis: Sendable {
    case none
    case horizontal  // resizing pinned rows (dragging the bottom edge)
    case vertical    // resizing pinned columns (dragging the right edge)
  }

  /// Estimated row heights (in page points). Used for snap targets.
  public var estimatedRowHeights: [CGFloat] = []
  /// Estimated column widths (in page points). Used for snap targets.
  public var estimatedColumnWidths: [CGFloat] = []
  /// Total rows and columns in the detected table.
  public var totalRows: Int = 0
  public var totalColumns: Int = 0

  /// Current page bounds (for coordinate conversion).
  public var pageBounds: CGRect = .zero
  /// Current zoom scale.
  public var zoomScale: CGFloat = 1.0

  /// Callback fired when the freeze configuration changes via drag.
  public var onConfigChange: ((FreezePaneConfig) -> Void)?

  public init() {}

  // MARK: - Coordinate Conversion

  // MARK: - Measurement Helpers

  /// Cumulative row boundary positions (in PDF points, from top of table).
  private var rowBoundaries: [CGFloat] {
    if !estimatedRowHeights.isEmpty {
      var cumulative: CGFloat = 0
      return estimatedRowHeights.map { height in
        cumulative += CGFloat(height)
        return cumulative
      }
    }
    // Fallback: evenly spaced
    guard totalRows > 0 else { return [] }
    let avg = pageBounds.height / CGFloat(totalRows)
    return (1...totalRows).map { CGFloat($0) * avg }
  }

  /// Cumulative column boundary positions (in PDF points, from left of table).
  private var columnBoundaries: [CGFloat] {
    if !estimatedColumnWidths.isEmpty {
      var cumulative: CGFloat = 0
      return estimatedColumnWidths.map { width in
        cumulative += CGFloat(width)
        return cumulative
      }
    }
    // Fallback: evenly spaced
    guard totalColumns > 0 else { return [] }
    let avg = pageBounds.width / CGFloat(totalColumns)
    return (1...totalColumns).map { CGFloat($0) * avg }
  }

  /// Convert a view-space Y coordinate to the number of pinned rows.
  public func pinnedRowsAtY(_ viewY: CGFloat, viewHeight: CGFloat) -> Int {
    guard totalRows > 0 else { return 0 }

    // viewY is from bottom; convert to distance from top of table
    let pixelsFromTop = viewHeight - viewY
    let pointsFromTop = pixelsFromTop / zoomScale

    // Find which row boundary is closest
    let boundaries = rowBoundaries
    for (idx, boundary) in boundaries.enumerated() {
      if pointsFromTop <= boundary {
        return idx + 1
      }
    }
    return totalRows
  }

  /// Convert a view-space X coordinate to the number of pinned columns.
  public func pinnedColumnsAtX(_ viewX: CGFloat) -> Int {
    guard totalColumns > 0 else { return 0 }

    let pointsFromLeft = viewX / zoomScale
    let boundaries = columnBoundaries
    for (idx, boundary) in boundaries.enumerated() {
      if pointsFromLeft <= boundary {
        return idx + 1
      }
    }
    return totalColumns
  }

  /// Convert a number of pinned rows to a view-space Y coordinate.
  public func yForPinnedRows(_ rows: Int, viewHeight: CGFloat) -> CGFloat {
    guard rows > 0 else { return 0 }
    let boundaries = rowBoundaries
    guard rows <= boundaries.count else { return 0 }
    let pinnedHeight = boundaries[rows - 1] * zoomScale
    return viewHeight - pinnedHeight
  }

  /// Convert a number of pinned columns to a view-space X coordinate.
  public func xForPinnedColumns(_ columns: Int) -> CGFloat {
    guard columns > 0 else { return 0 }
    let boundaries = columnBoundaries
    guard columns <= boundaries.count else { return 0 }
    return boundaries[columns - 1] * zoomScale
  }

  // MARK: - Snap Logic

  /// Find the nearest row boundary to a Y position (in view coordinates).
  public func snapToNearestRowBoundary(_ viewY: CGFloat, viewHeight: CGFloat) -> CGFloat {
    guard totalRows > 0 else { return viewY }

    let pixelsFromTop = viewHeight - viewY
    let pointsFromTop = pixelsFromTop / zoomScale

    let boundaries = rowBoundaries
    // Find nearest boundary
    var bestIdx = 0
    var bestDist: CGFloat = .greatestFiniteMagnitude
    for (idx, boundary) in boundaries.enumerated() {
      let dist = abs(pointsFromTop - boundary)
      if dist < bestDist {
        bestDist = dist
        bestIdx = idx
      }
    }
    // Also consider 0 (no rows pinned)
    if abs(pointsFromTop) < bestDist {
      return viewHeight // no rows pinned
    }

    let snappedHeight = boundaries[bestIdx] * zoomScale
    return viewHeight - snappedHeight
  }

  /// Find the nearest column boundary to an X position (in view coordinates).
  public func snapToNearestColumnBoundary(_ viewX: CGFloat) -> CGFloat {
    guard totalColumns > 0 else { return viewX }

    let pointsFromLeft = viewX / zoomScale
    let boundaries = columnBoundaries
    var bestIdx = 0
    var bestDist: CGFloat = .greatestFiniteMagnitude
    for (idx, boundary) in boundaries.enumerated() {
      let dist = abs(pointsFromLeft - boundary)
      if dist < bestDist {
        bestDist = dist
        bestIdx = idx
      }
    }
    if abs(pointsFromLeft) < bestDist {
      return 0 // no columns pinned
    }

    return boundaries[bestIdx] * zoomScale
  }

  // MARK: - Drag Events

  /// Called when a drag begins on a separator.
  public func beginDrag(axis: DragAxis) {
    isDragging = true
    activeDragAxis = axis
  }

  /// Called during a drag to update the separator position.
  public func updateDrag(to position: CGPoint, viewHeight: CGFloat) {
    switch activeDragAxis {
    case .horizontal:
      rowSeparatorY = snapToNearestRowBoundary(position.y, viewHeight: viewHeight)
    case .vertical:
      columnSeparatorX = snapToNearestColumnBoundary(position.x)
    case .none:
      break
    }
  }

  /// Called when a drag ends. Computes the final config and fires the callback.
  public func endDrag(viewHeight: CGFloat) {
    let pinnedRows: Int
    if let y = rowSeparatorY {
      pinnedRows = pinnedRowsAtY(y, viewHeight: viewHeight)
    } else {
      pinnedRows = 0
    }

    let pinnedColumns: Int
    if let x = columnSeparatorX {
      pinnedColumns = pinnedColumnsAtX(x)
    } else {
      pinnedColumns = 0
    }

    let newConfig = FreezePaneConfig(
      pinnedRows: pinnedRows,
      pinnedColumns: pinnedColumns,
      isAutoDetected: false
    )

    isDragging = false
    activeDragAxis = .none
    onConfigChange?(newConfig)
  }
}

// MARK: - Freeze Pane Drag Handle View

/// A SwiftUI view that renders draggable separator lines for freeze pane boundaries.
public struct FreezePaneDragHandleView: View {
  @Binding var rowSeparatorY: CGFloat?
  @Binding var columnSeparatorX: CGFloat?
  @Binding var isDragging: Bool

  let viewHeight: CGFloat
  let viewWidth: CGFloat
  let coordinator: FreezePaneResizeCoordinator

  /// The thickness of the hit area around the separator line.
  private let hitAreaThickness: CGFloat = 8
  /// The visible line thickness.
  private let lineWidth: CGFloat = 2
  /// Snap zone radius — how close you need to be to grab the line.
  private let grabRadius: CGFloat = 12

  public init(
    rowSeparatorY: Binding<CGFloat?>,
    columnSeparatorX: Binding<CGFloat?>,
    isDragging: Binding<Bool>,
    viewHeight: CGFloat,
    viewWidth: CGFloat,
    coordinator: FreezePaneResizeCoordinator
  ) {
    self._rowSeparatorY = rowSeparatorY
    self._columnSeparatorX = columnSeparatorX
    self._isDragging = isDragging
    self.viewHeight = viewHeight
    self.viewWidth = viewWidth
    self.coordinator = coordinator
  }

  public var body: some View {
    ZStack {
      // Row separator (horizontal line)
      if let y = rowSeparatorY {
        rowHandle(y: y)
      }

      // Column separator (vertical line)
      if let x = columnSeparatorX {
        columnHandle(x: x)
      }

      // Resize label during drag
      if isDragging {
        dragLabel
      }
    }
    .allowsHitTesting(true)
  }

  // MARK: - Row Handle (horizontal line)

  @ViewBuilder
  private func rowHandle(y: CGFloat) -> some View {
    GeometryReader { geo in
      ZStack {
        // Visible line
        Rectangle()
          .fill(Color.accentColor.opacity(0.8))
          .frame(height: lineWidth)
          .offset(y: -lineWidth / 2)

        // Hit area (wider, transparent)
        Rectangle()
          .fill(Color.clear)
          .frame(height: hitAreaThickness)
          .offset(y: -hitAreaThickness / 2)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 1)
              .onChanged { value in
                if !isDragging {
                  coordinator.beginDrag(axis: .horizontal)
                  isDragging = true
                }
                let newY = coordinator.snapToNearestRowBoundary(
                  value.location.y, viewHeight: geo.size.height
                )
                rowSeparatorY = newY
                coordinator.updateDrag(
                  to: CGPoint(x: value.location.x, y: newY),
                  viewHeight: geo.size.height
                )
              }
              .onEnded { value in
                coordinator.endDrag(viewHeight: geo.size.height)
                isDragging = false
              }
          )

        // Drag indicator (small circle at center)
        Circle()
          .fill(Color.accentColor)
          .frame(width: 6, height: 6)
          .offset(y: -lineWidth / 2)
      }
      .frame(width: geo.size.width, height: hitAreaThickness)
      .position(x: geo.size.width / 2, y: y)
    }
  }

  // MARK: - Column Handle (vertical line)

  @ViewBuilder
  private func columnHandle(x: CGFloat) -> some View {
    GeometryReader { geo in
      ZStack {
        // Visible line
        Rectangle()
          .fill(Color.accentColor.opacity(0.8))
          .frame(width: lineWidth)
          .offset(x: -lineWidth / 2)

        // Hit area (wider, transparent)
        Rectangle()
          .fill(Color.clear)
          .frame(width: hitAreaThickness)
          .offset(x: -hitAreaThickness / 2)
          .contentShape(Rectangle())
          .gesture(
            DragGesture(minimumDistance: 1)
              .onChanged { value in
                if !isDragging {
                  coordinator.beginDrag(axis: .vertical)
                  isDragging = true
                }
                let newX = coordinator.snapToNearestColumnBoundary(value.location.x)
                columnSeparatorX = newX
                coordinator.updateDrag(
                  to: CGPoint(x: newX, y: value.location.y),
                  viewHeight: geo.size.height
                )
              }
              .onEnded { value in
                coordinator.endDrag(viewHeight: geo.size.height)
                isDragging = false
              }
          )

        // Drag indicator (small circle at center)
        Circle()
          .fill(Color.accentColor)
          .frame(width: 6, height: 6)
          .offset(x: -lineWidth / 2)
      }
      .frame(width: hitAreaThickness, height: geo.size.height)
      .position(x: x, y: geo.size.height / 2)
    }
  }

  // MARK: - Drag Label

  @ViewBuilder
  private var dragLabel: some View {
    VStack(spacing: 2) {
      if let y = rowSeparatorY {
        let rows = coordinator.pinnedRowsAtY(y, viewHeight: viewHeight)
        Text("\(rows) row\(rows == 1 ? "" : "s")")
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.ultraThinMaterial)
          .cornerRadius(4)
      }

      if let x = columnSeparatorX {
        let cols = coordinator.pinnedColumnsAtX(x)
        Text("\(cols) col\(cols == 1 ? "" : "s")")
          .font(.caption2)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.ultraThinMaterial)
          .cornerRadius(4)
      }
    }
    .position(x: (columnSeparatorX ?? viewWidth / 2), y: (rowSeparatorY ?? viewHeight / 2) - 20)
    .transition(.opacity)
    .animation(.easeInOut(duration: 0.15), value: isDragging)
  }
}
