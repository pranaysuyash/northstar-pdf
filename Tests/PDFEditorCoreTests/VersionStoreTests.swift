import Foundation
import Testing
@testable import PDFEditorCore

@Suite("VersionStore")
struct VersionStoreTests {
  // MARK: - VersionSnapshot

  @Test("Snapshot creates with correct fields")
  func snapshotCreation() {
    let snap = VersionSnapshot(
      versionNumber: 1,
      label: "Initial",
      operations: [],
      digest: "abc123",
      sourceHash: "def456"
    )
    #expect(snap.versionNumber == 1)
    #expect(snap.label == "Initial")
    #expect(snap.operationCount == 0)
    #expect(snap.digest == "abc123")
    #expect(snap.sourceHash == "def456")
  }

  @Test("Snapshot summary includes version and label")
  func snapshotSummary() {
    let snap = VersionSnapshot(
      versionNumber: 3,
      label: "After edits",
      operations: [],
      digest: "abc",
      sourceHash: "def"
    )
    let summary = snap.summary
    #expect(summary.contains("v3"))
    #expect(summary.contains("After edits"))
    #expect(summary.contains("0 operations"))
  }

  @Test("Snapshot is Codable")
  func snapshotCodable() {
    let snap = VersionSnapshot(
      versionNumber: 1,
      label: "Test",
      operations: [],
      digest: "abc",
      sourceHash: "def"
    )
    let data = try? JSONEncoder().encode(snap)
    #expect(data != nil)
    let decoded = try? JSONDecoder().decode(VersionSnapshot.self, from: data!)
    #expect(decoded?.versionNumber == 1)
    #expect(decoded?.id == snap.id)
  }

  // MARK: - VersionComparison

  @Test("Comparison detects added operations")
  func comparisonAdded() {
    let from = VersionSnapshot(versionNumber: 1, operations: [], digest: "a", sourceHash: "b")
    let op = EditOperation(pageIndex: 0, kind: .overlayText, value: "hello")
    let to = VersionSnapshot(versionNumber: 2, operations: [op], digest: "c", sourceHash: "d")
    let comparison = VersionComparison(from: from, to: to)
    #expect(comparison.addedOperations.count == 1)
    #expect(comparison.hasChanges == true)
  }

  @Test("Comparison detects removed operations")
  func comparisonRemoved() {
    let op = EditOperation(pageIndex: 0, kind: .overlayText, value: "hello")
    let from = VersionSnapshot(versionNumber: 1, operations: [op], digest: "a", sourceHash: "b")
    let to = VersionSnapshot(versionNumber: 2, operations: [], digest: "c", sourceHash: "d")
    let comparison = VersionComparison(from: from, to: to)
    #expect(comparison.removedOperations.count == 1)
    #expect(comparison.hasChanges == true)
  }

  @Test("Comparison with no changes")
  func comparisonNoChanges() {
    let ops = [EditOperation(pageIndex: 0, kind: .overlayText, value: "hello")]
    let from = VersionSnapshot(versionNumber: 1, operations: ops, digest: "a", sourceHash: "b")
    let to = VersionSnapshot(versionNumber: 2, operations: ops, digest: "a", sourceHash: "b")
    let comparison = VersionComparison(from: from, to: to)
    #expect(comparison.hasChanges == false)
    #expect(comparison.addedOperations.isEmpty)
    #expect(comparison.removedOperations.isEmpty)
  }

  // MARK: - VersionStore

  @Test("Store starts empty")
  @MainActor
  func storeEmpty() {
    let store = VersionStore(documentID: "test-empty")
    store.clearAll()
    #expect(store.snapshots.isEmpty)
    #expect(store.latestSnapshot == nil)
  }

  @Test("Save snapshot increments version")
  @MainActor
  func storeSaveSnapshot() {
    let store = VersionStore(documentID: "test-save")
    store.clearAll()
    let snap1 = store.saveSnapshot(operations: [], sourceHash: "abc", label: "First")
    #expect(snap1.versionNumber == 1)
    let snap2 = store.saveSnapshot(operations: [], sourceHash: "def", label: "Second")
    #expect(snap2.versionNumber == 2)
    #expect(store.snapshots.count == 2)
  }

  @Test("Latest snapshot returns last")
  @MainActor
  func storeLatest() {
    let store = VersionStore(documentID: "test-latest")
    store.clearAll()
    store.saveSnapshot(operations: [], sourceHash: "a")
    let latest = store.saveSnapshot(operations: [], sourceHash: "b", label: "Latest")
    #expect(store.latestSnapshot?.id == latest.id)
  }

  @Test("Get snapshot by version number")
  @MainActor
  func storeGetByVersion() {
    let store = VersionStore(documentID: "test-get")
    store.clearAll()
    store.saveSnapshot(operations: [], sourceHash: "a")
    store.saveSnapshot(operations: [], sourceHash: "b")
    let snap = store.snapshot(version: 2)
    #expect(snap?.versionNumber == 2)
    #expect(store.snapshot(version: 99) == nil)
  }

  @Test("Compare two versions")
  @MainActor
  func storeCompare() {
    let store = VersionStore(documentID: "test-compare")
    store.clearAll()
    store.saveSnapshot(operations: [], sourceHash: "a")
    let op = EditOperation(pageIndex: 0, kind: .overlayText, value: "hello")
    store.saveSnapshot(operations: [op], sourceHash: "b")
    let comparison = store.compare(from: 1, to: 2)
    #expect(comparison != nil)
    #expect(comparison?.hasChanges == true)
  }

  @Test("Delete snapshot")
  @MainActor
  func storeDelete() {
    let store = VersionStore(documentID: "test-delete")
    store.clearAll()
    let snap = store.saveSnapshot(operations: [], sourceHash: "a")
    store.deleteSnapshot(id: snap.id)
    #expect(store.snapshots.isEmpty)
  }

  @Test("Clear all snapshots")
  @MainActor
  func storeClear() {
    let store = VersionStore(documentID: "test-clear")
    store.saveSnapshot(operations: [], sourceHash: "a")
    store.saveSnapshot(operations: [], sourceHash: "b")
    store.clearAll()
    #expect(store.snapshots.isEmpty)
  }

  @Test("Compute digest is deterministic for same input")
  @MainActor
  func digestDeterministic() {
    let fixedID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
    let date = Date(timeIntervalSince1970: 1000)
    let ops = [EditOperation(id: fixedID, pageIndex: 0, kind: .overlayText, value: "hello", createdAt: date)]
    let d1 = VersionStore.computeDigest(ops)
    let d2 = VersionStore.computeDigest(ops)
    #expect(d1 == d2)
    #expect(d1.count == 64)
  }

  @Test("Different operations produce different digests")
  @MainActor
  func digestDifferent() {
    let fixedID = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
    let date = Date(timeIntervalSince1970: 1000)
    let op1 = EditOperation(id: fixedID, pageIndex: 0, kind: .overlayText, value: "hello", createdAt: date)
    let op2 = EditOperation(id: fixedID, pageIndex: 0, kind: .overlayText, value: "world", createdAt: date)
    let d1 = VersionStore.computeDigest([op1])
    let d2 = VersionStore.computeDigest([op2])
    #expect(d1 != d2)
  }

  @Test("Operations for revert")
  @MainActor
  func storeRevert() {
    let store = VersionStore(documentID: "test-revert")
    store.clearAll()
    let op1 = EditOperation(pageIndex: 0, kind: .overlayText, value: "first")
    let op2 = EditOperation(pageIndex: 0, kind: .overlayText, value: "second")
    store.saveSnapshot(operations: [op1], sourceHash: "a")
    store.saveSnapshot(operations: [op1, op2], sourceHash: "b")
    let revertOps = store.operationsForRevert(from: 1, to: 2)
    #expect(revertOps != nil)
    #expect(revertOps?.count == 1) // op2 was added
  }

  // MARK: - Sendable

  @Test("VersionSnapshot is Sendable")
  func snapshotSendable() {
    let snap = VersionSnapshot(versionNumber: 1, operations: [], digest: "a", sourceHash: "b")
    Task {
      let captured = snap
      #expect(captured.versionNumber == 1)
    }
  }
}
