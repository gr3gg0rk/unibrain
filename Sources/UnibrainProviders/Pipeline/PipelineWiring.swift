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
    /// Wires:
    /// 1. `TranscriberRouter(modelPath:)` — SpeechAnalyzer primary + whisper.cpp fallback
    /// 2. `NSFileCoordinatorNoteWriter()` — atomic iCloud-safe note writes
    /// 3. `HardcodedVaultResolver()` — ~/Documents/Unibrain/lectures/ path
    ///
    /// - Parameter modelPath: Path to ggml-small.en.bin for whisper.cpp fallback.
    /// - Returns: A PipelineOrchestrator ready to accept PipelineInputs.
    public static func makeOrchestrator(modelPath: URL) -> PipelineOrchestrator {
        let transcriber = TranscriberRouter(modelPath: modelPath)
        let writer = NSFileCoordinatorNoteWriter()
        let resolver = HardcodedVaultResolver()
        return PipelineOrchestrator(
            transcriber: transcriber,
            writer: writer,
            resolver: resolver
        )
    }

    /// Creates a new RecordingSession for audio capture.
    ///
    /// - Returns: A RecordingSession actor in .idle state.
    public static func makeRecordingSession() -> RecordingSession {
        RecordingSession()
    }

    /// Maps a RecordingSession.Result to PipelineInputs for the orchestrator.
    ///
    /// Per Plan 03: Phase 3 has no calendar events (events: []),
    /// deferred to Phase 4. The recordingEnd is computed from
    /// recordingStart + durationSeconds.
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
        let recordingEnd = recordingStart.addingTimeInterval(
            TimeInterval(recordingResult.durationSeconds)
        )
        return PipelineInputs(
            recordingURL: recordingResult.audioURL,
            recordingStart: recordingStart,
            recordingEnd: recordingEnd,
            durationSeconds: recordingResult.durationSeconds,
            source: source,
            events: [] // Phase 3: no calendar events, deferred to Phase 4
        )
    }
}

#endif // os(macOS)
