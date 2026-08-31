import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Focused content-invariant raster extraction test.
/// Tests key pairs only (not full 630-pair corpus) for speed.
@Suite("Content-invariant raster extraction (focused)")
struct ContentInvariantRasterTests {

    private static let corpus = "/Users/pranay/Projects/pdf_editor/benchmark/results"

    /// Load a fixture's first page
    private func loadPage(_ relativePath: String) -> (PDFPage, CGRect)? {
        let url = URL(fileURLWithPath: "\(Self.corpus)/\(relativePath)")
        guard let doc = PDFDocument(url: url),
              let page = doc.page(at: 0) else { return nil }
        return (page, page.bounds(for: .cropBox))
    }

    // MARK: - Extraction approaches

    /// Binary occupancy (V2 parameters: 4pt, 0.10 threshold)
    private func extractBinary(page: PDFPage, bounds: CGRect) -> Set<LayoutFingerprintV2.Cell> {
        let cellSize = 4.0, threshold = 0.10
        let scale: CGFloat = 0.15
        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        guard renderSize.width > 0, renderSize.height > 0 else { return [] }
        let image = page.thumbnail(of: renderSize, for: .cropBox)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let width = cgImage.width, height = cgImage.height
        guard width > 0, height > 0 else { return [] }
        let byteCount = width * height * 4
        let pixelData = NSMutableData(length: byteCount)!
        guard let ctx = CGContext(data: pixelData.mutableBytes, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = pixelData.bytes.bindMemory(to: UInt8.self, capacity: byteCount)
        let cols = Int(ceil(bounds.width / cellSize))
        let rows = Int(ceil(bounds.height / cellSize))
        var cells = Set<LayoutFingerprintV2.Cell>()
        for row in 0..<rows {
            for col in 0..<cols {
                let px = Int(((Double(col) + 0.5) * cellSize / bounds.width) * Double(width))
                let py = Int(((Double(row) + 0.5) * cellSize / bounds.height) * Double(height))
                var nonBlank = 0, total = 0
                for dx in -1...1 { for dy in -1...1 {
                    let sx = min(max(px + dx, 0), width - 1)
                    let sy = min(max(py + dy, 0), height - 1)
                    let off = (sy * width + sx) * 4
                    guard off + 3 < byteCount else { continue }
                    total += 1
                    if bytes[off] < 245 || bytes[off+1] < 245 || bytes[off+2] < 245 { nonBlank += 1 }
                }}
                if total > 0 && Double(nonBlank) / Double(total) >= threshold {
                    cells.insert(LayoutFingerprintV2.Cell(col: col, row: row))
                }
            }
        }
        return cells
    }

    private func jaccard(_ a: Set<LayoutFingerprintV2.Cell>, _ b: Set<LayoutFingerprintV2.Cell>) -> Double {
        if a.isEmpty && b.isEmpty { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    // MARK: - Tests

    @Test("Approach comparison on 6 key pairs")
    func approachComparison() {
        // Positive pairs (re-encoding of same form)
        let positivePairs: [(String, String)] = [
            ("public-sample-form.pdf", "2026-08-25-native-incremental/corpus/compressed-acroform.pdf"),
            ("public-sample-form.pdf", "2026-08-25-native-incremental/corpus/tagged-acroform.pdf"),
            ("public-sample-form.pdf", "2026-08-25-native-incremental/corpus/tagged-no-acroform.pdf"),
        ]
        // Negative pairs (different layout)
        let negativePairs: [(String, String)] = [
            ("public-sample-form.pdf", "corpus-sweep-2026-08-25/plain-text.pdf"),
            ("public-sample-form.pdf", "corpus-sweep-2026-08-25/navigation.pdf"),
            ("public-sample-form.pdf", "browser-corpus/scanned-noisy.pdf"),
        ]

        let allPairs = positivePairs.map { ($0.0, $0.1, true) }
            + negativePairs.map { ($0.0, $0.1, false) }

        print("\n=== Approach comparison (6 key pairs) ===")
        print("Pair | binary | structural | edge | combined")
        print("-----|--------|------------|------|---------")

        var posSims: [String: [Double]] = ["binary": [], "structural": [], "edge": [], "combined": []]
        var negSims: [String: [Double]] = ["binary": [], "structural": [], "edge": [], "combined": []]

        for (aPath, bPath, isPositive) in allPairs {
            guard let (aPage, aBounds) = loadPage(aPath),
                  let (bPage, bBounds) = loadPage(bPath) else { continue }
            let aName = URL(fileURLWithPath: aPath).lastPathComponent
            let bName = URL(fileURLWithPath: bPath).lastPathComponent

            let binaryA = extractBinary(page: aPage, bounds: aBounds)
            let binaryB = extractBinary(page: bPage, bounds: bBounds)
            let structA = ContentInvariantRasterExtractor.extractStructuralOccupancy(page: aPage, bounds: aBounds)
            let structB = ContentInvariantRasterExtractor.extractStructuralOccupancy(page: bPage, bounds: bBounds)
            let edgeA = ContentInvariantRasterExtractor.extractEdgeDetection(page: aPage, bounds: aBounds)
            let edgeB = ContentInvariantRasterExtractor.extractEdgeDetection(page: bPage, bounds: bBounds)
            let combA = ContentInvariantRasterExtractor.extractCombined(page: aPage, bounds: aBounds)
            let combB = ContentInvariantRasterExtractor.extractCombined(page: bPage, bounds: bBounds)

            let bs = jaccard(binaryA, binaryB)
            let ss = jaccard(structA, structB)
            let es = jaccard(edgeA, edgeB)
            let cs = jaccard(combA, combB)

            let label = isPositive ? "POS" : "NEG"
            print("[\(label)] \(aName)↔\(bName): \(String(format: "%.4f", bs)) | \(String(format: "%.4f", ss)) | \(String(format: "%.4f", es)) | \(String(format: "%.4f", cs))")
            print("       cells: \(binaryA.count)↔\(binaryB.count) | \(structA.count)↔\(structB.count) | \(edgeA.count)↔\(edgeB.count) | \(combA.count)↔\(combB.count)")

            posSims["binary"]!.append(bs)
            posSims["structural"]!.append(ss)
            posSims["edge"]!.append(es)
            posSims["combined"]!.append(cs)
            if isPositive {
                negSims["binary"]!.append(bs)
                negSims["structural"]!.append(ss)
                negSims["edge"]!.append(es)
                negSims["combined"]!.append(cs)
            } else {
                negSims["binary"]!.append(bs)
                negSims["structural"]!.append(ss)
                negSims["edge"]!.append(es)
                negSims["combined"]!.append(cs)
            }
        }

        // Summary
        print("\n=== Summary ===")
        print("Approach     | pos min | neg max | gap    | improvement vs binary")
        print("-------------|---------|---------|--------|----------------------")
        for approach in ["binary", "structural", "edge", "combined"] {
            let pMin = posSims[approach]!.min() ?? 0
            let nMax = negSims[approach]!.max() ?? 0
            let gap = pMin - nMax
            let binPMin = posSims["binary"]!.min() ?? 0
            let binNMax = negSims["binary"]!.max() ?? 0
            let improvement = approach == "binary" ? "baseline" :
                String(format: "pos %+.4f neg %+.4f", pMin - binPMin, nMax - binNMax)
            print("\(approach.padding(toLength: 13, withPad: " ", startingAt: 0)) | \(String(format: "%.4f", pMin)) | \(String(format: "%.4f", nMax)) | \(String(format: "%.4f", gap)) | \(improvement)")
        }
    }
}
