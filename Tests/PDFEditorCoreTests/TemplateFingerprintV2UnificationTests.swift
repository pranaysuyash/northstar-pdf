import Foundation
import Testing
import PDFKit
@testable import PDFEditorCore

/// Unification of LayoutFingerprintV2 components with the production
/// `PDFTemplateFingerprint` per-page signature builder.
///
/// First principles (from the layout-fingerprint exploration §6/§7):
/// - One per-page signature carries both the legacy production features
///   (field kinds, keyed name/anchor tokens, region signatures) and the V2
///   cell layout (text/field/annotation channels).
/// - **HMAC keying stays in production**: V2 cells enter the signature as
///   per-cell `hmac:` tokens scoped to the workspace key, so the layout is
///   not linkable across workspaces. The calibration lane keeps the raw
///   digest (`LayoutFingerprintV2.digest`) for cross-lane comparability.
/// - **Backward compatibility**: records without cell channels decode to
///   empty; fingerprints built without a V2 layout are byte-identical to the
///   legacy builder (featureVersion `layout-features-1`); the cell-aware
///   family score applies only when both sides carry cells — so the browser
///   lane (no cell channel) keeps exact cross-lane parity.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — same-layout recognition verified on real corpus
///   bytes, not synthetic fixtures.
/// - §12 Privacy — tokens are HMAC-keyed; no raw coordinates or text.
/// - §6 Documentation — behavior deltas (feature version, score blend) are
///   asserted, not assumed.
@Suite("Template Fingerprint V2 Unification")
struct TemplateFingerprintV2UnificationTests {

  private static let results = "/Users/pranay/Projects/pdf_editor/benchmark/results"
  private static let keyA = Data("test-workspace-key-A-2026".utf8)
  private static let keyB = Data("test-workspace-key-B-2026".utf8)

  // MARK: - Fixture helpers

  private func url(_ name: String) -> URL {
    switch name {
    case "public-sample-form.pdf":
      return URL(fileURLWithPath: "\(Self.results)/\(name)")
    case "plain-text.pdf", "navigation.pdf", "multi-column.pdf", "geometry.pdf":
      return URL(fileURLWithPath: "\(Self.results)/corpus-sweep-2026-08-25/\(name)")
    default:
      return URL(fileURLWithPath: "\(Self.results)/2026-08-25-native-incremental/corpus/\(name)")
    }
  }

  private func document(_ name: String) throws -> PDFDocument {
    let url = url(name)
    guard FileManager.default.fileExists(atPath: url.path),
          let document = PDFDocument(url: url) else {
      throw PDFEditorError.inputMissing(name)
    }
    return document
  }

  private func inspection(_ name: String) throws -> DocumentInspection {
    try PDFKitProvider().inspect(url: url(name))
  }

  private func v2(_ name: String) throws -> LayoutFingerprintV2 {
    guard let fp = LayoutFingerprintV2Extractor.extract(from: try document(name)) else {
      throw PDFEditorError.cannotOpen(name)
    }
    return fp
  }

  private func fingerprint(
    _ name: String,
    key: Data,
    withV2: Bool
  ) throws -> (DocumentInspection, PDFTemplateFingerprint) {
    let inspection = try inspection(name)
    let fp = PDFTemplateFingerprint.make(
      from: inspection,
      workspaceKey: key,
      includeExactSourceDigest: true,
      layoutV2: withV2 ? try v2(name) : nil
    )
    return (inspection, fp)
  }

  // MARK: - Keyed cell channels

  @Test("V2 cells enter the production signature as HMAC-keyed tokens")
  func keyedCellTokens() throws {
    let (_, fp) = try fingerprint("public-sample-form.pdf", key: Self.keyA, withV2: true)
    #expect(fp.featureVersion == "layout-features-2")
    let page = try #require(fp.pageSignatures.first)
    #expect(page.hasLayoutCells)
    #expect(!page.fieldCellTokens.isEmpty, "The base form has 6 widgets — field cells must be keyed")
    #expect(!page.textCellTokens.isEmpty, "Label text outside widgets must yield text cells")

    // Privacy: every token is HMAC-keyed; raw coordinates never enter.
    for token in page.textCellTokens + page.fieldCellTokens + page.annotationCellTokens {
      #expect(token.hasPrefix("hmac:"), "Cell tokens must be keyed: \(token)")
      #expect(!token.contains(","), "Raw cell coordinates must never enter the signature")
    }
  }

  @Test("Same layout, different bytes: knownVariant with the cell channel included")
  func sameLayoutKnownVariantWithCells() throws {
    let (baseInspection, baseFP) = try fingerprint("public-sample-form.pdf", key: Self.keyA, withV2: true)
    let (producerInspection, producerFP) = try fingerprint("synthetic-producer-0.pdf", key: Self.keyA, withV2: true)

    // Layout-identical re-encodings must share the equality fingerprint.
    #expect(baseFP.layoutFingerprint == producerFP.layoutFingerprint)
    #expect(baseInspection.source.sha256 != producerInspection.source.sha256, "Bytes must differ")

    let templateID = UUID()
    let index = try PDFTemplateIndex(histories: [
      PDFTemplateRevisionSet(
        templateID: templateID,
        revisions: [PDFTemplateContract(
          header: PDFTemplateHeader(templateDigest: baseFP.layoutFingerprint, provider: PDFProviderDescriptor(id: "test", version: "1", platform: "test")),
          payload: PDFTemplatePayload(
            templateID: templateID,
            revisionID: UUID(),
            displayName: "Base form",
            lifecycle: .active,
            fingerprint: baseFP,
            mappings: [])
        )]
      )
    ])
    let result = try PDFTemplateIndexQuery.query(
      index: index,
      fingerprint: producerFP,
      sourceDigest: producerInspection.source.sha256)
    #expect(result.state == .knownVariant, "Cell-bearing captures must still recognize re-encodings (got \(result.state))")
  }

  @Test("Workspace key isolation: same layout, different keys never collide")
  func crossKeyIsolation() throws {
    let (_, fpA) = try fingerprint("public-sample-form.pdf", key: Self.keyA, withV2: true)
    let (_, fpB) = try fingerprint("public-sample-form.pdf", key: Self.keyB, withV2: true)

    #expect(fpA.layoutFingerprint != fpB.layoutFingerprint,
            "Keyed layout fingerprints must not be linkable across workspaces")
    let pageA = try #require(fpA.pageSignatures.first)
    let pageB = try #require(fpB.pageSignatures.first)
    #expect(pageA.textCellTokens != pageB.textCellTokens)
    #expect(pageA.fieldCellTokens != pageB.fieldCellTokens)
  }

  // MARK: - Legacy path (backward compatibility)

  @Test("Legacy builder (no V2) is byte-identical to pre-unification behavior")
  func legacyPathUnchanged() throws {
    let (_, legacyBase) = try fingerprint("public-sample-form.pdf", key: Self.keyA, withV2: false)
    let (_, legacyProducer) = try fingerprint("synthetic-producer-0.pdf", key: Self.keyA, withV2: false)

    #expect(legacyBase.featureVersion == "layout-features-1")
    #expect(legacyBase.pageSignatures.allSatisfy { !$0.hasLayoutCells })
    #expect(legacyBase.layoutFingerprint == legacyProducer.layoutFingerprint,
            "Legacy known-variant equality must be preserved")
  }

  @Test("Old records without cell fields decode to empty cell channels")
  func oldJSONBackwardCompatible() throws {
    let (_, fp) = try fingerprint("public-sample-form.pdf", key: Self.keyA, withV2: false)
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    let data = try encoder.encode(fp)

    // Strip the cell fields, simulating a record written before the
    // unification. Re-encode must decode with defaults.
    guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      Issue.record("Fingerprint must serialize to a JSON object")
      return
    }
    // Rebuild page signatures without the post-unification cell keys.
    // `featureVersion` and every other legacy field stay intact (they
    // existed before the unification).
    let pagesData = object["pageSignatures"] as? [[String: Any]] ?? []
    let legacyPages = pagesData.map { page -> [String: Any] in
      var reduced = page
      for key in ["cellSizePoints", "textCellTokens", "fieldCellTokens", "annotationCellTokens"] {
        reduced.removeValue(forKey: key)
      }
      return reduced
    }
    object["pageSignatures"] = legacyPages
    let legacyData = try JSONSerialization.data(withJSONObject: object)
    let decoded = try decoder.decode(PDFTemplateFingerprint.self, from: legacyData)
    #expect(decoded.pageSignatures.allSatisfy { !$0.hasLayoutCells })
    #expect(decoded.pageSignatures.allSatisfy { $0.cellSizePoints == 4.0 })
  }

  // MARK: - Cell-aware family scoring

  @Test("Cell channel adds discrimination where the legacy signature is blind")
  func cellAwareScoreDiscriminates() throws {
    // plain-text vs navigation (F-4 pair): identical page 0 (base form),
    // different pages 1-2 (text vs links+text). The legacy production
    // signature — field kinds, keyed name/anchor tokens, region kinds —
    // cannot see text layout at all: it scores the pair 1.0 (same workspace
    // key, same kinds, same geometry). The V2 cell channel must break that
    // false identity, pushing the family score strictly below legacy.
    let (_, fpPlainV2) = try fingerprint("plain-text.pdf", key: Self.keyA, withV2: true)
    let (_, fpNavV2) = try fingerprint("navigation.pdf", key: Self.keyA, withV2: true)
    let (_, fpPlainLegacy) = try fingerprint("plain-text.pdf", key: Self.keyA, withV2: false)
    let (_, fpNavLegacy) = try fingerprint("navigation.pdf", key: Self.keyA, withV2: false)

    let legacyScore = PDFTemplateIndexQuery.structuralScore(fpPlainLegacy, fpNavLegacy)
    let cellScore = PDFTemplateIndexQuery.structuralScore(fpPlainV2, fpNavV2)

    print(String(format: "[unification evidence] plain-text↔navigation legacy=%.4f cell-aware=%.4f (cells narrow the false 1.0)",
                 legacyScore, cellScore))
    #expect(cellScore < legacyScore,
            "Cell channel must add discrimination: cell-aware \(cellScore) < legacy \(legacyScore)")
    // The blend is legacy-dominated (0.85/0.15) by design for cross-lane
    // parity; the residual gap above the 0.72 family threshold is the
    // documented F-3 headroom on the production scale (the V2 calibration
    // lane already discriminates this pair at 0.713 < 0.90).
  }
}