import CryptoKit
import Foundation

/// Offline cohort entitlement (round-3 presale branch, audit §7.2 child 4;
/// R3-05): a compact, offline-verifiable credential that unlocks a certified
/// form class. This is the aspirational long-term design, implemented: the
/// entitlement sits at the end of a REAL signed evidence chain —
///
///   gate report bytes (SHA-256)
///     └─ signed by issuer  →  SignedGateReportAttestation
///           └─ embedded in  →  CohortEntitlementPayload
///                 └─ signed by issuer  →  SignedCohortEntitlement
///
/// Any third party can verify the whole chain offline against the public key
/// embedded in the app and the published gate report file.
///
/// Doctrine alignment:
/// - Honest claims (§2/§13): every link's verification is an observed boolean.
///   `verifyChain` reports per-link facts; no link may be skipped or assumed.
/// - Zero egress: verification is local-only. The issuer private key exists
///   only in offline issuance tooling (see `ReceiptSigning.swift`).
/// - Deterministic encoding: signatures cover canonical JSON (sorted keys,
///   ISO-8601 dates) so tampering is detectable at byte granularity.
public struct CohortEntitlementPayload: Codable, Equatable, Sendable {
    public let entitlementID: UUID
    public let formClass: String
    public let passDate: Date
    /// The signed attestation of the gate report that certifies this form
    /// class. Embedded whole so the entitlement is self-contained offline.
    public let gateAttestation: SignedGateReportAttestation
    /// Binds the entitlement to the operating-envelope version that was on
    /// sale when the class passed (envelope claims must stay version-bound).
    public let envelopeID: String

    public init(entitlementID: UUID = UUID(), formClass: String, passDate: Date, gateAttestation: SignedGateReportAttestation, envelopeID: String) {
        self.entitlementID = entitlementID
        self.formClass = formClass
        self.passDate = passDate
        self.gateAttestation = gateAttestation
        self.envelopeID = envelopeID
    }

    public func canonicalEncoding() throws -> Data {
        try CanonicalJSON.encoding(self)
    }
}

public struct SignedCohortEntitlement: Codable, Equatable, Sendable {
    public let payload: CohortEntitlementPayload
    public let signature: Data

    public init(payload: CohortEntitlementPayload, signature: Data) {
        self.payload = payload
        self.signature = signature
    }

    // MARK: - Issuance (offline; private key never ships in the app)

    public static func sign(_ payload: CohortEntitlementPayload, with key: ReceiptSigningKey) throws -> SignedCohortEntitlement {
        SignedCohortEntitlement(payload: payload, signature: try key.sign(payload))
    }

    // MARK: - Verification (local-only, per-link facts)

    public enum ChainLink: String, Sendable {
        case entitlementSignature
        case gateAttestationSignature
    }

    /// Per-link verification verdicts. Both links MUST be true for the chain
    /// to authorize anything; callers surface the failing link rather than a
    /// single opaque boolean, so a broken chain is diagnosable offline.
    public struct ChainVerdict: Equatable, Sendable {
        public let entitlementSignatureValid: Bool
        public let gateAttestationSignatureValid: Bool

        public var chainValid: Bool { entitlementSignatureValid && gateAttestationSignatureValid }
    }

    public func verifyChain(with key: ReceiptVerificationKey) -> ChainVerdict {
        ChainVerdict(
            entitlementSignatureValid: key.verify(signature: signature, over: payload),
            gateAttestationSignatureValid: payload.gateAttestation.verify(with: key)
        )
    }

    // MARK: - Transport encoding

    public func exportAsJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> SignedCohortEntitlement {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SignedCohortEntitlement.self, from: data)
    }
}
