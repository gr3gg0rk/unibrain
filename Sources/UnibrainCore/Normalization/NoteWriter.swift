import Foundation

/// Protocol for writing a ``NormalizedNote`` to the Obsidian vault filesystem.
///
/// Per A-01 and A-02: defines a single `write(_:to:)` method with a specific
/// (non-associatedtype) signature. The note is a ``NormalizedNote`` and the
/// destination is a file URL.
///
/// Conformances must guarantee:
/// - **WRITE-04**: Atomic writes (no partial files on crash).
/// - **WRITE-05**: `.icloud` placeholder detection (throw ``NoteWriterError/iCloudPlaceholder``).
/// - **WRITE-06**: Structured error propagation via ``NoteWriterError`` (no silent swallow).
/// - **A-05**: Intermediate directories created recursively before writing.
///
/// Per D-15: standalone protocol with no common ancestor.
/// Phase 3's `NSFileCoordinatorNoteWriter` is the production conformance;
/// `TestNoteWriter` (in tests) is the Linux-testable conformance using
/// pure Foundation `FileManager` with `.atomic` writes.
public protocol NoteWriter {
    /// Write the given note to the destination URL atomically.
    ///
    /// - Parameters:
    ///   - note: The normalized note containing title, body, and frontmatter.
    ///   - destination: The file URL to write the Markdown note to.
    /// - Throws: ``NoteWriterError`` on any failure:
    ///   - `.iCloudPlaceholder` if a `.icloud` placeholder is detected (WRITE-05).
    ///   - `.permissionDenied` if the filesystem denies write access.
    ///   - `.alreadyExists` if the destination file already exists.
    ///   - `.directoryCreationFailed` if recursive directory creation fails (A-05).
    ///   - `.diskFull` if no space remains.
    ///   - `.underlying` for any other filesystem error.
    func write(_ note: NormalizedNote, to destination: URL) async throws
}
