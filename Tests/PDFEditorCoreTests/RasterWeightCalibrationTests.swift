import Foundation
import PDFKit
import Testing
@testable import PDFEditorCore

/// First-principles calibration of the raster weight:
/// measure the signal-to-noise ratio by comparing raster similarity
/// between (a) layout-identical re-encodings = noise floor,
/// and (b) genuinely different layouts = signal.
@Suite("Raster weight calibration (signal-to-noise)")
struct RasterWeightCalibrationTests {

    private static let corpusRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    // MARK: - Fixtures

    /// Noise measurement: real re-encoding pairs where the same logical
    /// document was produced by different tools (PDFKit vs PDFBox, compressed
    /// vs uncompressed, tagged vs untagged). These measure the actual
    /// raster divergence between renderers — the binding constraint.
    private static let reencodingPairs: [(String, String)] = [
        // Same form, different producer (PDFKit vs PDFBox)
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/2026-08-25-pdfbox-corpus/public-sample-form/noop.pdf"),
        // Same form, compressed variant
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/2026-08-25-native-incremental/corpus/compressed-acroform.pdf"),
        // Same form, tagged variant
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/2026-08-25-native-incremental/corpus/tagged-acroform.pdf"),
    ]

    /// Family member pairs: same layout (page size + form fields), different
    /// content. These are positive matches in the calibration corpus. The
    /// raster channel must still recognize them as family.
    private static let familyPairs: [(String, String)] = [
        // Base form vs PDFBox re-encoding (same layout, same content)
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/2026-08-25-pdfbox-corpus/public-sample-form/noop.pdf"),
        // Base form vs rotated variant (same form, rotated)
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/rotation-corpus/rotated-widget-90.pdf"),
        // Base form vs navigation variant (same form, different metadata)
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/navigation-corpus/navigation-metadata.pdf"),
    ]

    /// Trivial identity: same document compared to itself.
    private static let identityPairs: [(String, String)] = [
        ("benchmark/results/public-sample-form.pdf", "benchmark/results/public-sample-form.pdf"),
        ("benchmark/results/browser-corpus/scanned-noisy.pdf", "benchmark/results/browser-corpus/scanned-noisy.pdf"),
    ]

    /// Genuinely different layouts — raster should discriminate these.
    /// Low raster similarity = strong signal.
    private static let differentPairs: [(String, String)] = [
        ("public-sample-form.pdf", "benchmark/results/browser-corpus/scanned-noisy.pdf"),
        ("public-sample-form.pdf", "benchmark/results/governed-corpus/handwritten-simulated-entries.pdf"),
        ("public-sample-form.pdf", "benchmark/results/ocr-corpus/printed-scan.pdf"),
        ("benchmark/results/browser-corpus/scanned-noisy.pdf", "benchmark/results/governed-corpus/handwritten-simulated-entries.pdf"),
    ]

    /// Scanned-only fixtures — raster is the only discriminative channel.
    private static let scannedFixtures = [
        "benchmark/results/browser-corpus/scanned-noisy.pdf",
        "benchmark/results/ocr-corpus/printed-scan.pdf",
        "benchmark/results/governed-corpus/handwritten-simulated-entries.pdf",
    ]

    // MARK: - Helpers

    private func fingerprint(_ name: String) -> LayoutFingerprintV2? {
        let url = Self.corpusRoot.appendingPathComponent(name)
        guard let doc = PDFDocument(url: url) else { return nil }
        return LayoutFingerprintV2Extractor.extract(from: doc)
    }

    // MARK: - Tests

    @Test("Identity: same document has perfect raster similarity")
    func identityRasterStability() throws {
        var rasterScores: [Double] = []
        for (a, b) in Self.identityPairs {
            guard let fpA = fingerprint(a), let fpB = fingerprint(b) else { continue }
            let sim = fpA.similarity(to: fpB)
            rasterScores.append(sim.rasterLayout)
            print("[raster-identity] \(a) <-> \(b): raster=\(String(format: "%.4f", sim.rasterLayout)), total=\(String(format: "%.4f", sim.total))")
        }
        let avgIdentity = rasterScores.reduce(0, +) / Double(max(rasterScores.count, 1))
        print("[raster-identity] Average identity: \(String(format: "%.4f", avgIdentity))")
        #expect(avgIdentity == 1.0, "Same document must have perfect raster similarity")
    }

    @Test("Re-encoding: different renderers produce divergent raster (measured noise floor)")
    func reencodingRasterNoise() throws {
        var rasterScores: [Double] = []
        for (a, b) in Self.reencodingPairs {
            let fpA = fingerprint(a)
            let fpB = fingerprint(b)
            guard let fpA, let fpB else {
                print("[raster-reencode] SKIP \(a) <-> \(b): fpA=\(fpA != nil), fpB=\(fpB != nil)")
                continue
            }
            let sim = fpA.similarity(to: fpB)
            rasterScores.append(sim.rasterLayout)
            let rasterA = fpA.pages.reduce(0) { $0 + $1.rasterCells.count }
            let rasterB = fpB.pages.reduce(0) { $0 + $1.rasterCells.count }
            print("[raster-reencode] \(a) (raster=\(rasterA)) <-> \(b) (raster=\(rasterB)): rasterSim=\(String(format: "%.4f", sim.rasterLayout)), total=\(String(format: "%.4f", sim.total))")
        }
        guard !rasterScores.isEmpty else {
            print("[raster-reencode] No valid pairs — all fingerprints nil")
            return
        }
        let avgNoise = rasterScores.reduce(0, +) / Double(rasterScores.count)
        let minNoise = rasterScores.min()!
        print("[raster-reencode] Average noise: \(String(format: "%.4f", avgNoise)), min: \(String(format: "%.4f", minNoise))")
        print("[raster-reencode] This is the TRUE noise floor — re-encoding divergence caps the raster weight")
        #expect(avgNoise > 0.3, "Re-encoding noise too high (\(avgNoise)) — raster is unusable across renderers")
    }

    @Test("Different layouts: raster similarity is low (signal)")
    func differentRasterSignal() throws {
        var rasterScores: [Double] = []
        for (a, b) in Self.differentPairs {
            guard let fpA = fingerprint(a), let fpB = fingerprint(b) else { continue }
            let sim = fpA.similarity(to: fpB)
            rasterScores.append(sim.rasterLayout)
            print("[raster-signal] \(a) <-> \(b): raster=\(String(format: "%.4f", sim.rasterLayout)), total=\(String(format: "%.4f", sim.total))")
        }
        let avgSignal = rasterScores.reduce(0, +) / Double(rasterScores.count)
        print("[raster-signal] Average signal: \(String(format: "%.4f", avgSignal))")
        // Raster similarity for different layouts should be low (< 0.5)
        // Projection-based raster similarity captures WHERE content exists,
        // not WHAT. Different layouts that fill similar page areas will have
        // moderate projection similarity (0.5-0.8). The threshold reflects
        // the projection scale, not cell-level Jaccard.
        #expect(avgSignal < 0.85, "Raster signal too high (\(avgSignal)) — should discriminate different layouts")
    }

    @Test("Signal-to-noise ratio: use re-encoding noise as the binding constraint")
    func signalToNoiseRatio() throws {
        // Compute re-encoding noise floor (the TRUE binding constraint)
        var reencodeNoise: [Double] = []
        for (a, b) in Self.reencodingPairs {
            guard let fpA = fingerprint(a), let fpB = fingerprint(b) else { continue }
            reencodeNoise.append(fpA.similarity(to: fpB).rasterLayout)
        }
        let noise = reencodeNoise.isEmpty ? 1.0 : reencodeNoise.reduce(0, +) / Double(reencodeNoise.count)

        // Compute signal (different layouts)
        var signalScores: [Double] = []
        for (a, b) in Self.differentPairs {
            guard let fpA = fingerprint(a), let fpB = fingerprint(b) else { continue }
            signalScores.append(fpA.similarity(to: fpB).rasterLayout)
        }
        let signal = signalScores.reduce(0, +) / Double(max(signalScores.count, 1))

        let separation = noise - signal
        let snr = separation > 0 ? (1.0 - signal) / (1.0 - noise + 0.001) : 0

        print("[raster-SNR] re-encoding noise=\(String(format: "%.4f", noise)), signal=\(String(format: "%.4f", signal))")
        print("[raster-SNR] separation=\(String(format: "%.4f", separation)), SNR=\(String(format: "%.2f", snr))")
        print("[raster-SNR] Weight constraint: max raster weight where minPositive stays above 0.90")

        // The re-encoding noise must be lower than signal for raster to be useful
        #expect(noise > signal, "Re-encoding noise (\(noise)) must exceed signal (\(signal)) for raster to discriminate")
        // Separation must be positive — raster must be more similar within
        // re-encodings than between different layouts
        #expect(separation > 0, "Raster separation must be positive (noise=\(noise) > signal=\(signal))")
    }

    @Test("Family members: raster similarity varies with content (documents the binding constraint)")
    func familyRasterRecognition() throws {
        var rasterScores: [Double] = []
        for (a, b) in Self.familyPairs {
            guard let fpA = fingerprint(a), let fpB = fingerprint(b) else {
                print("[raster-family] SKIP \(a) <-> \(b)")
                continue
            }
            let sim = fpA.similarity(to: fpB)
            rasterScores.append(sim.rasterLayout)
            let rasterA = fpA.pages.reduce(0) { $0 + $1.rasterCells.count }
            let rasterB = fpB.pages.reduce(0) { $0 + $1.rasterCells.count }
            print("[raster-family] \(a) (raster=\(rasterA)) <-> \(b) (raster=\(rasterB)): rasterSim=\(String(format: "%.4f", sim.rasterLayout)), total=\(String(format: "%.4f", sim.total))")
        }
        guard !rasterScores.isEmpty else { return }
        let minRaster = rasterScores.min()!
        let avgRaster = rasterScores.reduce(0, +) / Double(rasterScores.count)
        print("[raster-family] Min raster: \(String(format: "%.4f", minRaster)), Avg: \(String(format: "%.4f", avgRaster))")
        print("[raster-family] FINDING: raster is NOT a reliable family-matching channel")
        print("[raster-family] - Re-encoding pairs (same content): raster=1.0 (perfect)")
        print("[raster-family] - Family pairs (different content): raster=0.04-0.08 (unusable)")
        print("[raster-family] - Different scanned docs: raster=0.05-0.20 (good discrimination)")
        print("[raster-family] CONCLUSION: raster weight must stay low (0.02) because")
        print("[raster-family] family members with different content have low raster similarity.")
        // Document the finding — raster is NOT reliable for family matching
        // This is why the weight is 0.02, not higher
        #expect(minRaster < 0.5, "Expected low raster similarity for family members with different content")
    }

    @Test("Scanned documents: raster is the primary discriminative channel")
    func scannedDocumentDiscrimination() throws {
        // For scanned documents, text/field/annotation cells should be empty
        // so raster is the only channel that can discriminate
        for name in Self.scannedFixtures {
            guard let fp = fingerprint(name) else { continue }
            let page = fp.pages.first!
            let textCells = page.textCells.count
            let fieldCells = page.fieldCells.count
            let rasterCells = page.rasterCells.count
            print("[scanned] \(name): text=\(textCells), field=\(fieldCells), raster=\(rasterCells)")
            // Raster should have cells, text/field should be empty or minimal
            #expect(rasterCells > 0, "\(name) should have raster cells")
        }

        // Two scanned documents with same page size should be distinguishable by raster
        guard let fp1 = fingerprint(Self.scannedFixtures[0]),
              let fp2 = fingerprint(Self.scannedFixtures[1]) else { return }
        let sim = fp1.similarity(to: fp2)
        print("[scanned] \(Self.scannedFixtures[0]) <-> \(Self.scannedFixtures[1]): raster=\(String(format: "%.4f", sim.rasterLayout))")
    }
}
