import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Adaptive command history")
struct AdaptiveCommandHistoryTests {
  @Test("Recent commands are bounded and most recent first")
  @MainActor
  func boundedRecency() {
    let suiteName = "AdaptiveCommandHistoryTests.boundedRecency"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let history = AdaptiveCommandHistory(
      defaults: defaults,
      namespace: "test",
      maximumRecentCommands: 2
    )

    history.record(.search)
    history.record(.annotate)
    history.record(.search)
    history.record(.export)

    #expect(history.recentCommandIDs == ["export", "search"])
  }

  @Test("Recent hints expire by command distance without timestamps")
  @MainActor
  func recentHintsAgeOut() {
    let suiteName = "AdaptiveCommandHistoryTests.recentHintsAgeOut"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let history = AdaptiveCommandHistory(
      defaults: defaults,
      namespace: "test",
      maximumRecentAge: 2
    )

    history.record(.search)
    history.record(.annotate)
    #expect(history.recentCommandIDs == ["annotate", "search"])

    history.record(.export)
    #expect(history.recentCommandIDs == ["export", "annotate"])
    #expect(defaults.object(forKey: "test.recentEntries") != nil)
  }

  @Test("Explicit pins survive recency aging but remain separate")
  @MainActor
  func pinsDoNotAgeWithRecency() {
    let suiteName = "AdaptiveCommandHistoryTests.pinsDoNotAgeWithRecency"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let history = AdaptiveCommandHistory(
      defaults: defaults,
      namespace: "test",
      maximumRecentAge: 1
    )

    history.setPinned(.search, isPinned: true)
    history.record(.annotate)
    history.record(.export)

    #expect(history.recentCommandIDs == ["export"])
    #expect(history.pinnedCommandIDs == ["search"])
  }

  @Test("Pins are explicit and clear does not affect unrelated defaults")
  @MainActor
  func explicitPinsAndClear() {
    let suiteName = "AdaptiveCommandHistoryTests.explicitPinsAndClear"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defaults.set("untouched", forKey: "unrelated")
    let history = AdaptiveCommandHistory(defaults: defaults, namespace: "test")

    history.setPinned(.annotate, isPinned: true)
    history.setPinned(.search, isPinned: true)
    history.setPinned(.annotate, isPinned: false)

    #expect(history.pinnedCommandIDs == ["search"])
    history.clear()
    #expect(history.pinnedCommandIDs.isEmpty)
    #expect(history.recentCommandIDs.isEmpty)
    #expect(defaults.string(forKey: "unrelated") == "untouched")

    history.setPersonalizationEnabled(false)
    history.record(.export)
    #expect(history.recentCommandIDs.isEmpty)

    history.setPersonalizationEnabled(true)
    history.record(.export)
    #expect(history.recentCommandIDs == ["export"])
  }
}
