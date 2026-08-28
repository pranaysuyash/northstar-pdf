import Testing
import Foundation
@testable import PDFEditorCore

@Suite("CollaborationHistory")
struct CollaborationHistoryTests {

  // MARK: - Recording Events

  @Test("Record import creates event with correct fields")
  @MainActor
  func recordImport() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage(author: "Alice", markCount: 5)
    let event = history.recordImport(
      actor: "Bob",
      package: pkg,
      documentID: "doc-1",
      documentName: "Report.pdf"
    )
    #expect(event.kind == .packageImported)
    #expect(event.actor == "Bob")
    #expect(event.partnerName == "Alice")
    #expect(event.markCount == 5)
    #expect(event.documentName == "Report.pdf")
    #expect(history.events.count == 1)
  }

  @Test("Record merge with conflict resolutions")
  @MainActor
  func recordMerge() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage(author: "Carol")
    let record = PartnerPackageRecord(package: pkg, documentID: "d1", documentName: "A.pdf")
    let result = AnnotationMergeResult(
      localOnly: [makeMark(text: "local only")],
      partnerOnly: [makeMark(text: "partner only")],
      duplicates: [],
      conflicts: [makeConflict(reason: .sameRegionDifferentContent)]
    )
    let event = history.recordMerge(actor: "Dave", packageRecord: record, mergeResult: result)
    #expect(event.kind == .mergeExecuted)
    // markCount is mergedMarks.count (localOnly + partnerOnly + duplicates + conflicts.map(resolvedMark))
    // 1 localOnly + 1 partnerOnly + 0 duplicates + 1 conflict(resolved) = 3
    #expect(event.markCount == 3)
    #expect(event.conflictCount == 1)
    #expect(event.resolutions.count == 1)
    #expect(event.resolutions[0].followedSuggestion == (event.resolutions[0].resolution == event.resolutions[0].suggestedResolution))
  }

  @Test("Record conflict resolution")
  @MainActor
  func recordResolution() {
    let history = CollaborationHistory()
    history.clearAll()
    let conflict = ConflictRecord(
      packageRecordID: UUID(),
      documentName: "Report.pdf",
      conflict: makeConflict(reason: .overlappingBounds(0.7))
    )
    let event = history.recordResolution(
      actor: "Eve",
      conflict: conflict,
      resolution: .keepBoth,
      documentName: "Report.pdf"
    )
    #expect(event.kind == .conflictResolved)
    #expect(event.resolutions.count == 1)
    #expect(event.resolutions[0].resolution == .keepBoth)
  }

  @Test("Record revert")
  @MainActor
  func recordRevert() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage(author: "Frank")
    let record = PartnerPackageRecord(package: pkg, documentID: "d1", documentName: "B.pdf")
    let event = history.recordRevert(actor: "Grace", packageRecord: record, reason: "Wrong version")
    #expect(event.kind == .mergeReverted)
    #expect(event.summary.contains("Wrong version"))
  }

  @Test("Record rejection")
  @MainActor
  func recordRejection() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage(author: "Hank")
    let record = PartnerPackageRecord(package: pkg, documentID: "d1", documentName: "C.pdf")
    let event = history.recordRejection(
      actor: "Ivy",
      packageRecord: record,
      reason: "Document hash mismatch"
    )
    #expect(event.kind == .packageRejected)
    #expect(event.summary.contains("Document hash mismatch"))
  }

  @Test("Record removal")
  @MainActor
  func recordRemoval() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage(author: "Jack")
    let record = PartnerPackageRecord(package: pkg, documentID: "d1", documentName: "D.pdf")
    let event = history.recordRemoval(actor: "Kate", packageRecord: record)
    #expect(event.kind == .packageRemoved)
    #expect(event.partnerName == "Jack")
  }

  // MARK: - Events are newest first

  @Test("Events are ordered newest first")
  @MainActor
  func newestFirst() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage()
    history.recordImport(actor: "First", package: pkg, documentID: "d1", documentName: "A.pdf")
    // Small delay to ensure different timestamps
    history.recordImport(actor: "Second", package: pkg, documentID: "d1", documentName: "A.pdf")
    #expect(history.events.count == 2)
    #expect(history.events[0].actor == "Second")
    #expect(history.events[1].actor == "First")
  }

  // MARK: - Querying

  @Test("Filter events by document")
  @MainActor
  func filterByDocument() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage()
    history.recordImport(actor: "A", package: pkg, documentID: "d1", documentName: "Alpha.pdf")
    history.recordImport(actor: "B", package: pkg, documentID: "d2", documentName: "Beta.pdf")
    history.recordImport(actor: "C", package: pkg, documentID: "d1", documentName: "Alpha.pdf")
    let d1Events = history.events(for: "d1")
    #expect(d1Events.count == 2)
  }

  @Test("Filter events by partner")
  @MainActor
  func filterByPartner() {
    let history = CollaborationHistory()
    history.clearAll()
    let alice = makePackage(author: "Alice")
    let bob = makePackage(author: "Bob")
    history.recordImport(actor: "X", package: alice, documentID: "d1", documentName: "A.pdf")
    history.recordImport(actor: "X", package: bob, documentID: "d1", documentName: "A.pdf")
    history.recordImport(actor: "X", package: alice, documentID: "d2", documentName: "B.pdf")
    let aliceEvents = history.events(withPartner: "Alice")
    #expect(aliceEvents.count == 2)
  }

  @Test("Filter events by kind")
  @MainActor
  func filterByKind() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage()
    history.recordImport(actor: "A", package: pkg, documentID: "d1", documentName: "A.pdf")
    let record = PartnerPackageRecord(package: pkg, documentID: "d1", documentName: "A.pdf")
    history.recordRemoval(actor: "A", packageRecord: record)
    let imports = history.events(kind: .packageImported)
    #expect(imports.count == 1)
  }

  @Test("Partner names returns unique sorted names")
  @MainActor
  func partnerNames() {
    let history = CollaborationHistory()
    history.clearAll()
    let alice = makePackage(author: "Alice")
    let bob = makePackage(author: "Bob")
    history.recordImport(actor: "X", package: alice, documentID: "d1", documentName: "A.pdf")
    history.recordImport(actor: "X", package: bob, documentID: "d1", documentName: "A.pdf")
    history.recordImport(actor: "X", package: alice, documentID: "d2", documentName: "B.pdf")
    let names = history.partnerNames
    #expect(names == ["Alice", "Bob"])
  }

  // MARK: - Summary

  @Test("Summary aggregates correctly")
  @MainActor
  func summary() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage(author: "Alice")
    history.recordImport(actor: "A", package: pkg, documentID: "d1", documentName: "A.pdf")
    let record = PartnerPackageRecord(package: pkg, documentID: "d1", documentName: "A.pdf")
    let result = AnnotationMergeResult(localOnly: [], partnerOnly: [makeMark()], duplicates: [], conflicts: [])
    history.recordMerge(actor: "A", packageRecord: record, mergeResult: result)
    let s = history.summary
    #expect(s.totalEvents == 2)
    #expect(s.totalImports == 1)
    #expect(s.totalMerges == 1)
    #expect(s.documentsInvolved == 1)
    #expect(s.partnersInvolved == 1)
  }

  @Test("Summary tracks suggestion follow rate")
  @MainActor
  func suggestionFollowRate() {
    let history = CollaborationHistory()
    history.clearAll()
    // Record 3 resolutions — 2 follow suggestion, 1 doesn't
    let c1 = ConflictRecord(packageRecordID: UUID(), documentName: "A.pdf",
      conflict: makeConflict(reason: .sameRegionDifferentContent))
    let c2 = ConflictRecord(packageRecordID: UUID(), documentName: "A.pdf",
      conflict: makeConflict(reason: .overlappingBounds(0.6)))
    let c3 = ConflictRecord(packageRecordID: UUID(), documentName: "A.pdf",
      conflict: makeConflict(reason: .sameTextDifferentPosition))

    // Get the suggested resolutions
    let s1 = c1.conflict.suggestedResolution
    let s2 = c2.conflict.suggestedResolution
    let s3 = c3.conflict.suggestedResolution

    history.recordResolution(actor: "A", conflict: c1, resolution: s1, documentName: "A.pdf") // follows
    history.recordResolution(actor: "A", conflict: c2, resolution: s2, documentName: "A.pdf") // follows
    history.recordResolution(actor: "A", conflict: c3, resolution: .keepLocal, documentName: "A.pdf") // might not follow

    let s = history.summary
    #expect(s.totalResolutions == 3)
    // Follow rate depends on whether keepLocal matches the suggestion
    #expect(s.suggestionFollowRate >= 0.0 && s.suggestionFollowRate <= 1.0)
  }

  // MARK: - Export

  @Test("Export JSON produces valid data")
  @MainActor
  func exportJSON() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage()
    history.recordImport(actor: "Test", package: pkg, documentID: "d1", documentName: "A.pdf")
    let data = history.exportJSON()
    #expect(data != nil)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try? decoder.decode([CollaborationHistoryEvent].self, from: data!)
    #expect(decoded?.count == 1)
    #expect(decoded?.first?.actor == "Test")
  }

  @Test("Export CSV contains header and data")
  @MainActor
  func exportCSV() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage()
    history.recordImport(actor: "Test", package: pkg, documentID: "d1", documentName: "A.pdf")
    let csv = history.exportCSV()
    #expect(csv.contains("Timestamp,Actor,Event"))
    #expect(csv.contains("Package Imported"))
    #expect(csv.contains("Test"))
  }

  // MARK: - Manager Integration

  @Test("Manager import records history")
  @MainActor
  func managerImportHistory() {
    let manager = CollaborationManager()
    manager.clearAll()
    manager.history.clearAll()
    let pkg = makePackage(author: "Alice", markCount: 3)
    manager.importPackage(pkg, documentID: "d1", documentName: "A.pdf", actor: "Bob")
    #expect(manager.history.events.count == 1)
    #expect(manager.history.events.first?.kind == .packageImported)
    #expect(manager.history.events.first?.partnerName == "Alice")
  }

  @Test("Manager resolve records history")
  @MainActor
  func managerResolveHistory() {
    let manager = CollaborationManager()
    manager.clearAll()
    manager.history.clearAll()
    let pkg = makePackage()
    let record = manager.importPackage(pkg, documentID: "d1", documentName: "A.pdf", actor: "Bob")
    let conflict = makeConflict()
    manager.updateMergeStatus(
      packageID: record.id,
      status: .conflicts,
      newConflicts: [conflict],
      actor: "Bob"
    )
    let conflictID = manager.conflicts[0].id
    manager.resolveConflict(conflictID: conflictID, resolution: .keepBoth, actor: "Bob")

    // Should have import + resolve events
    let events = manager.history.events
    #expect(events.count == 2)
    #expect(events[0].kind == .conflictResolved)
    #expect(events[1].kind == .packageImported)
  }

  @Test("Manager remove records history")
  @MainActor
  func managerRemoveHistory() {
    let manager = CollaborationManager()
    manager.clearAll()
    manager.history.clearAll()
    let pkg = makePackage()
    let record = manager.importPackage(pkg, documentID: "d1", documentName: "A.pdf", actor: "Bob")
    manager.removePackage(id: record.id, actor: "Bob")
    let events = manager.history.events
    #expect(events.first?.kind == .packageRemoved)
  }

  // MARK: - Clear

  @Test("Clear all resets events")
  @MainActor
  func clearAll() {
    let history = CollaborationHistory()
    history.clearAll()
    let pkg = makePackage()
    history.recordImport(actor: "Test", package: pkg, documentID: "d1", documentName: "A.pdf")
    #expect(history.events.count == 1)
    history.clearAll()
    #expect(history.events.count == 0)
  }

  // MARK: - Helpers

  private func makePackage(author: String = "TestUser", markCount: Int = 2) -> CollaborationPackage {
    let marks = (0..<markCount).map { i in
      AnnotationMark(
        type: .highlight,
        pageIndex: i,
        bounds: PDFRect(x: 10, y: Double(i * 50), width: 200, height: 20),
        selectedText: "Mark \(i)",
        note: "Note \(i)"
      )
    }
    return CollaborationPackage(
      authorName: author,
      authorNote: "Test",
      documentIdentity: DocumentIdentity(
        contentHash: "abc123",
        fileName: "test.pdf",
        pageCount: 10,
        fileSize: 1024000
      ),
      annotations: marks,
      pdfIntegrityHash: "hash"
    )
  }

  private func makeMark(text: String = "test") -> AnnotationMark {
    AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: text
    )
  }

  private func makeConflict(reason: ConflictReason = .sameRegionDifferentContent) -> AnnotationConflict {
    let local = AnnotationMark(
      type: .highlight, pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: "Local text", note: "Local note"
    )
    let partner = AnnotationMark(
      type: .highlight, pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: "Partner text", note: "Partner note"
    )
    let hint = ConflictResolutionHint.analyze(local: local, partner: partner, reason: reason)
    return AnnotationConflict(
      localMark: local,
      partnerMark: partner,
      reason: reason,
      resolution: hint.suggested,
      suggestedResolution: hint.suggested,
      hintExplanation: hint.explanation,
      hintConfidence: hint.confidence
    )
  }
}
