import Foundation
import Testing
@testable import PDFEditorCore

@Suite("CommitFlow")
struct CommitFlowTests {
  // MARK: - CommitBindingInfo

  @Test("Binding info creates with all fields")
  func bindingInfoCreation() {
    let binding = CommitBindingInfo(
      fileName: "contract.pdf",
      documentHash: "abc123def456",
      fileSize: 1024,
      pageCount: 5,
      documentTitle: "Employment Contract",
      documentAuthor: "Acme Corp"
    )
    #expect(binding.fileName == "contract.pdf")
    #expect(binding.documentHash == "abc123def456")
    #expect(binding.fileSize == 1024)
    #expect(binding.pageCount == 5)
    #expect(binding.documentTitle == "Employment Contract")
    #expect(binding.documentAuthor == "Acme Corp")
  }

  @Test("Binding info defaults to Unknown")
  func bindingInfoDefaults() {
    let binding = CommitBindingInfo(fileName: "test.pdf", documentHash: "abc", fileSize: 0, pageCount: 0)
    #expect(binding.documentTitle == "Unknown")
    #expect(binding.documentAuthor == "Unknown")
  }

  @Test("Binding summary includes key fields")
  func bindingSummary() {
    let binding = CommitBindingInfo(
      fileName: "test.pdf",
      documentHash: "abcdef1234567890",
      fileSize: 2048,
      pageCount: 3,
      documentTitle: "Test Doc",
      documentAuthor: "Author"
    )
    let summary = binding.bindingSummary
    #expect(summary.contains("Test Doc"))
    #expect(summary.contains("Author"))
    #expect(summary.contains("3"))
    #expect(summary.contains("abcdef1234567890"))
  }

  // MARK: - CommitIntegrityCheck

  @Test("Unsigned document is safe to sign")
  func unsignedSafe() {
    let check = CommitIntegrityCheck(status: .unsigned, sourceHash: "abc")
    #expect(check.isSafeToSign == true)
    #expect(check.statusMessage.contains("Safe to sign"))
  }

  @Test("Valid signatures are safe to sign")
  func validSafe() {
    let check = CommitIntegrityCheck(status: .signedValid(count: 2), sourceHash: "abc")
    #expect(check.isSafeToSign == true)
    #expect(check.statusMessage.contains("2 valid"))
  }

  @Test("Altered signatures are not safe")
  func alteredUnsafe() {
    let check = CommitIntegrityCheck(status: .signedAltered(count: 1), sourceHash: "abc")
    #expect(check.isSafeToSign == false)
    #expect(check.statusMessage.contains("altered"))
  }

  @Test("Unverifiable is not safe")
  func unverifiableUnsafe() {
    let check = CommitIntegrityCheck(status: .unverifiable(reason: "parse error"), sourceHash: "abc")
    #expect(check.isSafeToSign == false)
    #expect(check.statusMessage.contains("parse error"))
  }

  // MARK: - CommitAuditEntry

  @Test("Audit entry creates with correct fields")
  func auditEntryCreation() {
    let entry = CommitAuditEntry(
      signerName: "John Doe",
      fileName: "contract.pdf",
      documentHash: "abc123",
      pageIndex: 2,
      method: "drawn",
      integrityStatus: "unsigned",
      reason: "Acceptance"
    )
    #expect(entry.signerName == "John Doe")
    #expect(entry.fileName == "contract.pdf")
    #expect(entry.pageIndex == 2)
    #expect(entry.method == "drawn")
    #expect(entry.reason == "Acceptance")
    #expect(entry.integrityStatus == "unsigned")
  }

  @Test("Audit entry summary is readable")
  func auditEntrySummary() {
    let entry = CommitAuditEntry(
      signerName: "Jane Smith",
      fileName: "agreement.pdf",
      documentHash: "abc",
      pageIndex: 0,
      method: "typed",
      integrityStatus: "unsigned"
    )
    let summary = entry.summary
    #expect(summary.contains("Jane Smith"))
    #expect(summary.contains("agreement.pdf"))
    #expect(summary.contains("typed"))
    #expect(summary.contains("page 1"))
  }

  @Test("Audit entry is Codable")
  func auditEntryCodable() {
    let entry = CommitAuditEntry(
      signerName: "Test",
      fileName: "test.pdf",
      documentHash: "abc",
      pageIndex: 0,
      method: "drawn",
      integrityStatus: "unsigned"
    )
    let data = try? JSONEncoder().encode(entry)
    #expect(data != nil)
    let decoded = try? JSONDecoder().decode(CommitAuditEntry.self, from: data!)
    #expect(decoded?.signerName == "Test")
    #expect(decoded?.id == entry.id)
  }

  // MARK: - CommitFlowManager

  @Test("Manager starts in verifying state")
  @MainActor
  func managerInitialState() {
    let mgr = CommitFlowManager()
    if case .verifying = mgr.state {
      // expected
    } else {
      Issue.record("Expected .verifying state")
    }
  }

  @Test("Manager begin with unsigned document goes to ready")
  @MainActor
  func managerBeginUnsigned() {
    let mgr = CommitFlowManager()
    // Use a minimal PDF (header only — won't have signatures)
    let minimalPDF = "%PDF-1.0\n1 0 obj<</Type/Catalog>>endobj\nxref\n0 0\ntrailer<</Size 1/Root 1 0 R>>\nstartxref\n0\n%%EOF"
    let data = minimalPDF.data(using: .utf8)!
    mgr.begin(
      fileName: "test.pdf",
      documentData: data,
      pageCount: 1,
      documentTitle: "Test",
      documentAuthor: "Author"
    )
    // Should be ready or integrityWarning (depending on whether the parser finds anything)
    if case .ready = mgr.state {
      // expected for unsigned
    } else if case .integrityWarning = mgr.state {
      // also acceptable — parser may flag the minimal PDF
    } else {
      Issue.record("Expected .ready or .integrityWarning, got \(mgr.state)")
    }
  }

  @Test("Manager cancel resets to verifying")
  @MainActor
  func managerCancel() {
    let mgr = CommitFlowManager()
    mgr.cancel()
    if case .verifying = mgr.state {
      // expected
    } else {
      Issue.record("Expected .verifying after cancel")
    }
  }

  // MARK: - Sendable

  @Test("CommitBindingInfo is Sendable")
  func bindingSendable() {
    let binding = CommitBindingInfo(fileName: "test.pdf", documentHash: "abc", fileSize: 0, pageCount: 0)
    Task {
      let captured = binding
      #expect(captured.fileName == "test.pdf")
    }
  }

  @Test("CommitAuditEntry is Sendable")
  func auditSendable() {
    let entry = CommitAuditEntry(signerName: "Test", fileName: "test.pdf", documentHash: "abc", pageIndex: 0, method: "drawn", integrityStatus: "unsigned")
    Task {
      let captured = entry
      #expect(captured.signerName == "Test")
    }
  }
}
