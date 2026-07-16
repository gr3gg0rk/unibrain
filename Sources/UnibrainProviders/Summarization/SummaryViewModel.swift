import Foundation
import UnibrainCore

/// Abstraction over ``OllamaHealthCheck`` enabling test injection.
public protocol HealthChecking: Sendable {
    func check() async -> Bool
}

extension OllamaHealthCheck: HealthChecking {}

/// LLM provider selection for ``SummaryViewModel``.
public enum LLMProvider: String, Sendable, CaseIterable {
    case off
    case ollama
    case openai
    case anthropic
    case grok
    case zai
}

/// View model orchestrating summarization requests from the UI.
///
/// Per SUMM-02: `isEnabled` defaults to false (off by default).
/// Per SUMM-07: relies on ``OllamaLLMSummarizer`` to enforce ModelLoadGate.
/// Per CF-02: runs a health check before invoking the summarizer to give
/// the user a fast failure path.
public final class SummaryViewModel: @unchecked Sendable {

    public var isEnabled: Bool = false
    public var selectedProvider: LLMProvider = .off

    private let summarizer: OllamaLLMSummarizer
    private let healthCheck: any HealthChecking

    public init(
        summarizer: OllamaLLMSummarizer = OllamaLLMSummarizer(),
        healthCheck: any HealthChecking = OllamaHealthCheck()
    ) {
        self.summarizer = summarizer
        self.healthCheck = healthCheck
    }

    /// Generates a summary by invoking the configured summarizer.
    ///
    /// - Throws:
    ///   - ``ProviderError/cancelled`` when summarization is disabled.
    ///   - ``ProviderError/unsupportedPlatform`` when the selected provider
    ///     is not Ollama (cloud providers are not in this plan).
    ///   - ``ProviderError/providerUnreachable`` when the Ollama health
    ///     check fails.
    public func generateSummary(
        transcript: String,
        courseContext: CourseContext
    ) async throws -> String {
        guard isEnabled else { throw ProviderError.cancelled }
        guard selectedProvider == .ollama else { throw ProviderError.unsupportedPlatform }

        let reachable = await healthCheck.check()
        guard reachable else {
            throw ProviderError.providerUnreachable(host: "localhost:11434")
        }

        return try await summarizer.summarize(transcript)
    }
}
