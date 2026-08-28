import Testing
import Foundation
@testable import PDFEditorCore

@Suite("AnnotationVersionStore")
struct AnnotationVersionTests {

  // MARK: - Creation

  @Test("Record creation creates version 1")
  @MainActor
  func recordCreation() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id)
    let version = store.recordCreation(of: mark, actor: "Alice")
    #expect(version.versionNumber == 1)
    #expect(version.changeType == .created)
    #expect(version.actor == "Alice")
    let chain = store.chain(for: id)
    #expect(chain?.count == 1)
    #expect(chain?.current?.actor == "Alice")
  }

  // MARK: - Updates

  @Test("Record update increments version number")
  @MainActor
  func recordUpdate() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id, text: "Original text")
    store.recordCreation(of: mark, actor: "Alice")
    let updated = makeMark(id: id, text: "Updated text")
    let version = store.recordUpdate(
      of: updated, previousMark: mark,
      changeType: .textEdited, description: "Text changed", actor: "Bob"
    )
    #expect(version.versionNumber == 2)
    #expect(version.actor == "Bob")
    #expect(version.changeType == .textEdited)
    let chain = store.chain(for: id)
    #expect(chain?.count == 2)
    #expect(chain?.editCount == 1)
  }

  @Test("Multiple updates build version chain")
  @MainActor
  func multipleUpdates() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let m1 = makeMark(id: id, text: "V1")
    store.recordCreation(of: m1, actor: "Alice")
    let m2 = makeMark(id: id, text: "V2")
    store.recordUpdate(of: m2, previousMark: m1, changeType: .textEdited, description: "Edit 1")
    let m3 = makeMark(id: id, text: "V2", note: "Added note")
    store.recordUpdate(of: m3, previousMark: m2, changeType: .noteEdited, description: "Edit 2")
    let chain = store.chain(for: id)
    #expect(chain?.count == 3)
    #expect(chain?.editCount == 2)
    #expect(chain?.hasBeenEdited == true)
    #expect(chain?.actors.contains("Alice") == true)
  }

  // MARK: - Diff

  @Test("Diff detects text change")
  @MainActor
  func diffTextChange() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id, text: "Original")
    store.recordCreation(of: mark, actor: "Alice")
    let updated = makeMark(id: id, text: "Changed")
    store.recordUpdate(of: updated, previousMark: mark, changeType: .textEdited, description: "Changed text")
    let diff = store.diff(markID: id, from: 1, to: 2)
    #expect(diff != nil)
    #expect(diff?.textChanged == true)
    #expect(diff?.noteChanged == false)
    #expect(diff?.hasChanges == true)
  }

  @Test("Diff detects multiple changes")
  @MainActor
  func diffMultipleChanges() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id, text: "Original", note: "Old note")
    store.recordCreation(of: mark, actor: "Alice")
    let updated = makeMark(id: id, text: "New text", note: "New note", color: .red)
    store.recordUpdate(of: updated, previousMark: mark, changeType: .textEdited, description: "Multiple changes")
    let diff = store.diff(markID: id, from: 1, to: 2)
    #expect(diff?.textChanged == true)
    #expect(diff?.noteChanged == true)
    #expect(diff?.colorChanged == true)
    #expect(diff?.summary.count == 3)
  }

  @Test("Diff from original summarizes all changes")
  @MainActor
  func diffFromOriginal() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let m1 = makeMark(id: id, text: "V1")
    store.recordCreation(of: m1, actor: "Alice")
    let m2 = makeMark(id: id, text: "V2")
    store.recordUpdate(of: m2, previousMark: m1, changeType: .textEdited, description: "Edit")
    let m3 = makeMark(id: id, text: "V2", note: "Note added")
    store.recordUpdate(of: m3, previousMark: m2, changeType: .noteEdited, description: "Note")
    let diff = store.diffFromOriginal(markID: id)
    #expect(diff?.fromVersion == 1)
    #expect(diff?.toVersion == 3)
    #expect(diff?.textChanged == true)
    #expect(diff?.noteChanged == true)
  }

  // MARK: - Restore

  @Test("Snapshot at version returns correct state")
  @MainActor
  func snapshotAtVersion() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id, text: "V1")
    store.recordCreation(of: mark, actor: "Alice")
    let updated = makeMark(id: id, text: "V2")
    store.recordUpdate(of: updated, previousMark: mark, changeType: .textEdited, description: "Edit")
    let snap1 = store.snapshot(markID: id, at: 1)
    let snap2 = store.snapshot(markID: id, at: 2)
    #expect(snap1?.selectedText == "V1")
    #expect(snap2?.selectedText == "V2")
  }

  // MARK: - Querying

  @Test("Edited marks returns only marks with multiple versions")
  @MainActor
  func editedMarks() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id1 = UUID()
    let m1 = makeMark(id: id1, text: "Unchanged")
    store.recordCreation(of: m1, actor: "Alice")
    let id2 = UUID()
    let m2 = makeMark(id: id2, text: "Will change")
    store.recordCreation(of: m2, actor: "Alice")
    let updated = makeMark(id: id2, text: "Changed")
    store.recordUpdate(of: updated, previousMark: m2, changeType: .textEdited, description: "Edit")
    #expect(store.editedMarks.count == 1)
    #expect(store.editedMarks.first?.markID == id2)
  }

  @Test("All actors returns unique sorted names")
  @MainActor
  func allActors() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id)
    store.recordCreation(of: mark, actor: "Charlie")
    let updated = makeMark(id: id, text: "Changed")
    store.recordUpdate(of: updated, previousMark: mark, changeType: .textEdited, description: "Edit", actor: "Alice")
    #expect(store.allActors == ["Alice", "Charlie"])
  }

  // MARK: - Import

  @Test("Record import creates version 1 for each mark")
  @MainActor
  func recordImport() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let marks = (0..<3).map { _ in makeMark() }
    store.recordImport(of: marks, actor: "Partner")
    #expect(store.chains.count == 3)
    for mark in marks {
      let chain = store.chain(for: mark.id)
      #expect(chain?.count == 1)
      #expect(chain?.current?.changeType == .imported)
    }
  }

  // MARK: - Statistics

  @Test("Statistics aggregate correctly")
  @MainActor
  func statistics() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id1 = UUID()
    let m1 = makeMark(id: id1)
    store.recordCreation(of: m1, actor: "Alice")
    let u1 = makeMark(id: id1, text: "Changed")
    store.recordUpdate(of: u1, previousMark: m1, changeType: .textEdited, description: "Edit", actor: "Alice")
    let id2 = UUID()
    let m2 = makeMark(id: id2)
    store.recordCreation(of: m2, actor: "Bob")
    let stats = store.statistics
    #expect(stats.totalMarks == 2)
    #expect(stats.totalVersions == 3)
    #expect(stats.editedCount == 1)
    #expect(stats.actorCount == 2)
  }

  @Test("Version chain description is correct")
  @MainActor
  func chainDescription() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id)
    store.recordCreation(of: mark, actor: "Alice")
    let chain = store.chain(for: id)
    #expect(chain?.description == "Created by Alice")
    let updated = makeMark(id: id, text: "Changed")
    store.recordUpdate(of: updated, previousMark: mark, changeType: .textEdited, description: "Edit", actor: "Bob")
    let chain2 = store.chain(for: id)
    #expect(chain2?.description.contains("2 versions") == true)
    #expect(chain2?.description.contains("Alice") == true)
    #expect(chain2?.description.contains("Bob") == true)
  }

  @Test("Diff with same version returns nil")
  @MainActor
  func diffSameVersion() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id)
    store.recordCreation(of: mark, actor: "Alice")
    let diff = store.diff(markID: id, from: 1, to: 1)
    #expect(diff == nil)
  }

  @Test("Diff with invalid version returns nil")
  @MainActor
  func diffInvalidVersion() {
    let store = AnnotationVersionStore()
    store.bind(toDocumentID: "test.pdf")
    store.clearAll()
    let id = UUID()
    let mark = makeMark(id: id)
    store.recordCreation(of: mark, actor: "Alice")
    let diff = store.diff(markID: id, from: 0, to: 5)
    #expect(diff == nil)
  }

  // MARK: - Helpers

  private func makeMark(
    id: UUID = UUID(),
    text: String = "Test text",
    note: String = "",
    type: AnnotationType = .highlight,
    color: AnnotationColor = .yellow
  ) -> AnnotationMark {
    AnnotationMark(
      id: id,
      type: type,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: text,
      note: note,
      color: color
    )
  }
}
