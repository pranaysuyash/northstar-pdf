import Foundation
import Testing
import PDFKit
import CryptoKit
@testable import PDFEditorCore

/// Calibration verification against the real benchmark PDF corpus.
///
/// This test suite runs the RecurringFormCalibrator and PageBoxPolicy
/// against the actual PDF fixtures in benchmark/results/ to verify that
/// calibrated thresholds produce correct classifications and that
/// cross-system comparison tolerances are appropriate.
///
/// Doctrine alignment:
/// - §5: Evidence-based — every claim is verified against real PDFs
/// - §3: Proportional rigor — Tier 3 (integration) with real corpus
/// - §2: Truth taxonomy — results labeled as Observed (real PDFs)

// MARK: - Corpus Paths

private enum CorpusPath {
    static let root = "/Users/pranay/Projects/pdf_editor/benchmark/results"
    static let corpusSweep = "\(root)/corpus-sweep-2026-08-25"
    static let browserCorpus = "\(root)/browser-corpus"
    static let contractParity = "\(root)/contract-parity-2026-08-24"
    static let detectorCalibration = "\(root)/detector-calibration"

    static func corpusSweepPDF(_ name: String) -> String {
        "\(corpusSweep)/\(name)"
    }

    static func browserCorpusPDF(_ name: String) -> String {
        "\(browserCorpus)/\(name)"
    }
}

// MARK: - Persisted Artifact Schema

/// Persisted recurring-form calibration report artifact.
/// Schema: `pdf-editor.recurring-form-calibration-report` v1.0.
/// Deterministic content (fixed generatedAt) so the artifact is stable across
/// runs and can be committed as evidence.
private struct RecurringFormCalibrationArtifact: Codable {
    struct Version: Codable {
        let major: Int
        let minor: Int
    }

    let schema: String
    let version: Version
    let generatedAt: String
    let corpus: String
    let thresholds: MatchingThresholds
    let calibration: CalibrationReport
    let falsePositiveReport: FalsePositiveReport
}

// MARK: - Helper: Extract page boxes from a real PDF

private func extractPageBoxes(from url: URL) -> PageBoxValues? {
    guard let document = PDFDocument(url: url) else { return nil }
    guard let page = document.page(at: 0) else { return nil }

    let mediaBox = page.bounds(for: .mediaBox)
    let cropBox = page.bounds(for: .cropBox)
    let bleedBox = page.bounds(for: .bleedBox)
    let trimBox = page.bounds(for: .trimBox)
    let artBox = page.bounds(for: .artBox)

    return PageBoxValues(
        mediaBox: mediaBox,
        cropBox: cropBox,
        bleedBox: bleedBox,
        trimBox: trimBox,
        artBox: artBox
    )
}

// MARK: - Helper: Extract V2 layout fingerprint from PDF

/// V2 structured fingerprint (LayoutFingerprintV2) — replaces the V1
/// first-page size + rotation + page-count string (recommendation 1 of the
/// layout-fingerprint exploration §7; the V1 collision was Finding 1).
/// The calibrator consumes it through the V2-aware lane with structured
/// similarity on the F-3-calibrated scale (threshold 0.90).
private func extractLayoutV2(from url: URL) -> LayoutFingerprintV2? {
    guard let document = PDFDocument(url: url) else { return nil }
    return LayoutFingerprintV2Extractor.extract(from: document)
}

// MARK: - Calibration Verification Tests

@Suite("Calibration — Real Corpus Verification")
struct CalibrationCorpusVerificationTests {

    // MARK: - Page Box Extraction Verification

    @Test("Page box extraction works on real corpus PDFs")
    func pageBoxExtractionOnRealCorpus() {
        let pdfNames = [
            "plain-text.pdf",
            "multi-column.pdf",
            "geometry.pdf",
            "navigation.pdf",
            "metadata-complete.pdf"
        ]

        var extractedCount = 0
        for name in pdfNames {
            let path = CorpusPath.corpusSweepPDF(name)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            if let boxes = extractPageBoxes(from: url) {
                extractedCount += 1
                #expect(boxes.mediaBox.width > 0, "\(name) should have valid mediaBox width")
                #expect(boxes.mediaBox.height > 0, "\(name) should have valid mediaBox height")
                #expect(boxes.canonicalBox == .cropBox || boxes.canonicalBox == .mediaBox,
                        "\(name) canonical box should be cropBox or mediaBox")
            }
        }

        // At least 3 of 5 should extract successfully
        #expect(extractedCount >= 3, "Should extract page boxes from at least 3 corpus PDFs")
    }

    @Test("Page box sizes are consistent across corpus categories")
    func pageSizeConsistency() {
        let pdfNames = [
            "plain-text.pdf",
            "multi-column.pdf",
            "metadata-complete.pdf"
        ]

        var sizes: [CGSize] = []
        for name in pdfNames {
            let path = CorpusPath.corpusSweepPDF(name)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            if let boxes = extractPageBoxes(from: url) {
                sizes.append(boxes.effectiveSize)
            }
        }

        // All should be Letter or A4 size
        for size in sizes {
            let isLetter = abs(size.width - 612) < 1 && abs(size.height - 792) < 1
            let isA4 = abs(size.width - 595) < 1 && abs(size.height - 842) < 1
            #expect(isLetter || isA4, "Page size \(size) should be Letter or A4")
        }
    }

    // MARK: - Cross-System Comparison on Real PDFs

    @Test("PageBoxPolicy comparison detects no issues on consistent PDFs")
    func crossSystemComparisonConsistent() {
        let policy = PageBoxPolicy(precision: .pdfKitStandard)
        let path = CorpusPath.corpusSweepPDF("plain-text.pdf")
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        let url = URL(fileURLWithPath: path)

        guard let boxes = extractPageBoxes(from: url) else {
            return
        }

        // Compare PDFKit values against themselves (should pass)
        let comparison = policy.compare(pdfKit: boxes, pdfJs: boxes)
        #expect(comparison.passed, "Self-comparison should pass: \(comparison.issues)")
        #expect(comparison.sizeDeviation == 0)
        #expect(comparison.coordinateDeviation == 0)
    }

    @Test("PageBoxPolicy fingerprint is deterministic")
    func fingerprintDeterminism() {
        let policy = PageBoxPolicy(precision: .pdfKitStandard)
        let path = CorpusPath.corpusSweepPDF("plain-text.pdf")
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        let url = URL(fileURLWithPath: path)

        guard let boxes = extractPageBoxes(from: url) else {
            return
        }

        let fp1 = policy.fingerprint(from: boxes)
        let fp2 = policy.fingerprint(from: boxes)
        #expect(fp1 == fp2, "Fingerprint should be deterministic")
        #expect(!fp1.isEmpty, "Fingerprint should not be empty")
    }

    @Test("PageBoxPolicy normalization handles negative coordinates")
    func negativeCoordinateNormalization() {
        let policy = PageBoxPolicy(precision: .pdfKitStandard)

        // Simulate a PDF with negative origin (some PDFs have this)
        let boxes = PageBoxValues(
            mediaBox: CGRect(x: -10, y: -5, width: 612, height: 792),
            cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
        )

        let normalized = policy.normalizedBox(boxes.mediaBox)
        #expect(normalized.origin.x >= 0, "Negative X should be normalized to 0")
        #expect(normalized.origin.y >= 0, "Negative Y should be normalized to 0")
    }

    // MARK: - Layout Fingerprint Verification

    @Test("V2 layout fingerprints are computed and discriminate all corpus PDFs")
    func v2LayoutFingerprintsOnCorpus() {
        let pdfNames = [
            "plain-text.pdf",
            "multi-column.pdf",
            "geometry.pdf",
            "navigation.pdf"
        ]

        var fingerprints: [String] = []
        for name in pdfNames {
            let path = CorpusPath.corpusSweepPDF(name)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            if let fp = extractLayoutV2(from: url) {
                fingerprints.append(fp.digest)
            }
        }

        // Finding 1 resolution: V2 discriminates where V1 collided
        // (V1 = first-page size + rotation + count collided on
        // plain-text ↔ navigation). Every corpus PDF must have a unique
        // V2 digest.
        let uniqueFingerprints = Set(fingerprints)
        #expect(uniqueFingerprints.count == fingerprints.count,
                "V2 must discriminate every corpus PDF, got \(uniqueFingerprints.count)/\(fingerprints.count)")
        #expect(uniqueFingerprints.count >= 3,
                "At least 3 fingerprints should differ across different PDFs")
    }

    @Test("V2 layout fingerprints are stable across multiple reads")
    func v2FingerprintStability() {
        let path = CorpusPath.corpusSweepPDF("plain-text.pdf")
        guard FileManager.default.fileExists(atPath: path) else {
            return
        }
        let url = URL(fileURLWithPath: path)

        let fp1 = extractLayoutV2(from: url)
        let fp2 = extractLayoutV2(from: url)
        #expect(fp1?.digest == fp2?.digest, "Fingerprint should be stable across reads")
        #expect(fp1 != nil, "V2 fingerprint must extract")
    }

    // MARK: - RecurringFormCalibrator on Real Corpus

    @Test("Calibrator classifies real corpus entries correctly on the V2 lane")
    func calibratorOnRealCorpus() {
        // V2 lane: the F-3-calibrated structured scale (threshold 0.90).
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)

        // Build templates from known PDFs (V2 fingerprints)
        var templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [:]
        let knownPDFs = [
            ("plain-text.pdf", "tpl-plain"),
            ("multi-column.pdf", "tpl-multi"),
            ("geometry.pdf", "tpl-geometry")
        ]

        for (pdfName, templateID) in knownPDFs {
            let path = CorpusPath.corpusSweepPDF(pdfName)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)

            if let fp = extractLayoutV2(from: url),
               let data = try? Data(contentsOf: url) {
                templatesV2[templateID] = (fingerprint: fp, sourceDigest: data.sha256Hex)
            }
        }

        #expect(templatesV2.count >= 2, "Should have at least 2 templates from real corpus")

        // Classify each known PDF — should match itself exactly
        for (pdfName, templateID) in knownPDFs {
            let path = CorpusPath.corpusSweepPDF(pdfName)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let fp = extractLayoutV2(from: url),
                  let data = try? Data(contentsOf: url) else { continue }

            let digest = data.sha256Hex
            let exactDigests = Dictionary(
                templatesV2.map { ($0.key, $0.value.sourceDigest) },
                uniquingKeysWith: { first, _ in first }
            )

            let (tier, score, matchedTemplate) = calibrator.classify(
                sourceDigest: digest,
                layoutV2: fp,
                templatesV2: templatesV2.mapValues(\.fingerprint),
                exactSourceDigests: exactDigests
            )

            #expect(tier == .exact, "\(pdfName) should be exact match, got \(tier)")
            #expect(score == 1.0, "\(pdfName) should have score 1.0")
            #expect(matchedTemplate == templateID, "\(pdfName) should match \(templateID)")
        }
    }

    @Test("Calibrator rejects different PDFs as non-matches on the V2 lane")
    func calibratorRejectsDifferent() {
        // V2 lane: multi-column vs plain-text measured 0.582 structured
        // similarity — far below the calibrated 0.90 family threshold, so
        // the V2 fingerprint achieves the proper rejection that V1's
        // colliding strings could not.
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)

        // Template from plain-text.pdf
        let templatePath = CorpusPath.corpusSweepPDF("plain-text.pdf")
        guard FileManager.default.fileExists(atPath: templatePath) else { return }
        let templateURL = URL(fileURLWithPath: templatePath)
        guard let templateFP = extractLayoutV2(from: templateURL),
              let templateData = try? Data(contentsOf: templateURL) else { return }

        let templatesV2: [String: LayoutFingerprintV2] = ["tpl-plain": templateFP]
        let exactDigests: [String: String] = ["tpl-plain": templateData.sha256Hex]

        // Classify multi-column.pdf — should NOT match plain-text
        let testPath = CorpusPath.corpusSweepPDF("multi-column.pdf")
        guard FileManager.default.fileExists(atPath: testPath) else { return }
        let testURL = URL(fileURLWithPath: testPath)
        guard let testFP = extractLayoutV2(from: testURL),
              let testData = try? Data(contentsOf: testURL) else { return }

        let (tier, score, _) = calibrator.classify(
            sourceDigest: testData.sha256Hex,
            layoutV2: testFP,
            templatesV2: templatesV2,
            exactSourceDigests: exactDigests
        )

        // V2 resolution: the different PDF is properly rejected (noMatch) —
        // the V1 string lane could only guarantee NOT-exact (it tolerated
        // familyMatch as a documented variance).
        #expect(tier == .noMatch, "Different PDF must be noMatch on the V2 lane, got \(tier) (score \(score))")
        #expect(score < calibrator.thresholds.familyThreshold,
                "Score must stay below the calibrated family threshold")
    }

    // MARK: - Corpus Calibration Report

    @Test("Full corpus calibration produces valid report on the V2 lane")
    func fullCorpusCalibrationReport() {
        // V2 lane: the F-3-calibrated structured scale (threshold 0.90).
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)

        // Build corpus from all available PDFs (V2 fingerprints)
        var corpus: [CorpusEntry] = []
        let pdfNames = [
            "plain-text.pdf", "multi-column.pdf", "geometry.pdf",
            "navigation.pdf", "metadata-complete.pdf"
        ]

        for name in pdfNames {
            let path = CorpusPath.corpusSweepPDF(name)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let fp = extractLayoutV2(from: url),
                  let data = try? Data(contentsOf: url) else { continue }

            // Only the template entries (first 3) can be exact: expectedTier
            // must reflect whether the entry is in the template set. The F-3
            // calibration (Verified 2026-08-28) measured navigation against
            // plain-text/multi-column/geometry at 0.378-0.713, all below the
            // 0.90 family threshold — it is a distinct document (.noMatch),
            // not a variant of any template.
            let isTemplateEntry = name == "plain-text.pdf" || name == "multi-column.pdf" || name == "geometry.pdf"
            corpus.append(CorpusEntry(
                sourceDigest: data.sha256Hex,
                layoutFingerprint: fp.digest,
                expectedTier: isTemplateEntry ? .exact : .noMatch,
                documentClass: name.replacingOccurrences(of: ".pdf", with: ""),
                layoutV2: fp
            ))
        }

        // Add a hard negative (completely different fingerprint)
        corpus.append(CorpusEntry(
            sourceDigest: "fake-digest-hard-negative",
            layoutFingerprint: "fake-fp-hard-negative-xyz",
            expectedTier: .noMatch,
            isHardNegative: true,
            documentClass: "hard-negative"
        ))

        #expect(corpus.count >= 5, "Corpus should have at least 5 entries")

        // Build templates from first 3 entries (V2 fingerprints)
        var templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [:]
        for (idx, entry) in corpus.prefix(3).enumerated() {
            guard let entryV2 = entry.layoutV2 else { continue }
            templatesV2["tpl-\(idx)"] = (fingerprint: entryV2, sourceDigest: entry.sourceDigest)
        }

        let report = calibrator.calibrate(corpus: corpus, templatesV2: templatesV2)

        // Verify report structure
        #expect(report.totalEntries == corpus.count)
        #expect(report.accuracy >= 0 && report.accuracy <= 1)
        #expect(report.falsePositiveRate >= 0 && report.falsePositiveRate <= 1)
        #expect(!report.recommendations.isEmpty, "Should have recommendations")

        // The hard negative should NOT be a false positive
        #expect(report.falsePositives == 0, "Hard negative should not be classified as match")
    }

    // MARK: - False Positive Report Generation

    @Test("False-positive report generates from real corpus calibration on the V2 lane")
    func falsePositiveReportFromRealCorpus() {
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
        let fpGenerator = FalsePositiveReportGenerator(maxFalsePositiveRate: 0.05)

        // Build corpus with hard negatives (V2 fingerprints)
        var corpus: [CorpusEntry] = []
        let pdfNames = ["plain-text.pdf", "multi-column.pdf", "geometry.pdf"]

        for name in pdfNames {
            let path = CorpusPath.corpusSweepPDF(name)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let fp = extractLayoutV2(from: url),
                  let data = try? Data(contentsOf: url) else { continue }

            corpus.append(CorpusEntry(
                sourceDigest: data.sha256Hex,
                layoutFingerprint: fp.digest,
                expectedTier: .exact,
                documentClass: name.replacingOccurrences(of: ".pdf", with: ""),
                layoutV2: fp
            ))
        }

        // Hard negatives: similar but not matching (no V2 → legacy fallback lane)
        corpus.append(CorpusEntry(
            sourceDigest: "hard-neg-similar",
            layoutFingerprint: "similar-but-not-matching-fp",
            expectedTier: .noMatch,
            isHardNegative: true,
            documentClass: "hard-negative-similar"
        ))
        corpus.append(CorpusEntry(
            sourceDigest: "hard-neg-different",
            layoutFingerprint: "completely-different-fingerprint",
            expectedTier: .noMatch,
            isHardNegative: true,
            documentClass: "hard-negative-different"
        ))

        // Build templates (V2 fingerprints)
        var templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [:]
        for (idx, entry) in corpus.filter({ !$0.isHardNegative }).prefix(3).enumerated() {
            guard let entryV2 = entry.layoutV2 else { continue }
            templatesV2["tpl-\(idx)"] = (fingerprint: entryV2, sourceDigest: entry.sourceDigest)
        }

        let calibrationReport = calibrator.calibrate(corpus: corpus, templatesV2: templatesV2)
        let fpReport = fpGenerator.generate(from: calibrationReport, corpus: corpus)

        // Verify false-positive report
        #expect(fpReport.totalHardNegatives == 2)
        #expect(fpReport.falsePositiveCount == 0, "No false positives expected with the calibrated V2 threshold")
        #expect(fpReport.passesThreshold, "False-positive rate should be within 5% threshold")
        #expect(!fpReport.recommendations.isEmpty, "Should have recommendations")
    }

    // MARK: - Persisted False-Positive Report Artifact

    @Test("Real false-positive report artifact is generated and round-trips on the V2 lane")
    func persistedFalsePositiveReportArtifact() {
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
        let fpGenerator = FalsePositiveReportGenerator(maxFalsePositiveRate: 0.05)

        // Real corpus entries with deterministic IDs (artifact must be stable).
        var corpus: [CorpusEntry] = []
        let pdfNames = ["plain-text.pdf", "multi-column.pdf", "geometry.pdf", "navigation.pdf"]
        for name in pdfNames {
            let path = CorpusPath.corpusSweepPDF(name)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let fp = extractLayoutV2(from: url),
                  let data = try? Data(contentsOf: url) else { continue }
            corpus.append(CorpusEntry(
                id: name.replacingOccurrences(of: ".pdf", with: ""),
                sourceDigest: data.sha256Hex,
                layoutFingerprint: fp.digest,
                // navigation is NOT in the template set (first 3), so exact is
                // unattainable; F-3 (Verified 2026-08-28) measured it below the
                // 0.90 family threshold against every template — a distinct
                // document (.noMatch). Under V1 its hex-digest char-Jaccard
                // inflated the score to 0.9 (knownVariant) — precisely the
                // false-similarity the V2 lane fixes.
                expectedTier: name == "navigation.pdf" ? .noMatch : .exact,
                documentClass: name.replacingOccurrences(of: ".pdf", with: ""),
                layoutV2: fp
            ))
        }

        // Hard negatives: similar-but-not-matching fingerprints (no V2 →
        // legacy fallback lane, keeping the string hard-negative machinery).
        corpus.append(CorpusEntry(
            id: "hard-neg-similar",
            sourceDigest: "hard-neg-similar-digest",
            layoutFingerprint: "similar-but-not-matching-fp",
            expectedTier: .noMatch,
            isHardNegative: true,
            documentClass: "hard-negative-similar"
        ))
        corpus.append(CorpusEntry(
            id: "hard-neg-different",
            sourceDigest: "hard-neg-different-digest",
            layoutFingerprint: "completely-different-fingerprint",
            expectedTier: .noMatch,
            isHardNegative: true,
            documentClass: "hard-negative-different"
        ))

        var templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [:]
        for (idx, entry) in corpus.filter({ !$0.isHardNegative }).prefix(3).enumerated() {
            guard let entryV2 = entry.layoutV2 else { continue }
            templatesV2["tpl-\(idx)"] = (fingerprint: entryV2, sourceDigest: entry.sourceDigest)
        }

        let calibrationReport = calibrator.calibrate(corpus: corpus, templatesV2: templatesV2)
        let fpReport = fpGenerator.generate(from: calibrationReport, corpus: corpus)

        let artifact = RecurringFormCalibrationArtifact(
            schema: "pdf-editor.recurring-form-calibration-report",
            version: .init(major: 1, minor: 0),
            generatedAt: "2026-08-28T00:00:00.000Z",
            corpus: "benchmark/results/corpus-sweep-2026-08-25",
            thresholds: calibrator.thresholds,
            calibration: calibrationReport,
            falsePositiveReport: fpReport
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(artifact),
              let json = String(data: data, encoding: .utf8) else {
            #expect(Bool(false), "Artifact must serialize")
            return
        }

        // Round-trip: decode must reproduce the same report.
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(RecurringFormCalibrationArtifact.self, from: data) else {
            #expect(Bool(false), "Artifact must round-trip")
            return
        }
        #expect(decoded.calibration.totalEntries == calibrationReport.totalEntries)
        #expect(decoded.falsePositiveReport.totalHardNegatives == fpReport.totalHardNegatives)
        #expect(decoded.thresholds.familyThreshold == calibrator.thresholds.familyThreshold)

        // Persist the artifact (deterministic content, fixed timestamp).
        let artifactDir = URL(fileURLWithPath: CorpusPath.root)
            .appendingPathComponent("recurring-form-calibration", isDirectory: true)
        let artifactURL = artifactDir.appendingPathComponent("recurring-form-calibration-report-2026-08-28.json")
        try? FileManager.default.createDirectory(at: artifactDir, withIntermediateDirectories: true)
        try? data.write(to: artifactURL)
        #expect(FileManager.default.fileExists(atPath: artifactURL.path), "Artifact must be persisted")
    }

    // MARK: - Tolerance Policy Verification

    @Test("Strict tolerance catches small deviations")
    func strictToleranceCatches() {
        let policy = PageBoxPolicy(precision: PageBoxPrecisionPolicy(
            coordinateSystem: .pdfPoints,
            renderDPI: 72,
            coordinateTolerance: 0.01,
            sizeTolerance: 0.1,
            coordinateRounding: 2,
            normalizeNegativeCoords: true,
            cropBoxOverridesMediaBox: true
        ))

        let reference = PageBoxValues(
            mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
        )

        // 0.05pt deviation — within strict tolerance (0.1pt)
        let smallDeviation = PageBoxValues(
            mediaBox: CGRect(x: 0, y: 0, width: 612.05, height: 792.03),
            cropBox: CGRect(x: 0, y: 0, width: 612.05, height: 792.03),
            bleedBox: CGRect(x: 0, y: 0, width: 612.05, height: 792.03),
            trimBox: CGRect(x: 0, y: 0, width: 612.05, height: 792.03),
            artBox: CGRect(x: 0, y: 0, width: 612.05, height: 792.03)
        )

        let result = policy.compare(pdfKit: reference, pdfJs: smallDeviation)
        #expect(result.passed, "0.05pt deviation should pass strict tolerance: \(result.issues)")

        // 0.2pt deviation — exceeds strict tolerance (0.1pt)
        let largeDeviation = PageBoxValues(
            mediaBox: CGRect(x: 0, y: 0, width: 612.2, height: 792.2),
            cropBox: CGRect(x: 0, y: 0, width: 612.2, height: 792.2),
            bleedBox: CGRect(x: 0, y: 0, width: 612.2, height: 792.2),
            trimBox: CGRect(x: 0, y: 0, width: 612.2, height: 792.2),
            artBox: CGRect(x: 0, y: 0, width: 612.2, height: 792.2)
        )

        let result2 = policy.compare(pdfKit: reference, pdfJs: largeDeviation)
        #expect(!result2.passed, "0.2pt deviation should fail strict tolerance")
    }

    @Test("Relaxed tolerance accepts larger deviations")
    func relaxedToleranceAccepts() {
        let policy = PageBoxPolicy(precision: .relaxed)

        let reference = PageBoxValues(
            mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
            artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
        )

        // 0.8pt deviation — within relaxed tolerance (1.0pt)
        let deviation = PageBoxValues(
            mediaBox: CGRect(x: 0, y: 0, width: 612.8, height: 792.8),
            cropBox: CGRect(x: 0, y: 0, width: 612.8, height: 792.8),
            bleedBox: CGRect(x: 0, y: 0, width: 612.8, height: 792.8),
            trimBox: CGRect(x: 0, y: 0, width: 612.8, height: 792.8),
            artBox: CGRect(x: 0, y: 0, width: 612.8, height: 792.8)
        )

        let result = policy.compare(pdfKit: reference, pdfJs: deviation)
        #expect(result.passed, "0.8pt deviation should pass relaxed tolerance")
    }
}

// MARK: - Data extension for SHA-256

private extension Data {
    var sha256Hex: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
