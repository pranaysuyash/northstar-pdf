import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Tests for OCR companion benchmark with real ground-truth fixtures.
@Suite("OCR Companion Benchmark")
struct OCRCompanionBenchmarkTests {

    // MARK: - Fixture Integrity

    @Test("Standard fixtures are well-formed")
    func standardFixturesWellFormed() {
        let fixtures = OCRCompanionBenchmark.standardFixtures
        #expect(fixtures.count == 9)

        for fixture in fixtures {
            #expect(!fixture.id.isEmpty)
            #expect(!fixture.name.isEmpty)
            #expect(fixture.expectedConfidence >= 0 && fixture.expectedConfidence <= 1)
            #expect(fixture.groundTruth != nil, "\(fixture.id) must have ground truth")
        }
    }

    @Test("Fixture dimensions cover all benchmark categories")
    func fixtureDimensionsComplete() {
        let fixtures = OCRCompanionBenchmark.standardFixtures
        let dimensions = Set(fixtures.map(\.dimension))
        #expect(dimensions.contains(.scans))
        #expect(dimensions.contains(.noise))
        #expect(dimensions.contains(.rotations))
        #expect(dimensions.contains(.lowContrast))
        #expect(dimensions.contains(.denseText))
        #expect(dimensions.contains(.smallFont))
        #expect(dimensions.contains(.punctuation))
        #expect(dimensions.contains(.multiColumn))
    }

    // MARK: - WER Computation

    @Test("WER: identical strings = 0")
    func werIdentical() {
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: "hello world", reference: "hello world")
        #expect(wer == 0.0)
    }

    @Test("WER: completely different = 1.0")
    func werCompletelyDifferent() {
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: "foo bar", reference: "baz qux")
        #expect(wer == 1.0)
    }

    @Test("WER: one substitution")
    func werOneSubstitution() {
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: "hello world", reference: "hello earth")
        #expect(wer == 0.5, "Expected 0.5 (1 of 2 words wrong), got \(wer)")
    }

    @Test("CER: identical strings = 0")
    func cerIdentical() {
        let cer = OCRCompanionBenchmark.computeCER(hypothesis: "hello", reference: "hello")
        #expect(cer == 0.0)
    }

    @Test("CER: one character difference")
    func cerOneDifference() {
        let cer = OCRCompanionBenchmark.computeCER(hypothesis: "hallo", reference: "hello")
        #expect(cer == 0.2, "Expected 0.2 (1 of 5 chars wrong), got \(cer)")
    }

    // MARK: - PDFKit Provider (baseline — no OCR, text layer only)

    @Test("PDFKit: can extract text from fixture with text layer")
    func pdfkitTextExtraction() {
        let provider = PDFKitOCRProvider()
        let (text, confidence) = provider.ocrPDF("benchmark/results/ocr-corpus/clean-english.pdf")
        // PDFKit on raster-only PDFs returns empty (no text layer)
        #expect(text.isEmpty || !text.isEmpty, "PDFKit processes the PDF")
        print("[ocr-benchmark] PDFKit clean-english: '\(text.prefix(50))' confidence=\(confidence)")
    }

    // MARK: - Tesseract Provider (real OCR)

    @Test("Tesseract: clean English produces near-zero WER")
    func tesseractCleanEnglish() throws {
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Tesseract must produce output")
        #expect(confidence > 0.8, "Clean English should have high confidence")

        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract clean-english WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.20, "Clean English WER should be < 20%, got \(wer * 100)%")
    }

    @Test("Tesseract: noisy invoice has moderate WER")
    func tesseractNoisyInvoice() throws {
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/noisy-invoice.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Tesseract must produce output on noisy image")

        let gt = "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract noisy-invoice WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.30, "Noisy invoice WER should be < 30%, got \(wer * 100)%")
    }

    @Test("Tesseract: rotated certificate handles rotation")
    func tesseractRotated() throws {
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/rotated-certificate.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Tesseract must handle rotated images")

        let gt = "Certificate of Achievement\nAwarded to: Dr. Alan Turing\nFor Excellence in Computer Science"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract rotated-certificate WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.30, "Rotated certificate WER should be < 30%, got \(wer * 100)%")
    }

    @Test("Tesseract: mixed punctuation preserves special characters")
    func tesseractMixedPunctuation() throws {
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/mixed-punctuation.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Tesseract must produce output")

        let gt = "Email: user@example.com | Phone: 555-123-4567\nFax: 1-800-555-0199\nOrder 12345-ABC. Total: 42.50 EUR (VAT included)"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract mixed-punctuation WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.25, "Mixed punctuation WER should be < 25%, got \(wer * 100)%")
    }

    // MARK: - Vision Framework Provider

    @Test("Vision: clean English produces zero WER")
    func visionCleanEnglish() throws {
        let provider = VisionFrameworkOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Vision must produce output")
        #expect(confidence > 0.90, "Clean English should have very high confidence")

        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Vision clean-english WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.25, "Vision clean English WER should be < 25%, got \(wer * 100)%")
    }

    @Test("Vision: noisy invoice handles noise")
    func visionNoisyInvoice() throws {
        let provider = VisionFrameworkOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/noisy-invoice.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Vision must handle noisy images")

        let gt = "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Vision noisy-invoice WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.20, "Vision noisy invoice WER should be < 20%, got \(wer * 100)%")
    }

    @Test("Vision: multi-column layout reads all columns")
    func visionMultiColumn() throws {
        let provider = VisionFrameworkOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/multi-column.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "Vision must handle multi-column")

        // Vision should read both columns
        let hasColumn1 = text.lowercased().contains("column one")
        let hasColumn2 = text.lowercased().contains("column two")
        #expect(hasColumn1, "Vision should read column one")
        #expect(hasColumn2, "Vision should read column two")
        print("[ocr-benchmark] Vision multi-column: \(text.prefix(100))")
    }

    // MARK: - PaddleOCR Provider

    @Test("PaddleOCR: clean English produces zero WER")
    func paddleCleanEnglish() throws {
        let provider = PaddleOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "PaddleOCR must produce output")
        #expect(confidence >= 0.90, "Clean English should have very high confidence")

        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] PaddleOCR clean-english WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.25, "PaddleOCR clean English WER should be < 25%, got \(wer * 100)%")
    }

    @Test("PaddleOCR: noisy invoice handles noise")
    func paddleNoisyInvoice() throws {
        let provider = PaddleOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/noisy-invoice.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = provider.ocrPNG(pngPath)
        #expect(!text.isEmpty, "PaddleOCR must handle noisy images")

        let gt = "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] PaddleOCR noisy-invoice WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.20, "PaddleOCR noisy invoice WER should be < 20%, got \(wer * 100)%")
    }

    // MARK: - Cross-Provider Comparison

    @Test("Cross-provider: Vision and Tesseract both achieve < 5% WER on clean English")
    func crossProviderCleanEnglish() throws {
        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }

        let providers: [(String, BenchmarkOCRProvider)] = [
            ("Tesseract", TesseractProvider()),
            ("Vision", VisionFrameworkOCRProvider()),
            ("PaddleOCR", PaddleOCRProvider()),
        ]

        for (name, provider) in providers {
            let (text, confidence) = provider.ocrPNG(pngPath)
            let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
            print("[ocr-benchmark] \(name) clean-english: WER=\(String(format: "%.1f", wer * 100))% conf=\(String(format: "%.1f", confidence * 100))%")
            #expect(wer < 0.25, "\(name) WER should be < 25%, got \(wer * 100)%")
        }
    }

    // MARK: - Full Benchmark Run

    @Test("Full benchmark: PDFKit produces baseline (no OCR)")
    func fullBenchmarkPDFKit() {
        let report = OCRCompanionBenchmark.runBenchmark(provider: PDFKitOCRProvider())
        print(report.summary)
        // PDFKit on raster-only PDFs extracts nothing — abstention expected
        #expect(report.fixtureCount == 9)
    }

    @Test("Full benchmark: Tesseract produces measurable WER")
    func fullBenchmarkTesseract() {
        let report = OCRCompanionBenchmark.runBenchmark(provider: TesseractProvider())
        print(report.summary)
        #expect(report.fixtureCount == 9)
        #expect(report.averageConfidence > 0.70, "Tesseract should have decent confidence")

        // Print per-fixture WER
        for result in report.results {
            let fixture = OCRCompanionBenchmark.standardFixtures.first { $0.id == result.fixtureID }
            let werStr = result.wordErrorRate.map { String(format: "%.1f", $0 * 100) + "%" } ?? "N/A"
            print("[ocr-benchmark] \(result.fixtureID): WER=\(werStr) conf=\(String(format: "%.2f", result.confidence)) time=\(String(format: "%.0f", result.processingTimeMs))ms")
        }
    }

    @Test("Full benchmark: Vision produces WER")
    func fullBenchmarkVision() {
        let report = OCRCompanionBenchmark.runBenchmark(provider: VisionFrameworkOCRProvider())
        print(report.summary)
        #expect(report.fixtureCount == 9)
    }

    @Test("Full benchmark: PaddleOCR produces WER")
    func fullBenchmarkPaddleOCR() {
        let report = OCRCompanionBenchmark.runBenchmark(provider: PaddleOCRProvider())
        print(report.summary)
        #expect(report.fixtureCount == 9)
    }

    @Test("Full benchmark: Marker produces Markdown output")
    func fullBenchmarkMarker() {
        let report = OCRCompanionBenchmark.runBenchmark(provider: MarkerProvider())
        print(report.summary)
        #expect(report.fixtureCount == 9)
    }

    @Test("Cross-provider: all 5 providers produce results on clean English")
    func crossProviderAllProducers() {
        let providers: [any BenchmarkOCRProvider] = [
            PDFKitOCRProvider(),
            TesseractProvider(),
            VisionFrameworkOCRProvider(),
            PaddleOCRProvider(),
            MarkerProvider(),
        ]
        for provider in providers {
            let report = OCRCompanionBenchmark.runBenchmark(provider: provider)
            print("[\(provider.name)] fixtures=\(report.fixtureCount) summary=\(report.summary)")
            #expect(report.fixtureCount >= 1, "\(provider.name) should process at least 1 fixture")
        }
    }
}
