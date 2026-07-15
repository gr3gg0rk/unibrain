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
