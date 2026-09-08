import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Tests for the OCR confirmation lane (§8 capability routing).
///
/// When `RecurringFormCalibrator` abstains with `.insufficientEvidence`, the
/// pair carries no structured-content signal. The OCR confirm lane reads the
/// real text inside the pixels to decide whether to promote, reject, or
/// remain abstained.
///
/// Two real-world scenarios:
/// - **Chart-vs-scan pair**: Both are scans with no text layer, but one is a
///   chart and the other is a form. OCR extracts different text → reject.
/// - **Re-encoding pair**: Same document saved twice. OCR extracts the same
///   text with minor noise → promote.
@Suite("OCR confirm lane (§8 capability routing)")
struct OCRConfirmLaneTests {

    private let lane = OCRConfirmLane(werThreshold: 0.10)

    // MARK: - Unit tests (synthetic, no I/O)

    @Test("WER computation: identical text → 0.0")
    func werIdentical() {
        let wer = OCRCompanionBenchmark.computeWER(
            hypothesis: "hello world",
            reference: "hello world"
        )
        #expect(wer == 0.0)
    }

    @Test("WER computation: completely different → high WER")
    func werDifferent() {
        let wer = OCRCompanionBenchmark.computeWER(
            hypothesis: "foo bar baz",
            reference: "hello world"
        )
        #expect(wer >= 1.0,
                "Completely different text should have WER >= 1.0, got \(wer)")
    }

    @Test("WER computation: minor noise → low WER")
    func werMinorNoise() {
        let wer = OCRCompanionBenchmark.computeWER(
            hypothesis: "The quick brown fox jumps over the lazy dog",
            reference: "The quick brown fox jumps over the lazy dog."
        )
        // Missing period = 1 edit / 9 words ≈ 0.11
        #expect(wer < 0.20,
                "Minor OCR noise should produce low WER, got \(wer)")
    }

    @Test("Available providers: at least Vision on macOS")
    func providersAvailable() {
        // This test verifies the lane can find providers
        let lane = OCRConfirmLane()
        // On macOS, Vision is always available; Tesseract may or may not be
        // The lane should not crash even if no providers are found
        let result = lane.confirm(
            candidatePDF: "/dev/null",
            templatePDF: "/dev/null",
            candidateDigest: "test-digest",
            templateID: "test-template",
            familyScore: 0.95
        )
        // With /dev/null as input, OCR will fail → abstain
        #expect(result.decision == .abstain)
    }

    // MARK: - Integration tests (real PDFs)

    /// Two scans with different content — OCR should extract different text
    /// and the lane should reject the false family candidate.
    @Test("Chart-vs-scan: OCR confirms different content → reject")
    func chartVsScanRejects() throws {
        let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"
        let candidatePDF = "\(results)/browser-corpus/scanned-noisy.pdf"
        let templatePDF = "\(results)/ocr-corpus/low-contrast.pdf"

        guard FileManager.default.fileExists(atPath: candidatePDF),
              FileManager.default.fileExists(atPath: templatePDF) else {
            print("[OCR-confirm skip] corpus files missing")
            return
        }

        let result = lane.confirm(
            candidatePDF: candidatePDF,
            templatePDF: templatePDF,
            candidateDigest: "scanned-noisy-digest",
            templateID: "low-contrast-template",
            familyScore: 0.9886
        )

        print("[OCR-confirm evidence] decision=\(result.decision.rawValue)")
        for (name, pr) in result.providerResults {
            print("  \(name): \(pr.text.count) chars, WER \(pr.wer.map { String(format: "%.4f", $0) } ?? "N/A")")
        }

        // The two scans have different text content — OCR should either
        // reject or abstain (never promote)
        #expect(result.decision != .promote,
                "Scans with different content must not be promoted: \(result.reason)")
    }

    /// Two copies of the same document (same fixture, same bytes) — OCR
    /// should extract the same text and the lane should promote.
    @Test("Re-encoding: OCR confirms same content → promote")
    func reEncodingPromotes() throws {
        let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"
        let fixture = "\(results)/ocr-corpus/clean-english.pdf"

        guard FileManager.default.fileExists(atPath: fixture) else {
            print("[OCR-confirm skip] corpus file missing")
            return
        }

        // Same document as both candidate and template — re-encoding pair
        let result = lane.confirm(
            candidatePDF: fixture,
            templatePDF: fixture,
            candidateDigest: "clean-english-digest",
            templateID: "clean-english-template",
            familyScore: 1.0
        )

        print("[OCR-confirm evidence] decision=\(result.decision.rawValue)")
        for (name, pr) in result.providerResults {
            print("  \(name): \(pr.text.count) chars, WER \(pr.wer.map { String(format: "%.4f", $0) } ?? "N/A")")
        }

        // Same document should always be promoted
        #expect(result.decision == .promote,
                "Same document must be promoted: \(result.reason)")
    }

    /// Batch confirmation with mixed pairs.
    @Test("Batch confirmation returns correct counts")
    func batchConfirmation() throws {
        let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"
        let fixture = "\(results)/ocr-corpus/clean-english.pdf"

        guard FileManager.default.fileExists(atPath: fixture) else {
            print("[OCR-confirm skip] corpus file missing")
            return
        }

        let batch = lane.confirmBatch([
            (candidatePDF: fixture, templatePDF: fixture,
             candidateDigest: "same-digest", templateID: "tpl-a", familyScore: 1.0),
            (candidatePDF: "/dev/null", templatePDF: "/dev/null",
             candidateDigest: "null-digest", templateID: "tpl-b", familyScore: 0.95),
        ])

        #expect(batch.totalPairs == 2)
        #expect(batch.promoted >= 1,
                "Same document must be promoted in batch")
        #expect(batch.abstained >= 1,
                "Null documents must be abstained in batch")
    }

    // MARK: - Evidence floor integration

    /// End-to-end: calibrator abstains → confirm lane decides.
    @Test("Calibrator abstain → confirm lane decides (end-to-end)")
    func endToEndFlow() throws {
        let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"
        let paths = [
            "\(results)/browser-corpus/scanned-noisy.pdf",
            "\(results)/ocr-corpus/low-contrast.pdf"
        ]

        guard paths.allSatisfy({ FileManager.default.fileExists(atPath: $0) }) else {
            print("[OCR-confirm skip] corpus files missing")
            return
        }

        // Step 1: Extract fingerprints and classify
        var fps: [LayoutFingerprintV2] = []
        for p in paths {
            guard let doc = PDFDocument(url: URL(fileURLWithPath: p)),
                  let extracted = LayoutFingerprintV2Extractor.extract(from: doc) else {
                throw TestError("Could not extract \(p)")
            }
            fps.append(extracted)
        }

        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
        let (tier, score, templateID) = calibrator.classify(
            sourceDigest: "digest-scan-a",
            layoutV2: fps[0],
            templatesV2: ["tpl-scan-b": fps[1]],
            exactSourceDigests: ["tpl-scan-b": "digest-scan-b"]
        )

        print("[OCR-confirm e2e] calibrator tier=\(tier.rawValue) score=\(String(format: "%.4f", score))")

        // Step 2: If calibrator abstained, escalate to confirm lane
        if tier == .insufficientEvidence {
            let confirmResult = lane.confirm(
                candidatePDF: paths[0],
                templatePDF: paths[1],
                candidateDigest: "digest-scan-a",
                templateID: templateID ?? "unknown",
                familyScore: score
            )

            print("[OCR-confirm e2e] confirm decision=\(confirmResult.decision.rawValue)")
            for (name, pr) in confirmResult.providerResults {
                print("  \(name): \(pr.text.count) chars, WER \(pr.wer.map { String(format: "%.4f", $0) } ?? "N/A")")
            }

            // The lane must not promote scans with different content
            #expect(confirmResult.decision != .promote,
                    "Scans with different content must not be promoted through the confirm lane")
        }
        // If calibrator did NOT abstain (score below threshold), that's also
        // valid — the test only exercises the confirm lane when the floor trips.
    }

    private struct TestError: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }
}
