import Foundation

/// Provider-neutral resource governance facts and budgets. The native app may
/// collect richer signals, but it serializes the same envelope as the browser.
public struct BrowserResourceEnvironment: Codable, Equatable, Hashable, Sendable {
  public struct Viewport: Codable, Equatable, Hashable, Sendable {
    public let width: Double
    public let height: Double
    public init(width: Double = 0, height: Double = 0) {
      self.width = max(0, width)
      self.height = max(0, height)
    }
  }

  public struct Connection: Codable, Equatable, Hashable, Sendable {
    public let effectiveType: String
    public let saveData: Bool?
    public init(effectiveType: String = "unknown", saveData: Bool? = nil) {
      self.effectiveType = effectiveType
      self.saveData = saveData
    }
  }

  public struct Memory: Codable, Equatable, Hashable, Sendable {
    public let state: String
    public let usedJSHeapSize: Double?
    public let jsHeapSizeLimit: Double?
    public init(state: String = "unknown", usedJSHeapSize: Double? = nil, jsHeapSizeLimit: Double? = nil) {
      self.state = state
      self.usedJSHeapSize = usedJSHeapSize
      self.jsHeapSizeLimit = jsHeapSizeLimit
    }
  }

  public struct Storage: Codable, Equatable, Hashable, Sendable {
    public let state: String
    public let quotaBytes: Double?
    public let usageBytes: Double?
    public init(state: String = "unknown", quotaBytes: Double? = nil, usageBytes: Double? = nil) {
      self.state = state
      self.quotaBytes = quotaBytes
      self.usageBytes = usageBytes
    }
  }

  public let cpuLogicalCores: Int?
  public let deviceMemoryGB: Double?
  public let devicePixelRatio: Double
  public let viewport: Viewport
  public let connection: Connection
  public let memory: Memory
  public let storage: Storage
  public let browserFamily: String?

  public init(
    cpuLogicalCores: Int? = nil,
    deviceMemoryGB: Double? = nil,
    devicePixelRatio: Double = 1,
    viewport: Viewport = Viewport(),
    connection: Connection = Connection(),
    memory: Memory = Memory(),
    storage: Storage = Storage(),
    browserFamily: String? = nil
  ) {
    self.cpuLogicalCores = cpuLogicalCores.map { max(0, $0) }
    self.deviceMemoryGB = deviceMemoryGB.map { max(0, $0) }
    self.devicePixelRatio = max(1, devicePixelRatio)
    self.viewport = viewport
    self.connection = connection
    self.memory = memory
    self.storage = storage
    self.browserFamily = browserFamily
  }
}

public struct BrowserResourceDocument: Codable, Equatable, Hashable, Sendable {
  public let byteCount: Int
  public let pageCount: Int
  public let maxPageAreaPoints: Double
  public let maxPageDimensionPoints: Double
  public let rotatedPageCount: Int
  public let rasterPageCount: Int
  public let selectableTextPageCount: Int
  public let nativeFieldCount: Int
  public let candidateCount: Int
  public let maxImagePixelsPerPage: Int
  public let hasAttachments: Bool
  public let isEncrypted: Bool
  public let isMalformed: Bool

  public init(
    byteCount: Int = 0,
    pageCount: Int = 1,
    maxPageAreaPoints: Double = 612 * 792,
    maxPageDimensionPoints: Double = 792,
    rotatedPageCount: Int = 0,
    rasterPageCount: Int = 0,
    selectableTextPageCount: Int = 0,
    nativeFieldCount: Int = 0,
    candidateCount: Int = 0,
    maxImagePixelsPerPage: Int = 0,
    hasAttachments: Bool = false,
    isEncrypted: Bool = false,
    isMalformed: Bool = false
  ) {
    let pages = max(1, pageCount)
    self.byteCount = max(0, byteCount)
    self.pageCount = pages
    self.maxPageAreaPoints = max(0, maxPageAreaPoints)
    self.maxPageDimensionPoints = max(0, maxPageDimensionPoints)
    self.rotatedPageCount = min(pages, max(0, rotatedPageCount))
    self.rasterPageCount = min(pages, max(0, rasterPageCount))
    self.selectableTextPageCount = min(pages, max(0, selectableTextPageCount))
    self.nativeFieldCount = max(0, nativeFieldCount)
    self.candidateCount = max(0, candidateCount)
    self.maxImagePixelsPerPage = max(0, maxImagePixelsPerPage)
    self.hasAttachments = hasAttachments
    self.isEncrypted = isEncrypted
    self.isMalformed = isMalformed
  }
}

public struct BrowserResourceRenderBudget: Codable, Equatable, Hashable, Sendable {
  public let maxDevicePixelRatio: Double
  public let maxCanvasPixels: Int
  public let maxPagePixels: Int
  public let maxPageScale: Double
  public let maxConcurrentPages: Int
  public let chunkPages: Int
  public let yieldEveryMs: Int
  public let workerCount: Int
  public let allowHighDPI: Bool
  public let reasons: [String]
}

public struct BrowserResourceOCRBudget: Codable, Equatable, Hashable, Sendable {
  public let state: String
  public let enabled: Bool
  public let maxConcurrentJobs: Int
  public let maxPixelsPerPage: Int
  public let maxPagesPerBatch: Int
  public let maxBatchPixels: Int
  public let yieldEveryMs: Int
  public let cancellationTimeoutMs: Int
  public let requiresUserConfirmation: Bool
  public let reasons: [String]
}

public struct BrowserResourceBatchBudget: Codable, Equatable, Hashable, Sendable {
  public let state: String
  public let enabled: Bool
  public let maxDocuments: Int
  public let maxTotalBytes: Int
  public let maxTotalPages: Int
  public let maxConcurrentDocuments: Int
  public let checkpointEveryDocuments: Int
  public let checkpointEveryPages: Int
  public let reasons: [String]
}

public struct BrowserResourceRecoveryBudget: Codable, Equatable, Hashable, Sendable {
  public let checkpointRequired: Bool
  public let retryCount: Int
  public let backoffMs: Int
  public let staleDigestRequired: Bool
  public let resumeSupported: Bool
  public let partialOutputAllowed: Bool
  public let cancellationSupported: Bool
  public let reasons: [String]
}

public struct BrowserResourcePolicy: Codable, Equatable, Hashable, Sendable {
  public static let contractName = "pdf-editor.browser-resource-policy"

  public struct Version: Codable, Equatable, Hashable, Sendable {
    public let major: Int
    public let minor: Int
  }

  public struct Header: Codable, Equatable, Hashable, Sendable {
    public let contractName: String
    public let version: Version
    public let generatedAt: String
    public let sourceDigest: String?
    public let provider: [String: String]
  }

  public struct Request: Codable, Equatable, Hashable, Sendable {
    public let renderMode: String
    public let ocrRequested: Bool
    public let batchRequested: Bool
    public let highDPIRequested: Bool
  }

  public struct Decision: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let capability: String
    public let state: String
    public let reasonCode: String
    public let evidence: [String: BrowserResourceEvidenceValue]
  }

  public struct Safety: Codable, Equatable, Hashable, Sendable {
    public let contentLogged: Bool
    public let networkAccessAttempted: Bool
    public let sourceBytesMutated: Bool
    public let partialOutputPromoted: Bool
    public let cancellationSupported: Bool
  }

  public struct Budgets: Codable, Equatable, Hashable, Sendable {
    public let render: BrowserResourceRenderBudget
    public let ocr: BrowserResourceOCRBudget
    public let batch: BrowserResourceBatchBudget
    public let recovery: BrowserResourceRecoveryBudget
  }

  public struct Payload: Codable, Equatable, Hashable, Sendable {
    public let environment: BrowserResourceEnvironment
    public let document: BrowserResourceDocument
    public let request: Request
    public let budgets: Budgets
    public let decisions: [Decision]
    public let safety: Safety

    public init(
      environment: BrowserResourceEnvironment,
      document: BrowserResourceDocument,
      request: Request,
      budgets: Budgets,
      decisions: [Decision],
      safety: Safety
    ) {
      self.environment = environment
      self.document = document
      self.request = request
      self.budgets = budgets
      self.decisions = decisions
      self.safety = safety
    }
  }

  public let header: Header
  public let payload: Payload

  public init(
    header: Header,
    payload: Payload
  ) {
    self.header = header
    self.payload = payload
  }

  public func validate(expectedSourceDigest: String? = nil) throws {
    guard header.contractName == Self.contractName, header.version.major == 1 else {
      throw BrowserResourcePolicyError.invalid("unsupported resource policy contract")
    }
    if let expectedSourceDigest, header.sourceDigest != expectedSourceDigest {
      throw BrowserResourcePolicyError.invalid("resource policy source digest mismatch")
    }
    guard payload.budgets.render.maxConcurrentPages >= 1,
      payload.budgets.ocr.maxConcurrentJobs >= 1,
      payload.budgets.batch.maxConcurrentDocuments >= 1,
      payload.budgets.recovery.staleDigestRequired,
      payload.budgets.recovery.resumeSupported,
      !payload.budgets.recovery.partialOutputAllowed,
      payload.safety.contentLogged == false,
      payload.safety.networkAccessAttempted == false,
      payload.safety.sourceBytesMutated == false,
      payload.safety.partialOutputPromoted == false,
      payload.safety.cancellationSupported
    else {
      throw BrowserResourcePolicyError.invalid("resource policy safety or budget invariant failed")
    }
    let allowed = Set(["enabled", "limited", "deferred", "unknown", "blocked"])
    guard payload.decisions.allSatisfy({ allowed.contains($0.state) }) else {
      throw BrowserResourcePolicyError.invalid("resource policy contains unknown decision state")
    }
  }
}

public enum BrowserResourcePolicyError: Error, LocalizedError, Equatable, Sendable {
  case invalid(String)
  public var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}
public enum BrowserResourceEvidenceValue: Codable, Equatable, Hashable, Sendable {
    case boolean(Bool)
    case number(Double)
    case string(String)
    case null

    public init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() { self = .null }
      else if let value = try? container.decode(Bool.self) { self = .boolean(value) }
      else if let value = try? container.decode(Double.self) { self = .number(value) }
      else if let value = try? container.decode(String.self) { self = .string(value) }
      else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported evidence value") }
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .boolean(let value): try container.encode(value)
      case .number(let value): try container.encode(value)
      case .string(let value): try container.encode(value)
      case .null: try container.encodeNil()
      }
    }
  }
