import CryptoKit
import Foundation

/// Receipt and gate-attestation signing (round-3 presale branch; R3-05 chain).
///
/// This is the long-term first-principles substrate the product's evidence
/// story points at: gate evidence and execution receipts become a verifiable
/// signed chain — issuer key signs gate-report digests (`GateReportAttestation`),
/// cohort entitlements attest through that signature, and execution receipts
/// gain optional Ed25519 signatures so "cryptographically verified" becomes a
/// TRUE claim wherever it is used, rather than a removed slogan.
///
/// Doctrine alignment:
/// - Honest claims (§2/§13): a signature is present or absent, and verification
///   is a boolean fact. Nothing here renders an unsigned artifact as signed, or
///   a failed verification as passed. Claims follow the bytes.
/// - Zero egress: all verification is local. The private key is issuer-side
///   and never ships in the app; only `ReceiptVerificationKey` (public) is
///   embedded.
/// - Deterministic encoding: every signature is computed over canonical JSON
///   (sorted keys, ISO-8601 dates) so signing is reproducible and tampering is
///   detectable at byte granularity.
/// - Canonical path: this file EXTENDS the existing receipt/gate-report
///   machinery; it does not fork a parallel evidence store.
public enum CanonicalJSON {
    /// Deterministic byte encoding for any Codable value: sorted keys,
    /// ISO-8601 dates. The single canonical encoding for signing anywhere in
    /// the evidence chain.
    public static func encoding<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }
}

/// The public half of the issuer key pair. Safe to embed in the app bundle and
/// publish; verification is offline against this key alone.
public struct ReceiptVerificationKey: Codable, Equatable, Sendable {
    public let publicKeyRaw: Data

    public init(privateKey: Curve25519.Signing.PrivateKey) {
        self.publicKeyRaw = privateKey.publicKey.rawRepresentation
    }

    public init(rawRepresentation: Data) throws {
        self.publicKeyRaw = try Curve25519.Signing.PublicKey(rawRepresentation: rawRepresentation).rawRepresentation
    }

    public var publicKey: Curve25519.Signing.PublicKey {
        // Force-try is safe by construction: rawRepresentation round-trips a
        // key that was validated at init.
        try! Curve25519.Signing.PublicKey(rawRepresentation: publicKeyRaw)
    }

    public func verify<S: Sendable & Codable>(signature: Data, over value: S) -> Bool {
        guard let data = try? CanonicalJSON.encoding(value) else { return false }
        return publicKey.isValidSignature(signature, for: data)
    }
}

/// The issuer-side private half. Exists only in offline issuance tooling —
/// never persisted in, or shipped with, the app.
public struct ReceiptSigningKey: Sendable {
    public let privateKey: Curve25519.Signing.PrivateKey

    public init() {
        self.privateKey = Curve25519.Signing.PrivateKey()
    }

    public init(rawRepresentation: Data) throws {
        self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawRepresentation)
    }

    public var verificationKey: ReceiptVerificationKey {
        ReceiptVerificationKey(privateKey: privateKey)
    }

    public func sign<S: Sendable & Codable>(_ value: S) throws -> Data {
        try privateKey.signature(for: CanonicalJSON.encoding(value))
    }
}

// MARK: - Signed execution receipts

/// A receipt plus its Ed25519 signature over the receipt's canonical encoding.
/// `ExecutionReceipt.signature` records the fact of signing on the receipt
/// itself; this envelope is the verifiable form.
public struct SignedExecutionReceipt: Codable, Equatable, Sendable {
    public let receipt: ExecutionReceipt
    public let signature: Data

    public init(receipt: ExecutionReceipt, signature: Data) {
        self.receipt = receipt
        self.signature = signature
    }

    public func verify(with key: ReceiptVerificationKey) -> Bool {
        key.verify(signature: signature, over: receipt)
    }
}

// MARK: - Gate report attestation (the signed-receipts-chain link for gates)

/// An issuer-signed statement that a specific gate report artifact (identified
/// by its SHA-256) is the authoritative record for a gate at a point in time.
/// This is the chain link between raw gate evidence (JSON files under
/// `benchmark/results/`) and anything that must trust them offline.
public struct GateReportAttestation: Codable, Equatable, Sendable {
    public let attestationID: UUID
    /// The gate report's schema identifier (e.g. "pdf-editor.human-review-gate").
    public let gateSchema: String
    /// SHA-256 (hex) of the attested gate report file.
    public let gateReportSHA256: String
    public let attestedAt: Date
    public let notes: String?

    public init(attestationID: UUID = UUID(), gateSchema: String, gateReportSHA256: String, attestedAt: Date = Date(), notes: String? = nil) {
        self.attestationID = attestationID
        self.gateSchema = gateSchema
        self.gateReportSHA256 = gateReportSHA256
        self.attestedAt = attestedAt
        self.notes = notes
    }
}

public struct SignedGateReportAttestation: Codable, Equatable, Sendable {
    public let attestation: GateReportAttestation
    public let signature: Data

    public init(attestation: GateReportAttestation, signature: Data) {
        self.attestation = attestation
        self.signature = signature
    }

    public static func sign(_ attestation: GateReportAttestation, with key: ReceiptSigningKey) throws -> SignedGateReportAttestation {
        SignedGateReportAttestation(attestation: attestation, signature: try key.sign(attestation))
    }

    public func verify(with key: ReceiptVerificationKey) -> Bool {
        key.verify(signature: signature, over: attestation)
    }
}

// MARK: - File digest helper

public enum GateReportDigest {
    /// SHA-256 (hex) of a gate report file — the value attestations carry.
    public static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
