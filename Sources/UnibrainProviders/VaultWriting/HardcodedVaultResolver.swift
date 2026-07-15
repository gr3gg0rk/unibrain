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
        // RED phase stub — implementation pending GREEN
        throw PipelineError.invalidInputs
    }
}

#endif // os(macOS)
