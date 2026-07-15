import Foundation
import UnibrainCore

#if canImport(Speech)
import Speech
#endif

/// Apple SpeechAnalyzer primary ASR adapter (macOS 26+).
///
/// Per CONTEXT P-01: SpeechAnalyzer is the PRIMARY ASR engine. Apple's WWDC 2025
/// `SpeechAnalyzer` framework runs first for every recording. Zero third-party
/// dependencies, Apple Intelligence-powered, A-series Neural Engine native,
/// no model download needed (model ships with the OS).
///
/// Per P-07: SpeechAnalyzer does NOT need ModelLoadGate — the Apple Intelligence
/// model is OS-managed, not app-loaded.
///
/// Per N-03: returns `[(start: TimeInterval, end: TimeInterval, text: String)]` —
/// the abstract timed-segment shape that `NoteNormalizer` consumes.
///
/// On non-macOS platforms (Linux CI) or macOS < 26, this transcriber throws
/// `.unsupportedPlatform`.
public struct SpeechAnalyzerTranscriber: PipelineTranscriber, Sendable {
    /// Creates a SpeechAnalyzer transcriber.
    ///
    /// SpeechAnalyzer is OS-managed (P-07) — no model path or ModelLoadGate needed.
    public init() {}

    public func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        #if os(macOS)
        guard #available(macOS 26, *) else {
            throw ProviderError.unsupportedPlatform
        }
        return try await transcribeMacOS26(audioURL)
        #else
        // On non-macOS (Linux CI), SpeechAnalyzer is not available
        throw ProviderError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    @available(macOS 26, *)
    /// macOS 26+ transcription using Apple's SpeechAnalyzer framework.
    ///
    /// This method isolates the SpeechAnalyzer API calls so that API shape changes
    /// (Pitfall 1 from RESEARCH) are contained within this adapter.
    private func transcribeMacOS26(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        // Per RESEARCH Pitfall 1: SpeechAnalyzer is a WWDC 2025 / macOS 26 API.
        // Exact method signatures are verified at build time against the macOS 26 SDK.
        //
        // Conceptual flow (from AI-SPEC §3):
        // 1. Create SpeechAnalyzer instance (OS-managed, no ModelLoadGate)
        // 2. Call Apple Speech API to transcribe audioURL
        // 3. Map SpeechTranscriber output to [(start, end, text)] format
        //
        // NOTE: The exact SpeechAnalyzer API shape will be validated on a
        // macOS 26 CI runner. On WSL2, this code path is unreachable
        // (guarded by #if os(macOS) and #available(macOS 26, *)).

        // TODO: Wire SpeechAnalyzer API once macOS 26 CI validates the import.
        throw ProviderError.modelError("SpeechAnalyzer binding not yet wired — requires macOS 26 CI validation")
    }
    #endif
}
