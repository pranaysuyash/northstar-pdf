import PDFEditorCore
import AppKit
import PDFKit

/// 1st principles page rendering: the pipeline is the *intended* sole renderer.
///
/// PDFKit is demoted to a data source (text rects, link URLs, annotation data).
/// All pixel output comes from the rendering pipeline's `RenderedPage` objects.
///
/// ARCHITECTURE STATUS (truth-status: PROPOSED — not yet wired in):
/// ```
/// PipelinePageView (intended sole renderer)
///   └── renderPageProgressive() → RenderedPage.imageData → NSImage
///       └── InteractionOverlay (text selection, links, annotations)
///             └── reads: pipeline text extraction + PDFKit metadata
/// ```
/// NOTE: As of 2026-08-28 this view is NOT yet integrated into `DocumentCanvasView`,
/// which still renders via `PDFKitView` (`InteractivePDFView: PDFView`). The tiling/
/// progressive capability is implemented here but currently orphaned. Wiring it in
/// (replacing the PDFKit render surface) is the outstanding first-principles improvement
/// (see decision D-058). Until then, the "sole renderer" claim is aspirational, not current.
///
/// Doctrine alignment (target state):
/// - §3: Do things smartly — pipeline handles rendering, PDFKit handles data
/// - §5: Evidence-based — every render is measurable (time, quality, cache hits)
/// - §12: Privacy stays value-free — overlay never inspects content, just positions

/// Custom view that renders PDF pages using the rendering pipeline as sole renderer.
public final class PipelinePageView: NSView {
    /// The rendering pipeline (sole source of rendered pixels).
    public var renderingPipeline: RenderingPipeline?
    /// Current page index.
    public var pageIndex: Int = 0 { didSet { if pageIndex != oldValue { reloadPage() } }
    }
    /// Available width for rendering (determines quality level).
    public var availableWidth: CGFloat = 800
    /// Scale factor for rendering.
    public var scaleFactor: CGFloat = 1.0 { didSet { if scaleFactor != oldValue { reloadPage() } } }

    /// Current rendered page image.
    private var currentImage: NSImage?
    /// Current rendered page metadata.
    private var currentRenderedPage: RenderedPage?
    /// Image layer for compositing.
    private var imageLayer: CALayer?
    /// Interaction overlay for text selection and links.
    private var interactionOverlay: InteractionOverlayView?
    /// Whether progressive rendering is in progress.
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

        // Image layer for pipeline output
        let imgLayer = CALayer()
        imgLayer.name = "pipeline-render"
        imgLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imgLayer)
        imageLayer = imgLayer

        // Interaction overlay
        let overlay = InteractionOverlayView(frame: bounds)
        overlay.autoresizingMask = [.width, .height]
        addSubview(overlay)
        interactionOverlay = overlay
    }

    /// Reload the current page from the pipeline.
    public func reloadPage() {
        guard let pipeline = renderingPipeline else { return }

        // Clear current image
        currentImage = nil
        imageLayer?.contents = nil

        // Progressive render: low → medium → high
        isProgressiveRendering = true

        pipeline.renderPageProgressive(
            pageIndex: pageIndex,
            availableWidth: availableWidth
        ) { [weak self] page in
            guard let self, let page else { return }
            self.applyRenderedPage(page)
        }
    }

    /// Apply a rendered page to the view.
    private func applyRenderedPage(_ page: RenderedPage) {
        guard let nsImage = NSImage(data: page.imageData) else { return }

        currentRenderedPage = page
        currentImage = nsImage

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        imageLayer?.contents = nsImage
        imageLayer?.frame = bounds
        CATransaction.commit()

        // Update interaction overlay with new page data
        interactionOverlay?.updateForPage(
            pageIndex: pageIndex,
            renderingPipeline: renderingPipeline,
            imageSize: CGSize(width: page.width, height: page.height)
        )

        if page.level == .high {
            isProgressiveRendering = false
        }
    }

    public override func layout() {
        super.layout()
        imageLayer?.frame = bounds
        interactionOverlay?.frame = bounds
    }


}

/// Interaction overlay that handles text selection, link detection, and annotations.
///
/// Reads from the pipeline's text extraction and PDFKit's metadata.
/// Does NOT render — just handles input and highlights.
public final class InteractionOverlayView: NSView {
    /// The rendering pipeline for text data.
    private weak var renderingPipeline: RenderingPipeline?
    /// Current page index.
    private var pageIndex: Int = 0
    /// Extracted text blocks for hit testing.
    private var textBlocks: [TextBlock] = []
    /// Selected text range.
    private var selectionRange: (start: Int, end: Int)?
    /// Selection highlight layer.
    private var selectionLayer: CALayer?

    public override var isFlipped: Bool { false }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    /// Update for a new page.
    public func updateForPage(
        pageIndex: Int,
        renderingPipeline: RenderingPipeline?,
        imageSize: CGSize
    ) {
        self.pageIndex = pageIndex
        self.renderingPipeline = renderingPipeline

        // Extract text blocks for this page
        if let extraction = try? renderingPipeline?.extractText() {
            // Map blocks to this page (simplified — blocks don't carry page index in current model)
            self.textBlocks = extraction.blocks
        }

        // Clear selection
        selectionRange = nil
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
    }

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Hit test against text blocks
        for (index, block) in textBlocks.enumerated() {
            let blockRect = CGRect(
                x: block.bounds.x,
                y: block.bounds.y,
                width: block.bounds.width,
                height: block.bounds.height
            )
            if blockRect.contains(point) {
                selectionRange = (start: index, end: index)
                showSelection(for: block)
                return
            }
        }

        // No hit — clear selection
        selectionRange = nil
        selectionLayer?.removeFromSuperlayer()
        selectionLayer = nil
    }

    /// Show a selection highlight for a text block.
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
    }
}
