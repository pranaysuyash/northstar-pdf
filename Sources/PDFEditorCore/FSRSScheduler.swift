import Foundation

// MARK: - FSRS Algorithm

/// Free Spaced Repetition Scheduler — the state-of-the-art SR algorithm.
///
/// Based on the DSR (Difficulty-Stability-Retrievability) memory model.
/// Integrated into Anki 23.10+ as the default scheduler.
/// 19 learned parameters, optimizable from review history.
///
/// References:
/// - Ye, J. & Anderson, J. (2022–2026). "FSRS: Free Spaced Repetition Scheduler."
/// - Expertium (2024). "Benchmark of SR Algorithms." 700M reviews.
/// - Borretti, F. (2025). "Implementing FSRS in 100 Lines."
public enum FSRS {
  // MARK: - Parameters

  /// FSRS-5 default parameters (19 values).
  /// These represent a "generic" memory model trained on millions of reviews.
  /// Personalization comes from running gradient descent on individual review history.
  public static let defaultParameters: [Double] = [
    0.40255, 1.18385, 3.173, 15.69105,  // w0-w3: initial stability per grade
    7.1949, 0.5345, 1.4604, 0.0046,     // w4-w7: difficulty params
    1.54575, 0.1192, 1.01925,            // w8-w10: stability-on-success params
    1.9395, 0.11, 0.29605, 2.2698,       // w11-w14: stability-on-failure params
    0.2315, 2.9898,                      // w15-w16: hard/easy bonuses
    0.51655, 0.6621,                     // w17-w18: short-term stability
  ]

  // MARK: - Constants

  /// Forgetting curve shape constants.
  /// R(t) = (1 + F * t/S)^C
  /// F = 19/81 ≈ 0.2346, C = -0.5
  static let F: Double = 19.0 / 81.0
  static let C: Double = -0.5

  // MARK: - Grade

  /// User's recall performance rating.
  /// Maps to the 4-button grading used in Anki, FSRS, and most modern SR apps.
  public enum Grade: Int, Codable, Sendable, Comparable, CaseIterable {
    case again = 1   // Forgot — lapse
    case hard = 2    // Recalled with difficulty
    case good = 3    // Recalled normally
    case easy = 4    // Recalled effortlessly

    public var displayName: String {
      switch self {
      case .again: return "Again"
      case .hard: return "Hard"
      case .good: return "Good"
      case .easy: return "Easy"
      }
    }

    public var symbolName: String {
      switch self {
      case .again: return "xmark.circle"
      case .hard: return "tortoise"
      case .good: return "checkmark.circle"
      case .easy: return "bolt.circle.fill"
      }
    }

    public static func < (lhs: Grade, rhs: Grade) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  // MARK: - DSR State

  /// The memory state of a single card/mark in the DSR model.
  public struct MemoryState: Codable, Sendable {
    /// Difficulty (1–10). Intrinsic property of the card, changes slowly.
    public var difficulty: Double
    /// Stability (days). Time for retrievability to drop from 100% to 90%.
    public var stability: Double
    /// Last review timestamp (for computing current R).
    public var lastReviewTimestamp: Date?

    public init(difficulty: Double = 5.0, stability: Double = 1.0, lastReviewTimestamp: Date? = nil) {
      self.difficulty = clampD(difficulty)
      self.stability = max(0.1, stability)
      self.lastReviewTimestamp = lastReviewTimestamp
    }

    /// Current retrievability given time since last review.
    public func retrievability(at date: Date = Date()) -> Double {
      guard let lastReview = lastReviewTimestamp else { return 0.0 }
      let t = date.timeIntervalSince(lastReview) / 86400.0 // days
      return FSRS.retrievability(t: t, s: stability)
    }
  }

  // MARK: - Core Functions

  /// Compute retrievability at time t given stability S.
  /// R(t) = (1 + F * t/S)^C
  public static func retrievability(t: Double, s: Double) -> Double {
    guard s > 0, t >= 0 else { return 0.0 }
    return pow(1.0 + F * (t / s), C)
  }

  /// Compute the optimal review interval for a desired retention R_d.
  /// I(R_d) = S * (R_d^(1/C) - 1) / F
  public static func interval(rDesired: Double, s: Double) -> Double {
    guard s > 0, rDesired > 0, rDesired < 1 else { return 1.0 }
    let raw = (s / F) * (pow(rDesired, 1.0 / C) - 1.0)
    return max(1.0, raw.rounded())
  }

  // MARK: - Initial State (First Review)

  /// Initial stability after the first review, based on grade.
  /// S_0(G) = w_{G-1}
  public static func initialStability(grade: Grade, parameters: [Double] = defaultParameters) -> Double {
    max(0.1, parameters[grade.rawValue - 1])
  }

  /// Initial difficulty after the first review.
  /// D_0(G) = w4 - exp(w5 * (G-1)) + 1
  public static func initialDifficulty(grade: Grade, parameters: [Double] = defaultParameters) -> Double {
    let g = Double(grade.rawValue)
    return clampD(parameters[4] - exp(parameters[5] * (g - 1.0)) + 1.0)
  }

  // MARK: - State Update (Subsequent Reviews)

  /// Update stability after a successful recall (Hard/Good/Easy).
  ///
  /// S' = S * (1 + t_d * t_s * t_r * h * b * e^(w8))
  ///
  /// Where:
  /// - t_d = 11 - D (difficulty penalty: harder cards gain less stability)
  /// - t_s = S^(-w9) (stability saturation: stable memories grow slower)
  /// - t_r = e^(w10 * (1-R)) - 1 (retrievability: review near-forget for max gain)
  /// - h = w15 if Hard, else 1 (hard penalty)
  /// - b = w16 if Easy, else 1 (easy bonus)
  public static func stabilityOnSuccess(
    d: Double, s: Double, r: Double, grade: Grade,
    parameters: [Double] = defaultParameters
  ) -> Double {
    let t_d = 11.0 - d
    let t_s = pow(s, -parameters[9])
    let t_r = exp(parameters[10] * (1.0 - r)) - 1.0
    let h: Double = grade == .hard ? parameters[15] : 1.0
    let b: Double = grade == .easy ? parameters[16] : 1.0
    let c = exp(parameters[8])
    let alpha = 1.0 + t_d * t_s * t_r * h * b * c
    return s * alpha
  }

  /// Update stability after a lapse (Again).
  ///
  /// S' = min(S_f, S)
  /// S_f = d_f * s_f * r_f * w11
  ///
  /// Where:
  /// - d_f = D^(-w12) (difficulty term)
  /// - s_f = (S+1)^(w13) - 1 (stability term)
  /// - r_f = e^(w14 * (1-R)) (retrievability term)
  public static func stabilityOnFailure(
    d: Double, s: Double, r: Double,
    parameters: [Double] = defaultParameters
  ) -> Double {
    let d_f = pow(d, -parameters[12])
    let s_f = pow(s + 1.0, parameters[13]) - 1.0
    let r_f = exp(parameters[14] * (1.0 - r))
    let c_f = parameters[11]
    let sNew = d_f * s_f * r_f * c_f
    return min(sNew, s)
  }

  /// Update difficulty after a review.
  ///
  /// D' = w7 * D_0(Easy) + (1 - w7) * D*
  /// D* = D + ΔD * (10 - D) / 9
  /// ΔD = -w6 * (G - 3)
  public static func updateDifficulty(
    d: Double, grade: Grade,
    parameters: [Double] = defaultParameters
  ) -> Double {
    let g = Double(grade.rawValue)
    let d0Easy = initialDifficulty(grade: .easy, parameters: parameters)
    let deltaD = -parameters[6] * (g - 3.0)
    let dStar = d + deltaD * ((10.0 - d) / 9.0)
    return clampD(parameters[7] * d0Easy + (1.0 - parameters[7]) * dStar)
  }

  // MARK: - Full State Transition

  /// Complete state transition after a review.
  /// Returns new MemoryState and interval.
  public static func nextState(
    current: MemoryState,
    grade: Grade,
    desiredRetention: Double = 0.9,
    parameters: [Double] = defaultParameters
  ) -> (state: MemoryState, intervalDays: Double) {
    let now = Date()
    let r: Double
    if let lastReview = current.lastReviewTimestamp {
      let t = now.timeIntervalSince(lastReview) / 86400.0
      r = retrievability(t: t, s: current.stability)
    } else {
      r = 0.0 // first review
    }

    let newS: Double
    let newD: Double

    if grade == .again {
      // Lapse
      newS = stabilityOnFailure(d: current.difficulty, s: current.stability, r: r, parameters: parameters)
      newD = updateDifficulty(d: current.difficulty, grade: grade, parameters: parameters)
    } else {
      // Success
      newS = stabilityOnSuccess(d: current.difficulty, s: current.stability, r: r, grade: grade, parameters: parameters)
      newD = updateDifficulty(d: current.difficulty, grade: grade, parameters: parameters)
    }

    let newState = MemoryState(
      difficulty: newD,
      stability: newS,
      lastReviewTimestamp: now
    )
    let nextInterval = interval(rDesired: desiredRetention, s: newS)

    return (newState, nextInterval)
  }

  // MARK: - Helpers

  private static func clampD(_ d: Double) -> Double {
    min(10.0, max(1.0, d))
  }
}

// MARK: - SRS Algorithm Selector

/// Allows users to choose between SM-2 and FSRS.
/// Existing users keep SM-2; new users get FSRS by default.
public enum SRSAlgorithm: String, Codable, Sendable, CaseIterable {
  case sm2 = "SM-2"
  case fsrs = "FSRS"

  public var displayName: String { rawValue }
  public var description: String {
    switch self {
    case .sm2: return "Classic SM-2 — simple, auditable, battle-tested since 1987"
    case .fsrs: return "FSRS — modern DSR model, 25% fewer reviews, personalizable"
    }
  }
}

// MARK: - Unified Grade

/// Unified grading interface for both SM-2 and FSRS.
/// SM-2 uses binary (correct/incorrect); FSRS uses 4 grades.
/// This enum bridges both, mapping cleanly to either algorithm.
public enum UnifiedGrade: Int, Codable, Sendable, CaseIterable {
  case again = 1
  case hard = 2
  case good = 3
  case easy = 4

  public var displayName: String {
    switch self {
    case .again: return "Again"
    case .hard: return "Hard"
    case .good: return "Good"
    case .easy: return "Easy"
    }
  }

  /// Convert to FSRS grade.
  public var fsrsGrade: FSRS.Grade {
    FSRS.Grade(rawValue: rawValue) ?? .good
  }

  /// Convert to SM-2 binary (true = correct, false = incorrect).
  /// SM-2: Again = incorrect, Hard/Good/Easy = correct.
  public var isCorrect: Bool { rawValue >= 2 }

  /// SM-2 quality rating (0–5 scale).
  /// Again=1, Hard=3, Good=4, Easy=5.
  public var sm2Quality: Int {
    switch self {
    case .again: return 1
    case .hard: return 3
    case .good: return 4
    case .easy: return 5
    }
  }
}
