import Foundation

/// Protocol for single-shot audio transcription (speech-to-text).
///
/// Per D-15: standalone protocol with no common ancestor.
/// Per D-17: single-shot only in Phase 1 (transcript returned after full capture).
public protocol AudioTranscriber {
    associatedtype Request
    associatedtype Response

    /// Transcribe the given audio request and return the full transcript.
    ///
    /// - Parameter request: Provider-specific request payload (e.g., audio file URL).
    /// - Returns: Provider-specific response payload (e.g., transcript text).
    /// - Throws: ``ProviderError`` on failure.
    func transcribe(_ request: Request) async throws -> Response
}
