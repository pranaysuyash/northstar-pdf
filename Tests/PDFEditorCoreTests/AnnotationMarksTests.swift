import Foundation
import Testing
@testable import PDFEditorCore

@Suite("AnnotationMarks")
struct AnnotationMarksTests {
  // MARK: - AnnotationMark

  @Test("Mark creates with correct fields")
  func markCreation() {
    let mark = AnnotationMark(
      type: .highlight,
      pageIndex: 2,
      bounds: PDFRect(x: 10, y: 20, width: 100, height: 30),
      selectedText: "important text",
      note: "remember this",
      color: .yellow
    )
    #expect(mark.type == .highlight)
    #expect(mark.pageIndex == 2)
    #expect(mark.selectedText == "important text")
    #expect(mark.note == "remember this")
    #expect(mark.color == .yellow)
    #expect(mark.isVisible == true)
    #expect(mark.tags.isEmpty)
  }

  @Test("Mark summary includes type and page")
  func markSummary() {
    let mark = AnnotationMark(
      type: .note,
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 50, height: 50),
      selectedText: "hello world",
      note: "my note"
    )
    let summary = mark.summary
    #expect(summary.contains("Note"))
    #expect(summary.contains("page 1"))
    #expect(summary.contains("hello world"))
  }

  @Test("Mark is Codable")
  func markCodable() {
    let mark = AnnotationMark(type: .underline, pageIndex: 1, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10))
    let data = try? JSONEncoder().encode(mark)
    #expect(data != nil)
    let decoded = try? JSONDecoder().decode(AnnotationMark.self, from: data!)
    #expect(decoded?.type == .underline)
    #expect(decoded?.id == mark.id)
  }

  // MARK: - AnnotationType

  @Test("All annotation types exist")
  func allTypes() {
    #expect(AnnotationType.allCases.count == 5)
  }

  @Test("Type symbol names are distinct")
  func typeSymbols() {
    let symbols = Set(AnnotationType.allCases.map(\.symbolName))
    #expect(symbols.count == AnnotationType.allCases.count)
  }

  // MARK: - AnnotationColor

  @Test("All colors exist")
  func allColors() {
    #expect(AnnotationColor.allCases.count == 8)
  }

  @Test("Colors have hex values")
  func colorHex() {
    for color in AnnotationColor.allCases {
      #expect(color.hexColor.hasPrefix("#"))
      #expect(color.hexColor.count == 7)
    }
  }

  // MARK: - AnnotationSearchQuery

  @Test("Default query matches all")
  func defaultQuery() {
    let query = AnnotationSearchQuery()
    #expect(query.type == nil)
    #expect(query.color == nil)
    #expect(query.text == nil)
    #expect(query.visibleOnly == true)
  }

  // MARK: - AnnotationStore

  @Test("Store starts empty")
  @MainActor
  func storeEmpty() {
    let store = AnnotationStore()
    #expect(store.marks.isEmpty)
  }

  @Test("Add mark")
  @MainActor
  func storeAdd() {
    let store = AnnotationStore()
    let mark = AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10))
    store.addMark(mark)
    #expect(store.marks.count == 1)
  }

  @Test("Delete mark")
  @MainActor
  func storeDelete() {
    let store = AnnotationStore()
    let mark = store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.deleteMark(id: mark.id)
    #expect(store.marks.isEmpty)
  }

  @Test("Update mark")
  @MainActor
  func storeUpdate() {
    let store = AnnotationStore()
    let mark = store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), note: "old"))
    store.updateMark(id: mark.id) { $0.note = "new" }
    #expect(store.marks.first?.note == "new")
  }

  @Test("Toggle visibility")
  @MainActor
  func storeToggleVisibility() {
    let store = AnnotationStore()
    let mark = store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    #expect(store.marks.first?.isVisible == true)
    store.toggleVisibility(id: mark.id)
    #expect(store.marks.first?.isVisible == false)
  }

  // MARK: - Search

  @Test("Search by type")
  @MainActor
  func searchByType() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .underline, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))

    let highlights = store.search(AnnotationSearchQuery(type: .highlight))
    #expect(highlights.count == 1)
    #expect(highlights.first?.type == .highlight)
  }

  @Test("Search by text")
  @MainActor
  func searchByText() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), selectedText: "important clause"))
    store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), note: "remember this"))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), selectedText: "other text"))

    let results = store.search(AnnotationSearchQuery(text: "important"))
    #expect(results.count == 1)
    #expect(results.first?.selectedText == "important clause")
  }

  @Test("Search by text in notes")
  @MainActor
  func searchByNoteText() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), note: "ask lawyer about this"))
    store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), note: "looks fine"))

    let results = store.search(AnnotationSearchQuery(text: "lawyer"))
    #expect(results.count == 1)
  }

  @Test("Search by page")
  @MainActor
  func searchByPage() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 5, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))

    let results = store.search(AnnotationSearchQuery(pageIndex: 5))
    #expect(results.count == 1)
    #expect(results.first?.pageIndex == 5)
  }

  @Test("Search by color")
  @MainActor
  func searchByColor() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), color: .yellow))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), color: .red))

    let results = store.search(AnnotationSearchQuery(color: .red))
    #expect(results.count == 1)
    #expect(results.first?.color == .red)
  }

  @Test("Search excludes hidden marks by default")
  @MainActor
  func searchExcludesHidden() {
    let store = AnnotationStore()
    let mark = store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.toggleVisibility(id: mark.id) // hide it

    let results = store.search(AnnotationSearchQuery())
    #expect(results.isEmpty)

    // But visibleOnly=false includes it
    let allResults = store.search(AnnotationSearchQuery(visibleOnly: false))
    #expect(allResults.count == 1)
  }

  @Test("Search by tags")
  @MainActor
  func searchByTags() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), tags: ["important", "legal"]))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), tags: ["important"]))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), tags: []))

    let results = store.search(AnnotationSearchQuery(tags: ["legal"]))
    #expect(results.count == 1)
  }

  // MARK: - Queries

  @Test("Marks for page")
  @MainActor
  func marksForPage() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 1, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))

    #expect(store.marksForPage(0).count == 2)
    #expect(store.marksForPage(1).count == 1)
    #expect(store.marksForPage(99).count == 0)
  }

  @Test("All tags collected")
  @MainActor
  func allTags() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), tags: ["a", "b"]))
    store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), tags: ["b", "c"]))

    let tags = store.allTags
    #expect(tags.contains("a"))
    #expect(tags.contains("b"))
    #expect(tags.contains("c"))
    #expect(tags.count == 3)
  }

  @Test("Marks by type count")
  @MainActor
  func marksByType() {
    let store = AnnotationStore()
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))
    store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))

    let counts = store.marksByType
    #expect(counts[.highlight] == 2)
    #expect(counts[.note] == 1)
  }

  // MARK: - Export

  @Test("Export JSON")
  @MainActor
  func exportJSON() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), selectedText: "hello"))

    let result = store.export(format: .json)
    #expect(result.markCount == 1)
    #expect(result.suggestedFileName.contains("annotations.json"))
    #expect(result.data.count > 0)
  }

  @Test("Export markdown")
  @MainActor
  func exportMarkdown() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), selectedText: "hello"))

    let result = store.export(format: .markdown)
    #expect(result.markCount == 1)
    #expect(result.suggestedFileName.contains("annotations.md"))
    let md = String(data: result.data, encoding: .utf8) ?? ""
    #expect(md.contains("Annotations for test"))
    #expect(md.contains("hello"))
  }

  @Test("Export plain text")
  @MainActor
  func exportPlainText() {
    let store = AnnotationStore()
    store.bind(toDocumentID: "test.pdf")
    store.addMark(AnnotationMark(type: .note, pageIndex: 2, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), note: "my note"))

    let result = store.export(format: .plainText)
    #expect(result.markCount == 1)
    let text = String(data: result.data, encoding: .utf8) ?? ""
    #expect(text.contains("[Note]"))
    #expect(text.contains("Page 3"))
    #expect(text.contains("my note"))
  }

  // MARK: - Sidecar Persistence

  @Test("Sidecar file created on add")
  @MainActor
  func sidecarCreated() throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    let pdfURL = tmpDir.appendingPathComponent("test.pdf")
    try Data("dummy".utf8).write(to: pdfURL)

    let store = AnnotationStore()
    store.bind(to: pdfURL)
    store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10)))

    let sidecarURL = tmpDir.appendingPathComponent("test.pdf.annotations.json")
    #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

    // Verify content
    let data = try Data(contentsOf: sidecarURL)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let marks = try decoder.decode([AnnotationMark].self, from: data)
    #expect(marks.count == 1)

    // Cleanup
    try? FileManager.default.removeItem(at: tmpDir)
  }

  @Test("Marks persist across store instances")
  @MainActor
  func sidecarPersist() throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    let pdfURL = tmpDir.appendingPathComponent("test.pdf")
    try Data("dummy".utf8).write(to: pdfURL)

    // Write marks via store 1
    let store1 = AnnotationStore()
    store1.bind(to: pdfURL)
    store1.addMark(AnnotationMark(type: .note, pageIndex: 3, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10), note: "test note"))

    // Verify sidecar file was created
    let baseName = pdfURL.deletingPathExtension().lastPathComponent
    let sidecarURL = pdfURL.deletingLastPathComponent().appendingPathComponent("\(baseName).pdf.annotations.json")
    #expect(FileManager.default.fileExists(atPath: sidecarURL.path))

    // Load via new store instance
    let store2 = AnnotationStore()
    store2.bind(to: pdfURL)
    #expect(store2.marks.count == 1)
    #expect(store2.marks.first?.note == "test note")
    #expect(store2.marks.first?.pageIndex == 3)

    // Cleanup
    try? FileManager.default.removeItem(at: tmpDir)
  }

  // MARK: - Sendable

  @Test("AnnotationMark is Sendable")
  func markSendable() {
    let mark = AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 10, height: 10))
    Task {
      let captured = mark
      #expect(captured.type == .highlight)
    }
  }
}
