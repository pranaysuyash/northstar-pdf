import Foundation

/// Manages annotation marks for a document, persisted as a JSON sidecar file.
///
/// Sidecar naming: for `document.pdf`, the sidecar is `document.pdf.annotations.json`.
/// This keeps annotations independent of the PDF — they survive PDF version changes,
/// don't require permission to modify, and are portable across tools.
///
/// Doctrine alignment:
/// - §3: Sidecar = non-destructive, no source modification
/// - §5: Timestamps on every mark, provenance tracked
/// - §8: Annotations are opt-in — no sidecar created until first mark

@MainActor
public final class AnnotationStore: ObservableObject {
  /// All annotation marks for the current document.
  @Published public var marks: [AnnotationMark] = []

  /// The document ID (file name) these annotations belong to.
  public private(set) var documentID: String = ""

  /// The sidecar file URL (nil if no document is loaded).
  public private(set) var sidecarURL: URL?

  /// Version store for tracking mark evolution.
  public let versionStore = AnnotationVersionStore()

  private let fileManager = FileManager.default

  public init() {}

  // MARK: - Document Binding

  /// Bind the store to a document. Loads existing sidecar if present.
  public func bind(to documentURL: URL) {
    self.documentID = documentURL.lastPathComponent
    let baseName = documentURL.deletingPathExtension().lastPathComponent
    let dir = documentURL.deletingLastPathComponent()
    self.sidecarURL = dir.appendingPathComponent("\(baseName).pdf.annotations.json")
    versionStore.bind(toDocumentID: documentID)
    load()
  }

  /// Bind by document ID only (for testing or when URL is unavailable).
  public func bind(toDocumentID documentID: String) {
    self.documentID = documentID
    self.sidecarURL = nil
    marks = []
    versionStore.bind(toDocumentID: documentID)
  }

  // MARK: - CRUD

  /// Add a new annotation mark.
  @discardableResult
  public func addMark(_ mark: AnnotationMark, actor: String = NSFullUserName()) -> AnnotationMark {
    marks.append(mark)
    versionStore.recordCreation(of: mark, actor: actor)
    save()
    return mark
  }

  /// Update an existing mark (by ID).
  public func updateMark(id: UUID, actor: String = NSFullUserName(), updates: (inout AnnotationMark) -> Void) {
    guard let index = marks.firstIndex(where: { $0.id == id }) else { return }
    let previous = marks[index]
    updates(&marks[index])
    marks[index].updatedAt = Date()
    let updated = marks[index]
    let changeType = detectChangeType(from: previous, to: updated)
    if let changeType {
      versionStore.recordUpdate(
        of: updated, previousMark: previous,
        changeType: changeType.0, description: changeType.1, actor: actor
      )
    }
    save()
  }

  /// Delete a mark by ID.
  public func deleteMark(id: UUID) {
    marks.removeAll { $0.id == id }
    save()
  }

  /// Delete all marks.
  public func deleteAllMarks() {
    marks = []
    save()
  }

  /// Toggle visibility of a mark.
  public func toggleVisibility(id: UUID, actor: String = NSFullUserName()) {
    guard let index = marks.firstIndex(where: { $0.id == id }) else { return }
    let previous = marks[index]
    marks[index].isVisible.toggle()
    marks[index].updatedAt = Date()
    let updated = marks[index]
    versionStore.recordUpdate(
      of: updated, previousMark: previous,
      changeType: .visibilityToggled,
      description: updated.isVisible ? "Mark made visible" : "Mark hidden",
      actor: actor
    )
    save()
  }

  // MARK: - Change Detection

  private func detectChangeType(from: AnnotationMark, to: AnnotationMark) -> (AnnotationChangeType, String)? {
    if from.selectedText != to.selectedText {
      return (.textEdited, "Text changed")
    }
    if from.note != to.note {
      return (.noteEdited, "Note changed")
    }
    if from.type != to.type {
      return (.typeChanged, "Type changed from \(from.type.displayName) to \(to.type.displayName)")
    }
    if from.color != to.color {
      return (.colorChanged, "Color changed")
    }
    if from.bounds != to.bounds {
      return (.positionChanged, "Position changed")
    }
    if from.tags != to.tags {
      return (.tagsModified, "Tags modified")
    }
    return nil
  }

  // MARK: - Search

  /// Search marks using a query.
  public func search(_ query: AnnotationSearchQuery) -> [AnnotationMark] {
    marks.filter { mark in
      // Visible filter
      if query.visibleOnly && !mark.isVisible { return false }

      // Type filter
      if let type = query.type, mark.type != type { return false }

      // Color filter
      if let color = query.color, mark.color != color { return false }

      // Page filter
      if let page = query.pageIndex, mark.pageIndex != page { return false }

      // Text search (case-insensitive in selectedText and note)
      if let text = query.text, !text.isEmpty {
        let lowerText = text.lowercased()
        let inSelectedText = mark.selectedText.lowercased().contains(lowerText)
        let inNote = mark.note.lowercased().contains(lowerText)
        if !inSelectedText && !inNote { return false }
      }

      // Tags filter (mark must have ALL specified tags)
      if let tags = query.tags, !tags.isEmpty {
        let markTags = Set(mark.tags)
        if !tags.allSatisfy({ markTags.contains($0) }) { return false }
      }

      return true
    }
  }

  /// Get all marks for a specific page.
  public func marksForPage(_ pageIndex: Int) -> [AnnotationMark] {
    marks.filter { $0.pageIndex == pageIndex && $0.isVisible }
  }

  /// Get all unique tags across all marks.
  public var allTags: [String] {
    Array(Set(marks.flatMap(\.tags))).sorted()
  }

  /// Get mark counts by type.
  public var marksByType: [AnnotationType: Int] {
    Dictionary(grouping: marks, by: \.type).mapValues(\.count)
  }

  // MARK: - Export

  /// Export annotations in the specified format.
  public func export(format: AnnotationExportFormat) -> AnnotationExportResult {
    let baseName = documentID.replacingOccurrences(of: ".pdf", with: "")

    switch format {
    case .json:
      return exportJSON(baseName: baseName)
    case .markdown:
      return exportMarkdown(baseName: baseName)
    case .plainText:
      return exportPlainText(baseName: baseName)
    }
  }

  private func exportJSON(baseName: String) -> AnnotationExportResult {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = (try? encoder.encode(marks)) ?? Data()
    return AnnotationExportResult(
      data: data,
      format: .json,
      markCount: marks.count,
      suggestedFileName: "\(baseName)-annotations.json"
    )
  }

  private func exportMarkdown(baseName: String) -> AnnotationExportResult {
    var md = "# Annotations for \(baseName)\n\n"
    md += "*Exported \(marks.count) marks on \(DateFormatter.annotationStyle.string(from: Date()))*\n\n"

    let grouped = Dictionary(grouping: marks, by: \.pageIndex)
    for pageIndex in grouped.keys.sorted() {
      let pageMarks = grouped[pageIndex]!.sorted { $0.createdAt < $1.createdAt }
      md += "## Page \(pageIndex + 1)\n\n"
      for mark in pageMarks {
        let icon = mark.type == .highlight ? "🟡" :
                   mark.type == .underline ? "〰️" :
                   mark.type == .note ? "📝" :
                   mark.type == .strikethrough ? "❌" : "✏️"
        md += "\(icon) **\(mark.type.displayName)**"
        if !mark.selectedText.isEmpty {
          md += ": \"\(mark.selectedText)\""
        }
        if !mark.note.isEmpty {
          md += " — \(mark.note)"
        }
        md += " *(\(DateFormatter.annotationStyle.string(from: mark.createdAt)))*\n"
      }
      md += "\n"
    }

    let data = md.data(using: .utf8) ?? Data()
    return AnnotationExportResult(
      data: data,
      format: .markdown,
      markCount: marks.count,
      suggestedFileName: "\(baseName)-annotations.md"
    )
  }

  private func exportPlainText(baseName: String) -> AnnotationExportResult {
    var text = "Annotations for \(baseName)\n"
    text += "\(marks.count) marks\n\n"

    for mark in marks.sorted(by: { $0.createdAt < $1.createdAt }) {
      text += "[\(mark.type.displayName)] Page \(mark.pageIndex + 1)"
      if !mark.selectedText.isEmpty {
        text += ": \"\(mark.selectedText)\""
      }
      if !mark.note.isEmpty {
        text += " — \(mark.note)"
      }
      text += "\n"
    }

    let data = text.data(using: .utf8) ?? Data()
    return AnnotationExportResult(
      data: data,
      format: .plainText,
      markCount: marks.count,
      suggestedFileName: "\(baseName)-annotations.txt"
    )
  }

  // MARK: - Persistence

  private func save() {
    guard let url = sidecarURL else { return }
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(marks) else { return }
    try? data.write(to: url, options: .atomic)
  }

  private func load() {
    guard let url = sidecarURL, fileManager.fileExists(atPath: url.path) else { return }
    guard let data = try? Data(contentsOf: url) else { return }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let decoded = try? decoder.decode([AnnotationMark].self, from: data) {
      marks = decoded
    }
  }
}

// MARK: - DateFormatter

extension DateFormatter {
  static let annotationStyle: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()
}
