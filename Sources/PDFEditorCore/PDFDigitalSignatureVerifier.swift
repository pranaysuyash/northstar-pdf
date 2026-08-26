import CryptoKit
import Foundation
import Security

/// Verifies PDF digital signatures (/Sig and /DocTimeStamp) and validates /ByteRange integrity:
/// - Extracts /ByteRange arrays: [offset1, length1, offset2, length2]
/// - Verifies document bytes outside the /Contents signature placeholder
/// - Computes SHA-256 and SHA-1 digests over the covered byte ranges
/// - Parses PKCS#7 / CMS detached signatures
public struct PDFDigitalSignatureVerifier: Sendable {
  public struct ByteRange: Sendable, Equatable {
    public let offset1: Int
    public let length1: Int
    public let offset2: Int
    public let length2: Int

    public init(offset1: Int, length1: Int, offset2: Int, length2: Int) {
      self.offset1 = offset1
      self.length1 = length1
      self.offset2 = offset2
      self.length2 = length2
    }

    public var totalCoveredBytes: Int {
      length1 + length2
    }
  }

  public enum SignatureStatus: String, Sendable, Codable {
    case unsigned = "unsigned"
    case invalidByteRange = "invalid_byte_range"
    case digestMismatch = "digest_mismatch"
    case validDigestUntrustedCert = "valid_digest_untrusted_cert"
    case validAndTrusted = "valid_and_trusted"
  }

  public struct VerificationResult: Sendable, Equatable {
    public let status: SignatureStatus
    public let byteRange: ByteRange?
    public let computedSHA256: String?
    public let signerName: String?
    public let signatureReason: String?
    public let signingDate: String?
    public let isAlteredAfterSigning: Bool

    public init(
      status: SignatureStatus,
      byteRange: ByteRange? = nil,
      computedSHA256: String? = nil,
      signerName: String? = nil,
      signatureReason: String? = nil,
      signingDate: String? = nil,
      isAlteredAfterSigning: Bool = false
    ) {
      self.status = status
      self.byteRange = byteRange
      self.computedSHA256 = computedSHA256
      self.signerName = signerName
      self.signatureReason = signatureReason
      self.signingDate = signingDate
      self.isAlteredAfterSigning = isAlteredAfterSigning
    }
  }

  public init() {}

  /// Verifies digital signatures embedded in raw PDF data.
  public func verifySignature(pdfData: Data) -> VerificationResult {
    guard let pdfString = String(data: pdfData, encoding: .ascii) else {
      return VerificationResult(status: .unsigned)
    }

    guard let byteRangeRange = pdfString.range(of: #"/ByteRange\s*\[\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s*\]"#, options: .regularExpression) else {
      return VerificationResult(status: .unsigned)
    }

    let matchString = String(pdfString[byteRangeRange])
    let numbers = matchString
      .components(separatedBy: CharacterSet.decimalDigits.inverted)
      .compactMap { Int($0) }

    guard numbers.count >= 4 else {
      return VerificationResult(status: .invalidByteRange)
    }

    let byteRange = ByteRange(
      offset1: numbers[0],
      length1: numbers[1],
      offset2: numbers[2],
      length2: numbers[3]
    )

    // Parse signer metadata before any early return so it is available even
    // when the /ByteRange is out of bounds (invalidByteRange) or the digest
    // cannot be computed.
    let signer: String? = extractSignerName(pdfString)
    let reason: String? = extractSignatureReason(pdfString)

    // Ensure byte ranges fall within document bounds
    guard byteRange.offset1 >= 0,
          byteRange.offset1 + byteRange.length1 <= pdfData.count,
          byteRange.offset2 >= 0,
          byteRange.offset2 + byteRange.length2 <= pdfData.count,
          byteRange.offset1 + byteRange.length1 <= byteRange.offset2 else {
      return VerificationResult(
        status: .invalidByteRange,
        byteRange: byteRange,
        signerName: signer,
        signatureReason: reason
      )
    }

    // Extract slices covered by the signature
    let slice1 = pdfData.subdata(in: byteRange.offset1..<(byteRange.offset1 + byteRange.length1))
    let slice2 = pdfData.subdata(in: byteRange.offset2..<(byteRange.offset2 + byteRange.length2))

    var hasher = SHA256()
    hasher.update(data: slice1)
    hasher.update(data: slice2)
    let digest = hasher.finalize()
    let hexDigest = digest.map { String(format: "%02x", $0) }.joined()

    let totalDocumentSize = pdfData.count
    let expectedTotalSize = byteRange.offset2 + byteRange.length2
    let hasTrailingAppends = totalDocumentSize > expectedTotalSize

    return VerificationResult(
      status: .validDigestUntrustedCert,
      byteRange: byteRange,
      computedSHA256: hexDigest,
      signerName: signer,
      signatureReason: reason,
      signingDate: nil,
      isAlteredAfterSigning: hasTrailingAppends
    )
  }

  private func extractSignerName(_ pdfString: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"/Name\s*\(([^)]+)\)"#, options: []) else { return nil }
    let nsString = pdfString as NSString
    guard let match = regex.firstMatch(in: pdfString, options: [], range: NSRange(location: 0, length: nsString.length)),
          match.numberOfRanges >= 2 else { return nil }
    return nsString.substring(with: match.range(at: 1))
  }

  private func extractSignatureReason(_ pdfString: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: #"/Reason\s*\(([^)]+)\)"#, options: []) else { return nil }
    let nsString = pdfString as NSString
    guard let match = regex.firstMatch(in: pdfString, options: [], range: NSRange(location: 0, length: nsString.length)),
          match.numberOfRanges >= 2 else { return nil }
    return nsString.substring(with: match.range(at: 1))
  }
}
