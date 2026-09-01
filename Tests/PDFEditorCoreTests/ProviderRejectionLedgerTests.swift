import Foundation
import Testing

@testable import PDFEditorCore

struct ProviderRejectionLedgerTests {
  private struct Fixture: Decodable {
    let ledgerID: String
    let sourceDigest: String
    let ledgers: [String: ProviderDefinition]
  }

  private struct ProviderDefinition: Decodable {
    let attempts: [PDFProviderRejectionAttempt]
  }

  private func fixture() throws -> Fixture {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let fixtureURL = repositoryRoot.appendingPathComponent("Tests/fixtures/provider_rejection_ledger_fixture.json")
    return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL))
  }

  private func makeLedgers() throws -> [PDFProviderRejectionLedger] {
    let value = try fixture()
    return try value.ledgers.keys.sorted().map { key in
      let definition = value.ledgers[key]!
      return try PDFProviderRejectionLedger(
        ledgerID: "\(value.ledgerID)-\(definition.attempts[0].providerKind.rawValue)",
        sourceDigest: value.sourceDigest,
        attempts: definition.attempts)
    }
  }

  @Test("Native oracle decodes the shared native/browser/companion rejection fixture")
  func sharedFixture() throws {
    let ledgers = try makeLedgers()
    #expect(ledgers.count == 3)
    let codesByProvider = Dictionary(uniqueKeysWithValues: ledgers.map { ledger in
      (ledger.attempts[0].providerID, ledger.attempts.map { $0.rejection?.code.rawValue })
    })
    #expect(codesByProvider["pdfkit"] == ["staleSourceDigest", "unsupportedOperation"])
    #expect(codesByProvider["pdfjs-pdflib"] == ["staleSourceDigest", "unsupportedOperation"])
    #expect(codesByProvider["companion-pdfbox"] == ["staleSourceDigest", "providerUnavailable"])
  }

  @Test("Native comparison preserves convergence and provider divergence")
  func comparison() throws {
    let report = try PDFRejectionLedgerOracle.compare(makeLedgers())
    #expect(report.providerCount == 3)
    #expect(report.providerSummaries.keys.sorted() == ["companion-pdfbox", "pdfjs-pdflib", "pdfkit"])
    #expect(report.caseCount == 2)
    #expect(report.comparisonCount == 6)
    #expect(report.comparableCount == 6)
    #expect(report.equivalentCount == 4)
    #expect(report.disagreementCount == 2)
    #expect(report.unknownCount == 0)

    let stale = report.comparisons.filter { $0.caseID == "stale-source" }
    #expect(stale.count == 3)
    #expect(stale.allSatisfy { $0.equivalent })
  }

  @Test("Native normalization is idempotent and strips provider-only output identity")
  func normalizationIsIdempotent() throws {
    let first = try makeLedgers()[0].attempts[0]
    let encoded = try JSONEncoder().encode(first)
    let decoded = try JSONDecoder().decode(PDFNormalizedRejectionAttempt.self, from: encoded)
    let second = try PDFRejectionLedgerOracle.normalize(PDFProviderRejectionAttempt(
      attemptID: decoded.attemptID,
      caseID: decoded.caseID,
      providerID: decoded.providerID,
      providerKind: decoded.providerKind,
      capability: decoded.capability,
      phase: decoded.phase,
      state: decoded.state,
      sourceDigest: decoded.sourceDigest,
      operationLineage: decoded.operationLineage,
      code: decoded.rejection?.code.rawValue))
    #expect(second.rejection?.code == .staleSourceDigest)
    #expect(second.operationLineageSignature == first.operationLineageSignature)
  }

  @Test("Native oracle records unknown provider reasons without promoting them")
  func unknownReasonsRemainVisible() throws {
    let value = try fixture()
    let attempt = value.ledgers["native"]!.attempts[0]
    let unknown = try PDFRejectionLedgerOracle.normalize(PDFProviderRejectionAttempt(
      attemptID: "unknown-native",
      caseID: attempt.caseID,
      providerID: attempt.providerID,
      providerKind: attempt.providerKind,
      capability: attempt.capability,
      phase: attempt.phase,
      state: .rejected,
      sourceDigest: attempt.sourceDigest,
      operationLineage: attempt.operationLineage,
      reasonCodes: ["opaqueProviderReason"]))
    #expect(unknown.rejection?.code == .unknownRejection)
    #expect(unknown.rejection?.unknownProviderReasonCodeCount == 1)
  }

  @Test("Native ledger rejects mixed provider provenance")
  func mixedProviderLedgerRejected() throws {
    let value = try fixture()
    let mixed = value.ledgers["native"]!.attempts + value.ledgers["browser"]!.attempts
    do {
      _ = try PDFProviderRejectionLedger(
        ledgerID: "mixed-provider-ledger",
        sourceDigest: value.sourceDigest,
        attempts: mixed)
      #expect(Bool(false), "mixed provider ledger must be rejected")
    } catch let error as PDFRejectionLedgerError {
      #expect(error == .invalid("all attempts in a ledger must belong to one provider"))
    }
  }
}
