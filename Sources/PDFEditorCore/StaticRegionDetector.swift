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
  /// OCR output below this Vision confidence is discarded rather than merged as
  /// label evidence. The floor mirrors the CV geometry provider's default.
  public static let ocrConfidenceFloor: Double = 0.35

  /// Builds OCR-origin candidates with preserved provenance.
  ///
  /// OCR text is supporting evidence, never a field contract: candidates carry
  /// the `.ocrRegion` kind, a score derived from (and capped by) recognition
  /// confidence, and the observed text plus confidence in the evidence list.
  /// The same conservative blank/label gate as text detection applies so OCR
  /// noise does not flood the review queue.
  public static func detectOCR(
    observations: [OCRObservation],
    pageIndex: Int,
    pageBounds: PDFRect
  ) -> [RegionCandidate] {
    observations
      .filter { $0.confidence >= ocrConfidenceFloor }
      .compactMap { observation -> RegionCandidate? in
        let normalized = observation.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let hasBlankMarker = normalized.contains("_")
        let looksLikeLabel = normalized.hasSuffix(":")
        guard hasBlankMarker || looksLikeLabel else { return nil }
        let line = observation.toPageSpace(pageBounds: pageBounds, pageIndex: pageIndex)
        // An OCR line that merges label and blank markers highlights only the
        // blank run, mirroring the text-anchored refinement.
        let bounds: PDFRect
        if hasBlankMarker,
          let blankBounds = blankRunBounds(in: normalized, lineBounds: line.bounds)
        {
          bounds = blankBounds
        } else {
          bounds = line.bounds
        }
        return RegionCandidate(
          pageIndex: pageIndex,
          bounds: bounds,
          kind: .ocrRegion,
          score: min(0.6, observation.confidence * 0.6),
          evidence: [
            "Vision OCR text: \(normalized)",
            String(
              format: "confidence %.2f (floor %.2f)", observation.confidence, ocrConfidenceFloor),
            "OCR is evidence, not a field contract.",
          ]
        )
      }
  }

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
      let fieldLabelLines = likelyFieldLabelLines(from: pageLines)

      // Character-entry forms often encode every cell as a separate
      // rectangle. Group those cells before assigning semantics so a
      // name field becomes one reviewable region rather than a queue of
      // checkbox-shaped false positives.
      let smallBoxes = smallCellBoxes(
        checkboxes: geom.potentialCheckboxes,
        inputBoxes: geom.potentialInputBoxes
      )
      for originalGroup in adjacentCellGroups(smallBoxes) {
        // A stray wide rectangle sharing the row signature would balloon the
        // union bounds past the user's intended field; split it off first.
        let (keptGroup, removedOutliers) = splittingOutliers(from: originalGroup)
        guard keptGroup.count >= 3 else { continue }
        let group = keptGroup
        let region = union(of: group)
        // Repeated geometry is not field intent by itself. Require a
        // semantically plausible label before promoting a grid to a review
        // candidate; unlabeled grids remain raw geometry evidence.
        guard let nearbyLabel = findNearestLabel(
          for: region, in: fieldLabelLines, maxDistance: 160.0)
        else { continue }
        let labelText: String? = nearbyLabel.text
        let inferredType = inferFieldType(from: labelText ?? "")
        let mode = entryMode(for: inferredType, isGrouped: true)
        var evidenceStrings = [
          "Grouped \(group.count) adjacent boxes into one \(mode.displayName.lowercased()) region.",
          "Repeated cell geometry supports a single logical entry area.",
        ]
        if removedOutliers > 0 {
          evidenceStrings.append(
            "Split \(removedOutliers) width-signature outlier(s) from the group.")
        }
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
            memberLabels:
              mode == .checkbox || mode == .radioGroup
              ? optionLabels(for: group, in: pageLines)
              : [],
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
        guard let nearbyLabel = findNearestLabel(
          for: box, in: fieldLabelLines, maxDistance: 120.0) else {
          continue
        }
        // Character-entry grids and decorative squares are common PDF
        // geometry. Without label evidence, treating every tiny square
        // as a checkbox creates an unusable review queue.
        guard !claimedVectorBoxes.contains(box), box.height >= 8 else {
          continue
        }
        // A square drawn over dense static text is page decoration (a photo
        // box or section border), not a fillable cell.
        let checkboxInteriorCoverage = interiorTextCoverage(
          of: box, in: pageLines, excluding: nearbyLabel)
        guard checkboxInteriorCoverage <= 0.40 else { continue }
        var evidenceStrings = [
          "Vector checkbox geometry detected (\(Int(box.width))x\(Int(box.height))pt).",
          "Associated label: \"\(nearbyLabel.text.trimmingCharacters(in: .whitespacesAndNewlines))\"",
        ]

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
            labelText: nearbyLabel.text.trimmingCharacters(in: .whitespacesAndNewlines),
            groupMemberCount: 1,
            memberBounds: [box],
            memberLabels: optionLabels(for: [box], in: pageLines),
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
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: nearbyLabel.text,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: nearbyLabel.text,
                score: 0.72
              ),
            ]
          )
        )
        claimedVectorBoxes.insert(box)
      }

            // B. Larger input boxes (table cells, form blanks)
      for box in geom.potentialInputBoxes {
        guard let nearbyLabel = findNearestLabel(
          for: box, in: fieldLabelLines, maxDistance: 160.0) else {
          continue
        }
        // Defer unlabeled character cells to grouped-layout detection;
        // a single cell is not a useful text-entry suggestion.
        guard !claimedVectorBoxes.contains(box), box.height >= 8 else {
          continue
        }
        // Rectangles whose interior is mostly static text are decorative
        // panels or borders; a fillable entry area is empty inside.
        let coverage = interiorTextCoverage(
          of: box, in: pageLines, excluding: nearbyLabel)
        guard coverage <= 0.40 else { continue }
        let inferredType = inferFieldType(from: nearbyLabel.text)
        var evidenceStrings = ["Vector bounding box (\(Int(box.width))x\(Int(box.height))pt)."]

        let score = 0.80
        evidenceStrings.append(
            "Associated label: \"\(nearbyLabel.text.trimmingCharacters(in: .whitespacesAndNewlines))\"")

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
            labelText: nearbyLabel.text.trimmingCharacters(in: .whitespacesAndNewlines),
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
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: nearbyLabel.text,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: nearbyLabel.text,
                score: 0.72
              ),
            ]
          )
        )
        claimedVectorBoxes.insert(box)
      }

            // C. Underlines from vector stream
      for line in geom.potentialUnderlines {
        // Provisional band used only to locate the associated label; the
        // final band height derives from the label's own line metrics so the
        // suggestion matches the real writing area instead of a fixed 18 pt.
        let searchBox = PDFRect(x: line.x, y: line.y, width: line.width, height: 18.0)
        guard let nearbyLabel = findNearestLabel(
          for: searchBox, in: fieldLabelLines, maxDistance: 120.0)
        else { continue }
        let bandHeight = min(26.0, max(10.0, nearbyLabel.bounds.height * 1.35))
        let boxAbove = PDFRect(
          x: line.x, y: line.y, width: line.width, height: bandHeight)
        let inferredType = inferFieldType(from: nearbyLabel.text)
        var evidenceStrings = [
          "Vector underline stroke detected (\(Int(line.width))pt).",
          String(
            format: "Entry band height derived from label line metrics (%.1fpt).",
            bandHeight),
          "Associated label: \"\(nearbyLabel.text.trimmingCharacters(in: .whitespacesAndNewlines))\"",
        ]

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
            labelText: nearbyLabel.text.trimmingCharacters(in: .whitespacesAndNewlines),
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
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: nearbyLabel.text,
                score: 0.72
              ),
              CandidateEvidence(
                kind: .spatialRelationship,
                origin: .textExtraction,
                summary: "Label matched by page-space proximity",
                region: PDFPageRegion(pageIndex: geom.pageIndex, rect: nearbyLabel.bounds),
                text: nearbyLabel.text,
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
      let pageLines = pageLinesByIndex[line.pageIndex] ?? []
      let pageRight: CGFloat
      if let pageGeometry = vectorGeometries.first(where: { $0.pageIndex == line.pageIndex }) {
        pageRight = pageGeometry.mediaBox.maxX
      } else {
        pageRight = line.bounds.x + line.bounds.width + 228
      }

      // A line with an underscore blank run highlights only the blank run,
      // never the static label words sitting next to it.
      var candidateBounds = line.bounds
      var boundsEvidence: [String] = []
      if containsUnderline,
        let blankBounds = blankRunBounds(in: normalized, lineBounds: line.bounds)
      {
        candidateBounds = blankBounds
        boundsEvidence = ["Blank-run isolated from label text within the line."]
      } else if looksLikeLabel {
        // Colon-label entries synthesize whitespace after the label. Clip the
        // synthesized width to the nearest same-row text run so the box can
        // no longer overflow into a neighboring column.
        let proposedX = line.bounds.x + line.bounds.width + 8
        let proposedWidth = max(0, min(220, pageRight - proposedX - 20))
        let clippedWidth = clippedWhitespaceWidth(
          for: PDFRect(
            x: proposedX, y: line.bounds.y, width: proposedWidth, height: line.bounds.height),
          pageLines: pageLines,
          labelLine: line)
        let usableWidth = min(proposedWidth, clippedWidth)
        guard usableWidth >= 48 else { continue }
        candidateBounds = PDFRect(
          x: proposedX,
          y: line.bounds.y,
          width: usableWidth,
          height: max(14, line.bounds.height + 5)
        )
        boundsEvidence =
          clippedWidth < proposedWidth
          ? ["Entry width clipped to the nearest same-row content."]
          : []
      }

      candidates.append(
        RegionCandidate(
          pageIndex: line.pageIndex,
          bounds: candidateBounds,
          kind: kind,
          status: .suggested,
          score: score,
          evidence: evidence + boundsEvidence,
          coordinate: PDFPageRegion(pageIndex: line.pageIndex, rect: candidateBounds),
          suggestedFieldType: inferredType,
          entryMode: entryMode(for: inferredType, isGrouped: false),
          labelText: normalized,
          evidenceItems: [
            CandidateEvidence(
              kind: .whitespace,
              origin: .textExtraction,
              summary: "Whitespace adjacent to a semantically plausible label",
              region: PDFPageRegion(pageIndex: line.pageIndex, rect: candidateBounds),
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

  private static func likelyFieldLabelLines(from lines: [TextLineEvidence])
    -> [TextLineEvidence]
  {
    lines.filter { line in
      let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
      return text.count > 1 && isLikelyFieldLabel(text)
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
    var result: [PDFRect] = []
    result.reserveCapacity(min(checkboxes.count + inputBoxes.count, 256))
    result.append(contentsOf: checkboxes)
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

    let unique = stableUnique(boxes)
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

  /// Splits a group of boxes into kept boxes and removed outliers based on
  /// width deviation. Boxes that are significantly wider than the median
  /// are removed as potential decorative elements.
  private static func splittingOutliers(from group: [PDFRect]) -> (kept: [PDFRect], removed: Int) {
    guard group.count >= 3 else { return (group, 0) }
    let widths = group.map { $0.width }.sorted()
    let median = widths[widths.count / 2]
    let threshold = median * 1.5
    let kept = group.filter { $0.width <= threshold }
    return (kept, group.count - kept.count)
  }

  private static func stableUnique(_ boxes: [PDFRect]) -> [PDFRect] {
    let reserveHint = min(boxes.count, 256)
    var unique: [PDFRect] = []
    unique.reserveCapacity(reserveHint)
    var seen = Set<PDFRect>()
    seen.reserveCapacity(reserveHint)

    for box in boxes where seen.insert(box).inserted {
      unique.append(box)
    }
    return unique
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

  // MARK: - Geometry refinement (bounds fidelity)

  /// Isolates the fillable portion of a text line that contains an
  /// underscore blank run ("Full Name: ______").
  ///
  /// Glyph-level projection is unavailable in this pure core layer, so the
  /// blank-run x-extent is interpolated proportionally from character
  /// offsets. Underscores have near-uniform advance widths, which keeps the
  /// estimate close to the true run while never covering the static label
  /// words — the defect this replaces was highlighting the entire line.
  public static func blankRunBounds(in text: String, lineBounds: PDFRect) -> PDFRect? {
    guard let range = text.range(of: "_{3,}", options: .regularExpression) else {
      return nil
    }
    let total = max(1, text.count)
    let startOffset = text.distance(from: text.startIndex, to: range.lowerBound)
    let runLength = text.distance(from: range.lowerBound, to: range.upperBound)
    let charWidth = lineBounds.width / CGFloat(total)
    let x = lineBounds.x + CGFloat(startOffset) * charWidth
    let width = max(12.0, CGFloat(runLength) * charWidth)
    return PDFRect(x: x, y: lineBounds.y, width: width, height: lineBounds.height)
  }

  /// Clips a synthesized whitespace-entry width to the nearest text run on
  /// the same visual row so the suggestion cannot overflow into a neighboring
  /// column or content block.
  static func clippedWhitespaceWidth(
    for rect: PDFRect,
    pageLines: [TextLineEvidence],
    labelLine: TextLineEvidence
  ) -> CGFloat {
    let top = rect.y + rect.height
    var limit: CGFloat = rect.width
    for line in pageLines {
      if line.bounds == labelLine.bounds && line.text == labelLine.text { continue }
      let lineTop = line.bounds.y + line.bounds.height
      // Only runs whose vertical span overlaps the entry band constrain it.
      guard line.bounds.y < top - 1, lineTop > rect.y + 1 else { continue }
      // Only runs starting to the right of the label matter.
      guard line.bounds.x >= labelLine.bounds.x + labelLine.bounds.width else { continue }
      let available = line.bounds.x - 8.0 - rect.x
      if available >= 0 && available < limit {
        limit = available
      }
    }
    return max(0, limit)
  }

  /// Fraction of a box's interior covered by static text runs other than its
  /// associated label. Decorative rectangles (photo boxes, section borders)
  /// sit over dense text; genuine entry areas are empty.
  static func interiorTextCoverage(
    of box: PDFRect,
    in lines: [TextLineEvidence],
    excluding excluded: TextLineEvidence?
  ) -> CGFloat {
    guard box.width > 0, box.height > 0 else { return 0 }
    let boxRect = box.cgRect
    var covered: CGFloat = 0
    for line in lines {
      if let excluded, line == excluded { continue }
      let intersection = line.bounds.cgRect.intersection(boxRect)
      if !intersection.isNull {
        covered += intersection.width * intersection.height
      }
    }
    return covered / (box.width * box.height)
  }

  /// Extracts one option name per choice-cell from the static text adjacent
  /// to each cell ("☐ Yes ☐ No" → ["Yes", "No"]). Right-side neighbors win
  /// because standard forms place option text after the cell; left side is a
  /// fallback for trailing-label layouts.
  public static func optionLabels(
    for members: [PDFRect],
    in lines: [TextLineEvidence]
  ) -> [String] {
    members.sorted { $0.x < $1.x }.map { member in
      let memberRect = member.cgRect
      var best: TextLineEvidence?
      var bestDistance: CGFloat = 120.0
      for line in lines {
        let lineRect = line.bounds.cgRect
        let baselineOverlap =
          abs(lineRect.midY - memberRect.midY) <= max(memberRect.height * 0.75, 8.0)
        guard baselineOverlap else { continue }
        let gapRight = lineRect.minX - memberRect.maxX
        let gapLeft = memberRect.minX - lineRect.maxX
        if gapRight >= -1 && gapRight < bestDistance {
          bestDistance = gapRight
          best = line
        } else if gapRight < -1 && gapLeft >= -1 && gapLeft < bestDistance {
          bestDistance = gapLeft
          best = line
        }
      }
      return best.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
    }
  }

  /// Splits outlier-width members out of a grouped cell run so one stray wide
  /// rectangle cannot balloon the union bounds over neighboring content.
  static func medianValue(_ values: [CGFloat]) -> CGFloat? {
    guard !values.isEmpty else { return nil }
    let sortedValues = values.sorted()
    let middle = sortedValues.count / 2
    if sortedValues.count.isMultiple(of: 2) {
      return (sortedValues[middle - 1] + sortedValues[middle]) / 2
    }
    return sortedValues[middle]
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
