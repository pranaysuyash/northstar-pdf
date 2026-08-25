import CryptoKit
import Foundation
import Security

/// A recovery result is intentionally different from a plain value. Callers
/// must be able to tell a healthy primary read from a read restored from the
/// last authenticated backup.
public enum PDFLocalStoreRecoveryState: String, Codable, CaseIterable, Hashable, Sendable {
    case primary
    case recoveredFromBackup
    case missing
}

public struct PDFLocalStoreLoadResult<Value: Sendable>: Sendable {
    public let value: Value
    public let state: PDFLocalStoreRecoveryState

    public init(value: Value, state: PDFLocalStoreRecoveryState) {
        self.value = value
        self.state = state
    }
}

public enum PDFTemplatePersistenceError: Error, LocalizedError, Equatable, Sendable {
    case emptyKey
    case invalidRevisionHistory(String)
    case directoryCreationFailed(String)
    case keychainFailed(String)
    case encodingFailed(String)
    case fileOperationFailed(String)
    case corruptedPrimaryAndBackup
    case decryptionFailed
    case invalidPassphrase(String)

    public var errorDescription: String? {
        switch self {
        case .emptyKey: "The local persistence encryption key is empty."
        case .invalidRevisionHistory(let message): "The revision history is invalid: \(message)"
        case .directoryCreationFailed(let message): "Could not create the local persistence directory: \(message)"
        case .keychainFailed(let message): "Could not access the local persistence key: \(message)"
        case .encodingFailed(let message): "Could not encode local persistence data: \(message)"
        case .fileOperationFailed(let message): "Local persistence file operation failed: \(message)"
        case .corruptedPrimaryAndBackup: "Both the primary and recovery copies are unavailable or unauthenticated."
        case .decryptionFailed: "The local persistence record could not be authenticated."
        case .invalidPassphrase(let message): "The local persistence passphrase is invalid: \(message)"
        }
    }
}

/// Profile revisions live in a separate encrypted vault from templates. The
/// profile payload is never copied into a template revision.
public struct PDFProfileRevisionSet: Codable, Equatable, Sendable {
    public let profileID: UUID
    public let revisions: [PDFProfileContract]

    public init(profileID: UUID, revisions: [PDFProfileContract]) throws {
        guard !revisions.isEmpty else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("at least one profile revision is required")
        }
        guard revisions.allSatisfy({ $0.payload.profileID == profileID && $0.header.profileID == profileID }) else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("profile identity differs across revisions")
        }
        let ids = revisions.map { $0.payload.revisionID }
        guard Set(ids).count == ids.count else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("profile revision IDs must be unique")
        }
        for (index, revision) in revisions.enumerated() {
            if let parent = revision.payload.parentRevisionID,
               !ids[..<index].contains(parent)
            {
                throw PDFTemplatePersistenceError.invalidRevisionHistory("profile revision parent must precede its child")
            }
        }
        self.profileID = profileID
        self.revisions = revisions
    }

    public func appending(_ revision: PDFProfileContract) throws -> PDFProfileRevisionSet {
        guard revision.payload.profileID == profileID, revision.header.profileID == profileID else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("profile identity mismatch")
        }
        guard !revisions.contains(where: { $0.payload.revisionID == revision.payload.revisionID }) else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("duplicate profile revision ID")
        }
        if let parent = revision.payload.parentRevisionID,
           !revisions.contains(where: { $0.payload.revisionID == parent })
        {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("profile revision parent is not present")
        }
        return try PDFProfileRevisionSet(profileID: profileID, revisions: revisions + [revision])
    }

    public var latestRevision: PDFProfileContract? { revisions.last }
}

private struct KeychainPersistenceKeyProvider {
    let service: String
    let account: String

    func keyData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, !data.isEmpty {
            return data
        }
        guard status == errSecItemNotFound else {
            throw PDFTemplatePersistenceError.keychainFailed("OSStatus \(status)")
        }

        let data = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw PDFTemplatePersistenceError.keychainFailed("OSStatus \(addStatus)")
        }
        if addStatus == errSecDuplicateItem {
            return try keyData()
        }
        return data
    }

    func existingKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, !data.isEmpty else {
            throw PDFTemplatePersistenceError.keychainFailed("OSStatus \(status)")
        }
        return data
    }

    func replaceKeyData(_ data: Data) throws {
        guard !data.isEmpty else { throw PDFTemplatePersistenceError.emptyKey }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
                throw PDFTemplatePersistenceError.keychainFailed("OSStatus \(addStatus)")
            }
        } else if status != errSecSuccess {
            throw PDFTemplatePersistenceError.keychainFailed("OSStatus \(status)")
        }
    }
}

private final class EncryptedRevisionFileStore<Value: Codable & Sendable>: @unchecked Sendable {
    private let directory: URL
    private let recordKind: PDFTemplateStoreRecordKind
    private let keyDataOverride: Data?
    private let keyProvider: KeychainPersistenceKeyProvider
    private let localStoreKind: PDFLocalStoreKind
    private let keyIdentifier: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager = FileManager.default
    private let lock = NSLock()

    init(
        directory: URL,
        recordKind: PDFTemplateStoreRecordKind,
        keyData: Data?,
        keyProvider: KeychainPersistenceKeyProvider,
        localStoreKind: PDFLocalStoreKind,
        keyIdentifier: String
    ) {
        self.directory = directory
        self.recordKind = recordKind
        self.keyDataOverride = keyData
        self.keyProvider = keyProvider
        self.localStoreKind = localStoreKind
        self.keyIdentifier = keyIdentifier
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ value: Value, id: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let key = try encryptionKey()
        let record: PDFEncryptedTemplateStoreRecord
        do {
            record = try PDFTemplateStoreCodec.seal(value, kind: recordKind, recordID: id, keyData: key)
        } catch let error as PDFTemplateStoreCodecError {
            throw map(error)
        } catch {
            throw PDFTemplatePersistenceError.encodingFailed(error.localizedDescription)
        }
        let data: Data
        do {
            data = try encoder.encode(record)
        } catch {
            throw PDFTemplatePersistenceError.encodingFailed(error.localizedDescription)
        }
        try write(data, id: id)
    }

    func load(_ id: String) throws -> PDFLocalStoreLoadResult<Value>? {
        lock.lock()
        defer { lock.unlock() }
        let primary = fileURL(id: id)
        let backup = backupURL(id: id)
        guard fileManager.fileExists(atPath: primary.path) || fileManager.fileExists(atPath: backup.path) else {
            return nil
        }
        do {
            return PDFLocalStoreLoadResult(value: try decode(Data(contentsOf: primary), id: id), state: .primary)
        } catch {
            guard fileManager.fileExists(atPath: backup.path) else {
                throw PDFTemplatePersistenceError.corruptedPrimaryAndBackup
            }
            do {
                let recovered = try decode(Data(contentsOf: backup), id: id)
                try? promoteBackup(id: id)
                return PDFLocalStoreLoadResult(value: recovered, state: .recoveredFromBackup)
            } catch {
                throw PDFTemplatePersistenceError.corruptedPrimaryAndBackup
            }
        }
    }

    func delete(_ id: String) throws {
        lock.lock()
        defer { lock.unlock() }
        for url in [fileURL(id: id), backupURL(id: id)] where fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw PDFTemplatePersistenceError.fileOperationFailed(error.localizedDescription)
            }
        }
    }

    /// Deletes all data records while leaving the separate audit record intact.
    /// The caller can therefore record the destructive action after the data
    /// deletion without recreating the deleted values or source identifiers.
    func deleteAllRecords(excluding excludedIDs: Set<String> = []) throws {
        for id in try ids() where !excludedIDs.contains(id) {
            try delete(id)
        }
    }

    func ids() throws -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        } catch {
            throw PDFTemplatePersistenceError.fileOperationFailed(error.localizedDescription)
        }
        return contents
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasSuffix(".backup.json") }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func recoveryEnvelope(passphrase: String) throws -> Data {
        let envelope = try PDFLocalStoreRecoveryCrypto.makeEnvelope(
            keyData: try encryptionKey(),
            passphrase: passphrase,
            storeKind: localStoreKind,
            keyIdentifier: keyIdentifier)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    func exportBackup() throws -> PDFLocalStoreBackupEnvelope {
        let records = try ids().map { id -> PDFEncryptedTemplateStoreRecord in
            let data = try Data(contentsOf: fileURL(id: id))
            do {
                return try decoder.decode(PDFEncryptedTemplateStoreRecord.self, from: data)
            } catch {
                throw PDFTemplatePersistenceError.encodingFailed("encrypted backup contains an unreadable record")
            }
        }
        let envelope = PDFLocalStoreBackupEnvelope(
            storeKind: localStoreKind,
            keyIdentifier: keyIdentifier,
            records: records)
        try envelope.validate()
        return envelope
    }

    func restoreBackup(_ envelope: PDFLocalStoreBackupEnvelope, replacing: Bool) throws {
        try envelope.validate()
        guard envelope.storeKind == localStoreKind,
              envelope.keyIdentifier == keyIdentifier
        else {
            throw PDFTemplatePersistenceError.keychainFailed("encrypted backup belongs to another local store")
        }
        if replacing {
            try deleteAllRecords()
        }
        for record in envelope.records {
            let data = try encoder.encode(record)
            try write(data, id: record.recordID)
        }
        _ = try decodeExistingRecordIfPresent()
    }

    func recoverKey(from data: Data, passphrase: String) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: PDFLocalStoreRecoveryEnvelope
        do {
            envelope = try decoder.decode(PDFLocalStoreRecoveryEnvelope.self, from: data)
            try envelope.validate()
        } catch let error as PDFTemplatePersistenceError {
            throw error
        } catch {
            throw PDFTemplatePersistenceError.encodingFailed("invalid passphrase recovery envelope")
        }
        guard envelope.storeKind == localStoreKind, envelope.keyIdentifier == keyIdentifier else {
            throw PDFTemplatePersistenceError.keychainFailed("recovery envelope belongs to another local store")
        }
        let recovered = try PDFLocalStoreRecoveryCrypto.openEnvelope(envelope, passphrase: passphrase)
        if let override = keyDataOverride {
            guard override == recovered else { throw PDFTemplatePersistenceError.keychainFailed("recovered key does not match the configured test key") }
        } else if let existing = try keyProvider.existingKeyData() {
            guard existing == recovered else { throw PDFTemplatePersistenceError.keychainFailed("a different Keychain key already protects this store") }
        } else {
            try keyProvider.replaceKeyData(recovered)
        }
        _ = try decodeExistingRecordIfPresent()
    }

    func health(auditEventCount: Int, recoveryEnvelopeAvailable: Bool) throws -> PDFLocalStoreHealth {
        let recordIDs = try ids()
        var recovered = false
        var backupAvailable = false
        let directoryExists = fileManager.fileExists(atPath: directory.path)
        if directoryExists {
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            backupAvailable = contents.contains { $0.lastPathComponent.hasSuffix(".backup.json") }
        }
        for id in recordIDs {
            if let result = try load(id) {
                recovered = recovered || result.state == .recoveredFromBackup
            }
        }
        return PDFLocalStoreHealth(
            storeKind: localStoreKind,
            state: recovered ? .recovered : recordIDs.isEmpty ? .uninitialized : .ready,
            primaryAvailable: !recordIDs.isEmpty,
            backupAvailable: backupAvailable,
            recordCount: recordIDs.count,
            auditEventCount: auditEventCount,
            recoveryEnvelopeAvailable: recoveryEnvelopeAvailable,
            encryptedBackupRecommended: !recordIDs.isEmpty && !recoveryEnvelopeAvailable,
            messageCode: recovered ? "primary-recovered-from-backup" : recordIDs.isEmpty ? "store-uninitialized" : "store-ready")
    }

    private func encryptionKey() throws -> Data {
        let data = try keyDataOverride ?? keyProvider.keyData()
        guard !data.isEmpty else { throw PDFTemplatePersistenceError.emptyKey }
        return data
    }

    private func decodeExistingRecordIfPresent() throws {
        guard let id = try ids().first, let result = try load(id) else { return }
        _ = result.value
    }

    private func decode(_ data: Data, id: String) throws -> Value {
        do {
            let record = try decoder.decode(PDFEncryptedTemplateStoreRecord.self, from: data)
            return try PDFTemplateStoreCodec.open(
                record,
                as: Value.self,
                kind: recordKind,
                recordID: id,
                keyData: try encryptionKey())
        } catch let error as PDFTemplateStoreCodecError {
            throw map(error)
        } catch {
            throw PDFTemplatePersistenceError.decryptionFailed
        }
    }

    private func write(_ data: Data, id: String) throws {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let primary = fileURL(id: id)
            let backup = backupURL(id: id)
            if fileManager.fileExists(atPath: primary.path) {
                if fileManager.fileExists(atPath: backup.path) { try fileManager.removeItem(at: backup) }
                try fileManager.copyItem(at: primary, to: backup)
            }
            let temporary = directory.appendingPathComponent(".\(id).\(UUID().uuidString).tmp")
            try data.write(to: temporary, options: .atomic)
            if fileManager.fileExists(atPath: primary.path) {
                _ = try fileManager.replaceItemAt(primary, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: primary)
            }
        } catch let error as PDFTemplatePersistenceError {
            throw error
        } catch {
            throw PDFTemplatePersistenceError.fileOperationFailed(error.localizedDescription)
        }
    }

    private func promoteBackup(id: String) throws {
        let primary = fileURL(id: id)
        let backup = backupURL(id: id)
        guard fileManager.fileExists(atPath: backup.path) else { return }
        if fileManager.fileExists(atPath: primary.path) { try fileManager.removeItem(at: primary) }
        try fileManager.copyItem(at: backup, to: primary)
    }

    private func fileURL(id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    private func backupURL(id: String) -> URL {
        directory.appendingPathComponent("\(id).backup.json")
    }

    private func map(_ error: PDFTemplateStoreCodecError) -> PDFTemplatePersistenceError {
        switch error {
        case .emptyKey: return .emptyKey
        case .invalidCiphertext: return .decryptionFailed
        case .unsupportedSchema(let version): return .encodingFailed("unsupported encrypted schema \(version)")
        case .recordIdentityMismatch: return .decryptionFailed
        }
    }
}

/// Encrypted, revision-preserving native template persistence.
public final class EncryptedPDFTemplateStore: @unchecked Sendable {
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PDFEditor", isDirectory: true)
            .appendingPathComponent("Templates", isDirectory: true)
    }

    private let store: EncryptedRevisionFileStore<PDFTemplateRevisionSet>
    private let learningStore: EncryptedRevisionFileStore<PDFTemplateLearningEventJournal>
    private let auditStore: EncryptedRevisionFileStore<PDFLocalStoreAuditJournal>

    public init(directory: URL = EncryptedPDFTemplateStore.defaultDirectory, keyData: Data? = nil) {
        self.store = EncryptedRevisionFileStore(
            directory: directory,
            recordKind: .template,
            keyData: keyData,
            keyProvider: KeychainPersistenceKeyProvider(
                service: "com.pdfeditor.template-store",
                account: "template-encryption-key-v1"),
            localStoreKind: .template,
            keyIdentifier: "template-encryption-key-v1")
        self.learningStore = EncryptedRevisionFileStore(
            directory: directory.appendingPathComponent("Learning", isDirectory: true),
            recordKind: .learningEvent,
            keyData: keyData,
            keyProvider: KeychainPersistenceKeyProvider(
                service: "com.pdfeditor.template-store",
                account: "template-encryption-key-v1"),
            localStoreKind: .template,
            keyIdentifier: "template-encryption-key-v1")
        self.auditStore = EncryptedRevisionFileStore(
            directory: directory.appendingPathComponent("Audit", isDirectory: true),
            recordKind: .audit,
            keyData: keyData,
            keyProvider: KeychainPersistenceKeyProvider(
                service: "com.pdfeditor.template-store",
                account: "template-encryption-key-v1"),
            localStoreKind: .template,
            keyIdentifier: "template-encryption-key-v1")
    }

    public func save(history: PDFTemplateRevisionSet) throws {
        try store.save(history, id: history.templateID.uuidString)
    }

    @discardableResult
    public func append(revision: PDFTemplateContract) throws -> PDFTemplateRevisionSet {
        let id = revision.payload.templateID.uuidString
        if let current = try store.load(id) {
            let history = try current.value.appending(revision)
            try store.save(history, id: id)
            return history
        }
        let history = try PDFTemplateRevisionSet(templateID: revision.payload.templateID, revisions: [revision])
        try store.save(history, id: id)
        return history
    }

    public func load(templateID: UUID) throws -> PDFTemplateRevisionSet? {
        try store.load(templateID.uuidString)?.value
    }

    public func loadResult(templateID: UUID) throws -> PDFLocalStoreLoadResult<PDFTemplateRevisionSet>? {
        try store.load(templateID.uuidString)
    }

    public func delete(templateID: UUID) throws {
        try store.delete(templateID.uuidString)
        try learningStore.delete(templateID.uuidString)
        try appendAudit(action: .recordDelete, outcome: .succeeded, recordID: templateID.uuidString, state: .ready, reasonCode: "template-deleted")
    }

    public func templateIDs() throws -> [UUID] {
        try store.ids().compactMap(UUID.init(uuidString:))
    }

    /// Forces a decrypting read of every local template. Native UI uses this
    /// as the explicit vault-unlock step; Keychain controls the OS-level lock.
    @discardableResult
    public func unlock() throws -> [UUID] {
        do {
            let ids = try templateIDs()
            for id in ids { _ = try load(templateID: id) }
            try appendAudit(action: .unlock, outcome: .succeeded, state: .ready, reasonCode: "keychain-authenticated")
            return ids
        } catch {
            try? appendAudit(action: .unlockFailure, outcome: .failed, state: .locked, reasonCode: "authentication-failed")
            throw error
        }
    }

    public func exportRecoveryEnvelope(passphrase: String) throws -> Data {
        let data = try store.recoveryEnvelope(passphrase: passphrase)
        try appendAudit(action: .recoveryExport, outcome: .succeeded, state: .ready, reasonCode: "passphrase-envelope-exported")
        return data
    }

    public func exportEncryptedBackup() throws -> Data {
        let envelope = try PDFLocalCrossDeviceRecoveryCodec.encode(
            backup: store.exportBackup(),
            learning: learningStore.exportBackup())
        try appendAudit(action: .backupExport, outcome: .succeeded, state: .ready, reasonCode: "encrypted-vault-backup-exported")
        return envelope
    }

    public func importEncryptedBackup(_ data: Data, replacing: Bool = false) throws {
        let parts = try PDFLocalCrossDeviceRecoveryCodec.decode(data)
        guard parts.backup.storeKind == .template,
              parts.learning?.storeKind == .template else {
            throw PDFTemplatePersistenceError.encodingFailed("template backup store kind mismatch")
        }
        try store.restoreBackup(parts.backup, replacing: replacing)
        if let learning = parts.learning {
            try learningStore.restoreBackup(learning, replacing: replacing)
        }
        try appendAudit(action: .backupImport, outcome: .succeeded, state: .ready, reasonCode: "encrypted-vault-backup-imported")
    }

    public func recoverKey(from data: Data, passphrase: String) throws {
        try store.recoverKey(from: data, passphrase: passphrase)
        try appendAudit(action: .recoveryImport, outcome: .succeeded, state: .recovered, reasonCode: "passphrase-envelope-imported")
    }

    public func health() throws -> PDFLocalStoreHealth {
        let events = try auditEvents()
        let result = try store.health(
            auditEventCount: events.count,
            recoveryEnvelopeAvailable: events.contains {
                $0.action == .recoveryExport && $0.outcome == .succeeded
            })
        try appendAudit(action: .healthCheck, outcome: .succeeded, state: result.state, reasonCode: result.messageCode)
        return result
    }

    /// Explicitly deletes all template, learning, and revision records. The
    /// value-free audit journal is retained and records the destructive action.
    public func deleteAllRecords() throws {
        try store.deleteAllRecords()
        try learningStore.deleteAllRecords()
        try appendAudit(action: .storeDelete, outcome: .succeeded, state: .deleted, reasonCode: "template-vault-records-deleted")
    }

    public func auditEvents() throws -> [PDFLocalStoreAuditEvent] {
        try auditStore.load("audit")?.value.events ?? []
    }

    public func exportHistory(templateID: UUID) throws -> Data {
        guard let history = try load(templateID: templateID) else {
            throw PDFTemplatePersistenceError.fileOperationFailed("template not found")
        }
        let envelope = PDFTemplateTransferEnvelope(history: history)
        try envelope.validate()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try appendAudit(action: .backupExport, outcome: .succeeded, state: .ready, reasonCode: "value-free-template-transfer-exported")
        return data
    }

    @discardableResult
    public func importHistory(_ data: Data, replacing: Bool = false) throws -> PDFTemplateRevisionSet {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope: PDFTemplateTransferEnvelope
        do {
            envelope = try decoder.decode(PDFTemplateTransferEnvelope.self, from: data)
            try envelope.validate()
        } catch let error as PDFTemplatePersistenceError {
            throw error
        } catch {
            throw PDFTemplatePersistenceError.encodingFailed("invalid template transfer envelope")
        }
        if !replacing, try load(templateID: envelope.history.templateID) != nil {
            throw PDFTemplatePersistenceError.fileOperationFailed("template already exists; use replacing=true to replace it")
        }
        try save(history: envelope.history)
        try appendAudit(action: .backupImport, outcome: .succeeded, recordID: envelope.history.templateID.uuidString, state: .ready, reasonCode: "value-free-template-transfer-imported")
        return envelope.history
    }

    @discardableResult
    public func append(learningEvent: PDFTemplateLearningEvent) throws -> PDFTemplateLearningEventJournal {
        let id = learningEvent.templateID.uuidString
        if let current = try learningStore.load(id) {
            let journal = try current.value.appending(learningEvent)
            try learningStore.save(journal, id: id)
            return journal
        }
        let journal = try PDFTemplateLearningEventJournal(templateID: learningEvent.templateID, events: [learningEvent])
        try learningStore.save(journal, id: id)
        return journal
    }

    public func learningEvents(templateID: UUID) throws -> [PDFTemplateLearningEvent] {
        try learningStore.load(templateID.uuidString)?.value.events ?? []
    }

    public func deleteLearningEvents(templateID: UUID) throws {
        try learningStore.delete(templateID.uuidString)
    }

    private func appendAudit(
        action: PDFLocalStoreAuditAction,
        outcome: PDFLocalStoreAuditOutcome,
        recordID: String? = nil,
        state: PDFLocalStoreHealthState,
        reasonCode: String?
    ) throws {
        let event = PDFLocalStoreAuditEvent(
            storeKind: .template,
            action: action,
            outcome: outcome,
            recordToken: recordID.map(PDFLocalStoreAuditIdentity.token),
            state: state,
            reasonCode: reasonCode)
        let journal = try auditStore.load("audit")?.value ?? PDFLocalStoreAuditJournal(storeKind: .template)
        try auditStore.save(try journal.appending(event), id: "audit")
    }
}

/// Encrypted profile vault with its own directory and Keychain account.
public final class EncryptedPDFProfileVault: @unchecked Sendable {
    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PDFEditor", isDirectory: true)
            .appendingPathComponent("ProfileVault", isDirectory: true)
    }

    private let store: EncryptedRevisionFileStore<PDFProfileRevisionSet>
    private let auditStore: EncryptedRevisionFileStore<PDFLocalStoreAuditJournal>

    public init(directory: URL = EncryptedPDFProfileVault.defaultDirectory, keyData: Data? = nil) {
        self.store = EncryptedRevisionFileStore(
            directory: directory,
            recordKind: .profile,
            keyData: keyData,
            keyProvider: KeychainPersistenceKeyProvider(
                service: "com.pdfeditor.profile-vault",
                account: "profile-vault-encryption-key-v1"),
            localStoreKind: .profile,
            keyIdentifier: "profile-vault-encryption-key-v1")
        self.auditStore = EncryptedRevisionFileStore(
            directory: directory.appendingPathComponent("Audit", isDirectory: true),
            recordKind: .audit,
            keyData: keyData,
            keyProvider: KeychainPersistenceKeyProvider(
                service: "com.pdfeditor.profile-vault",
                account: "profile-vault-encryption-key-v1"),
            localStoreKind: .profile,
            keyIdentifier: "profile-vault-encryption-key-v1")
    }

    public func save(history: PDFProfileRevisionSet) throws {
        try store.save(history, id: history.profileID.uuidString)
    }

    @discardableResult
    public func append(revision: PDFProfileContract) throws -> PDFProfileRevisionSet {
        let id = revision.payload.profileID.uuidString
        if let current = try store.load(id) {
            let history = try current.value.appending(revision)
            try store.save(history, id: id)
            return history
        }
        let history = try PDFProfileRevisionSet(profileID: revision.payload.profileID, revisions: [revision])
        try store.save(history, id: id)
        return history
    }

    public func load(profileID: UUID) throws -> PDFProfileRevisionSet? {
        try store.load(profileID.uuidString)?.value
    }

    public func loadResult(profileID: UUID) throws -> PDFLocalStoreLoadResult<PDFProfileRevisionSet>? {
        try store.load(profileID.uuidString)
    }

    public func delete(profileID: UUID) throws {
        try store.delete(profileID.uuidString)
        try appendAudit(action: .recordDelete, outcome: .succeeded, recordID: profileID.uuidString, state: .ready, reasonCode: "profile-deleted")
    }

    public func profileIDs() throws -> [UUID] {
        try store.ids().compactMap(UUID.init(uuidString:))
    }

    /// Explicitly authenticates all existing profile records through the
    /// Keychain-backed key before the native UI exposes their values.
    @discardableResult
    public func unlock() throws -> [UUID] {
        do {
            let ids = try profileIDs()
            for id in ids { _ = try load(profileID: id) }
            try appendAudit(action: .unlock, outcome: .succeeded, state: .ready, reasonCode: "keychain-authenticated")
            return ids
        } catch {
            try? appendAudit(action: .unlockFailure, outcome: .failed, state: .locked, reasonCode: "authentication-failed")
            throw error
        }
    }

    public func exportRecoveryEnvelope(passphrase: String) throws -> Data {
        let data = try store.recoveryEnvelope(passphrase: passphrase)
        try appendAudit(action: .recoveryExport, outcome: .succeeded, state: .ready, reasonCode: "passphrase-envelope-exported")
        return data
    }

    public func recoverKey(from data: Data, passphrase: String) throws {
        try store.recoverKey(from: data, passphrase: passphrase)
        try appendAudit(action: .recoveryImport, outcome: .succeeded, state: .recovered, reasonCode: "passphrase-envelope-imported")
    }

    public func exportEncryptedBackup() throws -> Data {
        let envelope = try PDFLocalCrossDeviceRecoveryCodec.encode(
            backup: store.exportBackup(),
            learning: nil)
        try appendAudit(action: .backupExport, outcome: .succeeded, state: .ready, reasonCode: "encrypted-vault-backup-exported")
        return envelope
    }

    public func importEncryptedBackup(_ data: Data, replacing: Bool = false) throws {
        let parts = try PDFLocalCrossDeviceRecoveryCodec.decode(data)
        guard parts.backup.storeKind == .profile, parts.learning == nil else {
            throw PDFTemplatePersistenceError.encodingFailed("profile backup store kind mismatch")
        }
        try store.restoreBackup(parts.backup, replacing: replacing)
        try appendAudit(action: .backupImport, outcome: .succeeded, state: .ready, reasonCode: "encrypted-vault-backup-imported")
    }

    public func health() throws -> PDFLocalStoreHealth {
        let events = try auditEvents()
        let result = try store.health(
            auditEventCount: events.count,
            recoveryEnvelopeAvailable: events.contains {
                $0.action == .recoveryExport && $0.outcome == .succeeded
            })
        try appendAudit(action: .healthCheck, outcome: .succeeded, state: result.state, reasonCode: result.messageCode)
        return result
    }

    /// Explicitly deletes all profile records while retaining the value-free
    /// deletion audit journal.
    public func deleteAllRecords() throws {
        try store.deleteAllRecords()
        try appendAudit(action: .storeDelete, outcome: .succeeded, state: .deleted, reasonCode: "profile-vault-records-deleted")
    }

    public func auditEvents() throws -> [PDFLocalStoreAuditEvent] {
        try auditStore.load("audit")?.value.events ?? []
    }

    /// Compatibility bridge for the native profile-fill UI. The UI keeps its
    /// existing value-oriented `UserProfile` projection, while every save is
    /// materialized as a new encrypted `PDFProfileContract` revision.
    public func save(profile: UserProfile) throws {
        let history = try load(profileID: profile.profileID)
        let parent = history?.latestRevision?.payload.revisionID
        let revisionNumber = (history?.latestRevision?.payload.revisionNumber ?? 0) + 1
        let revisionID = UUID()
        let payload = PDFProfilePayload(
            profileID: profile.profileID,
            revisionID: revisionID,
            parentRevisionID: parent,
            displayName: profile.displayName,
            revisionNumber: revisionNumber,
            storageScope: .deviceLocal,
            requiresUnlock: true,
            values: profile.values.map { value in
                PDFProfileValueRecord(
                    semanticKey: value.semanticKey,
                    value: .text(value.textValue))
            })
        let contract = PDFProfileContract(
            header: PDFProfileHeader(
                profileID: payload.profileID,
                revisionID: payload.revisionID,
                provider: PDFProviderDescriptor(
                    id: "pdf-editor-native-profile-vault",
                    version: "1",
                    platform: "macOS")),
            payload: payload)
        _ = try append(revision: contract)
    }

    public func loadUserProfile(profileID: UUID) throws -> UserProfile? {
        guard let contract = try load(profileID: profileID)?.latestRevision else { return nil }
        let values = contract.payload.values.map { record in
            let text: String
            switch record.value {
            case .text(let value), .choice(let value), .assetReference(let value): text = value
            case .boolean(let value): text = value ? "true" : "false"
            }
            return UserProfileValue(
                semanticKey: record.semanticKey,
                textValue: text,
                label: record.semanticKey,
                category: .general)
        }
        return UserProfile(
            profileID: contract.payload.profileID,
            displayName: contract.payload.displayName,
            values: values,
            createdAt: contract.header.generatedAt,
            lastModifiedAt: contract.header.generatedAt)
    }

    public func listUserProfiles() throws -> [UserProfile] {
        try profileIDs().compactMap { try loadUserProfile(profileID: $0) }
            .sorted { $0.lastModifiedAt > $1.lastModifiedAt }
    }

    private func appendAudit(
        action: PDFLocalStoreAuditAction,
        outcome: PDFLocalStoreAuditOutcome,
        recordID: String? = nil,
        state: PDFLocalStoreHealthState,
        reasonCode: String?
    ) throws {
        let event = PDFLocalStoreAuditEvent(
            storeKind: .profile,
            action: action,
            outcome: outcome,
            recordToken: recordID.map(PDFLocalStoreAuditIdentity.token),
            state: state,
            reasonCode: reasonCode)
        let journal = try auditStore.load("audit")?.value ?? PDFLocalStoreAuditJournal(storeKind: .profile)
        try auditStore.save(try journal.appending(event), id: "audit")
    }
}
