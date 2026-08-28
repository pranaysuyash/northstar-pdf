import Foundation

/// A content element placed on a PDF page during document creation.
///
/// First principle: elements are value-typed, immutable snapshots.
/// Movement and editing produce new element instances — never mutate in place.
/// This makes undo trivial (keep previous snapshots) and concurrency safe.
///
/// Doctrine alignment:
/// - §3: Do things smartly — elements are lightweight descriptors, not PDF annotations
/// - §5: Evidence-based — every element has a creation timestamp and optional metadata
/// - §8: Capability activation — content authoring is opt-in via CREATE mode

// MARK: - Document Element

/// A single content element on a PDF page.
public struct DocumentElement: Identifiable, Codable, Sendable {
  public let id: UUID
  /// Which page this element lives on (0-indexed).
  public var pageIndex: Int
  /// The type of element.
  public var kind: ElementKind
  /// Position and size in PDF points (origin at bottom-left).
  public var frame: PDFRect
  /// Rotation in degrees (0, 90, 180, 270).
  public var rotation: Int
  /// Opacity (0.0–1.0).
  public var opacity: Double
  /// Z-order (higher = on top).
  public var zIndex: Int
  /// When this element was created.
  public let createdAt: Date
  /// When this element was last modified.
  public var updatedAt: Date
  /// Optional user-provided name for the element.
  public var name: String

  public init(
    id: UUID = UUID(),
    pageIndex: Int,
    kind: ElementKind,
    frame: PDFRect,
    rotation: Int = 0,
    opacity: Double = 1.0,
    zIndex: Int = 0,
    name: String = ""
  ) {
    self.id = id
    self.pageIndex = pageIndex
    self.kind = kind
    self.frame = frame
    self.rotation = rotation
    self.opacity = opacity
    self.zIndex = zIndex
    self.createdAt = Date()
    self.updatedAt = Date()
    self.name = name
  }
}

// MARK: - Element Kind

/// The type of content element.
public enum ElementKind: Codable, Sendable {
  /// A text block with font, size, color, and content.
  case text(TextProperties)
  /// An image element with embedded image data.
  case image(ImageProperties)
  /// A shape element (rectangle, ellipse, line, arrow).
  case shape(ShapeProperties)
  /// A freeform path (drawing).
  case path(PathProperties)

  public var displayName: String {
    switch self {
    case .text: return "Text"
    case .image: return "Image"
    case .shape(let p): return p.shapeType.displayName
    case .path: return "Drawing"
    }
  }

  public var symbolName: String {
    switch self {
    case .text: return "text.cursor"
    case .image: return "photo"
    case .shape(let p): return p.shapeType.symbolName
    case .path: return "pencil.and.outline"
    }
  }
}

// MARK: - Text Properties

/// Properties for a text element.
public struct TextProperties: Codable, Sendable {
  /// The text content.
  public var content: String
  /// Font name (PostScript name).
  public var fontName: String
  /// Font size in points.
  public var fontSize: Double
  /// Text color as hex string.
  public var color: String
  /// Text alignment.
  public var alignment: TextAlignment
  /// Line spacing multiplier.
  public var lineSpacing: Double
  /// Whether the text wraps within the frame.
  public var wrapsText: Bool

  public init(
    content: String = "Text",
    fontName: String = "Helvetica",
    fontSize: Double = 14,
    color: String = "000000",
    alignment: TextAlignment = .left,
    lineSpacing: Double = 1.2,
    wrapsText: Bool = true
  ) {
    self.content = content
    self.fontName = fontName
    self.fontSize = fontSize
    self.color = color
    self.alignment = alignment
    self.lineSpacing = lineSpacing
    self.wrapsText = wrapsText
  }
}

public enum TextAlignment: String, Codable, Sendable, CaseIterable {
  case left, center, right, justified

  public var displayName: String { rawValue.capitalized }
}

// MARK: - Image Properties

/// Properties for an image element.
public struct ImageProperties: Codable, Sendable {
  /// The image data (PNG or JPEG).
  public var imageData: Data
  /// Original image width in points.
  public var originalWidth: Double
  /// Original image height in points.
  public var originalHeight: Double
  /// Whether to maintain aspect ratio when resizing.
  public var maintainAspectRatio: Bool

  public init(
    imageData: Data,
    originalWidth: Double,
    originalHeight: Double,
    maintainAspectRatio: Bool = true
  ) {
    self.imageData = imageData
    self.originalWidth = originalWidth
    self.originalHeight = originalHeight
    self.maintainAspectRatio = maintainAspectRatio
  }
}

// MARK: - Shape Properties

/// Properties for a shape element.
public struct ShapeProperties: Codable, Sendable {
  /// The type of shape.
  public var shapeType: ShapeType
  /// Stroke color as hex string.
  public var strokeColor: String
  /// Stroke width in points.
  public var strokeWidth: Double
  /// Fill color as hex string (nil = no fill).
  public var fillColor: String?
  /// Corner radius (for rectangles).
  public var cornerRadius: Double
  /// Whether this is a dashed stroke.
  public var isDashed: Bool

  public init(
    shapeType: ShapeType = .rectangle,
    strokeColor: String = "000000",
    strokeWidth: Double = 1.0,
    fillColor: String? = nil,
    cornerRadius: Double = 0,
    isDashed: Bool = false
  ) {
    self.shapeType = shapeType
    self.strokeColor = strokeColor
    self.strokeWidth = strokeWidth
    self.fillColor = fillColor
    self.cornerRadius = cornerRadius
    self.isDashed = isDashed
  }
}

public enum ShapeType: String, Codable, Sendable, CaseIterable {
  case rectangle, ellipse, line, arrow

  public var displayName: String {
    switch self {
    case .rectangle: return "Rectangle"
    case .ellipse: return "Ellipse"
    case .line: return "Line"
    case .arrow: return "Arrow"
    }
  }

  public var symbolName: String {
    switch self {
    case .rectangle: return "rectangle"
    case .ellipse: return "circle"
    case .line: return "minus"
    case .arrow: return "arrow.right"
    }
  }
}

// MARK: - Path Properties

/// Properties for a freeform path element.
public struct PathProperties: Codable, Sendable {
  /// Control points defining the path (in PDF coordinates relative to frame origin).
  public var points: [PathPoint]
  /// Stroke color as hex string.
  public var strokeColor: String
  /// Stroke width in points.
  public var strokeWidth: Double

  public init(
    points: [PathPoint] = [],
    strokeColor: String = "000000",
    strokeWidth: Double = 2.0
  ) {
    self.points = points
    self.strokeColor = strokeColor
    self.strokeWidth = strokeWidth
  }
}

public struct PathPoint: Codable, Sendable {
  public var x: Double
  public var y: Double
  /// Whether this point is a control point (for curves).
  public var isControl: Bool

  public init(x: Double, y: Double, isControl: Bool = false) {
    self.x = x
    self.y = y
    self.isControl = isControl
  }
}

// MARK: - Page Template

/// Pre-built page layouts for quick document creation.
public enum PageTemplate: String, Codable, Sendable, CaseIterable {
  case blank
  case letterhead
  case invoice
  case resume
  case coverPage
  case twoColumn

  public var displayName: String {
    switch self {
    case .blank: return "Blank"
    case .letterhead: return "Letterhead"
    case .invoice: return "Invoice"
    case .resume: return "Resume"
    case .coverPage: return "Cover Page"
    case .twoColumn: return "Two Column"
    }
  }

  public var symbolName: String {
    switch self {
    case .blank: return "doc"
    case .letterhead: return "doc.text"
    case .invoice: return "doc.richtext"
    case .resume: return "person.crop.rectangle"
    case .coverPage: return "book"
    case .twoColumn: return "rectangle.split.2x1"
    }
  }

  /// Generate elements for this template on a page of the given size.
  public func generateElements(pageIndex: Int, pageSize: CGSize) -> [DocumentElement] {
    let w = Double(pageSize.width)
    let h = Double(pageSize.height)
    let margin: Double = 72 // 1 inch

    switch self {
    case .blank:
      return []

    case .letterhead:
      return [
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "COMPANY NAME", fontSize: 24, color: "1a1a2e")),
          frame: PDFRect(x: margin, y: h - margin - 30, width: w - margin * 2, height: 30)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .shape(ShapeProperties(shapeType: .line, strokeColor: "1a1a2e", strokeWidth: 2)),
          frame: PDFRect(x: margin, y: h - margin - 45, width: w - margin * 2, height: 2)
        ),
      ]

    case .invoice:
      return [
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "INVOICE", fontSize: 32, color: "1a1a2e")),
          frame: PDFRect(x: margin, y: h - margin - 40, width: w - margin * 2, height: 40)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "Bill To:", fontSize: 12, color: "666666")),
          frame: PDFRect(x: margin, y: h - margin - 120, width: 200, height: 16)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .shape(ShapeProperties(shapeType: .rectangle, strokeColor: "cccccc", strokeWidth: 1)),
          frame: PDFRect(x: margin, y: margin + 200, width: w - margin * 2, height: 300)
        ),
      ]

    case .resume:
      return [
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "YOUR NAME", fontSize: 28, color: "1a1a2e")),
          frame: PDFRect(x: margin, y: h - margin - 36, width: w - margin * 2, height: 36)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "email@example.com | (555) 123-4567", fontSize: 11, color: "666666")),
          frame: PDFRect(x: margin, y: h - margin - 60, width: w - margin * 2, height: 16)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .shape(ShapeProperties(shapeType: .line, strokeColor: "1a1a2e", strokeWidth: 1)),
          frame: PDFRect(x: margin, y: h - margin - 72, width: w - margin * 2, height: 1)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "EXPERIENCE", fontSize: 14, color: "1a1a2e")),
          frame: PDFRect(x: margin, y: h - margin - 110, width: w - margin * 2, height: 18)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "EDUCATION", fontSize: 14, color: "1a1a2e")),
          frame: PDFRect(x: margin, y: h - margin - 300, width: w - margin * 2, height: 18)
        ),
      ]

    case .coverPage:
      return [
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "TITLE", fontSize: 36, color: "1a1a2e", alignment: .center)),
          frame: PDFRect(x: margin, y: h / 2, width: w - margin * 2, height: 50)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "Subtitle or description goes here", fontSize: 16, color: "666666", alignment: .center)),
          frame: PDFRect(x: margin, y: h / 2 - 60, width: w - margin * 2, height: 24)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .shape(ShapeProperties(shapeType: .line, strokeColor: "1a1a2e", strokeWidth: 2)),
          frame: PDFRect(x: w / 2 - 50, y: h / 2 - 90, width: 100, height: 2)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "Author Name", fontSize: 14, color: "999999", alignment: .center)),
          frame: PDFRect(x: margin, y: h / 2 - 120, width: w - margin * 2, height: 20)
        ),
      ]

    case .twoColumn:
      let colWidth = (w - margin * 3) / 2
      return [
        DocumentElement(
          pageIndex: pageIndex,
          kind: .shape(ShapeProperties(shapeType: .line, strokeColor: "cccccc", strokeWidth: 0.5)),
          frame: PDFRect(x: w / 2, y: margin, width: 1, height: h - margin * 2)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "Left Column", fontSize: 12, color: "999999")),
          frame: PDFRect(x: margin, y: h - margin - 20, width: colWidth, height: 16)
        ),
        DocumentElement(
          pageIndex: pageIndex,
          kind: .text(TextProperties(content: "Right Column", fontSize: 12, color: "999999")),
          frame: PDFRect(x: w / 2 + margin / 2, y: h - margin - 20, width: colWidth, height: 16)
        ),
      ]
    }
  }
}
