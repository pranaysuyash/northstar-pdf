import Foundation

/// The user-facing job that should shape command presentation.
///
/// This is a presentation lens, not an editor mode and not document state. A
/// lens can change which valid commands are promoted without changing the
/// document or selecting an edit operation.
public enum AdaptiveIntentLens: String, CaseIterable, Hashable, Sendable {
  case read
  case understand
  case complete
  case organize
  case review
}

/// The interaction context from which a command surface was requested.
public enum AdaptiveInteractionTarget: String, CaseIterable, Hashable, Sendable {
  case documentScrolling
  case emptyPage
  case textSelection
  case formField
  case annotation
  case imageObject
  case pageThumbnail

  /// Short aliases for call sites that use the noun rather than the UI event.
  public static var scrolling: Self { .documentScrolling }
  public static var image: Self { .imageObject }
}

/// Confidence in the semantic target supplied by a host surface. A weak
/// detector may describe a likely target, but it must not unlock target-bound
/// editing until the target is certain or explicitly confirmed by the user.
public enum AdaptiveTargetConfidence: String, CaseIterable, Hashable, Sendable {
  case certain
  case provisional
  case ambiguous

  public var isActionable: Bool {
    self == .certain
  }
}

/// Capabilities established by the document/provider boundary.
///
/// These are facts supplied by the caller. The policy does not inspect a PDF,
/// infer capabilities from its content, persist them, or emit telemetry.
public struct AdaptiveCapabilityFacts: Equatable, Hashable, Sendable {
  public let canSearch: Bool
  public let canAnnotate: Bool
  public let canEditText: Bool
  public let canFillFields: Bool
  public let canExtract: Bool
  public let canExport: Bool
  public let canUndo: Bool
  public let canRedo: Bool
  public let canOrganizePages: Bool

  public init(
    canSearch: Bool = false,
    canAnnotate: Bool = false,
    canEditText: Bool = false,
    canFillFields: Bool = false,
    canExtract: Bool = false,
    canExport: Bool = false,
    canUndo: Bool = false,
    canRedo: Bool = false,
    canOrganizePages: Bool = false
  ) {
    self.canSearch = canSearch
    self.canAnnotate = canAnnotate
    self.canEditText = canEditText
    self.canFillFields = canFillFields
    self.canExtract = canExtract
    self.canExport = canExport
    self.canUndo = canUndo
    self.canRedo = canRedo
    self.canOrganizePages = canOrganizePages
  }

  public static let none = AdaptiveCapabilityFacts()

  public static let all = AdaptiveCapabilityFacts(
    canSearch: true,
    canAnnotate: true,
    canEditText: true,
    canFillFields: true,
    canExtract: true,
    canExport: true,
    canUndo: true,
    canRedo: true,
    canOrganizePages: true
  )
}

/// Stable identifiers for commands exposed by the policy.
public enum AdaptiveCommandID: String, CaseIterable, Hashable, Sendable, Codable {
  case search = "search"
  case commandPalette = "command-palette"
  case continueReading = "continue-reading"
  case understandDocument = "understand-document"
  case fillForm = "fill-form"
  case editText = "edit-text"
  case annotate = "annotate"
  case extractText = "extract-text"
  case export = "export"
  case undo = "undo"
  case redo = "redo"
  case organizePages = "organize-pages"
  case inspectAnnotation = "inspect-annotation"
  case editImage = "edit-image"
}

/// Stable semantic anchors used by commands and host surfaces.
public enum AdaptiveCommandAnchor: String, CaseIterable, Hashable, Sendable {
  case search = "search"
  case commandPalette = "command-palette"
  case document = "document"
  case selection = "selection"
  case formField = "form-field"
  case annotation = "annotation"
  case imageObject = "image-object"
  case pageThumbnail = "page-thumbnail"

  public static let searchAnchor = AdaptiveCommandAnchor.search
  public static let commandPaletteAnchor = AdaptiveCommandAnchor.commandPalette
}

/// A command definition. Definitions contain no enabled state; availability
/// is computed from `AdaptiveCapabilityFacts` by `AdaptiveCommandPolicy`.
public struct AdaptiveCommand: Equatable, Hashable, Sendable {
  public let id: AdaptiveCommandID
  public let title: String
  public let anchor: AdaptiveCommandAnchor
  public let isMutating: Bool

  public init(
    id: AdaptiveCommandID,
    title: String,
    anchor: AdaptiveCommandAnchor,
    isMutating: Bool
  ) {
    self.id = id
    self.title = title
    self.anchor = anchor
    self.isMutating = isMutating
  }
}

/// The state a host surface should render for a relevant command.
public enum AdaptiveCommandAvailabilityState: String, CaseIterable, Hashable, Sendable {
  case available
  case needsReview
  case blocked
  case unavailable

  public var isActionable: Bool {
    self == .available
  }
}

/// Stable, user-explainable reasons for a command decision. Provider reason
/// codes remain available alongside this value in `AdaptiveCommandDecision`.
public enum AdaptiveCommandAvailabilityReason: String, CaseIterable, Hashable, Sendable, Codable {
  case requiresSearchPermission
  case requiresAnnotationPermission
  case requiresModifyPermission
  case requiresFillCapability
  case requiresTextSelection
  case requiresFormFieldContext
  case requiresAnnotationContext
  case requiresImageContext
  case requiresPageContext
  case requiresUndoHistory
  case requiresRedoHistory
  case requiresExportableOperation
  case capabilityUnsupported
  case capabilityRevoked
  case capabilityNeedsReview
  case capabilityBlocked
  case targetNeedsConfirmation
}

/// One command's explainable availability projection. This is intentionally
/// separate from execution; UI state cannot authorize a document mutation.
public struct AdaptiveCommandDecision: Equatable, Hashable, Sendable {
  public let command: AdaptiveCommand
  public let state: AdaptiveCommandAvailabilityState
  public let reasons: [AdaptiveCommandAvailabilityReason]
  public let providerReasonCodes: [String]

  public init(
    command: AdaptiveCommand,
    state: AdaptiveCommandAvailabilityState,
    reasons: [AdaptiveCommandAvailabilityReason] = [],
    providerReasonCodes: [String] = []
  ) {
    self.command = command
    self.state = state
    self.reasons = reasons
    self.providerReasonCodes = providerReasonCodes.sorted()
  }
}

/// The complete input to a policy decision. Recent and pinned IDs are local
/// behavior hints only; unknown IDs are ignored and duplicates are harmless.
public struct AdaptiveCommandPolicyInput: Equatable, Hashable, Sendable {
  public let intent: AdaptiveIntentLens
  public let target: AdaptiveInteractionTarget
  public let targetConfidence: AdaptiveTargetConfidence
  public let capabilities: AdaptiveCapabilityFacts
  /// Per-command provider/capability outcomes. An omitted outcome preserves
  /// the boolean-only behavior used by the first implementation slice.
  public let capabilityOutcomes: [AdaptiveCommandID: PDFCapabilityOutcome]
  /// Provider-native reason codes such as `missingPassedMeasurement`.
  public let capabilityReasonCodes: [AdaptiveCommandID: [String]]
  public let recentCommandIDs: [String]
  public let pinnedCommandIDs: [String]

  public init(
    intent: AdaptiveIntentLens,
    target: AdaptiveInteractionTarget,
    targetConfidence: AdaptiveTargetConfidence = .certain,
    capabilities: AdaptiveCapabilityFacts,
    capabilityOutcomes: [AdaptiveCommandID: PDFCapabilityOutcome] = [:],
    capabilityReasonCodes: [AdaptiveCommandID: [String]] = [:],
    recentCommandIDs: [String] = [],
    pinnedCommandIDs: [String] = []
  ) {
    self.intent = intent
    self.target = target
    self.targetConfidence = targetConfidence
    self.capabilities = capabilities
    self.capabilityOutcomes = capabilityOutcomes
    self.capabilityReasonCodes = capabilityReasonCodes
    self.recentCommandIDs = recentCommandIDs
    self.pinnedCommandIDs = pinnedCommandIDs
  }
}

/// The valid commands and their two presentation projections.
///
/// `allValidCommands` is the deterministic overflow-discoverable inventory.
/// `primaryCommands` is a bounded prefix of that same inventory, while
/// `overflowCommands` is the remainder. No invalid command is present in any
/// projection, so consumers never need to render a disabled fake action.
public struct AdaptiveCommandPolicyResult: Equatable, Hashable, Sendable {
  public let intent: AdaptiveIntentLens
  public let target: AdaptiveInteractionTarget
  public let allValidCommands: [AdaptiveCommand]
  public let primaryCommands: [AdaptiveCommand]
  public let overflowCommands: [AdaptiveCommand]

  public init(
    intent: AdaptiveIntentLens,
    target: AdaptiveInteractionTarget,
    allValidCommands: [AdaptiveCommand],
    primaryCommands: [AdaptiveCommand],
    overflowCommands: [AdaptiveCommand]
  ) {
    self.intent = intent
    self.target = target
    self.allValidCommands = allValidCommands
    self.primaryCommands = primaryCommands
    self.overflowCommands = overflowCommands
  }

  public var validCommands: [AdaptiveCommand] { allValidCommands }
  public var enabledCommands: [AdaptiveCommand] { allValidCommands }
}

/// A deterministic, local-only policy for deciding which commands are valid
/// and which valid commands deserve the small primary surface.
public struct AdaptiveCommandPolicy: Equatable, Hashable, Sendable {
  public let primaryLimit: Int

  public static let searchAnchor = AdaptiveCommandAnchor.search
  public static let commandPaletteAnchor = AdaptiveCommandAnchor.commandPalette

  public init(primaryLimit: Int = 4) {
    self.primaryLimit = max(0, primaryLimit)
  }

  public static let standard = AdaptiveCommandPolicy()

  /// Evaluates capability validity first, then ranks only the valid commands.
  public func resolve(_ input: AdaptiveCommandPolicyInput) -> AdaptiveCommandPolicyResult {
    let valid = assess(input).compactMap { decision in
      decision.state.isActionable ? decision.command : nil
    }
    let ranked = rank(valid, for: input)
    let primary = Array(ranked.prefix(primaryLimit))
    let overflow = Array(ranked.dropFirst(primary.count))

    return AdaptiveCommandPolicyResult(
      intent: input.intent,
      target: input.target,
      allValidCommands: ranked,
      primaryCommands: primary,
      overflowCommands: overflow
    )
  }

  public func evaluate(_ input: AdaptiveCommandPolicyInput) -> AdaptiveCommandPolicyResult {
    resolve(input)
  }

  /// Returns every catalog command with an explainable state. Host surfaces
  /// such as the menu bar can keep relevant unavailable commands discoverable,
  /// while contextual menus can use `resolve` for enabled actions only.
  public func assess(_ input: AdaptiveCommandPolicyInput) -> [AdaptiveCommandDecision] {
    Self.catalog.map { command in
      let base = baseDecision(for: command, input: input)
      guard base.state == .available,
            let outcome = input.capabilityOutcomes[command.id]
      else {
        return base
      }

      switch outcome {
      case .available:
        return base
      case .partial, .unknown, .needsReview:
        guard command.isMutating || command.id == .extractText || command.id == .export else {
          return base
        }
        return AdaptiveCommandDecision(
          command: command,
          state: .needsReview,
          reasons: [.capabilityNeedsReview],
          providerReasonCodes: input.capabilityReasonCodes[command.id] ?? []
        )
      case .unsupported:
        return unavailable(
          command,
          reason: .capabilityUnsupported,
          providerReasonCodes: input.capabilityReasonCodes[command.id] ?? []
        )
      case .revoked:
        return unavailable(
          command,
          reason: .capabilityRevoked,
          providerReasonCodes: input.capabilityReasonCodes[command.id] ?? []
        )
      }
    }
  }

  public func validCommands(for input: AdaptiveCommandPolicyInput) -> [AdaptiveCommand] {
    resolve(input).allValidCommands
  }

  public func primaryCommands(for input: AdaptiveCommandPolicyInput) -> [AdaptiveCommand] {
    resolve(input).primaryCommands
  }

  private static let catalog: [AdaptiveCommand] = [
    AdaptiveCommand(id: .search, title: "Search", anchor: .search, isMutating: false),
    AdaptiveCommand(id: .commandPalette, title: "Command Palette", anchor: .commandPalette, isMutating: false),
    AdaptiveCommand(id: .continueReading, title: "Continue Reading", anchor: .document, isMutating: false),
    AdaptiveCommand(id: .understandDocument, title: "Understand Document", anchor: .document, isMutating: false),
    AdaptiveCommand(id: .fillForm, title: "Fill Form", anchor: .formField, isMutating: true),
    AdaptiveCommand(id: .editText, title: "Edit Text", anchor: .selection, isMutating: true),
    AdaptiveCommand(id: .annotate, title: "Annotate", anchor: .annotation, isMutating: true),
    AdaptiveCommand(id: .extractText, title: "Extract Text", anchor: .selection, isMutating: false),
    AdaptiveCommand(id: .export, title: "Export", anchor: .document, isMutating: false),
    AdaptiveCommand(id: .undo, title: "Undo", anchor: .document, isMutating: true),
    AdaptiveCommand(id: .redo, title: "Redo", anchor: .document, isMutating: true),
    AdaptiveCommand(id: .organizePages, title: "Organize Pages", anchor: .pageThumbnail, isMutating: true),
    AdaptiveCommand(id: .inspectAnnotation, title: "Inspect Annotation", anchor: .annotation, isMutating: false),
    AdaptiveCommand(id: .editImage, title: "Edit Image or Object", anchor: .imageObject, isMutating: true)
  ]

  private func isValid(
    _ id: AdaptiveCommandID,
    for input: AdaptiveCommandPolicyInput
  ) -> Bool {
    switch id {
    case .search:
      return input.capabilities.canSearch
    case .commandPalette, .continueReading, .understandDocument:
      return true
    case .fillForm:
      return input.targetConfidence.isActionable
        && input.target == .formField && input.capabilities.canFillFields
    case .editText:
      return input.targetConfidence.isActionable
        && input.target == .textSelection && input.capabilities.canEditText
    case .annotate:
      return input.targetConfidence.isActionable
        && input.target == .textSelection && input.capabilities.canAnnotate
    case .extractText:
      return input.targetConfidence.isActionable
        && input.target == .textSelection && input.capabilities.canExtract
    case .export:
      return input.capabilities.canExport
    case .undo:
      return input.capabilities.canUndo
    case .redo:
      return input.capabilities.canRedo
    case .organizePages:
      return input.targetConfidence.isActionable
        && (input.intent == .organize || input.target == .pageThumbnail)
        && input.capabilities.canOrganizePages
    case .inspectAnnotation:
      return input.targetConfidence.isActionable && input.target == .annotation
    case .editImage:
      return input.targetConfidence.isActionable
        && input.target == .imageObject && input.capabilities.canAnnotate
    }
  }

  private func baseDecision(
    for command: AdaptiveCommand,
    input: AdaptiveCommandPolicyInput
  ) -> AdaptiveCommandDecision {
    guard isValid(command.id, for: input) else {
      return AdaptiveCommandDecision(
        command: command,
        state: .unavailable,
        reasons: reasonsForInvalid(command.id, input: input)
      )
    }

    if input.capabilityOutcomes[command.id] == .unknown {
      return AdaptiveCommandDecision(
        command: command,
        state: .blocked,
        reasons: [.capabilityBlocked],
        providerReasonCodes: input.capabilityReasonCodes[command.id] ?? []
      )
    }

    return AdaptiveCommandDecision(
      command: command,
      state: .available,
      providerReasonCodes: input.capabilityReasonCodes[command.id] ?? []
    )
  }

  private func unavailable(
    _ command: AdaptiveCommand,
    reason: AdaptiveCommandAvailabilityReason,
    providerReasonCodes: [String]
  ) -> AdaptiveCommandDecision {
    AdaptiveCommandDecision(
      command: command,
      state: .unavailable,
      reasons: [reason],
      providerReasonCodes: providerReasonCodes
    )
  }

  private func reasonsForInvalid(
    _ id: AdaptiveCommandID,
    input: AdaptiveCommandPolicyInput
  ) -> [AdaptiveCommandAvailabilityReason] {
    switch id {
    case .search:
      return input.capabilities.canSearch ? [] : [.requiresSearchPermission]
    case .fillForm:
      var reasons: [AdaptiveCommandAvailabilityReason] = []
      if input.target != .formField { reasons.append(.requiresFormFieldContext) }
      if !input.targetConfidence.isActionable { reasons.append(.targetNeedsConfirmation) }
      if !input.capabilities.canFillFields { reasons.append(.requiresFillCapability) }
      return reasons
    case .editText:
      var reasons: [AdaptiveCommandAvailabilityReason] = []
      if input.target != .textSelection { reasons.append(.requiresTextSelection) }
      if !input.targetConfidence.isActionable { reasons.append(.targetNeedsConfirmation) }
      if !input.capabilities.canEditText { reasons.append(.requiresModifyPermission) }
      return reasons
    case .annotate:
      var reasons: [AdaptiveCommandAvailabilityReason] = []
      if input.target != .textSelection { reasons.append(.requiresTextSelection) }
      if !input.targetConfidence.isActionable { reasons.append(.targetNeedsConfirmation) }
      if !input.capabilities.canAnnotate { reasons.append(.requiresAnnotationPermission) }
      return reasons
    case .extractText:
      var reasons: [AdaptiveCommandAvailabilityReason] = []
      if input.target != .textSelection { reasons.append(.requiresTextSelection) }
      if !input.targetConfidence.isActionable { reasons.append(.targetNeedsConfirmation) }
      if !input.capabilities.canExtract { reasons.append(.requiresSearchPermission) }
      return reasons
    case .export:
      return [.requiresExportableOperation]
    case .undo:
      return [.requiresUndoHistory]
    case .redo:
      return [.requiresRedoHistory]
    case .organizePages:
      var reasons: [AdaptiveCommandAvailabilityReason] = []
      if input.intent != .organize && input.target != .pageThumbnail {
        reasons.append(.requiresPageContext)
      }
      if !input.targetConfidence.isActionable { reasons.append(.targetNeedsConfirmation) }
      if !input.capabilities.canOrganizePages {
        reasons.append(.requiresModifyPermission)
      }
      return reasons
    case .inspectAnnotation:
      return input.targetConfidence.isActionable
        ? [.requiresAnnotationContext]
        : [.requiresAnnotationContext, .targetNeedsConfirmation]
    case .editImage:
      var reasons: [AdaptiveCommandAvailabilityReason] = [.requiresImageContext, .requiresAnnotationPermission]
      if !input.targetConfidence.isActionable { reasons.append(.targetNeedsConfirmation) }
      return reasons
    case .commandPalette, .continueReading, .understandDocument:
      return []
    }
  }

  private func rank(
    _ commands: [AdaptiveCommand],
    for input: AdaptiveCommandPolicyInput
  ) -> [AdaptiveCommand] {
    let pinned = firstValidIndexes(input.pinnedCommandIDs)
    let recent = firstValidIndexes(input.recentCommandIDs)

    return commands.sorted { lhs, rhs in
      let lhsPinned = pinned[lhs.id.rawValue]
      let rhsPinned = pinned[rhs.id.rawValue]
      if (lhsPinned != nil) != (rhsPinned != nil) {
        return lhsPinned != nil
      }
      if let lhsPinned, let rhsPinned, lhsPinned != rhsPinned {
        return lhsPinned < rhsPinned
      }

      let lhsContext = contextScore(lhs.id, for: input)
      let rhsContext = contextScore(rhs.id, for: input)
      if lhsContext != rhsContext {
        return lhsContext > rhsContext
      }

      let lhsRecent = recent[lhs.id.rawValue]
      let rhsRecent = recent[rhs.id.rawValue]
      if (lhsRecent != nil) != (rhsRecent != nil) {
        return lhsRecent != nil
      }
      if let lhsRecent, let rhsRecent, lhsRecent != rhsRecent {
        return lhsRecent < rhsRecent
      }

      let lhsIntent = intentScore(lhs.id, for: input.intent)
      let rhsIntent = intentScore(rhs.id, for: input.intent)
      if lhsIntent != rhsIntent {
        return lhsIntent > rhsIntent
      }

      let lhsBase = baseScore(lhs.id)
      let rhsBase = baseScore(rhs.id)
      if lhsBase != rhsBase {
        return lhsBase > rhsBase
      }
      return lhs.id.rawValue < rhs.id.rawValue
    }
  }

  private func firstValidIndexes(_ ids: [String]) -> [String: Int] {
    var indexes: [String: Int] = [:]
    for id in ids {
      guard Self.catalog.contains(where: { $0.id.rawValue == id }) else { continue }
      if indexes[id] == nil {
        indexes[id] = indexes.count
      }
    }
    return indexes
  }

  private func contextScore(
    _ id: AdaptiveCommandID,
    for input: AdaptiveCommandPolicyInput
  ) -> Int {
    switch input.target {
    case .documentScrolling:
      switch id {
      case .continueReading: return 100
      case .search: return 90
      case .commandPalette: return 80
      case .understandDocument: return 70
      case .extractText, .export: return 40
      default: return 0
      }
    case .emptyPage:
      switch id {
      case .editText: return 100
      case .annotate: return 90
      case .commandPalette: return 80
      case .export: return 40
      default: return 0
      }
    case .textSelection:
      switch id {
      case .editText: return 100
      case .extractText: return 95
      case .annotate: return 90
      case .search: return 80
      case .commandPalette: return 70
      default: return 0
      }
    case .formField:
      switch id {
      case .fillForm: return 100
      case .commandPalette: return 80
      case .export: return 45
      default: return 0
      }
    case .annotation:
      switch id {
      case .inspectAnnotation: return 100
      case .annotate: return 95
      case .extractText: return 70
      case .commandPalette: return 60
      default: return 0
      }
    case .imageObject:
      switch id {
      case .editImage: return 100
      case .annotate: return 90
      case .export: return 45
      case .commandPalette: return 60
      default: return 0
      }
    case .pageThumbnail:
      switch id {
      case .organizePages: return 100
      case .commandPalette: return 80
      case .export: return 45
      default: return 0
      }
    }
  }

  private func intentScore(_ id: AdaptiveCommandID, for intent: AdaptiveIntentLens) -> Int {
    switch intent {
    case .read:
      return id == .continueReading ? 30 : id == .search ? 20 : 0
    case .understand:
      return id == .understandDocument ? 30 : id == .extractText ? 20 : 0
    case .complete:
      return id == .fillForm ? 30 : id == .export ? 20 : 0
    case .organize:
      return id == .organizePages ? 30 : id == .undo ? 20 : 0
    case .review:
      return id == .inspectAnnotation ? 30 : id == .extractText ? 20 : 0
    }
  }

  private func baseScore(_ id: AdaptiveCommandID) -> Int {
    switch id {
    case .commandPalette: return 90
    case .search: return 80
    case .continueReading, .understandDocument: return 70
    case .fillForm, .editText, .annotate, .extractText: return 60
    case .export: return 50
    case .undo, .redo: return 40
    case .organizePages, .inspectAnnotation, .editImage: return 30
    }
  }
}

// Names used by callers that prefer the shorter domain vocabulary.
public typealias UserIntentLens = AdaptiveIntentLens
public typealias IntentLens = AdaptiveIntentLens
public typealias InteractionTarget = AdaptiveInteractionTarget
public typealias CapabilityFacts = AdaptiveCapabilityFacts
public typealias CommandID = AdaptiveCommandID
public typealias CommandAnchor = AdaptiveCommandAnchor
public typealias Command = AdaptiveCommand
public typealias AdaptiveCommandInput = AdaptiveCommandPolicyInput
public typealias CommandPolicyResult = AdaptiveCommandPolicyResult
