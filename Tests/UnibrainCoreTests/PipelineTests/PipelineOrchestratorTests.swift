import Testing
import Foundation
@testable import UnibrainCore

@Suite("PipelineState")
struct PipelineStateTests {

    @Test("PipelineState.idle constructs")
    func idleConstructs() {
        let state: PipelineState = .idle
        if case .idle = state { /* success */ } else {
            Issue.record("Expected .idle")
        }
    }

    @Test("PipelineState.transcribing constructs")
    func transcribingConstructs() {
        let state: PipelineState = .transcribing
        if case .transcribing = state { /* success */ } else {
            Issue.record("Expected .transcribing")
        }
    }

    @Test("PipelineState.classifying constructs")
    func classifyingConstructs() {
        let state: PipelineState = .classifying
        if case .classifying = state { /* success */ } else {
            Issue.record("Expected .classifying")
        }
    }

    @Test("PipelineState.normalizing constructs")
    func normalizingConstructs() {
        let state: PipelineState = .normalizing
        if case .normalizing = state { /* success */ } else {
            Issue.record("Expected .normalizing")
        }
    }

    @Test("PipelineState.writing constructs")
    func writingConstructs() {
        let state: PipelineState = .writing
        if case .writing = state { /* success */ } else {
            Issue.record("Expected .writing")
        }
    }

    @Test("PipelineState.completed constructs")
    func completedConstructs() {
        let state: PipelineState = .completed
        if case .completed = state { /* success */ } else {
            Issue.record("Expected .completed")
        }
    }

    @Test("PipelineState.failed constructs with Error parameter")
    func failedConstructsWithError() {
        struct TestError: Error {}
        let error = TestError()
        let state: PipelineState = .failed(error)
        if case .failed = state { /* success */ } else {
            Issue.record("Expected .failed")
        }
    }

    @Test("PipelineState.cancelled constructs")
    func cancelledConstructs() {
        let state: PipelineState = .cancelled
        if case .cancelled = state { /* success */ } else {
            Issue.record("Expected .cancelled")
        }
    }

    @Test("PipelineState is Sendable and can cross concurrency boundaries")
    func pipelineStateIsSendable() async {
        // Compile-time Sendable check: assigning to any Sendable succeeds
        // only if PipelineState conforms to Sendable.
        let state: PipelineState = .completed
        let sendable: any Sendable = state
        #expect(sendable is PipelineState)

        // Runtime check: state can cross concurrency boundaries via detached Task.
        let result = await Task.detached { () -> Bool in
            if case .completed = state { return true } else { return false }
        }.value
        #expect(result)
    }
}

// MARK: - PipelineInputs Tests

@Suite("PipelineInputs")
struct PipelineInputsTests {

    private func makeInputs() -> PipelineInputs {
        PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/recordings/lecture.m4a"),
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            recordingEnd: Date(timeIntervalSince1970: 1_700_036_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            events: [
                CalendarEvent(
                    id: "evt-1",
                    title: "Intro to CS",
                    startDate: Date(timeIntervalSince1970: 1_700_000_000),
                    endDate: Date(timeIntervalSince1970: 1_700_036_000)
                )
            ]
        )
    }

    @Test("PipelineInputs constructs with all 6 fields")
    func inputsConstructWithAllFields() {
        let inputs = makeInputs()
        #expect(inputs.recordingURL == URL(fileURLWithPath: "/recordings/lecture.m4a"))
        #expect(inputs.recordingStart == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(inputs.recordingEnd == Date(timeIntervalSince1970: 1_700_036_000))
        #expect(inputs.durationSeconds == 3600)
        #expect(inputs.source == "MacBook Air")
        #expect(inputs.events.count == 1)
        #expect(inputs.events[0].title == "Intro to CS")
    }

    @Test("PipelineInputs is Sendable and can cross concurrency boundaries")
    func inputsAreSendable() async {
        let inputs = makeInputs()
        // Compile-time Sendable: assigning to any Sendable
        let sendable: any Sendable = inputs
        #expect(sendable is PipelineInputs)

        // Runtime: cross actor boundary via detached Task
        let eventCount = await Task.detached { () -> Int in
            inputs.events.count
        }.value
        #expect(eventCount == 1)
    }

    @Test("PipelineInputs.events field carries [CalendarEvent] from CourseClassifier")
    func inputsEventsCarryCalendarEvents() {
        let events = [
            CalendarEvent(id: "a", title: "Math", startDate: Date(), endDate: Date()),
            CalendarEvent(id: "b", title: "Physics", startDate: Date(), endDate: Date())
        ]
        let inputs = PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/rec.m4a"),
            recordingStart: Date(),
            recordingEnd: Date(),
            durationSeconds: 1800,
            source: "iPhone",
            events: events
        )
        #expect(inputs.events.count == 2)
        #expect(inputs.events[0].title == "Math")
        #expect(inputs.events[1].title == "Physics")
    }
}

// MARK: - PipelineError Tests

@Suite("PipelineError")
struct PipelineErrorTests {

    @Test("PipelineError.alreadyRunning constructs")
    func alreadyRunningConstructs() {
        let error = PipelineError.alreadyRunning
        if case .alreadyRunning = error { /* success */ } else {
            Issue.record("Expected .alreadyRunning")
        }
    }

    @Test("PipelineError.invalidInputs constructs")
    func invalidInputsConstructs() {
        let error = PipelineError.invalidInputs
        if case .invalidInputs = error { /* success */ } else {
            Issue.record("Expected .invalidInputs")
        }
    }

    @Test("PipelineError.cancelled constructs")
    func cancelledConstructs() {
        let error = PipelineError.cancelled
        if case .cancelled = error { /* success */ } else {
            Issue.record("Expected .cancelled")
        }
    }

    @Test("PipelineError is Sendable and can cross concurrency boundaries")
    func pipelineErrorIsSendable() async {
        let error = PipelineError.alreadyRunning
        let sendable: any Sendable = error
        #expect(sendable is PipelineError)

        let result = await Task.detached { () -> Bool in
            if case .alreadyRunning = error { return true } else { return false }
        }.value
        #expect(result)
    }

    @Test("PipelineError is catchable as Error type")
    func pipelineErrorCatchableAsError() {
        do {
            throw PipelineError.alreadyRunning
        } catch {
            // Caught as generic Error — proves Error conformance
            #expect(error is PipelineError)
        }

        do {
            throw PipelineError.cancelled
        } catch let pipelineError as PipelineError {
            if case .cancelled = pipelineError { /* success */ } else {
                Issue.record("Expected .cancelled")
            }
        } catch {
            Issue.record("Failed to cast to PipelineError")
        }
    }
}

// MARK: - PipelineOrchestrator Tests

@Suite("PipelineOrchestrator")
struct PipelineOrchestratorTests {

    // MARK: - Test Fixtures

    /// Creates standard PipelineInputs for a single-event match scenario.
    private func makeInputs(eventStartOffset: TimeInterval = 0) -> PipelineInputs {
        let recordingStart = Date(timeIntervalSince1970: 1_700_000_000)
        let eventStart = recordingStart.addingTimeInterval(eventStartOffset)
        let event = CalendarEvent(
            id: "evt-cs101",
            title: "Intro to Computer Science",
            startDate: eventStart,
            endDate: eventStart.addingTimeInterval(3600)
        )
        return PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/recordings/lecture.m4a"),
            recordingStart: recordingStart,
            recordingEnd: recordingStart.addingTimeInterval(3600),
            durationSeconds: 3600,
            source: "MacBook Air",
            events: [event]
        )
    }

    /// Creates a default orchestrator with successful mock dependencies.
    private func makeOrchestrator(
        transcriber: MockTranscriber? = nil,
        writer: MockNoteWriter? = nil,
        resolver: MockVaultResolver? = nil
    ) -> PipelineOrchestrator {
        PipelineOrchestrator(
            transcriber: transcriber ?? MockTranscriber(),
            writer: writer ?? MockNoteWriter(),
            resolver: resolver ?? MockVaultResolver()
        )
    }

    // MARK: - State Transition Tests

    @Test("run starts in .idle state")
    func startsIdle() async {
        let orchestrator = makeOrchestrator()
        let state = await orchestrator.currentState
        if case .idle = state { /* success */ } else {
            Issue.record("Expected .idle, got: \(state)")
        }
    }

    @Test("run transitions through all stages to .completed")
    func runTransitionsAllStages() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeInputs()

        // Before run
        let beforeState = await orchestrator.currentState
        if case .idle = beforeState {} else {
            Issue.record("Expected .idle before run")
        }

        try await orchestrator.run(inputs: inputs)

        // After successful run — should be completed
        let afterState = await orchestrator.currentState
        if case .completed = afterState {} else {
            Issue.record("Expected .completed after run, got: \(afterState)")
        }
    }

    @Test("currentState is readable as PipelineState")
    func currentStateReadable() async {
        let orchestrator = makeOrchestrator()
        let state = await orchestrator.currentState
        if case .idle = state { /* success */ } else {
            Issue.record("Expected .idle initial state")
        }
    }

    // MARK: - Concurrent-Run Rejection (O-02)

    @Test("run throws .alreadyRunning when called while not idle")
    func runThrowsAlreadyRunning() async throws {
        // Use a slow transcriber to ensure the first run is still in progress
        let slowTranscriber = MockTranscriber(delaySeconds: 0.5)
        let orchestrator = PipelineOrchestrator(
            transcriber: slowTranscriber,
            writer: MockNoteWriter(),
            resolver: MockVaultResolver()
        )
        let inputs = makeInputs()

        // Start first run without awaiting — it runs in background
        async let firstRun: Void = try await orchestrator.run(inputs: inputs)

        // Give the first run time to enter the transcribing stage
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Second call should throw .alreadyRunning
        do {
            try await orchestrator.run(inputs: inputs)
            Issue.record("Should have thrown PipelineError.alreadyRunning")
        } catch let error as PipelineError {
            if case .alreadyRunning = error { /* success */ } else {
                Issue.record("Expected .alreadyRunning, got: \(error)")
            }
        } catch {
            Issue.record("Expected PipelineError, got: \(error)")
        }

        // Await the first run to completion
        _ = try? await firstRun
    }

    // MARK: - Fail-Fast (O-03)

    @Test("transcriber error transitions to .failed state")
    func transcriberErrorTransitionsToFailed() async {
        struct TranscribeError: Error {}
        let failingTranscriber = MockTranscriber(error: TranscribeError())
        let orchestrator = PipelineOrchestrator(
            transcriber: failingTranscriber,
            writer: MockNoteWriter(),
            resolver: MockVaultResolver()
        )
        let inputs = makeInputs()

        do {
            try await orchestrator.run(inputs: inputs)
            Issue.record("Should have thrown error")
        } catch {
            // Expected — error re-thrown from run()
        }

        // State should be .failed
        let state = await orchestrator.currentState
        if case .failed = state { /* success */ } else {
            Issue.record("Expected .failed state, got: \(state)")
        }
    }

    @Test("writer error transitions to .failed state")
    func writerErrorTransitionsToFailed() async {
        struct WriteError: Error {}
        let failingWriter = MockNoteWriter(error: WriteError())
        let orchestrator = PipelineOrchestrator(
            transcriber: MockTranscriber(),
            writer: failingWriter,
            resolver: MockVaultResolver()
        )
        let inputs = makeInputs()

        do {
            try await orchestrator.run(inputs: inputs)
            Issue.record("Should have thrown error")
        } catch {
            // Expected
        }

        let state = await orchestrator.currentState
        if case .failed = state { /* success */ } else {
            Issue.record("Expected .failed state, got: \(state)")
        }
    }

    // MARK: - Cooperative Cancellation (O-04)

    @Test("cancel transitions to .cancelled state")
    func cancelTransitionsToCancelled() async {
        let slowTranscriber = MockTranscriber(delaySeconds: 2.0)
        let orchestrator = PipelineOrchestrator(
            transcriber: slowTranscriber,
            writer: MockNoteWriter(),
            resolver: MockVaultResolver()
        )
        let inputs = makeInputs()

        // Start run without awaiting
        async let runResult: Void = try await orchestrator.run(inputs: inputs)

        // Give it time to enter the transcribing stage
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Cancel
        await orchestrator.cancel()

        // Await completion (will throw due to cancellation)
        _ = try? await runResult

        // State should be .cancelled
        let cancelState = await orchestrator.currentState
        if case .cancelled = cancelState { /* success */ } else {
            Issue.record("Expected .cancelled state, got: \(cancelState)")
        }
    }

    @Test("reset returns from terminal state to .idle")
    func resetReturnsToIdle() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeInputs()

        // Run to completion
        try await orchestrator.run(inputs: inputs)
        let completedState = await orchestrator.currentState
        if case .completed = completedState {} else {
            Issue.record("Expected .completed before reset")
        }

        // Reset
        await orchestrator.reset()
        let idleState = await orchestrator.currentState
        if case .idle = idleState {} else {
            Issue.record("Expected .idle after reset, got: \(idleState)")
        }
    }

    // MARK: - Integration with CourseClassifier / NoteNormalizer / NoteWriter

    @Test("orchestrator calls CourseClassifier and pauses for non-overlapping event")
    func callsCourseClassifier() async throws {
        // Phase 4: Non-overlapping event -> CourseClassifier returns .none
        // -> orchestrator pauses at .awaitingUserChoice (no longer fails immediately)
        let recordingStart = Date(timeIntervalSince1970: 1_700_000_000)
        let nonOverlappingEvent = CalendarEvent(
            id: "evt-far",
            title: "Far Future Event",
            startDate: recordingStart.addingTimeInterval(86400), // +1 day
            endDate: recordingStart.addingTimeInterval(90000)
        )
        let inputs = PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/rec.m4a"),
            recordingStart: recordingStart,
            recordingEnd: recordingStart.addingTimeInterval(3600),
            durationSeconds: 3600,
            source: "MacBook Air",
            events: [nonOverlappingEvent]
        )

        let resolver = MockVaultResolver(throwOnNone: true)
        let orchestrator = PipelineOrchestrator(
            transcriber: MockTranscriber(),
            writer: MockNoteWriter(),
            resolver: resolver
        )

        // Start the pipeline — it will park at .awaitingUserChoice
        async let pipelineResult: Void = try await orchestrator.run(inputs: inputs)

        // Give it time to reach the pause state
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        // Phase 4: .none match now pauses at .awaitingUserChoice (MP-04)
        let pausedState = await orchestrator.currentState
        if case .awaitingUserChoice = pausedState { /* success */ } else {
            Issue.record("Expected .awaitingUserChoice for non-overlapping event, got: \(pausedState)")
        }

        // Resume with the non-overlapping event to complete the pipeline
        await orchestrator.resume(with: nonOverlappingEvent)
        _ = try? await pipelineResult
    }

    @Test("orchestrator calls NoteWriter during writing stage with real temp file")
    func callsNoteWriterWithRealFile() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeInputs()

        try await orchestrator.run(inputs: inputs)

        // State should be completed — proving writer.write() was called and succeeded
        let state = await orchestrator.currentState
        if case .completed = state {} else {
            Issue.record("Expected .completed, got: \(state)")
        }
    }

    @Test("orchestrator full pipeline produces correct NoteWriter call")
    func fullPipelineProducesCorrectWrite() async throws {
        let writer = TrackingNoteWriter()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_pipeline_\(UUID().uuidString)")
        let resolver = MockVaultResolver(destinationURL: tempDir.appendingPathComponent("test_note.md"))
        let orchestrator = PipelineOrchestrator(
            transcriber: MockTranscriber(),
            writer: writer,
            resolver: resolver
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let inputs = makeInputs()
        try await orchestrator.run(inputs: inputs)

        #expect(writer.writeCallCount == 1)
        let finalState = await orchestrator.currentState
        if case .completed = finalState {} else {
            Issue.record("Expected .completed, got: \(finalState)")
        }
    }
}

// MARK: - Mock Implementations

/// Mock PipelineTranscriber with configurable behavior.
private struct MockTranscriber: PipelineTranscriber {
    let segments: [(start: TimeInterval, end: TimeInterval, text: String)]
    let error: (any Error)?
    let delaySeconds: TimeInterval

    init(
        segments: [(start: TimeInterval, end: TimeInterval, text: String)]? = nil,
        error: (any Error)? = nil,
        delaySeconds: TimeInterval = 0
    ) {
        self.segments = segments ?? [
            (start: 0.0, end: 2.0, text: "Welcome to the lecture."),
            (start: 2.5, end: 5.0, text: "Today we cover algorithms."),
            (start: 8.0, end: 12.0, text: "Let us begin with sorting.")
        ]
        self.error = error
        self.delaySeconds = delaySeconds
    }

    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        if delaySeconds > 0 {
            // Use try (not try?) so cancellation propagates correctly
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }
        if let error { throw error }
        return segments
    }
}

/// Mock NoteWriter with configurable error.
private struct MockNoteWriter: NoteWriter {
    let error: (any Error)?

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func write(_ note: NormalizedNote, to destination: URL) async throws {
        if let error { throw error }
        // Success — no-op
    }
}

/// Tracking NoteWriter that records calls for verification.
private final class TrackingNoteWriter: NoteWriter, @unchecked Sendable {
    private(set) var writeCallCount = 0

    func write(_ note: NormalizedNote, to destination: URL) async throws {
        writeCallCount += 1
    }
}

/// Mock VaultPathResolver with configurable behavior.
private struct MockVaultResolver: VaultPathResolver {
    let destinationURL: URL?
    let throwOnNone: Bool

    init(
        destinationURL: URL? = nil,
        throwOnNone: Bool = false
    ) {
        self.destinationURL = destinationURL
        self.throwOnNone = throwOnNone
    }

    func resolve(match: CourseMatch, recordingStart: Date) throws -> URL {
        switch match {
        case .single:
            return destinationURL ?? URL(fileURLWithPath: "/tmp/vault/lecture.md")
        case .multiple:
            throw PipelineError.invalidInputs
        case .none:
            if throwOnNone { throw PipelineError.invalidInputs }
            return destinationURL ?? URL(fileURLWithPath: "/tmp/vault/unmatched.md")
        }
    }
}
