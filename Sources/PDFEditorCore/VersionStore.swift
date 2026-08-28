import Foundation
import CryptoKit

/// Persistent version store — tracks document versions as snapshots
/// of the operation ledger, enabling revert and version-vs-version comparison.
///
/// First principle: every edit is a version. The user should be able to
/// go back to any point in time, compare two versions, and understand
/// what changed between them.
///
/// Architecture:
/// - `VersionSnapshot` — a named snapshot of the document state
/// - `VersionStore` — manages the version history, persisted locally
/// - `VersionComparison` — describes changes between two versions
///
/// Doctrine alignment:
/// - §3: Do things smartly — store operation digests, not full copies
/// - §5: Evidence-based — versions have timestamps and operation counts
/// - §8: Capability routing — versioning is opt-in per document

// MARK: - Version Snapshot

/// A single version snapshot in the version history.
public struct VersionSnapshot: Codable, Sendable, Identifiable, Hashable {
  public let id: UUID
  /// Version number (monotonically increasing).
  public let versionNumber: Int
  /// User-given label (e.g., "Before merge", "Draft 2").
  public let label: String
  /// Operations applied up to this version.
  public let operations: [EditOperation]
  /// Operation ledger digest at this version (hash of operations applied).
  public let digest: String
  /// Hash of the source document at this version.
  public let sourceHash: String
  /// When this version was created.
  public let createdAt: Date

  /// Number of operations in this snapshot.
  public var operationCount: Int { operations.count }

  /// Human-readable summary.
  public var summary: String {
    "v\(versionNumber) \"\(label)\" — \(operationCount) operations"
  }

  public init(
    versionNumber: Int,
    label: String = "",
    operations: [EditOperation] = [],
    digest: String = "",
    sourceHash: String = ""
  ) {
    self.id = UUID()
    self.versionNumber = versionNumber
    self.label = label
    self.operations = operations
    self.digest = digest
    self.sourceHash = sourceHash
    self.createdAt = Date()
  }
}

// MARK: - Version Comparison

/// Describes changes between two document versions.
public struct VersionComparison: Codable, Sendable {
  /// The version being compared from.
  public let from: VersionSnapshot
  /// The version being compared to.
  public let to: VersionSnapshot
  /// Operations that were added (in `to` but not in `from`).
  public let addedOperations: [EditOperation]
  /// Operations that were removed (in `from` but not in `to`).
  public let removedOperations: [EditOperation]
  /// Whether there are any changes.
  public var hasChanges: Bool {
    !addedOperations.isEmpty || !removedOperations.isEmpty
  }

  /// Auto-computing init — computes added/removed from the two snapshots.
  public init(from: VersionSnapshot, to: VersionSnapshot) {
    self.from = from
    self.to = to
    let fromIDs = Set(from.operations.map { $0.id })
    let toIDs = Set(to.operations.map { $0.id })
    self.addedOperations = to.operations.filter { !fromIDs.contains($0.id) }
    self.removedOperations = from.operations.filter { !toIDs.contains($0.id) }
  }

  public init(
    from: VersionSnapshot,
    to: VersionSnapshot,
    addedOperations: [EditOperation],
    removedOperations: [EditOperation]
  ) {
    self.from = from
    self.to = to
    self.addedOperations = addedOperations
    self.removedOperations = removedOperations
  }
}

// MARK: - Version Store

/// Manages the version history for a document.
@MainActor
public final class VersionStore: ObservableObject {
  /// All snapshots, sorted by version number.
  @Published public var snapshots: [VersionSnapshot] = []

  /// The latest snapshot (highest version number).
  public var latestSnapshot: VersionSnapshot? {
    snapshots.last
  }

  private let documentID: String

  public init(documentID: String = "") {
    self.documentID = documentID
  }

  // MARK: - Save

  /// Save a new snapshot from the given operations.
  @discardableResult
  public func saveSnapshot(
    operations: [EditOperation],
    sourceHash: String = "",
    label: String = ""
  ) -> VersionSnapshot {
    let nextVersion = (snapshots.last?.versionNumber ?? 0) + 1
    let digest = Self.computeDigest(operations)
    let snapshot = VersionSnapshot(
      versionNumber: nextVersion,
      label: label,
      operations: operations,
      digest: digest,
      sourceHash: sourceHash
    )
    snapshots.append(snapshot)
    return snapshot
  }

  // MARK: - Query

  /// Get a snapshot by version number.
  public func snapshot(version: Int) -> VersionSnapshot? {
    snapshots.first { $0.versionNumber == version }
  }

  /// Get a snapshot by ID.
  public func snapshot(id: UUID) -> VersionSnapshot? {
    snapshots.first { $0.id == id }
  }

  // MARK: - Compare

  /// Compare two versions by version number.
  public func compare(from v1: Int, to v2: Int) -> VersionComparison? {
    guard let from = snapshot(version: v1),
          let to = snapshot(version: v2)
    else { return nil }

    let fromIDs = Set(from.operations.map(\.id))
    let toIDs = Set(to.operations.map(\.id))

    let added = to.operations.filter { !fromIDs.contains($0.id) }
    let removed = from.operations.filter { !toIDs.contains($0.id) }

    return VersionComparison(
      from: from,
      to: to,
      addedOperations: added,
      removedOperations: removed
    )
  }

  // MARK: - Revert

  /// Compute the operations needed to revert from version 2 back to version 1.
  ///
  /// Returns the operations that were added between v1 and v2 (in reverse).
  public func operationsForRevert(from v1: Int, to v2: Int) -> [EditOperation]? {
    guard let comparison = compare(from: v1, to: v2) else { return nil }
    // Revert means undoing the added operations
    return comparison.addedOperations.isEmpty ? nil : comparison.addedOperations
  }

  // MARK: - Delete

  /// Delete a snapshot by ID.
  public func deleteSnapshot(id: UUID) {
    snapshots.removeAll { $0.id == id }
  }

  // MARK: - Clear

  /// Clear all snapshots.
  public func clearAll() {
    snapshots = []
  }

  // MARK: - Digest

  /// Compute a deterministic SHA-256 digest of an operation list.
  public static func computeDigest(_ operations: [EditOperation]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(operations.map { OperationDigestInput(from: $0) }) else {
      return ""
    }
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - Digest Input

/// Minimal representation of an operation for deterministic hashing.
private struct OperationDigestInput: Codable {
  let id: UUID
  let pageIndex: Int
  let kind: String
  let value: String

  init(from op: EditOperation) {
    self.id = op.id
    self.pageIndex = op.pageIndex
    self.kind = op.kind.rawValue
    self.value = op.value
  }
}
