import Foundation

/// A provider-neutral evidence signal used only to rank and explain a
/// candidate. It is deliberately smaller than CandidateEvidence so a fusion
/// report can be retained without copying document text or pixels.
public struct EvidenceFusionSignal: Codable, Equatable, Hashable, Sendable {
  public let id: String
  public let kind: CandidateEvidenceKind
  public let origin: CandidateEvidenceOrigin
  public let providerID: String?
  public let score: Double
  public let region: PDFRect?

  public init(
    id: String,
    kind: CandidateEvidenceKind,
    origin: CandidateEvidenceOrigin,
    providerID: String? = nil,
    score: Double,
    region: PDFRect? = nil
  ) {
    self.id = id
    self.kind = kind
    self.origin = origin
    self.providerID = providerID
    self.score = score
    self.region = region
  }
}

public struct EvidenceFusionThresholds: Codable, Equatable, Sendable {
  public let accept: Double
  public let review: Double
  public let conflictIoU: Double
  public let highConfidence: Double

  public init(
    accept: Double = 0.72,
    review: Double = 0.45,
    conflictIoU: Double = 0.10,
    highConfidence: Double = 0.80
  ) {
    self.accept = accept
    self.review = review
    self.conflictIoU = conflictIoU
    self.highConfidence = highConfidence
  }
}

public struct EvidenceFusionResult: Codable, Equatable, Hashable, Sendable {
  public let state: String
  public let score: Double
  public let supportScore: Double
  public let coverageScore: Double
  public let agreementScore: Double
  public let evidenceIDs: [String]
  public let independentGroups: [String]
  public let conflict: Bool
  public let reasonCodes: [String]
}

public enum EvidenceFusion {
  private static let thresholds = EvidenceFusionThresholds()

  private static let weights: [CandidateEvidenceKind: Double] = [
    .nativeField: 1.00,
    .manual: 1.00,
    .vectorRectangle: 0.75,
    .vectorLine: 0.75,
    .underline: 0.65,
    .textLabel: 0.65,
    .ocrText: 0.60,
    .spatialRelationship: 0.50,
    .repeatedPattern: 0.50,
    .whitespace: 0.40
  ]

  private static func group(for kind: CandidateEvidenceKind) -> String? {
    switch kind {
    case .nativeField, .manual:
      return "semantic"
    case .vectorRectangle, .vectorLine, .underline, .whitespace:
      return "geometry"
    case .textLabel, .ocrText:
      return "language"
    case .spatialRelationship, .repeatedPattern:
      return "relationship"
    }
  }

  private static func clamp(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(1, max(0, value))
  }

  private static func rounded(_ value: Double) -> Double {
    (clamp(value) * 1_000_000).rounded() / 1_000_000
  }

  private static func intersectionOverUnion(_ left: PDFRect, _ right: PDFRect) -> Double {
    let leftX = min(left.x, left.x + left.width)
    let leftY = min(left.y, left.y + left.height)
    let leftRight = max(left.x, left.x + left.width)
    let leftTop = max(left.y, left.y + left.height)
    let rightX = min(right.x, right.x + right.width)
    let rightY = min(right.y, right.y + right.height)
    let rightRight = max(right.x, right.x + right.width)
    let rightTop = max(right.y, right.y + right.height)
    let intersection = max(0, min(leftRight, rightRight) - max(leftX, rightX))
      * max(0, min(leftTop, rightTop) - max(leftY, rightY))
    let leftArea = max(0, leftRight - leftX) * max(0, leftTop - leftY)
    let rightArea = max(0, rightRight - rightX) * max(0, rightTop - rightY)
    let union = leftArea + rightArea - intersection
    return union > 0 ? intersection / union : 0
  }

  private static func regionAgreement(_ signals: [EvidenceFusionSignal]) -> Double {
    let regions = signals.compactMap(\.region)
    guard regions.count >= 2 else { return 1 }
    var total = 0.0
    var pairs = 0
    for left in regions.indices {
      for right in regions.indices where right > left {
        total += intersectionOverUnion(regions[left], regions[right])
        pairs += 1
      }
    }
    return pairs > 0 ? total / Double(pairs) : 1
  }

  public static func fuse(
    signals: [EvidenceFusionSignal],
    thresholds: EvidenceFusionThresholds = EvidenceFusionThresholds()
  ) -> EvidenceFusionResult {
    guard !signals.isEmpty else {
      return EvidenceFusionResult(
        state: "abstain",
        score: 0,
        supportScore: 0,
        coverageScore: 0,
        agreementScore: 0,
        evidenceIDs: [],
        independentGroups: [],
        conflict: false,
        reasonCodes: ["noEvidence"]
      )
    }
    let weightedTotal = signals.reduce(0.0) { partial, signal in
      partial + clamp(signal.score) * (weights[signal.kind] ?? 0.40)
    }
    let weightTotal = signals.reduce(0.0) { partial, signal in
      partial + (weights[signal.kind] ?? 0.40)
    }
    let supportScore = weightTotal > 0 ? weightedTotal / weightTotal : 0
    let groups = Set(signals.compactMap { group(for: $0.kind) }).sorted()
    let coverageScore = Double(groups.count) / 4.0
    let agreementScore = regionAgreement(signals)
    let highConfidence = signals.filter { clamp($0.score) >= thresholds.highConfidence }
    let conflict = highConfidence.count > 1
      && regionAgreement(highConfidence) < thresholds.conflictIoU
    let score = 0.55 * supportScore + 0.25 * coverageScore + 0.20 * agreementScore
    var reasons = Set<String>()
    if groups.count < 2 { reasons.insert("singleEvidenceFamily") }
    if agreementScore < thresholds.conflictIoU { reasons.insert("lowGeometricAgreement") }
    if conflict { reasons.insert("conflictingHighConfidenceEvidence") }
    let state: String
    if conflict {
      state = "abstain"
    } else if score >= thresholds.accept {
      state = "supported"
      if groups.count >= 2 { reasons.insert("independentEvidenceAgreement") }
    } else if score >= thresholds.review {
      state = "review"
    } else {
      state = "abstain"
      reasons.insert("lowSupport")
    }
    return EvidenceFusionResult(
      state: state,
      score: rounded(score),
      supportScore: rounded(supportScore),
      coverageScore: rounded(coverageScore),
      agreementScore: rounded(agreementScore),
      evidenceIDs: signals.map(\.id).sorted(),
      independentGroups: groups,
      conflict: conflict,
      reasonCodes: reasons.sorted()
    )
  }
}
