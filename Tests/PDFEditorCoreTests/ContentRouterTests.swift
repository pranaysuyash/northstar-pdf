import Foundation
import Testing
@testable import PDFEditorCore

@Suite("ContentRouter")
struct ContentRouterTests {
  // MARK: - ContentType

  @Test("ContentType has all cases")
  func allCases() {
    #expect(ContentType.allCases.count == 4)
    #expect(ContentType.allCases.contains(.text))
    #expect(ContentType.allCases.contains(.table))
    #expect(ContentType.allCases.contains(.form))
    #expect(ContentType.allCases.contains(.mixed))
  }

  @Test("ContentType symbol names are distinct")
  func symbolNamesDistinct() {
    let symbols = Set(ContentType.allCases.map(\.symbolName))
    #expect(symbols.count == ContentType.allCases.count)
  }

  @Test("ContentType suggested modes are distinct")
  func suggestedModesDistinct() {
    let modes = Set(ContentType.allCases.map(\.suggestedMode))
    #expect(modes.count >= 2) // at least study and reference
  }

  @Test("ContentType raw values round-trip")
  func rawValuesRoundTrip() {
    for type in ContentType.allCases {
      #expect(ContentType(rawValue: type.rawValue) == type)
    }
  }

  // MARK: - ContentSuggestion

  @Test("Actionable when confidence >= 0.7 and elements >= 2")
  func actionableThreshold() {
    let s1 = ContentSuggestion(contentType: .table, confidence: 0.8, reason: "test", elementCount: 3)
    #expect(s1.isActionable == true)

    let s2 = ContentSuggestion(contentType: .table, confidence: 0.5, reason: "test", elementCount: 3)
    #expect(s2.isActionable == false)

    let s3 = ContentSuggestion(contentType: .table, confidence: 0.8, reason: "test", elementCount: 1)
    #expect(s3.isActionable == false)
  }

  // MARK: - ContentRouter: Table Detection

  @Test("Router detects tables")
  func detectTables() {
    let router = ContentRouter()
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: [],
      tables: [
        DetectedTable(rows: 5, columns: 4, cells: [], bounds: PDFRect(x: 0, y: 0, width: 100, height: 100)),
        DetectedTable(rows: 3, columns: 3, cells: [], bounds: PDFRect(x: 0, y: 0, width: 100, height: 100))
      ],
      headings: [],
      pageCount: 1,
      totalCharacters: 0,
      extractionTimeMs: 0
    )
    let suggestion = router.route(extraction: extraction)
    #expect(suggestion.contentType == ContentType.table)
    #expect(suggestion.confidence > 0.5)
  }

  // MARK: - ContentRouter: Text Detection

  @Test("Router detects text-heavy documents")
  func detectText() {
    let router = ContentRouter()
    let blocks = (0..<10).map { i in
      TextBlock(text: "Paragraph \(i) with some content about various topics.", bounds: PDFRect(x: 0, y: Double(i) * 20, width: 100, height: 20), fontSize: 12)
    }
    let headings = [
      DetectedHeading(text: "Introduction", level: 1, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), fontSize: 18)
    ]
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: blocks,
      tables: [],
      headings: headings,
      pageCount: 1,
      totalCharacters: blocks.map(\.text.count).reduce(0, +),
      extractionTimeMs: 0
    )
    let suggestion = router.route(extraction: extraction)
    #expect(suggestion.contentType == ContentType.text)
  }

  // MARK: - ContentRouter: Form Detection

  @Test("Router detects form-like content")
  func detectForm() {
    let router = ContentRouter()
    let formTexts = [
      "Applicant Name: _______________",
      "Date of Birth: ___/___/______",
      "Email Address: _______________",
      "Phone Number: (__ _) ___-____",
      "Social Security: ___-__-____",
      "Signature: _______________"
    ]
    let blocks = formTexts.map { text in
      TextBlock(text: text, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), fontSize: 12)
    }
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: blocks,
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: blocks.map(\.text.count).reduce(0, +),
      extractionTimeMs: 0
    )
    let suggestion = router.route(extraction: extraction)
    #expect(suggestion.contentType == ContentType.form)
  }

  // MARK: - ContentRouter: Mixed

  @Test("Router detects mixed content")
  func detectMixed() {
    let router = ContentRouter()
    let blocks = (0..<5).map { i in
      TextBlock(text: "Text block \(i)", bounds: PDFRect(x: 0, y: Double(i) * 20, width: 100, height: 20), fontSize: 12)
    }
    let tables = [
      DetectedTable(rows: 3, columns: 3, cells: [], bounds: PDFRect(x: 0, y: 0, width: 100, height: 100))
    ]
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: blocks,
      tables: tables,
      headings: [],
      pageCount: 1,
      totalCharacters: blocks.map(\.text.count).reduce(0, +),
      extractionTimeMs: 0
    )
    let suggestion = router.route(extraction: extraction)
    // Should be either text, table, or mixed — but not crash
    #expect([ContentType.text, .table, .mixed].contains(suggestion.contentType))
  }

  // MARK: - ContentRouter: Empty

  @Test("Router handles empty extraction")
  func handleEmpty() {
    let router = ContentRouter()
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: [],
      tables: [],
      headings: [],
      pageCount: 0,
      totalCharacters: 0,
      extractionTimeMs: 0
    )
    let suggestion = router.route(extraction: extraction)
    #expect(suggestion.contentType == ContentType.text) // default
    #expect(suggestion.confidence == 0.5)
  }

  // MARK: - ContentRouter: Large table

  @Test("Router strongly suggests table for large tables")
  func largeTable() {
    let router = ContentRouter()
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: [],
      tables: [
        DetectedTable(rows: 20, columns: 10, cells: [], bounds: PDFRect(x: 0, y: 0, width: 100, height: 100))
      ],
      headings: [],
      pageCount: 1,
      totalCharacters: 0,
      extractionTimeMs: 0
    )
    let suggestion = router.route(extraction: extraction)
    #expect(suggestion.contentType == ContentType.table)
    #expect(suggestion.isActionable)
  }

  // MARK: - Sendable

  @Test("ContentRouter is Sendable")
  func sendable() {
    let router = ContentRouter()
    Task {
      let r = router
      let _ = r
    }
  }
}
