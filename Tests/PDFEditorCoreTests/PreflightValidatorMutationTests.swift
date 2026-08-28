import Foundation
import PDFEditorCore
import Testing

/// RG-127: S3 mutation tests for the preflight validator.
@Suite("Preflight Validator Mutation Tests")
struct PreflightValidatorMutationTests {

  private let emptySummary = PDFPreflightSummary(
    findingCount: 0, warningCount: 0, blockedCount: 0, unknownCount: 0,
    metadataFieldCount: 0, embeddedDataCount: 0, networkBoundaryCount: 0,
    activeContentCount: 0, unknownCoverageCount: 0
  )

  private func validReport() -> PDFPreflightReport {
    PDFPreflightReport(
      header: PDFPreflightHeader(
        sourceDigest: String(repeating: "a", count: 64),
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: PDFPreflightPayload(
        summary: emptySummary,
        metadata: PDFPreflightPayload.Metadata(fields: [:]),
        embeddedData: PDFPreflightEmbeddedData(attachmentCount: 0, possibleTokenCounts: [:]),
        networkBoundaries: PDFPreflightNetworkBoundaries(
          externalURLCount: 0, safeExternalURLCount: 0, unsafeExternalURLCount: 0,
          internalPageLinkCount: 0, unknownDestinationCount: 0, possibleActionTokenCounts: [:]
        ),
        activeContent: PDFPreflightActiveContent(possibleActionTokenCounts: [:], executionAttempted: false),
        security: PDFPreflightSecurity(encrypted: false, locked: false, permissionsObserved: false),
        sanitization: PDFPreflightSanitization(status: .notRun, safeToClaimClean: false, sourceUnchanged: true, limits: []),
        findings: []
      )
    )
  }

  @Test("MUT-PF-01: Invalid digest is rejected")
  func invalidDigest() {
    let report = PDFPreflightReport(
      header: PDFPreflightHeader(
        sourceDigest: "not-a-valid-digest",
        provider: PDFProviderDescriptor(id: "test", version: "1.0", platform: "macOS"),
        generatedAt: "2026-08-26T00:00:00Z"
      ),
      payload: validReport().payload
    )
    #expect(throws: PDFPreflightValidationError.invalidDigest) { try PDFPreflightValidator.validate(report) }
  }

  @Test("MUT-PF-02: Sanitization completed is rejected")
  func sanitizationCompleted() {
    let report = PDFPreflightReport(
      header: validReport().header,
      payload: PDFPreflightPayload(
        summary: emptySummary,
        metadata: PDFPreflightPayload.Metadata(fields: [:]),
        embeddedData: PDFPreflightEmbeddedData(attachmentCount: 0, possibleTokenCounts: [:]),
        networkBoundaries: PDFPreflightNetworkBoundaries(
          externalURLCount: 0, safeExternalURLCount: 0, unsafeExternalURLCount: 0,
          internalPageLinkCount: 0, unknownDestinationCount: 0, possibleActionTokenCounts: [:]
        ),
        activeContent: PDFPreflightActiveContent(possibleActionTokenCounts: [:], executionAttempted: false),
        security: PDFPreflightSecurity(encrypted: false, locked: false, permissionsObserved: false),
        sanitization: PDFPreflightSanitization(status: .completed, safeToClaimClean: false, sourceUnchanged: true, limits: []),
        findings: []
      )
    )
    #expect(throws: PDFPreflightValidationError.sanitizationStateNotAllowed) { try PDFPreflightValidator.validate(report) }
  }

  @Test("MUT-PF-03: Clean claim not allowed is rejected")
  func cleanClaimNotAllowed() {
    let report = PDFPreflightReport(
      header: validReport().header,
      payload: PDFPreflightPayload(
        summary: emptySummary,
        metadata: PDFPreflightPayload.Metadata(fields: [:]),
        embeddedData: PDFPreflightEmbeddedData(attachmentCount: 0, possibleTokenCounts: [:]),
        networkBoundaries: PDFPreflightNetworkBoundaries(
          externalURLCount: 0, safeExternalURLCount: 0, unsafeExternalURLCount: 0,
          internalPageLinkCount: 0, unknownDestinationCount: 0, possibleActionTokenCounts: [:]
        ),
        activeContent: PDFPreflightActiveContent(possibleActionTokenCounts: [:], executionAttempted: false),
        security: PDFPreflightSecurity(encrypted: false, locked: false, permissionsObserved: false),
        sanitization: PDFPreflightSanitization(status: .notRun, safeToClaimClean: true, sourceUnchanged: true, limits: []),
        findings: []
      )
    )
    #expect(throws: PDFPreflightValidationError.cleanClaimNotAllowed) { try PDFPreflightValidator.validate(report) }
  }

  @Test("MUT-PF-04: Active content executed is rejected")
  func activeContentExecuted() {
    let report = PDFPreflightReport(
      header: validReport().header,
      payload: PDFPreflightPayload(
        summary: emptySummary,
        metadata: PDFPreflightPayload.Metadata(fields: [:]),
        embeddedData: PDFPreflightEmbeddedData(attachmentCount: 0, possibleTokenCounts: [:]),
        networkBoundaries: PDFPreflightNetworkBoundaries(
          externalURLCount: 0, safeExternalURLCount: 0, unsafeExternalURLCount: 0,
          internalPageLinkCount: 0, unknownDestinationCount: 0, possibleActionTokenCounts: [:]
        ),
        activeContent: PDFPreflightActiveContent(possibleActionTokenCounts: [:], executionAttempted: true),
        security: PDFPreflightSecurity(encrypted: false, locked: false, permissionsObserved: false),
        sanitization: PDFPreflightSanitization(status: .notRun, safeToClaimClean: false, sourceUnchanged: true, limits: []),
        findings: []
      )
    )
    #expect(throws: PDFPreflightValidationError.activeContentExecuted) { try PDFPreflightValidator.validate(report) }
  }

  @Test("MUT-PF-05: Source unchanged false is rejected")
  func sourceUnchangedFalse() {
    let report = PDFPreflightReport(
      header: validReport().header,
      payload: PDFPreflightPayload(
        summary: emptySummary,
        metadata: PDFPreflightPayload.Metadata(fields: [:]),
        embeddedData: PDFPreflightEmbeddedData(attachmentCount: 0, possibleTokenCounts: [:]),
        networkBoundaries: PDFPreflightNetworkBoundaries(
          externalURLCount: 0, safeExternalURLCount: 0, unsafeExternalURLCount: 0,
          internalPageLinkCount: 0, unknownDestinationCount: 0, possibleActionTokenCounts: [:]
        ),
        activeContent: PDFPreflightActiveContent(possibleActionTokenCounts: [:], executionAttempted: false),
        security: PDFPreflightSecurity(encrypted: false, locked: false, permissionsObserved: false),
        sanitization: PDFPreflightSanitization(status: .notRun, safeToClaimClean: false, sourceUnchanged: false, limits: []),
        findings: []
      )
    )
    #expect(throws: PDFPreflightValidationError.sanitizationStateNotAllowed) { try PDFPreflightValidator.validate(report) }
  }

  @Test("MUT-PF-06: Valid report passes validation")
  func validReportPasses() throws {
    try PDFPreflightValidator.validate(validReport())
  }
}
