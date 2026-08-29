import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - CREATE Phase Tests

@Suite("Creator — CREATE Phase")
struct CreatorCreateTests {

  @Test("ContentAuthor adds text element")
  @MainActor
  func addText() {
    let author = ContentAuthor()
    let el = author.addText(content: "Hello", at: CGPoint(x: 72, y: 700))
    #expect(author.elements.count == 1)
    if case .text(let props) = el.kind {
      #expect(props.content == "Hello")
    }
  }

  @Test("ContentAuthor adds shape element")
  @MainActor
  func addShape() {
    let author = ContentAuthor()
    let el = author.addShape(type: .rectangle, frame: PDFRect(x: 0, y: 0, width: 100, height: 50), fillColor: "ff0000")
    #expect(author.elements.count == 1)
  }

  @Test("ContentAuthor undo/redo")
  @MainActor
  func undoRedo() {
    let author = ContentAuthor()
    author.addText(content: "First", at: .zero)
    author.addText(content: "Second", at: .zero)
    #expect(author.elements.count == 2)

    author.undo()
    #expect(author.elements.count == 1)

    author.redo()
    #expect(author.elements.count == 2)
  }

  @Test("ContentAuthor multi-page support")
  @MainActor
  func multiPage() {
    let author = ContentAuthor()
    author.addText(content: "Page 1", at: .zero)
    author.addPage()
    author.addText(content: "Page 2", at: .zero, pageIndex: 1)
    #expect(author.pageCount == 2)
    #expect(author.elementsOnPage(0).count == 1)
    #expect(author.elementsOnPage(1).count == 1)
  }

  @Test("ContentAuthor updateElement changes kind")
  @MainActor
  func updateElement() {
    let author = ContentAuthor()
    let el = author.addText(content: "Original", at: .zero)
    author.updateElement(id: el.id, kind: .text(TextProperties(content: "Updated", fontName: "Courier", fontSize: 12, color: "ff0000")))
    let updated = author.elements.first!
    if case .text(let props) = updated.kind {
      #expect(props.content == "Updated")
      #expect(props.fontName == "Courier")
    }
  }

  @Test("ContentAuthor renderToPDF produces valid PDF")
  @MainActor
  func renderToPDF() {
    let author = ContentAuthor()
    author.addText(content: "Test document", at: CGPoint(x: 72, y: 700))
    author.addShape(type: .rectangle, frame: PDFRect(x: 72, y: 600, width: 200, height: 100))

    let pdf = author.renderToPDF()
    #expect(pdf != nil)
    #expect(pdf?.pageCount == 1)
  }

  @Test("ContentAuthor element z-index ordering")
  @MainActor
  func zIndexOrdering() {
    let author = ContentAuthor()
    let e1 = author.addText(content: "Bottom", at: .zero)
    let e2 = author.addText(content: "Top", at: .zero)
    #expect(e1.zIndex < e2.zIndex)
  }
}

// MARK: - DESIGN Phase Tests

@Suite("Creator — DESIGN Phase")
struct CreatorDesignTests {

  @Test("Grid snapping rounds to grid")
  func gridSnap() {
    let grid = GridConfig(spacing: 36, isSnapping: true)
    let snapped = grid.snap(CGPoint(x: 100, y: 200))
    // 100/36 = 2.78, rounds to 3, so 3*36 = 108
    // 200/36 = 5.56, rounds to 6, so 6*36 = 216
    #expect(snapped.x == 108)
    #expect(snapped.y == 216)
  }

  @Test("Grid snapping disabled passes through")
  func gridDisabled() {
    let grid = GridConfig(isSnapping: false)
    let point = grid.snap(CGPoint(x: 100, y: 200))
    #expect(point.x == 100)
    #expect(point.y == 200)
  }

  @Test("Grid rect snapping")
  func gridRectSnap() {
    let grid = GridConfig(spacing: 36, isSnapping: true)
    let rect = grid.snap(PDFRect(x: 10, y: 20, width: 100, height: 50))
    // 10/36 = 0.28, rounds to 0, so 0*36 = 0
    // 20/36 = 0.56, rounds to 1, so 1*36 = 36
    #expect(rect.x == 0)
    #expect(rect.y == 36)
  }

  @Test("Page layout content area")
  func layoutContentArea() {
    let layout = PageLayout.letter
    let area = layout.contentArea
    #expect(area.x == 72)
    #expect(area.y == 72)
    #expect(area.width == 612 - 144) // 612 - 72 - 72
    #expect(area.height == 792 - 144)
  }

  @Test("Page layout predefined set")
  func layoutSet() {
    #expect(PageLayout.allLayouts.count >= 5)
    #expect(PageLayout.allLayouts.contains { $0.name == "Blank" })
    #expect(PageLayout.allLayouts.contains { $0.name == "Letter" })
    #expect(PageLayout.allLayouts.contains { $0.name == "A4" })
  }

  @Test("Paragraph style predefined set")
  func paragraphStyles() {
    #expect(ParagraphStyle.allStyles.count >= 6)
    #expect(ParagraphStyle.body.fontSize == 12)
    #expect(ParagraphStyle.heading1.fontSize == 24)
  }

  @Test("Character style predefined set")
  func characterStyles() {
    #expect(CharacterStyle.allStyles.count >= 4)
    #expect(CharacterStyle.bold.isBold)
    #expect(CharacterStyle.italic.isItalic)
  }

  @Test("Page margins defaults")
  func marginsDefaults() {
    let margins = PageMargins()
    #expect(margins.top == 72)
    #expect(margins.bottom == 72)
    #expect(margins.left == 72)
    #expect(margins.right == 72)
  }

  @Test("Master element types")
  func masterElementTypes() {
    let header = MasterElement(kind: .pageNumber, position: .topRight)
    let footer = MasterElement(kind: .text("Confidential"), position: .bottomCenter)
    let date = MasterElement(kind: .date, position: .bottomRight)

    if case .pageNumber = header.kind {} else { Issue.record("Expected pageNumber") }
    if case .text(let text) = footer.kind {
      #expect(text == "Confidential")
    } else { Issue.record("Expected text") }
    if case .date = date.kind {} else { Issue.record("Expected date") }
  }
}

// MARK: - PUBLISH Phase Tests

@Suite("Creator — PUBLISH Phase")
struct CreatorPublishTests {

  @Test("Publish pipeline default options")
  func defaultOptions() {
    let options = PublishOptions()
    #expect(options.optimizeFileSize == false)
    #expect(options.stripMetadata == false)
    #expect(options.imageQuality == 0.85)
    #expect(options.addPageNumbers == false)
  }

  @Test("Publish to clipboard succeeds")
  @MainActor
  func publishToClipboard() {
    let pipeline = PublishPipeline()
    let pdfData = Data("PDF-1.4 test".utf8)

    let result = pipeline.publish(
      document: pdfData,
      sourceName: "test.pdf",
      destination: .clipboard
    )

    #expect(result.success)
    #expect(result.fileSizeBytes == pdfData.count)
  }

  @Test("Publish to file succeeds")
  @MainActor
  func publishToFile() {
    let pipeline = PublishPipeline()
    let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("test-publish-\(UUID().uuidString).pdf")
    let pdfData = Data("PDF-1.4 test content".utf8)

    let result = pipeline.publish(
      document: pdfData,
      sourceName: "test.pdf",
      destination: .file(url: tmpURL)
    )

    #expect(result.success)
    // Clean up
    try? FileManager.default.removeItem(at: tmpURL)
  }

  @Test("Publish history is recorded")
  @MainActor
  func publishHistory() {
    let pipeline = PublishPipeline()
    let pdfData = Data("test".utf8)

    _ = pipeline.publish(
      document: pdfData,
      sourceName: "test.pdf",
        destination: .clipboard
    )
    _ = pipeline.publish(
      document: pdfData,
      sourceName: "test2.pdf",
        destination: .clipboard
    )

    #expect(pipeline.history.count == 2)
    #expect(pipeline.history.first?.sourceDocumentName == "test2.pdf")
  }

  @Test("Publish result file size formatted")
  func fileSizeFormatted() {
    let result = PublishResult(
        success: true,
        destination: .clipboard,
        fileSizeBytes: 1024
    )
    #expect(result.fileSizeFormatted.contains("KB"))
  }

  @Test("Publish options Codable round-trip")
  func optionsCodable() throws {
    let options = PublishOptions(
        optimizeFileSize: true,
        targetFileSize: 1_000_000,
        stripMetadata: true,
        flattenAnnotations: true,
        imageQuality: 0.5,
        addPageNumbers: true,
        pageNumberFormat: .bottomRight
    )

    let data = try JSONEncoder().encode(options)
    let decoded = try JSONDecoder().decode(PublishOptions.self, from: data)

    #expect(decoded.optimizeFileSize == true)
    #expect(decoded.targetFileSize == 1_000_000)
    #expect(decoded.stripMetadata == true)
    #expect(decoded.imageQuality == 0.5)
    #expect(decoded.pageNumberFormat == .bottomRight)
  }

  @Test("Publish destination Codable")
  func destinationCodable() throws {
    let dest = PublishDestination.file(url: URL(fileURLWithPath: "/tmp/test.pdf"))
    let data = try JSONEncoder().encode(dest)
    let decoded = try JSONDecoder().decode(PublishDestination.self, from: data)

    if case .file(let url) = decoded {
      #expect(url.path == "/tmp/test.pdf")
    } else {
      Issue.record("Expected file destination")
    }
  }
}
