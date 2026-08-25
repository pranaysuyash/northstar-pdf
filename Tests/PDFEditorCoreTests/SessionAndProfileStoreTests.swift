import Foundation
import PDFKit
import Testing

@testable import PDFEditorCore

struct SessionAndProfileStoreTests {
  // MARK: - Session Store Tests

  @Test func sessionRecordRoundTripsThroughCodable() throws {
    let source = DocumentSource(
      fileName: "form.pdf", byteCount: 1024,
      sha256: String(repeating: "a", count: 64))
    let operation = EditOperation(
      pageIndex: 0,
      targetID: "name",
      kind: .nativeFieldValue,
      value: "Ada Lovelace",
      bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
      sourceDigest: source.sha256,
      coordinate: PDFPageRegion(
        pageIndex: 0, rect: PDFRect(x: 72, y: 600, width: 200, height: 20)),
      payload: .text("Ada Lovelace")
    )
    let candidateID = UUID()
    let record = PDFSessionRecord(
      sourceDigest: source.sha256,
      sourceFileName: source.fileName,
      pageCount: 2,
      operationCount: 1,
      reviewCount: 0,
      operations: [operation],
      reviews: [],
      candidateStatuses: [candidateID: .confirmed],
      selectedPageIndex: 0,
      completionProgress: CompletionProgress(
        totalCandidates: 5, confirmedCount: 2, rejectedCount: 1, remainingCount: 2)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(record)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(PDFSessionRecord.self, from: data)

    #expect(decoded.sourceDigest == source.sha256)
    #expect(decoded.sourceFileName == "form.pdf")
    #expect(decoded.pageCount == 2)
    #expect(decoded.operationCount == 1)
    #expect(decoded.operations.count == 1)
    #expect(decoded.operations[0].value == "Ada Lovelace")
    #expect(decoded.candidateStatuses[candidateID] == .confirmed)
    #expect(decoded.completionProgress.percentComplete == 40.0)
    #expect(decoded.completionProgress.remainingCount == 2)
  }

  @Test func fileSessionStorePersistsAndLoads() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-session-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = FileSessionStore(directory: directory)
    let sourceDigest = String(repeating: "b", count: 64)

    // Empty initially
    #expect(store.count == 0)
    #expect(try store.load(sourceDigest: sourceDigest) == nil)

    // Save
    let record = PDFSessionRecord(
      sourceDigest: sourceDigest,
      sourceFileName: "test.pdf",
      pageCount: 3,
      operationCount: 2,
      reviewCount: 1,
      operations: [],
      reviews: [],
      candidateStatuses: [:],
      selectedPageIndex: 1,
      completionProgress: CompletionProgress(
        totalCandidates: 10, confirmedCount: 5, rejectedCount: 1, remainingCount: 4)
    )
    try store.save(record: record)
    #expect(store.count == 1)

    // Load
    let loaded = try store.load(sourceDigest: sourceDigest)
    #expect(loaded != nil)
    #expect(loaded?.sourceDigest == sourceDigest)
    #expect(loaded?.sourceFileName == "test.pdf")
    #expect(loaded?.pageCount == 3)
    #expect(loaded?.selectedPageIndex == 1)
    #expect(loaded?.completionProgress.confirmedCount == 5)

    // List
    let all = try store.listAll()
    #expect(all.count == 1)
    #expect(all[0].sourceDigest == sourceDigest)

    // Overwrite
    var updated = record
    updated = PDFSessionRecord(
      sourceDigest: sourceDigest,
      sourceFileName: "test-v2.pdf",
      pageCount: 3,
      operationCount: 5,
      reviewCount: 2,
      operations: [],
      reviews: [],
      candidateStatuses: [:],
      selectedPageIndex: 0,
      completionProgress: CompletionProgress(
        totalCandidates: 10, confirmedCount: 8, rejectedCount: 0, remainingCount: 2)
    )
    try store.save(record: updated)
    #expect(store.count == 1)
    let reloaded = try store.load(sourceDigest: sourceDigest)
    #expect(reloaded?.operationCount == 5)
    #expect(reloaded?.sourceFileName == "test-v2.pdf")

    // Delete
    try store.delete(sourceDigest: sourceDigest)
    #expect(store.count == 0)
    #expect(try store.load(sourceDigest: sourceDigest) == nil)
  }

  @Test func fileSessionStoreDeleteExpired() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-session-expiry-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = FileSessionStore(directory: directory)
    let oldRecord = PDFSessionRecord(
      sourceDigest: String(repeating: "c", count: 64),
      sourceFileName: "old.pdf",
      createdAt: Date(timeIntervalSince1970: 1_000_000),
      lastModifiedAt: Date(timeIntervalSince1970: 1_000_000),
      pageCount: 1,
      operationCount: 0,
      reviewCount: 0,
      operations: [],
      reviews: [],
      candidateStatuses: [:],
      selectedPageIndex: 0,
      completionProgress: .empty
    )
    let recentRecord = PDFSessionRecord(
      sourceDigest: String(repeating: "d", count: 64),
      sourceFileName: "recent.pdf",
      createdAt: Date(),
      lastModifiedAt: Date(),
      pageCount: 1,
      operationCount: 0,
      reviewCount: 0,
      operations: [],
      reviews: [],
      candidateStatuses: [:],
      selectedPageIndex: 0,
      completionProgress: .empty
    )
    try store.save(record: oldRecord)
    try store.save(record: recentRecord)
    #expect(store.count == 2)

    try store.deleteExpired(before: Date(timeIntervalSince1970: 2_000_000))
    #expect(store.count == 1)
    let remaining = try store.listAll()
    #expect(remaining[0].sourceFileName == "recent.pdf")
  }

  @Test func sessionRecordFromEditingStateCapturesProgress() {
    let source = DocumentSource(
      fileName: "test.pdf", byteCount: 512,
      sha256: String(repeating: "e", count: 64))
    let candidates = [
      RegionCandidate(
        pageIndex: 0, bounds: PDFRect(x: 10, y: 10, width: 100, height: 20),
        kind: .textAnchored, status: .confirmed, score: 0.9, evidence: ["test"]),
      RegionCandidate(
        pageIndex: 0, bounds: PDFRect(x: 10, y: 50, width: 100, height: 20),
        kind: .vectorRegion, status: .rejected, score: 0.7, evidence: ["test"]),
      RegionCandidate(
        pageIndex: 0, bounds: PDFRect(x: 10, y: 90, width: 100, height: 20),
        kind: .textAnchored, score: 0.8, evidence: ["test"]),
    ]
    let record = PDFSessionRecord.from(
      source: source,
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 100, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [],
      candidates: candidates,
      operations: [],
      reviews: [],
      selectedPageIndex: 0
    )

    #expect(record.completionProgress.totalCandidates == 3)
    #expect(record.completionProgress.confirmedCount == 1)
    #expect(record.completionProgress.rejectedCount == 1)
    #expect(record.completionProgress.remainingCount == 1)
    #expect(record.candidateStatuses.count == 2)
    #expect(record.isCompatibleWith(sourceDigest: source.sha256))
    #expect(!record.isCompatibleWith(sourceDigest: "wrong"))
  }

  // MARK: - Profile Store Tests

  @Test func userProfileRoundTripsThroughCodable() throws {
    let profile = UserProfile(
      displayName: "Personal",
      values: [
        UserProfileValue(semanticKey: "person.fullName", textValue: "Ada Lovelace"),
        UserProfileValue(semanticKey: "person.email", textValue: "ada@example.com"),
        UserProfileValue(semanticKey: "person.phone", textValue: "555-0100"),
      ]
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(profile)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(UserProfile.self, from: data)

    #expect(decoded.displayName == "Personal")
    #expect(decoded.values.count == 3)
    #expect(decoded.value(for: "person.fullName") == "Ada Lovelace")
    #expect(decoded.value(for: "person.email") == "ada@example.com")
    #expect(decoded.value(for: "person.phone") == "555-0100")
    #expect(decoded.semanticKeys.contains("person.fullName"))
  }

  @Test func userProfileSetValueAndUpdate() {
    var profile = UserProfile(displayName: "Test")
    #expect(profile.values.isEmpty)

    profile.setValue("John", for: "person.firstName")
    #expect(profile.values.count == 1)
    #expect(profile.value(for: "person.firstName") == "John")

    // Update existing
    profile.setValue("Jane", for: "person.firstName")
    #expect(profile.values.count == 1)
    #expect(profile.value(for: "person.firstName") == "Jane")

    // Add another
    profile.setValue("jane@test.com", for: "person.email")
    #expect(profile.values.count == 2)

    // Remove
    profile.removeValue(for: "person.firstName")
    #expect(profile.values.count == 1)
    #expect(profile.value(for: "person.firstName") == nil)
  }

  @Test func userProfileFromDictionary() {
    let profile = UserProfile.from(
      displayName: "From Dict",
      values: [
        "person.fullName": "Ada Lovelace",
        "person.email": "ada@example.com",
      ]
    )

    #expect(profile.displayName == "From Dict")
    #expect(profile.values.count == 2)
    #expect(profile.value(for: "person.fullName") == "Ada Lovelace")
    // Values should be sorted by semantic key
    #expect(profile.values[0].semanticKey == "person.email")
    #expect(profile.values[1].semanticKey == "person.fullName")
  }

  @Test func userProfileStandardPrePopulatesKeys() {
    let profile = UserProfile.standard(displayName: "Standard")
    #expect(profile.values.count == StandardSemanticKey.allCases.count)
    #expect(profile.value(for: "person.firstName") == "")
    #expect(profile.value(for: "person.ssn") == "")
    // All standard keys should be present
    for key in StandardSemanticKey.allCases {
      #expect(profile.values.contains { $0.semanticKey == key.rawValue })
    }
  }

  @Test func userProfileMatchesToTemplateMappings() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("Ada Lovelace", for: "person.fullName")
    profile.setValue("ada@example.com", for: "person.email")

    let mapping1 = PDFTemplateMapping(
      semanticKey: "person.fullName",
      target: PDFTemplateMappingTarget(
        kind: .nativeField, pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 10, width: 100, height: 20))),
      suggestedFieldType: .text,
      status: .confirmed
    )
    let mapping2 = PDFTemplateMapping(
      semanticKey: "person.phone",
      target: PDFTemplateMappingTarget(
        kind: .nativeField, pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 50, width: 100, height: 20))),
      suggestedFieldType: .text,
      status: .confirmed
    )
    let rejectedMapping = PDFTemplateMapping(
      semanticKey: "person.email",
      target: PDFTemplateMappingTarget(
        kind: .nativeField, pageIndex: 0,
        region: PDFPageRegion(pageIndex: 0, rect: PDFRect(x: 10, y: 90, width: 100, height: 20))),
      suggestedFieldType: .text,
      status: .rejected
    )

    let matches = profile.matchToMappings([mapping1, mapping2, rejectedMapping])
    #expect(matches.count == 1)  // Only fullName matches; phone has no value, email is rejected
    #expect(matches[mapping1.id] == "Ada Lovelace")
  }

  @Test func encryptedProfileStorePersistsAndLoads() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-profile-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = EncryptedProfileStore(directory: directory)
    #expect(store.count == 0)

    let profile = UserProfile(
      displayName: "Work",
      values: [
        UserProfileValue(semanticKey: "person.fullName", textValue: "Jane Smith"),
        UserProfileValue(semanticKey: "person.employer", textValue: "Acme Corp"),
      ]
    )
    try store.save(profile: profile)
    #expect(store.count == 1)

    let loaded = try store.load(profileID: profile.profileID)
    #expect(loaded != nil)
    #expect(loaded?.displayName == "Work")
    #expect(loaded?.value(for: "person.fullName") == "Jane Smith")
    #expect(loaded?.value(for: "person.employer") == "Acme Corp")

    let all = try store.listAll()
    #expect(all.count == 1)

    try store.delete(profileID: profile.profileID)
    #expect(store.count == 0)
  }

  @Test func profileValueCategoryClassifiesStandardKeys() {
    #expect(StandardSemanticKey.firstName.category == .personal)
    #expect(StandardSemanticKey.email.category == .contact)
    #expect(StandardSemanticKey.addressStreet.category == .address)
    #expect(StandardSemanticKey.ssn.category == .identification)
    #expect(StandardSemanticKey.employer.category == .general)
  }

  @Test func vCardImportExtractsBasicFields() {
    var profile = UserProfile(displayName: "Imported")
    let vCard = """
      BEGIN:VCARD
      VERSION:3.0
      FN:John Doe
      N:Doe;John;;;
      TEL;TYPE=WORK:555-0100
      EMAIL;TYPE=WORK:john@example.com
      ADR;TYPE=WORK:;;123 Main St;Springfield;IL;62701;US
      ORG:Acme Corp
      TITLE:Engineer
      END:VCARD
      """

    profile.importFromVCard(vCard)

    #expect(profile.value(for: StandardSemanticKey.fullName.rawValue) == "John Doe")
    #expect(profile.value(for: StandardSemanticKey.firstName.rawValue) == "John")
    #expect(profile.value(for: StandardSemanticKey.lastName.rawValue) == "Doe")
    #expect(profile.value(for: StandardSemanticKey.phone.rawValue) == "555-0100")
    #expect(profile.value(for: StandardSemanticKey.email.rawValue) == "john@example.com")
    #expect(profile.value(for: StandardSemanticKey.addressStreet.rawValue) == "123 Main St")
    #expect(profile.value(for: StandardSemanticKey.addressCity.rawValue) == "Springfield")
    #expect(profile.value(for: StandardSemanticKey.addressState.rawValue) == "IL")
    #expect(profile.value(for: StandardSemanticKey.addressZip.rawValue) == "62701")
    #expect(profile.value(for: StandardSemanticKey.addressCountry.rawValue) == "US")
    #expect(profile.value(for: StandardSemanticKey.employer.rawValue) == "Acme Corp")
    #expect(profile.value(for: StandardSemanticKey.jobTitle.rawValue) == "Engineer")
  }

  // MARK: - Document Diff Tests

  @Test func documentDiffPreservedStatusWhenNoChanges() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "a", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [],
      candidates: [],
      warnings: []
    )
    let diff = DocumentDiffBuilder.build(
      source: source, output: source, operations: [])

    #expect(diff.summary.overallStatus == .preserved)
    #expect(diff.summary.unexpectedChanges == 0)
    #expect(diff.pages.count == 1)
    #expect(!diff.pages[0].hasChanges)
  }

  @Test func documentDiffDetectsNativeFieldChanges() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "b", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "Old Value", choices: [])
      ],
      candidates: [],
      warnings: []
    )
    var output = source
    output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "c", count: 64)),
      pages: source.pages,
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "New Value", choices: [])
      ],
      candidates: [],
      warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [])

    #expect(diff.pages[0].regions.contains { $0.kind == .nativeFieldChanged })
    #expect(diff.summary.overallStatus != .preserved)
  }

  @Test func documentDiffIncompleteWhenPageCountDiffers() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "d", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [],
      candidates: [],
      warnings: []
    )
    let output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "e", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true),
        PageSnapshot(
          pageIndex: 1, pageLabel: "2",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [],
      candidates: [],
      warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [])

    #expect(diff.summary.overallStatus == .incomplete)
    #expect(diff.pages.isEmpty)
  }

  @Test func completionProgressPercentCalculatesCorrectly() {
    let empty = CompletionProgress.empty
    #expect(empty.percentComplete == 0)

    let half = CompletionProgress(
      totalCandidates: 10, confirmedCount: 5, rejectedCount: 0, remainingCount: 5)
    #expect(half.percentComplete == 50.0)

    let complete = CompletionProgress(
      totalCandidates: 4, confirmedCount: 4, rejectedCount: 0, remainingCount: 0)
    #expect(complete.percentComplete == 100.0)
  }

  // MARK: - Red-Team Regression Tests (PER-PDEV-0168)

  /// RT-001: Verify on-disk profile file is NOT readable as plaintext JSON.
  ///
  /// A local attacker reading Application Support must not find plaintext PII
  /// in the profile JSON files. After `save()`, the on-disk bytes must not be
  /// decodable directly as `UserProfile` — the file should contain only the
  /// nonce+ciphertext envelope.
  @Test func redTeamRT001ProfileIsNotStoredAsPlaintextJSON() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("pdf-editor-rt001-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = EncryptedProfileStore(directory: directory)
    var profile = UserProfile(displayName: "RT-001 Victim")
    profile.setValue("123-45-6789", for: StandardSemanticKey.ssn.rawValue)
    profile.setValue("Jane Doe", for: StandardSemanticKey.fullName.rawValue)
    try store.save(profile: profile)

    // Read the raw bytes from disk.
    let fileURL = directory.appendingPathComponent("\(profile.profileID.uuidString).json")
    let rawData = try Data(contentsOf: fileURL)

    // The raw file must NOT decode directly to a UserProfile (that would mean plaintext PII).
    let decodedDirectly = try? JSONDecoder().decode(UserProfile.self, from: rawData)
    #expect(
      decodedDirectly == nil,
      "RT-001 FAIL: Profile was written as plaintext JSON — PII is readable without decryption.")

    // But the store must still round-trip correctly (real decryption works).
    let reloaded = try store.load(profileID: profile.profileID)
    #expect(reloaded?.value(for: StandardSemanticKey.ssn.rawValue) == "123-45-6789")
    #expect(reloaded?.value(for: StandardSemanticKey.fullName.rawValue) == "Jane Doe")
  }

  /// RT-003: Verify vCard import truncates values longer than 1024 characters.
  ///
  /// A crafted vCard with a multi-kilobyte FN: line must not store unbounded
  /// data in the profile.
  @Test func redTeamRT003VCardImportTruncatesLongValues() {
    var profile = UserProfile(displayName: "RT-003 Victim")
    // Craft a 4096-character FN: value.
    let longValue = String(repeating: "A", count: 4096)
    let vCard = "BEGIN:VCARD\nFN:\(longValue)\nEND:VCARD"
    profile.importFromVCard(vCard)

    let stored = profile.value(for: StandardSemanticKey.fullName.rawValue)
    #expect(
      (stored?.count ?? 0) <= 1024,
      "RT-003 FAIL: vCard FN: value was stored at \(stored?.count ?? 0) chars; expected ≤ 1024.")
  }

  // MARK: - Bulk Fill Tests

  @Test func bulkFillMatchesNativeFieldsByName() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("Ada Lovelace", for: "person.fullName")
    profile.setValue("ada@example.com", for: "person.email")
    profile.setValue("555-0100", for: "person.phone")

    let fields = [
      NativeField(
        id: "applicant.name", name: "applicant.name", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 500, width: 200, height: 20),
        value: nil, choices: []),
      NativeField(
        id: "applicant.email", name: "applicant.email", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 460, width: 200, height: 20),
        value: nil, choices: []),
      NativeField(
        id: "applicant.dob", name: "applicant.dob", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 420, width: 200, height: 20),
        value: nil, choices: []),
    ]

    let result = profile.bulkFill(
      fields: fields, candidates: [], sourceDigest: "test-digest")

    #expect(result.totalMatches == 2)
    #expect(result.unmatchedFields == ["applicant.dob"])
    #expect(result.matchedOperations.count == 2)
    #expect(result.matchedOperations.contains { $0.value == "Ada Lovelace" })
    #expect(result.matchedOperations.contains { $0.value == "ada@example.com" })
  }

  @Test func bulkFillMatchesStaticCandidatesByLabel() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("Jane Smith", for: "person.fullName")
    profile.setValue("123 Main St", for: "person.address.street")

    let candidates = [
      RegionCandidate(
        pageIndex: 0,
        bounds: PDFRect(x: 100, y: 500, width: 200, height: 20),
        kind: .textAnchored, score: 0.8, evidence: ["label"],
        entryMode: .singleText, labelText: "Full Name:"),
      RegionCandidate(
        pageIndex: 0,
        bounds: PDFRect(x: 100, y: 460, width: 200, height: 20),
        kind: .vectorRegion, score: 0.7, evidence: ["label"],
        entryMode: .singleText, labelText: "Street Address:"),
      RegionCandidate(
        pageIndex: 0,
        bounds: PDFRect(x: 100, y: 420, width: 200, height: 20),
        kind: .textAnchored, score: 0.6, evidence: ["label"],
        entryMode: .checkbox, labelText: "Check if yes"),
    ]

    let result = profile.bulkFill(
      fields: [], candidates: candidates, sourceDigest: "test-digest")

    #expect(result.totalMatches == 2)
    #expect(result.matchedOperations.count == 2)
    #expect(result.matchedOperations.contains { $0.value == "Jane Smith" })
    #expect(result.matchedOperations.contains { $0.value == "123 Main St" })
  }

  @Test func bulkFillSkipsNonEditableCandidates() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("Yes", for: "person.firstName")

    let candidates = [
      RegionCandidate(
        pageIndex: 0,
        bounds: PDFRect(x: 100, y: 500, width: 200, height: 20),
        kind: .vectorRegion, score: 0.8, evidence: ["label"],
        entryMode: .checkbox, labelText: "First Name:"),
    ]

    let result = profile.bulkFill(
      fields: [], candidates: candidates, sourceDigest: "test-digest")

    #expect(result.totalMatches == 0)
  }

  @Test func bulkFillReturnsEmptyForEmptyProfile() {
    let profile = UserProfile(displayName: "Empty")
    let fields = [
      NativeField(
        id: "field-1", name: "name", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 500, width: 200, height: 20),
        value: nil, choices: []),
    ]

    let result = profile.bulkFill(
      fields: fields, candidates: [], sourceDigest: "test-digest")

    #expect(result.totalMatches == 0)
    #expect(result.unmatchedFields == ["name"])
  }

  @Test func bulkFillHeuristicMatchesPhoneAndSSN() {
    var profile = UserProfile(displayName: "Test")
    profile.setValue("555-0100", for: "person.phone")
    profile.setValue("123-45-6789", for: "person.ssn")

    let fields = [
      NativeField(
        id: "phone", name: "applicant.phone", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 500, width: 200, height: 20),
        value: nil, choices: []),
      NativeField(
        id: "ssn", name: "applicant.ssn", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 460, width: 200, height: 20),
        value: nil, choices: []),
      NativeField(
        id: "other", name: "random.field", kind: .text,
        pageIndex: 0, bounds: PDFRect(x: 100, y: 420, width: 200, height: 20),
        value: nil, choices: []),
    ]

    let result = profile.bulkFill(
      fields: fields, candidates: [], sourceDigest: "test-digest")

    #expect(result.totalMatches == 2)
    #expect(result.matchedOperations.contains { $0.value == "555-0100" })
    #expect(result.matchedOperations.contains { $0.value == "123-45-6789" })
    #expect(result.unmatchedFields == ["random.field"])
  }

  // MARK: - Visual Diff Tests

  @Test func diffDetectsOutsideRegionTextChange() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "a", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "Old", choices: [])
      ],
      candidates: [],
      warnings: []
    )
    let output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "b", count: 64)),
      pages: source.pages,
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "New", choices: [])
      ],
      candidates: [],
      warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [])

    #expect(diff.summary.overallStatus == .warnings)
    #expect(diff.pages[0].regions.contains { $0.kind == .nativeFieldChanged })
    #expect(diff.summary.unexpectedChanges >= 0)
  }

  @Test func diffPreservesInsideOperationRegions() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "c", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "Old", choices: [])
      ],
      candidates: [],
      warnings: []
    )
    let operation = EditOperation(
      pageIndex: 0,
      targetID: "field-1",
      kind: .nativeFieldValue,
      value: "New",
      bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
      sourceDigest: "c",
      coordinate: PDFPageRegion(
        pageIndex: 0,
        rect: PDFRect(x: 72, y: 600, width: 200, height: 20)),
      payload: .text("New")
    )
    let output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "d", count: 64)),
      pages: source.pages,
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "New", choices: [])
      ],
      candidates: [],
      warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [operation])

    // The change is inside an authorized operation region
    #expect(diff.pages[0].regions.contains { $0.kind == .nativeFieldChanged })
    #expect(diff.summary.operationRegionsMatched > 0)
  }

  @Test func diffDetectsGeometryChange() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "e", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [], candidates: [], warnings: []
    )
    let output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "f", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 595, height: 842),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 90, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [], candidates: [], warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [])

    #expect(diff.pages[0].regions.contains { $0.kind == .geometryChanged })
    #expect(diff.summary.overallStatus != .preserved)
  }

  @Test func diffSummaryCountsCorrectly() {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "g", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true),
        PageSnapshot(
          pageIndex: 1, pageLabel: "2",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 30, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [
        NativeField(
          id: "f1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "A", choices: []),
        NativeField(
          id: "f2", name: "email", kind: .text, pageIndex: 1,
          bounds: PDFRect(x: 72, y: 400, width: 200, height: 20),
          value: "B", choices: [])
      ],
      candidates: [], warnings: []
    )
    let output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "h", count: 64)),
      pages: source.pages,
      fields: [
        NativeField(
          id: "f1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "A-new", choices: []),
        NativeField(
          id: "f2", name: "email", kind: .text, pageIndex: 1,
          bounds: PDFRect(x: 72, y: 400, width: 200, height: 20),
          value: "B-new", choices: [])
      ],
      candidates: [], warnings: []
    )

    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [])

    #expect(diff.summary.pagesWithChanges == 2)
    #expect(diff.pageCount == 2)
    #expect(diff.summary.totalRegionsCompared == 0) // no operations
  }

  // MARK: - Diff Report Tests

  @Test func diffReportGeneratesPDFData() throws {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "a", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "Old", choices: [])
      ],
      candidates: [],
      warnings: []
    )
    let output = DocumentInspection(
      source: DocumentSource(
        fileName: "output.pdf", byteCount: 100,
        sha256: String(repeating: "b", count: 64)),
      pages: source.pages,
      fields: [
        NativeField(
          id: "field-1", name: "name", kind: .text, pageIndex: 0,
          bounds: PDFRect(x: 72, y: 600, width: 200, height: 20),
          value: "New", choices: [])
      ],
      candidates: [],
      warnings: []
    )
    let diff = DocumentDiffBuilder.build(
      source: source, output: output, operations: [])

    // Create minimal PDF documents for the report
    let sourcePDF = PDFDocument()
    let outputPDF = PDFDocument()

    let data = try DocumentDiffReport.generate(
      sourceDocument: sourcePDF,
      currentDocument: outputPDF,
      diff: diff,
      operations: []
    )

    #expect(!data.isEmpty)
    #expect(data.count > 100) // Must be a non-trivial PDF

    // Verify it's a valid PDF
    let reportDoc = PDFDocument(data: data)
    #expect(reportDoc != nil)
    // Cover page + 1 changed page = 2 pages
    #expect(reportDoc?.pageCount == 2)
  }

  @Test func diffReportThrowsOnNoChanges() throws {
    let source = DocumentInspection(
      source: DocumentSource(
        fileName: "source.pdf", byteCount: 100,
        sha256: String(repeating: "c", count: 64)),
      pages: [
        PageSnapshot(
          pageIndex: 0, pageLabel: "1",
          bounds: PDFRect(x: 0, y: 0, width: 612, height: 792),
          cropBox: nil, bleedBox: nil, trimBox: nil, artBox: nil,
          rotation: 0, characterCount: 50, annotationCount: 0,
          hasSelectableText: true)
      ],
      fields: [], candidates: [], warnings: []
    )
    let diff = DocumentDiffBuilder.build(
      source: source, output: source, operations: [])

    let sourcePDF = PDFDocument()
    let outputPDF = PDFDocument()

    #expect(throws: DocumentDiffReport.ReportError.noChanges) {
      try DocumentDiffReport.generate(
        sourceDocument: sourcePDF,
        currentDocument: outputPDF,
        diff: diff,
        operations: []
      )
    }
  }
}
