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

    /// Processes a single inbox audio file through the full pipeline (TRIG-03).
    ///
    /// Per TRIG-03: constructs a fresh PipelineInputs from the inbox file URL,
    /// runs the full pipeline (transcribe → classify → normalize → write),
    /// then moves the audio file from `_inbox/` to the final course folder.
    ///
    /// Per IC-03: the recording start timestamp is parsed from the filename
    /// (`{source}-{YYYYMMDDTHHMMSS}-{uuid}.m4a`), falling back to the file's
    /// creation date if parsing fails.
    ///
    /// Per P-15: the destination filename follows
    /// `YYYY-MM-DD-{course_code}-Lecture.m4a` derived from the pipeline result.
    ///
    /// - Parameters:
    ///   - audioURL: The inbox audio file URL to process.
    ///   - vaultRoot: Root URL of the Obsidian vault.
    ///   - termLabel: Current academic term label (e.g., "Fall 2026").
    ///   - mapping: Event title → course mapping snapshot.
    ///   - recordingStart: When the recording started (parsed from IC-03 filename).
    ///   - events: Calendar events for classification (empty if no calendar).
    ///   - durationSeconds: Recording duration in seconds.
    /// - Returns: The destination note URL the pipeline wrote to.
    /// - Throws: Pipeline errors on failure (caller handles retry/dead-letter).
    public static func processInboxFile(
        at audioURL: URL,
        vaultRoot: URL,
        termLabel: String,
        mapping: [String: CourseMapping],
        recordingStart: Date,
        events: [CalendarEvent],
        durationSeconds: Int
    ) async throws -> URL {
        let recordingEnd = recordingStart.addingTimeInterval(TimeInterval(durationSeconds))

        var inputs = PipelineInputs(
            recordingURL: audioURL,
            recordingStart: recordingStart,
            recordingEnd: recordingEnd,
            durationSeconds: durationSeconds,
            source: "iPhone",
            events: events,
            termLabel: termLabel
        )

        // Construct fresh orchestrator with latest mapping snapshot
        let orchestrator = makeScheduleAwareOrchestrator(
            modelPath: SmallEnDownloader.modelStoragePath,
            vaultRoot: vaultRoot,
            termLabel: termLabel,
            mapping: mapping
        )

        // Run the full pipeline
        try await orchestrator.run(inputs: inputs)

        // TRIG-03: move audio from _inbox/ to the course folder.
        // The resolver determines the destination based on classification.
        // We compute the expected note path to derive the audio destination.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: recordingStart)

        // The note was written by the orchestrator. Derive the course folder
        // from the note path to place the audio alongside it (P-15).
        // We look for the note in the vault under the term/course structure.
        let sanitizedTerm = FolderNameSanitizer.sanitize(
            folderName: termLabel.isEmpty ? "default-term" : termLabel
        )
        let termDir = vaultRoot.appendingPathComponent(sanitizedTerm)

        // Search for the note file that was just written
        let noteURL = try findRecentlyCreatedNote(
            in: termDir,
            dateString: dateString,
            recordingStart: recordingStart
        )

        // Move audio alongside the note (P-15)
        let courseDir = noteURL.deletingLastPathComponent()
        let audioDestination = courseDir.appendingPathComponent(
            "\(dateString)-Lecture.m4a"
        )

        // Create course directory if needed (A-05)
        try FileManager.default.createDirectory(
            at: courseDir,
            withIntermediateDirectories: true
        )

        // Remove existing audio destination if present (overwrite)
        if FileManager.default.fileExists(atPath: audioDestination.path) {
            try FileManager.default.removeItem(at: audioDestination)
        }

        // Move the audio file from _inbox/ to the course folder (TRIG-03)
        if FileManager.default.fileExists(atPath: audioURL.path) {
            try FileManager.default.moveItem(at: audioURL, to: audioDestination)
        }

        return noteURL
    }

    /// Parses the recording start timestamp from an IC-03 filename.
    ///
    /// Per IC-03: filenames follow `{source}-{YYYYMMDDTHHMMSS}-{uuid}.m4a`.
    /// Falls back to the file's creation date if parsing fails.
    ///
    /// - Parameter url: The inbox file URL with an IC-03 filename.
    /// - Returns: The parsed recording start date, or the file creation date.
    public static func parseRecordingStart(from url: URL) -> Date {
        let filename = url.lastPathComponent
        // Extract the YYYYMMDDTHHMMSS portion between the first and second dashes
        let components = filename.split(separator: "-", maxSplits: 2)
        guard components.count >= 2 else {
            return fileCreationDate(url) ?? Date()
        }

        let timestampString = String(components[1])
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        if let parsed = formatter.date(from: timestampString) {
            return parsed
        }

        return fileCreationDate(url) ?? Date()
    }

    /// Gets the file creation date, returning nil if unavailable.
    private static func fileCreationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    /// Finds the most recently created note file in a term directory matching
    /// the given date string.
    ///
    /// Falls back to the term directory itself if no note is found (the audio
    /// will still be moved to the term folder).
    private static func findRecentlyCreatedNote(
        in termDir: URL,
        dateString: String,
        recordingStart: Date
    ) throws -> URL {
        // Walk the term directory for a note matching the date
        if FileManager.default.fileExists(atPath: termDir.path) {
            let enumerator = FileManager.default.enumerator(
                at: termDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            var candidates: [(url: URL, date: Date)] = []
            while let itemURL = enumerator?.nextObject() as? URL {
                guard itemURL.pathExtension == "md" else { continue }
                if itemURL.lastPathComponent.contains(dateString) {
                    let modDate = (try? itemURL.resourceValues(
                        forKeys: [.contentModificationDateKey]
                    ).contentModificationDate) ?? .distantPast
                    candidates.append((itemURL, modDate))
                }
            }

            // Return the most recently modified matching note
            if let mostRecent = candidates.max(by: { $0.date < $1.date }) {
                return mostRecent.url
            }
        }

        // Fallback: return the term directory (audio will be placed there)
        return termDir
    }
}

#endif // os(macOS)
