import Foundation
import Testing
@testable import PDFEditorCore

/// R7 assist lane: explanation cards and label canonicalization must remain
/// deterministic-first, with model paths strictly additive.
struct LocalAssistLaneTests {

  private func candidateWithEvidence() -> RegionCandidate {
    RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 100, y: 500, width: 200, height: 20),
      kind: .vectorRegion,
      score: 0.80,
      evidence: ["Vector bounding box (200x20pt)."],
      entryMode: .singleText,
      labelText: "Full Name:",
      groupMemberCount: 1,
      memberBounds: [],
      evidenceItems: [
        CandidateEvidence(
          kind: .vectorRectangle, origin: .geometryExtraction,
          summary: "Vector rectangle", region: nil, score: 0.80),
        CandidateEvidence(
          kind: .textLabel, origin: .textExtraction,
          summary: "Semantically plausible field label",
          region: nil, text: "Full Name:", score: 0.72),
      ]
    )
  }

  @Test func explainerCardNamesTheSuggestionAndCitesEvidence() {
    let card = SuggestionExplainer.explain(candidateWithEvidence())

    #expect(card.title == "Full Name")
    #expect(card.reasons.contains { $0.contains("drawn geometry") })
    #expect(card.reasons.contains { $0.contains("label") })
    #expect(card.providerID == SuggestionExplainer.providerID)
  }

  @Test func explainerFlagsWeakEvidenceInsteadOfHidingIt() {
    let weak = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 50, height: 14),
      kind: .textAnchored, score: 0.45, evidence: [],
      labelText: "Ref:"
    )
    let card = SuggestionExplainer.explain(weak)
    // Single evidence family ⇒ a visible caution, never a confident claim.
    #expect(card.cautions.isEmpty == false)
  }

  @Test func deterministicAssistMirrorsCanonicalizer() async {
    let assist = DeterministicLabelAssist()
    let result = await assist.proposeCanonicalForm(for: "1. FULL NAME:____")
    #expect(result?.displayName == "Full Name")

    // Generic layout text stays rejected at the baseline.
    let generic = await assist.proposeCanonicalForm(for: "Section:")
    #expect(generic == nil)
  }

  @Test func assistServiceAlwaysReturnsDeterministicResultOffline() async {
    // On every machine — including those without a usable on-device model —
    // the service must return the deterministic canonicalization.
    let result = await LabelAssistService.canonicalize("APPLICANT NAME:")
    #expect(result?.displayName == "Applicant Name")
  }
}
