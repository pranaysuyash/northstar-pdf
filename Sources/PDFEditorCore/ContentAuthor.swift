import Foundation
import PDFKit

/// Manages content elements on blank PDF pages — the core engine for the CREATE archetype.
///
/// First principle: the author is a pure state machine.
/// Every operation produces a new element list; undo restores the previous list.
/// No side effects, no file I/O — rendering to PDF is a separate concern.
///
/// Doctrine alignment:
/// - §3: Do things smartly — elements are descriptors, PDF rendering is a projection
/// - §5: Evidence-based — full undo history with operation names
/// - §8: Capability activation — CREATE mode must be explicitly entered

// MARK: - Content Author

/// Pure state machine for document content authoring.
@MainActor
public final class ContentAuthor: ObservableObject {
  /// All elements across all pages.
  @Published public var elements: [DocumentElement] = []
  /// Undo stack (previous element states).
  @Published public private(set) var undoStack: [UndoEntry] = []
  /// Redo stack.
  @Published public private(set) var redoStack: [UndoEntry] = []
  /// Currently selected element ID.
  @Published public var selectedElementID: UUID?
  /// Page size (PDF points).
  public var pageSize: CGSize = CGSize(width: 612, height: 792)
  /// Number of pages.
  public var pageCount: Int = 1

  private let maxUndoLevels = 50

  public init() {}

  // MARK: - Element Management

  /// Add an element to the page.
  @discardableResult
  public func addElement(_ newElement: DocumentElement, operationName: String? = nil) -> DocumentElement {
    let name = operationName ?? "Add \(newElement.kind.displayName)"
    pushUndo(name: name)
    var el = newElement
    el.zIndex = (elements.filter { $0.pageIndex == newElement.pageIndex }.map(\.zIndex).max() ?? 0) + 1
    elements.append(el)
    selectedElementID = el.id
    return el
  }

  /// Add a text element at a position.
  @discardableResult
  public func addText(
    content: String,
    at point: CGPoint,
    pageIndex: Int = 0,
    fontName: String = "Helvetica",
    fontSize: Double = 14,
    color: String = "000000"
  ) -> DocumentElement {
    let width = min(400, Double(pageSize.width) - Double(point.x) - 72)
    let element = DocumentElement(
      pageIndex: pageIndex,
      kind: .text(TextProperties(
        content: content,
        fontName: fontName,
        fontSize: fontSize,
        color: color
      )),
      frame: PDFRect(x: Double(point.x), y: Double(point.y), width: width, height: fontSize * 1.5)
    )
    return addElement(element, operationName: "Add Text")
  }

  /// Add a shape element.
  @discardableResult
  public func addShape(
    type: ShapeType,
    frame: PDFRect,
    pageIndex: Int = 0,
    strokeColor: String = "000000",
    fillColor: String? = nil,
    strokeWidth: Double = 1.0
  ) -> DocumentElement {
    let element = DocumentElement(
      pageIndex: pageIndex,
      kind: .shape(ShapeProperties(
        shapeType: type,
        strokeColor: strokeColor,
        strokeWidth: strokeWidth,
        fillColor: fillColor
      )),
      frame: frame
    )
    return addElement(element, operationName: "Add \(type.displayName)")
  }

  /// Add an image element.
  @discardableResult
  public func addImage(
    imageData: Data,
    at point: CGPoint,
    pageIndex: Int = 0,
    maxWidth: Double = 300
  ) -> DocumentElement? {
    guard let nsImage = NSImage(data: imageData),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }
    let origW = Double(cgImage.width)
    let origH = Double(cgImage.height)
    let scale = min(1.0, maxWidth / origW)
    let w = origW * scale
    let h = origH * scale

    let element = DocumentElement(
      pageIndex: pageIndex,
      kind: .image(ImageProperties(
        imageData: imageData,
        originalWidth: origW,
        originalHeight: origH
      )),
      frame: PDFRect(x: Double(point.x), y: Double(point.y), width: w, height: h)
    )
    return addElement(element, operationName: "Add Image")
  }

  /// Move an element to a new position.
  public func moveElement(id: UUID, to frame: PDFRect) {
    guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
    pushUndo(name: "Move \(elements[index].kind.displayName)")
    elements[index].frame = frame
    elements[index].updatedAt = Date()
  }

  /// Resize an element.
  public func resizeElement(id: UUID, to frame: PDFRect) {
    guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
    pushUndo(name: "Resize \(elements[index].kind.displayName)")
    elements[index].frame = frame
    elements[index].updatedAt = Date()
  }

  /// Update text content of a text element.
  public func updateText(id: UUID, content: String) {
    guard let index = elements.firstIndex(where: { $0.id == id }),
          case .text(var props) = elements[index].kind else { return }
    pushUndo(name: "Edit Text")
    props.content = content
    elements[index] = DocumentElement(
      id: elements[index].id,
      pageIndex: elements[index].pageIndex,
      kind: .text(props),
      frame: elements[index].frame,
      rotation: elements[index].rotation,
      opacity: elements[index].opacity,
      zIndex: elements[index].zIndex,
      name: elements[index].name
    )
    elements[index].updatedAt = Date()
  }

  /// Update an element's kind (e.g., change font/color of text, fill of shape).
  public func updateElement(id: UUID, kind: ElementKind) {
    guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
    let displayName = elements[index].kind.displayName
    pushUndo(name: "Update \(displayName)")
    elements[index] = DocumentElement(
      id: elements[index].id,
      pageIndex: elements[index].pageIndex,
      kind: kind,
      frame: elements[index].frame,
      rotation: elements[index].rotation,
      opacity: elements[index].opacity,
      zIndex: elements[index].zIndex,
      name: elements[index].name
    )
    elements[index].updatedAt = Date()
  }

  /// Update the fill color of a shape element.
  public func updateShapeFill(id: UUID, fillColor: String) {
    guard let index = elements.firstIndex(where: { $0.id == id }),
          case .shape(var props) = elements[index].kind else { return }
    pushUndo(name: "Change Color")
    props.fillColor = fillColor
    elements[index] = DocumentElement(
      id: elements[index].id,
      pageIndex: elements[index].pageIndex,
      kind: .shape(props),
      frame: elements[index].frame,
      rotation: elements[index].rotation,
      opacity: elements[index].opacity,
      zIndex: elements[index].zIndex,
      name: elements[index].name
    )
    elements[index].updatedAt = Date()
  }

  /// Delete an element.
  public func deleteElement(id: UUID) {
    guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
    pushUndo(name: "Delete \(elements[index].kind.displayName)")
    elements.remove(at: index)
    if selectedElementID == id {
      selectedElementID = nil
    }
  }

  /// Duplicate an element.
  @discardableResult
  public func duplicateElement(id: UUID) -> DocumentElement? {
    guard let original = elements.first(where: { $0.id == id }) else { return nil }
    var newFrame = original.frame
    newFrame.x += 20
    newFrame.y -= 20
    let duplicate = DocumentElement(
      pageIndex: original.pageIndex,
      kind: original.kind,
      frame: newFrame,
      rotation: original.rotation,
      opacity: original.opacity,
      zIndex: (elements.filter { $0.pageIndex == original.pageIndex }.map(\.zIndex).max() ?? 0) + 1,
      name: original.name.isEmpty ? "" : "\(original.name) copy"
    )
    return addElement(duplicate, operationName: "Duplicate \(original.kind.displayName)")
  }

  // MARK: - Page Management

  /// Add a new blank page.
  public func addPage(at index: Int? = nil) {
    pushUndo(name: "Add Page")
    let insertAt = index ?? pageCount
    pageCount += 1
    // Shift elements on pages >= insertAt
    for i in elements.indices where elements[i].pageIndex >= insertAt {
      var el = elements[i]
      el.pageIndex += 1
      elements[i] = el
    }
  }

  /// Delete a page and all its elements.
  public func deletePage(at index: Int) {
    guard index >= 0, index < pageCount, pageCount > 1 else { return }
    pushUndo(name: "Delete Page")
    elements.removeAll { $0.pageIndex == index }
    // Shift elements on pages > index
    for i in elements.indices where elements[i].pageIndex > index {
      var el = elements[i]
      el.pageIndex -= 1
      elements[i] = el
    }
    pageCount -= 1
  }

  // MARK: - Template

  /// Apply a page template to a page.
  public func applyTemplate(_ template: PageTemplate, toPage pageIndex: Int) {
    let templateElements = template.generateElements(pageIndex: pageIndex, pageSize: pageSize)
    for element in templateElements {
      addElement(element, operationName: "Apply \(template.displayName)")
    }
  }

  // MARK: - Query

  /// Elements on a specific page, sorted by z-index.
  public func elementsOnPage(_ pageIndex: Int) -> [DocumentElement] {
    elements
      .filter { $0.pageIndex == pageIndex }
      .sorted { $0.zIndex < $1.zIndex }
  }

  /// Total element count.
  public var elementCount: Int { elements.count }

  /// Elements grouped by page.
  public var elementsByPage: [[DocumentElement]] {
    (0..<pageCount).map { page in
      elementsOnPage(page)
    }
  }

  // MARK: - Selection

  /// Select an element.
  public func selectElement(id: UUID?) {
    selectedElementID = id
  }

  /// Get the currently selected element.
  public var selectedElement: DocumentElement? {
    elements.first { $0.id == selectedElementID }
  }

  // MARK: - Undo/Redo

  public var canUndo: Bool { !undoStack.isEmpty }
  public var canRedo: Bool { !redoStack.isEmpty }

  public func undo() {
    guard let entry = undoStack.popLast() else { return }
    redoStack.append(UndoEntry(name: entry.name, elements: elements, pageCount: pageCount))
    elements = entry.elements
    pageCount = entry.pageCount
    selectedElementID = nil
  }

  public func redo() {
    guard let entry = redoStack.popLast() else { return }
    undoStack.append(UndoEntry(name: entry.name, elements: elements, pageCount: pageCount))
    elements = entry.elements
    pageCount = entry.pageCount
    selectedElementID = nil
  }

  private func pushUndo(name: String) {
    undoStack.append(UndoEntry(name: name, elements: elements, pageCount: pageCount))
    if undoStack.count > maxUndoLevels {
      undoStack.removeFirst()
    }
    redoStack.removeAll()
  }

  // MARK: - Render to PDF

  /// Render all elements to a PDF document.
  public func renderToPDF() -> PDFDocument? {
    let doc = PDFDocument()

    for pageIndex in 0..<pageCount {
      if let pageData = renderPageData(pageIndex: pageIndex),
         let pageDoc = PDFDocument(data: pageData),
         let page = pageDoc.page(at: 0) {
        doc.insert(page, at: pageIndex)
      } else {
        // Fallback: blank page
        let blankPage = PDFPage()
        blankPage.setBounds(CGRect(origin: .zero, size: pageSize), for: .mediaBox)
        doc.insert(blankPage, at: pageIndex)
      }
    }

    return doc
  }

  /// Render a single page to PDF data using CGContext.
  private func renderPageData(pageIndex: Int) -> Data? {
    let mediaBox = CGRect(origin: .zero, size: pageSize)
    let pdfData = NSMutableData()
    guard let consumer = CGDataConsumer(data: pdfData) else { return nil }
    var mediaBoxVar = mediaBox
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBoxVar, nil) else { return nil }

    // White background
    context.setFillColor(CGColor.white)
    context.fill(mediaBox)

    // Draw elements in z-order
    let pageElements = elementsOnPage(pageIndex)
    for element in pageElements {
      drawElement(element, in: context, pageBounds: mediaBox)
    }

    context.restoreGState()

    return pdfData as Data
  }

  /// Draw a single element into a CGContext.
  private func drawElement(_ element: DocumentElement, in context: CGContext, pageBounds: CGRect) {
    context.saveGState()
    context.setAlpha(CGFloat(element.opacity))

    // PDF coordinates: origin at bottom-left (matches our element frames)
    let rect = CGRect(
      x: element.frame.x,
      y: element.frame.y,
      width: element.frame.width,
      height: element.frame.height
    )

    switch element.kind {
    case .text(let props):
      drawText(props, in: rect, in: context)
    case .image(let props):
      drawImage(props, in: rect, in: context)
    case .shape(let props):
      drawShape(props, in: rect, in: context)
    case .path(let props):
      drawPath(props, in: rect, in: context)
    }

    context.restoreGState()
  }

  private func drawText(_ props: TextProperties, in rect: CGRect, in context: CGContext) {
    let nsFont = NSFont(name: props.fontName, size: CGFloat(props.fontSize)) ?? NSFont.systemFont(ofSize: CGFloat(props.fontSize))
    let color = NSColor(hex: props.color) ?? .black

    let attributes: [NSAttributedString.Key: Any] = [
      .font: nsFont,
      .foregroundColor: color
    ]

    let nsString = props.content as NSString
    let size = nsString.size(withAttributes: attributes)

    // Alignment
    let textX: CGFloat
    switch props.alignment {
    case .left: textX = rect.origin.x
    case .center: textX = rect.origin.x + (rect.width - size.width) / 2
    case .right: textX = rect.origin.x + rect.width - size.width
    case .justified: textX = rect.origin.x
    }

    // Draw text — flip coordinate system for text rendering
    context.saveGState()
    context.translateBy(x: 0, y: rect.origin.y + rect.height)
    context.scaleBy(x: 1, y: -1)
    nsString.draw(at: CGPoint(x: textX - rect.origin.x, y: 0), withAttributes: attributes)
    context.restoreGState()
  }

  private func drawImage(_ props: ImageProperties, in rect: CGRect, in context: CGContext) {
    guard let nsImage = NSImage(data: props.imageData),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
    context.draw(cgImage, in: rect)
  }

  private func drawShape(_ props: ShapeProperties, in rect: CGRect, in context: CGContext) {
    let strokeColor = NSColor(hex: props.strokeColor) ?? .black
    context.setStrokeColor(strokeColor.cgColor)
    context.setLineWidth(CGFloat(props.strokeWidth))

    if let fillHex = props.fillColor {
      let fillColor = NSColor(hex: fillHex) ?? .clear
      context.setFillColor(fillColor.cgColor)
    }

    if props.isDashed {
      context.setLineDash(phase: 0, lengths: [6, 4])
    }

    let path = CGMutablePath()

    switch props.shapeType {
    case .rectangle:
      let roundedRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
      if props.cornerRadius > 0 {
        path.addRoundedRect(in: roundedRect, cornerWidth: CGFloat(props.cornerRadius), cornerHeight: CGFloat(props.cornerRadius))
      } else {
        path.addRect(roundedRect)
      }
    case .ellipse:
      path.addEllipse(in: rect)
    case .line:
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    case .arrow:
      path.move(to: CGPoint(x: rect.minX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
      // Arrowhead
      let headSize: CGFloat = 10
      path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX - headSize, y: rect.midY + headSize / 2))
      path.move(to: CGPoint(x: rect.maxX, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX - headSize, y: rect.midY - headSize / 2))
    }

    if let fillColor = props.fillColor {
      context.addPath(path)
      context.fillPath()
    }
    context.addPath(path)
    context.strokePath()
  }

  private func drawPath(_ props: PathProperties, in rect: CGRect, in context: CGContext) {
    let strokeColor = NSColor(hex: props.strokeColor) ?? .black
    context.setStrokeColor(strokeColor.cgColor)
    context.setLineWidth(CGFloat(props.strokeWidth))
    context.setLineCap(.round)
    context.setLineJoin(.round)

    guard let first = props.points.first else { return }
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + CGFloat(first.x), y: rect.minY + CGFloat(first.y)))

    for point in props.points.dropFirst() {
      path.addLine(to: CGPoint(x: rect.minX + CGFloat(point.x), y: rect.minY + CGFloat(point.y)))
    }

    context.addPath(path)
    context.strokePath()
  }
}

// MARK: - Undo Entry

/// A snapshot of the authoring state for undo/redo.
public struct UndoEntry: Sendable {
  public let name: String
  public let elements: [DocumentElement]
  public let pageCount: Int

  public init(name: String, elements: [DocumentElement], pageCount: Int) {
    self.name = name
    self.elements = elements
    self.pageCount = pageCount
  }
}

// MARK: - NSColor Extension

extension NSColor {
  convenience init?(hex: String) {
    let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default: (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
  }
}
