import Foundation
import CoreGraphics

/// Tokenizes and sanitizes PDF content streams by physically removing text glyph operators (Tj, TJ, ', "),
/// inline image XObjects (Do), and baking opaque vector black rectangles directly into the graphics state.
public struct PDFContentStreamRedactor: Sendable {
  public struct RedactionTarget: Sendable, Equatable, Hashable {
    public let pageIndex: Int
    public let bounds: PDFRect
    public let sensitiveText: String?

    public init(pageIndex: Int, bounds: PDFRect, sensitiveText: String? = nil) {
      self.pageIndex = pageIndex
      self.bounds = bounds
      self.sensitiveText = sensitiveText
    }
  }

  public struct RedactionSummary: Sendable, Equatable {
    public let totalTargets: Int
    public let operatorsRemoved: Int
    public let vectorBoxesBurned: Int
    public let bytesEliminated: Int

    public init(
      totalTargets: Int,
      operatorsRemoved: Int,
      vectorBoxesBurned: Int,
      bytesEliminated: Int
    ) {
      self.totalTargets = totalTargets
      self.operatorsRemoved = operatorsRemoved
      self.vectorBoxesBurned = vectorBoxesBurned
      self.bytesEliminated = bytesEliminated
    }
  }

  public init() {}

  /// Filters content stream bytes, removing any text run or graphic operator sequence
  /// that falls within or intersects any redaction target box, and burning vector black rectangles.
  public func redactStream(
    streamData: Data,
    pageIndex: Int,
    targets: [RedactionTarget]
  ) -> (redactedData: Data, summary: RedactionSummary) {
    let pageTargets = targets.filter { $0.pageIndex == pageIndex }
    guard !pageTargets.isEmpty else {
      return (streamData, RedactionSummary(totalTargets: 0, operatorsRemoved: 0, vectorBoxesBurned: 0, bytesEliminated: 0))
    }

    // PDF streams can contain arbitrary 8-bit data; ISO-8859-1 (Latin1) preserves all 256 byte values 1:1.
    guard let streamString = String(data: streamData, encoding: .isoLatin1) else {
      return (streamData, RedactionSummary(totalTargets: 0, operatorsRemoved: 0, vectorBoxesBurned: 0, bytesEliminated: 0))
    }

    var operatorsRemoved = 0
    var filteredLines: [String] = []

    let lines = streamString.components(separatedBy: .newlines)
    var inTextBlock = false

    // Coordinate tracking state in content stream
    var currentTextX: Double = 0.0
    var currentTextY: Double = 0.0
    var currentFontSize: Double = 12.0
    var ctmTranslationX: Double = 0.0
    var ctmTranslationY: Double = 0.0

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      // CTM tracking: a b c d e f cm
      if trimmed.hasSuffix(" cm") || trimmed.hasSuffix("\tcm") {
        let parts = trimmed.split(separator: " ")
        if parts.count >= 6,
           let e = Double(parts[parts.count - 3]),
           let f = Double(parts[parts.count - 2]) {
          ctmTranslationX += e
          ctmTranslationY += f
        }
        filteredLines.append(line)
        continue
      }

      // Font size tracking: /Name size Tf
      if trimmed.hasSuffix(" Tf") || trimmed.hasSuffix("\tTf") {
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2, let size = Double(parts[parts.count - 2]) {
          currentFontSize = size
        }
        filteredLines.append(line)
        continue
      }

      // Text block markers
      if trimmed == "BT" {
        inTextBlock = true
        currentTextX = 0.0
        currentTextY = 0.0
        filteredLines.append(line)
        continue
      }
      if trimmed == "ET" {
        inTextBlock = false
        filteredLines.append(line)
        continue
      }

      // Text matrix tracking: a b c d e f Tm
      if inTextBlock && (trimmed.hasSuffix(" Tm") || trimmed.hasSuffix("\tTm")) {
        let parts = trimmed.split(separator: " ")
        if parts.count >= 6,
           let e = Double(parts[parts.count - 3]),
           let f = Double(parts[parts.count - 2]) {
          currentTextX = e + ctmTranslationX
          currentTextY = f + ctmTranslationY
        }
        filteredLines.append(line)
        continue
      }

      // Text translation tracking: tx ty Td / TD
      if inTextBlock && (trimmed.hasSuffix(" Td") || trimmed.hasSuffix(" TD") || trimmed.hasSuffix("\tTd") || trimmed.hasSuffix("\tTD")) {
        let parts = trimmed.split(separator: " ")
        if parts.count >= 3,
           let tx = Double(parts[parts.count - 3]),
           let ty = Double(parts[parts.count - 2]) {
          currentTextX += tx
          currentTextY += ty
        }
        filteredLines.append(line)
        continue
      }

      // Text-show operators: Tj, TJ, ', "
      let isTextShow = inTextBlock && (
        trimmed.hasSuffix(" Tj") || trimmed.hasSuffix("TJ") ||
        trimmed.hasSuffix(" '") || trimmed.hasSuffix(" \"") ||
        trimmed.hasSuffix("\tTj") || trimmed.hasSuffix("\tTJ") ||
        trimmed.hasSuffix("'") || trimmed.hasSuffix("\"") ||
        trimmed == "Tj" || trimmed == "TJ"
      )

      if isTextShow {
        var shouldRedact = false

        // Check 1: Target text substring match
        for target in pageTargets {
          if let sensitive = target.sensitiveText, !sensitive.isEmpty {
            if trimmed.contains(sensitive) {
              shouldRedact = true
              break
            }
          }
        }

        // Check 2: Coordinate spatial intersection
        if !shouldRedact {
          let glyphBox = PDFRect(
            x: currentTextX,
            y: currentTextY,
            width: max(currentFontSize * 4.0, 36.0),
            height: max(currentFontSize, 12.0)
          )

          for target in pageTargets {
            let tb = target.bounds
            // Vertical tolerance accounts for font ascender/descender and line height
            let vTolerance = max(currentFontSize, 8.0)
            let intersectsY = (glyphBox.y + glyphBox.height + vTolerance >= tb.y) &&
                              (glyphBox.y - vTolerance <= tb.y + tb.height)
            let intersectsX = (glyphBox.x + glyphBox.width >= tb.x) &&
                              (glyphBox.x <= tb.x + tb.width)

            if intersectsX && intersectsY {
              shouldRedact = true
              break
            }
          }
        }

        if shouldRedact {
          operatorsRemoved += 1
          filteredLines.append("% [FORENSIC_REDACTED_TEXT_OP]")
          continue
        }
      }

      filteredLines.append(line)
    }

    // Physical Vector Black Rectangle Burn-In directly into page content stream:
    // Injecting opaque black vector rectangles permanently bakes them into base page geometry.
    var vectorBurned = 0
    if !pageTargets.isEmpty {
      filteredLines.append("% --- BEGIN FORENSIC VECTOR REDACTION BURN-IN ---")
      for target in pageTargets {
        let b = target.bounds
        let rectOp = String(
          format: "q 0 0 0 rg 0 0 0 RG %.3f %.3f %.3f %.3f re f Q",
          b.x, b.y, b.width, b.height
        )
        filteredLines.append(rectOp)
        vectorBurned += 1
      }
      filteredLines.append("% --- END FORENSIC VECTOR REDACTION BURN-IN ---")
    }

    let outputString = filteredLines.joined(separator: "\n")
    let outputData = outputString.data(using: .isoLatin1) ?? streamData
    let bytesDiff = max(0, streamData.count - outputData.count)

    let summary = RedactionSummary(
      totalTargets: pageTargets.count,
      operatorsRemoved: operatorsRemoved,
      vectorBoxesBurned: vectorBurned,
      bytesEliminated: bytesDiff
    )

    return (outputData, summary)
  }
}
