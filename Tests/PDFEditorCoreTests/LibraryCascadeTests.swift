import Foundation
import PDFEditorCore
import Testing

// MARK: - F-001: Library Cascade Tests

@Suite("Library Cascade Pattern")
struct LibraryCascadeTests {

  /// A mock provider that always succeeds
  struct MockSuccessProvider: CascadeProvider {
    let name: String
    let priority: Int
    let isAvailable: Bool = true

    func execute<T>(input: Data) throws -> T {
      return "success-\(name)" as! T
    }
  }

  /// A mock provider that always fails
  struct MockFailProvider: CascadeProvider {
    let name: String
    let priority: Int
    let isAvailable: Bool = true

    func execute<T>(input: Data) throws -> T {
      throw NSError(domain: name, code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
    }
  }

  /// A mock provider that's unavailable
  struct MockUnavailableProvider: CascadeProvider {
    let name: String
    let priority: Int
    let isAvailable: Bool = false

    func execute<T>(input: Data) throws -> T {
      fatalError("Should not be called when unavailable")
    }
  }

  @Test("Cascade tries providers in priority order")
  func cascadeTriesPriorityOrder() throws {
    let cascade = LibraryCascade<String>(providers: [
      MockSuccessProvider(name: "Low", priority: 30),
      MockSuccessProvider(name: "High", priority: 10),
    ])

    let result = try cascade.execute(input: Data())
    #expect(result.value == "success-High")
    #expect(result.providerName == "High")
  }

  @Test("Cascade falls back to next provider on failure")
  func cascadeFallsBack() throws {
    let cascade = LibraryCascade<String>(providers: [
      MockFailProvider(name: "Primary", priority: 10),
      MockSuccessProvider(name: "Fallback", priority: 20),
    ])

    let result = try cascade.execute(input: Data())
    #expect(result.value == "success-Fallback")
    #expect(result.providerName == "Fallback")
    #expect(result.fallbackHistory.count == 1)
    #expect(result.fallbackHistory[0].providerName == "Primary")
  }

  @Test("Cascade skips unavailable providers")
  func cascadeSkipsUnavailable() throws {
    let cascade = LibraryCascade<String>(providers: [
      MockUnavailableProvider(name: "Unavailable", priority: 10),
      MockSuccessProvider(name: "Available", priority: 20),
    ])

    let result = try cascade.execute(input: Data())
    #expect(result.value == "success-Available")
    #expect(result.fallbackHistory.count == 1) // unavailable was recorded
  }

  @Test("Cascade throws when all providers fail")
  func cascadeExhausted() throws {
    let cascade = LibraryCascade<String>(providers: [
      MockFailProvider(name: "A", priority: 10),
      MockFailProvider(name: "B", priority: 20),
    ])

    #expect(throws: CascadeExhaustedError.self) {
      try cascade.execute(input: Data())
    }
  }

  @Test("Cascade with empty providers throws")
  func cascadeEmpty() throws {
    let cascade = LibraryCascade<String>(providers: [])

    #expect(throws: CascadeExhaustedError.self) {
      try cascade.execute(input: Data())
    }
  }

  @Test("Cascade result includes timing information")
  func cascadeTiming() throws {
    let cascade = LibraryCascade<String>(providers: [
      MockSuccessProvider(name: "Fast", priority: 10),
    ])

    let result = try cascade.execute(input: Data())
    #expect(result.totalTimeMs >= 0)
  }
}

// MARK: - F-003: Shadow Mode Tests

@Suite("Shadow Mode Extraction")
struct ShadowModeTests {

  /// A mock extractor that returns consistent results
  struct MockConsistentExtractor: ShadowExtractor {
    let name: String
    let isAvailable: Bool = true

    func extractText(from data: Data) throws -> ShadowExtractionResult {
      ShadowExtractionResult(
        pageCount: 5,
        characterCount: 1000,
        text: "Consistent text from \(name)",
        timeMs: 1.0
      )
    }
  }

  /// A mock extractor that returns different results
  struct MockDifferentExtractor: ShadowExtractor {
    let name: String
    let isAvailable: Bool = true

    func extractText(from data: Data) throws -> ShadowExtractionResult {
      ShadowExtractionResult(
        pageCount: 5,
        characterCount: 2000, // 100% more characters — exceeds 15% threshold
        text: "Different text from \(name)",
        timeMs: 2.0
      )
    }
  }

  /// A mock extractor that fails
  struct MockFailingExtractor: ShadowExtractor {
    let name: String
    let isAvailable: Bool = true

    func extractText(from data: Data) throws -> ShadowExtractionResult {
      throw NSError(domain: name, code: -1, userInfo: [NSLocalizedDescriptionKey: "Extraction failed"])
    }
  }

  @Test("Shadow mode with consistent engines produces high agreement")
  func shadowConsistent() {
    let runner = ShadowModeRunner(engines: [
      MockConsistentExtractor(name: "EngineA"),
      MockConsistentExtractor(name: "EngineB"),
    ])

    let result = runner.runShadowMode(input: Data())
    #expect(result.report.agreementScore == 1.0)
    #expect(result.report.discrepancies.isEmpty)
    #expect(result.report.allSucceeded)
  }

  @Test("Shadow mode with character count variance detects discrepancy")
  func shadowVariance() {
    let runner = ShadowModeRunner(engines: [
      MockConsistentExtractor(name: "EngineA"),
      MockDifferentExtractor(name: "EngineB"),
    ])

    let result = runner.runShadowMode(input: Data())
    #expect(result.report.discrepancies.count >= 1)
    #expect(result.report.agreementScore < 1.0)
  }

  @Test("Shadow mode with failing engine marks as incomplete")
  func shadowFailingEngine() {
    let runner = ShadowModeRunner(engines: [
      MockConsistentExtractor(name: "Good"),
      MockFailingExtractor(name: "Bad"),
    ])

    let result = runner.runShadowMode(input: Data())
    #expect(!result.report.allSucceeded)
    #expect(result.results.count == 1) // only Good succeeded
  }

  @Test("Shadow mode with single engine needs >= 2")
  func shadowSingleEngine() {
    let runner = ShadowModeRunner(engines: [
      MockConsistentExtractor(name: "Only"),
    ])

    let result = runner.runShadowMode(input: Data())
    #expect(result.report.engineCount == 1)
  }

  @Test("Shadow mode records timing per engine")
  func shadowTiming() {
    let runner = ShadowModeRunner(engines: [
      MockConsistentExtractor(name: "EngineA"),
      MockConsistentExtractor(name: "EngineB"),
    ])

    let result = runner.runShadowMode(input: Data())
    #expect(result.report.timing["EngineA"] != nil)
    #expect(result.report.timing["EngineB"] != nil)
  }
}

// MARK: - F-008: QPDF Validator Tests

@Suite("QPDF Validator")
struct QPDFValidatorTests {

  @Test("QPDF validator reports availability")
  func qpdfAvailability() {
    let validator = QPDFValidator()
    // Just check it doesn't crash — availability depends on system
    let _ = validator.isAvailable
  }

  @Test("QPDF validator conforms to CascadeProvider")
  func qpdfCascadeConformance() {
    let validator: any CascadeProvider = QPDFValidator()
    #expect(validator.name == "QPDF")
    #expect(validator.priority == 20)
  }

  @Test("QPDF validator produces structured result on valid PDF")
  func qpdfValidPDF() throws {
    let validator = QPDFValidator()
    guard validator.isAvailable else {
      // Skip if qpdf not installed
      return
    }

    // Create a minimal valid PDF
    let pdfData = Data("%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF".utf8)
    let result = try validator.validate(input: pdfData)

    // QPDF may report errors on our minimal PDF (no xref table),
    // but it should produce a result
    #expect(!result.rawOutput.isEmpty)
  }
}

// MARK: - F-009: pdf_oxide Extractor Tests

@Suite("pdf_oxide Extractor")
struct PdfOxideExtractorTests {

  @Test("pdf_oxide extractor reports availability")
  func pdfOxideAvailability() {
    let extractor = PdfOxideExtractor()
    // Just check it doesn't crash — availability depends on installation
    let _ = extractor.isAvailable
  }

  @Test("pdf_oxide extractor conforms to CascadeProvider")
  func pdfOxideCascadeConformance() {
    let extractor: any CascadeProvider = PdfOxideExtractor()
    #expect(extractor.name == "pdf_oxide")
    #expect(extractor.priority == 30)
  }

  @Test("pdf_oxide extractor conforms to ShadowExtractor")
  func pdfOxideShadowConformance() {
    let extractor: any ShadowExtractor = PdfOxideExtractor()
    #expect(extractor.name == "pdf_oxide")
  }
}
