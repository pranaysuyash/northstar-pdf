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

        // The fix: V2 structured similarity must stay below the calibrated
        // family threshold (0.90, F-3 ratify — LayoutFingerprintThreshold-
        // CalibrationTests) for every cross-PDF pair.
        for i in 0..<fingerprints.count {
            for j in (i + 1)..<fingerprints.count {
                let a = fingerprints[i]
                let b = fingerprints[j]
                let similarity = a.fp.similarity(to: b.fp)
                #expect(
                    similarity.total < LayoutFingerprintV2.familyThreshold,
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
        print("\n[LayoutFingerprintV2 evidence] cross-PDF similarity matrix (family threshold \(LayoutFingerprintV2.familyThreshold)):")
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

    // MARK: - F-3: Calibrated threshold must recognize layout-identical re-encodings

    @Test("F-3: layout-identical re-encodings are recognized at the calibrated threshold")
    func f3PositiveRecognition() {
        // Same single-page document re-encoded by different producers/tools:
        // byte digests differ, but V2 must still recognize the family at the
        // ratified threshold (0.90).
        let baseURL = URL(fileURLWithPath: "\(Self.corpusRoot)/public-sample-form.pdf")
        let producerURL = URL(fileURLWithPath: "\(Self.corpusRoot)/2026-08-25-native-incremental/corpus/synthetic-producer-0.pdf")
        guard FileManager.default.fileExists(atPath: baseURL.path),
              FileManager.default.fileExists(atPath: producerURL.path),
              let base = LayoutFingerprintV2Extractor.extract(from: PDFDocument(url: baseURL)!),
              let producer = LayoutFingerprintV2Extractor.extract(from: PDFDocument(url: producerURL)!) else { return }

        let similarity = base.similarity(to: producer).total
        #expect(similarity >= LayoutFingerprintV2.familyThreshold,
                "Layout-identical re-encodings must be recognized: \(similarity) vs \(LayoutFingerprintV2.familyThreshold)")
    }

    // MARK: - F-4: Per-page alignment (replaces pooled-cell Jaccard)

    @Test("F-4: dense-text cross-doc similarity drops below the family threshold")
    func f4PerPageAlignment() {
        // F-4 (Observed, pooled-cell lane): geometry↔navigation scored
        // text=0.824 because pooling merged all pages into one cell set —
        // two dense multi-page docs share most letter-grid cells. With
        // per-page alignment, differing page content must drive the score
        // well below the calibrated family threshold.
        guard let geometryURL = sweepURL("geometry.pdf"),
              let navigationURL = sweepURL("navigation.pdf"),
              let geometryFP = LayoutFingerprintV2Extractor.extract(from: PDFDocument(url: geometryURL)!),
              let navigationFP = LayoutFingerprintV2Extractor.extract(from: PDFDocument(url: navigationURL)!) else { return }

        let similarity = geometryFP.similarity(to: navigationFP)
        // The F-4 failure was text=0.824 — aligned comparison must be far below.
        #expect(similarity.textLayout < LayoutFingerprintV2.familyThreshold,
                "F-4: aligned text similarity must stay below the family threshold, got \(similarity.textLayout)")
        #expect(similarity.total < LayoutFingerprintV2.familyThreshold,
                "F-4: aligned total must stay below the family threshold, got \(similarity.total)")
        print(String(format: "[F-4 evidence] geometry vs navigation aligned: text=%.3f total=%.3f (pooled lane was 0.824)",
                      similarity.textLayout, similarity.total))
    }

    @Test("F-4: aligned comparison keeps identical pages at 1.0 and penalizes count mismatch")
    func f4AlignmentSemantics() throws {
        // Same cells on both shared pages → 1.0; count difference applies the penalty.
        let shared = [
            LayoutFingerprintV2.PageLayout(
                pageIndex: 0, widthPoints: 612, heightPoints: 792, rotationDegrees: 0,
                textCells: [LayoutFingerprintV2.Cell(col: 0, row: 0), LayoutFingerprintV2.Cell(col: 1, row: 0), LayoutFingerprintV2.Cell(col: 0, row: 1)],
                fieldCells: [], annotationCells: []),
            LayoutFingerprintV2.PageLayout(
                pageIndex: 1, widthPoints: 612, heightPoints: 792, rotationDegrees: 0,
                textCells: [LayoutFingerprintV2.Cell(col: 5, row: 5), LayoutFingerprintV2.Cell(col: 6, row: 5)],
                fieldCells: [], annotationCells: [])
        ]
        let a = LayoutFingerprintV2(
            algorithm: "test", featureVersion: "test", cellSizePoints: 4.0,
            pages: shared, digest: "a")
        let b = LayoutFingerprintV2(
            algorithm: "test", featureVersion: "test", cellSizePoints: 4.0,
            pages: shared, digest: "b")
        #expect(abs(a.similarity(to: b).textLayout - 1.0) < 1e-9, "Identical pages align to 1.0")

        // A third page with non-matching text: pooled would dilute less,
        // aligned must apply the count penalty.
        let extraPage = LayoutFingerprintV2.PageLayout(
            pageIndex: 2, widthPoints: 612, heightPoints: 792, rotationDegrees: 0,
            textCells: [LayoutFingerprintV2.Cell(col: 100, row: 100)], fieldCells: [], annotationCells: [])
        let c = LayoutFingerprintV2(
            algorithm: "test", featureVersion: "test", cellSizePoints: 4.0,
            pages: shared + [extraPage], digest: "c")
        let alignment = a.similarity(to: c).textLayout
        #expect(abs(alignment - (1.0 * (1.0 - 1.0 / 3.0))) < 1e-9,
                "Count penalty must apply to aligned components (2v3 pages → \(alignment))")
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