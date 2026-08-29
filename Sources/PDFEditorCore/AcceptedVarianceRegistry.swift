import Foundation

/// Accepted-variance registry — classifies every native/web PDF mismatch
/// with tolerances, owners, and falsifying tests.
///
/// First principle: no mismatch is acceptable unless it is:
/// 1. Classified (what type of difference)
/// 2. Tolerated (how much deviation is allowed)
/// 3. Owned (who is responsible)
/// 4. Falsified (what test proves the tolerance holds)
/// 5. Documented (why this variance exists)
///
/// Any unclassified mismatch is a defect. Any mismatch exceeding its
/// tolerance is a defect. Any mismatch without an owner is a defect.
///
/// Doctrine alignment:
/// - §2: Truth taxonomy — every variance is labeled (Observed/Verified/Inferred)
/// - §5: Evidence-based — every tolerance has a falsifying test
/// - §11: Engineering integrity — variance drift is detected by CI

// MARK: - Variance Category

/// What type of difference this variance describes.
public enum VarianceCategory: String, Codable, Sendable, CaseIterable {
    /// Page box dimensions (mediaBox, cropBox, etc.).
    case pageBox = "page_box"
    /// Text extraction content (different text returned).
    case textContent = "text_content"
    /// Text position/bounding boxes (same text, different coordinates).
    case textPosition = "text_position"
    /// Font metrics (size, family, leading detection).
    case fontMetrics = "font_metrics"
    /// Color values (RGB/CMYK precision).
    case colorValues = "color_values"
    /// Candidate/form field detection (different fields found).
    case candidateDetection = "candidate_detection"
    /// Candidate bounding boxes (same field, different rect).
    case candidateBounds = "candidate_bounds"
    /// Rotation handling (different rotation interpretation).
    case rotationHandling = "rotation_handling"
    /// Encryption/decryption behavior.
    case encryptionBehavior = "encryption_behavior"
    /// Annotation detection (different annotations found).
    case annotationDetection = "annotation_detection"
    /// Image extraction (different images or resolution).
    case imageExtraction = "image_extraction"
    /// Link/action detection.
    case linkDetection = "link_detection"
    /// Metadata extraction.
    case metadataExtraction = "metadata_extraction"
    /// Rendering output (pixel-level differences).
    case renderingOutput = "rendering_output"

    /// Human-readable description.
    public var description: String {
        switch self {
        case .pageBox: return "Page box dimensions"
        case .textContent: return "Text extraction content"
        case .textPosition: return "Text position/bounding boxes"
        case .fontMetrics: return "Font metrics detection"
        case .colorValues: return "Color value precision"
        case .candidateDetection: return "Form field/candidate detection"
        case .candidateBounds: return "Form field bounding boxes"
        case .rotationHandling: return "Rotation handling"
        case .encryptionBehavior: return "Encryption/decryption behavior"
        case .annotationDetection: return "Annotation detection"
        case .imageExtraction: return "Image extraction"
        case .linkDetection: return "Link/action detection"
        case .metadataExtraction: return "Metadata extraction"
        case .renderingOutput: return "Rendering output"
        }
    }
}

// MARK: - Variance Severity

/// How serious this variance is if it exceeds tolerance.
public enum VarianceSeverity: String, Codable, Sendable, Comparable {
    /// Cosmetic — user would never notice.
    case cosmetic = "cosmetic"
    /// Functional — affects feature behavior but document is usable.
    case functional = "functional"
    /// Critical — document is unusable or data is lost.
    case critical = "critical"

    public static func < (lhs: VarianceSeverity, rhs: VarianceSeverity) -> Bool {
        let order: [VarianceSeverity] = [.cosmetic, .functional, .critical]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

// MARK: - Tolerance Type

/// How the tolerance is measured.
public enum ToleranceType: String, Codable, Sendable {
    /// Absolute value in PDF points.
    case absolute = "absolute"
    /// Percentage of the reference value.
    case relative = "relative"
    /// Set membership (allowed values).
    case enumeration = "enumeration"
    /// Boolean (must match exactly).
    case exact = "exact"
    /// Fuzzy string match (Levenshtein distance).
    case fuzzyString = "fuzzy_string"
    /// Structural match (same shape, different content).
    case structural = "structural"
}

// MARK: - Accepted Variance

/// A single accepted variance between native and web implementations.
public struct AcceptedVariance: Codable, Sendable, Identifiable {
    public let id: String
    /// Human-readable name.
    public let name: String
    /// What category of mismatch this is.
    public let category: VarianceCategory
    /// Severity if tolerance is exceeded.
    public let severity: VarianceSeverity
    /// How the tolerance is measured.
    public let toleranceType: ToleranceType
    /// Tolerance value (meaning depends on toleranceType).
    public let toleranceValue: Double
    /// Secondary tolerance (for ranges).
    public let toleranceMax: Double?
    /// Which engine is the "reference" (typically PDFKit for native).
    public let referenceEngine: String
    /// Which engine is the "variant" (typically PDF.js for web).
    public let variantEngine: String
    /// Owner responsible for this variance.
    public let owner: String
    /// Falsifying test name or identifier.
    public let falsifyingTest: String
    /// Gate this variance is tracked under.
    public let gateID: String?
    /// Why this variance exists (root cause).
    public let rootCause: String
    /// Whether this variance is currently accepted.
    public var isAccepted: Bool
    /// Date this variance was last verified.
    public var lastVerified: Date?
    /// Notes or caveats.
    public let notes: String?
    /// Fixture this variance was observed on (if any).
    public let fixtureID: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        category: VarianceCategory,
        severity: VarianceSeverity,
        toleranceType: ToleranceType,
        toleranceValue: Double,
        toleranceMax: Double? = nil,
        referenceEngine: String = "PDFKit",
        variantEngine: String = "PDF.js",
        owner: String,
        falsifyingTest: String,
        gateID: String? = nil,
        rootCause: String,
        isAccepted: Bool = true,
        lastVerified: Date? = nil,
        notes: String? = nil,
        fixtureID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.severity = severity
        self.toleranceType = toleranceType
        self.toleranceValue = toleranceValue
        self.toleranceMax = toleranceMax
        self.referenceEngine = referenceEngine
        self.variantEngine = variantEngine
        self.owner = owner
        self.falsifyingTest = falsifyingTest
        self.gateID = gateID
        self.rootCause = rootCause
        self.isAccepted = isAccepted
        self.lastVerified = lastVerified
        self.notes = notes
        self.fixtureID = fixtureID
    }
}

// MARK: - Variance Check Result

/// Result of checking a measured value against an accepted variance.
public struct VarianceCheckResult: Codable, Sendable {
    /// The variance definition.
    public let variance: AcceptedVariance
    /// Measured value (from variant engine).
    public let measuredValue: Double
    /// Reference value (from reference engine).
    public let referenceValue: Double
    /// Absolute deviation.
    public let deviation: Double
    /// Whether the deviation is within tolerance.
    public let withinTolerance: Bool
    /// Human-readable result.
    public let summary: String

    public init(
        variance: AcceptedVariance,
        measuredValue: Double,
        referenceValue: Double,
        deviation: Double,
        withinTolerance: Bool,
        summary: String
    ) {
        self.variance = variance
        self.measuredValue = measuredValue
        self.referenceValue = referenceValue
        self.deviation = deviation
        self.withinTolerance = withinTolerance
        self.summary = summary
    }
}

// MARK: - Accepted Variance Registry

/// The full registry of accepted native/web variances.
public struct AcceptedVarianceRegistry: Codable, Sendable {
    /// All registered variances.
    public var variances: [AcceptedVariance]

    public init(variances: [AcceptedVariance] = []) {
        self.variances = variances
    }

    // MARK: - Query

    /// Get all variances for a category.
    public func variances(for category: VarianceCategory) -> [AcceptedVariance] {
        variances.filter { $0.category == category }
    }

    /// Get all accepted variances.
    public var acceptedVariances: [AcceptedVariance] {
        variances.filter { $0.isAccepted }
    }

    /// Get all unaccepted (pending) variances.
    public var pendingVariances: [AcceptedVariance] {
        variances.filter { !$0.isAccepted }
    }

    /// Get all variances for a specific gate.
    public func variances(forGate gateID: String) -> [AcceptedVariance] {
        variances.filter { $0.gateID == gateID }
    }

    /// Get all variances owned by a specific owner.
    public func variances(ownedBy owner: String) -> [AcceptedVariance] {
        variances.filter { $0.owner == owner }
    }

    /// Get all critical-severity variances.
    public var criticalVariances: [AcceptedVariance] {
        variances.filter { $0.severity == .critical }
    }

    // MARK: - Check

    /// Check a measured value against a specific variance.
    public func check(
        _ variance: AcceptedVariance,
        measured: Double,
        reference: Double
    ) -> VarianceCheckResult {
        let deviation = abs(measured - reference)

        let withinTolerance: Bool
        switch variance.toleranceType {
        case .absolute:
            withinTolerance = deviation <= variance.toleranceValue
        case .relative:
            let toleranceAbsolute = reference * variance.toleranceValue / 100.0
            withinTolerance = deviation <= toleranceAbsolute
        case .exact:
            withinTolerance = deviation == 0
        default:
            withinTolerance = deviation <= variance.toleranceValue
        }

        let summary: String
        if withinTolerance {
            summary = "PASS: \(variance.name) deviation \(String(format: "%.3f", deviation)) within tolerance \(String(format: "%.3f", variance.toleranceValue))"
        } else {
            summary = "FAIL: \(variance.name) deviation \(String(format: "%.3f", deviation)) exceeds tolerance \(String(format: "%.3f", variance.toleranceValue))"
        }

        return VarianceCheckResult(
            variance: variance,
            measuredValue: measured,
            referenceValue: reference,
            deviation: deviation,
            withinTolerance: withinTolerance,
            summary: summary
        )
    }

    /// Check a measured CGRect against a variance (for page boxes, bounds, etc.).
    public func checkRect(
        _ variance: AcceptedVariance,
        measured: CGRect,
        reference: CGRect
    ) -> VarianceCheckResult {
        // Check the maximum deviation across all four dimensions
        let maxDeviation = max(
            abs(measured.origin.x - reference.origin.x),
            abs(measured.origin.y - reference.origin.y),
            abs(measured.width - reference.width),
            abs(measured.height - reference.height)
        )

        let withinTolerance: Bool
        switch variance.toleranceType {
        case .absolute:
            withinTolerance = maxDeviation <= variance.toleranceValue
        case .relative:
            let maxRefDimension = max(reference.width, reference.height, 1.0)
            let toleranceAbsolute = maxRefDimension * variance.toleranceValue / 100.0
            withinTolerance = maxDeviation <= toleranceAbsolute
        default:
            withinTolerance = maxDeviation <= variance.toleranceValue
        }

        let summary: String
        if withinTolerance {
            summary = "PASS: \(variance.name) max deviation \(String(format: "%.3f", maxDeviation)) within tolerance"
        } else {
            summary = "FAIL: \(variance.name) max deviation \(String(format: "%.3f", maxDeviation)) exceeds tolerance \(String(format: "%.3f", variance.toleranceValue))"
        }

        return VarianceCheckResult(
            variance: variance,
            measuredValue: maxDeviation,
            referenceValue: 0,
            deviation: maxDeviation,
            withinTolerance: withinTolerance,
            summary: summary
        )
    }

    /// Check text content similarity (for textContent variances).
    public func checkText(
        _ variance: AcceptedVariance,
        measured: String,
        reference: String
    ) -> VarianceCheckResult {
        let similarity = textSimilarity(measured, reference)
        let deviation = 1.0 - similarity

        let withinTolerance: Bool
        switch variance.toleranceType {
        case .fuzzyString:
            withinTolerance = deviation <= variance.toleranceValue
        case .exact:
            withinTolerance = measured == reference
        default:
            withinTolerance = deviation <= variance.toleranceValue
        }

        let summary: String
        if withinTolerance {
            summary = "PASS: \(variance.name) similarity \(String(format: "%.1f%%", similarity * 100)) within tolerance"
        } else {
            summary = "FAIL: \(variance.name) similarity \(String(format: "%.1f%%", similarity * 100)) below threshold"
        }

        return VarianceCheckResult(
            variance: variance,
            measuredValue: similarity,
            referenceValue: 1.0,
            deviation: deviation,
            withinTolerance: withinTolerance,
            summary: summary
        )
    }

    // MARK: - Registration

    /// Register a new variance.
    public mutating func register(_ variance: AcceptedVariance) {
        variances.append(variance)
    }

    /// Accept a pending variance.
    public mutating func accept(varianceID: String) {
        if let idx = variances.firstIndex(where: { $0.id == varianceID }) {
            variances[idx].isAccepted = true
            variances[idx].lastVerified = Date()
        }
    }

    /// Reject a variance (mark as not accepted).
    public mutating func reject(varianceID: String) {
        if let idx = variances.firstIndex(where: { $0.id == varianceID }) {
            variances[idx].isAccepted = false
        }
    }

    /// Update last-verified date for all variances.
    public mutating func markAllVerified() {
        let now = Date()
        for i in variances.indices {
            variances[i].lastVerified = now
        }
    }

    // MARK: - Summary

    /// Summary statistics for the registry.
    public var summary: VarianceRegistrySummary {
        var byCategory: [VarianceCategory: Int] = [:]
        var bySeverity: [VarianceSeverity: Int] = [:]
        var byOwner: [String: Int] = [:]
        var byGate: [String: Int] = [:]

        for v in variances {
            byCategory[v.category, default: 0] += 1
            bySeverity[v.severity, default: 0] += 1
            byOwner[v.owner, default: 0] += 1
            if let gate = v.gateID {
                byGate[gate, default: 0] += 1
            }
        }

        return VarianceRegistrySummary(
            totalVariances: variances.count,
            accepted: acceptedVariances.count,
            pending: pendingVariances.count,
            critical: criticalVariances.count,
            byCategory: byCategory,
            bySeverity: bySeverity,
            byOwner: byOwner,
            byGate: byGate
        )
    }

    // MARK: - Export

    /// Export to markdown for human review.
    public func toMarkdown() -> String {
        var md = "# Accepted Variance Registry\n\n"
        md += "| Name | Category | Severity | Tolerance | Owner | Test | Status |\n"
        md += "|---|---|---|---|---|---|---|\n"

        for v in variances.sorted(by: { $0.severity > $1.severity }) {
            let tol = "\(String(format: "%.3f", v.toleranceValue)) \(v.toleranceType.rawValue)"
            let status = v.isAccepted ? "✅ Accepted" : "⏳ Pending"
            md += "| \(v.name) | \(v.category.rawValue) | \(v.severity.rawValue) | \(tol) | \(v.owner) | \(v.falsifyingTest) | \(status) |\n"
        }

        return md
    }

    // MARK: - Helpers

    /// Character-level Jaccard similarity.
    private func textSimilarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return a == b ? 1.0 : 0.0 }
        let setA = Set(a)
        let setB = Set(b)
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        return Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Variance Registry Summary

/// Summary statistics for the accepted-variance registry.
public struct VarianceRegistrySummary: Codable, Sendable {
    public let totalVariances: Int
    public let accepted: Int
    public let pending: Int
    public let critical: Int
    public let byCategory: [VarianceCategory: Int]
    public let bySeverity: [VarianceSeverity: Int]
    public let byOwner: [String: Int]
    public let byGate: [String: Int]

    public init(
        totalVariances: Int,
        accepted: Int,
        pending: Int,
        critical: Int,
        byCategory: [VarianceCategory: Int],
        bySeverity: [VarianceSeverity: Int],
        byOwner: [String: Int],
        byGate: [String: Int]
    ) {
        self.totalVariances = totalVariances
        self.accepted = accepted
        self.pending = pending
        self.critical = critical
        self.byCategory = byCategory
        self.bySeverity = bySeverity
        self.byOwner = byOwner
        self.byGate = byGate
    }
}
