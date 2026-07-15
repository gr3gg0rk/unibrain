import Foundation

#if canImport(AVFoundation)
import AVFoundation

/// State machine for a recording session lifecycle.
///
/// Per CAPT-01: drives the recording start/stop lifecycle.
/// Per CAPT-02: tracks pause/resume with contiguous audio.
/// Per CAPT-04: elapsedSeconds drives the live timer in the UI.
/// Per CAPT-05: currentLevel delegates to AudioRecorder for the mic meter.
///
/// Per P-D1: pauseIntervals are exposed so the transcription layer can
/// insert `[Paused HH:MM:SS-HH:MM:SS]` markers into the transcript.
///
/// Per P-D2: audio is recorded to a temp directory and moved to the
/// destination URL on stop — crash safety against partial files.
public actor RecordingSession: Sendable {

    // MARK: - Public Types

    /// The lifecycle state of a recording session.
    public enum State: Sendable, Equatable {
        case idle
        case recording
        case paused
        case stopped
    }

    /// A recorded pause interval for inline transcript markers (P-D1).
    public struct PauseInterval: Sendable, Equatable {
        /// Start time of the pause, in seconds from recording start.
        public let start: TimeInterval
        /// Duration of the pause, in seconds.
        public let duration: TimeInterval

        public init(start: TimeInterval, duration: TimeInterval) {
            self.start = start
            self.duration = duration
        }
    }

    /// Result of a completed recording session.
    public struct Result: Sendable {
        /// The final audio file URL (destination after temp-then-move).
        public let audioURL: URL
        /// Total recording duration in seconds (excluding paused time).
        public let durationSeconds: Int
        /// Pause intervals for inline transcript markers (P-D1).
        public let pauseIntervals: [PauseInterval]

        public init(audioURL: URL, durationSeconds: Int, pauseIntervals: [PauseInterval]) {
            self.audioURL = audioURL
            self.durationSeconds = durationSeconds
            self.pauseIntervals = pauseIntervals
        }
    }

    /// Error thrown when an invalid state transition is attempted.
    public enum Error: Swift.Error, Sendable {
        /// Attempted to start recording when not in .idle state.
        case alreadyRecording
        /// Attempted to pause when not in .recording state.
        case notRecording
        /// Attempted to resume when not in .paused state.
        case notPaused
        /// Attempted to stop when in .idle or .stopped state.
        case notActive
    }

    // MARK: - Private State

    /// Current session state.
    private var state: State = .idle

    /// The underlying audio recorder.
    private var recorder: AudioRecorder?

    /// When the current recording segment started.
    private var startTime: Date?

    /// When the current pause started.
    private var pausedAt: Date?

    /// Total time spent paused across all pause intervals.
    private var totalPausedTime: TimeInterval = 0

    /// Recorded pause intervals for P-D1 inline markers.
    private var pauseIntervals: [PauseInterval] = []

    /// The temp URL where audio is currently being recorded.
    private var tempURL: URL?

    /// The final destination URL for the audio file.
    private var destinationURL: URL?

    // MARK: - Public Read-Only Properties

    /// The current session state.
    public var currentState: State { state }

    /// Elapsed recording time in seconds, excluding paused intervals.
    ///
    /// Per CAPT-04: drives the live timer in the menu-bar popover.
    /// When paused, returns the frozen value (does not advance).
    public var elapsedSeconds: TimeInterval {
        guard let startTime else { return 0 }

        let now = Date()
        let totalElapsed = now.timeIntervalSince(startTime)

        if state == .paused {
            // Frozen: subtract paused time up to the pause point
            let currentPauseDuration = pausedAt.map { now.timeIntervalSince($0) } ?? 0
            return max(0, totalElapsed - totalPausedTime - currentPauseDuration)
        }

        return max(0, totalElapsed - totalPausedTime)
    }

    /// Current mic level in dB, delegating to AudioRecorder.
    ///
    /// Per CAPT-05: drives the mic-level meter in the UI.
    /// Returns -160.0 (silence floor) when not recording.
    public var currentLevel: Float {
        recorder?.currentLevel ?? -160.0
    }

    // MARK: - Lifecycle Methods

    /// Starts a new recording session.
    ///
    /// Per CAPT-01: begins recording to a temp file.
    /// Per P-D2: records to NSTemporaryDirectory(), moved to destination on stop.
    ///
    /// - Parameter destination: The final URL where the audio file should land.
    /// - Throws: ``Error/alreadyRecording`` if not in .idle state.
    public func startRecording(destination: URL) throws {
        guard state == .idle else {
            throw Error.alreadyRecording
        }

        // Create temp URL in the system temp directory (P-D2)
        let tempDir = FileManager.default.temporaryDirectory
        let temp = tempDir.appendingPathComponent("unibrain_rec_\(UUID().uuidString).m4a")

        let newRecorder = AudioRecorder()
        try newRecorder.start(to: temp)

        recorder = newRecorder
        tempURL = temp
        destinationURL = destination
        startTime = Date()
        totalPausedTime = 0
        pauseIntervals = []
        pausedAt = nil
        state = .recording
    }

    /// Pauses the current recording.
    ///
    /// Per CAPT-02: pauses without finalizing the file.
    ///
    /// - Throws: ``Error/notRecording`` if not in .recording state.
    public func pause() throws {
        guard state == .recording else {
            throw Error.notRecording
        }

        recorder?.pause()
        pausedAt = Date()
        state = .paused
    }

    /// Resumes recording after a pause.
    ///
    /// Per CAPT-02: continues writing to the same file.
    /// Records the pause interval for P-D1 inline transcript markers.
    ///
    /// - Throws: ``Error/notPaused`` if not in .paused state.
    public func resume() throws {
        guard state == .paused else {
            throw Error.notPaused
        }

        guard let pausedAt, let startTime else {
            throw Error.notPaused
        }

        let now = Date()
        let pauseDuration = now.timeIntervalSince(pausedAt)
        totalPausedTime += pauseDuration

        // Record the pause interval relative to recording start (P-D1)
        let pauseStartRelative = pausedAt.timeIntervalSince(startTime) - (totalPausedTime - pauseDuration)
        pauseIntervals.append(PauseInterval(
            start: max(0, pauseStartRelative),
            duration: pauseDuration
        ))

        recorder?.resume()
        self.pausedAt = nil
        state = .recording
    }

    /// Stops recording and finalizes the audio file.
    ///
    /// Per CAPT-01: stops recording and produces the final .m4a file.
    /// Per P-D2: moves the temp file to the destination URL.
    ///
    /// - Returns: A ``Result`` with the audio URL, duration, and pause intervals.
    /// - Throws: ``Error/notActive`` if in .idle or .stopped state.
    public func stop() throws -> Result {
        guard state == .recording || state == .paused else {
            throw Error.notActive
        }

        recorder?.stop()

        // If we were paused when stopped, record the final pause interval
        if state == .paused, let pausedAt, let startTime {
            let now = Date()
            let pauseDuration = now.timeIntervalSince(pausedAt)
            totalPausedTime += pauseDuration

            let pauseStartRelative = pausedAt.timeIntervalSince(startTime) - (totalPausedTime - pauseDuration)
            pauseIntervals.append(PauseInterval(
                start: max(0, pauseStartRelative),
                duration: pauseDuration
            ))
        }

        // Compute final duration
        let finalDuration: TimeInterval
        if let startTime {
            finalDuration = max(0, Date().timeIntervalSince(startTime) - totalPausedTime)
        } else {
            finalDuration = 0
        }

        // Move temp file to destination (P-D2)
        guard let tempURL, let destinationURL else {
            throw Error.notActive
        }

        // Remove destination if it already exists (overwrite)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        // Create parent directory if needed
        let parentDir = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        // Move temp file to destination
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        state = .stopped

        return Result(
            audioURL: destinationURL,
            durationSeconds: Int(finalDuration),
            pauseIntervals: pauseIntervals
        )
    }

    /// Resets the session back to .idle for a new recording.
    ///
    /// Clears all stored state. Use after .stopped to start a new session
    /// with the same RecordingSession actor instance.
    public func reset() {
        state = .idle
        recorder = nil
        startTime = nil
        pausedAt = nil
        totalPausedTime = 0
        pauseIntervals = []
        tempURL = nil
        destinationURL = nil
    }
}

#endif // canImport(AVFoundation)
