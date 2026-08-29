import Foundation
import PDFEditorCore
import Testing

/// RG-127: S3 mutation tests for privacy provenance and preflight validators.
///
/// Each mutation proves the validator is not merely present but actively
/// kills a specific tampering pattern.
///
/// Evidence sensitivity: S3 (deliberate mutations produce expected failures).
@Suite("Privacy Provenance & Preflight Mutation Tests")
struct PrivacyProvenanceMutationTests {

  // MARK: - Privacy Provenance Validator Mutations

  @Test("MUT-PP-01: Tampered source digest is rejected (S3 mutation)")
  func tamperedDigest() {
    // Build a valid record first
    let header = PDFSessionPrivacyProvenanceHeader(
      sessionID: "test-session",
      sourceDigest: String(repeating: "a", count: 64),
      provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
      generatedAt: "2026-08-26T00:00:00Z"
    )
    let payload = PDFSessionPrivacyProvenancePayload(
      processing: PDFSessionProcessingProvenance(
        locality: .localDevice,
        sourceInput: "test.pdf",
        dataEgress: .none
      ),
      sourceRetention: PDFSessionSourceRetentionProvenance(
        state: .inMemorySession,
        retainedUntilSessionEnd: true,
        deletion: .notApplicable
      ),
      export: PDFSessionExportProvenance(
        state: .notAttempted,
        sourceDigest: String(repeating: "a", count: 64),
        storage: .notApplicable,
        validation: .notRun
      )
    )
    let record = PDFSessionPrivacyProvenance(header: header, payload: payload)

    // Sanity: a valid, untampered record passes
    #expect(throws: Never.self) {
      try PDFSessionPrivacyProvenanceValidator.validate(record)
    }

    // S3 mutation: a record whose header digest diverges from the export digest
    // must be rejected — proves the validator actively catches tampering, not
    // merely that it exists (RG-127).
    let tampered = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "test-session",
        sourceDigest: String(repeating: "b", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: payload
    )
    #expect(throws: PDFSessionPrivacyProvenanceError.sourceMismatch) {
      try PDFSessionPrivacyProvenanceValidator.validate(tampered)
    }
  }

  @Test("MUT-PP-02: Empty session ID is rejected")
  func emptySessionID() {
    let record = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "", // Empty
        sourceDigest: String(repeating: "a", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFSessionPrivacyProvenancePayload(
        processing: PDFSessionProcessingProvenance(
          locality: .localDevice,
          sourceInput: "test.pdf",
          dataEgress: .none
        ),
        sourceRetention: PDFSessionSourceRetentionProvenance(
          state: .inMemorySession,
          retainedUntilSessionEnd: true,
          deletion: .notApplicable
        ),
        export: PDFSessionExportProvenance(
          state: .notAttempted,
          sourceDigest: String(repeating: "a", count: 64),
          storage: .notApplicable,
          validation: .notRun
        )
      )
    )

    #expect(throws: PDFSessionPrivacyProvenanceError.invalidSessionID) {
      try PDFSessionPrivacyProvenanceValidator.validate(record)
    }
  }

  @Test("MUT-PP-03: Privacy leak flag is rejected")
  func privacyLeakFlag() {
    let record = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "test-session",
        sourceDigest: String(repeating: "a", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFSessionPrivacyProvenancePayload(
        privacy: PDFSessionPrivacyFlags(
          sourceBytesIncluded: true // Leak!
        ),
        processing: PDFSessionProcessingProvenance(
          locality: .localDevice,
          sourceInput: "test.pdf",
          dataEgress: .none
        ),
        sourceRetention: PDFSessionSourceRetentionProvenance(
          state: .inMemorySession,
          retainedUntilSessionEnd: true,
          deletion: .notApplicable
        ),
        export: PDFSessionExportProvenance(
          state: .notAttempted,
          sourceDigest: String(repeating: "a", count: 64),
          storage: .notApplicable,
          validation: .notRun
        )
      )
    )

    #expect(throws: PDFSessionPrivacyProvenanceError.privacyLeakFlag) {
      try PDFSessionPrivacyProvenanceValidator.validate(record)
    }
  }

  @Test("MUT-PP-04: Source mismatch is rejected")
  func sourceMismatch() {
    let record = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "test-session",
        sourceDigest: String(repeating: "a", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFSessionPrivacyProvenancePayload(
        processing: PDFSessionProcessingProvenance(
          locality: .localDevice,
          sourceInput: "test.pdf",
          dataEgress: .none
        ),
        sourceRetention: PDFSessionSourceRetentionProvenance(
          state: .inMemorySession,
          retainedUntilSessionEnd: true,
          deletion: .notApplicable
        ),
        export: PDFSessionExportProvenance(
          state: .notAttempted,
          sourceDigest: String(repeating: "b", count: 64), // Different!
          storage: .notApplicable,
          validation: .notRun
        )
      )
    )

    #expect(throws: PDFSessionPrivacyProvenanceError.sourceMismatch) {
      try PDFSessionPrivacyProvenanceValidator.validate(record)
    }
  }

  @Test("MUT-PP-05: Invalid digest is rejected")
  func invalidDigest() {
    let record = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "test-session",
        sourceDigest: "not-a-valid-digest", // Invalid
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFSessionPrivacyProvenancePayload(
        processing: PDFSessionProcessingProvenance(
          locality: .localDevice,
          sourceInput: "test.pdf",
          dataEgress: .none
        ),
        sourceRetention: PDFSessionSourceRetentionProvenance(
          state: .inMemorySession,
          retainedUntilSessionEnd: true,
          deletion: .notApplicable
        ),
        export: PDFSessionExportProvenance(
          state: .notAttempted,
          sourceDigest: "not-a-valid-digest",
          storage: .notApplicable,
          validation: .notRun
        )
      )
    )

    #expect(throws: PDFSessionPrivacyProvenanceError.invalidDigest) {
      try PDFSessionPrivacyProvenanceValidator.validate(record)
    }
  }

  @Test("MUT-PP-06: OCR state inconsistency is rejected")
  func ocrStateInconsistency() {
    let record = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "test-session",
        sourceDigest: String(repeating: "a", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFSessionPrivacyProvenancePayload(
        processing: PDFSessionProcessingProvenance(
          locality: .localDevice,
          sourceInput: "test.pdf",
          dataEgress: .none
        ),
        ocr: PDFSessionOCRProvenance(
          state: .notUsed, // Says not used
          providerIDs: ["Vision"], // But has provider
          processedPageCount: 5 // And processed pages
        ),
        sourceRetention: PDFSessionSourceRetentionProvenance(
          state: .inMemorySession,
          retainedUntilSessionEnd: true,
          deletion: .notApplicable
        ),
        export: PDFSessionExportProvenance(
          state: .notAttempted,
          sourceDigest: String(repeating: "a", count: 64),
          storage: .notApplicable,
          validation: .notRun
        )
      )
    )

    #expect(throws: PDFSessionPrivacyProvenanceError.invalidOCRState) {
      try PDFSessionPrivacyProvenanceValidator.validate(record)
    }
  }

  @Test("MUT-PP-07: Valid record passes validation")
  func validRecordPasses() throws {
    let record = PDFSessionPrivacyProvenance(
      header: PDFSessionPrivacyProvenanceHeader(
        sessionID: "test-session",
        sourceDigest: String(repeating: "a", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFSessionPrivacyProvenancePayload(
        processing: PDFSessionProcessingProvenance(
          locality: .localDevice,
          sourceInput: "test.pdf",
          dataEgress: .none
        ),
        sourceRetention: PDFSessionSourceRetentionProvenance(
          state: .inMemorySession,
          retainedUntilSessionEnd: true,
          deletion: .notApplicable
        ),
        export: PDFSessionExportProvenance(
          state: .notAttempted,
          sourceDigest: String(repeating: "a", count: 64),
          storage: .notApplicable,
          validation: .notRun
        )
      )
    )

    // Should not throw
    try PDFSessionPrivacyProvenanceValidator.validate(record)
  }
}
