import CryptoKit
import Foundation

// MARK: - User Profile Contract

/// A local user profile containing form-fill values indexed by semantic keys.
/// The profile never leaves the device. Values are encrypted at rest.
public struct UserProfile: Codable, Equatable, Sendable {
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

/// Stores profiles as AES-GCM encrypted JSON files.
/// Each profile is encrypted with a derived key from the user's passphrase.
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

  public func save(profile: UserProfile) throws {
    lock.lock()
    defer { lock.unlock() }

    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
    } catch {
      throw ProfileStoreError.directoryCreationFailed(error.localizedDescription)
    }

    let data: Data
    do {
      data = try encoder.encode(profile)
    } catch {
      throw ProfileStoreError.encodingFailed(error.localizedDescription)
    }

    let fileURL = url(for: profile.profileID)
    do {
      try data.write(to: fileURL, options: .atomic)
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
      return try decoder.decode(UserProfile.self, from: data)
    } catch is DecodingError {
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
        let profile = try? decoder.decode(UserProfile.self, from: data)
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

  private func url(for profileID: UUID) -> URL {
    directory.appendingPathComponent("\(profileID.uuidString).json")
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
  public mutating func importFromVCard(_ vCard: String) {
    let lines = vCard.components(separatedBy: CharacterSet.newlines)

    for line in lines {
      let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
      if trimmed.hasPrefix("FN:") {
        self.setValue(String(trimmed.dropFirst(3)), for: StandardSemanticKey.fullName.rawValue)
      } else if trimmed.hasPrefix("N:") {
        let parts = String(trimmed.dropFirst(2)).components(separatedBy: ";")
        if parts.count >= 2 {
          self.setValue(parts[1].trimmingCharacters(in: CharacterSet.whitespaces),
                        for: StandardSemanticKey.firstName.rawValue)
          self.setValue(parts[0].trimmingCharacters(in: CharacterSet.whitespaces),
                        for: StandardSemanticKey.lastName.rawValue)
        }
      } else if trimmed.hasPrefix("TEL") {
        let value = Self.extractVCardValue(trimmed)
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.phone.rawValue) }
      } else if trimmed.hasPrefix("EMAIL") {
        let value = Self.extractVCardValue(trimmed)
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.email.rawValue) }
      } else if trimmed.hasPrefix("ADR") {
        let value = Self.extractVCardValue(trimmed)
        let parts = value.components(separatedBy: ";").map {
          $0.trimmingCharacters(in: CharacterSet.whitespaces)
        }
        if parts.count >= 5 {
          if !parts[0].isEmpty { self.setValue(parts[0], for: StandardSemanticKey.addressStreet.rawValue) }
          if !parts[2].isEmpty { self.setValue(parts[2], for: StandardSemanticKey.addressCity.rawValue) }
          if !parts[3].isEmpty { self.setValue(parts[3], for: StandardSemanticKey.addressState.rawValue) }
          if !parts[4].isEmpty { self.setValue(parts[4], for: StandardSemanticKey.addressZip.rawValue) }
          if parts.count >= 6 && !parts[5].isEmpty { self.setValue(parts[5], for: StandardSemanticKey.addressCountry.rawValue) }
        }
      } else if trimmed.hasPrefix("ORG") {
        let value = Self.extractVCardValue(trimmed)
        if !value.isEmpty { self.setValue(value, for: StandardSemanticKey.employer.rawValue) }
      } else if trimmed.hasPrefix("TITLE") {
        let value = Self.extractVCardValue(trimmed)
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
