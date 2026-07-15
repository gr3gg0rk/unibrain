import Foundation
import UnibrainCore

#if os(macOS)

/// Phase 4 schedule-aware vault path resolver.
///
/// Replaces ``HardcodedVaultResolver`` for Phase 4+ recordings. Instead of
/// routing all recordings to `lectures/YYYY-MM-DD-Lecture.md` with course
/// UNCLASSIFIED, this resolver builds schedule-aware paths:
///
/// Per CLAS-05: `{vault}/{sanitizedTerm}/{courseCode}/YYYY-MM-DD-{courseCode}-Lecture.md`
///
/// Per CLAS-02: When a mapping exists for the event title, the mapped
/// `courseCode` is used as the path component. When unmapped (CLAS-03),
/// the sanitized event title auto-creates a new folder.
///
/// Per MP-03: The Skip path uses title "_unsorted" which naturally produces
/// the `_unsorted/` folder — no special-casing needed.
///
/// Per A-05: Intermediate directories are created recursively via
/// `FileManager.createDirectory(withIntermediateDirectories: true)`.
///
/// Per T-04-11 (mitigate): ``FolderNameSanitizer`` strips `/`, `:`, and
/// leading dots before any path component use, preventing path traversal.
///
/// The resolver is a plain struct with no actor dependency and no async
/// calls — it reads from an injected mapping snapshot (a plain dictionary
/// loaded once at init time). Writes (auto-learn, manual pick) go through
/// ``CourseMappingStore`` elsewhere in the orchestrator.
public struct ScheduleAwareVaultResolver: VaultPathResolver, Sendable {

    /// Root directory of the Obsidian vault.
    private let vaultRoot: URL

    /// Current academic term label (e.g., "Fall 2026") from CT-01.
    private let termLabel: String

    /// Event title -> course mapping snapshot (loaded once at init time).
    /// Plain dictionary — no actor dependency, no async calls in resolve().
    private let mapping: [String: CourseMapping]

    /// Creates a schedule-aware vault resolver.
    ///
    /// - Parameters:
    ///   - vaultRoot: Root URL of the Obsidian vault.
    ///   - termLabel: Current academic term label (e.g., "Fall 2026").
    ///   - mapping: Event title → course mapping snapshot (default: empty for
    ///     Phase 3 backward compatibility).
    public init(
        vaultRoot: URL,
        termLabel: String,
        mapping: [String: CourseMapping] = [:]
    ) {
        self.vaultRoot = vaultRoot
        self.termLabel = termLabel
        self.mapping = mapping
    }

    /// Resolves the destination URL for a note given a matched course event.
    ///
    /// Per CLAS-05: Builds `{vault}/{sanitizedTerm}/{courseComponent}/YYYY-MM-DD-{courseComponent}-Lecture.md`.
    /// Per CLAS-02: Uses mapped courseCode if available; falls back to sanitized event title.
    /// Per CLAS-03: Unmapped titles auto-create sanitized folders.
    /// Per A-05: Creates the directory tree recursively.
    /// Per T-04-11: Both term label and event title are sanitized before path use.
    ///
    /// - Parameters:
    ///   - match: The CourseMatch result. Must be `.single` — the orchestrator
    ///     resolves `.multiple`/`.none` before calling this method.
    ///   - recordingStart: Recording start timestamp (for filename date).
    /// - Returns: Destination URL for the note file.
    /// - Throws: ``PipelineError/invalidInputs`` if match is not `.single`.
    public func resolve(match: CourseMatch, recordingStart: Date) throws -> URL {
        // Extract the resolved event — orchestrator always passes .single
        guard case .single(let event) = match else {
            throw PipelineError.invalidInputs
        }

        // CLAS-02: Look up mapping for the event title.
        let mapped = mapping[event.title]

        // Determine the course component for the path.
        // Per CLAS-02: Use mapped courseCode if available.
        // Per CLAS-03: Use sanitized event title for unmapped titles (auto-create).
        let rawCourseComponent = mapped?.courseCode ?? event.title
        let courseComponent = FolderNameSanitizer.sanitize(folderName: rawCourseComponent)

        // Sanitize the term label (T-04-11 path traversal mitigation).
        // Empty term falls back to "default-term" so recordings always land
        // in a named directory.
        let sanitizedTerm = FolderNameSanitizer.sanitize(
            folderName: termLabel.isEmpty ? "default-term" : termLabel
        )

        // Build the course directory: vault/{term}/{course}
        let courseDir = vaultRoot
            .appendingPathComponent(sanitizedTerm)
            .appendingPathComponent(courseComponent)

        // A-05: Create directory tree recursively
        try FileManager.default.createDirectory(
            at: courseDir,
            withIntermediateDirectories: true
        )

        // Format date as YYYY-MM-DD (matching HardcodedVaultResolver pattern)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: recordingStart)

        // CLAS-05: Return {courseDir}/{date}-{courseComponent}-Lecture.md
        return courseDir
            .appendingPathComponent("\(dateString)-\(courseComponent)-Lecture.md")
    }
}

#endif // os(macOS)
