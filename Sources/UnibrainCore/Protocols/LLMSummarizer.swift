import Foundation

/// Protocol for single-shot LLM text summarization.
///
/// Per D-15: standalone protocol with no common ancestor.
/// Per D-17: single-shot only in Phase 1 (no streaming).
/// A concrete conformance calls the provider once and returns a complete response.
public protocol LLMSummarizer {
    associatedtype Request
    associatedtype Response

    /// Summarize the given request payload and return the full response.
    ///
    /// - Parameter request: Provider-specific request payload.
    /// - Returns: Provider-specific response payload.
    /// - Throws: ``ProviderError`` on failure.
    func summarize(_ request: Request) async throws -> Response
}
