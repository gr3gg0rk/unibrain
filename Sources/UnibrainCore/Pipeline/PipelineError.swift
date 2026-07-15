import Foundation

/// Errors thrown by ``PipelineOrchestrator`` for orchestrator-internal failures.
///
/// Per O-02: `.alreadyRunning` enforces single-run-at-a-time via actor isolation.
/// Per CONTEXT.md Claude's Discretion: distinct from `NoteWriterError` (filesystem errors)
/// and `ProviderError` (dependency errors). PipelineError covers orchestrator-level
/// state machine violations.
///
/// All cases are `Sendable` — no associated error existentials that would break
/// Sendable conformance (unlike `PipelineState.failed(any Error)` which needs `@unchecked`).
public enum PipelineError: Error, Sendable {
    /// Thrown when `run(inputs:)` is called while the pipeline is already running.
    ///
    /// Per O-02: Actor isolation serializes access, but the synchronous guard
    /// at the top of `run()` checks state and throws this before any work starts.
    case alreadyRunning
    /// Thrown when `PipelineInputs` validation fails (e.g., negative duration,
    /// empty events array for auto-routing).
    case invalidInputs
    /// Thrown when the pipeline is cancelled via `cancel()` and the run task
    /// surfaces the cancellation as a `PipelineError` rather than `CancellationError`.
    case cancelled
}
