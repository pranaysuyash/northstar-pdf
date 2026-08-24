import CryptoKit
import Foundation

public enum PDFTemplateStoreRecordKind: String, Codable, CaseIterable, Hashable, Sendable {
    case template
    case profile
    case learningEvent
    case revisionPromotion
}

public struct PDFEncryptedTemplateStoreRecord: Codable, Equatable, Hashable, Sendable {
    public let schemaVersion: Int
    public let recordKind: PDFTemplateStoreRecordKind
    public let recordID: String
    public let nonce: Data
    public let ciphertext: Data
    public let tag: Data
    public let createdAt: Date

    public init(
        schemaVersion: Int = 1,
        recordKind: PDFTemplateStoreRecordKind,
        recordID: String,
        nonce: Data,
        ciphertext: Data,
        tag: Data,
        createdAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.recordKind = recordKind
        self.recordID = recordID
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
        self.createdAt = createdAt
    }
}

public enum PDFTemplateStoreCodecError: Error, Equatable, Sendable {
    case emptyKey
    case unsupportedSchema(Int)
    case recordIdentityMismatch
    case invalidCiphertext
}

/// The core owns authenticated encryption and serialization. The native app
/// must supply a key protected by Keychain; the core never persists that key.
public enum PDFTemplateStoreCodec {
    public static func seal<Value: Encodable>(
        _ value: Value,
        kind: PDFTemplateStoreRecordKind,
        recordID: String,
        keyData: Data,
        createdAt: Date = Date()
    ) throws -> PDFEncryptedTemplateStoreRecord {
        guard !keyData.isEmpty else { throw PDFTemplateStoreCodecError.emptyKey }
        let plaintext = try JSONEncoder().encode(value)
        let key = SymmetricKey(data: keyData)
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        return PDFEncryptedTemplateStoreRecord(
            recordKind: kind,
            recordID: recordID,
            nonce: Data(sealedBox.nonce),
            ciphertext: sealedBox.ciphertext,
            tag: sealedBox.tag,
            createdAt: createdAt
        )
    }

    public static func open<Value: Decodable>(
        _ record: PDFEncryptedTemplateStoreRecord,
        as type: Value.Type,
        kind: PDFTemplateStoreRecordKind,
        recordID: String,
        keyData: Data
    ) throws -> Value {
        guard !keyData.isEmpty else { throw PDFTemplateStoreCodecError.emptyKey }
        guard record.schemaVersion == 1 else {
            throw PDFTemplateStoreCodecError.unsupportedSchema(record.schemaVersion)
        }
        guard record.recordKind == kind, record.recordID == recordID else {
            throw PDFTemplateStoreCodecError.recordIdentityMismatch
        }
        do {
            let nonce = try AES.GCM.Nonce(data: record.nonce)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: record.ciphertext,
                tag: record.tag
            )
            let plaintext = try AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData))
            return try JSONDecoder().decode(Value.self, from: plaintext)
        } catch {
            throw PDFTemplateStoreCodecError.invalidCiphertext
        }
    }
}
