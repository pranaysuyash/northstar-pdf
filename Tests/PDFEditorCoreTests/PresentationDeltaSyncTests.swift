import AppKit
import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// The canvas presentation layer syncs edits by applying the operation ledger
/// delta to an independent document clone instead of deep-copying the whole
/// PDF on every projection revision. That policy is only sound while applying
/// operations in batches to a clone is equivalent to applying them one-shot to
/// the live document. These tests pin that invariant: if the provider ever
/// becomes batch- or clone-sensitive, the incremental canvas sync would
/// silently diverge from the document the export pipeline validates against.
@Suite(.serialized)
struct PresentationDeltaSyncTests {
  private let provider = PDFKitProvider()

  private func makeSourceData() throws -> Data {
    let document = PDFDocument()
    for pageIndex in 0..<3 {
      document.insert(PDFPage(), at: pageIndex)
    }
    return try #require(document.dataRepresentation())
  }

  private func overlayOperation(pageIndex: Int, text: String) -> EditOperation {
    EditOperation(
      pageIndex: pageIndex,
      kind: .overlayText,
      value: text,
      bounds: PDFRect(x: 72, y: 700, width: 160, height: 20),
      payload: .text(text)
    )
  }

  /// Order-insensitive document fingerprint: page count, per-page annotation
  /// counts, and per-page annotation contents.
  private func fingerprint(_ document: PDFDocument) -> [String] {
    var entries: [String] = []
    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex) else { continue }
      entries.append("page \(pageIndex): \(page.annotations.count) annotations")
      entries.append(contentsOf: page.annotations.compactMap(\.contents).sorted())
    }
    return entries
  }

  @Test("clone plus full ledger delta equals one-shot application")
  func cloneDeltaMatchesOneShot() throws {
    let sourceData = try makeSourceData()
    let operations = [
      overlayOperation(pageIndex: 0, text: "alpha"),
      overlayOperation(pageIndex: 1, text: "beta"),
      overlayOperation(pageIndex: 2, text: "gamma"),
    ]

    let live = try #require(PDFDocument(data: sourceData))
    for operation in operations {
      try provider.apply(operation, to: live)
    }

    // Canvas shape: the presentation clone is built from the untouched
    // source, then the ledger is applied as a delta in separate batches.
    let presentation = try #require(
      PDFDocument(data: sourceData)?.copy() as? PDFDocument)
    try provider.apply(operations[0], to: presentation)
    try provider.apply(operations[1], to: presentation)
    try provider.apply(operations[2], to: presentation)

    #expect(fingerprint(live) == fingerprint(presentation))
  }

  @Test("mid-ledger clone plus remaining delta equals one-shot application")
  func midSessionCloneDeltaMatches() throws {
    let sourceData = try makeSourceData()
    let operations = [
      overlayOperation(pageIndex: 0, text: "alpha"),
      overlayOperation(pageIndex: 1, text: "beta"),
      overlayOperation(pageIndex: 2, text: "gamma"),
    ]

    let live = try #require(PDFDocument(data: sourceData))
    for operation in operations {
      try provider.apply(operation, to: live)
    }

    // Undo-replay shape: the clone is rebuilt from a document that already
    // carries part of the ledger, then only the remaining operations apply.
    let partiallyApplied = try #require(PDFDocument(data: sourceData))
    try provider.apply(operations[0], to: partiallyApplied)
    let rebuiltClone = try #require(partiallyApplied.copy() as? PDFDocument)
    try provider.apply(operations[1], to: rebuiltClone)
    try provider.apply(operations[2], to: rebuiltClone)

    #expect(fingerprint(live) == fingerprint(rebuiltClone))
  }
}
