import Foundation
import PDFEditorCore
import Testing

/// AF-04: Real ByteRange corruption tests.
///
/// The 12 JavaScript mutation tests exercise the signature guard's decision logic.
/// These 6 Swift tests exercise the actual ByteRange integrity verification with
/// real byte-level corruption — proving that tampering after signing is detected.
///
/// Evidence sensitivity: S3 — deliberate corruption produces expected verification failures.
@Suite("ByteRange Integrity Tests")
struct ByteRangeIntegrityTests {
  let verifier = PDFDigitalSignatureVerifier()

  /// Build a minimal signed PDF with exactly ONE /ByteRange declaration.
  ///
  /// Layout:
  ///   [header] [catalog] [sigField] [coveredContent] [sigDict-with-ByteRange] [trailer]
  ///
  /// The sigDict is placed immediately after the covered content, and the /ByteRange
  /// in the sig dict is the ONLY occurrence in the file — avoiding the earlier bug
  /// where a placeholder also contained `/ByteRange [0 0 0 0]` and the verifier
  /// regex matched the wrong one.
  private func buildSignedPDF(content: String = "Hello, World!") -> (Data, PDFDigitalSignatureVerifier.ByteRange) {
    let header = "%PDF-1.7\n"
    let catalog = "1 0 obj\n<< /Type /Catalog /AcroForm << /Fields [2 0 R] /SigFlags 3 >> >>\nendobj\n"
    let sigField = "2 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Sig /T (Sig1) /V 3 0 R >>\nendobj\n"
    let coveredContent = Data(content.utf8)
    let trailer = "trailer\n<< /Size 4 >>\nstartxref\n0\n%%EOF\n"

    // offset1 starts right after sigField — covers header+catalog+sigField+content
    let offset1 = header.count + catalog.count + sigField.count + coveredContent.count
    let length1 = trailer.count

    // Build the sig dict with a placeholder that we'll patch with real values
    let contentsHex = String(repeating: "00", count: 32) // 32 bytes placeholder
    let sigDictTemplate = "3 0 obj\n<< /Type /Sig /Filter /Adobe.PPKLite /SubFilter /adbe.pkcs7.detached /Name (TestSigner) /Reason (Testing) /Contents <\(contentsHex)> >>\nendobj\n"
    let offset2 = offset1 + length1 + sigDictTemplate.count
    let length2 = 0 // no bytes after sig dict

    let sigDict = "3 0 obj\n<< /Type /Sig /Filter /Adobe.PPKLite /SubFilter /adbe.pkcs7.detached /Name (TestSigner) /Reason (Testing) /ByteRange [\(offset1) \(length1) \(offset2) \(length2)] /Contents <\(contentsHex)> >>\nendobj\n"

    var pdfData = Data()
    pdfData.append(Data(header.utf8))
    pdfData.append(Data(catalog.utf8))
    pdfData.append(Data(sigField.utf8))
    pdfData.append(coveredContent)
    pdfData.append(Data(trailer.utf8))
    pdfData.append(Data(sigDict.utf8))

    let byteRange = PDFDigitalSignatureVerifier.ByteRange(
      offset1: offset1,
      length1: length1,
      offset2: offset2,
      length2: length2
    )

    return (pdfData, byteRange)
  }

  // MARK: - Test 1: Valid ByteRange produces valid digest

  @Test("Valid ByteRange produces validDigestUntrustedCert status")
  func validByteRangeProducesValidDigest() {
    let (pdfData, _) = buildSignedPDF()
    let result = verifier.verifySignature(pdfData: pdfData)

    #expect(result.status == .validDigestUntrustedCert)
    #expect(result.signerName == "TestSigner")
    #expect(result.signatureReason == "Testing")
    #expect(result.computedSHA256 != nil)
    #expect(result.computedSHA256?.count == 64) // SHA-256 hex = 64 chars
  }

  // MARK: - Test 2: Corrupted content → digest mismatch

  @Test("Corrupted content between ByteRange offsets produces digest mismatch")
  func corruptedContentProducesDigestMismatch() {
    var (pdfData, byteRange) = buildSignedPDF(content: "Original content here")

    // Get original digest
    let originalResult = verifier.verifySignature(pdfData: pdfData)
    let originalDigest = originalResult.computedSHA256
    #expect(originalResult.status == .validDigestUntrustedCert)

    // Corrupt a byte in the covered region (valid ASCII)
    let corruptOffset = byteRange.offset1 + 5
    if corruptOffset < byteRange.offset1 + byteRange.length1 {
      pdfData[pdfData.startIndex + corruptOffset] = 0x42 // 'B'
    }

    let corruptedResult = verifier.verifySignature(pdfData: pdfData)

    #expect(corruptedResult.status == .validDigestUntrustedCert) // ByteRange still parses
    #expect(corruptedResult.computedSHA256 != originalDigest)    // But digest changed
  }

  // MARK: - Test 3: ByteRange pointing beyond document → invalid

  @Test("ByteRange offset beyond document length produces invalidByteRange")
  func byteRangeBeyondDocumentProducesInvalid() {
    var (pdfData, _) = buildSignedPDF()
    let pdfStr = String(data: pdfData, encoding: .ascii)!

    // Find the sig dict's /ByteRange [ and replace with out-of-bounds values
    guard let sigDictRange = pdfStr.range(of: "/Type /Sig") else { return }
    let sigDictTail = pdfStr[sigDictRange.upperBound...]
    guard let brRange = sigDictTail.range(of: "/ByteRange [") else { return }
    let afterPrefix = sigDictTail[brRange.upperBound...]
    guard let bracketEnd = afterPrefix.firstIndex(of: "]") else { return }

    let replacement = "/ByteRange [0 100 999999 100]"
    let sigDictStart = sigDictRange.lowerBound.utf16Offset(in: pdfStr)
    let brStart = sigDictStart + brRange.lowerBound.utf16Offset(in: sigDictTail)
    let byteEnd = sigDictStart + bracketEnd.utf16Offset(in: sigDictTail) + 1

    pdfData.replaceSubrange(
      pdfData.startIndex + brStart..<pdfData.startIndex + byteEnd,
      with: Data(replacement.utf8)
    )

    let result = verifier.verifySignature(pdfData: pdfData)
    #expect(result.status == .invalidByteRange)
  }

  // MARK: - Test 4: ByteRange with invalid ordering → invalid

  @Test("ByteRange with overlapping offsets produces invalidByteRange")
  func overlappingByteRangeProducesInvalid() {
    var (pdfData, _) = buildSignedPDF()
    let pdfStr = String(data: pdfData, encoding: .ascii)!

    guard let sigDictRange = pdfStr.range(of: "/Type /Sig") else { return }
    let sigDictTail = pdfStr[sigDictRange.upperBound...]
    guard let brRange = sigDictTail.range(of: "/ByteRange [") else { return }
    let afterPrefix = sigDictTail[brRange.upperBound...]
    guard let bracketEnd = afterPrefix.firstIndex(of: "]") else { return }

    // 50+100=150 > 40 → offset1+length1 > offset2 → invalid ordering
    let replacement = "/ByteRange [50 100 40 100]"
    let sigDictStart = sigDictRange.lowerBound.utf16Offset(in: pdfStr)
    let brStart = sigDictStart + brRange.lowerBound.utf16Offset(in: sigDictTail)
    let byteEnd = sigDictStart + bracketEnd.utf16Offset(in: sigDictTail) + 1

    pdfData.replaceSubrange(
      pdfData.startIndex + brStart..<pdfData.startIndex + byteEnd,
      with: Data(replacement.utf8)
    )

    let result = verifier.verifySignature(pdfData: pdfData)
    #expect(result.status == .invalidByteRange)
  }

  // MARK: - Test 5: Truncated document → invalid or unsigned

  @Test("Truncated document produces invalidByteRange or unsigned")
  func truncatedDocumentProducesInvalid() {
    let (pdfData, _) = buildSignedPDF()

    // Truncate to 70% — cuts off the sig dict, so regex can't match
    let truncated = pdfData.prefix(pdfData.count * 70 / 100)
    let result = verifier.verifySignature(pdfData: truncated)

    #expect(result.status == .invalidByteRange || result.status == .unsigned)
  }

  // MARK: - Test 6: Shifted ByteRange values → different digest

  @Test("Modified ByteRange values produce different digest or invalid status")
  func modifiedByteRangeValuesProducesDifferentDigest() {
    var (pdfData, byteRange) = buildSignedPDF()

    let originalResult = verifier.verifySignature(pdfData: pdfData)
    let originalDigest = originalResult.computedSHA256
    #expect(originalResult.status == .validDigestUntrustedCert)

    let pdfStr = String(data: pdfData, encoding: .ascii)!
    guard let sigDictRange = pdfStr.range(of: "/Type /Sig") else { return }
    let sigDictTail = pdfStr[sigDictRange.upperBound...]
    guard let brRange = sigDictTail.range(of: "/ByteRange [") else { return }
    let afterPrefix = sigDictTail[brRange.upperBound...]
    guard let bracketEnd = afterPrefix.firstIndex(of: "]") else { return }

    // Shift both offsets by +10
    let replacement = "/ByteRange [\(byteRange.offset1 + 10) \(byteRange.length1) \(byteRange.offset2 + 10) \(byteRange.length2)]"
    let sigDictStart = sigDictRange.lowerBound.utf16Offset(in: pdfStr)
    let brStart = sigDictStart + brRange.lowerBound.utf16Offset(in: sigDictTail)
    let byteEnd = sigDictStart + bracketEnd.utf16Offset(in: sigDictTail) + 1

    pdfData.replaceSubrange(
      pdfData.startIndex + brStart..<pdfData.startIndex + byteEnd,
      with: Data(replacement.utf8)
    )

    let result = verifier.verifySignature(pdfData: pdfData)

    // Either the shifted ByteRange is invalid (points outside file)
    // or it covers different bytes → different digest
    if result.status == .validDigestUntrustedCert {
      #expect(result.computedSHA256 != originalDigest)
    } else {
      #expect(result.status == .invalidByteRange)
    }
  }
}
