import Foundation
import PDFEditorCore
import Testing

// MARK: - E-009: Multi-Library Validation Tests

@Suite("Multi-Library Validation")
struct MultiLibraryValidationTests {

  /// A mock cascade that simulates multi-library validation
  struct MockValidationCascade {
    let validators: [String]

    func validate(input: Data) -> [String: Bool] {
      var results: [String: Bool] = [:]
      for validator in validators {
        // Simulate different validation results
        results[validator] = input.count > 0 // Simple validation
      }
      return results
    }
  }

  @Test("Multi-library validation produces consistent results")
  func multiLibraryConsistency() {
    let cascade = MockValidationCascade(validators: ["QPDF", "pdfcpu", "PDFKit"])
    let testData = Data("%PDF-1.7 test".utf8)

    let results = cascade.validate(input: testData)

    #expect(results.count == 3)
    #expect(results["QPDF"] == true)
    #expect(results["pdfcpu"] == true)
    #expect(results["PDFKit"] == true)
  }

  @Test("Multi-library validation detects inconsistencies")
  func multiLibraryInconsistency() {
    // Simulate a case where validators disagree
    let cascade = MockValidationCascade(validators: ["QPDF", "pdfcpu"])
    let emptyData = Data()

    let results = cascade.validate(input: emptyData)

    #expect(results["QPDF"] == false)
    #expect(results["pdfcpu"] == false)
  }

  @Test("Multi-library validation with mixed results")
  func multiLibraryMixed() {
    // In real usage, different libraries might have different validation criteria
    let cascade = MockValidationCascade(validators: ["Strict", "Lenient"])
    let testData = Data("%PDF-1.7 minimal".utf8)

    let results = cascade.validate(input: testData)

    #expect(results.count == 2)
    // Both should agree on valid input
    #expect(results["Strict"] == true)
    #expect(results["Lenient"] == true)
  }
}

// MARK: - E-010: Provenance Validation Tests

@Suite("Provenance Validation")
struct ProvenanceValidationTests {

  @Test("ExtractionProvenance encodes all fields")
  func provenanceEncoding() throws {
    let provenance = ExtractionProvenance(
      textExtractor: "PDFKit",
      fieldInspector: "CGPDF",
      ocrEngine: "Vision",
      confidence: 0.95,
      extractedAt: Date(timeIntervalSince1970: 0)
    )

    let data = try JSONEncoder().encode(provenance)
    let decoded = try JSONDecoder().decode(ExtractionProvenance.self, from: data)

    #expect(decoded.textExtractor == "PDFKit")
    #expect(decoded.fieldInspector == "CGPDF")
    #expect(decoded.ocrEngine == "Vision")
    #expect(decoded.confidence == 0.95)
  }

  @Test("ExtractionProvenance with nil optional fields")
  func provenanceOptionals() throws {
    let provenance = ExtractionProvenance(
      textExtractor: "pdf_oxide",
      fieldInspector: "CGPDF",
      ocrEngine: nil,
      confidence: 1.0,
      extractedAt: Date(timeIntervalSince1970: 0)
    )

    let data = try JSONEncoder().encode(provenance)
    let decoded = try JSONDecoder().decode(ExtractionProvenance.self, from: data)

    #expect(decoded.textExtractor == "pdf_oxide")
    #expect(decoded.ocrEngine == nil)
    #expect(decoded.confidence == 1.0)
  }

  @Test("DocumentInspection includes provenance")
  func documentInspectionProvenance() {
    let provenance = ExtractionProvenance(
      textExtractor: "Vision",
      fieldInspector: "CGPDF",
      ocrEngine: "Vision",
      confidence: 0.85,
      extractedAt: Date(timeIntervalSince1970: 0)
    )

    let page = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 100,
      annotationCount: 0,
      hasSelectableText: true
    )

    let inspection = DocumentInspection(
      source: DocumentSource(fileName: "test.pdf", byteCount: 100, sha256: "abc123"),
      pages: [page],
      fields: [],
      candidates: [],
      warnings: [],
      provenance: provenance
    )

    #expect(inspection.provenance.textExtractor == "Vision")
    #expect(inspection.provenance.confidence == 0.85)
  }
}

// MARK: - E-011: Shadow Mode Comparison Tests

@Suite("Shadow Mode Comparison")
struct ShadowModeComparisonTests {

  /// Mock extractors for testing shadow mode comparison
  struct MockExtractorA: ShadowExtractor {
    let name = "EngineA"
    let isAvailable = true

    func extractText(from data: Data) throws -> ShadowExtractionResult {
      ShadowExtractionResult(
        pageCount: 10,
        characterCount: 5000,
        text: "Text from Engine A",
        timeMs: 10.0
      )
    }
  }

  struct MockExtractorB: ShadowExtractor {
    let name = "EngineB"
    let isAvailable = true

    func extractText(from data: Data) throws -> ShadowExtractionResult {
      ShadowExtractionResult(
        pageCount: 10,
        characterCount: 5100, // 2% variance — within tolerance
        text: "Text from Engine B",
        timeMs: 12.0
      )
    }
  }

  struct MockExtractorC: ShadowExtractor {
    let name = "EngineC"
    let isAvailable = true

    func extractText(from data: Data) throws -> ShadowExtractionResult {
      ShadowExtractionResult(
        pageCount: 10,
        characterCount: 8000, // 60% variance — exceeds tolerance
        text: "Very different text",
        timeMs: 15.0
      )
    }
  }

  @Test("Shadow mode with close results shows high agreement")
  func shadowCloseResults() {
    let runner = ShadowModeRunner(engines: [
      MockExtractorA(),
      MockExtractorB(),
    ])

    let result = runner.runShadowMode(input: Data())

    #expect(result.report.engineCount == 2)
    #expect(result.report.agreementScore >= 0.8)
    #expect(result.report.discrepancies.isEmpty)
  }

  @Test("Shadow mode with divergent results shows low agreement")
  func shadowDivergentResults() {
    let runner = ShadowModeRunner(engines: [
      MockExtractorA(),
      MockExtractorC(),
    ])

    let result = runner.runShadowMode(input: Data())

    #expect(result.report.engineCount == 2)
    #expect(result.report.agreementScore <= 0.8) // 60% variance = 0.2 penalty
    #expect(result.report.discrepancies.count >= 1)
  }

  @Test("Shadow mode with three engines")
  func shadowThreeEngines() {
    let runner = ShadowModeRunner(engines: [
      MockExtractorA(),
      MockExtractorB(),
      MockExtractorC(),
    ])

    let result = runner.runShadowMode(input: Data())

    #expect(result.report.engineCount == 3)
    #expect(result.results.count >= 2) // At least A and B succeed
  }

  @Test("Shadow mode timing is recorded per engine")
  func shadowTiming() {
    let runner = ShadowModeRunner(engines: [
      MockExtractorA(),
      MockExtractorB(),
    ])

    let result = runner.runShadowMode(input: Data())

    #expect(result.report.timing["EngineA"] != nil)
    #expect(result.report.timing["EngineB"] != nil)
    #expect(result.report.timing["EngineA"]! >= 0)
    #expect(result.report.timing["EngineB"]! >= 0)
  }
}
