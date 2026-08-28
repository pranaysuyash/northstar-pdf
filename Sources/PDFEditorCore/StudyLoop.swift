import Foundation

/// A marks-based study loop for the LEARN job.
///
/// First principle: learning is retrieval practice, not passive re-reading.
/// The study loop takes the user's annotation marks and turns them into an
/// active recall session — show the context, hide the answer, prompt retrieval.
///
/// Three modes:
/// - **Review**: read through all marks in order (passive orientation)
/// - **Recall**: hide selected text/note, prompt user to recall from memory
/// - **Quiz**: present random marks, track correct/incorrect
///
/// Doctrine alignment:
/// - §3: Do things smartly — marks already exist, study loop reuses them
/// - §5: Evidence-based — mastery levels are data-driven, not subjective
/// - §8: Capability activation — study loop is opt-in, doesn't modify marks

// MARK: - Study Mode

/// The mode of a study session.
public enum StudyMode: String, Codable, Sendable, CaseIterable, Identifiable {
  /// Read through marks in order (passive).
  case review = "review"
  /// Hide the answer, prompt recall (active).
  case recall = "recall"
  /// Random order, track correctness (testing).
  case quiz = "quiz"

  public var id: String { rawValue }
  public var displayName: String { rawValue.capitalized }

  public var symbolName: String {
    switch self {
    case .review: return "book"
    case .recall: return "brain.head.profile"
    case .quiz: return "questionmark.circle"
    }
  }

  public var helpText: String {
    switch self {
    case .review: return "Read through all marks in order"
    case .recall: return "Hide the answer and test your memory"
    case .quiz: return "Random order with correctness tracking"
    }
  }
}

// MARK: - Recall State

/// What the user sees during recall mode.
public enum RecallState: Sendable {
  /// Showing the context (page, surrounding text) — answer is hidden.
  case hidden(question: RecallQuestion)
  /// User has revealed the answer.
  case revealed(answer: RecallAnswer)
  /// Session is complete.
  case complete
}

/// A question presented during recall.
public struct RecallQuestion: Sendable {
  /// The mark being tested.
  public let mark: AnnotationMark
  /// The page number (1-indexed for display).
  public let pageNumber: Int
  /// A hint derived from the mark's context (first N chars of selectedText).
  public let hint: String
  /// The type of mark (highlight, note, etc.) — shown as category.
  public let category: String

  public init(mark: AnnotationMark) {
    self.mark = mark
    self.pageNumber = mark.pageIndex + 1
    // Show first 3 words as hint
    let words = mark.selectedText.split(separator: " ")
    self.hint = words.prefix(3).joined(separator: " ") + (words.count > 3 ? "..." : "")
    self.category = mark.type.displayName
  }
}

/// The answer revealed after recall.
public struct RecallAnswer: Sendable {
  /// The full selected text.
  public let selectedText: String
  /// The user's note (if any).
  public let note: String
  /// The mark's color.
  public let color: AnnotationColor
  /// Page number.
  public let pageNumber: Int

  public init(question: RecallQuestion) {
    self.selectedText = question.mark.selectedText
    self.note = question.mark.note
    self.color = question.mark.color
    self.pageNumber = question.pageNumber
  }
}

// MARK: - Mastery Level

/// Mastery level for a single mark, tracked across study sessions.
public enum MasteryLevel: Int, Codable, Sendable, Comparable, CaseIterable {
  /// Never reviewed.
  case new = 0
  /// Seen but not recalled.
  case seen = 1
  /// Recalled correctly once.
  case learning = 2
  /// Recalled correctly 2-3 times.
  case review = 3
  /// Recalled correctly 4+ times in a row.
  case mastered = 4

  public var displayName: String {
    switch self {
    case .new: return "New"
    case .seen: return "Seen"
    case .learning: return "Learning"
    case .review: return "Review"
    case .mastered: return "Mastered"
    }
  }

  public var symbolName: String {
    switch self {
    case .new: return "circle.dashed"
    case .seen: return "circle"
    case .learning: return "circle.lefthalf.filled"
    case .review: return "circle.righthalf.filled"
    case .mastered: return "checkmark.circle.fill"
    }
  }

  public static func < (lhs: MasteryLevel, rhs: MasteryLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

// MARK: - Mark Mastery

/// Tracks mastery for a single annotation mark across sessions.
public struct MarkMastery: Codable, Sendable, Identifiable {
  public let markID: UUID
  public var level: MasteryLevel
  /// Number of consecutive correct recalls.
  public var correctStreak: Int
  /// Total number of recall attempts.
  public var totalAttempts: Int
  /// Number of correct recalls.
  public var correctCount: Int
  /// When this mastery record was created.
  public let createdAt: Date
  /// When the mark was last reviewed.
  public var lastReviewedAt: Date?

  // MARK: - SM-2 Spaced Repetition Fields
  /// Ease factor (starts at 2.5, min 1.3). Higher = longer intervals.
  public var easeFactor: Double
  /// Current interval in days until next review.
  public var intervalDays: Double
  /// Number of successful repetitions (consecutive correct answers).
  public var repetitions: Int
  /// When the mark is next due for review.
  public var nextReviewDate: Date?

  // MARK: - FSRS DSR Fields
  /// Which algorithm this mastery record uses.
  public var algorithm: SRSAlgorithm
  /// FSRS difficulty (1–10). Intrinsic property of the card.
  public var fsrsDifficulty: Double
  /// FSRS stability (days). Time for retrievability to drop to 90%.
  public var fsrsStability: Double
  /// Timestamp of last FSRS review (for computing current retrievability).
  public var fsrsLastReviewTimestamp: Date?
  /// User's desired retention target (0.7–0.95, default 0.9).
  public var desiredRetention: Double
  /// Learning steps (in days) before graduation into the main schedule.
  public var learningSteps: [Double]
  /// Current learning step index (-1 = graduated).
  public var currentLearningStep: Int
  /// Number of lapses (for leech detection).
  public var lapseCount: Int

  public var id: UUID { markID }

  public var accuracy: Double {
    guard totalAttempts > 0 else { return 0 }
    return Double(correctCount) / Double(totalAttempts)
  }

  /// Whether this mark is due for review now.
  /// Marks with no next review date are always due.
  public var isDue: Bool {
    guard let nextReview = nextReviewDate else { return true }
    return Date() >= nextReview
  }

  /// Days until next review (negative = overdue).
  public var daysUntilReview: Double {
    guard let nextReview = nextReviewDate else { return 0 }
    return nextReview.timeIntervalSinceNow / 86400.0
  }

  /// Whether this mark is a leech (too many lapses).
  public var isLeech: Bool { lapseCount >= 8 }

  /// Current FSRS retrievability.
  public var currentRetrievability: Double {
    let state = FSRS.MemoryState(
      difficulty: fsrsDifficulty,
      stability: fsrsStability,
      lastReviewTimestamp: fsrsLastReviewTimestamp
    )
    return state.retrievability()
  }

  public init(
    markID: UUID,
    easeFactor: Double = 2.5,
    intervalDays: Double = 0,
    repetitions: Int = 0,
    nextReviewDate: Date? = nil,
    algorithm: SRSAlgorithm = .sm2,
    fsrsDifficulty: Double = 5.0,
    fsrsStability: Double = 1.0,
    fsrsLastReviewTimestamp: Date? = nil,
    desiredRetention: Double = 0.9,
    learningSteps: [Double] = [1.0/1440, 10.0/1440, 1.0],
    currentLearningStep: Int = -1,
    lapseCount: Int = 0
  ) {
    self.markID = markID
    self.level = .new
    self.correctStreak = 0
    self.totalAttempts = 0
    self.correctCount = 0
    self.createdAt = Date()
    self.lastReviewedAt = nil
    self.easeFactor = easeFactor
    self.intervalDays = intervalDays
    self.repetitions = repetitions
    self.nextReviewDate = nextReviewDate
    self.algorithm = algorithm
    self.fsrsDifficulty = fsrsDifficulty
    self.fsrsStability = fsrsStability
    self.fsrsLastReviewTimestamp = fsrsLastReviewTimestamp
    self.desiredRetention = desiredRetention
    self.learningSteps = learningSteps
    self.currentLearningStep = currentLearningStep
    self.lapseCount = lapseCount
  }

  // MARK: - Unified Grading

  /// Record a review using the unified 4-grade system.
  /// Routes to SM-2 or FSRS based on the algorithm field.
  public mutating func recordGrade(_ grade: UnifiedGrade) {
    switch algorithm {
    case .sm2:
      recordSM2Grade(grade)
    case .fsrs:
      recordFSRSGrade(grade)
    }
  }

  // MARK: - SM-2 Path (backward compatible)

  /// Record a correct recall using SM-2 algorithm.
  /// Uses .easy grade for backward compatibility with pre-FSRS behavior.
  public mutating func recordCorrect() {
    recordSM2Grade(.easy)
  }

  /// Record an incorrect recall (resets SM-2 state).
  public mutating func recordIncorrect() {
    recordSM2Grade(.again)
  }

  private mutating func recordSM2Grade(_ grade: UnifiedGrade) {
    totalAttempts += 1
    lastReviewedAt = Date()

    if grade.isCorrect {
      correctCount += 1
      correctStreak += 1
      repetitions += 1

      // Ease-hell prevention: boost EF after 3 consecutive corrects at low EF
      if correctStreak >= 3 && easeFactor < 1.5 {
        easeFactor = min(2.5, easeFactor + 0.15)
      }

      switch repetitions {
      case 1:
        intervalDays = 1
      case 2:
        intervalDays = 6  // SM-2 standard: 1d, 6d
      default:
        intervalDays = intervalDays * easeFactor
      }

      // EF update based on quality
      let q = grade.sm2Quality
      let efDelta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
      easeFactor = min(3.0, max(1.3, easeFactor + efDelta))

      // Learning steps: if still in learning phase, step through short intervals
      if currentLearningStep >= 0 && currentLearningStep < learningSteps.count {
        intervalDays = learningSteps[currentLearningStep]
        currentLearningStep += 1
        if currentLearningStep >= learningSteps.count {
          currentLearningStep = -1 // graduated
        }
      }

      // Minimum interval: 3 days for graduated cards (ease-hell prevention)
      if currentLearningStep == -1 {
        intervalDays = max(3.0, intervalDays)
      }

      nextReviewDate = Date().addingTimeInterval(intervalDays * 86400)

      // Update mastery level
      if repetitions >= 4 {
        level = .mastered
      } else if repetitions >= 2 {
        level = .review
      } else if repetitions >= 1 {
        level = .learning
      }

    } else {
      // Lapse
      correctStreak = 0
      lapseCount += 1
      repetitions = 0
      intervalDays = 0
      easeFactor = max(1.3, easeFactor - 0.2)
      currentLearningStep = 0 // restart learning steps
      nextReviewDate = nil // Due immediately

      if level.rawValue > 0 {
        level = MasteryLevel(rawValue: level.rawValue - 1) ?? .new
      }
    }
  }

  // MARK: - FSRS Path

  private mutating func recordFSRSGrade(_ grade: UnifiedGrade) {
    totalAttempts += 1
    lastReviewedAt = Date()

    let fsrsGrade = grade.fsrsGrade
    let currentState = FSRS.MemoryState(
      difficulty: fsrsDifficulty,
      stability: fsrsStability,
      lastReviewTimestamp: fsrsLastReviewTimestamp
    )

    let (newState, nextInterval) = FSRS.nextState(
      current: currentState,
      grade: fsrsGrade,
      desiredRetention: desiredRetention
    )

    fsrsDifficulty = newState.difficulty
    fsrsStability = newState.stability
    fsrsLastReviewTimestamp = newState.lastReviewTimestamp
    intervalDays = nextInterval
    nextReviewDate = Date().addingTimeInterval(nextInterval * 86400)

    if grade.isCorrect {
      correctCount += 1
      correctStreak += 1
      repetitions += 1
    } else {
      correctStreak = 0
      lapseCount += 1
      repetitions = 0
    }

    // Update mastery level based on stability and repetitions
    if fsrsStability > 30 && repetitions >= 4 {
      level = .mastered
    } else if fsrsStability > 7 && repetitions >= 2 {
      level = .review
    } else if repetitions >= 1 {
      level = .learning
    }
  }
}

// MARK: - Study Session

/// A single study session — tracks progress through a set of marks.
public struct StudySession: Sendable {
  /// The marks being studied (ordered).
  public let marks: [AnnotationMark]
  /// The current study mode.
  public let mode: StudyMode
  /// Current index in the marks array.
  public let currentIndex: Int
  /// Per-mark mastery levels.
  public let mastery: [UUID: MarkMastery]
  /// Session start time.
  public let startedAt: Date

  public init(
    marks: [AnnotationMark],
    mode: StudyMode,
    currentIndex: Int,
    mastery: [UUID: MarkMastery],
    startedAt: Date
  ) {
    self.marks = marks
    self.mode = mode
    self.currentIndex = currentIndex
    self.mastery = mastery
    self.startedAt = startedAt
  }
  /// Whether the session is complete.
  public var isComplete: Bool {
    currentIndex >= marks.count
  }
  /// The current question (if any).
  public var currentQuestion: RecallQuestion? {
    guard currentIndex < marks.count else { return nil }
    return RecallQuestion(mark: marks[currentIndex])
  }
  /// Progress fraction (0.0 – 1.0).
  public var progress: Double {
    guard !marks.isEmpty else { return 1.0 }
    return Double(currentIndex) / Double(marks.count)
  }
  /// Number of marks reviewed so far.
  public var reviewedCount: Int { currentIndex }
  /// Number of marks remaining.
  public var remainingCount: Int { max(0, marks.count - currentIndex) }

  /// Summary of mastery across all marks in this session.
  public var masterySummary: MasterySummary {
    var counts: [MasteryLevel: Int] = [:]
    for level in MasteryLevel.allCases { counts[level] = 0 }
    for mark in marks {
      let level = mastery[mark.id]?.level ?? .new
      counts[level, default: 0] += 1
    }
    return MasterySummary(
      total: marks.count,
      new: counts[.new] ?? 0,
      seen: counts[.seen] ?? 0,
      learning: counts[.learning] ?? 0,
      review: counts[.review] ?? 0,
      mastered: counts[.mastered] ?? 0
    )
  }
}

// MARK: - Mastery Summary

/// Aggregate mastery stats for a set of marks.
public struct MasterySummary: Codable, Sendable {
  public let total: Int
  public let new: Int
  public let seen: Int
  public let learning: Int
  public let review: Int
  public let mastered: Int

  public var masteredFraction: Double {
    guard total > 0 else { return 0 }
    return Double(mastered) / Double(total)
  }

  public var description: String {
    "\(mastered)/\(total) mastered (\(Int(masteredFraction * 100))%)"
  }
}

/// Review schedule summary for a document.
public struct ReviewSchedule: Codable, Sendable {
  public let totalMarks: Int
  /// Marks that are due right now.
  public let dueNow: Int
  /// Marks due today.
  public let dueToday: Int
  /// Marks due this week.
  public let dueThisWeek: Int
  /// Marks due later than this week.
  public let dueLater: Int
  /// Marks that are overdue (past their next review date).
  public let overdue: Int

  /// Whether any marks need review.
  public var hasWork: Bool { dueNow > 0 || overdue > 0 }

  /// Fraction of marks due now or overdue.
  public var urgencyFraction: Double {
    guard totalMarks > 0 else { return 0 }
    return Double(dueNow + overdue) / Double(totalMarks)
  }

  public var description: String {
    if overdue > 0 {
      return "\(overdue) overdue, \(dueNow) due now"
    } else if dueNow > 0 {
      return "\(dueNow) due now"
    } else if dueToday > 0 {
      return "\(dueToday) due today"
    } else {
      return "All caught up!"
    }
  }
}

// MARK: - Study Progress Report

/// Per-mark report data for export.
public struct MarkReport: Codable, Sendable, Identifiable {
  public let id: String
  public let pageIndex: Int
  public let selectedText: String
  public let note: String
  public let type: String
  public let color: String
  public let level: String
  public let accuracy: Double
  public let totalAttempts: Int
  public let correctCount: Int
  public let correctStreak: Int
  public let easeFactor: Double
  public let intervalDays: Double
  public let repetitions: Int
  public let nextReviewDate: Date?
  public let lastReviewedAt: Date?
  public let createdAt: Date

  public init(
    markID: String,
    pageIndex: Int,
    selectedText: String,
    note: String,
    type: String,
    color: String,
    level: String,
    accuracy: Double,
    totalAttempts: Int,
    correctCount: Int,
    correctStreak: Int,
    easeFactor: Double,
    intervalDays: Double,
    repetitions: Int,
    nextReviewDate: Date?,
    lastReviewedAt: Date?,
    createdAt: Date
  ) {
    self.id = markID
    self.pageIndex = pageIndex
    self.selectedText = selectedText
    self.note = note
    self.type = type
    self.color = color
    self.level = level
    self.accuracy = accuracy
    self.totalAttempts = totalAttempts
    self.correctCount = correctCount
    self.correctStreak = correctStreak
    self.easeFactor = easeFactor
    self.intervalDays = intervalDays
    self.repetitions = repetitions
    self.nextReviewDate = nextReviewDate
    self.lastReviewedAt = lastReviewedAt
    self.createdAt = createdAt
  }
}

/// Complete study progress report for export.
public struct StudyProgressReport: Codable, Sendable {
  public let documentID: String
  public let generatedAt: Date
  public let totalMarks: Int
  public let summary: MasterySummary
  public let schedule: ReviewSchedule
  public let marks: [MarkReport]

  public init(
    documentID: String,
    generatedAt: Date,
    totalMarks: Int,
    summary: MasterySummary,
    schedule: ReviewSchedule,
    marks: [MarkReport]
  ) {
    self.documentID = documentID
    self.generatedAt = generatedAt
    self.totalMarks = totalMarks
    self.summary = summary
    self.schedule = schedule
    self.marks = marks
  }

  /// Generate CSV representation of the report.
  public func toCSV() -> String {
    var csv = "Mark ID,Page,Type,Color,Level,Accuracy,Attempts,Correct,Streak,Ease Factor,Interval (days),Repetitions,Next Review,Last Reviewed,Created,Selected Text,Note\n"

    let dateFormatter = ISO8601DateFormatter()

    for mark in marks {
      let selectedText = mark.selectedText.replacingOccurrences(of: "\"", with: "\"\"")
      let note = mark.note.replacingOccurrences(of: "\"", with: "\"\"")
      let nextReview = mark.nextReviewDate.map { dateFormatter.string(from: $0) } ?? ""
      let lastReviewed = mark.lastReviewedAt.map { dateFormatter.string(from: $0) } ?? ""
      let created = dateFormatter.string(from: mark.createdAt)

      csv += "\(mark.id),\(mark.pageIndex),\(mark.type),\(mark.color),\(mark.level),"
      csv += "\(String(format: "%.1f", mark.accuracy * 100))%,\(mark.totalAttempts),\(mark.correctCount),\(mark.correctStreak),"
      csv += "\(String(format: "%.2f", mark.easeFactor)),\(String(format: "%.1f", mark.intervalDays)),\(mark.repetitions),"
      let escapedText = "\"\(selectedText)\""
      let escapedNote = "\"\(note)\""
      csv += "\(nextReview),\(lastReviewed),\(created),\(escapedText),\(escapedNote)\n"
    }

    return csv
  }
}

// MARK: - Study Loop Manager

/// Orchestrates study sessions — creates sessions, advances through marks,
/// records mastery, and persists mastery data.
///
/// Usage:
/// ```swift
/// let manager = StudyLoopManager()
/// let session = manager.startSession(marks: marks, mode: .recall)
/// // ... user recalls ...
/// manager.recordCorrect(session: &session)
/// manager.advanceSession(&session)
/// ```
public final class StudyLoopManager: ObservableObject, @unchecked Sendable {
  /// Per-document mastery data, keyed by document ID.
  @Published public var masteryByDocument: [String: [UUID: MarkMastery]] = [:]

  private let storageKey = "com.pdfeditor.studyloop.mastery"

  public init() {
    load()
  }

  // MARK: - Session Lifecycle

  /// Create a new study session from a set of marks.
  /// Marks are sorted by page then by vertical position for logical flow.
  public func startSession(
    marks: [AnnotationMark],
    mode: StudyMode,
    documentID: String
  ) -> StudySession {
    let docMastery = masteryByDocument[documentID] ?? [:]

    let sorted: [AnnotationMark]
    switch mode {
    case .review, .recall:
      sorted = marks.sorted { (a: AnnotationMark, b: AnnotationMark) in
        if a.pageIndex != b.pageIndex { return a.pageIndex < b.pageIndex }
        return a.bounds.y < b.bounds.y
      }
    case .quiz:
      sorted = marks.shuffled()
    }

    return StudySession(
      marks: sorted,
      mode: mode,
      currentIndex: 0,
      mastery: docMastery,
      startedAt: Date()
    )
  }

  /// Advance to the next mark in the session.
  public func advanceSession(_ session: inout StudySession) {
    // This is a value type — we can't mutate it directly.
    // The caller replaces it with a new session at currentIndex + 1.
  }

  /// Create the next session state after advancing.
  public func nextSessionState(from session: StudySession) -> StudySession {
    StudySession(
      marks: session.marks,
      mode: session.mode,
      currentIndex: session.currentIndex + 1,
      mastery: session.mastery,
      startedAt: session.startedAt
    )
  }

  // MARK: - Mastery Recording

  /// Record a correct recall for the current mark.
  public func recordCorrect(documentID: String, markID: UUID) {
    var docMastery = masteryByDocument[documentID] ?? [:]
    var mastery = docMastery[markID] ?? MarkMastery(markID: markID)
    mastery.recordCorrect()
    docMastery[markID] = mastery
    masteryByDocument[documentID] = docMastery
    save()
  }

  /// Record an incorrect recall for the current mark.
  public func recordIncorrect(documentID: String, markID: UUID) {
    var docMastery = masteryByDocument[documentID] ?? [:]
    var mastery = docMastery[markID] ?? MarkMastery(markID: markID)
    mastery.recordIncorrect()
    docMastery[markID] = mastery
    masteryByDocument[documentID] = docMastery
    save()
  }

  /// Record a review using the unified 4-grade system.
  /// Routes to SM-2 or FSRS based on the mark's algorithm setting.
  public func recordGrade(_ grade: UnifiedGrade, documentID: String, markID: UUID) {
    var docMastery = masteryByDocument[documentID] ?? [:]
    var mastery = docMastery[markID] ?? MarkMastery(markID: markID)
    mastery.recordGrade(grade)
    docMastery[markID] = mastery
    masteryByDocument[documentID] = docMastery
    save()
  }

  /// Set the SRS algorithm for a specific mark.
  public func setAlgorithm(_ algorithm: SRSAlgorithm, documentID: String, markID: UUID) {
    var docMastery = masteryByDocument[documentID] ?? [:]
    var mastery = docMastery[markID] ?? MarkMastery(markID: markID)
    mastery.algorithm = algorithm
    if algorithm == .fsrs {
      // Initialize FSRS state from SM-2 state if migrating
      if mastery.fsrsStability <= 1.0 && mastery.repetitions > 0 {
        mastery.fsrsStability = max(1.0, mastery.intervalDays / 2.0)
        mastery.fsrsDifficulty = max(1.0, min(10.0, 10.0 - (mastery.easeFactor - 1.3) * 5.0))
      }
    }
    docMastery[markID] = mastery
    masteryByDocument[documentID] = docMastery
    save()
  }

  /// Set desired retention for a specific mark (FSRS only).
  public func setDesiredRetention(_ retention: Double, documentID: String, markID: UUID) {
    var docMastery = masteryByDocument[documentID] ?? [:]
    var mastery = docMastery[markID] ?? MarkMastery(markID: markID)
    mastery.desiredRetention = min(0.95, max(0.7, retention))
    docMastery[markID] = mastery
    masteryByDocument[documentID] = docMastery
    save()
  }

  /// Get mastery for a specific mark.
  public func mastery(for markID: UUID, documentID: String) -> MarkMastery? {
    masteryByDocument[documentID]?[markID]
  }

  /// Get mastery summary for a document.
  public func summary(for documentID: String, marks: [AnnotationMark]) -> MasterySummary {
    let docMastery = masteryByDocument[documentID] ?? [:]
    var counts: [MasteryLevel: Int] = [:]
    for level in MasteryLevel.allCases { counts[level] = 0 }
    for mark in marks {
      let level = docMastery[mark.id]?.level ?? .new
      counts[level, default: 0] += 1
    }
    return MasterySummary(
      total: marks.count,
      new: counts[.new] ?? 0,
      seen: counts[.seen] ?? 0,
      learning: counts[.learning] ?? 0,
      review: counts[.review] ?? 0,
      mastered: counts[.mastered] ?? 0
    )
  }

  /// Get marks that need review (not yet mastered).
  public func marksNeedingReview(_ marks: [AnnotationMark], documentID: String) -> [AnnotationMark] {
    let docMastery = masteryByDocument[documentID] ?? [:]
    return marks.filter { mark in
      let level = docMastery[mark.id]?.level ?? .new
      return level < .mastered
    }
  }

  // MARK: - Spaced Repetition Scheduling

  /// Get marks that are due for review (SM-2 schedule).
  public func marksDueForReview(_ marks: [AnnotationMark], documentID: String) -> [AnnotationMark] {
    let docMastery = masteryByDocument[documentID] ?? [:]
    return marks.filter { mark in
      let mastery = docMastery[mark.id]
      return mastery?.isDue ?? true // New marks are always due
    }
  }

  /// Get marks sorted by review priority (most overdue first).
  public func marksByReviewPriority(_ marks: [AnnotationMark], documentID: String) -> [AnnotationMark] {
    let docMastery = masteryByDocument[documentID] ?? [:]
    return marks.sorted { a, b in
      let aMastery = docMastery[a.id]
      let bMastery = docMastery[b.id]
      // New marks first, then by daysUntilReview (most overdue first)
      let aDue = aMastery?.isDue ?? true
      let bDue = bMastery?.isDue ?? true
      if aDue != bDue { return aDue }
      let aDays = aMastery?.daysUntilReview ?? 0
      let bDays = bMastery?.daysUntilReview ?? 0
      return aDays < bDays
    }
  }  /// Create a spaced repetition session (due marks only, sorted by priority).
  public func startSpacedRepetitionSession(
    marks: [AnnotationMark], documentID: String
  ) -> StudySession {
    let dueMarks = marksDueForReview(marks, documentID: documentID)
    let sorted = marksByReviewPriority(dueMarks, documentID: documentID)
    let docMastery = masteryByDocument[documentID] ?? [:]
    return StudySession(
      marks: sorted,
      mode: .recall,
      currentIndex: 0,
      mastery: docMastery,
      startedAt: Date()
    )
  }

  /// Get the review schedule summary for a document.
  public func reviewSchedule(for documentID: String, marks: [AnnotationMark]) -> ReviewSchedule {
    let docMastery = masteryByDocument[documentID] ?? [:]
    var dueNow = 0
    var dueToday = 0
    var dueThisWeek = 0
    var dueLater = 0
    var overdue = 0

    let now = Date()
    let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
    let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

    for mark in marks {
      let mastery = docMastery[mark.id]
      if mastery?.isDue ?? true {
        dueNow += 1
      } else if let nextReview = mastery?.nextReviewDate {
        if nextReview < now {
          overdue += 1
        } else if nextReview < endOfDay {
          dueToday += 1
        } else if nextReview < endOfWeek {
          dueThisWeek += 1
        } else {
          dueLater += 1
        }
      }
    }

    return ReviewSchedule(
      totalMarks: marks.count,
      dueNow: dueNow,
      dueToday: dueToday,
      dueThisWeek: dueThisWeek,
      dueLater: dueLater,
      overdue: overdue
    )
  }

  // MARK: - Progress Report Export

  /// Generate a study progress report for a document.
  public func generateReport(
    documentID: String,
    marks: [AnnotationMark]
  ) -> StudyProgressReport {
    let docMastery = masteryByDocument[documentID] ?? [:]

    var markReports: [MarkReport] = []
    for mark in marks {
      let mastery = docMastery[mark.id]
      markReports.append(MarkReport(
        markID: mark.id.uuidString,
        pageIndex: mark.pageIndex,
        selectedText: mark.selectedText,
        note: mark.note,
        type: mark.type.rawValue,
        color: mark.color.rawValue,
        level: mastery?.level.displayName ?? "New",
        accuracy: mastery?.accuracy ?? 0,
        totalAttempts: mastery?.totalAttempts ?? 0,
        correctCount: mastery?.correctCount ?? 0,
        correctStreak: mastery?.correctStreak ?? 0,
        easeFactor: mastery?.easeFactor ?? 2.5,
        intervalDays: mastery?.intervalDays ?? 0,
        repetitions: mastery?.repetitions ?? 0,
        nextReviewDate: mastery?.nextReviewDate,
        lastReviewedAt: mastery?.lastReviewedAt,
        createdAt: mastery?.createdAt ?? Date()
      ))
    }

    let summary = summary(for: documentID, marks: marks)
    let schedule = reviewSchedule(for: documentID, marks: marks)

    return StudyProgressReport(
      documentID: documentID,
      generatedAt: Date(),
      totalMarks: marks.count,
      summary: summary,
      schedule: schedule,
      marks: markReports
    )
  }

  /// Export study progress as CSV data.
  public func exportCSV(
    documentID: String,
    marks: [AnnotationMark]
  ) -> Data? {
    let report = generateReport(documentID: documentID, marks: marks)
    return report.toCSV().data(using: .utf8)
  }

  /// Export study progress as JSON data.
  public func exportJSON(
    documentID: String,
    marks: [AnnotationMark]
  ) -> Data? {
    let report = generateReport(documentID: documentID, marks: marks)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try? encoder.encode(report)
  }

  // MARK: - Persistence

  private func save() {
    guard let data = try? JSONEncoder().encode(masteryByDocument) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let loaded = try? JSONDecoder().decode([String: [UUID: MarkMastery]].self, from: data)
    else { return }
    masteryByDocument = loaded
  }

  /// Clear all mastery data (for testing).
  public func clearAll() {
    masteryByDocument = [:]
    UserDefaults.standard.removeObject(forKey: storageKey)
  }
}
