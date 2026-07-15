import Testing
import Foundation
@testable import UnibrainCore

/// Tests for the Phase 4 pause/resume capability of PipelineOrchestrator.
///
/// Covers MP-04 (picker fires at .awaitingUserChoice), CheckedContinuation
/// pause/resume (RESEARCH Pattern 2), SR-14875 avoidance (resume from outside
/// the actor), skipClassification (MP-03 _unsorted route), and cancellation
/// during pause.
///
/// Also covers NoteNormalizer parameterization (RESEARCH Pitfall 5) and
/// PipelineInputs.termLabel addition (CT-01).

// MARK: - PipelineState .awaitingUserChoice Tests

@Suite("PipelineState .awaitingUserChoice")
struct PipelineStateAwaitingUserChoiceTests {

    @Test("PipelineState.awaitingUserChoice constructs")
    func awaitingUserChoiceConstructs() {
        let state: PipelineState = .awaitingUserChoice
        if case .awaitingUserChoice = state { /* success */ } else {
            Issue.record("Expected .awaitingUserChoice")
        }
    }

    @Test("PipelineState.awaitingUserChoice is Sendable")
    func awaitingUserChoiceIsSendable() async {
        let state: PipelineState = .awaitingUserChoice
        let sendable: any Sendable = state
        #expect(sendable is PipelineState)

        let result = await Task.detached { () -> Bool in
            if case .awaitingUserChoice = state { return true } else { return false }
        }.value
        #expect(result)
    }
}

// MARK: - PipelineInputs termLabel Tests

@Suite("PipelineInputs termLabel")
struct PipelineInputsTermLabelTests {

    @Test("PipelineInputs has termLabel field with default empty string")
    func termLabelDefaultsToEmpty() {
        let inputs = PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/rec.m4a"),
            recordingStart: Date(),
            recordingEnd: Date(),
            durationSeconds: 1800,
            source: "MacBook Air",
            events: []
        )
        #expect(inputs.termLabel == "")
    }

    @Test("PipelineInputs accepts custom termLabel")
    func termLabelCustom() {
        let inputs = PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/rec.m4a"),
            recordingStart: Date(),
            recordingEnd: Date(),
            durationSeconds: 1800,
            source: "MacBook Air",
            events: [],
            termLabel: "Fall 2026"
        )
        #expect(inputs.termLabel == "Fall 2026")
    }
}

// MARK: - NoteNormalizer Parameterization Tests (Pitfall 5)

@Suite("NoteNormalizer Parameterization")
struct NoteNormalizerParameterizationTests {

    private func makeCourse() -> CalendarEvent {
        CalendarEvent(
            id: "evt-1",
            title: "Intro to CS",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_000_000 + 3600)
        )
    }

    private func makeTranscript() -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        [(start: 0.0, end: 2.0, text: "Welcome to the lecture.")]
    }

    @Test("normalize accepts term and source parameters")
    func normalizeAcceptsTermAndSource() throws {
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: makeCourse(),
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            term: "Fall 2026",
            source: "MacBook Pro"
        )

        #expect(note.frontmatter.term == "Fall 2026")
        #expect(note.frontmatter.source == "MacBook Pro")
    }

    @Test("normalize uses different term and source values correctly")
    func normalizeUsesDifferentValues() throws {
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: makeCourse(),
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            term: "Spring 2027",
            source: "iPhone"
        )

        #expect(note.frontmatter.term == "Spring 2027")
        #expect(note.frontmatter.source == "iPhone")
    }

    @Test("normalize with old hardcoded values produces correct frontmatter")
    func normalizeWithOldHardcodedValues() throws {
        // Existing Phase 2 tests that pass the old hardcoded values explicitly
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: makeCourse(),
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            term: "Fall 2026",
            source: "MacBook Air"
        )

        #expect(note.frontmatter.term == "Fall 2026")
        #expect(note.frontmatter.source == "MacBook Air")
    }
}

// MARK: - Orchestrator Pause/Resume Tests

@Suite("PipelineOrchestrator Pause/Resume")
struct PipelineOrchestratorPauseTests {

    // MARK: - Test Fixtures

    /// Creates PipelineInputs for a single-event match (no pause needed).
    private func makeSingleEventInputs() -> PipelineInputs {
        let recordingStart = Date(timeIntervalSince1970: 1_700_000_000)
        let event = CalendarEvent(
            id: "evt-cs101",
            title: "Intro to Computer Science",
            startDate: recordingStart,
            endDate: recordingStart.addingTimeInterval(3600)
        )
        return PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/recordings/lecture.m4a"),
            recordingStart: recordingStart,
            recordingEnd: recordingStart.addingTimeInterval(3600),
            durationSeconds: 3600,
            source: "MacBook Air",
            events: [event],
            termLabel: "Fall 2026"
        )
    }

    /// Creates PipelineInputs with no events (triggers .none -> pause).
    private func makeEmptyEventsInputs() -> PipelineInputs {
        let recordingStart = Date(timeIntervalSince1970: 1_700_000_000)
        return PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/recordings/lecture.m4a"),
            recordingStart: recordingStart,
            recordingEnd: recordingStart.addingTimeInterval(3600),
            durationSeconds: 3600,
            source: "MacBook Air",
            events: [],
            termLabel: "Fall 2026"
        )
    }

    /// Creates PipelineInputs with 2 overlapping events (triggers .multiple -> pause).
    private func makeMultipleEventsInputs() -> PipelineInputs {
        let recordingStart = Date(timeIntervalSince1970: 1_700_000_000)
        let event1 = CalendarEvent(
            id: "evt-1",
            title: "Math 101",
            startDate: recordingStart,
            endDate: recordingStart.addingTimeInterval(3600)
        )
        let event2 = CalendarEvent(
            id: "evt-2",
            title: "Physics 201",
            startDate: recordingStart,
            endDate: recordingStart.addingTimeInterval(3600)
        )
        return PipelineInputs(
            recordingURL: URL(fileURLWithPath: "/recordings/lecture.m4a"),
            recordingStart: recordingStart,
            recordingEnd: recordingStart.addingTimeInterval(3600),
            durationSeconds: 3600,
            source: "MacBook Air",
            events: [event1, event2],
            termLabel: "Fall 2026"
        )
    }

    /// Creates orchestrator with standard mock deps.
    private func makeOrchestrator() -> PipelineOrchestrator {
        PipelineOrchestrator(
            transcriber: PauseMockTranscriber(),
            writer: PauseMockNoteWriter(),
            resolver: PauseMockVaultResolver()
        )
    }

    // MARK: - Test 1: Single match runs to completion without pausing

    @Test("Single match runs to .completed without pausing")
    func singleMatchRunsToCompletion() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeSingleEventInputs()

        try await orchestrator.run(inputs: inputs)

        let finalState = await orchestrator.currentState
        if case .completed = finalState { /* success */ } else {
            Issue.record("Expected .completed, got: \(finalState)")
        }
    }

    // MARK: - Test 2: Empty events triggers .awaitingUserChoice, then resume

    @Test("Empty events pauses at .awaitingUserChoice, resume continues to .completed")
    func emptyEventsPausesThenResumes() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeEmptyEventsInputs()

        // Start the pipeline in a detached task — it will park at .awaitingUserChoice
        async let pipelineResult: Void = try await orchestrator.run(inputs: inputs)

        // Give the pipeline time to reach the pause state
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        // Verify we're parked at .awaitingUserChoice
        let pausedState = await orchestrator.currentState
        if case .awaitingUserChoice = pausedState { /* success */ } else {
            Issue.record("Expected .awaitingUserChoice, got: \(pausedState)")
        }

        // Resume with a user-selected event
        let userEvent = CalendarEvent(
            id: "user-pick",
            title: "Biology 101",
            startDate: inputs.recordingStart,
            endDate: inputs.recordingStart.addingTimeInterval(3600)
        )
        await orchestrator.resume(with: userEvent)

        // Pipeline should complete
        _ = try await pipelineResult

        let finalState = await orchestrator.currentState
        if case .completed = finalState { /* success */ } else {
            Issue.record("Expected .completed after resume, got: \(finalState)")
        }
    }

    // MARK: - Test 3: Multiple events triggers pause, skip routes to _unsorted

    @Test("Multiple events pauses, skipClassification continues to .completed")
    func multipleEventsPausesThenSkip() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeMultipleEventsInputs()

        async let pipelineResult: Void = try await orchestrator.run(inputs: inputs)

        // Wait for pause
        try? await Task.sleep(nanoseconds: 200_000_000)

        let pausedState = await orchestrator.currentState
        if case .awaitingUserChoice = pausedState { /* success */ } else {
            Issue.record("Expected .awaitingUserChoice for multiple events, got: \(pausedState)")
        }

        // Skip the classification
        await orchestrator.skipClassification()

        _ = try await pipelineResult

        let finalState = await orchestrator.currentState
        if case .completed = finalState { /* success */ } else {
            Issue.record("Expected .completed after skip, got: \(finalState)")
        }
    }

    // MARK: - Test 5: Cancel during pause transitions to .cancelled

    @Test("Cancel during .awaitingUserChoice transitions to .cancelled")
    func cancelDuringPause() async throws {
        let orchestrator = makeOrchestrator()
        let inputs = makeEmptyEventsInputs()

        async let pipelineResult: Void = try await orchestrator.run(inputs: inputs)

        // Wait for pause
        try? await Task.sleep(nanoseconds: 200_000_000)

        let pausedState = await orchestrator.currentState
        if case .awaitingUserChoice = pausedState { /* success */ } else {
            Issue.record("Expected .awaitingUserChoice before cancel, got: \(pausedState)")
        }

        // Cancel while paused
        await orchestrator.cancel()

        // Await — should throw CancellationError
        do {
            _ = try await pipelineResult
            Issue.record("Should have thrown cancellation error")
        } catch {
            // Expected
        }

        let finalState = await orchestrator.currentState
        if case .cancelled = finalState { /* success */ } else {
            Issue.record("Expected .cancelled after cancel during pause, got: \(finalState)")
        }
    }
}

// MARK: - Mock Implementations for Pause Tests

/// Mock transcriber that returns minimal segments immediately.
private struct PauseMockTranscriber: PipelineTranscriber {
    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        [(start: 0.0, end: 1.0, text: "Test transcript.")]
    }
}

/// Mock note writer that succeeds silently.
private struct PauseMockNoteWriter: NoteWriter {
    func write(_ note: NormalizedNote, to destination: URL) async throws {
        // Success — no-op
    }
}

/// Mock resolver that accepts any .single match and returns a path.
private struct PauseMockVaultResolver: VaultPathResolver {
    func resolve(match: CourseMatch, recordingStart: Date) throws -> URL {
        switch match {
        case .single:
            return URL(fileURLWithPath: "/tmp/vault/test-lecture.md")
        case .multiple:
            throw PipelineError.invalidInputs
        case .none:
            throw PipelineError.invalidInputs
        }
    }
}
