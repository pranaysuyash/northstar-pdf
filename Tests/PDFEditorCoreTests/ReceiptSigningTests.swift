import CryptoKit
import Foundation
import Testing
@testable import PDFEditorCore

// MARK: - Signed evidence chain tests (ReceiptSigning + CohortEntitlement, R3-05)

@Suite("Receipt Signing and Entitlement Chain")
struct ReceiptSigningTests {

    // MARK: - Canonical encoding

    @Test("Canonical encoding is deterministic (same value, same bytes)")
    func canonicalEncodingDeterministic() throws {
        let receipt = Self.makeReceipt()
        let first = try CanonicalJSON.encoding(receipt)
        let second = try CanonicalJSON.encoding(receipt)
        #expect(first == second)
    }

    // MARK: - Execution receipt signing

    @Test("Receipt signs, verifies, and records isSigned")
    func receiptSignVerify() throws {
        let key = ReceiptSigningKey()
        let receipt = Self.makeReceipt()
        #expect(!receipt.isSigned)

        let signature = try key.sign(receipt)
        let signed = SignedExecutionReceipt(receipt: receipt, signature: signature)
        #expect(signed.verify(with: key.verificationKey))
        // The receipt itself records the signing fact.
        let stamped = Self.makeReceipt(signature: signature)
        #expect(stamped.isSigned)
    }

    @Test("Tampered receipt field fails verification (S2 mutation)")
    func tamperedReceiptFails() throws {
        let key = ReceiptSigningKey()
        var receipt = Self.makeReceipt()
        let signature = try key.sign(receipt)
        #expect(key.verificationKey.verify(signature: signature, over: receipt))

        receipt = Self.makeReceipt(notes: "mutated after signing")
        #expect(!key.verificationKey.verify(signature: signature, over: receipt))
    }

    // MARK: - Gate attestation

    @Test("Gate attestation signs and verifies against report digest")
    func attestationSignVerify() throws {
        let key = ReceiptSigningKey()
        let reportBytes = Data("{\"schema\":\"pdf-editor.human-review-gate\"}".utf8)
        let attestation = GateReportAttestation(
            gateSchema: "pdf-editor.human-review-gate",
            gateReportSHA256: GateReportDigest.sha256Hex(of: reportBytes)
        )
        let signed = try SignedGateReportAttestation.sign(attestation, with: key)
        #expect(signed.verify(with: key.verificationKey))
        let attestedDigest = signed.attestation.gateReportSHA256
        #expect(attestedDigest == GateReportDigest.sha256Hex(of: reportBytes))
    }

    // MARK: - Entitlement chain

    @Test("Entitlement chain verifies: entitlement → attestation → report digest")
    func chainVerifies() throws {
        let key = ReceiptSigningKey()
        let reportBytes = Data("gate report bytes".utf8)
        let attestation = try SignedGateReportAttestation.sign(
            GateReportAttestation(
                gateSchema: "pdf-editor.human-review-gate",
                gateReportSHA256: GateReportDigest.sha256Hex(of: reportBytes)
            ),
            with: key
        )
        let payload = CohortEntitlementPayload(
            formClass: "IRS W-9",
            passDate: Date(timeIntervalSince1970: 1_791_000_000),
            gateAttestation: attestation,
            envelopeID: "cohort-1-recurring-forms"
        )
        let entitlement = try SignedCohortEntitlement.sign(payload, with: key)
        let verdict = entitlement.verifyChain(with: key.verificationKey)
        #expect(verdict.chainValid)
        #expect(verdict.entitlementSignatureValid)
        #expect(verdict.gateAttestationSignatureValid)
    }

    @Test("Tampered form class breaks the entitlement link (S2 mutation)")
    func tamperedFormClassBreaksChain() throws {
        let key = ReceiptSigningKey()
        let attestation = try SignedGateReportAttestation.sign(
            GateReportAttestation(gateSchema: "pdf-editor.human-review-gate", gateReportSHA256: String(repeating: "aa", count: 32)),
            with: key
        )
        let signed = try SignedCohortEntitlement.sign(
            CohortEntitlementPayload(formClass: "IRS W-9", passDate: Date(), gateAttestation: attestation, envelopeID: "cohort-1"),
            with: key
        )
        let tamperedPayload = CohortEntitlementPayload(
            entitlementID: signed.payload.entitlementID,
            formClass: "IRS W-4",
            passDate: signed.payload.passDate,
            gateAttestation: signed.payload.gateAttestation,
            envelopeID: signed.payload.envelopeID
        )
        let tampered = SignedCohortEntitlement(payload: tamperedPayload, signature: signed.signature)
        let verdict = tampered.verifyChain(with: key.verificationKey)
        #expect(!verdict.chainValid)
        #expect(!verdict.entitlementSignatureValid)
    }

    @Test("Attestation signed by a different key fails the chain (authority mismatch)")
    func authorityMismatchFails() throws {
        let issuer = ReceiptSigningKey()
        let impostor = ReceiptSigningKey()
        // Attestation signed by the impostor.
        let attestation = try SignedGateReportAttestation.sign(
            GateReportAttestation(gateSchema: "pdf-editor.human-review-gate", gateReportSHA256: String(repeating: "bb", count: 32)),
            with: impostor
        )
        // Entitlement signed by the real issuer over the impostor's attestation.
        let entitlement = try SignedCohortEntitlement.sign(
            CohortEntitlementPayload(formClass: "IRS W-9", passDate: Date(), gateAttestation: attestation, envelopeID: "cohort-1"),
            with: issuer
        )
        let verdict = entitlement.verifyChain(with: issuer.verificationKey)
        #expect(verdict.entitlementSignatureValid)
        #expect(!verdict.gateAttestationSignatureValid)
        #expect(!verdict.chainValid)
    }

    @Test("JSON round trip preserves the chain verdict")
    func jsonRoundTrip() throws {
        let key = ReceiptSigningKey()
        let attestation = try SignedGateReportAttestation.sign(
            GateReportAttestation(gateSchema: "pdf-editor.human-review-gate", gateReportSHA256: String(repeating: "cc", count: 32)),
            with: key
        )
        let signed = try SignedCohortEntitlement.sign(
            CohortEntitlementPayload(formClass: "IRS W-9", passDate: Date(), gateAttestation: attestation, envelopeID: "cohort-1"),
            with: key
        )
        let decoded = try SignedCohortEntitlement.decode(try signed.exportAsJSON())
        #expect(decoded.verifyChain(with: key.verificationKey).chainValid)
    }

    // MARK: - Fixtures

    private static func makeReceipt(notes: String? = nil, signature: Data? = nil) -> ExecutionReceipt {
        ExecutionReceipt(
            actionName: "Export",
            sourceDigest: String(repeating: "aa", count: 32),
            targetDigest: String(repeating: "bb", count: 32),
            executionRoute: "native-incremental",
            dataBoundary: .onDeviceIsolated,
            notes: notes,
            signature: signature
        )
    }
}
