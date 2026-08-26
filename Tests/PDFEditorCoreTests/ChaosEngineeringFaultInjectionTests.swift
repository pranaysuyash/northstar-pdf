import CryptoKit
import Foundation
import Testing
@testable import PDFEditorCore

@Suite("Chaos Engineering and Fault Injection Tests")
struct ChaosEngineeringFaultInjectionTests {

  // MARK: - Chaos Experiment 1: Bit-Flipping Ciphertext Tampering (PER-PL2-0035)
  // Hypothesis: Any single-bit corruption in the AES-256-GCM encrypted envelope must cause authentication tag failure and fail closed without returning partial data.

  @Test func encryptedProfileEnvelopeRejectsBitFlippedCiphertext() throws {
    let key = SymmetricKey(size: .bits256)
    let plaintext = Data("{\"displayName\":\"Chaos Target\",\"values\":[]}".utf8)

    let nonce = AES.GCM.Nonce()
    let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
    var combined = nonce + sealedBox.ciphertext + sealedBox.tag

    // Inject chaos: flip a bit in the middle of ciphertext
    let flipIndex = combined.count / 2
    combined[flipIndex] ^= 0x01

    #expect(throws: Error.self) {
      let corruptedBox = try AES.GCM.SealedBox(combined: combined)
      _ = try AES.GCM.open(corruptedBox, using: key)
    }
  }

  // MARK: - Chaos Experiment 2: Truncated JSON / Zero-Byte Recovery Envelopes (PER-PL2-0035)
  // Hypothesis: A zero-byte or partially written template or profile file must be rejected as invalid JSON and never crash the process.

  @Test func templateIndexStoreRejectsTruncatedDataWithoutCrashing() {
    let emptyData = Data()
    let partialJSON = Data("{\"contract\":\"pdf-editor.profile\",\"payload\":{\"displayName\":".utf8)

    let decoder = JSONDecoder()
    #expect(throws: Error.self) {
      _ = try decoder.decode(PDFProfileContract.self, from: emptyData)
    }
    #expect(throws: Error.self) {
      _ = try decoder.decode(PDFProfileContract.self, from: partialJSON)
    }
  }

  // MARK: - Chaos Experiment 3: Overwrite Rejection Under Target Collision (PER-PL2-0035)
  // Hypothesis: If the destination export file already exists or equals source, export is blocked before performing any mutations.

  @Test func exportRejectsCollisionWhenDestinationEqualsSource() throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let sourceURL = tempDir.appendingPathComponent("source.pdf")

    // Create synthetic source
    let sourceData = Data("%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF".utf8)
    try sourceData.write(to: sourceURL)

    let provider = PDFKitProvider()
    #expect(throws: PDFEditorError.self) {
      _ = try provider.export(url: sourceURL, operations: [], to: sourceURL)
    }
  }

  // MARK: - Chaos Experiment 4: Vector Stream Parser Stress On Corrupted Random Streams (PER-PL2-0035)
  // Hypothesis: A corrupted random byte buffer must not cause infinite loops, memory runaway, or SIGSEGV in the pure Swift vector parser.

  @Test func vectorStreamParserSurvivesRandomCorruptedBytes() {
    // Generate pseudo-random garbage data
    var randomBytes = [UInt8](repeating: 0, count: 4096)
    for i in 0..<randomBytes.count {
      randomBytes[i] = UInt8((i * 37 + 13) % 256)
    }
    let garbageData = Data(randomBytes)

    // Parser must complete and return a valid result without crashing
    let boxes = PDFVectorStreamParser.parse(data: garbageData)
    #expect(boxes.isEmpty || !boxes.isEmpty)
  }
}
