import Foundation

// MARK: - Session Contract

/// A persisted editing session that can be resumed across app restarts.
/// The session stores enough state to reconstruct the editing context
/// without holding the source PDF in memory.
public struct PDFSessionRecord: Codable, Equatable, Sendable {
  public let sessionID: UUID
  public let sourceDigest: String
  public let sourceFileName: String
  public let createdAt: Date
  public let lastModifiedAt: Date
  public let pageCount: Int
  public let operationCount: Int
  public let reviewCount: Int
  public let operations: [EditOperation]
  public let reviews: [CandidateReviewDecision]
  public let candidateStatuses: [UUID: CandidateStatus]
  public let selectedPageIndex: Int
  public let completionProgress: CompletionProgress

  public init(
    sessionID: UUID = UUID(),
    sourceDigest: String,
    sourceFileName: String,
    createdAt: Date = Date(),
    lastModifiedAt: Date = Date(),
    pageCount: Int,
    operationCount: Int,
    reviewCount: Int,
    operations: [EditOperation],
    reviews: [CandidateReviewDecision],
    candidateStatuses: [UUID: CandidateStatus],
    selectedPageIndex: Int,
    completionProgress: CompletionProgress
  ) {
    self.sessionID = sessionID
    self.sourceDigest = sourceDigest
    self.sourceFileName = sourceFileName
    self.createdAt = createdAt
    self.lastModifiedAt = lastModifiedAt
    self.pageCount = pageCount
    self.operationCount = operationCount
    self.reviewCount = reviewCount
    self.operations = operations
    self.reviews = reviews
    self.candidateStatuses = candidateStatuses
    self.selectedPageIndex = selectedPageIndex
    self.completionProgress = completionProgress
  }
}

/// Tracks how far the user has progressed through the document.
public struct CompletionProgress: Codable, Equatable, Sendable {
  public let totalCandidates: Int
  public let confirmedCount: Int
  public let rejectedCount: Int
  public let remainingCount: Int

  public init(
    totalCandidates: Int,
    confirmedCount: Int,
    rejectedCount: Int,
    remainingCount: Int
  ) {
    self.totalCandidates = totalCandidates
    self.confirmedCount = confirmedCount
    self.rejectedCount = rejectedCount
    self.remainingCount = remainingCount
  }

  public static let empty = CompletionProgress(
    totalCandidates: 0, confirmedCount: 0, rejectedCount: 0, remainingCount: 0
  )

  public var percentComplete: Double {
    guard totalCandidates > 0 else { return 0 }
    return Double(confirmedCount) / Double(totalCandidates) * 100
  }
}

// MARK: - Session Store Protocol

/// A provider-neutral session persistence interface.
/// Native uses file-based sidecars; browser uses IndexedDB.
public protocol SessionStore {
  /// Save a session record. Overwrites any existing session for the same source digest.
  func save(record: PDFSessionRecord) throws

  /// Load a session record by source digest.
  func load(sourceDigest: String) throws -> PDFSessionRecord?

  /// List all saved sessions, newest first.
  func listAll() throws -> [PDFSessionRecord]

  /// Delete a session by source digest.
  func delete(sourceDigest: String) throws

  /// Delete all sessions older than the given date.
  func deleteExpired(before date: Date) throws

  /// The number of saved sessions.
  var count: Int { get }
}

// MARK: - Session Store Errors

public enum SessionStoreError: Error, LocalizedError {
  case directoryCreationFailed(String)
  case encodingFailed(String)
  case decodingFailed(String)
  case fileOperationFailed(String)

  public var errorDescription: String? {
    switch self {
    case .directoryCreationFailed(let message):
      "Could not create session storage directory: \(message)"
    case .encodingFailed(let message):
      "Could not encode session record: \(message)"
    case .decodingFailed(let message):
      "Could not decode session record: \(message)"
    case .fileOperationFailed(let message):
      "Session file operation failed: \(message)"
    }
  }
}

// MARK: - File-Based Session Store (Native macOS)

/// Persists session records as JSON sidecar files alongside PDFs.
/// Each session is stored as `.pdfedit` in the session directory.
/// Files are named by SHA-256 digest of the source PDF.
public final class FileSessionStore: SessionStore, @unchecked Sendable {
  private let directory: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let lock = NSLock()

  public init(directory: URL) {
    self.directory = directory
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys]
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  /// The default session directory inside the user's Application Support.
  public static var defaultDirectory: URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    return appSupport
      .appendingPathComponent("PDFEditor", isDirectory: true)
      .appendingPathComponent("Sessions", isDirectory: true)
  }

  public func save(record: PDFSessionRecord) throws {
    lock.lock()
    defer { lock.unlock() }

    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
    } catch {
      throw SessionStoreError.directoryCreationFailed(error.localizedDescription)
    }

    let fileURL = url(for: record.sourceDigest)
    do {
      let data: Data
      do {
        data = try encoder.encode(record)
      } catch {
        throw SessionStoreError.encodingFailed(error.localizedDescription)
      }
      try data.write(to: fileURL, options: .atomic)
    } catch let error as SessionStoreError {
      throw error
    } catch {
      throw SessionStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  public func load(sourceDigest: String) throws -> PDFSessionRecord? {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: sourceDigest)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    do {
      let data = try Data(contentsOf: fileURL)
      return try decoder.decode(PDFSessionRecord.self, from: data)
    } catch is DecodingError {
      throw SessionStoreError.decodingFailed("Session file is corrupted: \(fileURL.lastPathComponent)")
    } catch {
      throw SessionStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  public func listAll() throws -> [PDFSessionRecord] {
    lock.lock()
    defer { lock.unlock() }

    guard FileManager.default.fileExists(atPath: directory.path) else {
      return []
    }

    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
    } catch {
      return []
    }

    var records: [PDFSessionRecord] = []
    for fileURL in contents where fileURL.pathExtension == "pdfedit" {
      if let data = try? Data(contentsOf: fileURL),
        let record = try? decoder.decode(PDFSessionRecord.self, from: data)
      {
        records.append(record)
      }
    }

    return records.sorted { $0.lastModifiedAt > $1.lastModifiedAt }
  }

  public func delete(sourceDigest: String) throws {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: sourceDigest)
    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        try FileManager.default.removeItem(at: fileURL)
      } catch {
        throw SessionStoreError.fileOperationFailed(error.localizedDescription)
      }
    }
  }

  public func deleteExpired(before date: Date) throws {
    let allSessions = try listAll()
    for session in allSessions where session.lastModifiedAt < date {
      try delete(sourceDigest: session.sourceDigest)
    }
  }

  public var count: Int {
    lock.lock()
    defer { lock.unlock() }

    guard FileManager.default.fileExists(atPath: directory.path) else {
      return 0
    }
    return (try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "pdfedit" }.count) ?? 0
  }

  private func url(for sourceDigest: String) -> URL {
    directory.appendingPathComponent("\(sourceDigest).pdfedit")
  }
}

// MARK: - Session Builder Helpers

extension PDFSessionRecord {
  /// Create a session record from the current editing state.
  public static func from(
    source: DocumentSource,
    pages: [PageSnapshot],
    fields: [NativeField],
    candidates: [RegionCandidate],
    operations: [EditOperation],
    reviews: [CandidateReviewDecision],
    selectedPageIndex: Int
  ) -> PDFSessionRecord {
    var candidateStatuses: [UUID: CandidateStatus] = [:]
    for candidate in candidates {
      if candidate.status != .suggested {
        candidateStatuses[candidate.id] = candidate.status
      }
    }

    let confirmed = candidates.filter { $0.status == .confirmed }.count
    let rejected = candidates.filter { $0.status == .rejected }.count
    let remaining = candidates.count - confirmed - rejected

    return PDFSessionRecord(
      sourceDigest: source.sha256,
      sourceFileName: source.fileName,
      pageCount: pages.count,
      operationCount: operations.count,
      reviewCount: reviews.count,
      operations: operations,
      reviews: reviews,
      candidateStatuses: candidateStatuses,
      selectedPageIndex: selectedPageIndex,
      completionProgress: CompletionProgress(
        totalCandidates: candidates.count,
        confirmedCount: confirmed,
        rejectedCount: rejected,
        remainingCount: remaining
      )
    )
  }

  /// Check if this session is compatible with a given source digest.
  public func isCompatibleWith(sourceDigest: String) -> Bool {
    self.sourceDigest == sourceDigest
  }

  /// Check if the session is stale (source may have changed).
  public var isStale: Bool {
    Calendar.current.date(
      byAdding: .day, value: 30, to: lastModifiedAt
    )?.compare(Date()) == .orderedAscending
  }
}
