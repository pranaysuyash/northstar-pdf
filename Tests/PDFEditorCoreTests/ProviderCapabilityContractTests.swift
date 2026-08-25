import Foundation
import Testing

@testable import PDFEditorCore

struct ProviderCapabilityContractTests {
  private let digestA = String(repeating: "a", count: 64)
  private let digestB = String(repeating: "b", count: 64)
  private let digestC = String(repeating: "c", count: 64)

  private func enabledReader() -> ProviderCapabilityManifest {
    let measurement = ProviderCapabilityMeasurement(
      measurementID: "measurement-reader-001",
      capabilityID: "reader.render",
      artifactDigest: digestA,
      corpusDigest: digestB,
      reportDigest: digestC,
      status: .passed,
      evidenceTier: .T3,
      sensitivity: .S1,
      gates: ["browser-contract", "independent-viewer"]
    )
    return ProviderCapabilityManifest(
      providerID: "browser-pdfjs-pdflib",
      engineFamily: "pdfjs-pdflib",
      providerVersion: "test",
      runtimeKind: "browser-bundled",
      artifactDigest: digestA,
      installState: .enabled,
      license: ProviderLicenseRecord(name: "Apache-2.0 plus MIT", status: .approved),
      capabilities: [
        ProviderCapabilityRecord(
          capabilityID: "reader.render",
          state: .enabled,
          limits: ProviderCapabilityLimits(
            maxBytes: 100_000_000,
            maxPages: 500,
            supportsEncrypted: true,
            supportsScanned: true
          ),
          measurementIDs: [measurement.measurementID]
        )
      ],
      measurements: [measurement]
    )
  }

  @Test func providerManifestRoundTripsWithoutChangingPDFContracts() throws {
    let manifest = enabledReader()
    try manifest.validate()
    let data = try JSONEncoder().encode(manifest)
    let decoded = try JSONDecoder().decode(ProviderCapabilityManifest.self, from: data)

    #expect(decoded == manifest)
    #expect(decoded.contract == "pdf-editor.provider-capability")
    #expect(decoded.capabilities[0].measurementIDs == ["measurement-reader-001"])
  }

  @Test func registryRejectsEnabledCapabilityWithoutExactMeasurementBinding() {
    var provider = enabledReader()
    provider = ProviderCapabilityManifest(
      providerID: provider.providerID,
      engineFamily: provider.engineFamily,
      providerVersion: provider.providerVersion,
      runtimeKind: provider.runtimeKind,
      artifactDigest: provider.artifactDigest,
      installState: provider.installState,
      license: provider.license,
      capabilities: [
        ProviderCapabilityRecord(
          capabilityID: "reader.render",
          state: .enabled,
          limits: provider.capabilities[0].limits,
          measurementIDs: []
        )
      ],
      measurements: provider.measurements
    )

    #expect(throws: ProviderCapabilityError.invalid("enabled capability requires a measurement reference")) {
      try provider.validate()
    }
  }

  @Test func registryRoundTripsAndRejectsDuplicateProviderIDs() throws {
    let provider = enabledReader()
    let registry = ProviderCapabilityRegistry(registryID: "test-registry", providers: [provider])
    try registry.validate()
    let data = try JSONEncoder().encode(registry)
    let decoded = try JSONDecoder().decode(ProviderCapabilityRegistry.self, from: data)
    #expect(decoded == registry)

    let duplicate = ProviderCapabilityRegistry(registryID: "duplicate", providers: [provider, provider])
    #expect(throws: ProviderCapabilityError.invalid("duplicate provider ID")) {
      try duplicate.validate()
    }
  }

  @Test func providerMeasurementBindsToArtifactDigest() {
    let provider = enabledReader()
    let measurement = ProviderCapabilityMeasurement(
      measurementID: "measurement-reader-bad",
      capabilityID: "reader.render",
      artifactDigest: String(repeating: "f", count: 64),
      corpusDigest: digestB,
      reportDigest: digestC,
      status: .passed,
      evidenceTier: .T3,
      sensitivity: .S1,
      gates: ["browser-contract"]
    )
    let invalid = ProviderCapabilityManifest(
      providerID: provider.providerID,
      engineFamily: provider.engineFamily,
      providerVersion: provider.providerVersion,
      runtimeKind: provider.runtimeKind,
      artifactDigest: provider.artifactDigest,
      installState: provider.installState,
      license: provider.license,
      capabilities: provider.capabilities,
      measurements: [measurement]
    )

    #expect(throws: ProviderCapabilityError.invalid("measurement binding is not source-artifact bound")) {
      try invalid.validate()
    }
  }

  @Test func nativeNegotiatorSelectsMeasuredCapabilityAndAbstainsWhenUnmeasured() throws {
    let reader = enabledReader()
    let registry = ProviderCapabilityRegistry(registryID: "test-registry", providers: [reader])
    let request = ProviderCapabilityRequest(
      capability: "reader.render",
      operationKinds: ["inspect"],
      source: ProviderSourceFacts(byteCount: 1_000, pageCount: 1, isEncrypted: false, isScanned: false),
      policy: ProviderCapabilityPolicy(localOnly: true, minimumState: .enabled, allowExperimental: false)
    )
    let decision = try ProviderCapabilityNegotiator.negotiate(registry: registry, request: request)
    #expect(decision.decision == .selected)
    #expect(decision.providerID == reader.providerID)
    #expect(decision.measurementID == "measurement-reader-001")

    let unmeasured = ProviderCapabilityManifest(
      providerID: "companion-pdfbox",
      engineFamily: "apache-pdfbox",
      providerVersion: "test",
      runtimeKind: "installed-companion",
      artifactDigest: String(repeating: "e", count: 64),
      installState: .installed,
      license: ProviderLicenseRecord(name: "Apache-2.0", status: .approved),
      capabilities: [
        ProviderCapabilityRecord(
          capabilityID: "edit.existingText",
          state: .installedUnmeasured,
          limits: ProviderCapabilityLimits(maxBytes: 1_000_000, maxPages: 10, supportsEncrypted: false, supportsScanned: false),
          measurementIDs: []
        )
      ],
      measurements: []
    )
    let unmeasuredRequest = ProviderCapabilityRequest(
      capability: "edit.existingText",
      operationKinds: ["edit"],
      source: ProviderSourceFacts(byteCount: 1_000, pageCount: 1, isEncrypted: false, isScanned: false),
      policy: ProviderCapabilityPolicy(localOnly: true, minimumState: .enabled, allowExperimental: false)
    )
    let abstained = try ProviderCapabilityNegotiator.negotiate(
      registry: ProviderCapabilityRegistry(registryID: "unmeasured", providers: [unmeasured]),
      request: unmeasuredRequest
    )
    #expect(abstained.decision == .abstained)
    #expect(abstained.reasonCodes.contains("providerState:installed"))
  }

  @Test func nativeDecodesTheSharedRegistryFixtureUsedByTheBrowserAdapter() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let fixtureURL = repositoryRoot.appendingPathComponent("Tests/fixtures/provider_capability_registry.json")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let registry = try decoder.decode(ProviderCapabilityRegistry.self, from: Data(contentsOf: fixtureURL))
    try registry.validate()

    #expect(registry.providers.count == 4)
    #expect(registry.providers.first(where: { $0.providerID == "browser-pdfjs-pdflib" })?.installState == .enabled)
    #expect(registry.providers.first(where: { $0.providerID == "companion-pdfbox" })?.installState == .installed)
    #expect(registry.providers.first(where: { $0.providerID == "companion-mupdf" })?.installState == .quarantined)
  }

  @Test func nativeRejectsDuplicateMeasurementAndPreferredProviderIDs() throws {
    let provider = enabledReader()
    let duplicateMeasurement = ProviderCapabilityMeasurement(
      measurementID: "measurement-reader-001",
      capabilityID: "reader.render",
      artifactDigest: digestA,
      corpusDigest: digestB,
      reportDigest: digestC,
      status: .passed,
      evidenceTier: .T3,
      sensitivity: .S1,
      gates: ["browser-contract"]
    )
    let invalidProvider = ProviderCapabilityManifest(
      providerID: provider.providerID,
      engineFamily: provider.engineFamily,
      providerVersion: provider.providerVersion,
      runtimeKind: provider.runtimeKind,
      artifactDigest: provider.artifactDigest,
      installState: provider.installState,
      license: provider.license,
      capabilities: provider.capabilities,
      measurements: provider.measurements + [duplicateMeasurement]
    )
    #expect(throws: ProviderCapabilityError.invalid("duplicate measurement ID")) {
      try invalidProvider.validate()
    }

    let request = ProviderCapabilityRequest(
      capability: "reader.render",
      operationKinds: ["inspect"],
      source: ProviderSourceFacts(byteCount: 1_000, pageCount: 1, isEncrypted: false, isScanned: false),
      policy: ProviderCapabilityPolicy(
        localOnly: true,
        minimumState: .enabled,
        allowExperimental: false,
        preferredProviderIDs: [provider.providerID, provider.providerID]
      )
    )
    #expect(throws: ProviderCapabilityError.invalid("duplicate preferred provider ID")) {
      try ProviderCapabilityNegotiator.negotiate(
        registry: ProviderCapabilityRegistry(registryID: "duplicate-preference", providers: [provider]),
        request: request
      )
    }
  }
}
