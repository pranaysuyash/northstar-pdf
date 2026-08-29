import PDFEditorCore
import SwiftUI

/// Interactive canvas for document creation — the core CREATE surface.
///
/// Users can:
/// - Place text, shapes, and images on a blank PDF page
/// - Select, move, resize, and delete elements
/// - Undo/redo all operations
/// - Navigate between pages
///
/// First principle: the canvas is a projection of ContentAuthor's state.
/// All mutations go through ContentAuthor (pure state machine).
/// The canvas never holds independent state — it's always in sync.
///
/// Doctrine alignment:
/// - §3: Do things smartly — canvas delegates to ContentAuthor, no side effects
/// - §5: Evidence-based — every action produces an undo entry with a name
/// - §8: Capability activation — CREATE mode must be explicitly entered

// MARK: - Creator Mode

/// The current creation tool selected by the user.
enum CreatorTool: String, CaseIterable, Identifiable {
    case select = "Select"
    case text = "Text"
    case rectangle = "Rectangle"
    case ellipse = "Ellipse"
    case line = "Line"
    case image = "Image"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .text: return "text.cursor"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .image: return "photo"
        }
    }
}

// MARK: - Authoring Canvas View

/// The main interactive canvas for document creation.
struct AuthoringCanvasView: View {
    @ObservedObject var author: ContentAuthor
    @State private var selectedTool: CreatorTool = .select
    @State private var currentPageIndex: Int = 0
    @State private var canvasScale: CGFloat = 1.0
    @State private var canvasOffset: CGPoint = .zero
    @State private var isDragging = false
    @State private var dragStart: CGPoint = .zero
    @State private var elementStartFrame = PDFRect(x: 0, y: 0, width: 0, height: 0)
    @State private var showFontPicker = false
    @State private var showColorPicker = false
    @State private var selectedFont: String = "Helvetica"
    @State private var selectedFontSize: Double = 14
    @State private var selectedColor: String = "000000"
    @State private var textColor: Color = .black
    @State private var isAddingText = false
    @State private var newTextInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            creatorToolbar

            Divider()

            // Canvas area
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    canvasContent(in: geometry)
                }
            }
            .background(Color(NSColor.controlBackgroundColor))

            // Status bar
            statusBar
        }
    }

    // MARK: - Toolbar

    private var creatorToolbar: some View {
        HStack(spacing: 12) {
            // Tool selection
            Picker("Tool", selection: $selectedTool) {
                ForEach(CreatorTool.allCases) { tool in
                    Label(tool.rawValue, systemImage: tool.symbolName).tag(tool)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Divider()

            // Font controls (visible when text tool or text element selected)
            if selectedTool == .text || (selectedTool == .select && selectedElementIsText) {
                fontControls
            }

            // Color controls
            colorControls

            Divider()

            // Page navigation
            HStack(spacing: 8) {
                Button {
                    if currentPageIndex > 0 { currentPageIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPageIndex == 0)

                Text("Page \(currentPageIndex + 1) of \(author.pageCount)")
                    .font(.caption)
                    .monospacedDigit()

                Button {
                    if currentPageIndex < author.pageCount - 1 { currentPageIndex += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPageIndex >= author.pageCount - 1)

                Button {
                    author.addPage()
                    currentPageIndex = author.pageCount - 1
                } label: {
                    Image(systemName: "plus.page")
                }
                .help("Add new page")
            }

            Spacer()

            // Undo/Redo
            HStack(spacing: 4) {
                Button {
                    author.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!author.canUndo)
                .help("Undo (\(author.undoStack.last?.name ?? "nothing"))")

                Button {
                    author.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!author.canRedo)
            }

            // Element count
            Text("\(author.elements.count) elements")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var fontControls: some View {
        HStack(spacing: 8) {
            Picker("Font", selection: $selectedFont) {
                ForEach(["Helvetica", "Helvetica Neue", "Times New Roman", "Courier", "Georgia", "Arial", "Verdana", "Trebuchet MS", "Palatino", "Garamond"], id: \.self) { font in
                    Text(font).font(.custom(font, size: 12)).tag(font)
                }
            }
            .frame(width: 180)

            TextField("Size", value: $selectedFontSize, format: .number)
                .frame(width: 50)
                .textFieldStyle(.roundedBorder)

            Button {
                // Apply font changes to selected element
                if let selectedID = author.selectedElementID,
                   let element = author.elements.first(where: { $0.id == selectedID }) {
                    if case .text(var props) = element.kind {
                        props.fontName = selectedFont
                        props.fontSize = selectedFontSize
                        author.updateElement(id: selectedID, kind: .text(props))
                    }
                }
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var colorControls: some View {
        HStack(spacing: 6) {
            ForEach(["000000", "ff0000", "0066ff", "009933", "ff6600", "9933cc", "666666"], id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().stroke(.primary, lineWidth: selectedColor == hex ? 2 : 0)
                    )
                    .onTapGesture {
                        selectedColor = hex
                        textColor = Color(hex: hex)
                        // Apply to selected element
                        if let selectedID = author.selectedElementID {
                            applyColorToElement(id: selectedID, hex: hex)
                        }
                    }
            }
        }
    }

    private func applyColorToElement(id: UUID, hex: String) {
        guard let element = author.elements.first(where: { $0.id == id }) else { return }
        switch element.kind {
        case .text(var props):
            props.color = hex
            author.updateElement(id: id, kind: .text(props))
        case .shape(var props):
            props.fillColor = hex
            author.updateElement(id: id, kind: .shape(props))
        default:
            break
        }
    }

    private var selectedElementIsText: Bool {
        guard let selectedID = author.selectedElementID,
              let element = author.elements.first(where: { $0.id == selectedID }) else { return false }
        if case .text = element.kind { return true }
        return false
    }



    // MARK: - Canvas Content

    private func canvasContent(in geometry: GeometryProxy) -> some View {
        let pageWidth = author.pageSize.width * canvasScale
        let pageHeight = author.pageSize.height * canvasScale

        return ZStack {
            // Page background
            Rectangle()
                .fill(.white)
                .frame(width: pageWidth, height: pageHeight)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            // Grid lines (subtle)
            gridOverlay(width: pageWidth, height: pageHeight)

            // Elements
            ForEach(elementsOnCurrentPage) { element in
                elementView(for: element)
                    .position(
                        x: (element.frame.x + element.frame.width / 2) * canvasScale,
                        y: (author.pageSize.height - element.frame.y - element.frame.height / 2) * canvasScale
                    )
                    .onTapGesture {
                        if selectedTool == .select {
                            author.selectedElementID = element.id
                            loadElementProperties(element)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if selectedTool == .select {
                                    handleDragChanged(element: element, value: value)
                                }
                            }
                            .onEnded { value in
                                if selectedTool == .select {
                                    handleDragEnded(element: element)
                                }
                            }
                    )
            }

            // Selection highlight
            if let selectedID = author.selectedElementID,
               let element = author.elements.first(where: { $0.id == selectedID }),
               element.pageIndex == currentPageIndex {
                selectionHighlight(for: element)
            }

            // Text input overlay (when adding new text)
            if isAddingText {
                textInputOverlay
            }
        }
        .frame(width: pageWidth, height: pageHeight)
        .onTapGesture { location in
            handleCanvasTap(at: location)
        }
    }

    // MARK: - Element Views

    @ViewBuilder
    private func elementView(for element: DocumentElement) -> some View {
        switch element.kind {
        case .text(let props):
            textElementView(props: props, element: element)
        case .image(let props):
            imageElementView(props: props, element: element)
        case .shape(let props):
            shapeElementView(props: props, element: element)
        case .path:
            Rectangle().fill(.clear)
        }
    }

    private func textElementView(props: TextProperties, element: DocumentElement) -> some View {
        Text(props.content)
            .font(.custom(props.fontName, size: props.fontSize * canvasScale))
            .foregroundStyle(Color(hex: props.color))
            .frame(
                width: element.frame.width * canvasScale,
                height: element.frame.height * canvasScale,
                alignment: .topLeading
            )
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(element.opacity)
    }

    private func imageElementView(props: ImageProperties, element: DocumentElement) -> some View {
        Group {
            if let nsImage = NSImage(data: props.imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(
            width: element.frame.width * canvasScale,
            height: element.frame.height * canvasScale
        )
        .opacity(element.opacity)
    }

    private func shapeElementView(props: ShapeProperties, element: DocumentElement) -> some View {
        Group {
            switch props.shapeType {
            case .rectangle:
                Rectangle()
                    .fill(Color(hex: props.fillColor ?? "000000"))
                    .overlay(
                        Rectangle().stroke(Color(hex: props.strokeColor), lineWidth: props.strokeWidth * canvasScale)
                    )
            case .ellipse:
                Ellipse()
                    .fill(Color(hex: props.fillColor ?? "000000"))
                    .overlay(
                        Ellipse().stroke(Color(hex: props.strokeColor), lineWidth: props.strokeWidth * canvasScale)
                    )
            case .line:
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(
                        x: element.frame.width * canvasScale,
                        y: element.frame.height * canvasScale
                    ))
                }
                .stroke(Color(hex: props.strokeColor), lineWidth: props.strokeWidth * canvasScale)
            case .arrow:
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(
                        x: element.frame.width * canvasScale,
                        y: element.frame.height * canvasScale
                    ))
                }
                .stroke(Color(hex: props.strokeColor), lineWidth: props.strokeWidth * canvasScale)
            }
        }
        .frame(
            width: element.frame.width * canvasScale,
            height: element.frame.height * canvasScale
        )
        .opacity(element.opacity)
    }

    // MARK: - Selection

    private func selectionHighlight(for element: DocumentElement) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(
                width: element.frame.width * canvasScale + 8,
                height: element.frame.height * canvasScale + 8
            )
            .position(
                x: (element.frame.x + element.frame.width / 2) * canvasScale,
                y: (author.pageSize.height - element.frame.y - element.frame.height / 2) * canvasScale
            )
            .allowsHitTesting(false)
    }

    // MARK: - Grid

    private func gridOverlay(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let spacing: CGFloat = 36 * canvasScale // 0.5 inch grid
            var path = Path()
            // Vertical lines
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            // Horizontal lines
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(.gray.opacity(0.1)), lineWidth: 0.5)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    // MARK: - Text Input

    private var textInputOverlay: some View {
        VStack {
            TextField("Type text...", text: $newTextInput, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.custom(selectedFont, size: selectedFontSize * canvasScale))
                .foregroundStyle(textColor)
                .frame(minWidth: 200, minHeight: 30)
                .padding(4)
                .background(.white.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.blue, lineWidth: 1))
                .onSubmit {
                    if !newTextInput.isEmpty {
                        let point = CGPoint(x: 72, y: author.pageSize.height - 100)
                        author.addText(
                            content: newTextInput,
                            at: point,
                            fontName: selectedFont,
                            fontSize: selectedFontSize,
                            color: selectedColor
                        )
                        newTextInput = ""
                        isAddingText = false
                    }
                }
        }
        .position(x: author.pageSize.width * canvasScale / 2, y: author.pageSize.height * canvasScale / 2)
    }

    // MARK: - Interaction

    private func handleCanvasTap(at location: CGPoint) {
        switch selectedTool {
        case .select:
            // Deselect
            author.selectedElementID = nil
        case .text:
            // Add text at tap location
            let pagePoint = CGPoint(
                x: location.x / canvasScale,
                y: author.pageSize.height - (location.y / canvasScale)
            )
            author.addText(
                content: "Text",
                at: pagePoint,
                fontName: selectedFont,
                fontSize: selectedFontSize,
                color: selectedColor
            )
        case .rectangle:
            let pagePoint = CGPoint(
                x: location.x / canvasScale - 100,
                y: author.pageSize.height - (location.y / canvasScale) - 50
            )
            author.addShape(
                type: .rectangle,
                frame: PDFRect(x: pagePoint.x, y: pagePoint.y, width: 200, height: 100),
                fillColor: selectedColor
            )
        case .ellipse:
            let pagePoint = CGPoint(
                x: location.x / canvasScale - 75,
                y: author.pageSize.height - (location.y / canvasScale) - 75
            )
            author.addShape(
                type: .ellipse,
                frame: PDFRect(x: pagePoint.x, y: pagePoint.y, width: 150, height: 150),
                fillColor: selectedColor
            )
        case .line:
            let pagePoint = CGPoint(
                x: location.x / canvasScale,
                y: author.pageSize.height - (location.y / canvasScale)
            )
            author.addShape(
                type: .line,
                frame: PDFRect(x: pagePoint.x, y: pagePoint.y, width: 200, height: 0),
                fillColor: selectedColor
            )
        case .image:
            // Open image picker (handled by parent view)
            break
        }
    }

    private func loadElementProperties(_ element: DocumentElement) {
        switch element.kind {
        case .text(let props):
            selectedFont = props.fontName
            selectedFontSize = props.fontSize
            selectedColor = props.color
            textColor = Color(hex: props.color)
        case .shape(let props):
            selectedColor = props.fillColor ?? "000000"
        default:
            break
        }
    }

    private func handleDragChanged(element: DocumentElement, value: DragGesture.Value) {
        let dx = value.translation.width / canvasScale
        let dy = -value.translation.height / canvasScale // PDF coords are bottom-up

        author.moveElement(
            id: element.id,
            to: PDFRect(
                x: element.frame.x + dx,
                y: element.frame.y + dy,
                width: element.frame.width,
                height: element.frame.height
            )
        )
    }

    private func handleDragEnded(element: DocumentElement) {
        // Drag end is handled by moveElement which creates an undo entry
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text("Page \(currentPageIndex + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            if let selected = author.selectedElementID,
               let element = author.elements.first(where: { $0.id == selected }) {
                Text("Selected: \(element.kind.displayName) at (\(Int(element.frame.x)), \(Int(element.frame.y)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Zoom: \(Int(canvasScale * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }

    // MARK: - Helpers

    private var elementsOnCurrentPage: [DocumentElement] {
        author.elements.filter { $0.pageIndex == currentPageIndex }.sorted { $0.zIndex < $1.zIndex }
    }
}


