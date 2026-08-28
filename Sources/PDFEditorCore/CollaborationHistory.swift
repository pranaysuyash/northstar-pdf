import Foundation

/// Tracks the full history of collaboration events: imports, merges, conflict resolutions.
///
/// First principle: every collaboration action is recorded with full provenance.
/// History is append-only — never mutated, never deleted. This provides a
/// complete audit trail for accountability and learning.
///
/// Doctrine alignment:
/// - §5: Evidence-based — every event has timestamp, actor, and full details
/// - §12: Privacy stays value-free — records actions on marks, never mark content

// MARK: - History Event

/// A single collaboration history event.
public struct CollaborationHistoryEvent: Identifiable, Codable, Sendable {
  public let id: UUID
  /// When this event occurred.
  public let timestamp: Date
  /// Who performed the action (user name).
  public let actor: String
  /// What kind of event this is.
  public let kind: HistoryEventKind
  /// The document this event relates to.
  public let documentID: String
  /// Human-readable document name.
  public let documentName: String
  /// The partner author (if applicable).
  public let partnerName: String?
  /// Number of marks involved.
  public let markCount: Int
  /// Number of conflicts in this event (0 for clean merges).
  public let conflictCount: Int
  /// Per-conflict resolution details.
  public let resolutions: [ResolutionDetail]
  /// Human-readable summary of the event.
  public let summary: String

  public init(
    actor: String,
    kind: HistoryEventKind,
    documentID: String,
    documentName: String,
    partnerName: String? = nil,
    markCount: Int = 0,
    conflictCount: Int = 0,
    resolutions: [ResolutionDetail] = [],
    summary: String = ""
  ) {
    self.id = UUID()
    self.timestamp = Date()
    self.actor = actor
    self.kind = kind
    self.documentID = documentID
    self.documentName = documentName
    self.partnerName = partnerName
    self.markCount = markCount
    self.conflictCount = conflictCount
    self.resolutions = resolutions
    self.summary = summary
  }
}

// MARK: - Event Kind

/// The type of collaboration event.
public enum HistoryEventKind: String, Codable, Sendable, CaseIterable, Identifiable {
  /// A partner package was imported.
  case packageImported = "packageImported"
  /// A merge was executed (with or without conflicts).
  case mergeExecuted = "mergeExecuted"
  /// A conflict was resolved.
  case conflictResolved = "conflictResolved"
  /// A merge was reverted/undone.
  case mergeReverted = "mergeReverted"
  /// A package was rejected (integrity failure, wrong document).
  case packageRejected = "packageRejected"
  /// A package was removed.
  case packageRemoved = "packageRemoved"

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .packageImported: return "Package Imported"
    case .mergeExecuted: return "Merge Executed"
    case .conflictResolved: return "Conflict Resolved"
    case .mergeReverted: return "Merge Reverted"
    case .packageRejected: return "Package Rejected"
    case .packageRemoved: return "Package Removed"
    }
  }

  public var symbolName: String {
    switch self {
    case .packageImported: return "arrow.down.doc"
    case .mergeExecuted: return "arrow.triangle.merge"
    case .conflictResolved: return "checkmark.circle"
    case .mergeReverted: return "arrow.uturn.backward"
    case .packageRejected: return "xmark.octagon"
    case .packageRemoved: return "trash"
    }
  }
}

// MARK: - Resolution Detail

/// Details of a single conflict resolution within a history event.
public struct ResolutionDetail: Codable, Sendable {
  /// The conflict reason (what kind of conflict it was).
  public let conflictReason: String
  /// Which resolution was chosen.
  public let resolution: ConflictResolution
  /// The auto-suggested resolution (for comparison).
  public let suggestedResolution: ConflictResolution
  /// Whether the user followed the suggestion.
  public let followedSuggestion: Bool
  /// Confidence of the suggestion.
  public let hintConfidence: Double
  /// Page number where the conflict occurred.
  public let pageNumber: Int

  public init(
    conflictReason: String,
    resolution: ConflictResolution,
    suggestedResolution: ConflictResolution,
    hintConfidence: Double,
    pageNumber: Int
  ) {
    self.conflictReason = conflictReason
    self.resolution = resolution
    self.suggestedResolution = suggestedResolution
    self.followedSuggestion = (resolution == suggestedResolution)
    self.hintConfidence = hintConfidence
    self.pageNumber = pageNumber
  }

  /// Whether the user followed the auto-suggestion.
  public var didFollowSuggestion: Bool { followedSuggestion }
}

// MARK: - History Summary

/// Aggregated statistics for the collaboration history.
public struct CollaborationHistorySummary: Sendable {
  public let totalEvents: Int
  public let totalImports: Int
  public let totalMerges: Int
  public let totalResolutions: Int
  public let totalReverts: Int
  public let totalRejections: Int
  public let totalRemovals: Int
  public let documentsInvolved: Int
  public let partnersInvolved: Int
  public let suggestionFollowRate: Double
  public let mostCommonResolution: ConflictResolution?
  public let lastActivityDate: Date?

  public var description: String {
    "\(totalEvents) events, \(totalMerges) merges, \(totalResolutions) resolutions, \(Int(suggestionFollowRate * 100))% suggestion follow rate"
  }
}

// MARK: - Collaboration History

/// Append-only history of all collaboration events.
@MainActor
public final class CollaborationHistory: ObservableObject {
  /// All history events, newest first.
  @Published public private(set) var events: [CollaborationHistoryEvent] = []

  private let storageKey = "com.pdfeditor.collaboration.history"

  public init() {
    load()
  }

  // MARK: - Recording Events

  /// Record a package import event.
  @discardableResult
  public func recordImport(
    actor: String,
    package: CollaborationPackage,
    documentID: String,
    documentName: String
  ) -> CollaborationHistoryEvent {
    let event = CollaborationHistoryEvent(
      actor: actor,
      kind: .packageImported,
      documentID: documentID,
      documentName: documentName,
      partnerName: package.authorName,
      markCount: package.annotations.count,
      summary: "\(actor) imported \(package.authorName)'s package (\(package.annotations.count) marks) for \(documentName)"
    )
    events.insert(event, at: 0)
    save()
    return event
  }

  /// Record a merge execution event.
  @discardableResult
  public func recordMerge(
    actor: String,
    packageRecord: PartnerPackageRecord,
    mergeResult: AnnotationMergeResult
  ) -> CollaborationHistoryEvent {
    let resolutions = mergeResult.conflicts.map { conflict in
      ResolutionDetail(
        conflictReason: conflict.reason.description,
        resolution: conflict.resolution,
        suggestedResolution: conflict.suggestedResolution,
        hintConfidence: conflict.hintConfidence,
        pageNumber: conflict.localMark.pageIndex + 1
      )
    }

    let event = CollaborationHistoryEvent(
      actor: actor,
      kind: .mergeExecuted,
      documentID: packageRecord.documentID,
      documentName: packageRecord.documentName,
      partnerName: packageRecord.package.authorName,
      markCount: mergeResult.mergedMarks.count,
      conflictCount: mergeResult.conflicts.count,
      resolutions: resolutions,
      summary: "\(actor) merged \(packageRecord.package.authorName)'s annotations into \(packageRecord.documentName) (\(mergeResult.mergedMarks.count) marks, \(mergeResult.conflicts.count) conflicts)"
    )
    events.insert(event, at: 0)
    save()
    return event
  }

  /// Record a conflict resolution event.
  @discardableResult
  public func recordResolution(
    actor: String,
    conflict: ConflictRecord,
    resolution: ConflictResolution,
    documentName: String
  ) -> CollaborationHistoryEvent {
    let detail = ResolutionDetail(
      conflictReason: conflict.conflict.reason.description,
      resolution: resolution,
      suggestedResolution: conflict.conflict.suggestedResolution,
      hintConfidence: conflict.conflict.hintConfidence,
      pageNumber: conflict.conflict.localMark.pageIndex + 1
    )

    let event = CollaborationHistoryEvent(
      actor: actor,
      kind: .conflictResolved,
      documentID: "",
      documentName: documentName,
      markCount: 1,
      conflictCount: 1,
      resolutions: [detail],
      summary: "\(actor) resolved conflict on page \(detail.pageNumber) as \"\(resolution.displayName)\" in \(documentName)"
    )
    events.insert(event, at: 0)
    save()
    return event
  }

  /// Record a merge revert event.
  @discardableResult
  public func recordRevert(
    actor: String,
    packageRecord: PartnerPackageRecord,
    reason: String = ""
  ) -> CollaborationHistoryEvent {
    let event = CollaborationHistoryEvent(
      actor: actor,
      kind: .mergeReverted,
      documentID: packageRecord.documentID,
      documentName: packageRecord.documentName,
      partnerName: packageRecord.package.authorName,
      summary: "\(actor) reverted merge of \(packageRecord.package.authorName)'s package from \(packageRecord.documentName)\(reason.isEmpty ? "" : " (\(reason))")"
    )
    events.insert(event, at: 0)
    save()
    return event
  }

  /// Record a package rejection event.
  @discardableResult
  public func recordRejection(
    actor: String,
    packageRecord: PartnerPackageRecord,
    reason: String
  ) -> CollaborationHistoryEvent {
    let event = CollaborationHistoryEvent(
      actor: actor,
      kind: .packageRejected,
      documentID: packageRecord.documentID,
      documentName: packageRecord.documentName,
      partnerName: packageRecord.package.authorName,
      summary: "\(actor) rejected \(packageRecord.package.authorName)'s package for \(packageRecord.documentName): \(reason)"
    )
    events.insert(event, at: 0)
    save()
    return event
  }

  /// Record a package removal event.
  @discardableResult
  public func recordRemoval(
    actor: String,
    packageRecord: PartnerPackageRecord
  ) -> CollaborationHistoryEvent {
    let event = CollaborationHistoryEvent(
      actor: actor,
      kind: .packageRemoved,
      documentID: packageRecord.documentID,
      documentName: packageRecord.documentName,
      partnerName: packageRecord.package.authorName,
      summary: "\(actor) removed \(packageRecord.package.authorName)'s package from \(packageRecord.documentName)"
    )
    events.insert(event, at: 0)
    save()
    return event
  }

  // MARK: - Querying

  /// History events for a specific document.
  public func events(for documentID: String) -> [CollaborationHistoryEvent] {
    events.filter { $0.documentID == documentID }
  }

  /// History events involving a specific partner.
  public func events(withPartner partnerName: String) -> [CollaborationHistoryEvent] {
    events.filter { $0.partnerName == partnerName }
  }

  /// History events of a specific kind.
  public func events(kind: HistoryEventKind) -> [CollaborationHistoryEvent] {
    events.filter { $0.kind == kind }
  }

  /// All unique partner names from history.
  public var partnerNames: [String] {
    Array(Set(events.compactMap(\.partnerName))).sorted()
  }

  /// All unique document names from history.
  public var documentNames: [String] {
    Array(Set(events.map(\.documentName))).sorted()
  }

  // MARK: - Summary

  /// Aggregated history statistics.
  public var summary: CollaborationHistorySummary {
    let allResolutions = events.flatMap(\.resolutions)
    let followCount = allResolutions.filter(\.followedSuggestion).count
    let followRate = allResolutions.isEmpty ? 0.0 : Double(followCount) / Double(allResolutions.count)

    // Most common resolution
    let resolutionCounts = Dictionary(grouping: allResolutions, by: \.resolution)
    let mostCommon = resolutionCounts.max(by: { $0.value.count < $1.value.count })?.key

    let partners = Set(events.compactMap(\.partnerName))
    let docs = Set(events.map(\.documentID))

    return CollaborationHistorySummary(
      totalEvents: events.count,
      totalImports: events.filter { $0.kind == .packageImported }.count,
      totalMerges: events.filter { $0.kind == .mergeExecuted }.count,
      totalResolutions: events.filter { $0.kind == .conflictResolved }.count,
      totalReverts: events.filter { $0.kind == .mergeReverted }.count,
      totalRejections: events.filter { $0.kind == .packageRejected }.count,
      totalRemovals: events.filter { $0.kind == .packageRemoved }.count,
      documentsInvolved: docs.count,
      partnersInvolved: partners.count,
      suggestionFollowRate: followRate,
      mostCommonResolution: mostCommon,
      lastActivityDate: events.first?.timestamp
    )
  }

  // MARK: - Export

  /// Export history as JSON data.
  public func exportJSON() -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try? encoder.encode(events)
  }

  /// Export history as CSV string.
  public func exportCSV() -> String {
    var lines: [String] = ["Timestamp,Actor,Event,Document,Partner,Marks,Conflicts,Summary"]
    let formatter = ISO8601DateFormatter()
    for event in events {
      let line = [
        formatter.string(from: event.timestamp),
        csvEscape(event.actor),
        event.kind.displayName,
        csvEscape(event.documentName),
        csvEscape(event.partnerName ?? ""),
        "\(event.markCount)",
        "\(event.conflictCount)",
        csvEscape(event.summary)
      ].joined(separator: ",")
      lines.append(line)
    }
    return lines.joined(separator: "\n")
  }

  // MARK: - Persistence

  private func save() {
    guard let data = try? JSONEncoder().encode(events) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let loaded = try? JSONDecoder().decode([CollaborationHistoryEvent].self, from: data)
    else { return }
    events = loaded
  }

  /// Clear all history (for testing).
  public func clearAll() {
    events = []
    UserDefaults.standard.removeObject(forKey: storageKey)
  }

  private func csvEscape(_ s: String) -> String {
    if s.contains(",") || s.contains("\"") || s.contains("\n") {
      return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return s
  }
}
