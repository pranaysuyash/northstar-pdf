import Foundation

// MARK: - Canonical Document Evidence Graph Substrate [TASK-B1, TASK-B2]

/// A typed, navigable graph unifying elements, index, layout, tables, entities,
/// annotations, and execution receipts without disconnected AI shadow stores.
public struct DocumentEvidenceGraph: Codable, Equatable, Sendable {
  public var nodes: [EvidenceGraphNode]
  public var edges: [EvidenceGraphEdge]
  public let sourceDigest: String
  public let generatedAt: Date

  public init(
    nodes: [EvidenceGraphNode] = [],
    edges: [EvidenceGraphEdge] = [],
    sourceDigest: String,
    generatedAt: Date = Date()
  ) {
    self.nodes = nodes
    self.edges = edges
    self.sourceDigest = sourceDigest
    self.generatedAt = generatedAt
  }

  // MARK: - Construction from Canonical Inspection

  public static func build(
    from inspection: DocumentInspection,
    tables: [ExtractedTable] = [],
    nerEntities: [NEREntity] = [],
    annotations: [AnnotationMark] = []
  ) -> DocumentEvidenceGraph {
    var nodes: [EvidenceGraphNode] = []
    var edges: [EvidenceGraphEdge] = []
    let sourceDigest = inspection.source.sha256

    // Root Document Node
    let docNodeID = "doc:\(sourceDigest.prefix(12))"
    nodes.append(EvidenceGraphNode(
      id: docNodeID,
      kind: .document,
      label: inspection.source.fileName,
      text: nil,
      region: nil,
      sourceDigest: sourceDigest,
      confidence: 1.0
    ))

    // Page Nodes
    for page in inspection.pages {
      let pageNodeID = "page:\(page.pageIndex)"
      nodes.append(EvidenceGraphNode(
        id: pageNodeID,
        kind: .page,
        label: page.pageLabel.isEmpty ? "Page \(page.pageIndex + 1)" : page.pageLabel,
        text: nil,
        region: PDFPageRegion(pageIndex: page.pageIndex, rect: page.bounds),
        sourceDigest: sourceDigest,
        confidence: 1.0
      ))
      edges.append(EvidenceGraphEdge(
        sourceID: docNodeID,
        targetID: pageNodeID,
        relationship: .contains
      ))
    }

    // Form Field Nodes
    for field in inspection.fields {
      let fieldNodeID = "field:\(field.id)"
      nodes.append(EvidenceGraphNode(
        id: fieldNodeID,
        kind: .field,
        label: field.name,
        text: field.value,
        region: PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds),
        sourceDigest: sourceDigest,
        confidence: 1.0
      ))
      edges.append(EvidenceGraphEdge(
        sourceID: "page:\(field.pageIndex)",
        targetID: fieldNodeID,
        relationship: .contains
      ))
    }

    // Candidate Region Nodes
    for candidate in inspection.candidates {
      let candNodeID = "candidate:\(candidate.id.uuidString)"
      let candidateLabel = candidate.displayName ?? candidate.labelText ?? "Candidate Region (\(candidate.kind.rawValue))"
      nodes.append(EvidenceGraphNode(
        id: candNodeID,
        kind: .candidate,
        label: candidateLabel,
        text: nil,
        region: PDFPageRegion(pageIndex: candidate.pageIndex, rect: candidate.bounds),
        sourceDigest: sourceDigest,
        confidence: candidate.score
      ))
      edges.append(EvidenceGraphEdge(
        sourceID: "page:\(candidate.pageIndex)",
        targetID: candNodeID,
        relationship: .contains
      ))
    }

    // Table Nodes
    for (idx, table) in tables.enumerated() {
      let tableNodeID = "table:\(table.pageIndex):\(idx)"
      let headersSummary = table.headers?.joined(separator: ", ") ?? "Table"
      nodes.append(EvidenceGraphNode(
        id: tableNodeID,
        kind: .table,
        label: "Table (\(table.rows)x\(table.columns)): \(headersSummary)",
        text: table.cells.map { $0.joined(separator: " | ") }.joined(separator: "\n"),
        region: PDFPageRegion(pageIndex: table.pageIndex, rect: table.bounds),
        sourceDigest: sourceDigest,
        confidence: table.confidence
      ))
      edges.append(EvidenceGraphEdge(
        sourceID: "page:\(table.pageIndex)",
        targetID: tableNodeID,
        relationship: .contains
      ))
    }

    // Entity Nodes (NER)
    for (idx, entity) in nerEntities.enumerated() {
      let entityNodeID = "entity:\(entity.sourcePageIndex):\(idx)"
      nodes.append(EvidenceGraphNode(
        id: entityNodeID,
        kind: .entity,
        label: "[\(entity.type.rawValue)] \(entity.value)",
        text: entity.value,
        region: nil,
        sourceDigest: sourceDigest,
        confidence: entity.confidence
      ))
      edges.append(EvidenceGraphEdge(
        sourceID: "page:\(entity.sourcePageIndex)",
        targetID: entityNodeID,
        relationship: .contains
      ))
    }

    // Annotations
    for mark in annotations {
      let markNodeID = "mark:\(mark.id.uuidString)"
      nodes.append(EvidenceGraphNode(
        id: markNodeID,
        kind: .annotation,
        label: "\(mark.type.rawValue.capitalized) Annotation",
        text: mark.selectedText.isEmpty ? mark.note : mark.selectedText,
        region: PDFPageRegion(pageIndex: mark.pageIndex, rect: mark.bounds),
        sourceDigest: sourceDigest,
        confidence: 1.0
      ))
      edges.append(EvidenceGraphEdge(
        sourceID: "page:\(mark.pageIndex)",
        targetID: markNodeID,
        relationship: .annotates
      ))
    }

    return DocumentEvidenceGraph(
      nodes: nodes,
      edges: edges,
      sourceDigest: sourceDigest
    )
  }

  // MARK: - Grounded Query Engine [TASK-B2]

  /// Query the graph for assertions backed by physical document region anchors.
  /// If insufficient evidence exists, returns a doctrine-compliant negative assertion.
  public func queryEvidence(query: String) -> GroundedQueryResult {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else {
      return GroundedQueryResult(
        answer: "Please enter a specific question about this document.",
        citations: [],
        confidence: 0.0,
        route: .onDeviceNeuralEngine
      )
    }

    // Search nodes with token overlap
    let queryTokens = normalized.split(separator: " ").map(String.init)
    var matchedNodes: [(node: EvidenceGraphNode, score: Double)] = []

    for node in nodes {
      var score: Double = 0.0
      let labelLower = node.label.lowercased()
      let textLower = node.text?.lowercased() ?? ""

      for token in queryTokens {
        if labelLower.contains(token) { score += 2.0 }
        if textLower.contains(token) { score += 1.5 }
      }

      if score > 0 {
        matchedNodes.append((node, score * node.confidence))
      }
    }

    matchedNodes.sort { $0.score > $1.score }

    guard let bestMatch = matchedNodes.first, bestMatch.score >= 1.0 else {
      return GroundedQueryResult(
        answer: "Could not establish this from the provided document evidence.",
        citations: [],
        confidence: 0.0,
        route: .onDeviceNeuralEngine
      )
    }

    let topNodes = matchedNodes.prefix(3)
    let citations: [EvidenceCitation] = topNodes.compactMap { item in
      guard let region = item.node.region else { return nil }
      return EvidenceCitation(
        nodeID: item.node.id,
        pageIndex: region.pageIndex,
        rect: region.rect,
        sourceDigest: item.node.sourceDigest,
        excerpt: item.node.label,
        relevanceScore: min(1.0, item.score / 5.0)
      )
    }

    let summaryParts = topNodes.map { "• \($0.node.label)" }.joined(separator: "\n")
    let answerText = "Found \(topNodes.count) anchored document element(s):\n\(summaryParts)"

    return GroundedQueryResult(
      answer: answerText,
      citations: citations,
      confidence: min(1.0, bestMatch.score / 4.0),
      route: .onDeviceNeuralEngine
    )
  }
}

// MARK: - Evidence Graph Node

public struct EvidenceGraphNode: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let kind: NodeKind
  public let label: String
  public let text: String?
  public let region: PDFPageRegion?
  public let sourceDigest: String
  public let confidence: Double

  public enum NodeKind: String, Codable, Sendable {
    case document
    case page
    case section
    case clause
    case table
    case field
    case candidate
    case entity
    case annotation
    case receipt
  }

  public init(
    id: String,
    kind: NodeKind,
    label: String,
    text: String?,
    region: PDFPageRegion?,
    sourceDigest: String,
    confidence: Double
  ) {
    self.id = id
    self.kind = kind
    self.label = label
    self.text = text
    self.region = region
    self.sourceDigest = sourceDigest
    self.confidence = confidence
  }
}

// MARK: - Evidence Graph Edge

public struct EvidenceGraphEdge: Codable, Equatable, Sendable {
  public let sourceID: String
  public let targetID: String
  public let relationship: EdgeRelationship

  public enum EdgeRelationship: String, Codable, Sendable {
    case contains
    case references
    case annotates
    case conflictsWith
    case verifies
    case derivedFrom
  }

  public init(
    sourceID: String,
    targetID: String,
    relationship: EdgeRelationship
  ) {
    self.sourceID = sourceID
    self.targetID = targetID
    self.relationship = relationship
  }
}

// MARK: - Grounded Citations & Query Results [TASK-B2, TASK-B3]

public struct EvidenceCitation: Codable, Equatable, Identifiable, Sendable {
  public var id: String { nodeID }
  public let nodeID: String
  public let pageIndex: Int
  public let rect: PDFRect
  public var bounds: PDFRect { rect }
  public let sourceDigest: String
  public let excerpt: String
  public let relevanceScore: Double

  public init(
    nodeID: String,
    pageIndex: Int,
    rect: PDFRect,
    sourceDigest: String,
    excerpt: String,
    relevanceScore: Double
  ) {
    self.nodeID = nodeID
    self.pageIndex = pageIndex
    self.rect = rect
    self.sourceDigest = sourceDigest
    self.excerpt = excerpt
    self.relevanceScore = relevanceScore
  }
}

public struct GroundedQueryResult: Codable, Equatable, Sendable {
  public let answer: String
  public let citations: [EvidenceCitation]
  public let confidence: Double
  public let route: CapabilityRoute

  public init(
    answer: String,
    citations: [EvidenceCitation],
    confidence: Double,
    route: CapabilityRoute = .onDeviceNeuralEngine
  ) {
    self.answer = answer
    self.citations = citations
    self.confidence = confidence
    self.route = route
  }
}

public enum CapabilityRoute: String, Codable, Sendable {
  case onDeviceNeuralEngine = "On-device (Apple Silicon ANE)"
  case applePrivateCloudCompute = "Apple Private Cloud Compute"
  case hostedProvider = "Hosted Provider (Metadata Scrubbed)"

  public var disclosureBadge: String {
    switch self {
    case .onDeviceNeuralEngine:
      return "● On-device (Neural Engine) — Zero Network Egress"
    case .applePrivateCloudCompute:
      return "● Apple PCC — Cryptographically Verified Isolated Enclave"
    case .hostedProvider:
      return "● External Hosted Provider — Minimal Redacted Scope"
    }
  }
}
