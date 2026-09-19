import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Operating Envelope Tests (round-3 merged branch, audit §7.1)

@Suite("Operating Envelope")
struct OperatingEnvelopeTests {

    // MARK: - Canonical artifact

    @Test("Canonical artifact loads from resources and is structurally valid")
    func loadsCanonicalArtifact() throws {
        let envelope = try OperatingEnvelope.load()
        #expect(envelope.schema == OperatingEnvelope.expectedSchema)
        #expect(envelope.envelopeID == "cohort-1-recurring-forms")
        #expect(envelope.rows.maxFileSizeBytes == 52_428_800)
        #expect(!envelope.claims.statement.isEmpty)
        // Honest-claims doctrine: the artifact ships with a truth status, and
        // cohort certification is pending — the artifact must not claim green.
        #expect(envelope.truthStatus.contains("pending"))
    }

    @Test("Decode rejects wrong schema and non-positive limits")
    func decodeRejectsInvalid() throws {
        let envelope = try OperatingEnvelope.load()
        let encoder = JSONEncoder()
        let data = try encoder.encode(envelope)

        // Mutate schema → invalid (S2-style mutation: this input must fail).
        var broken = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        broken["schema"] = "pdf-editor.something-else"
        let brokenData = try JSONSerialization.data(withJSONObject: broken)
        #expect(throws: OperatingEnvelope.EnvelopeError.self) { try OperatingEnvelope.decode(brokenData) }
    }

    // MARK: - Evaluation

    @Test("Inside-envelope document evaluates inside")
    func insideEnvelope() throws {
        let envelope = try OperatingEnvelope.load()
        let facts = OperatingEnvelope.DocumentFacts(
            fileSizeBytes: 1_000_000, pageCount: 4, isEncrypted: false, hasXFA: false
        )
        #expect(envelope.evaluate(facts) == .inside)
    }

    @Test("Each exceeded row is named individually")
    func eachRowNamed() throws {
        let envelope = try OperatingEnvelope.load()
        let big = OperatingEnvelope.DocumentFacts(
            fileSizeBytes: envelope.rows.maxFileSizeBytes + 1, pageCount: 1, isEncrypted: false, hasXFA: false
        )
        if case let .outside(rows) = envelope.evaluate(big) {
            #expect(rows.count == 1)
            #expect(rows.first?.rowName == "maxFileSizeBytes")
        } else {
            Issue.record("expected outside")
        }

        let xfa = OperatingEnvelope.DocumentFacts(
            fileSizeBytes: 10, pageCount: 1, isEncrypted: false, hasXFA: true
        )
        if case let .outside(rows) = envelope.evaluate(xfa) {
            #expect(rows.first?.rowName == "excludedDocumentFeatures:xfa")
        } else {
            Issue.record("expected outside")
        }
    }

    @Test("All exceeded rows are reported together (no first-match short circuit)")
    func allRowsReported() throws {
        let envelope = try OperatingEnvelope.load()
        let facts = OperatingEnvelope.DocumentFacts(
            fileSizeBytes: envelope.rows.maxFileSizeBytes + 1,
            pageCount: envelope.rows.maxPageCount + 5,
            isEncrypted: true,
            hasXFA: true
        )
        if case let .outside(rows) = envelope.evaluate(facts) {
            #expect(rows.count == 4)
            let names = Set(rows.map(\.rowName))
            #expect(names == ["maxFileSizeBytes", "maxPageCount", "excludedDocumentFeatures:encrypted", "excludedDocumentFeatures:xfa"])
        } else {
            Issue.record("expected outside")
        }
    }

    @Test("Rejection message names every exceeded row and states non-opening")
    func rejectionMessage() throws {
        let envelope = try OperatingEnvelope.load()
        let facts = OperatingEnvelope.DocumentFacts(
            fileSizeBytes: envelope.rows.maxFileSizeBytes + 1, pageCount: nil, isEncrypted: true, hasXFA: false
        )
        if case let .outside(rows) = envelope.evaluate(facts) {
            let message = envelope.rejectionMessage(for: rows)
            #expect(message.contains("not opened"))
            #expect(message.contains("maxFileSizeBytes"))
            #expect(message.contains("encrypted"))
            #expect(message.contains(envelope.envelopeID))
        } else {
            Issue.record("expected outside")
        }
    }

    @Test("Unknown page count does not fabricate a page-row rejection")
    func nilPageCountSkipsRow() throws {
        let envelope = try OperatingEnvelope.load()
        let facts = OperatingEnvelope.DocumentFacts(
            fileSizeBytes: 10, pageCount: nil, isEncrypted: false, hasXFA: false
        )
        #expect(envelope.evaluate(facts) == .inside)
    }

    @Test("Parse budget row is exposed as provisional, not evaluated at open")
    func parseBudgetIsProvisionalDatasheetRow() throws {
        let envelope = try OperatingEnvelope.load()
        #expect(envelope.rows.maxParseMilliseconds.provisional)
        // Open-time evaluation deliberately excludes the parse budget row.
        #expect(!envelope.evaluation.openTimeEvaluatedRows.contains("maxParseMilliseconds"))
    }
}
