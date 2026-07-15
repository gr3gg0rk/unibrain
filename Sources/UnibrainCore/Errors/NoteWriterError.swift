import Foundation

/// Structured error type for all NoteWriter conformances.
///
/// Per A-04: every NoteWriter conformance throws ``NoteWriterError``.
/// This enum is intentionally NOT declared `Sendable` because the
/// `underlying(any Error)` case holds a non-Sendable existential.
/// NoteWriterError instances are thrown and caught within a single
/// task/actor context — they are never passed across concurrency boundaries.
///
/// Threat mitigation (T-2-02, T-2-05): structured enum cases prevent
/// silent data loss from iCloud placeholders and surface filesystem
/// errors with clear context instead of opaque error strings.
public enum NoteWriterError: Error {
    /// A `.icloud` placeholder was detected in the destination path.
    ///
    /// Per WRITE-05 and A-03: iCloud may create `.icloud` placeholder files
    /// for documents that have not yet been downloaded to the local device.
    /// Writing to such a path would silently fail or corrupt data.
    /// The associated URL is the destination that triggered the detection.
    case iCloudPlaceholder(URL)
    /// The disk is full — no space remaining to write the note.
    ///
    /// Per WRITE-06: surfaces a clear error so the caller can inform the user
    /// rather than silently failing.
    case diskFull
    /// Filesystem permission denied for the destination URL.
    ///
    /// Per A-04 and WRITE-06: the associated URL is the path that was
    /// not writable.
    case permissionDenied(URL)
    /// The destination file already exists.
    ///
    /// Per A-04: prevents accidental overwrite of existing notes.
    /// The associated URL is the existing file path.
    case alreadyExists(URL)
    /// Recursive directory creation failed for the destination's parent.
    ///
    /// Per A-05 and T-2-05: the NoteWriter creates intermediate directories
    /// recursively before writing. If creation fails, this case surfaces
    /// the URL and the underlying filesystem error.
    case directoryCreationFailed(URL, underlying: any Error)
    /// An underlying filesystem error that does not fit other cases.
    ///
    /// Per A-04: catch-all for unexpected FileManager or POSIX errors.
    case underlying(any Error)
}
