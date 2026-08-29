import Foundation
import Testing
import PDFKit
import CryptoKit
@testable import PDFEditorCore

/// Layout fingerprint V2 verification against the real benchmark PDF corpus.
///
/// Encodes the two Observed findings from the calibration corpus verification
/// as regression tests:
/// - Finding 1: V1 fingerprint (first-page size + rotation + page count)
///   collides across different corpus PDFs.
/// - Finding 2: V1 family similarity (character-set Jaccard on serialized
///   strings) classifies different PDFs as `.familyMatch`.
///
/// Doctrine alignment:
/// - §5 Evidence-based — every claim verified against real PDFs.
/// - §2 Truth taxonomy — results labeled Observed (real corpus) / Verified.
/// - §12 Privacy — fingerprints contain positions and kinds only.
@Suite("Layout Fingerprint V2 — Real Corpus")
struct LayoutFingerprintV2Tests {

    private static let corpusRoot = "/Users/pranay/Projects/pdf_editor/benchmark/results"

    private static let sweepNames = [
        "plain-text.pdf", "multi-column.pdf", "geometry.pdf", "navigation.pdf"
    ]

    private func sweepURL(_ name: String) -> URL? {
        let path = "\(Self.corpusRoot)/corpus-sweep-2026-08-25/\(name)"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// The V1 fingerprint exactly as documented in the finding (page 0 only).
    private func v1Fingerprint(_ url: URL) -> String? {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        return "\(Int(bounds.width))x\(Int(bounds.height))_r\(page.rotation)_p\(document.pageCount)"
    }

    // MARK: - Finding 1: Collision

    @Test("V2 fingerprints discriminate all corpus PDFs (V1 collides)")
    func v2DiscriminatesWhereV1Collides() {
        var v1: [String] = []
        var v2: [String] = []
        for name in Self.sweepNames {
            guard let url = sweepURL(name),
                  let document = PDFDocument(url: url),
                  let fp = LayoutFingerprintV2Extractor.extract(from: document) else { continue }
            v1.append(v1Fingerprint(url) ?? "nil")
            v2.append(fp.digest)
        }
        #expect(v2.count >= 3, "Should extract from at least 3 corpus PDFs")

        let v1Unique = Set(v1).count
        let v2Unique = Set(v2).count
        // Document the V1 collision (Finding 1): fewer unique fingerprints than PDFs.
        #expect(v1Unique < v1.count, "V1 should collide on this corpus (finding)")
        // The fix: V2 must be unique per PDF.
        #expect(v2Unique == v2.count, "V2 must be unique per PDF, got \(v2Unique)/\(v2.count)")
    }

    @Test("V2 fingerprint is stable across reads")
    func v2StableAcrossReads() {
        guard let url = sweepURL("plain-text.pdf"),
              let document = PDFDocument(url: url) else { return }
        let fp1 = LayoutFingerprintV2Extractor.extract(from: document)
        let fp2 = LayoutFingerprintV2Extractor.extract(from: PDFDocument(url: url)!)
        #expect(fp1?.digest == fp2?.digest, "Fingerprint must be stable across reads")
    }

    @Test("Identical document has perfect similarity")
    func identicalSimilarity() {
        guard let url = sweepURL("geometry.pdf"),
              let document = PDFDocument(url: url),
              let fp = LayoutFingerprintV2Extractor.extract(from: document) else { return }
        let similarity = fp.similarity(to: fp)
        #expect(abs(similarity.geometry - 1.0) < 1e-9)
        #expect(abs(similarity.textLayout - 1.0) < 1e-9)
        #expect(abs(similarity.total - 1.0) < 1e-9)
    }

    // MARK: - Finding 2: Family similarity

    @Test("Cross-PDF V2 similarity stays below family threshold (V1 said familyMatch)")
    func crossPdfSimilarityBelowFamilyThreshold() {
        var fingerprints: [(name: String, fp: LayoutFingerprintV2)] = []
        for name in Self.sweepNames {
            guard let url = sweepURL(name),
                  let document = PDFDocument(url: url),
                  let fp = LayoutFingerprintV2Extractor.extract(from: document) else { continue }
            fingerprints.append((name, fp))
        }

        // V1 finding: plain-text and navigation share "612x792_r0_p3" →
        // the V1 exact-equality path classified them as knownVariant.
        let v1Plain = fingerprints.first { $0.name == "plain-text.pdf" }.map { v1Fingerprint(sweepURL($0.name)!) }
        let v1Nav = fingerprints.first { $0.name == "navigation.pdf" }.map { v1Fingerprint(sweepURL($0.name)!) }
        if let v1Plain, let v1Nav {
            #expect(v1Plain == v1Nav, "V1 fingerprints should collide (finding)")
        }

        // The fix: V2 structured similarity must stay below the family
        // threshold (0.76 well-calibrated) for every cross-PDF pair.
        for i in 0..<fingerprints.count {
            for j in (i + 1)..<fingerprints.count {
                let a = fingerprints[i]
                let b = fingerprints[j]
                let similarity = a.fp.similarity(to: b.fp)
                #expect(
                    similarity.total < 0.76,
                    "\(a.name) vs \(b.name) must stay below family threshold, got \(similarity.total)"
                )
            }
        }
    }

    @Test("Cross-PDF V2 similarity matrix (evidence report)")
    func crossPdfSimilarityMatrix() {
        var fingerprints: [(name: String, fp: LayoutFingerprintV2)] = []
        for name in Self.sweepNames {
            guard let url = sweepURL(name),
                  let document = PDFDocument(url: url),
                  let fp = LayoutFingerprintV2Extractor.extract(from: document) else { continue }
            fingerprints.append((name, fp))
        }
        print("\n[LayoutFingerprintV2 evidence] cross-PDF similarity matrix (family threshold 0.76):")
        for i in 0..<fingerprints.count {
            for j in (i + 1)..<fingerprints.count {
                let a = fingerprints[i]
                let b = fingerprints[j]
                let s = a.fp.similarity(to: b.fp)
                let an = a.name.padding(toLength: 18, withPad: " ", startingAt: 0)
                let bn = b.name.padding(toLength: 18, withPad: " ", startingAt: 0)
                print(String(format: "  %@ vs %@ geo=%.3f text=%.3f field=%.3f annot=%.3f total=%.3f",
                              an, bn, s.geometry, s.textLayout, s.fieldLayout, s.annotationLayout, s.total))
            }
        }
        print("[LayoutFingerprintV2 evidence] V1 fingerprints: "
            + Self.sweepNames.compactMap { name in
                sweepURL(name).flatMap { v1Fingerprint($0) }
            }.joined(separator: " | "))
    }

    @Test("V2 digests are content-free (positions only, never text)")
    func contentFree() {
        guard let url = sweepURL("multi-column.pdf"),
              let document = PDFDocument(url: url),
              let fp = LayoutFingerprintV2Extractor.extract(from: document) else { return }
        // The canonical serialization must not contain any document text.
        let pageText = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        for word in pageText.split(whereSeparator: \.isWhitespace).prefix(20) {
            #expect(!fp.canonical.contains(String(word)), "Fingerprint must not contain document text")
        }
    }

    // MARK: - Known-variant invariance (filled form = same template)

    @Test("Filled variant keeps the same V2 layout fingerprint")
    func filledVariantInvariance() {
        let path = "\(Self.corpusRoot)/2026-08-25-native-incremental/corpus/tagged-acroform.pdf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        guard let document = PDFDocument(url: url),
              let originalFP = LayoutFingerprintV2Extractor.extract(from: document) else { return }

        // Fill the first text widget with a value.
        var filled = false
        pageLoop: for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                guard annotation.type == "Widget",
                      annotation.widgetFieldType == .text else { continue }
                annotation.widgetStringValue = "FILLED-VALUE-2026"
                filled = true
                break pageLoop
            }
        }
        #expect(filled, "Fixture should contain a text widget")

        // Persist the filled variant to a temp file (real variant bytes).
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("filled-variant-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        guard document.write(to: tempURL),
              let variantDocument = PDFDocument(url: tempURL),
              let variantFP = LayoutFingerprintV2Extractor.extract(from: variantDocument) else { return }

        // Proven: file bytes differ (a real variant, not the same file).
        let originalData = try? Data(contentsOf: url)
        let variantData = try? Data(contentsOf: tempURL)
        let originalDigest = originalData.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
        let variantDigest = variantData.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
        #expect(originalDigest != variantDigest,
                "Filled variant must differ at the byte level")

        // The fix: layout identity survives the value change.
        #expect(variantFP.digest == originalFP.digest,
                "Filled variant must keep the same layout fingerprint")
    }
}