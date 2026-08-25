import AppKit
import Foundation
import PDFKit
import Testing

@testable import PDFEditorCore

struct PDFEditorCoreTests {
  @Test func sharedDocumentContractRoundTripsAndNegotiatesVersion() throws {
    let source = DocumentSource(
      fileName: "form.pdf", byteCount: 123, sha256: String(repeating: "a", count: 64))
    let provider = PDFProviderDescriptor(
      id: "pdfkit",
      version: "macOS",
      platform: "macOS",
      capabilities: ["render", "forms"]
    )
    let region = PDFPageRegion(
      pageIndex: 0,
      rect: PDFRect(x: 72, y: 640, width: 220, height: 24),
      coordinateSpace: PDFCoordinateSpace(rotationDegrees: 90)
    )
    let evidence = CandidateEvidence(
      kind: .textLabel,
      origin: .textExtraction,
      summary: "A nearby label ends with a colon.",
      region: region,
      text: "Applicant name:",
      score: 0.91,
      provider: provider
    )
    let candidate = RegionCandidate(
      pageIndex: 0,
      bounds: region.rect,
      kind: .textAnchored,
      score: 0.91,
      evidence: [evidence.summary],
      coordinate: region,
      suggestedFieldType: .text,
      evidenceItems: [evidence],
      sourceDigest: source.sha256
    )
    let inspection = DocumentInspection(
      source: source,
      pages: [
        PageSnapshot(
          pageIndex: 0,
          pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil,
          bleedBox: nil,
          trimBox: nil,
          artBox: nil,
          rotation: 90,
          characterCount: 42,
          annotationCount: 0,
          hasSelectableText: true
        )
      ],
      fields: [],
      candidates: [candidate],
      warnings: []
    )
    let contract = PDFDocumentContract(
      header: PDFContractHeader(
        contractName: "pdf-editor.document",
        sourceDigest: source.sha256,
        generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        provider: provider
      ),
      payload: inspection
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(contract)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(PDFDocumentContract.self, from: data)

    #expect(decoded.header.version == .current)
    #expect(decoded.header.sourceDigest == source.sha256)
    #expect(decoded.payload == inspection)
    #expect(decoded.payload.candidates[0].evidenceItems == [evidence])
    #expect(decoded.payload.candidates[0].coordinate == region)
    #expect(decoded.isReadableBy())
    #expect(!PDFContractVersion(major: 2, minor: 0).isReadableBy())
  }

  @Test func candidateContractDecodesOlderPayloadWithoutNewEvidenceFields() throws {
    let candidateID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    let json = """
      {
        "id": "\(candidateID.uuidString)",
        "pageIndex": 0,
        "bounds": {"x": 72, "y": 640, "width": 220, "height": 24},
        "kind": "textAnchored",
        "status": "suggested",
        "score": 0.45,
        "evidence": ["Text contains an underline-like blank marker."]
      }
      """.data(using: .utf8)!

    let candidate = try JSONDecoder().decode(RegionCandidate.self, from: json)

    #expect(candidate.id == candidateID)
    #expect(candidate.evidenceItems.isEmpty)
    #expect(candidate.coordinate == nil)
    #expect(candidate.suggestedFieldType == nil)
    #expect(candidate.sourceDigest == nil)
  }

  @Test func editSessionAndValidationContractsRoundTripStructuredPayload() throws {
    let source = DocumentSource(
      fileName: "source.pdf", byteCount: 64, sha256: String(repeating: "b", count: 64))
    let provider = PDFProviderDescriptor(id: "pdfjs-pdflib", version: "test", platform: "web")
    let sessionID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    let operation = EditOperation(
      pageIndex: 0,
      targetID: "contact-method",
      kind: .nativeFieldValue,
      value: "email",
      bounds: PDFRect(x: 72, y: 600, width: 100, height: 18),
      sessionID: sessionID,
      sourceDigest: source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 72, y: 600, width: 100, height: 18)),
      payload: .choice("email")
    )
    let session = PDFEditSessionContract(
      source: source,
      provider: provider,
      operations: [operation],
      generatedAt: Date(timeIntervalSince1970: 1_700_000_001)
    )
    let check = ValidationCheck(
      kind: .appliedOperations,
      status: .passed,
      message: "The selected field value was retained after reopen.",
      operationIDs: [operation.id]
    )
    let report = ValidationReport(
      status: .validated,
      messages: [],
      sourceUnchanged: true,
      outputReopenable: true,
      checks: [check],
      sourceDigest: source.sha256,
      outputDigest: String(repeating: "c", count: 64),
      provider: provider,
      validatedAt: Date(timeIntervalSince1970: 1_700_000_002),
      operationIDs: [operation.id]
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let sessionData = try encoder.encode(session)
    let reportData = try encoder.encode(report)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedSession = try decoder.decode(PDFEditSessionContract.self, from: sessionData)
    let decodedReport = try decoder.decode(ValidationReport.self, from: reportData)

    #expect(decodedSession.header.contractName == "pdf-editor.edit-session")
    #expect(decodedSession.source == source)
    #expect(decodedSession.operations[0].payload == .choice("email"))
    #expect(decodedSession.operations[0].sourceDigest == source.sha256)
    #expect(decodedReport.checks == [check])
    #expect(decodedReport.outputDigest == String(repeating: "c", count: 64))
    #expect(decodedReport.operationIDs == [operation.id])
  }

  @Test func templateFingerprintMappingAndProfileContractsRoundTripSafely() throws {
    let source = DocumentSource(
      fileName: "recurring-form.pdf",
      byteCount: 2048,
      sha256: String(repeating: "d", count: 64)
    )
    let provider = PDFProviderDescriptor(id: "pdfkit", version: "test", platform: "macOS")
    let pageRegion = PDFPageRegion(
      pageIndex: 0,
      rect: PDFRect(x: 120, y: 540, width: 220, height: 20)
    )
    let candidate = RegionCandidate(
      pageIndex: 0,
      bounds: pageRegion.rect,
      kind: .textAnchored,
      score: 0.88,
      evidence: ["Nearby label and whitespace"],
      coordinate: pageRegion,
      suggestedFieldType: .text,
      labelText: "Applicant legal name",
      sourceDigest: source.sha256
    )
    let inspection = DocumentInspection(
      source: source,
      pages: [
        PageSnapshot(
          pageIndex: 0,
          pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 600, height: 800),
          cropBox: nil,
          bleedBox: nil,
          trimBox: nil,
          artBox: nil,
          rotation: 0,
          characterCount: 120,
          annotationCount: 0,
          hasSelectableText: true
        )
      ],
      fields: [],
      candidates: [candidate],
      warnings: []
    )

    let fingerprint = PDFTemplateFingerprint.make(
      from: inspection,
      workspaceKey: Data("local-template-key".utf8),
      includeExactSourceDigest: true
    )
    #expect(fingerprint.exactSourceDigests == [source.sha256])
    #expect(fingerprint.layoutFingerprint.hasPrefix("hmac:"))
    #expect(fingerprint.pageSignatures[0].anchorTokens[0].hasPrefix("hmac:"))

    let mapping = PDFTemplateMapping(
      semanticKey: "person.fullName",
      target: PDFTemplateMappingTarget(
        kind: .staticRegion,
        pageIndex: 0,
        region: pageRegion,
        anchorToken: fingerprint.pageSignatures[0].anchorTokens[0],
        candidateKind: .textAnchored
      ),
      suggestedFieldType: .text,
      evidenceReferences: [candidate.id.uuidString],
      status: .confirmed
    )
    #expect(mapping.isApproved)

    let payload = PDFTemplatePayload(
      templateID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
      revisionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
      displayName: "Recurring application",
      lifecycle: .active,
      fingerprint: fingerprint,
      mappings: [mapping]
    )
    let template = PDFTemplateContract(
      header: PDFTemplateHeader(
        templateDigest: fingerprint.layoutFingerprint,
        provider: provider
      ),
      payload: payload
    )
    let profilePayload = PDFProfilePayload(
      profileID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
      revisionID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
      displayName: "Personal profile",
      revisionNumber: 2,
      storageScope: .userSelectedVault,
      values: [PDFProfileValueRecord(semanticKey: "person.fullName", value: .text("Ada Lovelace"))]
    )
    let profile = PDFProfileContract(
      header: PDFProfileHeader(
        profileID: profilePayload.profileID,
        revisionID: profilePayload.revisionID,
        provider: provider
      ),
      payload: profilePayload
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let templateData = try encoder.encode(template)
    let profileData = try encoder.encode(profile)
    let templateJSON = String(decoding: templateData, as: UTF8.self)
    #expect(!templateJSON.contains("Applicant legal name"))
    #expect(!templateJSON.contains("Ada Lovelace"))

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decodedTemplate = try decoder.decode(PDFTemplateContract.self, from: templateData)
    let decodedProfile = try decoder.decode(PDFProfileContract.self, from: profileData)
    #expect(decodedTemplate.payload.approvedMappings == [mapping])
    #expect(decodedProfile.payload.revisionNumber == 2)
    #expect(decodedProfile.payload.value(for: "person.fullName") == .text("Ada Lovelace"))
  }

  @Test func templateMatcherDistinguishesExactVariantNoMatchAndRevoked() throws {
    let sourceDigest = String(repeating: "e", count: 64)
    let fingerprint = PDFTemplateFingerprint(
      layoutFingerprint: "hmac:layout",
      exactSourceDigests: [sourceDigest],
      pageSignatures: []
    )
    let mapping = PDFTemplateMapping(
      semanticKey: "person.email",
      target: PDFTemplateMappingTarget(
        kind: .nativeField,
        pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 1, y: 1, width: 2, height: 2)),
        nativeFieldNameToken: "hmac:field"
      ),
      suggestedFieldType: .text,
      status: .confirmed
    )
    let payload = PDFTemplatePayload(
      displayName: "Email form",
      lifecycle: .active,
      fingerprint: fingerprint,
      mappings: [mapping]
    )
    let provider = PDFProviderDescriptor(id: "pdfjs-pdflib", version: "test", platform: "web")
    let template = PDFTemplateContract(
      header: PDFTemplateHeader(templateDigest: fingerprint.layoutFingerprint, provider: provider),
      payload: payload
    )

    let exact = PDFTemplateMatcher.propose(
      fingerprint: fingerprint,
      sourceDigest: sourceDigest,
      template: template
    )
    #expect(exact.state == .exact)
    #expect(exact.approvedMappingIDs == [mapping.id])
    #expect(exact.requiresValueReview)

    let variantFingerprint = PDFTemplateFingerprint(
      layoutFingerprint: fingerprint.layoutFingerprint,
      exactSourceDigests: [],
      pageSignatures: []
    )
    let variant = PDFTemplateMatcher.propose(
      fingerprint: variantFingerprint,
      sourceDigest: String(repeating: "f", count: 64),
      template: template
    )
    #expect(variant.state == .knownVariant)
    #expect(variant.requiresMappingReview)

    let noMatch = PDFTemplateMatcher.propose(
      fingerprint: PDFTemplateFingerprint(layoutFingerprint: "hmac:other", pageSignatures: []),
      sourceDigest: String(repeating: "f", count: 64),
      template: template
    )
    #expect(noMatch.state == .noMatch)
    #expect(noMatch.approvedMappingIDs.isEmpty)

    let revoked = PDFTemplatePayload(
      templateID: payload.templateID,
      revisionID: payload.revisionID,
      displayName: payload.displayName,
      lifecycle: .revoked,
      fingerprint: fingerprint,
      mappings: [mapping]
    )
    let revokedTemplate = PDFTemplateContract(
      header: PDFTemplateHeader(templateDigest: fingerprint.layoutFingerprint, provider: provider),
      payload: revoked
    )
    let revokedProposal = PDFTemplateMatcher.propose(
      fingerprint: fingerprint,
      sourceDigest: sourceDigest,
      template: revokedTemplate
    )
    #expect(revokedProposal.state == .unsupported)
    #expect(revokedProposal.approvedMappingIDs.isEmpty)
  }

  @Test func localTemplateCaptureCreatesKeyedDraftAndImmutableChildRevisions() throws {
    let source = DocumentSource(
      fileName: "capture.pdf", byteCount: 512, sha256: String(repeating: "c", count: 64))
    let coordinate = PDFPageRegion(
      pageIndex: 0, rect: PDFRect(x: 100, y: 500, width: 180, height: 20))
    let candidate = RegionCandidate(
      pageIndex: 0,
      bounds: coordinate.rect,
      kind: .textAnchored,
      score: 0.82,
      evidence: ["nearby label"],
      coordinate: coordinate,
      suggestedFieldType: .text,
      entryMode: .singleText,
      labelText: "Applicant legal name",
      sourceDigest: source.sha256
    )
    let inspection = DocumentInspection(
      source: source,
      pages: [
        PageSnapshot(
          pageIndex: 0,
          pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 600, height: 800),
          cropBox: nil,
          bleedBox: nil,
          trimBox: nil,
          artBox: nil,
          rotation: 0,
          characterCount: 80,
          annotationCount: 1,
          hasSelectableText: true
        )
      ],
      fields: [
        NativeField(
          id: "field-1",
          name: "applicant.name",
          kind: .text,
          pageIndex: 0,
          bounds: PDFRect(x: 100, y: 540, width: 180, height: 20),
          value: nil,
          choices: []
        )
      ],
      candidates: [candidate],
      warnings: []
    )

    let draft = try PDFTemplateCapture.captureDraft(
      from: inspection,
      workspaceKey: Data("capture-workspace-key".utf8),
      templateID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    )
    #expect(draft.payload.lifecycle == .draft)
    #expect(draft.payload.fingerprint.layoutFingerprint.hasPrefix("hmac:"))
    #expect(draft.payload.mappings.count == 2)
    #expect(draft.payload.mappings.allSatisfy { $0.status == .proposed })
    let draftData = try JSONEncoder().encode(draft)
    #expect(!String(decoding: draftData, as: UTF8.self).contains("Applicant legal name"))

    let mappingIDs = Set(draft.payload.mappings.map(\.id))
    let active = try PDFTemplateCapture.activateReviewedRevision(
      from: draft,
      approvedMappingIDs: mappingIDs,
      reviewedMappingIDs: mappingIDs
    )
    #expect(draft.payload.lifecycle == .draft)
    #expect(active.payload.lifecycle == .active)
    #expect(active.payload.templateID == draft.payload.templateID)
    #expect(active.payload.revisionID != draft.payload.revisionID)
    #expect(active.payload.parentRevisionID == draft.payload.revisionID)
    #expect(active.payload.mappings.allSatisfy { $0.status == .confirmed })

    var history = try PDFTemplateRevisionSet(
      templateID: draft.payload.templateID, revisions: [draft])
    history = try history.appending(active)
    #expect(history.revisions.count == 2)
    #expect(history.activeRevision?.payload.revisionID == active.payload.revisionID)
    let historyData = try JSONEncoder().encode(history)
    let decodedHistory = try JSONDecoder().decode(PDFTemplateRevisionSet.self, from: historyData)
    #expect(decodedHistory == history)

    #expect(throws: PDFTemplateCaptureError.unresolvedMappingDecisions) {
      try PDFTemplateCapture.activateReviewedRevision(
        from: draft,
        approvedMappingIDs: mappingIDs,
        reviewedMappingIDs: [mappingIDs.first!]
      )
    }
    let child = try PDFTemplateCapture.makeChildRevision(
      from: active,
      mappings: active.payload.mappings.map { $0.reviewed(as: .confirmed) }
    )
    let extendedHistory = try history.appending(child)
    #expect(child.payload.parentRevisionID == active.payload.revisionID)
    #expect(extendedHistory.revisions.count == 3)
  }

  @Test func completionProposalRequiresReviewResolvesTargetsAndBindsOperations() throws {
    let sourceDigest = String(repeating: "a", count: 64)
    let candidateID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    let mappingID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    let region = PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 100, y: 500, width: 180, height: 20))
    let fingerprint = PDFTemplateFingerprint(
      layoutFingerprint: "hmac:completion-layout",
      exactSourceDigests: [sourceDigest],
      pageSignatures: []
    )
    let mapping = PDFTemplateMapping(
      id: mappingID,
      semanticKey: "person.fullName",
      target: PDFTemplateMappingTarget(
        kind: .staticRegion,
        pageIndex: 0,
        region: region,
        candidateKind: .textAnchored
      ),
      suggestedFieldType: .text,
      evidenceReferences: [candidateID.uuidString],
      status: .confirmed
    )
    let provider = PDFProviderDescriptor(id: "pdfkit", version: "test", platform: "macOS")
    let template = PDFTemplateContract(
      header: PDFTemplateHeader(templateDigest: fingerprint.layoutFingerprint, provider: provider),
      payload: PDFTemplatePayload(
        templateID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        revisionID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
        displayName: "Completion template",
        lifecycle: .active,
        fingerprint: fingerprint,
        mappings: [mapping]
      )
    )
    let profilePayload = PDFProfilePayload(
      profileID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
      revisionID: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
      displayName: "Profile",
      values: [PDFProfileValueRecord(semanticKey: "person.fullName", value: .text("Ada Lovelace"))]
    )
    let profile = PDFProfileContract(
      header: PDFProfileHeader(
        profileID: profilePayload.profileID, revisionID: profilePayload.revisionID,
        provider: provider),
      payload: profilePayload
    )
    let match = PDFTemplateMatcher.propose(
      fingerprint: fingerprint, sourceDigest: sourceDigest, template: template)
    var proposal = try #require(
      PDFTemplateCompletionProposal.make(match: match, template: template, profile: profile))

    #expect(!proposal.isReadyToMaterialize)
    #expect(proposal.entries[0].valueReview == .resolvedUnreviewed)
    proposal = proposal.reviewingMapping(mappingID, approved: true)
    #expect(!proposal.isReadyToMaterialize)
    proposal = proposal.reviewingValue(mappingID, value: .text("Ada Lovelace"), approved: true)
    #expect(proposal.isReadyToMaterialize)

    let operations = try proposal.materializeOperations(currentSourceDigest: sourceDigest)
    #expect(operations.count == 1)
    #expect(operations[0].kind == .overlayText)
    #expect(operations[0].candidateID == candidateID)
    #expect(operations[0].sourceDigest == sourceDigest)
    #expect(operations[0].coordinate == region)
    #expect(operations[0].payload == .text("Ada Lovelace"))

    #expect(throws: PDFTemplateCompletionError.staleSource(expected: sourceDigest, actual: "stale"))
    {
      try proposal.materializeOperations(currentSourceDigest: "stale")
    }
  }

  @Test func nativeCompletionRequiresAdapterTargetResolutionAndLearningPromotionIsStrict() throws {
    let sourceDigest = String(repeating: "b", count: 64)
    let fingerprint = PDFTemplateFingerprint(
      layoutFingerprint: "hmac:native-layout",
      exactSourceDigests: [sourceDigest],
      pageSignatures: []
    )
    let mapping = PDFTemplateMapping(
      semanticKey: "person.email",
      target: PDFTemplateMappingTarget(
        kind: .nativeField,
        pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 80, y: 400, width: 200, height: 18)),
        nativeFieldNameToken: "hmac:field"
      ),
      suggestedFieldType: .text,
      status: .confirmed
    )
    let provider = PDFProviderDescriptor(id: "pdfkit", version: "test", platform: "macOS")
    let template = PDFTemplateContract(
      header: PDFTemplateHeader(templateDigest: fingerprint.layoutFingerprint, provider: provider),
      payload: PDFTemplatePayload(
        displayName: "Native template", lifecycle: .active, fingerprint: fingerprint,
        mappings: [mapping])
    )
    let profilePayload = PDFProfilePayload(
      displayName: "Profile",
      values: [PDFProfileValueRecord(semanticKey: "person.email", value: .text("ada@example.test"))]
    )
    let profile = PDFProfileContract(
      header: PDFProfileHeader(
        profileID: profilePayload.profileID, revisionID: profilePayload.revisionID,
        provider: provider),
      payload: profilePayload
    )
    let match = PDFTemplateMatcher.propose(
      fingerprint: fingerprint, sourceDigest: sourceDigest, template: template)
    var proposal = try #require(
      PDFTemplateCompletionProposal.make(match: match, template: template, profile: profile)
    )
    .reviewingMapping(mapping.id, approved: true)
    .reviewingValue(mapping.id, value: .text("ada@example.test"), approved: true)

    #expect(!proposal.isReadyToMaterialize)
    #expect(throws: PDFTemplateCompletionError.unresolvedNativeTarget(mapping.id)) {
      try proposal.materializeOperations(currentSourceDigest: sourceDigest)
    }
    proposal = proposal.resolvingNativeTarget(mapping.id, targetID: "actual-field-name")
      .reviewingMapping(mapping.id, approved: true)
    #expect(proposal.isReadyToMaterialize)
    #expect(
      try proposal.materializeOperations(currentSourceDigest: sourceDigest)[0].targetID
        == "actual-field-name")

    let event = PDFTemplateLearningEvent(
      templateID: template.payload.templateID,
      baseRevisionID: template.payload.revisionID,
      sourceDigest: sourceDigest,
      kind: .completionValidated,
      completionSessionID: proposal.sessionID
    )
    let validated = ValidationReport(
      status: .validated,
      messages: [],
      sourceUnchanged: true,
      outputReopenable: true,
      checks: [ValidationCheck(kind: .outputReopen, status: .passed, message: "Reopened")],
      sourceDigest: sourceDigest,
      validatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(
      PDFTemplateRevisionGate.canPromote(
        template: template, sourceDigest: sourceDigest, validation: validated, events: [event]))
    #expect(
      PDFTemplateRevisionGate.promote(
        template: template, sourceDigest: sourceDigest, validation: validated, events: [event])
        != nil)
    #expect(
      !PDFTemplateRevisionGate.canPromote(
        template: template, sourceDigest: sourceDigest,
        validation: ValidationReport(
          status: .validatedWithWarnings,
          messages: [],
          sourceUnchanged: true,
          outputReopenable: true,
          sourceDigest: sourceDigest
        ), events: [event]))
    let unknown = ValidationCheck(kind: .visualDiff, status: .unknown, message: "Not run")
    #expect(
      !PDFTemplateRevisionGate.canPromote(
        template: template, sourceDigest: sourceDigest,
        validation: ValidationReport(
          status: .validated,
          messages: [],
          sourceUnchanged: true,
          outputReopenable: true,
          checks: [unknown],
          sourceDigest: sourceDigest
        ), events: [event]))
    #expect(
      !PDFTemplateRevisionGate.canPromote(
        template: template, sourceDigest: sourceDigest, validation: validated,
        events: [event.applying()]))
  }

  @Test func completionApprovalStagesRejectValueOrMappingBypassAndInvalidateChangedInputs() throws {
    let sourceDigest = String(repeating: "c", count: 64)
    let mappingID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let profileID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let profileRevisionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let region = PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 20, width: 80, height: 16))
    let entry = PDFTemplateCompletionEntry(
      mappingID: mappingID,
      semanticKey: "person.fullName",
      target: PDFTemplateMappingTarget(kind: .staticRegion, pageIndex: 0, region: region),
      profileID: profileID,
      profileRevisionID: profileRevisionID,
      value: .text("Ada Lovelace"))
    let templateID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    var proposal = PDFTemplateCompletionProposal(
      sessionID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
      templateID: templateID,
      revisionID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
      sourceDigest: sourceDigest,
      matchState: .exact,
      entries: [entry])

    proposal = proposal.reviewingValue(mappingID, value: .text("Ada Lovelace"), approved: true)
    #expect(throws: PDFTemplateCompletionError.mappingReviewRequired(mappingID)) {
      try proposal.materializeOperations(currentSourceDigest: sourceDigest)
    }

    proposal = proposal.reviewingMapping(mappingID, approved: true)
    #expect(proposal.isReadyToMaterialize)
    let changedValue = PDFTemplateCompletionEntry(
      id: proposal.entries[0].id,
      mappingID: mappingID,
      semanticKey: proposal.entries[0].semanticKey,
      target: proposal.entries[0].target,
      mappingReview: .approved,
      profileID: profileID,
      profileRevisionID: profileRevisionID,
      value: .text("Grace Hopper"),
      valueReview: .approved,
      mappingApproval: proposal.entries[0].mappingApproval,
      profileValueApproval: proposal.entries[0].profileValueApproval,
      resolvedTargetID: nil)
    let staleValueProposal = PDFTemplateCompletionProposal(
      id: proposal.id,
      sessionID: proposal.sessionID,
      templateID: proposal.templateID,
      revisionID: proposal.revisionID,
      sourceDigest: proposal.sourceDigest,
      matchState: proposal.matchState,
      entries: [changedValue],
      createdAt: proposal.createdAt)
    #expect(throws: PDFTemplateCompletionError.profileValueApprovalRequired(mappingID)) {
      try staleValueProposal.materializeOperations(currentSourceDigest: sourceDigest)
    }

    let movedTarget = proposal.resolvingNativeTarget(mappingID, targetID: "provider-target")
    #expect(movedTarget.entries[0].mappingReview == .pending)
    #expect(throws: PDFTemplateCompletionError.mappingReviewRequired(mappingID)) {
      try movedTarget.materializeOperations(currentSourceDigest: sourceDigest)
    }
  }

  @Test func encryptedTemplateStoreCodecProtectsProfileValuesAndBindsRecordIdentity() throws {
    let provider = PDFProviderDescriptor(id: "pdfkit", version: "test", platform: "macOS")
    let profilePayload = PDFProfilePayload(
      displayName: "Private profile",
      storageScope: .userSelectedVault,
      values: [PDFProfileValueRecord(semanticKey: "person.fullName", value: .text("Ada Lovelace"))]
    )
    let profile = PDFProfileContract(
      header: PDFProfileHeader(
        profileID: profilePayload.profileID, revisionID: profilePayload.revisionID,
        provider: provider),
      payload: profilePayload
    )
    let key = Data(repeating: 7, count: 32)
    let record = try PDFTemplateStoreCodec.seal(
      profile,
      kind: .profile,
      recordID: profilePayload.profileID.uuidString,
      keyData: key
    )
    let encodedRecord = try JSONEncoder().encode(record)
    #expect(!String(decoding: encodedRecord, as: UTF8.self).contains("Ada Lovelace"))
    let decoded: PDFProfileContract = try PDFTemplateStoreCodec.open(
      record,
      as: PDFProfileContract.self,
      kind: .profile,
      recordID: profilePayload.profileID.uuidString,
      keyData: key
    )
    #expect(decoded == profile)
    #expect(throws: PDFTemplateStoreCodecError.invalidCiphertext) {
      let _: PDFProfileContract = try PDFTemplateStoreCodec.open(
        record,
        as: PDFProfileContract.self,
        kind: .profile,
        recordID: profilePayload.profileID.uuidString,
        keyData: Data(repeating: 8, count: 32)
      )
    }
    #expect(throws: PDFTemplateStoreCodecError.recordIdentityMismatch) {
      let _: PDFProfileContract = try PDFTemplateStoreCodec.open(
        record,
        as: PDFProfileContract.self,
        kind: .profile,
        recordID: "wrong-record",
        keyData: key
      )
    }
  }

  @Test func staticDetectorKeepsSuggestionsUncertain() {
    let lines = [
      TextLineEvidence(
        pageIndex: 0,
        text: "Applicant name: __________",
        bounds: PDFRect(x: 72, y: 600, width: 240, height: 18)
      ),
      TextLineEvidence(
        pageIndex: 0,
        text: "Ordinary paragraph",
        bounds: PDFRect(x: 72, y: 560, width: 240, height: 18)
      ),
    ]

    let candidates = StaticRegionDetector.detect(lines: lines)

    #expect(candidates.count == 1)
    #expect(candidates[0].status == .suggested)
    #expect(candidates[0].kind == .textAnchored)
    #expect(candidates[0].score < 1)
  }

  @Test func vectorDetectorAbstainsOnUnlabelledCellNoise() {
    let cell = PDFRect(x: 72, y: 600, width: 17, height: 13)
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: [],
      horizontalLines: [],
      potentialInputBoxes: [cell],
      potentialUnderlines: [],
      potentialCheckboxes: [cell]
    )

    let candidates = StaticRegionDetector.detect(lines: [], vectorGeometries: [geometry])

    #expect(candidates.isEmpty)
  }

  @Test func vectorDetectorGroupsCharacterCellsAndUsesNearbyLabel() {
    let cells = (0..<6).map { index in
      PDFRect(x: 120 + Double(index * 18), y: 600, width: 17, height: 13)
    }
    let label = TextLineEvidence(
      pageIndex: 0,
      text: "First name followed by middle name",
      bounds: PDFRect(x: 120, y: 632, width: 250, height: 16)
    )
    let geometry = PDFVectorStreamParser.ParsedPageGeometry(
      pageIndex: 0,
      mediaBox: CGRect(x: 0, y: 0, width: 612, height: 792),
      rectangles: cells.map(\.cgRect),
      horizontalLines: [],
      potentialInputBoxes: cells,
      potentialUnderlines: [],
      potentialCheckboxes: []
    )

    let candidates = StaticRegionDetector.detect(lines: [label], vectorGeometries: [geometry])

    #expect(candidates.count == 1)
    #expect(candidates[0].entryMode == CandidateEntryMode.characterGrid)
    #expect(candidates[0].groupMemberCount == 6)
    #expect(candidates[0].labelText == label.text)
    #expect(candidates[0].isDirectlyEditable)
    #expect(
      candidates[0].evidenceItems.first?.summary
        == "6 adjacent vector cells grouped into one region")
  }

  @Test func nativeFieldEditRoundTripsAndLeavesSourceUntouched() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let sourceURL = temporaryDirectory.appendingPathComponent("source.pdf")
    let outputURL = temporaryDirectory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    let page = PDFPage()
    fixture.insert(page, at: 0)
    let annotation = PDFAnnotation(
      bounds: CGRect(x: 72, y: 700, width: 220, height: 24),
      forType: PDFAnnotationSubtype.widget,
      withProperties: nil
    )
    annotation.widgetFieldType = .text
    annotation.fieldName = "fullName"
    annotation.backgroundColor = NSColor(calibratedWhite: 0.96, alpha: 1)
    annotation.border = PDFBorder()
    annotation.border?.lineWidth = 1
    page.addAnnotation(annotation)
    #expect(fixture.write(to: sourceURL))

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    #expect(inspection.fields.map(\.name) == ["fullName"])
    guard let field = inspection.fields.first else { return }
    let sourceDigest = inspection.source.sha256
    let operation = EditOperation(
      pageIndex: 0,
      targetID: "fullName",
      kind: .nativeFieldValue,
      value: "Ada Lovelace",
      bounds: field.bounds,
      sourceDigest: sourceDigest,
      coordinate: PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds)
    )

    let result = try provider.export(url: sourceURL, operations: [operation], to: outputURL)

    #expect(result.report.status == .validated)
    #expect(result.report.sourceUnchanged)
    #expect(try provider.inspect(url: sourceURL).source.sha256 == sourceDigest)
    #expect(try provider.inspect(url: outputURL).fields[0].value == "Ada Lovelace")
  }

  @Test func overlayEditIsBoundedAndReopens() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-overlay-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let sourceURL = temporaryDirectory.appendingPathComponent("source.pdf")
    let outputURL = temporaryDirectory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    fixture.insert(PDFPage(), at: 0)
    #expect(fixture.write(to: sourceURL))

    let inspection = try PDFKitProvider().inspect(url: sourceURL)
    let bounds = PDFRect(x: 72, y: 700, width: 120, height: 22)
    let operation = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "Reviewed",
      bounds: bounds,
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: bounds)
    )
    let result = try PDFKitProvider().export(url: sourceURL, operations: [operation], to: outputURL)

    #expect(result.report.status == .validated)
    #expect(PDFDocument(url: outputURL)?.page(at: 0)?.annotations.count == 1)
    #expect(result.report.checks.contains { $0.kind == .outsideRegionText && $0.status == .passed })
    #expect(result.report.checks.contains { $0.kind == .visualDiff && $0.status == .passed })
  }

  @Test func nativeCheckboxAndRadioGroupRoundTripTheirState() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-choice-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    let page = PDFPage()
    fixture.insert(page, at: 0)

    func widget(
      _ bounds: CGRect, fieldName: String, controlType: Int, state: Int, stateName: String
    ) -> PDFAnnotation {
      let annotation = PDFAnnotation(bounds: bounds, forType: .widget, withProperties: nil)
      annotation.widgetFieldType = .button
      annotation.fieldName = fieldName
      annotation.widgetControlType = PDFWidgetControlType(rawValue: controlType)!
      annotation.buttonWidgetStateString = stateName
      annotation.buttonWidgetState = PDFWidgetCellState(rawValue: state)!
      return annotation
    }

    page.addAnnotation(
      widget(
        CGRect(x: 72, y: 700, width: 20, height: 20), fieldName: "consent", controlType: 2,
        state: 0, stateName: "Yes"))
    page.addAnnotation(
      widget(
        CGRect(x: 72, y: 650, width: 20, height: 20), fieldName: "status", controlType: 1, state: 1,
        stateName: "yes"))
    page.addAnnotation(
      widget(
        CGRect(x: 104, y: 650, width: 20, height: 20), fieldName: "status", controlType: 1,
        state: 0, stateName: "no"))
    #expect(fixture.write(to: sourceURL))

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    let checkbox = EditOperation(
      pageIndex: 0,
      targetID: "consent",
      kind: .nativeFieldValue,
      value: "true",
      sourceDigest: inspection.source.sha256,
      payload: .boolean(true)
    )
    let radio = EditOperation(
      pageIndex: 0,
      targetID: "status",
      kind: .nativeFieldValue,
      value: "no",
      sourceDigest: inspection.source.sha256,
      payload: .choice("no")
    )
    let result = try provider.export(url: sourceURL, operations: [checkbox, radio], to: outputURL)
    let outputFields = try provider.inspect(url: outputURL).fields
    let statusFields = outputFields.filter { $0.name == "status" }

    #expect(result.report.status != .failed)
    #expect(result.report.checks.contains { $0.kind == .nativeFields && $0.status == .passed })
    #expect(outputFields.first { $0.name == "consent" }?.value == "Yes")
    #expect(statusFields.contains { $0.value == "no" })
    #expect(statusFields.filter { $0.value == "no" }.count == 1)
  }

  @Test func staticChoiceMarkAndNativeSynthesisRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "pdf-editor-static-action-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.pdf")
    let outputURL = directory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    fixture.insert(PDFPage(), at: 0)
    #expect(fixture.write(to: sourceURL))

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    let cell = PDFRect(x: 90, y: 600, width: 18, height: 18)
    let mark = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "X",
      bounds: cell,
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: cell),
      payload: .choiceMark(cell: cell)
    )
    let fieldBounds = PDFRect(x: 140, y: 600, width: 160, height: 22)
    let synthesis = EditOperation(
      pageIndex: 0,
      targetID: "static_name",
      kind: .synthesizeNativeField,
      value: "",
      bounds: fieldBounds,
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: fieldBounds),
      payload: .nativeField(fieldType: .text)
    )

    let result = try provider.export(url: sourceURL, operations: [mark, synthesis], to: outputURL)
    let outputDocument = PDFDocument(url: outputURL)
    let outputInspection = try provider.inspect(url: outputURL)
    let annotations = outputDocument?.page(at: 0)?.annotations ?? []

    #expect(result.report.status == .validated)
    #expect(annotations.contains { $0.type == "FreeText" && $0.contents == "X" })
    #expect(outputInspection.fields.contains { $0.name == "static_name" && $0.kind == .text })
  }

  @Test func characterGridOverlayWritesOneGlyphPerCell() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "pdf-editor-character-grid-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let sourceURL = temporaryDirectory.appendingPathComponent("source.pdf")
    let outputURL = temporaryDirectory.appendingPathComponent("output.pdf")
    let fixture = PDFDocument()
    fixture.insert(PDFPage(), at: 0)
    #expect(fixture.write(to: sourceURL))

    let inspection = try PDFKitProvider().inspect(url: sourceURL)
    let cells = [
      PDFRect(x: 100, y: 600, width: 17, height: 13),
      PDFRect(x: 118, y: 600, width: 17, height: 13),
      PDFRect(x: 136, y: 600, width: 17, height: 13),
    ]
    let bounds = PDFRect(x: 100, y: 600, width: 53, height: 13)
    let operation = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "AB",
      bounds: bounds,
      sourceDigest: inspection.source.sha256,
      coordinate: PDFPageRegion(pageIndex: 0, rect: bounds),
      payload: .characterGrid(text: "AB", cells: cells)
    )

    let result = try PDFKitProvider().export(url: sourceURL, operations: [operation], to: outputURL)
    let outputPage = PDFDocument(url: outputURL)?.page(at: 0)
    let glyphAnnotations = outputPage?.annotations.filter { $0.type == "FreeText" } ?? []

    #expect(result.report.status == .validated)
    #expect(glyphAnnotations.count == 2)
    #expect(glyphAnnotations.map { $0.contents ?? "" } == ["A", "B"])
    if glyphAnnotations.count == 2 {
      #expect(glyphAnnotations[0].bounds.width < 17)
      #expect(glyphAnnotations[1].bounds.minX > glyphAnnotations[0].bounds.minX)
    }
  }

  @Test func impactValidatorFailsClosedWhenCoordinatesAreMissing() {
    let source = PDFDocument()
    source.insert(PDFPage(), at: 0)
    let output = PDFDocument()
    output.insert(PDFPage(), at: 0)

    let noOpText = PDFImpactValidator.compareTextOutsideRegions(
      source: source,
      output: output,
      operations: []
    )
    #expect(noOpText.status == .passed)

    let missingCoordinate = EditOperation(
      pageIndex: 0,
      kind: .overlayText,
      value: "review"
    )
    let unknownText = PDFImpactValidator.compareTextOutsideRegions(
      source: source,
      output: output,
      operations: [missingCoordinate]
    )
    let unknownRaster = PDFImpactValidator.compareRasterOutsideRegions(
      source: source,
      output: output,
      operations: [missingCoordinate]
    )
    #expect(unknownText.status == .unknown)
    #expect(unknownRaster.status == .unknown)
  }

  @Test func realForm6SmokeWhenInputIsConfigured() throws {
    guard let path = ProcessInfo.processInfo.environment["PDF_EDITOR_FORM6_INPUT"] else { return }
    let sourceURL = URL(fileURLWithPath: path)
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-form6-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    #expect(inspection.pages.count == 2)
    #expect(inspection.fields.isEmpty)
    #expect(inspection.candidates.count < 100)
    #expect(
      inspection.candidates.contains {
        $0.entryMode == .characterGrid && $0.memberBounds.count >= 3
      })
    #expect(
      inspection.source.sha256 == "2cf1421343c22676f15eff0ec6f31a4df6e7f7975dc0f3d88d2b29a1dcc79d34"
    )

    let result = try provider.export(url: sourceURL, operations: [], to: outputURL)
    #expect(result.report.status == .validated)
    #expect(result.report.sourceUnchanged)
  }

  @Test func publicAcroFormChoiceLossRemainsVisibleWhenInputIsConfigured() throws {
    guard let path = ProcessInfo.processInfo.environment["PDF_EDITOR_PUBLIC_ACROFORM_INPUT"] else {
      return
    }
    let sourceURL = URL(fileURLWithPath: path)
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-public-acroform-\(UUID().uuidString).pdf")
    defer { try? FileManager.default.removeItem(at: outputURL) }

    let provider = PDFKitProvider()
    let inspection = try provider.inspect(url: sourceURL)
    #expect(inspection.fields.count == 6)
    #expect(inspection.fields.contains { !$0.choices.isEmpty })

    do {
      let result = try provider.export(url: sourceURL, operations: [], to: outputURL)
      #expect(result.report.sourceUnchanged)
      if result.report.status == .failed {
        #expect(result.report.messages.contains { $0.contains("choices changed") })
      } else {
        // The public fixture is allowed to improve or vary. If the
        // provider preserves its choices, a validated no-op is the
        // correct outcome; the regression must not demand a failure
        // that the current artifact does not reproduce.
        #expect(
          result.report.status == .validated || result.report.status == .validatedWithWarnings)
        #expect(!result.report.messages.contains { $0.contains("choices changed") })
      }
    } catch let error as PDFEditorError {
      guard case .exportFailed(let message) = error else {
        Issue.record("Unexpected PDFKit failure: \(error.localizedDescription)")
        return
      }
      #expect(message.contains("choices changed"))
      #expect(!FileManager.default.fileExists(atPath: outputURL.path))
    }
  }

  @Test func malformedInputIsRejectedWithoutWritingOutput() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-invalid-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let inputURL = directory.appendingPathComponent("invalid.pdf")
    try Data("not a PDF".utf8).write(to: inputURL)

    do {
      _ = try PDFKitProvider().inspect(url: inputURL)
      Issue.record("Invalid PDF input was accepted")
    } catch let error as PDFEditorError {
      guard case .cannotOpen = error else {
        Issue.record("Unexpected PDF error: \(error.localizedDescription)")
        return
      }
    }
  }

  @Test func inputSizeLimitFailsBeforeParsing() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-limit-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let inputURL = directory.appendingPathComponent("large.pdf")
    try Data(repeating: 0, count: 32).write(to: inputURL)

    do {
      _ = try PDFKitProvider(limits: .init(maximumInputBytes: 8)).inspect(url: inputURL)
      Issue.record("Input-size limit was not enforced")
    } catch let error as PDFEditorError {
      guard case .inputTooLarge = error else {
        Issue.record("Unexpected PDF error: \(error.localizedDescription)")
        return
      }
    }
  }

  @Test func inspectionIncludesPageGeometryAndConditionalAccessibilityEvidence() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-reading-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let inputURL = directory.appendingPathComponent("reading.pdf")
    let document = PDFDocument()
    document.insert(PDFPage(), at: 0)
    #expect(document.write(to: inputURL))

    let inspection = try PDFKitProvider().inspect(url: inputURL)
    #expect(inspection.pages.count == 1)
    #expect(inspection.pages[0].bounds.width > 0)
    #expect((inspection.pages[0].cropBox?.width ?? 0) > 0)
    #expect(inspection.security.isEncrypted == false)
    #expect(inspection.accessibility.hasTaggedContent == false)
    #expect(inspection.accessibility.notes.contains { $0.contains("PDF/UA") })
  }

  @Test func vectorStreamParserExtractsBoxesAndUnderlinesFromSyntheticPDF() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-vector-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let pdfURL = directory.appendingPathComponent("vector_test.pdf")

    // Create PDF with vector rectangle, checkbox, and horizontal line using CGContext
    var pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(url: pdfURL as CFURL),
      let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil)
    else {
      Issue.record("Could not create CGContext for vector test")
      return
    }

    context.beginPage(mediaBox: &pageRect)

    // Draw a form input box: 200x24 at (100, 500)
    context.setStrokeColor(NSColor.black.cgColor)
    context.setLineWidth(1.0)
    context.stroke(CGRect(x: 100, y: 500, width: 200, height: 24))

    // Draw a checkbox: 14x14 at (100, 450)
    context.stroke(CGRect(x: 100, y: 450, width: 14, height: 14))

    // Draw an underline: length 150 at y=400
    context.move(to: CGPoint(x: 100, y: 400))
    context.addLine(to: CGPoint(x: 250, y: 400))
    context.strokePath()

    context.endPage()
    context.closePDF()

    let parsedGeometries = PDFVectorStreamParser.parse(documentURL: pdfURL)
    #expect(parsedGeometries.count == 1)
    let pageGeom = parsedGeometries[0]

    #expect(!pageGeom.potentialInputBoxes.isEmpty)
    #expect(!pageGeom.potentialCheckboxes.isEmpty)
    #expect(!pageGeom.potentialUnderlines.isEmpty)

    // Run enhanced detector with text label lines
    let labelLine = TextLineEvidence(
      pageIndex: 0,
      text: "Date of Birth:",
      bounds: PDFRect(x: 20, y: 502, width: 75, height: 20)
    )
    let candidates = StaticRegionDetector.detect(
      lines: [labelLine], vectorGeometries: parsedGeometries)

    #expect(!candidates.isEmpty)
    let vectorCandidates = candidates.filter { $0.kind == .vectorRegion }
    #expect(!vectorCandidates.isEmpty)
    #expect(
      vectorCandidates.contains {
        $0.suggestedFieldType == .date || $0.suggestedFieldType == .checkbox
      })
  }

  @Test func ocrCoordinateConversionMapsCorrectlyToPageSpace() {
    let pageBounds = PDFRect(x: 0, y: 0, width: 600, height: 800)
    let ocrObs = OCRObservation(
      text: "Applicant Signature:",
      normalizedBounds: PDFRect(x: 0.1, y: 0.2, width: 0.3, height: 0.05),
      confidence: 0.95
    )
    let line = ocrObs.toPageSpace(pageBounds: pageBounds, pageIndex: 0)

    #expect(line.pageIndex == 0)
    #expect(line.text == "Applicant Signature:")
    #expect(abs(line.bounds.x - 60.0) < 0.01)
    #expect(abs(line.bounds.y - 160.0) < 0.01)
    #expect(abs(line.bounds.width - 180.0) < 0.01)
    #expect(abs(line.bounds.height - 40.0) < 0.01)
  }

  @Test func resilienceExportRejectsOverwritingSourceFile() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-resilience-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let fileURL = directory.appendingPathComponent("source.pdf")
    let doc = PDFDocument()
    doc.insert(PDFPage(), at: 0)
    #expect(doc.write(to: fileURL))

    let provider = PDFKitProvider()
    do {
      _ = try provider.export(url: fileURL, operations: [], to: fileURL)
      Issue.record("Overwriting the source file should have thrown an error")
    } catch let error as PDFEditorError {
      guard case .exportFailed = error else {
        Issue.record("Expected exportFailed error, got \(error)")
        return
      }
    }
  }

  @Test func resilienceStandardizesInvertedOrZeroGeometryBounds() {
    let invertedRect = CGRect(x: 100, y: 200, width: -50, height: -30)
    let standardized = invertedRect.standardized
    #expect(standardized.origin.x == 50)
    #expect(standardized.origin.y == 170)
    #expect(standardized.width == 50)
    #expect(standardized.height == 30)

    let pdfRect = PDFRect(invertedRect)
    #expect(pdfRect.x == 50)
    #expect(pdfRect.y == 170)
    #expect(pdfRect.width == 50)
    #expect(pdfRect.height == 30)
  }

  @Test func resilienceRejectsTruncatedStreamWithoutCrash() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-truncated-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let truncatedURL = directory.appendingPathComponent("truncated.pdf")
    // Partial PDF header with no objects or EOF marker
    try Data("%PDF-1.7\n1 0 obj\n<< /Type /Catalog".utf8).write(to: truncatedURL)

    let provider = PDFKitProvider()
    do {
      _ = try provider.inspect(url: truncatedURL)
      Issue.record("Truncated PDF input should not have opened")
    } catch let error as PDFEditorError {
      guard case .cannotOpen = error else {
        Issue.record("Expected cannotOpen error, got \(error)")
        return
      }
    }
  }

  @Test func securityDangerousLinkSchemesAreBlocked() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-sec-link-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let pdfURL = directory.appendingPathComponent("links.pdf")
    let doc = PDFDocument()
    let page = PDFPage()
    doc.insert(page, at: 0)

    // Add safe https link
    let safeAnnotation = PDFAnnotation(
      bounds: CGRect(x: 10, y: 100, width: 100, height: 20),
      forType: .link,
      withProperties: nil
    )
    safeAnnotation.action = PDFActionURL(url: URL(string: "https://example.com")!)
    page.addAnnotation(safeAnnotation)

    // Add unsafe javascript link
    let jsAnnotation = PDFAnnotation(
      bounds: CGRect(x: 10, y: 150, width: 100, height: 20),
      forType: .link,
      withProperties: nil
    )
    jsAnnotation.action = PDFActionURL(url: URL(string: "javascript:alert(1)")!)
    page.addAnnotation(jsAnnotation)

    // Add unsafe file:// link
    let fileAnnotation = PDFAnnotation(
      bounds: CGRect(x: 10, y: 200, width: 100, height: 20),
      forType: .link,
      withProperties: nil
    )
    fileAnnotation.action = PDFActionURL(url: URL(string: "file:///etc/passwd")!)
    page.addAnnotation(fileAnnotation)

    #expect(doc.write(to: pdfURL))

    let inspection = try PDFKitProvider().inspect(url: pdfURL)
    let safeLinks = inspection.links.filter { $0.isSafeExternal }
    let unsafeLinks = inspection.links.filter { !$0.isSafeExternal }

    #expect(safeLinks.contains { $0.destination == "https://example.com" })
    #expect(
      unsafeLinks.contains {
        $0.destination?.contains("javascript:") == true || $0.destination?.contains("file:") == true
      })
  }
}
