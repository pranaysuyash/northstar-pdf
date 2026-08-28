import Testing
import Foundation
@testable import PDFEditorCore

@Suite("AnnotationCreation")
struct AnnotationCreationTests {
  @Test("AnnotationMark creation with all fields")
  func markCreation() {
    let mark = AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 20, width: 100, height: 12),
      selectedText: "Important text",
      note: "Remember this",
      color: .yellow
    )
    #expect(mark.type == .highlight)
    #expect(mark.pageIndex == 0)
    #expect(mark.selectedText == "Important text")
    #expect(mark.note == "Remember this")
    #expect(mark.color == .yellow)
    #expect(mark.isVisible == true)
  }

  @Test("AnnotationStore add and query marks")
  func storeAddQuery() async {
    let store = await AnnotationStore()
    await store.bind(toDocumentID: "test.pdf")

    let mark1 = AnnotationMark(
      type: .highlight,
      pageIndex: 0,
      bounds: PDFRect(x: 10, y: 20, width: 100, height: 12),
      selectedText: "First"
    )
    let mark2 = AnnotationMark(
      type: .note,
      pageIndex: 1,
      bounds: PDFRect(x: 50, y: 60, width: 80, height: 10),
      selectedText: "Second",
      note: "A note"
    )

    await store.addMark(mark1)
    await store.addMark(mark2)

    let allMarks = await store.marks
    #expect(allMarks.count == 2)
  }

  @Test("AnnotationType has correct symbols")
  func typeSymbols() {
    #expect(AnnotationType.highlight.symbolName == "highlighter")
    #expect(AnnotationType.underline.symbolName == "underline")
    #expect(AnnotationType.note.symbolName == "note.text")
    #expect(AnnotationType.strikethrough.symbolName == "strikethrough")
    #expect(AnnotationType.freehand.symbolName == "pencil.line")
  }

  @Test("AnnotationColor has hex values")
  func colorHex() {
    #expect(AnnotationColor.yellow.hexColor == "#FFEB3B")
    #expect(AnnotationColor.blue.hexColor == "#2196F3")
  }

  @Test("AnnotationMark Codable round-trip")
  func markCodable() throws {
    let mark = AnnotationMark(
      type: .underline,
      pageIndex: 2,
      bounds: PDFRect(x: 0, y: 0, width: 200, height: 14),
      selectedText: "Underlined text",
      note: "Important",
      color: .blue
    )
    let data = try JSONEncoder().encode(mark)
    let decoded = try JSONDecoder().decode(AnnotationMark.self, from: data)
    #expect(decoded.type == .underline)
    #expect(decoded.selectedText == "Underlined text")
    #expect(decoded.color == .blue)
  }

  @Test("AnnotationStore search by type")
  func storeSearchType() async {
    let store = await AnnotationStore()
    await store.bind(toDocumentID: "search-test.pdf")

    await store.addMark(AnnotationMark(type: .highlight, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 50, height: 10)))
    await store.addMark(AnnotationMark(type: .note, pageIndex: 0, bounds: PDFRect(x: 0, y: 0, width: 50, height: 10)))
    await store.addMark(AnnotationMark(type: .highlight, pageIndex: 1, bounds: PDFRect(x: 0, y: 0, width: 50, height: 10)))

    let highlights = await store.marks.filter { $0.type == .highlight }
    #expect(highlights.count == 2)
  }
}
