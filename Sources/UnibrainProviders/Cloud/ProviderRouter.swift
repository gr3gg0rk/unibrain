import Foundation
import UnibrainCore

/// Per-modality provider router for LLM summarization.
///
/// Per CLOUD-01 and CLOUD-09: reads Settings to determine which provider to
/// dispatch to. The router itself conforms to no protocol — it returns
/// `any LLMSummarizer` instances on demand.
///
/// Per 06-CONTEXT.md (per-modality routers): this is the LLM router. Future
/// phases add ASRProvider, VisionProvider, TTSProvider routers.
///
/// The router holds a cached settings snapshot and a factory that constructs
/// provider clients with their dependencies (APIKeyStore, ConsentStore,
/// TCPReachability, RetryComposer). Settings can be refreshed via
/// ``updateSettings(_:)`` when the UI changes.
public actor ProviderRouter {

    /// Snapshot of user Settings relevant to provider routing.
    public struct Settings: Sendable {
        public let llmProvider: LLMProvider
        // Future: asrProvider, visionProvider, ttsProvider
        public init(llmProvider: LLMProvider = .off) {
            self.llmProvider = llmProvider
        }
    }

    /// Cached settings snapshot. Updated via ``updateSettings(_:)``.
    private var settings: Settings

    /// API key store (shared across all providers).
    private let apiKeyStore: any APIKeyStoring

    /// Consent store (shared across all providers).
    private let consentStore: any ConsentStoring

    public init(
        settings: Settings = Settings(),
        apiKeyStore: any APIKeyStoring,
        consentStore: any ConsentStoring
    ) {
        self.settings = settings
        self.apiKeyStore = apiKeyStore
        self.consentStore = consentStore
    }

    /// Refreshes the cached settings snapshot.
    ///
    /// Called by the Settings UI when the user changes the provider picker.
    public func updateSettings(_ newSettings: Settings) {
        self.settings = newSettings
    }

    /// Returns the ``LLMSummarizer`` for the given provider.
    ///
    /// - Parameter provider: The selected LLM provider.
    /// - Returns: A configured summarizer for the provider.
    /// - Throws: ``ProviderError/cancelled`` when `provider` is `.off`.
    public func summarizer(for provider: LLMProvider) async throws -> any LLMSummarizer {
        switch provider {
        case .off:
            throw ProviderError.cancelled
        case .ollama:
            return OllamaLLMSummarizer()
        case .openai:
            return OpenAILLMSummarizer(
                apiKeyStore: apiKeyStore,
                consentStore: consentStore
            )
        case .anthropic:
            return AnthropicLLMSummarizer(
                apiKeyStore: apiKeyStore,
                consentStore: consentStore
            )
        case .grok:
            return GrokLLMSummarizer(
                apiKeyStore: apiKeyStore,
                consentStore: consentStore
            )
        case .zai:
            return ZaiLLMSummarizer(
                apiKeyStore: apiKeyStore,
                consentStore: consentStore
            )
        }
    }
}
