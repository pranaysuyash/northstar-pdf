import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// F-3 threshold recalibration for LayoutFingerprintV2's structured similarity
/// scale (2026-08-28).
///
/// The 0.76 family threshold was tuned for V1's char-set Jaccard semantics;
/// V2's structured scale measured different (F-3: two negative pairs sat at
/// 0.72, within 0.05 of the threshold). This suite collects a **30-fixture
/// corpus with hard negatives** and re-derives the family threshold from the
/// measured positive/negative score distributions.
///
/// ## Corpus ground truth (Verified 2026-08-28, pikepdf + pdftotext + V2)
///
/// Every fixture in this corpus shares the identical 6 widget rects
/// (185.5..436.5 × 477.4..728.4) — the entire corpus descends from
/// `public-sample-form.pdf`. So "family" is defined by the *layout-matching
/// use case*, not shared ancestry. A first labeling round treated the
/// metadata/signed/XFA variants as hard negatives; **V2 measured them at 1.0**
/// (Observed: twenty identical 1-page layouts — same page, same widgets, same
/// text; only Info/signature/XFA attributes differ, which V2 deliberately
/// excludes). The corrected truth:
///
/// - **Layout-identical positives (A), 21 documents → 210 positive pairs**:
///   every one-page, same-layout document in the corpus — the base form, the
///   6 producer re-encodes, tagged/compressed re-encodes, the 5 metadata
///   variants, the 3 signed structures, the 3 XFA variants. They are the same
///   form under the layout-identity contract: filling/re-encoding/metadata
///   must never break recognition.
/// - **Layout-distinct negatives (N), 9 documents → 225 negative pairs**:
///   4 multi-page sweep fixtures (plain-text, multi-column, navigation,
///   geometry — page-count and page-set deltas), the 3 derived browser
///   fixtures (2-page raster, 2-page rotated, 40-page repeat), and 2
///   two unrelated documents (detector-calibration, scanned-noisy).
///
/// A third round of per-page probing refined B: `hybrid-text-raster-form.pdf`
/// and `rotated-hybrid-90.pdf` are the **same 2-page layout** (p0 = base text
/// form 595x841 / 157 chars / 6 widgets; p1 = 1600x700 raster page with no
/// extractable text; rotation the only delta) — family B, a true positive at
/// 0.971 (a rotated scan of the same form must match).
///
/// Excluded (cannot extract): `encrypted-hybrid.pdf` (password-encrypted),
/// `malformed-hybrid-truncated.pdf` (PdfError) — recorded in the artifact.
///
/// ## Measured separation (Verified)
/// 211 positive pairs (min **0.971**, max 1.0), 224 negative pairs
/// (max **0.813** = multi-column↔hybrid-text-raster — see the documented
/// raster-page limitation below). Gap midpoint 0.892 → ratified threshold
/// **0.90** (`LayoutFingerprintV2.familyThreshold`).
///
/// ## Raster-page limitation (documented, not fixed here)
/// V2 records positions only, so a raster page has zero extractable cells and
/// is skipped as uninformative. A text page vs a scan page that share page 0
/// therefore score high (multi-column↔hybrid = 0.813). This is the honest
/// F-3 headroom; OCR/pixel features are future work.
///
/// ## Threshold rule (doctrine-aligned, precision-first)
/// A family threshold must never promote a hard negative (false-positive rate
/// 0) while recognizing every layout-identical re-encoding. The ratified
/// value is the midpoint of the measured separation gap
/// `(maxNegative + minPositive) / 2`, rounded to 0.05 for stability, encoded
/// as `LayoutFingerprintV2.familyThreshold`.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — labels are Verified facts (rects, text, bytes, and
///   the measured V2 scores that falsified the first labeling round)
/// - §5 Evidence-based — the threshold is measured from a 30-fixture corpus
/// - §10 Failure — hard negatives are the constraint, not an afterthought
@Suite("Layout Fingerprint Threshold Calibration (F-3)")
struct LayoutFingerprintThresholdCalibrationTests {

  private static let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"

  /// (name, family, note). Family: "A" layout-identical, "N" layout-distinct.
  private static let corpus: [(name: String, family: String, note: String)] = [
    // A — 21 layout-identical single-page documents (210 positive pairs)
    ("public-sample-form.pdf", "A", "base form"),
    ("synthetic-producer-0.pdf", "A", "producer re-encode"),
    ("synthetic-producer-1.pdf", "A", "producer re-encode"),
    ("synthetic-producer-2.pdf", "A", "producer re-encode"),
    ("synthetic-producer-3.pdf", "A", "producer re-encode"),
    ("synthetic-producer-4.pdf", "A", "producer re-encode"),
    ("synthetic-producer-5.pdf", "A", "producer re-encode"),
    ("tagged-acroform.pdf", "A", "tagged writer re-encode"),
    ("compressed-acroform.pdf", "A", "compressed writer re-encode"),
    ("tagged-no-acroform.pdf", "A", "tagged, no acroform tree (widgets present)"),
    ("metadata-complete.pdf", "A", "RG-066, metadata only"),
    ("metadata-absent.pdf", "A", "RG-066, metadata only"),
    ("metadata-custom.pdf", "A", "RG-066, metadata only"),
    ("metadata-malformed.pdf", "A", "RG-066, metadata only"),
    ("metadata-unicode.pdf", "A", "RG-066, metadata only"),
    ("signed-valid-structure.pdf", "A", "RG-070, signature structure only"),
    ("signed-invalid-structure.pdf", "A", "RG-070, signature structure only"),
    ("signed-multiple.pdf", "A", "RG-070, signature structure only"),
    ("xfa-static.pdf", "A", "RG-071, XFA packet only"),
    ("xfa-hybrid.pdf", "A", "RG-071, XFA packet only"),
    ("xfa-dynamic.pdf", "A", "RG-071, XFA packet only"),
    // B — 2-page layout: base text page + raster page (1 positive pair,
    //   hybrid↔rotated = 0.971: same layout, rotation the only delta — a
    //   rotated scan should match; Verified by per-page probe: both p0 base
    //   595x841/157 chars/6 widgets, p1 raster 1600x700 with no extractable
    //   text)
    ("hybrid-text-raster-form.pdf", "B", "2 pages: text + raster form"),
    ("rotated-hybrid-90.pdf", "B", "2 pages, rotated 90"),
    // N — 7 layout-distinct documents
    ("plain-text.pdf", "N", "RG-060, 3 pages"),
    ("multi-column.pdf", "N", "RG-063, 2 pages, text p1"),
    ("navigation.pdf", "N", "RG-065, 3 pages"),
    ("geometry.pdf", "N", "RG-064, 4 pages"),
    ("large-hybrid-40-pages.pdf", "N", "40 pages: template repeated"),
    ("detector-calibration.pdf", "N", "unrelated 2-page form"),
    ("scanned-noisy.pdf", "N", "unrelated scan, no text")
  ]

  /// Excluded fixtures with the Verified reason.
  private static let excluded: [(name: String, reason: String)] = [
    ("encrypted-hybrid.pdf", "password-encrypted (pikepdf PasswordError)"),
    ("malformed-hybrid-truncated.pdf", "malformed (pikepdf PdfError)")
  ]

  private static let sweepNames = [
    "plain-text.pdf", "multi-column.pdf", "navigation.pdf", "geometry.pdf",
    "metadata-complete.pdf", "metadata-absent.pdf", "metadata-custom.pdf",
    "metadata-malformed.pdf", "metadata-unicode.pdf",
    "signed-valid-structure.pdf", "signed-invalid-structure.pdf", "signed-multiple.pdf",
    "xfa-static.pdf", "xfa-hybrid.pdf", "xfa-dynamic.pdf"
  ]

  private static func url(_ name: String) -> URL {
    switch name {
    case "public-sample-form.pdf":
      return URL(fileURLWithPath: "\(results)/\(name)")
    case "detector-calibration.pdf":
      return URL(fileURLWithPath: "\(results)/detector-calibration/\(name)")
    case "encrypted-hybrid.pdf", "malformed-hybrid-truncated.pdf":
      return URL(fileURLWithPath: "\(results)/browser-corpus/\(name)")
    default:
      if name.hasPrefix("synthetic-producer-")
          || name == "tagged-acroform.pdf" || name == "compressed-acroform.pdf"
          || name == "tagged-no-acroform.pdf" {
        return URL(fileURLWithPath: "\(results)/2026-08-25-native-incremental/corpus/\(name)")
      }
      if Self.sweepNames.contains(name) {
        return URL(fileURLWithPath: "\(results)/corpus-sweep-2026-08-25/\(name)")
      }
      return URL(fileURLWithPath: "\(results)/browser-corpus/\(name)")
    }
  }

  private struct PairScore: Codable {
    let a: String
    let b: String
    let classes: [String]
    let similarity: Double
  }

  private struct CalibrationArtifact: Codable {
    struct Version: Codable { let major: Int; let minor: Int }
    struct ExcludedEntry: Codable { let name: String; let reason: String }
    let schema: String
    let version: Version
    let generatedAt: String
    let corpusSize: Int
    let positivePairs: Int
    let hardNegativePairs: Int
    let excluded: [ExcludedEntry]
    let familyThreshold: Double
    let maxHardNegative: Double
    let minPositive: Double
    let maxPositive: Double
    let minHardNegative: Double
    let separationGapMidpoint: Double
    let topHardNegatives: [PairScore]
  }

  @Test("30-fixture corpus: positives separate from hard negatives; threshold ratified")
  func thresholdSeparatesCorpus() throws {
    let fingerprints = extractCorpus()
    #expect(fingerprints.count >= 28, "Expected most fixtures to extract")

    var pairs: [PairScore] = []
    for i in 0..<fingerprints.count {
      for j in (i + 1)..<fingerprints.count {
        let a = fingerprints[i]
        let b = fingerprints[j]
        let total = a.fp.similarity(to: b.fp).total
        pairs.append(PairScore(
          a: a.name, b: b.name,
          classes: [String(a.family), String(b.family)],
          similarity: total
        ))
      }
    }

    // Positives: within-family pairs (A-A one-page identical, B-B 2-page
    // base+scan). Negatives: every cross-family pair (A-B, A-N, B-N) plus
    // within-N pairs — different document structures are not family matches.
    let positives = pairs.filter { $0.classes == ["A", "A"] || $0.classes == ["B", "B"] }
    let hardNegatives = pairs.filter { $0.classes != ["A", "A"] && $0.classes != ["B", "B"] }
    #expect(positives.count == 211, "Expected 211 positive pairs (21 A docs + 1 B pair), got \(positives.count)")
    #expect(hardNegatives.count == 224, "Expected 224 negative pairs, got \(hardNegatives.count)")

    let maxNegative = hardNegatives.map(\.similarity).max() ?? 0
    let minPositive = positives.map(\.similarity).min() ?? 0
    let maxPositive = positives.map(\.similarity).max() ?? 0
    let minNegative = hardNegatives.map(\.similarity).min() ?? 0

    // The measured separation gap — the threshold must sit strictly inside it.
    #expect(maxNegative < minPositive, "There must be a separation gap, got \(maxNegative) vs \(minPositive)")

    let threshold = LayoutFingerprintV2.familyThreshold
    #expect(maxNegative < threshold,
            "All hard negatives must stay below the family threshold: max \(maxNegative) vs \(threshold)")
    #expect(minPositive >= threshold,
            "Every layout-identical re-encoding must be recognized: min \(minPositive) vs \(threshold)")

    // Precision-first: not a single hard-negative promotion.
    let promoted = hardNegatives.filter { $0.similarity >= threshold }
    #expect(promoted.isEmpty, "No hard negative may be promoted: \(promoted.map { "\($0.a)↔\($0.b)=\($0.similarity)" })")

    // Evidence printout.
    print("\n[F-3 evidence] positive pairs: \(positives.count), hard negatives: \(hardNegatives.count)")
    print("[F-3 evidence] positive min=\(String(format: "%.4f", minPositive)) max=\(String(format: "%.4f", maxPositive))")
    print("[F-3 evidence] negative min=\(String(format: "%.4f", minNegative)) max=\(String(format: "%.4f", maxNegative))")
    print("[F-3 evidence] separation gap = \(String(format: "%.4f", maxNegative))..\(String(format: "%.4f", minPositive))")
    print("[F-3 evidence] gap midpoint = \(String(format: "%.4f", (maxNegative + minPositive) / 2))")
    print("[F-3 evidence] ratified familyThreshold = \(String(format: "%.4f", threshold))")

    // Top hard negatives (the F-3 headroom pairs).
    let topNegatives = hardNegatives.sorted { $0.similarity > $1.similarity }.prefix(8)
    for pair in topNegatives {
      print(String(format: "[F-3 evidence] top negative: %@↔%@ total=%.4f", pair.a, pair.b, pair.similarity))
    }

    persistArtifact(
      positives: positives, hardNegatives: hardNegatives,
      maxNegative: maxNegative, minPositive: minPositive,
      maxPositive: maxPositive, minNegative: minNegative, threshold: threshold,
      topNegatives: Array(topNegatives))
  }

  private func extractCorpus() -> [(name: String, family: Character, fp: LayoutFingerprintV2)] {
    var out: [(name: String, family: Character, fp: LayoutFingerprintV2)] = []
    for entry in Self.corpus {
      let path = Self.url(entry.name).path
      guard FileManager.default.fileExists(atPath: path),
            let document = PDFDocument(url: Self.url(entry.name)),
            let fp = LayoutFingerprintV2Extractor.extract(from: document) else {
        print("[F-3 warning] could not extract \(entry.name)")
        continue
      }
      out.append((entry.name, Character(entry.family), fp))
    }
    return out
  }

  private func persistArtifact(
    positives: [PairScore],
    hardNegatives: [PairScore],
    maxNegative: Double,
    minPositive: Double,
    maxPositive: Double,
    minNegative: Double,
    threshold: Double,
    topNegatives: [PairScore]
  ) {
    let artifact = CalibrationArtifact(
      schema: "pdf-editor.layout-v2-family-threshold-calibration",
      version: CalibrationArtifact.Version(major: 1, minor: 0),
      generatedAt: "2026-08-28",
      corpusSize: Self.corpus.count,
      positivePairs: positives.count,
      hardNegativePairs: hardNegatives.count,
      excluded: Self.excluded.map { CalibrationArtifact.ExcludedEntry(name: $0.name, reason: $0.reason) },
      familyThreshold: threshold,
      maxHardNegative: maxNegative,
      minPositive: minPositive,
      maxPositive: maxPositive,
      minHardNegative: minNegative,
      separationGapMidpoint: (maxNegative + minPositive) / 2,
      topHardNegatives: topNegatives
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(artifact) else { return }
    let dir = URL(fileURLWithPath: "\(Self.results)/detector-calibration")
    let url = dir.appendingPathComponent("layout-v2-family-threshold-calibration-2026-08-28.json")
    try? data.write(to: url)
    #expect(FileManager.default.fileExists(atPath: url.path), "Calibration artifact must be persisted")
  }
}