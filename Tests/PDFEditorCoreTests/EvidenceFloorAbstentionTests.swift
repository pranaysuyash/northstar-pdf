import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// RG-138 (2026-09-03): evidence-floor abstention for recurring-form matching.
///
/// Root cause (Observed): six graphics-heavy hard-negative pairs score >= the
/// 0.90 family threshold purely on geometry + raster ink. Both documents are
/// silent on every structured-content channel (no extractable text, fields,
/// annotations, or regions), so the only evidence is "same page size, similar
/// ink density" — which is NOT family evidence. Corpus diversification was
/// tried (14 diverse-layout fixtures + OCR/rotation/security fixtures) and the
/// false positives persisted, falsifying the "corpus composition is the
/// binding constraint" hypothesis from `raster-weight-analysis-2026-08-30.md`
/// §8. The binding constraint is extraction resolution: the real text inside
/// the pixels is only reachable by OCR.
///
/// Fix (doctrine: §2 truth taxonomy, §0/§4.3 fail-closed):
/// - `LayoutSimilarityV2.coverage` records which structured channels carry
///   signal in either document.
/// - `RecurringFormCalibrator.classify` returns `.insufficientEvidence`
///   (NOT `.familyMatch`) when an above-threshold candidate has no structured
///   content on either side — regardless of raw score.
/// - The pair routes to a confirmation lane (`confirmLane`): OCR spot-check
///   when ink exists, human visual confirmation when nothing is readable.
///
/// Cost asymmetry justifies fail-closed: a false promotion pollutes the
/// template store and risks wrong prefill; a false abstention is recoverable
/// (the user re-specifies the form).
@Suite("Evidence-floor abstention (RG-138)")
struct EvidenceFloorAbstentionTests {

    // MARK: - Synthetic fingerprint helpers (deterministic, no PDF I/O)

    private func page(
        w: Int = 612, h: Int = 792,
        text: [LayoutFingerprintV2.Cell] = [],
        field: [LayoutFingerprintV2.Cell] = [],
        annot: [LayoutFingerprintV2.Cell] = [],
        raster: [LayoutFingerprintV2.Cell] = []
    ) -> LayoutFingerprintV2.PageLayout {
        LayoutFingerprintV2.PageLayout(
            pageIndex: 0, widthPoints: w, heightPoints: h, rotationDegrees: 0,
            textCells: text, fieldCells: field, annotationCells: annot,
            rasterCells: raster)
    }

    private func fp(
        _ digest: String,
        pages: [LayoutFingerprintV2.PageLayout]
    ) -> LayoutFingerprintV2 {
        LayoutFingerprintV2(
            algorithm: "layout-v2-cell-quantized",
            featureVersion: "layout-features-2",
            cellSizePoints: 4.0,
            pages: pages,
            digest: digest)
    }

    private func cell(_ col: Int, _ row: Int) -> LayoutFingerprintV2.Cell {
        LayoutFingerprintV2.Cell(col: col, row: row)
    }

    /// Two raster-only documents: identical geometry, identical ink pattern,
    /// zero structured content. This is the graphics-heavy lookalike profile.
    private func rasterOnlyPair() -> (a: LayoutFingerprintV2, b: LayoutFingerprintV2) {
        let ink = [cell(10, 10), cell(11, 10), cell(10, 11), cell(11, 11)]
        let a = fp("fp-raster-a", pages: [page(raster: ink)])
        let b = fp("fp-raster-b", pages: [page(raster: ink)])
        return (a, b)
    }

    /// Two blank documents: identical geometry, nothing else. Not even ink.
    private func blankPair() -> (a: LayoutFingerprintV2, b: LayoutFingerprintV2) {
        (fp("fp-blank-a", pages: [page()]), fp("fp-blank-b", pages: [page()]))
    }

    /// Two text-bearing documents with identical layout structure.
    private func textPair() -> (a: LayoutFingerprintV2, b: LayoutFingerprintV2) {
        let t = [cell(2, 2), cell(3, 2), cell(2, 3), cell(3, 3), cell(40, 5)]
        return (fp("fp-text-a", pages: [page(text: t)]), fp("fp-text-b", pages: [page(text: t)]))
    }

    private func calibrator() -> RecurringFormCalibrator {
        RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
    }

    // MARK: - Coverage semantics

    @Test("Coverage records structured channels and raster separately")
    func coverageFlags() {
        let (ra, rb) = rasterOnlyPair()
        let sim = ra.similarity(to: rb)
        #expect(!sim.coverage.text)
        #expect(!sim.coverage.field)
        #expect(!sim.coverage.annotation)
        #expect(!sim.coverage.region)
        #expect(sim.coverage.raster)
        #expect(!sim.coverage.hasStructuredContent)
        #expect(!sim.evidenceFloorMet)
        #expect(sim.confirmLane == .ocrSpotCheck)
        #expect(sim.total == 1.0,
                "Same geometry + same ink pattern must still score 1.0 — the floor is a classification gate, not a score deflator")
    }

    @Test("Blank pair has no content and routes to human visual lane")
    func blankCoverage() {
        let (a, b) = blankPair()
        let sim = a.similarity(to: b)
        #expect(!sim.coverage.hasStructuredContent)
        #expect(!sim.coverage.raster)
        #expect(sim.confirmLane == .humanVisual)
        #expect(sim.total == 1.0)
    }

    @Test("Text pair meets the evidence floor")
    func textCoverage() {
        let (a, b) = textPair()
        let sim = a.similarity(to: b)
        #expect(sim.coverage.text)
        #expect(sim.coverage.hasStructuredContent)
        #expect(sim.evidenceFloorMet)
        #expect(sim.confirmLane == nil)
        #expect(sim.total == 1.0)
    }

    @Test("Field or annotation signal alone also meets the floor")
    func fieldCoverage() {
        let f = [cell(20, 20), cell(21, 20)]
        let a = fp("fp-field-a", pages: [page(field: f)])
        let b = fp("fp-field-b", pages: [page(field: f)])
        let sim = a.similarity(to: b)
        #expect(sim.coverage.field)
        #expect(sim.evidenceFloorMet)
        #expect(sim.confirmLane == nil)
    }

    // MARK: - Classification gating

    @Test("Raster-only above-threshold pair abstains instead of promoting")
    func rasterOnlyAbstains() {
        let (a, b) = rasterOnlyPair()
        let (tier, score, templateID) = calibrator().classify(
            sourceDigest: "digest-candidate",
            layoutV2: a,
            templatesV2: ["tpl-scan": b],
            exactSourceDigests: ["tpl-scan": "digest-template"])
        #expect(score >= LayoutFingerprintV2.familyThreshold,
                "Precondition: the raw score must exceed the family threshold")
        #expect(tier == .insufficientEvidence,
                "A family claim on geometry + ink alone must abstain, got \(tier)")
        #expect(!tier.isMatch)
        #expect(templateID == "tpl-scan",
                "The abstention still identifies the candidate so the confirm lane can act on it")
    }

    @Test("Blank above-threshold pair abstains too")
    func blankAbstains() {
        let (a, b) = blankPair()
        let (tier, score, _) = calibrator().classify(
            sourceDigest: "digest-candidate",
            layoutV2: a,
            templatesV2: ["tpl-blank": b],
            exactSourceDigests: ["tpl-blank": "digest-template"])
        #expect(score >= LayoutFingerprintV2.familyThreshold)
        #expect(tier == .insufficientEvidence)
    }

    @Test("Text-bearing pair still promotes above threshold")
    func textPromotes() {
        let (a, b) = textPair()
        let (tier, score, templateID) = calibrator().classify(
            sourceDigest: "digest-candidate",
            layoutV2: a,
            templatesV2: ["tpl-form": b],
            exactSourceDigests: ["tpl-form": "digest-template"])
        #expect(score >= LayoutFingerprintV2.familyThreshold)
        #expect(tier == .familyMatch)
        #expect(tier.isMatch)
        #expect(templateID == "tpl-form")
    }

    @Test("Exact matches bypass the floor (same bytes, no family inference)")
    func exactBypassesFloor() {
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
        // Even a content-less exact source-digest match is a match: identical
        // bytes are the strongest claim the matcher can make.
        let (tier, score, templateID) = calibrator.classify(
            sourceDigest: "digest-same",
            layoutV2: fp("fp-x", pages: [page(raster: [cell(1, 1)])]),
            templatesV2: ["tpl": fp("fp-y", pages: [page(raster: [cell(1, 1)])])],
            exactSourceDigests: ["tpl": "digest-same"])
        #expect(tier == .exact)
        #expect(score == 1.0)
        #expect(templateID == "tpl")
        #expect(tier.isMatch)
    }

    @Test("Known variant with structured content still promotes")
    func knownVariantWithContentPromotes() {
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
        let t = [cell(2, 2), cell(3, 2)]
        // Same canonical layout (same digest), different source bytes, with
        // real text structure: a genuine layout-identity claim.
        let (tier, score, templateID) = calibrator.classify(
            sourceDigest: "digest-other",
            layoutV2: fp("fp-kv", pages: [page(text: t)]),
            templatesV2: ["tpl": fp("fp-kv", pages: [page(text: t)])],
            exactSourceDigests: ["tpl": "digest-same"])
        #expect(tier == .knownVariant)
        #expect(score == 0.9)
        #expect(templateID == "tpl")
        #expect(tier.isMatch)
    }

    @Test("Known variant on vacuous canonical equality abstains (scanned-pair hole)")
    func knownVariantVacuousAbstains() {
        let calibrator = RecurringFormCalibrator(thresholds: .layoutV2Calibrated)
        // Same canonical digest, no structured content on either side — the
        // scanned-noisy ↔ ocr-low-contrast collapse (both same-size textless
        // scans). Must abstain, never claim a known layout variant.
        let inkA = [cell(10, 10), cell(11, 10)]
        let inkB = [cell(50, 40), cell(51, 40), cell(60, 45)]  // different ink
        let (tier, score, _) = calibrator.classify(
            sourceDigest: "digest-other",
            layoutV2: fp("fp-vacuous", pages: [page(raster: inkA)]),
            templatesV2: ["tpl": fp("fp-vacuous", pages: [page(raster: inkB)])],
            exactSourceDigests: ["tpl": "digest-same"])
        #expect(score == 0.9)
        #expect(tier == .insufficientEvidence)
        #expect(!tier.isMatch)
    }

    @Test("Below-threshold pairs unchanged (ambiguous / noMatch)")
    func belowThresholdUnchanged() {
        let a = fp("fp-a", pages: [page(w: 612, h: 792, raster: [cell(1, 1)])])
        let b = fp("fp-b", pages: [page(w: 200, h: 300)])
        let (tier, _, _) = calibrator().classify(
            sourceDigest: "digest-candidate",
            layoutV2: a,
            templatesV2: ["tpl": b],
            exactSourceDigests: ["tpl": "digest-template"])
        #expect(tier == .noMatch || tier == .ambiguous)
        #expect(!tier.isMatch)
    }

    // MARK: - Calibration corpus behavior

    @Test("Hard-negative raster lookalike passes as an abstention, not a false positive")
    func calibrationAbstention() {
        let (a, b) = rasterOnlyPair()
        let corpus = [
            CorpusEntry(
                sourceDigest: "digest-lookalike",
                expectedTier: .noMatch,
                isHardNegative: true,
                documentClass: "scanned-form",
                notes: "Graphics-heavy lookalike: same page size, similar ink, no text",
                layoutV2: a)
        ]
        let templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [
            "tpl-scan": (fingerprint: b, sourceDigest: "digest-template")
        ]
        let report = calibrator().calibrate(corpus: corpus, templatesV2: templatesV2)
        #expect(report.falsePositives == 0,
                "An abstention must never count as a false positive")
        #expect(report.evidenceAbstentions == 1)
        #expect(report.passed == 1,
                "Expected noMatch + abstention is a passed entry (not promoted)")
        let result = report.results[0]
        #expect(result.actualTier == .insufficientEvidence)
        #expect(result.reason.contains("Evidence floor"))
    }

    @Test("Corpus entry can declare insufficientEvidence as its expected tier")
    func expectedAbstentionTier() {
        let (a, b) = blankPair()
        let corpus = [
            CorpusEntry(
                sourceDigest: "digest-blank",
                expectedTier: .insufficientEvidence,
                isHardNegative: true,
                documentClass: "blank-lookalike",
                layoutV2: a)
        ]
        let templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [
            "tpl-blank": (fingerprint: b, sourceDigest: "digest-template")
        ]
        let report = calibrator().calibrate(corpus: corpus, templatesV2: templatesV2)
        #expect(report.passed == 1)
        #expect(report.evidenceAbstentions == 1)
        #expect(report.falsePositives == 0)
    }

    @Test("True family entry with text still passes as familyMatch")
    func calibrationFamilyStillPasses() {
        let (a, b) = textPair()
        let corpus = [
            CorpusEntry(
                sourceDigest: "digest-member",
                expectedTier: .familyMatch,
                documentClass: "form",
                layoutV2: a)
        ]
        let templatesV2: [String: (fingerprint: LayoutFingerprintV2, sourceDigest: String)] = [
            "tpl-form": (fingerprint: b, sourceDigest: "digest-template")
        ]
        let report = calibrator().calibrate(corpus: corpus, templatesV2: templatesV2)
        #expect(report.falsePositives == 0)
        #expect(report.evidenceAbstentions == 0)
        #expect(report.results[0].actualTier == .familyMatch)
        #expect(report.results[0].passed)
    }

    // MARK: - Real-corpus confirmation (Observed evidence, 2026-09-03)

    /// The graphics-heavy pair measured at 0.9886 total (the F-3 cluster top).
    /// Both PDFs are scans with no extractable text layer.
    @Test("Real corpus: scanned-noisy vs ocr-low-contrast abstains, does not promote")
    func realCorpusGraphicsPairAbstains() throws {
        let results = "\(TestRepoRoot.prefix)benchmark/results"
        let paths = [
            "\(results)/browser-corpus/scanned-noisy.pdf",
            "\(results)/ocr-corpus/low-contrast.pdf"
        ]
        guard paths.allSatisfy({ FileManager.default.fileExists(atPath: $0) }) else {
            print("[RG-138 skip] corpus files missing; synthetic coverage already exercised")
            return
        }
        var fps: [LayoutFingerprintV2] = []
        for p in paths {
            guard let doc = PDFDocument(url: URL(fileURLWithPath: p)),
                  let extracted = LayoutFingerprintV2Extractor.extract(from: doc) else {
                throw TestError("Could not extract \(p)")
            }
            fps.append(extracted)
        }
        let sim = fps[0].similarity(to: fps[1])
        print(String(format: "[RG-138 evidence] scanned-noisy↔low-contrast total=%.4f coverage=%@",
                     sim.total, sim.coverage.description))
        #expect(!sim.coverage.hasStructuredContent,
                "Both scans must lack structured content for this test to be meaningful")
        #expect(sim.coverage.raster)

        let (tier, _, _) = calibrator().classify(
            sourceDigest: "digest-scan-a",
            layoutV2: fps[0],
            templatesV2: ["tpl-scan-b": fps[1]],
            exactSourceDigests: ["tpl-scan-b": "digest-scan-b"])
        print("[RG-138 evidence] classification = \(tier.rawValue) (score \(String(format: "%.4f", sim.total)))")
        // Whether or not this specific pair scores >= 0.90 today, the claim is:
        // if it does, it must abstain, never promote.
        if sim.total >= LayoutFingerprintV2.familyThreshold {
            #expect(tier == .insufficientEvidence)
        } else {
            #expect(tier == .noMatch || tier == .ambiguous)
        }
    }

    private struct TestError: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }
}
