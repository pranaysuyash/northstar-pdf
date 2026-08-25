import PDFEditorCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

private enum SearchProjectionState: Equatable {
  case none
  case exact
  case approximate
  case unavailable

  var title: String {
    switch self {
    case .none: return "No highlight"
    case .exact: return "Exact highlight"
    case .approximate: return "Approximate highlight"
    case .unavailable: return "Highlight unavailable"
    }
  }

  var message: String {
    switch self {
    case .none: return ""
    case .exact: return "The selected search result is highlighted at its exact text range."
    case .approximate: return "The selected result is highlighted approximately because PDFKit could not prove the exact text range."
    case .unavailable: return "The selected result could not be projected into the PDF view. The result remains selected in the list."
    }
  }

  var symbolName: String {
    switch self {
    case .none: return "magnifyingglass"
    case .exact: return "checkmark.circle"
    case .approximate: return "exclamationmark.triangle"
    case .unavailable: return "questionmark.circle"
    }
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

private extension View {
  func accessibilityHelp(_ text: String) -> some View {
    accessibilityHint(text)
  }
}

struct ContentView: View {
  @Bindable var model: AppModel
  @Binding private var searchFocusEvent: Int
  @State private var searchProjectionState: SearchProjectionState = .none

  // Recovery view state is encoded by AppModel, but the model currently does
  // not expose a public coalesced view-state autosave hook. Do not call its
  // private saveDurableRecovery/autoSaveSession methods from the view layer.
  // The missing seam is a public model-owned scheduleViewStateAutosave() API.

  init(model: AppModel, searchFocusEvent: Binding<Int> = .constant(0)) {
    self.model = model
    self._searchFocusEvent = searchFocusEvent
  }

  var body: some View {
    Group {
      if let inspection = model.inspection {
        VStack(spacing: 0) {
          RecoveryStatusView(model: model)
          EditorView(
            model: model,
            inspection: inspection,
            searchFocusEvent: searchFocusEvent,
            searchProjectionState: $searchProjectionState
          )
        }
      } else {
        WelcomeView(open: requestOpenDocument)
      }
    }
    .toolbar {
      ToolbarItemGroup {
        Button("Open", systemImage: "folder") {
          requestOpenDocument()
        }
        .help("Open another PDF. The current document remains open until the new PDF is admitted.")
        .accessibilityHelp("Open another PDF without discarding the current document before the new PDF is admitted.")
        Button("Undo", systemImage: "arrow.uturn.backward") {
          model.undoLastEdit()
        }
        .disabled(!model.canUndo)
        Button("Redo", systemImage: "arrow.uturn.forward") {
          model.redoLastEdit()
        }
        .disabled(!model.canRedo)
        Button("Export Copy", systemImage: "square.and.arrow.down") {
          model.export()
        }
        .disabled(!canExportCopy(model))
        .help(exportCopyHelp(model))
        .accessibilityHelp(exportCopyHelp(model))
      }
      // MARK: Editor mode pill (D-010)
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
        .help("Choose your intent: Read (passive), Fill (complete form fields), Sign (place a signature), or Edit (full authoring).")
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
        .frame(width: 220)
      }
      ToolbarItem {
        Picker(
          "Scale",
          selection: Binding(
            get: { model.readerScaleMode },
            set: { model.setReaderScaleMode($0) }
          )
        ) {
          Text("Fit width").tag(ReaderScaleMode.fitWidth)
          Text("Fit page").tag(ReaderScaleMode.fitPage)
          Text("Zoom").tag(ReaderScaleMode.zoom)
        }
        .pickerStyle(.menu)
        .frame(width: 140)
      }
      ToolbarItem(placement: .status) {
        HStack(spacing: 6) {
          // Fill offer chip
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
            .transition(.scale.combined(with: .opacity))
            .help("Enter Fill mode to highlight and complete all form fields.")
          }
          // Fill progress in Fill mode
          if model.editorMode == .fill, let label = model.fillProgressLabel {
            HStack(spacing: 6) {
              if let progress = model.fillProgress {
                ProgressView(value: progress)
                  .progressViewStyle(.linear)
                  .frame(width: 80)
                  .tint(.accentColor)
              }
              Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Text(model.statusMessage ?? "Ready")
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
    .fileImporter(
      isPresented: $model.isImporterPresented,
      allowedContentTypes: [.pdf],
      allowsMultipleSelection: false
    ) { result in
      switch result {
      case .success(let urls):
        if let url = urls.first {
          openImportedPDF(url)
        }
      case .failure(let error):
        model.alertMessage = error.localizedDescription
      }
    }
    .alert(
      "PDF Editor",
      isPresented: Binding(
        get: { model.alertMessage != nil },
        set: { isPresented in
          if !isPresented { model.alertMessage = nil }
        }
      )
    ) {
      Button("OK") {
        model.alertMessage = nil
      }
    } message: {
      Text(model.alertMessage ?? "")
    }
    .sheet(isPresented: $model.isPasswordSheetPresented) {
      PasswordPromptView(model: model)
    }
    .sheet(isPresented: $model.isManualTextSheetPresented) {
      ManualTextSheet(model: model)
    }
    // D-010: Sign sheet
    .sheet(isPresented: $model.isSignatureSheetPresented) {
      SignatureSheet(model: model)
    }
    // D-010: Redaction commit L3 gate
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
        "This will permanently remove the content under \(count) marked region\(count == 1 ? "" : "s") from a new PDF copy. The original file is never overwritten.\n\nThis action cannot be undone."
      )
    }
  }
}

private struct RecoveryStatusView: View {
  @Bindable var model: AppModel

  private var hasRecoveryState: Bool {
    switch model.recoveryStatus {
    case .none:
      return !model.recoveryRecords.isEmpty || !model.recoveryDiagnostics.isEmpty
    case .available, .replayable, .metadataOnly, .corrupted, .saveFailed:
      return true
    }
  }

  private var statusTitle: String {
    switch model.recoveryStatus {
    case .none:
      return "No recovery available"
    case .available:
      return "Recovery available"
    case .replayable:
      return "Recovery restored"
    case .metadataOnly:
      return "Recovery metadata only"
    case .corrupted:
      return "Recovery needs attention"
    case .saveFailed:
      return "Recovery save failed"
    }
  }

  private var statusMessage: String {
    switch model.recoveryStatus {
    case .none:
      return "No readable recovery session is associated with this document."
    case .available:
      return "Saved recovery work is available for this document. Review the discovered session before continuing."
    case .replayable:
      return "The recovered edit session was trusted and restored."
    case .metadataOnly:
      return "Recovery metadata was found, but no edit payload was trusted or applied."
    case .corrupted:
      return "One or more recovery records could not be read or validated."
    case .saveFailed:
      return "The latest recovery save did not complete. Earlier recovery data may still be available."
    }
  }

  private var statusColor: Color {
    switch model.recoveryStatus {
    case .none, .available:
      return .secondary
    case .replayable:
      return .green
    case .metadataOnly, .corrupted, .saveFailed:
      return .orange
    }
  }

  var body: some View {
    if hasRecoveryState {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Label("Recovery", systemImage: "arrow.clockwise.circle")
            .font(.subheadline.weight(.semibold))
          Text(statusTitle)
            .font(.caption.weight(.medium))
            .foregroundStyle(statusColor)
          Spacer()
        }

        Text(statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)

        if !model.recoveryRecords.isEmpty {
          Text("Discovered recovery sessions")
            .font(.caption.weight(.medium))
          ForEach(Array(model.recoveryRecords.enumerated()), id: \.offset) { _, record in
            Text("Session \(record.session.sessionID.uuidString.prefix(8))")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityLabel("Recovery session \(record.session.sessionID.uuidString)")
          }
        }

        ForEach(model.recoveryDiagnostics, id: \.self) { diagnostic in
          Label(diagnostic, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.orange.opacity(0.08))
      .overlay(alignment: .bottom) {
        Divider()
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Recovery status")
      .accessibilityValue("\(statusTitle). \(statusMessage)")
    }
  }
}


private extension ContentView {
  func openImportedPDF(_ url: URL) {
    // The current session remains untouched while the importer is open. A
    // lightweight PDFKit admission check also prevents malformed or empty
    // files from reaching the mutating AppModel load path.
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

  func requestOpenDocument() {
    let decision = model.lifecycleDecision(for: .openDocument)
    guard decision.disposition == .confirmBeforeDiscardingChanges else {
      model.isImporterPresented = true
      return
    }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "This document has unexported changes."
    alert.informativeText = "PDF Editor uses an export-only workflow: Export Copy... creates a separate edited PDF, never overwrites the source, and does not save changes in place. Choose Continue to Open to select another PDF without discarding this document before the new file is admitted, or Cancel to keep working."
    alert.addButton(withTitle: "Continue to Open")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    model.isImporterPresented = true
  }
}

private struct WelcomeView: View {
  let open: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 54, weight: .light))
        .foregroundStyle(.tint)
      Text("Complete PDFs without disturbing the source")
        .font(.title2.weight(.semibold))
      Text(
        "Open a PDF, review native fields and suggestions, and run reading/navigation workflows with bounded local export."
      )
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 520)
      Button("Open a PDF…", action: open)
        .keyboardShortcut(.defaultAction)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(40)
  }
}

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
        .onSubmit {
          model.submitPassword()
        }
        .frame(width: 320)
      HStack(spacing: 12) {
        Button("Cancel") {
          model.dismissPasswordPrompt()
        }
        Button("Open") {
          model.submitPassword()
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(24)
  }
}

private struct ManualTextSheet: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Add text to the document")
        .font(.title3.weight(.semibold))
      Text(
        "This creates a reversible overlay in the selected area. It does not claim that the source PDF contains a native form field."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      TextField("Text to place", text: $model.manualTextDraft)
        .textFieldStyle(.roundedBorder)
        .disabled(!canEditAnnotations(model))
        .accessibilityHelp(
          canEditAnnotations(model)
            ? "Enter text for a reversible document overlay."
            : "Unavailable because this PDF does not allow document annotations."
        )
        .onSubmit { model.applyManualText() }
      HStack {
        Button("Cancel") {
          model.cancelManualTextPlacement()
        }
        Spacer()
        Button("Add text") {
          model.applyManualText()
        }
        .buttonStyle(.borderedProminent)
        .disabled(
          !canEditAnnotations(model)
            || model.manualTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityHelp(
          canEditAnnotations(model)
            ? "Adds a reversible text overlay."
            : "Unavailable because this PDF does not allow document annotations."
        )
      }
    }
    .padding(24)
    .frame(width: 420)
  }
}

// MARK: - Signature Sheet (D-010)

/// The signature entry sheet for Sign mode.
///
/// Presents four tabs: Draw (freehand Canvas), Type (stylised text), Image
/// (file picker), and Saved (previously stored signatures).
///
/// Storage: interim app-sandboxed file; v2 migrates to macOS Keychain per D-010.
/// The user must explicitly check "Save for later" — no silent persistence.
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
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Add your signature")
            .font(.title3.weight(.semibold))
          Text("This places a visual signature overlay. For legally binding signatures, use a certified e-signature service.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
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

      // Tab picker
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

      // Tab content
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

      // Save for later
      HStack {
        Toggle("Save this signature for future use", isOn: $saveForLater)
          .font(.caption)
        if saveForLater {
          TextField("Label (optional)", text: $signatureLabel)
            .textFieldStyle(.roundedBorder)
            .frame(width: 160)
            .font(.caption)
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
    }
    .frame(width: 520)
  }

  private func applySignature(_ imageData: Data) {
    guard let inspection = model.inspection,
      let pageIndex = model.pendingSignatureRegion?.pageIndex ?? inspection.pages.first?.pageIndex
    else { return }

    // Place at the candidate's bounds or default to centre-bottom of current page
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
    // Render the typed name in the chosen script font to an NSImage, then PNG data.
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
    let size = CGSize(width: 472, height: 140)
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
      TextField("Your name", text: $typedName)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .padding(.horizontal, 24)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(fontNames.indices, id: \.self) { idx in
            Text(typedName.isEmpty ? "Your name" : typedName)
              .font(Font.custom(fontNames[idx], size: 32))
              .foregroundStyle(selectedFontIndex == idx ? Color.accentColor : Color.primary)
              .padding(8)
              .background(selectedFontIndex == idx ? Color.accentColor.opacity(0.1) : Color.clear)
              .clipShape(RoundedRectangle(cornerRadius: 6))
              .onTapGesture { selectedFontIndex = idx }
          }
        }
        .padding(.horizontal, 24)
      }

      HStack {
        Spacer()
        Button("Use this style") { onApply() }
          .buttonStyle(.borderedProminent)
          .disabled(typedName.trimmingCharacters(in: .whitespaces).isEmpty)
        Spacer()
      }
      .padding(.bottom, 8)
    }
  }
}

private struct SignatureImageTab: View {
  let onApply: (Data) -> Void
  @State private var isImporting = false
  @State private var previewData: Data?

  var body: some View {
    VStack(spacing: 12) {
      if let data = previewData, let img = NSImage(data: data) {
        Image(nsImage: img)
          .resizable()
          .scaledToFit()
          .frame(maxHeight: 100)
          .padding(.horizontal, 24)
      } else {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
          .frame(height: 100)
          .overlay(Text("Drop a PNG or JPEG here, or click Choose").foregroundStyle(.secondary).font(.callout))
          .padding(.horizontal, 24)
      }
      HStack {
        Button("Choose image…") { isImporting = true }
          .buttonStyle(.bordered)
        Spacer()
        Button("Use image") { if let d = previewData { onApply(d) } }
          .buttonStyle(.borderedProminent)
          .disabled(previewData == nil)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 8)
    }
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: [.png, .jpeg],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let url = urls.first {
        previewData = try? Data(contentsOf: url)
      }
    }
  }
}

private struct SignatureSavedTab: View {
  let signatures: [SavedSignature]
  let onApply: (Data) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        ForEach(signatures) { sig in
          HStack {
            if let data = Data(base64Encoded: sig.dataURL.components(separatedBy: ",").last ?? ""),
               let img = NSImage(data: data)
            {
              Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
              Text(sig.label).font(.caption.weight(.medium))
              Text(sig.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Use") {
              if let raw = sig.dataURL.components(separatedBy: ",").last,
                 let data = Data(base64Encoded: raw) {
                onApply(data)
              }
            }
            .buttonStyle(.bordered)
          }
          .padding(.horizontal, 24)
          Divider()
        }
      }
    }
  }
}

private extension NSImage {
  var pngData: Data? {
    guard let tiff = tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff)
    else { return nil }
    return bitmap.representation(using: .png, properties: [:])
  }
}

private struct TemplateCompletionEntryReviewCard: View {
  @Bindable var model: AppModel
  let entry: PDFTemplateCompletionEntry

  private var valueApprovalIsOn: Bool {
    entry.valueReview == .approved && entry.profileValueApproval?.state == .approved
  }

  private var valueApprovalDisabled: Bool {
    entry.profileRevisionID == nil
      || entry.value == nil
      || model.templateValueEditorKind(for: entry.mappingID) == .assetReference
      || model.templateValueEditorKind(for: entry.mappingID) == .missing
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Label(entry.semanticKey, systemImage: entry.mappingReview == .approved ? "checkmark.circle.fill" : "circle")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(entry.target.kind.rawValue)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Text("Page \(entry.target.pageIndex + 1) · x \(entry.target.region.rect.x, specifier: "%.1f") · y \(entry.target.region.rect.y, specifier: "%.1f") · \(entry.target.region.rect.width, specifier: "%.1f") × \(entry.target.region.rect.height, specifier: "%.1f")")
        .font(.caption2)
        .foregroundStyle(.secondary)

      if entry.target.kind == .nativeField {
        Label(
          entry.resolvedTargetID.map { "Resolved native field: \($0)" } ?? "Native field target unresolved",
          systemImage: entry.resolvedTargetID == nil ? "exclamationmark.triangle" : "link")
          .font(.caption2)
          .foregroundStyle(entry.resolvedTargetID == nil ? .orange : .secondary)
      } else {
        Label("Static region remains an overlay target, not a native form field", systemImage: "square.dashed")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Toggle(
        isOn: Binding(
          get: { entry.mappingReview == .approved },
          set: { model.reviewTemplateCompletionMapping(entry.mappingID, approved: $0) }
        )
      ) {
        Text("Approve mapping")
      }
      .accessibilityHelp("Approve only the target association. This does not approve the profile value.")

      switch model.templateValueEditorKind(for: entry.mappingID) {
      case .boolean:
        Toggle(
          "Profile boolean: \(model.templateCompletionBooleanValue(for: entry.mappingID) ? "true" : "false")",
          isOn: Binding(
            get: { model.templateCompletionBooleanValue(for: entry.mappingID) },
            set: { model.updateTemplateCompletionBoolean(entry.mappingID, value: $0) }
          )
        )
        .disabled(entry.profileRevisionID == nil)
      case .assetReference:
        Label("Asset reference needs an explicit asset picker before it can be applied", systemImage: "photo.badge.exclamationmark")
          .font(.caption)
          .foregroundStyle(.orange)
      case .missing:
        Label("No profile value resolved for this semantic key", systemImage: "questionmark.circle")
          .font(.caption)
          .foregroundStyle(.orange)
      case .text, .choice:
        TextField(
          model.templateValueEditorKind(for: entry.mappingID) == .choice ? "Profile choice" : "Profile value",
          text: Binding(
            get: { model.templateValueDrafts[entry.mappingID] ?? "" },
            set: { model.updateTemplateCompletionValue(entry.mappingID, value: $0) }
          ))
          .textFieldStyle(.roundedBorder)
          .disabled(entry.profileRevisionID == nil)
      }

      Toggle(
        isOn: Binding(
          get: { valueApprovalIsOn },
          set: { model.reviewTemplateCompletionValue(entry.mappingID, approved: $0) }
        )
      ) {
        Text("Approve exact value for this profile revision")
      }
      .disabled(valueApprovalDisabled)
      .accessibilityHelp("Approve the displayed value from the selected profile revision. Editing the value revokes this approval.")

      Text("Mapping: \(entry.mappingReview.rawValue) · Value: \(entry.valueReview.rawValue) · Profile revision: \(entry.profileRevisionID?.uuidString.prefix(8) ?? "none")")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(8)
    .background(Color.accentColor.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
  }
}

private struct EditorView: View {
  let model: AppModel
  let inspection: DocumentInspection
  let searchFocusEvent: Int
  @Binding var searchProjectionState: SearchProjectionState

  var body: some View {
    VStack(spacing: 10) {
      ReaderControlBar(
        model: model,
        focusEvent: searchFocusEvent,
        projectionState: searchProjectionState
      )
      HSplitView {
        PageList(model: model, inspection: inspection)
          .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)
        PDFKitView(
          document: model.liveDocument,
          projectionRevision: model.documentProjectionRevision,
          pageIndex: model.selectedPageIndex,
          viewMode: model.readerViewMode,
          scaleMode: model.readerScaleMode,
          zoom: model.readerZoom,
          rotation: model.readerRotation,
          selectedSearchMatch: model.selectedSearchMatch,
          searchProjectionState: $searchProjectionState,
          selectedCandidate: model.selectedCandidate,
          selectedField: model.selectedField,
          isManualPlacementMode: model.isManualPlacementMode,
          onManualPlacement: { pageIndex, point in
            model.receiveManualPlacement(pageIndex: pageIndex, point: point)
          },
          onDirectEdit: { pageIndex, point in
            model.beginDirectTextPlacement(pageIndex: pageIndex, point: point)
          }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("PDF document page \(model.selectedPageIndex + 1)")
        .accessibilityValue(
          model.selectedSearchMatch.map {
            "Search result on page \($0.pageIndex + 1): \($0.snippet)"
          }
            ?? model.selectedCandidate.map {
              "Selected suggested area on page \($0.pageIndex + 1), \($0.entryMode.rawValue)"
            }
            ?? model.selectedField.map {
              "Selected native field \($0.name) on page \($0.pageIndex + 1)"
            }
            ?? "Page \(model.selectedPageIndex + 1)"
        )
        .accessibilityHint(
          (model.isManualPlacementMode
            ? "Manual placement mode. Press Return or Space to place text at the current page center, or click the page."
            : "Use the page list, inspector, or search results to change the selected document element.")
            + " " + searchProjectionState.message
        )
        .frame(minWidth: 520)
        InspectorView(model: model, inspection: inspection)
          .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
      }
      .padding(.horizontal, 8)
    }
  }
}

private struct ReaderControlBar: View {
  @Bindable var model: AppModel
  let focusEvent: Int
  let projectionState: SearchProjectionState

  var body: some View {
    VStack(spacing: 10) {
      HStack {
        Text("Page")
        TextField("Page", text: $model.pageJumpInput)
          .textFieldStyle(.roundedBorder)
          .frame(width: 72)
          .onSubmit { model.runPageJump() }
        Button("Go") {
          model.runPageJump()
        }
        Spacer()
        Text("Zoom")
        Slider(
          value: Binding(
            get: { model.readerZoom },
            set: { model.setZoom($0) }
          ),
          in: 0.25...3.0
        )
        .frame(width: 160)
        Text(model.readerZoom, format: .number.precision(.fractionLength(2)))
          .frame(width: 52, alignment: .trailing)
          .monospacedDigit()
        Button("−") {
          model.setZoom(model.readerZoom - 0.1)
        }
        Button("+") {
          model.setZoom(model.readerZoom + 0.1)
        }
        Button("Rotate ⟲") {
          model.rotateLeft()
        }
        Button("Rotate ⟳") {
          model.rotateRight()
        }
        Button("Copy page text") {
          model.copyCurrentPageText()
        }
        .disabled(!canCopyText(model))
        .help(
          canCopyText(model)
            ? "Copy text from the selected page."
            : "This PDF does not allow text copying."
        )
        .accessibilityHelp(
          canCopyText(model)
            ? "Copies text from the selected page."
            : "Unavailable because this PDF's permissions do not allow text copying."
        )
      }
      HStack {
        SearchField(model: model, focusEvent: focusEvent, projectionState: projectionState)
        Spacer()
        Text("Labels and access")
          .foregroundStyle(.secondary)
          .font(.callout)
      }
      Divider()
    }
    .padding(.horizontal, 10)
    .padding(.top, 8)
  }
}

private struct SearchField: View {
  @Bindable var model: AppModel
  let focusEvent: Int
  let projectionState: SearchProjectionState
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 8) {
      TextField("Search in document", text: $model.searchQuery)
        .textFieldStyle(.roundedBorder)
        .focused($isFocused)
        .disabled(!canCopyText(model))
        .accessibilityHelp(
          canCopyText(model)
            ? "Search text in this PDF."
            : "Unavailable because this PDF's permissions do not allow text copying."
        )
        .onSubmit { model.runSearch() }
        .onChange(of: focusEvent) { _, _ in
          isFocused = true
        }
      Button("Find") {
        model.runSearch()
      }
      .disabled(!canCopyText(model))
      .accessibilityHelp(
        canCopyText(model)
          ? "Run the document search."
          : "Unavailable because this PDF's permissions do not allow text copying."
      )
      if model.canClearSearch {
        Button("Clear") {
          model.clearSearch()
        }
      }
      if !model.searchMatches.isEmpty {
        Text("\(model.searchMatches.count) matches")
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("Prev") { model.selectPreviousSearchMatch() }
          .disabled(!canCopyText(model))
          .help(
            canCopyText(model)
              ? "Select the previous search result."
              : "Unavailable because this PDF does not allow text copying."
          )
        Button("Next") { model.selectNextSearchMatch() }
          .disabled(!canCopyText(model))
          .help(
            canCopyText(model)
              ? "Select the next search result."
              : "Unavailable because this PDF does not allow text copying."
          )
        if let selected = model.selectedSearchMatchIndex {
          Text("#\(selected + 1)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}

private struct PageList: View {
  let model: AppModel
  let inspection: DocumentInspection

  var body: some View {
    List {
      Section("Pages (thumbnails)") {
        ForEach(inspection.pages) { page in
          Button {
            model.selectedPageIndex = page.pageIndex
          } label: {
            HStack {
              Image(systemName: model.selectedPageIndex == page.pageIndex ? "doc.fill" : "doc")
              VStack(alignment: .leading) {
                Text("Page \(page.pageLabel)")
                Text("\(page.characterCount) chars")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                Text("Media: \(Int(page.bounds.width))x\(Int(page.bounds.height))")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .monospacedDigit()
                if let crop = page.cropBox {
                  Text("Crop: \(Int(crop.width))x\(Int(crop.height))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
              }
              Spacer()
              if page.hasSelectableText {
                Image(systemName: "text.alignleft")
                  .foregroundStyle(.secondary)
                  .help("Selectable text available")
              }
            }
          }
          .buttonStyle(.plain)
          .padding(.vertical, 2)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Page \(page.pageLabel), \(page.characterCount) characters, \(page.hasSelectableText ? "has selectable text" : "no selectable text")")
          .accessibilityHint("Selects page \(page.pageLabel)")
          .accessibilityAddTraits(model.selectedPageIndex == page.pageIndex ? [.isSelected, .isButton] : [.isButton])
        }
      }
      Section("Session") {
        LabeledContent("Native fields", value: "\(inspection.fields.count)")
        LabeledContent("Suggestions", value: "\(inspection.candidates.count)")
        LabeledContent("Edits", value: "\(model.operations.count)")
        LabeledContent("Current page", value: "\(model.selectedPageLabel)")
      }
      Section("Security") {
        LabeledContent("Encrypted", value: inspection.security.isEncrypted ? "Yes" : "No")
        LabeledContent("Locked", value: inspection.security.isLocked ? "Yes" : "No")
        if inspection.security.isLocked {
          LabeledContent(
            "Password flow", value: inspection.security.requiresPassword ? "Required" : "Open")
        }
      }
    }
    .listStyle(.sidebar)
  }
}

private struct InspectorView: View {
  let model: AppModel
  let inspection: DocumentInspection
  @State private var fieldDraft = ""
  @State private var overlayDraft = ""
  @State private var choiceCellIndex = 0
  @State private var templateDisplayName = "Reviewed local layout"

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        Text("Review and edit")
          .font(.title3.weight(.semibold))

        templateSection
        profileSection
        fieldSection
        candidateSection
        searchSection
        linkAndOutlineSection
        metadataSection
        validationSection
      }
      .padding(16)
    }
    .onChange(of: model.selectedFieldID, initial: true) { _, _ in
      fieldDraft = model.selectedField.map { model.currentValue(for: $0) } ?? ""
    }
    .onChange(of: model.selectedCandidateID, initial: true) { _, _ in
      overlayDraft = ""
      choiceCellIndex = 0
    }
  }

  private var profileSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Profile & Bulk Fill", systemImage: "person.crop.circle")
        .font(.headline)

      if let profile = model.currentProfile {
        // Active profile
        HStack {
          Text(profile.displayName)
            .font(.subheadline.weight(.medium))
          Spacer()
          Button("Switch") {
            model.currentProfile = nil
          }
          .font(.caption)
          Button("Lock") {
            model.lockProfileVault()
          }
          .font(.caption)
        }
        .padding(8)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(6)

        // Profile fields
        ForEach(StandardSemanticKey.allCases, id: \.self) { key in
          let value = profile.value(for: key.rawValue) ?? ""
          HStack {
            Text(key.displayName)
              .font(.caption)
              .frame(width: 80, alignment: .trailing)
              .foregroundStyle(.secondary)
            TextField("—", text: Binding(
              get: { value },
              set: { model.updateProfileValue($0, for: key.rawValue) }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.caption)
          }
        }

        Divider()

        // Bulk fill actions
        HStack {
          Button("Preview Fill") {
            model.previewBulkFill()
          }
          .buttonStyle(.bordered)
          .disabled(model.inspection == nil)

          if let result = model.bulkFillResult, result.totalMatches > 0 {
            Button("Apply \(result.totalMatches) Field(s)") {
              model.applyBulkFill()
            }
            .buttonStyle(.borderedProminent)
          }
        }

        if let result = model.bulkFillResult {
          Text("\(result.totalMatches) matched · \(result.unmatchedFields.count) unmatched")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Button("Save Profile") {
          model.saveCurrentProfile()
        }
        .font(.caption)

      } else {
        if !model.isProfileVaultUnlocked {
          Button("Unlock encrypted profile vault") {
            model.unlockProfileVault()
          }
          .buttonStyle(.borderedProminent)
          Text("Profile values remain unavailable until the local vault is explicitly unlocked.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        // No profile selected — show list or create
        if !model.isProfileVaultUnlocked {
          EmptyView()
        } else if model.availableProfiles.isEmpty {
          Text("No profiles yet. Create one to enable bulk fill.")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
          ForEach(model.availableProfiles, id: \.profileID) { profile in
            Button {
              model.loadProfile(profileID: profile.profileID)
            } label: {
              HStack {
                Image(systemName: "person.circle")
                Text(profile.displayName)
                Spacer()
                Text("\(profile.values.count) fields")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .buttonStyle(.plain)
          }
        }

        Divider()

        NewProfileButton { name in
          model.createProfile(displayName: name)
        }
      }
    }
  }

  private var templateSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Reviewed completion template", systemImage: "checklist")
        .font(.headline)
      Text("Mapping approval and profile-value approval are separate. No template operation is created until both decisions are bound to this source and profile revision.")
        .font(.caption)
        .foregroundStyle(.secondary)

      TextField("Template display name", text: $templateDisplayName)
        .textFieldStyle(.roundedBorder)
        .help("The display name is local template metadata. Source bytes and profile values are not copied into the template.")

      HStack(spacing: 8) {
        Button("Capture layout") {
          model.captureTemplateReview(displayName: templateDisplayName)
        }
        .buttonStyle(.bordered)
        .disabled(model.inspection == nil || templateDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button(model.templateSaveButtonTitle) {
          model.saveTemplateRevision()
        }
        .buttonStyle(.bordered)
        .disabled(model.templateContract == nil)
        Button("Unlock") {
          model.unlockTemplateVault()
        }
        .buttonStyle(.bordered)
        Button("Find local matches") {
          model.findLocalTemplateMatches()
        }
        .buttonStyle(.bordered)
        .disabled(!model.isTemplateVaultUnlocked)
        Button("Import") {
          model.importTemplate()
        }
        .buttonStyle(.bordered)
        .disabled(!model.isTemplateVaultUnlocked)
        Button("Export") {
          model.exportTemplate()
        }
        .buttonStyle(.bordered)
        .disabled(!model.isTemplateVaultUnlocked || model.templateContract == nil)
      }

      if model.canSaveValidatedTemplateRevision {
        Text("Strict export validation passed. Saving will create one immutable child revision and append one pending learning event as applied.")
          .font(.caption)
          .foregroundStyle(.green)
      } else if model.pendingValidatedTemplateRevision != nil {
        Text("A proposed revision exists but is not currently saveable because the edit ledger or validation state changed.")
          .font(.caption)
          .foregroundStyle(.orange)
      }

      if let match = model.templateIndexMatch {
        VStack(alignment: .leading, spacing: 4) {
          Text("Local index: \(match.state.rawValue) · \(match.candidates.count) candidate(s) · \(match.abstained ? "abstained" : "review required")")
            .font(.caption)
          ForEach(match.candidates, id: \.entry.revisionID) { candidate in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(candidate.entry.displayName)
                Text("\(candidate.state.rawValue) · score \(candidate.score, specifier: "%.3f") · \(candidate.entry.revisionID.uuidString.prefix(8))")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button("Review") {
                model.loadTemplateRevision(templateID: candidate.entry.templateID, revisionID: candidate.entry.revisionID)
              }
              .buttonStyle(.bordered)
            }
          }
          ForEach(match.reasons, id: \.self) { reason in
            Text(reason)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
      }

      if let template = model.templateContract {
        LabeledContent(
          "Template state",
          value: "\(template.payload.lifecycle.rawValue) · \(template.payload.mappings.count) mapping(s)")
          .font(.caption)

        VStack(alignment: .leading, spacing: 3) {
          Text("Source-bound evidence")
            .font(.caption.weight(.semibold))
          Text("Layout fingerprint: \(template.payload.fingerprint.layoutFingerprint.prefix(16))...")
          Text("Source digests retained: \(template.payload.fingerprint.exactSourceDigests.count) · privacy: \(template.payload.privacyMode.rawValue)")
          Text("Template revision: \(template.payload.revisionID.uuidString.prefix(8)) · parent: \(template.payload.parentRevisionID?.uuidString.prefix(8) ?? "none")")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))

        if let diff = model.templateRevisionDiff {
          Text("Revision diff: +\(diff.exactSourceDigestsAdded.count) source variant(s), \(diff.mappingChanges.count) mapping change(s)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          ForEach(diff.mappingChanges) { change in
            Text("• \(change.change.rawValue) mapping \(change.id.uuidString.prefix(8))")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }

        if !model.templateLearningEvents.isEmpty {
          Text("Learning journal")
            .font(.caption.weight(.semibold))
          ForEach(model.templateLearningEvents) { event in
            Text("\(event.kind.rawValue) · \(event.status.rawValue) · source \(event.sourceDigest.prefix(12))...")
              .font(.caption2)
              .foregroundStyle(event.status == .pending ? .orange : .secondary)
          }
          if model.canSaveValidatedTemplateRevision {
            Text("A validated completion can migrate pending corrections into one immutable child revision.")
              .font(.caption2)
              .foregroundStyle(.green)
          }
        }

        ForEach(model.templateMappings) { mapping in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Toggle(
              isOn: Binding(
                get: { mapping.status == .confirmed },
                set: { model.reviewTemplateMapping(mapping.id, approved: $0) }
              )
            ) {
              VStack(alignment: .leading, spacing: 2) {
                Text(mapping.semanticKey)
                Text("Page \(mapping.target.pageIndex + 1) · \(mapping.target.kind.rawValue) · \(mapping.status.rawValue)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .disabled(template.payload.lifecycle != .draft)
          }
          .padding(.vertical, 2)
        }

        if template.payload.lifecycle == .draft {
          let reviewed = model.templateMappings.allSatisfy { $0.status != .proposed }
          Button("Activate reviewed mappings") {
            model.activateTemplateReview()
          }
          .buttonStyle(.borderedProminent)
          .disabled(!reviewed || !model.templateMappings.contains(where: \.isApproved))
        } else {
          Button("Prepare completion review") {
            model.prepareTemplateCompletionReview()
          }
          .buttonStyle(.borderedProminent)
          .disabled(!model.isProfileVaultUnlocked || model.currentProfile == nil)
          Text(model.isProfileVaultUnlocked
            ? "Current profile: \(model.currentProfile?.displayName ?? "none")"
            : "Unlock the profile vault and select a profile before resolving values.")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }

      if !model.templateReviewableEntries.isEmpty {
        Divider()
        Text("Completion review")
          .font(.subheadline.weight(.semibold))
        Text("\(model.templateCompletionApprovedMappingCount)/\(model.templateReviewableEntries.count) mappings approved · \(model.templateCompletionApprovedValueCount)/\(model.templateReviewableEntries.count) values approved")
          .font(.caption)
          .foregroundStyle(.secondary)
        if let proposal = model.templateCompletionProposal {
          Text("Match: \(proposal.matchState.rawValue) · source \(proposal.sourceDigest.prefix(12))... · session \(proposal.sessionID.uuidString.prefix(8))")
            .font(.caption2)
            .foregroundStyle(.secondary)
          ForEach(proposal.reasons, id: \.self) { reason in
            Label(reason, systemImage: "info.circle")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        ForEach(model.templateReviewableEntries) { entry in
          VStack(alignment: .leading, spacing: 7) {
            Toggle(
              isOn: Binding(
                get: { entry.mappingReview == .approved },
                set: { model.reviewTemplateCompletionMapping(entry.mappingID, approved: $0) }
              )
            ) {
              Text("Approve mapping · \(entry.semanticKey)")
            }
            .accessibilityHelp("Approve only the target association. This does not approve the profile value.")

            TextField(
              "Profile value",
              text: Binding(
                get: { model.templateValueDrafts[entry.mappingID] ?? "" },
                set: { model.updateTemplateCompletionValue(entry.mappingID, value: $0) }
              ))
              .textFieldStyle(.roundedBorder)
              .disabled(entry.profileRevisionID == nil)

            Toggle(
              isOn: Binding(
                get: { entry.valueReview == .approved && entry.profileValueApproval?.state == .approved },
                set: { model.reviewTemplateCompletionValue(entry.mappingID, approved: $0) }
              )
            ) {
              Text("Approve exact value for this profile revision")
            }
            .accessibilityHelp("Approve the displayed value from the selected profile revision. Editing the value revokes this approval.")

            Text("Mapping: \(entry.mappingReview.rawValue) · Value: \(entry.valueReview.rawValue) · Profile revision: \(entry.profileRevisionID?.uuidString.prefix(8) ?? "none")")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(8)
          .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
        }

        Button("Apply reviewed completion") {
          model.applyTemplateCompletion()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!(model.templateCompletionProposal?.isReadyToMaterialize ?? false))
        Text("Apply remains disabled until every mapping and every exact profile value is independently approved.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(10)
    .background(Color.accentColor.opacity(0.04))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var fieldSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Native fields", systemImage: "checkmark.square")
        .font(.headline)
      if inspection.fields.isEmpty {
        Text("No native fields were found. This PDF may use static entry regions only.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(inspection.fields) { field in
          Button {
            model.selectedFieldID = field.id
          } label: {
            HStack {
              Image(
                systemName: model.selectedFieldID == field.id ? "checkmark.circle.fill" : "circle")
              VStack(alignment: .leading) {
                Text(field.name)
                Text("Page \(field.pageIndex + 1) · \(field.kind.rawValue)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
            }
          }
          .buttonStyle(.plain)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Native field \(field.name)")
          .accessibilityValue("Page \(field.pageIndex + 1), \(field.kind.rawValue)")
          .accessibilityHint("Selects this native field for review and editing.")
          .accessibilityAddTraits(model.selectedFieldID == field.id ? [.isSelected] : [])
        }
        if let field = model.selectedField {
          if field.kind == .button {
            let options = model.buttonOptions(for: field)
            if options.count > 1 {
              Picker("Selected option", selection: $fieldDraft) {
                ForEach(options, id: \.self) { option in
                  Text(option).tag(option)
                }
              }
              .pickerStyle(.menu)
              .disabled(!(model.inspection?.permissions.canModify ?? false))
              .accessibilityHelp(
                (model.inspection?.permissions.canModify ?? false)
                  ? "Choose the native button option."
                  : "Unavailable because this PDF does not allow modifications."
              )
            } else {
              Toggle(
                "Checked",
                isOn: Binding(
                  get: { ["1", "true", "yes", "on", "checked"].contains(fieldDraft.lowercased()) },
                  set: { fieldDraft = $0 ? (options.first ?? "Yes") : "false" }
                ))
                .disabled(!(model.inspection?.permissions.canModify ?? false))
                .accessibilityHelp(
                  (model.inspection?.permissions.canModify ?? false)
                    ? "Change the native button value."
                    : "Unavailable because this PDF does not allow modifications."
                )
            }
          } else if field.kind == .choice && !field.choices.isEmpty {
            Picker("Selected option", selection: $fieldDraft) {
              Text("Empty").tag("")
              ForEach(field.choices, id: \.self) { option in
                Text(option).tag(option)
              }
            }
            .pickerStyle(.menu)
            .disabled(!(model.inspection?.permissions.canModify ?? false))
            .accessibilityHelp(
              (model.inspection?.permissions.canModify ?? false)
                ? "Choose the native field option."
                : "Unavailable because this PDF does not allow modifications."
            )
          } else {
            TextField("Field value", text: $fieldDraft)
              .disabled(!(model.inspection?.permissions.canModify ?? false))
              .accessibilityHelp(
                (model.inspection?.permissions.canModify ?? false)
                  ? "Edit the native field value."
                  : "Unavailable because this PDF does not allow modifications."
              )
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                model.applyFieldValue(fieldDraft)
              }
          }
          Button("Apply native field") {
            model.applyFieldValue(fieldDraft)
          }
          .disabled(
            field.kind == .signature
              || !(model.inspection?.permissions.canModify ?? false)
          )
          .help(
            field.kind == .signature
              ? "Signature fields are not edited in this lane."
              : (model.inspection?.permissions.canModify ?? false
                ? "Apply the selected native field value."
                : "Unavailable because this PDF does not allow modifications.")
          )
          .accessibilityHelp(
            field.kind == .signature
              ? "Unavailable because signature fields are not edited in this lane."
              : (model.inspection?.permissions.canModify ?? false
                ? "Applies the selected native field value."
                : "Unavailable because this PDF does not allow modifications.")
          )
        }
      }
    }
  }

  private var candidateSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Suggested areas (\(model.activeCandidates.count))", systemImage: "scope")
          .font(.headline)
        Spacer()
        Button("OCR Page") {
          model.runOCROnSelectedPage()
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .disabled(!canCopyText(model))
        .help(
          canCopyText(model)
            ? "Run local OCR on the selected page."
            : "Unavailable because this PDF's permissions do not allow text extraction."
        )
        .accessibilityHelp(
          canCopyText(model)
            ? "Runs local OCR on the selected page."
            : "Unavailable because this PDF's permissions do not allow text extraction."
        )
      }
      Text(
        "These are interpreted regions, not guaranteed fields. Review the label and geometry before applying text. Double-click the page to place text directly."
      )
      .font(.callout)
      .foregroundStyle(.secondary)
      HStack(spacing: 8) {
          Button("Add text manually", systemImage: "plus.circle") {
            model.beginManualTextPlacement()
          }
          .disabled(!canEditAnnotations(model))
          .accessibilityHelp(
            canEditAnnotations(model)
              ? "Starts reversible text overlay placement."
              : "Unavailable because this PDF does not allow document annotations."
          )
        .buttonStyle(.borderedProminent)
        if model.isManualPlacementMode {
          Button("Cancel placement") {
            model.cancelManualTextPlacement()
          }
          .buttonStyle(.bordered)
        }
      }
      if !model.activeCandidates.isEmpty {
        HStack(spacing: 8) {
          Button("Previous", systemImage: "chevron.left") {
            model.selectPreviousCandidate()
          }
          .font(.caption)
          .keyboardShortcut("[", modifiers: .command)
          Button("Next", systemImage: "chevron.right") {
            model.selectNextCandidate()
          }
          .font(.caption)
          .keyboardShortcut("]", modifiers: .command)
        }
      }
      if model.activeCandidates.isEmpty {
        Text("No active suggestions. You can add text manually or run OCR on this page.")
          .foregroundStyle(.secondary)
      } else {
        if let candidate = model.selectedCandidate {
          selectedCandidateCard(candidate)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
              "Selected suggested area on page \(candidate.pageIndex + 1), \(candidate.entryMode.rawValue)"
            )
            .accessibilityValue(
              candidate.labelText ?? candidate.evidence.first ?? "Detected from document structure"
            )
            .accessibilityHint(
              "Review this interpreted region before applying text or creating a native field."
            )
        }
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 4) {
            ForEach(model.activeCandidates) { candidate in
              candidateRow(candidate)
            }
          }
        }
        .frame(maxHeight: 250)
      }
      if !model.dismissedCandidates.isEmpty {
        DisclosureGroup("Dismissed (\(model.dismissedCandidates.count))") {
          ForEach(model.dismissedCandidates) { candidate in
            HStack {
              Text(
                "Page \(candidate.pageIndex + 1) · \(candidate.suggestedFieldType?.rawValue ?? "text")"
              )
              .font(.caption)
              Spacer()
              Button("Restore") {
                model.restoreCandidate(candidate.id)
              }
              .font(.caption)
            }
          }
        }
        .font(.caption)
      }
    }
  }

  private func candidateRow(_ candidate: RegionCandidate) -> some View {
    Button {
      model.selectedCandidateID = candidate.id
      model.selectedFieldID = nil
      model.jumpToPage(candidate.pageIndex)
    } label: {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: model.selectedCandidateID == candidate.id ? "scope" : "circle.dotted")
          .foregroundStyle(
            model.selectedCandidateID == candidate.id ? Color.accentColor : Color.secondary)
        VStack(alignment: .leading, spacing: 3) {
          HStack {
            Text("Page \(candidate.pageIndex + 1) · \(candidateEntryLabel(candidate))")
              .fontWeight(model.selectedCandidateID == candidate.id ? .semibold : .regular)
            Spacer()
            Text(confidenceLabel(candidate.score))
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          Text(candidate.evidence.first ?? "Detected from document structure")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        model.selectedCandidateID == candidate.id ? Color.accentColor.opacity(0.12) : Color.clear
      )
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Page \(candidate.pageIndex + 1), \(candidateEntryLabel(candidate)), confidence \(confidenceLabel(candidate.score)), \(candidate.evidence.first ?? "Detected from document structure")")
    .accessibilityHint("Selects this suggestion for editing or dismissal")
    .accessibilityAddTraits(model.selectedCandidateID == candidate.id ? [.isSelected, .isButton] : [.isButton])
  }

  private func selectedCandidateCard(_ candidate: RegionCandidate) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Review this area", systemImage: "scope")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Text(confidenceLabel(candidate.score))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      Text("Page \(candidate.pageIndex + 1) · \(candidateEntryLabel(candidate))")
        .font(.caption)
        .foregroundStyle(.secondary)
      if let labelText = candidate.labelText, !labelText.isEmpty {
        Text("Label: \(labelText)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(candidate.evidence.first ?? "Detected from document structure")
        .font(.caption)
        .foregroundStyle(.secondary)
      if candidate.isDirectlyEditable {
        TextField(
          candidate.entryMode == .characterGrid
            ? "Enter the full value for this region" : "Enter text to place here",
          text: $overlayDraft
        )
        .textFieldStyle(.roundedBorder)
        .disabled(!canEditAnnotations(model))
        .accessibilityHelp(
          canEditAnnotations(model)
            ? "Enter text for a reversible document overlay."
            : "Unavailable because this PDF does not allow document annotations."
        )
        .onSubmit {
          model.applyOverlay(overlayDraft)
          overlayDraft = ""
        }
        HStack {
          Button("Add text here", systemImage: "text.cursor") {
            model.applyOverlay(overlayDraft)
            overlayDraft = ""
          }
          .buttonStyle(.borderedProminent)
          .disabled(
            !canEditAnnotations(model)
              || overlayDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .accessibilityHelp(
            canEditAnnotations(model)
              ? "Adds a reversible text overlay in the selected region."
              : "Unavailable because this PDF does not allow document annotations."
          )
          Button("Create native field", systemImage: "rectangle.and.pencil.and.ellipsis") {
            model.synthesizeNativeField()
          }
          .buttonStyle(.bordered)
          .disabled(!canEditAnnotations(model))
          .accessibilityHelp(
            canEditAnnotations(model)
              ? "Creates a native field in the selected region."
              : "Unavailable because this PDF does not allow document annotations."
          )
          Button("Dismiss", role: .destructive) {
            model.rejectSelectedCandidate()
            overlayDraft = ""
          }
          .buttonStyle(.bordered)
        }
      } else {
        if [.checkbox, .radioGroup].contains(candidate.entryMode), !candidate.memberBounds.isEmpty {
          Label(
            candidate.entryMode == .radioGroup
              ? "Choose one detected option" : "Choose a detected box",
            systemImage: "checkmark.square"
          )
          .font(.callout.weight(.medium))
          .foregroundStyle(.orange)
          Picker("Choice cell", selection: $choiceCellIndex) {
            ForEach(candidate.memberBounds.indices, id: \.self) { index in
              Text("Option (index + 1)").tag(index)
            }
          }
          .disabled(!canEditAnnotations(model))
          .accessibilityHelp(
            canEditAnnotations(model)
              ? "Choose the detected choice region to mark."
              : "Unavailable because this PDF does not allow document annotations."
          )
          HStack {
            Button("Mark selected box", systemImage: "checkmark") {
              model.applyStaticChoiceMark(cellIndex: choiceCellIndex)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canEditAnnotations(model))
            .accessibilityHelp(
              canEditAnnotations(model)
                ? "Places a reversible visual choice mark."
                : "Unavailable because this PDF does not allow document annotations."
            )
          }
          Text(
            "This places a reversible visual mark. It is not an AcroForm checkbox or radio widget until the source template is explicitly modeled."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        } else {
          Label("Detected, but not directly editable yet", systemImage: "hand.raised")
            .font(.callout.weight(.medium))
            .foregroundStyle(.orange)
          Text(
            "Review the geometry, then use Add text manually or dismiss it. Choice regions require a selected option before marking."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        HStack {
          if candidate.isDirectlyEditable {
            Button("Create native field", systemImage: "rectangle.and.pencil.and.ellipsis") {
              model.synthesizeNativeField()
            }
            .buttonStyle(.bordered)
            .disabled(!canEditAnnotations(model))
            .accessibilityHelp(
              canEditAnnotations(model)
                ? "Creates a native field in the selected region."
                : "Unavailable because this PDF does not allow document annotations."
            )
          }
          Button("Dismiss", role: .destructive) {
            model.rejectSelectedCandidate()
            overlayDraft = ""
          }
          .buttonStyle(.bordered)
        }
      }
    }
    .padding(12)
    .background(Color.accentColor.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func confidenceLabel(_ score: Double) -> String {
    let percent = Int(score * 100)
    if score >= 0.75 { return "High · \(percent)%" }
    if score >= 0.5 { return "Medium · \(percent)%" }
    return "Low · \(percent)%"
  }

  private func candidateEntryLabel(_ candidate: RegionCandidate) -> String {
    switch candidate.entryMode {
    case .singleText:
      return "Text entry region"
    case .characterGrid:
      return "Character-entry region · \(candidate.groupMemberCount) cells"
    case .checkbox:
      return "Checkbox pattern · review only"
    case .radioGroup:
      return "Choice pattern · review only"
    case .signature:
      return "Signature region"
    case .unknown:
      return "Unclassified entry region"
    }
  }

  private var searchSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Search matches", systemImage: "magnifyingglass")
        .font(.headline)
      if model.searchMatches.isEmpty {
        Text("No matches yet. Use the search bar above to discover hits.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(model.searchMatches.enumerated()), id: \.offset) { offset, match in
          Button {
            model.setSearchMatch(offset)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text("Page \(match.pageIndex + 1)")
                  .font(.caption)
                  .fontWeight(.semibold)
                Text("(\(offset + 1)/\(model.searchMatches.count))")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              Text(match.snippet)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          .padding(.vertical, 2)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(
            "Search result \(offset + 1) of \(model.searchMatches.count), page \(match.pageIndex + 1)"
          )
          .accessibilityValue(match.snippet)
          .accessibilityHint("Selects and highlights this exact search result.")
          .accessibilityAddTraits(
            model.selectedSearchMatchIndex == offset ? [.isSelected] : []
          )
        }
      }
    }
  }

  private var linkAndOutlineSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Navigation and structure", systemImage: "list.bullet.indent")
        .font(.headline)

      if inspection.outlines.isEmpty {
        Text("No outline/bookmark tree found in this document.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(inspection.outlines) { item in
          Button {
            if let pageIndex = item.destinationPageIndex {
              model.jumpToPage(pageIndex)
            } else if let first = item.children.first {
              if let pageIndex = first.destinationPageIndex {
                model.jumpToPage(pageIndex)
              }
            }
          } label: {
            HStack {
              Text(item.title)
                .font(.caption)
              Spacer()
              if let pageIndex = item.destinationPageIndex {
                Text("p \(pageIndex + 1)")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.leading, CGFloat(item.level) * 8)
          }
          .buttonStyle(.plain)
        }
      }

      if inspection.links.isEmpty {
        Text("No navigable links were collected.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Links")
            .font(.subheadline.weight(.semibold))
          ForEach(inspection.links, id: \.id) { link in
            VStack(alignment: .leading, spacing: 4) {
              Text(link.label)
                .font(.caption)
                .foregroundStyle(.secondary)
              HStack {
                Button(link.destination ?? "Open destination") {
                  model.openLink(link)
                }
                .buttonStyle(.bordered)
                if link.kind == .externalURL {
                  Image(systemName: link.isSafeExternal ? "lock.open" : "exclamationmark.shield")
                    .foregroundStyle(link.isSafeExternal ? .green : .red)
                    .help(link.isSafeExternal ? "Safe external URL" : "Blocked or unsafe URL")
                }
              }
            }
          }
        }
      }
    }
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Document details", systemImage: "doc.on.doc")
        .font(.headline)

      DisclosureGroup("Metadata") {
        LabeledContent(
          "Title",
          value: inspection.metadata.title.isEmpty ? "Not declared" : inspection.metadata.title)
        LabeledContent(
          "Author",
          value: inspection.metadata.author.isEmpty ? "Not declared" : inspection.metadata.author)
        LabeledContent(
          "Producer",
          value: inspection.metadata.producer.isEmpty
            ? "Not declared" : inspection.metadata.producer)
        LabeledContent(
          "Creator",
          value: inspection.metadata.creator.isEmpty ? "Not declared" : inspection.metadata.creator)
      }

      DisclosureGroup("Permissions") {
        LabeledContent("Can print", value: inspection.permissions.canPrint ? "Yes" : "No")
        LabeledContent("Can copy text", value: inspection.permissions.canCopy ? "Yes" : "No")
        LabeledContent("Can modify", value: inspection.permissions.canModify ? "Yes" : "No")
        LabeledContent(
          "Can annotate", value: inspection.permissions.canAddAnnotations ? "Yes" : "No")
      }

      DisclosureGroup("Attachments") {
        if inspection.attachments.isEmpty {
          Text("No embedded attachments discovered in this lane.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          ForEach(inspection.attachments, id: \.self) { attachment in
            Text(attachment)
              .font(.caption)
          }
        }
      }

      DisclosureGroup("Accessibility and safety notes") {
        LabeledContent(
          "Tagged content",
          value: inspection.accessibility.hasTaggedContent ? "Observed" : "Unknown")
        LabeledContent(
          "Reading-order hints",
          value: inspection.accessibility.hasReadingOrder ? "Observed" : "Not guaranteed")
        ForEach(inspection.accessibility.notes, id: \.self) { note in
          Text(note)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var validationSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Export validation", systemImage: "checkmark.shield")
        .font(.headline)
      if let report = model.exportReport {
        Text(
          report.status.rawValue.replacingOccurrences(
            of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression
          ).capitalized
        )
        .foregroundStyle(report.status == .failed ? .red : .green)
        ForEach(report.messages, id: \.self) { message in
          Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else {
        Text(
          "Export creates a new copy, reopens it, and checks geometry, fields, text, and applied edits."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      }
    }
  }
}

private struct PDFPresentationHighlight {
  enum Kind {
    case candidate
    case characterGrid
    case field
    case search
  }

  let kind: Kind
  let page: PDFPage
  let bounds: CGRect
  let memberBounds: [CGRect]

  init(kind: Kind, page: PDFPage, bounds: CGRect, memberBounds: [CGRect] = []) {
    self.kind = kind
    self.page = page
    self.bounds = bounds
    self.memberBounds = memberBounds
  }
}

private final class PDFPresentationOverlayView: NSView {
  var highlights: [PDFPresentationHighlight] = [] {
    didSet { needsDisplay = true }
  }

  func invalidateProjection() {
    needsDisplay = true
    layer?.setNeedsDisplay()
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let pdfView = superview as? PDFView else { return }

    for highlight in highlights {
      let pdfViewBounds = pdfView.convert(highlight.bounds, from: highlight.page)
      let overlayBounds = convert(pdfViewBounds, from: pdfView)
      guard overlayBounds.intersects(dirtyRect) else { continue }

      if highlight.kind == .characterGrid {
        // The union is a hit/attention boundary only. Paint each cell
        // independently so the printed form text and inter-cell gaps remain
        // visible instead of becoming one opaque block.
        let boundary = NSBezierPath(roundedRect: overlayBounds, xRadius: 2, yRadius: 2)
        boundary.setLineDash([4, 3], count: 2, phase: 0)
        boundary.lineWidth = 1.5
        NSColor.controlAccentColor.setStroke()
        boundary.stroke()

        for memberBounds in highlight.memberBounds {
          let memberViewBounds = pdfView.convert(memberBounds, from: highlight.page)
          let cellBounds = convert(memberViewBounds, from: pdfView)
          guard cellBounds.intersects(dirtyRect) else { continue }
          let cell = NSBezierPath(rect: cellBounds)
          NSColor.systemBlue.withAlphaComponent(0.12).setFill()
          NSColor.controlAccentColor.withAlphaComponent(0.72).setStroke()
          cell.lineWidth = 1
          cell.fill()
          cell.stroke()
        }
        continue
      }

      let fillColor: NSColor
      let strokeColor: NSColor
      switch highlight.kind {
      case .candidate:
        fillColor = NSColor.systemBlue.withAlphaComponent(0.12)
        strokeColor = NSColor.controlAccentColor
      case .field:
        fillColor = NSColor.systemGreen.withAlphaComponent(0.10)
        strokeColor = NSColor.systemGreen
      case .characterGrid:
        continue
      case .search:
        fillColor = NSColor.systemYellow.withAlphaComponent(0.10)
        strokeColor = NSColor.systemOrange.withAlphaComponent(0.70)
      }

      fillColor.setFill()
      strokeColor.setStroke()
      let path = NSBezierPath(
        roundedRect: overlayBounds,
        xRadius: 3,
        yRadius: 3
      )
      path.lineWidth = highlight.kind == .search ? 1 : 1.5
      path.fill()
      path.stroke()
      if highlight.kind == .search {
        let underline = NSBezierPath()
        underline.move(to: NSPoint(x: overlayBounds.minX, y: overlayBounds.minY + 1))
        underline.line(to: NSPoint(x: overlayBounds.maxX, y: overlayBounds.minY + 1))
        underline.lineWidth = 2
        NSColor.systemOrange.withAlphaComponent(0.65).setStroke()
        underline.stroke()
      }
    }
  }
}

private final class InteractivePDFView: PDFView {
  var isManualPlacementMode = false
  var onManualPlacement: ((Int, CGPoint) -> Void)?
  var onDirectEdit: ((Int, CGPoint) -> Void)?
  var onProjectionInvalidated: (@MainActor @Sendable () -> Void)?
  var requestedScaleMode: ReaderScaleMode = .fitWidth
  var requestedRowWidth: CGFloat = 612
  var requestedZoom: CGFloat = 1

  override var acceptsFirstResponder: Bool { true }

  override func becomeFirstResponder() -> Bool {
    true
  }

  override func layout() {
    super.layout()
    applyRequestedScale()
    onProjectionInvalidated?()
  }

  func applyRequestedScale() {
    guard bounds.width > 0 else { return }
    switch requestedScaleMode {
    case .fitWidth:
      let availableWidth = max(240, bounds.width - 28)
      scaleFactor = min(3.0, max(0.25, availableWidth / requestedRowWidth))
    case .fitPage:
      scaleFactor = scaleFactorForSizeToFit * 0.95
    case .zoom:
      scaleFactor = requestedZoom
    }
    onProjectionInvalidated?()
  }

  override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    guard let document,
      let page = page(for: convert(event.locationInWindow, from: nil), nearest: true)
    else {
      super.mouseDown(with: event)
      return
    }
    let viewPoint = convert(event.locationInWindow, from: nil)
    let pagePoint = convert(viewPoint, to: page)
    let pageIndex = document.index(for: page)
    if isManualPlacementMode {
      onManualPlacement?(pageIndex, pagePoint)
    } else if event.clickCount >= 2 {
      onDirectEdit?(pageIndex, pagePoint)
    } else {
      super.mouseDown(with: event)
    }
  }

  override func keyDown(with event: NSEvent) {
    guard isManualPlacementMode,
      event.keyCode == 36 || event.keyCode == 49,
      let document,
      let page = currentPage
    else {
      super.keyDown(with: event)
      return
    }

    let pageBounds = page.bounds(for: displayBox)
    onManualPlacement?(
      document.index(for: page),
      CGPoint(x: pageBounds.midX, y: pageBounds.midY)
    )
  }
}

private struct PDFKitView: NSViewRepresentable {
  let document: PDFDocument?
  let projectionRevision: UInt64
  let pageIndex: Int
  let viewMode: ReaderViewMode
  let scaleMode: ReaderScaleMode
  let zoom: Double
    let rotation: Int
    let selectedSearchMatch: SearchMatch?
    @Binding var searchProjectionState: SearchProjectionState
    let selectedCandidate: RegionCandidate?
  let selectedField: NativeField?
  let isManualPlacementMode: Bool
  let onManualPlacement: (Int, CGPoint) -> Void
  let onDirectEdit: (Int, CGPoint) -> Void

  private final class ProjectionObserverTokenStore {
    var tokens: [NSObjectProtocol] = []

    deinit {
      let notificationCenter = NotificationCenter.default
      tokens.forEach { notificationCenter.removeObserver($0) }
    }
  }

  @MainActor
  final class Coordinator {
    weak var sourceDocument: PDFDocument?
    var presentationDocument: PDFDocument?
    var presentationRotation: Int?
    var presentationRevision: UInt64?
    weak var overlayView: PDFPresentationOverlayView?
    weak var observedRootView: NSView?
    weak var observedScrollContentView: NSView?
    weak var observedDocumentView: NSView?
    private let projectionObserverTokenStore = ProjectionObserverTokenStore()
    var lastNavigatedPageIndex: Int?
    var lastSearchSignature: String?

    func invalidateOverlay() {
      overlayView?.invalidateProjection()
    }

    func removeProjectionObservers() {
      let notificationCenter = NotificationCenter.default
      projectionObserverTokenStore.tokens.forEach { notificationCenter.removeObserver($0) }
      projectionObserverTokenStore.tokens.removeAll()
      observedRootView = nil
      observedScrollContentView = nil
      observedDocumentView = nil
    }

    func installProjectionObservers(for view: InteractivePDFView) {
      let scrollContentView = view.enclosingScrollView?.contentView
      let documentView = view.documentView
      if observedRootView === view,
        observedScrollContentView === scrollContentView,
        observedDocumentView === documentView,
        !projectionObserverTokenStore.tokens.isEmpty
      {
        return
      }

      removeProjectionObservers()
      observedRootView = view
      observedScrollContentView = scrollContentView
      observedDocumentView = documentView

      var observedViews: [NSView] = [view]
      if let scrollContentView {
        observedViews.append(scrollContentView)
      }
      if let documentView {
        observedViews.append(documentView)
      }
      observedViews.forEach { observedView in
        observedView.postsBoundsChangedNotifications = true
        observedView.postsFrameChangedNotifications = true
        let notificationCenter = NotificationCenter.default
        for name in [
          NSView.boundsDidChangeNotification,
          NSView.frameDidChangeNotification,
        ] {
          projectionObserverTokenStore.tokens.append(
            notificationCenter.addObserver(
              forName: name,
              object: observedView,
              queue: .main
            ) { [weak self] _ in
              Task { @MainActor [weak self] in
                self?.invalidateOverlay()
              }
            }
          )
        }
      }

      let notificationCenter = NotificationCenter.default
      for name in [
        Notification.Name("PDFViewScaleChanged"),
        Notification.Name("PDFViewDisplayModeChanged"),
      ] {
        projectionObserverTokenStore.tokens.append(
          notificationCenter.addObserver(forName: name, object: view, queue: .main) {
            [weak self] _ in
            Task { @MainActor [weak self] in
              self?.invalidateOverlay()
            }
          }
        )
      }
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> InteractivePDFView {
    let view = InteractivePDFView()
    view.autoScales = false
    view.displayMode = .singlePageContinuous
    view.displayBox = .cropBox
    view.backgroundColor = .windowBackgroundColor
    view.onManualPlacement = onManualPlacement
    view.onDirectEdit = onDirectEdit

    let overlayView = PDFPresentationOverlayView(frame: view.bounds)
    overlayView.autoresizingMask = [.width, .height]
    overlayView.wantsLayer = true
    view.addSubview(overlayView)
    context.coordinator.overlayView = overlayView
    view.onProjectionInvalidated = { @MainActor [weak coordinator = context.coordinator] in
      coordinator?.invalidateOverlay()
    }
    context.coordinator.installProjectionObservers(for: view)
    return view
  }

  func updateNSView(_ view: InteractivePDFView, context: Context) {
    if context.coordinator.sourceDocument !== document
      || context.coordinator.presentationRotation != rotation
      || context.coordinator.presentationRevision != projectionRevision
    {
      context.coordinator.sourceDocument = document
      context.coordinator.presentationRotation = rotation
      context.coordinator.presentationRevision = projectionRevision
      context.coordinator.lastNavigatedPageIndex = nil
      context.coordinator.lastSearchSignature = nil

      if let document,
        let presentationDocument = document.copy() as? PDFDocument
      {
        for pageNumber in 0..<presentationDocument.pageCount {
          presentationDocument.page(at: pageNumber)?.rotation = rotation
        }
        context.coordinator.presentationDocument = presentationDocument
        view.document = presentationDocument
      } else {
        context.coordinator.presentationDocument = document
        view.document = document
      }
    } else if view.document !== context.coordinator.presentationDocument {
      view.document = context.coordinator.presentationDocument
    }

    view.isManualPlacementMode = isManualPlacementMode
    view.onManualPlacement = onManualPlacement
    view.onDirectEdit = onDirectEdit
    view.onProjectionInvalidated = { @MainActor [weak coordinator = context.coordinator] in
      coordinator?.invalidateOverlay()
    }
    context.coordinator.installProjectionObservers(for: view)
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()

    switch viewMode {
    case .singlePage:
      view.displayMode = .singlePage
    case .continuous:
      view.displayMode = .singlePageContinuous
    case .twoPage:
      view.displayMode = .twoUp
    }

    view.autoScales = false
    let pageWidth = document?.page(at: pageIndex)?.bounds(for: .cropBox).width ?? 612
    view.requestedScaleMode = scaleMode
    view.requestedRowWidth = viewMode == .twoPage ? pageWidth * 2 + 18 : pageWidth
    view.requestedZoom = CGFloat(zoom)
    view.applyRequestedScale()
    context.coordinator.invalidateOverlay()

    var highlights: [PDFPresentationHighlight] = []
    if let selectedCandidate,
      let page = view.document?.page(at: selectedCandidate.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: selectedCandidate.entryMode == .characterGrid ? .characterGrid : .candidate,
          page: page,
          bounds: selectedCandidate.bounds.cgRect,
          memberBounds: selectedCandidate.entryMode == .characterGrid
            ? selectedCandidate.memberBounds.map(\.cgRect)
            : []
        )
      )
    } else if let selectedField,
      let page = view.document?.page(at: selectedField.pageIndex)
    {
      highlights.append(
        PDFPresentationHighlight(
          kind: .field,
          page: page,
          bounds: selectedField.bounds.cgRect
        )
      )
    }

    if let document = view.document {
      if context.coordinator.lastNavigatedPageIndex != pageIndex,
        let page = document.page(at: pageIndex)
      {
        view.go(to: page)
        context.coordinator.lastNavigatedPageIndex = pageIndex
      }

      if let selectedSearchMatch {
        let projection = searchProjection(for: selectedSearchMatch, in: document)
        searchProjectionState = projection.state
        if let selection = projection.selection,
          let page = document.page(at: selectedSearchMatch.pageIndex)
        {
          let signature = searchSignature(for: selectedSearchMatch)
          if context.coordinator.lastSearchSignature != signature {
            // Do not ask PDFKit to paint currentSelection: its platform-defined
            // selection fill is opaque enough to hide small printed glyphs.
            // The exact selection bounds are rendered by our controlled overlay
            // below, and the page navigation already happened above.
            context.coordinator.lastSearchSignature = signature
          }
          highlights.append(
            PDFPresentationHighlight(
              kind: .search,
              page: page,
              bounds: selection.bounds(for: page)
            )
          )
          // PDFKit paints currentSelection with its own high-contrast fill.
          // Keep the exact bounds for our controlled underline cue, then clear
          // the native selection so search never masks the document text.
          view.currentSelection = nil
        } else {
          if context.coordinator.lastSearchSignature != nil {
            view.currentSelection = nil
            context.coordinator.lastSearchSignature = nil
          }
        }
      } else {
        searchProjectionState = .none
        if context.coordinator.lastSearchSignature != nil {
          view.currentSelection = nil
          context.coordinator.lastSearchSignature = nil
        }
      }
    } else {
      searchProjectionState = .none
      context.coordinator.lastNavigatedPageIndex = nil
      context.coordinator.lastSearchSignature = nil
    }

    context.coordinator.overlayView?.highlights = highlights
    context.coordinator.invalidateOverlay()
  }

  private func searchSignature(for match: SearchMatch) -> String {
    "\(match.id)|page:\(match.pageIndex)|start:\(match.charStart)|length:\(match.charLength)"
  }

  private func searchProjection(
    for match: SearchMatch,
    in document: PDFDocument
  ) -> (selection: PDFSelection?, state: SearchProjectionState) {
    guard let page = document.page(at: match.pageIndex) else {
      return (nil, .unavailable)
    }
    let pageMatches = document.findString(match.query, withOptions: [.caseInsensitive]).filter {
      $0.pages.contains(where: { $0 === page }) && !$0.bounds(for: page).isEmpty
    }
    guard !pageMatches.isEmpty else { return (nil, .unavailable) }

    if let exact = pageMatches.first(where: {
      let bounds = $0.bounds(for: page)
      return !bounds.isEmpty
    }) {
      return (exact, .exact)
    }

    return (pageMatches[0], .approximate)
  }

}

struct SettingsView: View {
  var body: some View {
    Form {
      Section {
        LabeledContent("Processing", value: "On this Mac")
        LabeledContent("Source files", value: "Never overwritten")
        LabeledContent("Provider", value: "PDFKit evaluation lane")
        Text("Export Copy is the save action for this app. It creates a separate edited PDF; closing the window never saves changes into the source file.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } header: {
        Text("Safety")
      } footer: {
        Text("Provider adoption remains subject to the native/web parity and provider gates.")
      }
    }
    .formStyle(.grouped)
    .scenePadding()
    .frame(width: 420)
  }
}

private struct NewProfileButton: View {
  let onCreate: (String) -> Void
  @State private var isPresented = false
  @State private var name = ""

  var body: some View {
    Button {
      isPresented = true
    } label: {
      Label("New Profile", systemImage: "plus")
        .font(.subheadline)
    }
    .sheet(isPresented: $isPresented) {
      VStack(spacing: 16) {
        Text("Create Profile")
          .font(.headline)
        TextField("Profile name", text: $name)
          .textFieldStyle(.roundedBorder)
          .frame(width: 240)
        HStack {
          Button("Cancel") { isPresented = false }
          Button("Create") {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
              onCreate(trimmed)
              isPresented = false
              name = ""
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .padding(24)
    }
  }
}
