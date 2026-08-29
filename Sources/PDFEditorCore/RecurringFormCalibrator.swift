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
    /// Layout fingerprint.
    public let layoutFingerprint: String
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
    /// `LayoutFingerprintV2`). When present, classification uses the
    /// structured similarity on the calibrated scale; when absent, the
    /// legacy string fingerprint lane applies (backward compatible).
    public let layoutV2: LayoutFingerprintV2?

    public init(
        id: String = UUID().uuidString,
        sourceDigest: String,
        layoutFingerprint: String,
        expectedTier: MatchingTier,
        expectedTemplateID: String? = nil,
        isHardNegative: Bool = false,
        documentClass: String,
        notes: String? = nil,
        layoutV2: LayoutFingerprintV2? = nil
    ) {
        self.id = id
        self.sourceDigest = sourceDigest
        self.layoutFingerprint = layoutFingerprint
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
    public func classify(
        sourceDigest: String,
        layoutFingerprint: String,
        templates: [String: String], // templateID -> layoutFingerprint
        exactSourceDigests: [String: String] // templateID -> sourceDigest
    ) -> (tier: MatchingTier, score: Double, templateID: String?) {
        // Check exact match
        for (templateID, digest) in exactSourceDigests {
            if digest == sourceDigest {
                return (.exact, 1.0, templateID)
            }
        }

        // Check known variant (same layout fingerprint)
        for (templateID, fingerprint) in templates {
            if fingerprint == layoutFingerprint {
                return (.knownVariant, 0.9, templateID)
            }
        }

        // Check family match (structural similarity)
        guard thresholds.familyEnabled else {
            return (.noMatch, 0, nil)
        }

        // Simple structural similarity: count common layout features
        var bestScore: Double = 0
        var bestTemplate: String?
        for (templateID, fingerprint) in templates {
            let similarity = layoutSimilarity(layoutFingerprint, fingerprint)
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
    /// Entries carrying `layoutV2` are classified on the V2 scale (structured
    /// similarity); entries without it fall back to the legacy string lane
    /// (their `layoutFingerprint` vs the template digests), preserving the
    /// hard-negative machinery for synthetic entries.
    public func calibrate(
        corpus: [CorpusEntry],
        templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)]
    ) -> CalibrationReport {
        // Legacy fallback fingerprints derived from the V2 digests (equality
        // keys) for entries without a V2 layout (e.g., synthetic hard
        // negatives): the string lane stays consistent with the V2 lane on
        // exact/knownVariant while family falls back to its legacy semantics.
        let legacyFingerprints = templatesV2.mapValues { $0.fingerprint.digest }
        let exactDigests = Dictionary(
            templatesV2.map { ($0.key, $0.value.sourceDigest) },
            uniquingKeysWith: { first, _ in first }
        )

        var results: [CalibrationResult] = []
        var falsePositives = 0
        var falseNegatives = 0

        for entry in corpus {
            let actual: (tier: MatchingTier, score: Double, templateID: String?)
            if let entryV2 = entry.layoutV2 {
                actual = classify(
                    sourceDigest: entry.sourceDigest,
                    layoutV2: entryV2,
                    templatesV2: templatesV2.mapValues(\.fingerprint),
                    exactSourceDigests: exactDigests
                )
            } else {
                actual = classify(
                    sourceDigest: entry.sourceDigest,
                    layoutFingerprint: entry.layoutFingerprint,
                    templates: legacyFingerprints,
                    exactSourceDigests: exactDigests
                )
            }

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

    /// Run calibration against a corpus.
    public func calibrate(
        corpus: [CorpusEntry],
        templates: [String: (fingerprint: String, sourceDigest: String)] // templateID -> (fingerprint, sourceDigest)
    ) -> CalibrationReport {
        var results: [CalibrationResult] = []
        var falsePositives = 0
        var falseNegatives = 0

        for entry in corpus {
            let exactDigests = Dictionary(
                templates.map { ($0.key, $0.value.sourceDigest) },
                uniquingKeysWith: { first, _ in first }
            )
            let fingerprints = Dictionary(
                templates.map { ($0.key, $0.value.fingerprint) },
                uniquingKeysWith: { first, _ in first }
            )

            let (actualTier, score, matchedTemplate) = classify(
                sourceDigest: entry.sourceDigest,
                layoutFingerprint: entry.layoutFingerprint,
                templates: fingerprints,
                exactSourceDigests: exactDigests
            )

            let passed = actualTier == entry.expectedTier
            let falsePositive = entry.isHardNegative && actualTier.isMatch
            let falseNegative = entry.expectedTier.isMatch && !actualTier.isMatch

            if falsePositive { falsePositives += 1 }
            if falseNegative { falseNegatives += 1 }

            let reason: String
            if passed {
                reason = "Correctly classified as \(actualTier.rawValue)"
            } else if falsePositive {
                reason = "FALSE POSITIVE: Hard negative classified as \(actualTier.rawValue) (expected \(entry.expectedTier.rawValue))"
            } else if falseNegative {
                reason = "FALSE NEGATIVE: Expected \(entry.expectedTier.rawValue) but got \(actualTier.rawValue)"
            } else {
                reason = "Mismatch: expected \(entry.expectedTier.rawValue), got \(actualTier.rawValue)"
            }

            results.append(CalibrationResult(
                entryID: entry.id,
                expectedTier: entry.expectedTier,
                actualTier: actualTier,
                score: score,
                passed: passed,
                isHardNegative: entry.isHardNegative,
                falsePositiveDetected: falsePositive,
                reason: reason
            ))
        }

        return buildReport(results: results, corpus: corpus, falsePositives: falsePositives, falseNegatives: falseNegatives)
    }

    /// Shared report assembly for both calibration lanes (string + V2).
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

    // MARK: - Helpers

    /// Simple layout similarity between two fingerprint strings.
    /// Compares character-level overlap as a proxy for structural similarity.
    private func layoutSimilarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty && !b.isEmpty else { return 0 }
        let setA = Set(a)
        let setB = Set(b)
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        return Double(intersection.count) / Double(union.count) // Jaccard similarity
    }
}
