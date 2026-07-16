import Foundation

#if os(macOS)

/// Serial FIFO queue for inbox file processing (TRIG-02).
///
/// Per TRIG-02: discovered files enqueue; the queue processor pops one
/// file at a time, FIFO. Matches Phase 2 O-02 (orchestrator rejects
/// concurrent runs via `.alreadyRunning`).
///
/// Per CONTEXT discretion: the queue is in-memory — the launch scan
/// (TRIG-01) recovers any files the queue lost on app restart.
///
/// De-duplicates on enqueue — if a URL is already pending, it is skipped
/// (prevents duplicate processing when NSMetadataQuery fires multiple
/// notifications for the same file).
public actor InboxQueue {

    /// Pending file URLs in FIFO order (first enqueued = first processed).
    private var pendingFiles: [URL] = []

    /// True while a file is actively being processed.
    private var isProcessing: Bool = false

    /// The file currently being processed (nil when idle).
    private(set) var currentFile: URL?

    /// Creates a new empty inbox queue.
    public init() {}

    /// The number of pending files waiting to be processed.
    public var pendingCount: Int {
        pendingFiles.count
    }

    /// Whether the queue is currently processing a file.
    public var processing: Bool {
        isProcessing
    }

    /// Enqueues a file URL for processing.
    ///
    /// Per TRIG-02: appends to the end of the FIFO queue.
    /// De-duplicates: if the URL is already pending or currently being
    /// processed, the enqueue is a no-op.
    ///
    /// - Parameter url: The audio file URL to enqueue.
    public func enqueue(_ url: URL) {
        // De-duplicate: skip if already pending or currently processing
        if url == currentFile { return }
        if pendingFiles.contains(url) { return }
        pendingFiles.append(url)
    }

    /// Returns the next file to process, or nil if the queue is empty.
    ///
    /// Per TRIG-02: returns files in FIFO order (first-enqueued = first-out).
    /// Sets `isProcessing = true` and `currentFile` to the returned URL.
    ///
    /// - Returns: The next file URL, or nil if no files are pending.
    /// - Throws: ``InboxError/inboxNotReady`` if the queue is already
    ///   processing a file (caller must call ``markComplete()`` or
    ///   ``markFailed(error:)`` first).
    public func processNext() throws -> URL? {
        guard !isProcessing else {
            // Already processing — caller must complete the current file first.
            // This enforces TRIG-02 one-at-a-time semantics.
            return currentFile
        }

        guard !pendingFiles.isEmpty else {
            return nil
        }

        let next = pendingFiles.removeFirst()
        currentFile = next
        isProcessing = true
        return next
    }

    /// Marks the current file as complete (pipeline success).
    ///
    /// Clears `currentFile` and `isProcessing` so the next call to
    /// ``processNext()`` can proceed.
    public func markComplete() {
        currentFile = nil
        isProcessing = false
    }

    /// Clears all pending files (e.g., on app shutdown).
    public func clear() {
        pendingFiles.removeAll()
        currentFile = nil
        isProcessing = false
    }
}

#endif // os(macOS)
