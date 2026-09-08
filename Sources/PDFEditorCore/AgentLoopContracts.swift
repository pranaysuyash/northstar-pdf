import Foundation

// MARK: - Agentic loop contracts (D-078; renumbered 2026-09-07, see decisions.md)
//
// A first-principles agent for this product is a bounded loop over the
// existing capability contracts, not a chatbot and not a macro runner:
//
//   goal -> plan -> preview -> approve -> execute -> validate -> retry/escalate
//
// This file owns the loop's types, the deterministic planner, and the
// UI-agnostic executor policy. It performs no mutations itself: the host
// (HUD/AppModel) resolves fresh `AdaptiveCommandDecision`s, performs the
// underlying model actions through their existing owners, and reports
// outcomes back. UI availability can never authorize a mutation; only a
// fresh `.available` decision at execution time plus recorded approval can.
//
// Doctrine alignment:
// - ARCHITECTURE: one canonical plan model; permissions, validation, and
//   recovery keep their existing single owners.
// - SECURITY: tool authority stays with the provider/AppModel boundary; the
//   agent is a proposer and sequencer, never a second mutation store.
// - TESTING: the executor policy is pure and fully unit-testable.
//
// Canonical host-action mapping (implemented by the HUD host; steps without
// a row here must escalate, never improvise):
//   step-focus-fill   -> AppModel.setEditorMode(.fill)            (nav)
//   step-bulk-apply   -> AppModel.previewBulkFill + applyBulkFill (approved only)
//   step-ocr          -> AppModel.runOCROnSelectedPage            (approved only)
//   step-present-export -> AppModel.presentExportReview          (presentation)
// Fallback by commandID: search/undo/redo/fillForm/export/extractText map to
// their existing model actions; anything else escalates with
// .capabilityUnsupported.

// MARK: - Goal

/// Goals the deterministic planner supports. The raw query string is
/// retained on the plan for display only; it never authorizes anything.
public enum AgentGoal: String, CaseIterable, Hashable, Sendable, Codable {
  /// Review suggestions, fill native fields, validate, present export review.
  case completeDocument = "complete-document"
  /// Run local OCR where the document lacks selectable text.
  case ocrSweep = "ocr-sweep"
  /// Validate current operations and present the export review.
  case verifyExport = "verify-export"
  // NOTE: no organize goal. The planner must not propose steps with no
  // honest host action, and no page organizer exists yet. Organize queries
  // degrade to commandSearch until one does (then add the goal + mapping).
}

// MARK: - Radio scope (D-076; ratified 2026-09-07)

// The canonical radio scope for the agent loop. Controls whether the
// planner proposes single-document plans, multi-document / continuous
// runs, or a one-shot scan. Only the host may transition between scopes;
// the executor gates on the current scope.
public enum RadioScope: String, CaseIterable, Hashable, Sendable, Codable {
  case single = "single"
  case multi = "multi"
  case continuous = "continuous"
}

// MARK: - Plan state

public enum AgentPlanState: String, Hashable, Sendable, Codable {
  case draft
  case awaitingApproval
  case approved
  case running
  case succeeded
  case failed
  case escalated
  case cancelled
  case invalid
}

public enum AgentStepState: String, Hashable, Sendable, Codable {
  case proposed
  case approved
  case running
  case succeeded
  case failed
  case skipped
}

// MARK: - Step

/// One typed step. `commandID` must be an `AdaptiveCommandID` so every step
/// resolves through the same availability policy as every other surface.
public struct AgentPlanStep: Hashable, Sendable, Codable, Identifiable {
  public let id: String
  public let commandID: AdaptiveCommandID
  public let title: String
  public let detail: String
  /// Whether performing the step can change document-derived state.
  public let isMutating: Bool
  /// Destructive steps need per-step approval beyond plan approval.
  /// No v1 goal emits one; the flag exists so the invariant is structural.
  public let requiresStepApproval: Bool
  /// Transient-failure retries allowed. Mass-apply steps use 0: partial
  /// application must escalate with counts, never silently re-run.
  public let maxRetries: Int
  public var state: AgentStepState
  public var attemptCount: Int
  public var stepApproved: Bool
  public var lastReasons: [AdaptiveCommandAvailabilityReason]

  public init(
    id: String,
    commandID: AdaptiveCommandID,
    title: String,
    detail: String,
    isMutating: Bool,
    requiresStepApproval: Bool = false,
    maxRetries: Int = 0
  ) {
    self.id = id
    self.commandID = commandID
    self.title = title
    self.detail = detail
    self.isMutating = isMutating
    self.requiresStepApproval = requiresStepApproval
    self.maxRetries = maxRetries
    self.state = .proposed
    self.attemptCount = 0
    self.stepApproved = false
    self.lastReasons = []
  }
}

// MARK: - Plan

/// A plan binds the source digest at proposal time. A changed document
/// invalidates the plan: stale plans cannot execute (D-078 invariant 4).
public struct AgentPlan: Hashable, Sendable, Codable, Identifiable {
  public let id: String
  public let goal: AgentGoal
  public let queryText: String
  public let sourceDigest: String
  public var steps: [AgentPlanStep]
  public var state: AgentPlanState
  public var escalation: AgentEscalation?

  public init(
    id: String = "agent-plan-\(UUID().uuidString)",
    goal: AgentGoal,
    queryText: String,
    sourceDigest: String,
    steps: [AgentPlanStep]
  ) {
    self.id = id
    self.goal = goal
    self.queryText = queryText
    self.sourceDigest = sourceDigest
    self.steps = steps
    self.state = .awaitingApproval
    self.escalation = nil
  }

  /// Plan-level approval flips proposed steps to approved. Steps demanding
  /// per-step approval stay proposed until `approveStep` is called for them.
  public mutating func approve() {
    guard state == .awaitingApproval || state == .draft else { return }
    state = .approved
    for index in steps.indices where !steps[index].requiresStepApproval {
      if steps[index].state == .proposed { steps[index].state = .approved }
    }
  }

  public mutating func approveStep(id: String) {
    guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
    steps[index].stepApproved = true
    if steps[index].state == .proposed { steps[index].state = .approved }
  }

  public mutating func cancel() {
    state = .cancelled
  }
}

// MARK: - Escalation

/// Value-free escalation: reason codes and step identity only. No document
/// content, values, paths, or digests beyond the already-bound source digest.
public struct AgentEscalation: Hashable, Sendable, Codable {
  public let stepID: String?
  public let commandID: AdaptiveCommandID?
  public let reasons: [AdaptiveCommandAvailabilityReason]
  public let message: String
  public let attemptsExhausted: Bool

  public init(
    stepID: String?,
    commandID: AdaptiveCommandID?,
    reasons: [AdaptiveCommandAvailabilityReason],
    message: String,
    attemptsExhausted: Bool
  ) {
    self.stepID = stepID
    self.commandID = commandID
    self.reasons = reasons
    self.message = message
    self.attemptsExhausted = attemptsExhausted
  }
}

// MARK: - Executor policy (pure)

/// The host-facing effect the executor needs next. The executor never
/// performs effects; it only decides them from plan + fresh decisions.
public enum AgentExecutorAction: Hashable, Sendable {
  case requestPlanApproval
  case runStep(stepID: String, isMutating: Bool)
  case retryStep(stepID: String, attempt: Int)
  case escalate(AgentEscalation)
  case succeed
  case planInvalid(reason: String)
  case cancelled
}

public enum AgentStepReport: Hashable, Sendable {
  /// The host performed the step without a transient failure.
  case succeeded
  /// The host hit a transient failure (timeout, busy provider). Retried
  /// within `maxRetries`, then escalated. Never used for availability,
  /// permission, or validation states — those escalate immediately.
  case transientFailure(message: String)
}

public enum AgentExecutor {
  /// Computes the next action. `decisions` must be freshly assessed by the
  /// host immediately before calling; stale decisions are a host bug the
  /// source-digest binding only partly mitigates.
  public static func nextAction(
    plan: AgentPlan,
    decisions: [AdaptiveCommandID: AdaptiveCommandDecision],
    sourceDigestMatches: Bool
  ) -> AgentExecutorAction {
    if plan.state == .cancelled { return .cancelled }
    guard sourceDigestMatches else {
      return .planInvalid(reason: "The document changed since this plan was proposed. Review the new state and propose again.")
    }
    guard plan.state == .approved || plan.state == .running else {
      return .requestPlanApproval
    }
    guard let step = plan.steps.first(where: { $0.state == .approved || $0.state == .running }) else {
      if plan.steps.allSatisfy({ $0.state == .succeeded || $0.state == .skipped }) {
        return .succeed
      }
      // A failed step without escalation recorded is a host-protocol breach;
      // surface it as escalation rather than stalling.
      return .escalate(AgentEscalation(
        stepID: nil, commandID: nil, reasons: [],
        message: "The plan stopped with no runnable step and no recorded outcome.",
        attemptsExhausted: false
      ))
    }
    if step.requiresStepApproval && !step.stepApproved {
      return .escalate(AgentEscalation(
        stepID: step.id, commandID: step.commandID,
        reasons: [.targetNeedsConfirmation],
        message: "“\(step.title)” is destructive and needs explicit per-step approval.",
        attemptsExhausted: false
      ))
    }
    guard let decision = decisions[step.commandID] else {
      return .escalate(AgentEscalation(
        stepID: step.id, commandID: step.commandID, reasons: [.capabilityUnsupported],
        message: "“\(step.title)” has no availability decision from the policy.",
        attemptsExhausted: false
      ))
    }
    // Invariant 1: only a fresh `.available` authorizes execution.
    // Invariant 2: any non-available decision escalates immediately —
    // availability states are never retried.
    guard decision.state.isActionable else {
      return .escalate(AgentEscalation(
        stepID: step.id, commandID: step.commandID, reasons: decision.reasons,
        message: availabilityMessage(for: step, decision: decision),
        attemptsExhausted: false
      ))
    }
    return .runStep(stepID: step.id, isMutating: step.isMutating)
  }

  /// Folds a host step report back into the plan.
  public static func applyStepReport(
    plan: AgentPlan,
    stepID: String,
    report: AgentStepReport
  ) -> (plan: AgentPlan, action: AgentExecutorAction) {
    var next = plan
    guard let index = next.steps.firstIndex(where: { $0.id == stepID }) else {
      return (next, .escalate(AgentEscalation(
        stepID: stepID, commandID: nil, reasons: [],
        message: "The host reported an unknown step.",
        attemptsExhausted: false
      )))
    }
    switch report {
    case .succeeded:
      next.steps[index].state = .succeeded
      if next.state == .approved { next.state = .running }
      if next.steps.allSatisfy({ $0.state == .succeeded || $0.state == .skipped }) {
        next.state = .succeeded
        return (next, .succeed)
      }
      return (next, .runStep(stepID: next.steps.first(where: { $0.state == .approved })?.id ?? stepID,
                             isMutating: false))
    case .transientFailure(let message):
      next.steps[index].attemptCount += 1
      if next.steps[index].attemptCount <= next.steps[index].maxRetries {
        next.steps[index].state = .approved
        return (next, .retryStep(stepID: stepID, attempt: next.steps[index].attemptCount))
      }
      next.steps[index].state = .failed
      next.steps[index].lastReasons = []
      next.state = .escalated
      next.escalation = AgentEscalation(
        stepID: stepID, commandID: next.steps[index].commandID, reasons: [],
        message: "“\(next.steps[index].title)” failed transiently \(next.steps[index].attemptCount) time(s): \(message)",
        attemptsExhausted: true
      )
      return (next, .escalate(next.escalation!))
    }
  }

  private static func availabilityMessage(for step: AgentPlanStep, decision: AdaptiveCommandDecision) -> String {
    switch decision.state {
    case .needsReview:
      return "“\(step.title)” needs human review first (\(reasonSummary(decision.reasons))). The plan is parked with nothing applied by this step."
    case .blocked:
      return "“\(step.title)” is blocked (\(reasonSummary(decision.reasons))). The plan is parked with nothing applied by this step."
    case .unavailable:
      return "“\(step.title)” is unavailable here (\(reasonSummary(decision.reasons))). The plan is parked with nothing applied by this step."
    case .available:
      return "Availability changed mid-flight; re-assess and propose again."
    }
  }

  private static func reasonSummary(_ reasons: [AdaptiveCommandAvailabilityReason]) -> String {
    reasons.isEmpty ? "no reason given" : reasons.map(\.rawValue).joined(separator: ", ")
  }
}

// MARK: - Deterministic planner

// MARK: - Run journal (value-free)

/// An append-only, value-free record of plan runs: IDs, goal, step outcomes,
/// and reason codes. Mirrors the `AdaptiveCommandHistory` privacy posture —
/// no document content, values, paths, or timestamps-as-profiling.
public struct AgentRunRecord: Hashable, Sendable, Codable {
  public let planID: String
  public let goal: AgentGoal
  public let stepOutcomes: [String]
  public let escalated: Bool
  public let reasonCodes: [String]

  public init(planID: String, goal: AgentGoal, stepOutcomes: [String], escalated: Bool, reasonCodes: [String]) {
    self.planID = planID
    self.goal = goal
    self.stepOutcomes = stepOutcomes
    self.escalated = escalated
    self.reasonCodes = reasonCodes
  }
}

// MARK: - Radio scope wiring into the request

/// Input the host assembles from live model state. All fields are
/// capability facts, never document content.
public struct AgentPlanRequest: Hashable, Sendable {
  public let query: String
  public let intent: AdaptiveIntentLens
  public let scope: RadioScope
  public let sourceDigest: String
  public let hasProfile: Bool
  public let hasCandidates: Bool
  public let hasOperations: Bool
  public let canExport: Bool

  public init(
    query: String,
    intent: AdaptiveIntentLens,
    scope: RadioScope,
    sourceDigest: String,
    hasProfile: Bool,
    hasCandidates: Bool,
    hasOperations: Bool,
    canExport: Bool
  ) {
    self.query = query
    self.intent = intent
    self.scope = scope
    self.sourceDigest = sourceDigest
    self.hasProfile = hasProfile
    self.hasCandidates = hasCandidates
    self.hasOperations = hasOperations
    self.canExport = canExport
  }
}

public enum AgentPlanProposal: Hashable, Sendable {
  /// A proposed plan awaiting human approval. Nothing has executed.
  case plan(AgentPlan)
  /// No supported goal matched; the host should fall back to ranked
  /// command search and say so plainly.
  case commandSearch
}

public enum DeterministicAgentPlanner {
  public static func propose(request: AgentPlanRequest) -> AgentPlanProposal {
    let q = request.query.lowercased()
    let scope = request.scope

    func singlePlan(_ goal: AgentGoal, _ steps: [AgentPlanStep]) -> AgentPlanProposal {
      .plan(AgentPlan(
        goal: goal,
        queryText: request.query,
        sourceDigest: request.sourceDigest,
        steps: steps
      ))
    }

    func multiPlan(_ goal: AgentGoal, _ steps: [AgentPlanStep]) -> AgentPlanProposal {
      .plan(AgentPlan(
        goal: goal,
        queryText: request.query,
        sourceDigest: request.sourceDigest,
        steps: steps
      ))
    }

    if q.contains("fill") || q.contains("complete") || q.contains("form") {
      if scope == .continuous {
        return multiPlan(.completeDocument, [
          AgentPlanStep(
            id: "step-focus-fill", commandID: .fillForm,
            title: "Focus the fill workflow (multi)",
            detail: "Switches to Fill mode and selects the first pending field. Changes nothing in the document.",
            isMutating: false
          ),
          AgentPlanStep(
            id: "step-bulk-apply", commandID: .fillForm,
            title: "Apply profile values with review (multi)",
            detail: "Materializes reviewed profile mappings as reversible operations. Requires your approval first; skipped fields are reported, never forced.",
            isMutating: true, maxRetries: 0
          ),
        ])
      }
      return singlePlan(.completeDocument, [
        AgentPlanStep(
          id: "step-focus-fill", commandID: .fillForm,
          title: "Focus the fill workflow",
          detail: "Switches to Fill mode and selects the first pending field. Changes nothing in the document.",
          isMutating: false
        ),
        AgentPlanStep(
          id: "step-bulk-apply", commandID: .fillForm,
          title: request.hasProfile ? "Apply profile values with review" : "Review suggestions before applying",
          detail: request.hasProfile
            ? "Materializes reviewed profile mappings as reversible operations. Requires your approval first; skipped fields are reported, never forced."
            : "No local profile is active, so this step only gathers suggestions for your review. Nothing is applied.",
          isMutating: true, maxRetries: 0
        ),
        AgentPlanStep(
          id: "step-present-export", commandID: .export,
          title: "Present the export review",
          detail: "Opens export validation for the applied operations. The source file is never overwritten.",
          isMutating: false
        ),
      ])
    }
    if q.contains("ocr") || q.contains("scan") || q.contains("extract text") {
      if scope == .continuous {
        return multiPlan(.ocrSweep, [
          AgentPlanStep(
            id: "step-ocr", commandID: .extractText,
            title: "Run local OCR on the selected page (multi)",
            detail: "Synthesizes a reversible searchable layer via Vision. Requires your approval first.",
            isMutating: true, maxRetries: 1
          ),
        ])
      }
      return .plan(AgentPlan(
        goal: .ocrSweep,
        queryText: request.query,
        sourceDigest: request.sourceDigest,
        steps: [
          AgentPlanStep(
            id: "step-ocr", commandID: .extractText,
            title: "Run local OCR on the selected page",
            detail: "Synthesizes a reversible searchable layer via Vision. Requires your approval first.",
            isMutating: true, maxRetries: 1
          ),
        ]
      ))
    }
    if q.contains("export") || q.contains("validat") || q.contains("finish") || q.contains("done") {
      if scope == .continuous {
        return multiPlan(.verifyExport, [
          AgentPlanStep(
            id: "step-present-export", commandID: .export,
            title: "Present the export review (multi)",
            detail: "Validates current operations and opens the export review. The source file is never overwritten.",
            isMutating: false
          ),
        ])
      }
      return .plan(AgentPlan(
        goal: .verifyExport,
        queryText: request.query,
        sourceDigest: request.sourceDigest,
        steps: [
          AgentPlanStep(
            id: "step-present-export", commandID: .export,
            title: "Present the export review",
            detail: "Validates current operations and opens the export review. The source file is never overwritten.",
            isMutating: false
          ),
        ]
      ))
    }
    // No organize branch by design (see AgentGoal): without an honest host
    // action, organize queries degrade to command search below.
    return .commandSearch
  }
}

// MARK: - Run journal (value-free)

public struct AgentRunJournal: Hashable, Sendable {
  public private(set) var records: [AgentRunRecord] = []
  public init() {}

  public mutating func append(_ record: AgentRunRecord) {
    records.append(record)
    if records.count > 50 { records.removeFirst(records.count - 50) }
  }
}
