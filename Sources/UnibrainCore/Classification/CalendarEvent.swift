import Foundation

/// Apple-framework-agnostic calendar event for course classification.
///
/// Per C-01: Phase 4's EventKit adapter maps `EKEvent` → `CalendarEvent`
/// at the boundary. Phase 2 tests build fake events directly.
/// `id` enables stable identity across recurrences; `location` is optional.
///
/// `Codable` conformance enables Phase 4 EventKit adapter serialization if needed.
public struct CalendarEvent: Codable, Sendable {
    /// Stable identifier (e.g., EventKit identifier or UUID for tests).
    public let id: String
    /// Event title (e.g., "Intro to Computer Science").
    public let title: String
    /// Event start date.
    public let startDate: Date
    /// Event end date.
    public let endDate: Date
    /// Optional location (e.g., room number).
    public let location: String?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        location: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
    }
}
