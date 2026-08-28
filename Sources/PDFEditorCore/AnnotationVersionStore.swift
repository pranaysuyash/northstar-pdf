import Foundation

/// Tracks the evolution of individual annotation marks over time.
///
/// First principle: every change to a mark is a new version, not a mutation.
/// Partners can see exactly how annotations evolved — what was added, modified,
/// or removed, and when.
///
/// Doctrine alignment:
/// - §5: Evidence-based — full version chain with timestamps and change reasons
/// - §8: Capability activation — versioning is opt-in per document
/// - §12: Privacy stays value-free — tracks structural changes, not content analysis

// MARK: - Annotation Version

/// A snapshot of a mark's state at a point in time.
public struct AnnotationVersion: Identifiable, Codable, Sendable {
  public let id: UUID
  /// The mark this version belongs to.
  public let markID: UUID
  /// Version number (1 = original creation).
  public let versionNumber: Int
  /// When this version was created.
  public let timestamp: Date
  /// Who made the change (actor name).
  public let actor: String
  /// What kind of change this version represents.
  public let changeType: AnnotationChangeType
  /// Human-readable description of what changed.
  public let changeDescription: String
  /// The mark state at this version.
  public let snapshot: AnnotationMark

  public init(
    markID: UUID,
    versionNumber: Int,
    actor: String,
    changeType: AnnotationChangeType,
    changeDescription: String,
    snapshot: AnnotationMark
  ) {
    self.id = UUID()
    self.markID = markID
    self.versionNumber = versionNumber
    self.timestamp = Date()
    self.actor = actor
    self.changeType = changeType
    self.changeDescription = changeDescription
    self.snapshot = snapshot
  }
}

// MARK: - Change Type

/// The type of change that created this version.
public enum AnnotationChangeType: String, Codable, Sendable, CaseIterable, Identifiable {
  /// Mark was created.
  case created = "created"
  /// Mark text was edited.
  case textEdited = "textEdited"
  /// Mark note was edited.
  case noteEdited = "noteEdited"
  /// Mark type changed (e.g., highlight → underline).
  case typeChanged = "typeChanged"
  /// Mark color changed.
  case colorChanged = "colorChanged"
  /// Mark position/bounds changed.
  case positionChanged = "positionChanged"
  /// Mark visibility toggled.
  case visibilityToggled = "visibilityToggled"
  /// Mark tags were modified.
  case tagsModified = "tagsModified"
  /// Mark was restored from a version.
  case restored = "restored"
  /// Bulk import (e.g., from partner package).
  case imported = "imported"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .created: return "Created"
    case .textEdited: return "Text Edited"
    case .noteEdited: return "Note Edited"
    case .typeChanged: return "Type Changed"
    case .colorChanged: return "Color Changed"
    case .positionChanged: return "Position Changed"
    case .visibilityToggled: return "Visibility Toggled"
    case .tagsModified: return "Tags Modified"
    case .restored: return "Restored"
    case .imported: return "Imported"
    }
  }

  public var symbolName: String {
    switch self {
    case .created: return "plus.circle"
    case .textEdited: return "text.cursor"
    case .noteEdited: return "note.text"
    case .typeChanged: return "tag"
    case .colorChanged: return "paintpalette"
    case .positionChanged: return "arrow.up.and.down.and.arrow.left.and.right"
    case .visibilityToggled: return "eye"
    case .tagsModified: return "number"
    case .restored: return "arrow.counterclockwise"
    case .imported: return "arrow.down.doc"
    }
  }
}

// MARK: - Version Chain

/// The complete version history of a single mark.
public struct MarkVersionChain: Identifiable, Codable, Sendable {
  public let markID: UUID
  /// All versions, oldest first.
  public let versions: [AnnotationVersion]

  public var id: UUID { markID }

  /// The current (latest) version.
  public var current: AnnotationVersion? { versions.last }

  /// The original version.
  public var original: AnnotationVersion? { versions.first }

  /// Total number of versions.
  public var count: Int { versions.count }

  /// How many times this mark has been edited (excluding creation).
  public var editCount: Int { max(0, versions.count - 1) }

  /// All actors who have modified this mark.
  public var actors: [String] {
    Array(Set(versions.map(\.actor))).sorted()
  }

  /// Duration from first to last version.
  public var lifespan: TimeInterval? {
    guard let first = versions.first?.timestamp,
          let last = versions.last?.timestamp else { return nil }
    return last.timeIntervalSince(first)
  }

  /// Whether the mark has been modified since creation.
  public var hasBeenEdited: Bool { versions.count > 1 }

  /// Description of the change chain.
  public var description: String {
    if versions.count == 1 {
      return "Created by \(versions[0].actor)"
    }
    let actorList = actors.joined(separator: ", ")
    return "\(versions.count) versions, \(editCount) edits by \(actorList)"
  }
}

// MARK: - Diff Between Versions

/// The differences between two versions of a mark.
public struct AnnotationVersionDiff: Sendable {
  public let fromVersion: Int
  public let toVersion: Int
  public let textChanged: Bool
  public let noteChanged: Bool
  public let typeChanged: Bool
  public let colorChanged: Bool
  public let positionChanged: Bool
  public let tagsChanged: Bool
  public let visibilityChanged: Bool

  /// Whether any field changed.
  public var hasChanges: Bool {
    textChanged || noteChanged || typeChanged || colorChanged
      || positionChanged || tagsChanged || visibilityChanged
  }

  /// Summary of changes.
  public var summary: [String] {
    var changes: [String] = []
    if textChanged { changes.append("text") }
    if noteChanged { changes.append("note") }
    if typeChanged { changes.append("type") }
    if colorChanged { changes.append("color") }
    if positionChanged { changes.append("position") }
    if tagsChanged { changes.append("tags") }
    if visibilityChanged { changes.append("visibility") }
    return changes
  }

  public var description: String {
    let changes = summary.joined(separator: ", ")
    return "v\(fromVersion)→v\(toVersion): \(changes)"
  }
}

// MARK: - Version Store

/// Tracks version history for all marks in a document.
@MainActor
public final class AnnotationVersionStore: ObservableObject {
  /// Version chains indexed by mark ID.
  @Published public private(set) var chains: [UUID: MarkVersionChain] = [:]

  /// The document this store belongs to.
  public private(set) var documentID: String = ""

  private let storageKey = "com.pdfeditor.annotation.versions"

  public init() {}

  // MARK: - Document Binding

  /// Bind to a document ID.
  public func bind(toDocumentID documentID: String) {
    self.documentID = documentID
    load()
  }

  // MARK: - Recording Versions

  /// Record the creation of a new mark.
  @discardableResult
  public func recordCreation(
    of mark: AnnotationMark,
    actor: String = NSFullUserName()
  ) -> AnnotationVersion {
    let version = AnnotationVersion(
      markID: mark.id,
      versionNumber: 1,
      actor: actor,
      changeType: .created,
      changeDescription: "Created \(mark.type.displayName) on page \(mark.pageIndex + 1)",
      snapshot: mark
    )
    var chain = chains[mark.id] ?? MarkVersionChain(markID: mark.id, versions: [])
    chain = MarkVersionChain(markID: mark.id, versions: chain.versions + [version])
    chains[mark.id] = chain
    save()
    return version
  }

  /// Record an update to an existing mark.
  @discardableResult
  public func recordUpdate(
    of mark: AnnotationMark,
    previousMark: AnnotationMark,
    changeType: AnnotationChangeType,
    description: String,
    actor: String = NSFullUserName()
  ) -> AnnotationVersion {
    // Chain is keyed by the original mark's ID (previousMark.id)
    let markID = previousMark.id
    let chain = chains[markID]
    let nextVersion = (chain?.versions.count ?? 0) + 1

    let version = AnnotationVersion(
      markID: markID,
      versionNumber: nextVersion,
      actor: actor,
      changeType: changeType,
      changeDescription: description,
      snapshot: mark
    )

    var newChain = chain ?? MarkVersionChain(markID: markID, versions: [])
    newChain = MarkVersionChain(markID: markID, versions: newChain.versions + [version])
    chains[markID] = newChain
    save()
    return version
  }

  /// Record a bulk import of marks.
  public func recordImport(
    of marks: [AnnotationMark],
    actor: String = NSFullUserName()
  ) {
    for mark in marks {
      let version = AnnotationVersion(
        markID: mark.id,
        versionNumber: 1,
        actor: actor,
        changeType: .imported,
        changeDescription: "Imported \(mark.type.displayName) from partner",
        snapshot: mark
      )
      var chain = chains[mark.id] ?? MarkVersionChain(markID: mark.id, versions: [])
      chain = MarkVersionChain(markID: mark.id, versions: chain.versions + [version])
      chains[mark.id] = chain
    }
    save()
  }

  // MARK: - Querying

  /// Get the version chain for a specific mark.
  public func chain(for markID: UUID) -> MarkVersionChain? {
    chains[markID]
  }

  /// Get all version chains as an array (sorted by last update).
  public var allChains: [MarkVersionChain] {
    chains.values.sorted { a, b in
      let aDate = a.current?.timestamp ?? Date.distantPast
      let bDate = b.current?.timestamp ?? Date.distantPast
      return aDate > bDate
    }
  }

  /// Marks that have been edited (more than 1 version).
  public var editedMarks: [MarkVersionChain] {
    chains.values.filter { $0.hasBeenEdited }.sorted { a, b in
      (a.current?.timestamp ?? .distantPast) > (b.current?.timestamp ?? .distantPast)
    }
  }

  /// All actors who have made changes.
  public var allActors: [String] {
    Array(Set(chains.values.flatMap(\.actors))).sorted()
  }

  /// Total version count across all marks.
  public var totalVersionCount: Int {
    chains.values.reduce(0) { $0 + $1.count }
  }

  // MARK: - Diff

  /// Compute the diff between two versions of the same mark.
  public func diff(markID: UUID, from fromVersion: Int, to toVersion: Int) -> AnnotationVersionDiff? {
    guard let chain = chains[markID],
          fromVersion >= 1, toVersion >= 1,
          fromVersion <= chain.count, toVersion <= chain.count,
          fromVersion != toVersion else { return nil }

    let from = chain.versions[fromVersion - 1].snapshot
    let to = chain.versions[toVersion - 1].snapshot

    return AnnotationVersionDiff(
      fromVersion: fromVersion,
      toVersion: toVersion,
      textChanged: from.selectedText != to.selectedText,
      noteChanged: from.note != to.note,
      typeChanged: from.type != to.type,
      colorChanged: from.color != to.color,
      positionChanged: from.bounds != to.bounds,
      tagsChanged: from.tags != to.tags,
      visibilityChanged: from.isVisible != to.isVisible
    )
  }

  /// Compute the diff between the original and current version.
  public func diffFromOriginal(markID: UUID) -> AnnotationVersionDiff? {
    guard let chain = chains[markID], chain.count >= 2 else { return nil }
    return diff(markID: markID, from: 1, to: chain.count)
  }

  // MARK: - Restore

  /// Get the snapshot at a specific version number.
  public func snapshot(markID: UUID, at versionNumber: Int) -> AnnotationMark? {
    guard let chain = chains[markID],
          versionNumber >= 1, versionNumber <= chain.count else { return nil }
    return chain.versions[versionNumber - 1].snapshot
  }

  // MARK: - Statistics

  /// Version statistics for the document.
  public var statistics: VersionStatistics {
    let allVersions = chains.values.flatMap(\.versions)
    let createdCount = allVersions.filter { $0.changeType == .created }.count
    let editedCount = allVersions.filter { $0.changeType != .created && $0.changeType != .imported }.count
    let importedCount = allVersions.filter { $0.changeType == .imported }.count

    let changeTypeCounts = Dictionary(grouping: allVersions, by: \.changeType)
      .mapValues(\.count)

    return VersionStatistics(
      totalMarks: chains.count,
      totalVersions: allVersions.count,
      createdCount: createdCount,
      editedCount: editedCount,
      importedCount: importedCount,
      changeTypeCounts: changeTypeCounts,
      actorCount: allActors.count,
      mostEditedMarkID: chains.values.max(by: { $0.editCount < $1.editCount })?.markID
    )
  }

  // MARK: - Persistence

  private func save() {
    guard let data = try? JSONEncoder().encode(chains) else { return }
    UserDefaults.standard.set(data, forKey: storageKey + ".\(documentID)")
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey + ".\(documentID)"),
          let loaded = try? JSONDecoder().decode([UUID: MarkVersionChain].self, from: data)
    else { return }
    chains = loaded
  }

  /// Clear all version data (for testing).
  public func clearAll() {
    chains = [:]
    UserDefaults.standard.removeObject(forKey: storageKey + ".\(documentID)")
  }
}

// MARK: - Version Statistics

/// Aggregated statistics about annotation versions.
public struct VersionStatistics: Sendable {
  public let totalMarks: Int
  public let totalVersions: Int
  public let createdCount: Int
  public let editedCount: Int
  public let importedCount: Int
  public let changeTypeCounts: [AnnotationChangeType: Int]
  public let actorCount: Int
  public let mostEditedMarkID: UUID?

  public var editRate: Double {
    guard totalMarks > 0 else { return 0 }
    return Double(editedCount) / Double(totalMarks)
  }

  public var description: String {
    "\(totalVersions) versions across \(totalMarks) marks, \(editedCount) edits by \(actorCount) actors"
  }
}
