import Foundation

/// Approval workflow for collaboration — tracks who approved what, when.
///
/// First principle: approvals are explicit, auditable, and reversible.
/// Every approval has a reason, a timestamp, and can be withdrawn.
///
/// Architecture:
/// - `ApprovalRequest` — a request for approval on a document/package
/// - `ApprovalRecord` — a single approval decision
/// - `ApprovalWorkflow` — manages the approval lifecycle
///
/// Doctrine alignment:
/// - §5: Evidence-based — every approval has full audit trail
/// - §8: Capability activation — approval is opt-in per review cycle
/// - §12: Privacy stays value-free — records decisions, not content

// MARK: - Approval Status

/// Status of an approval request.
public enum ApprovalStatus: String, Codable, Sendable, CaseIterable, Identifiable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    case withdrawn = "withdrawn"
    case expired = "expired"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .withdrawn: return "Withdrawn"
        case .expired: return "Expired"
        }
    }
    
    public var symbolName: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .withdrawn: return "arrow.uturn.backward"
        case .expired: return "timer"
        }
    }
}

// MARK: - Approval Record

/// A single approval decision.
public struct ApprovalRecord: Codable, Sendable, Identifiable {
    public let id: UUID
    /// Who made the decision.
    public let approver: String
    /// The decision.
    public let status: ApprovalStatus
    /// Reason for the decision (required for reject, optional for approve).
    public let reason: String
    /// When the decision was made.
    public let decidedAt: Date
    /// Package record ID (if this is a package-level approval).
    public let packageRecordID: UUID?
    /// Document name.
    public let documentName: String
    /// Version number at time of approval (if versioned).
    public let versionNumber: Int?
    
    public init(
        approver: String,
        status: ApprovalStatus,
        reason: String = "",
        packageRecordID: UUID? = nil,
        documentName: String,
        versionNumber: Int? = nil
    ) {
        self.id = UUID()
        self.approver = approver
        self.status = status
        self.reason = reason
        self.decidedAt = Date()
        self.packageRecordID = packageRecordID
        self.documentName = documentName
        self.versionNumber = versionNumber
    }
}

// MARK: - Approval Request

/// A request for approval on a document or package.
public struct ApprovalRequest: Codable, Sendable, Identifiable {
    public let id: UUID
    /// Who requested the approval.
    public let requester: String
    /// Document name.
    public let documentName: String
    /// Package record ID (if package-level).
    public let packageRecordID: UUID?
    /// Required approvers (all must approve for the request to be fulfilled).
    public let requiredApprovers: [String]
    /// Current status.
    public var status: ApprovalStatus
    /// Approval decisions received.
    public private(set) var records: [ApprovalRecord]
    /// When the request was created.
    public let createdAt: Date
    /// Deadline (nil = no deadline).
    public let deadline: Date?
    /// Notes from the requester.
    public let notes: String
    
    /// Whether all required approvers have approved.
    public var isFullyApproved: Bool {
        guard !requiredApprovers.isEmpty else { return false }
        let approvedSet = Set(records.filter { $0.status == .approved }.map { $0.approver })
        return requiredApprovers.allSatisfy { approvedSet.contains($0) }
    }
    
    /// Whether any approver has rejected.
    public var isRejected: Bool {
        records.contains { $0.status == .rejected }
    }
    
    /// Whether the request has expired.
    public var isExpired: Bool {
        guard let deadline = deadline else { return false }
        return Date() > deadline
    }
    
    /// Approvals still pending.
    public var pendingApprovers: [String] {
        let decided = Set(records.filter { $0.status == .approved || $0.status == .rejected }.map { $0.approver })
        return requiredApprovers.filter { !decided.contains($0) }
    }
    
    /// Completion percentage (0.0–1.0).
    public var completionRate: Double {
        guard !requiredApprovers.isEmpty else { return 0 }
        let approved = records.filter { $0.status == .approved }.count
        return Double(approved) / Double(requiredApprovers.count)
    }
    
    public init(
        requester: String,
        documentName: String,
        packageRecordID: UUID? = nil,
        requiredApprovers: [String],
        deadline: Date? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.requester = requester
        self.documentName = documentName
        self.packageRecordID = packageRecordID
        self.requiredApprovers = requiredApprovers
        self.status = .pending
        self.records = []
        self.createdAt = Date()
        self.deadline = deadline
        self.notes = notes
    }
    
    /// Add an approval record.
    public mutating func addRecord(_ record: ApprovalRecord) {
        records.append(record)
        
        // Update status based on records
        if isRejected {
            status = .rejected
        } else if isFullyApproved {
            status = .approved
        } else if isExpired {
            status = .expired
        }
    }
}

// MARK: - Approval Workflow

/// Manages the approval lifecycle for collaboration packages.
@MainActor
public final class ApprovalWorkflow: ObservableObject {
    /// All approval requests.
    @Published public var requests: [ApprovalRequest] = []
    
    /// History of all approval decisions.
    public private(set) var decisionHistory: [ApprovalRecord] = []
    
    private let storageKey = "com.pdfeditor.collaboration.approvals"
    
    public init() {
        load()
    }
    
    // MARK: - Request Management
    
    /// Create an approval request.
    @discardableResult
    public func createRequest(
        requester: String,
        documentName: String,
        packageRecordID: UUID? = nil,
        requiredApprovers: [String],
        deadline: Date? = nil,
        notes: String = ""
    ) -> ApprovalRequest {
        var request = ApprovalRequest(
            requester: requester,
            documentName: documentName,
            packageRecordID: packageRecordID,
            requiredApprovers: requiredApprovers,
            deadline: deadline,
            notes: notes
        )
        requests.append(request)
        save()
        return request
    }
    
    /// Record an approval decision.
    public func recordDecision(
        requestID: UUID,
        approver: String,
        status: ApprovalStatus,
        reason: String = ""
    ) {
        guard let index = requests.firstIndex(where: { $0.id == requestID }) else { return }
        
        let record = ApprovalRecord(
            approver: approver,
            status: status,
            reason: reason,
            packageRecordID: requests[index].packageRecordID,
            documentName: requests[index].documentName,
            versionNumber: nil
        )
        
        requests[index].addRecord(record)
        decisionHistory.append(record)
        save()
    }
    
    /// Withdraw an approval.
    public func withdrawApproval(recordID: UUID, approver: String) {
        guard let reqIndex = requests.firstIndex(where: { $0.records.contains { $0.id == recordID } }),
              let recIndex = requests[reqIndex].records.firstIndex(where: { $0.id == recordID }) else { return }
        
        let original = requests[reqIndex].records[recIndex]
        let withdrawal = ApprovalRecord(
            approver: approver,
            status: .withdrawn,
            reason: "Withdrawn by \(approver)",
            packageRecordID: original.packageRecordID,
            documentName: original.documentName
        )
        
        requests[reqIndex].addRecord(withdrawal)
        decisionHistory.append(withdrawal)
        save()
    }
    
    /// Cancel a request entirely.
    public func cancelRequest(requestID: UUID) {
        requests.removeAll { $0.id == requestID }
        save()
    }
    
    // MARK: - Queries
    
    /// Pending requests.
    public var pendingRequests: [ApprovalRequest] {
        requests.filter { $0.status == .pending }
    }
    
    /// Approved requests.
    public var approvedRequests: [ApprovalRequest] {
        requests.filter { $0.status == .approved }
    }
    
    /// Rejected requests.
    public var rejectedRequests: [ApprovalRequest] {
        requests.filter { $0.status == .rejected }
    }
    
    /// Requests for a specific document.
    public func requests(for documentName: String) -> [ApprovalRequest] {
        requests.filter { $0.documentName == documentName }
    }
    
    /// Requests requiring a specific approver.
    public func requests(forApprover approver: String) -> [ApprovalRequest] {
        requests.filter { $0.requiredApprovers.contains(approver) && $0.status == .pending }
    }
    
    /// Dashboard summary.
    public var summary: ApprovalSummary {
        ApprovalSummary(
            totalRequests: requests.count,
            pendingCount: pendingRequests.count,
            approvedCount: approvedRequests.count,
            rejectedCount: rejectedRequests.count,
            totalDecisions: decisionHistory.count
        )
    }
    
    // MARK: - Persistence
    
    private func save() {
        guard let data = try? JSONEncoder().encode(requests) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([ApprovalRequest].self, from: data) else { return }
        requests = loaded
    }
    
    /// Clear all data.
    public func clearAll() {
        requests = []
        decisionHistory = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - Approval Summary

/// Aggregated approval stats.
public struct ApprovalSummary: Sendable {
    public let totalRequests: Int
    public let pendingCount: Int
    public let approvedCount: Int
    public let rejectedCount: Int
    public let totalDecisions: Int
    
    public var description: String {
        "\(totalRequests) requests: \(pendingCount) pending, \(approvedCount) approved, \(rejectedCount) rejected"
    }
}
