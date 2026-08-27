import Foundation

/// Key Point Extractor — extracts important sentences, claims, obligations, and data points.
///
/// First principle: Not all text is equally important. Key points are sentences that:
/// - Make claims (assertions about the world)
/// - Create obligations (must, shall, required)
/// - Define terms (X is Y)
/// - State conclusions (therefore, in summary)
/// - Present data (numbers, statistics)
///
/// Approach: Pattern-based extraction with structural analysis.
/// No external NLP dependencies — pure Swift, works offline.
///
/// Doctrine alignment:
/// - §3: Do things smartly — pattern-based, no AI dependency
/// - §5: Evidence-based — confidence scores for every extraction
/// - §8: Capability routing — works standalone

// MARK: - Key Point Types

/// Type of key point.
public enum KeyPointType: String, Sendable, CaseIterable {
  case claim = "claim"
  case obligation = "obligation"
  case definition = "definition"
  case conclusion = "conclusion"
  case data = "data"
  case question = "question"
  case recommendation = "recommendation"
  case exception = "exception"
}

/// A single extracted key point.
public struct ExtractedKeyPoint: Sendable, Identifiable {
  public let id: String
  public let type: KeyPointType
  public let text: String
  public let importance: Double // 0-1
  public let confidence: Double // 0-1
  public let sourcePageIndex: Int
  public let sourceSentenceIndex: Int
  public let relatedTerms: [String] // Terms this key point defines or references

  public init(
    id: String = UUID().uuidString,
    type: KeyPointType,
    text: String,
    importance: Double,
    confidence: Double,
    sourcePageIndex: Int,
    sourceSentenceIndex: Int = 0,
    relatedTerms: [String] = []
  ) {
    self.id = id
    self.type = type
    self.text = text
    self.importance = importance
    self.confidence = confidence
    self.sourcePageIndex = sourcePageIndex
    self.sourceSentenceIndex = sourceSentenceIndex
    self.relatedTerms = relatedTerms
  }
}

/// Result of key point extraction.
public struct KeyPointExtractionResult: Sendable {
  /// All extracted key points, sorted by importance
  public let keyPoints: [ExtractedKeyPoint]
  /// Key points grouped by type
  public let byType: [KeyPointType: [ExtractedKeyPoint]]
  /// Total key points found
  public let totalCount: Int
  /// Number of types found
  public let typeCount: Int
  /// Average importance
  public let averageImportance: Double
  /// Extraction time in milliseconds
  public let extractionTimeMs: Double

  public init(
    keyPoints: [ExtractedKeyPoint],
    byType: [KeyPointType: [ExtractedKeyPoint]],
    totalCount: Int,
    typeCount: Int,
    averageImportance: Double,
    extractionTimeMs: Double
  ) {
    self.keyPoints = keyPoints
    self.byType = byType
    self.totalCount = totalCount
    self.typeCount = typeCount
    self.averageImportance = averageImportance
    self.extractionTimeMs = extractionTimeMs
  }
}

// MARK: - Key Point Extractor

/// Extracts important sentences, claims, obligations, and data points from text.
public struct KeyPointExtractor: Sendable {
  /// Minimum importance threshold
  private let minImportance: Double
  /// Maximum key points per type
  private let maxPerType: Int

  public init(minImportance: Double = 0.5, maxPerType: Int = 50) {
    self.minImportance = minImportance
    self.maxPerType = maxPerType
  }

  /// Extract key points from extraction result.
  public func extract(extraction: StructuredExtractionResult) -> KeyPointExtractionResult {
    let startTime = CFAbsoluteTimeGetCurrent()
    var allPoints: [ExtractedKeyPoint] = []

    // Extract from each page
    var sentenceIndex = 0
    for (pageIndex, block) in extraction.blocks.enumerated() {
      let sentences = splitIntoSentences(block.text)
      for sentence in sentences {
        let points = extractFromSentence(sentence, pageIndex: pageIndex, sentenceIndex: sentenceIndex)
        allPoints.append(contentsOf: points)
        sentenceIndex += 1
      }
    }

    // Sort by importance
    allPoints.sort { $0.importance > $1.importance }

    // Group by type
    var byType: [KeyPointType: [ExtractedKeyPoint]] = [:]
    for point in allPoints {
      byType[point.type, default: []].append(point)
    }

    // Trim per type
    for (type, points) in byType {
      byType[type] = Array(points.prefix(maxPerType))
    }

    let avgImportance = allPoints.isEmpty ? 0 : allPoints.reduce(0) { $0 + $1.importance } / Double(allPoints.count)
    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    return KeyPointExtractionResult(
      keyPoints: Array(allPoints.prefix(maxPerType * byType.count)),
      byType: byType,
      totalCount: allPoints.count,
      typeCount: byType.count,
      averageImportance: avgImportance,
      extractionTimeMs: elapsed
    )
  }

  /// Extract key points from a single sentence.
  public func extractFromSentence(_ sentence: String, pageIndex: Int, sentenceIndex: Int) -> [ExtractedKeyPoint] {
    var points: [ExtractedKeyPoint] = []
    let lowercased = sentence.lowercased()

    // Obligations: must, shall, required, mandatory
    let obligationPatterns = ["must", "shall", "required", "mandatory", "obligated", "is obligated to", "has a duty to"]
    for pattern in obligationPatterns {
      if lowercased.contains(pattern) {
        let importance = 0.9
        points.append(ExtractedKeyPoint(
          type: .obligation,
          text: sentence,
          importance: importance,
          confidence: 0.9,
          sourcePageIndex: pageIndex,
          sourceSentenceIndex: sentenceIndex
        ))
        break
      }
    }

    // Definitions: X is Y, X means Y, X refers to Y
    let definitionPatterns = [" is a ", " is an ", " is the ", " means ", " refers to ", " is defined as ", " is defined in "]
    for pattern in definitionPatterns {
      if lowercased.contains(pattern) {
        let terms = extractTerms(from: sentence, pattern: pattern)
        points.append(ExtractedKeyPoint(
          type: .definition,
          text: sentence,
          importance: 0.85,
          confidence: 0.85,
          sourcePageIndex: pageIndex,
          sourceSentenceIndex: sentenceIndex,
          relatedTerms: terms
        ))
        break
      }
    }

    // Conclusions: therefore, in summary, in conclusion, thus, hence
    let conclusionPatterns = ["therefore", "in summary", "in conclusion", "thus", "hence", "consequently", "as a result"]
    for pattern in conclusionPatterns {
      if lowercased.contains(pattern) {
        points.append(ExtractedKeyPoint(
          type: .conclusion,
          text: sentence,
          importance: 0.8,
          confidence: 0.85,
          sourcePageIndex: pageIndex,
          sourceSentenceIndex: sentenceIndex
        ))
        break
      }
    }

    // Recommendations: should, recommend, suggest, advise
    let recommendationPatterns = ["should", "recommend", "suggest", "advise", "it is recommended", "we suggest"]
    for pattern in recommendationPatterns {
      if lowercased.contains(pattern) {
        points.append(ExtractedKeyPoint(
          type: .recommendation,
          text: sentence,
          importance: 0.75,
          confidence: 0.8,
          sourcePageIndex: pageIndex,
          sourceSentenceIndex: sentenceIndex
        ))
        break
      }
    }

    // Claims: contains assertions with confidence markers
    let claimPatterns = ["is", "are", "was", "were", "will be", "has been", "have been"]
    let hasClaim = claimPatterns.contains { lowercased.contains($0) }
    let hasData = sentence.range(of: "\\d+", options: .regularExpression) != nil
    if hasClaim && hasData && sentence.count > 30 {
      points.append(ExtractedKeyPoint(
        type: .data,
        text: sentence,
        importance: 0.7,
        confidence: 0.75,
        sourcePageIndex: pageIndex,
        sourceSentenceIndex: sentenceIndex
      ))
    }

    // Questions: explicit "?" or a leading question word (what, who, when,
    // where, why, how, is, are, can, will, does, should, do, did).
    let trimmed = sentence.trimmingCharacters(in: .whitespaces)
    let questionWords = ["what ", "who ", "when ", "where ", "why ", "how ", "is ", "are ", "can ", "will ", "does ", "do ", "did ", "should ", "would ", "could "]
    let startsAsQuestion = questionWords.contains { trimmed.lowercased().hasPrefix($0) }
    if lowercased.contains("?") || startsAsQuestion {
      points.append(ExtractedKeyPoint(
        type: .question,
        text: sentence,
        importance: 0.6,
        confidence: 0.9,
        sourcePageIndex: pageIndex,
        sourceSentenceIndex: sentenceIndex
      ))
    }

    // Exceptions: except, unless, excluding, with the exception of
    let exceptionPatterns = ["except", "unless", "excluding", "with the exception of", "other than", "apart from"]
    for pattern in exceptionPatterns {
      if lowercased.contains(pattern) {
        points.append(ExtractedKeyPoint(
          type: .exception,
          text: sentence,
          importance: 0.7,
          confidence: 0.8,
          sourcePageIndex: pageIndex,
          sourceSentenceIndex: sentenceIndex
        ))
        break
      }
    }

    return points.filter { $0.importance >= minImportance }
  }

  // MARK: - Helpers

  private func splitIntoSentences(_ text: String) -> [String] {
    text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { $0.count > 15 } // Skip fragments
  }

  private func extractTerms(from sentence: String, pattern: String) -> [String] {
    // Extract the term being defined (text before " is ", " means ", etc.)
    if let range = sentence.range(of: pattern) {
      let before = String(sentence[sentence.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
      // Get last few words as the term
      let words = before.split(separator: " ")
      let term = words.suffix(min(3, words.count)).joined(separator: " ")
      return [term]
    }
    return []
  }
}
