import CoreGraphics
import Foundation

public struct TextLineEvidence: Equatable, Hashable, Sendable {
  public let pageIndex: Int
  public let text: String
  public let bounds: PDFRect

  public init(pageIndex: Int, text: String, bounds: PDFRect) {
    self.pageIndex = pageIndex
    self.text = text
    self.bounds = bounds
  }
}

public enum StaticRegionDetector {
  /// Generates suggestions from text-only evidence (backwards-compatible).
  public static func detect(lines: [TextLineEvidence]) -> [RegionCandidate] {
    detect(lines: lines, vectorGeometries: [])
  }

  /// Enhanced detection incorporating vector content stream geometry and label-proximity graph.
  public static func detect(
    lines: [TextLineEvidence],
    vectorGeometries: [PDFVectorStreamParser.ParsedPageGeometry]
  ) -> [RegionCandidate] {
    var candidates: [RegionCandidate] = []
    var claimedVectorBoxes = Set<PDFRect>()
    let pageLinesByIndex = Dictionary(grouping: lines, by: \.pageIndex)

    // 1. Process vector geometries after grouping repeated small cells.
    for geom in vectorGeometries {
      let pageLines = pageLinesByIndex[geom.pageIndex] ?? []

      // Character-entry forms often encode every cell as a separate
      // rectangle. Group those cells before assigning semantics so a
      // name field becomes one reviewable region rather than a queue of
      // checkbox-shaped false positives.
      let smallBoxes = smallCellBoxes(
        checkboxes: geom.potentialCheckboxes,
        inputBoxes: geom.potentialInputBoxes
      )
      for group in adjacentCellGroups(smallBoxes) {
        let region = union(of: group)
        let nearbyLabel = findNearestLabel(for: region, in: pageLines, maxDistance: 160.0)
        let labelText = nearbyLabel?.text
        let inferredType = inferFieldType(from: labelText ?? "")
        let mode = entryMode(for: inferredType, isGrouped: true)
        var evidenceStrings = [
          "Grouped \(group.count) adjacent boxes into one \(mode.displayName.lowercased()) region.",
          "Repeated cell geometry supports a single logical entry area.",
        ]
        if let labelText, !labelText.isEmpty {
          evidenceStrings.append("Associated label: \"\(labelText)\"")
        } else {
          evidenceStrings.append("No nearby label matched; review before applying.")
        }

        candidates.append(
          RegionCandidate(
            pageIndex: geom.pageIndex,
            bounds: region,
            kind: .vectorRegion,
            status: mode == .checkbox || mode == .radioGroup ? .unknown : .suggested,
            score: nearbyLabel == nil ? 0.62 : 0.90,
            evidence: evidenceStrings,
            coordinate: PDFPageRegion(pageIndex: geom.pageIndex, rect: region),
            suggestedFieldType: inferredType,
            entryMode: mode,
            labelText: labelText,
            groupMemberCount: group.count,
            memberBounds: group.sorted { $0.x < $1.x },
            evidenceItems: [
              CandidateEvidence(
                kind: .repeatedPattern,
                origin: .geometryExtraction,
                summary: "\(group.count) adjacent vector cells grouped into one region",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: region),
                text: labelText,
                score: nearbyLabel == nil ? 0.62 : 0.90
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: nearbyLabel == nil
                  ? "No nearby label matched" : "Label matched by page-space proximity",
                region: nearbyLabel.map {
                  PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds)
                },
                text: labelText
              ),
            ]
          )
        )
        for box in group {
          claimedVectorBoxes.insert(box)
        }
        claimedVectorBoxes.insert(region)
      }

            // A. Isolated checkbox geometry. Small cells are handled above;
            // only larger, ungrouped rectangles can reach this path.
            for box in geom.potentialCheckboxes {
                let nearbyLabel = findNearestLabel(for: box, in: pageLines, maxDistance: 120.0)
        let isCellSized = box.width <= 32 && box.height <= 24
        // Character-entry grids and decorative squares are common PDF
        // geometry. Without label evidence, treating every tiny square
        // as a checkbox creates an unusable review queue.
        guard !claimedVectorBoxes.contains(box), !isCellSized, box.height >= 20 else {
          continue
        }
        var evidenceStrings = [
          "Vector checkbox geometry detected (\(Int(box.width))x\(Int(box.height))pt)."
        ]
        if let label = nearbyLabel {
          evidenceStrings.append(
            "Associated label: \"\(label.text.trimmingCharacters(in: .whitespacesAndNewlines))\"")
        }

        candidates.append(
          RegionCandidate(
            pageIndex: geom.pageIndex,
            bounds: box,
            kind: .vectorRegion,
            status: .suggested,
            score: 0.85,
            evidence: evidenceStrings,
            coordinate: PDFPageRegion(pageIndex: geom.pageIndex, rect: box),
            suggestedFieldType: .checkbox,
            entryMode: .checkbox,
            labelText: nearbyLabel?.text.trimmingCharacters(in: .whitespacesAndNewlines),
            evidenceItems: [
              CandidateEvidence(
                kind: .vectorRectangle,
                origin: .geometryExtraction,
                summary: "Vector square path at (\(Int(box.x)), \(Int(box.y)))"
              )
            ]
          )
        )
        claimedVectorBoxes.insert(box)
      }

            // B. Larger input boxes (table cells, form blanks)
            for box in geom.potentialInputBoxes {
                let nearbyLabel = findNearestLabel(for: box, in: pageLines, maxDistance: 160.0)
        let isCellSized = box.width <= 32 && box.height <= 24
        // Defer unlabeled character cells to grouped-layout detection;
        // a single cell is not a useful text-entry suggestion.
        guard !claimedVectorBoxes.contains(box), !isCellSized, box.height >= 20 else {
          continue
        }
        let inferredType = inferFieldType(from: nearbyLabel?.text ?? "")
        var evidenceStrings = ["Vector bounding box (\(Int(box.width))x\(Int(box.height))pt)."]

        let score: Double
        if let label = nearbyLabel {
          evidenceStrings.append(
            "Associated label: \"\(label.text.trimmingCharacters(in: .whitespacesAndNewlines))\"")
          score = 0.80
        } else {
          score = 0.65
        }

        candidates.append(
          RegionCandidate(
            pageIndex: geom.pageIndex,
            bounds: box,
            kind: .vectorRegion,
            status: .suggested,
            score: score,
            evidence: evidenceStrings,
            coordinate: PDFPageRegion(pageIndex: geom.pageIndex, rect: box),
            suggestedFieldType: inferredType,
            entryMode: entryMode(for: inferredType, isGrouped: false),
            labelText: nearbyLabel?.text.trimmingCharacters(in: .whitespacesAndNewlines),
            evidenceItems: [
              CandidateEvidence(
                kind: .vectorRectangle,
                origin: .geometryExtraction,
                summary: "Vector rectangle at (\(Int(box.x)), \(Int(box.y)))"
              )
            ]
          )
        )
        claimedVectorBoxes.insert(box)
      }

            // C. Underlines from vector stream
            for line in geom.potentialUnderlines {
                let boxAbove = PDFRect(x: line.x, y: line.y, width: line.width, height: 18.0)
                let nearbyLabel = findNearestLabel(for: boxAbove, in: pageLines, maxDistance: 120.0)
        let inferredType = inferFieldType(from: nearbyLabel?.text ?? "")
        var evidenceStrings = ["Vector underline stroke detected (\(Int(line.width))pt)."]
        if let label = nearbyLabel {
          evidenceStrings.append(
            "Associated label: \"\(label.text.trimmingCharacters(in: .whitespacesAndNewlines))\"")
        }

        candidates.append(
          RegionCandidate(
            pageIndex: geom.pageIndex,
            bounds: boxAbove,
            kind: .vectorRegion,
            status: .suggested,
            score: nearbyLabel != nil ? 0.75 : 0.60,
            evidence: evidenceStrings,
            coordinate: PDFPageRegion(pageIndex: geom.pageIndex, rect: boxAbove),
            suggestedFieldType: inferredType,
            entryMode: entryMode(for: inferredType, isGrouped: false),
            labelText: nearbyLabel?.text.trimmingCharacters(in: .whitespacesAndNewlines),
            evidenceItems: [
              CandidateEvidence(
                kind: .underline,
                origin: .geometryExtraction,
                summary: "Vector line stroke at y=\(Int(line.y))"
              )
            ]
          )
        )
        claimedVectorBoxes.insert(boxAbove)
      }
    }

    // 2. Text-Anchored Suggestions (for text ending with : or containing _)
    for line in lines {
      let normalized = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalized.isEmpty else { continue }

      let containsUnderline = normalized.contains("_")
      let looksLikeLabel = normalized.hasSuffix(":")
      guard containsUnderline || looksLikeLabel else { continue }

      // If a vector box already overlaps this line, do not create duplicate text-anchored candidate
      let overlapsVector = claimedVectorBoxes.contains { box in
        abs(box.x - line.bounds.x) < 40 && abs(box.y - line.bounds.y) < 20
      }
      if overlapsVector { continue }

      let kind: CandidateKind = .textAnchored
      let score = containsUnderline ? 0.45 : 0.25
      let evidence =
        containsUnderline
        ? ["Text contains an underline-like blank marker.", "No vector geometry was inspected."]
        : ["Text ends with a label delimiter.", "No vector-field proof is available."]

      let inferredType = inferFieldType(from: normalized)

      candidates.append(
        RegionCandidate(
          pageIndex: line.pageIndex,
          bounds: line.bounds,
          kind: kind,
          status: .suggested,
          score: score,
          evidence: evidence,
          coordinate: PDFPageRegion(pageIndex: line.pageIndex, rect: line.bounds),
          suggestedFieldType: inferredType,
          entryMode: entryMode(for: inferredType, isGrouped: false),
          labelText: normalized
        )
      )
    }

    return candidates
  }

  private static func findNearestLabel(
    for box: PDFRect,
    in lines: [TextLineEvidence],
    maxDistance: CGFloat
  ) -> TextLineEvidence? {
    var bestMatch: TextLineEvidence?
    var minDistance: CGFloat = maxDistance

    for line in lines {
      let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
      guard text.count > 1 else { continue }

      let lineBounds = line.bounds.cgRect
      let boxRect = box.cgRect

      // Check if label is to the left of the box on roughly the same horizontal line
      let isLeft =
        lineBounds.maxX <= boxRect.minX + 15
        && abs(lineBounds.midY - boxRect.midY) < max(boxRect.height, 20.0)
      // Check if label is above the box
      let isAbove =
        lineBounds.minY >= boxRect.maxY - 5
        && abs(lineBounds.minX - boxRect.minX) < max(boxRect.width, 100.0)
        && (lineBounds.minY - boxRect.maxY) < maxDistance

      if isLeft {
        let dist = boxRect.minX - lineBounds.maxX
        if dist >= 0 && dist < minDistance {
          minDistance = dist
          bestMatch = line
        }
      } else if isAbove {
        let dist = lineBounds.minY - boxRect.maxY
        if dist >= 0 && dist < minDistance {
          minDistance = dist
          bestMatch = line
        }
      }
    }
    return bestMatch
  }

  private static func inferFieldType(from label: String) -> SuggestedFieldType {
    let lower = label.lowercased()
    if lower.contains("date") || lower.contains("dob") || lower.contains("dd/mm")
      || lower.contains("yyyy")
    {
      return .date
    }
    if lower.contains("sign") || lower.contains("signature") || lower.contains("signed") {
      return .signature
    }
    if lower.contains("ssn") || lower.contains("phone") || lower.contains("zip")
      || lower.contains("amount") || lower.contains("number")
    {
      return .number
    }
    if lower.contains("select one") || lower.contains("one of") || lower.contains("gender")
      || lower.contains("relationship") || lower.contains("relative type")
      || lower.contains("proof choice")
    {
      return .radio
    }
    if lower.contains("check") || lower.contains("yes/no") || lower.contains("yes / no")
      || lower.contains("male") || lower.contains("female") || lower.contains("father")
      || lower.contains("mother") || lower.contains("husband") || lower.contains("wife")
      || lower.contains("tick") || lower.contains("select")
    {
      return .checkbox
    }
    return .text
  }

  private static func entryMode(for fieldType: SuggestedFieldType, isGrouped: Bool)
    -> CandidateEntryMode
  {
    switch fieldType {
    case .checkbox:
      return .checkbox
    case .radio:
      return .radioGroup
    case .signature:
      return .signature
    case .text, .date, .number, .choice:
      return isGrouped ? .characterGrid : .singleText
    case .unknown:
      return .unknown
    }
  }

  private static func smallCellBoxes(checkboxes: [PDFRect], inputBoxes: [PDFRect]) -> [PDFRect] {
    var result = checkboxes
    for box in inputBoxes {
      if box.width <= 32 && box.height <= 32 {
        result.append(box)
      }
    }
    return result
  }

  private static func adjacentCellGroups(_ boxes: [PDFRect]) -> [[PDFRect]] {
    let sorted = boxes.sorted {
      if abs($0.cgRect.midY - $1.cgRect.midY) > 3 {
        return $0.cgRect.midY > $1.cgRect.midY
      }
      return $0.cgRect.minX < $1.cgRect.minX
    }
    var groups: [[PDFRect]] = []
    for box in sorted {
      guard let lastIndex = groups.indices.last, let last = groups[lastIndex].last else {
        groups.append([box])
        continue
      }
      let sameRow =
        abs(box.cgRect.midY - last.cgRect.midY)
        <= max(3, min(box.cgRect.height, last.cgRect.height) * 0.5)
      let gap = box.cgRect.minX - last.cgRect.maxX
      let closeEnough = gap >= -1 && gap <= max(8, min(box.cgRect.width, last.cgRect.width) * 1.5)
      if sameRow && closeEnough {
        groups[lastIndex].append(box)
      } else {
        groups.append([box])
      }
    }
    return groups.filter { $0.count >= 3 }
  }

  private static func union(of boxes: [PDFRect]) -> PDFRect {
    guard let first = boxes.first else {
      return PDFRect(x: 0, y: 0, width: 0, height: 0)
    }
    let rect = boxes.dropFirst().reduce(first.cgRect) { partial, box in
      partial.union(box.cgRect)
    }
    return PDFRect(rect)
  }
}

extension CandidateEntryMode {
  fileprivate var displayName: String {
    switch self {
    case .singleText: return "text entry"
    case .characterGrid: return "character-entry"
    case .checkbox: return "checkbox"
    case .radioGroup: return "choice"
    case .signature: return "signature"
    case .unknown: return "review"
    }
  }
}
