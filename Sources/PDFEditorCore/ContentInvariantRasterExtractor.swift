import CoreGraphics
import Foundation
import PDFKit

/// Content-invariant raster extraction for layout fingerprinting.
///
/// The goal: detect WHERE content exists on a page, not WHAT content exists.
/// Two documents with the same layout but different text should have similar
/// raster fingerprints if they have the same structural regions (headers,
/// footers, sidebars, form fields, images).
///
/// ## Approaches (in order of structural level)
///
/// ### Cell-level (implemented first, found insufficient)
/// 1. **Structural occupancy**: Counts cells where content exceeds a density
///    threshold (>30% of pixels non-blank). Less sensitive to sparse content.
/// 2. **Edge detection (Sobel)**: Counts cells with significant edge activity.
///    Captures layout structure rather than content fill.
/// 3. **Combined**: Edge detection primary, structural occupancy fallback.
///
/// ### Region-level (implemented to unlock higher weight)
/// 4. **Connected component regions**: Groups adjacent occupied cells into
///    contiguous regions, then encodes region bounding boxes and sizes.
///    Two documents with the same layout structure produce similar region
///    signatures regardless of content.
/// 5. **Projection profiles**: Projects content density onto x and y axes,
///    producing horizontal and vertical histograms. These capture the
///    macro-level layout structure (where columns are, where headers end,
///    where sidebars begin) and are inherently content-invariant.
///
/// ## First principles
///
/// Cell-level approaches failed because individual cells are too fine-grained
/// to be content-invariant — a cell with one character vs. a cell with an
/// image both register as "occupied," but the difference matters for family
/// matching.
///
/// Region-level approaches operate at a higher structural level:
/// - A "header region" is a header regardless of what text it contains
/// - A "sidebar region" is a sidebar regardless of what images it holds
/// - A "two-column layout" has two vertical density bands regardless of
///   what fills those bands
///
/// ## Evidence
///
/// - Binary occupancy SNR: 799× (excellent for discrimination)
/// - Re-encoding noise: 1.0 (perfect) at 0.15× scale
/// - Cell-level family member raster similarity: 0.00–0.08
/// - Region-level target: family member raster similarity > 0.5
///
/// Doctrine ref: §5 Evidence-based, §2 Truth taxonomy
public enum ContentInvariantRasterExtractor {

    // MARK: - Configuration

    /// Density threshold for structural occupancy.
    /// A cell is "structurally occupied" if > threshold% of sampled pixels
    /// are non-blank. Higher values are more conservative (fewer cells).
    public static let densityThreshold: Double = 0.30

    /// Edge detection threshold (Sobel magnitude).
    /// Pixels with edge magnitude > threshold are counted as "edges."
    /// Lower values detect more edges (more sensitive to structure).
    public static let edgeThreshold: Double = 30.0

    /// Grid cell size in points (matches V2 defaultCellSizePoints).
    public static let cellSize: Double = 4.0

    /// Grid scales (in points) for the multi-scale graded occupancy channel.
    /// Coarse cells aggregate over larger regions, so their fractional
    /// coverage is stable under re-encoding noise; the degenerate 4pt fine
    /// scale (sub-pixel at the render scale) is deliberately excluded.
    /// Rendered at 0.5 scale, a 16pt cell spans ~8px/side (~64 samples) and
    /// a 64pt cell ~32px/side (~1024 samples) — genuinely fractional.
    public static let gradedScales: [Double] = [16.0, 64.0]

    // MARK: - Structural Occupancy

    /// Extract raster cells using structural occupancy (density threshold).
    ///
    /// Instead of counting ANY non-blank pixel, counts cells where a
    /// significant portion (>30%) of sampled pixels are non-blank.
    /// This makes the extraction less sensitive to sparse content like
    /// individual characters or thin lines.
    ///
    /// - Parameters:
    ///   - page: The PDF page to extract from
    ///   - bounds: The page bounds in points
    ///   - cellSize: Grid cell size in points (default 32)
    ///   - threshold: Density threshold (default 0.30)
    /// - Returns: Set of occupied cells
    public static func extractStructuralOccupancy(
        page: PDFPage,
        bounds: CGRect,
        cellSize: Double = cellSize,
        threshold: Double = densityThreshold
    ) -> Set<LayoutFingerprintV2.Cell> {
        let scale: CGFloat = 0.15
        let renderSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale)
        guard renderSize.width > 0, renderSize.height > 0 else { return [] }

        let image = page.thumbnail(of: renderSize, for: .cropBox)
        guard let cgImage = image.cgImage(
            forProposedRect: nil, context: nil, hints: nil) else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return [] }

        let byteCount = width * height * 4
        let pixelData = NSMutableData(length: byteCount)!
        guard let context = CGContext(
            data: pixelData.mutableBytes,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = pixelData.bytes.bindMemory(to: UInt8.self, capacity: byteCount)

        let cols = Int(ceil(bounds.width / cellSize))
        let rows = Int(ceil(bounds.height / cellSize))
        var cells = Set<LayoutFingerprintV2.Cell>()

        for row in 0..<rows {
            for col in 0..<cols {
                let cellMidX = (Double(col) + 0.5) * cellSize
                let cellMidY = (Double(row) + 0.5) * cellSize
                let px = Int((cellMidX / bounds.width) * Double(width))
                let py = Int((cellMidY / bounds.height) * Double(height))

                // Sample a 5×5 cluster for better density estimation.
                var nonBlankCount = 0
                var sampleCount = 0
                for dx in -2...2 {
                    for dy in -2...2 {
                        let sx = min(max(px + dx, 0), width - 1)
                        let sy = min(max(py + dy, 0), height - 1)
                        let offset = (sy * width + sx) * 4
                        guard offset + 3 < byteCount else { continue }
                        let r = bytes[offset]
                        let g = bytes[offset + 1]
                        let b = bytes[offset + 2]
                        sampleCount += 1
                        if r < 245 || g < 245 || b < 245 {
                            nonBlankCount += 1
                        }
                    }
                }
                if sampleCount > 0,
                   Double(nonBlankCount) / Double(sampleCount) >= threshold {
                    cells.insert(LayoutFingerprintV2.Cell(col: col, row: row))
                }
            }
        }
        return cells
    }

    // MARK: - Graded Occupancy

    /// Extract graded occupancy cells with fractional ink coverage at multiple scales.
    ///
    /// Unlike binary `extractStructuralOccupancy` (occupied/not), this
    /// returns the actual fraction of non-blank pixels in each cell [0, 1].
    /// Two cells with 80% and 75% coverage are structurally similar; binary
    /// Jaccard treats them identically to cells with 100% coverage.
    ///
    /// Multi-scale aggregation (2026-09-07): coverage is measured on **16pt
    /// and 64pt** grids from a **0.5-scale render**. Two fixes over the
    /// 2026-09-03 version, both first-principles (blend-sweep calibration):
    ///
    /// 1. **Render scale.** At the previous 0.15 scale, a 4pt cell spans
    ///    ~0.6 px, so a 4pt cell's "fractional coverage" was a single pixel
    ///    sample — binary in disguise. At 0.5 scale a 16pt cell spans ~8 px
    ///    per side (~64 samples) and a 64pt cell ~32 px (~1024 samples), so
    ///    coverage is genuinely fractional.
    /// 2. **Scale choice.** Coarser grids aggregate over larger regions, so
    ///    their per-cell coverage is inherently more stable under re-encoding
    ///    noise (anti-aliasing shifts boundary pixels by 1–2; at 16pt that
    ///    perturbs a ~64-sample mean by ~3%, vs ~100% for a 1-sample cell).
    ///    The fine 4pt scale — the threshold-fragile end — is deliberately
    ///    dropped from the graded channel.
    ///
    /// Cosine similarity over the union of (scale, col, row)-keyed coverage
    /// vectors is then scale-robust: fine-scale flips cannot change the
    /// signal, and coarse cells anchor the comparison in structure.
    ///
    /// - Parameters:
    ///   - page: The PDF page to extract from
    ///   - bounds: The page bounds in points
    ///   - cellSize: unused legacy parameter (the degenerate 4pt fine scale is dropped)
    /// - Returns: Array of graded cells sorted by (scale, row, col)
    public static func extractGradedOccupancy(
        page: PDFPage,
        bounds: CGRect,
        cellSize: Double = cellSize
    ) -> [LayoutFingerprintV2.GradedCell] {
        // 0.5-scale render: 16pt cells span ~8px/side (64 samples/cell),
        // 64pt cells ~32px/side (~1024 samples/cell) — genuinely fractional.
        let scale: CGFloat = 0.5
        let renderSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale)
        guard renderSize.width > 0, renderSize.height > 0 else { return [] }

        let image = page.thumbnail(of: renderSize, for: .cropBox)
        guard let cgImage = image.cgImage(
            forProposedRect: nil, context: nil, hints: nil) else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return [] }

        let byteCount = width * height * 4
        let pixelData = NSMutableData(length: byteCount)!
        guard let context = CGContext(
            data: pixelData.mutableBytes,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = pixelData.bytes.bindMemory(to: UInt8.self, capacity: byteCount)

        var cells: [LayoutFingerprintV2.GradedCell] = []
        for cellSize in Self.gradedScales {
            let cols = Int(ceil(bounds.width / cellSize))
            let rows = Int(ceil(bounds.height / cellSize))
            for row in 0..<rows {
                for col in 0..<cols {
                    // Pixel bounds for this cell.
                    let pxMin = Int((Double(col) * cellSize / bounds.width) * Double(width))
                    let pxMax = Int(((Double(col) + 1.0) * cellSize / bounds.width) * Double(width))
                    let pyMin = Int((Double(row) * cellSize / bounds.height) * Double(height))
                    let pyMax = Int(((Double(row) + 1.0) * cellSize / bounds.height) * Double(height))

                    var nonBlankCount = 0
                    var sampleCount = 0
                    for py in pyMin..<min(pyMax, height) {
                        for px in pxMin..<min(pxMax, width) {
                            let offset = (py * width + px) * 4
                            guard offset + 3 < byteCount else { continue }
                            let r = bytes[offset]
                            let g = bytes[offset + 1]
                            let b = bytes[offset + 2]
                            sampleCount += 1
                            if r < 245 || g < 245 || b < 245 {
                                nonBlankCount += 1
                            }
                        }
                    }

                    if sampleCount > 0 {
                        let coverage = Double(nonBlankCount) / Double(sampleCount)
                        // Only include cells with measurable content (>1% coverage).
                        // Cells with 0% coverage are omitted (same as binary: not occupied).
                        if coverage > 0.01 {
                            cells.append(LayoutFingerprintV2.GradedCell(
                                col: col, row: row, coverage: coverage, scale: cellSize))
                        }
                    }
                }
            }
        }
        return cells.sorted { ($0.scale, $0.row, $0.col) < ($1.scale, $1.row, $1.col) }
    }

    // MARK: - Edge Detection

    /// Grid scales (in points) for the multi-scale edge channel: 4pt (fine),
    /// 16pt (medium), 64pt (coarse). A 4pt cell is kept only when its 16pt
    /// parent or 64pt grandparent is also edge-occupied — the same
    /// confirm-by-coarser-scale pattern the main raster channel uses. This
    /// absorbs re-encoding noise at the threshold-fragile fine scale while
    /// preserving content-sensitive discrimination.
    public static let edgeScales: [Double] = [4.0, 16.0, 64.0]

    /// Extract raster cells using multi-scale edge detection.
    ///
    /// Applies a 3×3 Sobel operator over the rendered image **once** (full
    /// edge mask), then classifies cells at three grid scales by edge-pixel
    /// density. A fine (4pt) cell is retained only when confirmed by a
    /// coarser scale — coarser cells aggregate over larger regions, so their
    /// density measurement is stable under anti-aliasing/hinting differences
    /// that flip individual fine cells.
    ///
    /// Two fixes over the 2026-09-01 version (blend-sweep calibration):
    /// 1. **Render scale 0.15 → 0.5.** At 0.15, a 4pt cell spans ~0.6px, so
    ///    the old center 5×5 sample window extended beyond the cell into its
    ///    neighbors — adjacent cells shared overlapping evidence. At 0.5 a
    ///    4pt cell spans ~2px/side and the mask is computed per-pixel.
    /// 2. **Per-cell windows, not center clusters.** Cell classification now
    ///    counts edge pixels strictly inside the cell region at each scale.
    ///
    /// Edge detection is inherently content-invariant: a text line and an
    /// image border both produce edges, but the edge *pattern* is determined
    /// by layout, not content.
    ///
    /// - Parameters:
    ///   - page: The PDF page to extract from
    ///   - bounds: The page bounds in points
    ///   - cellSize: unused legacy parameter (superseded by `edgeScales`)
    ///   - threshold: Sobel magnitude threshold (default 30)
    /// - Returns: Set of confirmed fine-scale cells with significant edge activity
    public static func extractEdgeDetection(
        page: PDFPage,
        bounds: CGRect,
        cellSize: Double = cellSize,
        threshold: Double = edgeThreshold
    ) -> Set<LayoutFingerprintV2.Cell> {
        // 0.5-scale render: a 4pt cell spans ~2px/side (multi-sample), vs
        // the degenerate ~0.6px span at the previous 0.15 scale.
        let scale: CGFloat = 0.5
        let renderSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale)
        guard renderSize.width > 0, renderSize.height > 0 else { return [] }

        let image = page.thumbnail(of: renderSize, for: .cropBox)
        guard let cgImage = image.cgImage(
            forProposedRect: nil, context: nil, hints: nil) else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return [] }

        let byteCount = width * height * 4
        let pixelData = NSMutableData(length: byteCount)!
        guard let context = CGContext(
            data: pixelData.mutableBytes,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = pixelData.bytes.bindMemory(to: UInt8.self, capacity: byteCount)

        // Convert to grayscale for edge detection.
        var grayscale = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                guard offset + 3 < byteCount else { continue }
                // Luminance: 0.299R + 0.587G + 0.114B
                let r = Double(bytes[offset])
                let g = Double(bytes[offset + 1])
                let b = Double(bytes[offset + 2])
                let luminance = r * 0.299 + g * 0.587 + b * 0.114
                grayscale[y * width + x] = UInt8(min(255, Int(luminance)))
            }
        }

        // Full-image Sobel pass → edge mask, computed once (cheaper than the
        // previous per-cell 5×5 windows and strictly per-pixel).
        // Gx = [[-1,0,1],[-2,0,2],[-1,0,1]]
        // Gy = [[-1,-2,-1],[0,0,0],[1,2,1]]
        var edgeMask = [Bool](repeating: false, count: width * height)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let gx = -Int(grayscale[(y-1)*width + (x-1)])
                    + Int(grayscale[(y-1)*width + (x+1)])
                    - 2*Int(grayscale[y*width + (x-1)])
                    + 2*Int(grayscale[y*width + (x+1)])
                    - Int(grayscale[(y+1)*width + (x-1)])
                    + Int(grayscale[(y+1)*width + (x+1)])
                let gy = -Int(grayscale[(y-1)*width + (x-1)])
                    - 2*Int(grayscale[(y-1)*width + x])
                    - Int(grayscale[(y-1)*width + (x+1)])
                    + Int(grayscale[(y+1)*width + (x-1)])
                    + 2*Int(grayscale[(y+1)*width + x])
                    + Int(grayscale[(y+1)*width + (x+1)])
                let magnitude = Double(gx * gx + gy * gy).squareRoot()
                edgeMask[y * width + x] = magnitude > threshold
            }
        }

        // Classify cells at each scale by edge-pixel density (≥30%).
        var occupiedByScale: [Int: Set<LayoutFingerprintV2.Cell>] = [:]
        for (idx, s) in edgeScales.enumerated() {
            let cols = Int(ceil(bounds.width / s))
            let rows = Int(ceil(bounds.height / s))
            var cells = Set<LayoutFingerprintV2.Cell>()
            for row in 0..<rows {
                for col in 0..<cols {
                    let pxMin = Int((Double(col) * s / bounds.width) * Double(width))
                    let pxMax = Int(((Double(col) + 1.0) * s / bounds.width) * Double(width))
                    let pyMin = Int((Double(row) * s / bounds.height) * Double(height))
                    let pyMax = Int(((Double(row) + 1.0) * s / bounds.height) * Double(height))
                    var edgeCount = 0
                    var sampleCount = 0
                    for py in pyMin..<min(pyMax, height) {
                        for px in pxMin..<min(pxMax, width) {
                            sampleCount += 1
                            if edgeMask[py * width + px] { edgeCount += 1 }
                        }
                    }
                    if sampleCount > 0,
                       Double(edgeCount) / Double(sampleCount) >= 0.30 {
                        cells.insert(LayoutFingerprintV2.Cell(col: col, row: row))
                    }
                }
            }
            occupiedByScale[idx] = cells
        }

        // Keep only fine (4pt) cells confirmed by at least one coarser scale.
        // A 4pt cell at (c, r) has parent at (c/4, r/4) on the 16pt grid and
        // grandparent at (c/16, r/16) on the 64pt grid.
        guard let fineCells = occupiedByScale[0] else { return [] }
        let mediumCells = occupiedByScale[1] ?? []
        let coarseCells = occupiedByScale[2] ?? []
        var result = Set<LayoutFingerprintV2.Cell>()
        for cell in fineCells {
            let confirmed = mediumCells.contains(LayoutFingerprintV2.Cell(col: cell.col / 4, row: cell.row / 4))
                || coarseCells.contains(LayoutFingerprintV2.Cell(col: cell.col / 16, row: cell.row / 16))
            if confirmed {
                result.insert(cell)
            }
        }
        return result
    }

    // MARK: - Combined (Edge + Structural)

    /// Extract raster cells using combined edge detection + structural occupancy.
    ///
    /// A cell is included if EITHER edge detection OR structural occupancy
    /// marks it as occupied. This captures both:
    /// - Structural boundaries (edges)
    /// - Content regions (density)
    ///
    /// The union is more robust than either approach alone.
    ///
    /// - Parameters:
    ///   - page: The PDF page to extract from
    ///   - bounds: The page bounds in points
    ///   - cellSize: Grid cell size in points (default 32)
    /// - Returns: Set of structurally occupied cells
    public static func extractCombined(
        page: PDFPage,
        bounds: CGRect,
        cellSize: Double = cellSize
    ) -> Set<LayoutFingerprintV2.Cell> {
        let structural = extractStructuralOccupancy(
            page: page, bounds: bounds, cellSize: cellSize)
        let edges = extractEdgeDetection(
            page: page, bounds: bounds, cellSize: cellSize)
        return structural.union(edges)
    }

    // MARK: - Connected Component Regions

    /// A contiguous region of occupied cells.
    ///
    /// Two documents with the same layout structure produce similar region
    /// signatures regardless of content. A "header region" is a header
    /// regardless of what text it contains.
    public struct Region: Codable, Sendable, Equatable, Hashable {
        /// Bounding box in grid coordinates.
        public let minCol: Int
        public let minRow: Int
        public let maxCol: Int
        public let maxRow: Int
        /// Number of occupied cells in this region.
        public let cellCount: Int
        /// Area of the bounding box in grid cells.
        public var area: Int {
            (maxCol - minCol + 1) * (maxRow - minRow + 1)
        }
        /// Density: cellCount / area. Higher means more solidly filled.
        public var density: Double {
            area > 0 ? Double(cellCount) / Double(area) : 0
        }
        /// Aspect ratio of the bounding box (width/height). >1 = horizontal,
        /// <1 = vertical, ~1 = square.
        public var aspectRatio: Double {
            let w = Double(maxCol - minCol + 1)
            let h = Double(maxRow - minRow + 1)
            return h > 0 ? w / h : 1.0
        }
    }

    /// Extract connected component regions from occupied cells.
    ///
    /// Uses flood-fill to group adjacent occupied cells (4-connectivity)
    /// into contiguous regions. Each region is encoded by its bounding box,
    /// cell count, density, and aspect ratio — all content-invariant.
    ///
    /// The region signature (sorted list of region descriptors) captures
    /// the macro-level layout structure: how many regions, where they are,
    /// how large they are, and what shape they are.
    ///
    /// - Parameters:
    ///   - cells: Occupied cells from any extraction method
    ///   - cellSize: Grid cell size in points
    ///   - bounds: Page bounds in points
    /// - Returns: List of connected component regions
    public static func extractRegions(
        cells: Set<LayoutFingerprintV2.Cell>,
        cellSize: Double,
        bounds: CGRect
    ) -> [Region] {
        guard !cells.isEmpty else { return [] }

        // Build a lookup set for O(1) membership tests.
        let occupied = cells
        var visited = Set<LayoutFingerprintV2.Cell>()
        var regions: [Region] = []

        for startCell in cells where !visited.contains(startCell) {
            // Flood-fill from this cell.
            var queue = [startCell]
            visited.insert(startCell)
            var regionCells: [LayoutFingerprintV2.Cell] = []

            while !queue.isEmpty {
                let current = queue.removeLast()
                regionCells.append(current)

                // 4-connectivity neighbors.
                let neighbors = [
                    LayoutFingerprintV2.Cell(col: current.col - 1, row: current.row),
                    LayoutFingerprintV2.Cell(col: current.col + 1, row: current.row),
                    LayoutFingerprintV2.Cell(col: current.col, row: current.row - 1),
                    LayoutFingerprintV2.Cell(col: current.col, row: current.row + 1)
                ]
                for n in neighbors where occupied.contains(n) && !visited.contains(n) {
                    visited.insert(n)
                    queue.append(n)
                }
            }

            guard !regionCells.isEmpty else { continue }
            let minCol = regionCells.map { $0.col }.min()!
            let maxCol = regionCells.map { $0.col }.max()!
            let minRow = regionCells.map { $0.row }.min()!
            let maxRow = regionCells.map { $0.row }.max()!

            regions.append(Region(
                minCol: minCol, minRow: minRow,
                maxCol: maxCol, maxRow: maxRow,
                cellCount: regionCells.count
            ))
        }

        // Sort by position (top-left to bottom-right) for canonical ordering.
        return regions.sorted { a, b in
            if a.minRow != b.minRow { return a.minRow < b.minRow }
            return a.minCol < b.minCol
        }
    }

    /// Compare two region lists using structured similarity.
    ///
    /// First principles: region comparison must handle different counts,
    /// different positions, and different sizes. The approach:
    /// 1. Match regions by closest centroid distance (greedy assignment)
    /// 2. Score each matched pair by bounding-box overlap + density similarity
    /// 3. Penalize unmatched regions
    ///
    /// This is inherently content-invariant: region shape and position
    /// matter, not what fills them.
    public static func regionSimilarity(
        _ a: [Region],
        _ b: [Region]
    ) -> Double {
        if a.isEmpty && b.isEmpty { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }

        // Greedy matching by centroid distance.
        var usedB = Set<Int>()
        var totalScore = 0.0
        var matchCount = 0

        for regionA in a {
            let centroidAx = Double(regionA.minCol + regionA.maxCol) / 2
            let centroidAy = Double(regionA.minRow + regionA.maxRow) / 2

            var bestIdx = -1
            var bestDist = Double.infinity
            for (idx, regionB) in b.enumerated() where !usedB.contains(idx) {
                let centroidBx = Double(regionB.minCol + regionB.maxCol) / 2
                let centroidBy = Double(regionB.minRow + regionB.maxRow) / 2
                let dist = hypot(centroidAx - centroidBx, centroidAy - centroidBy)
                if dist < bestDist {
                    bestDist = dist
                    bestIdx = idx
                }
            }

            guard bestIdx >= 0 else { continue }
            usedB.insert(bestIdx)
            let regionB = b[bestIdx]

            // Score: bounding-box IoU + density similarity + aspect ratio similarity.
            let iouMinCol = max(regionA.minCol, regionB.minCol)
            let iouMaxCol = min(regionA.maxCol, regionB.maxCol)
            let iouMinRow = max(regionA.minRow, regionB.minRow)
            let iouMaxRow = min(regionA.maxRow, regionB.maxRow)
            let interCols = max(0, iouMaxCol - iouMinCol + 1)
            let interRows = max(0, iouMaxRow - iouMinRow + 1)
            let intersection = interCols * interRows
            let union = regionA.area + regionB.area - intersection
            let iouScore = union > 0 ? Double(intersection) / Double(union) : 0

            let densityDiff = abs(regionA.density - regionB.density)
            let aspectDiff = abs(regionA.aspectRatio - regionB.aspectRatio)
            let sizeDiff = abs(Double(regionA.cellCount - regionB.cellCount))
                / Double(max(regionA.cellCount, regionB.cellCount))

            // Combined score: 50% IoU, 20% density, 15% aspect, 15% size.
            let score = iouScore * 0.50
                + (1 - densityDiff) * 0.20
                + (1 - min(aspectDiff, 1.0)) * 0.15
                + (1 - sizeDiff) * 0.15
            totalScore += score
            matchCount += 1
        }

        // Penalize unmatched regions (missing in either direction).
        let unmatchedA = a.count - matchCount
        let unmatchedB = b.count - usedB.count
        let maxCount = max(a.count, b.count)
        let penalty = Double(unmatchedA + unmatchedB) / Double(max(maxCount, 1)) * 0.5

        let baseScore = matchCount > 0 ? totalScore / Double(matchCount) : 0
        return max(0, baseScore - penalty)
    }

    // MARK: - Projection Profiles

    /// Horizontal and vertical projection profiles.
    ///
    /// A projection profile is a 1D histogram of content density along
    /// an axis. The horizontal profile counts occupied cells per row; the
    /// vertical profile counts occupied cells per column.
    ///
    /// These capture macro-level layout structure:
    /// - Two-column layout → two peaks in the horizontal profile
    /// - Header region → high density in the top rows
    /// - Sidebar → sustained density in left/right columns
    ///
    /// Projection profiles are inherently content-invariant: they record
    /// WHERE content exists along each axis, not WHAT content exists.
    public struct ProjectionProfile: Codable, Sendable, Equatable {
        /// Horizontal profile: density per row (top to bottom).
        public let horizontal: [Double]
        /// Vertical profile: density per column (left to right).
        public let vertical: [Double]
        /// Number of quantization bins per axis.
        public let binCount: Int
    }

    /// Extract projection profiles from occupied cells.
    ///
    /// - Parameters:
    ///   - cells: Occupied cells from any extraction method
    ///   - cellSize: Grid cell size in points
    ///   - bounds: Page bounds in points
    ///   - binCount: Number of bins per axis (default 32)
    /// - Returns: Horizontal and vertical projection profiles
    public static func extractProjectionProfiles(
        cells: Set<LayoutFingerprintV2.Cell>,
        cellSize: Double,
        bounds: CGRect,
        binCount: Int = 32
    ) -> ProjectionProfile {
        guard !cells.isEmpty else {
            return ProjectionProfile(
                horizontal: [Double](repeating: 0, count: binCount),
                vertical: [Double](repeating: 0, count: binCount),
                binCount: binCount
            )
        }

        let totalCols = Int(ceil(bounds.width / cellSize))
        let totalRows = Int(ceil(bounds.height / cellSize))
        guard totalCols > 0, totalRows > 0 else {
            return ProjectionProfile(
                horizontal: [Double](repeating: 0, count: binCount),
                vertical: [Double](repeating: 0, count: binCount),
                binCount: binCount
            )
        }

        // Bin rows into `binCount` horizontal bins.
        var hBins = [Double](repeating: 0, count: binCount)
        for cell in cells {
            let bin = min(cell.row * binCount / totalRows, binCount - 1)
            hBins[bin] += 1
        }
        // Normalize by max bin value.
        let hMax = hBins.max() ?? 1
        if hMax > 0 {
            hBins = hBins.map { $0 / hMax }
        }

        // Bin columns into `binCount` vertical bins.
        var vBins = [Double](repeating: 0, count: binCount)
        for cell in cells {
            let bin = min(cell.col * binCount / totalCols, binCount - 1)
            vBins[bin] += 1
        }
        let vMax = vBins.max() ?? 1
        if vMax > 0 {
            vBins = vBins.map { $0 / vMax }
        }

        return ProjectionProfile(
            horizontal: hBins,
            vertical: vBins,
            binCount: binCount
        )
    }

    /// Compare two projection profiles using cosine similarity.
    ///
    /// Cosine similarity measures the angle between two vectors, making it
    /// invariant to magnitude (total cell count) and sensitive to shape
    /// (distribution pattern). Two layouts with the same column structure
    /// but different total cell counts will still score high.
    ///
    /// - Parameters:
    ///   - a: First projection profile
    ///   - b: Second projection profile
    /// - Returns: Similarity score [0, 1]
    public static func projectionSimilarity(
        _ a: ProjectionProfile,
        _ b: ProjectionProfile
    ) -> Double {
        guard a.binCount == b.binCount, a.binCount > 0 else { return 0 }

        // Horizontal similarity.
        let hSim = cosineSimilarity(a.horizontal, b.horizontal)
        // Vertical similarity.
        let vSim = cosineSimilarity(a.vertical, b.vertical)

        // Average of horizontal and vertical.
        return (hSim + vSim) / 2
    }

    /// Cosine similarity between two vectors.
    /// Empty/zero vectors are treated as identical (agreement on absence).
    private static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denominator = sqrt(normA) * sqrt(normB)
        if denominator > 0 { return dotProduct / denominator }
        // Both vectors are zero — agreement on absence.
        return 1.0
    }
}
