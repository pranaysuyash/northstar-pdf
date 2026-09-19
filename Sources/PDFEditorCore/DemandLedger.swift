import Foundation

/// Local-only demand ledger (round-3 merged branch, audit §7.1 child 3): every
/// over-envelope open attempt appends one value-free JSONL row so the ranked
/// roadmap is observed demand, not guesses.
///
/// Doctrine alignment:
/// - Zero egress: rows are appended to a caller-supplied local file and are
///   never transmitted. No filename, no path, no content: only sizes, counts,
///   exceeded-row names, and an optional coarse layout-class label supplied by
///   the caller (who is responsible for it remaining value-free).
/// - Extends the existing `benchmark/results/rejection-ledger/` pattern into
///   the app rather than inventing a parallel store shape.
/// - Preserve data on malformed input: a corrupt existing ledger never blocks
///   or erases appends; the corrupt file is archived and a fresh ledger starts.
public struct DemandLedger: Sendable {

    public struct Entry: Codable, Equatable, Sendable {
        /// ISO-8601 timestamp of the refused open attempt.
        public let timestamp: String
        /// Value-free document facts (same discipline as the envelope itself).
        public let fileSizeBytes: Int
        public let pageCount: Int?
        /// Envelope row names that the document exceeded (e.g. "maxFileSizeBytes").
        public let exceededRows: [String]
        /// Coarse layout-fingerprint class label (caller-supplied, value-free).
        public let layoutClass: String?

        public init(timestamp: String, fileSizeBytes: Int, pageCount: Int?, exceededRows: [String], layoutClass: String?) {
            self.timestamp = timestamp
            self.fileSizeBytes = fileSizeBytes
            self.pageCount = pageCount
            self.exceededRows = exceededRows
            self.layoutClass = layoutClass
        }
    }

    public enum DemandLedgerError: Error, LocalizedError {
        case appendFailed(String)

        public var errorDescription: String? { 
            switch self {
            case let .appendFailed(reason): return "Demand ledger append failed: \(reason)"
            }
        }
    }

    /// Rotate once the active ledger exceeds this many bytes. One archived
    /// generation (`.1`) is kept; older archives are overwritten, bounding use.
    public let rotationThresholdBytes: Int
    private let serialQueue = DispatchQueue(label: "pdf-editor.demand-ledger", qos: .utility)

    public init(rotationThresholdBytes: Int = 1_048_576) {
        self.rotationThresholdBytes = rotationThresholdBytes
    }

    /// Appends one entry. Serializable rows only; the caller's file URL is the
    /// single storage location (in-app: Application Support, never a shared or
    /// synced container).
    public func append(_ entry: Entry, to url: URL) throws {
        try serialQueue.sync {
            rotateIfNeeded(url: url)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            guard var line = String(data: try encoder.encode(entry), encoding: .utf8) else {
                throw DemandLedgerError.appendFailed("entry failed UTF-8 encoding")
            }
            line.append("\n")
            // createFile TRUNCATES an existing file — only create when absent,
            // otherwise each append would wipe the ledger.
            if !FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                    throw DemandLedgerError.appendFailed("cannot create ledger at \(url.path)")
                }
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        }
    }

    /// Reads back all decodable entries (corrupt trailing lines are skipped,
    /// preserving the readable prefix — diagnostics never become data loss).
    public func entries(at url: URL) throws -> [Entry] {
        try serialQueue.sync {
            guard let data = FileManager.default.contents(atPath: url.path), !data.isEmpty else { return [] }
            let decoder = JSONDecoder()
            return data.split(separator: 0x0A).compactMap { line in
                try? decoder.decode(Entry.self, from: Data(line))
            }
        }
    }

    private func rotateIfNeeded(url: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int,
              size >= rotationThresholdBytes else { return }
        let archived = url.deletingPathExtension().appendingPathExtension("1.\(url.pathExtension)")
        // Single-generation archive: overwrite the previous archive if present.
        try? FileManager.default.removeItem(at: archived)
        try? FileManager.default.moveItem(at: url, to: archived)
    }
}
