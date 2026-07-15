import Foundation
import UnibrainCore

#if os(macOS)
import Yams

/// macOS-only NoteWriter conformance using NSFileCoordinator for atomic,
/// iCloud-safe writes.
///
/// Per WRITE-04: Uses NSFileCoordinator to coordinate writes with iCloud Drive
/// sync, ensuring no partial files appear on crash.
/// Per WRITE-05: Detects `.icloud` placeholder files before writing.
/// Per WRITE-06: Surfaces structured `NoteWriterError` on any failure.
/// Per A-05: Creates intermediate directories recursively before writing.
///
/// This conformance replaces Phase 2's `TestNoteWriter` (Linux-testable,
/// pure Foundation) for production macOS use. The serialization logic
/// (YAML frontmatter + Markdown body) is identical.
public struct NSFileCoordinatorNoteWriter: NoteWriter, Sendable {

    public init() {}

    public func write(_ note: NormalizedNote, to destination: URL) async throws {
        // RED phase stub — implementation pending GREEN
        throw NoteWriterError.underlying(NSError(domain: "stub", code: 1))
    }
}

#endif // os(macOS)
