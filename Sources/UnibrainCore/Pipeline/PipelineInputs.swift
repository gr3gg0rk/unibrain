import Foundation

/// Carries all data needed for a single pipeline run.
///
/// Per O-05: Six fields capture everything the orchestrator and its
/// pure-logic components need from the capture session:
/// - `recordingURL`: Audio file path (passed to AudioTranscriber)
/// - `recordingStart`: Timestamp used by CourseClassifier for time-overlap matching
/// - `recordingEnd`: When recording stopped (metadata for future use)
/// - `durationSeconds`: Recording length (passed to NoteNormalizer for frontmatter)
/// - `source`: Device name (e.g., "MacBook Air", "iPhone") for frontmatter `source` field
/// - `events`: Calendar events from EventKit adapter (passed to CourseClassifier)
///
/// `Sendable` so it can be constructed outside the orchestrator actor and
/// passed in via `run(inputs:)`. Not `Codable` — no serialization needed.
public struct PipelineInputs: Sendable {
    /// Audio file URL for transcription.
    public var recordingURL: URL
    /// Timestamp when recording started.
    public var recordingStart: Date
    /// Timestamp when recording ended.
    public var recordingEnd: Date
    /// Recording duration in seconds.
    public var durationSeconds: Int
    /// Source device name (e.g., "MacBook Air").
    public var source: String
    /// Calendar events for course classification.
    public var events: [CalendarEvent]

    public init(
        recordingURL: URL,
        recordingStart: Date,
        recordingEnd: Date,
        durationSeconds: Int,
        source: String,
        events: [CalendarEvent]
    ) {
        self.recordingURL = recordingURL
        self.recordingStart = recordingStart
        self.recordingEnd = recordingEnd
        self.durationSeconds = durationSeconds
        self.source = source
        self.events = events
    }
}
