import Foundation
import Testing
@testable import PDFEditorCore

/// Tests for the OCR Eval Harness — multi-dimensional scoring with bias mitigation.
@Suite("OCR Eval Harness")
struct OCREvalHarnessTests {

    let harness = OCREvalHarness()

    // MARK: - Rubric Scoring

    @Test("Text accuracy rubric scores WER correctly")
    func textAccuracyRubric() {
        // Perfect match → WER=0, CER=0 → blended=60 (anchors/entities not provided)
        let perfect = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "perfect"
        )
        #expect(perfect.dimensionScores[.textAccuracy]! >= 55)

        // With anchors matching → higher score
        let withAnchors = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "with-anchors",
            anchorLines: ["Hello world"]
        )
        #expect(withAnchors.dimensionScores[.textAccuracy]! >= 70)

        // Total failure → score should be low
        let failed = harness.score(
            ocrText: "xyz garbage",
            groundTruth: "Hello world foo bar baz",
            providerID: "test",
            fixtureID: "failed"
        )
        #expect(failed.dimensionScores[.textAccuracy]! < 40)
    }

    @Test("Structural fidelity detects paragraphs")
    func structuralFidelity() {
        let withParagraphs = harness.score(
            ocrText: "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.",
            groundTruth: "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.",
            providerID: "test",
            fixtureID: "paragraphs"
        )
        // Paragraph detection=100%, list=100% (---), table=0% → blended=70
        #expect(withParagraphs.dimensionScores[.structuralFidelity]! >= 60)

        let noStructure = harness.score(
            ocrText: "One long line without breaks",
            groundTruth: "First paragraph.\n\nSecond paragraph.",
            providerID: "test",
            fixtureID: "no-structure"
        )
        // No paragraph breaks → paragraph detection=0% → lower than structured input
        #expect(noStructure.dimensionScores[.structuralFidelity]! < withParagraphs.dimensionScores[.structuralFidelity]!)
    }

    @Test("Structural fidelity detects lists")
    func listDetection() {
        let withLists = harness.score(
            ocrText: "• Item one\n• Item two\n• Item three",
            groundTruth: "• Item one\n• Item two\n• Item three",
            providerID: "test",
            fixtureID: "lists"
        )
        #expect(withLists.dimensionScores[.structuralFidelity]! >= 60)
    }

    // MARK: - Entity Extraction

    @Test("Entity extraction detects dates and emails")
    func entityExtraction() {
        let result = harness.score(
            ocrText: "Contact user@example.com on 01/15/2026",
            groundTruth: "Contact user@example.com on 01/15/2026",
            providerID: "test",
            fixtureID: "entities",
            entities: ["user@example.com", "01/15/2026"]
        )
        #expect(result.rawMetrics.entityF1 > 0)
        #expect(result.rawMetrics.entityPrecision > 0)
        #expect(result.rawMetrics.entityRecall > 0)
    }

    @Test("Entity extraction handles missing entities")
    func entityMissing() {
        let result = harness.score(
            ocrText: "No entities here",
            groundTruth: "No entities here",
            providerID: "test",
            fixtureID: "no-entities",
            entities: ["user@example.com"]
        )
        #expect(result.rawMetrics.entityRecall == 0)
    }

    // MARK: - Aggregate Score

    @Test("Aggregate score is bounded 0-100")
    func aggregateScore() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "aggregate"
        )
        #expect(result.aggregateScore >= 0)
        #expect(result.aggregateScore <= 100)
    }

    @Test("Perfect match with all signals scores high")
    func perfectMatch() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "perfect-full",
            anchorLines: ["Hello world"],
            entities: []
        )
        // WER=0, anchors=100% → text accuracy high
        #expect(result.dimensionScores[.textAccuracy]! >= 70)
        #expect(result.aggregateScore >= 40)
    }

    @Test("Total failure scores low")
    func totalFailure() {
        let result = harness.score(
            ocrText: "completely wrong output with no matching words",
            groundTruth: "The quick brown fox jumps over the lazy dog",
            providerID: "test",
            fixtureID: "failure"
        )
        #expect(result.aggregateScore < 50)
    }

    // MARK: - Gate Logic

    @Test("Gate passes on good output with anchors and boxes")
    func gatePasses() {
        // Perfect match with all signals: anchors, boxes, entities
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "gate-pass",
            anchorLines: ["Hello world"],
            boundingBoxes: [("Hello", CGRect(x: 0, y: 0, width: 50, height: 10))],
            groundTruthBoxes: [("Hello", CGRect(x: 0, y: 0, width: 50, height: 10))]
        )
        // Text=80, layout=100, structure=70, calibration=50, robustness=50
        // Aggregate should be above 70
        #expect(result.passesGate())
    }

    @Test("Gate fails on bad output")
    func gateFails() {
        let result = harness.score(
            ocrText: "xyz",
            groundTruth: "The quick brown fox jumps over the lazy dog",
            providerID: "test",
            fixtureID: "gate-fail"
        )
        #expect(!result.passesGate())
    }

    @Test("Custom gate threshold")
    func customThreshold() {
        let strict = OCREvalHarness(gateThreshold: 95)
        let result = strict.score(
            ocrText: "Hello world",
            groundTruth: "Hello world!",
            providerID: "test",
            fixtureID: "strict"
        )
        #expect(result.aggregateScore >= 0)
    }

    // MARK: - Bias Mitigation

    @Test("Provider ID is anonymized in scoring")
    func providerAnonymization() {
        let resultA = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "provider-A",
            fixtureID: "bias-test"
        )
        let resultB = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "provider-B",
            fixtureID: "bias-test"
        )
        // Same input → same score regardless of provider name
        #expect(resultA.aggregateScore == resultB.aggregateScore)
        #expect(resultA.dimensionScores == resultB.dimensionScores)
    }

    @Test("Length normalization prevents verbosity bias")
    func verbosityBias() {
        // Short correct answer
        let short = harness.score(
            ocrText: "Hello",
            groundTruth: "Hello",
            providerID: "test",
            fixtureID: "short"
        )
        // Longer correct answer with extra noise
        let verbose = harness.score(
            ocrText: "Hello extra noise words here",
            groundTruth: "Hello",
            providerID: "test",
            fixtureID: "verbose"
        )
        // Short correct should score higher than verbose with noise
        #expect(short.aggregateScore >= verbose.aggregateScore)
    }

    // MARK: - Cross-Provider Report

    @Test("Report groups results by provider")
    func reportGrouping() {
        let results = [
            harness.score(ocrText: "Hello", groundTruth: "Hello", providerID: "A", fixtureID: "f1"),
            harness.score(ocrText: "Hello", groundTruth: "Hello", providerID: "A", fixtureID: "f2"),
            harness.score(ocrText: "Hello", groundTruth: "Hello", providerID: "B", fixtureID: "f1"),
        ]
        let report = harness.generateReport(results: results)
        #expect(report.providerResults["A"]?.count == 2)
        #expect(report.providerResults["B"]?.count == 1)
    }

    @Test("Report identifies best provider")
    func reportBestProvider() {
        let results = [
            harness.score(ocrText: "Perfect match", groundTruth: "Perfect match", providerID: "good", fixtureID: "f1"),
            harness.score(ocrText: "xyz wrong", groundTruth: "Perfect match", providerID: "bad", fixtureID: "f1"),
        ]
        let report = harness.generateReport(results: results)
        #expect(report.comparison.bestProvider == "good")
    }

    @Test("Report computes gate results")
    func reportGates() {
        let results = [
            harness.score(ocrText: "Hello", groundTruth: "Hello", providerID: "pass", fixtureID: "f1",
                         anchorLines: ["Hello"],
                         boundingBoxes: [("Hello", CGRect(x: 0, y: 0, width: 50, height: 10))],
                         groundTruthBoxes: [("Hello", CGRect(x: 0, y: 0, width: 50, height: 10))]),
            harness.score(ocrText: "xyz", groundTruth: "Hello world foo", providerID: "fail", fixtureID: "f1"),
        ]
        let report = harness.generateReport(results: results)
        #expect(report.gates.providerResults["pass"] == true)
        #expect(report.gates.providerResults["fail"] == false)
        #expect(!report.gates.allProvidersPass)
    }

    // MARK: - Edge Cases

    @Test("Empty OCR text scores zero on text accuracy")
    func emptyOCR() {
        let result = harness.score(
            ocrText: "",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "empty"
        )
        #expect(result.dimensionScores[.textAccuracy]! == 0)
    }

    @Test("Empty ground truth handles gracefully")
    func emptyGroundTruth() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "",
            providerID: "test",
            fixtureID: "empty-gt"
        )
        #expect(result.aggregateScore >= 0)
    }

    @Test("No anchors defaults to zero anchor recall")
    func noAnchors() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "no-anchors"
        )
        #expect(result.rawMetrics.anchorRecall == 0)
    }

    @Test("No bounding boxes produces neutral layout score")
    func noBoundingBoxes() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "no-bboxes"
        )
        #expect(result.dimensionScores[.layoutPreservation]! == 0)
    }

    // MARK: - WER/CER Computation

    @Test("WER is zero for identical strings")
    func werIdentical() {
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: "hello world", reference: "hello world")
        #expect(wer == 0)
    }

    @Test("WER is 1.0 for completely different strings")
    func werDifferent() {
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: "foo bar", reference: "hello world")
        #expect(wer >= 0.9)
    }

    @Test("CER measures character-level errors")
    func cerMeasure() {
        let cer = OCRCompanionBenchmark.computeCER(hypothesis: "hello", reference: "helo")
        #expect(cer > 0)
        #expect(cer < 0.5)
    }

    // MARK: - Rubric Band Boundaries

    @Test("Rubric bands have correct boundaries")
    func rubricBands() {
        let rubric = ScoringRubric.textAccuracy
        #expect(rubric.bands.count >= 5)
        #expect(rubric.bands.first?.minScore == 0)
        #expect(rubric.bands.last?.maxScore == 100)
    }

    @Test("Score maps correctly through rubric")
    func rubricMapping() {
        let rubric = ScoringRubric.textAccuracy
        // metric=1.0 → score=100
        #expect(rubric.score(from: 1.0) >= 95)
        // metric=0.0 → score=0
        #expect(rubric.score(from: 0.0) == 0)
        // metric=0.5 → score=50
        #expect(rubric.score(from: 0.5) >= 40)
        #expect(rubric.score(from: 0.5) <= 60)
    }

    // MARK: - Dimension Weights

    @Test("Default weights sum to 1.0")
    func defaultWeights() {
        let totalWeight = EvalDimension.allCases.reduce(0) { $0 + $1.defaultWeight }
        #expect(abs(totalWeight - 1.0) < 0.01)
    }

    @Test("Text accuracy has highest weight")
    func textAccuracyWeight() {
        #expect(EvalDimension.textAccuracy.defaultWeight >= EvalDimension.robustness.defaultWeight)
        #expect(EvalDimension.textAccuracy.defaultWeight >= EvalDimension.confidenceCalibration.defaultWeight)
    }

    // MARK: - Evidence Trail

    @Test("Each dimension produces evidence string")
    func evidenceTrail() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "evidence"
        )
        for dim in EvalDimension.allCases {
            #expect(result.evidence[dim] != nil)
            #expect(!result.evidence[dim]!.isEmpty)
        }
    }

    @Test("Raw metrics are populated")
    func rawMetrics() {
        let result = harness.score(
            ocrText: "Hello world",
            groundTruth: "Hello world",
            providerID: "test",
            fixtureID: "metrics"
        )
        #expect(result.rawMetrics.wordErrorRate == 0)
        #expect(result.rawMetrics.charErrorRate == 0)
        #expect(result.rawMetrics.paragraphDetection >= 0)
        #expect(result.rawMetrics.confidenceMean == 0) // No confidence scores provided
    }
}
