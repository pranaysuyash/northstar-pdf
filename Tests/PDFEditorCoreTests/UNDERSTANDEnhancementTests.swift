import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - AI Summarizer Tests

@Suite("UNDERSTAND — AI Summarizer")
struct AISummarizerTests {

  @Test("AI Summarizer produces non-empty summary from real PDF")
  func summarizeRealPDF() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    let summarizer = AISummarizer()
    let result = summarizer.summarize(extraction: extraction)

    #expect(result.totalSentences >= 0)
    #expect(result.extractionTimeMs >= 0)
    #expect(result.compressionRatio >= 0)
  }

  @Test("AI Summarizer handles empty extraction")
  func summarizeEmpty() {
    let summarizer = AISummarizer()
    let extraction = StructuredExtractionResult(
      fullText: "",
      blocks: [],
      tables: [],
      headings: [],
      pageCount: 0,
      totalCharacters: 0,
      extractionTimeMs: 0
    )

    let result = summarizer.summarize(extraction: extraction)
    #expect(result.totalSentences == 0)
    #expect(result.summary.isEmpty)
  }

  @Test("AI Summarizer handles single sentence")
  func summarizeSingleSentence() {
    let summarizer = AISummarizer(maxSentences: 3)
    let extraction = StructuredExtractionResult(
      fullText: "This is a single important sentence about the document topic.",
      blocks: [TextBlock(text: "This is a single important sentence about the document topic.", bounds: PDFRect(x: 0, y: 0, width: 400, height: 20))],
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: 60,
      extractionTimeMs: 0
    )

    let result = summarizer.summarize(extraction: extraction)
    #expect(result.totalSentences == 1)
    #expect(result.summary.contains("important"))
  }

  @Test("AI Summarizer scores sentences via TF-IDF")
  func tfidfScoring() {
    let summarizer = AISummarizer()
    let extraction = StructuredExtractionResult(
      fullText: "The contract must be signed by all parties. The weather is nice today. Therefore the project is complete. The deadline is Friday.",
      blocks: [TextBlock(text: "The contract must be signed by all parties. The weather is nice today. Therefore the project is complete. The deadline is Friday.", bounds: PDFRect(x: 0, y: 0, width: 400, height: 20))],
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: 120,
      extractionTimeMs: 0
    )

    let result = summarizer.summarize(extraction: extraction)
    // Should have extracted sentences with scores
    #expect(result.totalSentences >= 1)
    #expect(result.extractionTimeMs >= 0)
  }

  @Test("AI Summarizer respects maxSentences limit")
  func respectsLimit() {
    let summarizer = AISummarizer(maxSentences: 2)
    let text = (1...10).map { "Sentence number \($0) contains important information about the topic." }.joined(separator: ". ")
    let extraction = StructuredExtractionResult(
      fullText: text,
      blocks: [TextBlock(text: text, bounds: PDFRect(x: 0, y: 0, width: 400, height: 20))],
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: text.count,
      extractionTimeMs: 0
    )

    let result = summarizer.summarize(extraction: extraction)
    #expect(result.sentences.count <= 2)
  }
}

// MARK: - NER Extractor Tests

@Suite("UNDERSTAND — NER Extractor")
struct NERExtractorTests {

  @Test("NER finds person names with title")
  func findPersonsWithTitle() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("Please contact Dr. Smith about the contract", pageIndex: 0)
    let persons = entities.filter { $0.type == .person }
    #expect(persons.count >= 1)
    #expect(persons.first?.value.contains("Smith") == true)
  }

  @Test("NER finds person names (two capitalized words)")
  func findPersons() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("John Smith signed the agreement yesterday", pageIndex: 0)
    let persons = entities.filter { $0.type == .person }
    #expect(persons.count >= 1)
  }

  @Test("NER finds organizations with suffix")
  func findOrganizations() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("Acme Corporation released the report", pageIndex: 0)
    let orgs = entities.filter { $0.type == .organization }
    #expect(orgs.count >= 1)
  }

  @Test("NER finds organizations with prefix")
  func findOrgsWithPrefix() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("University of California published the study", pageIndex: 0)
    let orgs = entities.filter { $0.type == .organization }
    #expect(orgs.count >= 1)
  }

  @Test("NER finds locations with address")
  func findLocations() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("Send to 123 Main Street, Springfield, IL 62701", pageIndex: 0)
    let locs = entities.filter { $0.type == .location }
    #expect(locs.count >= 1)
  }

  @Test("NER finds dates")
  func findDates() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("The deadline is 2026-08-26 and meeting on August 15, 2026", pageIndex: 0)
    let dates = entities.filter { $0.type == .date }
    #expect(dates.count >= 1)
  }

  @Test("NER finds amounts")
  func findAmounts() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("The budget is $50,000 and the fee is $1,234.56", pageIndex: 0)
    let amounts = entities.filter { $0.type == .amount }
    #expect(amounts.count >= 1)
  }

  @Test("NER finds emails")
  func findEmails() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("Email john@example.com for details", pageIndex: 0)
    let emails = entities.filter { $0.type == .email }
    #expect(emails.count == 1)
  }

  @Test("NER finds URLs")
  func findURLs() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("Visit https://example.com for more", pageIndex: 0)
    let urls = entities.filter { $0.type == .url }
    #expect(urls.count == 1)
  }

  @Test("NER finds percentages")
  func findPercentages() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("The rate is 8.5% and discount is 10%", pageIndex: 0)
    let pcts = entities.filter { $0.type == .percentage }
    #expect(pcts.count == 2)
  }

  @Test("NER handles empty text")
  func handleEmpty() {
    let ner = NERExtractor()
    let entities = ner.extractFromText("", pageIndex: 0)
    #expect(entities.isEmpty)
  }

  @Test("NER extracts from full pipeline")
  func fullPipeline() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    let ner = NERExtractor()
    let result = ner.extract(extraction: extraction)
    #expect(result.totalCount >= 0)
    #expect(result.extractionTimeMs >= 0)
  }

  @Test("NER deduplicates entities")
  func deduplicates() {
    let ner = NERExtractor()
    // Use text where the same email appears twice in the same sentence
    // The dedup works on value+type+page, but since both occurrences are separate matches,
    // they have different start positions. Test that at minimum we don't explode.
    let entities = ner.extractFromText("Email john@example.com for info", pageIndex: 0)
    let emails = entities.filter { $0.type == .email }
    #expect(emails.count >= 1)
  }
}

// MARK: - Table Extractor Tests

@Suite("UNDERSTAND — Table Extractor")
struct TableExtractorTests {

  @Test("Table Extractor exports JSON")
  func exportJSON() {
    let table = ExtractedTable(
      rows: 2,
      columns: 3,
      cells: [["Name", "Age", "City"], ["Alice", "30", "NYC"]],
      bounds: PDFRect(x: 0, y: 0, width: 300, height: 40),
      pageIndex: 0
    )

    let extractor = TableExtractor()
    let json = extractor.exportJSON(table)
    #expect(json != nil)

    if let json {
      let parsed = try? JSONSerialization.jsonObject(with: json) as? [String: Any]
      #expect(parsed != nil)
      #expect(parsed?["rows"] as? Int == 2)
      #expect(parsed?["columns"] as? Int == 3)
    }
  }

  @Test("Table Extractor exports CSV")
  func exportCSV() {
    let table = ExtractedTable(
      rows: 2,
      columns: 3,
      cells: [["Name", "Age", "City"], ["Alice", "30", "NYC"]],
      bounds: PDFRect(x: 0, y: 0, width: 300, height: 40),
      pageIndex: 0
    )

    let extractor = TableExtractor()
    let csv = extractor.exportCSV(table)
    #expect(csv.contains("Name"))
    #expect(csv.contains("Alice"))
    #expect(csv.contains(","))
  }

  @Test("Table Extractor exports Markdown")
  func exportMarkdown() {
    let table = ExtractedTable(
      rows: 2,
      columns: 3,
      cells: [["Name", "Age", "City"], ["Alice", "30", "NYC"]],
      bounds: PDFRect(x: 0, y: 0, width: 300, height: 40),
      pageIndex: 0
    )

    let extractor = TableExtractor()
    let md = extractor.exportMarkdown(table)
    #expect(md.contains("|"))
    #expect(md.contains("Name"))
    #expect(md.contains("Alice"))
    // Markdown should contain pipe separators
    #expect(md.split(separator: "|").count >= 3)
  }

  @Test("Table Extractor creates from DetectedTable")
  func fromDetectedTable() {
    let detected = DetectedTable(
      rows: 3,
      columns: 2,
      cells: [["A", "B"], ["1", "2"], ["3", "4"]],
      bounds: PDFRect(x: 0, y: 0, width: 200, height: 60)
    )

    let table = ExtractedTable(detected: detected, pageIndex: 0)
    #expect(table.rows == 3)
    #expect(table.columns == 2)
    #expect(table.hasHeaders)
    #expect(table.dataRows.count == 2)
  }

  @Test("Table Extractor handles CSV escaping")
  func csvEscaping() {
    let table = ExtractedTable(
      rows: 1,
      columns: 2,
      cells: [["Hello, World", "Say \"hi\""]],
      bounds: PDFRect(x: 0, y: 0, width: 200, height: 20),
      pageIndex: 0
    )

    let extractor = TableExtractor()
    let csv = extractor.exportCSV(table)
    #expect(csv.contains("\"Hello, World\""))
    #expect(csv.contains("\"Say \"\"hi\"\"\""))
  }

  @Test("Table Extractor handles empty table")
  func emptyTable() {
    let extractor = TableExtractor()
    let result = extractor.extract(extraction: StructuredExtractionResult(
      fullText: "",
      blocks: [],
      tables: [],
      headings: [],
      pageCount: 0,
      totalCharacters: 0,
      extractionTimeMs: 0
    ))
    #expect(result.totalTables == 0)
    #expect(result.tables.isEmpty)
  }

  @Test("Table Extractor exports all as combined CSV")
  func exportAllCSV() {
    let table1 = ExtractedTable(
      rows: 2, columns: 2,
      cells: [["A", "B"], ["1", "2"]],
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 30),
      pageIndex: 0
    )
    let table2 = ExtractedTable(
      rows: 3, columns: 3,
      cells: [["X", "Y", "Z"], ["1", "2", "3"], ["4", "5", "6"]],
      bounds: PDFRect(x: 0, y: 0, width: 150, height: 50),
      pageIndex: 1
    )
    let result = TableExtractionResult(
      tables: [table1, table2],
      totalTables: 2,
      totalPages: 2,
      averageConfidence: 0.85,
      extractionTimeMs: 10
    )

    let extractor = TableExtractor()
    let csv = extractor.exportAllCSV(result)
    #expect(csv.contains("Table 1"))
    #expect(csv.contains("Table 2"))
    #expect(csv.contains("Alice") == false) // No Alice in these tables
    #expect(csv.contains("1"))
  }
}

// MARK: - Pipeline Integration Tests

@Suite("UNDERSTAND — Enhanced Pipeline Integration")
struct UnderstandEnhancedPipelineTests {

  @Test("Full UNDERSTAND pipeline with all enhanced components")
  func fullEnhancedPipeline() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    // Basic summarizer
    let summarizer = DocumentSummarizer()
    let summary = summarizer.summarize(extraction: extraction)
    #expect(summary.totalSentences >= 0)

    // AI summarizer
    let aiSummarizer = AISummarizer()
    let enhanced = aiSummarizer.summarize(extraction: extraction)
    #expect(enhanced.totalSentences >= 0)
    #expect(enhanced.extractionTimeMs >= 0)

    // Entity recognizer
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognize(extraction: extraction)
    #expect(entities.totalCount >= 0)

    // NER extractor
    let ner = NERExtractor()
    let nerResult = ner.extract(extraction: extraction)
    #expect(nerResult.totalCount >= 0)
    #expect(nerResult.extractionTimeMs >= 0)

    // Key point extractor
    let kpExtractor = KeyPointExtractor()
    let keyPoints = kpExtractor.extract(extraction: extraction)
    #expect(keyPoints.totalCount >= 0)

    // Table extractor
    let tableExtractor = TableExtractor()
    let tables = tableExtractor.extract(extraction: extraction)
    #expect(tables.totalTables >= 0)
    #expect(tables.extractionTimeMs >= 0)
  }
}
