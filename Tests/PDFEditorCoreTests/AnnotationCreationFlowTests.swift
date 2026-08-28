import Testing
import Foundation
@testable import PDFEditorCore

@Suite("AnnotationCreationFlow")
struct AnnotationCreationFlowTests {

  // MARK: - Version-Tracked Creation

  @Test("AddMark records creation version")
  @MainActor
  func addMarkRecordsVersion() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    store.deleteAllMarks()
    store.versionStore.clearAll()
    let mark = AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: "Important text",
      note: "Remember this"
    )
    store.addMark(mark, actor: "TestUser")
    #expect(store.marks.count == 1)
    #expect(store.versionStore.chains.count == 1)
    let chain = store.versionStore.chain(for: mark.id)
    #expect(chain?.count == 1)
    #expect(chain?.current?.changeType == .created)
    #expect(chain?.current?.actor == "TestUser")
  }

  @Test("UpdateMark records change version")
  @MainActor
  func updateMarkRecordsVersion() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    let mark = store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 100, width: 200, height: 20),
      selectedText: "Original"
    ), actor: "Alice")
    store.updateMark(id: mark.id, actor: "Bob") { $0.note = "Added note" }
    let chain = store.versionStore.chain(for: mark.id)
    #expect(chain?.count == 2)
    #expect(chain?.versions.last?.changeType == .noteEdited)
    #expect(chain?.versions.last?.actor == "Bob")
  }

  @Test("ToggleVisibility records visibility version")
  @MainActor
  func toggleVisibilityRecordsVersion() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    let mark = store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 10),
      selectedText: "Visible"
    ))
    store.toggleVisibility(id: mark.id, actor: "Carol")
    let chain = store.versionStore.chain(for: mark.id)
    #expect(chain?.count == 2)
    #expect(chain?.versions.last?.changeType == .visibilityToggled)
    #expect(store.marks.first?.isVisible == false)
  }

  // MARK: - Full Flow: Select → Create → Query

  @Test("Full flow: select text, create highlight, find in search")
  @MainActor
  func fullFlowHighlight() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "contract.pdf")

    // Simulate text selection → toolbar → create mark
    let mark = store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 2,
      bounds: PDFRect(x: 72, y: 500, width: 400, height: 18),
      selectedText: "The parties agree to the following terms",
      note: "Key clause",
      color: .yellow
    ), actor: "User")

    // Verify mark exists
    #expect(store.marks.count == 1)
    #expect(mark.selectedText == "The parties agree to the following terms")
    #expect(mark.pageIndex == 2)

    // Verify search works
    let results = store.search(AnnotationSearchQuery(text: "parties agree"))
    #expect(results.count == 1)
    #expect(results[0].id == mark.id)

    // Verify page filter works
    let pageMarks = store.marksForPage(2)
    #expect(pageMarks.count == 1)

    // Verify version chain
    let chain = store.versionStore.chain(for: mark.id)
    #expect(chain?.count == 1)
    #expect(chain?.current?.changeType == .created)
  }

  @Test("Full flow: select text, create note, add another highlight")
  @MainActor
  func fullFlowMultipleMarks() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "report.pdf")

    // First: create a note
    let note = store.addMark(AnnotationMark(
      type: .note,
      pageIndex: 0,
      bounds: PDFRect(x: 50, y: 700, width: 24, height: 24),
      selectedText: "",
      note: "Check with legal team",
      color: .blue
    ))

    // Second: create a highlight on same page
    let highlight = store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 72, y: 400, width: 300, height: 16),
      selectedText: " liability clause",
      color: .red
    ))

    #expect(store.marks.count == 2)
    #expect(store.marksForPage(0).count == 2)

    // Verify types
    #expect(note.type == .note)
    #expect(highlight.type == .highlight)

    // Verify version chains are independent
    let chainNote = store.versionStore.chain(for: note.id)
    let chainHighlight = store.versionStore.chain(for: highlight.id)
    #expect(chainNote?.count == 1)
    #expect(chainHighlight?.count == 1)
  }

  // MARK: - Annotation Types

  @Test("All annotation types can be created")
  @MainActor
  func allAnnotationTypes() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    let types: [AnnotationType] = [.highlight, .underline, .note, .strikethrough, .freehand]
    for type in types {
      store.addMark(AnnotationMark(
        type: type,
        pageIndex: 0,
        bounds: PDFRect(x: 0, y: 0, width: 100, height: 10),
        selectedText: "Test for \(type.displayName)"
      ))
    }
    #expect(store.marks.count == types.count)
    #expect(store.marksByType.count == types.count)
  }

  // MARK: - Edit After Creation

  @Test("Edit mark note after creation tracks version")
  @MainActor
  func editNoteAfterCreation() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test-versions-edit")
    store.deleteAllMarks()
    store.versionStore.clearAll()
    let mark = store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 10),
      selectedText: "Important"
    ))

    // Edit note
    store.updateMark(id: mark.id) { $0.note = "First note" }
    let chain = store.versionStore.chain(for: mark.id)
    #expect(chain?.count == 2)
    #expect(chain?.versions[1].changeType == .noteEdited)

    // Edit note again — need a fresh read of the mark to ensure the change is detected
    let currentMark = store.marks.first!
    store.updateMark(id: mark.id) { $0.note = "Updated note" }
    let chainAfter = store.versionStore.chain(for: mark.id)
    #expect(chainAfter?.count == 3)

    // Verify diff
    let diff = store.versionStore.diffFromOriginal(markID: mark.id)
    #expect(diff?.noteChanged == true)
    #expect(diff?.textChanged == false)
  }

  // MARK: - Delete

  @Test("Delete mark removes from store")
  @MainActor
  func deleteMark() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    let mark = store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 10)
    ))
    #expect(store.marks.count == 1)
    store.deleteMark(id: mark.id)
    #expect(store.marks.count == 0)
    // Version chain still exists (history preserved)
    #expect(store.versionStore.chain(for: mark.id) != nil)
  }

  // MARK: - Tags

  @Test("Create mark with tags and search by tag")
  @MainActor
  func tagsOnCreation() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    store.addMark(AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 10),
      selectedText: "Tagged text",
      tags: ["important", "legal"]
    ))
    let results = store.search(AnnotationSearchQuery(tags: ["important"]))
    #expect(results.count == 1)
    #expect(store.allTags.contains("important"))
    #expect(store.allTags.contains("legal"))
  }
}
