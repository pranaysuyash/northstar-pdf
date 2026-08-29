import AppKit
import PDFEditorCore
import PDFEditorRecovery
import PDFKit
import SwiftUI

/// 1st principles rendering: pipeline as sole pixel source.
///
/// Architecture:
/// ```
/// PipelineCanvasView (NSViewRepresentable)
///   └── NSScrollView (zoom, scroll)
///         └── PipelinePageView (pipeline renders pages as images)
///               ├── CALayer (pipeline tile images)
///               └── InteractionOverlayView (text selection, links)
///                     └── reads: pipeline TextBlock extraction
///                           └── PDFKit: demoted to data source (text rects, link URLs)
/// ```
///
/// Doctrine alignment:
/// - §3: Do things smartly — pipeline handles rendering, PDFKit handles data
/// - §5: Evidence-based — every render is measurable
/// - §8: Capability routing — different quality for different zoom levels
/// - §12: Privacy stays value-free — overlay never inspects content, just positions
public struct PipelineCanvasView: NSViewRepresentable {
    public let document: PDFDocument?
    public let renderingPipeline: RenderingPipeline
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
    public let onTextSelectionChanged: ((String, PDFRect, Int) -> Void)?
    public let onSelectionCleared: (() -> Void)?

    public init(
        document: PDFDocument?,
        renderingPipeline: RenderingPipeline,
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
        onDismissInlineEditor: @escaping () -> Void,
        onTextSelectionChanged: ((String, PDFRect, Int) -> Void)? = nil,
        onSelectionCleared: (() -> Void)? = nil
    ) {
        self.document = document
        self.renderingPipeline = renderingPipeline
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
        self.onTextSelectionChanged = onTextSelectionChanged
        self.onSelectionCleared = onSelectionCleared
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        // Create the pipeline page view
        let pageView = PipelinePageView(frame: .zero)
        pageView.renderingPipeline = renderingPipeline
        pageView.pageIndex = pageIndex
        pageView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = pageView
        context.coordinator.pageView = pageView
        context.coordinator.scrollView = scrollView
        context.coordinator.renderingPipeline = renderingPipeline

        // Set up the document
        if let document, let data = document.dataRepresentation() {
            let docID = document.documentURL?.lastPathComponent ?? "unknown"
            Task {
                _ = try? await renderingPipeline.loadDocument(data: data, documentID: docID)
                // Warm cache for first pages
                renderingPipeline.warmUpPages(
                    pageIndexes: Array(0..<min(8, document.pageCount)),
                    dpi: 72
                )
                // Restore reading position
                if let position = renderingPipeline.getReadingPosition(documentID: docID) {
                    if position.pageIndex < document.pageCount {
                        context.coordinator.navigateToPage(position.pageIndex)
                    }
                }
            }
        }

        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let pageView = context.coordinator.pageView else { return }

        // Update page if changed
        if pageView.pageIndex != pageIndex {
            context.coordinator.navigateToPage(pageIndex)
        }

        // Update scale
        let targetScale = computeScale(
            for: scrollView,
            scaleMode: scaleMode,
            zoom: zoom,
            pageView: pageView
        )
        if abs(pageView.scaleFactor - targetScale) > 0.001 {
            pageView.scaleFactor = targetScale
        }

        // Update available width for quality selection
        pageView.availableWidth = scrollView.bounds.width
    }

    private func computeScale(
        for scrollView: NSScrollView,
        scaleMode: ReaderScaleMode,
        zoom: Double,
        pageView: PipelinePageView
    ) -> CGFloat {
        let pageWidth: CGFloat = 612 // nominal PDF page width
        switch scaleMode {
        case .fitWidth:
            let availableWidth = max(240, scrollView.bounds.width - 28)
            return min(3.0, max(0.25, availableWidth / pageWidth))
        case .fitPage:
            let availableHeight = max(400, scrollView.bounds.height - 28)
            let scaleW = scrollView.bounds.width / pageWidth
            let scaleH = availableHeight / 792
            return min(scaleW, scaleH) * 0.95
        case .zoom:
            return CGFloat(zoom)
        }
    }

    // MARK: - Coordinator

    public final class Coordinator {
        weak var pageView: PipelinePageView?
        weak var scrollView: NSScrollView?
        var renderingPipeline: RenderingPipeline?

        func navigateToPage(_ pageIndex: Int) {
            pageView?.pageIndex = pageIndex
        }
    }
}

// MARK: - Enhanced PipelinePageView with proper interaction

/// Enhanced pipeline page view with text selection, link detection, and annotations.
///
/// The pipeline renders pages as images. This view:
/// 1. Renders via `renderPageProgressive()` — low→medium→high quality
/// 2. Composites tiles as CALayers for smooth scrolling
/// 3. Provides interaction overlay for text selection and link clicks
/// 4. Reads text blocks from pipeline's extraction for hit-testing
public final class PipelineRenderView: NSView {
    /// The rendering pipeline (sole source of rendered pixels).
    public var renderingPipeline: RenderingPipeline?

    /// Current page index.
    public var pageIndex: Int = 0 {
        didSet { if pageIndex != oldValue { reloadPage() } }
    }

    /// Available width for rendering (determines quality level).
    public var availableWidth: CGFloat = 800 {
        didSet { if abs(availableWidth - oldValue) > 1 { reloadPage() } }
    }

    /// Scale factor for rendering.
    public var scaleFactor: CGFloat = 1.0 {
        didSet { if abs(scaleFactor - oldValue) > 0.001 { reloadPage() } }
    }

    /// Interaction callbacks.
    public var onManualPlacement: ((Int, CGPoint) -> Void)?
    public var onDirectEdit: ((Int, CGPoint) -> Void)?
    public var onPageTap: ((Int, CGPoint) -> Void)?
    public var onTextSelectionChanged: ((String, PDFRect, Int) -> Void)?
    public var onSelectionCleared: (() -> Void)?
    public var isManualPlacementMode = false

    /// Current rendered page image.
    private var currentImage: NSImage?
    /// Image layer for compositing.
    private var imageLayer: CALayer?
    /// Text blocks for hit-testing.
    private var textBlocks: [TextBlock] = []
    /// Selection highlight layer.
    private var selectionLayer: CALayer?
    /// Selection start point in page coordinates.
    private var selectionStart: CGPoint?
    /// Progressive rendering state.
    private var isProgressiveRendering = false

    public override var isFlipped: Bool { false }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor

        let imgLayer = CALayer()
        imgLayer.name = "pipeline-render"
        imgLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imgLayer)
        imageLayer = imgLayer
    }

    // MARK: - Page Rendering

    public func reloadPage() {
        guard let pipeline = renderingPipeline else { return }

        currentImage = nil
        imageLayer?.contents = nil
        isProgressiveRendering = true

        // Extract text blocks for this page
        if let extraction = try? pipeline.extractText() {
            textBlocks = extraction.blocks
        } else {
            textBlocks = []
        }

        // Progressive render: low → medium → high
        pipeline.renderPageProgressive(
            pageIndex: pageIndex,
            availableWidth: availableWidth
        ) { [weak self] page in
            guard let self, let page else { return }
            self.applyRenderedPage(page)
        }
    }

    private func applyRenderedPage(_ page: RenderedPage) {
        guard let nsImage = NSImage(data: page.imageData) else { return }

        currentImage = nsImage

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        imageLayer?.contents = nsImage
        imageLayer?.frame = bounds
        CATransaction.commit()

        if page.level == .high {
            isProgressiveRendering = false
        }
    }

    // MARK: - Interaction

    public override func mouseDown(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let pagePoint = viewPoint // In pipeline coordinates, view == page

        if isManualPlacementMode {
            onManualPlacement?(pageIndex, pagePoint)
            return
        }

        if event.clickCount >= 2 {
            onDirectEdit?(pageIndex, pagePoint)
            return
        }

        // Hit test against text blocks for selection
        for block in textBlocks {
            let blockRect = CGRect(
                x: block.bounds.x,
                y: block.bounds.y,
                width: block.bounds.width,
                height: block.bounds.height
            )
            if blockRect.contains(pagePoint) {
                selectionStart = pagePoint
                showSelection(for: block)
                return
            }
        }

        // No hit — clear selection, fire page tap
        clearSelection()
        onPageTap?(pageIndex, pagePoint)
    }

    public override func mouseUp(with event: NSEvent) {
        guard let start = selectionStart else {
            super.mouseUp(with: event)
            return
        }

        let end = convert(event.locationInWindow, from: nil)
        selectionStart = nil

        // Select all text blocks between start and end
        let selectionRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        if selectionRect.width > 2 && selectionRect.height > 2 {
            let selectedBlocks = textBlocks.filter { block in
                let blockRect = CGRect(
                    x: block.bounds.x,
                    y: block.bounds.y,
                    width: block.bounds.width,
                    height: block.bounds.height
                )
                return selectionRect.intersects(blockRect)
            }

            if !selectedBlocks.isEmpty {
                let selectedText = selectedBlocks.map(\.text).joined(separator: " ")
                let combinedBounds = selectedBlocks.reduce(selectedBlocks[0].bounds) { acc, block in
                    PDFRect(
                        x: min(acc.x, block.bounds.x),
                        y: min(acc.y, block.bounds.y),
                        width: max(acc.x + acc.width, block.bounds.x + block.bounds.width) - min(acc.x, block.bounds.x),
                        height: max(acc.y + acc.height, block.bounds.y + block.bounds.height) - min(acc.y, block.bounds.y)
                    )
                }
                onTextSelectionChanged?(selectedText, combinedBounds, pageIndex)
                showSelectionRect(selectionRect)
                return
            }
        }

        // Empty selection
        clearSelection()
        onSelectionCleared?()
    }

    // MARK: - Selection Rendering

    private func showSelection(for block: TextBlock) {
        selectionLayer?.removeFromSuperlayer()

        let highlight = CALayer()
        highlight.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        highlight.frame = CGRect(
            x: block.bounds.x,
            y: block.bounds.y,
            width: block.bounds.width,
            height: block.bounds.height
        )
        highlight.cornerRadius = 2
        layer?.addSublayer(highlight)
        selectionLayer = highlight

        onTextSelectionChanged?(block.text, block.bounds, pageIndex)
    }

    private func showSelectionRect(_ rect: CGRect) {
        selectionLayer?.removeFromSuperlayer()

        let highlight = CALayer()
        highlight.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
        highlight.frame = rect
        highlight.cornerRadius = 2
        layer?.addSublayer(highlight)
        selectionLayer = highlight
    }

    private func clearSelection() {
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
        selectionStart = nil
        onSelectionCleared?()
    }

    // MARK: - Layout

    public override func layout() {
        super.layout()
        imageLayer?.frame = bounds
    }
}
