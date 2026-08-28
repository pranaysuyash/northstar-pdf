import Foundation

/// Tracks collaboration packages, merge status, and unresolved conflicts across all documents.
///
/// First principle: every collaboration state is observable and reversible.
/// The manager doesn't own annotations — it tracks the relationship between
/// local marks and partner packages, and the merge status for each.
///
/// Doctrine alignment:
/// - §3: Do things smartly — file-level packages, no server state
/// - §5: Evidence-based — every merge has a full audit trail
/// - §8: Capability activation — collaboration is opt-in per document
/// - §12: Privacy stays value-free — tracks metadata, not content

// MARK: - Package Record

/// A tracked collaboration package with its merge status.
public struct PartnerPackageRecord: Identifiable, Codable, Sendable {
  public let id: UUID
  /// The collaboration package metadata.
  public let package: CollaborationPackage
  /// When this package was imported.
  public let importedAt: Date
  /// The merge status for this package against the current local annotations.
  public var mergeStatus: MergeStatus
  /// The number of unresolved conflicts from the last merge attempt.
  public var unresolvedConflictCount: Int
  /// The document this package is associated with.
  public let documentID: String
  /// The document's human-readable name.
  public let documentName: String

  public init(
    package: CollaborationPackage,
    documentID: String,
    documentName: String
  ) {
    self.id = UUID()
    self.package = package
    self.importedAt = Date()
    self.mergeStatus = .pending
    self.unresolvedConflictCount = 0
    self.documentID = documentID
    self.documentName = documentName
  }
}

// MARK: - Merge Status

/// The status of a collaboration package merge.
public enum MergeStatus: String, Codable, Sendable, CaseIterable, Identifiable {
  /// Package imported but not yet merged.
  case pending = "pending"
  /// Merge was attempted and completed with no conflicts.
  case merged = "merged"
  /// Merge was attempted but has unresolved conflicts.
  case conflicts = "conflicts"
  /// Merge was applied and conflicts were resolved.
  case resolved = "resolved"
  /// Package was rejected (wrong document, tampered, etc.).
  case rejected = "rejected"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .pending: return "Pending"
    case .merged: return "Merged"
    case .conflicts: return "Conflicts"
    case .resolved: return "Resolved"
    case .rejected: return "Rejected"
    }
  }

  public var symbolName: String {
    switch self {
    case .pending: return "clock"
    case .merged: return "checkmark.circle"
    case .conflicts: return "exclamationmark.triangle"
    case .resolved: return "checkmark.seal"
    case .rejected: return "xmark.circle"
    }
  }

  public var color: MergeStatusColor {
    switch self {
    case .pending: return .blue
    case .merged: return .green
    case .conflicts: return .orange
    case .resolved: return .green
    case .rejected: return .red
    }
  }
}

public enum MergeStatusColor: Sendable {
  case blue, green, orange, red
}

// MARK: - Conflict Record

/// A record of an unresolved conflict across all documents.
public struct ConflictRecord: Identifiable, Sendable {
  public let id: UUID
  /// The partner package this conflict belongs to.
  public let packageRecordID: UUID
  /// The document name.
  public let documentName: String
  /// The conflict details from the merge.
  public let conflict: AnnotationConflict
  /// When this conflict was detected.
  public let detectedAt: Date
  /// Current resolution (nil = unresolved).
  public var resolution: ConflictResolution?

  public init(
    packageRecordID: UUID,
    documentName: String,
    conflict: AnnotationConflict
  ) {
    self.id = UUID()
    self.packageRecordID = packageRecordID
    self.documentName = documentName
    self.conflict = conflict
    self.detectedAt = Date()
    self.resolution = nil
  }

  public var isResolved: Bool { resolution != nil }
}

// MARK: - Collaboration Dashboard Summary

/// Aggregated stats for the collaboration dashboard.
public struct CollaborationDashboardSummary: Sendable {
  public let totalPackages: Int
  public let pendingCount: Int
  public let mergedCount: Int
  public let conflictCount: Int
  public let resolvedCount: Int
  public let rejectedCount: Int
  public let totalUnresolvedConflicts: Int
  public let documentsInvolved: Int

  public var hasConflicts: Bool { totalUnresolvedConflicts > 0 }
  public var allResolved: Bool { totalUnresolvedConflicts == 0 && totalPackages > 0 }

  public var description: String {
    "\(totalPackages) packages, \(totalUnresolvedConflicts) unresolved conflicts across \(documentsInvolved) documents"
  }
}

// MARK: - Collaboration Manager

/// Manages all collaboration state: packages, merges, and conflicts.
@MainActor
public final class CollaborationManager: ObservableObject {
  /// All imported partner packages.
  @Published public var packages: [PartnerPackageRecord] = []
  /// All unresolved conflicts across all documents.
  @Published public var conflicts: [ConflictRecord] = []
  /// Full collaboration history.
  public let history = CollaborationHistory()

  private let storageKey = "com.pdfeditor.collaboration.manager"

  public init() {
    load()
  }

  // MARK: - Package Management

  /// Import a collaboration package for a document.
  @discardableResult
  public func importPackage(
    _ package: CollaborationPackage,
    documentID: String,
    documentName: String,
    actor: String = NSFullUserName()
  ) -> PartnerPackageRecord {
    let record = PartnerPackageRecord(
      package: package,
      documentID: documentID,
      documentName: documentName
    )
    packages.append(record)
    history.recordImport(
      actor: actor,
      package: package,
      documentID: documentID,
      documentName: documentName
    )
    save()
    return record
  }

  /// Remove a package record.
  public func removePackage(id: UUID, actor: String = NSFullUserName()) {
    if let record = packages.first(where: { $0.id == id }) {
      history.recordRemoval(actor: actor, packageRecord: record)
    }
    packages.removeAll { $0.id == id }
    conflicts.removeAll { $0.packageRecordID == id }
    save()
  }

  /// Get all packages for a specific document.
  public func packages(for documentID: String) -> [PartnerPackageRecord] {
    packages.filter { $0.documentID == documentID }
  }

  // MARK: - Merge Management

  /// Update merge status for a package after a merge attempt.
  public func updateMergeStatus(
    packageID: UUID,
    status: MergeStatus,
    newConflicts: [AnnotationConflict] = [],
    mergeResult: AnnotationMergeResult? = nil,
    actor: String = NSFullUserName()
  ) {
    guard let index = packages.firstIndex(where: { $0.id == packageID }) else { return }

    packages[index].mergeStatus = status
    packages[index].unresolvedConflictCount = newConflicts.count

    // Record history
    if let result = mergeResult {
      history.recordMerge(
        actor: actor,
        packageRecord: packages[index],
        mergeResult: result
      )
    }

    // Remove old conflicts for this package
    conflicts.removeAll { $0.packageRecordID == packageID }

    // Add new conflicts
    for conflict in newConflicts {
      conflicts.append(ConflictRecord(
        packageRecordID: packageID,
        documentName: packages[index].documentName,
        conflict: conflict
      ))
    }

    save()
  }

  /// Mark a specific conflict as resolved.
  public func resolveConflict(
    conflictID: UUID,
    resolution: ConflictResolution,
    actor: String = NSFullUserName()
  ) {
    guard let index = conflicts.firstIndex(where: { $0.id == conflictID }) else { return }
    let conflict = conflicts[index]
    conflicts[index].resolution = resolution

    // Record history
    history.recordResolution(
      actor: actor,
      conflict: conflict,
      resolution: resolution,
      documentName: conflict.documentName
    )

    // Update the package's unresolved count
    let packageID = conflict.packageRecordID
    if let pkgIndex = packages.firstIndex(where: { $0.id == packageID }) {
      let remaining = conflicts.filter {
        $0.packageRecordID == packageID && !$0.isResolved
      }.count
      packages[pkgIndex].unresolvedConflictCount = remaining
      if remaining == 0 {
        packages[pkgIndex].mergeStatus = .resolved
      }
    }

    save()
  }

  // MARK: - Dashboard Summary

  /// Get aggregated dashboard stats.
  public var dashboardSummary: CollaborationDashboardSummary {
    let docs = Set(packages.map(\.documentID))
    let unresolved = conflicts.filter { !$0.isResolved }
    return CollaborationDashboardSummary(
      totalPackages: packages.count,
      pendingCount: packages.filter { $0.mergeStatus == .pending }.count,
      mergedCount: packages.filter { $0.mergeStatus == .merged }.count,
      conflictCount: packages.filter { $0.mergeStatus == .conflicts }.count,
      resolvedCount: packages.filter { $0.mergeStatus == .resolved }.count,
      rejectedCount: packages.filter { $0.mergeStatus == .rejected }.count,
      totalUnresolvedConflicts: unresolved.count,
      documentsInvolved: docs.count
    )
  }

  /// Get all unresolved conflicts, grouped by document.
  public var unresolvedConflictsByDocument: [(documentName: String, conflicts: [ConflictRecord])] {
    let unresolved = conflicts.filter { !$0.isResolved }
    let grouped = Dictionary(grouping: unresolved) { $0.documentName }
    return grouped.map { (documentName: $0.key, conflicts: $0.value) }
      .sorted { $0.documentName < $1.documentName }
  }

  // MARK: - Persistence

  private func save() {
    guard let pkgData = try? JSONEncoder().encode(packages) else { return }
    UserDefaults.standard.set(pkgData, forKey: storageKey + ".packages")
    // Conflicts are ephemeral — reconstructed from merge status on import
  }

  private func load() {
    if let pkgData = UserDefaults.standard.data(forKey: storageKey + ".packages"),
       let loaded = try? JSONDecoder().decode([PartnerPackageRecord].self, from: pkgData) {
      packages = loaded
    }
  }

  /// Clear all data (for testing).
  public func clearAll() {
    packages = []
    conflicts = []
    UserDefaults.standard.removeObject(forKey: storageKey + ".packages")
  }
}
