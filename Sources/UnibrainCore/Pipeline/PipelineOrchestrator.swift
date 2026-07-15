import Foundation

/// Central coordinator that orchestrates the Record-to-Obsidian pipeline.
///
/// Per O-01: Enforces a 9-state lifecycle:
///   `idle -> transcribing -> classifying -> [awaitingUserChoice] -> normalizing -> writing -> completed`
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
/// Per MP-04: When CourseClassifier returns `.multiple` or `.none`, the
/// orchestrator transitions to `.awaitingUserChoice` and parks via
/// `withCheckedThrowingContinuation`. The UI layer resumes via `resume(with:)`
/// or `skipClassification()` (SR-14875 safe — resume crosses actor boundary).
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

    /// Stored continuation for pause/resume during .awaitingUserChoice (MP-04).
    ///
    /// Per RESEARCH Pitfall 3 (SR-14875): The continuation is resumed from
    /// OUTSIDE the actor (UI layer / @MainActor). This is the safe pattern.
    /// Resuming from within the same actor can hang.
    private var selectionContinuation: CheckedContinuation<CalendarEvent, any Error>?

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
    /// 3. **awaitingUserChoice** — if match is .multiple/.none, parks for manual selection
    /// 4. **normalizing** — calls `NoteNormalizer.normalize(transcript:course:...)`
    /// 5. **writing** — calls `writer.write(note, to: destinationURL)`
    /// 6. **completed** — terminal success state
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
    /// Per MP-04: If paused at `.awaitingUserChoice`, also resumes the
    /// continuation with `CancellationError` so the parked pipeline unblocks.
    ///
    /// If no pipeline is running, this is a no-op.
    public func cancel() {
        // Resume any parked continuation with cancellation (T-04-10 mitigation).
        if let cont = selectionContinuation {
            selectionContinuation = nil
            cont.resume(throwing: CancellationError())
        }
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

    // MARK: - Pause/Resume API (MP-04)

    /// Resumes the pipeline with a user-selected course event.
    ///
    /// Called from the UI layer (MenuBarViewModel on @MainActor) after the user
    /// picks a course from the picker. The method crosses the actor boundary —
    /// Swift 6 ensures it runs within the orchestrator's actor isolation.
    ///
    /// Per RESEARCH Pitfall 3 (SR-14875): This method is called from OUTSIDE
    /// the actor (UI layer), which is the safe pattern. Resuming a continuation
    /// from within the same actor that created it can hang.
    ///
    /// The UI layer is responsible for converting CourseSelection -> CalendarEvent
    /// before calling this method (keeps the orchestrator simpler and avoids
    /// importing CoursePickerViewModel into UnibrainCore).
    ///
    /// - Parameter event: The user-selected calendar event to route the note to.
    public func resume(with event: CalendarEvent) async {
        selectionContinuation?.resume(returning: event)
        selectionContinuation = nil
    }

    /// Skips course classification and routes to _unsorted.
    ///
    /// Per MP-03: The Skip button in the picker calls this method. It creates
    /// a synthetic `_unsorted` event and resumes the continuation, so the
    /// pipeline continues to normalizing + writing with the _unsorted folder
    /// as the destination.
    public func skipClassification() async {
        let unsortedEvent = CalendarEvent(
            id: "unsorted",
            title: "_unsorted",
            startDate: Date(),
            endDate: Date()
        )
        selectionContinuation?.resume(returning: unsortedEvent)
        selectionContinuation = nil
    }

    // MARK: - Private Pipeline Execution

    /// Executes the pipeline stages. Called from within a Task in `run()`.
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

            // Resolve course event (may pause for user input).
            // Per MP-04: .single proceeds directly; .multiple/.none pauses.
            let resolvedEvent: CalendarEvent
            switch match {
            case .single(let event):
                resolvedEvent = event
            case .multiple, .none:
                state = .awaitingUserChoice
                try Task.checkCancellation()
                resolvedEvent = try await resolveViaUserChoice()
            }

            // Resolve vault destination from the resolved event.
            // The resolver always receives a .single match with the resolved event.
            let destinationURL = try resolver.resolve(
                match: .single(resolvedEvent),
                recordingStart: inputs.recordingStart
            )

            // Stage 3: Normalizing
            state = .normalizing
            try Task.checkCancellation()
            // Per Pitfall 5: term and source are now parameterized.
            let note = NoteNormalizer.normalize(
                transcript: segments,
                course: resolvedEvent,
                audioFile: inputs.recordingURL.lastPathComponent,
                recordingStart: inputs.recordingStart,
                durationSeconds: inputs.durationSeconds,
                term: inputs.termLabel,
                source: inputs.source
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

    /// Suspends the orchestrator cooperatively until the UI layer resumes the continuation.
    ///
    /// Per RESEARCH Pattern 2: Uses `withCheckedThrowingContinuation` to park
    /// the pipeline at `.awaitingUserChoice`. The continuation is stored as
    /// actor state; it is resumed from OUTSIDE the actor via `resume(with:)`
    /// or `skipClassification()` (safe per Pitfall 3 / SR-14875).
    ///
    /// - Returns: The user-selected CalendarEvent to route the note to.
    private func resolveViaUserChoice() async throws -> CalendarEvent {
        return try await withCheckedThrowingContinuation { continuation in
            self.selectionContinuation = continuation
        }
    }
}
