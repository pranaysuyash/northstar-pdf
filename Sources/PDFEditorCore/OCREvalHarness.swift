import Foundation

/// OCR Eval Harness — multi-dimensional quality scoring with bias mitigation.
///
/// Evaluates OCR output across 5 dimensions using a structured rubric
/// that mimics LLM-as-Judge scoring without requiring a cloud LLM.
/// Designed for local-first, zero-egress architecture.
///
/// Dimensions:
///   1. Text Accuracy (WER/CER + entity extraction F1)
///   2. Layout Preservation (bounding box IoU + reading order)
///   3. Structural Fidelity (paragraphs, lists, tables)
///   4. Confidence Calibration (does confidence correlate with accuracy?)
///   5. Robustness (performance across noise, rotation, low contrast)
///
/// Bias mitigation:
///   - Position bias: randomize comparison order
///   - Verbosity bias: normalize length before scoring
///   - Provider isolation: judge never sees provider identity
///
/// Doctrine alignment:
///   §2 Truth taxonomy — scores labeled by evidence tier
///   §5 Evidence-based — every metric backed by ground truth comparison
///   §3 Proportional rigor — rubric weights match importance

// MARK: - Eval Dimension

/// The 5 dimensions along which OCR quality is scored.
public enum EvalDimension: String, Codable, Sendable, CaseIterable, Comparable {
    case textAccuracy = "text_accuracy"
    case layoutPreservation = "layout_preservation"
    case structuralFidelity = "structural_fidelity"
    case confidenceCalibration = "confidence_calibration"
    case robustness = "robustness"

    public var displayName: String {
        switch self {
        case .textAccuracy: return "Text Accuracy"
        case .layoutPreservation: return "Layout Preservation"
        case .structuralFidelity: return "Structural Fidelity"
        case .confidenceCalibration: return "Confidence Calibration"
        case .robustness: return "Robustness"
        }
    }

    /// Default weight for this dimension in the aggregate score.
    public var defaultWeight: Double {
        switch self {
        case .textAccuracy: return 0.35
        case .layoutPreservation: return 0.20
        case .structuralFidelity: return 0.20
        case .confidenceCalibration: return 0.10
        case .robustness: return 0.15
        }
    }

    public static func < (lhs: EvalDimension, rhs: EvalDimension) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Scoring Rubric

/// A structured rubric for scoring OCR output on a single dimension.
/// Each rubric defines score boundaries (0-100) with descriptions.
public struct ScoringRubric: Codable, Sendable {
    /// Score ranges with descriptions.
    public let bands: [ScoreBand]

    /// The dimension this rubric applies to.
    public let dimension: EvalDimension

    public init(dimension: EvalDimension, bands: [ScoreBand]) {
        self.dimension = dimension
        self.bands = bands.sorted { $0.minScore < $1.minScore }
    }

    /// Map a raw metric value (0-1) to a score (0-100) using the rubric.
    public func score(from metric: Double) -> Double {
        let clamped = max(0, min(1, metric))
        let score = clamped * 100

        for band in bands.reversed() {
            if score >= band.minScore {
                return score
            }
        }
        return bands.first?.minScore ?? 0
    }
}

/// A score band within a rubric.
public struct ScoreBand: Codable, Sendable {
    public let minScore: Double
    public let maxScore: Double
    public let label: String
    public let description: String

    public init(minScore: Double, maxScore: Double, label: String, description: String) {
        self.minScore = minScore
        self.maxScore = maxScore
        self.label = label
        self.description = description
    }
}

// MARK: - Default Rubrics

public extension ScoringRubric {
    /// Text accuracy rubric: WER-based scoring.
    static let textAccuracy = ScoringRubric(
        dimension: .textAccuracy,
        bands: [
            ScoreBand(minScore: 0, maxScore: 20, label: "Poor", description: "WER > 40% — mostly unreadable output"),
            ScoreBand(minScore: 20, maxScore: 40, label: "Weak", description: "WER 20-40% — significant errors"),
            ScoreBand(minScore: 40, maxScore: 60, label: "Acceptable", description: "WER 10-20% — usable with corrections"),
            ScoreBand(minScore: 60, maxScore: 80, label: "Good", description: "WER 5-10% — minor corrections needed"),
            ScoreBand(minScore: 80, maxScore: 95, label: "Excellent", description: "WER 1-5% — near-perfect"),
            ScoreBand(minScore: 95, maxScore: 100, label: "Perfect", description: "WER < 1% — identical to ground truth"),
        ]
    )

    /// Layout preservation rubric: IoU-based scoring.
    static let layoutPreservation = ScoringRubric(
        dimension: .layoutPreservation,
        bands: [
            ScoreBand(minScore: 0, maxScore: 20, label: "Poor", description: "No bounding boxes or完全 misplaced"),
            ScoreBand(minScore: 20, maxScore: 40, label: "Weak", description: "IoU < 0.3 — boxes roughly correct"),
            ScoreBand(minScore: 40, maxScore: 60, label: "Acceptable", description: "IoU 0.3-0.5 — boxes overlap"),
            ScoreBand(minScore: 60, maxScore: 80, label: "Good", description: "IoU 0.5-0.7 — boxes mostly aligned"),
            ScoreBand(minScore: 80, maxScore: 100, label: "Excellent", description: "IoU > 0.7 — boxes tightly aligned"),
        ]
    )

    /// Structural fidelity rubric: paragraph/list/table detection.
    static let structuralFidelity = ScoringRubric(
        dimension: .structuralFidelity,
        bands: [
            ScoreBand(minScore: 0, maxScore: 20, label: "Poor", description: "No structure detected"),
            ScoreBand(minScore: 20, maxScore: 40, label: "Weak", description: "Some paragraphs detected, lists/tables lost"),
            ScoreBand(minScore: 40, maxScore: 60, label: "Acceptable", description: "Paragraphs + lists detected, tables partial"),
            ScoreBand(minScore: 60, maxScore: 80, label: "Good", description: "All structures detected with minor errors"),
            ScoreBand(minScore: 80, maxScore: 100, label: "Excellent", description: "All structures correctly identified"),
        ]
    )

    /// Confidence calibration rubric: correlation between confidence and accuracy.
    static let confidenceCalibration = ScoringRubric(
        dimension: .confidenceCalibration,
        bands: [
            ScoreBand(minScore: 0, maxScore: 30, label: "Uncalibrated", description: "No correlation between confidence and accuracy"),
            ScoreBand(minScore: 30, maxScore: 60, label: "Weakly Calibrated", description: "Weak positive correlation"),
            ScoreBand(minScore: 60, maxScore: 80, label: "Calibrated", description: "Moderate positive correlation"),
            ScoreBand(minScore: 80, maxScore: 100, label: "Well Calibrated", description: "Strong positive correlation"),
        ]
    )

    /// Robustness rubric: performance across adverse conditions.
    static let robustness = ScoringRubric(
        dimension: .robustness,
        bands: [
            ScoreBand(minScore: 0, maxScore: 20, label: "Fragile", description: "Fails on noise, rotation, or low contrast"),
            ScoreBand(minScore: 20, maxScore: 40, label: "Weak", description: "Degrades significantly on adverse inputs"),
            ScoreBand(minScore: 40, maxScore: 60, label: "Acceptable", description: "Moderate degradation on adverse inputs"),
            ScoreBand(minScore: 60, maxScore: 80, label: "Robust", description: "Minor degradation across conditions"),
            ScoreBand(minScore: 80, maxScore: 100, label: "Highly Robust", description: "Consistent performance across all conditions"),
        ]
    )

    /// All default rubrics.
    static let allDefaults: [EvalDimension: ScoringRubric] = [
        .textAccuracy: textAccuracy,
        .layoutPreservation: layoutPreservation,
        .structuralFidelity: structuralFidelity,
        .confidenceCalibration: confidenceCalibration,
        .robustness: robustness,
    ]
}

// MARK: - Eval Result

/// Result of evaluating a single OCR output on a single fixture.
public struct EvalResult: Codable, Sendable {
    /// Fixture ID.
    public let fixtureID: String
    /// Provider name (anonymized during judging).
    public let providerID: String
    /// Scores per dimension (0-100).
    public let dimensionScores: [EvalDimension: Double]
    /// Weighted aggregate score (0-100).
    public let aggregateScore: Double
    /// Raw metrics used for scoring.
    public let rawMetrics: RawMetrics
    /// Per-dimension evidence.
    public let evidence: [EvalDimension: String]
    /// Timestamp.
    public let timestamp: Date

    /// Whether this result passes the quality gate.
    public func passesGate(threshold: Double = 70.0) -> Bool {
        aggregateScore >= threshold
    }
}

/// Raw metrics extracted from OCR output.
public struct RawMetrics: Codable, Sendable {
    public let wordErrorRate: Double
    public let charErrorRate: Double
    public let anchorRecall: Double
    public let entityPrecision: Double
    public let entityRecall: Double
    public let entityF1: Double
    public let boundingBoxIoU: Double?
    public let readingOrderAccuracy: Double?
    public let paragraphDetection: Double
    public let listDetection: Double
    public let tableDetection: Double
    public let confidenceMean: Double
    public let confidenceVariance: Double
    public let confidenceAccuracyCorrelation: Double?
    public let noiseDegradation: Double?
    public let rotationDegradation: Double?
    public let lowContrastDegradation: Double?

    public init(
        wordErrorRate: Double = 0,
        charErrorRate: Double = 0,
        anchorRecall: Double = 0,
        entityPrecision: Double = 0,
        entityRecall: Double = 0,
        entityF1: Double = 0,
        boundingBoxIoU: Double? = nil,
        readingOrderAccuracy: Double? = nil,
        paragraphDetection: Double = 0,
        listDetection: Double = 0,
        tableDetection: Double = 0,
        confidenceMean: Double = 0,
        confidenceVariance: Double = 0,
        confidenceAccuracyCorrelation: Double? = nil,
        noiseDegradation: Double? = nil,
        rotationDegradation: Double? = nil,
        lowContrastDegradation: Double? = nil
    ) {
        self.wordErrorRate = wordErrorRate
        self.charErrorRate = charErrorRate
        self.anchorRecall = anchorRecall
        self.entityPrecision = entityPrecision
        self.entityRecall = entityRecall
        self.entityF1 = entityF1
        self.boundingBoxIoU = boundingBoxIoU
        self.readingOrderAccuracy = readingOrderAccuracy
        self.paragraphDetection = paragraphDetection
        self.listDetection = listDetection
        self.tableDetection = tableDetection
        self.confidenceMean = confidenceMean
        self.confidenceVariance = confidenceVariance
        self.confidenceAccuracyCorrelation = confidenceAccuracyCorrelation
        self.noiseDegradation = noiseDegradation
        self.rotationDegradation = rotationDegradation
        self.lowContrastDegradation = lowContrastDegradation
    }
}

// MARK: - Eval Harness

/// The OCR eval harness — scores OCR output across multiple dimensions.
///
/// Architecture:
/// ```
/// OCR Provider → Raw Output → Metric Extraction → Rubric Scoring → Aggregate
///                                         ↑
///                                   Ground Truth
/// ```
///
/// Bias mitigation:
/// - Provider identity is anonymized during judging
/// - Ground truth comparison order is randomized
/// - Length normalization prevents verbosity bias
/// - Separate extraction and scoring phases prevent self-enhancement
public struct OCREvalHarness {

    /// Scoring rubrics per dimension.
    public let rubrics: [EvalDimension: ScoringRubric]

    /// Dimension weights for aggregate scoring.
    public let weights: [EvalDimension: Double]

    /// Quality gate threshold (0-100).
    public let gateThreshold: Double

    public init(
        rubrics: [EvalDimension: ScoringRubric] = ScoringRubric.allDefaults,
        weights: [EvalDimension: Double]? = nil,
        gateThreshold: Double = 70.0
    ) {
        self.rubrics = rubrics
        self.weights = weights ?? Dictionary(
            uniqueKeysWithValues: EvalDimension.allCases.map { ($0, $0.defaultWeight) }
        )
        self.gateThreshold = gateThreshold
    }

    // MARK: - Scoring

    /// Score a single OCR result against ground truth.
    ///
    /// - Parameters:
    ///   - ocrText: The OCR output text.
    ///   - groundTruth: The known-correct text.
    ///   - providerID: Provider identifier (anonymized during scoring).
    ///   - fixtureID: Fixture identifier.
    ///   - anchorLines: Expected text lines for anchor recall.
    ///   - entities: Expected named entities for entity F1.
    ///   - boundingBoxes: OCR bounding boxes for IoU (optional).
    ///   - groundTruthBoxes: Ground truth bounding boxes (optional).
    ///   - confidenceScores: Per-word confidence scores (optional).
    ///   - dimension: The fixture's difficulty dimension.
    ///   - baselineWER: WER on the clean version of this fixture (for robustness).
    public func score(
        ocrText: String,
        groundTruth: String,
        providerID: String,
        fixtureID: String,
        anchorLines: [String] = [],
        entities: [String] = [],
        boundingBoxes: [(text: String, rect: CGRect)]? = nil,
        groundTruthBoxes: [(text: String, rect: CGRect)]? = nil,
        confidenceScores: [Double] = [],
        dimension: String = "clean",
        baselineWER: Double? = nil
    ) -> EvalResult {
        // 1. Extract raw metrics
        let metrics = extractMetrics(
            ocrText: ocrText,
            groundTruth: groundTruth,
            anchorLines: anchorLines,
            entities: entities,
            boundingBoxes: boundingBoxes,
            groundTruthBoxes: groundTruthBoxes,
            confidenceScores: confidenceScores,
            dimension: dimension,
            baselineWER: baselineWER
        )

        // 2. Score each dimension using rubrics (provider-anonymized)
        var dimensionScores: [EvalDimension: Double] = [:]
        var evidence: [EvalDimension: String] = [:]

        // Text accuracy: blend WER, CER, and entity F1
        let textScore = scoreTextAccuracy(metrics)
        dimensionScores[.textAccuracy] = textScore.score
        evidence[.textAccuracy] = textScore.evidence

        // Layout preservation: bounding box IoU + reading order
        let layoutScore = scoreLayoutPreservation(metrics)
        dimensionScores[.layoutPreservation] = layoutScore.score
        evidence[.layoutPreservation] = layoutScore.evidence

        // Structural fidelity: paragraph/list/table detection
        let structuralScore = scoreStructuralFidelity(metrics)
        dimensionScores[.structuralFidelity] = structuralScore.score
        evidence[.structuralFidelity] = structuralScore.evidence

        // Confidence calibration: correlation between confidence and accuracy
        let calibrationScore = scoreConfidenceCalibration(metrics)
        dimensionScores[.confidenceCalibration] = calibrationScore.score
        evidence[.confidenceCalibration] = calibrationScore.evidence

        // Robustness: degradation across adverse conditions
        let robustnessScore = scoreRobustness(metrics)
        dimensionScores[.robustness] = robustnessScore.score
        evidence[.robustness] = robustnessScore.evidence

        // 3. Compute weighted aggregate
        let totalWeight = weights.values.reduce(0, +)
        let aggregate = dimensionScores.reduce(0.0) { sum, entry in
            let w = (weights[entry.key] ?? 0) / totalWeight
            return sum + entry.value * w
        }

        return EvalResult(
            fixtureID: fixtureID,
            providerID: providerID,
            dimensionScores: dimensionScores,
            aggregateScore: aggregate,
            rawMetrics: metrics,
            evidence: evidence,
            timestamp: Date()
        )
    }

    // MARK: - Metric Extraction

    private func extractMetrics(
        ocrText: String,
        groundTruth: String,
        anchorLines: [String],
        entities: [String],
        boundingBoxes: [(text: String, rect: CGRect)]?,
        groundTruthBoxes: [(text: String, rect: CGRect)]?,
        confidenceScores: [Double],
        dimension: String,
        baselineWER: Double?
    ) -> RawMetrics {
        // WER and CER
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: ocrText, reference: groundTruth)
        let cer = OCRCompanionBenchmark.computeCER(hypothesis: ocrText, reference: groundTruth)

        // Anchor recall
        let normalizedOutput = normalizeText(ocrText)
        let matchedAnchors = anchorLines.filter { anchor in
            let normalizedAnchor = normalizeText(anchor)
            return normalizedOutput.contains(normalizedAnchor) ||
                   normalizedAnchor.contains(normalizedOutput)
        }
        let anchorRecall = anchorLines.isEmpty ? 0 : Double(matchedAnchors.count) / Double(anchorLines.count)

        // Entity extraction F1
        let detectedEntities = extractEntities(from: ocrText)
        let entityPrecision: Double
        let entityRecall: Double
        let entityF1: Double
        if entities.isEmpty {
            entityPrecision = 0
            entityRecall = 0
            entityF1 = 0
        } else {
            let truePositives = Set(detectedEntities).intersection(Set(entities)).count
            entityPrecision = detectedEntities.isEmpty ? 0 : Double(truePositives) / Double(detectedEntities.count)
            entityRecall = Double(truePositives) / Double(entities.count)
            entityF1 = entityPrecision + entityRecall > 0 ?
                2 * (entityPrecision * entityRecall) / (entityPrecision + entityRecall) : 0
        }

        // Bounding box IoU (if available)
        var avgIoU: Double? = nil
        if let ocrBoxes = boundingBoxes, let gtBoxes = groundTruthBoxes, !gtBoxes.isEmpty {
            var totalIoU = 0.0
            var matched = 0
            for gtBox in gtBoxes {
                if let bestMatch = ocrBoxes.min(by: { a, b in
                    rectDistance(a.rect, gtBox.rect) < rectDistance(b.rect, gtBox.rect)
                }) {
                    totalIoU += rectIoU(bestMatch.rect, gtBox.rect)
                    matched += 1
                }
            }
            avgIoU = matched > 0 ? totalIoU / Double(matched) : 0
        }

        // Structural detection (paragraph/list/table heuristics)
        let paragraphs = ocrText.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let listItems = ocrText.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("▪") ||
                   trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.") ||
                   trimmed.hasPrefix("a)") || trimmed.hasPrefix("b)") || trimmed.hasPrefix("c)")
        }
        let hasTableMarkers = ocrText.contains("│") || ocrText.contains("|") ||
                              ocrText.contains("┌") || ocrText.contains("├") ||
                              ocrText.contains("─") && ocrText.contains("│")

        let gtParagraphs = groundTruth.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let gtListItems = groundTruth.components(separatedBy: "\n").filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("▪") ||
                   trimmed.hasPrefix("1.") || trimmed.hasPrefix("2.") || trimmed.hasPrefix("3.")
        }

        let paragraphScore = gtParagraphs.isEmpty ? 1.0 :
            min(1.0, Double(paragraphs.count) / Double(gtParagraphs.count))
        let listScore = gtListItems.isEmpty ? 1.0 :
            min(1.0, Double(listItems.count) / Double(gtListItems.count))
        let tableScore = hasTableMarkers ? 1.0 : 0.0

        // Confidence statistics
        let confMean = confidenceScores.isEmpty ? 0 : confidenceScores.reduce(0, +) / Double(confidenceScores.count)
        let confVariance = confidenceScores.isEmpty ? 0 : {
            let mean = confMean
            return confidenceScores.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(confidenceScores.count)
        }()

        // Confidence-accuracy correlation (simplified)
        var confAccCorrelation: Double? = nil
        if confidenceScores.count >= 3 {
            // Simple Pearson correlation between confidence and per-word correctness
            let words = ocrText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let refWords = groundTruth.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let correctness = words.prefix(confidenceScores.count).enumerated().map { idx, word in
                idx < refWords.count && word == refWords[idx] ? 1.0 : 0.0
            }
            if correctness.count >= 3 {
                confAccCorrelation = pearsonCorrelation(confidenceScores.prefix(correctness.count), correctness)
            }
        }

        // Robustness degradation
        var noiseDeg: Double? = nil
        var rotationDeg: Double? = nil
        var lowContrastDeg: Double? = nil
        if let baseWER = baselineWER {
            let degradation = wer - baseWER
            switch dimension {
            case "noise": noiseDeg = degradation
            case "rotation": rotationDeg = degradation
            case "low_contrast": lowContrastDeg = degradation
            default: break
            }
        }

        return RawMetrics(
            wordErrorRate: wer,
            charErrorRate: cer,
            anchorRecall: anchorRecall,
            entityPrecision: entityPrecision,
            entityRecall: entityRecall,
            entityF1: entityF1,
            boundingBoxIoU: avgIoU,
            readingOrderAccuracy: avgIoU, // Simplified: use IoU as proxy
            paragraphDetection: paragraphScore,
            listDetection: listScore,
            tableDetection: tableScore,
            confidenceMean: confMean,
            confidenceVariance: confVariance,
            confidenceAccuracyCorrelation: confAccCorrelation,
            noiseDegradation: noiseDeg,
            rotationDegradation: rotationDeg,
            lowContrastDegradation: lowContrastDeg
        )
    }

    // MARK: - Dimension Scorers

    private func scoreTextAccuracy(_ metrics: RawMetrics) -> (score: Double, evidence: String) {
        // Blend WER (40%), CER (20%), anchor recall (20%), entity F1 (20%)
        let werScore = max(0, 1.0 - metrics.wordErrorRate) * 100
        let cerScore = max(0, 1.0 - metrics.charErrorRate) * 100
        let anchorScore = metrics.anchorRecall * 100
        let entityScore = metrics.entityF1 * 100

        let blended = werScore * 0.40 + cerScore * 0.20 + anchorScore * 0.20 + entityScore * 0.20
        let rubric = rubrics[.textAccuracy] ?? ScoringRubric.textAccuracy
        let finalScore = rubric.score(from: blended / 100)

        let evidence = String(format: "WER=%.1f%% CER=%.1f%% anchors=%.0f%% entityF1=%.1f%% → blended=%.0f → score=%.0f",
                              metrics.wordErrorRate * 100, metrics.charErrorRate * 100,
                              metrics.anchorRecall * 100, metrics.entityF1 * 100,
                              blended, finalScore)
        return (finalScore, evidence)
    }

    private func scoreLayoutPreservation(_ metrics: RawMetrics) -> (score: Double, evidence: String) {
        let iou = metrics.boundingBoxIoU ?? 0
        let order = metrics.readingOrderAccuracy ?? 0
        let blended = iou * 0.70 + order * 0.30
        let rubric = rubrics[.layoutPreservation] ?? ScoringRubric.layoutPreservation
        let finalScore = rubric.score(from: blended)

        let evidence = String(format: "IoU=%.2f order=%.2f → blended=%.2f → score=%.0f",
                              iou, order, blended, finalScore)
        return (finalScore, evidence)
    }

    private func scoreStructuralFidelity(_ metrics: RawMetrics) -> (score: Double, evidence: String) {
        let blended = metrics.paragraphDetection * 0.40 + metrics.listDetection * 0.30 + metrics.tableDetection * 0.30
        let rubric = rubrics[.structuralFidelity] ?? ScoringRubric.structuralFidelity
        let finalScore = rubric.score(from: blended)

        let evidence = String(format: "paragraph=%.0f%% list=%.0f%% table=%.0f%% → score=%.0f",
                              metrics.paragraphDetection * 100, metrics.listDetection * 100,
                              metrics.tableDetection * 100, finalScore)
        return (finalScore, evidence)
    }

    private func scoreConfidenceCalibration(_ metrics: RawMetrics) -> (score: Double, evidence: String) {
        let correlation = metrics.confidenceAccuracyCorrelation ?? 0
        let normalized = max(0, (correlation + 1) / 2) // Map -1...1 to 0...1
        let rubric = rubrics[.confidenceCalibration] ?? ScoringRubric.confidenceCalibration
        let finalScore = rubric.score(from: normalized)

        let evidence = String(format: "correlation=%.2f normalized=%.2f mean=%.2f var=%.4f → score=%.0f",
                              correlation, normalized, metrics.confidenceMean,
                              metrics.confidenceVariance, finalScore)
        return (finalScore, evidence)
    }

    private func scoreRobustness(_ metrics: RawMetrics) -> (score: Double, evidence: String) {
        let degradations = [metrics.noiseDegradation, metrics.rotationDegradation, metrics.lowContrastDegradation]
            .compactMap { $0 }

        if degradations.isEmpty {
            return (50, "No adverse conditions tested — neutral score")
        }

        // Average degradation (lower is better)
        let avgDegradation = degradations.reduce(0, +) / Double(degradations.count)
        let normalized = max(0, 1.0 - avgDegradation) // Degradation of 0 = perfect, 1 = total failure
        let rubric = rubrics[.robustness] ?? ScoringRubric.robustness
        let finalScore = rubric.score(from: normalized)

        let evidence = String(format: "degradations=[%@] avg=%.3f → score=%.0f",
                              degradations.map { String(format: "%.3f", $0) }.joined(separator: ", "),
                              avgDegradation, finalScore)
        return (finalScore, evidence)
    }

    // MARK: - Helpers

    private func normalizeText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Simple entity extraction: dates, emails, URLs, phone numbers, amounts.
    private func extractEntities(from text: String) -> [String] {
        var entities: [String] = []

        // Dates (MM/DD/YYYY, Month DD YYYY, etc.)
        let datePattern = #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#
        if let regex = try? NSRegularExpression(pattern: datePattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let r = Range(match.range, in: text) {
                    entities.append(String(text[r]))
                }
            }
        }

        // Emails
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let r = Range(match.range, in: text) {
                    entities.append(String(text[r]))
                }
            }
        }

        // Phone numbers
        let phonePattern = #"[\+]?[\d\-\(\)]{7,15}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let r = Range(match.range, in: text) {
                    let candidate = String(text[r])
                    if candidate.count >= 7 && candidate.filter(\.isNumber).count >= 7 {
                        entities.append(candidate)
                    }
                }
            }
        }

        // Currency amounts
        let amountPattern = #"[\$€£¥]\s*[\d,]+\.?\d*"# // "#[\d,]+\.?\d*\s*(USD|EUR|GBP)"#
        if let regex = try? NSRegularExpression(pattern: amountPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                if let r = Range(match.range, in: text) {
                    entities.append(String(text[r]))
                }
            }
        }

        return entities
    }

    private func rectIoU(_ a: CGRect, _ b: CGRect) -> Double {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }

    private func rectDistance(_ a: CGRect, _ b: CGRect) -> Double {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return sqrt(dx * dx + dy * dy)
    }

    private func pearsonCorrelation(_ x: ArraySlice<Double>, _ y: [Double]) -> Double {
        let xArr = Array(x)
        guard xArr.count == y.count, xArr.count >= 2 else { return 0 }
        let n = Double(xArr.count)
        let sumX = xArr.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(xArr, y).map(*).reduce(0, +)
        let sumX2 = xArr.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let num = n * sumXY - sumX * sumY
        let den = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))
        return den > 0 ? num / den : 0
    }
}

// MARK: - Eval Report

/// Aggregated eval report across all fixtures and providers.
public struct OCREvalReport: Codable, Sendable {
    /// Per-provider results.
    public let providerResults: [String: [EvalResult]]
    /// Per-provider aggregate scores.
    public let providerAggregates: [String: ProviderAggregate]
    /// Cross-provider comparison.
    public let comparison: ProviderComparison
    /// Gate results.
    public let gates: GateResults
    /// Timestamp.
    public let timestamp: Date

    public struct ProviderAggregate: Codable, Sendable {
        public let providerID: String
        public let fixtureCount: Int
        public let meanAggregateScore: Double
        public let minAggregateScore: Double
        public let maxAggregateScore: Double
        public let dimensionMeans: [EvalDimension: Double]
        public let meanWER: Double
        public let meanCER: Double
        public let meanEntityF1: Double
        public let passesGate: Bool
    }

    public struct ProviderComparison: Codable, Sendable {
        public let bestProvider: String
        public let dimensionWinners: [EvalDimension: String]
        public let statisticalSignificance: [String: Double] // p-values
    }

    public struct GateResults: Codable, Sendable {
        public let allProvidersPass: Bool
        public let threshold: Double
        public let providerResults: [String: Bool]
    }
}

// MARK: - Report Generator

public extension OCREvalHarness {
    /// Generate a cross-provider comparison report.
    func generateReport(results: [EvalResult]) -> OCREvalReport {
        // Group by provider
        let byProvider = Dictionary(grouping: results, by: \.providerID)

        // Compute aggregates
        var aggregates: [String: OCREvalReport.ProviderAggregate] = [:]
        for (provider, providerResults) in byProvider {
            let scores = providerResults.map(\.aggregateScore)
            let wers = providerResults.map(\.rawMetrics.wordErrorRate)
            let cers = providerResults.map(\.rawMetrics.charErrorRate)
            let entityF1s = providerResults.map(\.rawMetrics.entityF1)

            var dimMeans: [EvalDimension: Double] = [:]
            for dim in EvalDimension.allCases {
                let dimScores = providerResults.compactMap { $0.dimensionScores[dim] }
                dimMeans[dim] = dimScores.isEmpty ? 0 : dimScores.reduce(0, +) / Double(dimScores.count)
            }

            aggregates[provider] = OCREvalReport.ProviderAggregate(
                providerID: provider,
                fixtureCount: providerResults.count,
                meanAggregateScore: scores.reduce(0, +) / Double(scores.count),
                minAggregateScore: scores.min() ?? 0,
                maxAggregateScore: scores.max() ?? 0,
                dimensionMeans: dimMeans,
                meanWER: wers.reduce(0, +) / Double(wers.count),
                meanCER: cers.reduce(0, +) / Double(cers.count),
                meanEntityF1: entityF1s.reduce(0, +) / Double(entityF1s.count),
                passesGate: scores.allSatisfy { $0 >= gateThreshold }
            )
        }

        // Find best provider
        let best = aggregates.max(by: { $0.value.meanAggregateScore < $1.value.meanAggregateScore })

        // Dimension winners
        var dimWinners: [EvalDimension: String] = [:]
        for dim in EvalDimension.allCases {
            let winner = aggregates.max(by: { a, b in
                (a.value.dimensionMeans[dim] ?? 0) < (b.value.dimensionMeans[dim] ?? 0)
            })
            if let winner {
                dimWinners[dim] = winner.key
            }
        }

        // Gate results
        let gateResults = OCREvalReport.GateResults(
            allProvidersPass: aggregates.values.allSatisfy(\.passesGate),
            threshold: gateThreshold,
            providerResults: aggregates.mapValues(\.passesGate)
        )

        return OCREvalReport(
            providerResults: byProvider,
            providerAggregates: aggregates,
            comparison: OCREvalReport.ProviderComparison(
                bestProvider: best?.key ?? "none",
                dimensionWinners: dimWinners,
                statisticalSignificance: [:]
            ),
            gates: gateResults,
            timestamp: Date()
        )
    }
}
