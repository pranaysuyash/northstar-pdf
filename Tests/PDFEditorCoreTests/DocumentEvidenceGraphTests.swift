import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Document Evidence Graph Substrate Tests")
struct DocumentEvidenceGraphTests {
  @Test("DocumentEvidenceGraph construction and node addition")
  func testGraphConstruction() {
    var graph = DocumentEvidenceGraph(sourceDigest: "test-hash-1234")
    #expect(graph.sourceDigest == "test-hash-1234")
    #expect(graph.nodes.isEmpty)

    let pageRegion = PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 10, width: 100, height: 50))
    let node = EvidenceGraphNode(
      id: "node-1",
      kind: .candidate,
      label: "Voter Name",
      text: "Pranay",
      region: pageRegion,
      sourceDigest: "test-hash-1234",
      confidence: 0.95
    )
    graph.nodes.append(node)

    #expect(graph.nodes.count == 1)
    #expect(graph.nodes.first?.text == "Pranay")
    #expect(graph.nodes.first?.region?.pageIndex == 0)
  }

  @Test("DocumentEvidenceGraph relational edges")
  func testGraphEdges() {
    var graph = DocumentEvidenceGraph(sourceDigest: "test-hash-1234")
    let region1 = PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 10, width: 100, height: 20))
    let region2 = PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 35, width: 100, height: 20))

    let node1 = EvidenceGraphNode(id: "node-1", kind: .clause, label: "Section 1", text: "Obligation clause", region: region1, sourceDigest: "test-hash-1234", confidence: 1.0)
    let node2 = EvidenceGraphNode(id: "node-2", kind: .field, label: "signature", text: "Signed", region: region2, sourceDigest: "test-hash-1234", confidence: 1.0)

    graph.nodes.append(contentsOf: [node1, node2])
    let edge = EvidenceGraphEdge(sourceID: "node-1", targetID: "node-2", relationship: .references)
    graph.edges.append(edge)

    #expect(graph.edges.count == 1)
    #expect(graph.edges.first?.sourceID == "node-1")
    #expect(graph.edges.first?.targetID == "node-2")
    #expect(graph.edges.first?.relationship == .references)
  }

  @Test("Grounded query returns physical coordinate citations")
  func testGroundedQueryWithCitations() {
    var graph = DocumentEvidenceGraph(sourceDigest: "test-hash-1234")
    let region = PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 50, y: 100, width: 200, height: 30))
    let node = EvidenceGraphNode(
      id: "node-voter",
      kind: .field,
      label: "Applicant Name",
      text: "First Name followed by Middle Name: Pranay",
      region: region,
      sourceDigest: "test-hash-1234",
      confidence: 0.98
    )
    graph.nodes.append(node)

    let result = graph.queryEvidence(query: "Applicant Name")
    #expect(result.answer.contains("Applicant Name"))
    #expect(!result.citations.isEmpty)
    #expect(result.citations.first?.pageIndex == 0)
    #expect(result.route == .onDeviceNeuralEngine)
  }

  @Test("Grounded query returns strict doctrine negative assertion when unsupported")
  func testGroundedQueryNegativeAssertion() {
    let graph = DocumentEvidenceGraph(sourceDigest: "test-hash-1234")
    let result = graph.queryEvidence(query: "Unrelated non-existent term")
    #expect(result.answer.contains("Could not establish this from the provided document evidence"))
    #expect(result.citations.isEmpty)
  }

  @Test("CapabilityRoute verifiable disclosure badge")
  func testCapabilityRouteDisclosures() {
    let route = CapabilityRoute.onDeviceNeuralEngine
    #expect(route.disclosureBadge.contains("On-device"))
    #expect(route.disclosureBadge.contains("Zero Network Egress"))
  }
}
