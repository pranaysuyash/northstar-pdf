import Foundation

/// Document-level cache manager — manages cached pages, thumbnails, and
/// extracted data across sessions.
///
/// First principle: caching is transparent — the user never thinks about it.
/// The cache manager decides what to keep, what to evict, and when to warm.
///
/// Architecture:
/// - Per-document cache entries with access timestamps
/// - LRU eviction when total cache exceeds budget
/// - Warm-up on document open (first N pages)
/// - Eviction on low disk space
///
/// Doctrine alignment:
/// - §3: Do things smartly — cache what's used, evict what's not
/// - §5: Evidence-based — cache stats are tracked and queryable

// MARK: - Cache Entry

/// A single cached item for a document.
public struct CacheEntry: Codable, Sendable {
  /// Document identifier (file name).
  public let documentID: String
  /// What type of content is cached.
  public let contentType: CacheContentType
  /// Page index (for page-level caches).
  public let pageIndex: Int
  /// DPI at which the content was rendered.
  public let dpi: Int
  /// Size in bytes.
  public let sizeBytes: Int
  /// When this entry was last accessed.
  public var lastAccessedAt: Date
  /// When this entry was created.
  public let createdAt: Date

  public init(
    documentID: String,
    contentType: CacheContentType,
    pageIndex: Int,
    dpi: Int,
    sizeBytes: Int
  ) {
    self.documentID = documentID
    self.contentType = contentType
    self.pageIndex = pageIndex
    self.dpi = dpi
    self.sizeBytes = sizeBytes
    self.lastAccessedAt = Date()
    self.createdAt = Date()
  }
}

// MARK: - Cache Content Type

/// Types of cached content.
public enum CacheContentType: String, Codable, Sendable {
  case renderedPage = "rendered_page"
  case thumbnail = "thumbnail"
  case extractedText = "extracted_text"
  case documentMetadata = "document_metadata"

  public var displayName: String {
    switch self {
    case .renderedPage: return "Rendered Page"
    case .thumbnail: return "Thumbnail"
    case .extractedText: return "Extracted Text"
    case .documentMetadata: return "Document Metadata"
    }
  }
}

// MARK: - Cache Statistics

/// Statistics about the cache state.
public struct CacheStatistics: Sendable {
  /// Total number of cached entries.
  public let entryCount: Int
  /// Total size in bytes.
  public let totalSizeBytes: Int
  /// Number of unique documents cached.
  public let documentCount: Int
  /// Cache hit rate (0.0–1.0).
  public let hitRate: Double
  /// Number of evictions in this session.
  public let evictionCount: Int

  public var totalSizeMB: Double {
    Double(totalSizeBytes) / (1024 * 1024)
  }

  public var description: String {
    "\(entryCount) entries, \(String(format: "%.1f", totalSizeMB)) MB, \(documentCount) documents, \(Int(hitRate * 100))% hit rate"
  }
}

// MARK: - Document Cache Manager

/// Manages cached pages, thumbnails, and extracted data.
///
/// Thread-safe via NSLock. All operations are synchronous for simplicity.
public final class DocumentCacheManager: @unchecked Sendable {
  /// Maximum total cache size in bytes (default 200 MB).
  private let maxCacheSizeBytes: Int
  /// Maximum entries per document.
  private let maxEntriesPerDocument: Int
  /// All cache entries, keyed by "documentID:contentType:pageIndex:dpi".
  private var entries: [String: CacheEntry] = [:]
  /// Insertion order for LRU eviction.
  private var accessOrder: [String] = []
  /// Total cache size in bytes.
  private var totalSizeBytes: Int = 0
  /// Cache hit counter.
  private var hitCount: Int = 0
  /// Cache miss counter.
  private var missCount: Int = 0
  /// Eviction counter.
  private var evictionCount: Int = 0
  private let lock = NSLock()

  public init(
    maxCacheSizeMB: Int = 200,
    maxEntriesPerDocument: Int = 50
  ) {
    self.maxCacheSizeBytes = maxCacheSizeMB * 1024 * 1024
    self.maxEntriesPerDocument = maxEntriesPerDocument
  }

  // MARK: - Cache Operations

  /// Store an entry in the cache.
  public func store(_ entry: CacheEntry) {
    lock.lock()
    defer { lock.unlock() }

    let key = self.key(for: entry)

    // If already cached, update access time
    if var existing = entries[key] {
      existing.lastAccessedAt = Date()
      entries[key] = existing
      touchKey(key)
      return
    }

    // Check per-document limit
    let docEntries = entries.values.filter { $0.documentID == entry.documentID }
    if docEntries.count >= maxEntriesPerDocument {
      // Evict oldest entry for this document
      if let oldest = docEntries.min(by: { $0.lastAccessedAt < $1.lastAccessedAt }) {
        evict(key: self.key(for: oldest))
      }
    }

    // Check total cache size
    while totalSizeBytes + entry.sizeBytes > maxCacheSizeBytes, !accessOrder.isEmpty {
      evictOldest()
    }

    // Add entry
    entries[key] = entry
    totalSizeBytes += entry.sizeBytes
    accessOrder.append(key)
  }

  /// Retrieve a cached entry (updates access time).
  public func retrieve(
    documentID: String,
    contentType: CacheContentType,
    pageIndex: Int,
    dpi: Int
  ) -> CacheEntry? {
    lock.lock()
    defer { lock.unlock() }

    let key = "\(documentID):\(contentType.rawValue):\(pageIndex):\(dpi)"
    if var entry = entries[key] {
      entry.lastAccessedAt = Date()
      entries[key] = entry
      touchKey(key)
      hitCount += 1
      return entry
    }
    missCount += 1
    return nil
  }

  /// Evict all entries for a specific document.
  public func evictDocument(_ documentID: String) {
    lock.lock()
    defer { lock.unlock() }

    let keysToEvict = entries.values
      .filter { $0.documentID == documentID }
      .map { key(for: $0) }

    for key in keysToEvict {
      evict(key: key)
    }
  }

  /// Clear the entire cache.
  public func clearAll() {
    lock.lock()
    defer { lock.unlock() }

    entries.removeAll()
    accessOrder.removeAll()
    totalSizeBytes = 0
  }

  // MARK: - Statistics

  /// Get current cache statistics.
  public var statistics: CacheStatistics {
    lock.lock()
    defer { lock.unlock() }

    let totalHits = hitCount + missCount
    let hitRate = totalHits > 0 ? Double(hitCount) / Double(totalHits) : 0
    let documentCount = Set(entries.values.map(\.documentID)).count

    return CacheStatistics(
      entryCount: entries.count,
      totalSizeBytes: totalSizeBytes,
      documentCount: documentCount,
      hitRate: hitRate,
      evictionCount: evictionCount
    )
  }

  // MARK: - Private

  private func key(for entry: CacheEntry) -> String {
    "\(entry.documentID):\(entry.contentType.rawValue):\(entry.pageIndex):\(entry.dpi)"
  }

  private func touchKey(_ key: String) {
    accessOrder.removeAll { $0 == key }
    accessOrder.append(key)
  }

  private func evict(key: String) {
    guard let entry = entries.removeValue(forKey: key) else { return }
    totalSizeBytes -= entry.sizeBytes
    accessOrder.removeAll { $0 == key }
    evictionCount += 1
  }

  private func evictOldest() {
    guard let oldestKey = accessOrder.first else { return }
    evict(key: oldestKey)
  }
}
