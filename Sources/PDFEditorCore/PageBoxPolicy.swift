import Foundation
import CoreGraphics

/// Canonical page-box precision and tolerance policy.
///
/// Defines how page boxes (mediaBox, cropBox, bleedBox, trimBox, artBox)
/// are extracted, compared, and used across PDFKit, PDF.js, coordinates,
/// fingerprints, and overlay operations.
///
/// First principle: page boxes are the ground truth for document geometry.
/// Every coordinate system (PDFKit, PDF.js, overlay, fingerprint) must
/// agree on what a page's dimensions are. Disagreements cause misalignment.
///
/// The policy establishes:
/// 1. Canonical box hierarchy (which box "wins" when multiple are present)
/// 2. Precision requirements (coordinate system, DPI, rounding)
/// 3. Tolerance for cross-system comparison
/// 4. Fingerprint invariants (what must be stable across renders)
///
/// Doctrine alignment:
/// - §5: Evidence-based — every tolerance is measurable and tested
/// - §11: Engineering integrity — precision is enforced, not assumed
/// - §3: Do things smartly — hierarchy prevents ambiguity

// MARK: - Page Box Type

/// The five standard PDF page boxes.
public enum PageBoxType: String, Codable, Sendable, CaseIterable, Comparable {
    case mediaBox = "mediaBox"
    case cropBox = "cropBox"
    case bleedBox = "bleedBox"
    case trimBox = "trimBox"
    case artBox = "artBox"

    /// Canonical priority order (highest = most authoritative).
    /// When multiple boxes are present, the highest-priority box wins.
    public var priority: Int {
        switch self {
        case .cropBox: return 5  // User-visible area
        case .mediaBox: return 4 // Physical page size
        case .trimBox: return 3  // Final trimmed size
        case .bleedBox: return 2 // Bleed area
        case .artBox: return 1   // Content area
        }
    }

    /// Whether this box should be used for rendering.
    public var isRenderBox: Bool {
        switch self {
        case .cropBox, .mediaBox: return true
        case .bleedBox, .trimBox, .artBox: return false
        }
    }

    public static func < (lhs: PageBoxType, rhs: PageBoxType) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - Page Box Values

/// Extracted page box values from a PDF page.
public struct PageBoxValues: Codable, Sendable {
    public let mediaBox: CGRect
    public let cropBox: CGRect
    public let bleedBox: CGRect
    public let trimBox: CGRect
    public let artBox: CGRect
    /// Which box is the canonical render box.
    public let canonicalBox: PageBoxType
    /// The effective page size (canonical box dimensions).
    public let effectiveSize: CGSize

    public init(
        mediaBox: CGRect,
        cropBox: CGRect,
        bleedBox: CGRect,
        trimBox: CGRect,
        artBox: CGRect
    ) {
        self.mediaBox = mediaBox
        self.cropBox = cropBox
        self.bleedBox = bleedBox
        self.trimBox = trimBox
        self.artBox = artBox

        // Determine canonical box: highest-priority non-empty box
        let candidates: [(PageBoxType, CGRect)] = [
            (.cropBox, cropBox),
            (.mediaBox, mediaBox),
            (.trimBox, trimBox),
            (.bleedBox, bleedBox),
            (.artBox, artBox)
        ]

        let valid = candidates.filter { !$0.1.isEmpty && $0.1.width > 0 && $0.1.height > 0 }
        if let best = valid.max(by: { $0.0.priority < $1.0.priority }) {
            self.canonicalBox = best.0
            self.effectiveSize = best.1.size
        } else {
            self.canonicalBox = .mediaBox
            self.effectiveSize = mediaBox.size
        }
    }

    /// Whether all boxes are present and valid.
    public var isComplete: Bool {
        [mediaBox, cropBox, bleedBox, trimBox, artBox].allSatisfy {
            $0.width > 0 && $0.height > 0
        }
    }
}

// MARK: - Precision Policy

/// Precision requirements for page-box operations.
public struct PageBoxPrecisionPolicy: Codable, Sendable {
    /// Coordinate system used throughout.
    public let coordinateSystem: CoordinateSystem
    /// DPI for rendering (affects coordinate precision).
    public let renderDPI: Int
    /// Tolerance for coordinate comparison (in PDF points).
    public let coordinateTolerance: Double
    /// Tolerance for size comparison (in PDF points).
    public let sizeTolerance: Double
    /// Rounding precision for coordinates (decimal places).
    public let coordinateRounding: Int
    /// Whether to normalize negative coordinates.
    public let normalizeNegativeCoords: Bool
    /// Whether cropBox should override mediaBox when smaller.
    public let cropBoxOverridesMediaBox: Bool

    public init(
        coordinateSystem: CoordinateSystem = .pdfPoints,
        renderDPI: Int = 72,
        coordinateTolerance: Double = 0.01,
        sizeTolerance: Double = 0.1,
        coordinateRounding: Int = 2,
        normalizeNegativeCoords: Bool = true,
        cropBoxOverridesMediaBox: Bool = true
    ) {
        self.coordinateSystem = coordinateSystem
        self.renderDPI = renderDPI
        self.coordinateTolerance = coordinateTolerance
        self.sizeTolerance = sizeTolerance
        self.coordinateRounding = coordinateRounding
        self.normalizeNegativeCoords = normalizeNegativeCoords
        self.cropBoxOverridesMediaBox = cropBoxOverridesMediaBox
    }

    /// Standard policy for PDFKit (macOS).
    public static let pdfKitStandard = PageBoxPrecisionPolicy(
        coordinateSystem: .pdfPoints,
        renderDPI: 72,
        coordinateTolerance: 0.01,
        sizeTolerance: 0.1,
        coordinateRounding: 2,
        normalizeNegativeCoords: true,
        cropBoxOverridesMediaBox: true
    )

    /// Standard policy for PDF.js (web).
    public static let pdfJsStandard = PageBoxPrecisionPolicy(
        coordinateSystem: .pdfPoints,
        renderDPI: 72,
        coordinateTolerance: 0.1, // PDF.js has slightly less precision
        sizeTolerance: 0.5,
        coordinateRounding: 1,
        normalizeNegativeCoords: true,
        cropBoxOverridesMediaBox: true
    )

    /// Policy for overlay operations (must match exactly).
    public static let overlayStrict = PageBoxPrecisionPolicy(
        coordinateSystem: .pdfPoints,
        renderDPI: 72,
        coordinateTolerance: 0.001,
        sizeTolerance: 0.01,
        coordinateRounding: 3,
        normalizeNegativeCoords: true,
        cropBoxOverridesMediaBox: true
    )

    /// Policy for fingerprinting (must be stable across renders).
    public static let fingerprintStable = PageBoxPrecisionPolicy(
        coordinateSystem: .pdfPoints,
        renderDPI: 72,
        coordinateTolerance: 0.0,
        sizeTolerance: 0.0,
        coordinateRounding: 0,
        normalizeNegativeCoords: true,
        cropBoxOverridesMediaBox: true
    )

    /// Relaxed tolerance for cross-engine comparison with known drift.
    public static let relaxed = PageBoxPrecisionPolicy(
        coordinateSystem: .pdfPoints,
        renderDPI: 72,
        coordinateTolerance: 1.0,
        sizeTolerance: 1.0,
        coordinateRounding: 0,
        normalizeNegativeCoords: true,
        cropBoxOverridesMediaBox: true
    )
}

// MARK: - Coordinate System

public enum CoordinateSystem: String, Codable, Sendable {
    case pdfPoints = "pdfPoints"   // 72 DPI, origin at bottom-left
    case pixels = "pixels"         // Device pixels, origin at top-left
    case normalized = "normalized" // 0-1 range
}

// MARK: - Cross-System Comparison

/// Result of comparing page boxes across systems.
public struct PageBoxComparison: Codable, Sendable {
    public let pdfKitValues: PageBoxValues
    public let pdfJsValues: PageBoxValues?
    public let sizeMatch: Bool
    public let coordinateMatch: Bool
    public let canonicalBoxMatch: Bool
    public let sizeDeviation: Double // points
    public let coordinateDeviation: Double // points
    public let issues: [String]

    public init(
        pdfKitValues: PageBoxValues,
        pdfJsValues: PageBoxValues? = nil,
        sizeMatch: Bool,
        coordinateMatch: Bool,
        canonicalBoxMatch: Bool,
        sizeDeviation: Double,
        coordinateDeviation: Double,
        issues: [String]
    ) {
        self.pdfKitValues = pdfKitValues
        self.pdfJsValues = pdfJsValues
        self.sizeMatch = sizeMatch
        self.coordinateMatch = coordinateMatch
        self.canonicalBoxMatch = canonicalBoxMatch
        self.sizeDeviation = sizeDeviation
        self.coordinateDeviation = coordinateDeviation
        self.issues = issues
    }

    /// Whether the comparison passed all checks.
    public var passed: Bool {
        issues.isEmpty
    }
}

// MARK: - Page Box Policy

/// Enforces page-box precision across all systems.
public struct PageBoxPolicy: Sendable {
    /// The precision policy to enforce.
    public let precision: PageBoxPrecisionPolicy

    public init(precision: PageBoxPrecisionPolicy = .pdfKitStandard) {
        self.precision = precision
    }

    /// Extract page boxes from a CGRect (mediaBox) and derive others.
    public func extractBoxes(mediaBox: CGRect) -> PageBoxValues {
        // Default: all boxes equal to mediaBox (most PDFs don't set them explicitly)
        let cropBox = mediaBox // CropBox defaults to MediaBox if not set
        let bleedBox = mediaBox
        let trimBox = mediaBox
        let artBox = mediaBox

        return PageBoxValues(
            mediaBox: normalizedBox(mediaBox),
            cropBox: normalizedBox(cropBox),
            bleedBox: normalizedBox(bleedBox),
            trimBox: normalizedBox(trimBox),
            artBox: normalizedBox(artBox)
        )
    }

    /// Extract page boxes from explicit PDFKit box values.
    public func extractBoxes(
        mediaBox: CGRect,
        cropBox: CGRect?,
        bleedBox: CGRect?,
        trimBox: CGRect?,
        artBox: CGRect?
    ) -> PageBoxValues {
        PageBoxValues(
            mediaBox: normalizedBox(mediaBox),
            cropBox: normalizedBox(cropBox ?? mediaBox),
            bleedBox: normalizedBox(bleedBox ?? mediaBox),
            trimBox: normalizedBox(trimBox ?? mediaBox),
            artBox: normalizedBox(artBox ?? mediaBox)
        )
    }

    /// Compare page boxes across two systems (e.g., PDFKit vs PDF.js).
    public func compare(
        pdfKit: PageBoxValues,
        pdfJs: PageBoxValues
    ) -> PageBoxComparison {
        var issues: [String] = []

        // Size comparison
        let widthDeviation = abs(pdfKit.effectiveSize.width - pdfJs.effectiveSize.width)
        let heightDeviation = abs(pdfKit.effectiveSize.height - pdfJs.effectiveSize.height)
        let sizeDeviation = max(widthDeviation, heightDeviation)
        let sizeMatch = sizeDeviation <= precision.sizeTolerance

        if !sizeMatch {
            issues.append("Size mismatch: PDFKit \(pdfKit.effectiveSize) vs PDFJs \(pdfJs.effectiveSize) (deviation: \(String(format: "%.2f", sizeDeviation))pt)")
        }

        // Coordinate comparison (origin)
        let originDeviation = max(
            abs(pdfKit.mediaBox.origin.x - pdfJs.mediaBox.origin.x),
            abs(pdfKit.mediaBox.origin.y - pdfJs.mediaBox.origin.y)
        )
        let coordinateMatch = originDeviation <= precision.coordinateTolerance

        if !coordinateMatch {
            issues.append("Origin mismatch: PDFKit \(pdfKit.mediaBox.origin) vs PDFJs \(pdfJs.mediaBox.origin) (deviation: \(String(format: "%.2f", originDeviation))pt)")
        }

        // Canonical box comparison
        let canonicalMatch = pdfKit.canonicalBox == pdfJs.canonicalBox
        if !canonicalMatch {
            issues.append("Canonical box mismatch: PDFKit uses \(pdfKit.canonicalBox.rawValue), PDFJs uses \(pdfJs.canonicalBox.rawValue)")
        }

        return PageBoxComparison(
            pdfKitValues: pdfKit,
            pdfJsValues: pdfJs,
            sizeMatch: sizeMatch,
            coordinateMatch: coordinateMatch,
            canonicalBoxMatch: canonicalMatch,
            sizeDeviation: sizeDeviation,
            coordinateDeviation: originDeviation,
            issues: issues
        )
    }

    /// Normalize a box (round coordinates, handle negative origins).
    public func normalizedBox(_ rect: CGRect) -> CGRect {
        var result = rect

        if precision.normalizeNegativeCoords && result.origin.x < 0 {
            result.origin.x = 0
        }
        if precision.normalizeNegativeCoords && result.origin.y < 0 {
            result.origin.y = 0
        }

        // Round coordinates
        let factor = pow(10.0, Double(precision.coordinateRounding))
        result.origin.x = (result.origin.x * factor).rounded() / factor
        result.origin.y = (result.origin.y * factor).rounded() / factor
        result.size.width = (result.size.width * factor).rounded() / factor
        result.size.height = (result.size.height * factor).rounded() / factor

        return result
    }

    /// Generate a stable fingerprint from page boxes.
    public func fingerprint(from boxes: PageBoxValues) -> String {
        let policy = PageBoxPrecisionPolicy.fingerprintStable
        let factor = pow(10.0, Double(policy.coordinateRounding))

        let components = [
            "\(Int(boxes.mediaBox.width * factor))x\(Int(boxes.mediaBox.height * factor))",
            "\(Int(boxes.cropBox.width * factor))x\(Int(boxes.cropBox.height * factor))",
            boxes.canonicalBox.rawValue
        ]

        return components.joined(separator: "|")
    }
}
