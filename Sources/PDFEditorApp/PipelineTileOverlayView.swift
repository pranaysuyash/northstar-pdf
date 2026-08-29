import AppKit
import PDFEditorCore

/// NSView that composites pipeline-rendered tiles as CALayers above PDFKit.
///
/// Architecture (1st principles):
/// - PDFKit renders invisibly (zPosition 0) — needed for text selection, links, annotations
/// - This overlay renders pipeline tiles on top (zPosition 50) — the visible pixels
/// - The pipeline is the *intended* sole visual renderer; PDFKit is the interaction layer
///
/// The overlay:
/// 1. On page change: calls `getViewportTiles()` to get tiles for the visible area
/// 2. Composites each tile's `imageData` as a `CALayer` positioned in page coordinates
/// 3. Updates on scroll (visible rect changes) and zoom (scale changes)
/// 4. Progressive quality: tiles start at low DPI, upgrade to medium, then high
///
/// Doctrine alignment:
/// - §3: Do things smartly — pipeline handles rendering, PDFKit handles interaction
/// - §5: Evidence-based — tile render times tracked in PageTile.renderTimeMs
/// - §8: Capability routing — different DPI for different zoom levels
/// - §12: Privacy stays value-free — overlay never inspects content, just positions
public final class PipelineTileOverlayView: NSView {
    /// The rendering pipeline (sole source of rendered pixels).
    public weak var renderingPipeline: RenderingPipeline?
    
    /// Current page index.
    public var currentPageIndex: Int = 0 {
        didSet { if currentPageIndex != oldValue { reloadTiles() } }
    }
    
    /// Current zoom scale (from PDFKit's scaleFactor).
    public var currentScale: CGFloat = 1.0 {
        didSet { if abs(currentScale - oldValue) > 0.001 { reloadTiles() } }
    }
    
    /// Current viewport rect in page coordinates (not NSView.visibleRect).
    public var viewportRect: CGRect = .zero {
        didSet { if viewportRect != oldValue { reloadTiles() } }
    }
    
    /// Tile layers currently displayed.
    private var tileLayers: [String: CALayer] = [:]
    
    /// Container layer for all tiles.
    private var tileContainer: CALayer?
    
    /// Whether a tile reload is in progress.
    private var isReloading = false
    
    /// Debounce timer for scroll/zoom updates.
    private var reloadTimer: Timer?
    
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
        layer?.masksToBounds = true
        
        let container = CALayer()
        container.name = "tile-container"
        layer?.addSublayer(container)
        tileContainer = container
    }
    
    // MARK: - Public API
    
    /// Reload tiles for the current page and visible rect.
    public func reloadTiles() {
        guard let pipeline = renderingPipeline else {
            clearTiles()
            return
        }
        
        // Debounce rapid updates (scroll/zoom)
        reloadTimer?.invalidate()
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            self?.performTileReload(pipeline: pipeline)
        }
    }
    
    /// Force an immediate tile reload (bypasses debounce).
    public func forceReload() {
        reloadTimer?.invalidate()
        guard let pipeline = renderingPipeline else {
            clearTiles()
            return
        }
        performTileReload(pipeline: pipeline)
    }
    
    // MARK: - Tile Rendering
    
    private func performTileReload(pipeline: RenderingPipeline) {
        guard !isReloading else { return }
        isReloading = true
        
        let tiles = pipeline.getViewportTiles(
            pageIndex: currentPageIndex,
            visibleRect: visibleRect,
            scale: currentScale
        )
        
        // Collect new tile IDs
        let newIDs = Set(tiles.map(\.id))
        
        // Remove tiles no longer in viewport
        for (id, layer) in tileLayers where !newIDs.contains(id) {
            layer.removeFromSuperlayer()
            tileLayers.removeValue(forKey: id)
        }
        
        // Add or update tiles
        for tile in tiles {
            if let existingLayer = tileLayers[tile.id] {
                // Update existing tile if image changed
                if let image = NSImage(data: tile.imageData) {
                    existingLayer.contents = image
                }
            } else {
                // Create new tile layer
                guard let image = NSImage(data: tile.imageData) else { continue }
                
                let tileLayer = CALayer()
                tileLayer.name = "tile-\(tile.id)"
                tileLayer.contents = image
                tileLayer.frame = tile.bounds
                tileLayer.contentsGravity = .resizeAspect
                tileLayer.masksToBounds = true
                
                tileContainer?.addSublayer(tileLayer)
                tileLayers[tile.id] = tileLayer
            }
        }
        
        isReloading = false
    }
    
    /// Clear all tile layers.
    private func clearTiles() {
        tileLayers.values.forEach { $0.removeFromSuperlayer() }
        tileLayers.removeAll()
    }
    
    // MARK: - Layout
    
    public override func layout() {
        super.layout()
        tileContainer?.frame = bounds
    }
    

}
