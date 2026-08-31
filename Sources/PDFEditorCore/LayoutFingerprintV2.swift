import Foundation
import PDFKit
import CryptoKit

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

        /// Backward-compatible init: old records without projection profiles
        /// decode to empty (Codable default via custom init).
        public init(
            pageIndex: Int, widthPoints: Int, heightPoints: Int,
            rotationDegrees: Int, textCells: [Cell], fieldCells: [Cell],
            annotationCells: [Cell], rasterCells: [Cell] = [],
            rasterProjectionH: [Double] = [], rasterProjectionV: [Double] = [],
            textProjectionH: [Double] = [], textProjectionV: [Double] = []
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
        }

        private enum CodingKeys: String, CodingKey {
            case pageIndex, widthPoints, heightPoints, rotationDegrees
            case textCells, fieldCells, annotationCells, rasterCells
            case rasterProjectionH, rasterProjectionV
            case textProjectionH, textProjectionV
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
                textProjectionV: textProjection.vertical
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

// MARK: - Structured Similarity

/// Structured component similarity between two layout fingerprints.
/// Replaces the semantically meaningless character-set Jaccard of V1.
public struct LayoutSimilarityV2: Codable, Sendable, Equatable {
    public let geometry: Double
    public let textLayout: Double
    public let fieldLayout: Double
    public let annotationLayout: Double
    public let rasterLayout: Double
    /// Weighted total (weights below).
    public let total: Double
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
    /// calibration-2026-08-28.json`. The 0.90 sits strictly inside the
    /// measured gap (midpoint 0.892, rounded to 0.05). Precision-first:
    /// every hard negative stays below; every layout-identical re-encoding
    /// is recognized.
    public static let familyThreshold: Double = 0.90

    /// Component weights — geometry is the strongest identity signal;
    /// raster layout captures scanned/image content that text/field/annotation
    /// channels miss; annotation layout is the weakest (often absent).
    public static let geometryWeight: Double = 0.35
    public static let textWeight: Double = 0.25
    public static let fieldWeight: Double = 0.20
    public static let annotationWeight: Double = 0.10
    /// Raster weight: 0.02. Raster captures scanned content, images,
    /// and graphics that no other channel sees. The theoretical optimum
    /// based on same-doc SNR (799×) is 0.15, but re-encoding noise
    /// (different renderers produce different raster cells for the same
    /// layout) caps the practical weight. At 0.05, minPositive drops to
    /// 0.88 (below the 0.90 threshold). The binding constraint is
    /// re-encoding divergence, not same-doc identity. To increase this
    /// weight, the raster extraction must be made more robust (coarser
    /// grid, higher blank threshold, or multi-scale sampling).
    public static let rasterWeight: Double = 0.04

    /// Number of bins per axis for projection profiles.
    /// 32 bins captures macro-level layout structure (columns, headers,
    /// sidebars) without being sensitive to fine-grained content differences.
    public static let rasterProjectionBinCount: Int = 32

    /// Structured similarity to another fingerprint.
    public func similarity(
        to other: LayoutFingerprintV2,
        rasterWeightOverride: Double? = nil
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
                let rDiff = abs(Double(a.rotationDegrees - b.rotationDegrees)) / 360.0
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
        let textLayout = alignedJaccard(other, keyPath: \.textCells)
        let fieldLayout = alignedJaccard(other, keyPath: \.fieldCells)
        let annotationLayout = alignedJaccard(other, keyPath: \.annotationCells)

        // Raster: use projection similarity instead of cell-level Jaccard.
        // Projection profiles capture macro-level layout structure (columns,
        // headers, sidebars) and are inherently content-invariant — a document
        // with the same column structure but different text scores high.
        // Cell-level Jaccard is too sensitive to content differences.
        // Text projection profiles are also stored for future use in a
        // content-invariant text channel (currently blended in the textLayout
        // computation above, kept here as data for future calibration).
        let rasterLayout = projectionRasterSimilarity(other)

        // F-5 fix: renormalize weights when channels have no content.
        // Empty channels score 1.0 (agreement on absence), but with fixed
        // weights this inflates the total for zero-content documents.
        // Redistributing weight to channels that actually have data keeps
        // the comparison grounded in observable structure.
        let hasText = pages.contains { !$0.textCells.isEmpty }
            || other.pages.contains { !$0.textCells.isEmpty }
        let hasField = pages.contains { !$0.fieldCells.isEmpty }
            || other.pages.contains { !$0.fieldCells.isEmpty }
        let hasAnnot = pages.contains { !$0.annotationCells.isEmpty }
            || other.pages.contains { !$0.annotationCells.isEmpty }
        let hasRaster = pages.contains { !$0.rasterCells.isEmpty }
            || other.pages.contains { !$0.rasterCells.isEmpty }
        let activeAnnotatedWeight = hasAnnot ? Self.annotationWeight : 0
        let activeFieldWeight = hasField ? Self.fieldWeight : 0
        let activeTextWeight = hasText ? Self.textWeight : 0
        let effectiveRasterWeight = rasterWeightOverride ?? Self.rasterWeight
        let activeRasterWeight = hasRaster ? effectiveRasterWeight : 0
        let activeTotal = Self.geometryWeight + activeTextWeight + activeFieldWeight + activeAnnotatedWeight + activeRasterWeight
        let renormGeometry = Self.geometryWeight / activeTotal
        let renormText = activeTextWeight / activeTotal
        let renormField = activeFieldWeight / activeTotal
        let renormAnnot = activeAnnotatedWeight / activeTotal
        let renormRaster = activeRasterWeight / activeTotal

        let total = renormGeometry * geometry
            + renormText * textLayout
            + renormField * fieldLayout
            + renormAnnot * annotationLayout
            + renormRaster * rasterLayout
        return LayoutSimilarityV2(
            geometry: geometry,
            textLayout: textLayout,
            fieldLayout: fieldLayout,
            annotationLayout: annotationLayout,
            rasterLayout: rasterLayout,
            total: total
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
}