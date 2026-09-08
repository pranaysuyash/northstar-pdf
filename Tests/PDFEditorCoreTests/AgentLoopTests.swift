import Foundation
import PDFEditorCore
import Testing

/// Gate-enforcement tests for the D-078 agentic loop executor policy.
/// Sensitivity: S1 — new pure policy, passing on correct enforcement.
/// Each test names the invariant it guards; weakening the executor must
/// break at least one of them.
@Suite("Agent Loop Executor")
struct AgentLoopTests {

  private func available(_ id: AdaptiveCommandID) -> AdaptiveCommandDecision {
    AdaptiveCommandDecision(
      command: AdaptiveCommand(id: id, title: id.rawValue, anchor: .document, isMutating: true),
      state: .available
    )
  }

  private func unavailable(
    _ id: AdaptiveCommandID,
    state: AdaptiveCommandAvailabilityState,
    reasons: [AdaptiveCommandAvailabilityReason] = []
  ) -> AdaptiveCommandDecision {
    AdaptiveCommandDecision(
      command: AdaptiveCommand(id: id, title: id.rawValue, anchor: .document, isMutating: true),
      state: state, reasons: reasons
    )
  }

  private func approvedPlan(digest: String = "digest-1") -> AgentPlan {
    var plan = AgentPlan(
      goal: .completeDocument, queryText: "fill this form",
      sourceDigest: digest,
      steps: [
        AgentPlanStep(id: "s1", commandID: .fillForm, title: "Focus fill",
                      detail: "nav", isMutating: false),
        AgentPlanStep(id: "s2", commandID: .fillForm, title: "Apply profile",
                      detail: "mutating", isMutating: true, maxRetries: 0),
      ]
    )
    plan.approve()
    return plan
  }

  @Test("Invariant 1a: unapproved plans never execute (Invariant: approval first)")
  func unapprovedPlanRequestsApproval() {
    let plan = AgentPlan(
      goal: .verifyExport, queryText: "export",
      sourceDigest: "d",
      steps: [AgentPlanStep(id: "s1", commandID: .export, title: "Export",
                            detail: "x", isMutating: false)]
    )
    let action = AgentExecutor.nextAction(
      plan: plan, decisions: [.export: available(.export)], sourceDigestMatches: true)
    #expect(action == .requestPlanApproval)
  }

  @Test("Invariant 4: changed document invalidates the plan")
  func staleDigestInvalidates() {
    let action = AgentExecutor.nextAction(
      plan: approvedPlan(), decisions: [:], sourceDigestMatches: false)
    if case .planInvalid = action { } else { Issue.record("expected planInvalid") }
  }

  @Test("Invariant 1b: only a fresh .available decision runs a mutating step")
  func availableStepRuns() {
    let action = AgentExecutor.nextAction(
      plan: approvedPlan(),
      decisions: [.fillForm: available(.fillForm)], sourceDigestMatches: true)
    #expect(action == .runStep(stepID: "s1", isMutating: false))
  }

  @Test("Invariant 2: blocked decisions escalate immediately, never retry")
  func blockedEscalates() {
    let action = AgentExecutor.nextAction(
      plan: approvedPlan(),
      decisions: [.fillForm: unavailable(.fillForm, state: .blocked,
                                         reasons: [.requiresModifyPermission])],
      sourceDigestMatches: true)
    if case .escalate(let e) = action {
      #expect(e.reasons.contains(.requiresModifyPermission))
      #expect(!e.attemptsExhausted)
    } else {
      Issue.record("expected escalate, got \(action)")
    }
  }

  @Test("Invariant 2b: needsReview escalates, never auto-runs")
  func needsReviewEscalates() {
    let action = AgentExecutor.nextAction(
      plan: approvedPlan(),
      decisions: [.fillForm: unavailable(.fillForm, state: .needsReview,
                                         reasons: [.targetNeedsConfirmation])],
      sourceDigestMatches: true)
    if case .escalate = action { } else { Issue.record("expected escalate") }
  }

  @Test("Invariant 3: transient failure retries within bound, then escalates exhausted")
  func retryBoundEnforced() {
    var plan = approvedPlan()
    plan.steps[1].state = .approved
    var planRunning = plan
    planRunning.state = .running
    // First transient failure on s2 (maxRetries 0 for mass-apply): escalates at once.
    let (p1, a1) = AgentExecutor.applyStepReport(
      plan: planRunning, stepID: "s2", report: .transientFailure(message: "busy"))
    if case .escalate(let e) = a1 {
      #expect(e.attemptsExhausted)
    } else {
      Issue.record("mass-apply must not retry, got \(a1)")
    }
    #expect(p1.state == .escalated)

    // A retryable step (maxRetries 1) retries once, then exhausts.
    var plan2 = AgentPlan(
      goal: .ocrSweep, queryText: "ocr",
      sourceDigest: "d",
      steps: [AgentPlanStep(id: "r1", commandID: .extractText, title: "Inspect",
                            detail: "ro", isMutating: false, maxRetries: 1)]
    )
    plan2.approve()
    plan2.state = .running
    let (p2, a2) = AgentExecutor.applyStepReport(
      plan: plan2, stepID: "r1", report: .transientFailure(message: "timeout"))
    if case .retryStep(let id, let attempt) = a2 {
      #expect(id == "r1" && attempt == 1)
    } else {
      Issue.record("expected retry, got \(a2)")
    }
    let (_, a3) = AgentExecutor.applyStepReport(
      plan: p2, stepID: "r1", report: .transientFailure(message: "timeout"))
    if case .escalate(let e3) = a3 {
      #expect(e3.attemptsExhausted)
    } else {
      Issue.record("expected exhausted escalation, got \(a3)")
    }
  }

  @Test("All steps succeeding completes the plan")
  func successPath() {
    var plan = approvedPlan()
    plan.state = .running
    let (p1, _) = AgentExecutor.applyStepReport(plan: plan, stepID: "s1", report: .succeeded)
    let (_, action) = AgentExecutor.applyStepReport(plan: p1, stepID: "s2", report: .succeeded)
    #expect(action == .succeed)
  }

  @Test("Destructive steps without per-step approval escalate")
  func destructiveNeedsStepApproval() {
    var plan = AgentPlan(
      goal: .completeDocument, queryText: "redact",
      sourceDigest: "d",
      steps: [AgentPlanStep(id: "x1", commandID: .annotate, title: "Commit redaction",
                            detail: "destructive", isMutating: true, requiresStepApproval: true)]
    )
    plan.approve()
    #expect(plan.steps[0].state == .proposed, "plan approval must not flip destructive steps")
    let action = AgentExecutor.nextAction(
      plan: plan, decisions: [.annotate: available(.annotate)], sourceDigestMatches: true)
    if case .escalate = action { } else { Issue.record("expected escalate") }
  }

  @Test("Planner maps fill language to a complete-document plan")
  func plannerProposesCompleteDocument() {
    let request = AgentPlanRequest(
      query: "fill out this form", intent: .complete, scope: .single, sourceDigest: "d",
      hasProfile: true, hasCandidates: true, hasOperations: false, canExport: false)
    if case .plan(let plan) = DeterministicAgentPlanner.propose(request: request) {
      #expect(plan.goal == .completeDocument)
      #expect(plan.steps.count == 3)
      #expect(plan.state == .awaitingApproval, "proposals must await human approval")
    } else {
      Issue.record("expected a plan proposal")
    }
  }

  @Test("Planner degrades open-ended input to command search, stated plainly")
  func plannerDegradesUnknownGoals() {
    let request = AgentPlanRequest(
      query: "make the sky purple", intent: .read, scope: .single, sourceDigest: "d",
      hasProfile: false, hasCandidates: false, hasOperations: false, canExport: false)
    if case .commandSearch = DeterministicAgentPlanner.propose(request: request) { } else {
      Issue.record("expected commandSearch fallback")
    }
  }
}
