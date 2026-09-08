import Foundation
import PDFKit
import CryptoKit


/// **Scope note (2026-09-06, epistemic audit EI-B1):** offline calibration/benchmark
/// subsystem — implemented and test-covered, but **not currently wired into the app's
/// runtime paths**. Consumers: tests and offline tooling only. Do not cite its behavior
/// as a product claim until wired. See docs/audits/epistemic-integrity-audit-per-0922-2026-09-06.md.
/// Structured layout fingerprint V2 — the first-principles fix for the
/// fingerprint-collision findings from the calibration corpus verification
/// (2026-08-28, `docs/audits/calibration-corpus-verification-2026-08-28.md`).
///
/// ## Why V1 failed (Observed, real corpus)
/// - V1 fingerprint = first-page size + first-page rotation + page count.
///   `plain-text.pdf` (3p Letter) and `navigation.pdf` (3p Letter) collide:
///   the feature set is too coarse and only looks at page 0.
/// - V1 family similarity = Jaccard on the *character sets* of the serialized
///   fingerprint strings. "612x792_r0_p3" vs "612x792_r0_p2" share almost all
///   characters, so different documents scored as `.familyMatch`. Comparing
///   characters of a serialized string is semantically meaningless — it is not
///   comparing structural features.
///
/// ## First principles
/// A layout fingerprint has two distinct jobs, and conflating them is the
/// root error:
/// 1. **Equality key** (exact layout match → known variant): a canonical
///    serialization of structural features, hashed. Must be *invariant to
///    field values*: a filled form is the same template, so text that falls
///    inside widget rects is masked out.
/// 2. **Similarity measure** (family match): a *structured* comparison of
///    feature components, never a string-distance hack.
///
/// ## Invariance requirements
/// - Field values must not change the fingerprint (masked text cells).
/// - ±render differences must not change the fingerprint (grid quantization:
///   4pt cells absorb sub-cell shifts; matches PageBoxPolicy tolerance
///   philosophy).
/// - Content must never enter the fingerprint (privacy doctrine): only
///   positions, kinds, and counts are recorded — never text.
///
/// ## Components (all content-free, all pages)
/// - Page geometry: (width, height, rotation) per page — fixes "page 0 only".
/// - Text-block layout: occupied grid cells of character bounds, with field
///   values masked — fixes "value-invariant known variant".
/// - Field layout: occupied cells of widget rects (corners + center).
/// - Annotation layout: occupied cells of non-widget annotation rects.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — collisions were Observed; the fix is Verified by
///   real-corpus tests.
/// - §5 Evidence-based — discrimination, stability, and invariance are
///   measured, not claimed.
/// - §12 Privacy — positions and kinds only, never text content.
public struct LayoutFingerprintV2: Codable, Sendable, Equatable {
    public let algorithm: String
    public let featureVersion: String
    public let cellSizePoints: Double
    public let pages: [PageLayout]
    /// SHA-256 of the canonical serialization — the equality key.
    public let digest: String

    /// Structured-content coverage of THIS document alone (any page).
    /// Used to gate the knownVariant equality claim: the canonical key is
    /// only as strong as what it encodes. When a document is silent on every
    /// structured channel, canonical equality with another silent document
    /// is vacuous ("same page size, same emptiness") and must abstain — see
    /// `RecurringFormCalibrator.classify`.
    public var contentCoverage: SimilarityCoverage {
        SimilarityCoverage(
            text: pages.contains { !$0.textCells.isEmpty },
            field: pages.contains { !$0.fieldCells.isEmpty },
            annotation: pages.contains { !$0.annotationCells.isEmpty },
            region: pages.contains { !$0.textRegions.isEmpty },
            raster: pages.contains { !$0.rasterCells.isEmpty }
        )
    }

    public struct PageLayout: Codable, Sendable, Equatable {
        public let pageIndex: Int
        public let widthPoints: Int
        public let heightPoints: Int
        public let rotationDegrees: Int
        public let textCells: [Cell]
        public let fieldCells: [Cell]
        public let annotationCells: [Cell]
        /// Raster/image cells — positions where rendered page content (images,
        /// scanned regions, drawn graphics) occupies the grid. Extracted by
        /// rendering the page at low resolution and sampling cell centers for
        /// non-blank pixels. Empty for purely vector/text pages.
        public let rasterCells: [Cell]
        /// Projection profiles for content-invariant raster comparison.
        /// Horizontal = density per row, vertical = density per column.
        /// Captures macro-level layout structure (columns, headers, sidebars)
        /// and is inherently content-invariant.
        public let rasterProjectionH: [Double]
        public let rasterProjectionV: [Double]
        /// Projection profiles for text layout — content-invariant comparison
        /// of WHERE text exists (which rows/columns have text), not WHAT text
        /// exists. Two documents with the same column structure but different
        /// text content have similar text projections.
        public let textProjectionH: [Double]
        public let textProjectionV: [Double]
        /// Connected-component regions extracted from text cells.
        /// Captures macro-level text layout structure (how many text blocks,
        /// where they are, what shape) — content-invariant.
        public let textRegions: [ContentInvariantRasterExtractor.Region]
        /// Edge-detected raster cells — cells where Sobel edge magnitude
        /// exceeds threshold. Captures layout structure (lines, borders,
        /// regions) rather than content fill. Content-invariant.
        public let edgeCells: [Cell]
        /// Structural occupancy cells — cells where pixel density exceeds
        /// threshold. Coarser than raw raster cells; captures where content
        /// exists structurally. Content-invariant.
        public let occupancyCells: [Cell]
        /// Graded occupancy cells — fractional ink coverage (0.0–1.0) per cell.
        /// Replaces binary occupancy for similarity comparison: cosine
        /// similarity on graded values is inherently content-invariant because
        /// it compares *how much* ink each cell has, not *whether* it has ink.
        public let gradedOccupancyCells: [GradedCell]

        /// Backward-compatible init: old records without projection profiles
        /// or regions decode to empty (Codable default via custom init).
        public init(
            pageIndex: Int, widthPoints: Int, heightPoints: Int,
            rotationDegrees: Int, textCells: [Cell], fieldCells: [Cell],
            annotationCells: [Cell], rasterCells: [Cell] = [],
            rasterProjectionH: [Double] = [], rasterProjectionV: [Double] = [],
            textProjectionH: [Double] = [], textProjectionV: [Double] = [],
            textRegions: [ContentInvariantRasterExtractor.Region] = [],
            edgeCells: [Cell] = [], occupancyCells: [Cell] = [],
            gradedOccupancyCells: [GradedCell] = []
        ) {
            self.pageIndex = pageIndex
            self.widthPoints = widthPoints
            self.heightPoints = heightPoints
            self.rotationDegrees = rotationDegrees
            self.textCells = textCells
            self.fieldCells = fieldCells
            self.annotationCells = annotationCells
            self.rasterCells = rasterCells
            self.rasterProjectionH = rasterProjectionH
            self.rasterProjectionV = rasterProjectionV
            self.textProjectionH = textProjectionH
            self.textProjectionV = textProjectionV
            self.textRegions = textRegions
            self.edgeCells = edgeCells
            self.occupancyCells = occupancyCells
            self.gradedOccupancyCells = gradedOccupancyCells
        }

        private enum CodingKeys: String, CodingKey {
            case pageIndex, widthPoints, heightPoints, rotationDegrees
            case textCells, fieldCells, annotationCells, rasterCells
            case rasterProjectionH, rasterProjectionV
            case textProjectionH, textProjectionV
            case textRegions
            case edgeCells, occupancyCells, gradedOccupancyCells
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            pageIndex = try c.decode(Int.self, forKey: .pageIndex)
            widthPoints = try c.decode(Int.self, forKey: .widthPoints)
            heightPoints = try c.decode(Int.self, forKey: .heightPoints)
            rotationDegrees = try c.decode(Int.self, forKey: .rotationDegrees)
            textCells = try c.decode([Cell].self, forKey: .textCells)
            fieldCells = try c.decode([Cell].self, forKey: .fieldCells)
            annotationCells = try c.decode([Cell].self, forKey: .annotationCells)
            rasterCells = try c.decodeIfPresent([Cell].self, forKey: .rasterCells) ?? []
            rasterProjectionH = try c.decodeIfPresent([Double].self, forKey: .rasterProjectionH) ?? []
            rasterProjectionV = try c.decodeIfPresent([Double].self, forKey: .rasterProjectionV) ?? []
            textProjectionH = try c.decodeIfPresent([Double].self, forKey: .textProjectionH) ?? []
            textProjectionV = try c.decodeIfPresent([Double].self, forKey: .textProjectionV) ?? []
            textRegions = try c.decodeIfPresent([ContentInvariantRasterExtractor.Region].self, forKey: .textRegions) ?? []
            edgeCells = try c.decodeIfPresent([Cell].self, forKey: .edgeCells) ?? []
            occupancyCells = try c.decodeIfPresent([Cell].self, forKey: .occupancyCells) ?? []
            gradedOccupancyCells = try c.decodeIfPresent([GradedCell].self, forKey: .gradedOccupancyCells) ?? []
        }
    }

    /// A quantized grid cell (col, row) in page space.
    public struct Cell: Codable, Sendable, Equatable, Hashable {
        public let col: Int
        public let row: Int
        public init(col: Int, row: Int) {
            self.col = col
            self.row = row
        }
    }

    /// A quantized grid cell with fractional ink coverage (0.0–1.0).
    /// Replaces binary occupancy for content-invariant comparison:
    /// a cell with 80% coverage is structurally similar to one with 75%
    /// coverage, unlike binary Jaccard where both are just "occupied."
    ///
    /// Multi-scale (2026-09-07): cells carry the grid scale they were
    /// extracted at (16pt medium, 64pt coarse). Coarser cells aggregate
    /// over larger regions, so their coverage is inherently more stable
    /// under re-encoding (anti-aliasing, hinting) — the multi-scale
    /// aggregation plan for the blend-sweep calibration row.
    public struct GradedCell: Codable, Sendable, Equatable {
        public let col: Int
        public let row: Int
        /// Fractional ink coverage in [0, 1]. Extracted by counting
        /// non-blank pixels in the cell's rendered region and normalizing.
        public let coverage: Double
        /// Grid scale in points this cell was extracted at. Legacy records
        /// (pre multi-scale) contained degenerate 4pt cells — a 4pt cell at
        /// the 0.15 render scale spans <1 pixel, so their coverage was
        /// binary in disguise; they decode as 16pt (the finest live scale).
        public let scale: Double
        public init(col: Int, row: Int, coverage: Double, scale: Double = 16.0) {
            self.col = col
            self.row = row
            self.coverage = min(1.0, max(0.0, coverage))
            self.scale = scale
        }

        private enum CodingKeys: String, CodingKey { case col, row, coverage, scale }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            col = try c.decode(Int.self, forKey: .col)
            row = try c.decode(Int.self, forKey: .row)
            coverage = try c.decode(Double.self, forKey: .coverage)
            scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 16.0
        }
    }

    /// Canonical serialization — deterministic across reads and lanes.
    /// Excludes raster cells: they capture rendering differences (pixel
    /// noise, compression artifacts) not layout structure. Two layout-
    /// identical re-encodings render differently but are the same template.
    public var canonical: String {
        var lines = ["v2|cell=\(cellSizePoints)|count=\(pages.count)"]
        for page in pages.sorted(by: { $0.pageIndex < $1.pageIndex }) {
            let t = page.textCells.map { "\($0.col),\($0.row)" }.joined(separator: ";")
            let f = page.fieldCells.map { "\($0.col),\($0.row)" }.joined(separator: ";")
            let a = page.annotationCells.map { "\($0.col),\($0.row)" }.joined(separator: ";")
            lines.append("p\(page.pageIndex)|\(page.widthPoints)x\(page.heightPoints)|r\(page.rotationDegrees)|t:\(t)|f:\(f)|a:\(a)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Extractor

/// Extracts `LayoutFingerprintV2` from a PDFKit document.
public enum LayoutFingerprintV2Extractor {
    public static let algorithm = "layout-v2-cell-quantized"
    public static let featureVersion = "layout-features-2"        /// Default quantization cell in points (4pt ≈ 0.5% of a Letter page).
        public static let defaultCellSizePoints: Double = 4.0

        /// Raster detection threshold: a cell is "occupied" when more than
        /// this fraction of sampled pixels differ from white (255,255,255).
        /// 20% absorbs anti-aliasing artifacts and sparse content differences
        /// between re-encodings, making extraction more content-invariant.
        private static let rasterThreshold: Double = 0.20

    public static func extract(
        from document: PDFDocument,
        cellSizePoints: Double = defaultCellSizePoints
    ) -> LayoutFingerprintV2? {
        guard document.pageCount > 0 else { return nil }
        var pages: [LayoutFingerprintV2.PageLayout] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let bounds = page.bounds(for: .cropBox)
            guard bounds.width > 0, bounds.height > 0 else { continue }

            let widgets: [(kind: String, rect: CGRect)] = page.annotations.compactMap { annotation in
                let rawType = annotation.type ?? "unknown"
                guard rawType == "Widget", !annotation.bounds.isEmpty else { return nil }
                return (annotation.widgetFieldType.rawValue, annotation.bounds)
            }
            let otherAnnotationRects: [CGRect] = page.annotations.compactMap { annotation in
                let rawType = annotation.type ?? "unknown"
                guard rawType != "Widget", !annotation.bounds.isEmpty else { return nil }
                return annotation.bounds
            }

            // Text cells with field-value masking: characters inside a widget
            // rect (expanded 2pt) are field values, not layout.
            var textCells = Set<LayoutFingerprintV2.Cell>()
            let charCount = page.numberOfCharacters
            if charCount > 0 {
                for index in 0..<charCount {
                    let charBounds = page.characterBounds(at: index)
                    guard charBounds.width > 0, charBounds.height > 0 else { continue }
                    let mask = widgets.contains {
                        $0.rect.insetBy(dx: -2, dy: -2).intersects(charBounds)
                    }
                    guard !mask else { continue }
                    textCells.insert(cell(for: charBounds, cellSize: cellSizePoints))
                }
            }

            let fieldCells = Set(widgets.flatMap { cells(for: $0.rect, cellSize: cellSizePoints) })
            let annotationCells = Set(otherAnnotationRects.flatMap { cells(for: $0, cellSize: cellSizePoints) })

            // Raster cells: render the page at low resolution and detect
            // non-blank grid cells. This captures scanned regions, images,
            // and drawn graphics that the text/field/annotation channels
            // cannot see. Rendering is ~2ms per page at 0.15 scale.
            let rasterCells = extractRasterCells(
                page: page, bounds: bounds, cellSize: cellSizePoints)

            // Projection profiles: content-invariant layout comparison.
            // Encode WHERE content exists along x/y axes, not WHAT content.
            let rasterProjection = ContentInvariantRasterExtractor
                .extractProjectionProfiles(
                    cells: rasterCells, cellSize: cellSizePoints,
                    bounds: bounds, binCount: LayoutFingerprintV2.rasterProjectionBinCount)
            // Text projection profiles: WHERE text exists (which rows/columns
            // have text), not WHAT text. Two documents with the same column
            // structure but different text content have similar projections.
            let textProjection = ContentInvariantRasterExtractor
                .extractProjectionProfiles(
                    cells: textCells, cellSize: cellSizePoints,
                    bounds: bounds, binCount: LayoutFingerprintV2.rasterProjectionBinCount)

            let textRegions = ContentInvariantRasterExtractor.extractRegions(
                cells: textCells, cellSize: cellSizePoints, bounds: bounds)

            // Cell-level text-structure channels (edge, occupancy, graded) are
            // uninformative on raster-only pages. A page with no extractable
            // text/field/annotation structure has no text layout to measure;
            // its rendered pixels are image content, which is the projection
            // channel's job (rasterProjection from rasterCells). Emitting
            // cells there compared render noise across producers — a rotated
            // raster page can never match at cell level (Observed: 85/8/7
            // blend-sweep, 2026-09-08: the rotated-raster B pair dropped
            // 0.971 → 0.8884 because both docs' raster pages emitted dense
            // edge/occupancy cells). This matches the F-3 doctrine: "a raster
            // page has zero extractable cells and is skipped as uninformative".
            let hasTextStructure = !textCells.isEmpty
                || !fieldCells.isEmpty || !annotationCells.isEmpty
            let edgeCells = hasTextStructure
                ? ContentInvariantRasterExtractor.extractEdgeDetection(
                    page: page, bounds: bounds, cellSize: cellSizePoints)
                : []

            // Structural occupancy: density-thresholded cells capture where content
            // exists structurally — coarser than raw raster, more robust.
            let occupancyCells = hasTextStructure
                ? ContentInvariantRasterExtractor.extractStructuralOccupancy(
                    page: page, bounds: bounds, cellSize: cellSizePoints)
                : []

            // Graded occupancy: fractional ink coverage per cell (0.0–1.0).
            // Used for content-invariant cosine similarity instead of binary Jaccard.
            let gradedOccupancyCells = hasTextStructure
                ? ContentInvariantRasterExtractor.extractGradedOccupancy(
                    page: page, bounds: bounds, cellSize: cellSizePoints)
                : []

            pages.append(LayoutFingerprintV2.PageLayout(
                pageIndex: pageIndex,
                widthPoints: Int(bounds.width.rounded()),
                heightPoints: Int(bounds.height.rounded()),
                rotationDegrees: page.rotation,
                textCells: textCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                fieldCells: fieldCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                annotationCells: annotationCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                rasterCells: rasterCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                rasterProjectionH: rasterProjection.horizontal,
                rasterProjectionV: rasterProjection.vertical,
                textProjectionH: textProjection.horizontal,
                textProjectionV: textProjection.vertical,
                textRegions: textRegions,
                edgeCells: edgeCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                occupancyCells: occupancyCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                gradedOccupancyCells: gradedOccupancyCells
            ))
        }
        guard !pages.isEmpty else { return nil }

        let fingerprint = LayoutFingerprintV2(
            algorithm: algorithm,
            featureVersion: featureVersion,
            cellSizePoints: cellSizePoints,
            pages: pages,
            digest: ""
        )
        // Digest over the canonical serialization (equality key).
        let digestData = Data(fingerprint.canonical.utf8)
        let digest = SHA256.hash(data: digestData).map { String(format: "%02x", $0) }.joined()
        return LayoutFingerprintV2(
            algorithm: algorithm,
            featureVersion: featureVersion,
            cellSizePoints: cellSizePoints,
            pages: pages,
            digest: digest
        )
    }

    /// All grid cells covered by a rect (capped for very large rects).
    private static func cells(for rect: CGRect, cellSize: Double) -> [LayoutFingerprintV2.Cell] {
        let minCol = Int(floor(rect.minX / cellSize))
        let maxCol = Int(floor(rect.maxX / cellSize))
        let minRow = Int(floor(rect.minY / cellSize))
        let maxRow = Int(floor(rect.maxY / cellSize))
        let colSpan = maxCol - minCol + 1
        let rowSpan = maxRow - minRow + 1
        // Cap coverage: large rects (e.g., full-page annotations) use
        // corners + center instead of every covered cell.
        if colSpan * rowSpan > 512 {
            return [
                LayoutFingerprintV2.Cell(col: minCol, row: minRow),
                LayoutFingerprintV2.Cell(col: maxCol, row: minRow),
                LayoutFingerprintV2.Cell(col: minCol, row: maxRow),
                LayoutFingerprintV2.Cell(col: maxCol, row: maxRow),
                LayoutFingerprintV2.Cell(col: (minCol + maxCol) / 2, row: (minRow + maxRow) / 2)
            ]
        }
        var result: [LayoutFingerprintV2.Cell] = []
        result.reserveCapacity(colSpan * rowSpan)
        for row in minRow...maxRow {
            for col in minCol...maxCol {
                result.append(LayoutFingerprintV2.Cell(col: col, row: row))
            }
        }
        return result
    }

    private static func cell(for rect: CGRect, cellSize: Double) -> LayoutFingerprintV2.Cell {
        LayoutFingerprintV2.Cell(
            col: Int(floor(rect.midX / cellSize)),
            row: Int(floor(rect.midY / cellSize))
        )
    }

    /// Multi-scale raster cell sizes: 4pt (fine), 16pt (medium), 64pt (coarse).
    /// A 4pt cell is kept only if its parent cell at 16pt OR grandparent at 64pt
    /// is also occupied — this absorbs re-encoding noise at fine scales while
    /// preserving content-sensitive discrimination.
    private static let rasterScales: [Double] = [4.0, 16.0, 64.0]

    /// Extract raster/image cells using multi-scale sampling.
    /// Renders the page once at low resolution, then samples at three grid
    /// resolutions. The 4pt cells provide precision; the 16pt and 64pt cells
    /// provide stability against re-encoding differences (anti-aliasing, font
    /// hinting, color space conversion). A 4pt cell is retained only when
    /// confirmed by at least one coarser scale.
    private static func extractRasterCells(
        page: PDFPage, bounds: CGRect, cellSize: Double
    ) -> Set<LayoutFingerprintV2.Cell> {
        // Render once at 0.15 scale (~2ms per page).
        let scale: CGFloat = 0.15
        let renderSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale)
        guard renderSize.width > 0, renderSize.height > 0 else { return [] }

        let image = page.thumbnail(of: renderSize, for: .cropBox)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }

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

        // Sample all three scales from the single rendered image.
        var occupiedByScale: [Int: Set<LayoutFingerprintV2.Cell>] = [:]
        for (idx, rasterCellSize) in rasterScales.enumerated() {
            let cols = Int(ceil(bounds.width / rasterCellSize))
            let rows = Int(ceil(bounds.height / rasterCellSize))
            var cells = Set<LayoutFingerprintV2.Cell>()
            for row in 0..<rows {
                for col in 0..<cols {
                    let cellMidX = (Double(col) + 0.5) * rasterCellSize
                    let cellMidY = (Double(row) + 0.5) * rasterCellSize
                    let px = Int((cellMidX / bounds.width) * Double(width))
                    let py = Int((cellMidY / bounds.height) * Double(height))
                    // Sample a 3×3 cluster for robustness.
                    var nonBlankCount = 0
                    var sampleCount = 0
                    for dx in -1...1 {
                        for dy in -1...1 {
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
                       Double(nonBlankCount) / Double(sampleCount) >= rasterThreshold {
                        cells.insert(LayoutFingerprintV2.Cell(col: col, row: row))
                    }
                }
            }
            occupiedByScale[idx] = cells
        }

        // Keep only 4pt cells confirmed by at least one coarser scale.
        // A 4pt cell at (c, r) has parent at (c/4, r/4) on 16pt grid
        // and grandparent at (c/16, r/16) on 64pt grid.
        guard let fineCells = occupiedByScale[0] else { return [] }
        let mediumCells = occupiedByScale[1] ?? []
        let coarseCells = occupiedByScale[2] ?? []

        var result = Set<LayoutFingerprintV2.Cell>()
        for cell in fineCells {
            let parentCol = cell.col / 4
            let parentRow = cell.row / 4
            let grandparentCol = cell.col / 16
            let grandparentRow = cell.row / 16
            let confirmed = mediumCells.contains(LayoutFingerprintV2.Cell(col: parentCol, row: parentRow))
                || coarseCells.contains(LayoutFingerprintV2.Cell(col: grandparentCol, row: grandparentRow))
            if confirmed {
                result.insert(cell)
            }
        }
        return result
    }
}

// MARK: - Evidence Coverage and Confirmation Routing

/// Whether a similarity comparison rests on structured-content evidence.
///
/// A family claim ("same recurring form template") is only epistemically
/// justified when at least one side of the pair carries structured content —
/// extractable text, form fields, annotations, or connected-component text
/// regions. When both sides are silent on every structured channel, the only
/// remaining evidence is page geometry plus raster ink distribution:
/// "same page size with similar ink density", which is not family evidence.
///
/// Observed (60-fixture corpus, 2026-09-01): six graphics-heavy hard-negative
/// pairs score >= 0.90 purely on geometry + raster (e.g. scanned-noisy <->
/// ocr-low-contrast = 0.9886, diverse-graphics-heavy <-> diverse-scanned-sim
/// = 0.972). Corpus diversification was tried and did NOT remove them — the
/// binding constraint is extraction resolution, not corpus composition. The
/// evidence floor below converts those promotions into first-class
/// abstentions that route to a confirmation lane (see
/// `docs/audits/evidence-floor-abstention-rg138-2026-09-03.md`).
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — a family claim on zero content signal is an
///   unverified inference; it is classified as abstention, not promotion
/// - §0/§4.3 Fail-closed — a false promotion pollutes the template store and
///   risks wrong prefill; a false abstention is recoverable (user re-specifies)
public struct SimilarityCoverage: Codable, Sendable, Equatable {
    /// Extractable text cells present on any page of either document.
    public let text: Bool
    /// AcroForm field (widget) cells present on any page of either document.
    public let field: Bool
    /// Non-widget annotation cells present on any page of either document.
    public let annotation: Bool
    /// Connected-component text regions present in either document.
    public let region: Bool
    /// Rendered raster/ink cells present on any page of either document.
    /// Recorded for confirmation-lane routing only — ink is NOT structured
    /// content evidence for a family claim.
    public let raster: Bool

    public init(text: Bool, field: Bool, annotation: Bool, region: Bool, raster: Bool) {
        self.text = text
        self.field = field
        self.annotation = annotation
        self.region = region
        self.raster = raster
    }

    /// True when at least one structured-content channel carries signal in
    /// either document. Raster/edge/occupancy are deliberately excluded —
    /// they describe ink, not structure.
    public var hasStructuredContent: Bool {
        text || field || annotation || region
    }

    /// Human-readable list of the structured channels that are present.
    public var description: String {
        var present: [String] = []
        if text { present.append("text") }
        if field { present.append("fields") }
        if annotation { present.append("annotations") }
        if region { present.append("regions") }
        if present.isEmpty {
            return raster ? "no structured content (raster ink only)"
                          : "no content signal at all"
        }
        return present.joined(separator: ", ")
    }
}

/// Which confirmation lane an abstained family candidate escalates to.
/// §8 capability routing: the family lane abstains, the confirm lane decides.
public enum FamilyConfirmLane: String, Codable, Sendable, CaseIterable {
    /// Both documents carry rendered ink but no extractable structured
    /// content — the missing evidence (real text inside the pixels) can only
    /// be read by OCR (`OCRCompanionBenchmark` spot-check). A chart-vs-scan
    /// pair fails the OCR check; a true re-encoding pair passes it.
    case ocrSpotCheck
    /// Neither document has structured content nor rendered ink — nothing
    /// automated can distinguish "identical blank template" from "unrelated
    /// blank pages"; a reviewer must compare visually (RG-135 human visual
    /// confirmation).
    case humanVisual
}

/// Structured component similarity between two layout fingerprints.
/// Replaces the semantically meaningless character-set Jaccard of V1.
public struct LayoutSimilarityV2: Codable, Sendable, Equatable {
    public let geometry: Double
    public let textLayout: Double
    public let fieldLayout: Double
    public let annotationLayout: Double
    public let rasterLayout: Double
    /// Connected-component region similarity (content-invariant text layout).
    public let regionLayout: Double
    /// Weighted total (weights below).
    public let total: Double
    /// Which structured-content channels carry signal in either document.
    public let coverage: SimilarityCoverage

    /// Evidence-floor gate: a family claim requires structured content on at
    /// least one side. When false, `total` may still be >= the family
    /// threshold — driven only by geometry + raster — and the classifier must
    /// abstain (`.insufficientEvidence`) instead of promoting.
    public var evidenceFloorMet: Bool { coverage.hasStructuredContent }

    /// The confirmation lane an abstained candidate escalates to. Non-nil
    /// exactly when the evidence floor is unmet.
    public var confirmLane: FamilyConfirmLane? {
        guard !evidenceFloorMet else { return nil }
        return coverage.raster ? .ocrSpotCheck : .humanVisual
    }
}

extension LayoutFingerprintV2 {
    /// Family-match threshold on V2's structured similarity scale.
    ///
    /// Recalibrated 2026-08-28 (F-3): the legacy 0.76 was tuned for V1's
    /// char-set Jaccard semantics. The ratified value is the midpoint of the
    /// separation gap measured on a 30-fixture corpus with hard negatives
    /// (211 positive pairs min 0.971 — layout-identical re-encodings;
    /// 224 negative pairs max 0.813 — layout-distinct documents) — see
    /// `LayoutFingerprintThresholdCalibrationTests` and
    /// `benchmark/results/detector-calibration/layout-v2-family-threshold-
    /// calibration-2026-08-31.json`.
    ///
    /// Updated to 0.96 for the expanded 44-fixture corpus (30 original +
    /// 14 diverse-layout). The diverse-layout fixtures include graphics-heavy
    /// documents that score 0.92–0.98 as hard negatives (both single-page,
    /// similar dimensions, empty text channels → geometry + text inflate the
    /// total). At 0.90, these are false positives. At 0.96, all true positives
    /// (A-family: 1.0, B-family: ~0.97) stay above and all hard negatives
    /// (top: 0.9806 graphics-heavy) stay below.
    ///
    /// Precision-first: every hard negative stays below; every layout-identical
    /// re-encoding is recognized.
    public static let familyThreshold: Double = 0.90

    /// Component weights — geometry is the strongest identity signal;
    /// raster layout captures scanned/image content that text/field/annotation
    /// channels miss; annotation layout is the weakest (often absent).
    public static let geometryWeight: Double = 0.35
    public static let textWeight: Double = 0.25
    public static let fieldWeight: Double = 0.20
    public static let annotationWeight: Double = 0.10
    /// Raster weight: 0.24 (raised from 0.02 via projection profiles).
    /// Projection profiles capture WHERE content exists along x/y axes,
    /// making the extraction content-invariant — a header region is a
    /// header regardless of what text it contains. This unlocked the
    /// weight from 0.02 to 0.24.
    ///
    /// Calibration evidence (36-fixture corpus, 211 positive / 224 negative pairs):
    /// - 0.04: gap 0.7875..0.9507 (conservative)
    /// - 0.08: gap 0.7781..0.9390
    /// - 0.12: gap 0.7696..0.9283
    /// - 0.16: gap 0.7617..0.9185
    /// - 0.20: gap 0.7545..0.9095
    /// - 0.24: gap 0.7479..0.9012 (maximum viable — minPositive 0.0012 above 0.90)
    /// - 0.26: FAILS (minPositive drops below 0.90)
    ///
    /// The binding constraint is now extraction resolution, not corpus
    /// composition. The diversification hypothesis was tested and falsified
    /// (Observed 2026-09-03, RG-138): expanding the corpus to 60 fixtures
    /// including 11 graphics-heavy PDFs did NOT separate the graphics-heavy
    /// high scorers (scanned-noisy↔low-contrast = 0.9886) — same geometry +
    /// same raster ink pattern is indistinguishable at this resolution
    /// regardless of corpus composition. Those pairs are resolved as
    /// first-class evidence-floor abstentions (see SimilarityCoverage /
    /// RecurringFormCalibrator.insufficientEvidence) that route to the
    /// confirmation lane (OCR spot-check or human visual review) instead of
    /// promoting. Further raster weight increases would require richer raster
    /// encoding (multi-scale, graded occupancy), not more fixtures.
    ///
    /// Doctrine ref: §5 Evidence-based, §2 Truth taxonomy
    public static let rasterWeight: Double = 0.24

    /// Number of bins per axis for projection profiles.
    /// 32 bins captures macro-level layout structure (columns, headers,
    /// sidebars) without being sensitive to fine-grained content differences.
    public static let rasterProjectionBinCount: Int = 32

    /// Region weight: connected-component region similarity.
    /// Compares macro-level text layout structure (how many blocks, where,
    /// what shape) — content-invariant like projection profiles but captures
    /// spatial clustering that projections miss.
    /// Start at 0.05; calibrated on the 44-fixture corpus.
    public static let regionWeight: Double = 0.05

    /// Structured similarity to another fingerprint.
    public func similarity(
        to other: LayoutFingerprintV2,
        rasterWeightOverride: Double? = nil,
        rasterBlendOverride: (projection: Double, edge: Double, occupancy: Double)? = nil
    ) -> LayoutSimilarityV2 {
        // Geometry: per-page mean over the shared page prefix; penalize page-count difference.
        let minPages = min(pages.count, other.pages.count)
        var geometrySum = 0.0
        if minPages > 0 {
            for i in 0..<minPages {
                let a = pages[i]
                let b = other.pages[i]
                let wDiff = abs(Double(a.widthPoints - b.widthPoints))
                    / max(Double(max(a.widthPoints, b.widthPoints)), 1)
                let hDiff = abs(Double(a.heightPoints - b.heightPoints))
                    / max(Double(max(a.heightPoints, b.heightPoints)), 1)
                // Rotation-aware geometry (2026-09-08, blend-sweep calibration):
                // a page rotated by a multiple of 90° is the same layout — a
                // rotated scan must match (F-3 doctrine). The penalty measures
                // only the non-axis-aligned residual (45° delta → 45/360).
                let rawRot = abs(Double(a.rotationDegrees - b.rotationDegrees))
                let rDiff = [0.0, 90.0, 180.0, 270.0]
                    .map { abs(rawRot - $0) }.min()! / 360.0
                geometrySum += 1 - (wDiff + hDiff + rDiff) / 3
            }
        }
        let countPenalty = Double(abs(pages.count - other.pages.count))
            / Double(max(pages.count, other.pages.count))
        let geometry = minPages > 0 ? (geometrySum / Double(minPages)) * (1 - countPenalty) : 0

        // F-4 fix: per-page aligned comparison instead of pooled cells.
        // Pooling merged all pages into one cell set, so two dense multi-page
        // documents with similar letter-grid occupancy inflated the score
        // (Observed: geometry↔navigation text=0.824). Aligning page-by-page
        // over the shared prefix keeps the comparison structural — the same
        // structure the geometry component already uses.
        // Text channel: blend 30% projection (content-invariant) + 70% cell Jaccard.
        // Projection captures WHERE text exists (column structure, headers, sidebars).
        // Cell Jaccard captures WHAT text exists (position-specific content).
        // The blend is more content-invariant than pure cell Jaccard while
        // retaining fine-grained positional discrimination.
        //
        // Calibration evidence (44-fixture corpus):
        // - 70% projection + 30% Jaccard: raises single-column variant pair to 0.94 (fails)
        // - 50% projection + 50% Jaccard: raises to 0.915 (fails)
        // - 30% projection + 70% Jaccard: 0.889 (passes, below 0.90 threshold)
        //
        // The 30% projection weight is the maximum that keeps all non-graphics-heavy
        // negatives below the 0.90 threshold. The projection component improves
        // content-invariance for documents with similar column structure but different
        // text content.
        let textCellJaccard = alignedJaccard(other, keyPath: \.textCells)
        let textProjection = projectionTextSimilarity(other)
        let textLayout = 0.3 * textProjection + 0.7 * textCellJaccard
        let fieldLayout = alignedJaccard(other, keyPath: \.fieldCells)
        let annotationLayout = alignedJaccard(other, keyPath: \.annotationCells)

        // Raster: blend of three content-invariant channels:
        // - Projection profiles (95%): WHERE content exists along x/y axes — most robust
        // - Edge detection (3%): layout structure (lines, borders, regions)
        // - Structural occupancy (2%): where content exists structurally
        // Edge/occupancy weights are low because cell-level operations are
        // sensitive to rendering differences; projection profiles are inherently
        // content-invariant (x/y histograms absorb pixel noise).
        //
        // Blend shares are overridable for calibration sweeps (same precedent
        // as rasterWeightOverride); the shipped values are 0.95/0.03/0.02
        // (calibrated 2026-09-01 — see raster-weight-analysis audit §9).
        let rasterProjection = projectionRasterSimilarity(other)
        let rasterEdge = edgeRasterSimilarity(other)
        // Prefer graded occupancy (continuous cosine similarity) over binary
        // Jaccard when graded data is available. Graded occupancy is more
        // content-invariant because it compares HOW MUCH ink each cell has,
        // not WHETHER it has ink — reducing sensitivity to anti-aliasing.
        let hasGraded = pages.contains { !$0.gradedOccupancyCells.isEmpty }
            || other.pages.contains { !$0.gradedOccupancyCells.isEmpty }
        let rasterOccupancy = hasGraded
            ? gradedOccupancySimilarity(other)
            : occupancyRasterSimilarity(other)
        let b = rasterBlendOverride ?? (projection: 0.95, edge: 0.03, occupancy: 0.02)
        let rasterLayout = b.projection * rasterProjection + b.edge * rasterEdge + b.occupancy * rasterOccupancy

        // Region: connected-component region similarity (content-invariant text layout).
        // Compares macro-level text structure (how many blocks, where, what shape)
        // instead of cell-level content. Two documents with the same text block
        // layout but different text score high.
        let regionLayout = regionSimilarity(other)

        // F-5 fix: renormalize weights when channels have no content.
        //
        // Empty channels score 1.0 via alignedJaccard (honest agreement on
        // absence), but with fixed weights this inflates the total for
        // zero-content documents. Redistributing weight to channels that
        // actually have data keeps the comparison grounded in observable
        // structure.
        //
        // Graphics-heavy pages (both docs have raster but no text): empty
        // text/field/annotation channels are excluded (weight=0) and the
        // remaining geometry+raster weights are renormalized. This is
        // correct — the excluded channels contribute 0 to the total, so
        // there is no inflation. The renormalization ensures the total
        // reflects only the channels with observable data.
        //
        // Why not use neutral0.5 for empty channels? Because the neutral
        // value deflates family scores (minPositive drops from 0.9012 to
        // 0.8660, below the 0.90 threshold). The binding constraint is
        // that we cannot distinguish "measurement limitation" from "genuine
        // absence" at comparison time — both cases look identical.
        let hasText = pages.contains { !$0.textCells.isEmpty }
            || other.pages.contains { !$0.textCells.isEmpty }
        let hasField = pages.contains { !$0.fieldCells.isEmpty }
            || other.pages.contains { !$0.fieldCells.isEmpty }
        let hasAnnot = pages.contains { !$0.annotationCells.isEmpty }
            || other.pages.contains { !$0.annotationCells.isEmpty }
        let hasRaster = pages.contains { !$0.rasterCells.isEmpty }
            || other.pages.contains { !$0.rasterCells.isEmpty }
        let hasRegion = pages.contains { !$0.textRegions.isEmpty }
            || other.pages.contains { !$0.textRegions.isEmpty }
        let activeAnnotatedWeight = hasAnnot ? Self.annotationWeight : 0
        let activeFieldWeight = hasField ? Self.fieldWeight : 0
        let activeTextWeight = hasText ? Self.textWeight : 0
        let effectiveRasterWeight = rasterWeightOverride ?? Self.rasterWeight
        let activeRasterWeight = hasRaster ? effectiveRasterWeight : 0
        let activeRegionWeight = hasRegion ? Self.regionWeight : 0
        let activeTotal = Self.geometryWeight + activeTextWeight + activeFieldWeight + activeAnnotatedWeight + activeRasterWeight + activeRegionWeight
        let renormGeometry = Self.geometryWeight / activeTotal
        let renormText = activeTextWeight / activeTotal
        let renormField = activeFieldWeight / activeTotal
        let renormAnnot = activeAnnotatedWeight / activeTotal
        let renormRaster = activeRasterWeight / activeTotal
        let renormRegion = activeRegionWeight / activeTotal

        let total = renormGeometry * geometry
            + renormText * textLayout
            + renormField * fieldLayout
            + renormAnnot * annotationLayout
            + renormRaster * rasterLayout
            + renormRegion * regionLayout
        let coverage = SimilarityCoverage(
            text: hasText, field: hasField, annotation: hasAnnot,
            region: hasRegion, raster: hasRaster)
        return LayoutSimilarityV2(
            geometry: geometry,
            textLayout: textLayout,
            fieldLayout: fieldLayout,
            annotationLayout: annotationLayout,
            rasterLayout: rasterLayout,
            regionLayout: regionLayout,
            total: total,
            coverage: coverage
        )
    }

    /// Per-page aligned Jaccard for a component (F-4 fix).
    ///
    /// Pairs the shared page prefix by index, averages the per-page Jaccard
    /// over the pages where the feature actually exists, then applies the
    /// page-count penalty (a 4-page doc can never match a 3-page doc at 1.0).
    ///
    /// Empty-empty page pairs are **skipped as uninformative**, not scored
    /// 1.0 — scoring them pulled the mean up on sparse components (Observed
    /// during the fix: plain-text↔navigation annotation went 0.000 → 0.667,
    /// pushing the total above the family threshold). The component scores
    /// 1.0 only when both documents lack the feature entirely (honest
    /// agreement on absence, matching the pre-alignment semantics).
    private func alignedJaccard(
        _ other: LayoutFingerprintV2,
        keyPath: KeyPath<PageLayout, [Cell]>
    ) -> Double {
        let minPages = min(pages.count, other.pages.count)
        guard minPages > 0 else { return 0 }
        var sum = 0.0
        var compared = 0
        for i in 0..<minPages {
            let a = Set(pages[i][keyPath: keyPath])
            let b = Set(other.pages[i][keyPath: keyPath])
            if a.isEmpty && b.isEmpty { continue }
            sum += jaccard(a, b)
            compared += 1
        }
        if compared == 0 {
            // Feature absent across both documents entirely.
            return 1.0
        }
        let countPenalty = Double(abs(pages.count - other.pages.count))
            / Double(max(pages.count, other.pages.count))
        return (sum / Double(compared)) * (1 - countPenalty)
    }

    private func jaccard(_ a: Set<Cell>, _ b: Set<Cell>) -> Double {
        // Agreement on absence is perfect agreement (e.g., both documents have
        // no annotations). Only one-sided absence scores 0.
        if a.isEmpty && b.isEmpty { return 1.0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }

    /// Raster similarity using projection profiles.
    ///
    /// Projection profiles capture macro-level layout structure (columns,
    /// headers, sidebars) and are inherently content-invariant. Two documents
    /// with the same column structure but different text score high.
    ///
    /// Per-page aligned: compare projection profiles page-by-page, then
    /// apply the page-count penalty.
    private func projectionRasterSimilarity(
        _ other: LayoutFingerprintV2
    ) -> Double {
        let minPages = min(pages.count, other.pages.count)
        guard minPages > 0 else { return 0 }

        var sum = 0.0
        var compared = 0
        for i in 0..<minPages {
            let aH = pages[i].rasterProjectionH
            let aV = pages[i].rasterProjectionV
            let bH = other.pages[i].rasterProjectionH
            let bV = other.pages[i].rasterProjectionV

            // Both empty → agreement on absence.
            if aH.isEmpty && bH.isEmpty { continue }

            // Compute cosine similarity for horizontal and vertical.
            let hSim = Self.cosineSimilarity(aH, bH)
            let vSim = Self.cosineSimilarity(aV, bV)
            sum += (hSim + vSim) / 2
            compared += 1
        }

        if compared == 0 {
            // No projection data on any shared page.
            return 1.0
        }

        let countPenalty = Double(abs(pages.count - other.pages.count))
            / Double(max(pages.count, other.pages.count))
        return (sum / Double(compared)) * (1 - countPenalty)
    }

    /// Edge raster similarity — Jaccard on edge-detected cells.
    /// Captures layout structure (lines, borders, regions) — content-invariant.
    private func edgeRasterSimilarity(
        _ other: LayoutFingerprintV2
    ) -> Double {
        return alignedJaccard(other, keyPath: \.edgeCells)
    }

    /// Structural occupancy similarity — Jaccard on density-thresholded cells.
    /// Coarser than raw raster; captures where content exists structurally.
    private func occupancyRasterSimilarity(
        _ other: LayoutFingerprintV2
    ) -> Double {
        return alignedJaccard(other, keyPath: \.occupancyCells)
    }

    /// Graded occupancy similarity — cosine similarity on fractional coverage.
    ///
    /// Unlike binary Jaccard (occupied/not), graded occupancy captures HOW
    /// MUCH ink each cell has. Two cells with 80% and 75% coverage score
    /// nearly identical, while binary Jaccard treats them as identical to
    /// cells with 100% coverage. This reduces sensitivity to anti-aliasing
    /// differences near content boundaries.
    ///
    /// Per-page aligned: compare graded vectors page-by-page.
    private func gradedOccupancySimilarity(
        _ other: LayoutFingerprintV2
    ) -> Double {
        let minPages = min(pages.count, other.pages.count)
        guard minPages > 0 else { return 0 }

        var sum = 0.0
        var compared = 0
        for i in 0..<minPages {
            let aCells = pages[i].gradedOccupancyCells
            let bCells = other.pages[i].gradedOccupancyCells

            // Both empty → agreement on absence.
            if aCells.isEmpty && bCells.isEmpty { continue }

            // Build coverage vectors keyed by (scale, col, row) — the
            // multi-scale grids share coordinate space, so a 16pt cell and a
            // 64pt cell at the same (col, row) are different features and
            // must not collide.
            struct ScaleKey: Hashable { let scale: Double; let col: Int; let row: Int }
            var allKeys = Set<ScaleKey>()
            for c in aCells { allKeys.insert(ScaleKey(scale: c.scale, col: c.col, row: c.row)) }
            for c in bCells { allKeys.insert(ScaleKey(scale: c.scale, col: c.col, row: c.row)) }

            let sortedKeys = allKeys.sorted { ($0.scale, $0.row, $0.col) < ($1.scale, $1.row, $1.col) }
            let aMap = Dictionary(uniqueKeysWithValues: aCells.map { (ScaleKey(scale: $0.scale, col: $0.col, row: $0.row), $0.coverage) })
            let bMap = Dictionary(uniqueKeysWithValues: bCells.map { (ScaleKey(scale: $0.scale, col: $0.col, row: $0.row), $0.coverage) })

            var vecA: [Double] = []
            var vecB: [Double] = []
            vecA.reserveCapacity(sortedKeys.count)
            vecB.reserveCapacity(sortedKeys.count)
            for key in sortedKeys {
                vecA.append(aMap[key] ?? 0.0)
                vecB.append(bMap[key] ?? 0.0)
            }

            // Cosine similarity on the coverage vectors.
            let sim = Self.cosineSimilarity(vecA, vecB)
            sum += sim
            compared += 1
        }

        if compared == 0 { return 1.0 }

        let countPenalty = Double(abs(pages.count - other.pages.count))
            / Double(max(pages.count, other.pages.count))
        return (sum / Double(compared)) * (1 - countPenalty)
    }

    /// Text similarity using text projection profiles.
    ///
    /// Text projection profiles capture WHERE text exists (which rows and
    /// columns have text content), not WHAT text exists. Two documents with
    /// the same column structure but different text content have similar
    /// text projections because text occupies the same structural regions.
    ///
    /// This is the content-invariant complement to the cell-level Jaccard,
    /// which is sensitive to exact character positions.
    private func projectionTextSimilarity(
        _ other: LayoutFingerprintV2
    ) -> Double {
        let minPages = min(pages.count, other.pages.count)
        guard minPages > 0 else { return 0 }

        var sum = 0.0
        var compared = 0
        for i in 0..<minPages {
            let aH = pages[i].textProjectionH
            let aV = pages[i].textProjectionV
            let bH = other.pages[i].textProjectionH
            let bV = other.pages[i].textProjectionV

            // Both empty → agreement on absence.
            if aH.isEmpty && bH.isEmpty { continue }

            let hSim = Self.cosineSimilarity(aH, bH)
            let vSim = Self.cosineSimilarity(aV, bV)
            sum += (hSim + vSim) / 2
            compared += 1
        }

        if compared == 0 { return 1.0 }

        let countPenalty = Double(abs(pages.count - other.pages.count))
            / Double(max(pages.count, other.pages.count))
        return (sum / Double(compared)) * (1 - countPenalty)
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
        return 1.0
    }

    /// Connected-component region similarity across shared pages.
    ///
    /// Compares macro-level text layout structure: how many text blocks exist,
    /// where they are, and what shape they are. Two documents with the same
    /// text block layout but different text content score high because regions
    /// are defined by spatial clustering, not content.
    ///
    /// Uses the greedy centroid-matching algorithm from
    /// `ContentInvariantRasterExtractor.regionSimilarity` with per-page
    /// alignment (F-4 style).
    private func regionSimilarity(_ other: LayoutFingerprintV2) -> Double {
        let minPages = min(pages.count, other.pages.count)
        guard minPages > 0 else { return 0 }

        var sum = 0.0
        var compared = 0
        for i in 0..<minPages {
            let aRegions = pages[i].textRegions
            let bRegions = other.pages[i].textRegions

            // Both empty → agreement on absence.
            if aRegions.isEmpty && bRegions.isEmpty { continue }

            let sim = ContentInvariantRasterExtractor.regionSimilarity(aRegions, bRegions)
            sum += sim
            compared += 1
        }

        if compared == 0 { return 1.0 }

        let countPenalty = Double(abs(pages.count - other.pages.count))
            / Double(max(pages.count, other.pages.count))
        return (sum / Double(compared)) * (1 - countPenalty)
    }
}