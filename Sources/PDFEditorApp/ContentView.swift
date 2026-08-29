import AppKit
import PDFEditorCore
import PDFEditorRecovery
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Apple Design §13: haptic feedback trigger values
// Used with .sensoryFeedback modifier on buttons.
private enum HapticTrigger {
  static let open = UUID()
  static let undo = UUID()
  static let redo = UUID()
  static let export = UUID()
}

extension NSImage {
  var pngData: Data? {
    guard let tiffData = tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
  }
}

extension SavedSignature {
  var signatureImageData: Data? {
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
  /// Shared rendering pipeline: the canvas and the thumbnail rail consume the
  /// same cache so thumbnails and progressive renders warm each other.
  @State private var renderingPipeline = RenderingPipeline()
  @StateObject private var themeManager = ThemeManager()
  @StateObject private var readingHistory = ReadingHistoryManager()
  @StateObject private var annotationStore = AnnotationStore()
  @StateObject private var documentIndex = DocumentIndex()
  @StateObject private var versionStore = VersionStore()
  @StateObject private var governanceEngine = GovernanceEngine()
  @State private var searchProjectionState: SearchProjectionState = .none
  @State private var isAgentCommandPresented = false
  @State private var isSecurityVaultPresented = false
  @State private var isBatchMergePresented = false
  @State private var isDocumentBrowserPresented = false
  @State private var isVersionComparePresented = false
  @State private var isGovernanceDashboardPresented = false
  @State private var isCompanionHealthPresented = false
  // Apple Design §13: haptic trigger tokens
  @State private var hapticNew = UUID()
  @State private var hapticOpen = UUID()
  @State private var hapticUndo = UUID()
  @State private var hapticRedo = UUID()
  @State private var hapticExport = UUID()

  public init(model: AppModel, searchFocusEvent: Binding<Int> = .constant(0)) {
    self.model = model
    self._searchFocusEvent = searchFocusEvent
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Display parameters derived from the current reading mode.
  private var readingParams: ReadingDisplayParams {
    ReadingDisplayParams.params(for: model.readingMode)
  }

  public var body: some View {
    mainContent
      .applyTheme(using: themeManager)
      .toolbar {
        if readingParams.showToolbar {
          appToolbar
        } else {
          // Skim mode: only show essential items (mode picker + page nav)
          skimToolbar
        }
      }
      .onAppear {
        NotificationCenter.default.addObserver(
          forName: .contentRoutingResult,
          object: nil,
          queue: .main
        ) { notification in
          if let suggestion = notification.userInfo?["suggestion"] as? ContentSuggestion {
            model.contentSuggestion = suggestion
            model.isContentSuggestionDismissed = false
          }
        }
      }
      // Apple Design §12: translucent toolbar — .ultraThinMaterial on macOS
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
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $model.isManualTextSheetPresented) {
        ManualTextSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $model.isSignatureSheetPresented) {
        CommitFlowSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isSecurityVaultPresented) {
        SecurityVaultSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isBatchMergePresented) {
        BatchMergeSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isDocumentBrowserPresented) {
        DocumentBrowserView(documentIndex: documentIndex)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isVersionComparePresented) {
        VersionCompareView(versionStore: versionStore)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isGovernanceDashboardPresented) {
        GovernanceDashboardView(engine: governanceEngine)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isCompanionHealthPresented) {
        CompanionHealthDashboardView(
          health: CompanionHealthCheck(
            bridge: model.companionBridge,
            registry: model.providerRegistry,
            egressGate: model.companionBridge.egressGate,
            contractStore: model.contractStore
          )
        )
          .transition(.scale(scale: 0.96).combined(with: .opacity))
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
        let count = model.redactionMarkCount
        Text(
          "This will permanently remove content under \(count) marked region\(count == 1 ? "" : "s") in a separate new PDF copy. The original file is never overwritten.\n\nThis action cannot be undone."
        )
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    if let inspection = model.inspection {
      inspectionContent(inspection: inspection)
    } else {
      welcomeContent
    }
  }

  private func inspectionContent(inspection: DocumentInspection) -> some View {
    ZStack {
      // Background tint for Reference mode
      Color.yellow
        .opacity(readingParams.backgroundOpacity * 0.3)
        .allowsHitTesting(false)

      VStack(spacing: 0) {
        RecoveryStatusBanner(model: model)

        HSplitView {
          if readingParams.showThumbnailRail {
            PageThumbnailRailView(
              model: model,
              inspection: inspection,
              renderingPipeline: renderingPipeline
            )
            .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)
          }

          DocumentCanvasView(
            model: model,
            inspection: inspection,
            renderingPipeline: renderingPipeline,
            readingParams: readingParams,
            searchProjectionState: $searchProjectionState,
            searchFocusEvent: $searchFocusEvent,
            annotationStore: annotationStore
          )

          if readingParams.showInspector {
            ContextualInspectorView(
              model: model,
              inspection: inspection,
              renderingPipeline: renderingPipeline,
              isSecurityVaultPresented: $isSecurityVaultPresented,
              annotationStore: annotationStore
            )
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
          }
        }

        // Reading progress bar (shown in Study/Review modes)
        if readingParams.showProgress, let inspection = model.inspection {
          let totalPages = inspection.pages.count
          VStack(spacing: 0) {
            Divider()
            HStack {
              Text("Page \(model.selectedPageIndex + 1) of \(totalPages)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
              Spacer()
              ProgressView(
                value: Double(model.selectedPageIndex + 1),
                total: Double(totalPages)
              )
              .progressViewStyle(.linear)
              .frame(width: 120)
              .tint(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
          }
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
    .animation(
      reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.8),
      value: isAgentCommandPresented
    )
    .onChange(of: model.selectedPageIndex) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.selectedFieldID) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.selectedCandidateID) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.selectedSearchMatchIndex) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.searchQuery) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.readerViewMode) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.readerScaleMode) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.readerZoom) { _, _ in model.scheduleViewStateAutosave() }
    .onChange(of: model.readerRotation) { _, _ in model.scheduleViewStateAutosave() }
  }

  private var welcomeContent: some View {
    WelcomeView(
      open: requestOpenDocument,
      createBlank: { size in model.newDocument(pageSize: size) },
      createFromImages: { model.presentNewFromImagesPanel() },
      createFromClipboard: { model.newDocumentFromClipboard() },
      createFromMarkdown: { model.newDocumentFromMarkdown() }
    )
  }

  @ToolbarContentBuilder
  private var appToolbar: some ToolbarContent {
    ToolbarItemGroup {

      Button("New", systemImage: "doc.badge.plus") {
        hapticNew = UUID()
        requestNewDocument()
      }
      .accessibilityLabel("New blank PDF")
      .sensoryFeedback(.impact, trigger: hapticNew)
      .help("Create a new blank PDF document in this window.")

      Button("Open", systemImage: "folder") {
        hapticOpen = UUID()
        requestOpenDocument()
      }
      .accessibilityLabel("Open PDF")
      .sensoryFeedback(.impact, trigger: hapticOpen)
      .help("Open another PDF. The current document remains open until the new PDF is admitted.")


      Button("Undo", systemImage: "arrow.uturn.backward") {
        hapticUndo = UUID()
        model.undoLastEdit()
      }
      .accessibilityLabel("Undo last edit")
      .sensoryFeedback(.decrease, trigger: hapticUndo)
      .disabled(!model.canUndo)


      Button("Redo", systemImage: "arrow.uturn.forward") {
        hapticRedo = UUID()
        model.redoLastEdit()
      }
      .accessibilityLabel("Redo last edit")
      .sensoryFeedback(.increase, trigger: hapticRedo)
      .disabled(!model.canRedo)

      Menu {

        Button("Export Copy…", systemImage: "square.and.arrow.down") {
          hapticExport = UUID()
          model.export()
        }
        .sensoryFeedback(.success, trigger: hapticExport)

        Button("Export Sanitized Copy (No Metadata)…", systemImage: "lock.shield") {
          let panel = NSSavePanel()
          panel.allowedContentTypes = [.pdf]
          panel.nameFieldStringValue = "Sanitized-\(model.inspection?.source.fileName ?? "document.pdf")"
          panel.begin { response in
            if response == .OK, let url = panel.url {
              _ = model.sanitizeAndExportCopy(destination: url)
            }
          }
        }

        Button("Extract / Split Pages…", systemImage: "arrow.triangle.pull") {
          let panel = NSSavePanel()
          panel.allowedContentTypes = [.pdf]
          panel.nameFieldStringValue = "Extracted-Page\(model.selectedPageIndex + 1).pdf"
          panel.begin { response in
            if response == .OK, let url = panel.url {
              _ = model.splitPageRange(from: model.selectedPageIndex, to: model.selectedPageIndex, destination: url)
            }
          }
        }

        Button("Batch Merge Documents…", systemImage: "doc.on.doc") {
          isBatchMergePresented = true
        }

        Button("Synthesize Searchable OCR Layer", systemImage: "text.viewfinder") {
          model.synthesizeSearchableOCRLayer()
        }

        Divider()

        Button("Export Flattened Copy…", systemImage: "printer.dotmatrix") {
          let panel = NSSavePanel()
          panel.allowedContentTypes = [.pdf]
          panel.nameFieldStringValue = "Flattened-\(model.inspection?.source.fileName ?? "document.pdf")"
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

      Menu {
        Button("Document Browser…", systemImage: "books.vertical") {
          isDocumentBrowserPresented = true
        }
        .help("Browse and organize your document corpus")

        Button("Version History…", systemImage: "clock.arrow.circlepath") {
          isVersionComparePresented = true
        }
        .help("Compare and revert document versions")

        Button("Governance Dashboard…", systemImage: "checkmark.shield") {
          isGovernanceDashboardPresented = true
        }
        .help("View compliance status and policy rules")

        Divider()

        Button("Companion Health…", systemImage: "heart.text.square") {
          isCompanionHealthPresented = true
        }
        .help("Provider status, egress connections, and bridge log")
      } label: {
        Label("Manager", systemImage: "slider.horizontal.3")
      }
      .accessibilityLabel("Manager power tools")
      .help("Corpus organization, versioning, and governance tools")
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
      .fixedSize()
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
      .accessibilityLabel("Agent Command Palette")
      .accessibilityHint("⌘K. Semantic actions, bulk fill, OCR, and diff tools.")
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
      .fixedSize()
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

    // Reading mode picker
    ToolbarItem {
      Menu {
        ForEach(ReadingMode.allCases) { mode in
          Button {
            model.readingMode = mode
          } label: {
            Label {
              Text(mode.displayName)
            } icon: {
              Image(systemName: mode.symbolName)
            }
          }
        }
        Divider()
        Toggle(isOn: $model.usePipelineRendering) {
          Label {
            Text("Pipeline Renderer")
          } icon: {
            Image(systemName: "cpu")
          }
        }
      } label: {
        Label(model.readingMode.displayName, systemImage: model.readingMode.symbolName)
          .font(.caption)
      }
      .help("Reading mode: \(model.readingMode.helpText)")
    }

    // Freeze pane toggle
    ToolbarItem {
      FreezePaneToggleButton(
        isFrozen: $model.isFreezePaneActive,
        onAutoDetect: {
          if let extraction = try? renderingPipeline.extractText(),
             !extraction.tables.isEmpty {
            let table = extraction.tables[0]
            let config = FreezePaneConfig.autoDetect(
              rows: table.rows,
              columns: table.columns,
              confidence: table.confidence
            )
            model.freezePaneConfig = config
            model.isFreezePaneActive = config.isActive
          }
        },
        onApplyPreset: { preset in
          model.freezePaneConfig = preset.config
          model.isFreezePaneActive = preset.config.isActive
          NotificationCenter.default.post(
            name: .freezePaneStateChanged,
            object: nil,
            userInfo: [
              "isActive": model.isFreezePaneActive,
              "config": model.freezePaneConfig
            ]
          )
        },
        onToggle: {
          NotificationCenter.default.post(
            name: .freezePaneStateChanged,
            object: nil,
            userInfo: [
              "isActive": model.isFreezePaneActive,
              "config": model.freezePaneConfig
            ]
          )
        },
        matchedPresets: {
          guard let extraction = try? renderingPipeline.extractText(),
                !extraction.tables.isEmpty else { return [] }
          let table = extraction.tables[0]
          let cellTexts = table.cells.flatMap { $0 }
          return FreezePanePresetMatcher().match(
            rows: table.rows,
            columns: table.columns,
            cellTexts: cellTexts
          )
        }()
      )
    }

    // Bookmark button
    ToolbarItem {
      Menu {
        Button {
          let docID = model.sourceURL?.lastPathComponent ?? "unknown"
          let pageIdx = model.selectedPageIndex ?? 0
          let _ = readingHistory.addBookmark(
            documentID: docID,
            pageIndex: pageIdx,
            title: "Page \(pageIdx + 1)"
          )
        } label: {
          Label("Add Bookmark", systemImage: "bookmark")
        }

        Divider()

        let docID = model.sourceURL?.lastPathComponent ?? "unknown"
        let bookmarks = readingHistory.bookmarks(for: docID)
        if bookmarks.isEmpty {
          Text("No bookmarks")
            .foregroundStyle(.secondary)
        } else {
          ForEach(bookmarks) { bm in
            Button {
              model.jumpToPage(bm.pageIndex)
            } label: {
              Label(bm.title, systemImage: "bookmark.fill")
            }
          }
        }

        if !bookmarks.isEmpty {
          Divider()
          Button("Clear Bookmarks", role: .destructive) {
            for bm in readingHistory.bookmarks(for: docID) {
              readingHistory.removeBookmark(id: bm.id, documentID: docID)
            }
          }
        }
      } label: {
        Image(systemName: "bookmark")
          .font(.caption)
      }
      .menuStyle(.borderlessButton)
      .help("Bookmarks for this document")
    }

    // Content suggestion indicator
    ToolbarItem(placement: .status) {
      if let suggestion = model.contentSuggestion,
         suggestion.isActionable,
         !model.isContentSuggestionDismissed,
         model.readingMode != suggestion.contentType.suggestedMode {
        Button {
          model.readingMode = suggestion.contentType.suggestedMode
          model.isContentSuggestionDismissed = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: suggestion.contentType.symbolName)
            Text(suggestion.contentType.suggestedAction)
              .fontWeight(.medium)
          }
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Color.accentColor.opacity(0.12))
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Suggest \(suggestion.contentType.suggestedAction)")
        .help(suggestion.reason)

        Button {
          model.isContentSuggestionDismissed = true
        } label: {
          Image(systemName: "xmark")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Dismiss suggestion")
      }
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
          .accessibilityLabel(model.fillProgressLabel ?? "Start filling")
          .accessibilityHint("Switches to fill mode to populate form fields")
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

  /// Minimal toolbar for Skim mode — only reading mode picker and page nav.
  private var skimToolbar: some ToolbarContent {
    ToolbarItemGroup {
      // Reading mode picker (always visible)
      Menu {
        ForEach(ReadingMode.allCases) { mode in
          Button {
            model.readingMode = mode
          } label: {
            Label {
              Text(mode.displayName)
            } icon: {
              Image(systemName: mode.symbolName)
            }
          }
        }
      } label: {
        Label(model.readingMode.displayName, systemImage: model.readingMode.symbolName)
          .font(.caption)
      }
      .help("Reading mode: \(model.readingMode.helpText)")

      // Page indicator
      if let inspection = model.inspection {
        Text("\(model.selectedPageIndex + 1)/\(inspection.pages.count)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }

      Spacer()

      // Minimal status
      Text(model.statusMessage ?? "Ready")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private func openImportedPDF(_ url: URL) {
    model.open(url: url)
    // Start reading history session
    let docID = url.lastPathComponent
    readingHistory.startSession(
      documentID: docID,
      fileName: url.lastPathComponent,
      startPage: 0
    )
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

  private func requestNewDocument() {
    let decision = model.lifecycleDecision(for: .newDocument)
    guard decision.disposition == .confirmBeforeDiscardingChanges else {
      model.newDocument()
      return
    }

    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "This document has unexported changes."
    alert.informativeText = "New Document replaces this window's document with a blank PDF. Export Copy... creates a separate edited PDF and never overwrites the source. A recoverable session is kept for the current document."
    alert.addButton(withTitle: "Create New Document")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    model.newDocument()
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
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
      /* Apple Design §12: translucent material for status banner */
      .background(.ultraThinMaterial)
      .overlay(alignment: .bottom) {
        Divider()
      }
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }
}

// MARK: - Welcome View
private struct WelcomeView: View {
  let open: () -> Void
  let createBlank: (CGSize) -> Void
  let createFromImages: () -> Void
  let createFromClipboard: () -> Void
  let createFromMarkdown: () -> Void
  @State private var pageSize = AppModel.ScratchPageSize.letter

  var body: some View {
    VStack(spacing: 20) {
      ZStack {
        Circle()
          .fill(Color.accentColor.opacity(0.12))
          .frame(width: 88, height: 88)
        Image(systemName: "sparkle.magnifyingglass")
          .font(.largeTitle.weight(.light))
          .foregroundStyle(Color.accentColor)
      }

      VStack(spacing: 6) {
        Text("Northstar Document Workbench")
          .font(.title2.weight(.semibold))
        Text("Local-first PDF reader and editor: open a PDF, create one from scratch, or assemble pages from images.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 480)
      }

      HStack(spacing: 12) {
        Button("Open a PDF…", action: open)
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.bordered)
          .controlSize(.large)

        Button {
          createBlank(pageSize.size)
        } label: {
          Label("Create Blank PDF", systemImage: "doc.badge.plus")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)

        Menu {
          Button("From Images…") { createFromImages() }
          Button("From Clipboard") { createFromClipboard() }
          Button("From Markdown…") { createFromMarkdown() }
        } label: {
          Label("New From…", systemImage: "plus.square.on.square")
        }
        .controlSize(.large)
      }

      Picker("Page size", selection: $pageSize) {
        ForEach(AppModel.ScratchPageSize.all) { size in
          Text(size.id).tag(size)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 280)
      .help("Page size used when creating a blank PDF.")
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
          SignatureDrawTab(onApply: { applySignature($0, source: .drawn) })
        } else if selectedTab == 1 {
          SignatureTypeTab(
            typedName: $typedName,
            selectedFontIndex: $selectedFontIndex,
            fontNames: scriptFonts,
            onApply: { applySignature(renderTypedSignature(), source: .typed) }
          )
        } else if selectedTab == 2 {
          SignatureImageTab(onApply: applySignature)
        } else {
          SignatureSavedTab(
            signatures: model.savedSignatures,
            onApply: applySavedSignature,
            onDelete: { model.deleteSignatureFromVault(id: $0) },
            onExport: exportSignature
          )
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

  private func signaturePlacementBounds() -> PDFRect? {
    guard let inspection = model.inspection else { return nil }
    if let region = model.pendingSignatureRegion {
      return region.bounds
    }
    let page = inspection.pages.indices.contains(model.selectedPageIndex)
      ? inspection.pages[model.selectedPageIndex] : inspection.pages[0]
    let w = page.bounds.width * 0.35
    let h = 60.0
    return PDFRect(x: page.bounds.x + (page.bounds.width - w) / 2,
                   y: page.bounds.y + 60,
                   width: w, height: h)
  }

  private func applySignature(_ imageData: Data, source: SignatureSource = .image) {
    guard let inspection = model.inspection,
      let pageIndex = model.pendingSignatureRegion?.pageIndex ?? inspection.pages.first?.pageIndex,
      let bounds = signaturePlacementBounds()
    else { return }

    model.applySignature(imageData, to: bounds, on: pageIndex)

    if saveForLater {
      let label = signatureLabel.isEmpty ? "Signature \(model.savedSignatures.count + 1)" : signatureLabel
      let dataURL = "data:image/png;base64,\(imageData.base64EncodedString())"
      model.saveSignatureToVault(label: label, dataURL: dataURL, source: source)
    }
  }

  /// Place a signature already stored in the library and record its reuse.
  private func applySavedSignature(_ sig: SavedSignature) {
    guard let data = sig.signatureImageData,
      let inspection = model.inspection,
      let pageIndex = model.pendingSignatureRegion?.pageIndex ?? inspection.pages.first?.pageIndex,
      let bounds = signaturePlacementBounds()
    else { return }

    model.applySignature(data, to: bounds, on: pageIndex)
    model.recordSignatureUse(id: sig.id)
  }

  /// Export a library signature as a standalone PNG via a save panel.
  private func exportSignature(_ sig: SavedSignature) {
    guard let data = sig.signatureImageData else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = (sig.label.isEmpty ? "signature" : sig.label) + ".png"
    if panel.runModal() == .OK, let url = panel.url {
      try? data.write(to: url)
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

struct SignatureDrawTab: View {
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

struct SignatureTypeTab: View {
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

struct SignatureImageTab: View {
  let onApply: (Data, SignatureSource) -> Void
  @State private var isImporterPresented = false
  @State private var loadedData: Data?
  @State private var cleanBackground = true
  /// 0 = conservative (keeps more), 1 = aggressive (removes more background).
  @State private var removalStrength: Double = 0.5
  @State private var eraseMode = false
  @State private var eraseStrokes: [EraseStroke] = []
  @State private var currentStroke: [CGPoint] = []
  @State private var containerSize: CGSize = .zero

  private var cleanContrast: Double { 0.5 - removalStrength * 0.45 }

  /// The signature data to apply: CV-cleaned + erase-applied when enabled.
  private var effectiveData: Data? {
    guard let data = loadedData else { return nil }
    let base: Data = cleanBackground
      ? (try? SignatureExtractor().clean(data)) ?? data
      : data
    if !eraseStrokes.isEmpty || !currentStroke.isEmpty {
      return (try? SignatureExtractor().applyingErase(
        base,
        strokes: eraseStrokes + (currentStroke.isEmpty ? [] : [EraseStroke(points: currentStroke)]),
        brush: 0.04
      )) ?? base
    }
    return base
  }

  private var displayedSize: CGSize? {
    guard let d = effectiveData, let img = NSImage(data: d) else { return nil }
    return img.size
  }

  private func drawnRect(in container: CGSize) -> CGRect {
    guard let n = displayedSize, n.width > 0, n.height > 0,
          container.width > 0, container.height > 0 else {
      return CGRect(origin: .zero, size: container)
    }
    let scale = min(container.width / n.width, container.height / n.height)
    let w = n.width * scale, h = n.height * scale
    return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
  }

  var body: some View {
    VStack(spacing: 8) {
      Toggle("Clean background (auto-extract ink)", isOn: $cleanBackground)
        .font(.caption)
        .padding(.horizontal, 24)
        .disabled(loadedData == nil)

      if let data = effectiveData, let img = NSImage(data: data) {
        GeometryReader { geo in
          let dRect = drawnRect(in: geo.size)
          let strokes = eraseStrokes + (currentStroke.isEmpty ? [] : [EraseStroke(points: currentStroke)])
          ZStack {
            Image(nsImage: img)
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            if eraseMode {
              Canvas { cx, _ in
                for stroke in strokes {
                  var path = Path()
                  for (i, p) in stroke.points.enumerated() {
                    let px = dRect.origin.x + p.x * dRect.width
                    let py = dRect.origin.y + p.y * dRect.height
                    if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                    else { path.addLine(to: CGPoint(x: px, y: py)) }
                  }
                  cx.stroke(path, with: .color(.red.opacity(0.55)),
                            lineWidth: max(3, dRect.width * 0.04))
                }
              }
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .contentShape(Rectangle())
          .gesture(eraseMode ? dragGesture(dRect: dRect) : nil)
          .onAppear { containerSize = geo.size }
          .onChange(of: geo.size) { _, newSize in containerSize = newSize }
        }
        .frame(height: 160)
        .padding(8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
      } else if loadedData == nil {
        Button("Choose an image…") { isImporterPresented = true }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      if loadedData != nil {
        HStack(spacing: 12) {
          Button("Choose another…") { isImporterPresented = true }
            .buttonStyle(.bordered)
          Spacer()
          if eraseMode {
            Button("Clear erases") { eraseStrokes.removeAll(); currentStroke.removeAll() }
              .buttonStyle(.bordered)
          }
          Toggle("Erase smudges", isOn: $eraseMode)
            .font(.caption)
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 24)

        if cleanBackground {
          VStack(alignment: .leading, spacing: 2) {
            Text("Background removal strength").font(.caption2)
            Slider(value: $removalStrength, in: 0...1, step: 0.01)
          }
          .padding(.horizontal, 24)
        }
      }

      HStack {
        Spacer()
        Button("Use signature") {
          if let data = effectiveData {
            onApply(data, cleanBackground ? .extracted : .image)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(effectiveData == nil)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 8)
    }
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: [.png, .jpeg],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let url = urls.first,
         let data = try? Data(contentsOf: url) {
        loadedData = data
        eraseStrokes.removeAll()
        currentStroke.removeAll()
      }
    }
  }

  private func dragGesture(dRect: CGRect) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        let nx = (value.location.x - dRect.origin.x) / dRect.width
        let ny = (value.location.y - dRect.origin.y) / dRect.height
        guard nx >= 0, nx <= 1, ny >= 0, ny <= 1 else { return }
        let p = CGPoint(x: nx, y: ny)
        if currentStroke.isEmpty { currentStroke = [p] } else { currentStroke.append(p) }
      }
      .onEnded { _ in
        if !currentStroke.isEmpty {
          eraseStrokes.append(EraseStroke(points: currentStroke))
          currentStroke.removeAll()
        }
      }
  }
}

struct SignatureSavedTab: View {
  let signatures: [SavedSignature]
  let onApply: (SavedSignature) -> Void
  let onDelete: (UUID) -> Void
  let onExport: (SavedSignature) -> Void
  @State private var selectedSignatureID: UUID?

  var body: some View {
    VStack(spacing: 8) {
      if signatures.isEmpty {
        Text("No saved signatures")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(signatures, selection: $selectedSignatureID) { sig in
          HStack(spacing: 8) {
            if let data = sig.signatureImageData, let img = NSImage(data: data) {
              Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(height: 30)
            }
            VStack(alignment: .leading, spacing: 1) {
              Text(sig.label).lineLimit(1)
              HStack(spacing: 6) {
                Text(sig.source.rawValue.capitalized)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                if sig.useCount > 0 {
                  Text("· used \(sig.useCount)×")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
            }
            Spacer()
          }
          .tag(sig.id)
          .contextMenu {
            Button("Use") { onApply(sig) }
            Button("Export PNG…") { onExport(sig) }
            Button("Delete", role: .destructive) { onDelete(sig.id) }
          }
        }
        .frame(maxHeight: 130)

        HStack {
          Button("Export…") {
            if let id = selectedSignatureID,
               let sig = signatures.first(where: { $0.id == id }) { onExport(sig) }
          }
          .disabled(selectedSignatureID == nil)
          Spacer()
          Button("Use signature") {
            if let id = selectedSignatureID,
               let sig = signatures.first(where: { $0.id == id }) { onApply(sig) }
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
  @AppStorage("layoutRestorePolicy") private var layoutRestorePolicyRaw: String =
    UserDefaults.standard.string(forKey: "layoutRestorePolicy") ?? AppModel.LayoutRestorePolicy.fixedDefault.rawValue

  public init() {}

  /// The stored raw value can pre-date a renamed case; normalize on read.
  private var resolvedPolicy: AppModel.LayoutRestorePolicy {
    AppModel.LayoutRestorePolicy(rawValue: layoutRestorePolicyRaw) ?? .fixedDefault
  }

  public var body: some View {
    Form {
      Section {
        Picker("Open documents with", selection: Binding(
          get: { resolvedPolicy },
          set: { layoutRestorePolicyRaw = $0.rawValue }
        )) {
          Text("Fixed default (fit width)").tag(AppModel.LayoutRestorePolicy.fixedDefault)
          Text("Layout last used on any document").tag(AppModel.LayoutRestorePolicy.lastUsedGlobally)
          Text("Each document's own last layout").tag(AppModel.LayoutRestorePolicy.perDocument)
        }
        .pickerStyle(.radioGroup)
        Text(
          "This controls zoom and orientation for documents without a saved layout. Where you were reading is always remembered per document. File ▸ Save This Layout pins zoom and orientation for one specific document, overriding this setting."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
      } header: {
        Text("Opening Documents")
      }

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

      AppearanceSettingsSection()
    }
    .formStyle(.grouped)
    .scenePadding()
    .frame(width: 460)
  }
}

// MARK: - Appearance Settings

/// Appearance section in Settings (light/dark/system + high contrast).
///
/// Uses `ThemeManager`'s persisted `@AppStorage` directly so it works
/// without an environment object — Settings is a separate scene.
private struct AppearanceSettingsSection: View {
  @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
  @AppStorage("isHighContrast") private var isHighContrast: Bool = false

  private var appearanceMode: AppearanceMode {
    get { AppearanceMode(rawValue: appearanceModeRaw) ?? .system }
    set { appearanceModeRaw = newValue.rawValue }
  }

  var body: some View {
    Section {
      Picker("Appearance", selection: Binding(
        get: { appearanceMode },
        set: { appearanceModeRaw = $0.rawValue }
      )) {
        ForEach(AppearanceMode.allCases, id: \.self) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      .pickerStyle(.radioGroup)

      Toggle("High contrast", isOn: $isHighContrast)
        .help("Thicker borders, stronger focus rings, and higher contrast ratios.")

      Text("High contrast is independent of light/dark. It strengthens visual boundaries for accessibility.")
        .font(.callout)
        .foregroundStyle(.secondary)
    } header: {
      Text("Appearance")
    }
  }
}
