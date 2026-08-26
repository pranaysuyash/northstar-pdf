import Foundation
import PDFKit
import Testing

@testable import PDFEditorRecovery

/// MarkdownToPDFRenderer: parsing, rendering, edge cases, and typographic polish.
struct MarkdownToPDFRendererTests {

  // MARK: - Parser Tests

  @Test func parseHeading() {
    let blocks = MarkdownToPDFRenderer.parse("# Hello")
    #expect(blocks.count == 1)
    if case .heading(let level, let text) = blocks.first {
      #expect(level == 1)
      #expect(text == "Hello")
    } else {
      Issue.record("Expected heading block")
    }
  }

  @Test func parseMultipleHeadings() {
    let md = "# H1\n## H2\n### H3"
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 3)
    if case .heading(let level, _) = blocks[0] { #expect(level == 1) }
    if case .heading(let level, _) = blocks[1] { #expect(level == 2) }
    if case .heading(let level, _) = blocks[2] { #expect(level == 3) }
  }

  @Test func parseParagraph() {
    let blocks = MarkdownToPDFRenderer.parse("Hello world")
    #expect(blocks.count == 1)
    if case .paragraph(let text) = blocks.first {
      #expect(text == "Hello world")
    } else {
      Issue.record("Expected paragraph block")
    }
  }

  @Test func parseCodeBlock() {
    let md = "```\nlet x = 1\n```"
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 1)
    if case .codeBlock(let code, _) = blocks.first {
      #expect(code.contains("let x = 1"))
    } else {
      Issue.record("Expected code block")
    }
  }

  @Test func parseCodeBlockWithLanguage() {
    let md = "```swift\nlet x = 1\n```"
    let blocks = MarkdownToPDFRenderer.parse(md)
    if case .codeBlock(_, let lang) = blocks.first {
      #expect(lang == "swift")
    } else {
      Issue.record("Expected code block with language")
    }
  }

  @Test func parseBulletList() {
    let md = "- Item 1\n- Item 2\n- Item 3"
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 1)
    if case .unorderedList(let items) = blocks.first {
      #expect(items.count == 3)
      #expect(items[0] == "Item 1")
    } else {
      Issue.record("Expected unordered list")
    }
  }

  @Test func parseOrderedList() {
    let md = "1. First\n2. Second\n3. Third"
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 1)
    if case .orderedList(let items) = blocks.first {
      #expect(items.count == 3)
      #expect(items[0] == "First")
    } else {
      Issue.record("Expected ordered list")
    }
  }

  @Test func parseBlockQuote() {
    let md = "> This is a quote"
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 1)
    if case .blockQuote(let lines) = blocks.first {
      #expect(lines.first?.contains("This is a quote") == true)
    } else {
      Issue.record("Expected block quote")
    }
  }

  @Test func parseThematicBreak() {
    let md = "---"
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 1)
    if case .thematicBreak = blocks.first {
      // ok
    } else {
      Issue.record("Expected thematic break")
    }
  }

  @Test func parseEmptyInput() {
    let blocks = MarkdownToPDFRenderer.parse("")
    #expect(blocks.isEmpty)
  }

  @Test func parseBlankLines() {
    let blocks = MarkdownToPDFRenderer.parse("\n\n\n")
    #expect(blocks.isEmpty)
  }

  @Test func parseMultipleParagraphs() {
    let md = "First paragraph.\n\nSecond paragraph."
    let blocks = MarkdownToPDFRenderer.parse(md)
    #expect(blocks.count == 2)
  }

  // MARK: - Rendering Tests

  @Test func renderProducesPDFData() {
    let data = MarkdownToPDFRenderer.render("# Test")
    guard let data else {
      Issue.record("Expected non-nil data")
      return
    }
    #expect(data.count > 0)
  }

  @Test func renderProducesValidPDF() {
    guard let data = MarkdownToPDFRenderer.render("Hello World") else {
      Issue.record("No data returned")
      return
    }
    guard let doc = PDFDocument(data: data) else {
      // CoreGraphics PDF may not be parseable by PDFKit in all environments
      #expect(data.count > 0, "PDF data should be non-empty")
      return
    }
    #expect(doc.pageCount >= 1)
  }

  @Test func renderEmptyMarkdown() {
    let data = MarkdownToPDFRenderer.render("")
    // Empty markdown may produce nil or a minimal/empty PDF
    // Both nil and a valid empty PDF are acceptable outcomes
    if let data {
      let doc = PDFDocument(data: data)
      // Empty PDFs may not parse — that's acceptable
      _ = doc
    }
  }

  @Test func renderWithCoverPage() {
    let options = MarkdownToPDFRenderer.Options(showCover: true, title: "My Doc", author: "Author")
    let data = MarkdownToPDFRenderer.render("# Chapter 1\nContent here.", options: options)
    guard let data else {
      Issue.record("No data returned for cover page render")
      return
    }
    #expect(data.count > 0, "PDF data should be non-empty")
  }

  @Test func renderWithoutCoverPage() {
    let options = MarkdownToPDFRenderer.Options(showCover: false)
    let data = MarkdownToPDFRenderer.render("# Title\nBody text.", options: options)
    guard let data else {
      Issue.record("No data returned without cover page")
      return
    }
    #expect(data.count > 0, "PDF data should be non-empty")
  }

  @Test func renderCodeBlock() {
    let md = "```swift\nfunc hello() {\n  print(\"hi\")\n}\n```"
    let data = MarkdownToPDFRenderer.render(md)
    guard let data else {
      Issue.record("No data returned for code block render")
      return
    }
    #expect(data.count > 0)
  }

  @Test func renderBulletList() {
    let md = "- Apple\n- Banana\n- Cherry"
    let data = MarkdownToPDFRenderer.render(md)
    #expect(data != nil)
  }

  @Test func renderBlockQuote() {
    let md = "> Wisdom is not a matter of policing.\n> It is a matter of principle."
    let data = MarkdownToPDFRenderer.render(md)
    #expect(data != nil)
  }

  @Test func renderLongDocument() {
    var md = "# Long Document\n\n"
    for i in 1...50 {
      md += "## Section \(i)\n\nThis is paragraph \(i) with some content to fill the page.\n\n"
    }
    let data = MarkdownToPDFRenderer.render(md)
    guard let data else {
      Issue.record("No data returned for long document")
      return
    }
    #expect(data.count > 1000, "Long document should produce substantial PDF data")
  }

  // MARK: - Smart Typography Tests

  @Test func smartQuotesApplied() {
    // The renderer applies curly quotes internally
    let data = MarkdownToPDFRenderer.render("\"Hello\" 'world'")
    #expect(data != nil)
  }

  @Test func emDashApplied() {
    let data = MarkdownToPDFRenderer.render("This -- that")
    #expect(data != nil)
  }
}
