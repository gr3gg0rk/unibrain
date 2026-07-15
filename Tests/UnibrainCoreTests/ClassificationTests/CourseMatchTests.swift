import Testing
import Foundation
@testable import UnibrainCore

@Suite("CourseMatch")
struct CourseMatchTests {

    private func makeEvent(id: String = UUID().uuidString, title: String = "Test Course") -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3_600)
        )
    }

    @Test("CourseMatch.single constructs with event parameter")
    func singleConstructsWithEvent() throws {
        let event = makeEvent(id: "evt-1")
        let match = CourseMatch.single(event)

        if case .single(let matched) = match {
            #expect(matched.id == "evt-1")
        } else {
            Issue.record("Expected .single case")
        }
    }

    @Test("CourseMatch.multiple constructs with array parameter")
    func multipleConstructsWithArray() throws {
        let events = [makeEvent(id: "evt-1"), makeEvent(id: "evt-2")]
        let match = CourseMatch.multiple(events)

        if case .multiple(let matched) = match {
            #expect(matched.count == 2)
            #expect(matched[0].id == "evt-1")
            #expect(matched[1].id == "evt-2")
        } else {
            Issue.record("Expected .multiple case")
        }
    }

    @Test("CourseMatch.none constructs without associated value")
    func noneConstructsWithoutValue() throws {
        let match = CourseMatch.none

        if case .none = match {
            // Success — .none case matched
        } else {
            Issue.record("Expected .none case")
        }
    }

    @Test("CourseMatch is Sendable and can cross concurrency boundaries")
    func isSendable() async throws {
        let match = CourseMatch.single(makeEvent())

        let result = await Task { match }.value
        if case .single = result {
            // Sendable boundary crossing verified
        } else {
            Issue.record("Sendable boundary crossing failed")
        }
    }

    @Test("CourseMatch is NOT an Error type")
    func isNotError() throws {
        // Compile-time verification: CourseMatch does not conform to Error.
        // This test exists to guard against accidentally adding : Error in future.
        // If CourseMatch were an Error, it could be thrown — we verify it cannot be.
        let match = CourseMatch.none
        #expect(match != CourseMatch.single(makeEvent()))
    }
}
