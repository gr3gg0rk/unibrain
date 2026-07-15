import Foundation
import UnibrainCore

#if os(macOS)

/// Phase 3 hardcoded vault path resolver.
///
/// Per P-13: vault root = `~/Documents/Unibrain/`
/// Per P-14: note path = `~/Documents/Unibrain/lectures/YYYY-MM-DD-Lecture.md`
/// Per P-16: does NOT write to `_inbox/` (reserved for Phase 5 iCloud handoff).
///
/// All Phase 3 recordings are UNCLASSIFIED — the `CourseMatch` parameter is
/// ignored. Phase 4 will replace this resolver with schedule-aware routing.
public struct HardcodedVaultResolver: VaultPathResolver, Sendable {

    /// Per P-13: Default vault root = ~/Documents/Unibrain/
    public static let vaultRoot: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Unibrain")

    /// Per P-14: Lectures output folder.
    public static let lecturesDir: URL = vaultRoot
        .appendingPathComponent("lectures")

    public init() {}

    public func resolve(match: CourseMatch, recordingStart: Date) throws -> URL {
        // Create lectures directory if it does not exist.
        try FileManager.default.createDirectory(
            at: Self.lecturesDir,
            withIntermediateDirectories: true
        )

        // Format date as YYYY-MM-DD.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        let dateString = dateFormatter.string(from: recordingStart)

        // P-14: Return lectures/YYYY-MM-DD-Lecture.md
        // The match parameter is intentionally ignored — Phase 3 writes
        // everything to lectures/ with course: UNCLASSIFIED.
        // Phase 4 will replace this resolver with schedule-aware routing.
        return Self.lecturesDir
            .appendingPathComponent("\(dateString)-Lecture.md")
    }
}

#endif // os(macOS)
