import Foundation

/// Eight-state lifecycle of the pipeline orchestrator.
///
/// Per O-01: The pipeline progresses through these stages:
/// - `idle` → waiting for a recording to process
/// - `transcribing` → ASR engine converting audio to text
/// - `classifying` → CourseClassifier matching recording to calendar event
/// - `normalizing` → NoteNormalizer building the NormalizedNote
/// - `writing` → NoteWriter writing the note to the vault
/// - `completed` → pipeline finished successfully (terminal)
/// - `failed` → pipeline errored at some stage (terminal)
/// - `cancelled` → user requested cancellation (terminal)
///
/// Per O-03: `failed` and `cancelled` are terminal states — the orchestrator
/// returns to `idle` only when a new `run()` is accepted.
///
/// `Sendable` via `@unchecked` because the `.failed(any Error)` case holds a
/// non-Sendable existential. The state enum crosses actor boundaries (read
/// from outside the orchestrator actor via `currentState`), so Sendable is
/// required. The error payload is used only for UI display and debugging.
public enum PipelineState: @unchecked Sendable {
    /// Initial state — orchestrator is idle and ready to accept a run.
    case idle
    /// Stage 1: AudioTranscriber is converting the recording to text.
    case transcribing
    /// Stage 2: CourseClassifier is matching the recording to a calendar event.
    case classifying
    /// Stage 3: NoteNormalizer is building the NormalizedNote from transcript + course.
    case normalizing
    /// Stage 4: NoteWriter is writing the NormalizedNote to the vault.
    case writing
    /// Terminal: pipeline completed successfully.
    case completed
    /// Terminal: pipeline failed at some stage. Carries the error for UI/debugging.
    case failed(any Error)
    /// Terminal: user requested cancellation via `cancel()`.
    case cancelled
}
