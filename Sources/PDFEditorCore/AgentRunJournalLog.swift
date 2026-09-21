import Foundation

// MARK: - PL-D09 run-journal instrument (D-083 slice 0, NM-T41)

/// One JSONL row of the cohort instrument behind D-083's slice-0 kill test.
///
/// Rows carry capability facts only — plan identity, step outcomes, terminal
/// state, escalation flags, and the source digest hash. Never document
/// content (zero-egress doctrine, D-066 invariants).
public struct AgentRunJournalRow: Codable, Sendable, Hashable {
  public enum Kind: String, Codable, Sendable {
    case sessionOpen = "session-open"
    case agentRun = "agent-run"
  }

  public let kind: Kind
  public let timestamp: Date
  /// One value per app process: the denominator that groups rows into
  /// per-user sessions for the per-user kill-threshold operationalization.
  public let sessionID: UUID
  public let sourceDigest: String
  /// Present iff `kind == .agentRun`.
  public let run: AgentRunRecord?

  public init(
    kind: Kind,
    timestamp: Date,
    sessionID: UUID,
    sourceDigest: String,
    run: AgentRunRecord? = nil
  ) {
    self.kind = kind
    self.timestamp = timestamp
    self.sessionID = sessionID
    self.sourceDigest = sourceDigest
    self.run = run
  }
}

/// Append-only JSONL log backing the PL-D09 cohort instrument.
///
/// The in-memory `AgentRunJournal` is session-local and capped at 50 records,
/// so it cannot answer "did the loop get opened across sessions". This log
/// can. Writes mirror `FileSessionStore` conventions (Application Support,
/// ISO-8601 dates, sorted keys) and are best-effort with an explicit health
/// flag: per the X2 rule an instrument that silently dies is worse than no
/// instrument, so a failed append is observable, never silent.
public final class AgentRunJournalLog: @unchecked Sendable {
  private let directory: URL
  private let fileURL: URL
  private let encoder: JSONEncoder
  private let lock = NSLock()

  /// False after the first failed append; reset on the next successful one.
  public private(set) var isHealthy = true

  /// One value per process; stamped onto every row this process writes.
  public let sessionID = UUID()

  public init(directory: URL = AgentRunJournalLog.defaultDirectory) {
    self.directory = directory
    self.fileURL = directory.appendingPathComponent("run-journal.jsonl")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    self.encoder = encoder
  }

  /// The default instrumentation directory inside the user's Application
  /// Support, sibling to the session store.
  public static var defaultDirectory: URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    return appSupport
      .appendingPathComponent("PDFEditor", isDirectory: true)
      .appendingPathComponent("Instrumentation", isDirectory: true)
  }

  /// Appends one row. Returns false when the write failed (health flips
  /// false so the data gap is detectable rather than silent).
  @discardableResult
  public func append(_ row: AgentRunJournalRow) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
      var data = try encoder.encode(row)
      data.append(0x0A) // JSONL line terminator
      if !FileManager.default.fileExists(atPath: fileURL.path) {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
      }
      let handle = try FileHandle(forWritingTo: fileURL)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: data)
      isHealthy = true
      return true
    } catch {
      isHealthy = false
      return false
    }
  }

  /// Reads every row back for analysis and testing. Malformed lines are
  /// skipped (a torn final line from a crash must not void the log).
  public func readAll() throws -> [AgentRunJournalRow] {
    lock.lock()
    defer { lock.unlock() }
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    let data = try Data(contentsOf: fileURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    var rows: [AgentRunJournalRow] = []
    for line in data.split(separator: 0x0A) where !line.isEmpty {
      if let row = try? decoder.decode(AgentRunJournalRow.self, from: Data(line)) {
        rows.append(row)
      }
    }
    return rows
  }
}
