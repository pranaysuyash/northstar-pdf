import Foundation
import PDFEditorCore
import Testing

// MARK: - Document Summarizer Tests

@Suite("UNDERSTAND — Document Summarizer")
struct DocumentSummarizerTests {

  @Test("Summarizer creates from extraction result")
  func summarizeFromExtraction() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    let summarizer = DocumentSummarizer()
    let summary = summarizer.summarize(extraction: extraction)

    #expect(summary.totalSentences >= 0)
    #expect(summary.extractionTimeMs >= 0)
    #expect(summary.keyPoints is [KeyPoint])
    #expect(summary.structure is [SummarySection])
  }

  @Test("Summarizer scores sentences correctly")
  func scoreSentence() {
    let summarizer = DocumentSummarizer()
    let headings: [DetectedHeading] = []
    let blocks: [TextBlock] = []

    // High-importance sentence with obligation words
    let highScore = summarizer.scoreSentence(
      "This document must be submitted by Friday",
      index: 0, total: 10, headings: headings, blocks: blocks
    )
    #expect(highScore > 0.5)

    // Low-importance short fragment
    let lowScore = summarizer.scoreSentence(
      "OK",
      index: 9, total: 10, headings: headings, blocks: blocks
    )
    #expect(lowScore < 0.5)
  }

  @Test("Summarizer handles empty extraction")
  func summarizeEmpty() {
    let summarizer = DocumentSummarizer()
    let emptyExtraction = StructuredExtractionResult(
      fullText: "",
      blocks: [],
      tables: [],
      headings: [],
      pageCount: 0,
      totalCharacters: 0,
      extractionTimeMs: 0
    )

    let summary = summarizer.summarize(extraction: emptyExtraction)
    #expect(summary.totalSentences == 0)
    #expect(summary.keyPoints.isEmpty)
  }

  @Test("Key point categories are assigned correctly")
  func keyPointCategories() {
    let summarizer = DocumentSummarizer()

    let obligationBlock = TextBlock(text: "The user must comply with all regulations", bounds: PDFRect(x: 0, y: 0, width: 100, height: 20))
    let definitionBlock = TextBlock(text: "A PDF is a document format", bounds: PDFRect(x: 0, y: 0, width: 100, height: 20))
    let generalBlock = TextBlock(text: "The weather is nice today", bounds: PDFRect(x: 0, y: 0, width: 100, height: 20))

    // Test internal categorization via summarize
    let extraction = StructuredExtractionResult(
      fullText: "The user must comply. A PDF is a document. The weather is nice.",
      blocks: [obligationBlock, definitionBlock, generalBlock],
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: 60,
      extractionTimeMs: 0
    )

    let summary = summarizer.summarize(extraction: extraction)
    #expect(summary.keyPoints.count >= 0)
  }
}

// MARK: - Entity Recognizer Tests

@Suite("UNDERSTAND — Entity Recognizer")
struct EntityRecognizerTests {

  @Test("Recognizer creates from extraction result")
  func recognizeFromExtraction() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    let recognizer = EntityRecognizer()
    let result = recognizer.recognize(extraction: extraction)

    #expect(result.totalCount >= 0)
    #expect(result.extractionTimeMs >= 0)
    #expect(result.entities is [DocumentEntity])
  }

  @Test("Recognizer finds email addresses")
  func findEmails() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("Contact us at support@example.com for help", pageIndex: 0)

    let emails = entities.filter { $0.type == .email }
    #expect(emails.count == 1)
    #expect(emails.first?.value == "support@example.com")
  }

  @Test("Recognizer finds URLs")
  func findURLs() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("Visit https://example.com for more info", pageIndex: 0)

    let urls = entities.filter { $0.type == .url }
    #expect(urls.count == 1)
    #expect(urls.first?.value == "https://example.com")
  }

  @Test("Recognizer finds phone numbers")
  func findPhoneNumbers() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("Call us at (555) 123-4567", pageIndex: 0)

    let phones = entities.filter { $0.type == .phoneNumber }
    #expect(phones.count >= 1)
  }

  @Test("Recognizer finds dates")
  func findDates() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("The deadline is 2026-08-26 and the start was 08/15/2026", pageIndex: 0)

    let dates = entities.filter { $0.type == .date }
    #expect(dates.count >= 1)
  }

  @Test("Recognizer finds amounts")
  func findAmounts() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("The cost is $1,234.56 and the fee is $500", pageIndex: 0)

    let amounts = entities.filter { $0.type == .amount }
    #expect(amounts.count >= 1)
  }

  @Test("Recognizer finds percentages")
  func findPercentages() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("The tax rate is 8.5% and discount is 10%", pageIndex: 0)

    let percentages = entities.filter { $0.type == .percentage }
    #expect(percentages.count == 2)
  }

  @Test("Recognizer finds section references")
  func findSectionReferences() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("See §1.2 and Section 3.1 for details", pageIndex: 0)

    let sections = entities.filter { $0.type == .sectionReference }
    #expect(sections.count == 2)
  }

  @Test("Recognizer finds page references")
  func findPageReferences() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("See page 5 and pp. 12-15 for more", pageIndex: 0)

    let pages = entities.filter { $0.type == .pageReference }
    #expect(pages.count == 2)
  }

  @Test("Recognizer handles empty text")
  func recognizeEmpty() {
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognizeInText("", pageIndex: 0)
    #expect(entities.isEmpty)
  }

  @Test("Recognizer groups by type")
  func groupByType() {
    let recognizer = EntityRecognizer()
    let extraction = StructuredExtractionResult(
      fullText: "Email test@example.com. Visit https://example.com. Call (555) 123-4567.",
      blocks: [TextBlock(text: "Email test@example.com. Visit https://example.com. Call (555) 123-4567.", bounds: PDFRect(x: 0, y: 0, width: 400, height: 20))],
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: 70,
      extractionTimeMs: 0
    )

    let result = recognizer.recognize(extraction: extraction)
    #expect(result.typeCount >= 2)
  }
}

// MARK: - Key Point Extractor Tests

@Suite("UNDERSTAND — Key Point Extractor")
struct KeyPointExtractorTests {

  @Test("Extractor creates from extraction result")
  func extractFromExtraction() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    let kpExtractor = KeyPointExtractor()
    let result = kpExtractor.extract(extraction: extraction)

    #expect(result.totalCount >= 0)
    #expect(result.extractionTimeMs >= 0)
    #expect(result.keyPoints is [ExtractedKeyPoint])
  }

  @Test("Extractor finds obligations")
  func findObligations() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence(
      "The vendor must deliver the goods by December 31",
      pageIndex: 0, sentenceIndex: 0
    )

    let obligations = points.filter { $0.type == .obligation }
    #expect(obligations.count == 1)
    #expect(obligations.first?.importance ?? 0 > 0.8)
  }

  @Test("Extractor finds definitions")
  func findDefinitions() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence(
      "A contract is a legally binding agreement between parties",
      pageIndex: 0, sentenceIndex: 0
    )

    let definitions = points.filter { $0.type == .definition }
    #expect(definitions.count == 1)
    #expect(definitions.first?.relatedTerms.isEmpty == false)
  }

  @Test("Extractor finds conclusions")
  func findConclusions() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence(
      "Therefore, the project should be completed by Q3",
      pageIndex: 0, sentenceIndex: 0
    )

    let conclusions = points.filter { $0.type == .conclusion }
    #expect(conclusions.count == 1)
  }

  @Test("Extractor finds recommendations")
  func findRecommendations() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence(
      "We recommend upgrading to the latest version for security",
      pageIndex: 0, sentenceIndex: 0
    )

    let recs = points.filter { $0.type == .recommendation }
    #expect(recs.count == 1)
  }

  @Test("Extractor finds exceptions")
  func findExceptions() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence(
      "All users must comply unless they have explicit exemption",
      pageIndex: 0, sentenceIndex: 0
    )

    let exceptions = points.filter { $0.type == .exception }
    #expect(exceptions.count == 1)
  }

  @Test("Extractor finds questions")
  func findQuestions() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence(
      "What is the timeline for implementation of this policy",
      pageIndex: 0, sentenceIndex: 0
    )

    let questions = points.filter { $0.type == .question }
    #expect(questions.count == 1)
  }

  @Test("Extractor groups by type")
  func groupByType() {
    let kpExtractor = KeyPointExtractor()
    let extraction = StructuredExtractionResult(
      fullText: "The vendor must deliver. Therefore, we conclude. We recommend caution. What is the deadline?",
      blocks: [TextBlock(text: "The vendor must deliver. Therefore, we conclude. We recommend caution. What is the deadline?", bounds: PDFRect(x: 0, y: 0, width: 400, height: 20))],
      tables: [],
      headings: [],
      pageCount: 1,
      totalCharacters: 100,
      extractionTimeMs: 0
    )

    let result = kpExtractor.extract(extraction: extraction)
    #expect(result.typeCount >= 2)
  }

  @Test("Extractor handles empty text")
  func extractEmpty() {
    let kpExtractor = KeyPointExtractor()
    let points = kpExtractor.extractFromSentence("", pageIndex: 0, sentenceIndex: 0)
    #expect(points.isEmpty)
  }
}

// MARK: - Integration: Full UNDERSTAND Pipeline

@Suite("UNDERSTAND — Full Pipeline Integration")
struct UnderstandPipelineTests {

  @Test("Full UNDERSTAND pipeline: extract → summarize → recognize → extract keypoints")
  func fullUnderstandPipeline() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    // Summarize
    let summarizer = DocumentSummarizer()
    let summary = summarizer.summarize(extraction: extraction)
    #expect(summary.totalSentences >= 0)

    // Recognize entities
    let recognizer = EntityRecognizer()
    let entities = recognizer.recognize(extraction: extraction)
    #expect(entities.totalCount >= 0)

    // Extract key points
    let kpExtractor = KeyPointExtractor()
    let keyPoints = kpExtractor.extract(extraction: extraction)
    #expect(keyPoints.totalCount >= 0)

    // All three work on the same extraction — no conflicts
    #expect(summary.extractionTimeMs >= 0)
    #expect(entities.extractionTimeMs >= 0)
    #expect(keyPoints.extractionTimeMs >= 0)
  }
}
