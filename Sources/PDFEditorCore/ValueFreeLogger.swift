import Foundation

// MARK: - Log Level

/// Log levels for structured logging.
public enum LogLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case debug
    case info
    case warning
    case error
    case critical
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        let order: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Log Entry

/// A value-free log entry — no document content, no field values, no OCR.
public struct LogEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    /// Log level.
    public let level: LogLevel
    /// Category for filtering (bridge, provider, operation, security, audit).
    public let category: LogCategory
    /// Human-readable message (value-free).
    public let message: String
    /// Structured metadata (value-free keys).
    public let metadata: [String: String]
    /// Timestamp.
    public let timestamp: Date
    
    public init(level: LogLevel, category: LogCategory, message: String, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.level = level
        self.category = category
        self.message = message
        self.metadata = metadata
        self.timestamp = Date()
    }
}

/// Log categories for filtering.
public enum LogCategory: String, Codable, Sendable, CaseIterable {
    case bridge
    case provider
    case operation
    case security
    case audit
    case error
    case performance
}

// MARK: - Sensitive Data Patterns

/// Patterns that must NEVER appear in log messages.
/// These are checked before any message is emitted.
public enum SensitivePattern: Sendable {
    /// PDF document text content.
    case pdfText
    /// Form field values.
    case fieldValue
    /// OCR-extracted text.
    case ocrContent
    /// Source document bytes (base64 or raw).
    case sourceBytes
    /// Screenshots or image data.
    case screenshotData
    /// Passphrases or passwords.
    case passphrase
    /// API keys or tokens.
    case apiToken
    /// Email addresses.
    case emailAddress
    /// Phone numbers.
    case phoneNumber
    /// Credit card numbers.
    case creditCard
    /// Social security numbers.
    case ssn
    
    /// Regex pattern to detect this sensitive data.
    public var detectionPattern: String {
        switch self {
        case .pdfText:
            // Very long strings that could be document content
            return "^.{500,}$"
        case .fieldValue:
            // Looks like a form value (contains common field patterns)
            return "(?i)(name|email|address|phone|ssn|dob|date\\s*of\\s*birth)\\s*[:=]\\s*.+"
        case .ocrContent:
            // Starts with OCR-like patterns
            return "(?i)^\\s*\\d+\\s*\\w+\\s+\\d{4}"
        case .sourceBytes:
            // Base64-like long strings
            return "^[A-Za-z0-9+/]{100,}={0,2}$"
        case .screenshotData:
            // Data URI or image markers
            return "(?i)data:image|\\.(png|jpg|jpeg|gif|bmp|tiff)(\\s|$)"
        case .passphrase:
            // Common password patterns
            return "(?i)(password|passphrase|secret|key)\\s*[:=]\\s*\\S+"
        case .apiToken:
            // Bearer tokens or API keys
            return "(?i)(bearer|api[_-]?key|token|authorization)\\s*[:=]\\s*\\S+"
        case .emailAddress:
            // Email pattern
            return "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
        case .phoneNumber:
            // Phone number patterns
            return "\\+?\\d{1,4}[\\s.-]?\\(?\\d{1,4}\\)?[\\s.-]?\\d{1,4}[\\s.-]?\\d{1,4}"
        case .creditCard:
            // Credit card patterns
            return "\\d{4}[\\s.-]?\\d{4}[\\s.-]?\\d{4}[\\s.-]?\\d{4}"
        case .ssn:
            // SSN patterns
            return "\\d{3}[\\s.-]?\\d{2}[\\s.-]?\\d{4}"
        }
    }
}

// MARK: - Value-Free Logger

/// Privacy-preserving logger that enforces value-free logging.
/// Excludes: PDF text, field values, OCR content, source bytes, screenshots, passphrases.
/// This is a SECURITY-CRITICAL component — logs must never leak document content.
public actor ValueFreeLogger {
    /// Minimum log level to emit.
    public var minimumLevel: LogLevel = .info
    
    /// Whether logging is enabled.
    public var isEnabled: Bool = true
    
    /// Maximum number of retained entries.
    public var maxEntries: Int = 10000
    
    /// Log entries (in-memory ring buffer).
    private var entries: [LogEntry] = []
    
    /// Sensitive patterns to check.
    private let sensitivePatterns: [SensitivePattern] = [
        .pdfText, .fieldValue, .ocrContent, .sourceBytes,
        .screenshotData, .passphrase, .apiToken, .emailAddress,
        .phoneNumber, .creditCard, .ssn
    ]
    
    /// Callback for real-time log consumers.
    private var onLog: ((LogEntry) -> Void)?
    
    /// Statistics.
    public private(set) var stats = LogStats()
    
    public init() {}
    
    /// Set the minimum log level (actor-safe setter).
    public func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }
    
    /// Enable or disable logging (actor-safe setter).
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    // MARK: - Logging API
    
    /// Log a debug message.
    public func debug(_ message: String, category: LogCategory = .operation, metadata: [String: String] = [:]) {
        log(level: .debug, category: category, message: message, metadata: metadata)
    }
    
    /// Log an info message.
    public func info(_ message: String, category: LogCategory = .operation, metadata: [String: String] = [:]) {
        log(level: .info, category: category, message: message, metadata: metadata)
    }
    
    /// Log a warning message.
    public func warning(_ message: String, category: LogCategory = .operation, metadata: [String: String] = [:]) {
        log(level: .warning, category: category, message: message, metadata: metadata)
    }
    
    /// Log an error message.
    public func error(_ message: String, category: LogCategory = .error, metadata: [String: String] = [:]) {
        log(level: .error, category: category, message: message, metadata: metadata)
    }
    
    /// Log a critical message.
    public func critical(_ message: String, category: LogCategory = .security, metadata: [String: String] = [:]) {
        log(level: .critical, category: category, message: message, metadata: metadata)
    }
    
    // MARK: - Core Logging
    
    /// Core logging function — sanitizes message before storage.
    public func log(level: LogLevel, category: LogCategory, message: String, metadata: [String: String] = [:]) {
        guard isEnabled, level >= minimumLevel else { return }
        
        // Sanitize message
        let sanitized = sanitize(message)
        guard !sanitized.isEmpty else { return }
        
        // Sanitize metadata values
        let sanitizedMetadata = metadata.mapValues { sanitize($0) }
        
        // Create entry
        let entry = LogEntry(level: level, category: category, message: sanitized, metadata: sanitizedMetadata)
        
        // Store
        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }
        
        // Update stats
        stats.record(level: level)
        
        // Notify real-time consumers
        onLog?(entry)
        
        #if DEBUG
        print("[\(level.rawValue.uppercased())] [\(category.rawValue)] \(sanitized)")
        #endif
    }
    
    /// Set a real-time log consumer.
    public func onLog(_ callback: @escaping @Sendable (LogEntry) -> Void) {
        self.onLog = callback
    }
    
    // MARK: - Sanitization
    
    /// Sanitize a message by redacting sensitive patterns.
    /// Returns empty string if the entire message is sensitive.
    public func sanitize(_ message: String) -> String {
        var result = message
        
        for pattern in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern.detectionPattern, options: []) {
                let range = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, range: range)
                
                if !matches.isEmpty {
                    // If the entire message matches a sensitive pattern, redact entirely
                    if matches.count == 1 && matches[0].range == range {
                        return "[REDACTED]"
                    }
                    
                    // Otherwise, redact the sensitive portions
                    var mutableResult = result
                    for match in matches.reversed() {
                        if let matchRange = Range(match.range, in: mutableResult) {
                            mutableResult.replaceSubrange(matchRange, with: "[REDACTED]")
                        }
                    }
                    result = mutableResult
                }
            }
        }
        
        return result
    }
    
    /// Check if a string contains sensitive data.
    public func containsSensitiveData(_ message: String) -> Bool {
        for pattern in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern.detectionPattern, options: []) {
                let range = NSRange(message.startIndex..., in: message)
                if regex.firstMatch(in: message, range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
    
    // MARK: - Query
    
    /// All log entries.
    public func allEntries() -> [LogEntry] {
        Array(entries)
    }
    
    /// Entries matching a filter.
    public func entries(level: LogLevel? = nil, category: LogCategory? = nil, limit: Int = 100) -> [LogEntry] {
        entries.filter { entry in
            if let level = level, entry.level != level { return false }
            if let category = category, entry.category != category { return false }
            return true
        }
        .suffix(limit)
    }
    
    /// Recent entries.
    public func recent(limit: Int = 50) -> [LogEntry] {
        Array(entries.suffix(limit))
    }
    
    /// Clear all entries.
    public func clear() {
        entries.removeAll()
        stats = LogStats()
    }
    
    /// Export entries as JSON.
    public func exportJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(entries)
    }
}

// MARK: - Log Statistics

/// Aggregate statistics for the log.
public struct LogStats: Codable, Sendable {
    public var debugCount: Int = 0
    public var infoCount: Int = 0
    public var warningCount: Int = 0
    public var errorCount: Int = 0
    public var criticalCount: Int = 0
    public var redactedCount: Int = 0
    public var totalEntries: Int = 0
    
    public init() {}
    
    mutating func record(level: LogLevel) {
        totalEntries += 1
        switch level {
        case .debug: debugCount += 1
        case .info: infoCount += 1
        case .warning: warningCount += 1
        case .error: errorCount += 1
        case .critical: criticalCount += 1
        }
    }
}
