import CryptoKit
import Foundation

/// Operating envelope: the machine-readable datasheet that names the document
/// class the product currently certifies (round-3 merged branch, audit §7.1).
///
/// Doctrine alignment:
/// - Honest claims only: the artifact carries `truthStatus`; consumers surface
///   it verbatim and must not derive stronger claims than the artifact states.
/// - Canonical path: all envelope values come from the shipped
///   `operating-envelope.json` resource — never from code constants.
/// - No silent conversions: an outside-envelope document is refused with EVERY
///   exceeded row named. There is no first-row-only short circuit and no
///   fallback to a permissive default when the artifact is missing or invalid.
/// - Value-free: evaluation consumes facts (sizes, counts, flags), never
///   document content.
public struct OperatingEnvelope: Codable, Equatable, Sendable {

    public struct Version: Codable, Equatable, Sendable {
        public let major: Int
        public let minor: Int
    }

    public struct ParseBudget: Codable, Equatable, Sendable {
        public let value: Int
        public let provisional: Bool
        public let reference: String
        public let note: String?
    }

    public struct Rows: Codable, Equatable, Sendable {
        public let maxFileSizeBytes: Int
        public let maxPageCount: Int
        public let maxParseMilliseconds: ParseBudget
        public let supportedFieldClasses: [String]
        public let excludedDocumentFeatures: [String]
    }

    public struct Claims: Codable, Equatable, Sendable {
        public let statement: String
        public let claimDiscipline: String
    }

    public struct EvaluationPolicy: Codable, Equatable, Sendable {
        public let openTimeEvaluatedRows: [String]
        public let openTimeNote: String
        public let rejectionMessageContract: String
    }

    public struct FormClass: Codable, Equatable, Sendable {
        public let named: String
        public let status: String
        public let note: String?
    }

    public struct Provenance: Codable, Equatable, Sendable {
        public let source: String
        public let decisionGate: String
    }

    public let schema: String
    public let schemaVersion: Version
    public let envelopeID: String
    public let title: String
    public let generatedAt: String
    public let truthStatus: String
    public let claims: Claims
    public let rows: Rows
    public let evaluation: EvaluationPolicy
    public let formClass: FormClass
    public let provenance: Provenance

    // MARK: - Facts input (value-free, open-time available)

    /// Facts available before or during open. Deliberately excludes content:
    /// the envelope refuses on structure, never on values.
    public struct DocumentFacts: Equatable, Sendable {
        public let fileSizeBytes: Int
        public let pageCount: Int?
        public let isEncrypted: Bool
        public let hasXFA: Bool

        public init(fileSizeBytes: Int, pageCount: Int?, isEncrypted: Bool, hasXFA: Bool) {
            self.fileSizeBytes = fileSizeBytes
            self.pageCount = pageCount
            self.isEncrypted = isEncrypted
            self.hasXFA = hasXFA
        }
    }

    // MARK: - Evaluation outcome

    public enum ExceededRow: Equatable, Sendable, CustomStringConvertible {
        case maxFileSizeBytes(actual: Int, limit: Int)
        case maxPageCount(actual: Int, limit: Int)
        case encryptedDocument
        case xfaDocument

        public var rowName: String {
            switch self {
            case .maxFileSizeBytes: return "maxFileSizeBytes"
            case .maxPageCount: return "maxPageCount"
            case .encryptedDocument: return "excludedDocumentFeatures:encrypted"
            case .xfaDocument: return "excludedDocumentFeatures:xfa"
            }
        }

        public var detail: String {
            switch self {
            case let .maxFileSizeBytes(actual, limit):
                return "File is \(actual) bytes; envelope allows at most \(limit)."
            case let .maxPageCount(actual, limit):
                return "Document has \(actual) pages; envelope allows at most \(limit)."
            case .encryptedDocument:
                return "Document is encrypted; envelope excludes encrypted variants."
            case .xfaDocument:
                return "Document contains XFA; envelope excludes XFA."
            }
        }

        public var description: String { "\(rowName): \(detail)" }    }

    public enum Outcome: Equatable, Sendable {
        case inside
        case outside([ExceededRow])
    }

    // MARK: - Loading (fail-closed, no permissive fallback)

    public enum EnvelopeError: Error, LocalizedError {
        case resourceMissing(String)
        case invalidSchema(String)

        public var errorDescription: String? {
            switch self {
            case let .resourceMissing(path): return "Operating envelope resource not found: \(path)"
            case let .invalidSchema(reason): return "Operating envelope artifact is invalid: \(reason)"
            }
        }
    }

    public static let expectedSchema = "pdf-editor.operating-envelope"

    /// Loads the canonical artifact from this module's resources. Throws when
    /// missing or structurally invalid — never substitutes a default envelope.
    public static func load() throws -> OperatingEnvelope {
        guard let url = Bundle.module.url(forResource: "operating-envelope", withExtension: "json") else {
            throw EnvelopeError.resourceMissing("operating-envelope.json (PDFEditorCore resources)")
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> OperatingEnvelope {
        let envelope = try JSONDecoder().decode(OperatingEnvelope.self, from: data)
        guard envelope.schema == expectedSchema else {
            throw EnvelopeError.invalidSchema("schema is \(envelope.schema), expected \(expectedSchema)")
        }
        guard envelope.rows.maxFileSizeBytes > 0, envelope.rows.maxPageCount > 0 else {
            throw EnvelopeError.invalidSchema("row limits must be positive")
        }
        guard !envelope.claims.statement.isEmpty, !envelope.truthStatus.isEmpty else {
            throw EnvelopeError.invalidSchema("claims and truthStatus are mandatory (honest-claims doctrine)")
        }
        return envelope
    }

    // MARK: - Evaluation

    /// Deterministic, complete row evaluation: every exceeded row is reported
    /// (no first-match short circuit) so the rejection names the whole gap.
    public func evaluate(_ facts: DocumentFacts) -> Outcome {
        var exceeded: [ExceededRow] = []
        if facts.fileSizeBytes > rows.maxFileSizeBytes {
            exceeded.append(.maxFileSizeBytes(actual: facts.fileSizeBytes, limit: rows.maxFileSizeBytes))
        }
        if let pageCount = facts.pageCount, pageCount > rows.maxPageCount {
            exceeded.append(.maxPageCount(actual: pageCount, limit: rows.maxPageCount))
        }
        if facts.isEncrypted, rows.excludedDocumentFeatures.contains("encrypted") {
            exceeded.append(.encryptedDocument)
        }
        if facts.hasXFA, rows.excludedDocumentFeatures.contains("xfa") {
            exceeded.append(.xfaDocument)
        }
        return exceeded.isEmpty ? .inside : .outside(exceeded)
    }

    /// The honest rejection message: names every exceeded row (by row name and
    /// detail) and states that the document was not opened. Consumed by the
    /// (pending) open-time wiring; produced here so the wording contract lives
    /// with the artifact contract.
    public func rejectionMessage(for exceeded: [ExceededRow]) -> String {
        let named = exceeded.map { "\($0.rowName) — \($0.detail)" }.joined(separator: " ")
        return "Document not opened — outside the operating envelope (\(envelopeID)). \(named) This document class is not certified; nothing was modified."
    }
}
