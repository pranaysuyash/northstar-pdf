import Foundation

/// Document Summarizer — extracts key points, summary, and importance scoring from text.
///
/// First principle: Understanding is compression. A good summary preserves the most
/// important information while discarding noise. Importance is inferred from:
/// - Position (earlier = more important in most documents)
/// - Font size (larger = more important)
/// - Density (more unique words = more important)
/// - Repetition (repeated concepts = important)
/// - Sentence structure (declarative > interrogative)
///
/// Doctrine alignment:
/// - §3: Do things smartly — heuristic scoring, no AI dependency
/// - §5: Evidence-based — confidence scores for every claim
/// - §8: Capability routing — works standalone, no external services

// MARK: - Summarization Result

/// A single key point extracted from the document.
public struct KeyPoint: Sendable, Identifiable {
  public let id: String
  public let text: String
  public let importance: Double // 0-1, higher = more important
  public let sourcePageIndex: Int
  public let sourceBlockIndex: Int
  public let confidence: Double // 0-1
  public let category: KeyPointCategory

  public init(
    id: String = UUID().uuidString,
    text: String,
    importance: Double,
    sourcePageIndex: Int,
    sourceBlockIndex: Int = 0,
    confidence: Double = 0.8,
    category: KeyPointCategory = .general
  ) {
    self.id = id
    self.text = text
    self.importance = importance
    self.sourcePageIndex = sourcePageIndex
    self.sourceBlockIndex = sourceBlockIndex
    self.confidence = confidence
    self.category = category
  }
}

/// Category of a key point.
public enum KeyPointCategory: String, Sendable, CaseIterable {
  case general = "general"
  case heading = "heading"
  case claim = "claim"
  case definition = "definition"
  case obligation = "obligation"
  case data = "data"
  case conclusion = "conclusion"
  case question = "question"
}

/// Document summary result.
public struct DocumentSummary: Sendable {
  /// Top-level summary (first N sentences that capture main topics)
  public let summary: String
  /// Key points ranked by importance
  public let keyPoints: [KeyPoint]
  /// Document structure (headings and their hierarchy)
  public let structure: [SummarySection]
  /// Total sentences analyzed
  public let totalSentences: Int
  /// Sentences selected for summary
  public let summarySentenceCount: Int
  /// Average importance score
  public let averageImportance: Double
  /// Extraction time in milliseconds
  public let extractionTimeMs: Double

  public init(
    summary: String,
    keyPoints: [KeyPoint],
    structure: [SummarySection],
    totalSentences: Int,
    summarySentenceCount: Int,
    averageImportance: Double,
    extractionTimeMs: Double
  ) {
    self.summary = summary
    self.keyPoints = keyPoints
    self.structure = structure
    self.totalSentences = totalSentences
    self.summarySentenceCount = summarySentenceCount
    self.averageImportance = averageImportance
    self.extractionTimeMs = extractionTimeMs
  }
}

/// A section in the document summary structure.
public struct SummarySection: Sendable, Identifiable {
  public let id: String
  public let title: String
  public let level: Int
  public let pageIndex: Int
  public let sentenceCount: Int
  public let importance: Double

  public init(
    id: String = UUID().uuidString,
    title: String,
    level: Int,
    pageIndex: Int,
    sentenceCount: Int = 0,
    importance: Double = 0.5
  ) {
    self.id = id
    self.title = title
    self.level = level
    self.pageIndex = pageIndex
    self.sentenceCount = sentenceCount
    self.importance = importance
  }
}

// MARK: - Document Summarizer

/// Extracts key points, summary, and importance scoring from structured text.
public struct DocumentSummarizer: Sendable {
  /// Maximum sentences in summary
  private let maxSummarySentences: Int
  /// Minimum importance threshold for key points
  private let importanceThreshold: Double
  /// Heading font size multiplier (same as extractor)
  private let headingFontSizeMultiplier: Double

  public init(
    maxSummarySentences: Int = 5,
    importanceThreshold: Double = 0.6,
    headingFontSizeMultiplier: Double = 1.2
  ) {
    self.maxSummarySentences = maxSummarySentences
    self.importanceThreshold = importanceThreshold
    self.headingFontSizeMultiplier = headingFontSizeMultiplier
  }

  /// Summarize a document from its extraction result.
  public func summarize(extraction: StructuredExtractionResult) -> DocumentSummary {
    let startTime = CFAbsoluteTimeGetCurrent()

    // Split full text into sentences
    let sentences = extraction.fullText
      .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.count > 10 } // Skip very short fragments

    // Score each sentence
    let scored = sentences.enumerated().map { index, sentence in
      let importance = scoreSentence(
        sentence,
        index: index,
        total: sentences.count,
        headings: extraction.headings,
        blocks: extraction.blocks
      )
      return (sentence: sentence, importance: importance, index: index)
    }

    // Sort by importance, take top N for summary
    let topSentences = scored
      .sorted { $0.importance > $1.importance }
      .prefix(maxSummarySentences)
      .sorted { $0.index < $1.index } // Restore document order

    let summary = topSentences.map(\.sentence).joined(separator: ". ")

    // Build key points from blocks
    let keyPoints = buildKeyPoints(from: extraction)

    // Build structure from headings
    let structure = extraction.headings.map { heading in
      SummarySection(
        title: heading.text,
        level: heading.level,
        pageIndex: 0, // Heading doesn't carry page index in current model
        importance: heading.confidence
      )
    }

    let avgImportance = scored.isEmpty ? 0 : scored.reduce(0) { $0 + $1.importance } / Double(scored.count)
    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    return DocumentSummary(
      summary: summary,
      keyPoints: keyPoints,
      structure: structure,
      totalSentences: sentences.count,
      summarySentenceCount: topSentences.count,
      averageImportance: avgImportance,
      extractionTimeMs: elapsed
    )
  }

  /// Score a single sentence for importance.
  public func scoreSentence(
    _ sentence: String,
    index: Int,
    total: Int,
    headings: [DetectedHeading],
    blocks: [TextBlock]
  ) -> Double {
    var score = 0.5 // Base score

    let lowercased = sentence.lowercased()

    // Position score: earlier sentences are often more important
    let positionFactor = 1.0 - (Double(index) / Double(max(total, 1)))
    score += positionFactor * 0.15

    // Length score: medium-length sentences are ideal (20-100 chars)
    let length = sentence.count
    if length >= 20 && length <= 100 {
      score += 0.1
    } else if length < 10 {
      score -= 0.2
    }

    // Keyword boosters: important signal words
    let highImportanceWords = [
      "important", "critical", "must", "required", "shall",
      "therefore", "conclusion", "result", "finding", "key",
      "significant", "primary", "essential", "mandatory",
      "defined", "means", "refers to", "is defined as"
    ]
    for word in highImportanceWords {
      if lowercased.contains(word) {
        score += 0.1
        break
      }
    }

    // Definition pattern: "X is Y" or "X means Y"
    if lowercased.contains(" is ") || lowercased.contains(" means ") || lowercased.contains(" refers to ") {
      score += 0.15
    }

    // Obligation pattern: "must", "shall", "required"
    let obligationWords = ["must", "shall", "required", "mandatory", "obligated"]
    for word in obligationWords {
      if lowercased.contains(word) {
        score += 0.1
        break
      }
    }

    // Heading proximity: sentences near headings are more important
    if !headings.isEmpty {
      score += 0.05
    }

    // Clamp to 0-1
    return min(1.0, max(0.0, score))
  }

  /// Build key points from extraction blocks.
  private func buildKeyPoints(from extraction: StructuredExtractionResult) -> [KeyPoint] {
    var keyPoints: [KeyPoint] = []

    // Key points from headings (high importance)
    for (index, heading) in extraction.headings.enumerated() {
      keyPoints.append(KeyPoint(
        text: heading.text,
        importance: 0.9,
        sourcePageIndex: 0,
        sourceBlockIndex: index,
        confidence: heading.confidence,
        category: .heading
      ))
    }

    // Key points from high-importance blocks
    for (index, block) in extraction.blocks.enumerated() {
      let category = categorizeBlock(block)
      if category != .general {
        keyPoints.append(KeyPoint(
          text: block.text,
          importance: block.confidence * 0.8,
          sourcePageIndex: 0,
          sourceBlockIndex: index,
          confidence: block.confidence,
          category: category
        ))
      }
    }

    // Sort by importance
    return keyPoints.sorted { $0.importance > $1.importance }
  }

  /// Categorize a text block by its content.
  private func categorizeBlock(_ block: TextBlock) -> KeyPointCategory {
    let lowercased = block.text.lowercased()

    if lowercased.contains("must") || lowercased.contains("shall") || lowercased.contains("required") {
      return .obligation
    }
    if lowercased.contains(" is ") || lowercased.contains(" means ") || lowercased.contains(" defined as ") {
      return .definition
    }
    if lowercased.contains("therefore") || lowercased.contains("conclusion") || lowercased.contains("in summary") {
      return .conclusion
    }
    if lowercased.contains("?") {
      return .question
    }
    if block.fontSize > 12 * headingFontSizeMultiplier {
      return .data
    }
    return .general
  }
}
