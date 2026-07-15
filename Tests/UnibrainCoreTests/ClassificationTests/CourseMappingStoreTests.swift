import Testing
import Foundation
@testable import UnibrainCore

@Suite("CourseMappingStore")
struct CourseMappingStoreTests {

    // MARK: - Helpers

    /// Creates a temporary directory for each test (isolation per testing.md).
    private func makeVaultRoot() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CourseMappingStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        return tempDir
    }

    /// Cleans up the temp directory after each test.
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Fixed dates for deterministic tests.
    private let termStart = ISO8601DateFormatter().date(from: "2026-08-25T00:00:00Z")!
    private let termEnd = ISO8601DateFormatter().date(from: "2026-12-15T23:59:59Z")!

    // MARK: - Test 1: Document round-trip through JSON
    // (Pure Codable, no actor needed — stays synchronous)

    @Test("CourseMappingDocument round-trips through JSONEncoder/Decoder with snake_case keys")
    func documentRoundTripsThroughJSON() throws {
        let mapping = CourseMapping(courseCode: "CS101", courseName: "Intro to CS")
        let document = CourseMappingDocument(
            schemaVersion: 1,
            currentTerm: TermDefinition(
                label: "Fall 2026",
                startDate: termStart,
                endDate: termEnd
            ),
            mappings: ["CS101 Lecture": mapping],
            recentCourseCodes: ["CS101"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)

        // Verify snake_case keys exist in JSON
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"schema_version\""))
        #expect(json.contains("\"current_term\""))
        #expect(json.contains("\"recent_course_codes\""))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CourseMappingDocument.self, from: data)

        #expect(decoded.schemaVersion == 1)
        #expect(decoded.currentTerm.label == "Fall 2026")
        #expect(decoded.mappings.count == 1)
        #expect(decoded.mappings["CS101 Lecture"]?.courseCode == "CS101")
        #expect(decoded.mappings["CS101 Lecture"]?.courseName == "Intro to CS")
        #expect(decoded.recentCourseCodes == ["CS101"])
    }

    // MARK: - Test 2: load() returns empty default on non-existent file

    @Test("load() returns empty default when file does not exist")
    func loadReturnsEmptyOnMissingFile() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        let document = try await store.load()

        #expect(document.schemaVersion == 1)
        #expect(document.mappings.isEmpty)
        #expect(document.recentCourseCodes.isEmpty)
        #expect(document.currentTerm.label == "")
        #expect(document.currentTerm.startDate == .distantPast)
        #expect(document.currentTerm.endDate == .distantFuture)
    }

    // MARK: - Test 3: load() returns empty default on malformed JSON

    @Test("load() returns empty default on malformed JSON")
    func loadReturnsEmptyOnMalformedJSON() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        // Write malformed JSON to .unibrain/courses.json
        let unibrainDir = vaultRoot.appendingPathComponent(".unibrain")
        try FileManager.default.createDirectory(
            at: unibrainDir,
            withIntermediateDirectories: true
        )
        let storeFile = unibrainDir.appendingPathComponent("courses.json")
        try "{ invalid json !!!".data(using: .utf8)!.write(to: storeFile)

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        let document = try await store.load()

        #expect(document.schemaVersion == 1)
        #expect(document.mappings.isEmpty)
        #expect(document.recentCourseCodes.isEmpty)
    }

    // MARK: - Test 4: lookup() returns mapping after upsert, nil for unmapped

    @Test("lookup() returns mapping after upsert, nil for unmapped title")
    func lookupReturnsMappingAfterUpsert() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        let mapping = CourseMapping(courseCode: "CS101", courseName: "Intro to CS")

        try await store.upsert(eventTitle: "CS101 Lecture", mapping: mapping)

        let found = try await store.lookup(eventTitle: "CS101 Lecture")
        #expect(found?.courseCode == "CS101")
        #expect(found?.courseName == "Intro to CS")

        let notFound = try await store.lookup(eventTitle: "Unknown Event")
        #expect(notFound == nil)
    }

    // MARK: - Test 5: upsert() persists to disk, visible on fresh load

    @Test("upsert() writes immediately and is visible on fresh load()")
    func upsertPersistsAndVisibleOnFreshLoad() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store1 = CourseMappingStore(vaultRoot: vaultRoot)
        let mapping = CourseMapping(courseCode: "MATH200", courseName: "Calculus II")
        try await store1.upsert(eventTitle: "Calc II Lecture", mapping: mapping)

        // Create a NEW store instance — simulates app restart / different device via iCloud
        let store2 = CourseMappingStore(vaultRoot: vaultRoot)
        let document = try await store2.load()

        #expect(document.mappings["Calc II Lecture"]?.courseCode == "MATH200")
        #expect(document.mappings["Calc II Lecture"]?.courseName == "Calculus II")
    }

    // MARK: - Test 6: addRecent() deduplicates and trims to 5

    @Test("addRecent() adds at position 0, deduplicates, trims to 5 entries")
    func addRecentDeduplicatesAndTrims() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store = CourseMappingStore(vaultRoot: vaultRoot)

        // Add 5 distinct codes
        try await store.addRecent(courseCode: "CS101")
        try await store.addRecent(courseCode: "MATH200")
        try await store.addRecent(courseCode: "PHYS101")
        try await store.addRecent(courseCode: "CHEM150")
        try await store.addRecent(courseCode: "BIO120")

        var recent = try await store.allRecentCourses()
        #expect(recent == ["BIO120", "CHEM150", "PHYS101", "MATH200", "CS101"])

        // Add a 6th — should trim the oldest (CS101)
        try await store.addRecent(courseCode: "ENG100")
        recent = try await store.allRecentCourses()
        #expect(recent.count == 5)
        #expect(recent == ["ENG100", "BIO120", "CHEM150", "PHYS101", "MATH200"])
        #expect(!recent.contains("CS101"))

        // Add an existing code — should deduplicate (remove prior) and move to front
        try await store.addRecent(courseCode: "PHYS101")
        recent = try await store.allRecentCourses()
        #expect(recent.count == 5)
        #expect(recent[0] == "PHYS101")
        // PHYS101 should appear only once
        #expect(recent.filter { $0 == "PHYS101" }.count == 1)
    }

    // MARK: - Test 7: setCurrentTerm() updates and persists

    @Test("setCurrentTerm() updates the term and persists it")
    func setCurrentTermPersists() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        try await store.setCurrentTerm(
            label: "Spring 2027",
            startDate: termStart,
            endDate: termEnd
        )

        // Verify via same store
        let term = try await store.currentTerm()
        #expect(term.label == "Spring 2027")

        // Verify via fresh store (disk persistence)
        let store2 = CourseMappingStore(vaultRoot: vaultRoot)
        let term2 = try await store2.currentTerm()
        #expect(term2.label == "Spring 2027")
    }

    // MARK: - Test 8: load() decodes pre-written JSON with snake_case keys

    @Test("load() decodes pre-written JSON with snake_case keys (iCloud sync simulation)")
    func loadDecodesPreWrittenSnakeCaseJSON() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        // Write a JSON file as if it came from another device via iCloud
        let unibrainDir = vaultRoot.appendingPathComponent(".unibrain")
        try FileManager.default.createDirectory(
            at: unibrainDir,
            withIntermediateDirectories: true
        )
        let storeFile = unibrainDir.appendingPathComponent("courses.json")

        let jsonPayload = """
        {
            "schema_version": 1,
            "current_term": {
                "label": "Fall 2026",
                "startDate": "2026-08-25T00:00:00Z",
                "endDate": "2026-12-15T23:59:59Z"
            },
            "mappings": {
                "CS101 Lecture": {
                    "courseCode": "CS101",
                    "courseName": "Intro to CS"
                },
                "MATH200 Lab": {
                    "courseCode": "MATH200",
                    "courseName": "Calculus II"
                }
            },
            "recent_course_codes": ["MATH200", "CS101"]
        }
        """
        try jsonPayload.data(using: .utf8)!.write(to: storeFile)

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        let document = try await store.load()

        #expect(document.schemaVersion == 1)
        #expect(document.currentTerm.label == "Fall 2026")
        #expect(document.mappings.count == 2)
        #expect(document.mappings["CS101 Lecture"]?.courseCode == "CS101")
        #expect(document.mappings["MATH200 Lab"]?.courseName == "Calculus II")
        #expect(document.recentCourseCodes == ["MATH200", "CS101"])
    }

    // MARK: - Test 9: deleteMapping() removes entry and persists

    @Test("deleteMapping() removes entry from mappings and persists")
    func deleteMappingRemovesAndPersists() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        let mapping = CourseMapping(courseCode: "CS101", courseName: "Intro to CS")
        try await store.upsert(eventTitle: "CS101 Lecture", mapping: mapping)

        // Verify it exists
        #expect(try await store.lookup(eventTitle: "CS101 Lecture") != nil)

        // Delete it
        try await store.deleteMapping(eventTitle: "CS101 Lecture")

        // Verify it's gone
        #expect(try await store.lookup(eventTitle: "CS101 Lecture") == nil)

        // Verify persistence via fresh load
        let store2 = CourseMappingStore(vaultRoot: vaultRoot)
        let document = try await store2.load()
        #expect(document.mappings["CS101 Lecture"] == nil)
    }

    // MARK: - Test 10: allMappings() returns full dict

    @Test("allMappings() returns the complete mappings dictionary")
    func allMappingsReturnsFullDict() async throws {
        let vaultRoot = try makeVaultRoot()
        defer { cleanup(vaultRoot) }

        let store = CourseMappingStore(vaultRoot: vaultRoot)
        try await store.upsert(
            eventTitle: "CS101 Lecture",
            mapping: CourseMapping(courseCode: "CS101", courseName: "Intro to CS")
        )
        try await store.upsert(
            eventTitle: "MATH200 Lab",
            mapping: CourseMapping(courseCode: "MATH200", courseName: "Calculus II")
        )

        let mappings = try await store.allMappings()
        #expect(mappings.count == 2)
        #expect(mappings["CS101 Lecture"]?.courseCode == "CS101")
        #expect(mappings["MATH200 Lab"]?.courseCode == "MATH200")
    }
}
