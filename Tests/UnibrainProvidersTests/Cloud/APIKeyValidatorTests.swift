import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

/// Tests for APIKeyValidator (T-06-24 mitigation).
///
/// Phase 06-05 Task 2: Verifies that API key format validation rejects
/// malformed keys and accepts valid prefixes per provider. This is the
/// security-critical path that prevents storing garbage or spoofed keys.
@Suite("APIKeyValidator")
struct APIKeyValidatorTests {

    // MARK: - OpenAI

    @Test("OpenAI keys: sk-* prefix accepted, others rejected")
    func openAIKeyValidation() {
        #expect(APIKeyValidator.isValid("sk-abc123xyz", for: .openai))
        #expect(APIKeyValidator.isValid("sk-proj-abc123", for: .openai))
        #expect(!APIKeyValidator.isValid("abc123", for: .openai))
        // Permissive prefix match by design — Keychain stores whatever the user enters
        // with a valid prefix. Length enforcement is not part of T-06-24 mitigation.
        #expect(APIKeyValidator.isValid("sk-", for: .openai))
        #expect(!APIKeyValidator.isValid("", for: .openai))
    }

    // MARK: - Anthropic

    @Test("Anthropic keys: sk-ant-* prefix accepted, others rejected")
    func anthropicKeyValidation() {
        #expect(APIKeyValidator.isValid("sk-ant-api03-abc123", for: .anthropic))
        #expect(!APIKeyValidator.isValid("sk-abc123", for: .anthropic))
        #expect(!APIKeyValidator.isValid("abc123", for: .anthropic))
        #expect(!APIKeyValidator.isValid("", for: .anthropic))
    }

    // MARK: - Grok (X)

    @Test("Grok keys: xai-* prefix accepted, others rejected")
    func grokKeyValidation() {
        #expect(APIKeyValidator.isValid("xai-abc123xyz", for: .grok))
        #expect(!APIKeyValidator.isValid("sk-abc123", for: .grok))
        #expect(!APIKeyValidator.isValid("abc", for: .grok))
        #expect(!APIKeyValidator.isValid("", for: .grok))
    }

    // MARK: - Z.ai

    @Test("Z.ai keys: 16+ character minimum accepted, short rejected")
    func zaiKeyValidation() {
        #expect(APIKeyValidator.isValid("0123456789abcdef", for: .zai))
        #expect(APIKeyValidator.isValid("0123456789abcdef0123456789abcdef", for: .zai))
        #expect(!APIKeyValidator.isValid("short", for: .zai))
        #expect(!APIKeyValidator.isValid("0123456789abcde", for: .zai)) // 15 chars
        #expect(!APIKeyValidator.isValid("", for: .zai))
    }

    // MARK: - Local Providers

    @Test("Local providers (Ollama, whisper.cpp) always reject keys")
    func localProviderRejection() {
        #expect(!APIKeyValidator.isValid("sk-abc123", for: .ollama))
        #expect(!APIKeyValidator.isValid("any-key-here", for: .ollama))
        #expect(!APIKeyValidator.isValid("sk-abc123", for: .whisperCpp))
        #expect(!APIKeyValidator.isValid("any-key-here", for: .whisperCpp))
        #expect(!APIKeyValidator.isValid("", for: .ollama))
        #expect(!APIKeyValidator.isValid("", for: .whisperCpp))
    }
}
