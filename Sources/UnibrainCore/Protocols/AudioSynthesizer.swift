import Foundation

/// Protocol for single-shot audio synthesis (text-to-speech).
///
/// Per D-15: standalone protocol with no common ancestor.
/// Per D-17: single-shot only in Phase 1.
public protocol AudioSynthesizer {
    associatedtype Request
    associatedtype Response

    /// Synthesize audio from the given text request.
    ///
    /// - Parameter request: Provider-specific request payload (e.g., text input).
    /// - Returns: Provider-specific response payload (e.g., audio data).
    /// - Throws: ``ProviderError`` on failure.
    func synthesize(_ request: Request) async throws -> Response
}
