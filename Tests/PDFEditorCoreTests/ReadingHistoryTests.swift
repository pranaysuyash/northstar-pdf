import Foundation
import Testing
@testable import PDFEditorCore

@Suite("ReadingHistory")
struct ReadingHistoryTests {
  // MARK: - Bookmark

  @Test("Bookmark creates with generated ID")
  func bookmarkCreation() {
    let bm = Bookmark(documentID: "test.pdf", pageIndex: 5)
    #expect(bm.documentID == "test.pdf")
    #expect(bm.pageIndex == 5)
    #expect(bm.title == "Page 6")
    #expect(bm.scrollOffset == 0)
    #expect(bm.scale == 1.0)
  }

  @Test("Bookmark with custom title and note")
  func bookmarkCustom() {
    let bm = Bookmark(documentID: "test.pdf", pageIndex: 3, title: "Important", note: "Check this")
    #expect(bm.title == "Important")
    #expect(bm.note == "Check this")
  }

  // MARK: - ReadingSession

  @Test("Session starts active")
  func sessionActive() {
    let session = ReadingSession(documentID: "test.pdf", startPage: 2)
    #expect(session.isActive == true)
    #expect(session.endedAt == nil)
    #expect(session.pagesRead == [2])
    #expect(session.lastPageIndex == 2)
  }

  @Test("Session duration is positive")
  func sessionDuration() {
    var session = ReadingSession(documentID: "test.pdf")
    session.endedAt = session.startedAt.addingTimeInterval(60)
    #expect(session.durationSeconds == 60.0)
  }

  // MARK: - DocumentHistory

  @Test("Document history tracks sessions")
  func docHistory() {
    var doc = DocumentHistory(documentID: "test.pdf", fileName: "test.pdf")
    doc.sessionCount = 3
    doc.totalTimeSpent = 300
    #expect(doc.averageSessionDuration == 100.0)
  }

  // MARK: - ReadingHistoryManager

  @Test("Manager starts empty")
  @MainActor
  func managerEmpty() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    #expect(mgr.documents.isEmpty)
    #expect(mgr.activeSession == nil)
  }

  @Test("Start session creates document history")
  @MainActor
  func startSession() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    mgr.startSession(documentID: "doc1.pdf", fileName: "doc1.pdf", startPage: 5)
    #expect(mgr.activeSession != nil)
    #expect(mgr.activeSession?.documentID == "doc1.pdf")
    #expect(mgr.documents["doc1.pdf"] != nil)
    #expect(mgr.documents["doc1.pdf"]?.sessionCount == 1)
    #expect(mgr.documents["doc1.pdf"]?.pagesRead.contains(5) == true)
  }

  @Test("End session clears active")
  @MainActor
  func endSession() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    mgr.startSession(documentID: "doc1.pdf")
    mgr.endSession()
    #expect(mgr.activeSession == nil)
    #expect(mgr.documents["doc1.pdf"]?.totalTimeSpent ?? 0 >= 0)
  }

  @Test("Update page tracks pages read")
  @MainActor
  func updatePage() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    mgr.startSession(documentID: "doc1.pdf", startPage: 0)
    mgr.updatePage(3)
    mgr.updatePage(7)
    #expect(mgr.documents["doc1.pdf"]?.pagesRead.contains(3) == true)
    #expect(mgr.documents["doc1.pdf"]?.pagesRead.contains(7) == true)
    #expect(mgr.activeSession?.lastPageIndex == 7)
  }

  @Test("Add bookmark")
  @MainActor
  func addBookmark() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    let bm = mgr.addBookmark(documentID: "doc1.pdf", pageIndex: 5, title: "Section 3")
    #expect(bm.title == "Section 3")
    #expect(mgr.bookmarks(for: "doc1.pdf").count == 1)
  }

  @Test("Remove bookmark")
  @MainActor
  func removeBookmark() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    let bm = mgr.addBookmark(documentID: "doc1.pdf", pageIndex: 5)
    mgr.removeBookmark(id: bm.id, documentID: "doc1.pdf")
    #expect(mgr.bookmarks(for: "doc1.pdf").isEmpty)
  }

  @Test("Recent documents sorted by last opened")
  @MainActor
  func recentDocuments() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    mgr.startSession(documentID: "old.pdf", fileName: "old.pdf")
    mgr.endSession()
    // Small delay to ensure different timestamps
    mgr.startSession(documentID: "new.pdf", fileName: "new.pdf")
    let recent = mgr.recentDocuments()
    #expect(recent.first?.documentID == "new.pdf")
  }

  @Test("Clear document history")
  @MainActor
  func clearDocument() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    mgr.startSession(documentID: "doc1.pdf")
    mgr.endSession()
    mgr.clearDocument("doc1.pdf")
    #expect(mgr.documents["doc1.pdf"] == nil)
  }

  @Test("Clear all history")
  @MainActor
  func clearAll() {
    let mgr = ReadingHistoryManager()
    mgr.startSession(documentID: "doc1.pdf")
    mgr.endSession()
    mgr.clearAll()
    #expect(mgr.documents.isEmpty)
  }

  // MARK: - Stats

  @Test("Stats returns nil for unknown document")
  @MainActor
  func statsUnknown() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    #expect(mgr.stats(for: "unknown.pdf") == nil)
  }

  @Test("Stats returns correct values")
  @MainActor
  func statsKnown() {
    let mgr = ReadingHistoryManager()
    mgr.clearAll()
    mgr.startSession(documentID: "doc1.pdf", startPage: 0)
    mgr.updatePage(1)
    mgr.updatePage(2)
    mgr.endSession()
    let stats = mgr.stats(for: "doc1.pdf")
    #expect(stats != nil)
    #expect(stats?.sessions == 1)
    #expect(stats?.pagesRead == 3) // pages 0, 1, 2
  }

  // MARK: - Sendable

  @Test("Bookmark is Sendable")
  func bookmarkSendable() {
    let bm = Bookmark(documentID: "test.pdf", pageIndex: 0)
    Task {
      let captured = bm
      #expect(captured.pageIndex == 0)
    }
  }
}
