import Foundation

/// Dual-lane detector gate: runs both native and browser lanes against the
/// reviewed ground truth on every corpus sweep.
///
/// First principles:
/// - **Both lanes, same truth.** The native and browser pipelines are measured
///   against the same reviewed ground truth, enabling cross-lane parity detection.
/// - **Fail closed.** A fixture with no reviewed ground truth cannot pass —
///   adding a new corpus fixture silently is impossible; it must be reviewed
///   and labeled first (truth taxonomy §2).
/// - **Per-fixture scoping.** Each fixture is measured against its own reviewed
///   cases so a regression is attributed to the fixture that caused it.
/// - **Privacy (§12).** The report carries region identities and metrics
///   only — never document text, field values, or candidate prose.
///
/// Doctrine alignment:
/// - §2 Truth taxonomy — metrics derive only from human-reviewed ground truth
/// - §5 Evidence-based — the gate runs real pipelines on real fixtures
/// - §6 Documentation — the harness persists a deterministic report artifact
/// - §10 Failure — regression is reported per fixture per lane

// MARK: - Dual-Lane Gate Result

/// Full gate outcome across both lanes for the corpus.
public struct DualLaneDetectorGateResult: Codable, Sendable {
  public let schema: String
  public let version: DetectorGateVersion
  /// Total reviewed cases in the canonical ground truth (context, not scope).
  public let groundTruthCount: Int
  public let fixtureCount: Int
  /// Per-fixture results for both lanes.
  public let fixtures: [DualLaneFixtureResult]
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
    schema: String = "pdf-editor.dual-lane-detector-gate",
    version: DetectorGateVersion = .current,
    groundTruthCount: Int,
    fixtureCount: Int,
    fixtures: [DualLaneFixtureResult]
  ) {
    self.schema = schema
    self.version = version
    self.groundTruthCount = groundTruthCount
    self.fixtureCount = fixtureCount
    self.fixtures = fixtures
    self.passed = fixtures.allSatisfy(\.passed)
    self.failedFixtureCount = fixtures.filter { !$0.passed }.count
    self.unreviewedFixtureCount = fixtures.filter { $0.unreviewed }.count
    self.reviewedCaseCount = fixtures.reduce(0) { $0 + $1.reviewedCaseCount }
    self.summary = Self.buildSummary(fixtures: fixtures, fixtureCount: fixtureCount)
  }

  private static func buildSummary(
    fixtures: [DualLaneFixtureResult],
    fixtureCount: Int
  ) -> String {
    let failures = fixtures
      .filter { !$0.passed }
      .map { fixture in
        if fixture.unreviewed {
          return "\(fixture.fixtureID): UNREVIEWED (fail-closed)"
        }
        var parts: [String] = []
        if let native = fixture.native {
          let m = native.metrics
          parts.append("native: recall=\(m.recall.map { String(format: "%.3f", $0) } ?? "n/a")")
        }
        if let browser = fixture.browser {
          let m = browser.metrics
          parts.append("browser: recall=\(m.recall.map { String(format: "%.3f", $0) } ?? "n/a")")
        }
        if let error = fixture.error {
          parts.append("error: \(error)")
        }
        return "\(fixture.fixtureID): \(parts.joined(separator: ", "))"
      }
    return "dual-lane detector gate: \(fixtures.filter(\.passed).count)/\(fixtureCount) fixtures passed"
      + (failures.isEmpty ? "" : "\n  " + failures.joined(separator: "\n  "))
  }
}

// MARK: - Per-Fixture Dual-Lane Result

/// Gate outcome for a single corpus fixture across both lanes.
public struct DualLaneFixtureResult: Codable, Sendable {
  /// Fixture file name (matches `ReviewedGroundTruthCase.fixtureID`).
  public let fixtureID: String
  /// SHA-256 of the fixture bytes measured (nil when inspection failed).
  public let sourceDigest: String?
  /// Number of reviewed cases this fixture was measured against.
  public let reviewedCaseCount: Int
  /// True when the fixture has no reviewed ground truth (fail-closed).
  public let unreviewed: Bool
  /// The measured native lane (nil when unreviewed or inspection failed).
  public let native: DetectorLaneResult?
  /// The measured browser lane (nil when unreviewed or browser unavailable).
  public let browser: DetectorLaneResult?
  /// Inspection failure message, when the pipeline could not read the fixture.
  public let error: String?

  /// The fixture passes only when both lanes pass (or browser is unavailable
  /// and native passes).  A fixture is failed-closed when unreviewed.
  public var passed: Bool {
    if unreviewed { return false }
    if error != nil { return false }
    let nativePass = native?.metrics.passed ?? true  // absent lane is not a failure
    let browserPass = browser?.metrics.passed ?? true
    return nativePass && browserPass
  }

  public init(
    fixtureID: String,
    sourceDigest: String?,
    reviewedCaseCount: Int,
    unreviewed: Bool,
    native: DetectorLaneResult?,
    browser: DetectorLaneResult?,
    error: String?
  ) {
    self.fixtureID = fixtureID
    self.sourceDigest = sourceDigest
    self.reviewedCaseCount = reviewedCaseCount
    self.unreviewed = unreviewed
    self.native = native
    self.browser = browser
    self.error = error
  }
}

// MARK: - The Dual-Lane Gate

/// Executes the detector measurement gate over both native and browser
/// pipeline output against the same reviewed ground truth.
public struct DualLaneDetectorGate: Sendable {
  public let measurement: DetectorSemanticMeasurement
  public let groundTruth: ReviewedCandidateGroundTruth

  public init(
    measurement: DetectorSemanticMeasurement = DetectorSemanticMeasurement(),
    groundTruth: ReviewedCandidateGroundTruth = ReviewedCandidateGroundTruth.canonical()
  ) {
    self.measurement = measurement
    self.groundTruth = groundTruth
  }

  /// Run the gate over the given corpus fixtures using both lanes.
  ///
  /// - Parameters:
  ///   - provider: the native pipeline provider (PDFKit in production).
  ///   - fixtures: corpus fixture URLs, measured individually.
  ///   - nativeCandidates: native pipeline mapping; injectable for mutation tests.
  ///   - browserCandidates: optional browser pipeline candidates per fixture;
  ///     when nil, the browser lane is skipped for that fixture.
  /// - Returns: the gate result. `passed` is false when any fixture
  ///   regressed on either lane, is unreviewed, or could not be inspected.
  public func run(
    provider: PDFProvider,
    fixtures: [URL],
    nativeCandidates: (DocumentInspection) -> [DetectorCandidate] = NativeDetectorGate.liveCandidates,
    browserCandidates: ((URL) -> [DetectorCandidate])? = nil
  ) throws -> DualLaneDetectorGateResult {
    let ordered = fixtures
      .map { $0.standardizedFileURL }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var results: [DualLaneFixtureResult] = []
    for url in ordered {
      let fixtureID = url.lastPathComponent
      do {
        let inspection = try provider.inspect(url: url)
        let scoped = groundTruth.cases(forFixture: fixtureID)
        guard !scoped.isEmpty else {
          results.append(DualLaneFixtureResult(
            fixtureID: fixtureID,
            sourceDigest: inspection.source.sha256,
            reviewedCaseCount: 0,
            unreviewed: true,
            native: nil,
            browser: nil,
            error: nil
          ))
          continue
        }
        let scopedTruth = ReviewedCandidateGroundTruth(cases: scoped)

        // Native lane
        let nativeLane = measurement.measure(
          lane: .native,
          groundTruth: groundTruth,
          candidates: nativeCandidates(inspection),
          fixtureID: fixtureID
        )

        // Browser lane (optional)
        let browserLane: DetectorLaneResult?
        if let browserCandidates = browserCandidates {
          let browserCands = browserCandidates(url)
          browserLane = measurement.measure(
            lane: .browser,
            groundTruth: groundTruth,
            candidates: browserCands,
            fixtureID: fixtureID
          )
        } else {
          browserLane = nil
        }

        results.append(DualLaneFixtureResult(
          fixtureID: fixtureID,
          sourceDigest: inspection.source.sha256,
          reviewedCaseCount: scoped.count,
          unreviewed: false,
          native: nativeLane,
          browser: browserLane,
          error: nil
        ))
      } catch {
        results.append(DualLaneFixtureResult(
          fixtureID: fixtureID,
          sourceDigest: nil,
          reviewedCaseCount: 0,
          unreviewed: false,
          native: nil,
          browser: nil,
          error: String(describing: error)
        ))
      }
    }

    return DualLaneDetectorGateResult(
      groundTruthCount: groundTruth.cases.count,
      fixtureCount: ordered.count,
      fixtures: results
    )
  }
}
