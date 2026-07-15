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

    /// Creates a Phase 4 schedule-aware orchestrator with ScheduleAwareVaultResolver.
    ///
    /// Per CLAS-01, CLAS-02, CLAS-05: Routes recordings to
    /// `{vault}/{sanitizedTerm}/{courseCode}/` based on calendar events
    /// and the mapping snapshot.
    ///
    /// Wires:
    /// 1. `TranscriberRouter(modelPath:)` — same dual-engine ASR as Phase 3
    /// 2. `NSFileCoordinatorNoteWriter()` — same atomic iCloud-safe writes
    /// 3. `ScheduleAwareVaultResolver` — Phase 4 resolver with mapping snapshot
    ///
    /// The mapping snapshot is loaded at construction time (per-recording)
    /// so newly-learned courses route correctly on the next recording.
    /// Call `makeUpdatedResolver` and construct a new orchestrator to refresh.
    ///
    /// - Parameters:
    ///   - modelPath: Path to ggml-small.en.bin for whisper.cpp fallback.
    ///   - vaultRoot: Root URL of the Obsidian vault.
    ///   - termLabel: Current academic term label (e.g., "Fall 2026").
    ///   - mapping: Event title -> course mapping snapshot.
    /// - Returns: A PipelineOrchestrator wired with ScheduleAwareVaultResolver.
    public static func makeScheduleAwareOrchestrator(
        modelPath: URL,
        vaultRoot: URL,
        termLabel: String,
        mapping: [String: CourseMapping]
    ) -> PipelineOrchestrator {
        let transcriber = TranscriberRouter(modelPath: modelPath)
        let writer = NSFileCoordinatorNoteWriter()
        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: termLabel,
            mapping: mapping
        )
        return PipelineOrchestrator(
            transcriber: transcriber,
            writer: writer,
            resolver: resolver
        )
    }

    /// Creates a fresh ScheduleAwareVaultResolver with updated mapping data.
    ///
    /// Use this when constructing a new orchestrator per-recording cycle to
    /// ensure the latest mapping snapshot (from courses.json) is used.
    ///
    /// - Parameters:
    ///   - vaultRoot: Root URL of the Obsidian vault.
    ///   - termLabel: Current academic term label.
    ///   - mapping: Event title -> course mapping snapshot.
    /// - Returns: A new ScheduleAwareVaultResolver with the provided data.
    public static func makeUpdatedResolver(
        vaultRoot: URL,
        termLabel: String,
        mapping: [String: CourseMapping]
    ) -> any VaultPathResolver {
        ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: termLabel,
            mapping: mapping
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
