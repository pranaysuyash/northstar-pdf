import Foundation

/// Document governance — retention policies, access control, compliance rules.
///
/// First principle: governance is proactive, not reactive. Policies should
/// prevent violations before they happen, not just audit them afterward.
///
/// Architecture:
/// - `DocumentPolicy` — defines rules for a document or corpus
/// - `PolicyViolation` — a detected rule violation
/// - `GovernanceEngine` — evaluates policies against documents
///
/// Doctrine alignment:
/// - §3: Do things smartly — automate retention, flag compliance issues
/// - §5: Evidence-based — violations have evidence and timestamps
/// - §8: Capability routing — governance is opt-in, policies are explicit

// MARK: - Policy Rule Types

/// Types of governance rules.
public enum PolicyRuleType: String, Codable, Sendable, CaseIterable, Identifiable {
  case retention = "retention"
  case accessControl = "access_control"
  case encryption = "encryption"
  case annotation = "annotation"
  case export = "export"
  case size = "size"

  public var id: String { rawValue }
  public var displayName: String {
    switch self {
    case .retention: return "Retention"
    case .accessControl: return "Access Control"
    case .encryption: return "Encryption"
    case .annotation: return "Annotation"
    case .export: return "Export"
    case .size: return "Size Limit"
    }
  }
}

// MARK: - Policy Rule

/// A single governance rule.
public struct PolicyRule: Codable, Sendable, Identifiable, Hashable {
  public let id: UUID
  /// Rule type.
  public let type: PolicyRuleType
  /// Rule name (human-readable).
  public let name: String
  /// Rule description.
  public let description: String
  /// Whether the rule is enabled.
  public var isEnabled: Bool
  /// Severity of violations (critical, warning, info).
  public let severity: ViolationSeverity
  /// Rule parameters (type-specific).
  public var parameters: [String: String]

  public init(
    type: PolicyRuleType,
    name: String,
    description: String,
    isEnabled: Bool = true,
    severity: ViolationSeverity = .warning,
    parameters: [String: String] = [:]
  ) {
    self.id = UUID()
    self.type = type
    self.name = name
    self.description = description
    self.isEnabled = isEnabled
    self.severity = severity
    self.parameters = parameters
  }
}

/// Violation severity levels.
public enum ViolationSeverity: String, Codable, Sendable, CaseIterable {
  case critical
  case warning
  case info

  public var weight: Int {
    switch self {
    case .critical: return 3
    case .warning: return 2
    case .info: return 1
    }
  }
}

// MARK: - Policy Violation

/// A detected governance violation.
public struct PolicyViolation: Codable, Sendable, Identifiable {
  public let id: UUID
  /// The rule that was violated.
  public let ruleID: UUID
  /// Rule name.
  public let ruleName: String
  /// Violation type.
  public let type: PolicyRuleType
  /// Severity.
  public let severity: ViolationSeverity
  /// Human-readable description.
  public let description: String
  /// When the violation was detected.
  public let detectedAt: Date
  /// Document path (if applicable).
  public let documentPath: String?
  /// Whether the violation has been addressed.
  public var isResolved: Bool
  /// Resolution notes.
  public var resolutionNotes: String

  public init(
    ruleID: UUID,
    ruleName: String,
    type: PolicyRuleType,
    severity: ViolationSeverity,
    description: String,
    documentPath: String? = nil,
    resolutionNotes: String = ""
  ) {
    self.id = UUID()
    self.ruleID = ruleID
    self.ruleName = ruleName
    self.type = type
    self.severity = severity
    self.description = description
    self.detectedAt = Date()
    self.documentPath = documentPath
    self.isResolved = false
    self.resolutionNotes = resolutionNotes
  }
}

// MARK: - Governance Engine

/// Evaluates policies against documents and tracks violations.
@MainActor
public final class GovernanceEngine: ObservableObject {
  /// Active policy rules.
  @Published public var rules: [PolicyRule] = []
  /// Detected violations.
  @Published public var violations: [PolicyViolation] = []

  public init() {}

  // MARK: - Rule Management

  /// Add a policy rule.
  public func addRule(_ rule: PolicyRule) {
    rules.append(rule)
  }

  /// Remove a policy rule.
  public func removeRule(id: UUID) {
    rules.removeAll { $0.id == id }
  }

  /// Toggle a rule's enabled state.
  public func toggleRule(id: UUID) {
    guard let index = rules.firstIndex(where: { $0.id == id }) else { return }
    rules[index].isEnabled.toggle()
  }

  // MARK: - Violation Management

  /// Mark a violation as resolved.
  public func resolveViolation(id: UUID, notes: String = "") {
    guard let index = violations.firstIndex(where: { $0.id == id }) else { return }
    violations[index].isResolved = true
    violations[index].resolutionNotes = notes
  }

  /// Clear all resolved violations.
  public func clearResolved() {
    violations.removeAll { $0.isResolved }
  }

  // MARK: - Compliance Check

  /// Run a compliance check against all active rules.
  public func runComplianceCheck(documents: [(path: String, fileSize: Int64, isEncrypted: Bool, pageCount: Int)]) -> [PolicyViolation] {
    var newViolations: [PolicyViolation] = []

    for rule in rules where rule.isEnabled {
      switch rule.type {
      case .size:
        if let maxSizeStr = rule.parameters["maxSizeBytes"],
           let maxSize = Int64(maxSizeStr) {
          for doc in documents where doc.fileSize > maxSize {
            let violation = PolicyViolation(
              ruleID: rule.id,
              ruleName: rule.name,
              type: .size,
              severity: rule.severity,
              description: "Document exceeds size limit: \(formatBytes(doc.fileSize)) > \(formatBytes(maxSize))",
              documentPath: doc.path
            )
            newViolations.append(violation)
          }
        }

      case .encryption:
        let requireEncryption = rule.parameters["required"] == "true"
        if requireEncryption {
          for doc in documents where !doc.isEncrypted {
            let violation = PolicyViolation(
              ruleID: rule.id,
              ruleName: rule.name,
              type: .encryption,
              severity: rule.severity,
              description: "Document is not encrypted",
              documentPath: doc.path
            )
            newViolations.append(violation)
          }
        }

      case .retention:
        // Check page count limits
        if let maxPagesStr = rule.parameters["maxPages"],
           let maxPages = Int(maxPagesStr) {
          for doc in documents where doc.pageCount > maxPages {
            let violation = PolicyViolation(
              ruleID: rule.id,
              ruleName: rule.name,
              type: .retention,
              severity: rule.severity,
              description: "Document exceeds page limit: \(doc.pageCount) > \(maxPages)",
              documentPath: doc.path
            )
            newViolations.append(violation)
          }
        }

      default:
        break
      }
    }

    violations.append(contentsOf: newViolations)
    return newViolations
  }

  // MARK: - Summary

  /// Compliance summary.
  public var complianceSummary: ComplianceSummary {
    let critical = violations.filter { $0.severity == .critical && !$0.isResolved }.count
    let warning = violations.filter { $0.severity == .warning && !$0.isResolved }.count
    let info = violations.filter { $0.severity == .info && !$0.isResolved }.count
    let resolved = violations.filter { $0.isResolved }.count

    return ComplianceSummary(
      criticalViolations: critical,
      warningViolations: warning,
      infoViolations: info,
      resolvedViolations: resolved,
      totalRules: rules.count,
      activeRules: rules.filter(\.isEnabled).count
    )
  }

  private func formatBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}

// MARK: - Compliance Summary

/// Summary of governance compliance status.
public struct ComplianceSummary: Sendable {
  public let criticalViolations: Int
  public let warningViolations: Int
  public let infoViolations: Int
  public let resolvedViolations: Int
  public let totalRules: Int
  public let activeRules: Int

  public var isCompliant: Bool {
    criticalViolations == 0 && warningViolations == 0
  }

  public var complianceScore: Double {
    let total = criticalViolations * 3 + warningViolations * 2 + infoViolations
    let resolved = resolvedViolations
    return total > 0 ? Double(resolved) / Double(total) : 1.0
  }
}

// MARK: - Built-in Policies

extension GovernanceEngine {
  /// Default governance policies for a document corpus.
  public static func defaultPolicies() -> [PolicyRule] {
    [
      PolicyRule(
        type: .size,
        name: "Max Document Size",
        description: "Documents should not exceed 100 MB",
        severity: .warning,
        parameters: ["maxSizeBytes": "104857600"] // 100 MB
      ),
      PolicyRule(
        type: .encryption,
        name: "Encryption Required",
        description: "All documents should be encrypted",
        severity: .critical,
        parameters: ["required": "true"]
      ),
      PolicyRule(
        type: .retention,
        name: "Page Count Limit",
        description: "Documents should not exceed 500 pages",
        severity: .info,
        parameters: ["maxPages": "500"]
      ),
    ]
  }
}
