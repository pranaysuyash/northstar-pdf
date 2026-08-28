import Testing
import Foundation
@testable import PDFEditorCore

@Suite("ConflictResolutionHint")
struct ConflictResolutionHintTests {

  // MARK: - Same Region Different Content

  @Test("High spatial separation suggests keepBoth")
  func farApartSameRegion() {
    let local = makeMark(x: 10, y: 100, text: "alpha", note: "Note A")
    let partner = makeMark(x: 10, y: 200, text: "beta", note: "Note B")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameRegionDifferentContent
    )
    #expect(hint.suggested == .keepBoth)
    #expect(hint.confidence >= 0.7)
    #expect(hint.explanation.contains("apart"))
  }

  @Test("Same text different notes suggests merge")
  func sameTextDiffNotes() {
    let local = makeMark(x: 10, y: 100, text: "Important finding", note: "First insight")
    let partner = makeMark(x: 10, y: 100, text: "Important finding", note: "Second insight")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameRegionDifferentContent
    )
    #expect(hint.suggested == .merge)
    #expect(hint.confidence >= 0.7)
    #expect(hint.explanation.contains("Same"))
  }

  @Test("Same note different text suggests keepBoth")
  func sameNoteDiffText() {
    let local = makeMark(x: 10, y: 100, text: "First occurrence", note: "Key concept")
    let partner = makeMark(x: 10, y: 100, text: "Second occurrence", note: "Key concept")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameRegionDifferentContent
    )
    #expect(hint.suggested == .keepBoth)
    #expect(hint.confidence >= 0.7)
  }

  @Test("Same type color and similar text suggests merge")
  func similarMarkMerge() {
    let local = makeMark(x: 10, y: 100, text: "the quick brown fox", note: "", type: .highlight, color: .yellow)
    let partner = makeMark(x: 10, y: 100, text: "the quick brown fox jumps", note: "", type: .highlight, color: .yellow)
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameRegionDifferentContent
    )
    #expect(hint.suggested == .merge)
    #expect(hint.confidence >= 0.6)
  }

  // MARK: - Overlapping Bounds

  @Test("Very high overlap with similar text suggests merge")
  func highOverlapMerge() {
    let local = makeMark(x: 10, y: 100, text: "Important text")
    let partner = makeMark(x: 12, y: 101, text: "Important text here")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .overlappingBounds(0.85)
    )
    #expect(hint.suggested == .merge)
    #expect(hint.confidence >= 0.7)
  }

  @Test("High overlap with different text suggests keepLocal")
  func highOverlapDiffText() {
    let local = makeMark(x: 10, y: 100, text: "Alpha beta gamma")
    let partner = makeMark(x: 10, y: 100, text: "Delta epsilon zeta")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .overlappingBounds(0.75)
    )
    #expect(hint.suggested == .keepLocal)
    #expect(hint.confidence >= 0.6)
  }

  @Test("Moderate overlap suggests keepBoth")
  func moderateOverlap() {
    let local = makeMark(x: 10, y: 100, text: "Alpha")
    let partner = makeMark(x: 50, y: 100, text: "Beta")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .overlappingBounds(0.55)
    )
    #expect(hint.suggested == .keepBoth)
  }

  // MARK: - Same Text Different Position

  @Test("Same text far apart same type suggests keepBoth")
  func sameTextFarApart() {
    let local = makeMark(x: 10, y: 100, text: "Recurring theme")
    let partner = makeMark(x: 10, y: 300, text: "Recurring theme")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameTextDifferentPosition
    )
    #expect(hint.suggested == .keepBoth)
    #expect(hint.confidence >= 0.7)
  }

  @Test("Same text close together same type suggests merge")
  func sameTextClose() {
    let local = makeMark(x: 10, y: 100, text: "Nearby highlight")
    let partner = makeMark(x: 12, y: 102, text: "Nearby highlight")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameTextDifferentPosition
    )
    #expect(hint.suggested == .merge)
  }

  @Test("Same text different types suggests keepBoth")
  func sameTextDiffTypes() {
    let local = makeMark(x: 10, y: 100, text: "Important", type: .highlight)
    let partner = makeMark(x: 10, y: 100, text: "Important", type: .underline)
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameTextDifferentPosition
    )
    #expect(hint.suggested == .keepBoth)
  }

  // MARK: - Same Note Content

  @Test("Same note different text far apart suggests keepBoth")
  func sameNoteFarApart() {
    let local = makeMark(x: 10, y: 100, text: "First mention", note: "Key insight")
    let partner = makeMark(x: 10, y: 400, text: "Later reference", note: "Key insight")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameNoteContent
    )
    #expect(hint.suggested == .keepBoth)
    #expect(hint.confidence >= 0.7)
  }

  @Test("Same note same text suggests keepLocal (duplicate)")
  func sameNoteSameText() {
    let local = makeMark(x: 10, y: 100, text: "Exact match", note: "Same note")
    let partner = makeMark(x: 10, y: 100, text: "Exact match", note: "Same note")
    let hint = ConflictResolutionHint.analyze(
      local: local, partner: partner, reason: .sameNoteContent
    )
    #expect(hint.suggested == .keepLocal)
    #expect(hint.confidence >= 0.7)
  }

  // MARK: - Helpers

  private func makeMark(
    x: Double = 10, y: Double = 100,
    text: String = "Test", note: String = "",
    type: AnnotationType = .highlight,
    color: AnnotationColor = .yellow
  ) -> AnnotationMark {
    AnnotationMark(
      type: type,
      pageIndex: 0,
      bounds: PDFRect(x: x, y: y, width: 200, height: 20),
      selectedText: text,
      note: note,
      color: color
    )
  }
}
