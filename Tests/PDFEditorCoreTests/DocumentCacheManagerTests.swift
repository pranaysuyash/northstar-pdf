import Foundation
import Testing
@testable import PDFEditorCore

@Suite("R-03 DocumentCacheManager")
struct DocumentCacheManagerTests {
    @Test("Store and retrieve cache entry")
    func storeRetrieve() {
        let cache = DocumentCacheManager(maxCacheSizeMB: 10)
        let entry = CacheEntry(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72, sizeBytes: 1024)
        cache.store(entry)
        let retrieved = cache.retrieve(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72)
        #expect(retrieved != nil)
        #expect(retrieved!.documentID == "doc1")
    }

    @Test("Cache miss returns nil")
    func cacheMiss() {
        let cache = DocumentCacheManager()
        let retrieved = cache.retrieve(documentID: "nonexistent", contentType: .renderedPage, pageIndex: 0, dpi: 72)
        #expect(retrieved == nil)
    }

    @Test("Evict document removes all its entries")
    func evictDocument() {
        let cache = DocumentCacheManager()
        cache.store(CacheEntry(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72, sizeBytes: 100))
        cache.store(CacheEntry(documentID: "doc1", contentType: .thumbnail, pageIndex: 0, dpi: 72, sizeBytes: 100))
        cache.store(CacheEntry(documentID: "doc2", contentType: .renderedPage, pageIndex: 0, dpi: 72, sizeBytes: 100))
        cache.evictDocument("doc1")
        #expect(cache.retrieve(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72) == nil)
        #expect(cache.retrieve(documentID: "doc2", contentType: .renderedPage, pageIndex: 0, dpi: 72) != nil)
    }

    @Test("Clear all removes everything")
    func clearAll() {
        let cache = DocumentCacheManager()
        cache.store(CacheEntry(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72, sizeBytes: 100))
        cache.clearAll()
        let stats = cache.statistics
        #expect(stats.entryCount == 0)
    }

    @Test("Statistics track hits and misses")
    func statistics() {
        let cache = DocumentCacheManager()
        cache.store(CacheEntry(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72, sizeBytes: 1024))
        _ = cache.retrieve(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72)
        _ = cache.retrieve(documentID: "doc1", contentType: .renderedPage, pageIndex: 0, dpi: 72)
        _ = cache.retrieve(documentID: "missing", contentType: .renderedPage, pageIndex: 0, dpi: 72)
        let stats = cache.statistics
        #expect(stats.entryCount == 1)
        #expect(stats.totalSizeBytes == 1024)
        #expect(stats.hitRate > 0.5)
    }
}
