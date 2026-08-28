import Testing
import Foundation
@testable import PDFEditorCore

@Suite("ContentAuthor")
struct ContentAuthorTests {

  // MARK: - Add Elements

  @Test("Add text element")
  @MainActor
  func addText() {
    let author = ContentAuthor()
    let el = author.addText(content: "Hello World", at: CGPoint(x: 72, y: 700))
    #expect(author.elements.count == 1)
    #expect(el.pageIndex == 0)
    if case .text(let props) = el.kind {
      #expect(props.content == "Hello World")
    } else {
      Issue.record("Expected text element")
    }
  }

  @Test("Add shape element")
  @MainActor
  func addShape() {
    let author = ContentAuthor()
    let el = author.addShape(
      type: .rectangle,
      frame: PDFRect(x: 72, y: 600, width: 200, height: 100),
      fillColor: "ff0000"
    )
    #expect(author.elements.count == 1)
    if case .shape(let props) = el.kind {
      #expect(props.shapeType == .rectangle)
      #expect(props.fillColor == "ff0000")
    } else {
      Issue.record("Expected shape element")
    }
  }

  @Test("Elements get ascending z-index")
  @MainActor
  func zIndexAscending() {
    let author = ContentAuthor()
    let e1 = author.addText(content: "First", at: .zero)
    let e2 = author.addText(content: "Second", at: .zero)
    let e3 = author.addText(content: "Third", at: .zero)
    #expect(e1.zIndex == 1)
    #expect(e2.zIndex == 2)
    #expect(e3.zIndex == 3)
  }

  // MARK: - Move & Resize

  @Test("Move element updates frame")
  @MainActor
  func moveElement() {
    let author = ContentAuthor()
    let el = author.addText(content: "Move me", at: CGPoint(x: 10, y: 10))
    author.moveElement(id: el.id, to: PDFRect(x: 100, y: 200, width: 150, height: 30))
    #expect(author.elements.first?.frame.x == 100)
    #expect(author.elements.first?.frame.y == 200)
  }

  @Test("Resize element updates dimensions")
  @MainActor
  func resizeElement() {
    let author = ContentAuthor()
    let el = author.addShape(type: .rectangle, frame: PDFRect(x: 0, y: 0, width: 50, height: 50))
    author.resizeElement(id: el.id, to: PDFRect(x: 0, y: 0, width: 200, height: 100))
    #expect(author.elements.first?.frame.width == 200)
    #expect(author.elements.first?.frame.height == 100)
  }

  // MARK: - Delete

  @Test("Delete element removes it")
  @MainActor
  func deleteElement() {
    let author = ContentAuthor()
    let el = author.addText(content: "Delete me", at: .zero)
    #expect(author.elements.count == 1)
    author.deleteElement(id: el.id)
    #expect(author.elements.count == 0)
  }

  @Test("Delete clears selection")
  @MainActor
  func deleteClearsSelection() {
    let author = ContentAuthor()
    let el = author.addText(content: "Selected", at: .zero)
    author.selectElement(id: el.id)
    author.deleteElement(id: el.id)
    #expect(author.selectedElementID == nil)
  }

  // MARK: - Duplicate

  @Test("Duplicate creates copy offset from original")
  @MainActor
  func duplicate() {
    let author = ContentAuthor()
    let el = author.addText(content: "Original", at: CGPoint(x: 100, y: 100))
    let dup = author.duplicateElement(id: el.id)
    #expect(author.elements.count == 2)
    #expect(dup?.frame.x == 120) // offset by 20
    #expect(dup?.frame.y == 80)  // offset by -20
    if case .text(let props) = dup?.kind {
      #expect(props.content == "Original")
    }
  }

  // MARK: - Update Text

  @Test("Update text content")
  @MainActor
  func updateText() {
    let author = ContentAuthor()
    let el = author.addText(content: "Old text", at: .zero)
    author.updateText(id: el.id, content: "New text")
    if case .text(let props) = author.elements.first?.kind {
      #expect(props.content == "New text")
    }
  }

  // MARK: - Undo/Redo

  @Test("Undo restores previous state")
  @MainActor
  func undo() {
    let author = ContentAuthor()
    author.addText(content: "A", at: .zero)
    author.addText(content: "B", at: .zero)
    #expect(author.elements.count == 2)
    author.undo()
    #expect(author.elements.count == 1)
    author.undo()
    #expect(author.elements.count == 0)
  }

  @Test("Redo restores undone state")
  @MainActor
  func redo() {
    let author = ContentAuthor()
    author.addText(content: "A", at: .zero)
    author.undo()
    #expect(author.elements.count == 0)
    author.redo()
    #expect(author.elements.count == 1)
  }

  @Test("New action clears redo stack")
  @MainActor
  func redoClearedOnNewAction() {
    let author = ContentAuthor()
    author.addText(content: "A", at: .zero)
    author.undo()
    #expect(author.canRedo == true)
    author.addText(content: "B", at: .zero)
    #expect(author.canRedo == false)
  }

  // MARK: - Page Management

  @Test("Add page increments count")
  @MainActor
  func addPage() {
    let author = ContentAuthor()
    #expect(author.pageCount == 1)
    author.addPage()
    #expect(author.pageCount == 2)
  }

  @Test("Delete page removes elements and decrements count")
  @MainActor
  func deletePage() {
    let author = ContentAuthor()
    author.addPage()
    author.addText(content: "Page 2", at: .zero, pageIndex: 1)
    author.deletePage(at: 1)
    #expect(author.pageCount == 1)
    #expect(author.elementsOnPage(1).isEmpty)
  }

  @Test("Add page shifts elements")
  @MainActor
  func addPageShiftsElements() {
    let author = ContentAuthor()
    author.addText(content: "On page 1", at: .zero, pageIndex: 0)
    author.addPage(at: 0) // Insert before page 0
    #expect(author.elementsOnPage(0).isEmpty)
    #expect(author.elementsOnPage(1).count == 1)
  }

  // MARK: - Query

  @Test("Elements on page returns correct subset")
  @MainActor
  func elementsOnPage() {
    let author = ContentAuthor()
    author.addPage()
    author.addText(content: "P1", at: .zero, pageIndex: 0)
    author.addText(content: "P2", at: .zero, pageIndex: 1)
    author.addText(content: "P1b", at: .zero, pageIndex: 0)
    #expect(author.elementsOnPage(0).count == 2)
    #expect(author.elementsOnPage(1).count == 1)
  }

  @Test("Elements sorted by z-index on page")
  @MainActor
  func sortedByZIndex() {
    let author = ContentAuthor()
    let e1 = author.addText(content: "First", at: .zero)
    let e3 = author.addText(content: "Third", at: .zero)
    let e2 = author.addText(content: "Second", at: .zero)
    let sorted = author.elementsOnPage(0)
    #expect(sorted.map(\.id) == [e1.id, e3.id, e2.id])
  }

  // MARK: - Templates

  @Test("Apply blank template adds no elements")
  @MainActor
  func blankTemplate() {
    let author = ContentAuthor()
    author.applyTemplate(.blank, toPage: 0)
    #expect(author.elements.count == 0)
  }

  @Test("Apply letterhead template adds elements")
  @MainActor
  func letterheadTemplate() {
    let author = ContentAuthor()
    author.applyTemplate(.letterhead, toPage: 0)
    #expect(author.elements.count >= 2)
  }

  @Test("Apply cover page template adds elements")
  @MainActor
  func coverPageTemplate() {
    let author = ContentAuthor()
    author.applyTemplate(.coverPage, toPage: 0)
    #expect(author.elements.count >= 3)
  }

  // MARK: - PDF Rendering

  @Test("Render to PDF produces valid document")
  @MainActor
  func renderToPDF() {
    let author = ContentAuthor()
    author.addText(content: "Hello PDF", at: CGPoint(x: 72, y: 700))
    author.addShape(type: .rectangle, frame: PDFRect(x: 72, y: 500, width: 200, height: 100), fillColor: "ff0000")
    let doc = author.renderToPDF()
    #expect(doc != nil)
    #expect(doc?.pageCount == 1)
  }

  @Test("Render multi-page document")
  @MainActor
  func renderMultiPage() {
    let author = ContentAuthor()
    author.addPage()
    author.addText(content: "Page 1", at: .zero, pageIndex: 0)
    author.addText(content: "Page 2", at: .zero, pageIndex: 1)
    let doc = author.renderToPDF()
    #expect(doc?.pageCount == 2)
  }

  // MARK: - Selection

  @Test("Select and deselect element")
  @MainActor
  func selection() {
    let author = ContentAuthor()
    let el = author.addText(content: "Select me", at: .zero)
    author.selectElement(id: el.id)
    #expect(author.selectedElement?.id == el.id)
    author.selectElement(id: nil)
    #expect(author.selectedElement == nil)
  }
}
