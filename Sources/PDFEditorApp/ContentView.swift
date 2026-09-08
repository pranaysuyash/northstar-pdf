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
  let input = AdaptiveCommandContext.input(
    model: model,
    intent: .review,
    target: .documentScrolling
  )
  return AdaptiveCommandPolicy.standard
    .resolve(input)
    .allValidCommands
    .contains { $0.id == .export }
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
  @State private var recentDocumentToReselect: URL?
  @State private var isSecurityVaultPresented = false
  @State private var isBatchMergePresented = false
  @State private var isDocumentBrowserPresented = false
  @State private var isVersionComparePresented = false
  @State private var isGovernanceDashboardPresented = false
  @State private var isCompanionHealthPresented = false
  @State private var isHumanReviewPresented = false
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

  /// The window toolbar is a document instrument, not a disabled home-screen menu.
  private var showsDocumentToolbar: Bool {
    model.inspection != nil
  }

  public var body: some View {
    mainContent
      .applyTheme(using: themeManager)
      .toolbar {
        if showsDocumentToolbar {
          if readingParams.showToolbar {
            appToolbar
          } else {
            // Skim mode: only show essential items (mode picker + page nav)
            skimToolbar
          }
        }
      }
      .toolbarVisibility(
        showsDocumentToolbar ? .visible : .hidden,
        for: .windowToolbar
      )
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
          if let staleURL = recentDocumentToReselect {
            recentDocumentToReselect = nil
            if model.reselectRecentDocument(staleURL, replacement: url) {
              readingHistory.startSession(
                documentID: url.lastPathComponent,
                fileName: url.lastPathComponent,
                startPage: 0
              )
            }
          } else {
            openImportedPDF(url)
          }
        }
      }
      .alert(
        ProductIdentity.displayName,
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
      .sheet(isPresented: $model.isExportReviewPresented) {
        ExportReviewReceiptView(model: model) {
          model.continueExportReview()
        }
      }
      .sheet(isPresented: $model.isSignatureSheetPresented) {
        CommitFlowSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $model.isSecurityVaultPresented) {
        SecurityVaultSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isBatchMergePresented) {
        BatchMergeSheet(model: model)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $model.isDocumentBrowserPresented) {
        DocumentBrowserView(documentIndex: documentIndex)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $model.isVersionComparePresented) {
        VersionCompareView(versionStore: versionStore)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $model.isGovernanceDashboardPresented) {
        GovernanceDashboardView(engine: governanceEngine)
          .transition(.scale(scale: 0.96).combined(with: .opacity))
      }
      .sheet(isPresented: $isHumanReviewPresented) {
        HumanReviewPanelView()
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
            isCommandPalettePresented: $isAgentCommandPresented,
            annotationStore: annotationStore
          )

          if readingParams.showInspector {
            ContextualInspectorView(
              model: model,
              inspection: inspection,
              renderingPipeline: renderingPipeline,
              isSecurityVaultPresented: $model.isSecurityVaultPresented,
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
          isSecurityVaultPresented: $model.isSecurityVaultPresented
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
    .onChange(of: model.inspection?.source.sha256, initial: true) { _, digest in
      registerOpenedDocument(digest: digest)
    }
    .onChange(of: model.lastExportURL) { _, exportURL in
      recordVersionSnapshot(exportURL: exportURL)
    }
  }

  // MARK: - Document registry sync

  /// Feeds the corpus index and governance engine when a document opens.
  /// Both registries were read-side only before this hook; entries are
  /// session-scoped and keyed by content digest so re-registering the same
  /// document does not fork the index.
  private func registerOpenedDocument(digest: String?) {
    guard let digest, let inspection = model.inspection else { return }
    let source = inspection.source
    let path = model.sourceURL?.path ?? source.fileName
    _ = documentIndex.addEntry(
      DocumentIndexEntry(
        filePath: path,
        contentHash: digest,
        pageCount: inspection.pages.count,
        fileSize: Int64(source.byteCount),
        title: inspection.metadata.title,
        author: inspection.metadata.author
      )
    )
    runGovernanceCheck(for: inspection, path: path)
  }

  /// Runs the seeded governance rules against the open document. Prior
  /// auto-check violations are resolved first because
  /// `runComplianceCheck` appends rather than replaces.
  private func runGovernanceCheck(for inspection: DocumentInspection, path: String) {
    if governanceEngine.rules.isEmpty {
      seedGovernanceRules()
    }
    for violation in governanceEngine.violations where !violation.isResolved {
      governanceEngine.resolveViolation(id: violation.id)
    }
    governanceEngine.clearResolved()
    _ = governanceEngine.runComplianceCheck(
      documents: [
        (
          path: path,
          fileSize: Int64(inspection.source.byteCount),
          isEncrypted: inspection.security.isEncrypted,
          pageCount: inspection.pages.count
        )
      ]
    )
  }

  /// Conservative default rule set: two extreme ceilings that rarely fire and
  /// a disabled encryption mandate the user can enable from the dashboard.
  private func seedGovernanceRules() {
    governanceEngine.addRule(
      PolicyRule(
        type: .size,
        name: "Large document notice",
        description: "Flags documents larger than 250 MB.",
        isEnabled: true,
        severity: .warning,
        parameters: ["maxSizeBytes": String(250 * 1024 * 1024)]
      )
    )
    governanceEngine.addRule(
      PolicyRule(
        type: .retention,
        name: "Page count ceiling",
        description: "Flags documents above 5,000 pages.",
        isEnabled: true,
        severity: .info,
        parameters: ["maxPages": "5000"]
      )
    )
    governanceEngine.addRule(
      PolicyRule(
        type: .encryption,
        name: "Require encrypted documents",
        description: "Flags documents that are not encrypted.",
        isEnabled: false,
        severity: .warning,
        parameters: ["required": "true"]
      )
    )
  }

  /// Records a version snapshot when an export completes so the version
  /// compare surface reflects this session's export history.
  private func recordVersionSnapshot(exportURL: URL?) {
    guard exportURL != nil, let inspection = model.inspection else { return }
    versionStore.saveSnapshot(
      operations: model.operations,
      sourceHash: inspection.source.sha256,
      label: "Exported copy"
    )
  }

  private var welcomeContent: some View {
    WelcomeView(
      recentDocuments: model.recentDocuments,
      open: requestOpenDocument,
      openRecent: { model.open(url: $0) },
      removeRecent: { model.removeRecentDocument($0) },
      clearRecents: { model.clearRecentDocuments() },
      reselectRecent: { staleURL in
        recentDocumentToReselect = staleURL
        model.isImporterPresented = true
      },
      openDroppedPDF: openDroppedPDF,
      createBlank: { size in model.newDocument(pageSize: size) },
      createFromImages: { model.presentNewFromImagesPanel() },
      createFromClipboard: { model.newDocumentFromClipboard() },
      createFromMarkdown: { model.newDocumentFromMarkdown() }
    )
  }

  private func openDroppedPDF(_ providers: [NSItemProvider]) -> Bool {
    guard let provider = providers.first else { return false }
    provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.pdf.identifier) { url, inPlace, error in
      guard let url else {
        Task { @MainActor in
          model.alertMessage = "Could not open the dropped PDF: \(error?.localizedDescription ?? "the provider returned no file")"
        }
        return
      }
      if inPlace {
        Task { @MainActor in
          model.open(url: url)
        }
        return
      }

      // Some providers expose only a temporary representation. Copy it into
      // an app-owned file so the open remains valid after the callback ends.
      let destination = FileManager.default.temporaryDirectory
        .appendingPathComponent("PDFEditor-Drop-\(UUID().uuidString).pdf")
      do {
        try FileManager.default.copyItem(at: url, to: destination)
      } catch {
        Task { @MainActor in
          model.alertMessage = "Could not copy the dropped PDF into the local workspace: \(error.localizedDescription)"
        }
        return
      }
      Task { @MainActor in
        model.open(url: destination)
      }
    }
    return true
  }

  @ToolbarContentBuilder
  private var appToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {

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

    }

    ToolbarItemGroup {
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
    }

    ToolbarItem(placement: .primaryAction) {
      Menu {

        Button("Export Copy…", systemImage: "square.and.arrow.down") {
          hapticExport = UUID()
          model.presentExportReview()
        }
        .disabled(!canExportCopy(model))
        .help(exportCopyHelp(model))
        .sensoryFeedback(.success, trigger: hapticExport)

        Button("Export Sanitized Copy (No Metadata)…", systemImage: "lock.shield") {
          model.presentExportReview(profile: .sanitizedCopy)
        }
        .disabled(model.inspection == nil || model.liveDocument == nil)

        Button("Extract / Split Pages…", systemImage: "arrow.triangle.pull") {
          model.presentExportReview(profile: .pageExtraction)
        }
        .disabled(model.inspection == nil || model.liveDocument == nil)

        Button("Batch Merge Documents…", systemImage: "doc.on.doc") {
          isBatchMergePresented = true
        }

        Button("Synthesize Searchable OCR Layer", systemImage: "text.viewfinder") {
          model.synthesizeSearchableOCRLayer()
        }

        Divider()

        Button("Export Flattened Copy…", systemImage: "printer.dotmatrix") {
          model.presentExportReview(profile: .flattenedCopy)
        }
      } label: {
        Label("Export", systemImage: "square.and.arrow.down")
      }
      .accessibilityLabel("Export edited PDF copy")
      .help("Prepare an edited, sanitized, extracted, or flattened PDF copy.")
    }

    ToolbarItem {
      Menu {
        Button("Document Browser…", systemImage: "books.vertical") {
          model.isDocumentBrowserPresented = true
        }
        .help("Browse and organize your document corpus")

        Button("Version History…", systemImage: "clock.arrow.circlepath") {
          model.isVersionComparePresented = true
        }
        .help("Compare and revert document versions")

        Button("Governance Dashboard…", systemImage: "checkmark.shield") {
          model.isGovernanceDashboardPresented = true
        }
        .help("View compliance status and policy rules")

        Divider()

        Button("Companion Health…", systemImage: "heart.text.square") {
          isCompanionHealthPresented = true
        }
        .help("Provider status, egress connections, and bridge log")

        Button("Security & Privacy Vault…", systemImage: "lock.shield") {
          model.isSecurityVaultPresented = true
        }
        .keyboardShortcut("8", modifiers: [.command])
        .help("Hardware-isolated encrypted local stores and audit ledger (⌘8)")

        Divider()

        #if DEBUG
        // RG-135 reviewer panel: reads the developer checkout's governed
        // corpus manifest, so it is a QA surface, not an end-user feature.
        Button("Human Review Panel…", systemImage: "eye") {
          isHumanReviewPresented = true
        }
        .help("Record human visual confirmations for governed fixtures (RG-135)")
        #endif
      } label: {
        Label("Workspace", systemImage: "rectangle.3.group")
      }
      .accessibilityLabel("Workspace tools")
      .help("Document browser, version history, governance, companion health, and human review")
    }

    ToolbarItemGroup(placement: .secondaryAction) {
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

    Button {
        isAgentCommandPresented.toggle()
      } label: {
        Image(systemName: "sparkles")
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
      .keyboardShortcut("k", modifiers: .command)
      .disabled(model.inspection == nil)
      .accessibilityLabel("Agent Command Palette")
      .accessibilityHint("Command-K. Semantic actions, bulk fill, OCR, and diff tools.")
      .help("Open Agent Command Palette (⌘K) for semantic actions, bulk fill, OCR, and diff tools.")

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
          let pageIdx = model.selectedPageIndex
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

    // Content suggestion and fill status share one low-priority status region.
    ToolbarItem(placement: .status) {
      HStack(spacing: 8) {
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
    alert.informativeText = "Northstar uses an export-only workflow: Export Copy... creates a separate edited PDF and never overwrites the source. Choose Continue to Open to select another PDF, or Cancel to keep working."
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
  @State private var isDetailsExpanded = false
  @State private var isDiscardConfirmationPresented = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var hasRecoveryState: Bool {
    switch model.recoveryStatus {
    case .none:
      return !model.recoveryRecords.isEmpty || !model.recoveryDiagnostics.isEmpty
    case .available, .replayable, .metadataOnly, .corrupted, .saveFailed:
      return true
    }
  }

  private var recoveryTitle: String {
    switch model.recoveryStatus {
    case .none:
      return "Recovery metadata found"
    case .available:
      return "Recovery session available"
    case .replayable:
      return "Recovery session restored"
    case .metadataOnly:
      return "Recovery metadata only"
    case .corrupted:
      return "Recovery needs attention"
    case .saveFailed:
      return "Recovery save needs attention"
    }
  }

  private var recoveryDetail: String {
    switch model.recoveryStatus {
    case .none:
      return "No active replay is attached to this document."
    case .available:
      return "A local session can be inspected before you continue working."
    case .replayable:
      return "The local session was matched to this source and restored."
    case .metadataOnly:
      return "The session identity is present, but its value-bearing payload is unavailable."
    case .corrupted:
      return "The session could not be trusted as a complete recovery."
    case .saveFailed:
      return "The latest recovery write did not complete successfully."
    }
  }

  var body: some View {
    if hasRecoveryState {
      // Inset glass card with amber accent
      VStack(alignment: .leading, spacing: 0) {
        // ── Header row ──────────────────────────────────────────────────────
        HStack(spacing: 8) {
          // Status icon
          Image(systemName: model.recoveryStatus == .corrupted
            ? "exclamationmark.triangle.fill"
            : (model.recoveryStatus == .replayable ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill"))
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(model.recoveryStatus == .corrupted ? .red
              : (model.recoveryStatus == .replayable ? .green : .orange))
            .symbolEffect(.pulse, options: .repeating, isActive: model.recoveryStatus == .available)

          VStack(alignment: .leading, spacing: 1) {
            Text(recoveryTitle)
              .font(.caption.weight(.semibold))
            Text(model.recoveryRecords.isEmpty
              ? "No local records"
              : "\(model.recoveryRecords.count) record\(model.recoveryRecords.count == 1 ? "" : "s") found")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(.secondary)
          }

          Spacer()

          // Primary CTA: Restore (only when restore is meaningful)
          if model.recoveryStatus == .available || model.recoveryStatus == .metadataOnly {
            Button {
              withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
                model.loadSavedSession()
              }
            } label: {
              Label("Restore Edits", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
            .accessibilityLabel("Restore edits from recovery session")
            .help("Replay the saved recovery session onto this document")
          }

          // Expand/collapse toggle
          Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
              isDetailsExpanded.toggle()
            }
          } label: {
            Image(systemName: isDetailsExpanded ? "chevron.up" : "chevron.down")
              .font(.caption.weight(.medium))
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.secondary)
          .accessibilityLabel(isDetailsExpanded ? "Hide recovery details" : "Show recovery details")
          .help(isDetailsExpanded ? "Hide recovery details" : "Show recovery details")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        // ── Expanded tray ────────────────────────────────────────────────────
        if isDetailsExpanded {
          Divider()
            .padding(.horizontal, 12)

          VStack(alignment: .leading, spacing: 8) {
            Text(recoveryDetail)
              .font(.caption)
              .foregroundStyle(.secondary)

            if let lastSessionInfo = model.lastSessionInfo {
              HStack(spacing: 4) {
                Image(systemName: "clock")
                  .font(.caption2)
                  .foregroundStyle(.tertiary)
                Text(lastSessionInfo)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }

            ForEach(model.recoveryDiagnostics.prefix(3), id: \.self) { diagnostic in
              Label(diagnostic, systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            // Destructive action lives in the tray — clearly labelled
            Divider()

            Button(role: .destructive) {
              isDiscardConfirmationPresented = true
            } label: {
              Label("Discard Session", systemImage: "trash")
                .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .accessibilityLabel("Discard recovery session")
            .help("Permanently remove the local recovery records for this document")
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(
            model.recoveryStatus == .corrupted
              ? Color.red.opacity(0.35)
              : (model.recoveryStatus == .replayable ? Color.green.opacity(0.3) : Color.orange.opacity(0.25)),
            lineWidth: 1
          )
      )
      .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .transition(.move(edge: .top).combined(with: .opacity))
      .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: isDetailsExpanded)
      .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: model.recoveryStatus)
      .alert("Discard recovery session?", isPresented: $isDiscardConfirmationPresented) {
        Button("Cancel", role: .cancel) {}
        Button("Discard Session", role: .destructive) {
          _ = model.discardRecovery()
          withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75)) {
            isDetailsExpanded = false
          }
        }
      } message: {
        Text("This permanently removes the local recovery records for the current session. The source PDF and any exported copy remain unchanged.")
      }
    }
  }
}


// MARK: - Welcome View
private struct WelcomeView: View {
  let recentDocuments: [URL]
  let open: () -> Void
  let openRecent: (URL) -> Void
  let removeRecent: (URL) -> Void
  let clearRecents: () -> Void
  let reselectRecent: (URL) -> Void
  let openDroppedPDF: ([NSItemProvider]) -> Bool
  let createBlank: (CGSize) -> Void
  let createFromImages: () -> Void
  let createFromClipboard: () -> Void
  let createFromMarkdown: () -> Void
  @State private var pageSize = AppModel.ScratchPageSize.letter
  @State private var isDropTargeted = false
  @State private var illustrationIsVisible = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 30) {
        WelcomeHero(
          illustrationIsVisible: illustrationIsVisible,
          pageSize: $pageSize,
          open: open,
          createBlank: createBlank
        )

        HomeStartSurface(
          isTargeted: isDropTargeted,
          createFromImages: createFromImages,
          createFromClipboard: createFromClipboard,
          createFromMarkdown: createFromMarkdown
        )

        if !recentDocuments.isEmpty {
          recentDocumentsContent
        }
      }
      .frame(maxWidth: 900, minHeight: 560, alignment: .topLeading)
      .padding(.horizontal, 44)
      .padding(.vertical, 34)
      .contentShape(Rectangle())
      .overlay {
        if isDropTargeted {
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .padding(10)
            .allowsHitTesting(false)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      Color(nsColor: .windowBackgroundColor)
        .opacity(0.55)
    }
    .onDrop(of: [UTType.pdf.identifier], isTargeted: $isDropTargeted, perform: openDroppedPDF)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Northstar welcome surface")
    .accessibilityValue(isDropTargeted ? "Ready to open a dropped PDF" : "Drop a PDF anywhere in this window")
    .onAppear {
      if reduceMotion {
        illustrationIsVisible = true
      } else {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
          illustrationIsVisible = true
        }
      }
    }
  }

  @ViewBuilder
  private var recentDocumentsContent: some View {
    if !recentDocuments.isEmpty {
      RecentDocumentsList(
        documents: recentDocuments,
        open: openRecent,
        removeRecent: removeRecent,
        clearRecents: clearRecents,
        reselect: reselectRecent
      )
    }
  }
}

private struct WelcomeHero: View {
  let illustrationIsVisible: Bool
  @Binding var pageSize: AppModel.ScratchPageSize
  let open: () -> Void
  let createBlank: (CGSize) -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .center, spacing: 34) {
        illustration
        copy
      }
      VStack(alignment: .leading, spacing: 22) {
        illustration
        copy
      }
    }
  }

  private var illustration: some View {
    DocumentFlowIllustration(isVisible: illustrationIsVisible)
      .frame(width: 190, height: 220)
  }

  private var copy: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("A calmer place for PDFs")
        .font(.system(size: 30, weight: .semibold, design: .rounded))
        .foregroundStyle(.primary)
      Text("Open, understand, and shape a document without losing sight of the original.")
        .font(.title3)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 430, alignment: .leading)

      HStack(spacing: 10) {
        Button("Open a PDF…", action: open)
          .keyboardShortcut(.defaultAction)
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .accessibilityIdentifier("pdfEditor.home.open")

        Menu {
          ForEach(AppModel.ScratchPageSize.all) { size in
            Button {
              pageSize = size
              createBlank(size.size)
            } label: {
              if size == pageSize {
                Label(size.id, systemImage: "checkmark")
              } else {
                Text(size.id)
              }
            }
          }
        } label: {
          Label("New blank · \(pageSize.id)", systemImage: "doc.badge.plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier("pdfEditor.home.newBlank")
      }
    }
  }
}

private struct DocumentFlowIllustration: View {
  let isVisible: Bool

  var body: some View {
    VStack(spacing: 12) {
      ZStack(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color(nsColor: .textBackgroundColor))
          .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
          }
          .shadow(color: .black.opacity(0.08), radius: 14, y: 7)
          .frame(width: 138, height: 174)
          .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 5) {
                Image(systemName: "doc.richtext")
                  .foregroundStyle(.blue)
                Text("PDF")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
              ForEach(0..<4, id: \.self) { index in
                Capsule()
                  .fill(index == 1 ? Color.orange.opacity(0.72) : Color.primary.opacity(0.12))
                  .frame(width: index == 1 ? 78 : 94 - CGFloat(index * 10), height: 7)
              }
              Spacer()
              HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
                Text("review")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(18)
          }

        Image(systemName: "arrow.up.right")
          .font(.headline.weight(.semibold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(Color.accentColor, in: Circle())
          .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 4))
          .offset(x: 10, y: 10)
      }

      HStack(spacing: 8) {
        FlowStep(title: "Read", color: .blue)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.tertiary)
        FlowStep(title: "Shape", color: .orange)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.tertiary)
        FlowStep(title: "Export", color: .green)
      }
    }
    .scaleEffect(isVisible ? 1 : 0.94)
    .opacity(isVisible ? 1 : 0)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("PDF workflow: read, shape, and export a separate copy")
  }
}

private struct FlowStep: View {
  let title: String
  let color: Color

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(title)
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }
  }
}

private struct QuickActionCard: View {
  let title: String
  let detail: String
  let systemImage: String
  let action: () -> Void
  @State private var isHovered = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(isHovered ? 0.16 : 0.08))
            .frame(width: 38, height: 38)
          Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 4)

        Image(systemName: "chevron.forward")
          .font(.caption.weight(.bold))
          .foregroundStyle(isHovered ? Color.accentColor : Color.secondary.opacity(0.35))
          .offset(x: isHovered ? 2 : 0)
          .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.primary.opacity(0.025))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(
            isHovered ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08),
            lineWidth: isHovered ? 1.5 : 1
          )
      }
      .shadow(
        color: isHovered ? Color.black.opacity(0.07) : .clear,
        radius: 6,
        y: 2
      )
      .scaleEffect(isHovered ? 1.012 : 1.0)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      if reduceMotion {
        isHovered = hovering
      } else {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
          isHovered = hovering
        }
      }
    }
    .accessibilityLabel("Create from \(title)")
    .accessibilityHint(detail)
  }
}

private struct HomeStartSurface: View {
  let isTargeted: Bool
  let createFromImages: () -> Void
  let createFromClipboard: () -> Void
  let createFromMarkdown: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .fill(isTargeted ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
            .frame(width: 44, height: 44)
          Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
            .font(.title3.weight(.medium))
            .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
            .scaleEffect(isTargeted ? 1.15 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65), value: isTargeted)
        }

        VStack(alignment: .leading, spacing: 3) {
          Text(isTargeted ? "Release to open in Northstar" : "Drop a PDF anywhere in this window")
            .font(.headline)
            .foregroundStyle(.primary)
          Text("The original file remains safely untouched. Edits create a separate export copy.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 12)

        HStack(spacing: 6) {
          Image(systemName: "checkmark.shield")
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.secondary.opacity(0.8))
          Text("Non-destructive")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04), in: Capsule())
      }

      Divider()

      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) {
          QuickActionCard(title: "Images", detail: "Turn images into pages", systemImage: "photo.on.rectangle", action: createFromImages)
          QuickActionCard(title: "Clipboard", detail: "Start from copied text", systemImage: "doc.on.clipboard", action: createFromClipboard)
          QuickActionCard(title: "Markdown", detail: "Compose structured document", systemImage: "text.document", action: createFromMarkdown)
        }
        VStack(alignment: .leading, spacing: 10) {
          QuickActionCard(title: "Images", detail: "Turn images into pages", systemImage: "photo.on.rectangle", action: createFromImages)
          QuickActionCard(title: "Clipboard", detail: "Start from copied text", systemImage: "doc.on.clipboard", action: createFromClipboard)
          QuickActionCard(title: "Markdown", detail: "Compose structured document", systemImage: "text.document", action: createFromMarkdown)
        }
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
    .background(
      Color.accentColor.opacity(isTargeted ? 0.12 : 0.035),
      in: RoundedRectangle(cornerRadius: 18, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(
          isTargeted ? Color.accentColor : Color.primary.opacity(0.12),
          style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [6, 5])
        )
    }
    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isTargeted)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("PDF start workspace")
    .accessibilityValue(isTargeted ? "Ready to open a dropped PDF" : "Drop a PDF or create a document")
    .accessibilityIdentifier("pdfEditor.home.startWorkspace")
  }
}

private struct RecentDocumentRowView: View {
  let url: URL
  let isAvailable: Bool
  let open: (URL) -> Void
  let removeRecent: (URL) -> Void
  let reselect: (URL) -> Void
  @State private var isHovered = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let filename = url.lastPathComponent
    Group {
      if isAvailable {
        actionButton(filename: filename)
      } else {
        locateButton(filename: filename)
      }
    }
    .background {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
    }
    .onHover { hovering in
      if reduceMotion {
        isHovered = hovering
      } else {
        withAnimation(.easeOut(duration: 0.15)) {
          isHovered = hovering
        }
      }
    }
    .contextMenu {
      if isAvailable {
        Button("Open") {
          open(url)
        }
        Button("Reveal in Finder") {
          NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        Button("Copy Path") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(url.path, forType: .string)
        }
        Divider()
      }
      Button("Remove from Recents", role: .destructive) {
        removeRecent(url)
      }
    }
  }

  @ViewBuilder
  private func actionButton(filename: String) -> some View {
    Button {
      open(url)
    } label: {
      rowContent {
        Image(systemName: "arrow.up.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(isHovered ? Color.accentColor : Color.secondary.opacity(0.6))
          .offset(x: isHovered ? 1 : 0, y: isHovered ? -1 : 0)
          .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
      }
    }
    .buttonStyle(.plain)
    .contentShape(Rectangle())
    .help("Open \(filename)")
    .accessibilityLabel("Open \(filename)")
    .accessibilityHint("Opens the recent PDF")
    .accessibilityIdentifier("pdfEditor.home.recent.\(filename)")
  }

  @ViewBuilder
  private func locateButton(filename: String) -> some View {
    rowContent {
      Button("Locate…", systemImage: "folder") {
        reselect(url)
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      .help("Choose the current location of \(filename)")
      .accessibilityLabel("Locate \(filename)")
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(filename) needs to be located again")
    .accessibilityHint("Choose its current location to continue")
    .accessibilityIdentifier("pdfEditor.home.recent.\(filename)")
  }

  @ViewBuilder
  private func rowContent<Accessory: View>(@ViewBuilder accessory: () -> Accessory) -> some View {
    HStack(spacing: 10) {
      ZStack {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill((isAvailable ? Color.accentColor : Color.orange).opacity(0.12))
          .frame(width: 28, height: 28)
        Image(systemName: isAvailable ? "doc.text.fill" : "doc.badge.ellipsis")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(isAvailable ? Color.accentColor : Color.orange)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(url.deletingPathExtension().lastPathComponent)
          .font(.callout.weight(.medium))
          .foregroundStyle(.primary)
          .lineLimit(1)
        Text(isAvailable ? url.deletingLastPathComponent().lastPathComponent : "File needs to be located again")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 10)

      accessory()
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
  }
}

private struct RecentDocumentsList: View {
  let documents: [URL]
  let open: (URL) -> Void
  let removeRecent: (URL) -> Void
  let clearRecents: () -> Void
  let reselect: (URL) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Continue where you left off")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        Button("Clear Recents") {
          clearRecents()
        }
        .buttonStyle(.plain)
        .font(.caption)
        .foregroundStyle(.secondary)
        .help("Remove all recent document shortcuts")
      }

      VStack(spacing: 2) {
        ForEach(documents, id: \.self) { url in
          let isAvailable = FileManager.default.fileExists(atPath: url.path)
          RecentDocumentRowView(
            url: url,
            isAvailable: isAvailable,
            open: open,
            removeRecent: removeRecent,
            reselect: reselect
          )
        }
      }
    }
    .frame(maxWidth: 420, alignment: .leading)
    .accessibilityIdentifier("pdfEditor.home.recentDocuments")
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
  @State private var didClearAdaptiveCommandHistory = false
  private let adaptiveCommandHistory = AdaptiveCommandHistory.shared

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
        Toggle(
          "Use recent commands to rank contextual actions",
          isOn: Binding(
            get: { adaptiveCommandHistory.isPersonalizationEnabled },
            set: { adaptiveCommandHistory.setPersonalizationEnabled($0) }
          )
        )

        Button("Clear Recent Commands and Pins") {
          adaptiveCommandHistory.clear()
          didClearAdaptiveCommandHistory = true
        }
        .disabled(adaptiveCommandHistory.recentCommandIDs.isEmpty && adaptiveCommandHistory.pinnedCommandIDs.isEmpty)

        if didClearAdaptiveCommandHistory {
          Label("Recent command history and pins cleared.", systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        Text("Only command IDs are stored locally. Document content, names, selections, timestamps, and network activity are never recorded for this preference.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } header: {
        Text("Adaptive Commands")
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
