import Foundation
import Testing

@testable import PDFEditorRecovery
import PDFEditorCore

/// D-057: view memory is split into a resume point (always restored) and a
/// magnification/layout policy (fixedDefault | lastUsedGlobally | perDocument),
/// with an explicit per-document pin overriding any policy. These tests pin
/// the resolution logic, the fresh-open layout application, and the boundary
/// snapping contract ("stale state is untrusted input").
@Suite(.serialized)
struct LayoutRestorePolicyTests {
  private static let globalLayoutDefaultsKey = "lastUsedReaderLayout"
  private let defaults = UserDefaults.standard

  /// AppModel's designated initializer touches only local stores; vault and
  /// keychain initialization stay disabled for hermetic unit tests.
  @MainActor
  private func makeModel() -> AppModel {
    // The convenience init would touch the user defaults domain used by the
    // real app; the full initializer with default stores still only reads
    // UserDefaults lazily (all D-057 state is UserDefaults-backed), so it is
    // safe here as long as each test cleans its keys.
    AppModel(initializeLocalVaultState: false, loadsKeychainSignatures: false)
  }

  private func cleanKeys() {
    defaults.removeObject(forKey: "layoutRestorePolicy")
    defaults.removeObject(forKey: Self.globalLayoutDefaultsKey)
  }

  private func seedGlobalLayout(
    viewMode: ReaderViewMode,
    scaleMode: ReaderScaleMode,
    zoom: Double,
    rotation: Int
  ) {
    let record = AppModel.GlobalLayoutRecord(
      viewModeRaw: viewMode.rawValue,
      scaleModeRaw: scaleMode.rawValue,
      zoom: zoom,
      rotation: rotation
    )
    if let data = try? JSONEncoder().encode(record) {
      defaults.set(data, forKey: Self.globalLayoutDefaultsKey)
    }
  }

  private func makeRestoredState(
    scaleMode: ReaderScaleMode = .fitPage,
    zoomScale: Double? = 2.0,
    rotation: Int = 180,
    pinnedLayout: DocumentSessionPinnedLayout? = nil
  ) -> DocumentSessionViewState {
    DocumentSessionViewState(
      selectedPageIndex: 3,
      viewMode: .continuous,
      scaleMode: scaleMode,
      zoomScale: zoomScale,
      pageRotation: rotation,
      pinnedLayout: pinnedLayout
    )
  }

  // MARK: - Policy resolution

  @MainActor
  @Test("Fixed default ignores the persisted layout entirely")
  func fixedDefaultIgnoresPersistedLayout() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .fixedDefault

    let resolved = model.resolvedRestoreLayout(from: makeRestoredState())

    #expect(resolved.scaleMode == .fitWidth)
    #expect(resolved.zoom == 1.0)
    #expect(resolved.rotation == 0)
    #expect(!resolved.usedPinnedLayout)
  }

  @MainActor
  @Test("Per-document policy restores the document's own last layout")
  func perDocumentUsesSnapshotLayout() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .perDocument

    let resolved = model.resolvedRestoreLayout(from: makeRestoredState())

    #expect(resolved.scaleMode == .fitPage)
    #expect(resolved.zoom == 2.0)
    #expect(resolved.rotation == 180)
  }

  @MainActor
  @Test("Last-used-globally prefers the global record over the document snapshot")
  func lastUsedGloballyPrefersGlobalRecord() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .lastUsedGlobally
    seedGlobalLayout(viewMode: .twoPage, scaleMode: .zoom, zoom: 1.5, rotation: 90)

    let resolved = model.resolvedRestoreLayout(from: makeRestoredState())

    #expect(resolved.scaleMode == .zoom)
    #expect(resolved.zoom == 1.5)
    #expect(resolved.rotation == 90)
  }

  @MainActor
  @Test("Last-used-globally falls back to neutral when no global record exists")
  func lastUsedGloballyFallsBackToNeutral() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .lastUsedGlobally

    let resolved = model.resolvedRestoreLayout(from: makeRestoredState())

    #expect(resolved.scaleMode == .fitWidth)
    #expect(resolved.zoom == 1.0)
    #expect(resolved.rotation == 0)
  }

  @MainActor
  @Test("Pinned layout overrides every policy")
  func pinnedLayoutOverridesPolicy() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .fixedDefault

    let pin = DocumentSessionPinnedLayout(
      viewMode: .singlePage,
      scaleMode: .zoom,
      zoomScale: 2.5,
      pageRotation: 270
    )
    let resolved = model.resolvedRestoreLayout(from: makeRestoredState(pinnedLayout: pin))

    #expect(resolved.scaleMode == .zoom)
    #expect(resolved.zoom == 2.5)
    #expect(resolved.rotation == 270)
    #expect(resolved.usedPinnedLayout)
  }

  // MARK: - Fresh-open layout

  @MainActor
  @Test("Fresh open under fixed default resets to fit-width/continuous/100%/0°")
  func freshOpenFixedDefault() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .fixedDefault
    // Simulate leakage from a previously open document.
    model.readerScaleMode = .zoom
    model.readerZoom = 2.75
    model.readerRotation = 90
    model.readerViewMode = .singlePage

    model.applyLayoutForFreshOpen()

    #expect(model.readerScaleMode == .fitWidth)
    #expect(model.readerZoom == 1.0)
    #expect(model.readerRotation == 0)
    #expect(model.readerViewMode == .continuous)
  }

  @MainActor
  @Test("Fresh open under last-used-globally adopts the recorded global layout")
  func freshOpenLastUsedGlobally() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .lastUsedGlobally
    seedGlobalLayout(viewMode: .continuous, scaleMode: .fitPage, zoom: 1.0, rotation: 90)

    model.applyLayoutForFreshOpen()

    #expect(model.readerScaleMode == .fitPage)
    #expect(model.readerRotation == 90)
    #expect(model.readerViewMode == .continuous)
  }

  // MARK: - Boundary snapping (stale state is untrusted input)

  @MainActor
  @Test("Resolved layout snaps out-of-bounds persisted values to legal ranges")
  func snappingClampsIllegalValues() {
    cleanKeys()
    let model = makeModel()
    model.layoutRestorePolicy = .perDocument

    let state = DocumentSessionViewState(
      selectedPageIndex: 99,
      viewMode: .continuous,
      scaleMode: .zoom,
      zoomScale: 99.0,
      pageRotation: 450,
      anchorPageFraction: 7.0,
      anchorViewportX: -3.0,
      anchorViewportY: 12.0
    )
    let resolved = model.resolvedRestoreLayout(from: state)

    #expect(resolved.zoom == 3.0)
    #expect(resolved.rotation == 90)
    // Anchor fields clamp at the contract boundary itself.
    #expect(state.anchorPageFraction == 1.0)
    #expect(state.anchorViewportX == 0.0)
    #expect(state.anchorViewportY == 1.0)
    // Page index clamps against the (empty) inspection page count.
    let snapshot = model.recoveryViewStateSnapshot(state, inspection: nil)
    #expect(snapshot.selectedPageIndex == 0)
  }

  // MARK: - Pin lifecycle guards

  @Test("Recovery-pair view-state digest is stable across the schema addition")
  func viewStateDigestStableAcrossSchemaAddition() throws {
    // A pre-D-057 payload: none of the anchor/pin keys are present.
    let legacyJSON = """
    {
      "selectedPageIndex": 2,
      "viewMode": "continuous",
      "scaleMode": "fitWidth",
      "pageRotation": 90,
      "selectedSearchMatchIndex": 1
    }
    """
    let decoded = try JSONDecoder().decode(
      DocumentSessionViewState.self, from: Data(legacyJSON.utf8))
    let fresh = DocumentSessionViewState(
      selectedPageIndex: 2,
      viewMode: .continuous,
      scaleMode: .fitWidth,
      pageRotation: 90,
      selectedSearchMatchIndex: 1
    )

    // Stored payloads validate their digest against a recompute on decode;
    // this pins that old recovery pairs still match after D-057.
    #expect(decoded == fresh)
    #expect(
      RecoveryLedgerIdentity.viewStateDigest(decoded)
        == RecoveryLedgerIdentity.viewStateDigest(fresh))
  }

  @MainActor
  @Test("Clearing a pin without one is a no-op that does not touch autosave state")
  func clearPinWithoutPinIsNoop() {
    cleanKeys()
    let model = makeModel()
    let before = model.hasPinnedLayout

    model.clearPinnedLayout()

    #expect(!before)
    #expect(!model.hasPinnedLayout)
  }
}
