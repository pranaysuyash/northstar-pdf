import Foundation

/// False-positive report generator for recurring-form matching.
///
/// Generates structured reports when hard negatives incorrectly match,
/// providing actionable data for threshold tuning.
///
/// First principle: false-positive reports are more valuable than
/// true-positive reports. Every false positive reveals a weakness in
/// the classification system that could cause real user harm.
///
/// Doctrine alignment:
/// - §5: Evidence-based — every false positive has entry ID, tier, score, reason
/// - §3: Proportional rigor — reports are proportional to false-positive count
/// - §11: Engineering integrity — threshold recommendations are data-driven

// MARK: - False Positive Report

/// A single false-positive instance in the corpus.
public struct FalsePositiveEntry: Codable, Sendable, Identifiable {
    public let id: String
    /// The corpus entry that was incorrectly classified as a match.
    public let entryID: String
    /// The document class (e.g., "invoice", "tax-form").
    public let documentClass: String
    /// The actual tier assigned by the calibrator.
    public let actualTier: MatchingTier
    /// The similarity score that caused the false positive.
    public let score: Double
    /// The template it incorrectly matched.
    public let matchedTemplateID: String?
    /// Why this is a false positive (human-readable).
    public let reason: String
    /// How similar the layout fingerprints are (Jaccard similarity).
    public let fingerprintSimilarity: Double
    /// The expected tier (should have been noMatch or ambiguous).
    public let expectedTier: MatchingTier

    public init(
        id: String = UUID().uuidString,
        entryID: String,
        documentClass: String,
        actualTier: MatchingTier,
        score: Double,
        matchedTemplateID: String?,
        reason: String,
        fingerprintSimilarity: Double,
        expectedTier: MatchingTier
    ) {
        self.id = id
        self.entryID = entryID
        self.documentClass = documentClass
        self.actualTier = actualTier
        self.score = score
        self.matchedTemplateID = matchedTemplateID
        self.reason = reason
        self.fingerprintSimilarity = fingerprintSimilarity
        self.expectedTier = expectedTier
    }
}

// MARK: - False Positive Report

/// Full false-positive report for a calibration run.
public struct FalsePositiveReport: Codable, Sendable {
    /// Total hard negatives in the corpus.
    public let totalHardNegatives: Int
    /// Number that incorrectly matched.
    public let falsePositiveCount: Int
    /// False-positive rate (falsePositives / totalHardNegatives).
    public let falsePositiveRate: Double
    /// Individual false-positive entries.
    public let entries: [FalsePositiveEntry]
    /// Per-document-class false-positive breakdown.
    public let classBreakdown: [String: Int]
    /// Per-tier breakdown of false positives.
    public let tierBreakdown: [MatchingTier: Int]
    /// Recommended threshold adjustments.
    public let recommendations: [String]
    /// Whether the calibration passes the 5% false-positive threshold.
    public let passesThreshold: Bool

    public init(
        totalHardNegatives: Int,
        falsePositiveCount: Int,
        falsePositiveRate: Double,
        entries: [FalsePositiveEntry],
        classBreakdown: [String: Int],
        tierBreakdown: [MatchingTier: Int],
        recommendations: [String],
        passesThreshold: Bool
    ) {
        self.totalHardNegatives = totalHardNegatives
        self.falsePositiveCount = falsePositiveCount
        self.falsePositiveRate = falsePositiveRate
        self.entries = entries
        self.classBreakdown = classBreakdown
        self.tierBreakdown = tierBreakdown
        self.recommendations = recommendations
        self.passesThreshold = passesThreshold
    }
}

// MARK: - False Positive Report Generator

/// Generates false-positive reports from calibration results.
public struct FalsePositiveReportGenerator: Sendable {
    /// Maximum acceptable false-positive rate (default 5%).
    public let maxFalsePositiveRate: Double

    public init(maxFalsePositiveRate: Double = 0.05) {
        self.maxFalsePositiveRate = maxFalsePositiveRate
    }

    /// Generate a false-positive report from calibration results.
    public func generate(
        from report: CalibrationReport,
        corpus: [CorpusEntry]
    ) -> FalsePositiveReport {
        let hardNegatives = corpus.filter { $0.isHardNegative }
        let totalHardNegatives = hardNegatives.count

        // Extract false-positive entries
        var fpEntries: [FalsePositiveEntry] = []
        var classBreakdown: [String: Int] = [:]
        var tierBreakdown: [MatchingTier: Int] = [:]

        for result in report.results where result.falsePositiveDetected {
            let entry = corpus.first { $0.id == result.entryID }
            let docClass = entry?.documentClass ?? "unknown"
            let expectedTier = entry?.expectedTier ?? .noMatch

            // Calculate fingerprint similarity for the entry
            let fingerprintSimilarity: Double
            if let entry = entry {
                // Find a non-hard-negative entry in the same class to compare fingerprints
                let sameClass = corpus.first { $0.documentClass == entry.documentClass && !$0.isHardNegative && $0.id != entry.id }
                if let templateEntry = sameClass {
                    fingerprintSimilarity = jaccardSimilarity(
                        entry.layoutFingerprint,
                        templateEntry.layoutFingerprint
                    )
                } else {
                    fingerprintSimilarity = result.score
                }
            } else {
                fingerprintSimilarity = result.score
            }

            let fpEntry = FalsePositiveEntry(
                entryID: result.entryID,
                documentClass: docClass,
                actualTier: result.actualTier,
                score: result.score,
                matchedTemplateID: nil,
                reason: "Hard negative classified as \(result.actualTier.rawValue) (expected \(expectedTier.rawValue))",
                fingerprintSimilarity: fingerprintSimilarity,
                expectedTier: expectedTier
            )
            fpEntries.append(fpEntry)

            classBreakdown[docClass, default: 0] += 1
            tierBreakdown[result.actualTier, default: 0] += 1
        }

        let fpRate = totalHardNegatives > 0
            ? Double(fpEntries.count) / Double(totalHardNegatives)
            : 0

        // Generate recommendations
        var recommendations: [String] = []

        if fpRate > maxFalsePositiveRate {
            recommendations.append(
                "False-positive rate \(String(format: "%.1f%%", fpRate * 100)) exceeds \(String(format: "%.0f%%", maxFalsePositiveRate * 100)) threshold. Consider raising familyThreshold."
            )
        }

        // Per-class recommendations
        for (docClass, count) in classBreakdown.sorted(by: { $0.value > $1.value }) {
            if count > 0 {
                recommendations.append(
                    "\(count) false positive(s) in class '\(docClass)'. Review this class's fingerprint characteristics."
                )
            }
        }

        // Tier-specific recommendations
        for (tier, count) in tierBreakdown where count > 0 {
            switch tier {
            case .familyMatch:
                recommendations.append(
                    "\(count) hard negative(s) classified as familyMatch. The family threshold (\(String(format: "%.2f", 0.76))) may be too low for these document classes."
                )
            case .knownVariant:
                recommendations.append(
                    "\(count) hard negative(s) classified as knownVariant. Fingerprint collision detected — review fingerprint algorithm for this class."
                )
            default:
                recommendations.append(
                    "\(count) hard negative(s) classified as \(tier.rawValue). Review classification logic."
                )
            }
        }

        if recommendations.isEmpty {
            recommendations.append("No false positives detected. Calibration is within acceptable bounds.")
        }

        return FalsePositiveReport(
            totalHardNegatives: totalHardNegatives,
            falsePositiveCount: fpEntries.count,
            falsePositiveRate: fpRate,
            entries: fpEntries,
            classBreakdown: classBreakdown,
            tierBreakdown: tierBreakdown,
            recommendations: recommendations,
            passesThreshold: fpRate <= maxFalsePositiveRate
        )
    }

    // MARK: - Helpers

    /// Jaccard similarity between two strings (character-level).
    private func jaccardSimilarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return 0 }
        let setA = Set(a)
        let setB = Set(b)
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        return Double(intersection.count) / Double(union.count)
    }
}
