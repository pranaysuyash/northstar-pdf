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
        // Repeated geometry is not field intent by itself. Require a
        // semantically plausible label before promoting a grid to a review
        // candidate; unlabeled grids remain raw geometry evidence.
        guard let nearbyLabel = findNearestLabel(for: region, in: pageLines, maxDistance: 160.0)
        else { continue }
        let labelText: String? = nearbyLabel.text
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
            score: 0.90,
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
                score: 0.90
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: labelText,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .textLabel,
                origin: .textExtraction,
                summary: "Semantically plausible field label",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: labelText,
                score: 0.72
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
        // Character-entry grids and decorative squares are common PDF
        // geometry. Without label evidence, treating every tiny square
        // as a checkbox creates an unusable review queue.
        guard !claimedVectorBoxes.contains(box), box.height >= 8, nearbyLabel != nil else {
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
            groupMemberCount: 1,
            memberBounds: [box],
            evidenceItems: [
              CandidateEvidence(
                kind: .vectorRectangle,
                origin: .geometryExtraction,
                summary: "Vector square path at (\(Int(box.x)), \(Int(box.y)))",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: box),
                score: 0.85
              ),
              CandidateEvidence(
                kind: .textLabel,
                origin: .textExtraction,
                summary: "Semantically plausible field label",
                region: nearbyLabel.map { PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds) },
                text: nearbyLabel?.text,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: nearbyLabel.map { PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds) },
                text: nearbyLabel?.text,
                score: 0.72
              ),
            ]
          )
        )
        claimedVectorBoxes.insert(box)
      }

            // B. Larger input boxes (table cells, form blanks)
      for box in geom.potentialInputBoxes {
        let nearbyLabel = findNearestLabel(for: box, in: pageLines, maxDistance: 160.0)
        // Defer unlabeled character cells to grouped-layout detection;
        // a single cell is not a useful text-entry suggestion.
        guard !claimedVectorBoxes.contains(box), box.height >= 8, nearbyLabel != nil else {
          continue
        }
        let inferredType = inferFieldType(from: nearbyLabel?.text ?? "")
        var evidenceStrings = ["Vector bounding box (\(Int(box.width))x\(Int(box.height))pt)."]

        let score = 0.80
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
                summary: "Vector rectangle at (\(Int(box.x)), \(Int(box.y)))",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: box),
                score: score
              ),
              CandidateEvidence(
                kind: .textLabel,
                origin: .textExtraction,
                summary: "Semantically plausible field label",
                region: nearbyLabel.map { PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds) },
                text: nearbyLabel?.text,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: nearbyLabel.map { PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds) },
                text: nearbyLabel?.text,
                score: 0.72
              ),
            ]
          )
        )
        claimedVectorBoxes.insert(box)
      }

            // C. Underlines from vector stream
      for line in geom.potentialUnderlines {
        let boxAbove = PDFRect(x: line.x, y: line.y, width: line.width, height: 18.0)
        let nearbyLabel = findNearestLabel(for: boxAbove, in: pageLines, maxDistance: 120.0)
        guard nearbyLabel != nil else { continue }
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
            score: 0.75,
            evidence: evidenceStrings,
            coordinate: PDFPageRegion(pageIndex: geom.pageIndex, rect: boxAbove),
            suggestedFieldType: inferredType,
            entryMode: entryMode(for: inferredType, isGrouped: false),
            labelText: nearbyLabel?.text.trimmingCharacters(in: .whitespacesAndNewlines),
            evidenceItems: [
              CandidateEvidence(
                kind: .underline,
                origin: .geometryExtraction,
                summary: "Vector line stroke at y=\(Int(line.y))",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: boxAbove),
                score: 0.75
              ),
              CandidateEvidence(
                kind: .textLabel,
                origin: .textExtraction,
                summary: "Semantically plausible field label",
                region: nearbyLabel.map { PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds) },
                text: nearbyLabel?.text,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: nearbyLabel.map { PDFPageRegion(pageIndex: geom.pageIndex, rect: $0.bounds) },
                text: nearbyLabel?.text,
                score: 0.72
              ),
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
      guard isLikelyFieldLabel(normalized) else { continue }

      // If a vector box already overlaps this line, do not create duplicate text-anchored candidate
      let overlapsVector = claimedVectorBoxes.contains { box in
        abs(box.x - line.bounds.x) < 40 && abs(box.y - line.bounds.y) < 20
      }
      if overlapsVector { continue }

      let kind: CandidateKind = .textAnchored
      // Keep the text-anchored score aligned with the browser adapter. This
      // is an evidence-strength rank, not a calibrated probability.
      let score = containsUnderline ? 0.45 : 0.58
      let evidence =
        containsUnderline
        ? ["Text contains an underline-like blank marker.", "No vector geometry was inspected."]
        : ["Text ends with a label delimiter.", "No vector-field proof is available."]

      let inferredType = inferFieldType(from: normalized)
      let whitespaceRect: PDFRect
      if let pageGeometry = vectorGeometries.first(where: { $0.pageIndex == line.pageIndex }) {
        let pageRight = pageGeometry.mediaBox.maxX
        let x = line.bounds.x + line.bounds.width + 8
        whitespaceRect = PDFRect(
          x: x,
          y: line.bounds.y,
          width: max(72, min(220, pageRight - x - 20)),
          height: max(14, line.bounds.height + 5)
        )
      } else {
        whitespaceRect = PDFRect(
          x: line.bounds.x + line.bounds.width + 8,
          y: line.bounds.y,
          width: 220,
          height: max(14, line.bounds.height + 5)
        )
      }
      let candidateBounds = containsUnderline ? line.bounds : whitespaceRect

      candidates.append(
        RegionCandidate(
          pageIndex: line.pageIndex,
          bounds: candidateBounds,
          kind: kind,
          status: .suggested,
          score: score,
          evidence: evidence,
          coordinate: PDFPageRegion(pageIndex: line.pageIndex, rect: candidateBounds),
          suggestedFieldType: inferredType,
          entryMode: entryMode(for: inferredType, isGrouped: false),
          labelText: normalized,
          evidenceItems: [
            CandidateEvidence(
              kind: .whitespace,
              origin: .textExtraction,
              summary: "Whitespace adjacent to a semantically plausible label",
              region: PDFPageRegion(pageIndex: line.pageIndex, rect: whitespaceRect),
              text: normalized,
              score: score
            ),
            CandidateEvidence(
              kind: .textLabel,
              origin: .textExtraction,
              summary: "Label text anchors the whitespace candidate",
              region: PDFPageRegion(pageIndex: line.pageIndex, rect: line.bounds),
              text: normalized,
              score: 0.72
            ),
            CandidateEvidence(
              kind: .spatialRelationship,
              origin: .textExtraction,
              summary: "Whitespace is positioned after the label text",
              region: PDFPageRegion(pageIndex: line.pageIndex, rect: line.bounds),
              text: normalized,
              score: score
            ),
          ]
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
      guard text.count > 1, isLikelyFieldLabel(text) else { continue }

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

  /// A nearby string is evidence of label association only when it contains
  /// a field-intent token. Layout words such as "Section:" and "Note:" are
  /// deliberate hard negatives in the detector calibration corpus.
  private static func isLikelyFieldLabel(_ text: String) -> Bool {
    let normalized = text
      .lowercased()
      .replacingOccurrences(of: "_", with: " ")
      .replacingOccurrences(of: ".", with: " ")
      .replacingOccurrences(of: ":", with: " ")
    let tokens = [
      "name", "address", "email", "phone", "tel", "date", "dob", "birth",
      "signature", "sign", "ssn", "zip", "postal", "amount", "number",
      "account", "agree", "check", "select", "choice", "gender", "relationship",
      "city", "state", "country", "company", "employer", "license", "policy",
      "claim", "reference", "id"
    ]
    return tokens.contains { token in
      normalized.range(of: "\\b\(token)\\b", options: .regularExpression) != nil
    }
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

  /// Groups cells only when their row geometry, width signature, and local gap
  /// pattern agree. A simple same-row gap threshold incorrectly unions sibling
  /// fields (and photo-box cells) that happen to share a baseline.
  private static func adjacentCellGroups(_ boxes: [PDFRect]) -> [[PDFRect]] {
    guard !boxes.isEmpty else { return [] }

    let unique = Array(Set(boxes))
    let topTolerance: CGFloat = 0.5
    let bottomTolerance: CGFloat = 0.5
    let heightTolerance: CGFloat = 0.7
    var bands: [[PDFRect]] = []

    for box in unique {
      let rect = box.cgRect
      if let bandIndex = bands.firstIndex(where: { band in
        band.contains { other in
          let otherRect = other.cgRect
          return abs(rect.minY - otherRect.minY) <= topTolerance
            && abs(rect.maxY - otherRect.maxY) <= bottomTolerance
            && abs(rect.height - otherRect.height) <= heightTolerance
        }
      }) {
        bands[bandIndex].append(box)
      } else {
        bands.append([box])
      }
    }

    func median(_ values: [CGFloat]) -> CGFloat {
      guard !values.isEmpty else { return 0 }
      let sorted = values.sorted()
      let middle = sorted.count / 2
      if sorted.count.isMultiple(of: 2) {
        return (sorted[middle - 1] + sorted[middle]) / 2
      }
      return sorted[middle]
    }

    let widthTolerance: CGFloat = 0.7
    var groups: [[PDFRect]] = []
    for band in bands {
      let sorted = band.sorted { $0.cgRect.minX < $1.cgRect.minX }
      guard let first = sorted.first else { continue }

      var signatureRuns: [[PDFRect]] = []
      var current = [first]
      var currentWidth = first.cgRect.width
      for box in sorted.dropFirst() {
        guard let previous = current.last else { continue }
        let previousRect = previous.cgRect
        let rect = box.cgRect
        let gap = rect.minX - previousRect.maxX
        let widthDelta = abs(rect.width - currentWidth)
        let continues = widthDelta <= widthTolerance
          && abs(rect.height - previousRect.height) <= heightTolerance
          && gap <= max(8, previousRect.width * 0.6)
        if continues {
          current.append(box)
        } else {
          signatureRuns.append(current)
          current = [box]
          currentWidth = rect.width
        }
      }
      signatureRuns.append(current)

      for signatureRun in signatureRuns {
        let sortedRun = signatureRun.sorted { $0.cgRect.minX < $1.cgRect.minX }
        guard let firstRunCell = sortedRun.first else { continue }
        var fieldRuns: [[PDFRect]] = []
        var run = [firstRunCell]
        var runGaps: [CGFloat] = []

        for box in sortedRun.dropFirst() {
          guard let previous = run.last else { continue }
          let previousRect = previous.cgRect
          let gap = box.cgRect.minX - previousRect.maxX
          if run.count == 1 {
            let tight = gap >= -1 && gap <= max(8, previousRect.width * 0.5)
            if tight {
              run.append(box)
              runGaps.append(gap)
            } else {
              fieldRuns.append(run)
              run = [box]
              runGaps = []
            }
            continue
          }

          let threshold = max(median(runGaps) * 4, 8, previousRect.width * 0.5)
          if gap >= -1 && gap <= threshold {
            run.append(box)
            runGaps.append(gap)
          } else {
            fieldRuns.append(run)
            run = [box]
            runGaps = []
          }
        }
        fieldRuns.append(run)
        for fieldRun in fieldRuns where fieldRun.count >= 3 {
          groups.append(fieldRun)
        }
      }
    }
    return groups
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
