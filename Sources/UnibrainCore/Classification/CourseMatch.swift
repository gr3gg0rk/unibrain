import Foundation

/// Three-state result of matching a recording timestamp against calendar events.
///
/// Per C-02: CourseClassifier.match returns one of three states.
/// This is a result type, NOT an error type — ambiguous matches (`.multiple`)
/// are a normal flow that Phase 4 resolves via manual picker fallback.
public enum CourseMatch: Sendable {
    /// Exactly one event overlaps the recording window.
    /// Phase 4 uses this event's title to resolve the course code.
    case single(CalendarEvent)

    /// Two or more events overlap the recording window.
    /// Phase 4 presents a manual picker so the user selects the correct course.
    case multiple([CalendarEvent])

    /// Zero events overlap the recording window.
    /// Phase 4 prompts the user to manually select or create a course.
    case none
}
