import Foundation

// MARK: - Resource Limits

/// Resource caps for companion bridge operations.
/// Enforces cancellation, timeouts, and capacity constraints.
public struct ResourceLimits: Codable, Sendable {
    /// Maximum concurrent requests per bridge session.
    public var maxConcurrentRequests: Int
    
    /// Per-request timeout in seconds.
    public var requestTimeoutSeconds: TimeInterval
    
    /// Maximum request payload size in bytes.
    public var maxPayloadBytes: Int
    
    /// Maximum log entries retained.
    public var maxLogEntries: Int
    
    /// Maximum memory budget in bytes (for companion processing).
    public var maxMemoryBytes: Int
    
    /// Maximum number of pages a single operation can touch.
    public var maxPagesPerOperation: Int
    
    /// Maximum number of documents in a batch.
    public var maxBatchDocuments: Int
    
    public init(
        maxConcurrentRequests: Int = 4,
        requestTimeoutSeconds: TimeInterval = 120,
        maxPayloadBytes: Int = 50 * 1024 * 1024,
        maxLogEntries: Int = 1000,
        maxMemoryBytes: Int = 512 * 1024 * 1024,
        maxPagesPerOperation: Int = 500,
        maxBatchDocuments: Int = 100
    ) {
        self.maxConcurrentRequests = maxConcurrentRequests
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.maxPayloadBytes = maxPayloadBytes
        self.maxLogEntries = maxLogEntries
        self.maxMemoryBytes = maxMemoryBytes
        self.maxPagesPerOperation = maxPagesPerOperation
        self.maxBatchDocuments = maxBatchDocuments
    }
    
    /// Strict limits for untrusted companions.
    public static let strict = ResourceLimits(
        maxConcurrentRequests: 1,
        requestTimeoutSeconds: 30,
        maxPayloadBytes: 10 * 1024 * 1024,
        maxLogEntries: 100,
        maxMemoryBytes: 128 * 1024 * 1024,
        maxPagesPerOperation: 50,
        maxBatchDocuments: 10
    )
    
    /// Relaxed limits for verified companions.
    public static let relaxed = ResourceLimits(
        maxConcurrentRequests: 8,
        requestTimeoutSeconds: 300,
        maxPayloadBytes: 100 * 1024 * 1024,
        maxLogEntries: 5000,
        maxMemoryBytes: 1024 * 1024 * 1024,
        maxPagesPerOperation: 2000,
        maxBatchDocuments: 500
    )
    
    /// Validate a payload against size limits.
    public func validatePayload(_ data: Data) -> ResourceValidation {
        if data.count > maxPayloadBytes {
            return .exceedsLimit(resource: "payloadSize", actual: data.count, limit: maxPayloadBytes)
        }
        return .ok
    }
    
    /// Validate page count against limits.
    public func validatePageCount(_ count: Int) -> ResourceValidation {
        if count > maxPagesPerOperation {
            return .exceedsLimit(resource: "pageCount", actual: count, limit: maxPagesPerOperation)
        }
        return .ok
    }
    
    /// Validate batch size.
    public func validateBatchSize(_ count: Int) -> ResourceValidation {
        if count > maxBatchDocuments {
            return .exceedsLimit(resource: "batchSize", actual: count, limit: maxBatchDocuments)
        }
        return .ok
    }
}

// MARK: - Resource Validation

/// Result of a resource limit check.
public enum ResourceValidation: Sendable {
    case ok
    case exceedsLimit(resource: String, actual: Int, limit: Int)
    
    public var isValid: Bool {
        if case .ok = self { return true }
        return false
    }
    
    public var errorMessage: String? {
        if case .exceedsLimit(let resource, let actual, let limit) = self {
            return "\(resource) exceeds limit: \(actual) > \(limit)"
        }
        return nil
    }
}

// MARK: - Operation Cancellation

/// Tracks cancellation state for long-running operations.
public actor OperationCancellation {
    /// IDs of cancelled operations.
    private var cancelledIDs: Set<UUID> = []
    
    /// Cancellation reason per operation.
    private var reasons: [UUID: String] = [:]
    
    public init() {}
    
    /// Request cancellation of an operation.
    public func cancel(id: UUID, reason: String = "user") {
        cancelledIDs.insert(id)
        reasons[id] = reason
    }
    
    /// Check if an operation has been cancelled.
    public func isCancelled(_ id: UUID) -> Bool {
        cancelledIDs.contains(id)
    }
    
    /// Throw if cancelled (call from async context).
    public func checkCancellation(_ id: UUID) throws {
        if cancelledIDs.contains(id) {
            throw BridgeError.operationCancelled
        }
    }
    
    /// Clear cancellation for an operation.
    public func clearCancellation(_ id: UUID) {
        cancelledIDs.remove(id)
        reasons.removeValue(forKey: id)
    }
    
    /// Get the cancellation reason.
    public func reason(for id: UUID) -> String? {
        reasons[id]
    }
    
    /// Clear all cancellations.
    public func clearAll() {
        cancelledIDs.removeAll()
        reasons.removeAll()
    }
    
    /// Number of active cancellations.
    public var activeCount: Int {
        cancelledIDs.count
    }
}

// MARK: - Timeout Configuration

/// Per-operation timeout configurations.
public struct TimeoutConfig: Sendable {
    /// Default timeout for companion operations.
    public var defaultTimeout: TimeInterval
    
    /// Timeout for OCR operations (longer).
    public var ocrTimeout: TimeInterval
    
    /// Timeout for validation operations.
    public var validationTimeout: TimeInterval
    
    /// Timeout for handshake operations (shorter).
    public var handshakeTimeout: TimeInterval
    
    public init(
        defaultTimeout: TimeInterval = 120,
        ocrTimeout: TimeInterval = 300,
        validationTimeout: TimeInterval = 60,
        handshakeTimeout: TimeInterval = 10
    ) {
        self.defaultTimeout = defaultTimeout
        self.ocrTimeout = ocrTimeout
        self.validationTimeout = validationTimeout
        self.handshakeTimeout = handshakeTimeout
    }
    
    /// Get timeout for a specific operation type.
    public func timeout(for operation: String) -> TimeInterval {
        switch operation.lowercased() {
        case "ocr", "textrecognition":
            return ocrTimeout
        case "validate", "validation":
            return validationTimeout
        case "handshake", "ping":
            return handshakeTimeout
        default:
            return defaultTimeout
        }
    }
}
