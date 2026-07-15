import Foundation

/// Central coordinator that orchestrates the Record-to-Obsidian pipeline.
///
/// Per O-01: Enforces an 8-state lifecycle:
///   `idle -> transcribing -> classifying -> normalizing -> writing -> completed`
///   (plus terminal `failed` and `cancelled`).
///
/// Per O-02: Swift 6 actor isolation serializes all state access by language
/// guarantee. A synchronous guard at `run()` entry rejects concurrent calls.
///
/// Per O-03: Fail-fast model — any error from a dependency transitions to
/// `.failed(error)` and the error is re-thrown to the caller.
///
/// Per O-04: Cooperative cancellation via `cancel()`. Each stage calls
/// `Task.checkCancellation()` before doing work, allowing clean teardown.
///
/// Per O-05: Dependencies are injected via the constructor:
/// - `transcriber`: Conforms to ``PipelineTranscriber`` (Phase 3 bridges whisper.cpp/SpeechAnalyzer)
/// - `writer`: Conforms to ``NoteWriter`` (Phase 3 provides NSFileCoordinatorNoteWriter)
/// - `resolver`: Conforms to ``VaultPathResolver`` (Phase 4 resolves course -> vault folder)
///
/// The orchestrator calls ``CourseClassifier.match`` (Plan 03) during the
/// classifying stage and ``NoteNormalizer.normalize`` (Plan 01) during the
/// normalizing stage.
public actor PipelineOrchestrator {

    // MARK: - State

    /// Current pipeline state (private — exposed read-only via `currentState`).
    private var state: PipelineState = .idle

    /// The active pipeline task, if one is running. Stored so `cancel()` can reach it.
    private var activeTask: Task<Void, Error>?

    // MARK: - Dependencies

    /// Audio transcription provider (Phase 3: whisper.cpp / SpeechAnalyzer bridge).
    private let transcriber: any PipelineTranscriber

    /// Note writing provider (Phase 3: NSFileCoordinatorNoteWriter).
    private let writer: any NoteWriter

    /// Vault path resolver (Phase 4: course -> vault folder mapping).
    private let resolver: any VaultPathResolver

    // MARK: - Init

    /// Creates a pipeline orchestrator with injected dependencies.
    ///
    /// - Parameters:
    ///   - transcriber: Audio transcription provider conforming to ``PipelineTranscriber``.
    ///   - writer: Note writing provider conforming to ``NoteWriter``.
    ///   - resolver: Vault path resolver conforming to ``VaultPathResolver``.
    public init(
        transcriber: any PipelineTranscriber,
        writer: any NoteWriter,
        resolver: any VaultPathResolver
    ) {
        self.transcriber = transcriber
        self.writer = writer
        self.resolver = resolver
    }

    // MARK: - Public API

    /// Current pipeline state, readable from outside the actor.
    public var currentState: PipelineState {
        state
    }

    /// Runs the full Record-to-Obsidian pipeline.
    ///
    /// Per O-01: Transitions through all stages:
    /// 1. **transcribing** — calls `transcriber.transcribe(inputs.recordingURL)`
    /// 2. **classifying** — calls `CourseClassifier.match(events:against:window:)`
    /// 3. **normalizing** — calls `NoteNormalizer.normalize(transcript:course:...)`
    /// 4. **writing** — calls `writer.write(note, to: destinationURL)`
    /// 5. **completed** — terminal success state
    ///
    /// Per O-02: Throws ``PipelineError/alreadyRunning`` if called while not `.idle`.
    ///
    /// Per O-03: Fail-fast — any stage error transitions to `.failed(error)` and re-throws.
    ///
    /// Per O-04: Checks `Task.checkCancellation()` before each stage for cooperative cancellation.
    ///
    /// - Parameter inputs: All data needed for this pipeline run.
    /// - Throws: ``PipelineError`` for orchestrator-level failures, or any error
    ///   from dependencies (re-thrown after setting `.failed` state).
    public func run(inputs: PipelineInputs) async throws {
        // O-02: Synchronous concurrent-run rejection.
        // Actor isolation serializes this check — no data race possible.
        guard case .idle = state else {
            throw PipelineError.alreadyRunning
        }

        // O-04: Wrap pipeline in a Task so cancel() can reach it.
        // The Task captures self weakly via [weak self] to avoid retain cycles,
        // but since the actor owns activeTask and we await its completion,
        // a strong capture is safe here.
        activeTask = Task { [self] in
            try await self.executePipeline(inputs: inputs)
        }

        do {
            try await activeTask?.value
        } catch {
            // Error already set state to .failed/.cancelled inside executePipeline.
            // Clear task and re-throw to caller.
            activeTask = nil
            throw error
        }

        // Clear the task reference on successful completion.
        activeTask = nil
    }

    /// Requests cooperative cancellation of a running pipeline.
    ///
    /// Per O-04: Calls `Task.cancel()` on the active task, which triggers
    /// `CancellationError` at the next `Task.checkCancellation()` checkpoint.
    /// The executePipeline catch block sets state to `.cancelled`.
    ///
    /// If no pipeline is running, this is a no-op.
    public func cancel() {
        activeTask?.cancel()
    }

    /// Resets the orchestrator back to `.idle` state.
    ///
    /// Useful for recovery after a `.failed` or `.cancelled` terminal state.
    /// Has no effect if a pipeline is actively running.
    public func reset() {
        if activeTask == nil {
            state = .idle
        }
    }

    // MARK: - Private Pipeline Execution

    /// Executes the 4-stage pipeline. Called from within a Task in `run()`.
    ///
    /// Sets state to `.failed(error)` or `.cancelled` before throwing so the
    /// terminal state is always consistent regardless of how the caller handles the error.
    private func executePipeline(inputs: PipelineInputs) async throws {
        do {
            // Stage 1: Transcribing
            state = .transcribing
            try Task.checkCancellation()
            let segments = try await transcriber.transcribe(inputs.recordingURL)

            // Stage 2: Classifying
            state = .classifying
            try Task.checkCancellation()
            let match = CourseClassifier.match(
                events: inputs.events,
                against: inputs.recordingStart,
                window: 1800
            )

            // Resolve vault destination from the match result.
            let destinationURL = try resolver.resolve(
                match: match,
                recordingStart: inputs.recordingStart
            )

            // Extract the matched course event for normalization.
            // For .single, we have exactly one event. For .multiple/.none,
            // the resolver decides (Phase 4 may throw or prompt).
            guard case .single(let course) = match else {
                // Resolver should have thrown for ambiguous matches.
                // If we get here, it's a bug — surface as failure.
                state = .failed(PipelineError.invalidInputs)
                throw PipelineError.invalidInputs
            }

            // Stage 3: Normalizing
            state = .normalizing
            try Task.checkCancellation()
            let note = NoteNormalizer.normalize(
                transcript: segments,
                course: course,
                audioFile: inputs.recordingURL.lastPathComponent,
                recordingStart: inputs.recordingStart,
                durationSeconds: inputs.durationSeconds
            )

            // Stage 4: Writing
            state = .writing
            try Task.checkCancellation()
            try await writer.write(note, to: destinationURL)

            // Terminal: Completed
            state = .completed

        } catch is CancellationError {
            // O-04: Cooperative cancellation reached a checkpoint.
            state = .cancelled
            throw CancellationError()
        } catch {
            // O-03: Fail-fast — any error transitions to terminal .failed state.
            state = .failed(error)
            throw error
        }
    }
}
