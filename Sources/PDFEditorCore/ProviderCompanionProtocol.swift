import Foundation

/// Typed, local-only messages exchanged with an installed capability provider.
/// This protocol is an adapter boundary and does not alter document or edit
/// contracts. The companion receives capability requests, never shell commands.
public enum CompanionMessageState: String, Codable, CaseIterable, Hashable, Sendable {
  case accepted
  case rejected
  case started
  case progress
  case completed
  case abstained
  case failed
  case cancelled
}

public struct CompanionHello: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.companion.hello"

  public let type: String
  public let version: PDFContractVersion
  public let sessionID: String
  public let clientNonce: String
  public let origin: String
  public let requestedCapabilities: [String]
  public let localOnly: Bool

  public init(
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    sessionID: String,
    clientNonce: String,
    origin: String,
    requestedCapabilities: [String],
    localOnly: Bool = true,
    type: String = CompanionHello.contractName
  ) {
    self.type = type
    self.version = version
    self.sessionID = sessionID
    self.clientNonce = clientNonce
    self.origin = origin
    self.requestedCapabilities = requestedCapabilities
    self.localOnly = localOnly
  }

  public func validate() throws {
    guard type == Self.contractName, version.major == 1, version.minor >= 0 else {
      throw CompanionProtocolError.invalid("unsupported companion protocol version")
    }
    guard !sessionID.isEmpty, !clientNonce.isEmpty, !origin.isEmpty else {
      throw CompanionProtocolError.invalid("hello identity is empty")
    }
    guard requestedCapabilities.allSatisfy({ Self.capabilities.contains($0) }), localOnly else {
      throw CompanionProtocolError.invalid("hello capability request is invalid")
    }
  }

  fileprivate static let capabilities: Set<String> = [
    "ocr.textBounds",
    "edit.existingText",
    "validate.independentViewer",
    "validate.rasterDiff"
  ]
}

public struct CompanionHelloResponse: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.companion.hello-response"

  public let type: String
  public let version: PDFContractVersion
  public let sessionID: String
  public let serverNonce: String
  public let accepted: Bool
  public let companionID: String
  public let providerIDs: [String]

  public init(
    sessionID: String,
    serverNonce: String,
    accepted: Bool,
    companionID: String,
    providerIDs: [String],
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    type: String = CompanionHelloResponse.contractName
  ) {
    self.type = type
    self.version = version
    self.sessionID = sessionID
    self.serverNonce = serverNonce
    self.accepted = accepted
    self.companionID = companionID
    self.providerIDs = providerIDs
  }

  public func validate(against hello: CompanionHello? = nil) throws {
    guard type == Self.contractName, version.major == 1, version.minor >= 0 else {
      throw CompanionProtocolError.invalid("unsupported companion protocol version")
    }
    guard !sessionID.isEmpty, !serverNonce.isEmpty, !companionID.isEmpty,
      providerIDs.allSatisfy({ !$0.isEmpty })
    else {
      throw CompanionProtocolError.invalid("hello response identity is empty")
    }
    if let hello {
      try hello.validate()
      guard hello.sessionID == sessionID else {
        throw CompanionProtocolError.invalid("hello response session mismatch")
      }
    }
  }
}

public struct CompanionCapabilityRequest: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.companion.capability-request"

  public let type: String
  public let version: PDFContractVersion
  public let sessionID: String
  public let requestID: String
  public let clientNonce: String
  public let serverNonce: String
  public let capability: String
  public let sourceDigest: String
  public let sourceByteCount: Int
  public let sourcePageCount: Int
  public let maxOutputBytes: Int
  public let timeoutMs: Int
  public let inputMode: String
  public let sourceBytesBase64: String?
  public let sourceFileToken: String?
  public let operationIDs: [String]
  public let localOnly: Bool

  public init(
    sessionID: String,
    requestID: String,
    clientNonce: String,
    serverNonce: String,
    capability: String,
    sourceDigest: String,
    sourceByteCount: Int,
    sourcePageCount: Int,
    maxOutputBytes: Int,
    timeoutMs: Int,
    inputMode: String,
    sourceBytesBase64: String?,
    sourceFileToken: String? = nil,
    operationIDs: [String],
    localOnly: Bool = true,
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    type: String = CompanionCapabilityRequest.contractName
  ) {
    self.type = type
    self.version = version
    self.sessionID = sessionID
    self.requestID = requestID
    self.clientNonce = clientNonce
    self.serverNonce = serverNonce
    self.capability = capability
    self.sourceDigest = sourceDigest
    self.sourceByteCount = sourceByteCount
    self.sourcePageCount = sourcePageCount
    self.maxOutputBytes = maxOutputBytes
    self.timeoutMs = timeoutMs
    self.inputMode = inputMode
    self.sourceBytesBase64 = sourceBytesBase64
    self.sourceFileToken = sourceFileToken
    self.operationIDs = operationIDs
    self.localOnly = localOnly
  }

  public func validate() throws {
    guard type == Self.contractName, version.major == 1, version.minor >= 0 else {
      throw CompanionProtocolError.invalid("unsupported companion protocol version")
    }
    guard !sessionID.isEmpty, !requestID.isEmpty, !clientNonce.isEmpty, !serverNonce.isEmpty else {
      throw CompanionProtocolError.invalid("capability request identity is empty")
    }
    guard CompanionHello.capabilities.contains(capability) else {
      throw CompanionProtocolError.invalid("unsupported companion capability")
    }
    guard Self.isDigest(sourceDigest) else {
      throw CompanionProtocolError.invalid("source digest must be a 64-character hex digest")
    }
    guard sourceByteCount >= 0, sourcePageCount >= 0, maxOutputBytes > 0, timeoutMs > 0 else {
      throw CompanionProtocolError.invalid("capability request limits are invalid")
    }
    guard inputMode == "source-bytes" || inputMode == "file-token" else {
      throw CompanionProtocolError.invalid("input mode is invalid")
    }
    guard operationIDs.allSatisfy({ !$0.isEmpty }), localOnly else {
      throw CompanionProtocolError.invalid("capability request is invalid")
    }
    if inputMode == "source-bytes" {
      guard let sourceBytesBase64, !sourceBytesBase64.isEmpty else {
        throw CompanionProtocolError.invalid("source bytes are required for source-bytes mode")
      }
      guard sourceFileToken == nil else {
        throw CompanionProtocolError.invalid("file token is forbidden for source-bytes mode")
      }
    } else {
      guard sourceBytesBase64 == nil else {
        throw CompanionProtocolError.invalid("source bytes are forbidden for file-token mode")
      }
      guard let sourceFileToken, !sourceFileToken.isEmpty else {
        throw CompanionProtocolError.invalid("source file token is required for file-token mode")
      }
    }
  }

  fileprivate static func isDigest(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy { $0.isHexDigit }
  }
}

public struct CompanionCapabilityResponse: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.companion.capability-response"

  public let type: String
  public let version: PDFContractVersion
  public let sessionID: String
  public let requestID: String
  public let state: CompanionMessageState
  public let providerID: String
  public let outputDigest: String?
  public let reasonCodes: [String]

  public init(
    sessionID: String,
    requestID: String,
    state: CompanionMessageState,
    providerID: String,
    outputDigest: String?,
    reasonCodes: [String],
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    type: String = CompanionCapabilityResponse.contractName
  ) {
    self.type = type
    self.version = version
    self.sessionID = sessionID
    self.requestID = requestID
    self.state = state
    self.providerID = providerID
    self.outputDigest = outputDigest
    self.reasonCodes = reasonCodes
  }

  public func validate(against request: CompanionCapabilityRequest? = nil) throws {
    guard type == Self.contractName, version.major == 1, version.minor >= 0 else {
      throw CompanionProtocolError.invalid("unsupported companion protocol version")
    }
    guard !sessionID.isEmpty, !requestID.isEmpty, !providerID.isEmpty,
      reasonCodes.allSatisfy({ !$0.isEmpty }),
      outputDigest == nil || CompanionCapabilityRequest.isDigest(outputDigest!)
    else {
      throw CompanionProtocolError.invalid("capability response is invalid")
    }
    if let request {
      try request.validate()
      guard request.sessionID == sessionID, request.requestID == requestID else {
        throw CompanionProtocolError.invalid("capability response request mismatch")
      }
    }
  }
}

public struct CompanionCancellation: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.companion.cancel"

  public let type: String
  public let version: PDFContractVersion
  public let sessionID: String
  public let requestID: String
  public let clientNonce: String
  public let serverNonce: String

  public init(
    sessionID: String,
    requestID: String,
    clientNonce: String,
    serverNonce: String,
    version: PDFContractVersion = PDFContractVersion(major: 1, minor: 0),
    type: String = CompanionCancellation.contractName
  ) {
    self.type = type
    self.version = version
    self.sessionID = sessionID
    self.requestID = requestID
    self.clientNonce = clientNonce
    self.serverNonce = serverNonce
  }

  public func validate(against request: CompanionCapabilityRequest? = nil) throws {
    guard type == Self.contractName, version.major == 1, version.minor >= 0 else {
      throw CompanionProtocolError.invalid("unsupported companion protocol version")
    }
    guard !sessionID.isEmpty, !requestID.isEmpty, !clientNonce.isEmpty, !serverNonce.isEmpty else {
      throw CompanionProtocolError.invalid("cancellation identity is empty")
    }
    if let request {
      try request.validate()
      guard request.sessionID == sessionID, request.requestID == requestID,
        request.clientNonce == clientNonce, request.serverNonce == serverNonce
      else {
        throw CompanionProtocolError.invalid("cancellation identity mismatch")
      }
    }
  }
}

public enum CompanionProtocolError: Error, Equatable, LocalizedError, Sendable {
  case invalid(String)

  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}
