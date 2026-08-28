import Foundation

/// Privacy audit trail — logs document lifecycle events without recording content.
///
/// First principle: prove what happened without storing what was seen.
/// Every event records WHO, WHEN, and WHAT ACTION — never document content.
/// This is value-free by design (aligns with existing recovery audit tests).
///
/// Doctrine alignment:
/// - §5: Evidence-based — every event is timestamped and immutable
/// - §8: Capability activation — audit is always on, not opt-in
/// - §12: Privacy value-free — no document content in audit records
///
/// Events tracked:
/// - document_opened: when a PDF is opened
/// - document_read: page viewed (page index only, no text)
/// - document_searched: search executed (query text recorded for user's own audit)
/// - document_exported: export performed (format, destination)
/// - document_annotated: annotation created/modified/deleted
/// - document_signed: signature applied
/// - document_shared: collaboration package sent

// MARK: - Audit Event

/// A single audit event in the trail.
public struct AuditEvent: Codable, Sendable, Identifiable {
  public let id: UUID
  /// When the event occurred.
  public let timestamp: Date
  /// The type of event.
  public let type: AuditEventType
  /// Document identifier (file name, not content).
  public let documentID: String
  /// Optional detail about the event (page index, format, etc.).
  public let detail: String
  /// Optional user identifier (for multi-user audit).
  public let userID: String?

  public init(
    type: AuditEventType,
    documentID: String,
    detail: String = "",
    userID: String? = nil
  ) {
    self.id = UUID()
    self.timestamp = Date()
    self.type = type
    self.documentID = documentID
    self.detail = detail
    self.userID = userID
  }
}

// MARK: - Audit Event Type

/// Types of auditable events.
public enum AuditEventType: String, Codable, Sendable, CaseIterable {
  case documentOpened = "document_opened"
  case documentRead = "document_read"
  case documentSearched = "document_searched"
  case documentExported = "document_exported"
  case documentAnnotated = "document_annotated"
  case documentSigned = "document_signed"
  case documentShared = "document_shared"
  case documentClosed = "document_closed"

  public var displayName: String {
    switch self {
    case .documentOpened: return "Opened"
    case .documentRead: return "Read"
    case .documentSearched: return "Searched"
    case .documentExported: return "Exported"
    case .documentAnnotated: return "Annotated"
    case .documentSigned: return "Signed"
    case .documentShared: return "Shared"
    case .documentClosed: return "Closed"
    }
  }

  public var symbolName: String {
    switch self {
    case .documentOpened: return "doc"
    case .documentRead: return "book"
    case .documentSearched: return "magnifyingglass"
    case .documentExported: return "square.and.arrow.up"
    case .documentAnnotated: return "highlighter"
    case .documentSigned: return "signature"
    case .documentShared: return "person.2"
    case .documentClosed: return "xmark.doc"
    }
  }
}

// MARK: - Audit Trail

/// Manages the privacy audit trail — append-only log of document lifecycle events.
///
/// Events are persisted to UserDefaults as a JSON array. The trail is append-only:
/// events cannot be modified or deleted after creation.
@MainActor
public final class AuditTrail: ObservableObject {
  /// All audit events (newest first for display, oldest first for export).
  @Published public private(set) var events: [AuditEvent] = []

  private let storageKey = "com.pdfeditor.audit.trail"
  private let maxEvents = 1000

  public init() {
    load()
  }

  // MARK: - Recording

  /// Record an audit event.
  public func record(_ event: AuditEvent) {
    events.insert(event, at: 0)
    // Trim to max events
    if events.count > maxEvents {
      events = Array(events.prefix(maxEvents))
    }
    save()
  }

  /// Convenience: record a document opened event.
  public func recordOpen(documentID: String) {
    record(AuditEvent(type: .documentOpened, documentID: documentID))
  }

  /// Convenience: record a page read event.
  public func recordRead(documentID: String, pageIndex: Int) {
    record(AuditEvent(type: .documentRead, documentID: documentID, detail: "page:\(pageIndex)"))
  }

  /// Convenience: record a search event.
  public func recordSearch(documentID: String, query: String) {
    record(AuditEvent(type: .documentSearched, documentID: documentID, detail: query))
  }

  /// Convenience: record an export event.
  public func recordExport(documentID: String, format: String) {
    record(AuditEvent(type: .documentExported, documentID: documentID, detail: format))
  }

  /// Convenience: record an annotation event.
  public func recordAnnotation(documentID: String, action: String) {
    record(AuditEvent(type: .documentAnnotated, documentID: documentID, detail: action))
  }

  /// Convenience: record a signing event.
  public func recordSign(documentID: String) {
    record(AuditEvent(type: .documentSigned, documentID: documentID))
  }

  /// Convenience: record a sharing event.
  public func recordShare(documentID: String) {
    record(AuditEvent(type: .documentShared, documentID: documentID))
  }

  /// Convenience: record a document closed event.
  public func recordClose(documentID: String) {
    record(AuditEvent(type: .documentClosed, documentID: documentID))
  }

  // MARK: - Querying

  /// Get events for a specific document.
  public func events(for documentID: String) -> [AuditEvent] {
    events.filter { $0.documentID == documentID }
  }

  /// Get events of a specific type.
  public func events(ofType type: AuditEventType) -> [AuditEvent] {
    events.filter { $0.type == type }
  }

  /// Get events in a date range.
  public func events(from start: Date, to end: Date) -> [AuditEvent] {
    events.filter { $0.timestamp >= start && $0.timestamp <= end }
  }

  /// Get unique document IDs that have been audited.
  public var auditedDocuments: [String] {
    Array(Set(events.map(\.documentID))).sorted()
  }

  /// Total event count.
  public var count: Int { events.count }

  // MARK: - Export

  /// Export the audit trail as JSON.
  public func exportJSON() -> Data? {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try? encoder.encode(events)
  }

  /// Export the audit trail as a human-readable report.
  public func exportReport() -> String {
    var report = "# Privacy Audit Trail\n\n"
    report += "Generated: \(DateFormatter.auditDate.string(from: Date()))\n"
    report += "Total events: \(events.count)\n"
    report += "Documents audited: \(auditedDocuments.count)\n\n"

    let grouped = Dictionary(grouping: events, by: \.documentID)
    for docID in grouped.keys.sorted() {
      let docEvents = grouped[docID]!.sorted { $0.timestamp < $1.timestamp }
      report += "## \(docID)\n\n"
      for event in docEvents {
        let time = DateFormatter.auditTime.string(from: event.timestamp)
        report += "- [\(time)] \(event.type.displayName)"
        if !event.detail.isEmpty {
          report += " — \(event.detail)"
        }
        report += "\n"
      }
      report += "\n"
    }

    return report
  }

  // MARK: - Persistence

  private func save() {
    guard let data = try? JSONEncoder().encode(events) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private func load() {
    guard let data = UserDefaults.standard.data(forKey: storageKey),
          let loaded = try? JSONDecoder().decode([AuditEvent].self, from: data)
    else { return }
    events = loaded
  }
}

// MARK: - Date Formatters

extension DateFormatter {
  static let auditDate: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    f.timeStyle = .none
    return f
  }()

  static let auditTime: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
  }()
}
