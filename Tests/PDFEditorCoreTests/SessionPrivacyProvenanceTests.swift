import Foundation
import Testing

@testable import PDFEditorCore

struct SessionPrivacyProvenanceTests {
  private let digest = String(repeating: "a", count: 64)
  private let outputDigest = String(repeating: "b", count: 64)
  private let provider = PDFProviderDescriptor(
    id: "pdfkit", version: "test", platform: "macOS",
    capabilities: ["session-provenance"])

  private func record(exportState: PDFSessionExportState = .notAttempted) -> PDFSessionPrivacyProvenance {
    let export = exportState == .notAttempted
      ? PDFSessionExportProvenance(
        state: .notAttempted,
        sourceDigest: digest,
        storage: .notApplicable,
        validation: .notRun)
      : PDFSessionExportProvenance(
        state: .succeeded,
        sourceDigest: digest,
        outputDigest: outputDigest,
        storage: .localFile,
        validation: .validated,
        outputReopenable: true,
        operationCount: 2,
        exporterID: provider.id,
        validationProviderID: provider.id)
    return PDFSessionPrivacyProvenanceBuilder.build(
      sessionID: "session-test-1",
      sourceDigest: digest,
      provider: provider,
      generatedAt: "2026-08-25T00:00:00.000Z",
      processing: PDFSessionProcessingProvenance(
        locality: .localDevice,
        sourceInput: "local-file",
        dataEgress: .none),
      sourceRetention: PDFSessionSourceRetentionProvenance(
        state: .inMemorySession,
        retainedUntilSessionEnd: true,
        deletion: .pending),
      export: export)
  }

  @Test func provenanceRoundTripsWithoutContentValues() throws {
    let original = record(exportState: .succeeded)
    try PDFSessionPrivacyProvenanceValidator.validate(original, expectedSourceDigest: digest)
    let encoded = try JSONEncoder().encode(original)
    let serialized = String(decoding: encoded, as: UTF8.self)
    #expect(!serialized.contains("\"sourceBytes\":"))
    #expect(!serialized.contains("\"documentText\":"))
    #expect(!serialized.contains("\"ocrText\":"))
    #expect(!serialized.contains("\"fieldValues\":"))
    #expect(!serialized.contains("\"fileName\":"))
    #expect(serialized.contains("\"sourceBytesIncluded\":false"))
    #expect(serialized.contains("\"fieldValuesIncluded\":false"))
    #expect(!serialized.contains("https://"))
    let decoded = try JSONDecoder().decode(PDFSessionPrivacyProvenance.self, from: encoded)
    #expect(decoded == original)
  }

  @Test func notAttemptedExportIsDistinctFromSuccessfulExport() throws {
    let notAttempted = record()
    try PDFSessionPrivacyProvenanceValidator.validate(notAttempted)
    #expect(notAttempted.payload.export.outputDigest == nil)

    let completed = record(exportState: .succeeded)
    try PDFSessionPrivacyProvenanceValidator.validate(completed)
    #expect(completed.payload.export.outputDigest == outputDigest)
  }

  @Test func unknownProviderStateIsRepresentableWithoutBecomingLocal() throws {
    let original = record()
    let unknown = PDFSessionPrivacyProvenancePayload(
      processing: PDFSessionProcessingProvenance(
        locality: .unknown,
        sourceInput: "unknown",
        dataEgress: .unknown),
      ocr: PDFSessionOCRProvenance(state: .unknown),
      sourceRetention: PDFSessionSourceRetentionProvenance(
        state: .unknown,
        retainedUntilSessionEnd: false,
        deletion: .unknown,
        sourceCopyCount: 0),
      export: original.payload.export)
    let record = PDFSessionPrivacyProvenance(header: original.header, payload: unknown)
    try PDFSessionPrivacyProvenanceValidator.validate(record)
    #expect(record.payload.processing.locality == .unknown)
    #expect(record.payload.ocr.state == .unknown)
    #expect(record.payload.sourceRetention.state == .unknown)
  }

  @Test func staleDigestAndContradictoryClaimsAreRejected() throws {
    let original = record()
    let staleHeader = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: original.header.sessionID,
        sourceDigest: String(repeating: "c", count: 64),
        provider: provider,
        generatedAt: original.header.generatedAt),
      payload: original.payload)
    #expect(throws: PDFSessionPrivacyProvenanceError.sourceMismatch) {
      try PDFSessionPrivacyProvenanceValidator.validate(staleHeader, expectedSourceDigest: digest)
    }

    let leaked = PDFSessionPrivacyFlags(fieldValuesIncluded: true)
    let leakedPayload = PDFSessionPrivacyProvenancePayload(
      privacy: leaked,
      processing: original.payload.processing,
      ocr: original.payload.ocr,
      sourceRetention: original.payload.sourceRetention,
      export: original.payload.export)
    let leakedRecord = PDFSessionPrivacyProvenance(header: original.header, payload: leakedPayload)
    #expect(throws: PDFSessionPrivacyProvenanceError.privacyLeakFlag) {
      try PDFSessionPrivacyProvenanceValidator.validate(leakedRecord)
    }

    let missingOutput = PDFSessionExportProvenance(
      state: .succeeded,
      sourceDigest: digest,
      storage: .localFile,
      validation: .validated,
      outputReopenable: true)
    let invalidPayload = PDFSessionPrivacyProvenancePayload(
      processing: original.payload.processing,
      ocr: original.payload.ocr,
      sourceRetention: original.payload.sourceRetention,
      export: missingOutput)
    let invalidRecord = PDFSessionPrivacyProvenance(header: original.header, payload: invalidPayload)
    #expect(throws: PDFSessionPrivacyProvenanceError.invalidExportState) {
      try PDFSessionPrivacyProvenanceValidator.validate(invalidRecord)
    }
  }

  @Test func documentSessionCarriesThePrivacyProvenance() throws {
    let source = DocumentSource(fileName: "private.pdf", byteCount: 1, sha256: digest)
    let session = DocumentSession(
      sourceArtifact: DocumentSessionSourceArtifact(source: source),
      privacyProvenance: record())
    let envelope = DocumentSessionRecoveryEnvelope(session: session)
    let decoded = try JSONDecoder().decode(
      DocumentSessionRecoveryEnvelope.self,
      from: JSONEncoder().encode(envelope))
    #expect(decoded.session.privacyProvenance == session.privacyProvenance)
  }
}
