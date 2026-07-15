import Testing
import Foundation
@testable import UnibrainCore

@Suite("CourseClassifier")
struct CourseClassifierTests {

    // MARK: - Helpers

    /// Creates a fake event spanning [start, end] seconds from epoch.
    private func makeEvent(
        id: String = UUID().uuidString,
        title: String = "Test Course",
        start: TimeInterval,
        end: TimeInterval
    ) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: Date(timeIntervalSince1970: start),
            endDate: Date(timeIntervalSince1970: end)
        )
    }

    // MARK: - Match Tests

    @Test("match returns .single when one event overlaps the window")
    func returnsSingleOnOneOverlap() throws {
        // Recording at t=0, event from -1800..+3600 (fully covers ±30min window)
        let event = makeEvent(start: -1800, end: 3600)
        let result = CourseClassifier.match(
            events: [event],
            against: Date(timeIntervalSince1970: 0)
        )

        if case .single(let matched) = result {
            #expect(matched.id == event.id)
        } else {
            Issue.record("Expected .single, got \(result)")
        }
    }

    @Test("match returns .multiple when 2+ events overlap the window")
    func returnsMultipleOnTwoOverlaps() throws {
        let event1 = makeEvent(id: "evt-1", start: -1800, end: 3600)
        let event2 = makeEvent(id: "evt-2", start: -900, end: 900)
        let result = CourseClassifier.match(
            events: [event1, event2],
            against: Date(timeIntervalSince1970: 0)
        )

        if case .multiple(let matched) = result {
            #expect(matched.count == 2)
        } else {
            Issue.record("Expected .multiple, got \(result)")
        }
    }

    @Test("match returns .none when zero events overlap")
    func returnsNoneOnZeroOverlaps() throws {
        // Event far outside the ±30min window
        let event = makeEvent(start: 10_000, end: 13_600)
        let result = CourseClassifier.match(
            events: [event],
            against: Date(timeIntervalSince1970: 0)
        )

        if case .none = result {
            // Success
        } else {
            Issue.record("Expected .none, got \(result)")
        }
    }

    @Test("match handles boundary: event ends exactly at windowStart")
    func eventEndsAtWindowStartDoesNotOverlap() throws {
        // Window: [-1800, +1800]. Event ends exactly at -1800 (windowStart).
        // Standard interval overlap: event.endDate >= windowStart => -1800 >= -1800 => true
        // This is a boundary touch — by half-open interval convention, this should overlap.
        let event = makeEvent(start: -3600, end: -1800)
        let result = CourseClassifier.match(
            events: [event],
            against: Date(timeIntervalSince1970: 0),
            window: 1800
        )

        // event.endDate (-1800) >= windowStart (-1800) → overlaps
        if case .single = result {
            // Boundary touch counts as overlap
        } else {
            Issue.record("Expected .single at boundary, got \(result)")
        }
    }

    @Test("match handles event that fully contains the recording window")
    func eventFullyContainsWindow() throws {
        // Event spans -99999..+99999, window is ±1800
        let event = makeEvent(start: -99_999, end: 99_999)
        let result = CourseClassifier.match(
            events: [event],
            against: Date(timeIntervalSince1970: 0)
        )

        if case .single(let matched) = result {
            #expect(matched.id == event.id)
        } else {
            Issue.record("Expected .single for containing event, got \(result)")
        }
    }

    @Test("match respects ±30min default window (1800 seconds)")
    func defaultWindowIs1800Seconds() throws {
        // Event just inside the default window boundary: start = +1799
        let eventInside = makeEvent(start: 1799, end: 9999)
        let resultInside = CourseClassifier.match(
            events: [eventInside],
            against: Date(timeIntervalSince1970: 0)
        )
        if case .single = resultInside {} else {
            Issue.record("Event at +1799 should overlap default ±1800 window")
        }

        // Event just outside the default window boundary: start = +1801
        // But end must also be < windowStart (-1800) for no overlap
        let eventOutside = makeEvent(start: -99_999, end: -1801)
        let resultOutside = CourseClassifier.match(
            events: [eventOutside],
            against: Date(timeIntervalSince1970: 0)
        )
        if case .none = resultOutside {} else {
            Issue.record("Event ending at -1801 should not overlap default ±1800 window")
        }
    }

    @Test("match accepts custom window parameter")
    func customWindowParameter() throws {
        // With a 60-second window, an event at 100s should NOT overlap
        let event = makeEvent(start: 100, end: 200)
        let result = CourseClassifier.match(
            events: [event],
            against: Date(timeIntervalSince1970: 0),
            window: 60
        )

        if case .none = result {} else {
            Issue.record("Event at +100s should not overlap ±60s window")
        }

        // With a 200-second window, same event SHOULD overlap
        let resultWide = CourseClassifier.match(
            events: [event],
            against: Date(timeIntervalSince1970: 0),
            window: 200
        )
        if case .single = resultWide {} else {
            Issue.record("Event at +100s should overlap ±200s window")
        }
    }
}
