import CoreGraphics
import Foundation
import Testing
@testable import PDFEditorCore

/// Stage 0 learning loop: value-free review events must never carry document
/// values, label text, evidence prose, paths, or signature material.
struct CandidateReviewLearningEventTests {

  private func labeledCandidate() -> RegionCandidate {
    RegionCandidate(
      pageIndex: 2,
      bounds: PDFRect(x: 100, y: 500, width: 120, height: 18),
      kind: .textAnchored, score: 0.58,
      evidence: ["Label: Jane Doe's form line"],
      entryMode: .singleText,
      labelText: "Jane Doe Home Address:",
      memberBounds: [],
      evidenceItems: [
        CandidateEvidence(
          kind: .textLabel, origin: .textExtraction,
          summary: "Label text anchors the candidate",
          region: nil, text: "Jane Doe Home Address:", score: 0.72)
      ]
    )
  }

  @Test func eventFromLabeledCandidateEncodesWithoutAnyTextualContent() throws {
    let candidate = labeledCandidate()
    let event = CandidateReviewLearningEventFactory.make(
      candidateID: candidate.id,
      decision: .confirmed,
      pageIndex: candidate.pageIndex,
      candidate: candidate,
      sourceDigest: "abc123"
    )

    #expect(event?.hadLabel == true)
    #expect(event?.pageIndex == 2)
    #expect(event?.decision == .confirmed)

    let encoded = try JSONEncoder().encode(event)
    let offenders = ValueFreeEventGuard.forbiddenKeysFound(in: encoded)
    #expect(offenders.isEmpty)
    // Belt and suspenders: even the label-derived displayName must not leak.
    #expect(String(data: encoded, encoding: .utf8)!.contains("Jane Doe") == false)

    try ValueFreeEventGuard.assertValueFree(contents: encoded)
  }

  @Test func journalValidationPassesAndGuardFlagsSmuggledKeys() throws {
    let journal = CandidateReviewLearningEventJournal(events: [])
    try journal.validate()

    // A payload carrying forbidden keys must fail closed.
    let smuggled = """
      {"contractName":"pdf-editor.candidate-review-learning-journal",
       "events":[{"labelText":"Full Name","bounds":{"x":0,"y":0,"width":1,"height":1}}]}
      """
    let offenders = ValueFreeEventGuard.forbiddenKeysFound(in: Data(smuggled.utf8))
    #expect(offenders.contains("labelText"))
    #expect(throws: PDFSessionPrivacyProvenanceError.self) {
      try ValueFreeEventGuard.assertValueFree(contents: Data(smuggled.utf8))
    }
  }

  @Test func storeRoundTripsPerSourceDigestWithoutCrossTalk() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("learning-events-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = CandidateReviewLearningEventStore(directory: directory)

    let candidateA = labeledCandidate()
    let candidateB = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 50, y: 200, width: 16, height: 16),
      kind: .vectorRegion, score: 0.85,
      evidence: ["vector square"],
      entryMode: .checkbox
    )
    let confirmed = CandidateReviewLearningEventFactory.make(
      candidateID: candidateA.id, decision: .confirmed, pageIndex: candidateA.pageIndex,
      candidate: candidateA, sourceDigest: "digest-A"
    )
    let rejected = CandidateReviewLearningEventFactory.make(
      candidateID: candidateB.id, decision: .rejected, pageIndex: candidateB.pageIndex,
      candidate: candidateB, sourceDigest: "digest-B"
    )

    try store.append(event: confirmed!)
    try store.append(event: CandidateReviewLearningEventFactory.make(
      candidateID: candidateA.id, decision: .rejected, pageIndex: candidateA.pageIndex,
      candidate: candidateA, sourceDigest: "digest-A"
    )!)
    try store.append(event: rejected!)

    let digestAEvents = store.events(sourceDigest: "digest-A")
    #expect(digestAEvents.count == 2)
    #expect(digestAEvents.map(\.decision) == [.confirmed, .rejected])
    #expect(store.events(sourceDigest: "digest-B").count == 1)
    #expect(store.events(sourceDigest: "missing").isEmpty)
  }

  @Test func manualCreationWithoutCandidateStillRecordsGeometryOnlyIntent() throws {
    let event = CandidateReviewLearningEventFactory.make(
      candidateID: UUID(),
      decision: .manuallyCreated,
      pageIndex: 3,
      candidate: nil,
      sourceDigest: "digest-C"
    )
    #expect(event?.kind == .manual)
    #expect(event?.hadLabel == false)
    let encoded = try JSONEncoder().encode(event)
    try ValueFreeEventGuard.assertValueFree(contents: encoded)
  }
}
