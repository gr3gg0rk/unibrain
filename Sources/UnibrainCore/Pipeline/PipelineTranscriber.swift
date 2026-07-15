import Foundation

/// Concrete protocol for audio transcription within the pipeline.
///
/// This protocol exists because ``AudioTranscriber`` uses associated types
/// (`Request`, `Response`), which makes it impossible to store as `any AudioTranscriber`.
/// The pipeline needs a concrete signature to call without generic context.
///
/// Phase 3's ASR adapter (whisper.cpp / SpeechAnalyzer) will conform to this
/// protocol, bridging from the provider-level `AudioTranscriber` to the
/// pipeline-level timed-segment contract.
///
/// Per N-03: Returns `[(start: TimeInterval, end: TimeInterval, text: String)]` —
/// the abstract timed-segment shape that `NoteNormalizer.normalize()` consumes.
public protocol PipelineTranscriber: Sendable {
    /// Transcribe the audio at the given URL into timed text segments.
    ///
    /// - Parameter audioURL: File URL of the audio recording.
    /// - Returns: Array of (start, end, text) tuples — abstract timed segments per N-03.
    /// - Throws: Provider-level error on failure.
    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)]
}

/// Concrete protocol for vault destination resolution within the pipeline.
///
/// The orchestrator needs to know WHERE to write the note. In production (Phase 3+4),
/// this resolves the matched course to a vault folder path. For Phase 2 testing,
/// a simple mock provides a temp directory.
///
/// Per C-02: When `CourseMatch` is `.single`, the resolver builds the vault path.
/// When `.multiple` or `.none`, the pipeline surfaces the ambiguity (Phase 4 UI).
public protocol VaultPathResolver: Sendable {
    /// Resolve the destination URL for a note given a matched course event.
    ///
    /// - Parameters:
    ///   - match: The CourseMatch result from CourseClassifier.
    ///   - recordingStart: Recording start timestamp (for filename).
    /// - Returns: Destination URL for the note file.
    /// - Throws: `PipelineError` if the match is ambiguous or unresolved.
    func resolve(match: CourseMatch, recordingStart: Date) throws -> URL
}
