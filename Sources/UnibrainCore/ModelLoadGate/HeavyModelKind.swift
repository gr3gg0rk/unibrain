import Foundation

/// The kind of heavy local model that occupies RAM on the 8GB device.
///
/// Per D-12: the ModelLoadGate tracks only local heavy models.
/// Cloud providers bypass the gate entirely — they do not count
/// toward local RAM.
///
/// Future phases may add `.vision` if a heavy local vision model
/// is introduced (Phase 2 vision ingestion).
public enum HeavyModelKind: String, Sendable {
    /// Audio transcription model (e.g., whisper.cpp small.en, ~852 MB).
    case asr
    /// LLM summarization model (e.g., Ollama llama-3.2-3b, ~4-5 GB).
    case llm

    // MARK: - Phase 06-01 Addition

    /// Ollama local LLM (specific variant for SUMM-07 gate enforcement).
    ///
    /// Phase 06-01: Distinguishes Ollama from generic `.llm` for
    /// ModelLoadGate conflict detection. While Ollama is technically
    /// an LLM, this case enables explicit gate checks for SUMM-07
    /// (refuse to run while ASR is loaded).
    case ollama
}
