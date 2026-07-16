import Foundation

#if os(macOS) || os(iOS)
import Security
#endif

/// Persists security-scoped bookmarks for user-picked vault folders.
///
/// Per ONBD-04 / ONB-03: After the user picks a vault folder via `.fileImporter`,
/// the URL is persisted as a security-scoped bookmark so the app retains
/// filesystem access across launches.
///
/// Per T-05-01 (mitigate): Bookmarks are stored in Keychain (SecItemAdd with
/// `kSecAttrAccessibleWhenUnlocked`), NEVER in UserDefaults — bookmarks grant
/// filesystem access and must be treated as sensitive.
///
/// Per T-05-03 (mitigate): `resolve()` checks `bookmarkDataIsStale` and returns
/// `nil` when stale so the caller can re-prompt the user to pick the folder.
/// `startAccessingSecurityScopedResource()` is called before returning the URL.
///
/// Per IC-01: Stores per-device in Keychain — paths differ between macOS and iOS
/// even for the "same" iCloud Drive folder.
///
/// All Keychain calls are guarded by `#if os(macOS) || os(iOS)` since SecItem
/// APIs are unavailable on Linux.
public final class BookmarkStore: @unchecked Sendable {

    /// Keychain service identifier for unibrain vault bookmarks.
    private static let keychainService = "app.unibrain"

    /// Keychain account key for the vault bookmark.
    private static let keychainAccount = "vault_bookmark"

    // MARK: - Public API

    /// Saves a security-scoped bookmark for the given URL.
    ///
    /// Per ONB-03: Called after the user picks a folder via `.fileImporter`.
    /// Encodes the URL as bookmark data with `.withSecurityScope` options,
    /// then stores the data in Keychain as a generic password item.
    ///
    /// Per T-05-01: Stored in Keychain with `kSecAttrAccessibleWhenUnlocked`.
    ///
    /// - Parameter url: The user-picked folder URL to persist.
    /// - Throws: An error if bookmark creation or Keychain storage fails.
    public static func save(for url: URL) throws {
        #if os(macOS) || os(iOS)
        let bookmarkData = try url.bookmark(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        try saveToKeychain(bookmarkData)
        #endif
    }

    /// Resolves the stored bookmark to a URL.
    ///
    /// Per T-05-03: Checks `bookmarkDataIsStale` — if stale, returns `nil` so
    /// the caller re-prompts the user to pick the folder.
    ///
    /// After resolving, calls `url.startAccessingSecurityScopedResource()` to
    /// gain access to the sandboxed path.
    ///
    /// - Returns: The resolved URL with security-scoped access started,
    ///   or `nil` if no bookmark exists or the bookmark is stale.
    public static func resolve() -> URL? {
        #if os(macOS) || os(iOS)
        guard let data = loadFromKeychain() else { return nil }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                // Per T-05-03: stale bookmark — caller must re-prompt.
                return nil
            }
            // Per T-05-03: start security-scoped access before returning.
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Removes the stored bookmark from Keychain.
    ///
    /// Called when the user picks a new folder (replaces the old bookmark)
    /// or when clearing app state.
    public static func clear() {
        #if os(macOS) || os(iOS)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        #endif
    }

    // MARK: - Keychain Helpers (macOS/iOS only)

    #if os(macOS) || os(iOS)
    /// Saves bookmark data to Keychain as a generic password item.
    ///
    /// Per T-05-01: Uses `kSecAttrAccessibleWhenUnlocked` for security.
    /// If an item already exists, it is deleted before inserting the new one.
    private static func saveToKeychain(_ data: Data) throws {
        // Delete any existing bookmark first.
        clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BookmarkStoreError.keychainSaveFailed(status: status)
        }
    }

    /// Loads bookmark data from Keychain.
    ///
    /// - Returns: The bookmark `Data`, or `nil` if no item exists.
    private static func loadFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }
    #endif
}

// MARK: - Errors

/// Errors thrown by BookmarkStore operations.
public enum BookmarkStoreError: Error, Equatable {
    /// Keychain SecItemAdd returned a non-success status.
    case keychainSaveFailed(status: Int32)
}
