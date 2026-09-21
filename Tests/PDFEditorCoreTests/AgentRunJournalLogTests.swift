import Foundation
import XCTest

@testable import PDFEditorCore

/// PL-D09 run-journal instrument (D-083 slice 0, NM-T41): the JSONL log must
/// round-trip rows, skip torn lines, and expose a dead instrument instead of
/// failing silently (X2 rule).
final class AgentRunJournalLogTests: XCTestCase {
  private func makeTemporaryDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-run-journal-log-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
    return dir
  }

  func testAppendAndReadAllRoundTripsRows() throws {
    let log = AgentRunJournalLog(directory: try makeTemporaryDirectory())
    let sessionID = log.sessionID

    log.append(AgentRunJournalRow(
      kind: .sessionOpen,
      timestamp: Date(timeIntervalSince1970: 1_000),
      sessionID: sessionID,
      sourceDigest: "abc123"))

    log.append(AgentRunJournalRow(
      kind: .agentRun,
      timestamp: Date(timeIntervalSince1970: 2_000),
      sessionID: sessionID,
      sourceDigest: "abc123",
      run: AgentRunRecord(
        planID: "plan-1",
        goal: .completeDocument,
        stepOutcomes: ["step-1:approved", "step-2:approved"],
        escalated: false,
        reasonCodes: [])))

    let rows = try log.readAll()
    XCTAssertEqual(rows.count, 2)
    XCTAssertEqual(rows[0].kind, .sessionOpen)
    XCTAssertEqual(rows[0].sourceDigest, "abc123")
    XCTAssertNil(rows[0].run)
    XCTAssertEqual(rows[1].kind, .agentRun)
    XCTAssertEqual(rows[1].run?.planID, "plan-1")
    XCTAssertEqual(rows[1].run?.stepOutcomes, ["step-1:approved", "step-2:approved"])
    XCTAssertEqual(rows[1].sessionID, sessionID)
    XCTAssertTrue(log.isHealthy)
  }

  func testAppendSkipsTornFinalLineOnRead() throws {
    let dir = try makeTemporaryDirectory()
    let log = AgentRunJournalLog(directory: dir)
    log.append(AgentRunJournalRow(
      kind: .sessionOpen,
      timestamp: Date(timeIntervalSince1970: 1_000),
      sessionID: log.sessionID,
      sourceDigest: "abc123"))

    // Simulate a crash mid-write: append garbage without a newline, then a
    // malformed line. readAll must skip both, not throw.
    let fileURL = dir.appendingPathComponent("run-journal.jsonl")
    var data = try Data(contentsOf: fileURL)
    data.append(Data("{torn".utf8))
    try data.write(to: fileURL)

    let rows = try log.readAll()
    XCTAssertEqual(rows.count, 1)
  }

  func testFailedAppendFlipsHealthInsteadOfFailingSilently() throws {
    let dir = try makeTemporaryDirectory()
    // A file where the directory must be: every append must fail.
    let blocker = dir.appendingPathComponent("Instrumentation")
    try Data("not a directory".utf8).write(to: blocker)

    let log = AgentRunJournalLog(directory: blocker)
    let appended = log.append(AgentRunJournalRow(
      kind: .sessionOpen,
      timestamp: Date(),
      sessionID: log.sessionID,
      sourceDigest: "abc123"))

    XCTAssertFalse(appended)
    XCTAssertFalse(log.isHealthy)
  }
}
