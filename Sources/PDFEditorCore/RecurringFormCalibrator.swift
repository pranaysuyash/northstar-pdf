import Foundation

/// Recurring-form matching calibrator — validates exact, known-variant, family,
/// ambiguous, and stale classification against a reviewed corpus with hard
/// negatives and false-positive reports.
///
/// First principle: matching quality is measured by what it rejects, not just
/// what it accepts. Hard negatives (forms that look similar but aren't matches)
/// are more valuable than easy positives.
///
/// Doctrine alignment:
/// - §5: Evidence-based — every classification has a confidence score and reason
/// - §3: Do things smartly — tiered classification prevents false matches
/// - §11: Engineering integrity — calibration drift is detected and reported

// MARK: - Matching Tier

/// Classification tier for recurring-form matching.
public enum MatchingTier: String, Codable, Sendable, CaseIterable {
    /// Exact source digest match — same document, same revision.
    case exact
    /// Known variant — same layout fingerprint, different source digest.
    case knownVariant
    /// Family match — structural similarity above threshold.
    case familyMatch
    /// Ambiguous — below family threshold but above noise.
    case ambiguous
    /// Stale — expected source digest doesn't match actual.
    case stale
    /// No match — no viable candidate.
    case noMatch

    /// Whether this tier is considered a "match" for auto-selection.
    public var isMatch: Bool {
        switch self {
        case .exact, .knownVariant, .familyMatch: return true
        case .ambiguous, .stale, .noMatch: return false
        }
    }

    /// Human-readable description.
    public var description: String {
        switch self {
        case .exact: return "Exact match (same source digest)"
        case .knownVariant: return "Known variant (same layout, different source)"
        case .familyMatch: return "Family match (structural similarity)"
        case .ambiguous: return "Ambiguous (below family threshold)"
        case .stale: return "Stale (source digest mismatch)"
        case .noMatch: return "No match"
        }
    }
}

// MARK: - Deterministic Dictionary Encoding

/// Coding key that carries an arbitrary string, used so `MatchingTier` can act
/// as a JSON object key.
///
/// Without `CodingKeyRepresentable`, `[MatchingTier: Int]` encodes as an
/// unkeyed array of alternating key/value pairs emitted in Swift's dictionary
/// hash order. Any persisted artifact carrying it is then non-deterministic run
/// to run, and `JSONEncoder.OutputFormatting.sortedKeys` cannot help because
/// there is no keyed container to sort. Conforming turns the same value into a
/// real JSON object (`{"exact": 3, "noMatch": 3}`) whose keys `.sortedKeys`
/// then orders deterministically.
struct MatchingTierCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

extension MatchingTier: CodingKeyRepresentable {
    public var codingKey: CodingKey { MatchingTierCodingKey(stringValue: rawValue) }

    public init?<T: CodingKey>(codingKey: T) {
        self.init(rawValue: codingKey.stringValue)
    }
}

// MARK: - Calibration Thresholds

/// Thresholds for matching tier classification.
public struct MatchingThresholds: Codable, Sendable {
    /// Minimum score for family match (default 0.76).
    public var familyThreshold: Double
    /// Margin below family threshold for ambiguous zone (default 0.05).
    public var ambiguousMargin: Double
    /// Whether family matching is enabled for this document class.
    public var familyEnabled: Bool

    public init(
        familyThreshold: Double = 0.76,
        ambiguousMargin: Double = 0.05,
        familyEnabled: Bool = true
    ) {
        self.familyThreshold = familyThreshold
        self.ambiguousMargin = ambiguousMargin
        self.familyEnabled = familyEnabled
    }

    /// Default thresholds for well-calibrated document classes.
    public static let wellCalibrated = MatchingThresholds(
        familyThreshold: 0.76,
        ambiguousMargin: 0.05,
        familyEnabled: true
    )

    /// Conservative thresholds for poorly-calibrated classes.
    public static let conservative = MatchingThresholds(
        familyThreshold: 0.85,
        ambiguousMargin: 0.03,
        familyEnabled: true
    )

    /// Calibrated for the `LayoutFingerprintV2` structured similarity scale
    /// (F-3 ratified 2026-08-28: 30-fixture corpus, gap 0.813..0.971,
    /// threshold 0.90 — see `LayoutFingerprintThresholdCalibrationTests`).
    /// The legacy 0.76 belongs to the V1 char-set scale and does not apply
    /// to V2's structured components.
    public static let layoutV2Calibrated = MatchingThresholds(
        familyThreshold: LayoutFingerprintV2.familyThreshold,
        ambiguousMargin: 0.05,
        familyEnabled: true
    )

    /// Disabled thresholds (family matching off).
    public static let familyDisabled = MatchingThresholds(
        familyThreshold: 1.0,
        ambiguousMargin: 0,
        familyEnabled: false
    )
}

// MARK: - Corpus Entry

/// A single entry in the calibration corpus.
public struct CorpusEntry: Codable, Sendable, Identifiable {
    public let id: String
    /// Source digest of the document.
    public let sourceDigest: String
    /// Expected matching tier.
    public let expectedTier: MatchingTier
    /// Template ID this document should match (nil if no match expected).
    public let expectedTemplateID: String?
    /// Whether this is a hard negative (looks similar but isn't a match).
    public let isHardNegative: Bool
    /// Document class (e.g., "invoice", "tax-form", "contract").
    public let documentClass: String
    /// Optional notes about why this entry exists.
    public let notes: String?
    /// Optional V2 structured fingerprint (unification with
    /// `LayoutFingerprintV2`). Classification uses the structured similarity
    /// on the calibrated scale (0.90, F-3 ratified).
    public let layoutV2: LayoutFingerprintV2?

    public init(
        id: String = UUID().uuidString,
        sourceDigest: String,
        expectedTier: MatchingTier,
        expectedTemplateID: String? = nil,
        isHardNegative: Bool = false,
        documentClass: String,
        notes: String? = nil,
        layoutV2: LayoutFingerprintV2? = nil
    ) {
        self.id = id
        self.sourceDigest = sourceDigest
        self.expectedTier = expectedTier
        self.expectedTemplateID = expectedTemplateID
        self.isHardNegative = isHardNegative
        self.documentClass = documentClass
        self.notes = notes
        self.layoutV2 = layoutV2
    }
}

// MARK: - Calibration Result

/// Result of classifying a single corpus entry.
public struct CalibrationResult: Codable, Sendable {
    public let entryID: String
    public let expectedTier: MatchingTier
    public let actualTier: MatchingTier
    public let score: Double
    public let passed: Bool
    public let isHardNegative: Bool
    public let falsePositiveDetected: Bool
    public let reason: String

    public init(
        entryID: String,
        expectedTier: MatchingTier,
        actualTier: MatchingTier,
        score: Double,
        passed: Bool,
        isHardNegative: Bool,
        falsePositiveDetected: Bool,
        reason: String
    ) {
        self.entryID = entryID
        self.expectedTier = expectedTier
        self.actualTier = actualTier
        self.score = score
        self.passed = passed
        self.isHardNegative = isHardNegative
        self.falsePositiveDetected = falsePositiveDetected
        self.reason = reason
    }
}

// MARK: - Calibration Report

/// Full calibration report for a corpus.
public struct CalibrationReport: Codable, Sendable {
    /// Total entries tested.
    public let totalEntries: Int
    /// Entries that passed (actual == expected).
    public let passed: Int
    /// Entries that failed.
    public let failed: Int
    /// False positives (hard negatives classified as matches).
    public let falsePositives: Int
    /// False negatives (true matches classified as noMatch).
    public let falseNegatives: Int
    /// Per-tier breakdown.
    public let tierBreakdown: [MatchingTier: Int]
    /// Per-document-class breakdown.
    public let classBreakdown: [String: Int]
    /// Individual results.
    public let results: [CalibrationResult]
    /// Overall accuracy (passed / total).
    public let accuracy: Double
    /// False-positive rate (falsePositives / hardNegatives).
    public let falsePositiveRate: Double
    /// Recommendations for threshold adjustment.
    public let recommendations: [String]

    public init(
        totalEntries: Int,
        passed: Int,
        failed: Int,
        falsePositives: Int,
        falseNegatives: Int,
        tierBreakdown: [MatchingTier: Int],
        classBreakdown: [String: Int],
        results: [CalibrationResult],
        accuracy: Double,
        falsePositiveRate: Double,
        recommendations: [String]
    ) {
        self.totalEntries = totalEntries
        self.passed = passed
        self.failed = failed
        self.falsePositives = falsePositives
        self.falseNegatives = falseNegatives
        self.tierBreakdown = tierBreakdown
        self.classBreakdown = classBreakdown
        self.results = results
        self.accuracy = accuracy
        self.falsePositiveRate = falsePositiveRate
        self.recommendations = recommendations
    }
}

// MARK: - Recurring Form Calibrator

/// Calibrates matching thresholds against a reviewed corpus.
public struct RecurringFormCalibrator: Sendable {
    /// Thresholds to test.
    public let thresholds: MatchingThresholds

    public init(thresholds: MatchingThresholds = .wellCalibrated) {
        self.thresholds = thresholds
    }

    /// Classify a document against a set of templates.
    /// Classify a document against templates using the V2 structured
    /// fingerprint (unification with `LayoutFingerprintV2`).
    ///
    /// - exact: source digest equality
    /// - knownVariant: V2 digest equality (equality key) with a different source
    /// - family: structured `similarity(to:)` total on the calibrated scale
    ///   (defaults `.layoutV2Calibrated` — 0.90, F-3 ratified)
    public func classify(
        sourceDigest: String,
        layoutV2: LayoutFingerprintV2,
        templatesV2: [String: LayoutFingerprintV2],
        exactSourceDigests: [String: String]
    ) -> (tier: MatchingTier, score: Double, templateID: String?) {
        for (templateID, digest) in exactSourceDigests where digest == sourceDigest {
            return (.exact, 1.0, templateID)
        }
        // Known variant: the equality key (V2 digest) matches a different source.
        for (templateID, fingerprint) in templatesV2 where fingerprint.digest == layoutV2.digest {
            return (.knownVariant, 0.9, templateID)
        }
        guard thresholds.familyEnabled else { return (.noMatch, 0, nil) }

        var bestScore = 0.0
        var bestTemplate: String?
        for (templateID, fingerprint) in templatesV2 {
            let similarity = layoutV2.similarity(to: fingerprint).total
            if similarity > bestScore {
                bestScore = similarity
                bestTemplate = templateID
            }
        }
        if bestScore >= thresholds.familyThreshold {
            return (.familyMatch, bestScore, bestTemplate)
        } else if bestScore >= thresholds.familyThreshold - thresholds.ambiguousMargin {
            return (.ambiguous, bestScore, bestTemplate)
        } else {
            return (.noMatch, bestScore, nil)
        }
    }

    /// Run calibration against a corpus using V2 structured fingerprints.
    ///
    /// Every corpus entry must carry a `layoutV2` fingerprint. Entries without
    /// one are skipped (the legacy string lane has been retired).
    public func calibrate(
        corpus: [CorpusEntry],
        templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)]
    ) -> CalibrationReport {
        let exactDigests = Dictionary(
            templatesV2.map { ($0.key, $0.value.sourceDigest) },
            uniquingKeysWith: { first, _ in first }
        )

        var results: [CalibrationResult] = []
        var falsePositives = 0
        var falseNegatives = 0

        for entry in corpus {
            guard let entryV2 = entry.layoutV2 else {
                // Entry without V2 layout — classify as noMatch (cannot
                // compare on the structured scale without a V2 fingerprint).
                let passed = entry.expectedTier == .noMatch
                if !passed && entry.isHardNegative { falsePositives += 1 }
                if entry.expectedTier.isMatch && !passed { falseNegatives += 1 }
                results.append(CalibrationResult(
                    entryID: entry.id,
                    expectedTier: entry.expectedTier,
                    actualTier: .noMatch,
                    score: 0,
                    passed: passed,
                    isHardNegative: entry.isHardNegative,
                    falsePositiveDetected: entry.isHardNegative && !passed,
                    reason: passed
                        ? "Correctly classified as noMatch (no V2 layout)"
                        : "Mismatch: expected \(entry.expectedTier.rawValue), got noMatch (no V2 layout)"
                ))
                continue
            }

            let actual = classify(
                sourceDigest: entry.sourceDigest,
                layoutV2: entryV2,
                templatesV2: templatesV2.mapValues(\.fingerprint),
                exactSourceDigests: exactDigests
            )

            let passed = actual.tier == entry.expectedTier
            let falsePositive = entry.isHardNegative && actual.tier.isMatch
            let falseNegative = entry.expectedTier.isMatch && !actual.tier.isMatch

            if falsePositive { falsePositives += 1 }
            if falseNegative { falseNegatives += 1 }

            let reason: String
            if passed {
                reason = "Correctly classified as \(actual.tier.rawValue)"
            } else if falsePositive {
                reason = "FALSE POSITIVE: Hard negative classified as \(actual.tier.rawValue) (expected \(entry.expectedTier.rawValue))"
            } else if falseNegative {
                reason = "FALSE NEGATIVE: Expected \(entry.expectedTier.rawValue) but got \(actual.tier.rawValue)"
            } else {
                reason = "Mismatch: expected \(entry.expectedTier.rawValue), got \(actual.tier.rawValue)"
            }

            results.append(CalibrationResult(
                entryID: entry.id,
                expectedTier: entry.expectedTier,
                actualTier: actual.tier,
                score: actual.score,
                passed: passed,
                isHardNegative: entry.isHardNegative,
                falsePositiveDetected: falsePositive,
                reason: reason
            ))
        }

        return buildReport(results: results, corpus: corpus, falsePositives: falsePositives, falseNegatives: falseNegatives)
    }

    /// Shared report assembly.
    private func buildReport(
        results: [CalibrationResult],
        corpus: [CorpusEntry],
        falsePositives: Int,
        falseNegatives: Int
    ) -> CalibrationReport {
        let passedCount = results.filter(\.passed).count
        let failedCount = results.count - passedCount
        let accuracy = results.isEmpty ? 0 : Double(passedCount) / Double(results.count)
        let hardNegatives = corpus.filter(\.isHardNegative).count
        let fpr = hardNegatives > 0 ? Double(falsePositives) / Double(hardNegatives) : 0

        // Tier breakdown
        var tierBreakdown: [MatchingTier: Int] = [:]
        for result in results {
            tierBreakdown[result.actualTier, default: 0] += 1
        }

        // Class breakdown
        var classBreakdown: [String: Int] = [:]
        for entry in corpus {
            classBreakdown[entry.documentClass, default: 0] += 1
        }

        // Generate recommendations
        var recommendations: [String] = []
        if fpr > 0.05 {
            recommendations.append("False-positive rate \(String(format: "%.1f%%", fpr * 100)) exceeds 5% threshold. Consider raising familyThreshold from \(thresholds.familyThreshold) to \(String(format: "%.2f", thresholds.familyThreshold + 0.05)).")
        }
        if falseNegatives > 0 {
            recommendations.append("\(falseNegatives) false negative(s) detected. Some true matches are being missed. Consider lowering familyThreshold or enabling additional fingerprint components.")
        }
        if accuracy < 0.95 {
            recommendations.append("Accuracy \(String(format: "%.1f%%", accuracy * 100)) is below 95% target. Review ambiguous cases and adjust thresholds.")
        }
        if recommendations.isEmpty {
            recommendations.append("Calibration within acceptable bounds. No threshold adjustments recommended.")
        }

        return CalibrationReport(
            totalEntries: results.count,
            passed: passedCount,
            failed: failedCount,
            falsePositives: falsePositives,
            falseNegatives: falseNegatives,
            tierBreakdown: tierBreakdown,
            classBreakdown: classBreakdown,
            results: results,
            accuracy: accuracy,
            falsePositiveRate: fpr,
            recommendations: recommendations
        )
    }

}
