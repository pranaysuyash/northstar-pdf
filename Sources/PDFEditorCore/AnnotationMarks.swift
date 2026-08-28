import Foundation

/// A user-created annotation mark stored in a sidecar file (not in-PDF).
///
/// First principle: annotations are the user's commentary layer — they belong
/// to the user, not the document. Storing them in-PDF makes them subject to
/// permission restrictions and version conflicts. Sidecar storage keeps them
/// independent, portable, and searchable.
///
/// Architecture:
/// - `AnnotationMark` — a single mark (highlight, note, underline, etc.)
/// - `AnnotationStore` — manages marks for a document, persists as JSON sidecar
/// - `AnnotationSearchQuery` — find marks by text, type, color, date
///
/// Doctrine alignment:
/// - §3: Do things smartly — sidecar = non-destructive, portable
/// - §5: Evidence-based — marks have timestamps, page references
/// - §8: Capability routing — annotations are opt-in per document

// MARK: - Annotation Type

/// The type of annotation mark.
public enum AnnotationType: String, Codable, Sendable, CaseIterable, Identifiable {
  case highlight = "highlight"
  case underline = "underline"
  case note = "note"
  case strikethrough = "strikethrough"
  case freehand = "freehand"

  public var id: String { rawValue }
  public var displayName: String { rawValue.capitalized }

  public var symbolName: String {
    switch self {
    case .highlight: return "highlighter"
    case .underline: return "underline"
    case .note: return "note.text"
    case .strikethrough: return "strikethrough"
    case .freehand: return "pencil.line"
    }
  }
}

// MARK: - Annotation Color

/// Preset colors for annotation marks.
public enum AnnotationColor: String, Codable, Sendable, CaseIterable, Identifiable {
  case yellow = "yellow"
  case green = "green"
  case blue = "blue"
  case pink = "pink"
  case orange = "orange"
  case purple = "purple"
  case red = "red"
  case gray = "gray"

  public var id: String { rawValue }
  public var displayName: String { rawValue.capitalized }

  /// Hex color string for rendering.
  public var hexColor: String {
    switch self {
    case .yellow: return "#FFEB3B"
    case .green: return "#4CAF50"
    case .blue: return "#2196F3"
    case .pink: return "#E91E63"
    case .orange: return "#FF9800"
    case .purple: return "#9C27B0"
    case .red: return "#F44336"
    case .gray: return "#9E9E9E"
    }
  }
}

// MARK: - Annotation Mark

/// A single annotation mark in a sidecar file.
public struct AnnotationMark: Codable, Sendable, Identifiable {
  public let id: UUID
  /// The annotation type (highlight, note, underline, etc.).
  public let type: AnnotationType
  /// Page index where the mark is located.
  public let pageIndex: Int
  /// Bounds of the mark in page coordinates (points).
  public let bounds: PDFRect
  /// The text content of the marked region (for search).
  public let selectedText: String
  /// User's note/comment on this mark (for notes, or optional on highlights).
  public var note: String
  /// Color of the mark.
  public var color: AnnotationColor
  /// When the mark was created.
  public let createdAt: Date
  /// When the mark was last modified.
  public var updatedAt: Date
  /// Whether the mark is visible (can be hidden without deleting).
  public var isVisible: Bool
  /// Optional tags for organization.
  public var tags: [String]

  public init(
    id: UUID = UUID(),
    type: AnnotationType,
    pageIndex: Int,
    bounds: PDFRect,
    selectedText: String = "",
    note: String = "",
    color: AnnotationColor = .yellow,
    tags: [String] = []
  ) {
    self.id = id
    self.type = type
    self.pageIndex = pageIndex
    self.bounds = bounds
    self.selectedText = selectedText
    self.note = note
    self.color = color
    self.createdAt = Date()
    self.updatedAt = Date()
    self.isVisible = true
    self.tags = tags
  }

  /// Human-readable summary of the mark.
  public var summary: String {
    let textPreview = selectedText.isEmpty ? "" : " \"\(selectedText.prefix(50))\""
    let notePreview = note.isEmpty ? "" : " — \(note.prefix(50))"
    return "\(type.displayName) on page \(pageIndex + 1)\(textPreview)\(notePreview)"
  }
}

// MARK: - Annotation Search Query

/// Query for searching annotations.
public struct AnnotationSearchQuery: Sendable {
  /// Filter by annotation type (nil = all types).
  public var type: AnnotationType?
  /// Filter by color (nil = all colors).
  public var color: AnnotationColor?
  /// Text to search for in selectedText and note fields.
  public var text: String?
  /// Filter by page index (nil = all pages).
  public var pageIndex: Int?
  /// Filter by tags (empty = all tags).
  public var tags: [String]?
  /// Only include visible marks.
  public var visibleOnly: Bool

  public init(
    type: AnnotationType? = nil,
    color: AnnotationColor? = nil,
    text: String? = nil,
    pageIndex: Int? = nil,
    tags: [String] = [],
    visibleOnly: Bool = true
  ) {
    self.type = type
    self.color = color
    self.text = text
    self.pageIndex = pageIndex
    self.tags = tags
    self.visibleOnly = visibleOnly
  }
}

// MARK: - Annotation Export Format

/// Format for exporting annotations.
public enum AnnotationExportFormat: String, Sendable {
  /// JSON sidecar file (portable, machine-readable).
  case json = "json"
  /// Markdown document (human-readable).
  case markdown = "markdown"
  /// Plain text list.
  case plainText = "plainText"
}

// MARK: - Annotation Export Result

/// Result of exporting annotations.
public struct AnnotationExportResult: Sendable {
  /// The exported data.
  public let data: Data
  /// The format used.
  public let format: AnnotationExportFormat
  /// Number of marks exported.
  public let markCount: Int
  /// Suggested file name.
  public let suggestedFileName: String

  public init(data: Data, format: AnnotationExportFormat, markCount: Int, suggestedFileName: String) {
    self.data = data
    self.format = format
    self.markCount = markCount
    self.suggestedFileName = suggestedFileName
  }
}
