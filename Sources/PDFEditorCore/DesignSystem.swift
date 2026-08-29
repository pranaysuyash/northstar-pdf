import Foundation
import CoreGraphics

/// Design system for the CREATE archetype — grid snapping, page layouts,
/// master elements, and styles.
///
/// First principle: design is a constraint system. Good design tools constrain
/// choices to good outcomes — grid snapping prevents misalignment, style
/// inheritance prevents inconsistency, master pages prevent forgotten headers.
///
/// Note: `PageTemplate` (enum) and `TextAlignment` (enum) already exist in
/// DocumentElement.swift. This file adds complementary design primitives.
///
/// Doctrine alignment:
/// - §3: Do things smartly — constraints are applied automatically
/// - §5: Evidence-based — every constraint has a measurable effect
/// - §8: Capability activation — design features are opt-in per document

// MARK: - Grid System

/// Grid configuration for alignment snapping.
public struct GridConfig: Codable, Sendable {
    /// Grid spacing in PDF points.
    public var spacing: Double
    /// Whether grid is visible.
    public var isVisible: Bool
    /// Whether snapping is enabled.
    public var isSnapping: Bool
    /// Grid color (hex).
    public var color: String

    public init(
        spacing: Double = 36, // 0.5 inch
        isVisible: Bool = true,
        isSnapping: Bool = true,
        color: String = "cccccc"
    ) {
        self.spacing = spacing
        self.isVisible = isVisible
        self.isSnapping = isSnapping
        self.color = color
    }

    /// Snap a point to the nearest grid intersection.
    public func snap(_ point: CGPoint) -> CGPoint {
        guard isSnapping else { return point }
        return CGPoint(
            x: (point.x / spacing).rounded() * spacing,
            y: (point.y / spacing).rounded() * spacing
        )
    }

    /// Snap a rect to the nearest grid boundaries.
    public func snap(_ rect: PDFRect) -> PDFRect {
        guard isSnapping else { return rect }
        let origin = snap(CGPoint(x: rect.x, y: rect.y))
        let corner = snap(CGPoint(x: rect.x + rect.width, y: rect.y + rect.height))
        return PDFRect(
            x: origin.x,
            y: origin.y,
            width: corner.x - origin.x,
            height: corner.y - origin.y
        )
    }
}

// MARK: - Page Layout

/// A detailed page layout with margins, master elements, and column configuration.
/// Complements the existing `PageTemplate` enum with richer layout data.
public struct PageLayout: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let pageSize: CGSize
    public let margins: PageMargins
    public let header: MasterElement?
    public let footer: MasterElement?
    public let columns: Int
    public let columnSpacing: Double

    public init(
        id: String = UUID().uuidString,
        name: String,
        pageSize: CGSize = CGSize(width: 612, height: 792),
        margins: PageMargins = PageMargins(),
        header: MasterElement? = nil,
        footer: MasterElement? = nil,
        columns: Int = 1,
        columnSpacing: Double = 36
    ) {
        self.id = id
        self.name = name
        self.pageSize = pageSize
        self.margins = margins
        self.header = header
        self.footer = footer
        self.columns = columns
        self.columnSpacing = columnSpacing
    }

    /// Content area (page minus margins).
    public var contentArea: PDFRect {
        PDFRect(
            x: margins.left,
            y: margins.bottom,
            width: pageSize.width - margins.left - margins.right,
            height: pageSize.height - margins.top - margins.bottom
        )
    }

    /// Predefined layouts.
    public static let blank = PageLayout(name: "Blank")
    public static let letter = PageLayout(
        name: "Letter",
        pageSize: CGSize(width: 612, height: 792),
        margins: PageMargins(top: 72, bottom: 72, left: 72, right: 72)
    )
    public static let a4 = PageLayout(
        name: "A4",
        pageSize: CGSize(width: 595.28, height: 841.89),
        margins: PageMargins(top: 72, bottom: 72, left: 72, right: 72)
    )
    public static let presentation = PageLayout(
        name: "Presentation (16:9)",
        pageSize: CGSize(width: 720, height: 405),
        margins: PageMargins(top: 36, bottom: 36, left: 36, right: 36),
        header: MasterElement(kind: .pageNumber, position: .topRight),
        footer: MasterElement(kind: .text("Confidential"), position: .bottomCenter)
    )
    public static let report = PageLayout(
        name: "Report",
        pageSize: CGSize(width: 612, height: 792),
        margins: PageMargins(top: 90, bottom: 72, left: 72, right: 72),
        header: MasterElement(kind: .line, position: .topCenter),
        footer: MasterElement(kind: .pageNumber, position: .bottomCenter),
        columns: 2,
        columnSpacing: 24
    )

    public static let allLayouts: [PageLayout] = [.blank, .letter, .a4, .presentation, .report]
}

// MARK: - Page Margins

/// Page margins in PDF points.
public struct PageMargins: Codable, Sendable {
    public var top: Double
    public var bottom: Double
    public var left: Double
    public var right: Double

    public init(top: Double = 72, bottom: Double = 72, left: Double = 72, right: Double = 72) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }
}

// MARK: - Master Element

/// A repeating element on every page (header, footer, page number).
public struct MasterElement: Codable, Sendable {
    public enum Kind: Codable, Sendable {
        case text(String)
        case pageNumber
        case line
        case date
    }

    public enum Position: Codable, Sendable {
        case topLeft
        case topCenter
        case topRight
        case bottomLeft
        case bottomCenter
        case bottomRight
    }

    public let kind: Kind
    public let position: Position

    public init(kind: Kind, position: Position) {
        self.kind = kind
        self.position = position
    }
}

// MARK: - Paragraph Style

/// A paragraph style that can be applied to text elements.
public struct ParagraphStyle: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public var fontName: String
    public var fontSize: Double
    public var color: String
    public var lineHeight: Double // multiplier (1.0 = single, 1.5 = 1.5x, etc.)
    public var alignment: String // "left", "center", "right", "justified"
    public var spaceBefore: Double // points
    public var spaceAfter: Double // points
    public var firstLineIndent: Double // points

    public init(
        id: String = UUID().uuidString,
        name: String,
        fontName: String = "Helvetica",
        fontSize: Double = 14,
        color: String = "000000",
        lineHeight: Double = 1.2,
        alignment: String = "left",
        spaceBefore: Double = 0,
        spaceAfter: Double = 6,
        firstLineIndent: Double = 0
    ) {
        self.id = id
        self.name = name
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.lineHeight = lineHeight
        self.alignment = alignment
        self.spaceBefore = spaceBefore
        self.spaceAfter = spaceAfter
        self.firstLineIndent = firstLineIndent
    }

    /// Predefined styles.
    public static let body = ParagraphStyle(name: "Body", fontSize: 12, lineHeight: 1.5)
    public static let heading1 = ParagraphStyle(name: "Heading 1", fontName: "Helvetica-Bold", fontSize: 24, spaceAfter: 12)
    public static let heading2 = ParagraphStyle(name: "Heading 2", fontName: "Helvetica-Bold", fontSize: 18, spaceAfter: 8)
    public static let heading3 = ParagraphStyle(name: "Heading 3", fontName: "Helvetica-Bold", fontSize: 14, spaceAfter: 6)
    public static let caption = ParagraphStyle(name: "Caption", fontName: "Helvetica", fontSize: 10, color: "666666")
    public static let code = ParagraphStyle(name: "Code", fontName: "Courier", fontSize: 11, lineHeight: 1.4)

    public static let allStyles: [ParagraphStyle] = [.heading1, .heading2, .heading3, .body, .caption, .code]
}

// MARK: - Character Style

/// A character-level style (bold, italic, etc.) that can be applied to spans.
public struct CharacterStyle: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public var fontName: String?
    public var fontSize: Double?
    public var color: String?
    public var isBold: Bool
    public var isItalic: Bool
    public var isUnderline: Bool

    public init(
        id: String = UUID().uuidString,
        name: String,
        fontName: String? = nil,
        fontSize: Double? = nil,
        color: String? = nil,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false
    ) {
        self.id = id
        self.name = name
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderline = isUnderline
    }

    public static let bold = CharacterStyle(name: "Bold", isBold: true)
    public static let italic = CharacterStyle(name: "Italic", isItalic: true)
    public static let emphasis = CharacterStyle(name: "Emphasis", isBold: true, isItalic: true)
    public static let link = CharacterStyle(name: "Link", color: "0066ff", isUnderline: true)

    public static let allStyles: [CharacterStyle] = [.bold, .italic, .emphasis, .link]
}
