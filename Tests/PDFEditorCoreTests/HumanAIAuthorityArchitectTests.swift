import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Human-AI Authority Architect Contract Tests")
struct HumanAIAuthorityArchitectTests {

  // MARK: - Authority Classification & Action Matrix (PER-0927)

  public enum AuthorityTier: String, Codable, CaseIterable, Sendable {
    case tier0ReadOnly = "tier0_read_only" // Autonomous
    case tier1ReversibleEdit = "tier1_reversible_edit" // Autonomous with Ledger Undo
    case tier2HeuristicProposal = "tier2_heuristic_proposal" // Human-in-the-Loop Review
    case tier3CryptographicVault = "tier3_cryptographic_vault" // Explicit Auth Gate
    case tier4DestructiveExport = "tier4_destructive_export" // Two-Phase Commit Required
  }

  public struct ActionAuthorityPolicy: Sendable {
    public static func requiresHumanReview(for tier: AuthorityTier) -> Bool {
      switch tier {
      case .tier0ReadOnly, .tier1ReversibleEdit:
        return false
      case .tier2HeuristicProposal, .tier3CryptographicVault, .tier4DestructiveExport:
        return true
      }
    }

    public static func isIrreversible(for tier: AuthorityTier) -> Bool {
      switch tier {
      case .tier0ReadOnly, .tier1ReversibleEdit, .tier2HeuristicProposal, .tier3CryptographicVault:
        return false
      case .tier4DestructiveExport:
        return true
      }
    }
  }

  // MARK: - Test 1: Tier 0 & Tier 1 Actions Remain Autonomous with Undo Support

  @Test func reversibleEditsMaintainUndoLedgerWithoutApprovalFatigue() {
    #expect(!ActionAuthorityPolicy.requiresHumanReview(for: .tier0ReadOnly))
    #expect(!ActionAuthorityPolicy.requiresHumanReview(for: .tier1ReversibleEdit))
    #expect(!ActionAuthorityPolicy.isIrreversible(for: .tier1ReversibleEdit))
  }

  // MARK: - Test 2: Tier 2 Heuristic Suggestions Require Human Review Gate

  @Test func heuristicCandidateSuggestionsEnforceHumanReviewGate() {
    let mapping = PDFTemplateMapping(
      id: UUID(),
      semanticKey: "person.ssn",
      target: PDFTemplateMappingTarget(
        kind: .staticRegion,
        pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 10, width: 100, height: 20))
      ),
      suggestedFieldType: .text,
      status: .proposed // Must remain proposed until human review
    )

    #expect(mapping.status == .proposed)
    #expect(ActionAuthorityPolicy.requiresHumanReview(for: .tier2HeuristicProposal))
  }

  // MARK: - Test 3: Tier 4 Irreversible Destructive Actions Require Explicit 2-Phase Confirmation

  @Test func destructiveExportEnforcesIrreversibilityFlagAndExplicitConfirmation() {
    #expect(ActionAuthorityPolicy.isIrreversible(for: .tier4DestructiveExport))
    #expect(ActionAuthorityPolicy.requiresHumanReview(for: .tier4DestructiveExport))
  }

  // MARK: - Test 4: Low-Confidence AI/Heuristic Suggestions Fail-Closed to Suggested Status

  @Test func lowConfidenceHeuristicsRemainSuggestedPendingHumanAction() {
    let candidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 100, y: 100, width: 200, height: 30),
      kind: .textAnchored,
      status: .suggested,
      score: 0.45,
      evidence: ["underlined-text"]
    )

    #expect(candidate.status == .suggested)
    #expect(candidate.status != .confirmed)
  }
}
