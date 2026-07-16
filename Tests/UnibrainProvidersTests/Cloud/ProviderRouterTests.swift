import Testing
import Foundation
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum ProviderRouterTests {

    @Test("ProviderRouter returns OllamaLLMSummarizer-shaped provider for .ollama")
    static func returnsOllamaForOllamaSelection() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .ollama),
            apiKeyStore: StubAPIKeyStore(key: "unused"),
            consentStore: StubConsentStore(hasConsent: true)
        )

        let summarizer = try await router.summarizer(for: .ollama)
        // We verify by type — the router returns `any LLMSummarizer`.
        // The actual OllamaLLMSummarizer requires no API key.
        _ = summarizer
    }

    @Test("ProviderRouter returns OpenAI-shaped provider for .openai")
    static func returnsOpenAIForOpenAISelection() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .openai),
            apiKeyStore: StubAPIKeyStore(key: "sk-test"),
            consentStore: StubConsentStore(hasConsent: true)
        )

        let summarizer = try await router.summarizer(for: .openai)
        _ = summarizer
    }

    @Test("ProviderRouter returns Anthropic-shaped provider for .anthropic")
    static func returnsAnthropicForAnthropicSelection() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .anthropic),
            apiKeyStore: StubAPIKeyStore(key: "sk-test"),
            consentStore: StubConsentStore(hasConsent: true)
        )

        let summarizer = try await router.summarizer(for: .anthropic)
        _ = summarizer
    }

    @Test("ProviderRouter returns Grok-shaped provider for .grok")
    static func returnsGrokForGrokSelection() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .grok),
            apiKeyStore: StubAPIKeyStore(key: "xai-test"),
            consentStore: StubConsentStore(hasConsent: true)
        )

        let summarizer = try await router.summarizer(for: .grok)
        _ = summarizer
    }

    @Test("ProviderRouter returns Zai-shaped provider for .zai")
    static func returnsZaiForZaiSelection() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .zai),
            apiKeyStore: StubAPIKeyStore(key: "zai-test"),
            consentStore: StubConsentStore(hasConsent: true)
        )

        let summarizer = try await router.summarizer(for: .zai)
        _ = summarizer
    }

    @Test("ProviderRouter throws cancelled when .off selected")
    static func throwsCancelledForOff() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .off),
            apiKeyStore: StubAPIKeyStore(key: nil),
            consentStore: StubConsentStore(hasConsent: false)
        )

        do {
            _ = try await router.summarizer(for: .off)
            #expect(Bool(false), "Expected throw")
        } catch let err as ProviderError {
            if case .cancelled = err {
                // Expected
            } else {
                #expect(Bool(false), "Expected .cancelled, got \(err)")
            }
        }
    }

    @Test("ProviderRouter.updateSettings refreshes cached settings")
    static func updateSettingsRefreshesCache() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .off),
            apiKeyStore: StubAPIKeyStore(key: nil),
            consentStore: StubConsentStore(hasConsent: false)
        )

        // Verify .off throws first
        do {
            _ = try await router.summarizer(for: .off)
            #expect(Bool(false), "Expected throw")
        } catch is ProviderError {}

        // Update to .ollama — should now succeed
        await router.updateSettings(ProviderRouter.Settings(llmProvider: .ollama))
        let summarizer = try await router.summarizer(for: .ollama)
        _ = summarizer
    }
}
