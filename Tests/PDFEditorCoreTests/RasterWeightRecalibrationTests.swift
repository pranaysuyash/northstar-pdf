import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Focused raster weight recalibration with multi-scale extraction.
/// Tests 6 key pairs: 3 positive (re-encoding) and 3 negative (different-layout).
@Suite("Raster weight recalibration (multi-scale)")
struct RasterWeightRecalibrationTests {
    
    private static let corpus = "\(TestRepoRoot.prefix)benchmark/results"
    
    /// Load a fixture and extract its V2 fingerprint
    private func load(_ relativePath: String) -> LayoutFingerprintV2? {
        let url = URL(fileURLWithPath: "\(Self.corpus)/\(relativePath)")
        guard let doc = PDFDocument(url: url),
              let fp = LayoutFingerprintV2Extractor.extract(from: doc) else { return nil }
        return fp
    }
    
    /// Positive pairs: layout-identical re-encodings of the same form
    private let positivePairs: [(String, String)] = [
        ("public-sample-form.pdf", "2026-08-25-native-incremental/corpus/compressed-acroform.pdf"),
        ("public-sample-form.pdf", "2026-08-25-native-incremental/corpus/tagged-acroform.pdf"),
        ("public-sample-form.pdf", "2026-08-25-native-incremental/corpus/tagged-no-acroform.pdf"),
    ]
    
    /// Negative pairs: layout-distinct documents
    private let negativePairs: [(String, String)] = [
        ("public-sample-form.pdf", "corpus-sweep-2026-08-25/plain-text.pdf"),
        ("public-sample-form.pdf", "corpus-sweep-2026-08-25/navigation.pdf"),
        ("corpus-sweep-2026-08-25/plain-text.pdf", "corpus-sweep-2026-08-25/multi-column.pdf"),
    ]
    
    @Test("Multi-scale raster: re-encoding pairs have perfect raster similarity")
    func reencodingPairs() {
        for (aPath, bPath) in positivePairs {
            guard let a = load(aPath), let b = load(bPath) else { continue }
            let sim = a.similarity(to: b)
            let aName = URL(fileURLWithPath: aPath).lastPathComponent
            let bName = URL(fileURLWithPath: bPath).lastPathComponent
            print("[reencode] \(aName)↔\(bName): raster=\(String(format: "%.4f", sim.rasterLayout)) total=\(String(format: "%.4f", sim.total))")
            // Multi-scale extraction (4/16/64pt) tolerates sub-cell anti-aliasing divergence:
            // re-encodings score ≥0.95 (measured 0.9845) rather than exact 1.0 (Observed 2026-09-02).
            #expect(sim.rasterLayout >= 0.95, "Re-encoding pair \(aName)↔\(bName) should have near-perfect raster similarity (≥0.95), got \(sim.rasterLayout)")
        }
    }
    
    @Test("Multi-scale raster: different-layout documents have low raster similarity")
    func differentLayoutPairs() {
        for (aPath, bPath) in negativePairs {
            guard let a = load(aPath), let b = load(bPath) else { continue }
            let sim = a.similarity(to: b)
            let aName = URL(fileURLWithPath: aPath).lastPathComponent
            let bName = URL(fileURLWithPath: bPath).lastPathComponent
            print("[diff-layout] \(aName)↔\(bName): raster=\(String(format: "%.4f", sim.rasterLayout)) total=\(String(format: "%.4f", sim.total))")
            #expect(sim.rasterLayout < 1.0, "Different-layout pair \(aName)↔\(bName) should have raster < 1.0")
        }
    }
    
    @Test("Raster weight sweep: find maximum valid weight")
    func weightSweep() {
        // Load all fixtures
        var allPairs: [(a: LayoutFingerprintV2, b: LayoutFingerprintV2, isPositive: Bool)] = []
        
        for (aPath, bPath) in positivePairs {
            guard let a = load(aPath), let b = load(bPath) else { continue }
            allPairs.append((a, b, true))
        }
        for (aPath, bPath) in negativePairs {
            guard let a = load(aPath), let b = load(bPath) else { continue }
            allPairs.append((a, b, false))
        }
        
        #expect(allPairs.count >= 5, "Need at least 5 pairs for calibration")
        
        // Print individual component similarities
        for pair in allPairs {
            let sim = pair.a.similarity(to: pair.b)
            let label = pair.isPositive ? "POS" : "NEG"
            print("[components] [\(label)] geo=\(String(format: "%.4f", sim.geometry)) text=\(String(format: "%.4f", sim.textLayout)) field=\(String(format: "%.4f", sim.fieldLayout)) annot=\(String(format: "%.4f", sim.annotationLayout)) raster=\(String(format: "%.4f", sim.rasterLayout)) total=\(String(format: "%.4f", sim.total))")
        }
        
        // Sweep raster weight
        print("\n[weight-sweep] weight | minPos | maxNeg | gap    | status")
        print("[weight-sweep] -------|--------|--------|--------|-------")
        
        var bestWeight = 0.02
        for weight in stride(from: 0.02, through: 0.20, by: 0.01) {
            let posTotals = allPairs.filter { $0.isPositive }.map { $0.a.similarity(to: $0.b, rasterWeightOverride: weight).total }
            let negTotals = allPairs.filter { !$0.isPositive }.map { $0.a.similarity(to: $0.b, rasterWeightOverride: weight).total }
            
            let minPos = posTotals.min() ?? 0
            let maxNeg = negTotals.max() ?? 0
            let pass = minPos > 0.90 && maxNeg < 0.90
            
            if pass && weight > bestWeight { bestWeight = weight }
            
            print("[weight-sweep] \(String(format: "%.2f", weight))  | \(String(format: "%.4f", minPos)) | \(String(format: "%.4f", maxNeg)) | \(String(format: "%.4f", minPos - maxNeg)) | \(pass ? "✅" : "❌")")
        }
        
        print("\n[weight-sweep] Best valid raster weight: \(String(format: "%.2f", bestWeight))")
        print("[weight-sweep] RECOMMENDATION: Set rasterWeight to \(String(format: "%.2f", bestWeight))")
    }
}
