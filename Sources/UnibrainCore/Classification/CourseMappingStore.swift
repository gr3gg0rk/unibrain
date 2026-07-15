import Foundation
#if canImport(os)
import os
#endif

/// Actor providing atomic CRUD operations on `.unibrain/courses.json` (CLAS-02).
///
/// Per M-01: The JSON file lives at `{vault}/.unibrain/courses.json` so
/// iCloud Drive syncs it between Angelica's devices.
/// Per M-02: Auto-learn path — upsert on first encounter, then auto-route forever.
/// Per M-03: Manual pick updates both mapping and recent list.
/// Per CT-01: Current term label + date range stored and retrieved from the same file.
///
/// Per T-04-02 (mitigate): `load()` catches all decode errors and falls back to
/// `CourseMappingDocument.empty` — never throws on corrupted data.
/// Per T-04-03 (mitigate): `Data.write(to:options:.atomic)` ensures POSIX-level
/// atomicity to survive iCloud sync conflicts. Actor isolation prevents concurrent
/// writes from the same process.
///
/// Per T-2-01 (path traversal): The `.unibrain/` path component is a fixed constant,
/// not derived from user input. Event titles are dictionary keys in the JSON, not
/// path components.
public actor CourseMappingStore {

    /// Maximum number of entries in the recent course codes list (M-03).
    static let maxRecentEntries = 5

    /// Root directory of the Obsidian vault.
    private let vaultRoot: URL

    /// Full URL to the courses.json file.
    private let storeURL: URL

    #if canImport(os)
    private let logger = Logger(
        subsystem: "app.unibrain",
        category: "CourseMappingStore"
    )
    #endif

    /// Creates a store rooted at the given vault directory.
    ///
    /// - Parameter vaultRoot: Root URL of the Obsidian vault.
    public init(vaultRoot: URL) {
        self.vaultRoot = vaultRoot
        self.storeURL = vaultRoot
            .appendingPathComponent(".unibrain")
            .appendingPathComponent("courses.json")
    }

    // MARK: - Load / Save

    /// Loads the document from disk.
    ///
    /// Per T-04-02: Returns `CourseMappingDocument.empty` if the file is
    /// missing or malformed — never throws on corrupted data.
    ///
    /// - Returns: The decoded document, or the empty default.
    public func load() async throws -> CourseMappingDocument {
        guard let data = FileManager.default.contents(atPath: storeURL.path) else {
            return .empty
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(CourseMappingDocument.self, from: data)
        } catch {
            #if canImport(os)
            logger.warning("Failed to decode courses.json: \(error.localizedDescription). Falling back to empty default.")
            #endif
            return .empty
        }
    }

    /// Saves the document to disk atomically.
    ///
    /// Per T-04-03: Uses `Data.write(to:options:.atomic)` to prevent corruption
    /// from concurrent iCloud sync.
    ///
    /// - Parameter document: The document to persist.
    private func save(_ document: CourseMappingDocument) async throws {
        let unibrainDir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: unibrainDir,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(document)
        try data.write(to: storeURL, options: [.atomic])
    }

    // MARK: - Read Operations

    /// Looks up a course mapping by event title (M-01).
    ///
    /// - Parameter eventTitle: The calendar event title to look up.
    /// - Returns: The mapped `CourseMapping`, or nil if unmapped.
    public func lookup(eventTitle: String) async throws -> CourseMapping? {
        let document = try await load()
        return document.mappings[eventTitle]
    }

    /// Returns all course mappings (for Manage Courses sheet — M-04).
    public func allMappings() async throws -> [String: CourseMapping] {
        let document = try await load()
        return document.mappings
    }

    /// Returns the recent course codes list (for picker Recent section — M-03).
    public func allRecentCourses() async throws -> [String] {
        let document = try await load()
        return document.recentCourseCodes
    }

    /// Returns the current term definition (for term filter + UI display — CT-01).
    public func currentTerm() async throws -> TermDefinition {
        let document = try await load()
        return document.currentTerm
    }

    // MARK: - Write Operations

    /// Inserts or updates a mapping for an event title (M-02 auto-learn, M-03 manual pick).
    ///
    /// - Parameters:
    ///   - eventTitle: The calendar event title.
    ///   - mapping: The course mapping to associate.
    public func upsert(eventTitle: String, mapping: CourseMapping) async throws {
        var document = try await load()
        document.mappings[eventTitle] = mapping
        try await save(document)
    }

    /// Adds a course code to the recent list (M-03).
    ///
    /// Removes any prior occurrence, inserts at position 0, trims to
    /// `maxRecentEntries` (5). MRU ordering.
    ///
    /// - Parameter courseCode: The course code to add.
    public func addRecent(courseCode: String) async throws {
        var document = try await load()
        document.recentCourseCodes.removeAll { $0 == courseCode }
        document.recentCourseCodes.insert(courseCode, at: 0)
        if document.recentCourseCodes.count > Self.maxRecentEntries {
            document.recentCourseCodes = Array(document.recentCourseCodes.prefix(Self.maxRecentEntries))
        }
        try await save(document)
    }

    /// Sets the current term label and date range (CT-01).
    ///
    /// - Parameters:
    ///   - label: Human-readable term label (e.g., "Fall 2026").
    ///   - startDate: Term start date.
    ///   - endDate: Term end date.
    public func setCurrentTerm(label: String, startDate: Date, endDate: Date) async throws {
        var document = try await load()
        document.currentTerm = TermDefinition(
            label: label,
            startDate: startDate,
            endDate: endDate
        )
        try await save(document)
    }

    /// Removes a mapping by event title (for Manage Courses delete — M-04).
    ///
    /// - Parameter eventTitle: The event title to unmap.
    public func deleteMapping(eventTitle: String) async throws {
        var document = try await load()
        document.mappings.removeValue(forKey: eventTitle)
        try await save(document)
    }
}
