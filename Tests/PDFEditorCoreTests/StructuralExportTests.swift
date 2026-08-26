import Foundation
import PDFKit
import Testing

@testable import PDFEditorCore

/// Structural page operations must replay onto an opened source file and
/// survive the export validation contract: the reopened page count matches
/// the operation-derived expectation, and rotation survives reopen.
struct StructuralExportTests {
  private func makeTwoPageFixture(at url: URL) throws -> DocumentInspection {
    let fixture = PDFDocument()
    for _ in 0..<2 {
      fixture.insert(PDFPage(), at: fixture.pageCount)
    }
    #expect(fixture.write(to: url))
    return try PDFKitProvider().inspect(url: url)
  }

  @Test("structural page operations replay and validate on export")
  func structuralPageOperationsReplayAndValidateOnExport() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-structural-export-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let inspection = try makeTwoPageFixture(at: sourceURL)
    let digest = inspection.source.sha256

    // Live sequence: [A,B] → insert C → [A,B,C] → rotate A 180 → move A to
    // end → [B,C,A] → delete index 1 → [B,A(rotated)]. Expected count: 2.
    let operations = [
      EditOperation(
        pageIndex: 2, kind: .pageInsert, value: "blank:612x792",
        sourceDigest: digest),
      EditOperation(
        pageIndex: 0, kind: .pageTransform, value: "180",
        sourceDigest: digest),
      EditOperation(
        pageIndex: 0, kind: .pageMove, value: "0 -> 2",
        sourceDigest: digest),
      EditOperation(
        pageIndex: 1, kind: .pageDelete, value: "1",
        sourceDigest: digest),
    ]

    let result = try PDFKitProvider().export(
      url: sourceURL, operations: operations, to: outputURL)

    #expect(result.report.status != .failed)
    #expect(result.report.messages.isEmpty)

    let reopened = try #require(PDFDocument(url: outputURL))
    #expect(reopened.pageCount == 2)
    #expect(reopened.page(at: 1)?.rotation == 180)
  }

  @Test("imported page inserts fail closed on replay against an opened file")
  func importedPageInsertsFailClosedOnReplay() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-structural-import-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let inspection = try makeTwoPageFixture(at: sourceURL)

    let operation = EditOperation(
      pageIndex: 2, kind: .pageInsert, value: "import:3:other.pdf",
      sourceDigest: inspection.source.sha256)

    #expect(throws: PDFEditorError.self) {
      _ = try PDFKitProvider().export(
        url: sourceURL, operations: [operation], to: outputURL)
    }
    #expect(!FileManager.default.fileExists(atPath: outputURL.path))
  }

  @Test("blank page insert replays at the one-past-the-end index")
  func blankPageInsertReplaysAtEndIndex() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-structural-append-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let inspection = try makeTwoPageFixture(at: sourceURL)

    let operation = EditOperation(
      pageIndex: 2, kind: .pageInsert, value: "blank:595x842",
      sourceDigest: inspection.source.sha256)

    let result = try PDFKitProvider().export(
      url: sourceURL, operations: [operation], to: outputURL)

    #expect(result.report.status != .failed)
    let reopened = try #require(PDFDocument(url: outputURL))
    #expect(reopened.pageCount == 3)
    #expect(reopened.page(at: 2)?.bounds(for: .mediaBox).width == 595)
  }
}
