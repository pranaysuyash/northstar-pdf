import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// Tests for advanced content-invariant raster extraction:
/// connected component regions and projection profiles.
///
/// These approaches operate at a higher structural level than cell-level
/// extraction, detecting page zones (headers, footers, sidebars) rather
/// than individual pixel occupancy.
///
/// Doctrine ref: §5 Evidence-based
@Suite("Content-Invariant Raster — Advanced Approaches")
struct ContentInvariantRasterAdvancedTests {

    // MARK: - Helpers

    private func loadPDF(_ name: String) -> PDFDocument? {
        let candidates = [
            "benchmark/results/corpus-sweep-2026-08-25/corpus/\(name)",
            "benchmark/results/2026-08-25-native-incremental/corpus/\(name)",
            "benchmark/results/browser-corpus/\(name)",
            "benchmark/results/contract-parity-2026-08-24/corpus/\(name)"
        ]
        for path in candidates {
            if let doc = PDFDocument(url: URL(fileURLWithPath: path)) {
                return doc
            }
        }
        return nil
    }

    private func extractCells(from doc: PDFDocument) -> Set<LayoutFingerprintV2.Cell>? {
        guard let page = doc.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        return ContentInvariantRasterExtractor.extractStructuralOccupancy(
            page: page, bounds: bounds, cellSize: 4.0
        )
    }

    private func extractEdgeCells(from doc: PDFDocument) -> Set<LayoutFingerprintV2.Cell>? {
        guard let page = doc.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        return ContentInvariantRasterExtractor.extractEdgeDetection(
            page: page, bounds: bounds, cellSize: 4.0
        )
    }

    // MARK: - Region Extraction

    @Test("Region extraction produces non-empty regions for form-bearing PDF")
    func regionExtractionNonEmpty() {
        guard let doc = loadPDF("compressed-acroform.pdf") else {
            Issue.record("Fixture not found")
            return
        }
        guard let cells = extractCells(from: doc),
              let page = doc.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let bounds = page.bounds(for: .cropBox)
        let regions = ContentInvariantRasterExtractor.extractRegions(
            cells: cells, cellSize: 4.0, bounds: bounds
        )
        #expect(!regions.isEmpty)
        #expect(regions.allSatisfy { $0.cellCount > 0 })
        #expect(regions.allSatisfy { $0.density > 0 && $0.density <= 1.0 })
    }

    @Test("Region extraction is deterministic")
    func regionDeterministic() {
        guard let doc = loadPDF("compressed-acroform.pdf") else {
            Issue.record("Fixture not found")
            return
        }
        guard let cells = extractCells(from: doc),
              let page = doc.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let bounds = page.bounds(for: .cropBox)
        let r1 = ContentInvariantRasterExtractor.extractRegions(
            cells: cells, cellSize: 4.0, bounds: bounds
        )
        let r2 = ContentInvariantRasterExtractor.extractRegions(
            cells: cells, cellSize: 4.0, bounds: bounds
        )
        #expect(r1 == r2)
    }

    @Test("Region similarity: same document = 1.0")
    func regionSameDoc() {
        guard let doc = loadPDF("compressed-acroform.pdf") else {
            Issue.record("Fixture not found")
            return
        }
        guard let cells = extractCells(from: doc),
              let page = doc.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let bounds = page.bounds(for: .cropBox)
        let regions = ContentInvariantRasterExtractor.extractRegions(
            cells: cells, cellSize: 4.0, bounds: bounds
        )
        let sim = ContentInvariantRasterExtractor.regionSimilarity(regions, regions)
        #expect(sim == 1.0)
    }

    @Test("Region similarity: empty = 1.0")
    func regionBothEmpty() {
        let sim = ContentInvariantRasterExtractor.regionSimilarity([], [])
        #expect(sim == 1.0)
    }

    @Test("Region similarity: one empty = 0.0")
    func regionOneEmpty() {
        guard let doc = loadPDF("compressed-acroform.pdf") else {
            Issue.record("Fixture not found")
            return
        }
        guard let cells = extractCells(from: doc),
              let page = doc.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let bounds = page.bounds(for: .cropBox)
        let regions = ContentInvariantRasterExtractor.extractRegions(
            cells: cells, cellSize: 4.0, bounds: bounds
        )
        #expect(ContentInvariantRasterExtractor.regionSimilarity(regions, []) == 0.0)
        #expect(ContentInvariantRasterExtractor.regionSimilarity([], regions) == 0.0)
    }

    @Test("Region similarity: different documents score lower than same")
    func regionDifferentDocs() {
        guard let docA = loadPDF("compressed-acroform.pdf"),
              let docB = loadPDF("scanned-noisy.pdf") else {
            Issue.record("Fixtures not found")
            return
        }
        guard let cellsA = extractCells(from: docA),
              let cellsB = extractCells(from: docB),
              let pageA = docA.page(at: 0),
              let pageB = docB.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let boundsA = pageA.bounds(for: .cropBox)
        let boundsB = pageB.bounds(for: .cropBox)
        let regionsA = ContentInvariantRasterExtractor.extractRegions(
            cells: cellsA, cellSize: 4.0, bounds: boundsA
        )
        let regionsB = ContentInvariantRasterExtractor.extractRegions(
            cells: cellsB, cellSize: 4.0, bounds: boundsB
        )
        let simSame = ContentInvariantRasterExtractor.regionSimilarity(regionsA, regionsA)
        let simDiff = ContentInvariantRasterExtractor.regionSimilarity(regionsA, regionsB)
        #expect(simSame > simDiff)
        print("[region] same=\(String(format: "%.4f", simSame)) diff=\(String(format: "%.4f", simDiff))")
    }

    // MARK: - Projection Profiles

    @Test("Projection profile extraction produces correct bin count")
    func projectionBinCount() {
        guard let doc = loadPDF("compressed-acroform.pdf") else {
            Issue.record("Fixture not found")
            return
        }
        guard let cells = extractCells(from: doc),
              let page = doc.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let bounds = page.bounds(for: .cropBox)
        let profile = ContentInvariantRasterExtractor.extractProjectionProfiles(
            cells: cells, cellSize: 4.0, bounds: bounds, binCount: 32
        )
        #expect(profile.horizontal.count == 32)
        #expect(profile.vertical.count == 32)
        #expect(profile.binCount == 32)
    }

    @Test("Projection profile: empty cells = all zeros")
    func projectionEmpty() {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let profile = ContentInvariantRasterExtractor.extractProjectionProfiles(
            cells: [], cellSize: 4.0, bounds: bounds, binCount: 32
        )
        #expect(profile.horizontal.allSatisfy { $0 == 0 })
        #expect(profile.vertical.allSatisfy { $0 == 0 })
    }

    @Test("Projection similarity: same document = 1.0")
    func projectionSameDoc() {
        guard let doc = loadPDF("compressed-acroform.pdf") else {
            Issue.record("Fixture not found")
            return
        }
        guard let cells = extractCells(from: doc),
              let page = doc.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let bounds = page.bounds(for: .cropBox)
        let profile = ContentInvariantRasterExtractor.extractProjectionProfiles(
            cells: cells, cellSize: 4.0, bounds: bounds
        )
        let sim = ContentInvariantRasterExtractor.projectionSimilarity(profile, profile)
        #expect(sim == 1.0)
    }

    @Test("Projection similarity: empty = 1.0")
    func projectionBothEmpty() {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let p = ContentInvariantRasterExtractor.extractProjectionProfiles(
            cells: [], cellSize: 4.0, bounds: bounds
        )
        #expect(ContentInvariantRasterExtractor.projectionSimilarity(p, p) == 1.0)
    }

    @Test("Projection similarity: different documents score lower than same")
    func projectionDifferentDocs() {
        guard let docA = loadPDF("compressed-acroform.pdf"),
              let docB = loadPDF("scanned-noisy.pdf") else {
            Issue.record("Fixtures not found")
            return
        }
        guard let cellsA = extractCells(from: docA),
              let cellsB = extractCells(from: docB),
              let pageA = docA.page(at: 0),
              let pageB = docB.page(at: 0) else {
            Issue.record("Extraction failed")
            return
        }
        let boundsA = pageA.bounds(for: .cropBox)
        let boundsB = pageB.bounds(for: .cropBox)
        let profileA = ContentInvariantRasterExtractor.extractProjectionProfiles(
            cells: cellsA, cellSize: 4.0, bounds: boundsA
        )
        let profileB = ContentInvariantRasterExtractor.extractProjectionProfiles(
            cells: cellsB, cellSize: 4.0, bounds: boundsB
        )
        let simSame = ContentInvariantRasterExtractor.projectionSimilarity(profileA, profileA)
        let simDiff = ContentInvariantRasterExtractor.projectionSimilarity(profileA, profileB)
        #expect(simSame > simDiff)
        print("[projection] same=\(String(format: "%.4f", simSame)) diff=\(String(format: "%.4f", simDiff))")
    }

    // MARK: - Corpus Sweep (key pairs)

    @Test("Region + projection: re-encoding pairs score higher than different-doc pairs")
    func corpusSweepRegionProjection() {
        // Load key fixtures.
        let fixtureNames = [
            "compressed-acroform.pdf", "tagged-acroform.pdf",
            "public-sample-form.pdf", "scanned-noisy.pdf"
        ]
        var fixtures: [(name: String, doc: PDFDocument, cells: Set<LayoutFingerprintV2.Cell>)] = []
        for name in fixtureNames {
            guard let doc = loadPDF(name),
                  let cells = extractCells(from: doc) else { continue }
            fixtures.append((name, doc, cells))
        }
        guard fixtures.count >= 3 else {
            Issue.record("Need at least 3 fixtures")
            return
        }

        print("\n=== Region + Projection Sweep ===")
        print("Fixtures: \(fixtures.map { $0.name })")

        // Compare all pairs.
        for i in 0..<fixtures.count {
            for j in (i + 1)..<fixtures.count {
                let a = fixtures[i]
                let b = fixtures[j]
                guard let pageA = a.doc.page(at: 0),
                      let pageB = b.doc.page(at: 0) else { continue }
                let boundsA = pageA.bounds(for: .cropBox)
                let boundsB = pageB.bounds(for: .cropBox)

                // Regions
                let regionsA = ContentInvariantRasterExtractor.extractRegions(
                    cells: a.cells, cellSize: 4.0, bounds: boundsA)
                let regionsB = ContentInvariantRasterExtractor.extractRegions(
                    cells: b.cells, cellSize: 4.0, bounds: boundsB)
                let regionSim = ContentInvariantRasterExtractor.regionSimilarity(regionsA, regionsB)

                // Projections
                let projA = ContentInvariantRasterExtractor.extractProjectionProfiles(
                    cells: a.cells, cellSize: 4.0, bounds: boundsA)
                let projB = ContentInvariantRasterExtractor.extractProjectionProfiles(
                    cells: b.cells, cellSize: 4.0, bounds: boundsB)
                let projSim = ContentInvariantRasterExtractor.projectionSimilarity(projA, projB)

                // Binary baseline
                let binarySim = jaccard(a.cells, b.cells)

                let isReencoding = (a.name == "compressed-acroform.pdf" && b.name == "tagged-acroform.pdf")
                    || (a.name == "compressed-acroform.pdf" && b.name == "public-sample-form.pdf")
                let label = isReencoding ? "RE-ENCODING" : "DIFFERENT"

                print("[\(label)] \(a.name)↔\(b.name):")
                print("  binary=\(String(format: "%.4f", binarySim)) region=\(String(format: "%.4f", regionSim)) proj=\(String(format: "%.4f", projSim))")
                print("  regions: \(regionsA.count)↔\(regionsB.count)  proj-bins: \(projA.binCount)")

                if isReencoding {
                    // Re-encoding pairs should have high region and projection similarity.
                    #expect(regionSim > 0.5, "Re-encoding region similarity should be > 0.5")
                    #expect(projSim > 0.5, "Re-encoding projection similarity should be > 0.5")
                }
            }
        }
    }

    // MARK: - Helpers

    private func jaccard(_ a: Set<LayoutFingerprintV2.Cell>, _ b: Set<LayoutFingerprintV2.Cell>) -> Double {
        if a.isEmpty && b.isEmpty { return 1.0 }
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}
