import Foundation
import Testing

@testable import PDFEditorCore

struct ProviderCompanionProtocolTests {
  private let digestA = String(repeating: "a", count: 64)
  private let digestB = String(repeating: "b", count: 64)

  private func hello() -> CompanionHello {
    CompanionHello(
      sessionID: "session-test",
      clientNonce: "client-test",
      origin: "https://pdf-editor.local",
      requestedCapabilities: ["ocr.textBounds"]
    )
  }

  private func request() -> CompanionCapabilityRequest {
    CompanionCapabilityRequest(
      sessionID: "session-test",
      requestID: "request-test",
      clientNonce: "client-test",
      serverNonce: "server-test",
      capability: "ocr.textBounds",
      sourceDigest: digestA,
      sourceByteCount: 10,
      sourcePageCount: 1,
      maxOutputBytes: 100,
      timeoutMs: 1000,
      inputMode: "source-bytes",
      sourceBytesBase64: "cGRm",
      operationIDs: ["operation-test"]
    )
  }

  @Test func protocolMessagesRoundTripAndValidate() throws {
    let clientHello = hello()
    let serverHello = CompanionHelloResponse(
      sessionID: clientHello.sessionID,
      serverNonce: "server-test",
      accepted: true,
      companionID: "companion-test",
      providerIDs: ["native-vision"]
    )
    let capabilityRequest = request()
    let capabilityResponse = CompanionCapabilityResponse(
      sessionID: capabilityRequest.sessionID,
      requestID: capabilityRequest.requestID,
      state: .completed,
      providerID: "native-vision",
      outputDigest: digestB,
      reasonCodes: ["local-only"]
    )
    let cancellation = CompanionCancellation(
      sessionID: capabilityRequest.sessionID,
      requestID: capabilityRequest.requestID,
      clientNonce: capabilityRequest.clientNonce,
      serverNonce: capabilityRequest.serverNonce
    )

    try clientHello.validate()
    try serverHello.validate(against: clientHello)
    try capabilityRequest.validate()
    try capabilityResponse.validate(against: capabilityRequest)
    try cancellation.validate(against: capabilityRequest)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    #expect(try decoder.decode(CompanionHello.self, from: encoder.encode(clientHello)) == clientHello)
    #expect(try decoder.decode(CompanionCapabilityRequest.self, from: encoder.encode(capabilityRequest)) == capabilityRequest)
    #expect(try decoder.decode(CompanionCapabilityResponse.self, from: encoder.encode(capabilityResponse)) == capabilityResponse)
  }

  @Test func nativeDecodesTheBrowserCompanionFixture() throws {
    struct Fixture: Decodable {
      let hello: CompanionHello
      let helloResponse: CompanionHelloResponse
      let request: CompanionCapabilityRequest
      let response: CompanionCapabilityResponse
      let cancel: CompanionCancellation
    }

    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let fixtureURL = repositoryRoot.appendingPathComponent("Tests/fixtures/provider_companion_protocol_fixture.json")
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL))

    try fixture.hello.validate()
    try fixture.helloResponse.validate(against: fixture.hello)
    try fixture.request.validate()
    try fixture.response.validate(against: fixture.request)
    try fixture.cancel.validate(against: fixture.request)
    #expect(fixture.request.capability == "ocr.textBounds")
    #expect(fixture.response.state == .completed)
  }

  @Test func sourceBytesAreRequiredOnlyForSourceBytesMode() {
    var value = request()
    value = CompanionCapabilityRequest(
      sessionID: value.sessionID,
      requestID: value.requestID,
      clientNonce: value.clientNonce,
      serverNonce: value.serverNonce,
      capability: value.capability,
      sourceDigest: value.sourceDigest,
      sourceByteCount: value.sourceByteCount,
      sourcePageCount: value.sourcePageCount,
      maxOutputBytes: value.maxOutputBytes,
      timeoutMs: value.timeoutMs,
      inputMode: "file-token",
      sourceBytesBase64: nil,
      sourceFileToken: "file-token-test",
      operationIDs: value.operationIDs
    )
    #expect(throws: Never.self) { try value.validate() }

    value = CompanionCapabilityRequest(
      sessionID: value.sessionID,
      requestID: value.requestID,
      clientNonce: value.clientNonce,
      serverNonce: value.serverNonce,
      capability: value.capability,
      sourceDigest: value.sourceDigest,
      sourceByteCount: value.sourceByteCount,
      sourcePageCount: value.sourcePageCount,
      maxOutputBytes: value.maxOutputBytes,
      timeoutMs: value.timeoutMs,
      inputMode: "source-bytes",
      sourceBytesBase64: nil,
      operationIDs: value.operationIDs
    )
    #expect(throws: CompanionProtocolError.invalid("source bytes are required for source-bytes mode")) {
      try value.validate()
    }
  }

  @Test func sourceDigestAndCancellationIdentityAreFailClosed() {
    var value = request()
    value = CompanionCapabilityRequest(
      sessionID: value.sessionID,
      requestID: value.requestID,
      clientNonce: value.clientNonce,
      serverNonce: value.serverNonce,
      capability: value.capability,
      sourceDigest: "bad",
      sourceByteCount: value.sourceByteCount,
      sourcePageCount: value.sourcePageCount,
      maxOutputBytes: value.maxOutputBytes,
      timeoutMs: value.timeoutMs,
      inputMode: value.inputMode,
      sourceBytesBase64: value.sourceBytesBase64,
      sourceFileToken: value.sourceFileToken,
      operationIDs: value.operationIDs
    )
    #expect(throws: CompanionProtocolError.invalid("source digest must be a 64-character hex digest")) {
      try value.validate()
    }

    let valid = request()
    let cancellation = CompanionCancellation(
      sessionID: valid.sessionID,
      requestID: valid.requestID,
      clientNonce: valid.clientNonce,
      serverNonce: "wrong-server"
    )
    #expect(throws: CompanionProtocolError.invalid("cancellation identity mismatch")) {
      try cancellation.validate(against: valid)
    }
  }
}
