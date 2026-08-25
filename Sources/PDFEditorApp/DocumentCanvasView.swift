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

  public init(
    model: AppModel,
    inspection: DocumentInspection,
    searchProjectionState: Binding<SearchProjectionState>
  ) {
    self.model = model
    self.inspection = inspection
    self._searchProjectionState = searchProjectionState
  }

  public var body: some View {
    ZStack(alignment: .bottomTrailing) {
      pdfCanvas
      floatingCanvasHUD
        .padding(16)
    }
    .frame(minWidth: 480)
  }

  private var pdfCanvas: some View {
    PDFKitView(
      document: model.liveDocument,
      projectionRevision: model.documentProjectionRevision,
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
      return "Selected suggested area on page \(candidate.pageIndex + 1), \(candidate.entryMode.rawValue)"
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
          .font(.system(size: 11, weight: .bold))
      }
      .buttonStyle(.plain)

      Text("\(Int(model.readerZoom * 100))%")
        .font(.system(size: 11, weight: .semibold).monospacedDigit())
        .frame(width: 38)

      Button {
        model.setZoom(min(3.0, model.readerZoom + 0.1))
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .bold))
      }
      .buttonStyle(.plain)

      Divider()
        .frame(height: 12)

      Button {
        model.rotateLeft()
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 11))
      }
      .buttonStyle(.plain)
      .help("Rotate Left 90°")

      Button {
        model.rotateRight()
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 11))
      }
      .buttonStyle(.plain)
      .help("Rotate Right 90°")
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial)
    .clipShape(Capsule())
    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    .overlay(
      Capsule()
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
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

  public init(kind: Kind, page: PDFPage, bounds: CGRect, memberBounds: [CGRect] = []) {
    self.kind = kind
    self.page = page
    self.bounds = bounds
    self.memberBounds = memberBounds
  }
}

// MARK: - Inline Editor TextField Host
public final class InlineEditorTextFieldHost: NSView, NSTextFieldDelegate {
  public let textField: NSTextField
  public var onCommit: (String) -> Void
  public var onDismiss: () -> Void

  public init(onCommit: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
    self.onCommit = onCommit
    self.onDismiss = onDismiss
    self.textField = NSTextField()
    super.init(frame: .zero)

    wantsLayer = true
    layer?.cornerRadius = 4
    layer?.masksToBounds = true
    layer?.borderColor = NSColor.controlAccentColor.cgColor
    layer?.borderWidth = 1.5
    layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

    textField.isBordered = false
    textField.drawsBackground = false
    textField.font = NSFont.systemFont(ofSize: 13)
    textField.focusRingType = .none
    textField.delegate = self
    textField.autoresizingMask = [.width, .height]
    textField.frame = bounds.insetBy(dx: 4, dy: 2)

    addSubview(textField)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func resizeSubviews(withOldSize oldSize: NSSize) {
    super.resizeSubviews(withOldSize: oldSize)
    textField.frame = bounds.insetBy(dx: 4, dy: 2)
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
    switch requestedScaleMode {
    case .fitWidth:
      let availableWidth = max(240, bounds.width - 28)
      scaleFactor = min(3.0, max(0.25, availableWidth / requestedRowWidth))
    case .fitPage:
      scaleFactor = scaleFactorForSizeToFit * 0.95
    case .zoom:
      scaleFactor = requestedZoom
    }
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
  public let onManualPlacement: (Int, CGPoint) -> Void
  public let onDirectEdit: (Int, CGPoint) -> Void
  public let onPageTap: (Int, CGPoint) -> Void
  public let onCommitInlineEditor: (String) -> Void
  public let onDismissInlineEditor: () -> Void

  public init(
    document: PDFDocument?,
    projectionRevision: UInt64,
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
    onManualPlacement: @escaping (Int, CGPoint) -> Void,
    onDirectEdit: @escaping (Int, CGPoint) -> Void,
    onPageTap: @escaping (Int, CGPoint) -> Void,
    onCommitInlineEditor: @escaping (String) -> Void,
    onDismissInlineEditor: @escaping () -> Void
  ) {
    self.document = document
    self.projectionRevision = projectionRevision
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
    weak var overlayView: PDFPresentationOverlayView?
    weak var observedRootView: NSView?
    weak var observedScrollContentView: NSView?
    weak var observedDocumentView: NSView?
    weak var inlineEditorHostView: NSView?
    private let projectionObserverTokenStore = ProjectionObserverTokenStore()
    var lastNavigatedPageIndex: Int?
    var lastSearchSignature: String?

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
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()

    switch viewMode {
    case .singlePage:
      view.displayMode = .singlePage
    case .continuous:
      view.displayMode = .singlePageContinuous
    case .twoPage:
      view.displayMode = .twoUp
    }

    view.autoScales = false
    let pageWidth = document?.page(at: pageIndex)?.bounds(for: .cropBox).width ?? 612
    view.requestedScaleMode = scaleMode
    view.requestedRowWidth = viewMode == .twoPage ? pageWidth * 2 + 18 : pageWidth
    view.requestedZoom = CGFloat(zoom)
    view.applyRequestedScale()
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
              bounds: highlight.bounds.cgRect
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
            : []
        )
      )
    } else if let selectedField,
      let page = view.document?.page(at: selectedField.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: .field,
          page: page,
          bounds: selectedField.bounds.cgRect
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
      hostView.updateText(inlineEditor.draftText)
      hostView.isHidden = false
      view.window?.makeFirstResponder(hostView.textField)
    } else {
      context.coordinator.inlineEditorHostView?.removeFromSuperview()
      context.coordinator.inlineEditorHostView = nil
    }
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
    let pageMatches = document.findString(match.query, withOptions: [.caseInsensitive]).filter {
      $0.pages.contains(where: { $0 === page }) && !$0.bounds(for: page).isEmpty
    }
    guard !pageMatches.isEmpty else { return (nil, .unavailable) }

    if let exact = pageMatches.first(where: {
      let bounds = $0.bounds(for: page)
      return !bounds.isEmpty
    }) {
      return (exact, .exact)
    }

    return (pageMatches[0], .approximate)
  }
}
