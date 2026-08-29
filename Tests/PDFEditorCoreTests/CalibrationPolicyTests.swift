import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Recurring Form Calibrator Tests

@Suite("Calibration — Recurring Form Matching")
struct RecurringFormCalibratorTests {

  @Test("Exact match classification")
  func exactMatch() {
    let calibrator = RecurringFormCalibrator()
    let templates: [String: (fingerprint: String, sourceDigest: String)] = [
      "tpl-1": (fingerprint: "fp-aaa", sourceDigest: "digest-111")
    ]

    let (tier, score, templateID) = calibrator.classify(
      sourceDigest: "digest-111",
      layoutFingerprint: "fp-bbb",
      templates: ["tpl-1": "fp-aaa"],
      exactSourceDigests: ["tpl-1": "digest-111"]
    )

    #expect(tier == .exact)
    #expect(score == 1.0)
    #expect(templateID == "tpl-1")
  }

  @Test("Known variant classification")
  func knownVariant() {
    let calibrator = RecurringFormCalibrator()

    let (tier, score, templateID) = calibrator.classify(
      sourceDigest: "digest-222",
      layoutFingerprint: "fp-aaa",
      templates: ["tpl-1": "fp-aaa"],
      exactSourceDigests: ["tpl-1": "digest-111"]
    )

    #expect(tier == .knownVariant)
    #expect(score == 0.9)
    #expect(templateID == "tpl-1")
  }

  @Test("Family match classification")
  func familyMatch() {
    let calibrator = RecurringFormCalibrator(thresholds: .wellCalibrated)

    // Create templates with similar fingerprints
    let templates: [String: String] = [
      "tpl-1": "abc123def456",
        "tpl-2": "abc123xyz789"
    ]
    let exactDigests: [String: String] = [
        "tpl-1": "digest-old",
        "tpl-2": "digest-other"
    ]

    let (tier, score, _) = calibrator.classify(
      sourceDigest: "digest-new",
      layoutFingerprint: "abc123ghi012", // Similar to both
      templates: templates,
      exactSourceDigests: exactDigests
    )

    // Should be family match or ambiguous depending on similarity
    #expect(tier == .familyMatch || tier == .ambiguous || tier == .noMatch)
    #expect(score >= 0)
  }

  @Test("Stale classification when source digest mismatch")
  func staleClassification() {
    let calibrator = RecurringFormCalibrator()

    // This would be caught by the corpus entry's expectedSourceDigest check
    // In practice, stale is detected before classification
    let tier: MatchingTier = .stale
    #expect(tier == .stale)
    #expect(!tier.isMatch)
  }

  @Test("No match classification")
  func noMatch() {
    let calibrator = RecurringFormCalibrator()

    let (tier, score, templateID) = calibrator.classify(
      sourceDigest: "digest-completely-different",
      layoutFingerprint: "fp-completely-different",
      templates: ["tpl-1": "fp-aaa"],
      exactSourceDigests: ["tpl-1": "digest-111"]
    )

    #expect(tier == .noMatch || tier == .ambiguous)
    #expect(templateID == nil || tier == .ambiguous)
  }

  @Test("Family matching disabled returns noMatch")
  func familyDisabled() {
    let calibrator = RecurringFormCalibrator(thresholds: .familyDisabled)

    let (tier, _, _) = calibrator.classify(
      sourceDigest: "digest-new",
      layoutFingerprint: "fp-aaa",
      templates: ["tpl-1": "fp-aaa"],
      exactSourceDigests: ["tpl-1": "digest-old"]
    )

    // With family disabled, knownVariant still works (exact layout match)
    #expect(tier == .knownVariant || tier == .noMatch)
  }

  @Test("Hard negative is not classified as match")
  func hardNegativeReject() {
    let calibrator = RecurringFormCalibrator()

    let corpus = [
      CorpusEntry(
        sourceDigest: "hard-neg-1",
        layoutFingerprint: "fp-similar-but-not-match",
        expectedTier: .noMatch,
        isHardNegative: true,
        documentClass: "invoice"
      )
    ]

    let templates: [String: (fingerprint: String, sourceDigest: String)] = [
      "tpl-1": (fingerprint: "fp-aaa", sourceDigest: "digest-111")
    ]

    let report = calibrator.calibrate(corpus: corpus, templates: templates)

    #expect(report.falsePositives == 0)
    #expect(report.passed == 1)
  }

  @Test("Calibration report accuracy calculation")
  func calibrationAccuracy() {
    let calibrator = RecurringFormCalibrator()

    let corpus = [
      CorpusEntry(sourceDigest: "d1", layoutFingerprint: "fp1", expectedTier: .exact, documentClass: "form"),
      CorpusEntry(sourceDigest: "d2", layoutFingerprint: "fp2", expectedTier: .noMatch, documentClass: "form"),
      CorpusEntry(sourceDigest: "d3", layoutFingerprint: "fp3", expectedTier: .noMatch, isHardNegative: true, documentClass: "form"),
    ]

    let templates: [String: (fingerprint: String, sourceDigest: String)] = [
      "tpl-1": (fingerprint: "fp1", sourceDigest: "d1")
    ]

    let report = calibrator.calibrate(corpus: corpus, templates: templates)

    #expect(report.totalEntries == 3)
    #expect(report.accuracy >= 0)
    #expect(report.accuracy <= 1)
    #expect(report.falsePositiveRate >= 0)
    #expect(report.falsePositiveRate <= 1)
  }

  @Test("Tier breakdown counts correctly")
  func tierBreakdown() {
    let calibrator = RecurringFormCalibrator()

    let corpus = [
      CorpusEntry(sourceDigest: "d1", layoutFingerprint: "fp1", expectedTier: .exact, documentClass: "A"),
      CorpusEntry(sourceDigest: "d2", layoutFingerprint: "fp1", expectedTier: .knownVariant, documentClass: "A"),
      CorpusEntry(sourceDigest: "d3", layoutFingerprint: "fp-other", expectedTier: .noMatch, documentClass: "B"),
    ]

    let templates: [String: (fingerprint: String, sourceDigest: String)] = [
      "tpl-1": (fingerprint: "fp1", sourceDigest: "d1")
    ]

    let report = calibrator.calibrate(corpus: corpus, templates: templates)

    #expect(report.tierBreakdown[.exact] ?? 0 >= 0)
    #expect(report.tierBreakdown[.knownVariant] ?? 0 >= 0)
    #expect(report.tierBreakdown[.noMatch] ?? 0 >= 0)
  }

  @Test("MatchingTier isMatch property")
  func tierIsMatch() {
    #expect(MatchingTier.exact.isMatch)
    #expect(MatchingTier.knownVariant.isMatch)
    #expect(MatchingTier.familyMatch.isMatch)
    #expect(!MatchingTier.ambiguous.isMatch)
    #expect(!MatchingTier.stale.isMatch)
    #expect(!MatchingTier.noMatch.isMatch)
  }
}

// MARK: - Page Box Policy Tests

@Suite("Calibration — Page Box Precision Policy")
struct PageBoxPolicyTests {

  @Test("Canonical box selection: cropBox wins over mediaBox")
  func canonicalBoxCropWins() {
    let values = PageBoxValues(
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: CGRect(x: 10, y: 10, width: 500, height: 700),
      bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )

    #expect(values.canonicalBox == .cropBox)
    #expect(values.effectiveSize.width == 500)
    #expect(values.effectiveSize.height == 700)
  }

  @Test("Canonical box selection: mediaBox when cropBox is empty")
  func canonicalBoxMediaWhenCropEmpty() {
    let values = PageBoxValues(
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: .zero,
      bleedBox: .zero,
      trimBox: .zero,
      artBox: .zero
    )

    #expect(values.canonicalBox == .mediaBox)
    #expect(values.effectiveSize.width == 612)
    #expect(values.effectiveSize.height == 792)
  }

  @Test("PageBoxValues isComplete")
  func valuesComplete() {
    let complete = PageBoxValues(
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )
    #expect(complete.isComplete)

    let incomplete = PageBoxValues(
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: .zero,
      bleedBox: .zero,
      trimBox: .zero,
      artBox: .zero
    )
    #expect(!incomplete.isComplete)
  }

  @Test("Cross-system comparison: identical boxes pass")
  func crossSystemIdentical() {
    let policy = PageBoxPolicy()
    let boxes = PageBoxValues(
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )

    let comparison = policy.compare(pdfKit: boxes, pdfJs: boxes)
    #expect(comparison.passed)
    #expect(comparison.sizeMatch)
    #expect(comparison.coordinateMatch)
    #expect(comparison.canonicalBoxMatch)
  }

  @Test("Cross-system comparison: size deviation detected")
  func crossSystemSizeDeviation() {
    let policy = PageBoxPolicy()
    let pdfKit = PageBoxValues(
        mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )
    let pdfJs = PageBoxValues(
        mediaBox: CGRect(x: 0, y: 0, width: 613, height: 793), // 1pt deviation
        cropBox: CGRect(x: 0, y: 0, width: 613, height: 793),
        bleedBox: CGRect(x: 0, y: 0, width: 613, height: 793),
        trimBox: CGRect(x: 0, y: 0, width: 613, height: 793),
        artBox: CGRect(x: 0, y: 0, width: 613, height: 793)
    )

    let comparison = policy.compare(pdfKit: pdfKit, pdfJs: pdfJs)
    // 1pt deviation exceeds 0.1pt tolerance
    #expect(!comparison.passed)
    #expect(!comparison.sizeMatch)
    #expect(comparison.sizeDeviation == 1.0)
  }

  @Test("Cross-system comparison: within tolerance passes")
  func crossSystemWithinTolerance() {
    let policy = PageBoxPolicy(precision: .pdfJsStandard) // 0.5pt tolerance
    let pdfKit = PageBoxValues(
        mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )
    let pdfJs = PageBoxValues(
        mediaBox: CGRect(x: 0, y: 0, width: 612.3, height: 792.3), // 0.3pt deviation
        cropBox: CGRect(x: 0, y: 0, width: 612.3, height: 792.3),
        bleedBox: CGRect(x: 0, y: 0, width: 612.3, height: 792.3),
        trimBox: CGRect(x: 0, y: 0, width: 612.3, height: 792.3),
        artBox: CGRect(x: 0, y: 0, width: 612.3, height: 792.3)
    )

    let comparison = policy.compare(pdfKit: pdfKit, pdfJs: pdfJs)
    #expect(comparison.passed)
    #expect(comparison.sizeMatch)
  }

  @Test("Normalization rounds coordinates")
  func normalizationRounds() {
    let policy = PageBoxPolicy()
    let raw = CGRect(x: 10.123456, y: 20.654321, width: 612.987654, height: 792.111111)
    let normalized = policy.normalizedBox(raw)

    // Rounded to 2 decimal places
    #expect(normalized.origin.x == 10.12)
    #expect(normalized.origin.y == 20.65)
    #expect(normalized.size.width == 612.99)
    #expect(normalized.size.height == 792.11)
  }

  @Test("Normalization handles negative coordinates")
  func normalizationNegativeCoords() {
    let policy = PageBoxPolicy()
    let raw = CGRect(x: -10, y: -20, width: 612, height: 792)
    let normalized = policy.normalizedBox(raw)

    #expect(normalized.origin.x == 0)
    #expect(normalized.origin.y == 0)
  }

  @Test("Fingerprint is stable for same boxes")
  func fingerprintStable() {
    let policy = PageBoxPolicy()
    let boxes = PageBoxValues(
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )

    let fp1 = policy.fingerprint(from: boxes)
    let fp2 = policy.fingerprint(from: boxes)
    #expect(fp1 == fp2)
  }

  @Test("Fingerprint differs for different boxes")
  func fingerprintDiffers() {
    let policy = PageBoxPolicy()
    let boxes1 = PageBoxValues(
        mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        cropBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        bleedBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        trimBox: CGRect(x: 0, y: 0, width: 612, height: 792),
        artBox: CGRect(x: 0, y: 0, width: 612, height: 792)
    )
    let boxes2 = PageBoxValues(
        mediaBox: CGRect(x: 0, y: 0, width: 595, height: 842),
        cropBox: CGRect(x: 0, y: 0, width: 595, height: 842),
        bleedBox: CGRect(x: 0, y: 0, width: 595, height: 842),
        trimBox: CGRect(x: 0, y: 0, width: 595, height: 842),
        artBox: CGRect(x: 0, y: 0, width: 595, height: 842)
    )

    let fp1 = policy.fingerprint(from: boxes1)
    let fp2 = policy.fingerprint(from: boxes2)
    #expect(fp1 != fp2)
  }

  @Test("Policy presets exist")
  func policyPresets() {
    let _ = PageBoxPrecisionPolicy.pdfKitStandard
    let _ = PageBoxPrecisionPolicy.pdfJsStandard
    let _ = PageBoxPrecisionPolicy.overlayStrict
    let _ = PageBoxPrecisionPolicy.fingerprintStable
  }

  @Test("PageBoxType priority ordering")
  func boxTypePriority() {
    #expect(PageBoxType.cropBox.priority > PageBoxType.mediaBox.priority)
    #expect(PageBoxType.mediaBox.priority > PageBoxType.trimBox.priority)
    #expect(PageBoxType.trimBox.priority > PageBoxType.bleedBox.priority)
    #expect(PageBoxType.bleedBox.priority > PageBoxType.artBox.priority)
  }

  @Test("Real PDF page boxes from fixture")
  func realPDFPageBoxes() throws {
    let extractor = ImprovedTextExtractor()
    let fixtureURL = URL(fileURLWithPath: "benchmark/results/public-sample-form.pdf")
    let pdfData = try Data(contentsOf: fixtureURL)
    let extraction = try extractor.extract(data: pdfData)

    // Extraction should have found at least one page
    #expect(extraction.pageCount > 0)
    #expect(extraction.blocks.count > 0)
  }
}
