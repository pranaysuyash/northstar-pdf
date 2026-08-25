import PDFEditorCore
import PDFKit
import SwiftUI

/// A side-by-side comparison view showing the **original source PDF** and the
/// **current edited PDF** rendered as separate documents.
///
/// Left panel:  Original source PDF (pre-edit), rendered from cached source bytes.
/// Right panel: Current edited PDF with operation regions overlaid.
///
/// Region colors on the edited panel:
/// - Red fill + bold stroke: change outside authorized operation regions.
/// - Green fill + stroke: change inside authorized operation regions.
/// - Dashed green border on original panel: preserved (unchanged) regions.
struct DiffComparisonView: View {
  let sourceDocument: PDFDocument?
  let currentDocument: PDFDocument?
  let sourceInspection: DocumentInspection?
  let currentInspection: DocumentInspection?
  let operations: [EditOperation]
  let diff: DocumentDiff?
  let selectedPageIndex: Int
  let onPageChange: (Int) -> Void
  let onExportReport: () -> Void

  @State private var pageIndex: Int = 0
  @State private var zoom: CGFloat = 1.0

  var body: some View {
    VStack(spacing: 0) {
      diffSummaryHeader
      Divider()
      pageNavigation
      Divider()
      HSplitView {
        sourcePanel
        editedPanel
      }
    }
    .frame(minWidth: 1000, minHeight: 600)
    .onAppear { pageIndex = selectedPageIndex }
  }

  // MARK: - Summary Header

  private var diffSummaryHeader: some View {
    HStack(spacing: 12) {
      Image(systemName: statusIcon)
        .foregroundStyle(statusColor)
        .font(.title3)
      VStack(alignment: .leading, spacing: 2) {
        Text("Visual Diff — Original vs Filled")
          .font(.headline)
        if let diff {
          Text(diffSummaryText(diff))
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("No diff data available.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      HStack(spacing: 12) {
        legendItem(color: .green, label: "Inside operation", dashed: false)
        legendItem(color: .red, label: "Outside operation", dashed: false)
        legendItem(color: .green, label: "Preserved", dashed: true)
      }
      .font(.caption2)
      Button {
        onExportReport()
      } label: {
        Label("Export Report", systemImage: "square.and.arrow.up")
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
    HStack(spacing: 4) {
      Rectangle()
        .fill(dashed ? Color.clear : color.opacity(0.3))
        .overlay(
          Rectangle()
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [4, 3] : []))
        )
        .frame(width: 14, height: 10)
        .clipShape(RoundedRectangle(cornerRadius: 2))
      Text(label)
    }
  }

  private var statusIcon: String {
    guard let diff else { return "questionmark.circle" }
    switch diff.summary.overallStatus {
    case .preserved: return "checkmark.circle.fill"
    case .warnings: return "exclamationmark.triangle.fill"
    case .violations: return "xmark.octagon.fill"
    case .incomplete: return "questionmark.circle.fill"
    }
  }

  private var statusColor: Color {
    guard let diff else { return .secondary }
    switch diff.summary.overallStatus {
    case .preserved: return .green
    case .warnings: return .orange
    case .violations: return .red
    case .incomplete: return .secondary
    }
  }

  private func diffSummaryText(_ diff: DocumentDiff) -> String {
    let changedPages = diff.pages.filter { $0.hasChanges }.count
    let totalRegions = diff.summary.totalRegionsCompared
    let matched = diff.summary.operationRegionsMatched
    let unexpected = diff.summary.unexpectedChanges
    return "\(changedPages) page(s) changed · \(matched)/\(totalRegions) operation regions matched · \(unexpected) unexpected change(s)"
  }

  // MARK: - Page Navigation

  private var pageNavigation: some View {
    HStack(spacing: 12) {
      Button { pageGoTo(0) } label: { Image(systemName: "backward.fill") }
        .disabled(pageIndex <= 0)
      Button { pageGoTo(pageIndex - 1) } label: { Image(systemName: "chevron.left") }
        .disabled(pageIndex <= 0)
      Text("Page \(pageIndex + 1) of \(sourceInspection?.pages.count ?? 0)")
        .font(.callout.monospacedDigit())
        .frame(minWidth: 120)
      Button { pageGoTo(pageIndex + 1) } label: { Image(systemName: "chevron.right") }
        .disabled(pageIndex >= maxPage - 1)
      Button { pageGoTo(maxPage - 1) } label: { Image(systemName: "forward.fill") }
        .disabled(pageIndex >= maxPage - 1)
      Spacer()
      Slider(value: $zoom, in: 0.5...3.0)
        .frame(width: 140)
      Text("\(Int(zoom * 100))%")
        .font(.caption.monospacedDigit())
        .frame(width: 40)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private var maxPage: Int { sourceInspection?.pages.count ?? 1 }

  private func pageGoTo(_ index: Int) {
    let clamped = min(max(index, 0), max(0, maxPage - 1))
    pageIndex = clamped
    onPageChange(clamped)
  }

  // MARK: - Source Panel (Original PDF)

  private var sourcePanel: some View {
    VStack(spacing: 4) {
      HStack {
        Label("Original", systemImage: "doc")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Text(sourceDocumentLabel)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
      .padding(.top, 4)

      if let sourceDocument, sourceDocument.pageCount > pageIndex,
         let page = sourceDocument.page(at: pageIndex) {
        DiffPDFPageView(page: page, zoom: zoom)
          .overlay(alignment: .topLeading) {
            // Show preserved region outlines on original
            preservedRegionOverlay
          }
          .overlay(alignment: .bottomLeading) {
            sourceFieldSummary
              .padding(6)
          }
      } else {
        PlaceholderPanel(message: sourceDocument == nil
          ? "No source PDF data cached"
          : "Source page unavailable")
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var sourceDocumentLabel: String {
    guard let sourceDocument else { return "" }
    return "\(sourceDocument.pageCount) page\(sourceDocument.pageCount == 1 ? "" : "s") · source"
  }

  @ViewBuilder
  private var preservedRegionOverlay: some View {
    if let diff, diff.pages.indices.contains(pageIndex) {
      let pageDiff = diff.pages[pageIndex]
      GeometryReader { geo in
        DiffRegionCanvas(
          regions: pageDiff.regions,
          highlightMode: .source,
          pageIndex: pageIndex,
          viewSize: geo.size
        )
      }
    }
  }

  private var sourceFieldSummary: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 2) {
        if let source = sourceInspection {
          Text("Fields: \(source.fields.count) · Candidates: \(source.candidates.count)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          ForEach(source.fields.prefix(5), id: \.id) { field in
            let value = field.value ?? "(empty)"
            Text("\(field.name): \(value)")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          if source.fields.count > 5 {
            Text("…and \(source.fields.count - 5) more")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .groupBoxStyle(.automatic)
  }

  // MARK: - Edited Panel (Current PDF)

  private var editedPanel: some View {
    VStack(spacing: 4) {
      HStack {
        Label("Filled (Current)", systemImage: "doc.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Text(editedDocumentLabel)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 8)
      .padding(.top, 4)

      if let currentDocument, currentDocument.pageCount > pageIndex,
         let page = currentDocument.page(at: pageIndex) {
        DiffPDFPageView(page: page, zoom: zoom)
          .overlay(alignment: .topLeading) {
            // Show change overlays (red/green) on edited panel
            editedRegionOverlay
          }
          .overlay(alignment: .bottomLeading) {
            editedFieldSummary
              .padding(6)
          }
      } else {
        PlaceholderPanel(message: "No edited page")
      }
    }
    .background(Color(nsColor: .controlBackgroundColor))
  }

  private var editedDocumentLabel: String {
    guard let currentDocument else { return "" }
    return "\(currentDocument.pageCount) page\(currentDocument.pageCount == 1 ? "" : "s") · \(operations.count) operation(s)"
  }

  @ViewBuilder
  private var editedRegionOverlay: some View {
    if let diff, diff.pages.indices.contains(pageIndex) {
      let pageDiff = diff.pages[pageIndex]
      GeometryReader { geo in
        DiffRegionCanvas(
          regions: pageDiff.regions,
          highlightMode: .edited,
          pageIndex: pageIndex,
          viewSize: geo.size
        )
      }
    }
  }

  private var editedFieldSummary: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 2) {
        if let current = currentInspection {
          Text("Fields: \(current.fields.count) · Candidates: \(current.candidates.count) · Ops: \(operations.count)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          ForEach(current.fields.prefix(5), id: \.id) { field in
            let value = field.value ?? "(empty)"
            Text("\(field.name): \(value)")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          if current.fields.count > 5 {
            Text("…and \(current.fields.count - 5) more")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
      }
    }
    .groupBoxStyle(.automatic)
  }
}

// MARK: - DiffRegionCanvas

/// Renders colored overlays for diff regions using SwiftUI Canvas.
private struct DiffRegionCanvas: View {
  let regions: [RegionDiff]
  let highlightMode: HighlightMode
  let pageIndex: Int
  let viewSize: CGSize

  enum HighlightMode {
    case source   // dashed green for preserved
    case edited   // red/green fills for changes
  }

  var body: some View {
    Canvas { context, size in
      for region in regions {
        guard region.region.pageIndex == pageIndex else { continue }
        let rect = region.region.rect
        let viewRect = DiffRegionCanvas.convertToView(
          rect, viewSize: size, pageWidth: 612, pageHeight: 792)

        switch highlightMode {
        case .source:
          if region.kind == .preserved {
            context.stroke(
              Path(viewRect),
              with: .color(.green.opacity(0.5)),
              style: StrokeStyle(lineWidth: 1, dash: [4, 3])
            )
          }
        case .edited:
          switch region.kind {
          case .unexpectedTextChange, .geometryChanged:
            context.fill(Path(viewRect), with: .color(.red.opacity(0.18)))
            context.stroke(
              Path(viewRect),
              with: .color(.red.opacity(0.8)),
              style: StrokeStyle(lineWidth: 2.5)
            )
          case .operationApplied, .nativeFieldChanged, .overlayAdded:
            context.fill(Path(viewRect), with: .color(.green.opacity(0.14)))
            context.stroke(
              Path(viewRect),
              with: .color(.green.opacity(0.8)),
              style: StrokeStyle(lineWidth: 1.5)
            )
          case .preserved:
            break
          }
        }
      }
    }
  }

  /// Convert PDF lower-left coordinates to view top-left coordinates.
  static func convertToView(
    _ rect: PDFRect, viewSize: CGSize, pageWidth: CGFloat, pageHeight: CGFloat
  ) -> CGRect {
    let scaleX = viewSize.width / max(pageWidth, 1)
    let scaleY = viewSize.height / max(pageHeight, 1)
    let scale = min(scaleX, scaleY)
    let offsetX = (viewSize.width - pageWidth * scale) / 2
    let offsetY = (viewSize.height - pageHeight * scale) / 2

    let x = rect.x * scale + offsetX
    let y = (pageHeight - (rect.y + rect.height)) * scale + offsetY
    let w = rect.width * scale
    let h = rect.height * scale
    return CGRect(x: x, y: y, width: w, height: h)
  }
}

// MARK: - DiffPDFPageView

/// Renders a single PDFKit page into a SwiftUI view.
private struct DiffPDFPageView: NSViewRepresentable {
  let page: PDFPage
  let zoom: CGFloat

  func makeNSView(context: Context) -> NSView {
    let view = DiffPageNSView()
    view.page = page
    view.zoomFactor = zoom
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    guard let view = nsView as? DiffPageNSView else { return }
    view.page = page
    view.zoomFactor = zoom
    view.needsDisplay = true
  }
}

private class DiffPageNSView: NSView {
  var page: PDFPage?
  var zoomFactor: CGFloat = 1.0

  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    guard let page else {
      NSColor.controlBackgroundColor.setFill()
      dirtyRect.fill()
      return
    }

    NSColor.white.setFill()
    dirtyRect.fill()

    let pageBounds = page.bounds(for: .cropBox)
    let scaleX = bounds.width / max(pageBounds.width, 1)
    let scaleY = bounds.height / max(pageBounds.height, 1)
    let scale = min(scaleX, scaleY) * zoomFactor

    let drawWidth = pageBounds.width * scale
    let drawHeight = pageBounds.height * scale
    let offsetX = (bounds.width - drawWidth) / 2
    let offsetY = (bounds.height - drawHeight) / 2

    guard let context = NSGraphicsContext.current?.cgContext else { return }
    context.saveGState()
    context.translateBy(x: offsetX, y: offsetY + drawHeight)
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .cropBox, to: context)
    context.restoreGState()
  }
}

// MARK: - Placeholder

private struct PlaceholderPanel: View {
  let message: String
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "doc.text")
        .font(.largeTitle)
        .foregroundStyle(.tertiary)
      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .controlBackgroundColor))
  }
}
