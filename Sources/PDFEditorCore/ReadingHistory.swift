import Foundation

/// Reading history: bookmarks, time-spent tracking, and recent documents.
///
/// First principle: reading is not a single session — it spans days, involves
/// re-reading marked passages, and users need to pick up where they left off
/// across documents. History is the memory of reading.
///
/// Architecture:
/// - `Bookmark` — a named position in a document (page + optional note)
/// - `ReadingSession` — time-spent tracking per document per session
/// - `ReadingHistory` — aggregated history across all documents
///
/// Doctrine alignment:
/// - §3: Do things smartly — remember what the user cares about
/// - §5: Evidence-based — track actual reading time, not estimates
/// - Long-term: Foundation for spaced repetition, reading analytics

// MARK: - Bookmark

/// A named position in a document.
public struct Bookmark: Codable, Sendable, Identifiable {
  public let id: UUID
  public let documentID: String
  public let pageIndex: Int
  public let scrollOffset: CGFloat
  public let scale: CGFloat
  public var title: String
  public var note: String
  public let createdAt: Date
  public var updatedAt: Date

  public init(
    documentID: String,
    pageIndex: Int,
    scrollOffset: CGFloat = 0,
    scale: CGFloat = 1.0,
    title: String = "",
    note: String = ""
  ) {
    self.id = UUID()
    self.documentID = documentID
    self.pageIndex = pageIndex
    self.scrollOffset = scrollOffset
    self.scale = scale
    self.title = title.isEmpty ? "Page \(pageIndex + 1)" : title
    self.note = note
    self.createdAt = Date()
    self.updatedAt = Date()
  }
}

// MARK: - Reading Session

/// A single reading session for a document.
public struct ReadingSession: Codable, Sendable {
  public let documentID: String
  public let startedAt: Date
  public var endedAt: Date?
  public var pagesRead: Set<Int>
  public var lastPageIndex: Int

  public var durationSeconds: Double {
    let end = endedAt ?? Date()
    return end.timeIntervalSince(startedAt)
  }

  public var isActive: Bool {
    endedAt == nil
  }

  public init(documentID: String, startPage: Int = 0) {
    self.documentID = documentID
    self.startedAt = Date()
    self.endedAt = nil
    self.pagesRead = [startPage]
    self.lastPageIndex = startPage
  }
}

// MARK: - Document History

/// Aggregated reading history for a single document.
public struct DocumentHistory: Codable, Sendable {
  public let documentID: String
  public let fileName: String
  public var lastOpenedAt: Date
  public var totalTimeSpent: Double // seconds
  public var sessionCount: Int
  public var pagesRead: Set<Int>
  public var bookmarks: [Bookmark]
  public var lastPageIndex: Int

  public var averageSessionDuration: Double {
    guard sessionCount > 0 else { return 0 }
    return totalTimeSpent / Double(sessionCount)
  }

  public init(documentID: String, fileName: String = "") {
    self.documentID = documentID
    self.fileName = fileName
    self.lastOpenedAt = Date()
    self.totalTimeSpent = 0
    self.sessionCount = 0
    self.pagesRead = []
    self.bookmarks = []
    self.lastPageIndex = 0
  }
}

// MARK: - Reading History Manager

/// Centralized reading history with persistence.
@MainActor
public final class ReadingHistoryManager: ObservableObject {
  @Published public var documents: [String: DocumentHistory] = [:]
  @Published public var activeSession: ReadingSession?

  private let maxRecentDocuments = 50
  private let maxBookmarksPerDocument = 100

  public init() {
    load()
  }

  // MARK: - Session Management

  /// Start a new reading session for a document.
  public func startSession(documentID: String, fileName: String = "", startPage: Int = 0) {
    // End any active session first
    endSession()

    let session = ReadingSession(documentID: documentID, startPage: startPage)
    activeSession = session

    // Ensure document history exists
    if documents[documentID] == nil {
      documents[documentID] = DocumentHistory(documentID: documentID, fileName: fileName)
    }
    documents[documentID]?.lastOpenedAt = Date()
    documents[documentID]?.sessionCount += 1
    documents[documentID]?.pagesRead.insert(startPage)
    documents[documentID]?.lastPageIndex = startPage

    save()
  }

  /// End the current reading session.
  public func endSession() {
    guard let session = activeSession else { return }

    var endedSession = session
    endedSession.endedAt = Date()

    // Update document history
    let duration = endedSession.durationSeconds
    documents[session.documentID]?.totalTimeSpent += duration

    activeSession = nil
    save()
  }

  /// Update the current page in the active session.
  public func updatePage(_ pageIndex: Int) {
    guard let session = activeSession else { return }

    activeSession?.pagesRead.insert(pageIndex)
    activeSession?.lastPageIndex = pageIndex
    documents[session.documentID]?.pagesRead.insert(pageIndex)
    documents[session.documentID]?.lastPageIndex = pageIndex

    save()
  }

  // MARK: - Bookmarks

  /// Add a bookmark to a document.
  public func addBookmark(
    documentID: String,
    pageIndex: Int,
    scrollOffset: CGFloat = 0,
    scale: CGFloat = 1.0,
    title: String = "",
    note: String = ""
  ) -> Bookmark {
    let bookmark = Bookmark(
      documentID: documentID,
      pageIndex: pageIndex,
      scrollOffset: scrollOffset,
      scale: scale,
      title: title.isEmpty ? "Page \(pageIndex + 1)" : title,
      note: note
    )

    if documents[documentID] == nil {
      documents[documentID] = DocumentHistory(documentID: documentID)
    }
    documents[documentID]?.bookmarks.append(bookmark)

    // Enforce limit
    if let count = documents[documentID]?.bookmarks.count,
       count > maxBookmarksPerDocument {
      documents[documentID]?.bookmarks.removeFirst(count - maxBookmarksPerDocument)
    }

    save()
    return bookmark
  }

  /// Remove a bookmark.
  public func removeBookmark(id: UUID, documentID: String) {
    documents[documentID]?.bookmarks.removeAll { $0.id == id }
    save()
  }

  /// Get all bookmarks for a document.
  public func bookmarks(for documentID: String) -> [Bookmark] {
    documents[documentID]?.bookmarks ?? []
  }

  // MARK: - Queries

  /// Get recent documents, sorted by last opened.
  public func recentDocuments(limit: Int = 20) -> [DocumentHistory] {
    Array(documents.values
      .sorted { $0.lastOpenedAt > $1.lastOpenedAt }
      .prefix(limit))
  }

  /// Get the most-read documents by time spent.
  public func mostReadDocuments(limit: Int = 10) -> [DocumentHistory] {
    Array(documents.values
      .sorted { $0.totalTimeSpent > $1.totalTimeSpent }
      .prefix(limit))
  }

  /// Get reading stats for a document.
  public func stats(for documentID: String) -> (timeSpent: Double, sessions: Int, pagesRead: Int, bookmarks: Int)? {
    guard let doc = documents[documentID] else { return nil }
    return (
      timeSpent: doc.totalTimeSpent,
      sessions: doc.sessionCount,
      pagesRead: doc.pagesRead.count,
      bookmarks: doc.bookmarks.count
    )
  }

  /// Get total reading time across all documents.
  public var totalReadingTime: Double {
    documents.values.reduce(0) { $0 + $1.totalTimeSpent }
  }

  /// Get total documents read.
  public var totalDocumentsRead: Int {
    documents.count
  }

  // MARK: - Persistence

  private let storageKey = "readingHistory"

  private func save() {
    guard let data = try? JSONEncoder().encode(documents) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let loaded = try? JSONDecoder().decode([String: DocumentHistory].self, from: data)
    else { return }
    documents = loaded
  }

  /// Clear all reading history.
  public func clearAll() {
    documents = [:]
    activeSession = nil
    UserDefaults.standard.removeObject(forKey: storageKey)
  }

  /// Clear history for a specific document.
  public func clearDocument(_ documentID: String) {
    documents.removeValue(forKey: documentID)
    save()
  }
}
