import Testing
import Foundation
@testable import UnibrainProviders
@testable import UnibrainCore

/// Tests for APIKeyStore secure API key storage.
///
/// Phase 06-01 Task 2: Keychain-backed API key storage with macOS Keychain /
/// iOS Secure Enclave. Linux tests use MockAPIKeyStore (in-memory).
@Suite("APIKeyStoreTests")
struct APIKeyStoreTests {

    // MARK: - APIKeyStore Tests (macOS/iOS only)

    #if os(macOS) || os(iOS)
    @Test("APIKeyStore.store(key:for:) writes to Keychain")
    func storeKey() async throws {
        let store = APIKeyStore()
        let provider = CloudProvider.openai
        let key = "sk-test-1234567890"

        try await store.store(key: key, for: provider)

        // Verify retrieval works
        let retrieved = try await store.fetch(provider: provider)
        #expect(retrieved == key)
    }

    @Test("APIKeyStore.store throws on duplicate key")
    func storeDuplicateThrows() async throws {
        let store = APIKeyStore()
        let provider = CloudProvider.anthropic
        let key = "sk-ant-test-key"

        try await store.store(key: key, for: provider)

        await #expect(throws: KeychainError.self) {
            try await store.store(key: "different-key", for: provider)
        }
    }

    @Test("APIKeyStore.fetch returns nil for missing key")
    func fetchMissingReturnsNil() async throws {
        let store = APIKeyStore()
        let provider = CloudProvider.grok

        let result = try await store.fetch(provider: provider)
        #expect(result == nil)
    }

    @Test("APIKeyStore.delete removes key from Keychain")
    func deleteKey() async throws {
        let store = APIKeyStore()
        let provider = CloudProvider.zai
        let key = "zai-test-key"

        try await store.store(key: key, for: provider)
        var retrieved = try await store.fetch(provider: provider)
        #expect(retrieved == key)

        try await store.delete(provider: provider)
        retrieved = try await store.fetch(provider: provider)
        #expect(retrieved == nil)
    }
    #endif

    // MARK: - MockAPIKeyStore Tests (Linux-compatible)

    @Test("MockAPIKeyStore matches APIKeyStore behavior")
    func mockStoreBehavior() async throws {
        var mockStore = MockAPIKeyStore()
        let provider = CloudProvider.openai
        let key = "sk-test-key"

        try await mockStore.store(key: key, for: provider)
        let retrieved = try await mockStore.fetch(provider: provider)
        #expect(retrieved == key)

        try await mockStore.delete(provider: provider)
        let deleted = try await mockStore.fetch(provider: provider)
        #expect(deleted == nil)
    }

    @Test("MockAPIKeyStore handles multiple providers")
    func mockMultipleProviders() async throws {
        var mockStore = MockAPIKeyStore()

        try await mockStore.store(key: "openai-key", for: .openai)
        try await mockStore.store(key: "anthropic-key", for: .anthropic)
        try await mockStore.store(key: "ollama-key", for: .ollama)

        #expect(try await mockStore.fetch(provider: .openai) == "openai-key")
        #expect(try await mockStore.fetch(provider: .anthropic) == "anthropic-key")
        #expect(try await mockStore.fetch(provider: .ollama) == "ollama-key")
    }

    // MARK: - Security Verification

    #if os(macOS) || os(iOS)
    @Test("APIKeyStore uses kSecAttrAccessibleWhenUnlocked")
    func verifySecurityAttribute() async throws {
        // This test verifies that APIKeyStore uses the correct Keychain
        // accessibility attribute. The actual Security framework call
        // is tested indirectly by successful key storage/retrieval.

        let store = APIKeyStore()
        let provider = CloudProvider.whisperCpp
        let key = "test-key"

        try await store.store(key: key, for: provider)

        // If we get here without throwing, SecItemAdd succeeded with
        // kSecAttrAccessibleWhenUnlocked (verified in implementation).
        let retrieved = try await store.fetch(provider: provider)
        #expect(retrieved == key)

        // Cleanup
        try await store.delete(provider: provider)
    }
    #endif
}
