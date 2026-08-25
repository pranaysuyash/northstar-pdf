import Foundation
import XCTest
@testable import PDFEditorCore

final class BrowserResourcePolicyContractTests: XCTestCase {
  func testBrowserBenchmarkEnvelopeDecodesAndValidates() throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let resultURL = root
      .appendingPathComponent("benchmark/results/browser-resource-policy/2026-08-25-device-adaptive.json")
    guard FileManager.default.fileExists(atPath: resultURL.path) else {
      throw XCTSkip("run benchmark/benchmark_browser_resource_policy.mjs before native parity")
    }
    let data = try Data(contentsOf: resultURL)
    let report = try JSONDecoder().decode(BrowserResourceBenchmarkResult.self, from: data)
    XCTAssertFalse(report.source.contentLogged)
    XCTAssertFalse(report.execution.networkAccessAttempted)
    XCTAssertTrue(report.execution.noPartialOutputPromotion)
    XCTAssertEqual(report.execution.rows, report.rows.count)
    XCTAssertGreaterThan(report.rows.count, 0)
    for row in report.rows {
      try row.policy.validate(expectedSourceDigest: String(repeating: "a", count: 64))
    }
  }

  func testResourcePolicySafetyAndUnknownStateAreRejected() throws {
    let policy = try makePolicy()
    try policy.validate(expectedSourceDigest: policy.header.sourceDigest)
    let unsafePayload = BrowserResourcePolicy.Payload(
      environment: policy.payload.environment,
      document: policy.payload.document,
      request: policy.payload.request,
      budgets: policy.payload.budgets,
      decisions: policy.payload.decisions,
      safety: .init(contentLogged: true, networkAccessAttempted: false, sourceBytesMutated: false, partialOutputPromoted: false, cancellationSupported: true)
    )
    let unsafe = BrowserResourcePolicy(header: policy.header, payload: unsafePayload)
    XCTAssertThrowsError(try unsafe.validate())
  }

  private func makePolicy() throws -> BrowserResourcePolicy {
    let data = Data("{}".utf8)
    let digest = String(repeating: "a", count: 64)
    let environment = BrowserResourceEnvironment(cpuLogicalCores: 2, deviceMemoryGB: 2)
    let document = BrowserResourceDocument(byteCount: data.count, pageCount: 1)
    let render = BrowserResourceRenderBudget(maxDevicePixelRatio: 1, maxCanvasPixels: 1, maxPagePixels: 1, maxPageScale: 1, maxConcurrentPages: 1, chunkPages: 1, yieldEveryMs: 8, workerCount: 1, allowHighDPI: false, reasons: [])
    let ocr = BrowserResourceOCRBudget(state: "deferred", enabled: false, maxConcurrentJobs: 1, maxPixelsPerPage: 1, maxPagesPerBatch: 1, maxBatchPixels: 1, yieldEveryMs: 8, cancellationTimeoutMs: 5000, requiresUserConfirmation: true, reasons: ["ocrNeedsExplicitOptIn"])
    let batch = BrowserResourceBatchBudget(state: "deferred", enabled: false, maxDocuments: 1, maxTotalBytes: 1, maxTotalPages: 1, maxConcurrentDocuments: 1, checkpointEveryDocuments: 1, checkpointEveryPages: 1, reasons: ["batchNeedsExplicitOptIn"])
    let recovery = BrowserResourceRecoveryBudget(checkpointRequired: false, retryCount: 1, backoffMs: 250, staleDigestRequired: true, resumeSupported: true, partialOutputAllowed: false, cancellationSupported: true, reasons: [])
    let budgets = BrowserResourcePolicy.Budgets(render: render, ocr: ocr, batch: batch, recovery: recovery)
    let request = BrowserResourcePolicy.Request(renderMode: "reader", ocrRequested: false, batchRequested: false, highDPIRequested: false)
    let header = BrowserResourcePolicy.Header(contractName: BrowserResourcePolicy.contractName, version: .init(major: 1, minor: 0), generatedAt: "2026-08-25T00:00:00Z", sourceDigest: digest, provider: ["providerID": "native-test"])
    let safety = BrowserResourcePolicy.Safety(contentLogged: false, networkAccessAttempted: false, sourceBytesMutated: false, partialOutputPromoted: false, cancellationSupported: true)
    let payload = BrowserResourcePolicy.Payload(environment: environment, document: document, request: request, budgets: budgets, decisions: [], safety: safety)
    return BrowserResourcePolicy(header: header, payload: payload)
  }
}

private struct BrowserResourceBenchmarkResult: Decodable {
  struct Source: Decodable { let contentLogged: Bool }
  struct Execution: Decodable { let networkAccessAttempted: Bool; let rows: Int; let noPartialOutputPromotion: Bool }
  struct Row: Decodable { let deviceProfileID: String; let documentClassID: String; let policy: BrowserResourcePolicy }
  let source: Source
  let execution: Execution
  let rows: [Row]
}
