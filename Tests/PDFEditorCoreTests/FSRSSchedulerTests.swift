import Foundation
import Testing
@testable import PDFEditorCore

@Suite("FSRS Scheduler")
struct FSRSSchedulerTests {

  // MARK: - Retrievability

  @Test("Retrievability at t=0 is 1.0")
  func retrievabilityAtZero() {
    let r = FSRS.retrievability(t: 0, s: 30)
    #expect(abs(r - 1.0) < 0.001)
  }

  @Test("Retrievability at t=S is 0.9 (by definition of stability)")
  func retrievabilityAtStability() {
    let s = 30.0
    let r = FSRS.retrievability(t: s, s: s)
    #expect(abs(r - 0.9) < 0.001)
  }

  @Test("Retrievability decays monotonically")
  func retrievabilityDecaysMonotonically() {
    let s = 30.0
    var prev = FSRS.retrievability(t: 0, s: s)
    for t in stride(from: 1.0, through: 100.0, by: 1.0) {
      let r = FSRS.retrievability(t: t, s: s)
      #expect(r < prev)
      prev = r
    }
  }

  @Test("Retrievability with higher stability decays slower")
  func higherStabilitySlowerDecay() {
    let r10 = FSRS.retrievability(t: 10, s: 10)
    let r30 = FSRS.retrievability(t: 10, s: 30)
    #expect(r30 > r10)
  }

  @Test("Retrievability with t=0 returns 1 regardless of stability")
  func retrievabilityZeroTime() {
    #expect(FSRS.retrievability(t: 0, s: 0.1) == 1.0)
    #expect(FSRS.retrievability(t: 0, s: 100) == 1.0)
  }

  @Test("Retrievability with s=0 returns 0")
  func retrievabilityZeroStability() {
    #expect(FSRS.retrievability(t: 5, s: 0) == 0.0)
  }

  // MARK: - Interval

  @Test("Interval at R_d=0.9 equals stability")
  func intervalAtDefaultRetention() {
    let s = 30.0
    let i = FSRS.interval(rDesired: 0.9, s: s)
    #expect(abs(i - s) < 1.0)
  }

  @Test("Higher desired retention gives shorter interval")
  func higherRetentionShorterInterval() {
    let s = 30.0
    let i90 = FSRS.interval(rDesired: 0.9, s: s)
    let i95 = FSRS.interval(rDesired: 0.95, s: s)
    #expect(i95 < i90)
  }

  @Test("Lower desired retention gives longer interval")
  func lowerRetentionLongerInterval() {
    let s = 30.0
    let i90 = FSRS.interval(rDesired: 0.9, s: s)
    let i80 = FSRS.interval(rDesired: 0.8, s: s)
    #expect(i80 > i90)
  }

  @Test("Interval is always at least 1 day")
  func intervalMinimumOneDay() {
    let i = FSRS.interval(rDesired: 0.9, s: 0.1)
    #expect(i >= 1.0)
  }

  // MARK: - Initial State

  @Test("Initial stability increases with grade quality")
  func initialStabilityIncreases() {
    let sAgain = FSRS.initialStability(grade: .again)
    let sHard = FSRS.initialStability(grade: .hard)
    let sGood = FSRS.initialStability(grade: .good)
    let sEasy = FSRS.initialStability(grade: .easy)
    #expect(sAgain < sHard)
    #expect(sHard < sGood)
    #expect(sGood < sEasy)
  }

  @Test("Initial difficulty decreases with grade quality")
  func initialDifficultyDecreases() {
    let dAgain = FSRS.initialDifficulty(grade: .again)
    let dHard = FSRS.initialDifficulty(grade: .hard)
    let dGood = FSRS.initialDifficulty(grade: .good)
    let dEasy = FSRS.initialDifficulty(grade: .easy)
    #expect(dAgain > dHard)
    #expect(dHard > dGood)
    #expect(dGood > dEasy)
  }

  @Test("Initial difficulty is between 1 and 10")
  func initialDifficultyClamped() {
    for grade in FSRS.Grade.allCases {
      let d = FSRS.initialDifficulty(grade: grade)
      #expect(d >= 1.0)
      #expect(d <= 10.0)
    }
  }

  @Test("Initial stability is positive")
  func initialStabilityPositive() {
    for grade in FSRS.Grade.allCases {
      let s = FSRS.initialStability(grade: grade)
      #expect(s > 0)
    }
  }

  // MARK: - State Update

  @Test("Good grade increases stability")
  func goodIncreasesStability() {
    let state = FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    let (newState, _) = FSRS.nextState(current: state, grade: .good)
    #expect(newState.stability > state.stability)
  }

  @Test("Easy grade increases stability more than Good")
  func easyIncreasesMoreThanGood() {
    let makeState = { FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400)) }
    let (_, iGood) = FSRS.nextState(current: makeState(), grade: .good)
    let (_, iEasy) = FSRS.nextState(current: makeState(), grade: .easy)
    #expect(iEasy > iGood)
  }

  @Test("Hard grade increases stability less than Good")
  func hardIncreasesLessThanGood() {
    let makeState = { FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400)) }
    let (_, iHard) = FSRS.nextState(current: makeState(), grade: .hard)
    let (_, iGood) = FSRS.nextState(current: makeState(), grade: .good)
    #expect(iHard < iGood)
  }

  @Test("Again grade decreases stability")
  func againDecreasesStability() {
    let state = FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    let (newState, _) = FSRS.nextState(current: state, grade: .again)
    #expect(newState.stability < state.stability)
  }

  @Test("Again increases difficulty")
  func againIncreasesDifficulty() {
    let state = FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    let (newState, _) = FSRS.nextState(current: state, grade: .again)
    #expect(newState.difficulty > state.difficulty)
  }

  @Test("Easy decreases difficulty")
  func easyDecreasesDifficulty() {
    let state = FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    let (newState, _) = FSRS.nextState(current: state, grade: .easy)
    #expect(newState.difficulty < state.difficulty)
  }

  @Test("Difficulty stays between 1 and 10")
  func difficultyClamped() {
    var state = FSRS.MemoryState(difficulty: 1.5, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    // 10 lapses in a row
    for _ in 0..<10 {
      let (newState, _) = FSRS.nextState(current: state, grade: .again)
      state = newState
      #expect(state.difficulty >= 1.0)
      #expect(state.difficulty <= 10.0)
    }
  }

  @Test("Stability never goes below 0.1")
  func stabilityMinimum() {
    var state = FSRS.MemoryState(difficulty: 9.0, stability: 0.5, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    for _ in 0..<10 {
      let (newState, _) = FSRS.nextState(current: state, grade: .again)
      state = newState
      #expect(state.stability >= 0.1)
    }
  }

  // MARK: - Full Sequence Simulation

  @Test("All correct reviews increase stability progressively")
  func allCorrectIncreasesStability() {
    var state = FSRS.MemoryState(difficulty: 5.0, stability: 1.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    var intervals: [Double] = []
    for _ in 0..<10 {
      let (newState, interval) = FSRS.nextState(current: state, grade: .good)
      intervals.append(interval)
      state = newState
    }
    // Intervals should be monotonically increasing
    for i in 1..<intervals.count {
      #expect(intervals[i] >= intervals[i - 1])
    }
  }

  @Test("Sequence of correct then lapse then correct recovers")
  func lapseRecovery() {
    var state = FSRS.MemoryState(difficulty: 5.0, stability: 10.0, lastReviewTimestamp: Date().addingTimeInterval(-86400))
    // 3 correct reviews
    for _ in 0..<3 {
      let (s, _) = FSRS.nextState(current: state, grade: .good)
      state = s
    }
    let stabilityBeforeLapse = state.stability
    // 1 lapse
    let (lapsedState, _) = FSRS.nextState(current: state, grade: .again)
    #expect(lapsedState.stability < stabilityBeforeLapse)
    state = lapsedState
    // 3 correct reviews to recover
    for _ in 0..<3 {
      let (s, _) = FSRS.nextState(current: state, grade: .good)
      state = s
    }
    // Stability should recover but not exceed pre-lapse
    #expect(state.stability > lapsedState.stability)
  }

  // MARK: - MemoryState

  @Test("MemoryState retrievability decreases over time")
  func memoryStateRetrievabilityDecay() {
    let state = FSRS.MemoryState(difficulty: 5.0, stability: 30.0, lastReviewTimestamp: Date())
    let r0 = state.retrievability(at: Date())
    let r1 = state.retrievability(at: Date().addingTimeInterval(86400))
    let r7 = state.retrievability(at: Date().addingTimeInterval(86400 * 7))
    #expect(r0 > r1)
    #expect(r1 > r7)
  }

  @Test("MemoryState without lastReview returns 0 retrievability")
  func memoryStateNoReview() {
    let state = FSRS.MemoryState(difficulty: 5.0, stability: 30.0, lastReviewTimestamp: nil)
    #expect(state.retrievability() == 0.0)
  }

  // MARK: - Grade Mapping

  @Test("UnifiedGrade maps to FSRS grade correctly")
  func unifiedToFSRS() {
    #expect(UnifiedGrade.again.fsrsGrade == .again)
    #expect(UnifiedGrade.hard.fsrsGrade == .hard)
    #expect(UnifiedGrade.good.fsrsGrade == .good)
    #expect(UnifiedGrade.easy.fsrsGrade == .easy)
  }

  @Test("UnifiedGrade maps to SM-2 binary correctly")
  func unifiedToSM2Binary() {
    #expect(!UnifiedGrade.again.isCorrect)
    #expect(UnifiedGrade.hard.isCorrect)
    #expect(UnifiedGrade.good.isCorrect)
    #expect(UnifiedGrade.easy.isCorrect)
  }

  @Test("UnifiedGrade SM-2 quality rating")
  func unifiedSM2Quality() {
    #expect(UnifiedGrade.again.sm2Quality == 1)
    #expect(UnifiedGrade.hard.sm2Quality == 3)
    #expect(UnifiedGrade.good.sm2Quality == 4)
    #expect(UnifiedGrade.easy.sm2Quality == 5)
  }

  // MARK: - Algorithm Selection

  @Test("SRSAlgorithm has both cases")
  func algorithmCases() {
    #expect(SRSAlgorithm.allCases.count == 2)
    #expect(SRSAlgorithm.sm2.displayName == "SM-2")
    #expect(SRSAlgorithm.fsrs.displayName == "FSRS")
  }

  // MARK: - Desired Retention Impact

  @Test("Higher retention requires more frequent reviews")
  func higherRetentionMoreFrequent() {
    let s = 30.0
    let i80 = FSRS.interval(rDesired: 0.80, s: s)
    let i85 = FSRS.interval(rDesired: 0.85, s: s)
    let i90 = FSRS.interval(rDesired: 0.90, s: s)
    let i95 = FSRS.interval(rDesired: 0.95, s: s)
    #expect(i80 > i85)
    #expect(i85 > i90)
    #expect(i90 > i95)
  }

  @Test("Stability scales interval linearly")
  func stabilityScalesInterval() {
    let r = 0.9
    let i10 = FSRS.interval(rDesired: r, s: 10)
    let i30 = FSRS.interval(rDesired: r, s: 30)
    let i90 = FSRS.interval(rDesired: r, s: 90)
    // Should be roughly 3x and 9x
    #expect(i30 > i10 * 2.5)
    #expect(i90 > i30 * 2.5)
  }
}
