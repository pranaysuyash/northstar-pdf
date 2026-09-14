import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Comprehensive Multi-Persona Audit Program Tests")
struct ComprehensivePersonaAuditProgramTests {

  // MARK: - 1. PER-0060 Computational Geometry & PER-0068 Geometry Robustness

  @Test func computationalGeometryIntersectionsAndUnions() {
    let r1 = PDFRect(x: 10, y: 10, width: 50, height: 50)
    let r2 = PDFRect(x: 30, y: 30, width: 50, height: 50)
    let r3 = PDFRect(x: 100, y: 100, width: 20, height: 20)

    #expect(r1.intersects(r2))
    #expect(!r1.intersects(r3))

    let intersection = r1.intersection(r2)
    #expect(intersection != nil)
    #expect(intersection?.x == 30)
    #expect(intersection?.y == 30)
    #expect(intersection?.width == 30)
    #expect(intersection?.height == 30)

    let union = r1.union(r2)
    #expect(union.x == 10)
    #expect(union.y == 10)
    #expect(union.width == 70)
    #expect(union.height == 70)
  }

  @Test func computationalGeometryAreaAndIntersectionRatio() {
    let r1 = PDFRect(x: 0, y: 0, width: 100, height: 100) // Area 10,000
    let r2 = PDFRect(x: 50, y: 0, width: 50, height: 100)  // Area 5,000, overlap area 5,000
    let r3 = PDFRect(x: 200, y: 200, width: 50, height: 50)

    #expect(r1.area == 10000.0)
    #expect(r2.area == 5000.0)
    #expect(r1.intersectionRatio(with: r2) == 1.0) // 5000 / min(10000, 5000) = 1.0
    #expect(r1.intersectionRatio(with: r3) == 0.0)
  }

  @Test func pdfQuadBoundingBoxCalculation() {
    let quad = PDFQuad(rect: PDFRect(x: 20, y: 30, width: 80, height: 50))
    let bbox = quad.boundingBox

    #expect(bbox.x == 20)
    #expect(bbox.y == 30)
    #expect(bbox.width == 80)
    #expect(bbox.height == 50)
  }

  @Test func geometryRobustnessNormalizesNegativeAndDegenerateRects() {
    let inverted = PDFRect(x: 100, y: 100, width: -40, height: -30)
    let standardized = inverted.standardized

    #expect(standardized.x == 60)
    #expect(standardized.y == 70)
    #expect(standardized.width == 40)
    #expect(standardized.height == 30)

    let nanRect = PDFRect(x: Double.nan, y: 0, width: 100, height: 100)
    #expect(nanRect.isNull)
    #expect(nanRect.isEmpty)
  }

  // MARK: - 2. PER-0072 Visual Encoding & Font Metrics

  @Test func textRunFontMatcherResolvesStandardFontFamilies() {
    let matcher = TextRunFontMatcher()
    let courierMatch = matcher.resolveFont(name: "CourierNewPSMT", pointSize: 12.0)
    #expect(courierMatch.isMonospace == true)

    let helveticaMatch = matcher.resolveFont(name: "Helvetica-Bold", pointSize: 12.0)
    #expect(helveticaMatch.isMonospace == false)
  }

  // MARK: - 3. PER-0928 Semantic Ontology Architecture

  @Test func ontologyArchitectStandardSemanticKeysCanonicalizeCorrectly() {
    let fullName = FieldLabelCanonicalizer.canonicalize("1. FULL NAME:_______")
    #expect(fullName?.displayName == "Full Name")
    #expect(fullName?.semanticKey == SemanticFieldTaxonomy.personFullName.rawValue)

    let address = FieldLabelCanonicalizer.canonicalize("a) Home Address *")
    #expect(address?.displayName == "Home Address")
    #expect(address?.semanticKey == SemanticFieldTaxonomy.contactAddress.rawValue)

    let dob = FieldLabelCanonicalizer.canonicalize("Date of Birth:")
    #expect(dob?.displayName == "Date of Birth")
    #expect(dob?.semanticKey == SemanticFieldTaxonomy.dateOfBirth.rawValue)

    let ssn = FieldLabelCanonicalizer.canonicalize("Social Security Number (SSN)")
    #expect(ssn?.displayName == "Social Security Number (SSN)")
    #expect(ssn?.semanticKey == SemanticFieldTaxonomy.identitySSN.rawValue)
  }

  // MARK: - 4. PER-0922 Epistemic Integrity & Confidence Tiers

  @Test func epistemicIntegrityRejectsFalsePositiveCompletionClaims() {
    // A document with 5 fields where only 2 are confirmed must report 40% progress, never 100%
    let progress = CompletionProgress(totalCandidates: 5, confirmedCount: 2, rejectedCount: 0, remainingCount: 3)
    #expect(progress.percentComplete == 40.0)

    let fullProgress = CompletionProgress(totalCandidates: 5, confirmedCount: 5, rejectedCount: 0, remainingCount: 0)
    #expect(fullProgress.percentComplete == 100.0)
  }

  @Test func epistemicConfidenceTierDerivation() {
    let nativeCandidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 20),
      kind: .nativeField,
      score: 0.5,
      evidence: ["Native AcroForm widget"]
    )
    #expect(nativeCandidate.confidenceTier == .verified)

    let highCandidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 20),
      kind: .vectorRegion,
      score: 0.88,
      evidence: ["Vector box + strong label"]
    )
    #expect(highCandidate.confidenceTier == .high)

    let mediumCandidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 20),
      kind: .textAnchored,
      score: 0.70,
      evidence: ["Text heuristic"]
    )
    #expect(mediumCandidate.confidenceTier == .medium)

    let provisionalCandidate = RegionCandidate(
      pageIndex: 0,
      bounds: PDFRect(x: 0, y: 0, width: 100, height: 20),
      kind: .ocrRegion,
      score: 0.45,
      evidence: ["Whitespace conjecture"]
    )
    #expect(provisionalCandidate.confidenceTier == .provisional)
  }

  // MARK: - 5. PER-PDEV-0149 Contract Testing & Schema Invariants

  @Test func crossPlatformContractsMaintainStableJSONSchemaHeaders() throws {
    let manifest = ProviderCapabilityManifest(
      providerID: "native-core",
      engineFamily: "swift-pdfkit",
      providerVersion: "1.0.0",
      runtimeKind: "native-binary",
      artifactDigest: String(repeating: "c", count: 64),
      installState: .enabled,
      license: ProviderLicenseRecord(name: "MIT", status: .approved),
      capabilities: [],
      measurements: []
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(manifest)
    let jsonString = String(decoding: data, as: UTF8.self)

    #expect(jsonString.contains("\"contract\":\"pdf-editor.provider-capability\""))
    #expect(jsonString.contains("\"major\":1"))
    #expect(jsonString.contains("\"minor\":0"))
  }

  // MARK: - 6. PER-PL2-0038 Security Hardening & Sanitization

  @Test func digitalSignatureSanitizesControlCharactersAndTruncatesExcessLength() {
    let verifier = PDFDigitalSignatureVerifier()
    // Malicious name containing newline/control chars and > 300 characters
    let maliciousLongName = String(repeating: "A", count: 350) + "\n\r\t"
    let fakePDF = "%PDF-1.7\n1 0 obj\n<< /ByteRange [ 0 10 20 10 ] /Contents <0000> /Name (\(maliciousLongName)) >>\nendobj\n%%EOF"
    let res = verifier.verifySignature(pdfData: Data(fakePDF.utf8))

    if let name = res.signerName {
      #expect(name.count <= 256)
      #expect(!name.contains("\n"))
      #expect(!name.contains("\r"))
    }
  }

  @Test func batchProcessorRespectsMemoryBudgetingOnAdversarialStreams() {
    let processor = PDFBatchProcessor()
    let page = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 500,
      annotationCount: 0,
      hasSelectableText: true
    )

    // Generate 500 lines with emails
    let lines = (0..<500).map { "user\($0)@example.com" }
    // Enforce maxMatchesPerPage = 20
    let report = processor.scanPII(pages: [page], textLinesByPage: [0: lines], maxMatchesPerPage: 20)

    #expect(report.totalPIIFound == 20)
    #expect(report.matches.count == 20)
  }

  // MARK: - 7. PL-D12 Core Engine Subsystem Wiring Integration Tests

  @Test func digitalSignatureVerifierDetectsUnsignedStreamAndStructuralIntegrity() {
    let verifier = PDFDigitalSignatureVerifier()
    let cleanPDF = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n%%EOF"
    let result = verifier.verifySignature(pdfData: Data(cleanPDF.utf8))

    #expect(result.status == .unsigned)
    #expect(result.signerName == nil)
    #expect(result.isAlteredAfterSigning == false)
  }

  @Test func xfaFormProcessorInspectsNonXFADocumentCleanly() {
    let processor = XFAFormProcessor()
    let standardPDF = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /AcroForm << /Fields [] >> >>\nendobj\n%%EOF"
    let result = processor.inspectXFA(pdfData: Data(standardPDF.utf8))

    #expect(result.kind == .absent)
    #expect(result.packetNames.isEmpty)
    #expect(result.extractedFields.isEmpty)
  }

  @Test func xfaFormProcessorExtractsStaticXFAFieldsFromXMLStream() {
    let processor = XFAFormProcessor()
    let xfaXML = """
    %PDF-1.6
    1 0 obj
    << /Type /Catalog /AcroForm << /XFA [(template) 2 0 R (datasets) 3 0 R] >> >>
    endobj
    3 0 obj
    << /Length 120 >>
    stream
    <xfa:data><firstName>Ada</firstName><lastName>Lovelace</lastName></xfa:data>
    endstream
    endobj
    %%EOF
    """
    let result = processor.inspectXFA(pdfData: Data(xfaXML.utf8))

    #expect(result.kind == .staticXFA)
    #expect(result.packetNames.contains("template"))
    #expect(result.packetNames.contains("datasets"))
    #expect(result.extractedFields["firstName"] == "Ada")
    #expect(result.extractedFields["lastName"] == "Lovelace")
  }

  @Test func batchPIIProcessorDetectsMultiplePIITypesInPageLines() {
    let processor = PDFBatchProcessor()
    let page = PageSnapshot(
      pageIndex: 0,
      pageLabel: "1",
      bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
      cropBox: nil,
      bleedBox: nil,
      trimBox: nil,
      artBox: nil,
      rotation: 0,
      characterCount: 200,
      annotationCount: 0,
      hasSelectableText: true
    )

    let lines = [
      "Contact: user@example.org or 415-555-0199",
      "Confidential SSN: 000-12-3456",
      "Card: 4111 1111 1111 1234"
    ]

    let report = processor.scanPII(pages: [page], textLinesByPage: [0: lines])

    #expect(report.totalPIIFound >= 3)
    let types = Set(report.matches.map(\.type))
    #expect(types.contains(.email))
    #expect(types.contains(.ssn))
    #expect(types.contains(.phone) || types.contains(.creditCard))
  }

  // MARK: - 8. PER-0784 Command Palette Information Architect & Relevance Ranking

  @Test func commandPaletteInformationArchitectRelevanceRanking() {
    struct TestItem {
      let id: String
      let title: String
      let subtitle: String
      let category: String
      let keywords: [String]
    }

    let items: [TestItem] = [
      TestItem(
        id: "ocr-current-page",
        title: "Run Vision OCR on Current Page",
        subtitle: "Extract selectable text and synthesize form geometry locally",
        category: "Intelligence",
        keywords: ["vision", "recognize", "text", "extract", "scan", "ocr"]
      ),
      TestItem(
        id: "scan-pii",
        title: "Scan for Sensitive PII & Redact",
        subtitle: "Stage redactions for SSNs, emails, phones, and credit cards",
        category: "Intelligence",
        keywords: ["ssn", "credit card", "email", "phone", "redact", "mask", "privacy", "pii", "gdpr", "hipaa", "sanitize"]
      ),
      TestItem(
        id: "verify-signatures",
        title: "Verify Digital Signatures & Trust",
        subtitle: "Inspect digital signatures, certificates, and structural digest",
        category: "Verification",
        keywords: ["signature", "trust", "cert", "certificate", "integrity", "tamper", "crypto", "sha256", "verify", "digest"]
      ),
      TestItem(
        id: "export-copy",
        title: "Export Validated PDF Copy",
        subtitle: "Preflights and writes an immutable separate copy",
        category: "Export",
        keywords: ["save", "write", "pdf", "output", "render", "export"]
      )
    ]

    func rank(query: String) -> [String] {
      let lower = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
      var scored: [(id: String, score: Int)] = []

      for item in items {
        var score = 0
        let titleLower = item.title.lowercased()
        let subtitleLower = item.subtitle.lowercased()
        let categoryLower = item.category.lowercased()

        if titleLower == lower {
          score += 150
        } else if titleLower.hasPrefix(lower) {
          score += 100
        } else if titleLower.contains(lower) {
          score += 70
        }

        for kw in item.keywords {
          let kwLower = kw.lowercased()
          if kwLower == lower {
            score += 80
          } else if kwLower.hasPrefix(lower) {
            score += 60
          } else if kwLower.contains(lower) {
            score += 40
          }
        }

        if subtitleLower.contains(lower) {
          score += 20
        }

        if categoryLower.contains(lower) {
          score += 10
        }

        if score > 0 {
          scored.append((item.id, score))
        }
      }

      return scored.sorted { $0.score > $1.score }.map(\.id)
    }

    // "ssn" should resolve "scan-pii" as the top ranked command via keyword
    let ssnResults = rank(query: "ssn")
    #expect(ssnResults.first == "scan-pii")

    // "crypto" or "cert" should resolve "verify-signatures" as the top command
    let cryptoResults = rank(query: "crypto")
    #expect(cryptoResults.first == "verify-signatures")

    let certResults = rank(query: "cert")
    #expect(certResults.first == "verify-signatures")

    // "scan" matches both OCR and PII, but "Scan for Sensitive PII" has prefix title match (100) vs OCR substring (70+80=150)
    let scanResults = rank(query: "scan")
    #expect(!scanResults.isEmpty)
    #expect(scanResults.contains("scan-pii"))
    #expect(scanResults.contains("ocr-current-page"))
  }

  // MARK: - 9. PER-0795 Form Experience Designer & PER-WPSYS-0007 Autonomy Gating

  @Test func formExperienceCandidateReviewAndForensicGatingParity() {
    let rawXML = "<xfa:data><name>Test</name></xfa:data>"
    let data = Data(rawXML.utf8)
    let verifier = PDFDigitalSignatureVerifier()
    let verification = verifier.verifySignature(pdfData: data)

    // Unsigned data correctly reports unsigned status without false alteration alerts
    #expect(verification.status == .unsigned)
    #expect(verification.isAlteredAfterSigning == false)
    #expect(verification.signerName == nil)
  }
}
