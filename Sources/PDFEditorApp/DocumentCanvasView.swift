import AppKit
import PDFEditorCore
import PDFEditorRecovery
@preconcurrency import PDFKit
import SwiftUI

public enum SearchProjectionState: Equatable, Sendable {
  case none
  case exact
  case approximate
  case unavailable

  public var title: String {
    switch self {
    case .none: return "No highlight"
    case .exact: return "Exact highlight"
    case .approximate: return "Approximate highlight"
    case .unavailable: return "Highlight unavailable"
    }
  }

  public var message: String {
    switch self {
    case .none: return ""
    case .exact: return "The selected search result is highlighted at its exact text range."
    case .approximate: return "The selected result is highlighted approximately because PDFKit could not prove the exact text range."
    case .unavailable: return "The selected result could not be projected into the PDF view. The result remains selected in the list."
    }
  }

  public var symbolName: String {
    switch self {
    case .none: return "magnifyingglass"
    case .exact: return "checkmark.circle"
    case .approximate: return "exclamationmark.triangle"
    case .unavailable: return "questionmark.circle"
    }
  }
}

public struct DocumentCanvasView: View {
  @Bindable var model: AppModel
  let inspection: DocumentInspection
  @Binding var searchProjectionState: SearchProjectionState
  // RG-058: honor Reduce Motion for canvas-level transitions.
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  // RG-059: raised-contrast chrome under the Increased Contrast setting.
  @Environment(\.colorSchemeContrast) private var colorSchemeContrast
  /// RG-057: incremented by the ⌘F command; consuming it focuses the field.
  @Binding var searchFocusEvent: Int
  @FocusState private var isSearchFieldFocused: Bool

  public init(
    model: AppModel,
    inspection: DocumentInspection,
    searchProjectionState: Binding<SearchProjectionState>,
    searchFocusEvent: Binding<Int> = .constant(0)
  ) {
    self.model = model
    self.inspection = inspection
    self._searchProjectionState = searchProjectionState
    self._searchFocusEvent = searchFocusEvent
  }

  @State private var isSearchExpanded = false

  public var body: some View {
    ZStack {
      pdfCanvas

      VStack {
        HStack {
          Spacer()
          floatingSearchHUD
        }
        .padding(.top, 14)
        .padding(.trailing, 16)

        Spacer()

        HStack {
          Spacer()
          floatingCanvasHUD
        }
        .padding(.bottom, 16)
        .padding(.trailing, 16)
      }
    }
    .frame(minWidth: 480)
    // RG-057: the ⌘F command increments searchFocusEvent; consuming it here
    // expands the search HUD and moves keyboard focus into the field so focus
    // lands predictably after the Find action.
    .onChange(of: searchFocusEvent) { _, newValue in
      guard newValue > 0 else { return }
      isSearchExpanded = true
      isSearchFieldFocused = true
    }
  }

  private var pdfCanvas: some View {
    PDFKitView(
      document: model.liveDocument,
      projectionRevision: model.documentProjectionRevision,
      operations: model.operations,
      pageIndex: model.selectedPageIndex,
      viewMode: model.readerViewMode,
      scaleMode: model.readerScaleMode,
      zoom: model.readerZoom,
      rotation: model.readerRotation,
      selectedSearchMatch: model.selectedSearchMatch,
      searchProjectionState: $searchProjectionState,
      selectedCandidate: model.selectedCandidate,
      selectedField: model.selectedField,
      isManualPlacementMode: model.isManualPlacementMode,
      fillHighlights: model.fillHighlightRegions + model.diffHighlightRegions,
      activeInlineEditor: model.activeInlineEditor,
      initialAnchor: model.stagedInitialAnchor,
      initialAnchorToken: model.pendingInitialAnchorToken,
      onViewportAnchorChange: { anchor in
        model.reportViewportAnchor(anchor)
      },
      applyPresentationOperation: { operation, document in
        model.applyOperationForPresentation(operation, to: document)
      },
      onManualPlacement: { pageIndex, point in
        model.receiveManualPlacement(pageIndex: pageIndex, point: point)
      },
      onDirectEdit: { pageIndex, point in
        model.beginDirectTextPlacement(pageIndex: pageIndex, point: point)
      },
      onPageTap: { pageIndex, point in
        model.handlePageTap(pageIndex: pageIndex, point: point)
      },
      onCommitInlineEditor: { text in
        model.commitInlineEditor(text: text, andAdvance: true)
      },
      onDismissInlineEditor: {
        model.dismissInlineEditor()
      }
    )
    .accessibilityElement(children: .contain)
    .accessibilityLabel("PDF document page \(model.selectedPageIndex + 1)")
    .accessibilityValue(accessibilityValueDescription)
    .accessibilityHint(accessibilityHintDescription)
  }

  private var accessibilityValueDescription: String {
    if let match = model.selectedSearchMatch {
      return "Search result on page \(match.pageIndex + 1): \(match.snippet)"
    }
    if let candidate = model.selectedCandidate {
      return "Selected suggested area \(candidate.effectiveDisplayName) on page \(candidate.pageIndex + 1), \(candidate.entryMode.rawValue)"
    }
    if let field = model.selectedField {
      return "Selected native field \(field.name) on page \(field.pageIndex + 1)"
    }
    return "Page \(model.selectedPageIndex + 1)"
  }

  private var accessibilityHintDescription: String {
    let modeHint = model.isManualPlacementMode
      ? "Manual placement mode. Press Return or Space to place text at the current page center, or click the page."
      : "Use the page list, inspector, or search results to change the selected document element."
    return "\(modeHint) \(searchProjectionState.message)"
  }

  private var floatingCanvasHUD: some View {
    HStack(spacing: 8) {
      Button {
        model.setZoom(max(0.25, model.readerZoom - 0.1))
      } label: {
        Image(systemName: "minus")
          .font(.caption.weight(.bold))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Zoom out")

      Text("\(Int(model.readerZoom * 100))%")
        .font(.caption.weight(.semibold).monospacedDigit())
        .frame(width: 38)
        .accessibilityLabel("Zoom level \(Int(model.readerZoom * 100)) percent")
        .accessibilityAddTraits(.isStaticText)

      Button {
        model.setZoom(min(3.0, model.readerZoom + 0.1))
      } label: {
        Image(systemName: "plus")
          .font(.caption.weight(.bold))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Zoom in")

      Divider()
        .frame(height: 12)
        .accessibilityHidden(true)

      Button {
        model.rotateLeft()
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Rotate left 90 degrees")
      .help("Rotate Left 90°")

      Button {
        model.rotateRight()
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Rotate right 90 degrees")
      .help("Rotate Right 90°")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    .overlay(
      Capsule()
        .stroke(
          colorSchemeContrast == .increased
            ? Color.primary.opacity(0.6) : Color.white.opacity(0.2),
          lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
        )
    )
  }

  private var floatingSearchHUD: some View {
    HStack(spacing: 8) {
      if isSearchExpanded || !model.searchQuery.isEmpty {
        Image(systemName: "magnifyingglass")
          .font(.caption)
          .foregroundStyle(.secondary)

        TextField("Find in document…", text: $model.searchQuery)
          .textFieldStyle(.plain)
          .frame(minWidth: 160, maxWidth: 220)
          .focused($isSearchFieldFocused)
          .onSubmit { model.runSearch() }
          .onChange(of: model.searchQuery) { _, newValue in
            if !newValue.isEmpty {
              model.runSearch()
            }
          }

        if !model.searchMatches.isEmpty {
          Text("\(model.selectedSearchMatchIndex.map { $0 + 1 } ?? 1)/\(model.searchMatches.count)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)

          Button {
            model.selectPreviousSearchMatch()
          } label: {
            Image(systemName: "chevron.up")
              .font(.caption2.weight(.bold))
          }
          .buttonStyle(.plain)
          .help("Previous match (⇧⌘G)")

          Button {
            model.selectNextSearchMatch()
          } label: {
            Image(systemName: "chevron.down")
              .font(.caption2.weight(.bold))
          }
          .buttonStyle(.plain)
          .help("Next match (⌘G)")
        } else if !model.searchQuery.isEmpty {
          Text("0 results")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }

        if searchProjectionState != .none && searchProjectionState != .exact {
          Image(systemName: searchProjectionState.symbolName)
            .font(.caption2)
            .foregroundStyle(searchProjectionState == .approximate ? Color.orange : Color.secondary)
            .help(searchProjectionState.message)
        }

        Button {
          model.searchQuery = ""
          isSearchExpanded = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Clear search")
      } else {
        Button {
          // RG-058: skip the expand animation under Reduce Motion.
          if reduceMotion {
            isSearchExpanded = true
          } else {
            withAnimation(.easeInOut(duration: 0.15)) {
              isSearchExpanded = true
            }
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
            Text("Find")
              .font(.caption.weight(.medium))
            Text("⌘F")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help("Search in document (⌘F)")
      }

      Divider()
        .frame(height: 12)

      Button {
        model.copyCurrentPageText()
      } label: {
        Image(systemName: "doc.on.doc")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .disabled(!(model.inspection?.permissions.canCopy ?? false))
      .help("Copy current page text to clipboard")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    .overlay(
      Capsule()
        .stroke(
          colorSchemeContrast == .increased
            ? Color.primary.opacity(0.6) : Color.white.opacity(0.2),
          lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
        )
    )
  }
}

// MARK: - Presentation Highlights & Overlays

public struct PDFPresentationHighlight: @unchecked Sendable {
  public enum Kind: Sendable {
    case candidate
    case characterGrid
    case field
    case search
    case candidateUnfilled
    case candidateFilled
    case signatureRegion
    case focused
    case outsideRegionChange
    case insideRegionChange
    case preserved
  }

  public let kind: Kind
  public let page: PDFPage
  public let bounds: CGRect
  public let memberBounds: [CGRect]
  /// Human-facing suggestion name rendered as an on-canvas chip.
  public let label: String?

  public init(
    kind: Kind, page: PDFPage, bounds: CGRect, memberBounds: [CGRect] = [],
    label: String? = nil
  ) {
    self.kind = kind
    self.page = page
    self.bounds = bounds
    self.memberBounds = memberBounds
    self.label = label
  }
}

// MARK: - Inline Editor TextField Host
public final class InlineEditorTextFieldHost: NSView, NSTextFieldDelegate {
  public let textField: NSTextField
  /// Names the region being filled so the user never edits an anonymous box.
  public let nameLabel: NSTextField
  public var onCommit: (String) -> Void
  public var onDismiss: () -> Void

  public init(onCommit: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
    self.onCommit = onCommit
    self.onDismiss = onDismiss
    self.textField = NSTextField()
    self.nameLabel = NSTextField(labelWithString: "")
    super.init(frame: .zero)

    wantsLayer = true
    layer?.cornerRadius = 4
    layer?.masksToBounds = true
    layer?.borderColor = NSColor.controlAccentColor.cgColor
    layer?.borderWidth = 1.5
    layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

    nameLabel.font = NSFont.systemFont(ofSize: 9, weight: .semibold)
    nameLabel.textColor = .secondaryLabelColor
    nameLabel.lineBreakMode = .byTruncatingTail
    addSubview(nameLabel)

    textField.isBordered = false
    textField.drawsBackground = false
    textField.font = NSFont.preferredFont(forTextStyle: .callout)
    textField.focusRingType = .none
    textField.autoresizingMask = [.width]
    addSubview(textField)
    layoutEditorSubviews()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func layoutEditorSubviews() {
    let showLabel = !nameLabel.stringValue.isEmpty
    let labelHeight: CGFloat = showLabel ? 12 : 0
    nameLabel.frame = CGRect(
      x: 6, y: bounds.height - labelHeight - 2,
      width: max(0, bounds.width - 12), height: labelHeight)
    nameLabel.isHidden = !showLabel
    textField.frame = CGRect(
      x: 6, y: 3,
      width: max(0, bounds.width - 12),
      height: max(14, bounds.height - labelHeight - 8))
  }

  public func setLabel(_ label: String) {
    guard nameLabel.stringValue != label else { return }
    nameLabel.stringValue = label
    textField.placeholderString = label
    layoutEditorSubviews()
  }

  public override func resizeSubviews(withOldSize oldSize: NSSize) {
    super.resizeSubviews(withOldSize: oldSize)
    layoutEditorSubviews()
  }

  public func updateText(_ text: String) {
    if textField.stringValue != text {
      textField.stringValue = text
    }
  }

  public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    if commandSelector == #selector(NSResponder.insertNewline(_:)) {
      onCommit(textField.stringValue)
      return true
    } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
      onDismiss()
      return true
    }
    return false
  }

  public func controlTextDidEndEditing(_ obj: Notification) {
    if let field = obj.object as? NSTextField {
      onCommit(field.stringValue)
    }
  }
}

public final class PDFPresentationOverlayView: NSView {
  public var highlights: [PDFPresentationHighlight] = [] {
    didSet { needsDisplay = true }
  }

  public func invalidateProjection() {
    needsDisplay = true
    layer?.setNeedsDisplay()
  }

  public override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  public override func draw(_ dirtyRect: NSRect) {
    guard let pdfView = superview as? PDFView else { return }

    // Name chips render only when the page is large enough to read them.
    let chipsEnabled = pdfView.scaleFactor >= 0.5
    var occupiedChipRects: [CGRect] = []

    for highlight in highlights {
      let pdfViewBounds = pdfView.convert(highlight.bounds, from: highlight.page)
      let overlayBounds = convert(pdfViewBounds, from: pdfView)
      guard overlayBounds.intersects(dirtyRect) else { continue }

      if highlight.kind == .characterGrid {
        let boundary = NSBezierPath(roundedRect: overlayBounds, xRadius: 2, yRadius: 2)
        boundary.setLineDash([4, 3], count: 2, phase: 0)
        boundary.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        boundary.stroke()

        for memberBounds in highlight.memberBounds {
          let memberViewBounds = pdfView.convert(memberBounds, from: highlight.page)
          let cellBounds = convert(memberViewBounds, from: pdfView)
          guard cellBounds.intersects(dirtyRect) else { continue }
          let cell = NSBezierPath(rect: cellBounds)
          NSColor.systemBlue.withAlphaComponent(0.12).setFill()
          NSColor.controlAccentColor.withAlphaComponent(0.72).setStroke()
          cell.lineWidth = 1
          cell.fill()
          cell.stroke()
        }
        drawChip(
          label: highlight.label, anchor: overlayBounds,
          tint: NSColor.controlAccentColor, chipsEnabled: chipsEnabled,
          occupied: &occupiedChipRects)
        continue
      }

      let fillColor: NSColor
      let strokeColor: NSColor
      var isDashed = false
      var lineWidth: CGFloat = 1.5

      switch highlight.kind {
      case .candidate:
        fillColor = NSColor.systemBlue.withAlphaComponent(0.12)
        strokeColor = NSColor.controlAccentColor
      case .field:
        fillColor = NSColor.systemBlue.withAlphaComponent(0.08)
        strokeColor = NSColor.controlAccentColor
      case .candidateUnfilled:
        fillColor = NSColor.systemOrange.withAlphaComponent(0.08)
        strokeColor = NSColor.systemOrange
        isDashed = true
      case .candidateFilled:
        fillColor = NSColor.systemGreen.withAlphaComponent(0.10)
        strokeColor = NSColor.systemGreen
      case .signatureRegion:
        fillColor = NSColor.systemPurple.withAlphaComponent(0.10)
        strokeColor = NSColor.systemPurple
        isDashed = true
      case .focused:
        fillColor = NSColor.controlAccentColor.withAlphaComponent(0.20)
        strokeColor = NSColor.controlAccentColor
        lineWidth = 2.0
      case .characterGrid:
        continue
      case .search:
        fillColor = NSColor.systemYellow.withAlphaComponent(0.10)
        strokeColor = NSColor.systemOrange.withAlphaComponent(0.70)
        lineWidth = 1.0
      case .outsideRegionChange:
        fillColor = NSColor.systemRed.withAlphaComponent(0.15)
        strokeColor = NSColor.systemRed
        lineWidth = 2.5
      case .insideRegionChange:
        fillColor = NSColor.systemGreen.withAlphaComponent(0.12)
        strokeColor = NSColor.systemGreen
        lineWidth = 1.5
      case .preserved:
        fillColor = NSColor.clear
        strokeColor = NSColor.systemGreen.withAlphaComponent(0.3)
        lineWidth = 0.5
        isDashed = true
      }

      fillColor.setFill()
      strokeColor.setStroke()
      let path = NSBezierPath(
        roundedRect: overlayBounds,
        xRadius: 3,
        yRadius: 3
      )
      if isDashed {
        path.setLineDash([4, 3], count: 2, phase: 0)
      }
      path.lineWidth = lineWidth
      path.fill()
      path.stroke()
      drawChip(
        label: highlight.label, anchor: overlayBounds,
        tint: strokeColor, chipsEnabled: chipsEnabled,
        occupied: &occupiedChipRects)
      if highlight.kind == .search {
        let underline = NSBezierPath()
        underline.move(to: NSPoint(x: overlayBounds.minX, y: overlayBounds.minY + 1))
        underline.line(to: NSPoint(x: overlayBounds.maxX, y: overlayBounds.minY + 1))
        underline.lineWidth = 2
        NSColor.systemOrange.withAlphaComponent(0.65).setStroke()
        underline.stroke()
      }
    }
  }

  /// Draws the suggestion's display name docked above-left of its region so
  /// each suggestion introduces itself by name without leaving the page.
  ///
  /// Chips stack upward when they would overlap an already-drawn chip and
  /// disappear entirely below a readability zoom threshold.
  private func drawChip(
    label: String?, anchor: NSRect, tint: NSColor,
    chipsEnabled: Bool, occupied: inout [CGRect]
  ) {
    guard chipsEnabled, let label, !label.isEmpty else { return }

    let font = NSFont.systemFont(ofSize: 9, weight: .semibold)
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.white,
    ]
    let textSize = (label as NSString).size(withAttributes: attributes)
    var chipFrame = CGRect(
      x: anchor.minX,
      y: anchor.maxY + 2,
      width: ceil(textSize.width) + 12,
      height: ceil(textSize.height) + 4
    )

    // Stack above previously placed chips instead of overlapping them.
    var attempts = 0
    while occupied.contains(where: { $0.intersects(chipFrame.insetBy(dx: -1, dy: -1)) }),
      attempts < 5
    {
      chipFrame.origin.y += chipFrame.height + 1
      attempts += 1
    }
    // Never cover the region it names.
    guard chipFrame.minY > anchor.maxY - 1 else { return }
    occupied.append(chipFrame)

    let chip = NSBezierPath(roundedRect: chipFrame, xRadius: 3.5, yRadius: 3.5)
    tint.withAlphaComponent(0.88).setFill()
    chip.fill()

    let textRect = chipFrame.insetBy(dx: 6, dy: 2)
    (label as NSString).draw(in: textRect, withAttributes: attributes)
  }
}

public final class InteractivePDFView: PDFView {
  public var isManualPlacementMode = false
  public var onManualPlacement: ((Int, CGPoint) -> Void)?
  public var onDirectEdit: ((Int, CGPoint) -> Void)?
  public var onPageTap: ((Int, CGPoint) -> Void)?
  public var onProjectionInvalidated: (@MainActor @Sendable () -> Void)?
  public var requestedScaleMode: ReaderScaleMode = .fitWidth
  public var requestedRowWidth: CGFloat = 612
  public var requestedZoom: CGFloat = 1

  public override var acceptsFirstResponder: Bool { true }

  public override func becomeFirstResponder() -> Bool {
    true
  }

  public override func layout() {
    super.layout()
    applyRequestedScale()
    onProjectionInvalidated?()
  }

  public func applyRequestedScale() {
    guard bounds.width > 0 else { return }
    let target: CGFloat
    switch requestedScaleMode {
    case .fitWidth:
      let availableWidth = max(240, bounds.width - 28)
      target = min(3.0, max(0.25, availableWidth / requestedRowWidth))
    case .fitPage:
      target = scaleFactorForSizeToFit * 0.95
    case .zoom:
      target = requestedZoom
    }
    guard abs(target - scaleFactor) > 0.0005 else { return }
    scaleFactor = target
    onProjectionInvalidated?()
  }

  public override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    guard let document,
      let page = page(for: convert(event.locationInWindow, from: nil), nearest: true)
    else {
      super.mouseDown(with: event)
      return
    }
    let viewPoint = convert(event.locationInWindow, from: nil)
    let pagePoint = convert(viewPoint, to: page)
    let pageIndex = document.index(for: page)
    if isManualPlacementMode {
      onManualPlacement?(pageIndex, pagePoint)
    } else if event.clickCount >= 2 {
      onDirectEdit?(pageIndex, pagePoint)
    } else {
      onPageTap?(pageIndex, pagePoint)
      super.mouseDown(with: event)
    }
  }

  public override func keyDown(with event: NSEvent) {
    guard isManualPlacementMode,
      event.keyCode == 36 || event.keyCode == 49,
      let document,
      let page = currentPage
    else {
      super.keyDown(with: event)
      return
    }

    let pageBounds = page.bounds(for: displayBox)
    onManualPlacement?(
      document.index(for: page),
      CGPoint(x: pageBounds.midX, y: pageBounds.midY)
    )
  }
}

public struct PDFKitView: NSViewRepresentable {
  public let document: PDFDocument?
  public let projectionRevision: UInt64
  public let operations: [EditOperation]
  public let pageIndex: Int
  public let viewMode: ReaderViewMode
  public let scaleMode: ReaderScaleMode
  public let zoom: Double
  public let rotation: Int
  public let selectedSearchMatch: SearchMatch?
  @Binding public var searchProjectionState: SearchProjectionState
  public let selectedCandidate: RegionCandidate?
  public let selectedField: NativeField?
  public let isManualPlacementMode: Bool
  public let fillHighlights: [FillHighlight]
  public let activeInlineEditor: InlineEditorState?
  public let applyPresentationOperation: (EditOperation, PDFDocument) -> Bool
  public let onManualPlacement: (Int, CGPoint) -> Void
  public let onDirectEdit: (Int, CGPoint) -> Void
  public let onPageTap: (Int, CGPoint) -> Void
  public let onCommitInlineEditor: (String) -> Void
  public let onDismissInlineEditor: () -> Void

  public init(
    document: PDFDocument?,
    projectionRevision: UInt64,
    operations: [EditOperation],
    pageIndex: Int,
    viewMode: ReaderViewMode,
    scaleMode: ReaderScaleMode,
    zoom: Double,
    rotation: Int,
    selectedSearchMatch: SearchMatch?,
    searchProjectionState: Binding<SearchProjectionState>,
    selectedCandidate: RegionCandidate?,
    selectedField: NativeField?,
    isManualPlacementMode: Bool,
    fillHighlights: [FillHighlight],
    activeInlineEditor: InlineEditorState?,
    applyPresentationOperation: @escaping (EditOperation, PDFDocument) -> Bool,
    onManualPlacement: @escaping (Int, CGPoint) -> Void,
    onDirectEdit: @escaping (Int, CGPoint) -> Void,
    onPageTap: @escaping (Int, CGPoint) -> Void,
    onCommitInlineEditor: @escaping (String) -> Void,
    onDismissInlineEditor: @escaping () -> Void
  ) {
    self.document = document
    self.projectionRevision = projectionRevision
    self.operations = operations
    self.pageIndex = pageIndex
    self.viewMode = viewMode
    self.scaleMode = scaleMode
    self.zoom = zoom
    self.rotation = rotation
    self.selectedSearchMatch = selectedSearchMatch
    self._searchProjectionState = searchProjectionState
    self.selectedCandidate = selectedCandidate
    self.selectedField = selectedField
    self.isManualPlacementMode = isManualPlacementMode
    self.fillHighlights = fillHighlights
    self.activeInlineEditor = activeInlineEditor
    self.applyPresentationOperation = applyPresentationOperation
    self.onManualPlacement = onManualPlacement
    self.onDirectEdit = onDirectEdit
    self.onPageTap = onPageTap
    self.onCommitInlineEditor = onCommitInlineEditor
    self.onDismissInlineEditor = onDismissInlineEditor
  }

  private final class ProjectionObserverTokenStore {
    var tokens: [NSObjectProtocol] = []

    deinit {
      let notificationCenter = NotificationCenter.default
      tokens.forEach { notificationCenter.removeObserver($0) }
    }
  }

  @MainActor
  public final class Coordinator {
    weak var sourceDocument: PDFDocument?
    var presentationDocument: PDFDocument?
    var presentationRotation: Int?
    var presentationRevision: UInt64?
    /// Number of ledger operations already applied to the presentation
    /// clone. Anchors the incremental sync so edits never force a full
    /// document copy. Nil when no clone-based anchor exists.
    var presentationOperationCount: Int?
    weak var overlayView: PDFPresentationOverlayView?
    weak var observedRootView: NSView?
    weak var observedScrollContentView: NSView?
    weak var observedDocumentView: NSView?
    weak var inlineEditorHostView: NSView?
    private let projectionObserverTokenStore = ProjectionObserverTokenStore()
    var lastNavigatedPageIndex: Int?
    var lastSearchSignature: String?
    var lastScaleSignature: String?
    var lastDisplayMode: PDFDisplayMode?
    var didForceInitialLayout = false

    func invalidateOverlay() {
      overlayView?.invalidateProjection()
    }

    func removeProjectionObservers() {
      let notificationCenter = NotificationCenter.default
      projectionObserverTokenStore.tokens.forEach { notificationCenter.removeObserver($0) }
      projectionObserverTokenStore.tokens.removeAll()
      observedRootView = nil
      observedScrollContentView = nil
      observedDocumentView = nil
    }

    func installProjectionObservers(for view: InteractivePDFView) {
      let scrollContentView = view.enclosingScrollView?.contentView
      let documentView = view.documentView
      if observedRootView === view,
        observedScrollContentView === scrollContentView,
        observedDocumentView === documentView,
        !projectionObserverTokenStore.tokens.isEmpty
      {
        return
      }

      removeProjectionObservers()
      observedRootView = view
      observedScrollContentView = scrollContentView
      observedDocumentView = documentView

      var observedViews: [NSView] = [view]
      if let scrollContentView {
        observedViews.append(scrollContentView)
      }
      if let documentView {
        observedViews.append(documentView)
      }
      observedViews.forEach { observedView in
        observedView.postsBoundsChangedNotifications = true
        observedView.postsFrameChangedNotifications = true
        let notificationCenter = NotificationCenter.default
        for name in [
          NSView.boundsDidChangeNotification,
          NSView.frameDidChangeNotification,
        ] {
          projectionObserverTokenStore.tokens.append(
            notificationCenter.addObserver(
              forName: name,
              object: observedView,
              queue: .main
            ) { [weak self] _ in
              Task { @MainActor [weak self] in
                self?.invalidateOverlay()
              }
            }
          )
        }
      }

      let notificationCenter = NotificationCenter.default
      for name in [
        Notification.Name("PDFViewScaleChanged"),
        Notification.Name("PDFViewDisplayModeChanged"),
      ] {
        projectionObserverTokenStore.tokens.append(
          notificationCenter.addObserver(forName: name, object: view, queue: .main) {
            [weak self] _ in
            Task { @MainActor [weak self] in
              self?.invalidateOverlay()
            }
          }
        )
      }
    }
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  public func makeNSView(context: Context) -> InteractivePDFView {
    let view = InteractivePDFView()
    view.autoScales = false
    view.displayMode = .singlePageContinuous
    view.displayBox = .cropBox
    view.backgroundColor = .windowBackgroundColor
    view.onManualPlacement = onManualPlacement
    view.onDirectEdit = onDirectEdit
    view.onPageTap = onPageTap

    let overlayView = PDFPresentationOverlayView(frame: view.bounds)
    overlayView.autoresizingMask = [.width, .height]
    overlayView.wantsLayer = true
    view.addSubview(overlayView)
    context.coordinator.overlayView = overlayView
    view.onProjectionInvalidated = { @MainActor [weak coordinator = context.coordinator] in
      coordinator?.invalidateOverlay()
    }
    context.coordinator.installProjectionObservers(for: view)
    return view
  }

  public func updateNSView(_ view: InteractivePDFView, context: Context) {
    if context.coordinator.sourceDocument !== document
      || context.coordinator.presentationRotation != rotation
      || context.coordinator.presentationRevision != projectionRevision
    {
      context.coordinator.sourceDocument = document
      context.coordinator.presentationRotation = rotation
      context.coordinator.presentationRevision = projectionRevision
      context.coordinator.lastNavigatedPageIndex = nil
      context.coordinator.lastSearchSignature = nil

      if let document,
        let presentationDocument = document.copy() as? PDFDocument
      {
        for pageNumber in 0..<presentationDocument.pageCount {
          presentationDocument.page(at: pageNumber)?.rotation = rotation
        }
        context.coordinator.presentationDocument = presentationDocument
        view.document = presentationDocument
      } else {
        context.coordinator.presentationDocument = document
        view.document = document
      }
    } else if view.document !== context.coordinator.presentationDocument {
      view.document = context.coordinator.presentationDocument
    }

    view.isManualPlacementMode = isManualPlacementMode
    view.onManualPlacement = onManualPlacement
    view.onDirectEdit = onDirectEdit
    view.onPageTap = onPageTap
    view.onProjectionInvalidated = { @MainActor [weak coordinator = context.coordinator] in
      coordinator?.invalidateOverlay()
    }
    context.coordinator.installProjectionObservers(for: view)
    if !context.coordinator.didForceInitialLayout {
      context.coordinator.didForceInitialLayout = true
      view.needsLayout = true
      view.layoutSubtreeIfNeeded()
    }

    let nextDisplayMode: PDFDisplayMode
    switch viewMode {
    case .singlePage:
      nextDisplayMode = .singlePage
    case .continuous:
      nextDisplayMode = .singlePageContinuous
    case .twoPage:
      nextDisplayMode = .twoUp
    }
    if view.displayMode != nextDisplayMode {
      view.displayMode = nextDisplayMode
    }

    view.autoScales = false
    let pageWidth = document?.page(at: pageIndex)?.bounds(for: .cropBox).width ?? 612
    view.requestedScaleMode = scaleMode
    view.requestedRowWidth = viewMode == .twoPage ? pageWidth * 2 + 18 : pageWidth
    view.requestedZoom = CGFloat(zoom)
    let scaleSignature = "\(scaleMode)|\(zoom)|\(view.requestedRowWidth)"
    if context.coordinator.lastScaleSignature != scaleSignature {
      context.coordinator.lastScaleSignature = scaleSignature
      view.applyRequestedScale()
    }
    context.coordinator.invalidateOverlay()

    var highlights: [PDFPresentationHighlight] = []

    if !fillHighlights.isEmpty {
      for highlight in fillHighlights {
        if let page = view.document?.page(at: highlight.pageIndex) {
          let kind: PDFPresentationHighlight.Kind
          switch highlight.state {
          case .nativeField: kind = .field
          case .candidateUnfilled: kind = .candidateUnfilled
          case .candidateFilled: kind = .candidateFilled
          case .signatureRegion: kind = .signatureRegion
          case .focused: kind = .focused
          case .outsideRegionChange: kind = .outsideRegionChange
          case .insideRegionChange: kind = .insideRegionChange
          case .preserved: kind = .preserved
          }
          highlights.append(
            PDFPresentationHighlight(
              kind: kind,
              page: page,
              bounds: highlight.bounds.cgRect,
              label: (highlight.label?.isEmpty == false) ? highlight.label : nil
            )
          )
        }
      }
    } else if let selectedCandidate,
      let page = view.document?.page(at: selectedCandidate.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: selectedCandidate.entryMode == .characterGrid ? .characterGrid : .candidate,
          page: page,
          bounds: selectedCandidate.bounds.cgRect,
          memberBounds: selectedCandidate.entryMode == .characterGrid
            ? selectedCandidate.memberBounds.map(\.cgRect)
            : [],
          label: suggestionName(for: selectedCandidate)
        )
      )
    } else if let selectedField,
      let page = view.document?.page(at: selectedField.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: .field,
          page: page,
          bounds: selectedField.bounds.cgRect,
          label: selectedField.name
        )
      )
    }

    if let document = view.document {
      if context.coordinator.lastNavigatedPageIndex != pageIndex,
        let page = document.page(at: pageIndex)
      {
        view.go(to: page)
        context.coordinator.lastNavigatedPageIndex = pageIndex
      }

      if let selectedSearchMatch {
        let projection = searchProjection(for: selectedSearchMatch, in: document)
        searchProjectionState = projection.state
        if let selection = projection.selection,
          let page = document.page(at: selectedSearchMatch.pageIndex)
        {
          let signature = searchSignature(for: selectedSearchMatch)
          if context.coordinator.lastSearchSignature != signature {
            context.coordinator.lastSearchSignature = signature
          }
          highlights.append(
            PDFPresentationHighlight(
              kind: .search,
              page: page,
              bounds: selection.bounds(for: page)
            )
          )
          view.currentSelection = nil
        } else {
          if context.coordinator.lastSearchSignature != nil {
            view.currentSelection = nil
            context.coordinator.lastSearchSignature = nil
          }
        }
      } else {
        searchProjectionState = .none
        if context.coordinator.lastSearchSignature != nil {
          view.currentSelection = nil
          context.coordinator.lastSearchSignature = nil
        }
      }
    } else {
      searchProjectionState = .none
      context.coordinator.lastNavigatedPageIndex = nil
      context.coordinator.lastSearchSignature = nil
    }

    context.coordinator.overlayView?.highlights = highlights
    context.coordinator.invalidateOverlay()

    // Inline Canvas Text Editor Host
    if let inlineEditor = activeInlineEditor,
       let page = view.document?.page(at: inlineEditor.target.pageIndex) {
      let pageBounds = inlineEditor.target.bounds.cgRect
      let viewBounds = view.convert(pageBounds, from: page)

      let hostView: InlineEditorTextFieldHost
      if let existing = context.coordinator.inlineEditorHostView as? InlineEditorTextFieldHost {
        hostView = existing
      } else {
        context.coordinator.inlineEditorHostView?.removeFromSuperview()
        let newHost = InlineEditorTextFieldHost(
          onCommit: { text in onCommitInlineEditor(text) },
          onDismiss: { onDismissInlineEditor() }
        )
        view.addSubview(newHost)
        context.coordinator.inlineEditorHostView = newHost
        hostView = newHost
      }

      let editorFrame = CGRect(
        x: max(8, viewBounds.origin.x),
        y: max(8, viewBounds.origin.y),
        width: max(140, viewBounds.size.width),
        height: max(28, viewBounds.size.height)
      )
      hostView.frame = editorFrame
      if !hostView.isDescendant(of: view) {
        view.addSubview(hostView)
      }
      hostView.setLabel(inlineEditor.label ?? "")
      hostView.updateText(inlineEditor.draftText)
      hostView.isHidden = false
      if view.window?.firstResponder !== hostView.textField,
        hostView.textField.currentEditor() == nil
      {
        view.window?.makeFirstResponder(hostView.textField)
      }
    } else {
      context.coordinator.inlineEditorHostView?.removeFromSuperview()
      context.coordinator.inlineEditorHostView = nil
    }
  }

  /// Keeps the rotated presentation clone in sync with the live document.
  ///
  /// The previous policy deep-copied the entire PDF on every projection
  /// revision, which put a full-document clone on each edit click — a main
  /// thread hang proportional to page count. The clone is now rebuilt only
  /// when document identity changes (open, undo/redo replay). Rotation is
  /// reapplied in place, and newly recorded operations are applied to the
  /// clone as a ledger delta. A revision bump the ledger cannot explain, or a
  /// delta operation that fails to apply, falls back to a full rebuild from
  /// ground truth.
  private func syncPresentationDocument(
    view: InteractivePDFView,
    context: Context,
    document: PDFDocument?,
    rotation: Int,
    projectionRevision: UInt64,
    operations: [EditOperation]
  ) {
    let coordinator = context.coordinator

    func rebuildPresentationDocument() {
      coordinator.sourceDocument = document
      coordinator.presentationRotation = rotation
      coordinator.presentationRevision = projectionRevision
      coordinator.lastNavigatedPageIndex = nil
      coordinator.lastSearchSignature = nil
      if let document,
        let presentationDocument = document.copy() as? PDFDocument
      {
        for pageNumber in 0..<presentationDocument.pageCount {
          presentationDocument.page(at: pageNumber)?.rotation = rotation
        }
        coordinator.presentationDocument = presentationDocument
        coordinator.presentationOperationCount = operations.count
        view.document = presentationDocument
      } else {
        coordinator.presentationDocument = document
        coordinator.presentationOperationCount = nil
        view.document = document
      }
    }

    if coordinator.sourceDocument !== document {
      rebuildPresentationDocument()
      return
    }

    if coordinator.presentationRotation != rotation {
      coordinator.presentationRotation = rotation
      if let presentationDocument = coordinator.presentationDocument,
        presentationDocument !== document
      {
        // Rotation is presentation state on the clone; reapply it in place
        // instead of rebuilding the clone.
        for pageNumber in 0..<presentationDocument.pageCount {
          presentationDocument.page(at: pageNumber)?.rotation = rotation
        }
      }
    }

    guard coordinator.presentationRevision != projectionRevision else { return }

    // The revision advanced without the document identity changing. The
    // preferred explanation is ledger growth: apply only the delta.
    if let presentationDocument = coordinator.presentationDocument,
      document == nil || presentationDocument !== document,
      let appliedCount = coordinator.presentationOperationCount,
      appliedCount >= 0, appliedCount <= operations.count
    {
      for operation in operations[appliedCount...] {
        // The clone diverged (an operation no longer applies cleanly); fall
        // back to ground truth rather than rendering a stale projection.
        guard applyPresentationOperation(operation, presentationDocument) else {
          rebuildPresentationDocument()
          return
        }
      }
      coordinator.presentationOperationCount = operations.count
      coordinator.presentationRevision = projectionRevision
      return
    }

    // No ledger anchor explains the bump: an in-place mutation bypassed the
    // ledger. Rebuild from the live document.
    rebuildPresentationDocument()
  }

  /// Display-name fallback chain shared by every suggestion surface.
  private func suggestionName(for candidate: RegionCandidate) -> String {
    candidate.displayName
      ?? FieldLabelCanonicalizer.displayName(
        labelText: candidate.labelText,
        fieldType: candidate.suggestedFieldType,
        entryMode: candidate.entryMode,
        groupMemberCount: candidate.groupMemberCount)
  }

  private func searchSignature(for match: SearchMatch) -> String {
    "\(match.id)|page:\(match.pageIndex)|start:\(match.charStart)|length:\(match.charLength)"
  }

  private func searchProjection(
    for match: SearchMatch,
    in document: PDFDocument
  ) -> (selection: PDFSelection?, state: SearchProjectionState) {
    guard let page = document.page(at: match.pageIndex) else {
      return (nil, .unavailable)
    }
    // The match's character range is page-relative (search scans page.string),
    // so the exact selection is available locally. The previous projection
    // ran `document.findString` over every page on each view update, which
    // re-searched the whole document for one already-known range.
    guard
      let selection = page.selection(
        for: NSRange(location: match.charStart, length: match.charLength))
    else {
      return (nil, .unavailable)
    }
    if selection.bounds(for: page).isEmpty {
      return (selection, .approximate)
    }
    return (selection, .exact)
  }
}
