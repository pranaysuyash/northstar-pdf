import AppKit
import Observation
import PDFEditorCore
import PDFKit

struct SearchMatch: Identifiable, Equatable, Sendable {
  let id = UUID()
  let pageIndex: Int
  let query: String
  let snippet: String
  let charStart: Int
  let charLength: Int
}

struct ManualTextPlacement: Equatable, Sendable {
  let pageIndex: Int
  let bounds: PDFRect
}

@Observable
@MainActor
final class AppModel {
  private let provider = PDFKitProvider()
  private let sessionStore: FileSessionStore

  var inspection: DocumentInspection?
  var liveDocument: PDFDocument?
  var sourceURL: URL?
  var operations: [EditOperation] = []
  var selectedPageIndex = 0
  var selectedFieldID: String?
  var selectedCandidateID: UUID?
  var isManualPlacementMode = false
  var manualTextPlacement: ManualTextPlacement?
  var isManualTextSheetPresented = false
  var manualTextDraft = ""
  var isImporterPresented = false
  var statusMessage: String?
  var alertMessage: String?
  var exportReport: ValidationReport?

  var readerViewMode: ReaderViewMode = .continuous
  var readerScaleMode: ReaderScaleMode = .fitWidth
  var readerZoom = 1.0
  var readerRotation = 0
  var pageJumpInput = ""

  var searchQuery = ""
  var searchMatches: [SearchMatch] = []
  var selectedSearchMatchIndex: Int?

  var isPasswordSheetPresented = false
  var passwordAttempt = ""
  private var passwordPendingURL: URL?
  private var cachedSourceData: Data?

  // Session persistence
  private var currentSessionID: UUID?
  var hasSavedSession: Bool = false
  var lastSessionInfo: String?

  private struct ReplayCheckpoint {
    let operationCount: Int
    let document: PDFDocument
  }

  // Checkpoints bound undo replay work without making a full-document copy for
  // every edit. The source replay path remains the correctness fallback when a
  // checkpoint is unavailable or cannot be copied.
  private static let replayCheckpointInterval = 8
  private static let maximumReplayCheckpoints = 8
  private var replayCheckpoints: [ReplayCheckpoint] = []

  init(sessionStore: FileSessionStore = FileSessionStore(directory: FileSessionStore.defaultDirectory)) {
    self.sessionStore = sessionStore
  }

  var selectedField: NativeField? {
    guard let selectedFieldID else { return nil }
    return inspection?.fields.first { $0.id == selectedFieldID }
  }

  var selectedCandidate: RegionCandidate? {
    guard let selectedCandidateID else { return nil }
    return inspection?.candidates.first { $0.id == selectedCandidateID }
  }

  var selectedSearchMatch: SearchMatch? {
    guard let index = selectedSearchMatchIndex,
      index >= 0,
      index < searchMatches.count
    else { return nil }
    return searchMatches[index]
  }

  var canClearSearch: Bool {
    !searchQuery.isEmpty || !searchMatches.isEmpty
  }

  var selectedPageLabel: String {
    inspection?.pages[safe: selectedPageIndex]?.pageLabel ?? "\(selectedPageIndex + 1)"
  }

  var currentPageCount: Int {
    inspection?.pages.count ?? 0
  }

  func open(url: URL, password: String? = nil) {
    do {
      let hasSecurityScope = url.startAccessingSecurityScopedResource()
      defer {
        if hasSecurityScope {
          url.stopAccessingSecurityScopedResource()
        }
      }
      let nextInspection = try provider.inspect(url: url, password: password)
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard let document = PDFDocument(data: data) else {
        throw PDFEditorError.cannotOpen(url.lastPathComponent)
      }
      if document.isLocked, let password {
        _ = document.unlock(withPassword: password)
      }

      inspection = nextInspection
      liveDocument = document
      sourceURL = url
      cachedSourceData = data
      operations = []
      replayCheckpoints = []
      selectedPageIndex = 0
      selectedFieldID = nil
      selectedCandidateID = nil
      isManualPlacementMode = false
      manualTextPlacement = nil
      isManualTextSheetPresented = false
      manualTextDraft = ""
      selectedSearchMatchIndex = nil
      searchQuery = ""
      searchMatches = []
      exportReport = nil
      passwordAttempt = ""
      isPasswordSheetPresented = false
      pageJumpInput = ""

      // Attempt to load a saved session for this source
      if let savedSession = try? sessionStore.load(sourceDigest: nextInspection.source.sha256) {
        currentSessionID = savedSession.sessionID
        hasSavedSession = true
        lastSessionInfo = "Session from \(savedSession.lastModifiedAt.formatted(date: .abbreviated, time: .shortened)) — \(savedSession.operationCount) edits, \(savedSession.completionProgress.confirmedCount)/\(savedSession.completionProgress.totalCandidates) fields filled"
        // Restore candidate statuses from session
        var restoredCandidates = nextInspection.candidates
        for candidate in restoredCandidates {
          if let savedStatus = savedSession.candidateStatuses[candidate.id] {
            restoredCandidates[restoredCandidates.firstIndex(where: { $0.id == candidate.id })!].status = savedStatus
          }
        }
        inspection = DocumentInspection(
          source: nextInspection.source,
          pages: nextInspection.pages,
          fields: nextInspection.fields,
          candidates: restoredCandidates,
          warnings: nextInspection.warnings,
          links: nextInspection.links,
          outlines: nextInspection.outlines,
          metadata: nextInspection.metadata,
          permissions: nextInspection.permissions,
          attachments: nextInspection.attachments,
          accessibility: nextInspection.accessibility,
          security: nextInspection.security
        )
        operations = savedSession.operations
        selectedPageIndex = savedSession.selectedPageIndex
        statusMessage = "Opened \(url.lastPathComponent) — restored session from \(savedSession.lastModifiedAt.formatted(date: .abbreviated, time: .shortened))"
      } else {
        hasSavedSession = false
        lastSessionInfo = nil
        statusMessage = "Opened \(url.lastPathComponent)"
      }
    } catch {
      switch error {
      case PDFEditorError.passwordRequired:
        passwordPendingURL = url
        passwordAttempt = ""
        isPasswordSheetPresented = true
      case PDFEditorError.passwordIncorrect:
        passwordPendingURL = url
        passwordAttempt = ""
        statusMessage = "Wrong password. Try again."
        isPasswordSheetPresented = true
      default:
        alertMessage = error.localizedDescription
      }
    }
  }

  func submitPassword() {
    guard let url = passwordPendingURL else { return }
    let attempted = passwordAttempt
    passwordAttempt = ""
    isPasswordSheetPresented = false
    open(url: url, password: attempted)
  }

  func dismissPasswordPrompt() {
    passwordPendingURL = nil
    passwordAttempt = ""
    isPasswordSheetPresented = false
  }

  func resetDocument() {
    inspection = nil
    liveDocument = nil
    sourceURL = nil
    cachedSourceData = nil
    operations = []
    replayCheckpoints = []
    selectedPageIndex = 0
    selectedFieldID = nil
    selectedCandidateID = nil
    selectedSearchMatchIndex = nil
    searchQuery = ""
    searchMatches = []
    exportReport = nil
    currentSessionID = nil
    hasSavedSession = false
    lastSessionInfo = nil
    statusMessage = "New document"
    resetReaderState()
  }

  func currentValue(for field: NativeField) -> String {
    guard let page = liveDocument?.page(at: field.pageIndex) else { return field.value ?? "" }
    let widgets = page.annotations.filter {
      $0.type == "Widget"
        && $0.fieldName == field.name
    }
    if field.kind == .button {
      return widgets.first(where: { $0.buttonWidgetState == PDFWidgetCellState(rawValue: 1) })?
        .buttonWidgetStateString ?? ""
    }
    return widgets.first?.widgetStringValue ?? field.value ?? ""
  }

  func buttonOptions(for field: NativeField) -> [String] {
    guard let page = liveDocument?.page(at: field.pageIndex) else { return [] }
    var seen = Set<String>()
    return page.annotations
      .filter { $0.type == "Widget" && $0.fieldName == field.name }
      .compactMap { annotation -> String? in
        let value = annotation.buttonWidgetStateString.trimmingCharacters(
          in: .whitespacesAndNewlines)
        guard !value.isEmpty, seen.insert(value).inserted else { return nil }
        return value
      }
  }

  func applyFieldValue(_ value: String) {
    guard let field = selectedField, let liveDocument else { return }
    let operation = EditOperation(
      pageIndex: field.pageIndex,
      targetID: field.name,
      kind: .nativeFieldValue,
      value: value,
      bounds: field.bounds,
      previousValue: currentValue(for: field),
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds),
      payload: .text(value)
    )
    do {
      try provider.apply(operation, to: liveDocument)
      operations.append(operation)
      recordReplayCheckpointIfNeeded()
      autoSaveSession()
      statusMessage = "Applied a reversible native-field edit."
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  func applyOverlay(_ value: String) {
    guard let candidate = selectedCandidate else { return }
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if candidate.entryMode == .characterGrid {
      guard !candidate.memberBounds.isEmpty else {
        statusMessage =
          "This character grid has no cell geometry. Use manual placement or rerun inspection."
        return
      }
      guard Array(normalized).count <= candidate.memberBounds.count else {
        statusMessage = "The value is longer than the detected character grid."
        return
      }
    }
    applyTextOverlay(
      value: normalized,
      pageIndex: candidate.pageIndex,
      bounds: candidate.bounds,
      candidateID: candidate.id,
      markCandidateConfirmed: true,
      payload: candidate.entryMode == .characterGrid
        ? .characterGrid(text: normalized, cells: candidate.memberBounds)
        : .text(normalized)
    )
  }

  func applyStaticChoiceMark(cellIndex: Int) {
    guard let candidate = selectedCandidate,
      [.checkbox, .radioGroup].contains(candidate.entryMode),
      candidate.memberBounds.indices.contains(cellIndex)
    else {
      statusMessage = "Choose one detected choice cell before marking it."
      return
    }
    let cell = candidate.memberBounds[cellIndex]
    applyTextOverlay(
      value: "X",
      pageIndex: candidate.pageIndex,
      bounds: cell,
      candidateID: candidate.id,
      markCandidateConfirmed: true,
      payload: .choiceMark(cell: cell)
    )
  }

  func synthesizeNativeField() {
    guard let candidate = selectedCandidate,
      candidate.isDirectlyEditable,
      let liveDocument
    else {
      statusMessage = "Only reviewed text-like regions can become native fields."
      return
    }
    let fieldName = "static_\(candidate.id.uuidString.replacingOccurrences(of: "-", with: "_"))"
    let operation = EditOperation(
      pageIndex: candidate.pageIndex,
      targetID: fieldName,
      kind: .synthesizeNativeField,
      value: "",
      bounds: candidate.bounds,
      candidateID: candidate.id,
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: candidate.pageIndex, rect: candidate.bounds),
      payload: .nativeField(fieldType: candidate.suggestedFieldType ?? .text)
    )
    do {
      try provider.apply(operation, to: liveDocument)
      operations.append(operation)
      recordReplayCheckpointIfNeeded()
      autoSaveSession()
      updateCandidate(candidate.id, status: .confirmed)
      statusMessage =
        "Created a reviewed native text field overlay. Export will preserve the static page and reopen the new field."
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  func applyManualText() {
    guard let placement = manualTextPlacement else { return }
    let value = manualTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      statusMessage = "Enter text before placing it."
      return
    }
    applyTextOverlay(
      value: value,
      pageIndex: placement.pageIndex,
      bounds: placement.bounds,
      candidateID: nil,
      markCandidateConfirmed: false,
      payload: .text(value)
    )
    manualTextPlacement = nil
    manualTextDraft = ""
    isManualTextSheetPresented = false
  }

  func beginManualTextPlacement() {
    guard liveDocument != nil else {
      statusMessage = "Open a PDF before placing text."
      return
    }
    selectedCandidateID = nil
    selectedFieldID = nil
    manualTextPlacement = nil
    isManualPlacementMode = true
    statusMessage = "Click the document where the new text should begin."
  }

  func cancelManualTextPlacement() {
    isManualPlacementMode = false
    manualTextPlacement = nil
    manualTextDraft = ""
    isManualTextSheetPresented = false
    statusMessage = "Manual text placement cancelled."
  }

  func receiveManualPlacement(pageIndex: Int, point: CGPoint) {
    guard isManualPlacementMode else { return }
    receiveTextPlacement(pageIndex: pageIndex, point: point)
  }

  /// Double-click placement is the direct-on-page path. It uses the same
  /// page-space bounds and reversible overlay operation as toolbar placement.
  func beginDirectTextPlacement(pageIndex: Int, point: CGPoint) {
    guard liveDocument != nil else {
      statusMessage = "Open a PDF before placing text."
      return
    }
    selectedCandidateID = nil
    selectedFieldID = nil
    receiveTextPlacement(pageIndex: pageIndex, point: point)
  }

  private func receiveTextPlacement(pageIndex: Int, point: CGPoint) {
    guard let page = liveDocument?.page(at: pageIndex) else { return }
    let pageBounds = page.bounds(for: .cropBox)
    let width = min(180.0, max(80.0, pageBounds.width - 16.0))
    let height = min(28.0, max(18.0, pageBounds.height - 16.0))
    let x = min(max(point.x, pageBounds.minX + 8.0), pageBounds.maxX - width - 8.0)
    let y = min(max(point.y, pageBounds.minY + 8.0), pageBounds.maxY - height - 8.0)
    manualTextPlacement = ManualTextPlacement(
      pageIndex: pageIndex,
      bounds: PDFRect(x: x, y: y, width: width, height: height)
    )
    isManualPlacementMode = false
    manualTextDraft = ""
    isManualTextSheetPresented = true
    statusMessage = "Enter the text for the selected document area."
  }

  func rejectSelectedCandidate() {
    guard let candidate = selectedCandidate else { return }
    updateCandidate(candidate.id, status: .rejected)
    selectedCandidateID = nil
    statusMessage = "Dismissed the suggested area. The source PDF was not changed."
  }

  func restoreCandidate(_ candidateID: UUID) {
    updateCandidate(candidateID, status: .suggested)
    statusMessage = "Restored the suggested area for review."
  }

  private func applyTextOverlay(
    value: String,
    pageIndex: Int,
    bounds: PDFRect,
    candidateID: UUID?,
    markCandidateConfirmed: Bool,
    payload: EditPayload
  ) {
    guard let liveDocument else { return }
    let operation = EditOperation(
      pageIndex: pageIndex,
      kind: .overlayText,
      value: value,
      bounds: bounds,
      candidateID: candidateID,
      sourceDigest: inspection?.source.sha256,
      coordinate: PDFPageRegion(pageIndex: pageIndex, rect: bounds),
      payload: payload
    )
    do {
      try provider.apply(operation, to: liveDocument)
      operations.append(operation)
      recordReplayCheckpointIfNeeded()
      if markCandidateConfirmed, let candidateID {
        updateCandidate(candidateID, status: .confirmed)
      }
      if case .characterGrid = payload {
        statusMessage = "Placed one glyph per detected character cell. The edit remains reversible."
      } else {      autoSaveSession()
      statusMessage =
        candidateID == nil
          ? "Added reversible text to the document preview."
          : "Added reviewed text. It remains an overlay, not a native PDF field."
      }
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  private func updateCandidate(_ candidateID: UUID, status: CandidateStatus) {
    guard let current = inspection else { return }
    let candidates = current.candidates.map { candidate in
      guard candidate.id == candidateID else { return candidate }
      var updated = candidate
      updated.status = status
      return updated
    }
    inspection = DocumentInspection(
      source: current.source,
      pages: current.pages,
      fields: current.fields,
      candidates: candidates,
      warnings: current.warnings,
      links: current.links,
      outlines: current.outlines,
      metadata: current.metadata,
      permissions: current.permissions,
      attachments: current.attachments,
      accessibility: current.accessibility,
      security: current.security
    )
  }

  var activeCandidates: [RegionCandidate] {
    inspection?.candidates.filter { $0.status != .rejected } ?? []
  }

  var dismissedCandidates: [RegionCandidate] {
    inspection?.candidates.filter { $0.status == .rejected } ?? []
  }

  private func recordReplayCheckpointIfNeeded() {
    guard operations.count > 0,
      operations.count % Self.replayCheckpointInterval == 0,
      let liveDocument,
      let snapshot = liveDocument.copy() as? PDFDocument
    else {
      return
    }

    replayCheckpoints.append(
      ReplayCheckpoint(operationCount: operations.count, document: snapshot))
    if replayCheckpoints.count > Self.maximumReplayCheckpoints {
      replayCheckpoints.removeFirst(replayCheckpoints.count - Self.maximumReplayCheckpoints)
    }
  }

  private func replayDocument(upTo operationCount: Int) throws
    -> (document: PDFDocument, usedCheckpoint: Bool)
  {
    guard operationCount >= 0, operationCount <= operations.count else {
      throw PDFEditorError.invalidOperation("The requested edit history position is invalid.")
    }

    for checkpoint in replayCheckpoints.reversed()
    where checkpoint.operationCount <= operationCount {
      guard let restored = checkpoint.document.copy() as? PDFDocument else { continue }
      do {
        for operation in operations.dropFirst(checkpoint.operationCount)
          .prefix(operationCount - checkpoint.operationCount)
        {
          try provider.apply(operation, to: restored)
        }
        return (restored, true)
      } catch {
        // A stale or provider-invalid checkpoint is not an authority. Fall
        // back to the source replay path, which preserves the old behavior.
        continue
      }
    }

    let data: Data
    if let cached = cachedSourceData {
      data = cached
    } else if let sourceURL {
      data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
      cachedSourceData = data
    } else {
      throw PDFEditorError.cannotOpen("The active PDF source is unavailable.")
    }
    guard let rebuilt = PDFDocument(data: data) else {
      throw PDFEditorError.cannotOpen(sourceURL?.lastPathComponent ?? "PDF")
    }
    for operation in operations.prefix(operationCount) {
      try provider.apply(operation, to: rebuilt)
    }
    return (rebuilt, false)
  }

  func undoLastEdit() {
    guard !operations.isEmpty else { return }
    let removedOperation = operations[operations.count - 1]
    let targetOperationCount = operations.count - 1
    do {
      let replay = try replayDocument(upTo: targetOperationCount)
      liveDocument = replay.document
      operations.removeLast()
      replayCheckpoints.removeAll { $0.operationCount > operations.count }
      if let candidateID = removedOperation.candidateID {
        updateCandidate(candidateID, status: .suggested)
      }
      // Viewer rotation is derived UI state, not an edit operation. Reapply it
      // after restoring a source or checkpoint document.
      refreshRotation()
      autoSaveSession()
      statusMessage = replay.usedCheckpoint
        ? "Removed the last edit and restored the preview from an in-memory checkpoint."
        : "Removed the last edit and rebuilt the preview from the cached source."
    } catch {
      alertMessage = "Undo could not rebuild the preview: \(error.localizedDescription)"
    }
  }

  func selectNextCandidate() {
    let candidates = activeCandidates
    guard !candidates.isEmpty else { return }
    let currentID = selectedCandidateID
    let currentIndex = candidates.firstIndex { $0.id == currentID } ?? -1
    let nextIndex = (currentIndex + 1) % candidates.count
    let next = candidates[nextIndex]
    selectedCandidateID = next.id
    selectedFieldID = nil
    jumpToPage(next.pageIndex)
    statusMessage =
      "Selected candidate \(nextIndex + 1) of \(candidates.count) (\(next.suggestedFieldType?.rawValue ?? "field"))"
  }

  func selectPreviousCandidate() {
    let candidates = activeCandidates
    guard !candidates.isEmpty else { return }
    let currentID = selectedCandidateID
    let currentIndex = candidates.firstIndex { $0.id == currentID } ?? 0
    let prevIndex = (currentIndex - 1 + candidates.count) % candidates.count
    let prev = candidates[prevIndex]
    selectedCandidateID = prev.id
    selectedFieldID = nil
    jumpToPage(prev.pageIndex)
    statusMessage =
      "Selected candidate \(prevIndex + 1) of \(candidates.count) (\(prev.suggestedFieldType?.rawValue ?? "field"))"
  }

  func runOCROnSelectedPage() {
    guard let page = liveDocument?.page(at: selectedPageIndex),
      let pageSnapshot = inspection?.pages[safe: selectedPageIndex]
    else {
      statusMessage = "Select a valid page before running OCR."
      return
    }
    do {
      let ocrProvider = VisionOCRProvider()
      let observations = try ocrProvider.recognize(page: page, pageIndex: selectedPageIndex)
      guard !observations.isEmpty else {
        statusMessage = "No additional text recognized by OCR on page \(selectedPageIndex + 1)."
        return
      }
      let pageLines = observations.map {
        $0.toPageSpace(pageBounds: pageSnapshot.bounds, pageIndex: selectedPageIndex)
      }
      let ocrCandidates = StaticRegionDetector.detect(lines: pageLines)

      if let current = inspection {
        var existingCandidates = current.candidates
        for c in ocrCandidates {
          if !existingCandidates.contains(where: {
            $0.pageIndex == c.pageIndex && abs($0.bounds.x - c.bounds.x) < 10
              && abs($0.bounds.y - c.bounds.y) < 10
          }) {
            existingCandidates.append(c)
          }
        }
        inspection = DocumentInspection(
          source: current.source,
          pages: current.pages,
          fields: current.fields,
          candidates: existingCandidates,
          warnings: current.warnings,
          links: current.links,
          outlines: current.outlines,
          metadata: current.metadata,
          permissions: current.permissions,
          attachments: current.attachments,
          accessibility: current.accessibility,
          security: current.security
        )
        statusMessage =
          "OCR recognized \(observations.count) text regions (\(ocrCandidates.count) candidate blanks)."
      }
    } catch {
      alertMessage = "OCR recognition error: \(error.localizedDescription)"
    }
  }

  func export() {
    guard let sourceURL else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "-filled.pdf"
    panel.begin { [weak self] response in
      guard response == .OK, let destination = panel.url else { return }
      self?.performExport(sourceURL: sourceURL, destination: destination)
    }
  }

  func jumpToPage(_ index: Int) {
    let clamped = min(max(index, 0), max(0, currentPageCount - 1))
    selectedPageIndex = clamped
    selectedSearchMatchIndex = nil
  }

  func runPageJump() {
    guard let index = Int(pageJumpInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      statusMessage = "Enter a valid page number."
      return
    }
    jumpToPage(index - 1)
  }

  func clearSearch() {
    searchQuery = ""
    searchMatches = []
    selectedSearchMatchIndex = nil
  }

  func runSearch() {
    guard let document = liveDocument else {
      searchMatches = []
      selectedSearchMatchIndex = nil
      return
    }
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      searchMatches = []
      selectedSearchMatchIndex = nil
      return
    }

    var nextMatches: [SearchMatch] = []
    let needle = query.lowercased()
    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex), let pageText = page.string else { continue }
      let haystack = pageText.lowercased() as NSString
      guard haystack.length > 0 else { continue }
      var cursor = 0
      while cursor < haystack.length {
        let range = haystack.range(
          of: needle, options: [],
          range: NSRange(location: cursor, length: haystack.length - cursor))
        if range.location == NSNotFound { break }
        let snippetRange = NSRange(
          location: max(0, range.location - 32),
          length: min(110, max(0, haystack.length - max(0, range.location - 32))))
        let snippet = haystack.substring(with: snippetRange).replacingOccurrences(
          of: "\n", with: " ")
        nextMatches.append(
          SearchMatch(
            pageIndex: pageIndex,
            query: query,
            snippet: snippet,
            charStart: range.location,
            charLength: range.length
          )
        )
        let nextCursor = range.location + max(range.length, 1)
        if nextCursor >= haystack.length { break }
        cursor = nextCursor
      }
    }
    searchMatches = nextMatches
    selectedSearchMatchIndex = nextMatches.isEmpty ? nil : 0
    statusMessage =
      nextMatches.isEmpty
      ? "No matches found for \(query)." : "Found \(nextMatches.count) matches for \(query)."
    if let first = selectedSearchMatch {
      jumpToPage(first.pageIndex)
    }
  }

  func copyCurrentPageText() {
    guard let page = liveDocument?.page(at: selectedPageIndex) else {
      statusMessage = "Open a page first before copying."
      return
    }
    let text = page.string ?? ""
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if pasteboard.setString(text, forType: .string) {
      statusMessage = "Copied page \(selectedPageIndex + 1) text."
    } else {
      statusMessage = "Page text copy failed."
    }
  }

  func setSearchMatch(_ index: Int) {
    guard index >= 0 && index < searchMatches.count else { return }
    selectedSearchMatchIndex = index
    if let match = selectedSearchMatch {
      jumpToPage(match.pageIndex)
    }
  }

  func selectNextSearchMatch() {
    guard !searchMatches.isEmpty else { return }
    let next = (selectedSearchMatchIndex ?? -1) + 1
    let index = next >= searchMatches.count ? 0 : next
    setSearchMatch(index)
  }

  func selectPreviousSearchMatch() {
    guard !searchMatches.isEmpty else { return }
    let previous = (selectedSearchMatchIndex ?? 0) - 1
    let index = previous < 0 ? searchMatches.count - 1 : previous
    setSearchMatch(index)
  }

  func openLink(_ link: PDFLink) {
    switch link.kind {
    case .internalPage, .outline, .namedDestination:
      if let targetPage = link.targetPageIndex {
        selectedPageIndex = max(0, min(targetPage, max(0, currentPageCount - 1)))
      } else {
        statusMessage = "No mapped page target found for this link."
      }
    case .externalURL:
      guard link.isSafeExternal, let raw = link.destination, let url = URL(string: raw) else {
        statusMessage = "Blocked a potentially unsafe or malformed external destination."
        return
      }
      NSWorkspace.shared.open(url)
    case .unknown:
      statusMessage = "Cannot navigate this link type in current lane."
    }
  }

  func setReaderViewMode(_ mode: ReaderViewMode) {
    readerViewMode = mode
    if mode == .continuous {
      readerScaleMode = .fitWidth
    }
  }

  func setReaderScaleMode(_ mode: ReaderScaleMode) {
    readerScaleMode = mode
    if mode == .zoom && readerZoom == 1.0 {
      readerZoom = 1.0
    }
  }

  func setZoom(_ value: Double) {
    readerZoom = max(0.25, min(3.0, value))
  }

  func rotateLeft() {
    readerRotation = (readerRotation + 270) % 360
    refreshRotation()
  }

  func rotateRight() {
    readerRotation = (readerRotation + 90) % 360
    refreshRotation()
  }

  func resetReaderState() {
    readerViewMode = .continuous
    readerScaleMode = .fitWidth
    readerZoom = 1.0
    readerRotation = 0
    pageJumpInput = ""
    clearSearch()
  }

  private func refreshRotation() {
    guard let document = liveDocument else { return }
    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex) else { continue }
      page.rotation = readerRotation
    }
  }

  private func performExport(sourceURL: URL, destination: URL) {
    do {
      let result = try provider.export(url: sourceURL, operations: operations, to: destination)
      exportReport = result.report
      switch result.report.status {
      case .validated:
        statusMessage = "Exported and reopened a validated copy."
      case .validatedWithWarnings:
        statusMessage =
          "Exported with validation warnings. Review the report before relying on the copy."
      case .failed:
        statusMessage =
          "Exported, but validation failed. The source and edit history remain available."
      }
      if result.report.status == .failed {
        alertMessage = result.report.messages.joined(separator: "\n")
      }
      // Save session after successful export
      saveSession()
    } catch {
      alertMessage = error.localizedDescription
    }
  }

  // MARK: - Session Persistence

  /// Save the current editing session to disk.
  func saveSession() {
    guard let inspection, sourceURL != nil else { return }
    let record = PDFSessionRecord.from(
      source: inspection.source,
      pages: inspection.pages,
      fields: inspection.fields,
      candidates: inspection.candidates,
      operations: operations,
      reviews: [],
      selectedPageIndex: selectedPageIndex
    )
    do {
      try sessionStore.save(record: record)
      currentSessionID = record.sessionID
      hasSavedSession = true
    } catch {
      // Session save failure is non-fatal; the document and edits are still in memory
      print("Session save failed: \(error.localizedDescription)")
    }
  }

  /// Load a saved session for the current document.
  func loadSavedSession() {
    guard let currentInspection = inspection else { return }
    do {
      if let savedSession = try sessionStore.load(sourceDigest: currentInspection.source.sha256) {
        currentSessionID = savedSession.sessionID
        hasSavedSession = true
        lastSessionInfo = "Session from \(savedSession.lastModifiedAt.formatted(date: .abbreviated, time: .shortened)) — \(savedSession.operationCount) edits, \(savedSession.completionProgress.confirmedCount)/\(savedSession.completionProgress.totalCandidates) fields filled"
        // Restore candidate statuses
        var restoredCandidates = currentInspection.candidates
        for candidate in restoredCandidates {
          if let savedStatus = savedSession.candidateStatuses[candidate.id] {
            restoredCandidates[restoredCandidates.firstIndex(where: { $0.id == candidate.id })!].status = savedStatus
          }
        }
        self.inspection = DocumentInspection(
          source: currentInspection.source,
          pages: currentInspection.pages,
          fields: currentInspection.fields,
          candidates: restoredCandidates,
          warnings: currentInspection.warnings,
          links: currentInspection.links,
          outlines: currentInspection.outlines,
          metadata: currentInspection.metadata,
          permissions: currentInspection.permissions,
          attachments: currentInspection.attachments,
          accessibility: currentInspection.accessibility,
          security: currentInspection.security
        )
        operations = savedSession.operations
        selectedPageIndex = savedSession.selectedPageIndex
        statusMessage = "Restored session from \(savedSession.lastModifiedAt.formatted(date: .abbreviated, time: .shortened))"
      } else {
        statusMessage = "No saved session found for this document."
      }
    } catch {
      statusMessage = "Could not load saved session: \(error.localizedDescription)"
    }
  }

  /// Auto-save session periodically (call after each operation).
  private func autoSaveSession() {
    // Auto-save on every operation for crash safety
    saveSession()
  }

  /// List all saved sessions.
  func listSavedSessions() -> [PDFSessionRecord] {
    (try? sessionStore.listAll()) ?? []
  }

  /// Delete a saved session.
  func deleteSession(sourceDigest: String) {
    do {
      try sessionStore.delete(sourceDigest: sourceDigest)
      if inspection?.source.sha256 == sourceDigest {
        hasSavedSession = false
        lastSessionInfo = nil
      }
    } catch {
      print("Session delete failed: \(error.localizedDescription)")
    }
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
