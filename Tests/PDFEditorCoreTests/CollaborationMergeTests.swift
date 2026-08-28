import Foundation
import Testing
@testable import PDFEditorCore

@Suite("CollaborationMerge")
struct CollaborationMergeTests {

  // MARK: - DocumentIdentity

  @Test("DocumentIdentity isSameDocument compares content hashes")
  func identityComparison() {
    let a = DocumentIdentity(contentHash: "abc123", fileName: "doc.pdf", pageCount: 10, fileSize: 1000)
    let b = DocumentIdentity(contentHash: "abc123", fileName: "renamed.pdf", pageCount: 10, fileSize: 1000)
    let c = DocumentIdentity(contentHash: "def456", fileName: "doc.pdf", pageCount: 10, fileSize: 1000)
    #expect(a.isSameDocument(as: b))
    #expect(!a.isSameDocument(as: c))
  }

  @Test("DocumentIdentity displayIdentity uses title or filename")
  func identityDisplay() {
    let withTitle = DocumentIdentity(contentHash: "abc123", fileName: "doc.pdf", pageCount: 5, fileSize: 1000, title: "My Report")
    #expect(withTitle.displayIdentity.contains("My Report"))
    #expect(withTitle.displayIdentity.contains("5 pages"))

    let noTitle = DocumentIdentity(contentHash: "abc123", fileName: "doc.pdf", pageCount: 3, fileSize: 500)
    #expect(noTitle.displayIdentity.contains("doc.pdf"))
  }

  // MARK: - Merge: Exact Duplicates

  @Test("Merge deduplicates identical marks")
  func deduplicateIdentical() {
    let mark = makeMark(page: 0, text: "Hello world", type: .highlight)
    let partnerMark = makeMark(page: 0, text: "Hello world", type: .highlight)

    // Override bounds to be identical
    let local = [mark]
    let partner = [AnnotationMark(
      type: partnerMark.type,
      pageIndex: partnerMark.pageIndex,
      bounds: mark.bounds,
      selectedText: partnerMark.selectedText,
      note: partnerMark.note,
      color: partnerMark.color
    )]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.duplicates.count == 1)
    #expect(result.localOnly.isEmpty)
    #expect(result.partnerOnly.isEmpty)
    #expect(result.conflicts.isEmpty)
    #expect(result.summary.duplicateCount == 1)
  }

  // MARK: - Merge: Unique Marks

  @Test("Merge keeps unique marks from both sides")
  func uniqueMarks() {
    let local = [
      makeMark(page: 0, text: "Local mark 1"),
      makeMark(page: 0, text: "Local mark 2", y: 100)
    ]
    let partner = [
      makeMark(page: 1, text: "Partner mark 1"),
      makeMark(page: 2, text: "Partner mark 2")
    ]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.localOnly.count == 2)
    #expect(result.partnerOnly.count == 2)
    #expect(result.duplicates.isEmpty)
    #expect(result.conflicts.isEmpty)
  }

  // MARK: - Merge: Same Region, Different Content

  @Test("Merge detects same region different content as conflict")
  func sameRegionConflict() {
    let bounds = PDFRect(x: 10, y: 20, width: 100, height: 30)
    let local = [makeMark(page: 0, text: "Local text", bounds: bounds, type: .highlight)]
    let partner = [makeMark(page: 0, text: "Partner text", bounds: bounds, type: .highlight)]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.conflicts.count == 1)
    #expect(result.conflicts[0].reason.description.contains("Same region"))
  }

  // MARK: - Merge: Overlapping Bounds

  @Test("Merge detects overlapping bounds as conflict")
  func overlappingBoundsConflict() {
    let localBounds = PDFRect(x: 10, y: 20, width: 100, height: 50)
    let partnerBounds = PDFRect(x: 30, y: 30, width: 100, height: 50) // ~60% overlap
    let local = [makeMark(page: 0, text: "A", bounds: localBounds)]
    let partner = [makeMark(page: 0, text: "B", bounds: partnerBounds)]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.conflicts.count == 1)
    if case .overlappingBounds(let ratio) = result.conflicts[0].reason {
      #expect(ratio > 0.5)
    } else {
      Issue.record("Expected overlappingBounds conflict reason")
    }
  }

  @Test("Merge does not conflict for non-overlapping bounds")
  func nonOverlappingNoConflict() {
    let localBounds = PDFRect(x: 0, y: 0, width: 50, height: 50)
    let partnerBounds = PDFRect(x: 200, y: 200, width: 50, height: 50)
    let local = [makeMark(page: 0, text: "A", bounds: localBounds)]
    let partner = [makeMark(page: 0, text: "B", bounds: partnerBounds)]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.conflicts.isEmpty)
    #expect(result.localOnly.count == 1)
    #expect(result.partnerOnly.count == 1)
  }

  // MARK: - Merge: Same Text, Different Position

  @Test("Merge detects same text at different positions")
  func sameTextConflict() {
    let local = [makeMark(page: 0, text: "Important sentence", y: 10)]
    let partner = [makeMark(page: 0, text: "Important sentence", y: 200)]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.conflicts.count == 1)
    if case .sameTextDifferentPosition = result.conflicts[0].reason {
      // correct
    } else {
      Issue.record("Expected sameTextDifferentPosition conflict reason")
    }
  }

  // MARK: - Merge: Same Note Content

  @Test("Merge detects same note content")
  func sameNoteConflict() {
    // Use non-overlapping bounds so the bounds check doesn't fire first
    let local = [makeMark(page: 0, text: "Different text A", note: "Remember this", bounds: PDFRect(x: 0, y: 0, width: 50, height: 20))]
    let partner = [makeMark(page: 0, text: "Different text B", note: "Remember this", bounds: PDFRect(x: 200, y: 200, width: 50, height: 20))]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.conflicts.count == 1)
    if case .sameNoteContent = result.conflicts[0].reason {
      // correct
    } else {
      Issue.record("Expected sameNoteContent conflict reason, got \(result.conflicts[0].reason.description)")
    }
  }

  // MARK: - Merge: Cross-Page Isolation

  @Test("Marks on different pages never conflict")
  func crossPageIsolation() {
    let local = [makeMark(page: 0, text: "Same text")]
    let partner = [makeMark(page: 1, text: "Same text")]

    let result = AnnotationMerger.merge(local: local, partner: partner)
    #expect(result.conflicts.isEmpty)
    #expect(result.localOnly.count == 1)
    #expect(result.partnerOnly.count == 1)
  }

  // MARK: - Merge: Empty Inputs

  @Test("Merge with empty local returns all partner")
  func emptyLocal() {
    let partner = [makeMark(page: 0, text: "A"), makeMark(page: 1, text: "B")]
    let result = AnnotationMerger.merge(local: [], partner: partner)
    #expect(result.partnerOnly.count == 2)
    #expect(result.localOnly.isEmpty)
  }

  @Test("Merge with empty partner returns all local")
  func emptyPartner() {
    let local = [makeMark(page: 0, text: "A")]
    let result = AnnotationMerger.merge(local: local, partner: [])
    #expect(result.localOnly.count == 1)
    #expect(result.partnerOnly.isEmpty)
  }

  @Test("Merge with both empty")
  func bothEmpty() {
    let result = AnnotationMerger.merge(local: [], partner: [])
    #expect(result.mergedMarks.isEmpty)
    #expect(result.summary.totalCount == 0)
  }

  // MARK: - Bounds Overlap Calculation

  @Test("Bounds overlap returns 1.0 for identical rects")
  func overlapIdentical() {
    let r = PDFRect(x: 10, y: 10, width: 50, height: 50)
    #expect(AnnotationMerger.boundsOverlap(r, r) == 1.0)
  }

  @Test("Bounds overlap returns 0.0 for disjoint rects")
  func overlapDisjoint() {
    let a = PDFRect(x: 0, y: 0, width: 10, height: 10)
    let b = PDFRect(x: 100, y: 100, width: 10, height: 10)
    #expect(AnnotationMerger.boundsOverlap(a, b) == 0.0)
  }

  @Test("Bounds overlap calculates partial overlap correctly")
  func overlapPartial() {
    let a = PDFRect(x: 0, y: 0, width: 100, height: 100)
    let b = PDFRect(x: 50, y: 50, width: 100, height: 100)
    let overlap = AnnotationMerger.boundsOverlap(a, b)
    // Intersection is 50x50 = 2500. Min area is 100x100 = 10000. Ratio = 0.25
    #expect(overlap == 0.25)
  }

  // MARK: - Conflict Resolution

  @Test("Conflict keepLocal resolution returns local mark")
  func resolveKeepLocal() {
    let local = makeMark(page: 0, text: "Local text", y: 10)
    let partner = makeMark(page: 0, text: "Partner text", y: 10)
    let result = AnnotationMerger.merge(
      local: [local],
      partner: [AnnotationMark(
        type: partner.type,
        pageIndex: partner.pageIndex,
        bounds: local.bounds,
        selectedText: partner.selectedText,
        note: partner.note,
        color: partner.color
      )]
    )
    guard let conflict = result.conflicts.first else {
      Issue.record("Expected a conflict")
      return
    }
    var c = conflict
    c.resolution = .keepLocal
    #expect(c.resolvedMark.selectedText == "Local text")
  }

  @Test("Conflict keepPartner resolution returns partner mark")
  func resolveKeepPartner() {
    let local = makeMark(page: 0, text: "Local", y: 10)
    let partner = makeMark(page: 0, text: "Partner", y: 10)
    let result = AnnotationMerger.merge(
      local: [local],
      partner: [AnnotationMark(
        type: partner.type,
        pageIndex: partner.pageIndex,
        bounds: local.bounds,
        selectedText: partner.selectedText,
        note: partner.note,
        color: partner.color
      )]
    )
    guard let conflict = result.conflicts.first else {
      Issue.record("Expected a conflict")
      return
    }
    var c = conflict
    c.resolution = .keepPartner
    #expect(c.resolvedMark.selectedText == "Partner")
  }

  @Test("Conflict merge resolution combines notes")
  func resolveMerge() {
    let local = makeMark(page: 0, text: "Local", note: "Note A", y: 10)
    let partner = makeMark(page: 0, text: "Partner", note: "Note B", y: 10)
    let result = AnnotationMerger.merge(
      local: [local],
      partner: [AnnotationMark(
        type: partner.type,
        pageIndex: partner.pageIndex,
        bounds: local.bounds,
        selectedText: partner.selectedText,
        note: partner.note,
        color: partner.color
      )]
    )
    guard let conflict = result.conflicts.first else {
      Issue.record("Expected a conflict")
      return
    }
    var c = conflict
    c.resolution = .merge
    let merged = c.resolvedMark
    #expect(merged.note.contains("Note A"))
    #expect(merged.note.contains("Note B"))
    #expect(merged.note.contains("---"))
  }

  @Test("Conflict merge combines tags")
  func resolveMergeTags() {
    let local = makeMark(page: 0, text: "A", y: 10, tags: ["important"])
    let partner = makeMark(page: 0, text: "B", y: 10, tags: ["review"])
    let result = AnnotationMerger.merge(
      local: [local],
      partner: [AnnotationMark(
        type: partner.type,
        pageIndex: partner.pageIndex,
        bounds: local.bounds,
        selectedText: partner.selectedText,
        note: partner.note,
        color: partner.color,
        tags: partner.tags
      )]
    )
    guard let conflict = result.conflicts.first else {
      Issue.record("Expected a conflict")
      return
    }
    var c = conflict
    c.resolution = .merge
    let tags = Set(c.resolvedMark.tags)
    #expect(tags.contains("important"))
    #expect(tags.contains("review"))
  }

  // MARK: - Merge Summary

  @Test("MergeSummary description is readable")
  func summaryDescription() {
    let s = MergeSummary(localOnlyCount: 3, partnerOnlyCount: 2, duplicateCount: 1, conflictCount: 1, totalCount: 6)
    #expect(s.description.contains("3 yours"))
    #expect(s.description.contains("2 theirs"))
    #expect(s.description.contains("1 shared"))
    #expect(s.description.contains("1 conflicts"))
    #expect(s.hasConflicts)
  }

  // MARK: - Helpers

  private func makeMark(
    page: Int = 0,
    text: String = "Test",
    note: String = "",
    y: Double = 50,
    bounds: PDFRect? = nil,
    type: AnnotationType = .highlight,
    tags: [String] = []
  ) -> AnnotationMark {
    AnnotationMark(
      type: type,
      pageIndex: page,
      bounds: bounds ?? PDFRect(x: 10, y: y, width: 100, height: 20),
      selectedText: text,
      note: note,
      color: .yellow,
      tags: tags
    )
  }
}
