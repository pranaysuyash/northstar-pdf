import Foundation
import Testing

@testable import PDFEditorCore

/// D-057 contract tests: additive optional fields must keep legacy payload
/// JSON decodable and byte-stable on re-encode (the recovery pair manifest
/// validates stored view-state digests against recomputed ones), and the
/// fractional anchor math must be pure and clamped.
@Suite
struct DocumentSessionViewStateContractTests {
  /// A legacy payload produced before the D-057 fields existed: none of the
  /// anchor/pin keys are present.
  private static let legacyJSON = """
  {
    "selectedPageIndex": 2,
    "viewMode": "continuous",
    "scaleMode": "fitWidth",
    "pageRotation": 90,
    "selectedSearchMatchIndex": 1
  }
  """

  @Test("Legacy payloads decode with nil anchors and nil pin")
  func legacyPayloadDecodes() throws {
    let data = Data(Self.legacyJSON.utf8)
    let decoder = JSONDecoder()
    let state = try decoder.decode(DocumentSessionViewState.self, from: data)

    #expect(state.selectedPageIndex == 2)
    #expect(state.pageRotation == 90)
    #expect(state.selectedSearchMatchIndex == 1)
    #expect(state.anchorPageFraction == nil)
    #expect(state.anchorViewportX == nil)
    #expect(state.anchorViewportY == nil)
    #expect(state.pinnedLayout == nil)
    #expect(state.zoomScale == nil)
  }

  @Test("Re-encoding a legacy-shaped struct omits the new keys entirely")
  func reencodeOmitsNewKeys() throws {
    let state = DocumentSessionViewState(
      selectedPageIndex: 2,
      viewMode: .continuous,
      scaleMode: .fitWidth,
      pageRotation: 90,
      selectedSearchMatchIndex: 1
    )
    let data = try JSONEncoder().encode(state)
    let json = String(decoding: data, as: UTF8.self)

    #expect(!json.contains("anchorPageFraction"))
    #expect(!json.contains("anchorViewportX"))
    #expect(!json.contains("anchorViewportY"))
    #expect(!json.contains("pinnedLayout"))
  }

  @Test("Digest stability: legacy round-trip equals fresh nil-field encoding")
  func digestStabilityAcrossSchemaAddition() throws {
    let legacyState = try JSONDecoder().decode(
      DocumentSessionViewState.self, from: Data(Self.legacyJSON.utf8))
    let freshState = DocumentSessionViewState(
      selectedPageIndex: 2,
      viewMode: .continuous,
      scaleMode: .fitWidth,
      pageRotation: 90,
      selectedSearchMatchIndex: 1
    )

    // Same value ⇒ same encoded bytes ⇒ same recovery-pair digest. This is
    // what keeps old recovery pairs valid after the schema addition: stored
    // payloads decode into the extended struct with nil new fields and
    // re-encode to identical bytes. The encoder mirrors the production
    // identity encoder's [.sortedKeys] formatting, which makes digests
    // deterministic (a default JSONEncoder orders keys by hash seed and is
    // NOT byte-stable across processes).
    #expect(legacyState == freshState)
    let sortedKeysEncoder = JSONEncoder()
    sortedKeysEncoder.outputFormatting = [.sortedKeys]
    let legacyData = try sortedKeysEncoder.encode(legacyState)
    let freshData = try sortedKeysEncoder.encode(freshState)
    #expect(legacyData == freshData)
  }

  @Test("Round-trip preserves populated anchors and pin")
  func populatedFieldsRoundTrip() throws {
    let pin = DocumentSessionPinnedLayout(
      viewMode: .twoPage,
      scaleMode: .zoom,
      zoomScale: 1.75,
      pageRotation: 270
    )
    let state = DocumentSessionViewState(
      selectedPageIndex: 4,
      viewMode: .singlePage,
      scaleMode: .zoom,
      zoomScale: 1.5,
      pageRotation: 180,
      anchorPageFraction: 0.42,
      anchorViewportX: 0.3,
      anchorViewportY: 0.6,
      pinnedLayout: pin
    )

    let data = try JSONEncoder().encode(state)
    let decoded = try JSONDecoder().decode(DocumentSessionViewState.self, from: data)

    #expect(decoded == state)
    #expect(decoded.pinnedLayout?.zoomScale == 1.75)
    #expect(decoded.pinnedLayout?.pageRotation == 270)
    #expect(decoded.anchorPageFraction == 0.42)
  }

  @Test("Anchor math maps top-fraction into bottom-origin page space")
  func anchorPointMath() {
    // Letter-size page in PDFKit space: origin bottom-left, y up.
    let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)

    let top = DocumentSessionViewState.anchorPoint(pageBounds: pageBounds, fractionIntoPage: 0)
    #expect(top.y == 792)

    let middle = DocumentSessionViewState.anchorPoint(pageBounds: pageBounds, fractionIntoPage: 0.5)
    #expect(abs(middle.y - 396) < 0.001)

    let bottom = DocumentSessionViewState.anchorPoint(pageBounds: pageBounds, fractionIntoPage: 1)
    #expect(bottom.y == 0)

    // X stays at the horizontal page center.
    #expect(top.x == 306)
  }

  @Test("Anchor math clamps out-of-range fractions")
  func anchorPointClamps() {
    let pageBounds = CGRect(x: 10, y: 20, width: 612, height: 792)

    let aboveRange = DocumentSessionViewState.anchorPoint(pageBounds: pageBounds, fractionIntoPage: -2)
    #expect(aboveRange.y == 812)

    let belowRange = DocumentSessionViewState.anchorPoint(pageBounds: pageBounds, fractionIntoPage: 9)
    #expect(belowRange.y == 20)
  }
}
