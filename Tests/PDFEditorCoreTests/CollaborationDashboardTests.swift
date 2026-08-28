import Testing
import Foundation
@testable import PDFEditorCore

@Suite("CollaborationDashboard")
struct CollaborationDashboardTests {

  // MARK: - Package Import

  @Test("Import package creates record with pending status")
  @MainActor
  func importPackage() {
    let manager = CollaborationManager()
    manager.clearAll()
    let pkg = makePackage(author: "Alice", markCount: 3)
    let record = manager.importPackage(pkg, documentID: "doc-1", documentName: "Report.pdf")
    #expect(record.mergeStatus == .pending)
    #expect(record.package.annotations.count == 3)
    #expect(record.package.authorName == "Alice")
    #expect(manager.packages.count == 1)
  }

  @Test("Import multiple packages for different documents")
  @MainActor
  func importMultiple() {
    let manager = CollaborationManager()
    manager.clearAll()
    manager.importPackage(makePackage(author: "Alice"), documentID: "doc-1", documentName: "A.pdf")
    manager.importPackage(makePackage(author: "Bob"), documentID: "doc-2", documentName: "B.pdf")
    manager.importPackage(makePackage(author: "Carol"), documentID: "doc-1", documentName: "A.pdf")
    #expect(manager.packages.count == 3)
    #expect(manager.packages(for: "doc-1").count == 2)
    #expect(manager.packages(for: "doc-2").count == 1)
  }

  // MARK: - Merge Status

  @Test("Update merge status to merged")
  @MainActor
  func mergeStatus() {
    let manager = CollaborationManager()
    manager.clearAll()
    let record = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")
    manager.updateMergeStatus(packageID: record.id, status: .merged)
    #expect(manager.packages.first?.mergeStatus == .merged)
    #expect(manager.dashboardSummary.mergedCount == 1)
  }

  @Test("Update merge status with conflicts records them")
  @MainActor
  func mergeWithConflicts() {
    let manager = CollaborationManager()
    manager.clearAll()
    let record = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")

    let conflict = makeConflict()
    manager.updateMergeStatus(packageID: record.id, status: .conflicts, newConflicts: [conflict])

    #expect(manager.packages.first?.mergeStatus == .conflicts)
    #expect(manager.packages.first?.unresolvedConflictCount == 1)
    #expect(manager.conflicts.count == 1)
    #expect(manager.dashboardSummary.totalUnresolvedConflicts == 1)
  }

  // MARK: - Conflict Resolution

  @Test("Resolve conflict updates package and dashboard")
  @MainActor
  func resolveConflict() {
    let manager = CollaborationManager()
    manager.clearAll()
    let record = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")

    let c1 = makeConflict()
    let c2 = makeConflict()
    manager.updateMergeStatus(packageID: record.id, status: .conflicts, newConflicts: [c1, c2])

    #expect(manager.conflicts.count == 2)
    #expect(manager.dashboardSummary.totalUnresolvedConflicts == 2)

    // Resolve one
    let firstConflictID = manager.conflicts[0].id
    manager.resolveConflict(conflictID: firstConflictID, resolution: .keepLocal)

    #expect(manager.dashboardSummary.totalUnresolvedConflicts == 1)
    #expect(manager.conflicts[0].resolution == .keepLocal)
    #expect(manager.conflicts[0].isResolved == true)

    // Resolve the other
    let secondConflictID = manager.conflicts[1].id
    manager.resolveConflict(conflictID: secondConflictID, resolution: .keepBoth)

    #expect(manager.dashboardSummary.totalUnresolvedConflicts == 0)
    #expect(manager.dashboardSummary.allResolved == true)
    #expect(manager.packages.first?.mergeStatus == .resolved)
  }

  // MARK: - Dashboard Summary

  @Test("Dashboard summary aggregates correctly")
  @MainActor
  func dashboardSummary() {
    let manager = CollaborationManager()
    manager.clearAll()

    let r1 = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")
    let r2 = manager.importPackage(makePackage(), documentID: "d2", documentName: "B.pdf")
    let r3 = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")

    manager.updateMergeStatus(packageID: r1.id, status: .merged)
    manager.updateMergeStatus(packageID: r2.id, status: .conflicts, newConflicts: [makeConflict()])
    // r3 stays pending

    let summary = manager.dashboardSummary
    #expect(summary.totalPackages == 3)
    #expect(summary.mergedCount == 1)
    #expect(summary.conflictCount == 1)
    #expect(summary.pendingCount == 1)
    #expect(summary.documentsInvolved == 2)
    #expect(summary.totalUnresolvedConflicts == 1)
    #expect(summary.hasConflicts == true)
  }

  @Test("Empty dashboard shows zero stats")
  @MainActor
  func emptyDashboard() {
    let manager = CollaborationManager()
    manager.clearAll()
    let summary = manager.dashboardSummary
    #expect(summary.totalPackages == 0)
    #expect(summary.totalUnresolvedConflicts == 0)
    #expect(summary.allResolved == false)
    #expect(summary.hasConflicts == false)
  }

  // MARK: - Conflicts By Document

  @Test("Conflicts grouped by document")
  @MainActor
  func conflictsByDocument() {
    let manager = CollaborationManager()
    manager.clearAll()

    let r1 = manager.importPackage(makePackage(), documentID: "d1", documentName: "Alpha.pdf")
    let r2 = manager.importPackage(makePackage(), documentID: "d2", documentName: "Beta.pdf")

    manager.updateMergeStatus(packageID: r1.id, status: .conflicts, newConflicts: [makeConflict()])
    manager.updateMergeStatus(packageID: r2.id, status: .conflicts, newConflicts: [makeConflict(), makeConflict()])

    let grouped = manager.unresolvedConflictsByDocument
    #expect(grouped.count == 2)
    #expect(grouped[0].documentName == "Alpha.pdf")
    #expect(grouped[0].conflicts.count == 1)
    #expect(grouped[1].documentName == "Beta.pdf")
    #expect(grouped[1].conflicts.count == 2)
  }

  // MARK: - Package Removal

  @Test("Remove package cleans up conflicts")
  @MainActor
  func removePackage() {
    let manager = CollaborationManager()
    manager.clearAll()

    let r1 = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")
    manager.updateMergeStatus(packageID: r1.id, status: .conflicts, newConflicts: [makeConflict()])

    #expect(manager.packages.count == 1)
    #expect(manager.conflicts.count == 1)

    manager.removePackage(id: r1.id)

    #expect(manager.packages.count == 0)
    #expect(manager.conflicts.count == 0)
  }

  @Test("Remove package only cleans its own conflicts")
  @MainActor
  func removePackageOnlyOwnConflicts() {
    let manager = CollaborationManager()
    manager.clearAll()

    let r1 = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")
    let r2 = manager.importPackage(makePackage(), documentID: "d1", documentName: "A.pdf")

    manager.updateMergeStatus(packageID: r1.id, status: .conflicts, newConflicts: [makeConflict()])
    manager.updateMergeStatus(packageID: r2.id, status: .conflicts, newConflicts: [makeConflict()])

    manager.removePackage(id: r1.id)

    #expect(manager.packages.count == 1)
    #expect(manager.conflicts.count == 1)
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
      authorNote: "Test note from \(author)",
      documentIdentity: DocumentIdentity(
        contentHash: "abc123def456",
        fileName: "test.pdf",
        pageCount: 10,
        fileSize: 1024000
      ),
      annotations: marks,
      pdfIntegrityHash: "hash123"
    )
  }

  private func makeConflict() -> AnnotationConflict {
    let local = AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: "Important text",
      note: "Local note"
    )
    let partner = AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: "Important text",
      note: "Partner note"
    )
    return AnnotationConflict(
      localMark: local,
      partnerMark: partner,
      reason: .sameNoteContent,
      resolution: .keepBoth,
      suggestedResolution: .keepBoth,
      hintExplanation: "Same note on different text — different contexts",
      hintConfidence: 0.80
    )
  }
}
