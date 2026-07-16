import Foundation

#if os(macOS)

/// Retry tracking + dead-letter handling for the inbox queue (TRIG-04).
///
/// Per TRIG-04: failed files retry up to ``maxRetries`` times with
/// exponential backoff (``backoffSchedule`` = 30s, 2min, 10min). On the
/// final failure the file is moved to `_inbox/_failed/` with a sidecar
/// `.error.json` containing ONLY error metadata (T-05-10: never transcript
/// text, audio content, or course names).
///
/// Per TRIG-04: this is queue-level retry, DISTINCT from Phase 6's
/// cloud-provider retry (CLOUD-10) which is per-call inside the provider
/// client. The two retry layers compose cleanly.
///
/// Per TRIG-02: the queue processes one file at a time, so the
/// `retryTracker` dictionary has no concurrent-access concern — the actor
/// isolation of ``InboxQueue`` serializes access.
public actor DeadLetterHandler {

    /// Maximum retry attempts before dead-lettering (TRIG-04).
    public static let maxRetries = 3

    /// Exponential backoff schedule in seconds (TRIG-04: 30s, 2min, 10min).
    public static let backoffSchedule: [TimeInterval] = [30, 120, 600]

    /// Per-file URL retry counts.
    private var retryTracker: [URL: Int] = [:]

    /// Creates a new dead-letter handler.
    public init() {}

    /// Returns the current retry count for a file URL.
    ///
    /// Returns 0 for files that have never failed.
    public func retryCount(for url: URL) -> Int {
        retryTracker[url] ?? 0
    }

    /// Records a failure for the given URL, scheduling a retry or dead-lettering.
    ///
    /// Per TRIG-04: increments the retry count; if count < maxRetries, returns
    /// `.retryScheduled` (the caller is responsible for sleeping the backoff
    /// interval then re-enqueuing); if count >= maxRetries, calls
    /// ``deadLetter(url:inboxRoot:error:retryCount:)`` and returns `.deadLettered`.
    ///
    /// - Parameters:
    ///   - url: The audio file that failed processing.
    ///   - inboxRoot: The `_inbox/` root URL (where `_failed/` lives).
    ///   - error: The error that caused the failure.
    /// - Returns: `.retryScheduled` if more retries remain; `.deadLettered`
    ///   if the file was moved to `_failed/`.
    public func recordFailure(
        for url: URL,
        inboxRoot: URL,
        error: InboxError
    ) async -> FailureOutcome {
        let currentCount = (retryTracker[url] ?? 0) + 1
        retryTracker[url] = currentCount

        if currentCount >= Self.maxRetries {
            do {
                try await deadLetter(
                    url: url,
                    inboxRoot: inboxRoot,
                    error: error,
                    retryCount: currentCount
                )
                return .deadLettered
            } catch {
                // If dead-letter move fails, still report dead-lettered so the
                // queue stops retrying. Log the move failure in the sidecar.
                return .deadLettered
            }
        }

        return .retryScheduled
    }

    /// Moves a failed file to `_inbox/_failed/` and writes a sidecar JSON.
    ///
    /// Per TRIG-04: creates `_inbox/_failed/` if needed, moves the file,
    /// writes `_failed/{filename}.error.json` with fields: original_filename,
    /// failed_at (ISO 8601), error_type, error_message, retry_count.
    ///
    /// Per T-05-10 (Information Disclosure): the sidecar contains ONLY error
    /// metadata — never transcript text, audio content, or course names.
    ///
    /// - Parameters:
    ///   - url: The audio file to dead-letter.
    ///   - inboxRoot: The `_inbox/` root URL.
    ///   - error: The error that caused the dead-letter.
    ///   - retryCount: The number of retries attempted.
    /// - Throws: FileManager errors if the move or sidecar write fails.
    public func deadLetter(
        url: URL,
        inboxRoot: URL,
        error: InboxError,
        retryCount: Int
    ) async throws {
        let failedDir = inboxRoot.appendingPathComponent("_failed")
        try FileManager.default.createDirectory(
            at: failedDir,
            withIntermediateDirectories: true
        )

        let filename = url.lastPathComponent
        let destination = failedDir.appendingPathComponent(filename)

        // Remove existing destination if present (overwrite on retry dead-letter)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        // Move the audio file to _failed/
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.moveItem(at: url, to: destination)
        }

        // Write sidecar JSON (T-05-10: metadata only — no transcript/audio)
        let sidecarURL = failedDir.appendingPathComponent("\(filename).error.json")
        let sidecar = DeadLetterSidecar(
            originalFilename: filename,
            failedAt: ISO8601DateFormatter().string(from: Date()),
            errorType: error.errorType,
            errorMessage: error.errorMessage,
            retryCount: retryCount
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let sidecarData = try encoder.encode(sidecar)
        try sidecarData.write(to: sidecarURL, options: [.atomic])
    }

    /// Clears the retry count for a URL (e.g., after manual Retry from popover).
    public func resetRetries(for url: URL) {
        retryTracker[url] = nil
    }
}

/// Outcome of recording a failure (TRIG-04).
public enum FailureOutcome: Sendable {
    /// The file has not yet exhausted retries — caller should sleep the
    /// backoff interval then re-enqueue.
    case retryScheduled
    /// The file has been moved to `_failed/` — no more retries.
    case deadLettered
}

/// Sidecar JSON structure for dead-lettered files (T-05-10).
///
/// Per T-05-10: contains ONLY error metadata — never transcript text,
/// audio content, or course names. Written to `_failed/{filename}.error.json`.
public struct DeadLetterSidecar: Codable, Sendable {
    /// Original filename of the dead-lettered audio file.
    public let originalFilename: String
    /// ISO 8601 timestamp when the file was dead-lettered.
    public let failedAt: String
    /// Machine-parseable error type (e.g., "download_timed_out").
    public let errorType: String
    /// Human-readable error message (no transcript/audio content).
    public let errorMessage: String
    /// Number of retries attempted before dead-lettering.
    public let retryCount: Int

    enum CodingKeys: String, CodingKey {
        case originalFilename = "original_filename"
        case failedAt = "failed_at"
        case errorType = "error_type"
        case errorMessage = "error_message"
        case retryCount = "retry_count"
    }

    public init(
        originalFilename: String,
        failedAt: String,
        errorType: String,
        errorMessage: String,
        retryCount: Int
    ) {
        self.originalFilename = originalFilename
        self.failedAt = failedAt
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.retryCount = retryCount
    }
}

#endif // os(macOS)
