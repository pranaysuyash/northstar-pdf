import Foundation

/// Entity Recognizer — extracts structured entities from PDF text using pattern matching.
///
/// First principle: PDFs contain structured data (dates, amounts, identifiers) that
/// users need to find and understand. Entity recognition transforms unstructured text
/// into structured, actionable information.
///
/// Approach: Regex-based pattern matching with confidence scoring.
/// No external NLP dependencies — pure Swift, works offline.
///
/// Doctrine alignment:
/// - §3: Do things smartly — pattern-based, no AI dependency
/// - §5: Evidence-based — confidence scores for every entity
/// - §8: Capability routing — works standalone

// MARK: - Entity Types

/// Type of extracted entity.
public enum EntityType: String, Sendable, CaseIterable {
  case date = "date"
  case amount = "amount"
  case email = "email"
  case url = "url"
  case phoneNumber = "phone_number"
  case ssn = "ssn"
  case zipCode = "zip_code"
  case percentage = "percentage"
  case pageReference = "page_reference"
  case sectionReference = "section_reference"
}

/// A single extracted entity.
public struct DocumentEntity: Sendable, Identifiable {
  public let id: String
  public let type: EntityType
  public let value: String
  public let normalizedValue: String // Cleaned/standardized version
  public let sourcePageIndex: Int
  public let sourceText: String // Surrounding context
  public let confidence: Double // 0-1
  public let startIndex: Int // Position in source text
  public let endIndex: Int

  public init(
    id: String = UUID().uuidString,
    type: EntityType,
    value: String,
    normalizedValue: String? = nil,
    sourcePageIndex: Int,
    sourceText: String = "",
    confidence: Double = 0.9,
    startIndex: Int = 0,
    endIndex: Int = 0
  ) {
    self.id = id
    self.type = type
    self.value = value
    self.normalizedValue = normalizedValue ?? value
    self.sourcePageIndex = sourcePageIndex
    self.sourceText = sourceText
    self.confidence = confidence
    self.startIndex = startIndex
    self.endIndex = endIndex
  }
}

/// Result of entity recognition.
public struct EntityRecognitionResult: Sendable {
  /// All extracted entities
  public let entities: [DocumentEntity]
  /// Entities grouped by type
  public let byType: [EntityType: [DocumentEntity]]
  /// Total entities found
  public let totalCount: Int
  /// Number of unique entity types found
  public let typeCount: Int
  /// Average confidence
  public let averageConfidence: Double
  /// Extraction time in milliseconds
  public let extractionTimeMs: Double

  public init(
    entities: [DocumentEntity],
    byType: [EntityType: [DocumentEntity]],
    totalCount: Int,
    typeCount: Int,
    averageConfidence: Double,
    extractionTimeMs: Double
  ) {
    self.entities = entities
    self.byType = byType
    self.totalCount = totalCount
    self.typeCount = typeCount
    self.averageConfidence = averageConfidence
    self.extractionTimeMs = extractionTimeMs
  }
}

// MARK: - Entity Recognizer

/// Extracts structured entities from PDF text using pattern matching.
public struct EntityRecognizer: Sendable {
  /// Minimum confidence threshold
  private let minConfidence: Double
  /// Maximum entities per type (prevent explosion)
  private let maxPerType: Int

  public init(minConfidence: Double = 0.7, maxPerType: Int = 100) {
    self.minConfidence = minConfidence
    self.maxPerType = maxPerType
  }

  /// Recognize entities in extraction result.
  public func recognize(extraction: StructuredExtractionResult) -> EntityRecognitionResult {
    let startTime = CFAbsoluteTimeGetCurrent()
    var allEntities: [DocumentEntity] = []

    for (pageIndex, block) in extraction.blocks.enumerated() {
      let entities = recognizeInText(block.text, pageIndex: pageIndex)
      allEntities.append(contentsOf: entities)
    }

    // Also scan full text for cross-block entities
    let fullTextEntities = recognizeInText(extraction.fullText, pageIndex: -1)
    // Deduplicate: keep block-level entities (they have page info)
    let blockPositions = Set(allEntities.map { "\($0.value):\($0.sourcePageIndex)" })
    for entity in fullTextEntities {
      let key = "\(entity.value):\(entity.sourcePageIndex)"
      if !blockPositions.contains(key) {
        allEntities.append(entity)
      }
    }

    // Group by type
    var byType: [EntityType: [DocumentEntity]] = [:]
    for entity in allEntities {
      byType[entity.type, default: []].append(entity)
    }

    // Trim per type
    for (type, entities) in byType {
      byType[type] = Array(entities.prefix(maxPerType))
    }

    let avgConfidence = allEntities.isEmpty ? 0 : allEntities.reduce(0) { $0 + $1.confidence } / Double(allEntities.count)
    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

    return EntityRecognitionResult(
      entities: allEntities,
      byType: byType,
      totalCount: allEntities.count,
      typeCount: byType.count,
      averageConfidence: avgConfidence,
      extractionTimeMs: elapsed
    )
  }

  /// Recognize entities in a text string.
  public func recognizeInText(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    var entities: [DocumentEntity] = []

    // Email addresses
    entities.append(contentsOf: findEmails(text, pageIndex: pageIndex))

    // URLs
    entities.append(contentsOf: findURLs(text, pageIndex: pageIndex))

    // Phone numbers
    entities.append(contentsOf: findPhoneNumbers(text, pageIndex: pageIndex))

    // Dates
    entities.append(contentsOf: findDates(text, pageIndex: pageIndex))

    // Amounts (currency)
    entities.append(contentsOf: findAmounts(text, pageIndex: pageIndex))

    // Percentages
    entities.append(contentsOf: findPercentages(text, pageIndex: pageIndex))

    // SSNs
    entities.append(contentsOf: findSSNs(text, pageIndex: pageIndex))

    // ZIP codes
    entities.append(contentsOf: findZipCodes(text, pageIndex: pageIndex))

    // Section references (§1.2, Section 3, etc.)
    entities.append(contentsOf: findSectionReferences(text, pageIndex: pageIndex))

    // Page references (page 5, p. 10, pp. 12-15)
    entities.append(contentsOf: findPageReferences(text, pageIndex: pageIndex))

    return entities.filter { $0.confidence >= minConfidence }
  }

  // MARK: - Pattern Finders

  private func findEmails(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    let pattern = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    return findMatches(pattern, in: text, type: .email, pageIndex: pageIndex, confidence: 0.95)
  }

  private func findURLs(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    let pattern = "https?://[^\\s\"'<>]+"
    return findMatches(pattern, in: text, type: .url, pageIndex: pageIndex, confidence: 0.95)
  }

  private func findPhoneNumbers(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    // US phone: (555) 123-4567, 555-123-4567, +1-555-123-4567
    // The separator after the parenthesized area code may be a space, so the
    // separator class includes whitespace: (555) 123-4567 must match.
    let pattern = "(?:\\+1[-.]?\\s*)?(?:\\(\\d{3}\\)|\\d{3})[-.\\s]?\\d{3}[-.]?\\d{4}"
    return findMatches(pattern, in: text, type: .phoneNumber, pageIndex: pageIndex, confidence: 0.85)
  }

  private func findDates(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    var entities: [DocumentEntity] = []

    // ISO format: 2026-08-26
    entities.append(contentsOf: findMatches(
      "\\d{4}-\\d{2}-\\d{2}",
      in: text, type: .date, pageIndex: pageIndex, confidence: 0.9,
      normalizer: { $0 }
    ))

    // US format: 08/26/2026, 8/26/2026
    entities.append(contentsOf: findMatches(
      "\\d{1,2}/\\d{1,2}/\\d{4}",
      in: text, type: .date, pageIndex: pageIndex, confidence: 0.85,
      normalizer: { formatDate($0) }
    ))

    // Written format: August 26, 2026 or Aug 26, 2026
    entities.append(contentsOf: findMatches(
      "(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\.?\\s+\\d{1,2},?\\s+\\d{4}",
      in: text, type: .date, pageIndex: pageIndex, confidence: 0.9,
      normalizer: { $0 }
    ))

    return entities
  }

  private func findAmounts(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    // $1,234.56 or $1234.56 or USD 1,234.56
    let pattern = "(?:\\$|USD|EUR|GBP|¥|€|£)\\s*\\d{1,3}(?:,\\d{3})*(?:\\.\\d{2})?"
    return findMatches(pattern, in: text, type: .amount, pageIndex: pageIndex, confidence: 0.9)
  }

  private func findPercentages(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    let pattern = "\\d{1,3}(?:\\.\\d{1,2})?\\s*%"
    return findMatches(pattern, in: text, type: .percentage, pageIndex: pageIndex, confidence: 0.95)
  }

  private func findSSNs(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    let pattern = "\\d{3}-\\d{2}-\\d{4}"
    return findMatches(pattern, in: text, type: .ssn, pageIndex: pageIndex, confidence: 0.8)
  }

  private func findZipCodes(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    // US ZIP: 12345 or 12345-6789
    let pattern = "\\b\\d{5}(?:-\\d{4})?\\b"
    return findMatches(pattern, in: text, type: .zipCode, pageIndex: pageIndex, confidence: 0.7)
  }

  private func findSectionReferences(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    // §1.2, Section 3, Section 3.1, § 4
    let pattern = "(?:§|Section|SEC)\\.?\\s*\\d+(?:\\.\\d+)*"
    return findMatches(pattern, in: text, type: .sectionReference, pageIndex: pageIndex, confidence: 0.9)
  }

  private func findPageReferences(_ text: String, pageIndex: Int) -> [DocumentEntity] {
    // page 5, p. 10, pp. 12-15, pages 3-7
    let pattern = "(?:page|pp?\\.?|pages)\\s+\\d+(?:\\s*[-–]\\s*\\d+)?"
    return findMatches(pattern, in: text, type: .pageReference, pageIndex: pageIndex, confidence: 0.85)
  }

  // MARK: - Helpers

  private func findMatches(
    _ pattern: String,
    in text: String,
    type: EntityType,
    pageIndex: Int,
    confidence: Double,
    normalizer: ((String) -> String)? = nil
  ) -> [DocumentEntity] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
      return []
    }

    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, options: [], range: range)

    return matches.prefix(maxPerType).compactMap { match -> DocumentEntity? in
      guard let matchRange = Range(match.range, in: text) else { return nil }
      let value = String(text[matchRange])

      // Get surrounding context
      let matchLocation = match.range.location
      let matchLength = match.range.length
      let contextStart = text.index(text.startIndex, offsetBy: max(0, matchLocation - 30), limitedBy: text.endIndex) ?? text.startIndex
      let contextEnd = text.index(text.startIndex, offsetBy: min(text.count, matchLocation + matchLength + 30), limitedBy: text.endIndex) ?? text.endIndex
      let context = String(text[contextStart..<contextEnd])

      return DocumentEntity(
        type: type,
        value: value,
        normalizedValue: normalizer?(value) ?? value,
        sourcePageIndex: pageIndex,
        sourceText: context,
        confidence: confidence,
        startIndex: matchLocation,
        endIndex: matchLocation + matchLength
      )
    }
  }

  private func formatDate(_ dateStr: String) -> String {
    // Convert MM/DD/YYYY to YYYY-MM-DD
    let parts = dateStr.split(separator: "/")
    guard parts.count == 3,
          let month = Int(parts[0]),
          let day = Int(parts[1]),
          let year = Int(parts[2])
    else { return dateStr }
    return String(format: "%04d-%02d-%02d", year, month, day)
  }
}
