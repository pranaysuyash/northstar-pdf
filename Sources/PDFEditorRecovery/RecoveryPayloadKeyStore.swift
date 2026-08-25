import CryptoKit
import Foundation
import Security

enum RecoveryPayloadKeyStoreError: Error, LocalizedError {
  case keychainUnavailable(OSStatus)
  case invalidKey
  case keychainWriteFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .keychainUnavailable:
      "Recovery payload encryption key is unavailable."
    case .invalidKey:
      "Recovery payload encryption key is invalid."
    case .keychainWriteFailed:
      "Recovery payload encryption key could not be stored."
    }
  }
}

/// Provides the stable local key used for sensitive recovery payloads.
///
/// The key is deliberately not derived from a document, session, or source
/// digest. Those values are authenticated as associated data; the key itself
/// is a per-user Keychain secret that remains stable across app launches.
public final class RecoveryPayloadKeyStore: @unchecked Sendable {
  public static let shared = RecoveryPayloadKeyStore()

  public static let defaultService = "com.pdfeditor.recovery-payload"
  public static let defaultAccount = "aes-gcm-256-v1"

  private let service: String
  private let account: String
  private let testKeyData: Data?
  private let lock = NSLock()

  public init(
    service: String = RecoveryPayloadKeyStore.defaultService,
    account: String = RecoveryPayloadKeyStore.defaultAccount,
    testKeyData: Data? = nil
  ) {
    self.service = service
    self.account = account
    self.testKeyData = testKeyData
  }

  func loadOrCreateKey() throws -> SymmetricKey {
    if let testKeyData {
      return try makeKey(from: testKeyData)
    }

    lock.lock()
    defer { lock.unlock() }

    if let data = try readKeyData() {
      return try makeKey(from: data)
    }

    let generatedKey = SymmetricKey(size: .bits256)
    let generatedData = generatedKey.withUnsafeBytes { Data($0) }
    let addStatus = SecItemAdd(addQuery(value: generatedData) as CFDictionary, nil)

    if addStatus == errSecSuccess {
      return generatedKey
    }

    // Another process may have created the same stable item between the read
    // and add. Re-read that item rather than generating a second identity.
    if addStatus == errSecDuplicateItem, let data = try readKeyData() {
      return try makeKey(from: data)
    }

    throw RecoveryPayloadKeyStoreError.keychainWriteFailed(addStatus)
  }

  private func readKeyData() throws -> Data? {
    var result: CFTypeRef?
    let status = SecItemCopyMatching(readQuery() as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data else {
        throw RecoveryPayloadKeyStoreError.invalidKey
      }
      return data
    case errSecItemNotFound:
      return nil
    default:
      throw RecoveryPayloadKeyStoreError.keychainUnavailable(status)
    }
  }

  private func makeKey(from data: Data) throws -> SymmetricKey {
    guard data.count == 32 else {
      throw RecoveryPayloadKeyStoreError.invalidKey
    }
    return SymmetricKey(data: data)
  }

  private func readQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
  }

  private func addQuery(value: Data) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: value
    ]
  }
}
