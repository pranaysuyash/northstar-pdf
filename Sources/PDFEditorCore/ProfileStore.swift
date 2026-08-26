import CryptoKit
import Foundation

// MARK: - User Profile Contract

/// A local user profile containing form-fill values indexed by semantic keys.
/// The profile never leaves the device. Values are encrypted at rest.
public struct UserProfile: Codable, Equatable, Hashable, Sendable, Identifiable {
  public var id: UUID { profileID }
  public let profileID: UUID
  public var displayName: String
  public var values: [UserProfileValue]
  public var createdAt: Date
  public var lastModifiedAt: Date

  public init(
    profileID: UUID = UUID(),
    displayName: String,
    values: [UserProfileValue] = [],
    createdAt: Date = Date(),
    lastModifiedAt: Date = Date()
  ) {
    self.profileID = profileID
    self.displayName = displayName
    self.values = values
    self.createdAt = createdAt
    self.lastModifiedAt = lastModifiedAt
  }

  /// Look up a value by semantic key.
  public func value(for key: String) -> String? {
    values.first { $0.semanticKey == key }?.textValue
  }

  /// The set of semantic keys in this profile.
  public var semanticKeys: Set<String> {
    Set(values.map(\.semanticKey))
  }

  /// Match profile values to template mapping semantic keys.
  /// Returns a dictionary of mappingID → profile value for approved mappings.
  public func matchToMappings(
    _ mappings: [PDFTemplateMapping]
  ) -> [UUID: String] {
    var result: [UUID: String] = [:]
    for mapping in mappings where mapping.isApproved {
      if let value = value(for: mapping.semanticKey) {
        result[mapping.id] = value
      }
    }
    return result
  }
}

/// A single profile value with its semantic key and optional metadata.
public struct UserProfileValue: Codable, Equatable, Hashable, Sendable {
  public let semanticKey: String
  public let textValue: String
  public let label: String?
  public let category: ProfileValueCategory

  public init(
    semanticKey: String,
    textValue: String,
    label: String? = nil,
    category: ProfileValueCategory = .general
  ) {
    self.semanticKey = semanticKey
    self.textValue = textValue
    self.label = label
    self.category = category
  }
}

/// Categories for profile values to support UI grouping.
public enum ProfileValueCategory: String, Codable, CaseIterable, Hashable, Sendable {
  case personal = "personal"
  case contact = "contact"
  case address = "address"
  case financial = "financial"
  case identification = "identification"
  case general = "general"
}

// MARK: - Standard Semantic Keys

/// Well-known semantic keys for common form fields.
public enum StandardSemanticKey: String, CaseIterable, Sendable {
  case firstName = "person.firstName"
  case lastName = "person.lastName"
  case fullName = "person.fullName"
  case email = "person.email"
  case phone = "person.phone"
  case dateOfBirth = "person.dateOfBirth"
  case addressStreet = "person.address.street"
  case addressCity = "person.address.city"
  case addressState = "person.address.state"
  case addressZip = "person.address.zip"
  case addressCountry = "person.address.country"
  case ssn = "person.ssn"
  case employer = "person.employer"
  case jobTitle = "person.jobTitle"

  public var displayName: String {
    switch self {
    case .firstName: return "First Name"
    case .lastName: return "Last Name"
    case .fullName: return "Full Name"
    case .email: return "Email"
    case .phone: return "Phone"
    case .dateOfBirth: return "Date of Birth"
    case .addressStreet: return "Street Address"
    case .addressCity: return "City"
    case .addressState: return "State"
    case .addressZip: return "ZIP Code"
    case .addressCountry: return "Country"
    case .ssn: return "SSN"
    case .employer: return "Employer"
    case .jobTitle: return "Job Title"
    }
  }

  public var category: ProfileValueCategory {
    switch self {
    case .firstName, .lastName, .fullName, .dateOfBirth:
      return .personal
    case .email, .phone:
      return .contact
    case .addressStreet, .addressCity, .addressState, .addressZip, .addressCountry:
      return .address
    case .ssn:
      return .identification
    case .employer, .jobTitle:
      return .general
    }
  }
}

// MARK: - Profile Store Protocol

/// A provider-neutral profile persistence interface.
public protocol ProfileStore {
  /// Save a profile. Overwrites any existing profile with the same ID.
  func save(profile: UserProfile) throws

  /// Load a profile by ID.
  func load(profileID: UUID) throws -> UserProfile?

  /// List all profiles, newest first.
  func listAll() throws -> [UserProfile]

  /// Delete a profile by ID.
  func delete(profileID: UUID) throws

  /// The number of saved profiles.
  var count: Int { get }
}

// MARK: - Profile Store Errors

public enum ProfileStoreError: Error, LocalizedError {
  case directoryCreationFailed(String)
  case encryptionFailed(String)
  case decryptionFailed(String)
  case encodingFailed(String)
  case decodingFailed(String)
  case fileOperationFailed(String)
  case wrongKey
  case recordNotFound

  public var errorDescription: String? {
    switch self {
    case .directoryCreationFailed(let m): "Could not create profile directory: \(m)"
    case .encryptionFailed(let m): "Could not encrypt profile: \(m)"
    case .decryptionFailed(let m): "Could not decrypt profile: \(m)"
    case .encodingFailed(let m): "Could not encode profile: \(m)"
    case .decodingFailed(let m): "Could not decode profile: \(m)"
    case .fileOperationFailed(let m): "Profile file operation failed: \(m)"
    case .wrongKey: "The provided key does not match the profile encryption key."
    case .recordNotFound: "The requested profile was not found."
    }
  }
}

// MARK: - Encrypted Profile Store (Native macOS)

// MARK: - AES-GCM On-Disk Envelope

/// The on-disk representation of an encrypted profile.
/// Both fields are base64-encoded; neither contains plaintext PII.
private struct EncryptedProfileEnvelope: Codable {
  /// Fresh AES-GCM 12-byte nonce, base64-encoded.
  let nonce: String
  /// AES-256-GCM sealed ciphertext + 16-byte auth tag, base64-encoded.
  let ciphertext: String
}

// MARK: - Keychain Key Management

/// Keychain service and account labels for the profile encryption key.
private let kProfileStoreKeychainService = "com.pdfeditor.profilestore"
private let kProfileStoreKeychainAccount = "profile-encryption-key-v1"

/// Retrieve or create the 256-bit AES-GCM symmetric key used to protect profiles.
/// The key is stored in the user's macOS Keychain and never written to disk.
private func profileEncryptionKey() throws -> SymmetricKey {
  let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: kProfileStoreKeychainService,
    kSecAttrAccount as String: kProfileStoreKeychainAccount,
    kSecReturnData as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne,
  ]
  var result: AnyObject?
  let status = SecItemCopyMatching(query as CFDictionary, &result)
  if status == errSecSuccess, let keyData = result as? Data {
    return SymmetricKey(data: keyData)
  }

  let newKey = SymmetricKey(size: .bits256)
  let newKeyData = newKey.withUnsafeBytes { Data($0) }
  let addQuery: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: kProfileStoreKeychainService,
    kSecAttrAccount as String: kProfileStoreKeychainAccount,
    kSecValueData as String: newKeyData,
    kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
  ]
  let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
  guard addStatus == errSecSuccess else {
    throw ProfileStoreError.encryptionFailed(
      "Could not store encryption key in Keychain (OSStatus \(addStatus)).")
  }
  return newKey
}

/// Stores profiles as AES-256-GCM encrypted JSON files on disk.
///
/// Each profile is encoded to JSON and sealed with AES-256-GCM using a 256-bit
/// key generated once and stored in the user's macOS Keychain under the service
/// label `com.pdfeditor.profilestore`. The on-disk file is an
/// `EncryptedProfileEnvelope` JSON blob containing only the nonce and sealed
/// ciphertext; no plaintext PII is ever written to the Application Support directory.
///
/// **Red-team finding RT-001 remediated.** The previous implementation wrote raw
/// plaintext JSON to disk despite the "Encrypted" class name and AES-GCM
/// documentation. This implementation provides genuine at-rest encryption for all
/// profile values including SSN, address, DOB, employer, and email.
///
/// **Backward compatibility:** Profiles written by the previous plaintext
/// implementation are detected (they decode successfully as `UserProfile` directly)
/// and migrated to the encrypted format on the next save.
public final class EncryptedProfileStore: ProfileStore, @unchecked Sendable {
  private let directory: URL
  private let lock = NSLock()
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL) {
    self.directory = directory
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys]
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  /// The default profile directory inside the user's Application Support.
  public static var defaultDirectory: URL {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    return appSupport
      .appendingPathComponent("PDFEditor", isDirectory: true)
      .appendingPathComponent("Profiles", isDirectory: true)
  }

  // MARK: - ProfileStore Protocol

  public func save(profile: UserProfile) throws {
    lock.lock()
    defer { lock.unlock() }

    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
    } catch {
      throw ProfileStoreError.directoryCreationFailed(error.localizedDescription)
    }

    // 1. JSON-encode the profile.
    let plaintext: Data
    do {
      plaintext = try encoder.encode(profile)
    } catch {
      throw ProfileStoreError.encodingFailed(error.localizedDescription)
    }

    // 2. Retrieve (or generate) the Keychain-backed 256-bit symmetric key.
    let key: SymmetricKey
    do {
      key = try profileEncryptionKey()
    } catch {
      throw ProfileStoreError.encryptionFailed(error.localizedDescription)
    }

    // 3. Seal with AES-256-GCM using a fresh random 96-bit nonce.
    let sealedBox: AES.GCM.SealedBox
    do {
      sealedBox = try AES.GCM.seal(plaintext, using: key)
    } catch {
      throw ProfileStoreError.encryptionFailed(error.localizedDescription)
    }

    let nonceData = sealedBox.nonce.withUnsafeBytes { Data($0) }
    // .combined = nonce(12) + ciphertext + tag(16)
    let combinedData = sealedBox.combined ?? (sealedBox.ciphertext + sealedBox.tag)

    // 4. Write the envelope (nonce + combined, both base64) to disk atomically.
    let envelope = EncryptedProfileEnvelope(
      nonce: nonceData.base64EncodedString(),
      ciphertext: combinedData.base64EncodedString()
    )
    let envelopeData: Data
    do {
      envelopeData = try encoder.encode(envelope)
    } catch {
      throw ProfileStoreError.encodingFailed(error.localizedDescription)
    }

    let fileURL = url(for: profile.profileID)
    do {
      try envelopeData.write(to: fileURL, options: .atomic)
    } catch {
      throw ProfileStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  public func load(profileID: UUID) throws -> UserProfile? {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: profileID)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    do {
      let data = try Data(contentsOf: fileURL)
      return try decodeProfile(from: data)
    } catch is ProfileStoreError {
      throw ProfileStoreError.decodingFailed("Profile file is corrupted.")
    } catch {
      throw ProfileStoreError.fileOperationFailed(error.localizedDescription)
    }
  }

  public func listAll() throws -> [UserProfile] {
    lock.lock()
    defer { lock.unlock() }

    guard FileManager.default.fileExists(atPath: directory.path) else {
      return []
    }

    let contents: [URL]
    do {
      contents = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
    } catch {
      return []
    }

    var profiles: [UserProfile] = []
    for fileURL in contents where fileURL.pathExtension == "json" {
      if let data = try? Data(contentsOf: fileURL),
        let profile = try? decodeProfile(from: data)
      {
        profiles.append(profile)
      }
    }

    return profiles.sorted { $0.lastModifiedAt > $1.lastModifiedAt }
  }

  public func delete(profileID: UUID) throws {
    lock.lock()
    defer { lock.unlock() }

    let fileURL = url(for: profileID)
    if FileManager.default.fileExists(atPath: fileURL.path) {
      do {
        try FileManager.default.removeItem(at: fileURL)
      } catch {
        throw ProfileStoreError.fileOperationFailed(error.localizedDescription)
      }
    }
  }

  public var count: Int {
    lock.lock()
    defer { lock.unlock() }

    guard FileManager.default.fileExists(atPath: directory.path) else {
      return 0
    }
    return (try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }.count) ?? 0
  }

  // MARK: - Private Helpers

  private func url(for profileID: UUID) -> URL {
    directory.appendingPathComponent("\(profileID.uuidString).json")
  }

  /// Decode a profile from raw file data.
  /// Tries the encrypted envelope format first; falls back to legacy plaintext JSON.
  private func decodeProfile(from data: Data) throws -> UserProfile {
    // Attempt encrypted envelope path.
    if let envelope = try? decoder.decode(EncryptedProfileEnvelope.self, from: data),
      !envelope.nonce.isEmpty, !envelope.ciphertext.isEmpty
    {
      return try decryptProfile(from: envelope)
    }

    // Backward-compat: plaintext profile written before encryption was implemented.
    if let profile = try? decoder.decode(UserProfile.self, from: data) {
      return profile
    }

    throw ProfileStoreError.decodingFailed("Profile file is corrupted or unrecognized format.")
  }

  /// Decrypt an `EncryptedProfileEnvelope` and return the contained `UserProfile`.
  private func decryptProfile(from envelope: EncryptedProfileEnvelope) throws -> UserProfile {
    guard let combinedData = Data(base64Encoded: envelope.ciphertext) else {
      throw ProfileStoreError.decryptionFailed("Ciphertext field is not valid base64.")
    }

    let key: SymmetricKey
    do {
      key = try profileEncryptionKey()
    } catch {
      throw ProfileStoreError.decryptionFailed(error.localizedDescription)
    }

    let sealedBox: AES.GCM.SealedBox
    do {
      // combinedData = nonce(12) + ciphertext + tag(16)
      sealedBox = try AES.GCM.SealedBox(combined: combinedData)
    } catch {
      throw ProfileStoreError.decryptionFailed(
        "Could not reconstruct sealed box: \(error.localizedDescription)")
    }

    let plaintext: Data
    do {
      plaintext = try AES.GCM.open(sealedBox, using: key)
    } catch {
      throw ProfileStoreError.wrongKey
    }

    do {
      return try decoder.decode(UserProfile.self, from: plaintext)
    } catch {
      throw ProfileStoreError.decodingFailed("Decrypted profile content is invalid JSON.")
    }
  }
}

// MARK: - Profile Builder Helpers

extension UserProfile {
  /// Create a profile pre-populated with standard semantic keys.
  public static func standard(displayName: String) -> UserProfile {
    UserProfile(
      displayName: displayName,
      values: StandardSemanticKey.allCases.map { key in
        UserProfileValue(
          semanticKey: key.rawValue,
          textValue: "",
          label: key.displayName,
          category: key.category
        )
      }
    )
  }

  /// Create a profile from a dictionary of semantic key → value.
  public static func from(
    displayName: String,
    values: [String: String]
  ) -> UserProfile {
    UserProfile(
      displayName: displayName,
      values: values.map { key, value in
        UserProfileValue(
          semanticKey: key,
          textValue: value,
          category: StandardSemanticKey(rawValue: key)?.category ?? .general
        )
      }.sorted { $0.semanticKey < $1.semanticKey }
    )
  }

  /// Update a value by semantic key, or append if not present.
  public mutating func setValue(_ value: String, for key: String) {
    if let index = values.firstIndex(where: { $0.semanticKey == key }) {
      values[index] = UserProfileValue(
        semanticKey: key,
        textValue: value,
        label: values[index].label,
        category: values[index].category
      )
    } else {
      values.append(
        UserProfileValue(
          semanticKey: key,
          textValue: value,
          category: StandardSemanticKey(rawValue: key)?.category ?? .general
        )
      )
    }
    lastModifiedAt = Date()
  }

  /// Remove a value by semantic key.
  public mutating func removeValue(for key: String) {
    values.removeAll { $0.semanticKey == key }
    lastModifiedAt = Date()
  }

  /// Import values from a vCard string (basic extraction).
  ///
  /// - Red-team finding RT-003 remediated: Values longer than
  ///   `vCardMaxValueLength` characters are silently truncated to prevent
  ///   crafted vCard inputs from storing unbounded data.
  public mutating func importFromVCard(_ vCard: String) {
    /// Maximum allowed length for any single imported vCard field value.
    let vCardMaxValueLength = 1024

    /// Truncate a raw imported string to the permitted maximum.
    func sanitized(_ raw: String) -> String {
      raw.count <= vCardMaxValueLength ? raw : String(raw.prefix(vCardMaxValueLength))
    }

    let lines = vCard.components(separatedBy: CharacterSet.newlines)

    for line in lines {
      let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
      if trimmed.hasPrefix("FN:") {
        self.setValue(sanitized(String(trimmed.dropFirst(3))), for: StandardSemanticKey.fullName.rawValue)
      } else if trimmed.hasPrefix("N:") {
        let parts = sanitized(String(trimmed.dropFirst(2))).components(separatedBy: ";")
        if parts.count >= 2 {
          self.setValue(parts[1].trimmingCharacters(in: CharacterSet.whitespaces),
                        for: StandardSemanticKey.firstName.rawValue)
          self.setValue(parts[0].trimmingCharacters(in: CharacterSet.whitespaces),
                        for: StandardSemanticKey.lastName.rawValue)
        }
      } else if trimmed.hasPrefix("TEL") {
        let value = sanitized(Self.extractVCardValue(trimmed))
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.phone.rawValue) }
      } else if trimmed.hasPrefix("EMAIL") {
        let value = sanitized(Self.extractVCardValue(trimmed))
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.email.rawValue) }
      } else if trimmed.hasPrefix("ADR") {
        let value = sanitized(Self.extractVCardValue(trimmed))
        let parts = value.components(separatedBy: ";").map {
          $0.trimmingCharacters(in: CharacterSet.whitespaces)
        }
        if parts.count >= 6 {
          if !parts[2].isEmpty { self.setValue(parts[2], for: StandardSemanticKey.addressStreet.rawValue) }
          if !parts[3].isEmpty { self.setValue(parts[3], for: StandardSemanticKey.addressCity.rawValue) }
          if !parts[4].isEmpty { self.setValue(parts[4], for: StandardSemanticKey.addressState.rawValue) }
          if !parts[5].isEmpty { self.setValue(parts[5], for: StandardSemanticKey.addressZip.rawValue) }
          if parts.count > 6 && !parts[6].isEmpty { self.setValue(parts[6], for: StandardSemanticKey.addressCountry.rawValue) }
        }
      } else if trimmed.hasPrefix("ORG") {
        let value = sanitized(Self.extractVCardValue(trimmed))
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.employer.rawValue) }
      } else if trimmed.hasPrefix("TITLE") {
        let value = sanitized(Self.extractVCardValue(trimmed))
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.jobTitle.rawValue) }
      }
    }
  }

  private static func extractVCardValue(_ line: String) -> String {
    if let colonIndex = line.firstIndex(of: ":") {
      return String(line[line.index(after: colonIndex)...])
        .trimmingCharacters(in: CharacterSet.whitespaces)
    }
    return ""
  }
}

// MARK: - Profile Bulk Fill

/// The result of matching a profile against a document's candidates and fields.
public struct ProfileBulkFillResult: Codable, Equatable, Sendable {
  public let matchedOperations: [EditOperation]
  public let unmatchedFields: [String]
  public let profileKeysUsed: Set<String>
  public let totalMatches: Int

  public init(
    matchedOperations: [EditOperation],
    unmatchedFields: [String],
    profileKeysUsed: Set<String>,
    totalMatches: Int
  ) {
    self.matchedOperations = matchedOperations
    self.unmatchedFields = unmatchedFields
    self.profileKeysUsed = profileKeysUsed
    self.totalMatches = totalMatches
  }
}

extension UserProfile {
  /// Match profile values against native fields and static candidates.
  /// Uses semantic key matching: "person.fullName" matches fields labeled "Full Name" etc.
  /// Returns operations for every match, plus a list of unmatched fields.
  public func bulkFill(
    fields: [NativeField],
    candidates: [RegionCandidate],
    sourceDigest: String
  ) -> ProfileBulkFillResult {
    var operations: [EditOperation] = []
    var unmatchedFields: [String] = []
    var usedKeys: Set<String> = []

    // Match native fields
    for field in fields {
      if let match = bestMatch(forLabel: field.name) {
        usedKeys.insert(match.key)
        operations.append(
          EditOperation(
            pageIndex: field.pageIndex,
            targetID: field.name,
            kind: .nativeFieldValue,
            value: match.value,
            bounds: field.bounds,
            sourceDigest: sourceDigest,
            coordinate: PDFPageRegion(pageIndex: field.pageIndex, rect: field.bounds),
            payload: .text(match.value)
          )
        )
      } else {
        unmatchedFields.append(field.name)
      }
    }

    // Match static candidates (text-entry regions only)
    for candidate in candidates where candidate.isDirectlyEditable {
      let label = candidate.labelText ?? ""
      if let match = bestMatch(forLabel: label) {
        usedKeys.insert(match.key)
        operations.append(
          EditOperation(
            pageIndex: candidate.pageIndex,
            kind: .overlayText,
            value: match.value,
            bounds: candidate.bounds,
            candidateID: candidate.id,
            sourceDigest: sourceDigest,
            coordinate: PDFPageRegion(pageIndex: candidate.pageIndex, rect: candidate.bounds),
            payload: candidate.entryMode == .characterGrid
              ? .characterGrid(text: match.value, cells: candidate.memberBounds)
              : .text(match.value)
          )
        )
      }
    }

    return ProfileBulkFillResult(
      matchedOperations: operations,
      unmatchedFields: unmatchedFields,
      profileKeysUsed: usedKeys,
      totalMatches: operations.count
    )
  }

  // MARK: - Scored label matching

  /// Alias table mapping each standard semantic key to the label phrases it
  /// accepts on documents. Matching stays deterministic and local; the table
  /// replaces the previous first-hit substring rules which mis-assigned
  /// "First Name" fields to the full-name value.
  static let labelAliases: [String: [String]] = [
    StandardSemanticKey.fullName.rawValue: [
      "name", "full name", "full legal name", "legal name", "applicant name",
      "your name", "print name", "employee name", "student name",
    ],
    StandardSemanticKey.firstName.rawValue: [
      "first name", "given name", "forename", "first",
    ],
    StandardSemanticKey.lastName.rawValue: [
      "last name", "surname", "family name", "last",
    ],
    StandardSemanticKey.email.rawValue: [
      "email", "e mail", "email address", "electronic mail",
    ],
    StandardSemanticKey.phone.rawValue: [
      "phone", "telephone", "tel", "mobile", "cell", "cellular",
      "contact number", "daytime phone", "home phone", "work phone",
    ],
    StandardSemanticKey.dateOfBirth.rawValue: [
      "dob", "date of birth", "birth date", "birthday", "born on",
    ],
    StandardSemanticKey.addressStreet.rawValue: [
      "address", "street", "street address", "mailing address",
      "home address", "residence", "addr",
    ],
    StandardSemanticKey.addressCity.rawValue: ["city", "town", "municipality"],
    StandardSemanticKey.addressState.rawValue: ["state", "province", "region"],
    StandardSemanticKey.addressZip.rawValue: [
      "zip", "zip code", "zipcode", "postal code", "postcode",
    ],
    StandardSemanticKey.addressCountry.rawValue: ["country", "nation"],
    StandardSemanticKey.ssn.rawValue: [
      "ssn", "social security number", "social security no", "tax id",
      "taxpayer id",
    ],
    StandardSemanticKey.employer.rawValue: [
      "employer", "company", "organization", "organisation", "firm",
      "business name",
    ],
    StandardSemanticKey.jobTitle.rawValue: [
      "title", "job title", "position", "occupation", "role",
    ],
  ]

  /// Normalizes a label or alias phrase into comparable tokens.
  private static func normalizedTokens(_ text: String) -> Set<String> {
    let cleaned = text.lowercased()
      .map { $0.isLetter || $0.isNumber ? $0 : " " }
      .reduce(into: "") { $0.append($1) }
    return Set(cleaned.split(separator: " ").map(String.init))
  }

  /// Scores how well a raw document label names a semantic key.
  ///
  /// 1.0 = exact alias-phrase equality; otherwise graded token overlap.
  /// Short labels (<2 meaningful tokens) never match multi-token aliases
  /// partially, so "Name" cannot pull the first-name value.
  static func matchScore(label rawLabel: String, semanticKey: String) -> Double {
    guard let aliases = labelAliases[semanticKey] else { return 0 }
    let labelTokens = normalizedTokens(rawLabel)
    guard !labelTokens.isEmpty else { return 0 }

    var best = 0.0
    for alias in aliases {
      let aliasTokens = normalizedTokens(alias)
      guard !aliasTokens.isEmpty else { continue }

      if labelTokens == aliasTokens { return 1.0 }

      // Containment: every alias token present in the label, penalized by
      // how much unrelated text surrounds it.
      if aliasTokens.isSubset(of: labelTokens) {
        let precision = Double(aliasTokens.count) / Double(labelTokens.count)
        best = max(best, 0.6 + 0.35 * precision)
        continue
      }

      // Partial overlap requires at least half the alias tokens and at
      // least two tokens' worth of signal.
      let shared = labelTokens.intersection(aliasTokens)
      if aliasTokens.count >= 2 && shared.count >= 1 {
        let recall = Double(shared.count) / Double(aliasTokens.count)
        if recall >= 0.5 {
          best = max(best, 0.3 + 0.25 * recall)
        }
      }
    }
    return min(best, 0.99)
  }

  /// Best profile entry for a raw document label, or nil below threshold.
  public func bestMatch(forLabel rawLabel: String) -> (key: String, value: String, score: Double)? {
    var best: (key: String, value: String, score: Double)?
    for profileValue in values where !profileValue.textValue.isEmpty {
      let score = Self.matchScore(label: rawLabel, semanticKey: profileValue.semanticKey)
      if score >= 0.6, score > (best?.score ?? 0) {
        best = (profileValue.semanticKey, profileValue.textValue, score)
      }
    }
    return best
  }

  // MARK: - Value suggestions

  /// Formats a raw stored value for placement into a field of the given
  /// inferred type. Deliberately narrow: only unambiguous normalizations.
  public static func formattedValue(
    _ raw: String, for fieldType: SuggestedFieldType?
  ) -> String {
    switch fieldType {
    case .date:
      let isoFormatters = [
        "yyyy-MM-dd", "yyyyMMdd", "MM/dd/yyyy", "M/d/yyyy",
      ].map { format -> DateFormatter in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
      }
      for formatter in isoFormatters {
        if let date = formatter.date(from: raw) {
          let output = DateFormatter()
          output.locale = Locale(identifier: "en_US_POSIX")
          output.dateFormat = "MM/dd/yyyy"
          return output.string(from: date)
        }
      }
      return raw
    case .number:
      let digits = raw.filter(\.isNumber)
      if digits.count == 10 {
        return "(\(digits.prefix(3))) \(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
      }
      if digits.count == 7 {
        return "\(digits.prefix(3))-\(digits.suffix(4))"
      }
      return raw
    default:
      return raw
    }
  }

  /// Up to `limit` fill-ready suggestions for a labeled region: profile
  /// matches formatted for the inferred field type.
  public func valueSuggestions(
    labelText: String?, fieldType: SuggestedFieldType?, limit: Int = 3
  ) -> [String] {
    guard let labelText, !labelText.isEmpty else { return [] }
    var results: [String] = []
    if let match = bestMatch(forLabel: labelText) {
      results.append(Self.formattedValue(match.value, for: fieldType))
    }
    return Array(results.prefix(limit))
  }
}

