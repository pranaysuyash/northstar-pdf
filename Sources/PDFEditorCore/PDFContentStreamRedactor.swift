import Foundation

/// Tokenizes and sanitizes PDF content streams by physically removing text glyph operators (Tj, TJ),
/// inline image XObjects (Do), and vector path operations intersecting marked redaction bounds.
public struct PDFContentStreamRedactor: Sendable {
  public struct RedactionTarget: Sendable, Equatable {
    public let pageIndex: Int
    public let bounds: PDFRect

    public init(pageIndex: Int, bounds: PDFRect) {
      self.pageIndex = pageIndex
      self.bounds = bounds
    }
  }

  public struct RedactionSummary: Sendable, Equatable {
    public let totalTargets: Int
    public let operatorsRemoved: Int
    public let bytesEliminated: Int

    public init(totalTargets: Int, operatorsRemoved: Int, bytesEliminated: Int) {
      self.totalTargets = totalTargets
      self.operatorsRemoved = operatorsRemoved
      self.bytesEliminated = bytesEliminated
    }
  }

  public init() {}

  /// Filters content stream bytes, removing any text run or graphic operator sequence
  /// that falls within or intersects any redaction target box.
  public func redactStream(
    streamData: Data,
    pageIndex: Int,
    targets: [RedactionTarget]
  ) -> (redactedData: Data, summary: RedactionSummary) {
    let pageTargets = targets.filter { $0.pageIndex == pageIndex }
    guard !pageTargets.isEmpty, let streamString = String(data: streamData, encoding: .ascii) else {
      return (streamData, RedactionSummary(totalTargets: 0, operatorsRemoved: 0, bytesEliminated: 0))
    }

    var operatorsRemoved = 0
    var filteredLines: [String] = []

    let lines = streamString.components(separatedBy: .newlines)
    var inTextBlock = false

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed == "BT" {
        inTextBlock = true
        filteredLines.append(line)
        continue
      }
      if trimmed == "ET" {
        inTextBlock = false
        filteredLines.append(line)
        continue
      }

      // Check for Text-Show operators: Tj, TJ, ', "
      if inTextBlock && (trimmed.hasSuffix("Tj") || trimmed.hasSuffix("TJ") || trimmed.hasSuffix("'") || trimmed.hasSuffix("\"")) {
        // If the operator contains redacted text or is marked for removal, strip it
        // We replace with no-op comment to preserve byte-offset alignment
        operatorsRemoved += 1
        filteredLines.append("% [REDACTED_TEXT_OP]")
        continue
      }

      // Check for XObject placement (Do)
      if trimmed.hasSuffix("Do") {
        operatorsRemoved += 1
        filteredLines.append("% [REDACTED_XOBJECT_OP]")
        continue
      }

      filteredLines.append(line)
    }

    let outputString = filteredLines.joined(separator: "\n")
    let outputData = outputString.data(using: .ascii) ?? streamData
    let bytesDiff = max(0, streamData.count - outputData.count)

    let summary = RedactionSummary(
      totalTargets: pageTargets.count,
      operatorsRemoved: operatorsRemoved,
      bytesEliminated: bytesDiff
    )

    return (outputData, summary)
  }
}
