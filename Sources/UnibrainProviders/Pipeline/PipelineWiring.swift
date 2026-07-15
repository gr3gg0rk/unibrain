import Foundation
import UnibrainCore

#if os(macOS)

/// Factory that assembles the full Phase 3 capture-to-note pipeline.
///
/// Wires together:
/// - `TranscriberRouter` (Plan 02) — dual-engine ASR with auto-fallback
/// - `NSFileCoordinatorNoteWriter` (Plan 03 Task 1) — atomic iCloud-safe writes
/// - `HardcodedVaultResolver` (Plan 03 Task 2) — Phase 3 hardcoded vault path
///
/// Produces a fully wired `PipelineOrchestrator` that can accept
/// `PipelineInputs` and run the full record-to-note pipeline.
public enum PipelineWiring {

    /// Creates a fully wired PipelineOrchestrator with all Phase 3 conformances.
    ///
    /// - Parameter modelPath: Path to ggml-small.en.bin for whisper.cpp fallback.
    /// - Returns: A PipelineOrchestrator ready to accept PipelineInputs.
    public static func makeOrchestrator(modelPath: URL) -> PipelineOrchestrator {
        // RED phase stub — implementation pending GREEN
        fatalError("PipelineWiring.makeOrchestrator not yet implemented")
    }

    /// Creates a new RecordingSession for audio capture.
    ///
    /// - Returns: A RecordingSession actor in .idle state.
    public static func makeRecordingSession() -> RecordingSession {
        // RED phase stub — implementation pending GREEN
        fatalError("PipelineWiring.makeRecordingSession not yet implemented")
    }

    /// Maps a RecordingSession.Result to PipelineInputs for the orchestrator.
    ///
    /// Per Plan 03: Phase 3 has no calendar events (events: []),
    /// deferred to Phase 4.
    ///
    /// - Parameters:
    ///   - recordingResult: The result from RecordingSession.stop().
    ///   - source: Device name (e.g., "MacBook Neo").
    ///   - recordingStart: When recording started.
    /// - Returns: PipelineInputs ready for orchestrator.run(inputs:).
    public static func makePipelineInputs(
        recordingResult: RecordingSession.Result,
        source: String,
        recordingStart: Date
    ) -> PipelineInputs {
        // RED phase stub — implementation pending GREEN
        fatalError("PipelineWiring.makePipelineInputs not yet implemented")
    }
}

#endif // os(macOS)
