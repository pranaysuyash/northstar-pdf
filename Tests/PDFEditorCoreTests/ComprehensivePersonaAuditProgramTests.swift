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

    let address = FieldLabelCanonicalizer.canonicalize("a) Home Address *")
    #expect(address?.displayName == "Home Address")

    let dob = FieldLabelCanonicalizer.canonicalize("Date of Birth:")
    #expect(dob?.displayName == "Date of Birth")
  }

  // MARK: - 4. PER-0922 Epistemic Integrity & Truth Maintenance

  @Test func epistemicIntegrityRejectsFalsePositiveCompletionClaims() {
    // A document with 5 fields where only 2 are confirmed must report 40% progress, never 100%
    let progress = CompletionProgress(totalCandidates: 5, confirmedCount: 2, rejectedCount: 0, remainingCount: 3)
    #expect(progress.percentComplete == 40.0)

    let fullProgress = CompletionProgress(totalCandidates: 5, confirmedCount: 5, rejectedCount: 0, remainingCount: 0)
    #expect(fullProgress.percentComplete == 100.0)
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
}
