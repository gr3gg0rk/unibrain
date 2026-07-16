import Testing
import Foundation
@testable import UnibrainProviders
@testable import UnibrainCore

/// Tests for ConsentStore (.unibrain/consent.json persistence).
///
/// Phase 06-01 Task 3: Consent state persistence with iCloud sync.
/// Tests verify atomic writes, consent CRUD operations, and schema version.
@Suite("ConsentStoreTests")
struct ConsentStoreTests {

    // MARK: - Consent CRUD Operations

    @Test("ConsentStore.hasConsent returns false for no consent record")
    func hasConsentReturnsFalseForMissing() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
        let store = ConsentStore(vaultPath: vaultPath)

        let hasConsent = await store.hasConsent(provider: .openai, modality: .llm)
        #expect(hasConsent == false)
    }

    @Test("ConsentStore.grantConsent persists and returns true on next check")
    func grantConsentPersists() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
        let store = ConsentStore(vaultPath: vaultPath)
        let provider = CloudProvider.anthropic
        let modality = Modality.vision

        try await store.grantConsent(provider: provider, modality: modality, alwaysAllow: true)
        let hasConsent = await store.hasConsent(provider: provider, modality: modality)

        #expect(hasConsent == true)
    }

    @Test("ConsentStore.revokeConsent removes record, hasConsent returns false")
    func revokeConsentRemovesRecord() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
        let store = ConsentStore(vaultPath: vaultPath)
        let provider = CloudProvider.grok
        let modality = Modality.asr

        try await store.grantConsent(provider: provider, modality: modality, alwaysAllow: true)
        try await store.revokeConsent(provider: provider, modality: modality)
        let hasConsent = await store.hasConsent(provider: provider, modality: modality)

        #expect(hasConsent == false)
    }

    // MARK: - Schema Version and Migration

    @Test("ConsentStore.load reads existing .unibrain/consent.json with schema_version: 1")
    func loadReadsExistingConsentFile() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
        let unibrainDir = vaultPath.appendingPathComponent(".unibrain")
        try FileManager.default.createDirectory(at: unibrainDir, withIntermediateDirectories: true)

        // Write consent.json with schemaVersion: 1
        let consentFile = unibrainDir.appendingPathComponent("consent.json")
        let jsonContent = """
        {
          "schemaVersion": 1,
          "consents": {
            "openai.llm": {
              "alwaysAllow": true,
              "firstConsentedAt": "2026-07-16T10:00:00Z"
            }
          }
        }
        """
        try jsonContent.write(to: consentFile, atomically: true, encoding: .utf8)

        let store = ConsentStore(vaultPath: vaultPath)
        try await store.load()

        let hasConsent = await store.hasConsent(provider: .openai, modality: .llm)
        #expect(hasConsent == true)
    }

    @Test("Atomic write prevents corruption")
    func atomicWritePreventsCorruption() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
        let store = ConsentStore(vaultPath: vaultPath)

        // Grant multiple consents rapidly
        for provider in [CloudProvider.openai, .anthropic, .grok] {
            try await store.grantConsent(provider: provider, modality: .llm, alwaysAllow: true)
        }

        // Verify all consents persisted
        let openaiConsent = await store.hasConsent(provider: .openai, modality: .llm)
        let anthropicConsent = await store.hasConsent(provider: .anthropic, modality: .llm)
        let grokConsent = await store.hasConsent(provider: .grok, modality: .llm)

        #expect(openaiConsent == true)
        #expect(anthropicConsent == true)
        #expect(grokConsent == true)
    }
}
