import Foundation

/// Content-aware routing: detect what type of content dominates a document
/// and suggest the optimal reading mode.
///
/// First principle: the document's structure should decide its presentation.
/// A table wants sortable headers; an image wants pixel inspection; a form
/// wants field navigation; a long text wants comfortable reading.
///
/// Architecture:
/// - `ContentType` enumerates the detected content types
/// - `ContentRouter` analyzes extraction results
/// - `ContentSuggestion` bundles the suggestion with confidence and reason
///
/// Doctrine alignment:
/// - §3: Do things smartly — route to the right mode automatically
/// - §8: Capability routing — content type activates specific UI capabilities

// MARK: - Content Type

/// The dominant content type detected in a document or page.
public enum ContentType: String, Sendable, CaseIterable, Identifiable {
  /// Plain text (paragraphs, articles, documentation).
  case text = "text"
  /// Structured table (rows, columns, cells).
  case table = "table"
  /// Form (fields, checkboxes, signatures).
  case form = "form"
  /// Mixed content (no single type dominates).
  case mixed = "mixed"

  public var id: String { rawValue }
  public var displayName: String { rawValue.capitalized }

  public var symbolName: String {
    switch self {
    case .text: return "doc.text"
    case .table: return "tablecells"
    case .form: return "checkmark.rectangle.stack"
    case .mixed: return "square.grid.2x2"
    }
  }

  /// The suggested reading mode for this content type.
  public var suggestedMode: ReadingMode {
    switch self {
    case .text: return .study
    case .table: return .reference
    case .form: return .reference
    case .mixed: return .study
    }
  }

  /// The suggested action label shown in the toolbar.
  public var suggestedAction: String {
    switch self {
    case .text: return "Study mode"
    case .table: return "Table view"
    case .form: return "Form mode"
    case .mixed: return "Default view"
    }
  }
}

// MARK: - Content Suggestion

/// A routing suggestion based on document content.
public struct ContentSuggestion: Sendable {
  /// The detected dominant content type.
  public let contentType: ContentType
  /// Confidence in the detection (0-1).
  public let confidence: Double
  /// Human-readable reason for the suggestion.
  public let reason: String
  /// Number of elements of the dominant type found.
  public let elementCount: Int

  /// Whether the suggestion is strong enough to act on automatically.
  /// High confidence (≥0.9) with even one element is actionable.
  public var isActionable: Bool {
    confidence >= 0.9 || (confidence >= 0.7 && elementCount >= 2)
  }

  public init(
    contentType: ContentType,
    confidence: Double,
    reason: String,
    elementCount: Int
  ) {
    self.contentType = contentType
    self.confidence = confidence
    self.reason = reason
    self.elementCount = elementCount
  }
}

// MARK: - Content Router

/// Analyzes extraction results and determines the dominant content type.
public struct ContentRouter: Sendable {
  public init() {}

  /// Route an extraction result to a content suggestion.
  public func route(extraction: StructuredExtractionResult) -> ContentSuggestion {
    let tableCount = extraction.tables.count
    let blockCount = extraction.blocks.count
    let headingCount = extraction.headings.count

    // Count table cells
    let totalCells = extraction.tables.reduce(0) {
      $0 + $1.rows * $1.columns
    }

    // Heuristic scoring: each content type gets a score 0-1
    var scores: [(ContentType, Double, String, Int)] = []

    // TABLE: presence of detected tables with enough cells
    if tableCount > 0 {
      let tableScore = min(1.0, Double(totalCells) / 20.0 + Double(tableCount) * 0.2)
      scores.append((
        .table,
        tableScore,
        "\(tableCount) table(s) with \(totalCells) cells",
        tableCount
      ))
    }

    // TEXT: text blocks with headings (structured document)
    if blockCount > 0 {
      let headingRatio = Double(headingCount) / max(1, Double(blockCount))
      let textScore = min(1.0, 0.4 + headingRatio * 0.4 + min(0.2, Double(blockCount) / 50.0))
      scores.append((
        .text,
        textScore,
        "\(blockCount) text blocks, \(headingCount) headings",
        blockCount
      ))
    }

    // FORM: blocks that look like form fields
    let formKeywords = ["field", "check", "signature", "date of birth",
                        "name", "address", "phone", "email", "social security",
                        "employee", "applicant", "patient", "account"]
    let formBlocks = extraction.blocks.filter { block in
      let text = block.text.lowercased()
      return formKeywords.contains { text.contains($0) }
    }
    if formBlocks.count >= 3 {
      let formScore = min(1.0, Double(formBlocks.count) / Double(max(1, blockCount)) + 0.3)
      scores.append((
        .form,
        formScore,
        "\(formBlocks.count) form-like fields detected",
        formBlocks.count
      ))
    }

    // Default if nothing detected
    if scores.isEmpty {
      return ContentSuggestion(
        contentType: .text,
        confidence: 0.5,
        reason: "Default — no strong content signal",
        elementCount: blockCount
      )
    }

    // Pick highest score
    guard let best = scores.max(by: { $0.1 < $1.1 }) else {
      return ContentSuggestion(
        contentType: .mixed,
        confidence: 0.3,
        reason: "No clear dominant content",
        elementCount: 0
      )
    }

    // If two top scores are close → mixed
    let sorted = scores.sorted(by: { $0.1 > $1.1 })
    if sorted.count >= 2 {
      let gap = sorted[0].1 - sorted[1].1
      if gap < 0.15 {
        return ContentSuggestion(
          contentType: .mixed,
          confidence: 0.4,
          reason: "\(best.2) and \(sorted[1].2)",
          elementCount: best.3
        )
      }
    }

    return ContentSuggestion(
      contentType: best.0,
      confidence: best.1,
      reason: best.2,
      elementCount: best.3
    )
  }
}
