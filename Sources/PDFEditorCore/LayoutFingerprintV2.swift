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
    public static let featureVersion = "layout-features-2"

    /// Default quantization cell in points (4pt ≈ 0.5% of a Letter page).
    public static let defaultCellSizePoints: Double = 4.0

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

            pages.append(LayoutFingerprintV2.PageLayout(
                pageIndex: pageIndex,
                widthPoints: Int(bounds.width.rounded()),
                heightPoints: Int(bounds.height.rounded()),
                rotationDegrees: page.rotation,
                textCells: textCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                fieldCells: fieldCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) },
                annotationCells: annotationCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
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
}

// MARK: - Structured Similarity

/// Structured component similarity between two layout fingerprints.
/// Replaces the semantically meaningless character-set Jaccard of V1.
public struct LayoutSimilarityV2: Codable, Sendable, Equatable {
    public let geometry: Double
    public let textLayout: Double
    public let fieldLayout: Double
    public let annotationLayout: Double
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
    /// annotation layout is the weakest (often absent).
    public static let geometryWeight: Double = 0.35
    public static let textWeight: Double = 0.30
    public static let fieldWeight: Double = 0.25
    public static let annotationWeight: Double = 0.10

    /// Structured similarity to another fingerprint.
    public func similarity(to other: LayoutFingerprintV2) -> LayoutSimilarityV2 {
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

        let total = Self.geometryWeight * geometry
            + Self.textWeight * textLayout
            + Self.fieldWeight * fieldLayout
            + Self.annotationWeight * annotationLayout
        return LayoutSimilarityV2(
            geometry: geometry,
            textLayout: textLayout,
            fieldLayout: fieldLayout,
            annotationLayout: annotationLayout,
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
}