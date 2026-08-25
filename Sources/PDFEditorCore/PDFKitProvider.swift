import AppKit
import CryptoKit
import CoreGraphics
import Foundation
import PDFKit

public struct PDFKitProvider: PDFProvider {
  public struct Limits: Sendable {
    public let maximumInputBytes: Int
    public let maximumPageCount: Int

    public init(maximumInputBytes: Int = 250_000_000, maximumPageCount: Int = 2_000) {
      self.maximumInputBytes = maximumInputBytes
      self.maximumPageCount = maximumPageCount
    }
  }

  public let limits: Limits

  public init(limits: Limits = Limits()) {
    self.limits = limits
  }

  public func inspect(url: URL, password: String?) throws -> DocumentInspection {
    try PerformanceTelemetry.shared.measureOpenLoad {
    let data = try loadData(from: url)
    guard let document = PDFDocument(data: data) else {
      throw PDFEditorError.cannotOpen(url.lastPathComponent)
    }

    if document.isLocked {
      guard let password, !password.isEmpty else {
        throw PDFEditorError.passwordRequired(url.lastPathComponent)
      }
      guard document.unlock(withPassword: password) else {
        throw PDFEditorError.passwordIncorrect(url.lastPathComponent)
      }
    }
    return try inspection(for: document, source: makeSource(url: url, data: data), data: data)
    }
  }

  /// Produces a value-minimized privacy preflight without mutating the source.
  /// The report is observational only. It must not be used as proof that a
  /// later sanitizer removed or neutralized every PDF risk surface.
  public func preflight(url: URL, password: String?) throws -> PDFPreflightReport {
    let data = try loadData(from: url)
    guard let document = PDFDocument(data: data) else {
      throw PDFEditorError.cannotOpen(url.lastPathComponent)
    }
    if document.isLocked {
      guard let password, !password.isEmpty else {
        throw PDFEditorError.passwordRequired(url.lastPathComponent)
      }
      guard document.unlock(withPassword: password) else {
        throw PDFEditorError.passwordIncorrect(url.lastPathComponent)
      }
    }
    let inspection = try inspection(for: document, source: makeSource(url: url, data: data), data: data)
    return PDFPreflightBuilder.build(
      inspection: inspection,
      data: data,
      provider: PDFProviderDescriptor(
        id: "pdfkit",
        version: ProcessInfo.processInfo.operatingSystemVersionString,
        platform: "macOS",
        capabilities: ["inspection", "metadata-presence", "embedded-data-counts", "network-boundary-counts", "bounded-token-scan"]
      )
    )
  }

  public func export(url: URL, operations: [EditOperation], to outputURL: URL) throws
    -> ExportResult
  {
    // Save timing intentionally covers the full export contract, including
    // source load, staging, reopen/fidelity validation, cleanup, and publication.
    try PerformanceTelemetry.shared.measureSave {
    let sourceData = try loadData(from: url)
    guard let document = PDFDocument(data: sourceData) else {
      throw PDFEditorError.cannotOpen(url.lastPathComponent)
    }
    let source = try inspection(
      for: document, source: makeSource(url: url, data: sourceData), data: sourceData)

    guard url.standardizedFileURL != outputURL.standardizedFileURL else {
      throw PDFEditorError.exportFailed(
        "Choose a new output copy; the original source cannot be overwritten.")
    }

    // Structural detection via the CGPDF catalog. Unlike the previous raw byte
    // scan for "/AcroForm", this cannot be fooled by the literal string appearing
    // in content/annotation strings, and it sees through cross-reference and
    // object streams where the catalog dictionary is compressed.
    if !operations.isEmpty && hasDocumentLevelAcroForm(sourceData) {
      throw PDFEditorError.exportFailed(
        "This PDF contains an existing document-level AcroForm. The PDFKit writer cannot safely preserve its widget tree during edits; the source remains read-only until a form-aware provider is available."
      )
    }

    let fileManager = FileManager.default
    // RT-002: Use the OS-isolated temporary directory rather than the user-chosen
    // export directory, which could be attacker-influenced via symlink placement.
    let temporaryURL =
      fileManager.temporaryDirectory
      .appendingPathComponent(".pdf-editor-\(UUID().uuidString).pdf")
    if operations.isEmpty {
      do {
        try fileManager.copyItem(at: url, to: temporaryURL)
      } catch {
        throw PDFEditorError.exportFailed(
          "The unchanged source could not be staged for export: \(error.localizedDescription)")
      }
    } else {
      for operation in operations {
        try validateSourceBinding(operation, source: source.source)
        try apply(operation, to: document)
      }
      guard document.write(to: temporaryURL) else {
        throw PDFEditorError.exportFailed("The PDF provider could not write the temporary export.")
      }
    }

    let report: ValidationReport
    do {
      report = try validate(
        source: source,
        sourceURL: url,
        outputURL: temporaryURL,
        operations: operations
      )
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      throw PDFEditorError.exportFailed(
        "The staged export could not be validated before publication: \(error.localizedDescription)"
      )
    }

    guard report.status != .failed else {
      try? fileManager.removeItem(at: temporaryURL)
      let detail =
        report.messages.isEmpty
        ? "The provider validation contract failed without a diagnostic."
        : report.messages.joined(separator: " ")
      throw PDFEditorError.exportFailed("The export was rejected before publication: \(detail)")
    }

    do {
      if fileManager.fileExists(atPath: outputURL.path) {
        _ = try fileManager.replaceItemAt(
          outputURL,
          withItemAt: temporaryURL,
          backupItemName: nil,
          options: .usingNewMetadataOnly
        )
      } else {
        try fileManager.moveItem(at: temporaryURL, to: outputURL)
      }
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      throw PDFEditorError.exportFailed(
        "The validated export could not be moved into place: \(error.localizedDescription)")
    }

    return ExportResult(outputURL: outputURL, report: report)
    }
  }

  private func validateSourceBinding(_ operation: EditOperation, source: DocumentSource) throws {
    if let operationDigest = operation.sourceDigest, operationDigest != source.sha256 {
      throw PDFEditorError.invalidOperation(
        "The operation source digest does not match the inspected PDF source."
      )
    }
  }

  private func validateOperationShape(_ operation: EditOperation) throws {
    if operation.destructive {
      throw PDFEditorError.invalidOperation(
        "Destructive PDF operations require an explicit provider policy."
      )
    }

    if let coordinate = operation.coordinate {
      guard coordinate.pageIndex == operation.pageIndex else {
        throw PDFEditorError.invalidOperation(
          "The operation coordinate page does not match the operation page."
        )
      }
      if let bounds = operation.bounds, bounds != coordinate.rect {
        throw PDFEditorError.invalidOperation(
          "The operation bounds do not match its page-space coordinate."
        )
      }
    }
  }

  public func apply(_ operation: EditOperation, to document: PDFDocument) throws {
    try validateOperationShape(operation)
    guard let page = document.page(at: operation.pageIndex) else {
      throw PDFEditorError.invalidPage(operation.pageIndex)
    }

    switch operation.kind {
    case .nativeFieldValue:
      guard let targetID = operation.targetID else {
        throw PDFEditorError.invalidOperation("A native field edit requires a field name.")
      }
      let widgets = page.annotations.filter {
        $0.type == "Widget" && $0.fieldName == targetID
      }
      guard !widgets.isEmpty else {
        throw PDFEditorError.invalidOperation(
          "The native field \(targetID) was not found on the target page.")
      }
      for widget in widgets {
        applyNativeValue(operation.value, to: widget)
      }

    case .synthesizeNativeField:
      guard let targetID = operation.targetID, !targetID.isEmpty,
        let bounds = operation.bounds
      else {
        throw PDFEditorError.invalidOperation(
          "A synthesized native field requires a stable name and page bounds."
        )
      }
      let fieldType: SuggestedFieldType
      if case .nativeField(let type) = operation.payload {
        fieldType = type
      } else {
        fieldType = .text
      }
      guard [.text, .date, .number].contains(fieldType) else {
        throw PDFEditorError.invalidOperation(
          "Only text-like static regions can be synthesized as native fields."
        )
      }
      let widget = PDFAnnotation(
        bounds: bounds.cgRect,
        forType: PDFAnnotationSubtype.widget,
        withProperties: nil
      )
      widget.widgetFieldType = .text
      widget.fieldName = targetID
      widget.border = PDFBorder()
      widget.border?.lineWidth = 0
      page.addAnnotation(widget)

    case .textRunReplacement:
      throw PDFEditorError.invalidOperation(
        "Semantic text-run replacement requires a provider with font/glyph preservation and independent outside-region fidelity evidence."
      )

    case .overlayText, .annotation:
      guard let bounds = operation.bounds else {
        throw PDFEditorError.invalidOperation("An overlay edit requires page bounds.")
      }
      if case .characterGrid(let text, let cells) = operation.payload {
        try applyCharacterGrid(text, cells: cells, to: page)
        return
      }
      if case .choiceMark(let cell) = operation.payload {
        let annotation = PDFAnnotation(
          bounds: cell.cgRect.insetBy(dx: 1, dy: 1),
          forType: PDFAnnotationSubtype.freeText,
          withProperties: nil
        )
        annotation.contents = operation.value.isEmpty ? "X" : operation.value
        annotation.font = NSFont.boldSystemFont(ofSize: max(8, min(14, cell.height * 0.78)))
        annotation.fontColor = NSColor.labelColor
        annotation.backgroundColor = .clear
        annotation.border = nil
        annotation.alignment = .center
        page.addAnnotation(annotation)
        return
      }
      let annotation = PDFAnnotation(
        bounds: bounds.cgRect,
        forType: PDFAnnotationSubtype.freeText,
        withProperties: nil
      )
      annotation.contents = operation.value
      annotation.font = NSFont.systemFont(ofSize: 11)
      annotation.fontColor = NSColor.labelColor
      annotation.backgroundColor = .clear
      page.addAnnotation(annotation)

    default:
      // Fail closed with the real constraint: system PDFKit exposes no image
      // annotation that survives save (stamps are name-only; custom appearance
      // streams are not serializable through the public API). Silently faking a
      // placement would violate the review-before-trust contract, so signature
      // placement stays unavailable until a form-aware provider lane lands.
      throw PDFEditorError.invalidOperation(
        "The PDFKit adapter cannot serialize \(operation.kind.rawValue) operations: system PDFKit has no image-annotation API that survives save. The edit was rejected before any file was written; signature placement requires the form-aware provider lane."
      )
    }
  }

  private func applyCharacterGrid(_ value: String, cells: [PDFRect], to page: PDFPage) throws {
    let characters = Array(value)
    guard !cells.isEmpty else {
      throw PDFEditorError.invalidOperation(
        "A character-grid edit requires detected cell geometry.")
    }
    guard characters.count <= cells.count else {
      throw PDFEditorError.invalidOperation(
        "The value has \(characters.count) characters but the detected grid has only \(cells.count) cells."
      )
    }

    for (index, character) in characters.enumerated() {
      let cell = cells[index].cgRect.insetBy(dx: 1, dy: 1)
      let annotation = PDFAnnotation(
        bounds: cell,
        forType: PDFAnnotationSubtype.freeText,
        withProperties: nil
      )
      annotation.contents = String(character)
      annotation.font = NSFont.systemFont(ofSize: max(6, min(11, cell.height * 0.72)))
      annotation.fontColor = NSColor.labelColor
      annotation.backgroundColor = .clear
      annotation.border = nil
      annotation.alignment = .center
      page.addAnnotation(annotation)
    }
  }

  private func loadData(from url: URL) throws -> Data {
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw PDFEditorError.inputMissing(url.path)
    }
    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
    guard data.count <= limits.maximumInputBytes else {
      throw PDFEditorError.inputTooLarge(data.count)
    }
    return data
  }

  private func makeSource(url: URL, data: Data) -> DocumentSource {
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    return DocumentSource(fileName: url.lastPathComponent, byteCount: data.count, sha256: digest)
  }

  private func inspection(
    for document: PDFDocument,
    source: DocumentSource,
    data: Data? = nil
  ) throws -> DocumentInspection {
    guard document.pageCount <= limits.maximumPageCount else {
      throw PDFEditorError.invalidOperation("The PDF exceeds the current page-count safety limit.")
    }

    var pages: [PageSnapshot] = []
    var fields: [NativeField] = []
    var lines: [TextLineEvidence] = []
    var links: [PDFLink] = []
    var attachments: [String] = []
    var annotationTypeCounts: [String: Int] = [:]

    for pageIndex in 0..<document.pageCount {
      guard let page = document.page(at: pageIndex) else {
        throw PDFEditorError.invalidPage(pageIndex)
      }
      let bounds = page.bounds(for: .cropBox)
      for annotation in page.annotations {
        let rawType = annotation.type ?? "unknown"
        let normalizedType: String
        switch rawType {
        case "Widget": normalizedType = "widget"
        case "Link": normalizedType = "link"
        case "FileAttachment": normalizedType = "fileAttachment"
        case "Text", "FreeText", "Highlight", "Underline", "StrikeOut", "Squiggly", "Ink", "Square", "Circle", "Line", "Polygon", "PolyLine", "Caret", "Stamp", "Popup": normalizedType = "markup"
        default: normalizedType = "unknown"
        }
        annotationTypeCounts[normalizedType, default: 0] += 1
      }
      pages.append(
        PageSnapshot(
          pageIndex: pageIndex,
          pageLabel: page.label ?? "\(pageIndex + 1)",
          bounds: PDFRect(bounds),
          cropBox: PDFRect(page.bounds(for: .cropBox)),
          bleedBox: PDFRect(page.bounds(for: .bleedBox)),
          trimBox: PDFRect(page.bounds(for: .trimBox)),
          artBox: PDFRect(page.bounds(for: .artBox)),
          rotation: page.rotation,
          characterCount: page.numberOfCharacters,
          annotationCount: page.annotations.count,
          hasSelectableText: !(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        ))

      // Identity must not embed PDFKit's global annotation enumeration index:
      // it is not stable across save/reload when non-widget annotations are
      // interleaved. Use a per-(page, name) occurrence counter instead, keeping
      // the index only as a tie-breaker for repeated names.
      var widgetOccurrenceCounts: [String: Int] = [:]
      for (annotationIndex, annotation) in page.annotations.enumerated()
      where annotation.type == "Widget" {
        let name = annotation.fieldName ?? "unnamed-\(pageIndex)-\(annotationIndex)"
        let occurrence = widgetOccurrenceCounts[name, default: 0]
        widgetOccurrenceCounts[name] = occurrence + 1
        let stableID = occurrence == 0 ? "\(name)#\(pageIndex)" : "\(name)#\(pageIndex)#\(occurrence)"
        fields.append(
          NativeField(
            id: stableID,
            name: name,
            kind: nativeFieldKind(annotation.widgetFieldType),
            pageIndex: pageIndex,
            bounds: PDFRect(annotation.bounds),
            value: nativeValue(for: annotation),
            choices: annotation.choices ?? []
          ))
      }

      for annotation in page.annotations where annotation.type == "Link" {
        links.append(makeLink(from: annotation, pageIndex: pageIndex, page: page, source: source))
      }

      for annotation in page.annotations where annotation.type == "FileAttachment" {
        if let contents = annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines),
          !contents.isEmpty
        {
          attachments.append(contents)
        }
      }

      // Use PDFKit's selection geometry rather than assigning evenly spaced
      // bands to page.string lines. The latter loses the authored x/y layout
      // and can associate a label with the wrong rectangle in a dense form.
      if let selection = page.selection(for: page.bounds(for: .cropBox)) {
        for line in selection.selectionsByLine() {
          guard let text = line.string?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
          else { continue }
          lines.append(
            TextLineEvidence(
              pageIndex: pageIndex,
              text: text,
              bounds: PDFRect(line.bounds(for: page))
            ))
        }
      } else if let pageString = page.string {
        // Keep a conservative fallback for providers that cannot construct a
        // selection. Its bounds are explicitly approximate and candidates
        // still require semantic label evidence before promotion.
        let pageLines = pageString.components(separatedBy: .newlines)
        let lineHeight = max(14, min(24, bounds.height / CGFloat(max(pageLines.count, 1))))
        for (lineIndex, text) in pageLines.enumerated() {
          let lineBounds = CGRect(
            x: bounds.minX + 48,
            y: bounds.maxY - CGFloat(lineIndex + 1) * lineHeight,
            width: max(1, bounds.width - 96),
            height: lineHeight
          )
          lines.append(
            TextLineEvidence(pageIndex: pageIndex, text: text, bounds: PDFRect(lineBounds)))
        }
      }
    }

    let outlineRoot = collectOutlines(from: document.outlineRoot, level: 0, includeRoot: false)
    let metadata = inspectMetadata(document)
    let permissions = inspectPermissions(document)
    let accessibility = inspectAccessibility(document)
    let security = PDFSecuritySummary(
      isEncrypted: document.isEncrypted,
      isLocked: document.isLocked,
      requiresPassword: document.isLocked
    )

    let vectorGeometries = data.map { PDFVectorStreamParser.parse(data: $0) } ?? []
    let candidates = PerformanceTelemetry.shared.measureDetection {
      StaticRegionDetector.detect(lines: lines, vectorGeometries: vectorGeometries)
    }

    return DocumentInspection(
      source: source,
      pages: pages,
      fields: fields,
      candidates: candidates,
      warnings: [],
      links: links,
      outlines: outlineRoot,
      metadata: metadata,
      permissions: permissions,
      attachments: attachments + embeddedFileNames(from: data),
      accessibility: accessibility,
      security: security,
      annotationTypeCounts: annotationTypeCounts
    )
  }

  private func nativeFieldKind(_ subtype: PDFAnnotationWidgetSubtype) -> NativeFieldKind {
    switch subtype {
    case .text:
      .text
    case .button:
      .button
    case .choice:
      .choice
    case .signature:
      .signature
    default:
      .unknown
    }
  }

  /// Structural AcroForm presence check against the parsed CGPDF catalog.
  private func hasDocumentLevelAcroForm(_ data: Data) -> Bool {
    guard let provider = CGDataProvider(data: data as CFData),
      let document = CGPDFDocument(provider),
      let catalog = document.catalog
    else { return false }
    var acroForm: CGPDFDictionaryRef?
    return CGPDFDictionaryGetDictionary(catalog, "AcroForm", &acroForm)
  }

  /// Button retention contract.
  ///
  /// A single checkbox kid answers to boolean tokens. A radio group (multiple
  /// kids sharing one field name) may have exactly one kid on — the kid whose
  /// state string matches the requested value — and every sibling must be off.
  /// The previous "any kid off matches a request for off" rule could validate a
  /// document with the wrong kid selected. Text/choice fields compare trimmed.
  static func buttonValueRetained(fields: [NativeField], requested rawValue: String) -> Bool {
    let trimmedRequest = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let requested = trimmedRequest.lowercased()
    let onTokens: Set<String> = ["1", "true", "yes", "on", "checked"]
    let offTokens: Set<String> = ["", "0", "false", "no", "off", "unchecked"]
    let kids = fields.filter { $0.kind == .button }
    let others = fields.filter { $0.kind != .button }
    let othersRetained = others.allSatisfy { $0.value == trimmedRequest }
    if kids.isEmpty { return othersRetained }
    if kids.count == 1, onTokens.contains(requested) || offTokens.contains(requested) {
      return ((kids[0].value != nil) == onTokens.contains(requested)) && othersRetained
    }
    // A radio group's option can legitimately be named "no", "off", or
    // "false". Resolve a named kid before applying the single-checkbox
    // boolean vocabulary, otherwise a valid radio selection is misclassified
    // as an unchecked checkbox.
    if kids.count > 1 {
      if let target = kids.first(where: {
        $0.value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == requested
      }) {
        return kids.allSatisfy { kid in
          kid.id == target.id ? kid.value != nil : kid.value == nil
        } && othersRetained
      }
      if offTokens.contains(requested) {
        return kids.allSatisfy { $0.value == nil } && othersRetained
      }
      return false
    }
    if offTokens.contains(requested) {
      return kids.allSatisfy { $0.value == nil } && othersRetained
    }
    return false
  }

  private func nativeValue(for annotation: PDFAnnotation) -> String? {    if annotation.widgetFieldType == .button {
      let state = annotation.buttonWidgetStateString
      if !state.isEmpty, annotation.buttonWidgetState == PDFWidgetCellState(rawValue: 1) {
        return state
      }
      return nil
    }
    if let value = annotation.widgetStringValue, !value.isEmpty {
      return value
    }
    return nil
  }

  private func applyNativeValue(_ value: String, to annotation: PDFAnnotation) {
    switch annotation.widgetFieldType {
    case .button:
      let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      let isOn =
        ["true", "yes", "on", "1", "checked"].contains(normalized)
        || annotation.buttonWidgetStateString.lowercased() == normalized
      annotation.buttonWidgetState = PDFWidgetCellState(rawValue: isOn ? 1 : 0)!
    case .text, .choice:
      annotation.widgetStringValue = value
    default:
      annotation.widgetStringValue = value
    }
  }

  private func validate(
    source: DocumentInspection,
    sourceURL: URL,
    outputURL: URL,
    operations: [EditOperation]
  ) throws -> ValidationReport {
    let sourceData = try loadData(from: sourceURL)
    let outputData = try loadData(from: outputURL)
    let sourceUnchanged =
      SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined()
      == source.source.sha256
    guard let sourceDocument = PDFDocument(data: sourceData) else {
      return ValidationReport(
        status: .failed,
        messages: ["The source could not be reopened by PDFKit for impact validation."],
        sourceUnchanged: sourceUnchanged,
        outputReopenable: false,
        sourceDigest: source.source.sha256,
        provider: PDFProviderDescriptor(
          id: "pdfkit",
          version: ProcessInfo.processInfo.operatingSystemVersionString,
          platform: "macOS",
          capabilities: ["render", "forms", "overlay", "reopen-validation"]
        ),
        validatedAt: Date(),
        operationIDs: operations.map(\.id)
      )
    }
    var checks: [ValidationCheck] = [
      ValidationCheck(
        kind: .sourceDigest,
        status: sourceUnchanged ? .passed : .failed,
        message: sourceUnchanged
          ? "Source bytes still match the inspected SHA-256."
          : "Source bytes changed after inspection.",
        operationIDs: operations.map(\.id)
      )
    ]
    guard let outputDocument = PDFDocument(data: outputData) else {
      checks.append(
        ValidationCheck(
          kind: .outputReopen,
          status: .failed,
          message: "The output could not be reopened by PDFKit.",
          operationIDs: operations.map(\.id)
        ))
      return ValidationReport(
        status: .failed,
        messages: ["The output could not be reopened by PDFKit."],
        sourceUnchanged: sourceUnchanged,
        outputReopenable: false,
        checks: checks,
        sourceDigest: source.source.sha256,
        outputDigest: nil,
        provider: PDFProviderDescriptor(
          id: "pdfkit",
          version: ProcessInfo.processInfo.operatingSystemVersionString,
          platform: "macOS",
          capabilities: ["render", "forms", "overlay", "reopen-validation"]
        ),
        validatedAt: Date(),
        operationIDs: operations.map(\.id)
      )
    }
    checks.append(
      ValidationCheck(
        kind: .outputReopen,
        status: .passed,
        message: "Export reopened in PDFKit with \(outputDocument.pageCount) page(s).",
        operationIDs: operations.map(\.id)
      ))
    let output = try inspection(
      for: outputDocument, source: makeSource(url: outputURL, data: outputData), data: outputData)
    var messages: [String] = []

    guard output.pages.count == source.pages.count else {
      messages.append("Page count changed during export.")
      checks.append(
        ValidationCheck(
          kind: .pageGeometry,
          status: .failed,
          message: "Page count changed during export.",
          operationIDs: operations.map(\.id)
        ))
      return ValidationReport(
        status: .failed,
        messages: messages,
        sourceUnchanged: sourceUnchanged,
        outputReopenable: true,
        checks: checks,
        sourceDigest: source.source.sha256,
        outputDigest: output.source.sha256,
        provider: PDFProviderDescriptor(
          id: "pdfkit",
          version: ProcessInfo.processInfo.operatingSystemVersionString,
          platform: "macOS",
          capabilities: ["render", "forms", "overlay", "reopen-validation"]
        ),
        validatedAt: Date(),
        operationIDs: operations.map(\.id)
      )
    }
    for (expected, actual) in zip(source.pages, output.pages) {
      if expected.bounds != actual.bounds || expected.rotation != actual.rotation {
        messages.append("Page geometry or rotation changed on page \(expected.pageIndex + 1).")
      }
    }
    checks.append(
      ValidationCheck(
        kind: .pageGeometry,
        status: messages.contains(where: { $0.contains("Page geometry") }) ? .failed : .passed,
        message: messages.contains(where: { $0.contains("Page geometry") })
          ? "Page geometry or rotation changed during export."
          : "Page count, page boxes, and rotations are unchanged.",
        operationIDs: operations.map(\.id)
      ))

    let sourceFields = source.fields.sorted { $0.id < $1.id }
    let outputFields = output.fields.sorted { $0.id < $1.id }
    let synthesizedOperations = operations.filter { $0.kind == .synthesizeNativeField }
    if outputFields.count < sourceFields.count {
      messages.append("Native field count decreased during export.")
    }
    for expected in sourceFields {
      guard let actual = outputFields.first(where: { $0.id == expected.id }) else {
        messages.append("Native field \(expected.name) disappeared during export.")
        continue
      }
      if expected.kind != actual.kind || expected.bounds != actual.bounds {
        messages.append("Native field identity or geometry changed for \(expected.name).")
      }
      if expected.choices != actual.choices {
        messages.append("Native field choices changed for \(expected.name).")
      }
    }
    for operation in synthesizedOperations {
      if !(outputFields.contains {
        $0.name == operation.targetID && $0.pageIndex == operation.pageIndex
      }) {
        messages.append(
          "Synthesized native field \(operation.targetID ?? "unknown") was not found after reopen.")
      }
    }
    checks.append(
      ValidationCheck(
        kind: .nativeFields,
        status: messages.contains(where: {
          $0.contains("Native field") || $0.contains("Synthesized native field")
        }) ? .failed : .passed,
        message: messages.contains(where: {
          $0.contains("Native field") || $0.contains("Synthesized native field")
        })
          ? "Native field identity, geometry, choices, or synthesis changed during export."
          : synthesizedOperations.isEmpty
            ? "Native field identity and geometry are unchanged."
            : "Existing native fields were preserved and synthesized fields reopened.",
        operationIDs: operations.filter {
          $0.kind == .nativeFieldValue || $0.kind == .synthesizeNativeField
        }.map(\.id)
      ))

    for operation in operations {
      switch operation.kind {
      case .nativeFieldValue:
        let matching = output.fields.filter {
          $0.name == operation.targetID && $0.pageIndex == operation.pageIndex
        }
        guard !matching.isEmpty else {
          messages.append(
            "Applied native field \(operation.targetID ?? "unknown") could not be found after reopen."
          )
          continue
        }
        let retained = Self.buttonValueRetained(fields: matching, requested: operation.value)
        if !retained {
          messages.append(
            "Native field \(operation.targetID ?? "unknown") did not retain the requested value.")
        }
      case .synthesizeNativeField:
        let matching = output.fields.filter {
          $0.name == operation.targetID && $0.pageIndex == operation.pageIndex
        }
        if matching.isEmpty {
          messages.append(
            "Synthesized native field \(operation.targetID ?? "unknown") could not be located after reopen."
          )
        }
      case .overlayText, .annotation:
        guard let page = outputDocument.page(at: operation.pageIndex), let bounds = operation.bounds
        else {
          messages.append("Overlay edit could not be located after reopen.")
          continue
        }
        if case .characterGrid(let value, let cells) = operation.payload {
          let characters = Array(value)
          let retained = zip(characters, cells).allSatisfy { character, cell in
            let expectedBounds = cell.cgRect.insetBy(dx: 1, dy: 1)
            return page.annotations.contains {
              $0.type == "FreeText"
                && $0.contents == String(character)
                && approximatelyEqual($0.bounds, expectedBounds)
            }
          }
          if !retained {
            messages.append(
              "Character-grid overlay \(operation.id.uuidString) could not be located after reopen."
            )
          }
          continue
        }
        if case .choiceMark(let cell) = operation.payload {
          let expectedBounds = cell.cgRect.insetBy(dx: 1, dy: 1)
          let found = page.annotations.contains {
            $0.type == "FreeText"
              && $0.contents == operation.value
              && approximatelyEqual($0.bounds, expectedBounds)
          }
          if !found {
            messages.append(
              "Choice mark \(operation.id.uuidString) could not be located after reopen.")
          }
          continue
        }
        let found = page.annotations.contains {
          $0.type == "FreeText"
            && $0.contents == operation.value
            && approximatelyEqual($0.bounds, bounds.cgRect)
        }
        if !found {
          messages.append(
            "Overlay edit \(operation.id.uuidString) could not be located after reopen.")
        }
      default:
        messages.append(
          "Validation for \(operation.kind.rawValue) is not implemented by the PDFKit adapter.")
      }
    }

    let (textImpact, rasterImpact) = PerformanceTelemetry.shared.measureImpactValidation {
      let tImpact = PDFImpactValidator.compareTextOutsideRegions(
        source: sourceDocument,
        output: outputDocument,
        operations: operations
      )
      let rImpact = PDFImpactValidator.compareRasterOutsideRegions(
        source: sourceDocument,
        output: outputDocument,
        operations: operations,
        scale: 1.0
      )
      return (tImpact, rImpact)
    }
    checks.append(
      ValidationCheck(
        kind: .outsideRegionText,
        status: textImpact.status,
        message: textImpact.message,
        operationIDs: operations.map(\.id)
      ))
    if textImpact.status == .failed {
      messages.append(textImpact.message)
    }

    checks.append(
      ValidationCheck(
        kind: .visualDiff,
        status: rasterImpact.status,
        message: rasterImpact.message,
        operationIDs: operations.map(\.id)
      ))
    if rasterImpact.status == .failed {
      messages.append(rasterImpact.message)
    }
    checks.append(
      ValidationCheck(
        kind: .appliedOperations,
        status: messages.contains(where: {
          $0.contains("could not") || $0.contains("did not retain")
        }) ? .failed : .passed,
        message: messages.contains(where: {
          $0.contains("could not") || $0.contains("did not retain")
        })
          ? "One or more requested operations could not be located or retained after reopen."
          : "Requested operations were represented in the reopened export.",
        operationIDs: operations.map(\.id)
      ))

    let status: ValidationStatus
    if !sourceUnchanged || !messages.isEmpty {
      status = .failed
    } else if !source.warnings.isEmpty
      || checks.contains(where: { $0.status == .unknown || $0.status == .warning })
    {
      status = .validatedWithWarnings
      messages.append(contentsOf: source.warnings)
    } else {
      status = .validated
    }
    return ValidationReport(
      status: status,
      messages: messages,
      sourceUnchanged: sourceUnchanged,
      outputReopenable: true,
      checks: checks,
      sourceDigest: source.source.sha256,
      outputDigest: output.source.sha256,
      provider: PDFProviderDescriptor(
        id: "pdfkit",
        version: ProcessInfo.processInfo.operatingSystemVersionString,
        platform: "macOS",
        capabilities: ["render", "forms", "overlay", "reopen-validation"]
      ),
      validatedAt: Date(),
      operationIDs: operations.map(\.id)
    )
  }

  private func pageText(_ document: PDFDocument) -> [String] {
    (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
  }

  private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.5) -> Bool {
    abs(lhs.minX - rhs.minX) <= tolerance
      && abs(lhs.minY - rhs.minY) <= tolerance
      && abs(lhs.width - rhs.width) <= tolerance
      && abs(lhs.height - rhs.height) <= tolerance
  }

  private func makeLink(
    from annotation: PDFAnnotation,
    pageIndex: Int,
    page: PDFPage,
    source: DocumentSource
  ) -> PDFLink {
    let label =
      annotation.contents?.trimmingCharacters(in: .whitespacesAndNewlines)
      ?? "Page \(pageIndex + 1) link"

    guard let action = annotation.action else {
      return PDFLink(
        id: "\(source.sha256)-\(pageIndex)-\(annotation.hash)",
        pageIndex: pageIndex,
        label: label,
        kind: .unknown,
        destination: nil,
        destinationBounds: PDFRect(annotation.bounds),
        isSafeExternal: false
      )
    }

    if let urlAction = action as? PDFActionURL, let url = urlAction.url {
      let safe = isSafeExternalLink(url)
      return PDFLink(
        id: "\(source.sha256)-\(pageIndex)-\(annotation.hash)",
        pageIndex: pageIndex,
        label: label,
        kind: .externalURL,
        destination: url.absoluteString,
        destinationBounds: PDFRect(annotation.bounds),
        isSafeExternal: safe
      )
    }

    if let destinationAction = action as? PDFActionGoTo {
      let destination = destinationAction.destination
      let index = destinationPageIndex(for: destination)
      return PDFLink(
        id: "\(source.sha256)-\(pageIndex)-\(annotation.hash)",
        pageIndex: pageIndex,
        label: label,
        kind: .internalPage,
        targetPageIndex: index,
        destination: index.map { String($0 + 1) },
        destinationBounds: PDFRect(annotation.bounds),
        isSafeExternal: true
      )
    }

    if action is PDFActionRemoteGoTo {
      return PDFLink(
        id: "\(source.sha256)-\(pageIndex)-\(annotation.hash)",
        pageIndex: pageIndex,
        label: label,
        kind: .unknown,
        destination: "Remote destination blocked",
        destinationBounds: PDFRect(annotation.bounds),
        isSafeExternal: false
      )
    }

    if let destinationAction = action as? PDFActionNamed {
      let destinationName = destinationAction.name
      return PDFLink(
        id: "\(source.sha256)-\(pageIndex)-\(annotation.hash)",
        pageIndex: pageIndex,
        label: label,
        kind: .namedDestination,
        destination: String(describing: destinationName),
        destinationBounds: PDFRect(annotation.bounds),
        isSafeExternal: false
      )
    }

    return PDFLink(
      id: "\(source.sha256)-\(pageIndex)-\(annotation.hash)",
      pageIndex: pageIndex,
      label: label,
      kind: .unknown,
      destinationBounds: PDFRect(annotation.bounds),
      isSafeExternal: false
    )
  }

  private func collectOutlines(
    from outlineRoot: PDFOutline?,
    level: Int,
    includeRoot: Bool
  ) -> [PDFOutlineItem] {
    guard let outlineRoot else { return [] }
    if includeRoot {
      return collectOutlines(from: outlineRoot, level: level)
    }
    var items: [PDFOutlineItem] = []
    for index in 0..<outlineRoot.numberOfChildren {
      if let child = outlineRoot.child(at: index) {
        items.append(contentsOf: collectOutlines(from: child, level: level))
      }
    }
    return items
  }

  private func embeddedFileNames(from data: Data?) -> [String] {
    guard
      let data,
      let provider = CGDataProvider(data: data as CFData),
      let document = CGPDFDocument(provider),
      let catalog = document.catalog
    else { return [] }

    var names: CGPDFDictionaryRef?
    guard CGPDFDictionaryGetDictionary(catalog, "Names", &names), let names else { return [] }
    var embeddedFiles: CGPDFDictionaryRef?
    guard CGPDFDictionaryGetDictionary(names, "EmbeddedFiles", &embeddedFiles), let embeddedFiles else {
      return []
    }

    func collect(_ node: CGPDFDictionaryRef, into result: inout [String]) {
      var nameArray: CGPDFArrayRef?
      if CGPDFDictionaryGetArray(node, "Names", &nameArray), let nameArray {
        var index = 0
        while index + 1 < CGPDFArrayGetCount(nameArray) {
          var nameString: CGPDFStringRef?
          if CGPDFArrayGetString(nameArray, index, &nameString), let nameString,
             let value = CGPDFStringCopyTextString(nameString) as String?
          {
            result.append(value)
          }
          index += 2
        }
      }

      var kids: CGPDFArrayRef?
      if CGPDFDictionaryGetArray(node, "Kids", &kids), let kids {
        for index in 0..<CGPDFArrayGetCount(kids) {
          var child: CGPDFDictionaryRef?
          if CGPDFArrayGetDictionary(kids, index, &child), let child {
            collect(child, into: &result)
          }
        }
      }
    }

    var result: [String] = []
    collect(embeddedFiles, into: &result)
    if result.isEmpty {
      result = embeddedFileNamesFromBoundedNameTree(data)
    }
    var seen = Set<String>()
    return result.filter { seen.insert($0).inserted }
  }

  private func embeddedFileNamesFromBoundedNameTree(_ data: Data) -> [String] {
    let source = String(decoding: data, as: UTF8.self)
    guard let marker = source.range(of: "/EmbeddedFiles") else { return [] }
    let tail = String(source[marker.upperBound...])
    guard let end = tail.range(of: "endobj") else { return [] }
    let node = String(tail[..<end.lowerBound])
    guard let expression = try? NSRegularExpression(
      pattern: #"\(([^()\\]*(?:\\.[^()\\]*)*)\)\s+\d+\s+\d+\s+R"#
    ) else { return [] }
    let range = NSRange(node.startIndex..<node.endIndex, in: node)
    return expression.matches(in: node, range: range).compactMap { match in
      guard let valueRange = Range(match.range(at: 1), in: node) else { return nil }
      return String(node[valueRange])
    }
  }

  private func collectOutlines(from outline: PDFOutline, level: Int) -> [PDFOutlineItem] {
    let title = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Section"
    let destinationPageIndex = destinationPageIndex(for: outline.destination)

    var children: [PDFOutlineItem] = []
    if outline.numberOfChildren > 0 {
      for index in 0..<outline.numberOfChildren {
        if let child = outline.child(at: index) {
          children.append(contentsOf: collectOutlines(from: child, level: level + 1))
        }
      }
    }

    return [
      PDFOutlineItem(
        id: "\(title)-\(UUID())",
        title: title,
        level: level,
        destinationPageIndex: destinationPageIndex,
        children: children
      )
    ]
  }

  private func destinationPageIndex(for destination: PDFDestination?) -> Int? {
    guard let destination else { return nil }
    guard let destinationPage = destination.page else { return nil }
    return documentPageIndex(for: destinationPage)
  }

  private func documentPageIndex(for page: PDFPage) -> Int? {
    return page.document?.index(for: page)
  }

  private func inspectMetadata(_ document: PDFDocument) -> PDFDocumentMetadata {
    let attributes = document.documentAttributes ?? [:]
    return PDFDocumentMetadata(
      title: stringMetadataValue(attributes[PDFDocumentAttribute.titleAttribute], source: "title"),
      author: stringMetadataValue(
        attributes[PDFDocumentAttribute.authorAttribute], source: "author"),
      subject: stringMetadataValue(
        attributes[PDFDocumentAttribute.subjectAttribute], source: "subject"),
      creator: stringMetadataValue(
        attributes[PDFDocumentAttribute.creatorAttribute], source: "creator"),
      producer: stringMetadataValue(
        attributes[PDFDocumentAttribute.producerAttribute], source: "producer"),
      creationDate: stringMetadataValue(
        attributes[PDFDocumentAttribute.creationDateAttribute], source: "creation date"),
      modificationDate: stringMetadataValue(
        attributes[PDFDocumentAttribute.modificationDateAttribute], source: "modification date"),
      keywords: stringMetadataValue(
        attributes[PDFDocumentAttribute.keywordsAttribute], source: "keywords")
    )
  }

  private func stringMetadataValue(_ value: Any?, source: String) -> String {
    if let stringValue = value as? String {
      return stringValue
    }
    if let dateValue = value as? Date {
      return dateValue.formatted()
    }
    return ""
  }

  private func inspectPermissions(_ document: PDFDocument) -> PDFPermissionsSummary {
    PDFPermissionsSummary(
      canPrint: document.allowsPrinting,
      canCopy: document.allowsCopying,
      canModify: document.allowsDocumentChanges,
      canAddAnnotations: document.allowsCommenting,
      isReadOnly: document.isLocked || !document.allowsDocumentChanges
    )
  }

  private func inspectAccessibility(_ document: PDFDocument) -> PDFAccessibilitySummary {
    let attributes = document.documentAttributes ?? [:]
    let hasTagged = (attributes["Tagged"] as? Bool) == true
    let hasExtractedReadingOrder =
      document.pageCount > 0
      && (0..<document.pageCount).contains { index in
        guard let text = document.page(at: index)?.string else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }
    return PDFAccessibilitySummary(
      hasTaggedContent: hasTagged,
      hasReadingOrder: hasExtractedReadingOrder,
      notes: [
        hasExtractedReadingOrder
          ? "Reading order is derived from provider text extraction and is not an authored-tag guarantee."
          : "No usable extracted text was found; OCR or a tagged-content provider is required.",
        "PDF/UA conformance and authored tag-tree preservation require a validator-backed lane.",
      ]
    )
  }

  private func isSafeExternalLink(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    switch scheme {
    case "https", "http":
      return true
    default:
      return false
    }
  }
}
