import Foundation

/// Merges two annotation layers (local + partner) into a unified set.
///
/// First principle: merge is additive — we never delete marks from either side.
/// Conflicts are presented to the user for resolution, not auto-resolved.
///
/// Three categories of merge outcomes:
/// 1. **Unique to local** — keep as-is
/// 2. **Unique to partner** — keep as-is (imported)
/// 3. **Conflicting** — both sides annotated the same region; present for resolution
///
/// Matching strategy:
/// - **Exact match**: same page + same bounds + same type → same mark
///   - If both have the same mark: keep one (deduplicate)
///   - If both have same region but different type/content: conflict
/// - **Overlap match**: same page + overlapping bounds (>50%) → potential conflict
/// - **Text match**: same page + same selectedText → may be the same mark in different positions
///
/// Doctrine alignment:
/// - §3: Do things smartly — deterministic merge, no data loss
/// - §5: Evidence-based — merge produces a conflict report with full evidence
/// - §8: Capability activation — merge is explicit, user-driven

// MARK: - Merge Result

/// The result of merging two annotation layers.
public struct AnnotationMergeResult: Sendable {
  /// Marks that exist only in the local layer (kept as-is).
  public let localOnly: [AnnotationMark]
  /// Marks that exist only in the partner layer (imported).
  public let partnerOnly: [AnnotationMark]
  /// Marks that are identical in both layers (deduplicated, one copy kept).
  public let duplicates: [AnnotationMark]
  /// Conflicts that need user resolution.
  public let conflicts: [AnnotationConflict]
  /// The final merged set (before conflict resolution).
  public var mergedMarks: [AnnotationMark] {
    localOnly + partnerOnly + duplicates + conflicts.map(\.resolvedMark)
  }

  public var summary: MergeSummary {
    MergeSummary(
      localOnlyCount: localOnly.count,
      partnerOnlyCount: partnerOnly.count,
      duplicateCount: duplicates.count,
      conflictCount: conflicts.count,
      totalCount: mergedMarks.count
    )
  }
}

// MARK: - Merge Summary

public struct MergeSummary: Sendable {
  public let localOnlyCount: Int
  public let partnerOnlyCount: Int
  public let duplicateCount: Int
  public let conflictCount: Int
  public let totalCount: Int

  public var description: String {
    "\(totalCount) marks total: \(localOnlyCount) yours, \(partnerOnlyCount) theirs, \(duplicateCount) shared, \(conflictCount) conflicts"
  }

  public var hasConflicts: Bool { conflictCount > 0 }
}

// MARK: - Annotation Conflict

/// A conflict between two annotations that annotate the same region.
public struct AnnotationConflict: Sendable, Identifiable {
  public let id = UUID()
  /// The local annotation.
  public let localMark: AnnotationMark
  /// The partner's annotation.
  public let partnerMark: AnnotationMark
  /// Why these two marks are considered conflicting.
  public let reason: ConflictReason
  /// The currently selected resolution.
  public var resolution: ConflictResolution
  /// Auto-suggested resolution based on conflict analysis.
  public let suggestedResolution: ConflictResolution
  /// Human-readable explanation of why the suggestion was made.
  public let hintExplanation: String
  /// Confidence in the suggestion (0.0–1.0).
  public let hintConfidence: Double
  /// The mark to use in the final merge based on the current resolution.
  public var resolvedMark: AnnotationMark {
    switch resolution {
    case .keepLocal: return localMark
    case .keepPartner: return partnerMark
    case .keepBoth: return localMark // Both are added separately
    case .merge: return mergedMark
    }
  }

  /// Merged mark combining both (for .merge resolution).
  private var mergedMark: AnnotationMark {
    // Combine notes, keep local bounds/type/color
    let combinedNote: String
    if localMark.note.isEmpty && partnerMark.note.isEmpty {
      combinedNote = ""
    } else if localMark.note.isEmpty {
      combinedNote = partnerMark.note
    } else if partnerMark.note.isEmpty {
      combinedNote = localMark.note
    } else {
      combinedNote = "\(localMark.note)\n---\n\(partnerMark.note)"
    }

    // Combine tags
    let combinedTags = Array(Set(localMark.tags + partnerMark.tags)).sorted()

    return AnnotationMark(
      type: localMark.type,
      pageIndex: localMark.pageIndex,
      bounds: localMark.bounds,
      selectedText: localMark.selectedText.isEmpty ? partnerMark.selectedText : localMark.selectedText,
      note: combinedNote,
      color: localMark.color,
      tags: combinedTags
    )
  }
}

// MARK: - Conflict Reason

/// Why two marks are considered conflicting.
public enum ConflictReason: Sendable {
  /// Same page + same bounds + same type but different content.
  case sameRegionDifferentContent
  /// Same page + overlapping bounds (>50%).
  case overlappingBounds(Double)
  /// Same page + same selected text but different positions.
  case sameTextDifferentPosition
  /// Same page + same note content.
  case sameNoteContent

  public var description: String {
    switch self {
    case .sameRegionDifferentContent: return "Same region, different content"
    case .overlappingBounds(let overlap):
      return "Overlapping regions (\(Int(overlap * 100))% overlap)"
    case .sameTextDifferentPosition: return "Same text at different positions"
    case .sameNoteContent: return "Same note content"
    }
  }
}

// MARK: - Conflict Resolution

/// How to resolve a conflict.
public enum ConflictResolution: String, Codable, Sendable, CaseIterable, Identifiable {
  /// Keep the local mark.
  case keepLocal = "keepLocal"
  /// Keep the partner's mark.
  case keepPartner = "keepPartner"
  /// Keep both marks (additive).
  case keepBoth = "keepBoth"
  /// Merge notes and tags into one mark.
  case merge = "merge"

  public var id: String { rawValue }
  public var displayName: String {
    switch self {
    case .keepLocal: return "Keep Mine"
    case .keepPartner: return "Keep Theirs"
    case .keepBoth: return "Keep Both"
    case .merge: return "Merge"
    }
  }
}

// MARK: - Annotation Merger

/// Merges two annotation layers with conflict detection.
public struct AnnotationMerger {

  /// Merge local and partner annotations.
  ///
  /// - Parameters:
  ///   - local: The local annotation marks.
  ///   - partner: The partner's annotation marks.
  ///   - tolerance: Overlap threshold for bounds matching (0.0–1.0, default 0.5).
  /// - Returns: A merge result with categorized marks and conflicts.
  public static func merge(
    local: [AnnotationMark],
    partner: [AnnotationMark],
    tolerance: Double = 0.5
  ) -> AnnotationMergeResult {
    var localOnly: [AnnotationMark] = []
    var partnerOnly: [AnnotationMark] = []
    var duplicates: [AnnotationMark] = []
    var conflicts: [AnnotationConflict] = []

    var matchedPartnerIndices = Set<Int>()

    for localMark in local {
      var foundMatch = false

      for (partnerIndex, partnerMark) in partner.enumerated() {
        guard !matchedPartnerIndices.contains(partnerIndex) else { continue }
        guard localMark.pageIndex == partnerMark.pageIndex else { continue }

        let matchType = classifyMatch(local: localMark, partner: partnerMark, tolerance: tolerance)

        switch matchType {
        case .exact:
          // Same mark — deduplicate, keep local
          duplicates.append(localMark)
          matchedPartnerIndices.insert(partnerIndex)
          foundMatch = true
          break

        case .conflict(let reason):
          // Same region but different — conflict
          let hint = ConflictResolutionHint.analyze(
            local: localMark, partner: partnerMark, reason: reason
          )
          conflicts.append(AnnotationConflict(
            localMark: localMark,
            partnerMark: partnerMark,
            reason: reason,
            resolution: hint.suggested,
            suggestedResolution: hint.suggested,
            hintExplanation: hint.explanation,
            hintConfidence: hint.confidence
          ))
          matchedPartnerIndices.insert(partnerIndex)
          foundMatch = true
          break

        case .none:
          continue
        }

        if foundMatch { break }
      }

      if !foundMatch {
        localOnly.append(localMark)
      }
    }

    // Remaining partner marks are unique to partner
    for (index, partnerMark) in partner.enumerated() {
      if !matchedPartnerIndices.contains(index) {
        partnerOnly.append(partnerMark)
      }
    }

    return AnnotationMergeResult(
      localOnly: localOnly,
      partnerOnly: partnerOnly,
      duplicates: duplicates,
      conflicts: conflicts
    )
  }
}

// MARK: - Match Classification

/// The result of comparing two individual marks.
enum MatchClassification {
  /// Exact match — same mark, deduplicate.
  case exact
  /// Conflicting marks in the same region.
  case conflict(ConflictReason)
  /// No match.
  case none
}

// MARK: - Matching Logic

extension AnnotationMerger {

  /// Classify the relationship between two marks on the same page.
  static func classifyMatch(
    local: AnnotationMark,
    partner: AnnotationMark,
    tolerance: Double
  ) -> MatchClassification {
    // 1. Exact bounds + type match → deduplicate
    if local.bounds == partner.bounds && local.type == partner.type {
      // If content is also identical, it's a true duplicate
      if local.selectedText == partner.selectedText && local.note == partner.note {
        return .exact
      }
      // Same region, same type, different content → conflict
      return .conflict(.sameRegionDifferentContent)
    }

    // 2. Overlapping bounds (>tolerance) → conflict
    if local.type == partner.type || local.type == .highlight || partner.type == .highlight {
      let overlap = Self.boundsOverlap(local.bounds, partner.bounds)
      if overlap > tolerance {
        return .conflict(.overlappingBounds(overlap))
      }
    }

    // 3. Same selected text on same page → possible conflict
    if !local.selectedText.isEmpty,
       local.selectedText == partner.selectedText {
      return .conflict(.sameTextDifferentPosition)
    }

    // 4. Same note content on same page → possible conflict
    if !local.note.isEmpty,
       local.note == partner.note {
      return .conflict(.sameNoteContent)
    }

    return .none
  }

  /// Calculate the overlap ratio between two rects (0.0 = no overlap, 1.0 = identical).
  static func boundsOverlap(_ a: PDFRect, _ b: PDFRect) -> Double {
    let interLeft = max(a.x, b.x)
    let interTop = max(a.y, b.y)
    let interRight = min(a.x + a.width, b.x + b.width)
    let interBottom = min(a.y + a.height, b.y + b.height)

    let interArea = max(0, interRight - interLeft) * max(0, interBottom - interTop)
    let minArea = min(a.width * a.height, b.width * b.height)

    guard minArea > 0 else { return 0 }
    return interArea / minArea
  }
}

// MARK: - Conflict Resolution Hint

/// Result of conflict resolution analysis.
public struct ConflictResolutionHint: Sendable {
  /// The suggested resolution.
  public let suggested: ConflictResolution
  /// Human-readable explanation.
  public let explanation: String
  /// Confidence in the suggestion (0.0–1.0).
  public let confidence: Double

  public init(suggested: ConflictResolution, explanation: String, confidence: Double) {
    self.suggested = suggested
    self.explanation = explanation
    self.confidence = confidence
  }
}

/// Analyzes a conflict between two marks and suggests a resolution.
///
/// Heuristics (ordered by priority):
/// 1. High spatial separation → keepBoth (independent annotations)
/// 2. Same selected text, different notes → merge (complementary content)
/// 3. Same note content, different text → keepBoth (same idea, different context)
/// 4. High bounds overlap with different content → keepLocal (conservative default)
/// 5. Overlapping bounds (>50%) → keepLocal (conservative default)
public extension ConflictResolutionHint {

  static func analyze(
    local: AnnotationMark,
    partner: AnnotationMark,
    reason: ConflictReason
  ) -> ConflictResolutionHint {
    switch reason {
    case .sameRegionDifferentContent:
      return analyzeSameRegion(local: local, partner: partner)
    case .overlappingBounds(let overlap):
      return analyzeOverlapping(local: local, partner: partner, overlap: overlap)
    case .sameTextDifferentPosition:
      return analyzeSameText(local: local, partner: partner)
    case .sameNoteContent:
      return analyzeSameNote(local: local, partner: partner)
    }
  }

  // MARK: - Private Heuristics

  /// Same region, different content — analyze what differs.
  private static func analyzeSameRegion(
    local: AnnotationMark, partner: AnnotationMark
  ) -> ConflictResolutionHint {
    let boundsDistance = centerDistance(local.bounds, partner.bounds)
    let sameType = local.type == partner.type
    let sameColor = local.color == partner.color
    let textOverlap = textSimilarity(local.selectedText, partner.selectedText)
    let noteOverlap = textSimilarity(local.note, partner.note)

    // High spatial separation → keepBoth (independent annotations on same region)
    if boundsDistance > 50 {
      return ConflictResolutionHint(
        suggested: .keepBoth,
        explanation: "Marks are \(Int(boundsDistance))pt apart — likely independent annotations",
        confidence: 0.85
      )
    }

    // Same text, different notes → merge (complementary content)
    if textOverlap > 0.8 && noteOverlap < 0.5 {
      return ConflictResolutionHint(
        suggested: .merge,
        explanation: "Same highlighted text with different notes — merging preserves both insights",
        confidence: 0.80
      )
    }

    // Same note, different text → keepBoth
    if noteOverlap > 0.5 && textOverlap < 0.5 {
      return ConflictResolutionHint(
        suggested: .keepBoth,
        explanation: "Same note on different text — both annotations capture the same idea",
        confidence: 0.75
      )
    }

    // Same type and color, similar text → merge
    if sameType && sameColor && textOverlap > 0.5 {
      return ConflictResolutionHint(
        suggested: .merge,
        explanation: "Same type/color with similar text — merging combines the annotations",
        confidence: 0.70
      )
    }

    // Default: keepLocal (conservative)
    return ConflictResolutionHint(
      suggested: .keepLocal,
      explanation: "Overlapping marks with different content — keeping local as default",
      confidence: 0.50
    )
  }

  /// Overlapping bounds — analyze degree of overlap.
  private static func analyzeOverlapping(
    local: AnnotationMark, partner: AnnotationMark, overlap: Double
  ) -> ConflictResolutionHint {
    let textOverlap = textSimilarity(local.selectedText, partner.selectedText)

    // Very high overlap + similar text → merge
    if overlap > 0.8 && textOverlap > 0.5 {
      return ConflictResolutionHint(
        suggested: .merge,
        explanation: "\(Int(overlap * 100))% overlap with similar text — merge combines both",
        confidence: 0.85
      )
    }

    // High overlap but different text → keepLocal
    if overlap > 0.7 {
      return ConflictResolutionHint(
        suggested: .keepLocal,
        explanation: "\(Int(overlap * 100))% overlap with different text — keeping local",
        confidence: 0.75
      )
    }

    // Moderate overlap → keepBoth (spatially distinct enough)
    return ConflictResolutionHint(
      suggested: .keepBoth,
      explanation: "\(Int(overlap * 100))% overlap — marks are distinct enough to keep both",
      confidence: 0.65
    )
  }

  /// Same text at different positions — analyze why.
  private static func analyzeSameText(
    local: AnnotationMark, partner: AnnotationMark
  ) -> ConflictResolutionHint {
    let boundsDistance = centerDistance(local.bounds, partner.bounds)
    let sameType = local.type == partner.type

    // Far apart + same type → keepBoth (same concept highlighted twice)
    if boundsDistance > 30 && sameType {
      return ConflictResolutionHint(
        suggested: .keepBoth,
        explanation: "Same text \(Int(boundsDistance))pt apart — both instances are independently marked",
        confidence: 0.80
      )
    }

    // Close together + same type → merge (likely duplicate)
    if boundsDistance <= 30 && sameType {
      return ConflictResolutionHint(
        suggested: .merge,
        explanation: "Same text, same type, close together — likely duplicate, merging",
        confidence: 0.75
      )
    }

    // Different types → keepBoth
    return ConflictResolutionHint(
      suggested: .keepBoth,
      explanation: "Same text marked differently — both interpretations are valuable",
      confidence: 0.70
    )
  }

  /// Same note content — analyze why.
  private static func analyzeSameNote(
    local: AnnotationMark, partner: AnnotationMark
  ) -> ConflictResolutionHint {
    let textOverlap = textSimilarity(local.selectedText, partner.selectedText)
    let boundsDistance = centerDistance(local.bounds, partner.bounds)

    // Same text + same note → deduplicate (should have been caught, but safety net)
    if textOverlap > 0.9 {
      return ConflictResolutionHint(
        suggested: .keepLocal,
        explanation: "Nearly identical text and notes — likely a duplicate",
        confidence: 0.85
      )
    }

    // Different text + same note + far apart → keepBoth
    if boundsDistance > 30 {
      return ConflictResolutionHint(
        suggested: .keepBoth,
        explanation: "Same note on different text, \(Int(boundsDistance))pt apart — different contexts",
        confidence: 0.80
      )
    }

    // Different text + same note + close → merge
    return ConflictResolutionHint(
      suggested: .merge,
      explanation: "Same note on nearby text — merging captures both contexts",
      confidence: 0.70
    )
  }

  // MARK: - Helpers

  /// Distance between centers of two rects.
  private static func centerDistance(_ a: PDFRect, _ b: PDFRect) -> Double {
    let ax = a.x + a.width / 2
    let ay = a.y + a.height / 2
    let bx = b.x + b.width / 2
    let by = b.y + b.height / 2
    return sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
  }

  /// Jaccard similarity of two strings (word-level).
  private static func textSimilarity(_ a: String, _ b: String) -> Double {
    guard !a.isEmpty || !b.isEmpty else { return 1.0 }
    guard !a.isEmpty, !b.isEmpty else { return 0.0 }
    let wordsA = Set(a.lowercased().split(separator: " ").map(String.init))
    let wordsB = Set(b.lowercased().split(separator: " ").map(String.init))
    let intersection = wordsA.intersection(wordsB)
    let union = wordsA.union(wordsB)
    guard !union.isEmpty else { return 0.0 }
    return Double(intersection.count) / Double(union.count)
  }
}
