import Foundation

/// Automated detector gate for the native candidate pipeline.
///
/// Runs the live native pipeline (provider inspection → candidates + fields
/// channel) against the reviewed ground truth on every corpus sweep and
/// **fails the gate on any regression**. It is the CI-facing enforcement of
/// the detector semantic measurement: instead of measuring synthetic
/// candidate lanes, it measures what `PDFProvider.inspect` actually produces
/// for the real corpus fixtures.
///
/// First principles:
/// - **Live truth, not synthetic lanes.** The gate feeds real inspection
///   output (candidates + confirmed native fields) into
///   `DetectorSemanticMeasurement`; the only synthetic lanes are the
///   mutation tests that prove the gate can fail.
/// - **Fail closed.** A fixture with no reviewed ground truth cannot pass —
///   adding a new corpus fixture silently is impossible; it must be reviewed
///   and labeled first (truth taxonomy §2).
/// - **Per-fixture scoping.** Each fixture is measured against its own
///   reviewed cases so a regression is attributed to the fixture that caused
///   it (the pooled-lane artifact that could mask identical rects across
///   fixtures is deliberately avoided).
/// - **Privacy (§12).** The report carries region identities and metrics
///   only — never document text, field values, or candidate prose.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — metrics derive only from human-reviewed ground truth
/// - §5 Evidence-based — the gate runs the real pipeline on real fixtures
/// - §6 Documentation — the harness persists a deterministic report artifact
/// - §10 Failure — regression is reported per fixture, not as a blob

// MARK: - Gate Version

/// Version of the gate report schema.
public struct DetectorGateVersion: Codable, Sendable, Equatable {
  public let major: Int
  public let minor: Int

  public init(major: Int, minor: Int) {
    self.major = major
    self.minor = minor
  }

  public static let current = DetectorGateVersion(major: 1, minor: 0)
}

// MARK: - Per-Fixture Gate Result

/// Gate outcome for a single corpus fixture.
public struct NativeDetectorGateFixtureResult: Codable, Sendable {
  /// Fixture file name (matches `ReviewedGroundTruthCase.fixtureID`).
  public let fixtureID: String
  /// SHA-256 of the fixture bytes measured (nil when inspection failed).
  public let sourceDigest: String?
  /// Number of reviewed cases this fixture was measured against.
  public let reviewedCaseCount: Int
  /// True when the fixture has no reviewed ground truth (fail-closed).
  public let unreviewed: Bool
  /// The measured native lane (nil when unreviewed or inspection failed).
  public let lane: DetectorLaneResult?
  /// Inspection failure message, when the pipeline could not read the fixture.
  public let error: String?
  /// Encoded so the persisted artifact is self-describing.
  public let passed: Bool

  public init(
    fixtureID: String,
    sourceDigest: String?,
    reviewedCaseCount: Int,
    unreviewed: Bool,
    lane: DetectorLaneResult?,
    error: String?
  ) {
    self.fixtureID = fixtureID
    self.sourceDigest = sourceDigest
    self.reviewedCaseCount = reviewedCaseCount
    self.unreviewed = unreviewed
    self.lane = lane
    self.error = error
    self.passed = error == nil && !unreviewed && lane?.metrics.passed == true
  }
}

// MARK: - Gate Result

/// Full gate outcome across the corpus.
public struct NativeDetectorGateResult: Codable, Sendable {
  public let schema: String
  public let version: DetectorGateVersion
  /// Total reviewed cases in the canonical ground truth (context, not scope).
  public let groundTruthCount: Int
  public let fixtureCount: Int
  public let fixtures: [NativeDetectorGateFixtureResult]
  /// Encoded so the persisted artifact is self-describing.
  public let passed: Bool
  public let failedFixtureCount: Int
  public let unreviewedFixtureCount: Int
  /// Reviewed cases actually measured across all fixtures.
  public let reviewedCaseCount: Int
  /// Short human-readable summary for gate output (content-free); encoded so
  /// the persisted artifact is self-describing.
  public let summary: String

  public init(
    schema: String = "pdf-editor.detector-gate",
    version: DetectorGateVersion = .current,
    groundTruthCount: Int,
    fixtureCount: Int,
    fixtures: [NativeDetectorGateFixtureResult]
  ) {
    self.schema = schema
    self.version = version
    self.groundTruthCount = groundTruthCount
    self.fixtureCount = fixtureCount
    self.fixtures = fixtures
    self.passed = fixtures.allSatisfy(\.passed)
    self.failedFixtureCount = fixtures.filter { !$0.passed }.count
    self.unreviewedFixtureCount = fixtures.filter(\.unreviewed).count
    self.reviewedCaseCount = fixtures.reduce(0) { $0 + $1.reviewedCaseCount }
    self.summary = Self.buildSummary(fixtures: fixtures, failedCount: fixtures.filter { !$0.passed }.count, fixtureCount: fixtureCount)
  }

  private static func buildSummary(
    fixtures: [NativeDetectorGateFixtureResult],
    failedCount: Int,
    fixtureCount: Int
  ) -> String {
    let failures = fixtures
      .filter { !$0.passed }
      .map { fixture in
        if fixture.unreviewed {
          return "\(fixture.fixtureID): UNREVIEWED (fail-closed)"
        }
        if let error = fixture.error {
          return "\(fixture.fixtureID): INSPECTION FAILED (\(error))"
        }
        let lane = fixture.lane
        let metrics = lane?.metrics
        return "\(fixture.fixtureID): recall=\(metrics?.recall.map { String(format: "%.3f", $0) } ?? "n/a") "
          + "abstention=\(metrics?.abstention.map { String(format: "%.3f", $0) } ?? "n/a") "
          + "label=\(metrics?.labelAssociationPrecision.map { String(format: "%.3f", $0) } ?? "n/a") "
          + "evidence=\(metrics?.evidenceFamilyAgreement.map { String(format: "%.3f", $0) } ?? "n/a") "
          + "grouping=\(metrics?.groupingAgreement.map { String(format: "%.3f", $0) } ?? "n/a") "
          + "severityBurden=\(metrics?.severityBurden ?? -1)"
      }
    return "detector gate: \(fixtures.filter(\.passed).count)/\(fixtureCount) fixtures passed"
      + (failures.isEmpty ? "" : "\n  " + failures.joined(separator: "\n  "))
  }
}

// MARK: - The Gate

/// Executes the detector measurement gate over live native pipeline output.
public struct NativeDetectorGate: Sendable {
  public let measurement: DetectorSemanticMeasurement
  public let groundTruth: ReviewedCandidateGroundTruth

  public init(
    measurement: DetectorSemanticMeasurement = DetectorSemanticMeasurement(),
    groundTruth: ReviewedCandidateGroundTruth = ReviewedCandidateGroundTruth.canonical()
  ) {
    self.measurement = measurement
    self.groundTruth = groundTruth
  }

  /// The live candidate mapping: detector candidates plus the fields channel.
  ///
  /// Confirmed native AcroForm fields are surfaced through the fields
  /// channel, never the candidate channel (the detectors correctly abstain
  /// from re-suggesting them). The ground truth's `nativeField` cases measure
  /// these regions, so fields are mapped to candidate-shape entries — the
  /// exact contract the cross-lane runner uses
  /// (`Tests/browser_detector_corpus_report.mjs` `fieldCandidates`).
  public static func liveCandidates(_ inspection: DocumentInspection) -> [DetectorCandidate] {
    inspection.candidates.map(DetectorCandidate.native(from:))
      + inspection.fields.map(DetectorCandidate.native(from:))
  }

  /// Run the gate over the given corpus fixtures.
  ///
  /// - Parameters:
  ///   - provider: the native pipeline provider (PDFKit in production).
  ///   - fixtures: corpus fixture URLs, measured individually.
  ///   - candidates: live pipeline mapping; injectable for mutation tests.
  /// - Returns: the gate result. `passed` is false when any fixture
  ///   regressed, is unreviewed, or could not be inspected.
  public func run(
    provider: PDFProvider,
    fixtures: [URL],
    candidates: (DocumentInspection) -> [DetectorCandidate] = NativeDetectorGate.liveCandidates
  ) throws -> NativeDetectorGateResult {
    let ordered = fixtures
      .map { $0.standardizedFileURL }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var results: [NativeDetectorGateFixtureResult] = []
    for url in ordered {
      let fixtureID = url.lastPathComponent
      do {
        let inspection = try provider.inspect(url: url)
        let scoped = groundTruth.cases(forFixture: fixtureID)
        guard !scoped.isEmpty else {
          results.append(NativeDetectorGateFixtureResult(
            fixtureID: fixtureID,
            sourceDigest: inspection.source.sha256,
            reviewedCaseCount: 0,
            unreviewed: true,
            lane: nil,
            error: nil
          ))
          continue
        }
        let scopedTruth = ReviewedCandidateGroundTruth(cases: scoped)
        let lane = measurement.measure(
          lane: .native,
          groundTruth: scopedTruth,
          candidates: candidates(inspection)
        )
        results.append(NativeDetectorGateFixtureResult(
          fixtureID: fixtureID,
          sourceDigest: inspection.source.sha256,
          reviewedCaseCount: scoped.count,
          unreviewed: false,
          lane: lane,
          error: nil
        ))
      } catch {
        results.append(NativeDetectorGateFixtureResult(
          fixtureID: fixtureID,
          sourceDigest: nil,
          reviewedCaseCount: 0,
          unreviewed: false,
          lane: nil,
          error: error.localizedDescription
        ))
      }
    }

    return NativeDetectorGateResult(
      groundTruthCount: groundTruth.cases.count,
      fixtureCount: results.count,
      fixtures: results
    )
  }
}