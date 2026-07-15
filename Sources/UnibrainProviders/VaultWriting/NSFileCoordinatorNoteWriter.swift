import Foundation
import UnibrainCore

#if os(macOS)
import Yams

/// macOS-only NoteWriter conformance using NSFileCoordinator for atomic,
/// iCloud-safe writes.
///
/// Per WRITE-04: Uses NSFileCoordinator to coordinate writes with iCloud Drive
/// sync, ensuring no partial files appear on crash. The actual data write
/// uses `Data.write(to:options:.atomic)` inside the coordination block,
/// providing double-layered atomicity (NSFileCoordinator + POSIX rename).
///
/// Per WRITE-05: Detects `.icloud` placeholder files before writing. iCloud
/// Drive may create `.icloud` stubs for documents not yet downloaded locally.
/// Writing to a path whose `.icloud` variant exists would silently fail or
/// corrupt data — we reject upfront with `NoteWriterError.iCloudPlaceholder`.
///
/// Per WRITE-06: Surfaces structured `NoteWriterError` on any failure,
/// mapping common POSIX/Cocoa errors to specific cases.
///
/// Per A-05: Creates intermediate directories recursively before writing.
///
/// This conformance replaces Phase 2's `TestNoteWriter` (Linux-testable,
/// pure Foundation) for production macOS use. The serialization logic
/// (YAML frontmatter + Markdown body) is identical.
public struct NSFileCoordinatorNoteWriter: NoteWriter, Sendable {

    public init() {}

    public func write(_ note: NormalizedNote, to destination: URL) async throws {
        // WRITE-05: Detect .icloud placeholder files.
        // iCloud Drive creates `.{filename}.icloud` stub files for documents
        // not yet downloaded to the local device.
        let iCloudPlaceholderURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).icloud")
        if FileManager.default.fileExists(atPath: iCloudPlaceholderURL.path) {
            throw NoteWriterError.iCloudPlaceholder(destination)
        }

        // A-05: Create intermediate directories recursively before writing.
        let parentDir = destination.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true
            )
        } catch {
            throw NoteWriterError.directoryCreationFailed(parentDir, underlying: error)
        }

        // Serialize the note: YAML frontmatter + Markdown body.
        let yamlString: String
        do {
            let yamlData = try YAMLEncoder().encode(note.frontmatter)
            yamlString = yamlData
        } catch {
            throw NoteWriterError.underlying(error)
        }

        let markdown = "---\n\(yamlString)---\n\n\(note.title)\n\n\(note.body)"
        guard let data = markdown.data(using: .utf8) else {
            throw NoteWriterError.underlying(
                NSError(domain: "NSFileCoordinatorNoteWriter", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to encode note as UTF-8"])
            )
        }

        // WRITE-04: Write atomically using NSFileCoordinator.
        // NSFileCoordinator coordinates with iCloud Drive sync and other
        // file presenters. Inside the coordination block, we use
        // Data.write(to:options:.atomic) for POSIX-level atomicity.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.writeAccessAllowed = true

            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { newURL in
                do {
                    try data.write(to: newURL, options: .atomic)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: Self.mapFileError(error, destination: destination))
                }
            }

            if let coordinationError {
                continuation.resume(throwing: Self.mapFileError(coordinationError, destination: destination))
            }
        }
    }

    /// Maps filesystem and coordination errors to structured NoteWriterError cases.
    ///
    /// Per WRITE-06: every failure surfaces as a specific NoteWriterError case
    /// rather than an opaque error, enabling the caller to take appropriate action.
    private static func mapFileError(_ error: Error, destination: URL) -> NoteWriterError {
        let nsError = error as NSError

        // Disk full (ENOSPC)
        if nsError.code == NSFileWriteOutOfSpaceError {
            return .diskFull
        }

        // Permission denied (EPERM/EACCES)
        if nsError.code == NSFileWriteNoPermissionError
            || nsError.domain == NSPOSIXErrorDomain
                && (nsError.code == Int(EPERM) || nsError.code == Int(EACCES))
        {
            return .permissionDenied(destination)
        }

        // File already exists (EEXIST) — shouldn't happen with .forReplacing
        // but handle defensively
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EEXIST) {
            return .alreadyExists(destination)
        }

        // Fallback: wrap in .underlying
        return .underlying(error)
    }
}

#endif // os(macOS)
