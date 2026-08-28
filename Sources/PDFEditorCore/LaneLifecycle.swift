import Foundation

/// R-1: Lane Lifecycle & Complexity Budget
///
/// First-principle: Features that nobody exercises are liabilities, not assets.
/// Every line of code has a maintenance cost — if the value doesn't exceed the
/// cost, the code should be removed.
///
/// Architecture:
/// - `LaneLifecycle`: tracks when lanes were added, last used, and deprecation status
/// - `ComplexityBudget`: caps source lines per feature, enforces limits
/// - `DeadCodeDetector`: identifies unused code paths
///
/// Doctrine alignment:
/// - OPERATING_DOCTRINE §8: Capability routing — lanes are the right abstraction
/// - OPERATING_DOCTRINE §3: Do things smartly — complexity budget prevents bloat
/// - OPERATING_DOCTRINE §9: Evolution — lifecycle management enables clean evolution

/// Lifecycle status for a capability lane.
public enum LaneStatus: String, Codable, Sendable {
  /// Actively maintained and exercised
  case active

  /// No longer recommended, but still functional
  case deprecated

  /// Removed from active use, kept for backwards compatibility only
  case archived

  /// Scheduled for removal
  case scheduledRemoval

  /// Removed from codebase
  case removed
}

/// Metadata for tracking a lane's lifecycle.
public struct LaneLifecycleRecord: Codable, Sendable {
  public let lane: String
  public let addedAt: Date
  public var lastUsedAt: Date?
  public var status: LaneStatus
  public var deprecationDate: Date?
  public var removalDate: Date?
  public var sourceLines: Int
  public var testLines: Int
  public var publicTypes: Int

  public init(
    lane: String,
    addedAt: Date = Date(),
    lastUsedAt: Date? = nil,
    status: LaneStatus = .active,
    deprecationDate: Date? = nil,
    removalDate: Date? = nil,
    sourceLines: Int = 0,
    testLines: Int = 0,
    publicTypes: Int = 0
  ) {
    self.lane = lane
    self.addedAt = addedAt
    self.lastUsedAt = lastUsedAt
    self.status = status
    self.deprecationDate = deprecationDate
    self.removalDate = removalDate
    self.sourceLines = sourceLines
    self.testLines = testLines
    self.publicTypes = publicTypes
  }
}

/// Lifecycle management for capability lanes.
public struct LaneLifecycleManager: Sendable {
  /// Threshold for deprecation (days without use)
  public static let deprecationThresholdDays = 90

  /// Threshold for removal (days after deprecation)
  public static let removalThresholdDays = 30

  public init() {}

  /// Check if a lane should be deprecated.
  public func shouldDeprecate(record: LaneLifecycleRecord, now: Date = Date()) -> Bool {
    guard record.status == .active else { return false }
    guard let lastUsed = record.lastUsedAt else { return true } // Never used
    let daysSinceUse = Calendar.current.dateComponents([.day], from: lastUsed, to: now).day ?? 0
    return daysSinceUse >= Self.deprecationThresholdDays
  }

  /// Check if a lane should be removed.
  public func shouldRemove(record: LaneLifecycleRecord, now: Date = Date()) -> Bool {
    guard record.status == .deprecated || record.status == .archived else { return false }
    guard let deprecationDate = record.deprecationDate else { return false }
    let daysSinceDeprecation = Calendar.current.dateComponents([.day], from: deprecationDate, to: now).day ?? 0
    return daysSinceDeprecation >= Self.removalThresholdDays
  }

  /// Generate a lifecycle report for all lanes.
  public func report(records: [LaneLifecycleRecord], now: Date = Date()) -> LaneLifecycleReport {
    var active: [LaneLifecycleRecord] = []
    var deprecated: [LaneLifecycleRecord] = []
    var archived: [LaneLifecycleRecord] = []
    var scheduledForRemoval: [LaneLifecycleRecord] = []

    for record in records {
      switch record.status {
      case .active: active.append(record)
      case .deprecated: deprecated.append(record)
      case .archived: archived.append(record)
      case .scheduledRemoval: scheduledForRemoval.append(record)
      case .removed: break
      }
    }

    let totalSourceLines = records.reduce(0) { $0 + $1.sourceLines }
    let totalTestLines = records.reduce(0) { $0 + $1.testLines }
    let totalPublicTypes = records.reduce(0) { $0 + $1.publicTypes }

    return LaneLifecycleReport(
      activeLanes: active.count,
      deprecatedLanes: deprecated.count,
      archivedLanes: archived.count,
      scheduledForRemoval: scheduledForRemoval.count,
      totalSourceLines: totalSourceLines,
      totalTestLines: totalTestLines,
      totalPublicTypes: totalPublicTypes,
      lanesNeedingDeprecation: records.filter { shouldDeprecate(record: $0, now: now) },
      lanesNeedingRemoval: records.filter { shouldRemove(record: $0, now: now) }
    )
  }
}

/// Report on lane lifecycle status.
public struct LaneLifecycleReport: Sendable {
  public let activeLanes: Int
  public let deprecatedLanes: Int
  public let archivedLanes: Int
  public let scheduledForRemoval: Int
  public let totalSourceLines: Int
  public let totalTestLines: Int
  public let totalPublicTypes: Int
  public let lanesNeedingDeprecation: [LaneLifecycleRecord]
  public let lanesNeedingRemoval: [LaneLifecycleRecord]

  public init(
    activeLanes: Int,
    deprecatedLanes: Int,
    archivedLanes: Int,
    scheduledForRemoval: Int,
    totalSourceLines: Int,
    totalTestLines: Int,
    totalPublicTypes: Int,
    lanesNeedingDeprecation: [LaneLifecycleRecord],
    lanesNeedingRemoval: [LaneLifecycleRecord]
  ) {
    self.activeLanes = activeLanes
    self.deprecatedLanes = deprecatedLanes
    self.archivedLanes = archivedLanes
    self.scheduledForRemoval = scheduledForRemoval
    self.totalSourceLines = totalSourceLines
    self.totalTestLines = totalTestLines
    self.totalPublicTypes = totalPublicTypes
    self.lanesNeedingDeprecation = lanesNeedingDeprecation
    self.lanesNeedingRemoval = lanesNeedingRemoval
  }
}

// MARK: - Complexity Budget

/// Complexity budget for the codebase.
public struct ComplexityBudget: Sendable {
  /// Maximum source lines per feature (lane)
  public let maxSourceLinesPerFeature: Int

  /// Maximum test lines per feature (lane)
  public let maxTestLinesPerFeature: Int

  /// Maximum public types per feature (lane)
  public let maxPublicTypesPerFeature: Int

  /// Total codebase budget (source lines)
  public let totalSourceLinesBudget: Int

  /// Total codebase budget (test lines)
  public let totalTestLinesBudget: Int

  public init(
    maxSourceLinesPerFeature: Int = 2000,
    maxTestLinesPerFeature: Int = 500,
    maxPublicTypesPerFeature: Int = 30,
    totalSourceLinesBudget: Int = 50000,
    totalTestLinesBudget: Int = 15000
  ) {
    self.maxSourceLinesPerFeature = maxSourceLinesPerFeature
    self.maxTestLinesPerFeature = maxTestLinesPerFeature
    self.maxPublicTypesPerFeature = maxPublicTypesPerFeature
    self.totalSourceLinesBudget = totalSourceLinesBudget
    self.totalTestLinesBudget = totalTestLinesBudget
  }

  /// Check if a feature exceeds its budget.
  public func checkFeature(record: LaneLifecycleRecord) -> [ComplexityViolation] {
    var violations: [ComplexityViolation] = []

    if record.sourceLines > maxSourceLinesPerFeature {
      violations.append(ComplexityViolation(
        lane: record.lane,
        kind: .sourceLinesExceeded,
        actual: record.sourceLines,
        limit: maxSourceLinesPerFeature
      ))
    }

    if record.testLines > maxTestLinesPerFeature {
      violations.append(ComplexityViolation(
        lane: record.lane,
        kind: .testLinesExceeded,
        actual: record.testLines,
        limit: maxTestLinesPerFeature
      ))
    }

    if record.publicTypes > maxPublicTypesPerFeature {
      violations.append(ComplexityViolation(
        lane: record.lane,
        kind: .publicTypesExceeded,
        actual: record.publicTypes,
        limit: maxPublicTypesPerFeature
      ))
    }

    return violations
  }

  /// Check if the total codebase exceeds its budget.
  public func checkTotal(records: [LaneLifecycleRecord]) -> [ComplexityViolation] {
    var violations: [ComplexityViolation] = []

    let totalSource = records.reduce(0) { $0 + $1.sourceLines }
    if totalSource > totalSourceLinesBudget {
      violations.append(ComplexityViolation(
        lane: "TOTAL",
        kind: .totalSourceLinesExceeded,
        actual: totalSource,
        limit: totalSourceLinesBudget
      ))
    }

    let totalTests = records.reduce(0) { $0 + $1.testLines }
    if totalTests > totalTestLinesBudget {
      violations.append(ComplexityViolation(
        lane: "TOTAL",
        kind: .totalTestLinesExceeded,
        actual: totalTests,
        limit: totalTestLinesBudget
      ))
    }

    return violations
  }
}

/// A complexity budget violation.
public struct ComplexityViolation: Sendable, Equatable {
  public enum Kind: String, Sendable {
    case sourceLinesExceeded
    case testLinesExceeded
    case publicTypesExceeded
    case totalSourceLinesExceeded
    case totalTestLinesExceeded
  }

  public let lane: String
  public let kind: Kind
  public let actual: Int
  public let limit: Int

  public init(lane: String, kind: Kind, actual: Int, limit: Int) {
    self.lane = lane
    self.kind = kind
    self.actual = actual
    self.limit = limit
  }

  public var message: String {
    "\(kind.rawValue) for \(lane): \(actual) > \(limit)"
  }
}
