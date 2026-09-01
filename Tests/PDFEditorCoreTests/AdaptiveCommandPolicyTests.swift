import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Adaptive Command Policy")
struct AdaptiveCommandPolicyTests {

  @Test("Reader scrolling keeps selection-only actions out of the context menu")
  func readerScrolling() {
    let input = AdaptiveCommandPolicyInput(
      intent: .read,
      target: .documentScrolling,
      capabilities: .all
    )

    let result = AdaptiveCommandPolicy().resolve(input)
    let primaryIDs = Set(result.primaryCommands.map(\.id))
    let allValidIDs = Set(result.allValidCommands.map(\.id))

    #expect(primaryIDs.contains(.continueReading))
    #expect(primaryIDs.contains(.search))
    #expect(!primaryIDs.contains(.editText))
    #expect(!primaryIDs.contains(.annotate))
    #expect(!allValidIDs.contains(.editText))
    #expect(!allValidIDs.contains(.annotate))
    #expect(!allValidIDs.contains(.extractText))

    let editDecision = AdaptiveCommandPolicy.standard.assess(input)
      .first { $0.command.id == .editText }
    #expect(editDecision?.reasons == [.requiresTextSelection])
  }

  @Test("Text selection promotes text, extraction, and annotation context")
  func textSelection() {
    let result = AdaptiveCommandPolicy().resolve(AdaptiveCommandPolicyInput(
      intent: .understand,
      target: .textSelection,
      capabilities: AdaptiveCapabilityFacts(
        canSearch: true,
        canAnnotate: true,
        canEditText: true,
        canExtract: true
      )
    ))

    #expect(result.primaryCommands.prefix(3).map(\.id) == [.editText, .extractText, .annotate])
  }

  @Test("Form field promotes completion without performing a fill")
  func formField() {
    let result = AdaptiveCommandPolicy().resolve(AdaptiveCommandPolicyInput(
      intent: .complete,
      target: .formField,
      capabilities: AdaptiveCapabilityFacts(canFillFields: true)
    ))

    #expect(result.primaryCommands.first?.id == .fillForm)
    #expect(result.target == .formField)
  }

  @Test("Page organization requires a page target and modify capability")
  func pageOrganizationGating() {
    let denied = AdaptiveCommandPolicy.standard.assess(AdaptiveCommandPolicyInput(
      intent: .organize,
      target: .pageThumbnail,
      capabilities: .none
    )).first { $0.command.id == .organizePages }

    let allowed = AdaptiveCommandPolicy.standard.resolve(AdaptiveCommandPolicyInput(
      intent: .organize,
      target: .pageThumbnail,
      capabilities: AdaptiveCapabilityFacts(canOrganizePages: true)
    ))

    #expect(denied?.state == .unavailable)
    #expect(denied?.reasons == [.requiresModifyPermission])
    #expect(allowed.primaryCommands.first?.id == .organizePages)
  }

  @Test("Unsupported capabilities are absent from every enabled projection")
  func capabilityGating() {
    let result = AdaptiveCommandPolicy().resolve(AdaptiveCommandPolicyInput(
      intent: .review,
      target: .textSelection,
      capabilities: .none
    ))
    let ids = Set(result.allValidCommands.map(\.id))

    #expect(!ids.contains(.search))
    #expect(!ids.contains(.annotate))
    #expect(!ids.contains(.editText))
    #expect(!ids.contains(.fillForm))
    #expect(!ids.contains(.extractText))
    #expect(!ids.contains(.export))
    #expect(!ids.contains(.undo))
    #expect(!ids.contains(.redo))
    #expect(result.primaryCommands.allSatisfy { ids.contains($0.id) })
    #expect(result.overflowCommands.allSatisfy { ids.contains($0.id) })
  }

  @Test("Valid pins lead ranking and invalid or duplicate local IDs are ignored")
  func rankingAndPinning() {
    let result = AdaptiveCommandPolicy().resolve(AdaptiveCommandPolicyInput(
      intent: .read,
      target: .textSelection,
      capabilities: .all,
      recentCommandIDs: ["export", "export", "missing-command"],
      pinnedCommandIDs: ["annotate", "annotate", "missing-command", "search"]
    ))

    #expect(result.allValidCommands.first?.id == .annotate)
    #expect(result.allValidCommands.dropFirst().first?.id == .search)
    #expect(result.allValidCommands.map(\.id).count == Set(result.allValidCommands.map(\.id)).count)
  }

  @Test("Overflow provides deterministic discoverability for every valid command")
  func overflowDiscoverability() {
    let policy = AdaptiveCommandPolicy(primaryLimit: 2)
    let input = AdaptiveCommandPolicyInput(
      intent: .organize,
      target: .pageThumbnail,
      capabilities: .all,
      recentCommandIDs: ["undo", "search", "unknown"],
      pinnedCommandIDs: ["organize-pages"]
    )

    let first = policy.resolve(input)
    let second = policy.resolve(input)
    let primaryAndOverflow = first.primaryCommands + first.overflowCommands

    #expect(first == second)
    #expect(first.primaryCommands.count == 2)
    #expect(primaryAndOverflow == first.allValidCommands)
    #expect(Set(first.overflowCommands.map(\.id)).count == first.overflowCommands.count)
    #expect(first.allValidCommands.contains(where: { $0.id == .export }))
  }

  @Test("Resolving context is immutable and carries no document content")
  func contextImmutability() {
    let input = AdaptiveCommandPolicyInput(
      intent: .review,
      target: .annotation,
      capabilities: AdaptiveCapabilityFacts(canAnnotate: true),
      recentCommandIDs: ["inspect-annotation"],
      pinnedCommandIDs: ["command-palette"]
    )
    let before = input

    let result = AdaptiveCommandPolicy().resolve(input)

    #expect(input == before)
    #expect(result.target == .annotation)
    #expect(result.primaryCommands.first?.id == .commandPalette)
    #expect(result.allValidCommands.contains(where: { $0.id == .inspectAnnotation }))
  }

  @Test("Search and command palette anchors remain stable")
  func stableAnchors() {
    #expect(AdaptiveCommandID.search.rawValue == "search")
    #expect(AdaptiveCommandID.commandPalette.rawValue == "command-palette")
    #expect(AdaptiveCommandAnchor.searchAnchor == .search)
    #expect(AdaptiveCommandAnchor.commandPaletteAnchor == .commandPalette)
    #expect(AdaptiveCommandPolicy.searchAnchor == .search)
    #expect(AdaptiveCommandPolicy.commandPaletteAnchor == .commandPalette)
  }

  @Test("Assessment preserves relevant unavailable actions with stable reasons")
  func explainableUnavailableActions() {
    let input = AdaptiveCommandPolicyInput(
      intent: .read,
      target: .textSelection,
      capabilities: .none
    )

    let decisions = AdaptiveCommandPolicy.standard.assess(input)
    let annotate = decisions.first { $0.command.id == .annotate }
    let palette = decisions.first { $0.command.id == .commandPalette }

    #expect(annotate?.state == .unavailable)
    #expect(annotate?.reasons.contains(.requiresAnnotationPermission) == true)
    #expect(palette?.state == .available)
    #expect(palette?.state.isActionable == true)

    let fill = decisions.first { $0.command.id == .fillForm }
    #expect(fill?.reasons.contains(.requiresFormFieldContext) == true)
  }

  @Test("Partial capability remains visible to host surfaces but is not actionable")
  func partialCapabilityNeedsReview() {
    let input = AdaptiveCommandPolicyInput(
      intent: .review,
      target: .textSelection,
      capabilities: AdaptiveCapabilityFacts(canExtract: true),
      capabilityOutcomes: [.extractText: .partial],
      capabilityReasonCodes: [.extractText: ["missingPassedMeasurement"]]
    )

    let decisions = AdaptiveCommandPolicy.standard.assess(input)
    let extract = decisions.first { $0.command.id == .extractText }
    let enabledIDs = Set(AdaptiveCommandPolicy.standard.resolve(input).allValidCommands.map(\.id))

    #expect(extract?.state == .needsReview)
    #expect(extract?.reasons == [.capabilityNeedsReview])
    #expect(extract?.providerReasonCodes == ["missingPassedMeasurement"])
    #expect(!enabledIDs.contains(.extractText))
  }

  @Test("Unknown mutating capability is blocked before contextual promotion")
  func unknownCapabilityBlocksMutation() {
    let input = AdaptiveCommandPolicyInput(
      intent: .complete,
      target: .formField,
      capabilities: AdaptiveCapabilityFacts(canFillFields: true),
      capabilityOutcomes: [.fillForm: .unknown],
      capabilityReasonCodes: [.fillForm: ["noEligibleLocalProvider"]]
    )

    let decision = AdaptiveCommandPolicy.standard.assess(input).first { $0.command.id == .fillForm }
    let result = AdaptiveCommandPolicy.standard.resolve(input)

    #expect(decision?.state == .blocked)
    #expect(decision?.reasons == [.capabilityBlocked])
    #expect(decision?.providerReasonCodes == ["noEligibleLocalProvider"])
    #expect(!result.allValidCommands.contains(where: { $0.id == .fillForm }))
  }

  @Test("Provisional text targets fall back to reader-safe commands")
  func provisionalTextTargetAbstains() {
    let input = AdaptiveCommandPolicyInput(
      intent: .review,
      target: .textSelection,
      targetConfidence: .provisional,
      capabilities: AdaptiveCapabilityFacts(
        canSearch: true,
        canAnnotate: true,
        canEditText: true,
        canExtract: true
      )
    )

    let result = AdaptiveCommandPolicy.standard.resolve(input)
    let decisions = AdaptiveCommandPolicy.standard.assess(input)

    #expect(result.allValidCommands.contains(where: { $0.id == .search }))
    #expect(!result.allValidCommands.contains(where: { $0.id == .editText }))
    #expect(!result.allValidCommands.contains(where: { $0.id == .annotate }))
    #expect(!result.allValidCommands.contains(where: { $0.id == .extractText }))
    #expect(decisions.first(where: { $0.command.id == .editText })?.reasons.contains(.targetNeedsConfirmation) == true)
  }

  @Test("Ambiguous annotation targets cannot expose annotation actions")
  func ambiguousAnnotationTargetAbstains() {
    let input = AdaptiveCommandPolicyInput(
      intent: .review,
      target: .annotation,
      targetConfidence: .ambiguous,
      capabilities: AdaptiveCapabilityFacts(canAnnotate: true)
    )

    let result = AdaptiveCommandPolicy.standard.resolve(input)
    let decision = AdaptiveCommandPolicy.standard.assess(input)
      .first { $0.command.id == .inspectAnnotation }

    #expect(!result.allValidCommands.contains(where: { $0.id == .inspectAnnotation }))
    #expect(decision?.reasons.contains(.targetNeedsConfirmation) == true)
  }
}
