import Foundation
import UnibrainCore

#if canImport(AVFoundation)
import AVFoundation
#endif

/// whisper.cpp + Metal fallback ASR adapter.
///
/// Per CONTEXT P-02: whisper.cpp with the small.en model is the FALLBACK ASR,
/// auto-triggered when SpeechAnalyzer fails. Uses Metal acceleration on Apple Silicon.
///
/// Per TRAN-06 / P-07: acquires `ModelLoadGate.shared.acquire(.asr)` before loading
/// the model, and releases via `defer` after transcription (success or failure).
///
/// Per N-03: returns `[(start: TimeInterval, end: TimeInterval, text: String)]` —
/// the abstract timed-segment shape that `NoteNormalizer` consumes.
///
/// On non-macOS platforms (Linux CI), this transcriber throws `.unsupportedPlatform`.
public struct WhisperCppTranscriber: PipelineTranscriber, Sendable {
    /// Path to the ggml-small.en.bin model file.
    private let modelPath: URL

    /// The model load gate enforcing 8GB RAM discipline.
    private let gate: ModelLoadGate

    /// Creates a whisper.cpp transcriber.
    ///
    /// - Parameters:
    ///   - modelPath: File URL pointing to ggml-small.en.bin on disk.
    ///   - gate: The ModelLoadGate to acquire/release around model loading.
    ///           Defaults to `.shared` for app-wide use.
    public init(modelPath: URL, gate: ModelLoadGate = .shared) {
        self.modelPath = modelPath
        self.gate = gate
    }

    public func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        // Per TRAN-06 / P-07: acquire gate before loading model
        let lease = try await gate.acquire(.asr)
        defer { Task { await lease.release() } }

        // Verify model file exists before attempting to load
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw ProviderError.modelError("whisper.cpp model not found at \(modelPath.path)")
        }

        // Per TRAN-03: this method is async, callable from Task.detached.
        // The actual whisper.cpp inference happens on macOS.
        #if os(macOS)
        return try await transcribeMacOS(audioURL)
        #else
        // On non-macOS (Linux CI), whisper.cpp is not available
        throw ProviderError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    /// macOS-specific transcription using whisper.cpp with Metal acceleration.
    ///
    /// This method isolates the whisper.cpp C API calls so that API changes
    /// are contained within this adapter (Pitfall 1 pattern from RESEARCH).
    private func transcribeMacOS(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        // Per Pitfall 2 (RESEARCH): whisper.cpp SPM integration with Swift 6
        // The actual whisper.cpp binding will be wired here when the SPM
        // dependency compiles on the macOS CI runner.
        //
        // Conceptual flow (from AI-SPEC §3):
        // 1. Load whisper context from modelPath
        // 2. Configure: language=en, translate=false, greedy (temperature 0)
        // 3. Run Metal-accelerated inference
        // 4. Map whisper segments to [(start, end, text)]
        //
        // The whisper.cpp SPM package provides the C API via module import.
        // This adapter bridges C types to Swift's typed output.
        //
        // NOTE: The exact whisper.cpp SPM import and API shape will be
        // validated on the macOS CI runner. On WSL2, this code path
        // is unreachable (guarded by #if os(macOS)).

        // TODO: Wire whisper.cpp SPM API once macOS CI validates the import.
        // For now, throw modelError to indicate the binding needs macOS CI verification.
        throw ProviderError.modelError("whisper.cpp binding not yet wired — requires macOS CI validation")
    }
    #endif
}
