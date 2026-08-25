import Foundation
import Testing

@testable import PDFEditorCore

struct EncryptedTemplatePersistenceTests {
    private let provider = PDFProviderDescriptor(id: "persistence-test", version: "1", platform: "test")
    private let templateID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let profileID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func template(
        revisionID: UUID,
        parentRevisionID: UUID? = nil,
        lifecycle: PDFTemplateLifecycle = .active
    ) -> PDFTemplateContract {
        let fingerprint = PDFTemplateFingerprint(
            layoutFingerprint: "hmac:persistence-layout",
            exactSourceDigests: [String(repeating: "a", count: 64)],
            pageSignatures: [])
        let payload = PDFTemplatePayload(
            templateID: templateID,
            revisionID: revisionID,
            parentRevisionID: parentRevisionID,
            displayName: "Private recurring form",
            lifecycle: lifecycle,
            fingerprint: fingerprint,
            mappings: [])
        return PDFTemplateContract(
            header: PDFTemplateHeader(templateDigest: fingerprint.layoutFingerprint, provider: provider),
            payload: payload)
    }

    private func profile(
        revisionID: UUID,
        parentRevisionID: UUID? = nil,
        revisionNumber: Int = 1
    ) -> PDFProfileContract {
        let payload = PDFProfilePayload(
            profileID: profileID,
            revisionID: revisionID,
            parentRevisionID: parentRevisionID,
            displayName: "Private profile",
            revisionNumber: revisionNumber,
            storageScope: .userSelectedVault,
            values: [PDFProfileValueRecord(
                semanticKey: "person.fullName",
                value: .text("Ada Lovelace Secret"))])
        return PDFProfileContract(
            header: PDFProfileHeader(
                profileID: profileID,
                revisionID: revisionID,
                provider: provider),
            payload: payload)
    }

    @Test func templateStoreEncryptsAppendOnlyHistoryAndRecoversPrimary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-editor-template-persistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = Data(repeating: 7, count: 32)
        let store = EncryptedPDFTemplateStore(directory: directory, keyData: key)
        let first = template(revisionID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
        let second = template(
            revisionID: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            parentRevisionID: first.payload.revisionID)

        let firstHistory = try store.append(revision: first)
        #expect(firstHistory.revisions == [first])
        let secondHistory = try store.append(revision: second)
        #expect(secondHistory.revisions == [first, second])
        #expect(secondHistory.activeRevision?.payload.revisionID == second.payload.revisionID)

        let primaryURL = directory.appendingPathComponent("\(templateID.uuidString).json")
        let primaryData = try Data(contentsOf: primaryURL)
        #expect(!String(decoding: primaryData, as: UTF8.self).contains("Private recurring form"))

        try Data("corrupted-primary".utf8).write(to: primaryURL, options: .atomic)
        let recovered = try store.loadResult(templateID: templateID)
        #expect(recovered?.state == .recoveredFromBackup)
        #expect(recovered?.value.revisions.count == 1)
        #expect(recovered?.value.revisions[0].payload.revisionID == first.payload.revisionID)

        let reopened = EncryptedPDFTemplateStore(directory: directory, keyData: key)
        #expect(try reopened.load(templateID: templateID)?.revisions.count == 1)

        #expect(throws: PDFTemplateCaptureError.missingRevisionParent) {
            try store.append(revision: template(
                revisionID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                parentRevisionID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!))
        }

        try store.delete(templateID: templateID)
        #expect(try store.load(templateID: templateID) == nil)
        #expect(try store.templateIDs().isEmpty)
    }

    @Test func profileVaultUsesSeparateEncryptedHistoryAndDeletionBoundary() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-editor-profile-vault-\(UUID().uuidString)", isDirectory: true)
        let templateDirectory = root.appendingPathComponent("Templates", isDirectory: true)
        let profileDirectory = root.appendingPathComponent("ProfileVault", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let profileKey = Data(repeating: 9, count: 32)
        let first = profile(revisionID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!)
        let second = profile(
            revisionID: UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
            parentRevisionID: first.payload.revisionID,
            revisionNumber: 2)
        let vault = EncryptedPDFProfileVault(directory: profileDirectory, keyData: profileKey)
        _ = try vault.append(revision: first)
        let history = try vault.append(revision: second)
        #expect(history.revisions.count == 2)
        #expect(history.latestRevision?.payload.revisionNumber == 2)

        let rawFiles = try FileManager.default.contentsOfDirectory(at: profileDirectory, includingPropertiesForKeys: nil)
        let rawText = rawFiles.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        #expect(!rawText.contains("Ada Lovelace Secret"))

        let wrongVault = EncryptedPDFProfileVault(directory: profileDirectory, keyData: Data(repeating: 8, count: 32))
        #expect(throws: PDFTemplatePersistenceError.corruptedPrimaryAndBackup) {
            _ = try wrongVault.load(profileID: profileID)
        }
        #expect(try vault.profileIDs() == [profileID])

        try vault.delete(profileID: profileID)
        #expect(try vault.load(profileID: profileID) == nil)
        #expect(try vault.profileIDs().isEmpty)

        let templateStore = EncryptedPDFTemplateStore(directory: templateDirectory, keyData: Data(repeating: 7, count: 32))
        _ = try templateStore.append(revision: template(
            revisionID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!))
        #expect(try vault.profileIDs().isEmpty)
        #expect(try templateStore.templateIDs() == [templateID])
    }

    @Test func recoveryEnvelopeHealthAndDeletionAuditRemainValueFree() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-editor-persistence-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = Data(repeating: 6, count: 32)
        let store = EncryptedPDFTemplateStore(directory: directory, keyData: key)
        _ = try store.append(revision: template(revisionID: UUID(uuidString: "26262626-2626-2626-2626-262626262626")!))

        let passphrase = "native-recovery-passphrase"
        let envelope = try store.exportRecoveryEnvelope(passphrase: passphrase)
        #expect(String(decoding: envelope, as: UTF8.self).contains(passphrase) == false)
        #expect(try store.health().recoveryEnvelopeAvailable)

        let reopened = EncryptedPDFTemplateStore(directory: directory, keyData: key)
        #expect(throws: PDFTemplatePersistenceError.decryptionFailed) {
            try reopened.recoverKey(from: envelope, passphrase: "wrong-recovery-passphrase")
        }
        try reopened.recoverKey(from: envelope, passphrase: passphrase)
        #expect(try reopened.load(templateID: templateID) != nil)

        try reopened.deleteAllRecords()
        #expect(try reopened.templateIDs().isEmpty)
        let events = try reopened.auditEvents()
        #expect(events.contains { $0.action == .storeDelete && $0.outcome == .succeeded })
        #expect(events.allSatisfy { $0.recordToken?.contains(templateID.uuidString) != true })
        #expect(events.allSatisfy { $0.reasonCode?.contains("Private recurring form") != true })
    }

    @Test func validatedChildRevisionTransferDiffAndLearningJournalRemainValueFree() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-editor-template-lifecycle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = EncryptedPDFTemplateStore(directory: directory, keyData: Data(repeating: 4, count: 32))
        let parent = template(revisionID: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!)
        let sourceDigest = String(repeating: "e", count: 64)
        let child = try PDFTemplateCapture.makeValidatedCompletionRevision(
            from: parent,
            sourceDigest: sourceDigest,
            sessionID: UUID(uuidString: "13131313-1313-1313-1313-131313131313"))

        #expect(child.payload.parentRevisionID == parent.payload.revisionID)
        #expect(child.payload.fingerprint.exactSourceDigests.contains(sourceDigest))
        let diff = try PDFTemplateRevisionDiff.make(from: parent, to: child)
        #expect(diff.exactSourceDigestsAdded == [sourceDigest])
        #expect(diff.mappingChanges.isEmpty)

        let history = try PDFTemplateRevisionSet(templateID: templateID, revisions: [parent, child])
        let envelope = PDFTemplateTransferEnvelope(history: history)
        try envelope.validate()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let roundTrip = try decoder.decode(PDFTemplateTransferEnvelope.self, from: encoder.encode(envelope))
        #expect(roundTrip.history == history)

        _ = try store.append(revision: parent)
        _ = try store.append(learningEvent: PDFTemplateLearningEvent(
            templateID: templateID,
            baseRevisionID: parent.payload.revisionID,
            sourceDigest: sourceDigest,
            kind: .completionValidated,
            completionSessionID: UUID(uuidString: "14141414-1414-1414-1414-141414141414")))
        #expect(try store.learningEvents(templateID: templateID).count == 1)
        let rawFiles = try FileManager.default.contentsOfDirectory(
            at: directory.appendingPathComponent("Learning", isDirectory: true),
            includingPropertiesForKeys: nil)
        #expect(rawFiles.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined().contains(sourceDigest) == false)
    }

    @Test func nativeClientEncryptedTemplateSyncRejectsWrongKeyAndConflicts() throws {
        let first = template(revisionID: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!)
        let second = try PDFTemplateCapture.makeValidatedCompletionRevision(
            from: first,
            sourceDigest: String(repeating: "b", count: 64))
        let history = try PDFTemplateRevisionSet(templateID: templateID, revisions: [first, second])
        let payload = try PDFTemplateSyncPayload(history: history)
        let key = Data(repeating: 3, count: 32)
        let envelope = try PDFTemplateSyncCodec.seal(
            payload: payload,
            keyData: key,
            deviceID: "native-device",
            generation: 2)
        #expect(try PDFTemplateSyncCodec.open(envelope, keyData: key) == payload)
        #expect(throws: PDFTemplatePersistenceError.decryptionFailed) {
            _ = try PDFTemplateSyncCodec.open(envelope, keyData: Data(repeating: 2, count: 32))
        }
        let merged = try PDFTemplateSyncCodec.merge(local: try PDFTemplateRevisionSet(templateID: templateID, revisions: [first]), incoming: history)
        #expect(merged.conflicts.isEmpty)
        #expect(merged.history == history)
        var conflicting = second
        conflicting = PDFTemplateContract(
            header: conflicting.header,
            payload: PDFTemplatePayload(
                templateID: conflicting.payload.templateID,
                revisionID: conflicting.payload.revisionID,
                parentRevisionID: conflicting.payload.parentRevisionID,
                displayName: "Conflicting revision",
                lifecycle: conflicting.payload.lifecycle,
                privacyMode: conflicting.payload.privacyMode,
                fingerprint: conflicting.payload.fingerprint,
                mappings: conflicting.payload.mappings,
                reviewPolicy: conflicting.payload.reviewPolicy))
        let conflictHistory = try PDFTemplateRevisionSet(templateID: templateID, revisions: [first, conflicting])
        let conflictResult = try PDFTemplateSyncCodec.merge(local: history, incoming: conflictHistory)
        #expect(conflictResult.history == nil)
        #expect(conflictResult.conflicts.count == 1)
    }

    @Test func encryptedVaultBackupsRoundTripAndCrossDeviceBundlesStaySeparated() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-editor-cross-device-(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sourceTemplateDirectory = root.appendingPathComponent("SourceTemplates", isDirectory: true)
        let destinationTemplateDirectory = root.appendingPathComponent("DestinationTemplates", isDirectory: true)
        let sourceProfileDirectory = root.appendingPathComponent("SourceProfiles", isDirectory: true)
        let destinationProfileDirectory = root.appendingPathComponent("DestinationProfiles", isDirectory: true)
        let key = Data(repeating: 0x2A, count: 32)
        let recoveryPassphrase = "cross-device-recovery-passphrase"

        let sourceTemplates = EncryptedPDFTemplateStore(directory: sourceTemplateDirectory, keyData: key)
        _ = try sourceTemplates.append(revision: template(
            revisionID: UUID(uuidString: "30303030-3030-3030-3030-303030303030")!))
        _ = try sourceTemplates.append(learningEvent: PDFTemplateLearningEvent(
            templateID: templateID,
            baseRevisionID: UUID(uuidString: "30303030-3030-3030-3030-303030303030")!,
            sourceDigest: String(repeating: "f", count: 64),
            kind: .completionValidated,
            completionSessionID: UUID(uuidString: "31313131-3131-3131-3131-313131313131")!))

        let encryptedTemplateBackup = try sourceTemplates.exportEncryptedBackup()
        let encryptedTemplateText = String(decoding: encryptedTemplateBackup, as: UTF8.self)
        #expect(!encryptedTemplateText.contains("Private recurring form"))
        #expect(!encryptedTemplateText.contains("completionValidated"))

        let recoveryData = try sourceTemplates.exportRecoveryEnvelope(passphrase: recoveryPassphrase)
        let backupBundle = try PDFLocalCrossDeviceRecoveryCodec.decode(encryptedTemplateBackup)
        let recoveryDecoder = JSONDecoder()
        recoveryDecoder.dateDecodingStrategy = .iso8601
        let recovery = try recoveryDecoder.decode(PDFLocalStoreRecoveryEnvelope.self, from: recoveryData)
        let crossDevice = PDFLocalCrossDeviceRecoveryBundle(
            storeKind: .template,
            backup: backupBundle,
            recovery: recovery)
        let crossDeviceData = try PDFLocalCrossDeviceBundleCodec.encode(crossDevice)
        let decoded = try PDFLocalCrossDeviceBundleCodec.decode(crossDeviceData)
        // Normalize both sides to whole-second precision because ISO8601
        // encoding truncates sub-second fractional seconds.
        #expect(PDFLocalCrossDeviceBundleCodec.normalized(decoded) == PDFLocalCrossDeviceBundleCodec.normalized(crossDevice))

        let destinationTemplates = EncryptedPDFTemplateStore(directory: destinationTemplateDirectory, keyData: key)
        try destinationTemplates.recoverKey(from: recoveryData, passphrase: recoveryPassphrase)
        try destinationTemplates.importEncryptedBackup(encryptedTemplateBackup, replacing: true)
        #expect(try destinationTemplates.load(templateID: templateID) != nil)
        #expect(try destinationTemplates.learningEvents(templateID: templateID).count == 1)

        let sourceProfiles = EncryptedPDFProfileVault(directory: sourceProfileDirectory, keyData: key)
        _ = try sourceProfiles.append(revision: profile(
            revisionID: UUID(uuidString: "32323232-3232-3232-3232-323232323232")!))
        let encryptedProfileBackup = try sourceProfiles.exportEncryptedBackup()
        let encryptedProfileText = String(decoding: encryptedProfileBackup, as: UTF8.self)
        #expect(!encryptedProfileText.contains("Ada Lovelace Secret"))

        let destinationProfiles = EncryptedPDFProfileVault(directory: destinationProfileDirectory, keyData: key)
        try destinationProfiles.importEncryptedBackup(encryptedProfileBackup, replacing: true)
        #expect(try destinationProfiles.load(profileID: profileID)?.latestRevision?.payload.values.first?.value == .text("Ada Lovelace Secret"))
        #expect(throws: PDFTemplatePersistenceError.encodingFailed("profile backup store kind mismatch")) {
            try destinationProfiles.importEncryptedBackup(encryptedTemplateBackup, replacing: true)
        }
    }
}
