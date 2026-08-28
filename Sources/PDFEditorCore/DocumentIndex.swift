import Foundation

/// Corpus-level document organization — tags, folders, search, and dedup.
///
/// First principle: a single document is useful; a corpus is powerful.
/// Organization should be automatic (dedup, metadata extraction) and manual
/// (tags, folders) without requiring cloud sync or accounts.
///
/// Architecture:
/// - `DocumentIndexEntry` — metadata for one document in the corpus
/// - `DocumentIndex` — manages the full corpus index, persisted locally
/// - `CorpusSearch` — full-text search across all indexed documents
/// - `DedupDetector` — finds near-duplicate documents by content hash
///
/// Doctrine alignment:
/// - §3: Do things smartly — auto-tag from metadata, auto-detect dedup
/// - §5: Evidence-based — index entries have timestamps and provenance
/// - §8: Capability routing — organization is opt-in, index created on demand
/// - §12: Privacy stays value-free — index stores metadata, not content

// MARK: - Document Index Entry

/// A single document's metadata in the corpus index.
public struct DocumentIndexEntry: Codable, Sendable, Identifiable, Hashable {
  public let id: UUID
  /// File path (resolved, absolute).
  public let filePath: String
  /// File name (basename without path).
  public let fileName: String
  /// SHA-256 hash of the PDF content (for dedup).
  public let contentHash: String
  /// Page count.
  public let pageCount: Int
  /// File size in bytes.
  public let fileSize: Int64
  /// Title from PDF metadata.
  public let title: String
  /// Author from PDF metadata.
  public let author: String
  /// Tags assigned by the user.
  public var tags: Set<String>
  /// Folder/group name (nil = ungrouped).
  public var folder: String?
  /// When the document was first indexed.
  public let indexedAt: Date
  /// When the document was last accessed.
  public var lastAccessedAt: Date
  /// User-assigned rating (0 = unrated, 1–5 stars).
  public var rating: Int
  /// User notes about this document.
  public var notes: String
  /// Whether the document has been read completely.
  public var isRead: Bool
  /// Whether the document is starred/favorited.
  public var isStarred: Bool

  public init(
    filePath: String,
    contentHash: String,
    pageCount: Int,
    fileSize: Int64,
    title: String = "",
    author: String = "",
    tags: Set<String> = [],
    folder: String? = nil,
    rating: Int = 0,
    notes: String = "",
    isRead: Bool = false,
    isStarred: Bool = false
  ) {
    self.id = UUID()
    self.filePath = filePath
    self.fileName = URL(fileURLWithPath: filePath).lastPathComponent
    self.contentHash = contentHash
    self.pageCount = pageCount
    self.fileSize = fileSize
    self.title = title
    self.author = author
    self.tags = tags
    self.folder = folder
    self.indexedAt = Date()
    self.lastAccessedAt = Date()
    self.rating = rating
    self.notes = notes
    self.isRead = isRead
    self.isStarred = isStarred
  }
}

// MARK: - Document Index

/// Manages the full corpus index, persisted as a JSON sidecar.
@MainActor
public final class DocumentIndex: ObservableObject {
  /// All indexed documents.
  @Published public var entries: [DocumentIndexEntry] = []

  /// All known tags across the corpus.
  public var allTags: Set<String> {
    Set(entries.flatMap { $0.tags })
  }

  /// All known folders across the corpus.
  public var allFolders: Set<String> {
    Set(entries.compactMap { $0.folder })
  }

  /// Total corpus size in bytes.
  public var totalSize: Int64 {
    entries.reduce(0) { $0 + $1.fileSize }
  }

  /// Total pages across all documents.
  public var totalPages: Int {
    entries.reduce(0) { $0 + $1.pageCount }
  }

  private let fileManager = FileManager.default
  private var indexURL: URL?

  public init() {}

  // MARK: - Persistence

  /// Load index from disk.
  public func load(from directory: URL) {
    indexURL = directory.appendingPathComponent(".pdf-editor-index.json")
    guard let url = indexURL,
          let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode([DocumentIndexEntry].self, from: data)
    else { return }
    entries = decoded
  }

  /// Save index to disk.
  public func save() {
    guard let url = indexURL else { return }
    guard let data = try? JSONEncoder().encode(entries) else { return }
    try? data.write(to: url, options: .atomic)
  }

  // MARK: - Add/Remove

  /// Add a document to the index.
  @discardableResult
  public func addEntry(_ entry: DocumentIndexEntry) -> DocumentIndexEntry {
    // Check for existing entry by path
    if let existingIndex = entries.firstIndex(where: { $0.filePath == entry.filePath }) {
      // Update existing entry
      var updated = entries[existingIndex]
      entries[existingIndex] = updated
      save()
      return updated
    }
    entries.append(entry)
    save()
    return entry
  }

  /// Remove a document from the index.
  public func removeEntry(id: UUID) {
    entries.removeAll { $0.id == id }
    save()
  }

  /// Remove documents that no longer exist on disk.
  public func prune() {
    entries.removeAll { entry in
      !fileManager.fileExists(atPath: entry.filePath)
    }
    save()
  }

  // MARK: - Tagging

  /// Add a tag to a document.
  public func addTag(_ tag: String, to entryID: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
    entries[index].tags.insert(tag)
    save()
  }

  /// Remove a tag from a document.
  public func removeTag(_ tag: String, from entryID: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
    entries[index].tags.remove(tag)
    save()
  }

  /// Move a document to a folder.
  public func moveToFolder(_ folder: String?, entryID: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
    entries[index].folder = folder
    save()
  }

  // MARK: - Star/Rate

  /// Toggle star status.
  public func toggleStar(entryID: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
    entries[index].isStarred.toggle()
    save()
  }

  /// Set rating (0–5).
  public func setRating(_ rating: Int, entryID: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
    entries[index].rating = min(5, max(0, rating))
    save()
  }

  // MARK: - Queries

  /// Documents in a specific folder.
  public func documents(in folder: String) -> [DocumentIndexEntry] {
    entries.filter { $0.folder == folder }
  }

  /// Documents with a specific tag.
  public func documents(withTag tag: String) -> [DocumentIndexEntry] {
    entries.filter { $0.tags.contains(tag) }
  }

  /// Starred documents.
  public var starredDocuments: [DocumentIndexEntry] {
    entries.filter { $0.isStarred }
  }

  /// Unread documents.
  public var unreadDocuments: [DocumentIndexEntry] {
    entries.filter { !$0.isRead }
  }

  /// Recently accessed documents.
  public func recentDocuments(limit: Int = 10) -> [DocumentIndexEntry] {
    entries.sorted { $0.lastAccessedAt > $1.lastAccessedAt }
      .prefix(limit)
      .map { $0 }
  }
}

// MARK: - Corpus Search

/// Full-text search across the corpus index (metadata-based, not content-based).
@MainActor
public struct CorpusSearch: Sendable {
  public init() {}

  /// Search the index by query string (matches title, author, tags, notes).
  public func search(_ query: String, in index: DocumentIndex) -> [DocumentIndexEntry] {
    let lower = query.lowercased()
    return index.entries.filter { entry in
      entry.title.lowercased().contains(lower)
        || entry.author.lowercased().contains(lower)
        || entry.fileName.lowercased().contains(lower)
        || entry.tags.contains { $0.lowercased().contains(lower) }
        || entry.notes.lowercased().contains(lower)
    }
  }

  /// Search by tag.
  public func search(tag: String, in index: DocumentIndex) -> [DocumentIndexEntry] {
    index.entries.filter { $0.tags.contains(tag) }
  }

  /// Search by rating.
  public func search(minRating: Int, in index: DocumentIndex) -> [DocumentIndexEntry] {
    index.entries.filter { $0.rating >= minRating }
  }
}

// MARK: - Dedup Detector

/// Finds near-duplicate documents by content hash.
@MainActor
public struct DedupDetector: Sendable {
  public init() {}

  /// Find groups of duplicate documents (same content hash).
  public func findDuplicates(in index: DocumentIndex) -> [[DocumentIndexEntry]] {
    var hashGroups: [String: [DocumentIndexEntry]] = [:]
    for entry in index.entries {
      hashGroups[entry.contentHash, default: []].append(entry)
    }
    return hashGroups.values.filter { $0.count > 1 }
  }

  /// Count total duplicate groups.
  public func duplicateGroupCount(in index: DocumentIndex) -> Int {
    findDuplicates(in: index).count
  }

  /// Total wasted space from duplicates (bytes).
  public func wastedSpace(in index: DocumentIndex) -> Int64 {
    var wasted: Int64 = 0
    for group in findDuplicates(in: index) {
      let fileSize = group.first?.fileSize ?? 0
      wasted += fileSize * Int64(group.count - 1)
    }
    return wasted
  }
}
