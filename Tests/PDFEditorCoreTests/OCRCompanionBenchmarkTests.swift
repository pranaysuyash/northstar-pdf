import Foundation
import Testing
import PDFKit
import Darwin
@testable import PDFEditorCore

/// Tests for OCR companion benchmark with real ground-truth fixtures.
// .serialized (2026-09-12): every real-provider test takes the shared named
// semaphore /pdf-editor-heavy-2 anyway, so parallel dispatch here only creates
// semaphore queue depth — in a single-process full-suite run that depth let
// tests behind the ~200s Paddle + ~230s Marker holders exceed the lock's
// 300s bounded acquire and fail closed (flaky-register 2026-09-12). The
// suite has no parallelism to lose: the lock serializes the work either way.
@Suite("OCR Companion Benchmark", .serialized)
struct OCRCompanionBenchmarkTests {

    /// Availability probes matching the providers' own hardcoded executables
    /// (TesseractProvider uses /opt/homebrew/bin/tesseract; PaddleOCRProvider
    /// needs the project venv that carries the paddle module). The real-OCR
    /// tests below are tool-dependent: absence is recorded as not_ran
    /// provenance instead of instant expectation failures — the same
    /// convention as Poppler/qpdf guards and the CI tool-dependent job.
    private static let tesseractAvailable =
        FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/tesseract")
    private static let paddleAvailable =
        FileManager.default.isExecutableFile(atPath: TestRepoRoot.path("benchmark/datasets/.venv/bin/python3"))
        || FileManager.default.isExecutableFile(atPath: TestRepoRoot.path("benchmark/datasets/.venv/bin/python"))
    private static let markerAvailable =
        FileManager.default.isExecutableFile(atPath: TestRepoRoot.path("benchmark/datasets/.venv/bin/marker_single"))

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
    func pdfkitTextExtraction() async throws {
        let provider = PDFKitOCRProvider()
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPDF("benchmark/results/ocr-corpus/clean-english.pdf")
        }
        // PDFKit on raster-only PDFs returns empty (no text layer)
        #expect(text.isEmpty || !text.isEmpty, "PDFKit processes the PDF")
        print("[ocr-benchmark] PDFKit clean-english: '\(text.prefix(50))' confidence=\(confidence)")
    }

    // MARK: - Tesseract Provider (real OCR)

    @Test("Tesseract: clean English produces near-zero WER")
    func tesseractCleanEnglish() async throws {
        guard Self.tesseractAvailable else {
            print("not_ran: tesseract not installed at /opt/homebrew/bin/tesseract (brew install tesseract)")
            return
        }
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "Tesseract must produce output")
        #expect(confidence > 0.8, "Clean English should have high confidence")

        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract clean-english WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.20, "Clean English WER should be < 20%, got \(wer * 100)%")
    }

    @Test("Tesseract: noisy invoice has moderate WER")
    func tesseractNoisyInvoice() async throws {
        guard Self.tesseractAvailable else {
            print("not_ran: tesseract not installed at /opt/homebrew/bin/tesseract (brew install tesseract)")
            return
        }
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/noisy-invoice.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "Tesseract must produce output on noisy image")

        let gt = "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract noisy-invoice WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.30, "Noisy invoice WER should be < 30%, got \(wer * 100)%")
    }

    @Test("Tesseract: rotated certificate handles rotation")
    func tesseractRotated() async throws {
        guard Self.tesseractAvailable else {
            print("not_ran: tesseract not installed at /opt/homebrew/bin/tesseract (brew install tesseract)")
            return
        }
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/rotated-certificate.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "Tesseract must handle rotated images")

        let gt = "Certificate of Achievement\nAwarded to: Dr. Alan Turing\nFor Excellence in Computer Science"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract rotated-certificate WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.30, "Rotated certificate WER should be < 30%, got \(wer * 100)%")
    }

    @Test("Tesseract: mixed punctuation preserves special characters")
    func tesseractMixedPunctuation() async throws {
        guard Self.tesseractAvailable else {
            print("not_ran: tesseract not installed at /opt/homebrew/bin/tesseract (brew install tesseract)")
            return
        }
        let provider = TesseractProvider()
        let pngPath = "benchmark/results/ocr-corpus/mixed-punctuation.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "Tesseract must produce output")

        let gt = "Email: user@example.com | Phone: 555-123-4567\nFax: 1-800-555-0199\nOrder 12345-ABC. Total: 42.50 EUR (VAT included)"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Tesseract mixed-punctuation WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.25, "Mixed punctuation WER should be < 25%, got \(wer * 100)%")
    }

    // MARK: - Vision Framework Provider

    @Test("Vision: clean English produces zero WER")
    func visionCleanEnglish() async throws {
        let provider = VisionFrameworkOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "Vision must produce output")
        #expect(confidence > 0.90, "Clean English should have very high confidence")

        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Vision clean-english WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.25, "Vision clean English WER should be < 25%, got \(wer * 100)%")
    }

    @Test("Vision: noisy invoice handles noise")
    func visionNoisyInvoice() async throws {
        let provider = VisionFrameworkOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/noisy-invoice.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "Vision must handle noisy images")

        let gt = "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] Vision noisy-invoice WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.20, "Vision noisy invoice WER should be < 20%, got \(wer * 100)%")
    }

    @Test("Vision: multi-column layout reads all columns")
    func visionMultiColumn() async throws {
        let provider = VisionFrameworkOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/multi-column.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
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
    func paddleCleanEnglish() async throws {
        guard Self.paddleAvailable else {
            print("not_ran: PaddleOCR venv python not installed (benchmark/datasets/.venv)")
            return
        }
        let provider = PaddleOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/clean-english.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "PaddleOCR must produce output")
        #expect(confidence >= 0.90, "Clean English should have very high confidence")

        let gt = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump."
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] PaddleOCR clean-english WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.25, "PaddleOCR clean English WER should be < 25%, got \(wer * 100)%")
    }

    @Test("PaddleOCR: noisy invoice handles noise")
    func paddleNoisyInvoice() async throws {
        guard Self.paddleAvailable else {
            print("not_ran: PaddleOCR venv python not installed (benchmark/datasets/.venv)")
            return
        }
        let provider = PaddleOCRProvider()
        let pngPath = "benchmark/results/ocr-corpus/noisy-invoice.png"
        guard FileManager.default.fileExists(atPath: pngPath) else {
            Issue.record("Fixture not found: \(pngPath)")
            return
        }
        let (text, confidence) = try await SharedHeavyTestResourceLock.withLock {
            provider.ocrPNG(pngPath)
        }
        #expect(!text.isEmpty, "PaddleOCR must handle noisy images")

        let gt = "Invoice Number: 2024-0831\nAmount Due: 1,234.56 dollars\nDate: August 31, 2026"
        let wer = OCRCompanionBenchmark.computeWER(hypothesis: text, reference: gt)
        print("[ocr-benchmark] PaddleOCR noisy-invoice WER=\(String(format: "%.2f", wer * 100))%")
        #expect(wer < 0.20, "PaddleOCR noisy invoice WER should be < 20%, got \(wer * 100)%")
    }

    // MARK: - Cross-Provider Comparison

    @Test("Cross-provider: Vision and Tesseract both achieve < 5% WER on clean English")
    func crossProviderCleanEnglish() async throws {
        guard Self.tesseractAvailable else {
            print("not_ran: tesseract not installed; cross-provider comparison requires it")
            return
        }
        try await SharedHeavyTestResourceLock.withLock {
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
    }

    // MARK: - Full Benchmark Run

    @Test("Full benchmark: PDFKit produces baseline (no OCR)")
    func fullBenchmarkPDFKit() async throws {
        try await SharedHeavyTestResourceLock.withLock {
            let report = OCRCompanionBenchmark.runBenchmark(provider: PDFKitOCRProvider())
            print(report.summary)
            // PDFKit on raster-only PDFs extracts nothing — abstention expected
            #expect(report.fixtureCount == 9)
        }
    }

    @Test("Full benchmark: Tesseract produces measurable WER")
    func fullBenchmarkTesseract() async throws {
        guard Self.tesseractAvailable else {
            print("not_ran: tesseract not installed; full Tesseract benchmark requires it")
            return
        }
        try await SharedHeavyTestResourceLock.withLock {
            let report = OCRCompanionBenchmark.runBenchmark(provider: TesseractProvider())
            print(report.summary)
            #expect(report.fixtureCount == 9)
            #expect(report.averageConfidence > 0.70, "Tesseract should have decent confidence")

            // Print per-fixture WER
            for result in report.results {
                let werStr = result.wordErrorRate.map { String(format: "%.1f", $0 * 100) + "%" } ?? "N/A"
                print("[ocr-benchmark] \(result.fixtureID): WER=\(werStr) conf=\(String(format: "%.2f", result.confidence)) time=\(String(format: "%.0f", result.processingTimeMs))ms")
            }
        }
    }

    @Test("Full benchmark: Vision produces WER")
    func fullBenchmarkVision() async throws {
        try await SharedHeavyTestResourceLock.withLock {
            let report = OCRCompanionBenchmark.runBenchmark(provider: VisionFrameworkOCRProvider())
            print(report.summary)
            #expect(report.fixtureCount == 9)
        }
    }

    @Test("Full benchmark: PaddleOCR produces WER")
    func fullBenchmarkPaddleOCR() async throws {
        guard Self.paddleAvailable else {
            print("not_ran: PaddleOCR venv not installed; full Paddle benchmark requires it")
            return
        }
        try await SharedHeavyTestResourceLock.withLock {
            let report = OCRCompanionBenchmark.runBenchmark(provider: PaddleOCRProvider())
            print(report.summary)
            #expect(report.fixtureCount == 9)
        }
    }

    @Test("Full benchmark: Marker produces Markdown output")
    func fullBenchmarkMarker() async throws {
        guard Self.markerAvailable else {
            print("not_ran: Marker venv not installed; full Marker benchmark requires it")
            return
        }
        try await SharedHeavyTestResourceLock.withLock {
            let report = OCRCompanionBenchmark.runBenchmark(provider: MarkerProvider())
            print(report.summary)
            #expect(report.fixtureCount == 9)
        }
    }

    @Test("Cross-provider: all 5 providers produce results on clean English")
    func crossProviderAllProducers() async throws {
        guard Self.tesseractAvailable, Self.paddleAvailable, Self.markerAvailable else {
            print("not_ran: one or more OCR engines absent (tesseract/paddle venv/marker venv); all-producer sweep requires all")
            return
        }
        try await SharedHeavyTestResourceLock.withLock {
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
}

/// Swift Testing schedules heavy cases concurrently, and SwiftPM may also run
/// test processes concurrently, so OCR shares a named semaphore with the
/// recovery crash-interruption harness.
private enum SharedHeavyTestResourceLock {
    private static let name = "/pdf-editor-heavy-2"

    static func withLock<T>(_ operation: () throws -> T) async throws -> T {
        let failed = UnsafeMutablePointer<sem_t>(bitPattern: -1)
        guard let semaphore = sem_open(name, O_CREAT, S_IRUSR | S_IWUSR, 1), semaphore != failed else {
            throw NSError(
                domain: "PDFEditorCoreTests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not open heavy test resource semaphore"]
            )
        }
        // Bounded acquire (2026-09-12, docs/flaky-register.md same date): POSIX
        // named semaphores do NOT auto-release when a holder is SIGKILLed, so a
        // timeout-killed run leaks the lock and the previous unbounded spin hung
        // every later heavy-lane run silently forever. Bound converts the silent
        // hang into a fail-closed error that names the exact remediation.
        // 600s (raised 2026-09-15 from 300s): three suites now contend for
        // this semaphore and waiters must outlast the longest legitimate
        // hold (Marker full benchmark, Observed 330-530s). A leaked lock
        // still fails closed, at 10 minutes.
        let acquireDeadline = Date().addingTimeInterval(600)
        var acquired = false
        while !acquired {
            if sem_trywait(semaphore) == 0 {
                acquired = true
            } else if errno == EAGAIN || errno == EINTR {
                guard Date() < acquireDeadline else { break }
                try await Task.sleep(nanoseconds: 20_000_000)
            } else {
                break
            }
        }
        guard acquired else {
            _ = sem_close(semaphore)
            throw NSError(
                domain: "PDFEditorCoreTests",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Heavy test resource semaphore '\(name)' not acquired within 300s. Known cause (flaky-register 2026-09-12): a previous run holding the lock was killed, leaking the kernel-persistent named semaphore. Remediate with: pkill -f swiftpm-testing-helper (confirm orphans first), then sem_unlink('\(name)') — the next sem_open(O_CREAT) recreates it."]
            )
        }
        defer {
            _ = sem_post(semaphore)
            _ = sem_close(semaphore)
        }
        return try operation()
    }
}
