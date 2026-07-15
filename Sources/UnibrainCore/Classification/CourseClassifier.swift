import Foundation

/// Pure static matcher that classifies a recording to a calendar event by time overlap.
///
/// Per C-03: Uses a ±30min window around the recording start timestamp.
/// Per C-04: Pure matcher — no EventKit dependency, no course-code resolution.
/// Phase 4's EventKit adapter provides events; Phase 4 resolves the matched
/// event to a course code.
///
/// Per Pattern 7: Struct with static func — no state, no instance data.
public struct CourseClassifier {

    /// Matches a recording start time against a list of calendar events.
    ///
    /// Per C-03: The ±30min window means any event whose time range overlaps
    /// [recordingStart - window, recordingStart + window] is a candidate.
    /// Standard interval overlap: `event.startDate <= windowEnd AND event.endDate >= windowStart`.
    ///
    /// Per C-02: Returns three states:
    /// - `.single` when exactly one event overlaps — auto-routing succeeds
    /// - `.multiple` when 2+ events overlap — Phase 4 shows manual picker
    /// - `.none` when zero events overlap — Phase 4 prompts user
    ///
    /// - Parameters:
    ///   - events: Calendar events to match against (from EventKit adapter in Phase 4).
    ///   - recordingStart: The recording start timestamp.
    ///   - window: Half-width of the match window in seconds (default: 1800 = ±30min per C-03).
    /// - Returns: ``CourseMatch`` indicating the match result.
    public static func match(
        events: [CalendarEvent],
        against recordingStart: Date,
        window: TimeInterval = 1800
    ) -> CourseMatch {
        let windowStart = recordingStart.addingTimeInterval(-window)
        let windowEnd = recordingStart.addingTimeInterval(window)

        let overlapping = events.filter { event in
            event.startDate <= windowEnd && event.endDate >= windowStart
        }

        switch overlapping.count {
        case 0:
            return .none
        case 1:
            return .single(overlapping[0])
        default:
            return .multiple(overlapping)
        }
    }
}
