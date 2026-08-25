import AppKit
import PDFEditorCore
import PDFEditorRecovery
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension NSImage {
  fileprivate var pngData: Data? {
    guard let tiffData = tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
  }
}

extension SavedSignature {
  fileprivate var signatureImageData: Data? {
    if dataURL.hasPrefix("data:image"), let comma = dataURL.firstIndex(of: ",") {
      return Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...]))
    }
    return Data(base64Encoded: dataURL)
  }
}

@MainActor private func canCopyText(_ model: AppModel) -> Bool {
  model.inspection?.permissions.canCopy ?? false
}

@MainActor private func canEditAnnotations(_ model: AppModel) -> Bool {
  guard let permissions = model.inspection?.permissions else { return false }
  return permissions.canModify && permissions.canAddAnnotations
}

@MainActor private func canExportCopy(_ model: AppModel) -> Bool {
  guard model.canExportCurrentOperations,
    let permissions = model.inspection?.permissions
  else { return false }
  return permissions.canModify || permissions.canAddAnnotations
}

@MainActor private func exportCopyHelp(_ model: AppModel) -> String {
  if canExportCopy(model) {
    return "Creates a separate edited PDF. The source file is never overwritten or saved in place."
  }
  if model.inspection == nil {
    return "Unavailable until a PDF is open and contains exportable edits."
  }
  if !(model.inspection?.permissions.canModify ?? false)
    && !(model.inspection?.permissions.canAddAnnotations ?? false)
  {
    return "Unavailable because this PDF does not allow the document changes required for export."
  }
  return "Unavailable until there are authorized, validated edits to export."
}

public struct ContentView: View {
  @Bindable var model: AppModel
  @Binding private var searchFocusEvent: Int
  @State private var searchProjectionState: SearchProjectionState = .none
  @State private var isAgentCommandPresented = false
  @State private var isSecurityVaultPresented = false

  public init(model: AppModel, searchFocusEvent: Binding<Int> = .constant(0)) {
    self.model = model
    self._searchFocusEvent = searchFocusEvent
  }

  public var body: some View {
    mainContent
      .toolbar { appToolbar }
      .fileImporter(
        isPresented: $model.isImporterPresented,
        allowedContentTypes: [.pdf],
        allowsMultipleSelection: false
      ) { result in
        if case .success(let urls) = result, let url = urls.first {
          openImportedPDF(url)
        }
      }
      .alert(
        "PDF Editor",
        isPresented: Binding(
          get: { model.alertMessage != nil },
          set: { if !$0 { model.alertMessage = nil } }
        )
      ) {
        Button("OK") { model.alertMessage = nil }
      } message: {
        Text(model.alertMessage ?? "")
      }
      .sheet(isPresented: $model.isPasswordSheetPresented) {
        PasswordPromptView(model: model)
      }
      .sheet(isPresented: $model.isManualTextSheetPresented) {
        ManualTextSheet(model: model)
      }
      .sheet(isPresented: $model.isSignatureSheetPresented) {
        SignatureSheet(model: model)
      }
      .sheet(isPresented: $isSecurityVaultPresented) {
        SecurityVaultSheet(model: model)
      }
      .sheet(isPresented: $model.showDiffSheet) {
        DiffComparisonView(
          sourceDocument: model.sourceDocument,
          currentDocument: model.liveDocument,
          sourceInspection: model.sourceInspection,
          currentInspection: model.inspection,
          operations: model.operations,
          diff: model.currentDiff,
          selectedPageIndex: model.selectedPageIndex,
          onPageChange: { model.selectedPageIndex = $0 },
          onExportReport: { model.exportDiffReport() }
        )
      }
      .alert(
        "Commit Redactions Permanently?",
        isPresented: $model.isRedactionCommitPresented
      ) {
        Button("Cancel", role: .cancel) {
          model.isRedactionCommitPresented = false
        }
        Button("Commit Permanently", role: .destructive) {
          model.commitRedactions()
        }
      } message: {
        let count = model.operations.filter { $0.kind == .redactMark }.count
        Text(
          "This will permanently remove content under \(count) marked region\(count == 1 ? "" : "s") in a separate new PDF copy. The original file is never overwritten.\n\nThis action cannot be undone."
        )
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    if let inspection = model.inspection {
      ZStack {
        VStack(spacing: 0) {
          RecoveryStatusBanner(model: model)

          HSplitView {
            PageThumbnailRailView(model: model, inspection: inspection)
              .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

            DocumentCanvasView(
              model: model,
              inspection: inspection,
              searchProjectionState: $searchProjectionState
            )

            ContextualInspectorView(
              model: model,
              inspection: inspection,
              isSecurityVaultPresented: $isSecurityVaultPresented
            )
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
          }
        }

        if isAgentCommandPresented {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
              isAgentCommandPresented = false
            }

          AgentCommandHUD(
            model: model,
            isPresented: $isAgentCommandPresented,
            isSecurityVaultPresented: $isSecurityVaultPresented
          )
          .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isAgentCommandPresented)
      .onChange(of: model.selectedPageIndex) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.selectedFieldID) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.selectedCandidateID) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.selectedSearchMatchIndex) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.searchQuery) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.readerViewMode) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.readerScaleMode) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.readerZoom) { _, _ in model.scheduleViewStateAutosave() }
      .onChange(of: model.readerRotation) { _, _ in model.scheduleViewStateAutosave() }
    } else {
      WelcomeView(open: requestOpenDocument)
    }
  }

  @ToolbarContentBuilder
  private var appToolbar: some ToolbarContent {
    ToolbarItemGroup {
      Button("Open", systemImage: "folder") {
        requestOpenDocument()
      }
      .accessibilityLabel("Open PDF")
      .help("Open another PDF. The current document remains open until the new PDF is admitted.")

      Button("Undo", systemImage: "arrow.uturn.backward") {
        model.undoLastEdit()
      }
      .accessibilityLabel("Undo last edit")
      .disabled(!model.canUndo)

      Button("Redo", systemImage: "arrow.uturn.forward") {
        model.redoLastEdit()
      }
      .accessibilityLabel("Redo last edit")
      .disabled(!model.canRedo)

      Menu {
        Button("Export Copy…", systemImage: "square.and.arrow.down") {
          model.export()
        }
        Button("Export Flattened Copy…", systemImage: "printer.dotmatrix") {
          let panel = NSSavePanel()
          panel.allowedContentTypes = [.pdf]
          panel.nameFieldStringValue = "Flattened-\(model.inspection?.source.name ?? "document.pdf")"
          panel.begin { response in
            if response == .OK, let url = panel.url {
              model.exportFlattenedCopy(destination: url)
            }
          }
        }
      } label: {
        Label("Export", systemImage: "square.and.arrow.down")
      }
      .accessibilityLabel("Export edited PDF copy")
      .disabled(!canExportCopy(model))
      .help(exportCopyHelp(model))
    }

    ToolbarItem {
      Picker(
        "Editor mode",
        selection: Binding(
          get: { model.editorMode },
          set: { model.setEditorMode($0) }
        )
      ) {
        ForEach(EditorMode.allCases, id: \.self) { mode in
          Label(mode.displayName, systemImage: mode.symbolName).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 260)
      .disabled(model.inspection == nil)
      .help("Choose intent: Read, Fill, Sign, or Edit.")
    }

    ToolbarItem {
      Button {
        isAgentCommandPresented.toggle()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "sparkles")
            .foregroundStyle(Color.accentColor)
          Text("Agent")
            .font(.caption.weight(.medium))
          Text("⌘K")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.12))
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .keyboardShortcut("k", modifiers: .command)
      .disabled(model.inspection == nil)
      .help("Open Agent Command Palette (⌘K) for semantic actions, bulk fill, OCR, and diff tools.")
    }

    ToolbarItem {
      Picker(
        "Reader mode",
        selection: Binding(
          get: { model.readerViewMode },
          set: { model.setReaderViewMode($0) }
        )
      ) {
        Text("Single").tag(ReaderViewMode.singlePage)
        Text("Continuous").tag(ReaderViewMode.continuous)
        Text("Two-page").tag(ReaderViewMode.twoPage)
      }
      .pickerStyle(.segmented)
      .frame(width: 210)
    }

    ToolbarItem {
      Menu {
        Button {
          model.toggleDiffView()
        } label: {
          Label(
            model.showDiff ? "Hide Visual Diff Overlay" : "Show Visual Diff Overlay",
            systemImage: model.showDiff ? "rectangle.dashed" : "rectangle.fill"
          )
        }
        .disabled(model.sourceInspection == nil)

        Button {
          model.openDiffComparison()
        } label: {
          Label("Side-by-Side Comparison…", systemImage: "rectangle.split.2x1")
        }
        .disabled(model.sourceInspection == nil)
      } label: {
        Label(
          "Diff",
          systemImage: model.showDiff ? "doc.text.magnifyingglass.fill" : "doc.text.magnifyingglass"
        )
      }
      .disabled(model.sourceInspection == nil)
      .help("Visual diff: overlay highlights on the page, or open a side-by-side comparison.")
    }

    ToolbarItem(placement: .status) {
      HStack(spacing: 8) {
        if model.isFillOfferVisible && model.editorMode == .read {
          Button {
            model.setEditorMode(.fill)
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "pencil.and.list.clipboard")
              Text(model.fillProgressLabel ?? "Start filling")
                .fontWeight(.medium)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }

        if model.editorMode == .fill, let label = model.fillProgressLabel {
          HStack(spacing: 6) {
            if let progress = model.fillProgress {
              ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 70)
                .tint(.accentColor)
            }
            Text(label)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Text(model.statusMessage ?? "Ready")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }

  private func openImportedPDF(_ url: URL) {
    guard let candidate = PDFDocument(url: url) else {
      model.alertMessage = "The selected PDF could not be opened. The current document remains open."
      return
    }
    guard candidate.isLocked || candidate.pageCount > 0 else {
      model.alertMessage = "The selected PDF contains no readable pages. The current document remains open."
      return
    }
    model.open(url: url)
  }

  @MainActor
  private func requestOpenDocument() {
    let decision = model.lifecycleDecision(for: .openDocument)
    guard decision.disposition == .confirmBeforeDiscardingChanges else {
      model.isImporterPresented = true
      return
    }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "This document has unexported changes."
    alert.informativeText = "PDF Editor uses an export-only workflow: Export Copy... creates a separate edited PDF and never overwrites the source. Choose Continue to Open to select another PDF, or Cancel to keep working."
    alert.addButton(withTitle: "Continue to Open")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    model.isImporterPresented = true
  }
}

// MARK: - Recovery Status Banner
private struct RecoveryStatusBanner: View {
  @Bindable var model: AppModel

  private var hasRecoveryState: Bool {
    switch model.recoveryStatus {
    case .none:
      return !model.recoveryRecords.isEmpty || !model.recoveryDiagnostics.isEmpty
    case .available, .replayable, .metadataOnly, .corrupted, .saveFailed:
      return true
    }
  }

  var body: some View {
    if hasRecoveryState {
      HStack(spacing: 8) {
        Image(systemName: "arrow.clockwise.circle.fill")
          .foregroundStyle(.orange)
        Text("Recovery session active")
          .font(.caption.weight(.semibold))
        Text("(\(model.recoveryRecords.count) record(s))")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      .background(Color.orange.opacity(0.12))
      .overlay(alignment: .bottom) {
        Divider()
      }
    }
  }
}

// MARK: - Welcome View
private struct WelcomeView: View {
  let open: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .fill(Color.accentColor.opacity(0.12))
          .frame(width: 88, height: 88)
        Image(systemName: "sparkle.magnifyingglass")
          .font(.system(size: 42, weight: .light))
          .foregroundStyle(Color.accentColor)
      }

      VStack(spacing: 6) {
        Text("Northstar Document Workbench")
          .font(.title2.weight(.semibold))
        Text("Local-first PDF reader, verified completion, and agentic intelligence without disturbing source bytes.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 480)
      }

      Button("Open a PDF…", action: open)
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}

// MARK: - Password Prompt
private struct PasswordPromptView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(spacing: 16) {
      Text("PDF password")
        .font(.headline)
      Text("This file is encrypted. Enter a password to open it.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      SecureField("Password", text: $model.passwordAttempt)
        .textFieldStyle(.roundedBorder)
        .onSubmit { model.submitPassword() }
        .frame(width: 300)
      HStack(spacing: 12) {
        Button("Cancel") { model.dismissPasswordPrompt() }
        Button("Open") { model.submitPassword() }
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
  }
}

// MARK: - Manual Text Placement Sheet
private struct ManualTextSheet: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Add text to document")
        .font(.title3.weight(.semibold))
      Text("Creates a reversible visual overlay in the selected area.")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField("Text to place", text: $model.manualTextDraft)
        .textFieldStyle(.roundedBorder)
        .onSubmit { model.applyManualText() }

      HStack {
        Button("Cancel") { model.cancelManualTextPlacement() }
        Spacer()
        Button("Add Text") { model.applyManualText() }
          .buttonStyle(.borderedProminent)
          .disabled(model.manualTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(24)
    .frame(width: 380)
  }
}

// MARK: - Signature Sheet
private struct SignatureSheet: View {
  @Bindable var model: AppModel
  @State private var selectedTab = 0
  @State private var typedName = ""
  @State private var selectedFontIndex = 0
  @State private var saveForLater = false
  @State private var signatureLabel = ""

  private let scriptFonts = ["Zapfino", "Snell Roundhand", "Bradley Hand"]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Add your signature")
            .font(.title3.weight(.semibold))
          Text("Places a visual signature overlay.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Cancel") {
          model.isSignatureSheetPresented = false
          model.pendingSignatureRegion = nil
        }
      }
      .padding([.horizontal, .top], 24)
      .padding(.bottom, 12)

      Divider()

      Picker("Signature method", selection: $selectedTab) {
        Text("Draw").tag(0)
        Text("Type").tag(1)
        Text("Image").tag(2)
        if !model.savedSignatures.isEmpty {
          Text("Saved").tag(3)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 24)
      .padding(.vertical, 12)

      Group {
        if selectedTab == 0 {
          SignatureDrawTab(onApply: applySignature)
        } else if selectedTab == 1 {
          SignatureTypeTab(
            typedName: $typedName,
            selectedFontIndex: $selectedFontIndex,
            fontNames: scriptFonts,
            onApply: { applySignature(renderTypedSignature()) }
          )
        } else if selectedTab == 2 {
          SignatureImageTab(onApply: applySignature)
        } else {
          SignatureSavedTab(signatures: model.savedSignatures, onApply: applySignature)
        }
      }
      .frame(height: 200)

      Divider()

      HStack {
        Toggle("Save for future use", isOn: $saveForLater)
          .font(.caption)
        if saveForLater {
          TextField("Label (optional)", text: $signatureLabel)
            .textFieldStyle(.roundedBorder)
            .frame(width: 140)
            .font(.caption)
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
    }
    .frame(width: 500)
  }

  private func applySignature(_ imageData: Data) {
    guard let inspection = model.inspection,
      let pageIndex = model.pendingSignatureRegion?.pageIndex ?? inspection.pages.first?.pageIndex
    else { return }

    let bounds: PDFRect
    if let region = model.pendingSignatureRegion {
      bounds = region.bounds
    } else {
      let page = inspection.pages.indices.contains(model.selectedPageIndex)
        ? inspection.pages[model.selectedPageIndex] : inspection.pages[0]
      let w = page.bounds.width * 0.35
      let h = 60.0
      bounds = PDFRect(x: page.bounds.x + (page.bounds.width - w) / 2,
                       y: page.bounds.y + 60,
                       width: w, height: h)
    }
    model.applySignature(imageData, to: bounds, on: pageIndex)

    if saveForLater {
      let label = signatureLabel.isEmpty ? "Signature \(model.savedSignatures.count + 1)" : signatureLabel
      let dataURL = "data:image/png;base64,\(imageData.base64EncodedString())"
      model.savedSignatures.append(SavedSignature(label: label, dataURL: dataURL))
    }
  }

  private func renderTypedSignature() -> Data {
    let font = NSFont(name: scriptFonts[selectedFontIndex], size: 48)
      ?? NSFont.systemFont(ofSize: 48, weight: .light)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: NSColor.black
    ]
    let str = NSAttributedString(string: typedName.isEmpty ? "Signature" : typedName, attributes: attrs)
    let size = str.size()
    let image = NSImage(size: NSSize(width: size.width + 20, height: size.height + 12))
    image.lockFocus()
    str.draw(at: NSPoint(x: 10, y: 6))
    image.unlockFocus()
    return image.pngData ?? Data()
  }
}

private struct SignatureDrawTab: View {
  let onApply: (Data) -> Void
  @State private var strokes: [[CGPoint]] = []
  @State private var currentStroke: [CGPoint] = []

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        Canvas { ctx, size in
          for stroke in strokes + [currentStroke] {
            guard stroke.count > 1 else { continue }
            var path = Path()
            path.move(to: stroke[0])
            for pt in stroke.dropFirst() { path.addLine(to: pt) }
            ctx.stroke(path, with: .color(.primary), lineWidth: 2)
          }
        }
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { v in currentStroke.append(v.location) }
            .onEnded { _ in strokes.append(currentStroke); currentStroke = [] }
        )
        if strokes.isEmpty && currentStroke.isEmpty {
          Text("Draw your signature here")
            .foregroundStyle(.secondary)
            .font(.callout)
            .allowsHitTesting(false)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 24)

      HStack {
        Button("Clear") { strokes = []; currentStroke = [] }
          .buttonStyle(.bordered)
        Spacer()
        Button("Use signature") {
          onApply(renderStrokes())
        }
        .buttonStyle(.borderedProminent)
        .disabled(strokes.isEmpty)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 8)
    }
  }

  private func renderStrokes() -> Data {
    let size = CGSize(width: 452, height: 140)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.set()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
    NSColor.black.set()
    for stroke in strokes {
      guard stroke.count > 1 else { continue }
      let path = NSBezierPath()
      path.lineWidth = 2
      path.move(to: stroke[0])
      for pt in stroke.dropFirst() { path.line(to: pt) }
      path.stroke()
    }
    image.unlockFocus()
    return image.pngData ?? Data()
  }
}

private struct SignatureTypeTab: View {
  @Binding var typedName: String
  @Binding var selectedFontIndex: Int
  let fontNames: [String]
  let onApply: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      TextField("Type your name", text: $typedName)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .padding(.horizontal, 24)

      Picker("Style", selection: $selectedFontIndex) {
        ForEach(fontNames.indices, id: \.self) { idx in
          Text(fontNames[idx]).tag(idx)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal, 24)

      Spacer()

      HStack {
        Spacer()
        Button("Use signature", action: onApply)
          .buttonStyle(.borderedProminent)
          .disabled(typedName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 8)
    }
  }
}

private struct SignatureImageTab: View {
  let onApply: (Data) -> Void
  @State private var isImporterPresented = false
  @State private var loadedImage: NSImage?
  @State private var loadedData: Data?

  var body: some View {
    VStack(spacing: 8) {
      if let image = loadedImage {
        Image(nsImage: image)
          .resizable()
          .scaledToFit()
          .frame(maxHeight: 120)
          .padding(8)
      } else {
        Button("Choose an image…") {
          isImporterPresented = true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      HStack {
        if loadedImage != nil {
          Button("Choose another…") { isImporterPresented = true }
            .buttonStyle(.bordered)
        }
        Spacer()
        Button("Use signature") {
          if let data = loadedData { onApply(data) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(loadedData == nil)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 8)
    }
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: [.png, .jpeg],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let url = urls.first {
        if let data = try? Data(contentsOf: url), let img = NSImage(data: data) {
          loadedData = data
          loadedImage = img
        }
      }
    }
  }
}

private struct SignatureSavedTab: View {
  let signatures: [SavedSignature]
  let onApply: (Data) -> Void
  @State private var selectedSignatureID: UUID?

  var body: some View {
    VStack(spacing: 8) {
      if signatures.isEmpty {
        Text("No saved signatures")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(signatures, selection: $selectedSignatureID) { sig in
          HStack {
            Text(sig.label)
            Spacer()
            if let data = sig.signatureImageData, let img = NSImage(data: data) {
              Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(height: 30)
            }
          }
          .tag(sig.id)
        }
        .frame(maxHeight: 130)

        HStack {
          Spacer()
          Button("Use signature") {
            if let selectedID = selectedSignatureID,
               let sig = signatures.first(where: { $0.id == selectedID }),
               let data = sig.signatureImageData {
              onApply(data)
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(selectedSignatureID == nil)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
      }
    }
  }
}

public struct SettingsView: View {
  public init() {}
  public var body: some View {
    Form {
      Section {
        LabeledContent("Processing", value: "On this Mac")
        LabeledContent("Source files", value: "Never overwritten")
        LabeledContent("Provider", value: "PDFKit evaluation lane")
        Text("Export Copy creates a separate edited PDF; closing the window never saves changes into the source file.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } header: {
        Text("Safety")
      }
    }
    .formStyle(.grouped)
    .scenePadding()
    .frame(width: 420)
  }
}
