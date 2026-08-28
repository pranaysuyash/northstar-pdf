import Foundation
import Testing
@testable import PDFEditorCore

@Suite("StudyLoop")
struct StudyLoopTests {

  // MARK: - MarkMastery

  @Test("MarkMastery starts as new")
  func masteryStartsAsNew() {
    let m = MarkMastery(markID: UUID())
    #expect(m.level == .new)
    #expect(m.correctStreak == 0)
    #expect(m.totalAttempts == 0)
    #expect(m.accuracy == 0)
  }

  @Test("Correct recall advances mastery")
  func correctAdvancesMastery() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    #expect(m.level == .learning)
    #expect(m.correctStreak == 1)
    #expect(m.totalAttempts == 1)
    #expect(m.correctCount == 1)
    #expect(m.accuracy == 1.0)

    m.recordCorrect()
    #expect(m.level == .review)
    #expect(m.correctStreak == 2)

    m.recordCorrect()
    #expect(m.level == .review)
    #expect(m.correctStreak == 3)

    m.recordCorrect()
    #expect(m.level == .mastered)
    #expect(m.correctStreak == 4)
  }

  @Test("Incorrect recall demotes mastery and resets streak")
  func incorrectDemotesMastery() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    m.recordCorrect()
    #expect(m.level == .review)
    #expect(m.correctStreak == 2)

    m.recordIncorrect()
    #expect(m.level == .learning)
    #expect(m.correctStreak == 0)
    #expect(m.totalAttempts == 3)
    #expect(m.accuracy == 2.0 / 3.0)
  }

  @Test("Incorrect at new stays new")
  func incorrectAtNewStaysNew() {
    var m = MarkMastery(markID: UUID())
    m.recordIncorrect()
    #expect(m.level == .new)
    #expect(m.correctStreak == 0)
  }

  @Test("MasteryLevel is Comparable")
  func masteryComparable() {
    #expect(MasteryLevel.new < MasteryLevel.seen)
    #expect(MasteryLevel.seen < MasteryLevel.learning)
    #expect(MasteryLevel.learning < MasteryLevel.review)
    #expect(MasteryLevel.review < MasteryLevel.mastered)
  }

  // MARK: - RecallQuestion / RecallAnswer

  @Test("RecallQuestion extracts hint from selectedText")
  func questionHint() {
    let mark = makeMark(text: "The mitochondria is the powerhouse of the cell")
    let q = RecallQuestion(mark: mark)
    #expect(q.hint == "The mitochondria is...")
    #expect(q.pageNumber == 1)
    #expect(q.category == "Highlight")
  }

  @Test("RecallQuestion with short text shows full hint")
  func questionShortHint() {
    let mark = makeMark(text: "Hello world")
    let q = RecallQuestion(mark: mark)
    #expect(q.hint == "Hello world")
  }

  @Test("RecallAnswer pulls from question")
  func answerFromQuestion() {
    let mark = makeMark(text: "Important fact", note: "Remember this!")
    let q = RecallQuestion(mark: mark)
    let a = RecallAnswer(question: q)
    #expect(a.selectedText == "Important fact")
    #expect(a.note == "Remember this!")
    #expect(a.pageNumber == 1)
  }

  // MARK: - StudySession

  @Test("Session sorts marks by page then vertical position")
  func sessionSorting() {
    let m1 = makeMark(page: 1, y: 100)
    let m2 = makeMark(page: 0, y: 50)
    let m3 = makeMark(page: 0, y: 10)

    let manager = StudyLoopManager()
    manager.clearAll()
    let session = manager.startSession(
      marks: [m1, m2, m3], mode: .review, documentID: "test"
    )
    #expect(session.marks[0].pageIndex == 0)
    #expect(session.marks[0].bounds.y == 10)
    #expect(session.marks[1].bounds.y == 50)
    #expect(session.marks[2].pageIndex == 1)
  }

  @Test("Session quiz mode shuffles marks")
  func sessionQuizShuffles() {
    let marks = (0..<20).map { makeMark(page: 0, y: Double($0 * 10)) }
    let manager = StudyLoopManager()
    manager.clearAll()

    // Run multiple times — at least one should differ from sorted
    var differentCount = 0
    for _ in 0..<5 {
      let session = manager.startSession(
        marks: marks, mode: .quiz, documentID: "test"
      )
      if session.marks[0].bounds.y != 0 {
        differentCount += 1
      }
    }
    // With 20 items, at least one shuffle should differ
    #expect(differentCount > 0)
  }

  @Test("Session progress and completion")
  func sessionProgress() {
    let marks = [makeMark(), makeMark(), makeMark()]
    let manager = StudyLoopManager()
    manager.clearAll()
    var session = manager.startSession(
      marks: marks, mode: .review, documentID: "test"
    )

    #expect(session.progress == 0)
    #expect(session.isComplete == false)
    #expect(session.reviewedCount == 0)
    #expect(session.remainingCount == 3)

    session = manager.nextSessionState(from: session)
    #expect(session.currentIndex == 1)
    #expect(session.reviewedCount == 1)
    #expect(session.remainingCount == 2)

    session = manager.nextSessionState(from: session)
    session = manager.nextSessionState(from: session)
    #expect(session.isComplete == true)
    #expect(session.progress == 1.0)
  }

  @Test("Empty session is complete")
  func emptySession() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let session = manager.startSession(
      marks: [], mode: .review, documentID: "test"
    )
    #expect(session.isComplete == true)
    #expect(session.progress == 1.0)
  }

  // MARK: - StudyLoopManager

  @Test("Manager records correct recall")
  func managerRecordCorrect() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let markID = UUID()
    let docID = "test-doc"

    manager.recordCorrect(documentID: docID, markID: markID)
    let m = manager.mastery(for: markID, documentID: docID)
    #expect(m != nil)
    #expect(m?.level == .learning)
    #expect(m?.correctStreak == 1)
  }

  @Test("Manager records incorrect recall")
  func managerRecordIncorrect() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let markID = UUID()
    let docID = "test-doc"

    manager.recordCorrect(documentID: docID, markID: markID)
    manager.recordCorrect(documentID: docID, markID: markID)
    manager.recordIncorrect(documentID: docID, markID: markID)
    let m = manager.mastery(for: markID, documentID: docID)
    #expect(m?.level == .learning)
    #expect(m?.correctStreak == 0)
  }

  @Test("Manager computes mastery summary")
  func managerSummary() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let marks = (0..<5).map { _ in makeMark() }

    // Mark first 2 as mastered
    manager.recordCorrect(documentID: docID, markID: marks[0].id)
    manager.recordCorrect(documentID: docID, markID: marks[0].id)
    manager.recordCorrect(documentID: docID, markID: marks[0].id)
    manager.recordCorrect(documentID: docID, markID: marks[0].id)
    manager.recordCorrect(documentID: docID, markID: marks[1].id)
    manager.recordCorrect(documentID: docID, markID: marks[1].id)
    manager.recordCorrect(documentID: docID, markID: marks[1].id)
    manager.recordCorrect(documentID: docID, markID: marks[1].id)

    let summary = manager.summary(for: docID, marks: marks)
    #expect(summary.total == 5)
    // Both marks[0] and marks[1] got 4 correct → .mastered
    #expect(summary.mastered == 2)
    #expect(summary.masteredFraction == 0.4)
  }

  @Test("Manager filters marks needing review")
  func managerMarksNeedingReview() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let m1 = makeMark()
    let m2 = makeMark()
    let m3 = makeMark()

    // Master m1
    for _ in 0..<4 {
      manager.recordCorrect(documentID: docID, markID: m1.id)
    }

    // m1 mastered (4 correct), m2 new, m3 new
    let needingReview = manager.marksNeedingReview([m1, m2, m3], documentID: docID)
    // m1 has nextReviewDate set (1 day out) → isDue is false
    // m2, m3 have no nextReviewDate → isDue is true
    // So only m2 and m3 need review
    #expect(needingReview.count == 2)
    #expect(needingReview.allSatisfy { $0.id != m1.id })
  }

  // MARK: - MasterySummary

  @Test("MasterySummary description")
  func summaryDescription() {
    let s = MasterySummary(total: 10, new: 2, seen: 1, learning: 2, review: 3, mastered: 2)
    #expect(s.description == "2/10 mastered (20%)")
    #expect(s.masteredFraction == 0.2)
  }

  @Test("MasterySummary with zero total")
  func summaryZeroTotal() {
    let s = MasterySummary(total: 0, new: 0, seen: 0, learning: 0, review: 0, mastered: 0)
    #expect(s.masteredFraction == 0)
    #expect(s.description == "0/0 mastered (0%)")
  }

  // MARK: - StudyMode

  @Test("StudyMode has all 3 cases")
  func studyModeCases() {
    #expect(StudyMode.allCases.count == 3)
    #expect(StudyMode.allCases.contains(.review))
    #expect(StudyMode.allCases.contains(.recall))
    #expect(StudyMode.allCases.contains(.quiz))
  }

  @Test("MasteryLevel has all 5 cases")
  func masteryLevelCases() {
    #expect(MasteryLevel.allCases.count == 5)
  }

  // MARK: - SM-2 Spaced Repetition

  @Test("SM-2: new mark has default ease factor")
  func sm2Defaults() {
    let m = MarkMastery(markID: UUID())
    #expect(m.easeFactor == 2.5)
    #expect(m.intervalDays == 0)
    #expect(m.repetitions == 0)
    #expect(m.nextReviewDate == nil)
    #expect(m.isDue == true)
  }

  @Test("SM-2: first correct sets interval with minimum floor")
  func sm2FirstCorrect() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    #expect(m.repetitions == 1)
    // SM-2: first interval is 1 day, but minimum floor is 3 days
    #expect(m.intervalDays == 3.0)
    // .easy grade (q=5): EF increases by 0.1
    #expect(abs(m.easeFactor - 2.6) < 0.01)
    #expect(m.nextReviewDate != nil)
    #expect(m.isDue == false)
  }

  @Test("SM-2: second correct sets 6 day interval")
  func sm2SecondCorrect() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    m.recordCorrect()
    #expect(m.repetitions == 2)
    // SM-2: second interval is 6 days
    #expect(m.intervalDays == 6.0)
    #expect(abs(m.easeFactor - 2.7) < 0.01)
  }

  @Test("SM-2: third correct uses ease factor multiplication")
  func sm2ThirdCorrect() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    m.recordCorrect()
    m.recordCorrect()
    #expect(m.repetitions == 3)
    // Standard SM-2: 1d, 6d, then interval × EF
    // recordCorrect() uses .easy grade (q=5): EF increases by 0.1 each time
    // After 3 correct: interval uses EF before update (2.7) → 6 * 2.7 = 16.2
    // EF then updates to 2.8
    #expect(abs(m.intervalDays - 16.2) < 0.01)
    #expect(abs(m.easeFactor - 2.8) < 0.01)
  }

  @Test("SM-2: ease factor caps at 3.0")
  func sm2EaseFactorCap() {
    var m = MarkMastery(markID: UUID())
    // Record many correct to push ease factor up
    for _ in 0..<10 {
      m.recordCorrect()
    }
    #expect(abs(m.easeFactor - 3.0) < 0.01)
  }

  @Test("SM-2: incorrect reduces ease factor")
  func sm2IncorrectReducesEase() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    m.recordCorrect()
    // .easy grade: EF increases by 0.1 each time → 2.7
    #expect(abs(m.easeFactor - 2.7) < 0.01)

    m.recordIncorrect()
    // EF decreases by 0.2 on lapse → 2.5
    #expect(abs(m.easeFactor - 2.5) < 0.01) // 2.7 - 0.2
    #expect(m.repetitions == 0)
    #expect(m.intervalDays == 0)
    #expect(m.isDue == true) // Due again immediately
  }

  @Test("SM-2: ease factor floor is 1.3")
  func sm2EaseFactorFloor() {
    var m = MarkMastery(markID: UUID())
    m.easeFactor = 1.4
    m.recordIncorrect()
    #expect(abs(m.easeFactor - 1.3) < 0.01) // 1.4 - 0.2 = 1.2, but floor is 1.3
    m.recordIncorrect()
    #expect(abs(m.easeFactor - 1.3) < 0.01) // Still capped at 1.3
  }

  @Test("SM-2: mastery level updates with SM-2 state")
  func sm2MasteryLevel() {
    var m = MarkMastery(markID: UUID())
    m.recordCorrect()
    #expect(m.level == .learning) // 1 rep

    m.recordCorrect()
    m.recordCorrect()
    #expect(m.level == .review) // 3 reps >= 2

    m.recordCorrect()
    #expect(m.level == .mastered) // 4 reps >= 4
  }

  @Test("SM-2: mastered after 5+ reps and 21+ day interval")
  func sm2Mastered() {
    var m = MarkMastery(markID: UUID())
    // Build up to high ease factor and many reps
    for _ in 0..<5 {
      m.recordCorrect()
    }
    #expect(m.repetitions == 5)
    // With ease 3.0, interval should be large enough
    // 3 days * 3.0 = 9, then 9 * 3.0 = 27, then 27 * 3.0 = 81
    #expect(m.intervalDays >= 21)
    #expect(m.level == .mastered)
  }

  // MARK: - ReviewSchedule

  @Test("ReviewSchedule tracks due marks")
  func reviewSchedule() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let marks = (0..<5).map { _ in makeMark() }

    // Master 2 marks
    for _ in 0..<5 {
      manager.recordCorrect(documentID: docID, markID: marks[0].id)
      manager.recordCorrect(documentID: docID, markID: marks[1].id)
    }

    let schedule = manager.reviewSchedule(for: docID, marks: marks)
    #expect(schedule.totalMarks == 5)
    #expect(schedule.hasWork == true) // 3 marks are still due
  }

  @Test("ReviewSchedule: all mastered shows no work")
  func reviewScheduleAllMastered() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let marks = (0..<3).map { _ in makeMark() }

    for mark in marks {
      for _ in 0..<5 {
        manager.recordCorrect(documentID: docID, markID: mark.id)
      }
    }

    let schedule = manager.reviewSchedule(for: docID, marks: marks)
    #expect(schedule.hasWork == false)
    #expect(schedule.description == "All caught up!")
  }

  // MARK: - Spaced Repetition Session

  @Test("Spaced repetition session returns due marks")
  func spacedRepetitionSession() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let marks = (0..<5).map { _ in makeMark() }

    // Master 2 marks (they won't be due)
    for _ in 0..<5 {
      manager.recordCorrect(documentID: docID, markID: marks[0].id)
      manager.recordCorrect(documentID: docID, markID: marks[1].id)
    }

    let session = manager.startSpacedRepetitionSession(marks: marks, documentID: docID)
    #expect(session.marks.count == 3) // Only the 3 non-mastered marks
  }

  // MARK: - Export

  @Test("CSV export contains header and data rows")
  func csvExport() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let m1 = makeMark(text: "Important fact", note: "Remember this")
    let m2 = makeMark(page: 1, text: "Another fact")

    manager.recordCorrect(documentID: docID, markID: m1.id)
    manager.recordIncorrect(documentID: docID, markID: m2.id)

    let data = manager.exportCSV(documentID: docID, marks: [m1, m2])
    #expect(data != nil)

    let csv = String(data: data!, encoding: .utf8) ?? ""
    #expect(csv.contains("Mark ID"))
    #expect(csv.contains("Page"))
    #expect(csv.contains("Accuracy"))
    #expect(csv.contains("Ease Factor"))
    #expect(csv.contains("Important fact"))
    #expect(csv.contains("Another fact"))
  }

  @Test("JSON export is valid")
  func jsonExport() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let marks = (0..<3).map { makeMark(text: "Mark \($0)") }

    for mark in marks {
      manager.recordCorrect(documentID: docID, markID: mark.id)
    }

    let data = manager.exportJSON(documentID: docID, marks: marks)
    #expect(data != nil)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let report = try? decoder.decode(StudyProgressReport.self, from: data!)
    #expect(report != nil)
    #expect(report?.documentID == docID)
    #expect(report?.marks.count == 3)
    #expect(report?.summary.total == 3)
  }

  @Test("Report includes SM-2 data")
  func reportIncludesSM2() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let mark = makeMark(text: "SM-2 test")

    manager.recordCorrect(documentID: docID, markID: mark.id)
    manager.recordCorrect(documentID: docID, markID: mark.id)

    let report = manager.generateReport(documentID: docID, marks: [mark])
    #expect(report.marks.count == 1)
    let markReport = report.marks[0]
    #expect(markReport.repetitions == 2)
    // recordCorrect() uses .easy grade: EF increases by 0.1 each time
    #expect(markReport.easeFactor == 2.7)
    // Standard SM-2: 1d, 6d intervals
    #expect(markReport.intervalDays == 6)
    #expect(markReport.totalAttempts == 2)
    #expect(markReport.correctCount == 2)
  }

  @Test("Report includes schedule summary")
  func reportIncludesSchedule() {
    let manager = StudyLoopManager()
    manager.clearAll()
    let docID = "test-doc"
    let marks = (0..<5).map { _ in makeMark() }

    // Master 2 marks
    for mark in marks.prefix(2) {
      for _ in 0..<5 {
        manager.recordCorrect(documentID: docID, markID: mark.id)
      }
    }

    let report = manager.generateReport(documentID: docID, marks: marks)
    #expect(report.schedule.totalMarks == 5)
    #expect(report.summary.mastered == 2)
  }

  // MARK: - Helpers

  private func makeMark(
    page: Int = 0,
    y: Double = 0,
    text: String = "Test text",
    note: String = "",
    type: AnnotationType = .highlight
  ) -> AnnotationMark {
    AnnotationMark(
      type: type,
      pageIndex: page,
      bounds: PDFRect(x: 0, y: y, width: 100, height: 20),
      selectedText: text,
      note: note
    )
  }
}
