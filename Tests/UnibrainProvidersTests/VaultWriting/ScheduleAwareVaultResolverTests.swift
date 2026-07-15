import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

/// Tests for ScheduleAwareVaultResolver (Phase 4 replacement for HardcodedVaultResolver).
///
/// Validates CLAS-05 (multi-term folder structure),
/// CLAS-02 (mapping lookup -> course code path),
/// CLAS-03 (auto-create sanitized folder for unmapped titles),
/// MP-03 (Skip -> _unsorted path),
/// and A-05 (recursive directory creation).
///
/// macOS-only: uses FileManager.createDirectory which needs macOS path semantics.
/// The resolver itself is struct-based and fully testable.

#if os(macOS)

@Suite("ScheduleAwareVaultResolver")
struct ScheduleAwareVaultResolverTests {

    // MARK: - Test Fixtures

    /// Creates a unique temp vault root for each test.
    private func makeVaultRoot() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_resolver_\(UUID().uuidString)")
        return tempDir
    }

    /// Standard recording date: Sept 15, 2026.
    private let recordingDate = Date(timeIntervalSince1970: 1_789_108_800) // approx 2026-09-15

    // MARK: - Test 1: Basic path construction (CLAS-05)

    @Test("resolve builds {vault}/{term}/{course}/YYYY-MM-DD-{COURSE}-Lecture.md path")
    func resolveBuildsCorrectPath() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let event = CalendarEvent(
            id: "evt-1",
            title: "CS101 Lecture",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )

        let url = try resolver.resolve(match: .single(event), recordingStart: recordingDate)

        // Path should contain sanitized term
        #expect(url.path.contains("Fall 2026"))
        // Path should contain course title as folder
        #expect(url.path.contains("CS101 Lecture"))
        // Filename should be date-course-Lecture.md pattern
        #expect(url.lastPathComponent.contains("Lecture.md"))
        // The path structure: vault/term/course/filename
        let relativePath = url.path.replacingOccurrences(of: vaultRoot.path + "/", with: "")
        let components = relativePath.split(separator: "/")
        #expect(components.count == 3) // term/course/file.md
    }

    // MARK: - Test 2: Unsafe characters sanitized (CLAS-03, T-2-01)

    @Test("resolve sanitizes unsafe characters in event title")
    func resolveSanitizesUnsafeCharacters() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let event = CalendarEvent(
            id: "evt-2",
            title: "CS101: Intro / Lecture",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )

        let url = try resolver.resolve(match: .single(event), recordingStart: recordingDate)

        // Path should NOT contain raw slashes in the folder name (sanitized)
        // The sanitized version replaces / and : with spaces
        let sanitized = FolderNameSanitizer.sanitize(folderName: "CS101: Intro / Lecture")
        #expect(url.path.contains(sanitized))
    }

    // MARK: - Test 3: Skip path routes to _unsorted (MP-03)

    @Test("resolve with _unsorted title produces {term}/_unsorted/ path")
    func resolveUnsortedPath() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let unsortedEvent = CalendarEvent(
            id: "unsorted",
            title: "_unsorted",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )

        let url = try resolver.resolve(match: .single(unsortedEvent), recordingStart: recordingDate)

        #expect(url.path.contains("_unsorted"))
        #expect(url.lastPathComponent.contains("Lecture.md"))
    }

    // MARK: - Test 4: Directory tree created recursively (A-05)

    @Test("resolve creates intermediate directories recursively")
    func resolveCreatesDirectories() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        // Ensure vault root does not exist yet
        #expect(!FileManager.default.fileExists(atPath: vaultRoot.path))

        let event = CalendarEvent(
            id: "evt-3",
            title: "Math 201",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )

        _ = try resolver.resolve(match: .single(event), recordingStart: recordingDate)

        // The term/course directory tree should have been created
        let expectedDir = vaultRoot
            .appendingPathComponent("Fall 2026")
            .appendingPathComponent("Math 201")
        #expect(FileManager.default.fileExists(atPath: expectedDir.path))
    }

    // MARK: - Test 5: Different terms produce different base directories (CLAS-05)

    @Test("Different term labels produce different base directories")
    func differentTermsDifferentDirs() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let event = CalendarEvent(
            id: "evt-4",
            title: "CS101",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let fallResolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )
        let springResolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Spring 2027"
        )

        let fallURL = try fallResolver.resolve(match: .single(event), recordingStart: recordingDate)
        let springURL = try springResolver.resolve(match: .single(event), recordingStart: recordingDate)

        // The term component should differ
        #expect(fallURL.path.contains("Fall 2026"))
        #expect(springURL.path.contains("Spring 2027"))
        // The paths should not be the same
        #expect(fallURL.path != springURL.path)
    }

    // MARK: - Test 6: Mapping lookup uses courseCode (CLAS-02)

    @Test("resolve with mapping uses courseCode in path instead of raw title")
    func resolveWithMappingUsesCourseCode() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let event = CalendarEvent(
            id: "evt-5",
            title: "Intro to Computer Science",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let mapping: [String: CourseMapping] = [
            "Intro to Computer Science": CourseMapping(
                courseCode: "CS101",
                courseName: "Intro to CS"
            )
        ]

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026",
            mapping: mapping
        )

        let url = try resolver.resolve(match: .single(event), recordingStart: recordingDate)

        // Path should use the mapped courseCode, not the raw title
        #expect(url.path.contains("CS101"))
        // Path should NOT contain the raw event title as a folder component
        // (it might appear in the sanitized form, but CS101 should be the folder)
        let relativePath = url.path.replacingOccurrences(of: vaultRoot.path + "/", with: "")
        let components = relativePath.split(separator: "/")
        // Second component (index 1) should be the course folder = CS101
        if components.count >= 2 {
            #expect(components[1] == "CS101")
        }
        // Filename should contain CS101
        #expect(url.lastPathComponent.contains("CS101"))
    }

    // MARK: - Test 7: Empty term label uses default (edge case)

    @Test("resolve with empty term label uses default-term fallback")
    func resolveWithEmptyTermLabel() throws {
        let vaultRoot = makeVaultRoot()
        defer { try? FileManager.default.removeItem(at: vaultRoot) }

        let event = CalendarEvent(
            id: "evt-6",
            title: "Physics 101",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: ""
        )

        let url = try resolver.resolve(match: .single(event), recordingStart: recordingDate)

        // Should use "default-term" as fallback
        #expect(url.path.contains("default-term"))
    }

    // MARK: - Test 8: Throws on .multiple or .none match

    @Test("resolve throws PipelineError.invalidInputs for .none match")
    func resolveThrowsForNoneMatch() throws {
        let vaultRoot = makeVaultRoot()

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )

        #expect(throws: PipelineError.self) {
            try resolver.resolve(match: .none, recordingStart: recordingDate)
        }
    }

    @Test("resolve throws PipelineError.invalidInputs for .multiple match")
    func resolveThrowsForMultipleMatch() throws {
        let vaultRoot = makeVaultRoot()

        let event1 = CalendarEvent(
            id: "e1",
            title: "Math",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )
        let event2 = CalendarEvent(
            id: "e2",
            title: "Physics",
            startDate: recordingDate,
            endDate: recordingDate.addingTimeInterval(3600)
        )

        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: vaultRoot,
            termLabel: "Fall 2026"
        )

        #expect(throws: PipelineError.self) {
            try resolver.resolve(match: .multiple([event1, event2]), recordingStart: recordingDate)
        }
    }

    // MARK: - Test 9: Sendable conformance

    @Test("ScheduleAwareVaultResolver is Sendable")
    func resolverIsSendable() async {
        let resolver = ScheduleAwareVaultResolver(
            vaultRoot: URL(fileURLWithPath: "/tmp/vault"),
            termLabel: "Fall 2026"
        )
        // Compile-time Sendable check: assigning to any Sendable succeeds
        // only if the type conforms to Sendable.
        let sendable: any Sendable = resolver
        #expect(sendable is ScheduleAwareVaultResolver)
    }
}

#endif // os(macOS)
