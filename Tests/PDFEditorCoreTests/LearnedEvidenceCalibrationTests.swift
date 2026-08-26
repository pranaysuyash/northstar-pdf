import CoreGraphics
import Foundation
import Testing
@testable import PDFEditorCore

/// R6 Stage 2: learned evidence-kind calibration must bias fusion weights
/// from review history while remaining value-free and neutral without signal.
struct LearnedEvidenceCalibrationTests {

  private func event(
    _ decision: CandidateReviewDecisionKind,
    evidenceKinds: [String],
    digest: String = "d"
  ) -> CandidateReviewLearningEvent {
    CandidateReviewLearningEvent(
      sourceDigest: digest,
      candidateID: UUID(),
      pageIndex: 0,
      kind: .textAnchored,
      entryMode: .singleText,
      suggestedFieldType: .text,
      decision: decision,
      hadLabel: true,
      memberCount: 1,
      score: 0.6,
      bounds: PDFRect(x: 10, y: 10, width: 100, height: 18),
      evidenceKinds: evidenceKinds
    )
  }

  @Test func calibrationStaysNeutralBelowSignalFloor() {
    let calibration = LearnedEvidenceCalibration.from(
      events: [event(.confirmed, evidenceKinds: ["whitespace"])]
    )
    #expect(calibration.hasSignal == false)
    #expect(calibration.overrideWeights() == nil)
  }

  @Test func confirmedFamiliesGainTrustRejectedFamiliesLoseIt() {
    let events =
      (0..<3).map { _ in event(.confirmed, evidenceKinds: ["vectorRectangle", "textLabel"]) }
      + (0..<3).map { _ in event(.rejected, evidenceKinds: ["whitespace"]) }
    let calibration = LearnedEvidenceCalibration.from(events: events)

    let weights = calibration.overrideWeights()
    #expect(weights != nil)
    // Consistently-confirmed family gains trust over neutral.
    #expect((weights?[.vectorRectangle] ?? 0) > 1.0)
    // Consistently-rejected family loses trust but is not zeroed out.
    let whitespace = weights?[.whitespace] ?? 1.0
    #expect(whitespace < 1.0)
    #expect(whitespace >= 0.5)
    // Unseen families are absent (canonical weight applies).
    #expect(weights?[.ocrText] == nil)
  }

  @Test func learnedWeightsShiftMixedEvidenceTowardTrustedFamilies() {
    // Mixed candidate: strong geometry + weak whitespace corroboration.
    let signals = [
      EvidenceFusionSignal(
        id: "v1", kind: .vectorRectangle, origin: .geometryExtraction, score: 0.9,
        region: PDFRect(x: 0, y: 0, width: 100, height: 18)),
      EvidenceFusionSignal(
        id: "w1", kind: .whitespace, origin: .textExtraction, score: 0.58,
        region: PDFRect(x: 0, y: 0, width: 100, height: 18)),
    ]
    let baseline = EvidenceFusion.fuse(signals: signals)

    // History: whitespace repeatedly rejected, geometry repeatedly confirmed.
    let events =
      (0..<3).map { _ in event(.rejected, evidenceKinds: ["whitespace"]) }
        + (0..<3).map { _ in event(.confirmed, evidenceKinds: ["vectorRectangle"]) }
    let calibration = LearnedEvidenceCalibration.from(events: events)

    let shifted = EvidenceFusion.fuse(
      signals: signals,
      weightsOverride: calibration.overrideWeights())

    // De-emphasizing the distrusted family lets the trusted one dominate:
    // fused confidence rises versus canonical weighting.
    #expect(shifted.score > baseline.score)

    // And the mirror image: if geometry were the distrusted family instead,
    // confidence must fall.
    let inverseEvents =
      (0..<3).map { _ in event(.rejected, evidenceKinds: ["vectorRectangle"]) }
        + (0..<3).map { _ in event(.confirmed, evidenceKinds: ["whitespace"]) }
    let inverse = EvidenceFusion.fuse(
      signals: signals,
      weightsOverride: LearnedEvidenceCalibration.from(events: inverseEvents).overrideWeights())
    #expect(inverse.score < baseline.score)

    // Nil override reproduces the canonical result exactly.
    let canonical = EvidenceFusion.fuse(signals: signals, weightsOverride: nil)
    #expect(canonical.score == baseline.score)
  }

  @Test func recalibrationPreservesIdentityAndStatus() {
    var candidate = RegionCandidate(
      pageIndex: 1,
      bounds: PDFRect(x: 40, y: 300, width: 120, height: 20),
      kind: .vectorRegion,
      score: 0.72,
      evidence: ["e"],
      entryMode: .singleText,
      labelText: "Reference:"
    )
    candidate.status = .suggested
    let weights: [CandidateEvidenceKind: Double] = [.vectorRectangle: 0.5]
    let updated = candidate.recalibratingFusion(weights: weights)

    #expect(updated.id == candidate.id)
    #expect(updated.bounds == candidate.bounds)
    #expect(updated.labelText == candidate.labelText)
    #expect(updated.displayName == candidate.displayName)
    #expect(updated.status == .suggested)
    #expect(updated.score == candidate.score)
    #expect(updated.evidenceItems.count == candidate.evidenceItems.count)
  }

  @Test func legacyJournalWithoutEvidenceKindsDecodes() throws {
    // Older journals predate the evidenceKinds field; decode defaults apply.
    let legacyJSON = """
        {"contractName":"pdf-editor.candidate-review-learning-journal",
         "version":{"major":1,"minor":0},
         "privacy":"value-free-structural-decisions-only",
         "events":[{"id":"00000000-0000-0000-0000-000000000001",
           "sourceDigest":"abc","candidateID":"00000000-0000-0000-0000-000000000002",
           "pageIndex":0,"kind":"textAnchored","entryMode":"singleText",
           "suggestedFieldType":"text","decision":"confirmed","hadLabel":true,
           "memberCount":1,"score":0.6,
           "bounds":{"x":0,"y":0,"width":10,"height":10},
           "createdAt":7258118400}]
        }
    """
    let journal = try JSONDecoder().decode(
      CandidateReviewLearningEventJournal.self, from: Data(legacyJSON.utf8))
    #expect(journal.events.count == 1)
    #expect(journal.events[0].evidenceKinds.isEmpty)
  }
}
