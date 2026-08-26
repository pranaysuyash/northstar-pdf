import CoreGraphics
import CoreText
import Foundation
import PDFKit

/// Renders Markdown into a publication-quality PDF using Core Text.
///
/// Built-in parser handles: headings (H1–H6), bold, italic, inline code,
/// fenced code blocks, bullet lists, numbered lists, block quotes,
/// horizontal rules, links, and soft/hard line breaks.
/// H1 triggers a page break. Optional cover page and page numbers.
public struct MarkdownToPDFRenderer {

  // MARK: - Public API

  public struct Options {
    public var pageSize: CGSize
    public var margins: CGFloat
    public var showCover: Bool
    public var title: String?
    public var author: String?
    public var date: String?

    public init(
      pageSize: CGSize = .init(width: 612, height: 792),
      margins: CGFloat = 72,
      showCover: Bool = true,
      title: String? = nil,
      author: String? = nil,
      date: String? = nil
    ) {
      self.pageSize = pageSize
      self.margins = margins
      self.showCover = showCover
      self.title = title
      self.author = author
      self.date = date
    }
  }

  /// Renders the given markdown string to PDF data.
  public static func render(_ markdown: String, options: Options = .init()) -> Data? {
    let blocks = parse(markdown)
    var renderer = Renderer(options: options)
    return renderer.render(blocks)
  }

  // MARK: - Lightweight Markdown Parser

  public enum Block: Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(code: String, language: String?)
    case unorderedList(items: [String])
    case orderedList(items: [String])
    case blockQuote(lines: [String])
    case thematicBreak
  }

  public static func parse(_ markdown: String) -> [Block] {
    var blocks: [Block] = []
    let lines = markdown.components(separatedBy: .newlines)
    var i = 0

    while i < lines.count {
      let line = lines[i]

      // Fenced code block
      if line.hasPrefix("```") {
        let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var code: [String] = []
        i += 1
        while i < lines.count && !lines[i].hasPrefix("```") {
          code.append(lines[i])
          i += 1
        }
        i += 1  // skip closing ```
        blocks.append(.codeBlock(code: code.joined(separator: "\n"), language: lang.isEmpty ? nil : lang))
        continue
      }

      // Thematic break
      if line.range(of: #"^(\*{3,}|-{3,}|_{3,})\s*$"#, options: .regularExpression) != nil {
        blocks.append(.thematicBreak)
        i += 1
        continue
      }

      // Heading
      if let headingMatch = line.range(of: #"^(#{1,6})\s+(.+)$"#, options: .regularExpression) {
        let level = line.prefix(while: { $0 == "#" }).count
        let text = String(line.drop(while: { $0 == "#" }).drop(while: { $0 == " " })).trimmingCharacters(in: .whitespaces)
        blocks.append(.heading(level: level, text: text))
        i += 1
        continue
      }

      // Block quote
      if line.hasPrefix(">") {
        var quoteLines: [String] = []
        while i < lines.count && (lines[i].hasPrefix(">") || (!lines[i].trimmingCharacters(in: .whitespaces).isEmpty && !lines[i].hasPrefix("#") && !lines[i].hasPrefix("```"))) {
          let content = lines[i].hasPrefix(">") ? String(lines[i].dropFirst(1)).trimmingCharacters(in: .whitespaces) : lines[i]
          quoteLines.append(content)
          i += 1
          if i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).isEmpty { break }
        }
        blocks.append(.blockQuote(lines: quoteLines))
        continue
      }

      // Unordered list
      if line.range(of: #"^[\s]*[-*+]\s+"#, options: .regularExpression) != nil {
        var items: [String] = []
        while i < lines.count, lines[i].range(of: #"^[\s]*[-*+]\s+"#, options: .regularExpression) != nil {
          let itemText = lines[i].replacingOccurrences(of: #"^[\s]*[-*+]\s+"#, with: "", options: .regularExpression)
          items.append(itemText)
          i += 1
        }
        blocks.append(.unorderedList(items: items))
        continue
      }

      // Ordered list
      if line.range(of: #"^[\s]*\d+[.)]\s+"#, options: .regularExpression) != nil {
        var items: [String] = []
        while i < lines.count, lines[i].range(of: #"^[\s]*\d+[.)]\s+"#, options: .regularExpression) != nil {
          let itemText = lines[i].replacingOccurrences(of: #"^[\s]*\d+[.)]\s+"#, with: "", options: .regularExpression)
          items.append(itemText)
          i += 1
        }
        blocks.append(.orderedList(items: items))
        continue
      }

      // Blank line — skip
      if line.trimmingCharacters(in: .whitespaces).isEmpty {
        i += 1
        continue
      }

      // Paragraph — collect consecutive non-blank, non-special lines
      var paraLines: [String] = []
      while i < lines.count {
        let l = lines[i]
        if l.trimmingCharacters(in: .whitespaces).isEmpty { break }
        if l.hasPrefix("#") || l.hasPrefix("```") || l.hasPrefix(">") { break }
        if l.range(of: #"^[\s]*[-*+]\s+"#, options: .regularExpression) != nil { break }
        if l.range(of: #"^[\s]*\d+[.)]\s+"#, options: .regularExpression) != nil { break }
        if l.range(of: #"^(\*{3,}|-{3,}|_{3,})\s*$"#, options: .regularExpression) != nil { break }
        paraLines.append(l)
        i += 1
      }
      if !paraLines.isEmpty {
        blocks.append(.paragraph(text: paraLines.joined(separator: " ")))
      }
    }

    return blocks
  }

  // MARK: - Inline Parsing

  public enum Inline: Sendable {
    case text(String)
    case bold(String)
    case italic(String)
    case boldItalic(String)
    case code(String)
    case link(text: String, destination: String)
  }

  /// Parses inline markdown (bold, italic, code, links) into Inline tokens.
  public static func parseInline(_ text: String) -> [Inline] {
    var result: [Inline] = []
    var remaining = text[...]

    while !remaining.isEmpty {
      // Bold+Italic ***text*** or ___text___
      if remaining.hasPrefix("***") || remaining.hasPrefix("___") {
        let marker = remaining.hasPrefix("***") ? "***" : "___"
        remaining = remaining.dropFirst(marker.count)
        if let end = remaining.range(of: marker) {
          result.append(.boldItalic(String(remaining[..<end.lowerBound])))
          remaining = remaining[end.upperBound...]
          continue
        }
      }

      // Bold **text** or __text__
      if remaining.hasPrefix("**") || remaining.hasPrefix("__") {
        let marker = remaining.hasPrefix("**") ? "**" : "__"
        remaining = remaining.dropFirst(marker.count)
        if let end = remaining.range(of: marker) {
          result.append(.bold(String(remaining[..<end.lowerBound])))
          remaining = remaining[end.upperBound...]
          continue
        }
      }

      // Italic *text* or _text_
      if remaining.hasPrefix("*") || remaining.hasPrefix("_") {
        let marker = String(remaining.first!)
        remaining = remaining.dropFirst()
        if let end = remaining.firstIndex(of: Character(marker)) {
          result.append(.italic(String(remaining[..<end])))
          remaining = remaining[remaining.index(after: end)...]
          continue
        }
      }

      // Inline code `text`
      if remaining.hasPrefix("`") {
        remaining = remaining.dropFirst()
        if let end = remaining.firstIndex(of: "`") {
          result.append(.code(String(remaining[..<end])))
          remaining = remaining[remaining.index(after: end)...]
          continue
        }
      }

      // Link [text](url)
      if remaining.hasPrefix("[") {
        remaining = remaining.dropFirst()
        if let closeBracket = remaining.firstIndex(of: "]"),
          remaining[remaining.startIndex...closeBracket].dropFirst().hasPrefix("(")
        {
          let linkText = String(remaining[..<closeBracket])
          remaining = remaining[remaining.index(after: closeBracket)...]  // skip ]
          remaining = remaining.dropFirst()  // skip (
          if let closeParen = remaining.firstIndex(of: ")") {
            let url = String(remaining[..<closeParen])
            result.append(.link(text: linkText, destination: url))
            remaining = remaining[remaining.index(after: closeParen)...]
            continue
          }
        }
      }

      // Plain text — consume until next special character
      var j = remaining.startIndex
      while j < remaining.endIndex {
        let ch = remaining[j]
        if ch == "*" || ch == "_" || ch == "`" || ch == "[" { break }
        j = remaining.index(after: j)
      }
      if j > remaining.startIndex {
        result.append(.text(String(remaining[..<j])))
        remaining = remaining[j...]
      } else {
        // Safety: consume one character to avoid infinite loop
        result.append(.text(String(remaining.first!)))
        remaining = remaining.dropFirst()
      }
    }

    return result
  }

  // MARK: - Internal Renderer

  private struct Renderer {
    let options: Options
    let contentRect: CGRect
    var pdfData = NSMutableData()
    var consumer: CGDataConsumer?
    var context: CGContext?
    var pageNumber = 0

    init(options: Options) {
      self.options = options
      let m = options.margins
      contentRect = CGRect(
        x: m, y: m,
        width: max(1, options.pageSize.width - m * 2),
        height: max(1, options.pageSize.height - m * 2))
    }

    mutating func render(_ blocks: [Block]) -> Data? {
      var mediaBox = CGRect(origin: .zero, size: options.pageSize)
      consumer = CGDataConsumer(data: pdfData)
      guard let consumer,
        let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
      else { return nil }
      context = ctx

      if options.showCover { drawCoverPage() }

      var state = RenderState()
      for block in blocks {
        renderBlock(block, state: &state)
      }
      finishPage()
      ctx.closePDF()
      return pdfData as Data?
    }

    // MARK: - Cover page

    private mutating func drawCoverPage() {
      guard let ctx = context else { return }
      ctx.beginPDFPage(nil)

      let pageW = options.pageSize.width
      let pageH = options.pageSize.height
      let titleText = options.title ?? "Document"

      // Title
      let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 32, nil)
      let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: titleFont, .foregroundColor: NSColor.labelColor.cgColor,
      ]
      let titleStr = NSAttributedString(string: Self.smartQuotes(titleText), attributes: titleAttrs)
      let titleSetter = CTFramesetterCreateWithAttributedString(titleStr)
      let titleRect = CGRect(x: 72, y: pageH * 0.55, width: pageW - 144, height: 120)
      let titleFrame = CTFramesetterCreateFrame(
        titleSetter, CFRange(), CGPath(rect: titleRect, transform: nil), nil)
      CTFrameDraw(titleFrame, ctx)

      // Hairline
      ctx.setStrokeColor(NSColor.separatorColor.cgColor)
      ctx.setLineWidth(0.5)
      ctx.move(to: CGPoint(x: 72, y: pageH * 0.54))
      ctx.addLine(to: CGPoint(x: pageW - 72, y: pageH * 0.54))
      ctx.strokePath()

      // Author
      if let author = options.author, !author.isEmpty {
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        let attrs: [NSAttributedString.Key: Any] = [
          .font: font, .foregroundColor: NSColor.secondaryLabelColor.cgColor,
        ]
        let str = NSAttributedString(string: author, attributes: attrs)
        let setter = CTFramesetterCreateWithAttributedString(str)
        let rect = CGRect(x: 72, y: pageH * 0.50, width: pageW - 144, height: 30)
        let frame = CTFramesetterCreateFrame(
          setter, CFRange(), CGPath(rect: rect, transform: nil), nil)
        CTFrameDraw(frame, ctx)
      }

      // Date
      let dateText = options.date ?? Self.formattedDate()
      let dateFont = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
      let dateAttrs: [NSAttributedString.Key: Any] = [
        .font: dateFont, .foregroundColor: NSColor.tertiaryLabelColor.cgColor,
      ]
      let dateStr = NSAttributedString(string: dateText, attributes: dateAttrs)
      let dateSetter = CTFramesetterCreateWithAttributedString(dateStr)
      let dateRect = CGRect(x: 72, y: pageH * 0.47, width: pageW - 144, height: 24)
      let dateFrame = CTFramesetterCreateFrame(
        dateSetter, CFRange(), CGPath(rect: dateRect, transform: nil), nil)
      CTFrameDraw(dateFrame, ctx)

      finishPage()
    }

    // MARK: - Block rendering

    private mutating func renderBlock(_ block: Block, state: inout RenderState) {
      switch block {
      case .heading(let level, let text):
        renderHeading(level: level, text: text, state: &state)
      case .paragraph(let text):
        renderParagraph(text, state: &state)
      case .codeBlock(let code, _):
        renderCodeBlock(code, state: &state)
      case .unorderedList(let items):
        for item in items { renderListItem(item, bullet: "•  ", state: &state) }
      case .orderedList(let items):
        for (idx, item) in items.enumerated() { renderListItem(item, bullet: "\(idx + 1).  ", state: &state) }
      case .blockQuote(let lines):
        renderBlockQuote(lines, state: &state)
      case .thematicBreak:
        renderHorizontalRule(state: &state)
      }
    }

    // MARK: - Heading

    private mutating func renderHeading(level: Int, text: String, state: inout RenderState) {
      if level == 1 && state.hasContent { finishPage(); beginNewPage(); state.yOffset = 0 }
      ensurePage(state: &state)

      let fontSize: CGFloat
      let fontName: String
      let spacingBefore: CGFloat
      let spacingAfter: CGFloat
      switch level {
      case 1: fontSize = 28; fontName = "Helvetica-Bold"; spacingBefore = 0; spacingAfter = 18
      case 2: fontSize = 22; fontName = "Helvetica-Bold"; spacingBefore = 24; spacingAfter = 12
      case 3: fontSize = 18; fontName = "Helvetica-Bold"; spacingBefore = 18; spacingAfter = 8
      case 4: fontSize = 15; fontName = "Helvetica-Bold"; spacingBefore = 14; spacingAfter = 6
      default: fontSize = 13; fontName = "Helvetica-Bold"; spacingBefore = 10; spacingAfter = 4
      }

      let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
      let color = level <= 2 ? NSColor.labelColor.cgColor : NSColor.secondaryLabelColor.cgColor
      let paraStyle = NSMutableParagraphStyle()
      paraStyle.paragraphSpacingBefore = spacingBefore
      paraStyle.paragraphSpacing = spacingAfter
      paraStyle.lineBreakMode = .byWordWrapping

      let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: paraStyle,
      ]
      let attrStr = NSAttributedString(string: Self.smartQuotes(text), attributes: attrs)
      draw(attrStr, state: &state)
      state.hasContent = true
    }

    // MARK: - Paragraph

    private mutating func renderParagraph(_ text: String, state: inout RenderState) {
      ensurePage(state: &state)
      let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
      let paraStyle = NSMutableParagraphStyle()
      paraStyle.lineBreakMode = .byWordWrapping
      paraStyle.paragraphSpacing = 8

      let baseAttrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.labelColor.cgColor, .paragraphStyle: paraStyle,
      ]
      let attrStr = buildInlineAttributedString(text, baseAttributes: baseAttrs)
      draw(attrStr, state: &state)
      state.hasContent = true
    }

    // MARK: - Code block

    private mutating func renderCodeBlock(_ code: String, state: inout RenderState) {
      ensurePage(state: &state)
      let font = CTFontCreateWithName("Menlo" as CFString, 9, nil)
      let paraStyle = NSMutableParagraphStyle()
      paraStyle.lineBreakMode = .byCharWrapping
      paraStyle.lineSpacing = 2

      let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.labelColor.cgColor, .paragraphStyle: paraStyle,
      ]
      let attrStr = NSAttributedString(string: code, attributes: attrs)
      drawCodeBlock(attrStr, state: &state)
      state.hasContent = true
    }

    // MARK: - List item

    private mutating func renderListItem(_ text: String, bullet: String, state: inout RenderState) {
      ensurePage(state: &state)
      let font = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
      let bulletFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)

      let bulletAttrs: [NSAttributedString.Key: Any] = [
        .font: bulletFont, .foregroundColor: NSColor.secondaryLabelColor.cgColor,
      ]
      let bodyAttrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.labelColor.cgColor,
      ]

      let combined = NSMutableAttributedString()
      combined.append(NSAttributedString(string: "    ", attributes: bulletAttrs))
      combined.append(NSAttributedString(string: bullet, attributes: bulletAttrs))
      combined.append(buildInlineAttributedString(text, baseAttributes: bodyAttrs))

      draw(combined, state: &state)
      state.hasContent = true
    }

    // MARK: - Block quote

    private mutating func renderBlockQuote(_ lines: [String], state: inout RenderState) {
      ensurePage(state: &state)
      let font = CTFontCreateWithName("Helvetica-Oblique" as CFString, 11, nil)
      let paraStyle = NSMutableParagraphStyle()
      paraStyle.lineBreakMode = .byWordWrapping
      paraStyle.paragraphSpacing = 8
      paraStyle.headIndent = 12

      let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.secondaryLabelColor.cgColor, .paragraphStyle: paraStyle,
      ]

      for line in lines {
        let attrStr = buildInlineAttributedString(line, baseAttributes: attrs)
        draw(attrStr, state: &state)
      }
      state.hasContent = true
    }

    // MARK: - Horizontal rule

    private mutating func renderHorizontalRule(state: inout RenderState) {
      ensurePage(state: &state)
      guard let ctx = context else { return }
      state.yOffset += 12
      let y = contentRect.maxY - state.yOffset
      ctx.setStrokeColor(NSColor.separatorColor.cgColor)
      ctx.setLineWidth(0.5)
      ctx.move(to: CGPoint(x: contentRect.minX, y: y))
      ctx.addLine(to: CGPoint(x: contentRect.maxX, y: y))
      ctx.strokePath()
      state.yOffset += 12
      state.hasContent = true
    }

    // MARK: - Inline string building

    private func buildInlineAttributedString(_ text: String, baseAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
      let result = NSMutableAttributedString()
      let inlines = MarkdownToPDFRenderer.parseInline(text)
      for inline in inlines {
        switch inline {
        case .text(let t):
          result.append(NSAttributedString(string: Self.smartQuotes(t), attributes: baseAttributes))
        case .bold(let t):
          var attrs = baseAttributes
          let size = CTFontGetSize(baseAttributes[.font] as! CTFont)
          attrs[.font] = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
          result.append(NSAttributedString(string: Self.smartQuotes(t), attributes: attrs))
        case .italic(let t):
          var attrs = baseAttributes
          let size = CTFontGetSize(baseAttributes[.font] as! CTFont)
          attrs[.font] = CTFontCreateWithName("Helvetica-Oblique" as CFString, size, nil)
          result.append(NSAttributedString(string: Self.smartQuotes(t), attributes: attrs))
        case .boldItalic(let t):
          var attrs = baseAttributes
          let size = CTFontGetSize(baseAttributes[.font] as! CTFont)
          attrs[.font] = CTFontCreateWithName("Helvetica-BoldOblique" as CFString, size, nil)
          result.append(NSAttributedString(string: Self.smartQuotes(t), attributes: attrs))
        case .code(let t):
          var attrs = baseAttributes
          attrs[.font] = CTFontCreateWithName("Menlo" as CFString, 10, nil)
          attrs[.foregroundColor] = NSColor.systemRed.cgColor
          result.append(NSAttributedString(string: t, attributes: attrs))
        case .link(let text, let destination):
          var attrs = baseAttributes
          attrs[.foregroundColor] = NSColor.systemBlue.cgColor
          attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
          attrs[.link] = destination
          result.append(NSAttributedString(string: Self.smartQuotes(text), attributes: attrs))
        }
      }
      return result
    }

    // MARK: - Drawing helpers

    private mutating func ensurePage(state: inout RenderState) {
      if context == nil || state.needsNewPage {
        beginNewPage()
        state.yOffset = 0
        state.needsNewPage = false
      }
    }

    private mutating func beginNewPage() {
      guard let ctx = context else { return }
      if pageNumber > 0 { ctx.endPage() }
      ctx.beginPDFPage(nil)
      pageNumber += 1
    }

    private mutating func finishPage() {
      guard pageNumber > 0 else {
        if pageNumber == 0, context != nil {
          context?.beginPDFPage(nil)
          pageNumber = 1
        }
        return
      }
      guard let ctx = context else { return }
      drawRunningHeader(ctx)
      drawPageNumber(ctx)
      ctx.endPage()
    }

    private func drawRunningHeader(_ ctx: CGContext) {
      guard let title = options.title else { return }
      let font = CTFontCreateWithName("Helvetica" as CFString, 8, nil)
      let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.tertiaryLabelColor.cgColor,
      ]
      let str = NSAttributedString(string: title, attributes: attrs)
      let setter = CTFramesetterCreateWithAttributedString(str)
      let rect = CGRect(
        x: options.margins,
        y: options.pageSize.height - options.margins + 24,
        width: options.pageSize.width - options.margins * 2,
        height: 12)
      let frame = CTFramesetterCreateFrame(
        setter, CFRange(), CGPath(rect: rect, transform: nil), nil)
      CTFrameDraw(frame, ctx)
    }

    private func drawPageNumber(_ ctx: CGContext) {
      let font = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
      let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: NSColor.tertiaryLabelColor.cgColor,
      ]
      let str = NSAttributedString(string: "\(pageNumber)", attributes: attrs)
      let setter = CTFramesetterCreateWithAttributedString(str)
      let rect = CGRect(
        x: options.pageSize.width / 2 - 20,
        y: options.margins - 24,
        width: 40, height: 14)
      let frame = CTFramesetterCreateFrame(
        setter, CFRange(), CGPath(rect: rect, transform: nil), nil)
      CTFrameDraw(frame, ctx)
    }

    private mutating func draw(_ attrStr: NSAttributedString, state: inout RenderState) {
      guard let ctx = context else { return }
      let setter = CTFramesetterCreateWithAttributedString(attrStr)
      let availableWidth = contentRect.width

      let estimatedHeight = attrStr.boundingRect(
        with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin
      ).height

      if state.yOffset + estimatedHeight > contentRect.height {
        finishPage()
        ctx.beginPDFPage(nil)
        pageNumber += 1
        state.yOffset = 0
      }

      var location = 0
      let totalLength = attrStr.length
      while location < totalLength {
        let frame = CTFramesetterCreateFrame(
          setter, CFRange(location: location, length: totalLength - location),
          CGPath(
            rect: CGRect(
              x: contentRect.minX,
              y: contentRect.maxY - state.yOffset - contentRect.height,
              width: availableWidth,
              height: contentRect.height - state.yOffset),
            transform: nil),
          nil)
        CTFrameDraw(frame, ctx)
        let visible = CTFrameGetVisibleStringRange(frame)
        guard visible.length > 0 else { break }
        location += visible.length
        state.yOffset = contentRect.height  // force new page for overflow
      }
    }

    private mutating func drawCodeBlock(_ codeStr: NSAttributedString, state: inout RenderState) {
      guard let ctx = context else { return }
      let setter = CTFramesetterCreateWithAttributedString(codeStr)
      let padding: CGFloat = 8
      let availableWidth = contentRect.width - padding * 2

      let estimatedHeight = codeStr.boundingRect(
        with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
        options: .usesLineFragmentOrigin
      ).height + padding * 2

      if state.yOffset + estimatedHeight > contentRect.height {
        finishPage()
        ctx.beginPDFPage(nil)
        pageNumber += 1
        state.yOffset = 0
      }

      // Background
      let bgRect = CGRect(
        x: contentRect.minX - 4,
        y: contentRect.maxY - state.yOffset - estimatedHeight - 4,
        width: contentRect.width + 8,
        height: estimatedHeight + 8)
      ctx.setFillColor(NSColor.controlBackgroundColor.withAlphaComponent(0.5).cgColor)
      ctx.fill(bgRect)

      // Text
      let textRect = CGRect(
        x: contentRect.minX + padding / 2,
        y: contentRect.maxY - state.yOffset - estimatedHeight,
        width: availableWidth,
        height: estimatedHeight)
      let frame = CTFramesetterCreateFrame(
        setter, CFRange(), CGPath(rect: textRect, transform: nil), nil)
      CTFrameDraw(frame, ctx)
      state.yOffset += estimatedHeight + 8
    }

    // MARK: - Smart quotes & dashes

    private static func smartQuotes(_ text: String) -> String {
      var result = text
      result = result.replacingOccurrences(of: " -- ", with: " — ")
      result = result.replacingOccurrences(of: "---", with: "—")
      result = result.replacingOccurrences(of: "--", with: "–")
      result = result.replacingOccurrences(of: "\"", with: "\u{201C}")
      result = result.replacingOccurrences(of: "\"", with: "\u{201D}")
      result = result.replacingOccurrences(of: "'", with: "\u{2019}")
      result = result.replacingOccurrences(of: "...", with: "…")
      return result
    }

    private static func formattedDate() -> String {
      let formatter = DateFormatter()
      formatter.dateStyle = .long
      return formatter.string(from: Date())
    }
  }

  // MARK: - Render state

  private struct RenderState {
    var yOffset: CGFloat = 0
    var needsNewPage = true
    var hasContent = false
  }
}
