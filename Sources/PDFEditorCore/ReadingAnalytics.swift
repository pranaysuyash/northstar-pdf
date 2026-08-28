import Foundation

/// Reading analytics — track time per page, session statistics, and reading patterns.
///
/// First principle: analytics help users understand their own reading behavior.
/// All data stays local — no telemetry, no cloud, no privacy concerns.
///
/// Metrics tracked:
/// - Time per page (how long spent on each page)
/// - Total session time
/// - Reading speed (pages per minute)
/// - Most-read pages (heat map)
/// - Reading session history
///
/// Doctrine alignment:
/// - §5: Evidence-based — all metrics are computed from real data
/// - §12: Privacy value-free — no document content, only timing data

// MARK: - Page Reading Data

/// Reading data for a single page.
public struct PageReadingData: Codable, Sendable {
  /// Page index.
  public let pageIndex: Int
  /// Total time spent on this page (seconds).
  public var timeSpentSeconds: Double
  /// Number of times this page was visited.
  public var visitCount: Int
  /// When this page was first visited.
  public let firstVisitedAt: Date
  /// When this page was last visited.
  public var lastVisitedAt: Date

  public init(pageIndex: Int) {
    self.pageIndex = pageIndex
    self.timeSpentSeconds = 0
    self.visitCount = 0
    self.firstVisitedAt = Date()
    self.lastVisitedAt = Date()
  }
}

// MARK: - Reading Session

/// A single reading session (time between open and close).
public struct AnalyticsSession: Codable, Sendable {
  /// Session identifier.
  public let id: UUID
  /// Document identifier.
  public let documentID: String
  /// When the session started.
  public let startedAt: Date
  /// When the session ended (nil if still active).
  public var endedAt: Date?
  /// Pages visited during this session.
  public var pagesVisited: [Int]
  /// Total time spent (seconds).
  public var totalTimeSeconds: Double
  /// Starting page.
  public let startPage: Int
  /// Ending page.
  public var endPage: Int?

  public init(documentID: String, startPage: Int) {
    self.id = UUID()
    self.documentID = documentID
    self.startedAt = Date()
    self.endedAt = nil
    self.pagesVisited = [startPage]
    self.totalTimeSeconds = 0
    self.startPage = startPage
    self.endPage = nil
  }

  public var durationMinutes: Double {
    let elapsed = (endedAt ?? Date()).timeIntervalSince(startedAt)
    return elapsed / 60.0
  }
}

// MARK: - Reading Statistics

/// Aggregated reading statistics for a document.
public struct ReadingStatistics: Sendable {
  /// Total time spent reading (seconds).
  public let totalTimeSeconds: Double
  /// Total pages read (unique).
  public let uniquePagesRead: Int
  /// Total page visits (including revisits).
  public let totalPageVisits: Int
  /// Average time per page (seconds).
  public let averageTimePerPage: Double
  /// Reading speed (pages per minute).
  public let pagesPerMinute: Double
  /// Most-read pages (sorted by time).
  public let topPages: [(pageIndex: Int, timeSeconds: Double)]
  /// Number of sessions.
  public let sessionCount: Int

  public var totalTimeMinutes: Double { totalTimeSeconds / 60.0 }
  public var description: String {
    "\(String(format: "%.1f", totalTimeMinutes)) min, \(uniquePagesRead) pages, \(String(format: "%.1f", pagesPerMinute)) pages/min"
  }
}

// MARK: - Reading Analytics Manager

/// Tracks reading behavior across sessions.
@MainActor
public final class ReadingAnalytics: ObservableObject {
  /// Per-page reading data for the current document.
  @Published public private(set) var pageData: [Int: PageReadingData] = [:]
  /// All sessions for the current document.
  @Published public private(set) var sessions: [AnalyticsSession] = []
  /// The current active session.
  @Published public private(set) var currentSession: AnalyticsSession?

  private let storageKey = "com.pdfeditor.reading.analytics"
  private var allSessions: [AnalyticsSession] = []

  public init() {
    load()
  }

  // MARK: - Session Management

  /// Start a new reading session.
  public func startSession(documentID: String, startPage: Int) {
    let session = AnalyticsSession(documentID: documentID, startPage: startPage)
    currentSession = session
    sessions.append(session)
  }

  /// End the current reading session.
  public func endSession() {
    guard var session = currentSession else { return }
    session.endedAt = Date()
    session.totalTimeSeconds = session.durationMinutes * 60
    currentSession = nil

    // Update in sessions array
    if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
      sessions[idx] = session
    }

    save()
  }

  // MARK: - Page Tracking

  /// Record a page visit.
  public func recordPageVisit(_ pageIndex: Int) {
    var data = pageData[pageIndex] ?? PageReadingData(pageIndex: pageIndex)
    data.visitCount += 1
    data.lastVisitedAt = Date()
    pageData[pageIndex] = data

    // Add to current session
    currentSession?.pagesVisited.append(pageIndex)
    currentSession?.endPage = pageIndex
  }

  /// Record time spent on a page.
  public func recordTimeSpent(_ seconds: Double, onPage pageIndex: Int) {
    var data = pageData[pageIndex] ?? PageReadingData(pageIndex: pageIndex)
    data.timeSpentSeconds += seconds
    pageData[pageIndex] = data
  }

  // MARK: - Statistics

  /// Get reading statistics for the current document.
  public var statistics: ReadingStatistics {
    let allData = Array(pageData.values)
    let totalTime = allData.reduce(0) { $0 + $1.timeSpentSeconds }
    let uniquePages = allData.filter { $0.visitCount > 0 }.count
    let totalVisits = allData.reduce(0) { $0 + $1.visitCount }
    let avgTime = uniquePages > 0 ? totalTime / Double(uniquePages) : 0
    let ppm = totalTime > 0 ? Double(uniquePages) / (totalTime / 60.0) : 0

    let topPages = allData
      .filter { $0.timeSpentSeconds > 0 }
      .sorted { $0.timeSpentSeconds > $1.timeSpentSeconds }
      .prefix(5)
      .map { (pageIndex: $0.pageIndex, timeSeconds: $0.timeSpentSeconds) }

    return ReadingStatistics(
      totalTimeSeconds: totalTime,
      uniquePagesRead: uniquePages,
      totalPageVisits: totalVisits,
      averageTimePerPage: avgTime,
      pagesPerMinute: ppm,
      topPages: Array(topPages),
      sessionCount: sessions.count
    )
  }

  // MARK: - Persistence

  private func save() {
    guard let data = try? JSONEncoder().encode(sessions) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let loaded = try? JSONDecoder().decode([AnalyticsSession].self, from: data)
    else { return }
    allSessions = loaded
  }
}
