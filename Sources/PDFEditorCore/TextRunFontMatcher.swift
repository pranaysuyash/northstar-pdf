import AppKit
import Foundation

/// Analyzes font descriptors, metrics, and typographic parameters from PDF text runs
/// and finds the closest matching platform font for in-place text replacement.
public struct TextRunFontMatcher: Sendable {
  public struct FontMatchResult: Equatable, Sendable {
    public let postscriptName: String
    public let familyName: String
    public let pointSize: CGFloat
    public let weight: NSFont.Weight
    public let isItalic: Bool
    public let isMonospace: Bool
    public let approximateCharWidth: CGFloat

    public init(
      postscriptName: String,
      familyName: String,
      pointSize: CGFloat,
      weight: NSFont.Weight = .regular,
      isItalic: Bool = false,
      isMonospace: Bool = false,
      approximateCharWidth: CGFloat = 0
    ) {
      self.postscriptName = postscriptName
      self.familyName = familyName
      self.pointSize = pointSize
      self.weight = weight
      self.isItalic = isItalic
      self.isMonospace = isMonospace
      self.approximateCharWidth = approximateCharWidth
    }
  }

  public init() {}

  /// Resolves the best-matching platform font given raw PDF font descriptor name and size.
  public func resolveFont(name rawName: String, pointSize: CGFloat) -> FontMatchResult {
    let lower = rawName.lowercased()

    let isBold = lower.contains("bold") || lower.contains("black") || lower.contains("heavy") || lower.contains("-b")
    let isItalic = lower.contains("italic") || lower.contains("oblique") || lower.contains("slanted") || lower.contains("-i")
    let isMonospace = lower.contains("courier") || lower.contains("mono") || lower.contains("typewriter") || lower.contains("consolas") || lower.contains("menlo")

    let weight: NSFont.Weight = isBold ? .bold : .regular

    if isMonospace {
      return FontMatchResult(
        postscriptName: isBold ? (isItalic ? "CourierNewPS-BoldItalicMT" : "CourierNewPS-BoldMT") : (isItalic ? "CourierNewPS-ItalicMT" : "CourierNewPSMT"),
        familyName: "Courier New",
        pointSize: pointSize,
        weight: weight,
        isItalic: isItalic,
        isMonospace: true,
        approximateCharWidth: pointSize * 0.6
      )
    }

    if lower.contains("times") || lower.contains("serif") || lower.contains("minion") || lower.contains("georgia") || lower.contains("palatino") {
      let family = lower.contains("georgia") ? "Georgia" : (lower.contains("palatino") ? "Palatino" : "Times New Roman")
      return FontMatchResult(
        postscriptName: isBold ? (isItalic ? "\(family)-BoldItalic" : "\(family)-Bold") : (isItalic ? "\(family)-Italic" : family),
        familyName: family,
        pointSize: pointSize,
        weight: weight,
        isItalic: isItalic,
        isMonospace: false,
        approximateCharWidth: pointSize * 0.45
      )
    }

    // Default to clean Sans-Serif (Helvetica / SF Pro)
    let family = "Helvetica"
    return FontMatchResult(
      postscriptName: isBold ? (isItalic ? "Helvetica-BoldOblique" : "Helvetica-Bold") : (isItalic ? "Helvetica-Oblique" : "Helvetica"),
      familyName: family,
      pointSize: pointSize,
      weight: weight,
      isItalic: isItalic,
      isMonospace: false,
      approximateCharWidth: pointSize * 0.5
    )
  }

  /// Calculates the expected bounding box width of replacement text using the matched font metrics.
  public func estimateTextWidth(text: String, font: FontMatchResult) -> CGFloat {
    if font.isMonospace {
      return CGFloat(text.count) * font.approximateCharWidth
    }

    let nsFont: NSFont
    if let specificFont = NSFont(name: font.postscriptName, size: font.pointSize) {
      nsFont = specificFont
    } else {
      nsFont = NSFont.systemFont(ofSize: font.pointSize, weight: font.weight)
    }

    let attrs: [NSAttributedString.Key: Any] = [.font: nsFont]
    let size = (text as NSString).size(withAttributes: attrs)
    return size.width
  }
}
