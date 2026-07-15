import Testing
import Foundation
@testable import UnibrainCore

@Suite("CalendarEvent")
struct CalendarEventTests {

    @Test("CalendarEvent constructs with all fields including location")
    func constructsWithAllFields() throws {
        let event = CalendarEvent(
            id: "evt-001",
            title: "Intro to Computer Science",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 3_600),
            location: "Room 101"
        )

        #expect(event.id == "evt-001")
        #expect(event.title == "Intro to Computer Science")
        #expect(event.startDate == Date(timeIntervalSince1970: 1_000))
        #expect(event.endDate == Date(timeIntervalSince1970: 3_600))
        #expect(event.location == "Room 101")
    }

    @Test("CalendarEvent constructs with location: nil")
    func constructsWithNilLocation() throws {
        let event = CalendarEvent(
            id: "evt-002",
            title: "Calculus I",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1_800)
        )

        #expect(event.location == nil)
    }

    @Test("CalendarEvent is Sendable and can cross concurrency boundaries")
    func isSendable() async throws {
        let event = CalendarEvent(
            id: "evt-003",
            title: "Physics 201",
            startDate: Date(timeIntervalSince1970: 5_000),
            endDate: Date(timeIntervalSince1970: 7_000),
            location: "Lab 3"
        )

        // Cross actor boundary — Sendable conformance verified at compile time
        let result = await Task { event }.value
        #expect(result.id == "evt-003")
    }

    @Test("CalendarEvent.id is stable identifier using UUID")
    func stableIdWithUUID() throws {
        let uuid = UUID().uuidString
        let event = CalendarEvent(
            id: uuid,
            title: "Chemistry",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 1_000)
        )

        #expect(event.id == uuid)
        #expect(event.id.count == 36) // UUID string length
    }
}
