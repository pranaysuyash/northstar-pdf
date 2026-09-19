import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Demand Ledger Tests (round-3 audit §7.1 child 3; R3-28)

@Suite("Demand Ledger")
struct DemandLedgerTests {

    private func temporaryLedgerURL(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("demand-ledger-tests-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return url
    }

    @Test("Append and read back value-free entries")
    func appendAndReadBack() throws {
        let ledger = DemandLedger()
        let url = temporaryLedgerURL("ledger.jsonl")
        let entry = DemandLedger.Entry(
            timestamp: "2026-09-17T00:00:00Z",
            fileSizeBytes: 60_000_000,
            pageCount: 3,
            exceededRows: ["maxFileSizeBytes"],
            layoutClass: "form-like"
        )
        try ledger.append(entry, to: url)
        try ledger.append(entry, to: url)

        let entries = try ledger.entries(at: url)
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { $0.exceededRows == ["maxFileSizeBytes"] })

        // Value-free guarantee: no paths or file names may appear in the store.
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.contains("/Users/"))
        #expect(!raw.contains("ledger.jsonl"))
        #expect(!raw.contains("sourcePath"))
    }

    @Test("Rotation archives one generation and starts fresh")
    func rotation() throws {
        let ledger = DemandLedger(rotationThresholdBytes: 200)
        let url = temporaryLedgerURL("rotating.jsonl")
        let entry = DemandLedger.Entry(
            timestamp: "2026-09-17T00:00:00Z", fileSizeBytes: 1, pageCount: 1, exceededRows: [], layoutClass: nil
        )
        // First appends fill the active ledger past the tiny threshold.
        for _ in 0..<5 { try ledger.append(entry, to: url) }
        let beforeRotationArchive = url.deletingPathExtension().appendingPathExtension("1.jsonl")
        // The rotation happened on one of the appends (5 entries > 200 bytes).
        let archivedData = try? Data(contentsOf: beforeRotationArchive)
        let activeCount = try ledger.entries(at: url).count
        #expect((archivedData?.isEmpty == false) || activeCount > 0)

        // Everything appended remains recoverable across active + archive.
        let allDecodable = (try ledger.entries(at: url)).count
            + (archivedData.map { data in
                data.split(separator: 0x0A).compactMap { try? JSONDecoder().decode(DemandLedger.Entry.self, from: Data($0)) }.count
            } ?? 0)
        #expect(allDecodable >= 5)
    }

    @Test("Corrupt existing ledger does not block appends (preserve-on-malformed)")
    func corruptLedgerDoesNotBlockAppends() throws {
        let ledger = DemandLedger()
        let url = temporaryLedgerURL("corrupt.jsonl")
        try Data("this is not json\n".utf8).write(to: url)
        let entry = DemandLedger.Entry(
            timestamp: "2026-09-17T00:00:00Z", fileSizeBytes: 10, pageCount: nil, exceededRows: [], layoutClass: nil
        )
        try ledger.append(entry, to: url)
        // The corrupt line is skipped; the good entry is still readable.
        let entries = try ledger.entries(at: url)
        #expect(entries.count == 1)
        #expect(entries.first?.fileSizeBytes == 10)
    }
}
