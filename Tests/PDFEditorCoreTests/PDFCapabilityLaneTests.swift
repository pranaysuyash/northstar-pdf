import Testing
@testable import PDFEditorCore

struct PDFCapabilityLaneTests {
  @Test func unavailableAdvancedLaneRemainsTypedAndReviewBound() throws {
    let request = PDFCapabilityRequest(
      lane: .textReflow,
      sourceDigest: String(repeating: "a", count: 64),
      operationKinds: ["textRunReplacement"],
      source: ProviderSourceFacts(byteCount: 100, pageCount: 1, isEncrypted: false, isScanned: false),
      policy: ProviderCapabilityPolicy(localOnly: true, minimumState: .enabled, allowExperimental: false))
    try request.validate()
    let record = PDFCapabilityOutcomeRecord(
      lane: .textReflow,
      sourceDigest: request.sourceDigest,
      outcome: .unknown,
      reasonCodes: ["noEligibleLocalProvider"],
      requiresReview: true)
    try record.validate()
    #expect(record.outcome == .unknown)
    #expect(record.requiresReview)
  }
}
