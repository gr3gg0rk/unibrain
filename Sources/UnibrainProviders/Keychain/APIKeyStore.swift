import Foundation
import UnibrainCore

#if os(macOS) || os(iOS)
import Security
#endif

/// Keychain-backed API key storage for cloud providers.
///
/// Phase 06-01 Task 2: Secure API key storage using macOS Keychain /
/// iOS Secure Enclave. Keys are stored with `kSecAttrAccessibleWhenUnlocked`
/// per ASVS V2 requirements. Linux tests use MockAPIKeyStore.
///
/// Per T-06-01 (mitigate): All Keychain calls validate OSStatus and throw
/// on failure (no silent swallow). Per CLOUD-07: API keys never touch
/// plaintext config files or logs.
public actor APIKeyStore {

    /// Keychain service identifier for unibrain provider keys.
    private static let keychainService = "app.unibrain.provider-keys"

    // MARK: - Public API

    /// Stores an API key in Keychain for the given provider.
    ///
    /// Per T-06-01: Uses `kSecAttrAccessibleWhenUnlocked` for security.
    /// If a key already exists for the provider, throws `KeychainError.writeFailed`.
    ///
    /// - Parameters:
    ///   - key: The API key string to store.
    ///   - provider: The cloud provider identifier.
    /// - Throws: ``KeychainError`` if Keychain storage fails.
    #if os(macOS) || os(iOS)
    public func store(key: String, for provider: CloudProvider) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(OSStatus: status)
        }
    }
    #else
    public func store(key: String, for provider: CloudProvider) async throws {
        // Linux fallback: should use MockAPIKeyStore in tests
        fatalError("APIKeyStore requires macOS/iOS Security framework")
    }
    #endif

    /// Retrieves an API key from Keychain for the given provider.
    ///
    /// - Parameter provider: The cloud provider identifier.
    /// - Returns: The API key string, or `nil` if no key is stored.
    /// - Throws: ``KeychainError`` if Keychain read fails (except `errSecItemNotFound`).
    #if os(macOS) || os(iOS)
    public func fetch(provider: CloudProvider) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: provider.keychainAccount,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.readFailed(OSStatus: status)
        }

        return String(data: data, encoding: .utf8)
    }
    #else
    public func fetch(provider: CloudProvider) async throws -> String? {
        fatalError("APIKeyStore requires macOS/iOS Security framework")
    }
    #endif

    /// Deletes an API key from Keychain for the given provider.
    ///
    /// - Parameter provider: The cloud provider identifier.
    /// - Throws: ``KeychainError`` if Keychain deletion fails.
    #if os(macOS) || os(iOS)
    public func delete(provider: CloudProvider) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: provider.keychainAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(OSStatus: status)
        }
    }
    #else
    public func delete(provider: CloudProvider) async throws {
        fatalError("APIKeyStore requires macOS/iOS Security framework")
    }
    #endif
}

// MARK: - MockAPIKeyStore (Linux Tests)

/// In-memory mock of APIKeyStore for Linux tests.
///
/// Phase 06-01 Task 2: Provides Linux-compatible test double that matches
/// APIKeyStore behavior. Used in CI tests where Security framework is unavailable.
public struct MockAPIKeyStore: Sendable {
    private var storage: [String: String] = [:]

    /// Stores an API key in memory.
    public mutating func store(key: String, for provider: CloudProvider) async throws {
        let account = provider.keychainAccount
        if storage[account] != nil {
            throw KeychainError.writeFailed(OSStatus: 1)
        }
        storage[account] = key
    }

    /// Retrieves an API key from memory.
    public func fetch(provider: CloudProvider) async throws -> String? {
        return storage[provider.keychainAccount]
    }

    /// Deletes an API key from memory.
    public mutating func delete(provider: CloudProvider) async throws {
        storage[provider.keychainAccount] = nil
    }
}

// MARK: - CloudProvider Extension

extension CloudProvider {
    /// Keychain account identifier for this provider.
    ///
    /// Phase 06-01: Maps enum cases to stable Keychain account keys.
    /// Used by APIKeyStore for SecItemAdd/SecItemCopyMatching queries.
    var keychainAccount: String {
        return "provider-\(self.rawValue)"
    }
}

// MARK: - KeychainError

/// Errors thrown by Keychain operations.
///
/// Phase 06-01 Task 2: Wraps Security framework OSStatus codes with
/// semantic error types for clearer error handling.
public enum KeychainError: Error, Sendable {
    /// SecItemAdd returned a non-success status.
    case writeFailed(OSStatus: Int32)
    /// SecItemCopyMatching returned a non-success status (except `errSecItemNotFound`).
    case readFailed(OSStatus: Int32)
    /// SecItemDelete returned a non-success status (except `errSecItemNotFound`).
    case deleteFailed(OSStatus: Int32)
}
