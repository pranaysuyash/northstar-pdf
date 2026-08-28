import Foundation

/// Opt-in file bridges for connecting to other systems.
///
/// First principle: every connection is opt-in, per-connection, with consent.
/// The core engine stays offline. Exports are the safe integration bridge.
/// No connection is made without explicit user action.
///
/// Architecture:
/// - `FileBridge` — defines a connection type (export/import format)
/// - `BridgeResult` — outcome of a bridge operation
/// - `BridgeManager` — manages available bridges and their consent state
///
/// Doctrine alignment:
/// - §3: Do things smartly — file-based bridges, no cloud
/// - §8: Capability activation — every bridge is opt-in, consent-gated
/// - §12: Privacy stays value-free — bridge logs what was transferred, not content

// MARK: - Bridge Type

/// Types of file bridges.
public enum BridgeType: String, Codable, Sendable, CaseIterable, Identifiable {
  case markdown = "markdown"
  case csv = "csv"
  case json = "json"
  case plainText = "plain_text"
  case annotations = "annotations"
  case collaboration = "collaboration"
  case citation = "citation"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .markdown: return "Markdown"
    case .csv: return "CSV"
    case .json: return "JSON"
    case .plainText: return "Plain Text"
    case .annotations: return "Annotations"
    case .collaboration: return "Collaboration Package"
    case .citation: return "Citation"
    }
  }

  public var fileExtension: String {
    switch self {
    case .markdown: return "md"
    case .csv: return "csv"
    case .json: return "json"
    case .plainText: return "txt"
    case .annotations: return "annotations.json"
    case .collaboration: return "zip"
    case .citation: return "txt"
    }
  }

  public var iconName: String {
    switch self {
    case .markdown: return "doc.text"
    case .csv: return "tablecells"
    case .json: return "curlybraces"
    case .plainText: return "doc.plaintext"
    case .annotations: return "highlighter"
    case .collaboration: return "person.2"
    case .citation: return "quote.bubble"
    }
  }
}

// MARK: - Bridge Direction

/// Direction of data flow.
public enum BridgeDirection: String, Codable, Sendable {
  case export
  case `import`
}

// MARK: - Bridge Result

/// Outcome of a bridge operation.
public struct BridgeResult: Codable, Sendable {
  /// Bridge type.
  public let type: BridgeType
  /// Direction.
  public let direction: BridgeDirection
  /// Whether the operation succeeded.
  public let success: Bool
  /// Output file path (for export).
  public let outputPath: String?
  /// Error message (if failed).
  public let error: String?
  /// Bytes transferred.
  public let bytesTransferred: Int64
  /// Operation duration in seconds.
  public let durationSeconds: Double
  /// When the operation completed.
  public let completedAt: Date

  public init(
    type: BridgeType,
    direction: BridgeDirection,
    success: Bool,
    outputPath: String? = nil,
    error: String? = nil,
    bytesTransferred: Int64 = 0,
    durationSeconds: Double = 0
  ) {
    self.type = type
    self.direction = direction
    self.success = success
    self.outputPath = outputPath
    self.error = error
    self.bytesTransferred = bytesTransferred
    self.durationSeconds = durationSeconds
    self.completedAt = Date()
  }
}

// MARK: - Bridge Consent

/// Tracks user consent for a bridge type.
public struct BridgeConsent: Codable, Sendable, Identifiable {
  public let id: UUID
  /// Bridge type.
  public let type: BridgeType
  /// Whether the user has consented to this bridge.
  public var isConsented: Bool
  /// When consent was given/revoked.
  public var consentedAt: Date?
  /// Number of times this bridge has been used.
  public var useCount: Int

  public init(type: BridgeType, isConsented: Bool = false) {
    self.id = UUID()
    self.type = type
    self.isConsented = isConsented
    self.consentedAt = nil
    self.useCount = 0
  }
}

// MARK: - Bridge Manager

/// Manages available bridges and their consent state.
@MainActor
public final class BridgeManager: ObservableObject {
  /// Consent state for each bridge type.
  @Published public var consents: [BridgeType: BridgeConsent] = [:]
  /// Bridge operation history.
  @Published public var history: [BridgeResult] = []

  /// Whether a specific bridge is consented.
  public func isConsented(_ type: BridgeType) -> Bool {
    consents[type]?.isConsented ?? false
  }

  /// Grant consent for a bridge type.
  public func grantConsent(for type: BridgeType) {
    var consent = consents[type] ?? BridgeConsent(type: type)
    consent.isConsented = true
    consent.consentedAt = Date()
    consents[type] = consent
  }

  /// Revoke consent for a bridge type.
  public func revokeConsent(for type: BridgeType) {
    var consent = consents[type] ?? BridgeConsent(type: type)
    consent.isConsented = false
    consent.consentedAt = Date()
    consents[type] = consent
  }

  /// Record a bridge operation.
  public func recordOperation(_ result: BridgeResult) {
    history.append(result)
    if var consent = consents[result.type] {
      consent.useCount += 1
      consents[result.type] = consent
    }
  }

  public init() {}
}

// MARK: - Export Bridges

/// Export operations for different formats.
public struct ExportBridge: Sendable {
  public init() {}

  /// Export document text as Markdown.
  public func exportMarkdown(text: String, title: String, to outputDir: URL) -> BridgeResult {
    let filename = "\(title.sanitizedForFilename).md"
    let outputURL = outputDir.appendingPathComponent(filename)
    let markdown = "# \(title)\n\n\(text)"

    guard let data = markdown.data(using: .utf8) else {
      return BridgeResult(type: .markdown, direction: .export, success: false, error: "Encoding failed")
    }

    do {
      try data.write(to: outputURL, options: .atomic)
      return BridgeResult(
        type: .markdown,
        direction: .export,
        success: true,
        outputPath: outputURL.path,
        bytesTransferred: Int64(data.count)
      )
    } catch {
      return BridgeResult(type: .markdown, direction: .export, success: false, error: error.localizedDescription)
    }
  }

  /// Export annotations as JSON.
  public func exportAnnotations(_ annotations: Data, to outputDir: URL, documentName: String) -> BridgeResult {
    let filename = "\(documentName.sanitizedForFilename).annotations.json"
    let outputURL = outputDir.appendingPathComponent(filename)

    do {
      try annotations.write(to: outputURL, options: .atomic)
      return BridgeResult(
        type: .annotations,
        direction: .export,
        success: true,
        outputPath: outputURL.path,
        bytesTransferred: Int64(annotations.count)
      )
    } catch {
      return BridgeResult(type: .annotations, direction: .export, success: false, error: error.localizedDescription)
    }
  }

  /// Export metadata as JSON.
  public func exportMetadata(_ metadata: [String: Any], to outputDir: URL, documentName: String) -> BridgeResult {
    let filename = "\(documentName.sanitizedForFilename).metadata.json"
    let outputURL = outputDir.appendingPathComponent(filename)

    guard let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]) else {
      return BridgeResult(type: .json, direction: .export, success: false, error: "JSON serialization failed")
    }

    do {
      try data.write(to: outputURL, options: .atomic)
      return BridgeResult(
        type: .json,
        direction: .export,
        success: true,
        outputPath: outputURL.path,
        bytesTransferred: Int64(data.count)
      )
    } catch {
      return BridgeResult(type: .json, direction: .export, success: false, error: error.localizedDescription)
    }
  }
}

// MARK: - String Extension

private extension String {
  var sanitizedForFilename: String {
    self.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
  }
}
