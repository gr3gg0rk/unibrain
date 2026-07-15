import Foundation

/// Pure-logic filter that narrows calendar events to a ±30min recording window.
///
/// Per CT-02: Two-stage filter:
/// 1. EventKit term-range predicate (applied in the adapter query — broad)
/// 2. Swift-side ±30min filter (applied here — narrow)
///
/// Per RESEARCH.md Pitfall 6: TermRangeFilter handles ONLY the ±30min
/// narrowing. The term-range predicate is applied at the EventKit query
/// level in `EventKitCalendarAdapter.fetchEvents(in:)`.
///
/// Per C-03: The ±30min window means any event whose time range overlaps
/// `[recordingStart - window, recordingStart + window]` is a candidate.
/// Standard interval overlap:
/// `event.startDate <= windowEnd AND event.endDate >= windowStart`.
///
/// This filter is separate from `CourseClassifier.match` because the adapter
/// can pre-filter events before passing them to the orchestrator, reducing
/// the event set before classification runs. `CourseClassifier.match` also
/// applies the same overlap logic, but on the already-narrowed set.
public struct TermRangeFilter: Sendable {

    /// Narrows events to those overlapping the recording window.
    ///
    /// - Parameters:
    ///   - allEvents: All events from a broad date-range query (typically
    ///     the full term range from the EventKit adapter).
    ///   - recordingStart: The recording start timestamp.
    ///   - window: Half-width of the match window in seconds
    ///     (default: 1800 = ±30min per C-03).
    /// - Returns: Events overlapping `[recordingStart - window, recordingStart + window]`.
    public static func filterEvents(
        allEvents: [CalendarEvent],
        recordingStart: Date,
        window: TimeInterval = 1800
    ) -> [CalendarEvent] {
        let windowStart = recordingStart.addingTimeInterval(-window)
        let windowEnd = recordingStart.addingTimeInterval(window)

        return allEvents.filter { event in
            event.startDate <= windowEnd && event.endDate >= windowStart
        }
    }
}
