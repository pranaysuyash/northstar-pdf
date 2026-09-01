import Foundation
import Testing
@testable import PDFEditorCore

/// Tests for the cross-provider AcroForm parity experiment.
@Suite("AcroForm Parity Experiment")
struct AcroFormParityExperimentTests {

    /// Discover form-bearing PDFs from the governed corpus.
    ///
    /// Includes PDFs from multiple producers to stress-test the round-trip:
    /// - public-sample-form (baseline)
    /// - pdfkit-widgets (PDFKit native widgets)
    /// - public-acroform (PDFKit AcroForm)
    /// - native-incremental (6 producer re-encodes: synthetic, tagged, compressed)
    /// - browser-corpus hybrid (text + raster form)
    /// - rotation-corpus (rotated widgets)
    private static func corpusFixtures() -> [String] {
        let fm = FileManager.default
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        
        // Known form-bearing PDFs (verified via PDFKit inspection)
        let knownForms = [
            "benchmark/results/public-sample-form.pdf",
            "benchmark/results/2026-08-23-pdfkit-widgets/noop.pdf",
            "benchmark/results/2026-08-23-public-acroform/noop.pdf",
            // Producer re-encodes of the same base form
            "benchmark/results/2026-08-25-native-incremental/corpus/compressed-acroform.pdf",
            "benchmark/results/2026-08-25-native-incremental/corpus/tagged-acroform.pdf",
            "benchmark/results/2026-08-25-native-incremental/corpus/tagged-no-acroform.pdf",
            "benchmark/results/2026-08-25-native-incremental/corpus/synthetic-producer-0.pdf",
            // Browser corpus: hybrid text+raster form
            "benchmark/results/browser-corpus/hybrid-text-raster-form.pdf",
            // Rotation corpus: rotated widgets
            "benchmark/results/rotation-corpus/rotated-widget-90.pdf",
        ]
        
        var fixtures: [String] = []
        for rel in knownForms {
            let path = projectRoot.appendingPathComponent(rel).path
            if fm.fileExists(atPath: path) && !fixtures.contains(path) {
                fixtures.append(path)
            }
        }
        return fixtures
    }

    @Test("AcroFormFieldType classification")
    func fieldTypeClassification() {
        #expect(AcroFormFieldType.radio.supportsRoundTrip == true)
        #expect(AcroFormFieldType.checkbox.supportsRoundTrip == true)
        #expect(AcroFormFieldType.choice.supportsRoundTrip == true)
        #expect(AcroFormFieldType.text.supportsRoundTrip == true)
        #expect(AcroFormFieldType.signature.supportsRoundTrip == false)
        #expect(AcroFormFieldType.button.supportsRoundTrip == false)
    }

    @Test("ProviderCapability decision logic")
    func capabilityDecision() {
        let highConfidence = AcroFormCapability(
            provider: "PDFKit", fieldType: .text,
            canDetect: true, canRead: true, canWrite: true, canRoundTrip: true,
            verifiedFixtures: 10, failedFixtures: 0
        )
        #expect(highConfidence.decision == .productionReady)
        #expect(highConfidence.confidence == 1.0)

        let mediumConfidence = AcroFormCapability(
            provider: "PDF.js", fieldType: .choice,
            canDetect: true, canRead: true, canWrite: false, canRoundTrip: false,
            verifiedFixtures: 8, failedFixtures: 2
        )
        #expect(mediumConfidence.decision == .experimental)
        #expect(mediumConfidence.confidence == 0.8)

        let lowConfidence = AcroFormCapability(
            provider: "qpdf", fieldType: .radio,
            canDetect: true, canRead: false, canWrite: false, canRoundTrip: false,
            verifiedFixtures: 2, failedFixtures: 8
        )
        #expect(lowConfidence.decision == .unsupported)
        #expect(lowConfidence.confidence == 0.2)
    }

    @Test("Experiment runs against real PDF corpus and persists gate report")
    func experimentRuns() {
        let fixtures = Self.corpusFixtures()
        #expect(fixtures.count >= 1, "Need at least 1 corpus fixture")

        let results = AcroFormParityExperiment.runExperiment(fixturePaths: fixtures)
        #expect(results.count == 4) // radio, checkbox, choice, text

        for result in results {
            print("[parity] \(result.fieldType.rawValue): \(result.decision)")
            print("  agreement=\(String(format: "%.2f", result.crossProviderAgreement)) roundTrip=\(String(format: "%.2f", result.roundTripSuccessRate)) ghost=\(result.ghostFields)")
        }

        // Persist the gate report.
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let outputDir = projectRoot.appendingPathComponent("benchmark/results/acroform-parity").path
        let url = AcroFormParityExperiment.persistReport(
            results: results,
            corpusSize: fixtures.count,
            outputDir: outputDir
        )
        #expect(url != nil, "Gate report must be persisted")
        #expect(FileManager.default.fileExists(atPath: outputDir + "/acroform-parity-gate-report.json"))
    }
}
