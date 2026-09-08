import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Blend-sweep calibration gate (2026-09-08) — permanent, fail-closed.
///
/// Codifies the 85/8/7 projection/edge/occupancy blend result that the
/// multi-scale graded-occupancy plan targeted (docs/audits/
/// blend-sweep-binding-constraint-analysis-2026-09-03.md: the 85/8/7 row
/// FAILED at 0.8935 under cell-level binary extraction). This gate proves
/// the plan's completion on the same 56-fixture corpus the F-3 gate uses.
///
/// Two structural fixes made the row pass (both measured, both doctrine-
/// aligned, neither is a weight tweak):
///
/// 1. **Multi-scale graded occupancy** (ContentInvariantRasterExtractor.
///    gradedScales = [16pt, 64pt] on a 0.5-scale render): coverage is now
///    genuinely fractional (~64–1024 samples/cell vs the degenerate 1
///    sample at 4pt/0.15-scale). Cosine similarity keyed by
///    (scale, col, row).
/// 2. **Cell-level channels skip raster-only pages** (LayoutFingerprintV2
///    extraction): a page with no extractable text/field/annotation
///    structure emits no edge/occupancy/graded cells — its pixels are
///    image content, the projection channel's job. Comparing render noise
///    across producers dragged every rotated-raster pair down (Observed:
///    B pair 0.971 → 0.8884 before this).
/// 3. **Rotation-aware geometry**: a 90°-rotated page is the same layout
///    (F-3 doctrine: "a rotated scan of the same form must match"); the
///    rotation penalty measures only the non-axis-aligned residual.
///
/// Gate semantics mirror the F-3 precision-first rule:
/// - every blend row must have zero evidence-bearing hard-negative
///   promotions (raw ≥ threshold WITH structured content on either side)
/// - the shipped blend (95/3/2) and the target blend (85/8/7) must
///   recognize every layout-identical positive (minPositive ≥ 0.90)
///
/// Doctrine: §5 Evidence-based (measured on the corpus, not asserted),
/// §10 Failure (precision constraint encoded, not just recall).
@Suite("Raster Blend Calibration Gate (85/8/7)")
struct RasterBlendCalibrationGateTests {

  private static let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"

  /// The 56-fixture F-3 corpus (same families: A layout-identical,
  /// B 2-page text+raster, N layout-distinct). Mirrors
  /// LayoutFingerprintThresholdCalibrationTests.corpus — keep in sync.
  private static let corpus: [(name: String, family: String)] = [
    ("public-sample-form.pdf", "A"), ("synthetic-producer-0.pdf", "A"),
    ("synthetic-producer-1.pdf", "A"), ("synthetic-producer-2.pdf", "A"),
    ("synthetic-producer-3.pdf", "A"), ("synthetic-producer-4.pdf", "A"),
    ("synthetic-producer-5.pdf", "A"), ("tagged-acroform.pdf", "A"),
    ("compressed-acroform.pdf", "A"), ("tagged-no-acroform.pdf", "A"),
    ("metadata-complete.pdf", "A"), ("metadata-absent.pdf", "A"),
    ("metadata-custom.pdf", "A"), ("metadata-malformed.pdf", "A"),
    ("metadata-unicode.pdf", "A"), ("signed-valid-structure.pdf", "A"),
    ("signed-invalid-structure.pdf", "A"), ("signed-multiple.pdf", "A"),
    ("xfa-static.pdf", "A"), ("xfa-hybrid.pdf", "A"), ("xfa-dynamic.pdf", "A"),
    ("hybrid-text-raster-form.pdf", "B"), ("rotated-hybrid-90.pdf", "B"),
    ("plain-text.pdf", "N"), ("multi-column.pdf", "N"), ("navigation.pdf", "N"),
    ("geometry.pdf", "N"), ("large-hybrid-40-pages.pdf", "N"),
    ("detector-calibration.pdf", "N"), ("scanned-noisy.pdf", "N"),
    ("diverse-single-column.pdf", "N"), ("diverse-single-column-variant.pdf", "N"),
    ("diverse-two-column.pdf", "N"), ("diverse-two-column-square.pdf", "N"),
    ("diverse-three-column.pdf", "N"), ("diverse-form-layout.pdf", "N"),
    ("diverse-table-grid.pdf", "N"), ("diverse-graphics-heavy.pdf", "N"),
    ("diverse-sparse-text.pdf", "N"), ("diverse-dense-grid.pdf", "N"),
    ("diverse-header-footer.pdf", "N"), ("diverse-landscape-chart.pdf", "N"),
    ("diverse-scanned-sim.pdf", "N"), ("diverse-mixed-3page.pdf", "N"),
    ("ocr-clean-english.pdf", "N"), ("ocr-dense-paragraph.pdf", "N"),
    ("ocr-low-contrast.pdf", "N"), ("ocr-mixed-punctuation.pdf", "N"),
    ("ocr-noisy-invoice.pdf", "N"), ("ocr-printed-scan.pdf", "N"),
    ("ocr-small-font.pdf", "N"), ("rotated-form6-mixed.pdf", "N"),
    ("rotated-widget-90.pdf", "N"), ("repeated-20-pages.pdf", "N"),
    ("handwritten-simulated.pdf", "N"), ("pdfkit-widgets.pdf", "N"),
  ]

  private static func url(_ name: String) -> URL {
    switch name {
    case "public-sample-form.pdf":
      return URL(fileURLWithPath: "\(results)/\(name)")
    case "detector-calibration.pdf":
      return URL(fileURLWithPath: "\(results)/detector-calibration/\(name)")
    default:
      if name.hasPrefix("synthetic-producer-")
          || name == "tagged-acroform.pdf" || name == "compressed-acroform.pdf"
          || name == "tagged-no-acroform.pdf" {
        return URL(fileURLWithPath: "\(results)/2026-08-25-native-incremental/corpus/\(name)")
      }
      if ["plain-text.pdf", "multi-column.pdf", "navigation.pdf", "geometry.pdf",
          "metadata-complete.pdf", "metadata-absent.pdf", "metadata-custom.pdf",
          "metadata-malformed.pdf", "metadata-unicode.pdf", "signed-valid-structure.pdf",
          "signed-invalid-structure.pdf", "signed-multiple.pdf", "xfa-static.pdf",
          "xfa-hybrid.pdf", "xfa-dynamic.pdf"].contains(name) {
        return URL(fileURLWithPath: "\(results)/corpus-sweep-2026-08-25/\(name)")
      }
      if name.hasPrefix("diverse-") {
        return URL(fileURLWithPath: "\(results)/diverse-layout-corpus/\(name)")
      }
      if name.hasPrefix("ocr-") {
        return URL(fileURLWithPath: "\(results)/ocr-corpus/\(String(name.dropFirst(4)))")
      }
      if name == "rotated-form6-mixed.pdf" || name == "rotated-widget-90.pdf" {
        return URL(fileURLWithPath: "\(results)/rotation-corpus/\(name)")
      }
      if name == "repeated-20-pages.pdf" {
        return URL(fileURLWithPath: "\(results)/security-corpus/\(name)")
      }
      if name == "handwritten-simulated.pdf" {
        return URL(fileURLWithPath: "\(results)/governed-corpus/handwritten-simulated-entries.pdf")
      }
      if name == "pdfkit-widgets.pdf" {
        return URL(fileURLWithPath: "\(results)/2026-08-23-pdfkit-widgets/noop.pdf")
      }
      return URL(fileURLWithPath: "\(results)/browser-corpus/\(name)")
    }
  }

  /// The blends the gate pins. 95/3/2 is shipped; 85/8/7 is the plan's
  /// target (higher edge/occupancy share = more content sensitivity once
  /// extraction is structurally sound). Both must hold the precision-first
  /// separation.
  private static let gatedBlends: [(label: String, p: Double, e: Double, o: Double)] = [
    ("95/3/2 shipped", 0.95, 0.03, 0.02),
    ("85/8/7 target", 0.85, 0.08, 0.07),
  ]

  @Test("85/8/7 blend: positives separate from hard negatives at both gated blends")
  func blendSeparatesCorpus() throws {
    var fps: [(name: String, family: String, fp: LayoutFingerprintV2)] = []
    for entry in Self.corpus {
      let path = Self.url(entry.name).path
      guard FileManager.default.fileExists(atPath: path),
            let doc = PDFDocument(url: Self.url(entry.name)),
            let fp = LayoutFingerprintV2Extractor.extract(from: doc) else {
        print("[blend-gate] could not extract \(entry.name)")
        continue
      }
      fps.append((entry.name, entry.family, fp))
    }
    #expect(fps.count >= 50, "Expected most of the 56-fixture corpus to extract, got \(fps.count)")

    let threshold = LayoutFingerprintV2.familyThreshold

    for blend in Self.gatedBlends {
      var minPositive = 1.0
      var worstPositive = ""
      var evidencePromotions: [String] = []
      var abstentions = 0

      for i in 0..<fps.count {
        for j in (i + 1)..<fps.count {
          let a = fps[i], b = fps[j]
          let isPositive = (a.family == "A" && b.family == "A")
              || (a.family == "B" && b.family == "B")
          let result = a.fp.similarity(
            to: b.fp,
            rasterBlendOverride: (projection: blend.p, edge: blend.e, occupancy: blend.o))
          let sim = result.total
          if isPositive {
            if sim < minPositive {
              minPositive = sim
              worstPositive = "\(a.name)↔\(b.name)"
            }
          } else if sim >= threshold {
            // Evidence floor (RG-138): a high raw score with no structured
            // content on either side is an abstention, not a promotion.
            let structured = result.coverage.hasStructuredContent
            if structured {
              evidencePromotions.append("\(a.name)↔\(b.name)=\(String(format: "%.4f", sim))")
            } else {
              abstentions += 1
            }
          }
        }
      }

      print("[blend-gate] \(blend.label): minPos=\(String(format: "%.4f", minPositive)) ev-promotions=\(evidencePromotions.count) abstentions=\(abstentions)")
      #expect(evidencePromotions.isEmpty,
              "\(blend.label): evidence-bearing hard negative promoted: \(evidencePromotions.prefix(4))")
      #expect(minPositive >= threshold,
              "\(blend.label): layout-identical positive not recognized: worst \(worstPositive)=\(String(format: "%.4f", minPositive)) vs \(threshold)")
    }
  }

  /// Structural invariants that make the blend meaningful — fail loudly if
  /// extraction regresses to the degenerate pre-multi-scale state.
  @Test("graded occupancy is genuinely fractional (not binary in disguise)")
  func gradedOccupancyIsFractional() throws {
    guard let doc = PDFDocument(url: Self.url("public-sample-form.pdf")),
          let fp = LayoutFingerprintV2Extractor.extract(from: doc) else {
      Issue.record("base form must extract")
      return
    }
    let coverages = fp.pages.flatMap(\.gradedOccupancyCells).map(\.coverage)
    #expect(!coverages.isEmpty, "base form must emit graded cells")
    let distinct = Set(coverages.map { ($0 * 1000).rounded() / 1000 })
    #expect(distinct.count >= 20,
            "coverage must be fractional across cells, got \(distinct.count) distinct values")
    // Degenerate 0/1 cells must be a small minority (boundary pixels only).
    let degenerate = coverages.filter { $0 == 0 || $0 == 1 }.count
    #expect(Double(degenerate) / Double(coverages.count) < 0.10,
            "degenerate 0/1 coverage cells must stay under 10%, got \(degenerate)/\(coverages.count)")
    // Scales: only 16pt and 64pt cells (the degenerate 4pt scale is dropped).
    let scales = Set(fp.pages.flatMap(\.gradedOccupancyCells).map(\.scale))
    #expect(scales == Set([16.0, 64.0]), "graded scales must be {16, 64}, got \(scales)")
  }

  /// Raster-only pages emit no cell-level channel data (the F-3 doctrine:
  /// skipped as uninformative; projection handles raster pages).
  @Test("raster-only pages emit no edge/occupancy/graded cells")
  func rasterOnlyPagesAreSkipped() throws {
    let base = "\(Self.results)/browser-corpus"
    guard let doc = PDFDocument(url: URL(fileURLWithPath: "\(base)/hybrid-text-raster-form.pdf")),
          let fp = LayoutFingerprintV2Extractor.extract(from: doc) else {
      Issue.record("hybrid fixture must extract")
      return
    }
    let rasterPage = fp.pages.first { $0.textCells.isEmpty && $0.fieldCells.isEmpty }
    #expect(rasterPage != nil, "fixture must contain a raster-only page")
    if let p = rasterPage {
      #expect(p.edgeCells.isEmpty, "raster-only page must not emit edge cells")
      #expect(p.occupancyCells.isEmpty, "raster-only page must not emit occupancy cells")
      #expect(p.gradedOccupancyCells.isEmpty, "raster-only page must not emit graded cells")
      #expect(!p.rasterCells.isEmpty, "raster-only page must still feed the projection channel")
    }
  }

  /// Rotation-aware geometry: a 90°-rotated layout is the same layout.
  @Test("90-degree rotation is not penalized in geometry")
  func rotationIsAxisAligned() throws {
    let base = "\(Self.results)/browser-corpus"
    guard let aDoc = PDFDocument(url: URL(fileURLWithPath: "\(base)/hybrid-text-raster-form.pdf")),
          let bDoc = PDFDocument(url: URL(fileURLWithPath: "\(base)/rotated-hybrid-90.pdf")),
          let a = LayoutFingerprintV2Extractor.extract(from: aDoc),
          let b = LayoutFingerprintV2Extractor.extract(from: bDoc) else {
      Issue.record("B pair must extract")
      return
    }
    let sim = a.similarity(to: b)
    #expect(sim.geometry >= 0.95,
            "rotated pair geometry must be ≥0.95 (axis-aligned), got \(String(format: "%.4f", sim.geometry))")
    #expect(sim.total >= LayoutFingerprintV2.familyThreshold,
            "rotated scan of the same form must be recognized at the default blend, got \(String(format: "%.4f", sim.total))")
  }
}