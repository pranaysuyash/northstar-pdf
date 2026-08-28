import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Table Exporter

@Suite("TableExporter")
struct TableExporterTests {

  private func makeTable() -> DetectedTable {
    DetectedTable(
      rows: 3, columns: 2,
      cells: [
        ["Name", "Score"],
        ["Alice", "95"],
        ["Bob", "87"]
      ],
      bounds: PDFRect(x: 0, y: 0, width: 400, height: 200),
      confidence: 0.9
    )
  }

  @Test("JSON export produces valid JSON")
  func jsonExport() {
    let result = TableExporter.export(table: makeTable(), format: .json)
    #expect(result.format == .json)
    #expect(result.rowCount == 3)
    #expect(result.columnCount == 2)
    let json = try? JSONSerialization.jsonObject(with: result.data) as? [String: Any]
    #expect(json != nil)
    #expect(json?["rows"] as? Int == 3)
  }

  @Test("CSV export produces comma-separated values")
  func csvExport() {
    let result = TableExporter.export(table: makeTable(), format: .csv)
    let csv = String(data: result.data, encoding: .utf8) ?? ""
    #expect(csv.contains("Name,Score"))
    #expect(csv.contains("Alice,95"))
    #expect(csv.contains("Bob,87"))
  }

  @Test("Markdown export produces table syntax")
  func markdownExport() {
    let result = TableExporter.export(table: makeTable(), format: .markdown)
    let md = String(data: result.data, encoding: .utf8) ?? ""
    #expect(md.contains("| Name | Score |"))
    #expect(md.contains("| --- | --- |"))
    #expect(md.contains("| Alice | 95 |"))
  }

  @Test("Export all tables")
  func exportAll() {
    let tables = [makeTable(), makeTable()]
    let results = TableExporter.exportAll(tables: tables, format: .csv)
    #expect(results.count == 2)
    #expect(results[0].suggestedFileName.contains("table_1"))
    #expect(results[1].suggestedFileName.contains("table_2"))
  }

  @Test("CSV escapes quoted cells")
  func csvEscaping() {
    let table = DetectedTable(
      rows: 1, columns: 1,
      cells: [["Hello, \"world\""]],
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 100),
      confidence: 0.9
    )
    let result = TableExporter.export(table: table, format: .csv)
    let csv = String(data: result.data, encoding: .utf8) ?? ""
    #expect(csv.contains("\"Hello, \"\"world\"\"\""))
  }
}

// MARK: - Form Validator

@Suite("FormValidator")
struct FormValidatorTests {

  @Test("Required field — empty fails")
  func requiredEmpty() {
    let results = FormValidator.validate(fieldName: "Name", value: "", rules: [.required])
    #expect(results.count == 1)
    #expect(!results[0].isValid)
    #expect(results[0].message != nil)
  }

  @Test("Required field — non-empty passes")
  func requiredNonEmpty() {
    let results = FormValidator.validate(fieldName: "Name", value: "Alice", rules: [.required])
    #expect(results.filter { !$0.isValid }.isEmpty)
  }

  @Test("Email validation — valid passes")
  func emailValid() {
    let results = FormValidator.validate(fieldName: "Email", value: "alice@example.com", rules: [.email])
    #expect(results.filter { !$0.isValid }.isEmpty)
  }

  @Test("Email validation — invalid fails")
  func emailInvalid() {
    let results = FormValidator.validate(fieldName: "Email", value: "not-an-email", rules: [.email])
    #expect(!results[0].isValid)
  }

  @Test("Number range — within range passes")
  func numberRangeValid() {
    let results = FormValidator.validate(fieldName: "Age", value: "25", rules: [.numberRange(min: 0, max: 150)])
    #expect(results.filter { !$0.isValid }.isEmpty)
  }

  @Test("Number range — outside range fails")
  func numberRangeInvalid() {
    let results = FormValidator.validate(fieldName: "Age", value: "200", rules: [.numberRange(min: 0, max: 150)])
    #expect(!results[0].isValid)
  }

  @Test("Min length — too short fails")
  func minLengthFail() {
    let results = FormValidator.validate(fieldName: "Password", value: "ab", rules: [.minLength(8)])
    #expect(!results[0].isValid)
  }

  @Test("Min length — long enough passes")
  func minLengthPass() {
    let results = FormValidator.validate(fieldName: "Password", value: "abcdefgh", rules: [.minLength(8)])
    #expect(results.filter { !$0.isValid }.isEmpty)
  }

  @Test("One of — valid value passes")
  func oneOfValid() {
    let results = FormValidator.validate(fieldName: "Country", value: "US", rules: [.oneOf(["US", "UK", "CA"])])
    #expect(results.filter { !$0.isValid }.isEmpty)
  }

  @Test("One of — invalid value fails")
  func oneOfInvalid() {
    let results = FormValidator.validate(fieldName: "Country", value: "XX", rules: [.oneOf(["US", "UK", "CA"])])
    #expect(!results[0].isValid)
  }

  @Test("Multiple rules on one field")
  func multipleRules() {
    let results = FormValidator.validate(
      fieldName: "Email", value: "",
      rules: [.required, .email]
    )
    #expect(results.count == 2)
    #expect(!results[0].isValid) // required fails
    #expect(!results[1].isValid) // email fails on empty
  }

  @Test("Form validation report")
  func formReport() {
    let report = FormValidator.validateForm(fields: [
      ("Name", "Alice", [.required]),
      ("Email", "bad", [.required, .email]),
      ("Age", "25", [.numberRange(min: 0, max: 150)])
    ])
    #expect(report.totalCount == 4) // 1 + 2 + 1
    #expect(report.invalidCount == 1) // only email fails
    #expect(report.validCount == 3)
    #expect(!report.allValid)
  }

  @Test("All valid report")
  func allValidReport() {
    let report = FormValidator.validateForm(fields: [
      ("Name", "Alice", [.required]),
      ("Email", "alice@test.com", [.email])
    ])
    #expect(report.allValid)
    #expect(report.summary.contains("All"))
  }

  @Test("Phone validation")
  func phoneValidation() {
    #expect(FormValidator.validate(fieldName: "Phone", value: "+1 (555) 123-4567", rules: [.phone]).filter { !$0.isValid }.isEmpty)
    #expect(!FormValidator.validate(fieldName: "Phone", value: "abc", rules: [.phone])[0].isValid)
  }

  @Test("URL validation")
  func urlValidation() {
    #expect(FormValidator.validate(fieldName: "URL", value: "https://example.com", rules: [.url]).filter { !$0.isValid }.isEmpty)
    #expect(!FormValidator.validate(fieldName: "URL", value: "not a url", rules: [.url])[0].isValid)
  }
}

// MARK: - Text Exporter

@Suite("TextExporter")
struct TextExporterTests {

  private func makeExtraction() -> StructuredExtractionResult {
    StructuredExtractionResult(
      fullText: "Hello world. This is a test document.",
      blocks: [
        TextBlock(text: "Hello world.", bounds: PDFRect(x: 0, y: 0, width: 100, height: 20)),
        TextBlock(text: "This is a test document.", bounds: PDFRect(x: 0, y: 30, width: 100, height: 20))
      ],
      tables: [
        DetectedTable(rows: 2, columns: 2, cells: [["A", "B"], ["1", "2"]], bounds: PDFRect(x: 0, y: 60, width: 100, height: 40), confidence: 0.9)
      ],
      headings: [
        DetectedHeading(text: "Introduction", level: 1, bounds: PDFRect(x: 0, y: 0, width: 100, height: 20), fontSize: 16)
      ],
      pageCount: 1,
      totalCharacters: 35,
      extractionTimeMs: 10.0
    )
  }

  @Test("JSON export produces valid JSON")
  func jsonExport() {
    let result = TextExporter.export(extraction: makeExtraction(), format: .json)
    let json = try? JSONSerialization.jsonObject(with: result.data) as? [String: Any]
    #expect(json != nil)
    #expect(json?["blockCount"] as? Int == 2)
    #expect(json?["tableCount"] as? Int == 1)
  }

  @Test("CSV export includes type and text")
  func csvExport() {
    let result = TextExporter.export(extraction: makeExtraction(), format: .csv)
    let csv = String(data: result.data, encoding: .utf8) ?? ""
    #expect(csv.contains("Type,Text"))
    #expect(csv.contains("Hello world."))
    #expect(csv.contains("Introduction"))
  }

  @Test("Markdown export includes headings and tables")
  func markdownExport() {
    let result = TextExporter.export(extraction: makeExtraction(), format: .markdown)
    let md = String(data: result.data, encoding: .utf8) ?? ""
    #expect(md.contains("# Extracted Text"))
    #expect(md.contains("Hello world."))
    #expect(md.contains("## Tables"))
    #expect(md.contains("| A | B |"))
  }

  @Test("Plain text export is readable")
  func plainTextExport() {
    let result = TextExporter.export(extraction: makeExtraction(), format: .plainText)
    let text = String(data: result.data, encoding: .utf8) ?? ""
    #expect(text.contains("Hello world."))
    #expect(text.contains("This is a test document."))
  }

  @Test("Export result metadata is correct")
  func exportMetadata() {
    let result = TextExporter.export(extraction: makeExtraction(), format: .json, fileName: "test")
    #expect(result.blockCount == 2)
    #expect(result.pageCount > 0)
    #expect(result.suggestedFileName == "test.json")
  }

  @Test("Empty extraction exports cleanly")
  func emptyExtraction() {
    let extraction = StructuredExtractionResult(
      fullText: "", blocks: [], tables: [], headings: [],
      pageCount: 0, totalCharacters: 0, extractionTimeMs: 0
    )
    let result = TextExporter.export(extraction: extraction, format: .json)
    #expect(result.blockCount == 0)
  }
}
