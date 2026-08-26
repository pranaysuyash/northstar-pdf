import CoreGraphics
import Foundation
import Testing
@testable import PDFEditorCore

/// R6 Stage 1: priors from value-free review events must bias ranking
/// without touching contract scores, and stay neutral until there is signal.
struct CandidatePriorScorerTests {

  private func event(
    _ decision: CandidateReviewDecisionKind,
    entryMode: CandidateEntryMode = .singleText,
    fieldType: SuggestedFieldType? = .text,
    kind: CandidateKind = .textAnchored,
    digest: String = "d"
  ) -> CandidateReviewLearningEvent {
    CandidateReviewLearningEvent(
      sourceDigest: digest,
      candidateID: UUID(),
      pageIndex: 0,
      kind: kind,
      entryMode: entryMode,
      suggestedFieldType: fieldType,
      decision: decision,
      hadLabel: true,
      memberCount: 1,
      score: 0.6,
      bounds: PDFRect(x: 10, y: 10, width: 100, height: 18)
    )
  }

  private func candidate(
    entryMode: CandidateEntryMode = .singleText,
    fieldType: SuggestedFieldType? = .text,
    kind: CandidateKind = .textAnchored,
    score: Double = 0.60
  ) -> RegionCandidate {
    RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 500, width: 100, height: 18),
      kind: kind,
      score: score,
      evidence: ["e"],
      suggestedFieldType: fieldType,
      entryMode: entryMode
    )
  }

  @Test func noEventsMeansNeutralRanking() {
    let priors = CandidatePriors(events: [])
    #expect(priors.hasSignal == false)
    let adjusted = priors.adjustedScore(for: candidate())
    #expect(adjusted == candidate().score)
  }

  @Test func confirmedHistoryBoostsMatchingFactors() {
    // Three confirms of singleText/text candidates on this source.
    let events = (0..<3).map { _ in event(.confirmed) }
    let priors = CandidatePriors(events: events)
    #expect(priors.hasSignal)

    let boosted = priors.adjustedScore(for: candidate())
    let untouchedType = priors.adjustedScore(
      for: candidate(entryMode: .checkbox, fieldType: .checkbox, kind: .vectorRegion))

    #expect(boosted > candidate(score: 0.60).score)
    // An unrelated factor combination gets little to no lift.
    #expect(untouchedType < boosted)
  }

  @Test func rejectedHistoryDampensMatchingFactors() {
    let events = (0..<4).map { _ in event(.rejected) }
    let priors = CandidatePriors(events: events)
    let dampened = priors.adjustedScore(for: candidate())
    #expect(dampened < 0.60)
    #expect(dampened >= 0.60 * 0.6) // multiplier floor holds
  }

  @Test func contractScoresAreNeverMutated() {
    let events = (0..<5).map { _ in event(.confirmed) }
    let priors = CandidatePriors(events: events)
    let base = candidate(score: 0.58)
    let original = base.score
    _ = priors.adjustedScore(for: base)
    #expect(base.score == original)
  }

  @Test func nonTerminalDecisionsDoNotCreateSignal() {
    let events = [
      event(.moved), event(.resized), event(.retyped),
    ]
    let priors = CandidatePriors(events: events)
    #expect(priors.sampleCount == 0)
    #expect(priors.hasSignal == false)
  }

  @Test func rankingReordersByPriorAdjustedScore() {
    var priors = CandidatePriors(sampleCount: 0)
    // Checkbox-heavy acceptance history.
    let events = (0..<3).map { _ in
      event(.confirmed, entryMode: .checkbox, fieldType: .checkbox, kind: .vectorRegion)
    }
    priors = CandidatePriors(events: events)

    let checkbox = candidate(entryMode: .checkbox, fieldType: .checkbox, kind: .vectorRegion, score: 0.55)
    let text = candidate(entryMode: .singleText, fieldType: .text, kind: .textAnchored, score: 0.55)
    let ranked = [text, checkbox].sorted {
      priors.adjustedScore(for: $0) > priors.adjustedScore(for: $1)
    }
    #expect(ranked.first?.entryMode == .checkbox)
  }
}
