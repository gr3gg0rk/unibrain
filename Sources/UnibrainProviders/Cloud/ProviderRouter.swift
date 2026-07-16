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
/// Phase 06-04 Task 5: The router now depends on `ConsentViewModel` and
/// `FailureRecoveryViewModel`. Before returning a cloud summarizer it checks
/// consent (CON-01) and throws `ProviderError.consentDenied` when missing.
/// `fallbackSummarizer(for:)` returns the local provider for a modality, and
/// `executeWithRecovery(provider:modality:operation:)` wraps an operation so
/// the UI can build a `CloudFailureContext` on failure.
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

    /// Phase 06-04: Consent gate for first-use provider×modality (CON-01).
    private let consentViewModel: ConsentViewModel?

    /// Phase 06-04: Failure recovery reference for fallback selection.
    private let failureRecovery: FailureRecoveryViewModel?

    /// Phase 06-03 original initializer (preserved for existing call sites).
    public init(
        settings: Settings = Settings(),
        apiKeyStore: any APIKeyStoring,
        consentStore: any ConsentStoring
    ) {
        self.settings = settings
        self.apiKeyStore = apiKeyStore
        self.consentStore = consentStore
        self.consentViewModel = nil
        self.failureRecovery = nil
    }

    /// Phase 06-04 initializer with consent gate and failure recovery.
    ///
    /// Per CON-01: When `consentViewModel` is non-nil, `summarizer(for:)`
    /// checks consent before returning a cloud provider and throws
    /// `.consentDenied(provider:modality:)` when missing.
    public init(
        settings: Settings = Settings(),
        apiKeyStore: any APIKeyStoring,
        consentStore: any ConsentStoring,
        consentViewModel: ConsentViewModel,
        failureRecovery: FailureRecoveryViewModel
    ) {
        self.settings = settings
        self.apiKeyStore = apiKeyStore
        self.consentStore = consentStore
        self.consentViewModel = consentViewModel
        self.failureRecovery = failureRecovery
    }

    /// Refreshes the cached settings snapshot.
    ///
    /// Called by the Settings UI when the user changes the provider picker.
    public func updateSettings(_ newSettings: Settings) {
        self.settings = newSettings
    }

    /// Returns the ``LLMSummarizer`` for the given provider.
    ///
    /// Phase 06-04 Task 5: When `consentViewModel` is set (cloud providers),
    /// consent is checked first per CON-01. Missing consent throws
    /// `ProviderError.consentDenied`.
    ///
    /// - Parameter provider: The selected LLM provider.
    /// - Returns: A configured summarizer for the provider.
    /// - Throws: ``ProviderError/cancelled`` when `provider` is `.off`.
    ///           ``ProviderError/consentDenied`` when consent missing.
    public func summarizer(for provider: LLMProvider) async throws -> any LLMSummarizer {
        switch provider {
        case .off:
            throw ProviderError.cancelled
        case .ollama:
            // Local provider — consent not required (local-first default)
            return OllamaLLMSummarizer()
        case .openai, .anthropic, .grok, .zai:
            // Cloud providers — consent gate (CON-01)
            if let consentVM = consentViewModel {
                let cloudProvider = cloudProviderMapping(for: provider)
                let shouldShowConsent = await consentVM.shouldShowConsent(
                    provider: cloudProvider,
                    modality: .llm
                )
                if shouldShowConsent {
                    throw ProviderError.consentDenied(
                        provider: cloudProvider,
                        modality: .llm
                    )
                }
            }
            return makeCloudSummarizer(for: provider)
        }
    }

    /// Returns a fallback local summarizer for the given modality (CF-01).
    ///
    /// Phase 06-04 Task 5: Used by `executeWithRecovery` and the UI when the
    /// user taps "Fall back to local". Per 06-CONTEXT.md:
    /// - `.llm` → Ollama
    /// - `.asr` → whisper.cpp (not yet wired in MVP — throws `.cancelled`)
    /// - `.vision`, `.tts` → throws `.cancelled` (no local fallback in MVP)
    public func fallbackSummarizer(for modality: Modality) async throws -> any LLMSummarizer {
        guard let recovery = failureRecovery else {
            throw ProviderError.cancelled
        }
        guard let fallback = recovery.fallbackProvider(for: modality) else {
            throw ProviderError.cancelled
        }
        switch fallback {
        case .ollama:
            return OllamaLLMSummarizer()
        case .whisperCpp, .openai, .anthropic, .grok, .zai:
            // whisper.cpp is an ASR provider, not an LLMSummarizer.
            // For LLM modality the only fallback is Ollama; for ASR, the
            // caller (TranscriberRouter, future phase) handles it.
            throw ProviderError.cancelled
        }
    }

    /// Wraps a provider operation so failures can be surfaced via the
    /// CloudFailureSheet (CF-01).
    ///
    /// Phase 06-04 Task 5: The caller (e.g., SummaryViewModel) supplies the
    /// provider and an operation closure. If the operation throws, this
    /// method rethrows the error — the caller is responsible for constructing
    /// a `CloudFailureContext` from the caught error and presenting the sheet.
    /// The wrapper exists so callers don't have to repeat the provider/modality
    /// context; future iterations can route the error through a delegate.
    public func executeWithRecovery<T: Sendable>(
        provider: CloudProvider,
        modality: Modality,
        operation: @Sendable (any LLMSummarizer) async throws -> T
    ) async throws -> T {
        let llmProvider = llmProviderMapping(for: provider)
        let summarizer = try await self.summarizer(for: llmProvider)
        do {
            return try await operation(summarizer)
        } catch {
            // Propagate — caller builds CloudFailureContext and presents sheet
            throw error
        }
    }

    // MARK: - Private Helpers

    /// Map LLMProvider enum → CloudProvider enum for consent/error reporting.
    private func cloudProviderMapping(for provider: LLMProvider) -> CloudProvider {
        switch provider {
        case .off: return .ollama
        case .ollama: return .ollama
        case .openai: return .openai
        case .anthropic: return .anthropic
        case .grok: return .grok
        case .zai: return .zai
        }
    }

    /// Map CloudProvider → LLMProvider (inverse of cloudProviderMapping).
    private func llmProviderMapping(for provider: CloudProvider) -> LLMProvider {
        switch provider {
        case .ollama: return .ollama
        case .openai: return .openai
        case .anthropic: return .anthropic
        case .grok: return .grok
        case .zai: return .zai
        case .whisperCpp: return .off
        }
    }

    /// Construct the cloud summarizer (after consent has been verified).
    private func makeCloudSummarizer(for provider: LLMProvider) -> any LLMSummarizer {
        switch provider {
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
        case .off, .ollama:
            // Defensive — caller should have routed these elsewhere
            return OllamaLLMSummarizer()
        }
    }
}
