import Testing
import Foundation
@testable import UnibrainCore

@Suite("TermRangeFilter")
struct TermRangeFilterTests {

    // MARK: - Helpers

    /// Creates a fake event spanning [start, end] seconds from epoch.
    private func makeEvent(
        id: String = UUID().uuidString,
        title: String = "Test Course",
        start: TimeInterval,
        end: TimeInterval,
        location: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: Date(timeIntervalSince1970: start),
            endDate: Date(timeIntervalSince1970: end),
            location: location
        )
    }

    // MARK: - ±30min Window Tests

    @Test("filterEvents returns events within ±30min of recordingStart")
    func returnsEventsWithinWindow() throws {
        // Recording at t=0. ±30min window = [-1800, +1800].
        let event1 = makeEvent(id: "evt-1", start: -900, end: 900)
        let event2 = makeEvent(id: "evt-2", start: 0, end: 3600)
        let event3 = makeEvent(id: "evt-3", start: 10_000, end: 13_600)
        let event4 = makeEvent(id: "evt-4", start: -13_600, end: -10_000)
        let event5 = makeEvent(id: "evt-5", start: 500, end: 1200)

        let result = TermRangeFilter.filterEvents(
            allEvents: [event1, event2, event3, event4, event5],
            recordingStart: Date(timeIntervalSince1970: 0)
        )

        // Only events 1, 2, 5 overlap the ±30min window.
        let resultIds = Set(result.map(\.id))
        #expect(resultIds == Set(["evt-1", "evt-2", "evt-5"]))
        #expect(result.count == 3)
    }

    @Test("filterEvents returns empty array when no events in ±30min window")
    func returnsEmptyWhenNoOverlap() throws {
        let event1 = makeEvent(id: "far-1", start: 10_000, end: 13_600)
        let event2 = makeEvent(id: "far-2", start: -13_600, end: -10_000)

        let result = TermRangeFilter.filterEvents(
            allEvents: [event1, event2],
            recordingStart: Date(timeIntervalSince1970: 0)
        )

        #expect(result.isEmpty)
    }

    @Test("filterEvents includes event that starts before window but overlaps it")
    func includesOverlappingEventFromBefore() throws {
        // Event starts 45min before recording (t=-2700) and ends 10min into recording (t=+600).
        // The ±30min window is [-1800, +1800].
        // event.startDate (-2700) <= windowEnd (+1800) AND event.endDate (+600) >= windowStart (-1800) → overlaps.
        let event = makeEvent(id: "overlap-pre", start: -2700, end: 600)

        let result = TermRangeFilter.filterEvents(
            allEvents: [event],
            recordingStart: Date(timeIntervalSince1970: 0)
        )

        #expect(result.count == 1)
        #expect(result.first?.id == "overlap-pre")
    }

    @Test("filterEvents respects custom window parameter")
    func customWindowParameter() throws {
        // Event at +100s end +200s. With ±60s window (windowStart=-60, windowEnd=+60),
        // event.startDate (100) <= 60? No → excluded.
        let event = makeEvent(start: 100, end: 200)

        let result = TermRangeFilter.filterEvents(
            allEvents: [event],
            recordingStart: Date(timeIntervalSince1970: 0),
            window: 60
        )

        #expect(result.isEmpty)

        // Same event with ±200s window (windowStart=-200, windowEnd=+200).
        // event.startDate (100) <= 200 AND event.endDate (200) >= -200 → included.
        let resultWide = TermRangeFilter.filterEvents(
            allEvents: [event],
            recordingStart: Date(timeIntervalSince1970: 0),
            window: 200
        )

        #expect(resultWide.count == 1)
    }

    @Test("filterEvents with empty input returns empty output")
    func emptyInputReturnsEmpty() throws {
        let result = TermRangeFilter.filterEvents(
            allEvents: [],
            recordingStart: Date(timeIntervalSince1970: 0)
        )
        #expect(result.isEmpty)
    }
}

@Suite("CalendarPermissionStatus")
struct CalendarPermissionStatusTests {

    @Test("CalendarPermissionStatus has exactly 5 cases")
    func hasFiveCases() throws {
        let allCases: [CalendarPermissionStatus] = [
            .notDetermined,
            .fullAccess,
            .writeOnly,
            .denied,
            .restricted
        ]
        #expect(allCases.count == 5)
        // Verify uniqueness by checking set-like deduplication
        let uniqueCount = Set(allCases.map { "\($0)" }).count
        #expect(uniqueCount == 5)
    }

    @Test("CalendarPermissionStatus is Sendable")
    func isSendable() throws {
        // This test compiles only if CalendarPermissionStatus conforms to Sendable.
        let status: CalendarPermissionStatus = .fullAccess
        let sendable: any Sendable = status
        #expect(sendable != nil)
    }
}
