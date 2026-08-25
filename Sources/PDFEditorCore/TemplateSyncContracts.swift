import CryptoKit
import Foundation

public struct PDFTemplateSyncEnvelope: Codable, Equatable, Sendable {
    public let contractName: String
    public let version: PDFContractVersion
    public let algorithm: String
    public let deviceID: String
    public let generation: Int
    public let templateID: UUID
    public let salt: Data
    public let nonce: Data
    public let ciphertext: Data
    public let tag: Data

    public init(
        deviceID: String,
        generation: Int,
        templateID: UUID,
        salt: Data,
        nonce: Data,
        ciphertext: Data,
        tag: Data
    ) {
        self.contractName = "pdf-editor.template-sync"
        self.version = .current
        self.algorithm = "AES-256-GCM-key-provided"
        self.deviceID = deviceID
        self.generation = generation
        self.templateID = templateID
        self.salt = salt
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.tag = tag
    }
}

public struct PDFTemplateSyncPayload: Codable, Equatable, Sendable {
    public let history: PDFTemplateRevisionSet
    public let learningEvents: [PDFTemplateLearningEvent]

    public init(history: PDFTemplateRevisionSet, learningEvents: [PDFTemplateLearningEvent] = []) throws {
        guard learningEvents.allSatisfy({ $0.templateID == history.templateID }) else {
            throw PDFTemplatePersistenceError.invalidRevisionHistory("sync event template identity mismatch")
        }
        self.history = history
        self.learningEvents = learningEvents
    }
}

public struct PDFTemplateSyncMergeResult: Equatable, Sendable {
    public let history: PDFTemplateRevisionSet?
    public let conflicts: [String]

    public init(history: PDFTemplateRevisionSet?, conflicts: [String]) {
        self.history = history
        self.conflicts = conflicts
    }
}

public enum PDFTemplateSyncCodec {
    public static func seal(
        payload: PDFTemplateSyncPayload,
        keyData: Data,
        deviceID: String,
        generation: Int
    ) throws -> PDFTemplateSyncEnvelope {
        guard keyData.count >= 32 else { throw PDFTemplatePersistenceError.emptyKey }
        let plaintext = try JSONEncoder().encode(payload)
        let sealed = try AES.GCM.seal(plaintext, using: SymmetricKey(data: keyData))
        return PDFTemplateSyncEnvelope(
            deviceID: deviceID,
            generation: generation,
            templateID: payload.history.templateID,
            salt: Data(),
            nonce: Data(sealed.nonce),
            ciphertext: sealed.ciphertext,
            tag: sealed.tag)
    }

    public static func open(
        _ envelope: PDFTemplateSyncEnvelope,
        keyData: Data
    ) throws -> PDFTemplateSyncPayload {
        guard envelope.contractName == "pdf-editor.template-sync",
              envelope.version.isReadableBy(),
              envelope.algorithm == "AES-256-GCM-key-provided",
              keyData.count >= 32
        else { throw PDFTemplatePersistenceError.decryptionFailed }
        do {
            let nonce = try AES.GCM.Nonce(data: envelope.nonce)
            let sealed = try AES.GCM.SealedBox(nonce: nonce, ciphertext: envelope.ciphertext, tag: envelope.tag)
            let payload = try JSONDecoder().decode(
                PDFTemplateSyncPayload.self,
                from: AES.GCM.open(sealed, using: SymmetricKey(data: keyData)))
            guard payload.history.templateID == envelope.templateID else {
                throw PDFTemplatePersistenceError.invalidRevisionHistory("sync template identity mismatch")
            }
            return payload
        } catch let error as PDFTemplatePersistenceError {
            throw error
        } catch {
            throw PDFTemplatePersistenceError.decryptionFailed
        }
    }

    public static func merge(
        local: PDFTemplateRevisionSet,
        incoming: PDFTemplateRevisionSet
    ) throws -> PDFTemplateSyncMergeResult {
        guard local.templateID == incoming.templateID else {
            return PDFTemplateSyncMergeResult(history: nil, conflicts: ["template identity mismatch"])
        }
        var revisions: [UUID: PDFTemplateContract] = [:]
        var conflicts: [String] = []
        for revision in local.revisions + incoming.revisions {
            if let existing = revisions[revision.payload.revisionID], existing != revision {
                conflicts.append("revision \(revision.payload.revisionID) has conflicting content")
            } else {
                revisions[revision.payload.revisionID] = revision
            }
        }
        let ids = Set(revisions.keys)
        for revision in revisions.values {
            if let parent = revision.payload.parentRevisionID, !ids.contains(parent) {
                conflicts.append("revision \(revision.payload.revisionID) is missing its parent")
            }
        }
        guard conflicts.isEmpty else { return PDFTemplateSyncMergeResult(history: nil, conflicts: conflicts) }
        var remaining = revisions
        var ordered: [PDFTemplateContract] = []
        while !remaining.isEmpty {
            let ready = remaining.values
                .filter { revision in
                    guard let parent = revision.payload.parentRevisionID else { return true }
                    return ordered.contains { $0.payload.revisionID == parent }
                }
                .sorted { $0.payload.revisionID.uuidString < $1.payload.revisionID.uuidString }
            guard !ready.isEmpty else {
                return PDFTemplateSyncMergeResult(history: nil, conflicts: ["revision parent graph is cyclic"])
            }
            for revision in ready {
                ordered.append(revision)
                remaining.removeValue(forKey: revision.payload.revisionID)
            }
        }
        return PDFTemplateSyncMergeResult(
            history: try PDFTemplateRevisionSet(templateID: local.templateID, revisions: ordered),
            conflicts: [])
    }
}
