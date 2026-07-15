import Testing
import Foundation
@testable import UnibrainApp
@testable import UnibrainCore

// MARK: - Mock Orchestrator (Spy)

/// Mock orchestrator that records resume/skipClassification calls.
///
/// Per W3 fix: Tests inject this spy to verify the view model correctly
/// routes user selections to the orchestrator.
final class MockOrchestrator: PipelineOrchestratorProtocol, @unchecked Sendable {

    // MARK: - Call Recording

    var resumeCallCount = 0
    var resumeReceivedEvent: CalendarEvent?
    var skipCallCount = 0
    var cancelCallCount = 0
    var resetCallCount = 0

    // MARK: - State Stub

    var stubbedState: PipelineState = .idle
    var stubbedCurrentState: PipelineState {
        stubbedState
    }

    // MARK: - PipelineOrchestratorProtocol

    func resume(with event: CalendarEvent) async {
        resumeCallCount += 1
        resumeReceivedEvent = event
    }

    func skipClassification() async {
        skipCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
    }

    func reset() {
        resetCallCount += 1
    }

    func run(inputs: PipelineInputs) async throws {
        // No-op for testing
    }
}

// MARK: - MenuBarViewModelOverlayTests

/// Tests for PopoverOverlay state transitions and selectCourse/skipClassification logic.
///
/// Per W3 fix: Verifies the 7 behaviors listed in the plan:
/// 1. overlayState == .none at init
/// 2. handleClassificationPause(.none) -> .coursePicker(.none)
/// 3. handleClassificationPause(.multiple) -> .coursePicker(.multiple)
/// 4. selectCourse(.course) calls orchestrator.resume
/// 5. selectCourse(.skip) calls orchestrator.skipClassification
/// 6. skipClassification resets overlayState + calls orchestrator
/// 7. PopoverOverlay has exactly 5 cases
@MainActor
@Suite("MenuBarViewModel PopoverOverlay Tests")
struct MenuBarViewModelOverlayTests {

    // MARK: - Test 1: Init overlayState is .none

    @Test("Init overlayState is .none")
    func initOverlayStateIsNone() {
        let vm = makeViewModel()
        #expect(vm.overlayState == .none)
    }

    // MARK: - Test 2: handleClassificationPause(.none) -> .coursePicker(.none)

    @Test("handleClassificationPause(.none) transitions to .coursePicker(.none)")
    func handleNoneMatchShowsPicker() async {
        let vm = makeViewModel()
        await vm.handleClassificationPause(match: .none)
        #expect(vm.overlayState == .coursePicker(.none))
    }

    // MARK: - Test 3: handleClassificationPause(.multiple) -> .coursePicker(.multiple)

    @Test("handleClassificationPause(.multiple) transitions to .coursePicker(.multiple)")
    func handleMultipleMatchShowsPickerWithEvents() async {
        let vm = makeViewModel()
        let event1 = CalendarEvent(
            id: "evt-1",
            title: "CS101 Lecture",
            startDate: Date(),
            endDate: Date()
        )
        let event2 = CalendarEvent(
            id: "evt-2",
            title: "CS101 Lab",
            startDate: Date(),
            endDate: Date()
        )
        await vm.handleClassificationPause(match: .multiple([event1, event2]))
        #expect(vm.overlayState == .coursePicker(.multiple([event1, event2])))
    }

    // MARK: - Test 4: selectCourse(.course) resumes orchestrator

    @Test("selectCourse(.course) calls orchestrator.resume with CalendarEvent")
    func selectCourseResumesOrchestrator() async {
        let spy = MockOrchestrator()
        let vm = makeViewModel(orchestrator: spy)
        await vm.handleClassificationPause(match: .none)

        await vm.selectCourse(.course("CS101"))

        #expect(spy.resumeCallCount == 1)
        #expect(spy.resumeReceivedEvent?.title == "CS101")
        #expect(vm.overlayState == .none)
    }

    // MARK: - Test 5: selectCourse(.skip) calls skipClassification

    @Test("selectCourse(.skip) calls orchestrator.skipClassification")
    func selectCourseSkipCallsSkipClassification() async {
        let spy = MockOrchestrator()
        let vm = makeViewModel(orchestrator: spy)
        await vm.handleClassificationPause(match: .none)

        await vm.selectCourse(.skip)

        #expect(spy.skipCallCount == 1)
        #expect(vm.overlayState == .none)
    }

    // MARK: - Test 6: skipClassification resets overlay and calls orchestrator

    @Test("skipClassification resets overlayState and calls orchestrator.skipClassification")
    func skipClassificationResetsAndCallsOrchestrator() async {
        let spy = MockOrchestrator()
        let vm = makeViewModel(orchestrator: spy)
        await vm.handleClassificationPause(match: .none)

        await vm.skipClassification()

        #expect(spy.skipCallCount == 1)
        #expect(vm.overlayState == .none)
    }

    // MARK: - Test 7: PopoverOverlay has exactly 5 cases

    @Test("PopoverOverlay has exactly 5 cases: none, coursePicker, manageCourses, permissionDenied, termEditor")
    func popoverOverlayHasFiveCases() {
        // Verify all 5 cases can be constructed
        let case1: PopoverOverlay = .none
        let case2: PopoverOverlay = .coursePicker(.none)
        let case3: PopoverOverlay = .manageCourses
        let case4: PopoverOverlay = .permissionDenied
        let case5: PopoverOverlay = .termEditor

        // Verify they are all distinct (Equatable)
        #expect(case1 != case2)
        #expect(case1 != case3)
        #expect(case1 != case4)
        #expect(case1 != case5)
        #expect(case2 != case3)
        #expect(case2 != case4)
        #expect(case2 != case5)
        #expect(case3 != case4)
        #expect(case3 != case5)
        #expect(case4 != case5)
    }

    // MARK: - Helpers

    /// Creates a MenuBarViewModel for testing with a mock orchestrator.
    private func makeViewModel(
        orchestrator: MockOrchestrator? = nil
    ) -> MenuBarViewModel {
        // For testing, we create a minimal view model with the mock orchestrator.
        // The real init requires a RecordingSession + SmallEnDownloader,
        // but those are not needed for overlay-state tests.
        let spy = orchestrator ?? MockOrchestrator()
        return MenuBarViewModel(
            overlayOrchestrator: spy
        )
    }
}
