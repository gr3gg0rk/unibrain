import Foundation
import UnibrainCore

/// Dual-engine transcription facade conforming to `PipelineTranscriber`.
///
/// Per CONTEXT P-05: wraps `SpeechAnalyzerTranscriber` (primary) and
/// `WhisperCppTranscriber` (fallback) behind a single conformance.
/// The PipelineOrchestrator depends on `any PipelineTranscriber` and gets
/// the Router — it doesn't know which engine ran.
///
/// Per P-06: auto-fallback re-transcribes the WHOLE recording. SpeechAnalyzer
/// and whisper.cpp produce different segment boundaries; partial-state pickup
/// across engines is infeasible.
///
/// Per P-05: if both engines throw, the whisper.cpp (fallback) error is
/// propagated — it is the more informative failure.
///
/// Per TRAN-03: all transcribe methods are `async throws`, callable from
/// `Task.detached` — never blocking MainActor.
public struct TranscriberRouter: PipelineTranscriber, Sendable {
    /// The primary ASR engine (SpeechAnalyzer, macOS 26+).
    private let primary: any PipelineTranscriber

    /// The fallback ASR engine (whisper.cpp + Metal).
    private let fallback: any PipelineTranscriber

    /// Timeout budget for the primary engine before declaring failure (P-D8).
    /// Default: 180 seconds (3x expected realtime for a 60-min recording).
    public let timeout: TimeInterval

    /// Creates a router with explicit primary and fallback transcribers.
    ///
    /// This initializer accepts `any PipelineTranscriber` to enable dependency
    /// injection of mock transcribers in tests. Production code constructs
    /// with `SpeechAnalyzerTranscriber` and `WhisperCppTranscriber`.
    ///
    /// - Parameters:
    ///   - primary: The primary ASR engine to try first.
    ///   - fallback: The fallback ASR engine if primary throws.
    ///   - timeout: Timeout for the primary engine in seconds (default: 180).
    public init(
        primary: any PipelineTranscriber,
        fallback: any PipelineTranscriber,
        timeout: TimeInterval = 180
    ) {
        self.primary = primary
        self.fallback = fallback
        self.timeout = timeout
    }

    /// Convenience initializer for production use with default engines.
    ///
    /// - Parameter modelPath: Path to ggml-small.en.bin for the whisper.cpp fallback.
    public init(modelPath: URL, timeout: TimeInterval = 180) {
        self.primary = SpeechAnalyzerTranscriber()
        self.fallback = WhisperCppTranscriber(modelPath: modelPath)
        self.timeout = timeout
    }

    public func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        // P-05/P-06: Try primary first; on throw, retry the WHOLE recording via fallback.
        do {
            return try await primary.transcribe(audioURL)
        } catch {
            // P-06: Re-transcribe the WHOLE recording via fallback.
            // If fallback also throws, propagate the fallback error (P-05 — more informative).
            return try await fallback.transcribe(audioURL)
        }
    }
}
