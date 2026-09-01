import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

@Suite("Region Similarity Channel")
struct RegionSimilarityChannelTests {

    private let root = FileManager.default.currentDirectoryPath

    private func fingerprint(_ name: String) -> LayoutFingerprintV2? {
        let path = "\(root)/benchmark/results/corpus-sweep-2026-08-25/\(name)"
        guard FileManager.default.fileExists(atPath: path),
              let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { return nil }
        return LayoutFingerprintV2Extractor.extract(from: doc)
    }

    @Test("Region similarity discriminates different layouts")
    func discriminatesLayouts() throws {
        guard let fp1 = fingerprint("plain-text.pdf"),
              let fp2 = fingerprint("multi-column.pdf") else { return }
        let sim = fp1.similarity(to: fp2)
        #expect(sim.regionLayout < 0.8, "Region similarity \(sim.regionLayout) should discriminate")
        #expect(sim.total < 0.7, "Total \(sim.total) should be below family threshold")
        print("[region] plain vs multi: region=\(String(format: "%.4f", sim.regionLayout)) total=\(String(format: "%.4f", sim.total))")
    }

    @Test("Region similarity is 1.0 for identical documents")
    func identicalDocuments() throws {
        guard let fp1 = fingerprint("plain-text.pdf"),
              let fp2 = fingerprint("plain-text.pdf") else { return }
        let sim = fp1.similarity(to: fp2)
        #expect(sim.regionLayout == 1.0)
        #expect(sim.total == 1.0)
    }

    @Test("Region channels are populated for text-heavy documents")
    func regionsPopulated() throws {
        guard let fp = fingerprint("plain-text.pdf") else { return }
        let regionCount = fp.pages.first?.textRegions.count ?? 0
        #expect(regionCount > 0, "Text-heavy document should have regions, got \(regionCount)")
        print("[region] plain-text: \(regionCount) regions")
    }

    @Test("Region similarity contributes to total")
    func contributesToTotal() throws {
        guard let fp1 = fingerprint("plain-text.pdf"),
              let fp2 = fingerprint("multi-column.pdf") else { return }
        let sim = fp1.similarity(to: fp2)
        #expect(sim.regionLayout > 0.0, "Region should have non-zero value")
        #expect(sim.regionLayout < 1.0, "Region should discriminate")
        print("[region] contribution: region=\(String(format: "%.4f", sim.regionLayout)) total=\(String(format: "%.4f", sim.total))")
    }
}
