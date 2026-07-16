import Foundation

#if os(macOS)

/// Structured error type for the inbox pipeline (Phase 5 Plan 03).
///
/// Per IC-04: the ``downloadTimedOut`` case is distinct from
/// ``NoteWriterError/iCloudPlaceholder`` — the inbox pipeline handles
/// placeholders BEFORE they reach the NoteWriter. Once the inbox
/// pipeline actively downloads a `.icloud` placeholder to a real file,
/// the existing ``NSFileCoordinatorNoteWriter`` processes it normally
/// without hitting the Phase 2 A-03 hard-error path.
///
/// Per T-05-10: error sidecars written by ``DeadLetterHandler`` contain
/// only metadata from these cases — never transcript text or audio content.
public enum InboxError: Error, Sendable {
    /// iCloud download did not complete within the timeout window.
    ///
    /// Per IC-04: the associated URL is the `.icloud` placeholder that
    /// ``InboxFileDownloader`` was polling. The queue schedules a retry
    /// via ``DeadLetterHandler``.
    case downloadTimedOut(URL)
    /// The pipeline failed while processing an inbox file.
    ///
    /// Per TRIG-04: the associated URL is the audio file that failed;
    /// `underlying` carries the original pipeline error for diagnostics.
    case pipelineFailed(URL, underlying: any Error)
    /// The file exhausted all retry attempts and was dead-lettered.
    ///
    /// Per TRIG-04: the associated URL is the file; `retryCount` is the
    /// number of attempts before dead-lettering (default max: 3).
    case deadLetterExhausted(URL, retryCount: Int)
    /// The inbox folder is not ready (missing, unreadable, or not iCloud-enabled).
    ///
    /// Per TRIG-01: the associated value is a human-readable description
    /// of why the inbox is not ready.
    case inboxNotReady(String)

    /// Human-readable error type name for sidecar JSON (T-05-10).
    ///
    /// Returns a stable, machine-parseable string identifying the error
    /// case WITHOUT leaking transcript or audio content.
    public var errorType: String {
        switch self {
        case .downloadTimedOut: return "download_timed_out"
        case .pipelineFailed: return "pipeline_failed"
        case .deadLetterExhausted: return "dead_letter_exhausted"
        case .inboxNotReady: return "inbox_not_ready"
        }
    }

    /// Human-readable error message for sidecar JSON (T-05-10).
    ///
    /// Contains only diagnostic metadata — never transcript or audio content.
    public var errorMessage: String {
        switch self {
        case .downloadTimedOut(let url):
            return "iCloud download timed out for \(url.lastPathComponent)"
        case .pipelineFailed(let url, let underlying):
            return "Pipeline failed for \(url.lastPathComponent): \(underlying.localizedDescription)"
        case .deadLetterExhausted(let url, let count):
            return "Exhausted \(count) retries for \(url.lastPathComponent)"
        case .inboxNotReady(let detail):
            return "Inbox not ready: \(detail)"
        }
    }
}

#endif // os(macOS)
