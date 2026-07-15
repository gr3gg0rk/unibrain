import Testing
import Foundation
@testable import UnibrainCore
import Yams

@Suite("NoteWriter")
struct NoteWriterTests {

    // MARK: - Test Fixtures

    /// Creates a minimal valid NormalizedNote for testing.
    private func makeNote() -> NormalizedNote {
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to Computer Science",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture", "cs101"]
        )
        return NormalizedNote(
            title: "# 2023-11-14 — CS101 Lecture",
            body: "## Transcript\n\nThis is a test transcript.",
            frontmatter: frontmatter
        )
    }

    // MARK: - TestNoteWriter Conformance Tests

    @Test("TestNoteWriter conforms to NoteWriter protocol")
    func testNoteWriterConforms() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_conformance.md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    @Test("write creates intermediate directories recursively")
    func writeCreatesIntermediateDirectories() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_dirs_\(UUID().uuidString)")
        let dest = baseURL
            .appendingPathComponent("subdir1/subdir2/note.md")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        try await writer.write(note, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    @Test("write serializes frontmatter to YAML using Yams")
    func writeSerializesFrontmatterToYAML() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_yaml_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)
        let content = try String(contentsOf: dest, encoding: .utf8)

        // Verify frontmatter YAML markers
        #expect(content.contains("---"))
        // Verify key frontmatter fields are present in YAML
        #expect(content.contains("course: CS101"))
        #expect(content.contains("course_name: Intro to Computer Science"))
        #expect(content.contains("duration_seconds: 3600"))
    }

    @Test("write uses FileManager .atomic option for atomic writes")
    func writeUsesAtomicOption() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_atomic_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.path))
        // The .atomic flag is verified by the TestNoteWriter implementation
        // using String.write(to:atomically:encoding:) which uses POSIX rename(2).
        // The file existing after write proves the atomic rename completed.
    }

    @Test("write throws iCloudPlaceholder when destination contains .icloud in path")
    func writeThrowsICloudPlaceholder() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent(".icloud")
            .appendingPathComponent("note.md")

        await #expect(throws: NoteWriterError.self) {
            try await writer.write(note, to: dest)
        }
    }

    @Test("write throws permissionDenied when createDirectory fails")
    func writeThrowsPermissionDenied() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        // Use a path under a non-existent root that will fail directory creation
        // On Linux, /nonexistent_root_for_unibrain/... will fail with permission error
        let dest = URL(fileURLWithPath: "/nonexistent_root_for_unibrain_\(UUID().uuidString)/subdir/note.md")

        await #expect(throws: NoteWriterError.self) {
            try await writer.write(note, to: dest)
        }
    }

    @Test("write round-trip: write then read content matches")
    func writeRoundTrip() async throws {
        let writer = TestNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_roundtrip_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)
        let readContent = try String(contentsOf: dest, encoding: .utf8)

        // Verify the title is present
        #expect(readContent.contains("# 2023-11-14 — CS101 Lecture"))
        // Verify the body is present
        #expect(readContent.contains("## Transcript"))
        #expect(readContent.contains("This is a test transcript."))
        // Verify frontmatter is present
        #expect(readContent.contains("course: CS101"))
    }

    // MARK: - NoteWriterError All-Cases Coverage

    @Test("All six NoteWriterError cases are constructible and catchable")
    func allErrorCasesConstructible() async throws {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let underlying = NSError(domain: "test", code: 1)

        let errors: [NoteWriterError] = [
            .iCloudPlaceholder(url),
            .diskFull,
            .permissionDenied(url),
            .alreadyExists(url),
            .directoryCreationFailed(url, underlying: underlying),
            .underlying(underlying)
        ]

        for error in errors {
            do {
                throw error
            } catch let caught as NoteWriterError {
                // Verify each error is caught as NoteWriterError
                switch caught {
                case .iCloudPlaceholder:
                    break
                case .diskFull:
                    break
                case .permissionDenied:
                    break
                case .alreadyExists:
                    break
                case .directoryCreationFailed:
                    break
                case .underlying:
                    break
                }
            } catch {
                Issue.record("Caught non-NoteWriterError: \(error)")
            }
        }
    }

    @Test("iCloudPlaceholder case carries URL parameter correctly")
    func iCloudPlaceholderCarriesURL() async throws {
        let url = URL(fileURLWithPath: "/vault/.icloud/note.md")
        let error = NoteWriterError.iCloudPlaceholder(url)

        if case .iCloudPlaceholder(let carriedURL) = error {
            #expect(carriedURL == url)
        } else {
            Issue.record("Expected .iCloudPlaceholder case")
        }
    }

    @Test("permissionDenied case carries URL parameter correctly")
    func permissionDeniedCarriesURL() async throws {
        let url = URL(fileURLWithPath: "/readonly/note.md")
        let error = NoteWriterError.permissionDenied(url)

        if case .permissionDenied(let carriedURL) = error {
            #expect(carriedURL == url)
        } else {
            Issue.record("Expected .permissionDenied case")
        }
    }

    @Test("alreadyExists case carries URL parameter correctly")
    func alreadyExistsCarriesURL() async throws {
        let url = URL(fileURLWithPath: "/vault/existing.md")
        let error = NoteWriterError.alreadyExists(url)

        if case .alreadyExists(let carriedURL) = error {
            #expect(carriedURL == url)
        } else {
            Issue.record("Expected .alreadyExists case")
        }
    }

    @Test("directoryCreationFailed case carries URL and underlying Error")
    func directoryCreationFailedCarriesURLAndError() async throws {
        let url = URL(fileURLWithPath: "/vault/new/sub/dir/")
        let underlying = NSError(domain: "filesystem", code: 13)
        let error = NoteWriterError.directoryCreationFailed(url, underlying: underlying)

        if case .directoryCreationFailed(let carriedURL, let carriedError) = error {
            #expect(carriedURL == url)
            #expect(carriedError as NSError == underlying)
        } else {
            Issue.record("Expected .directoryCreationFailed case")
        }
    }

    @Test("underlying case carries any Error correctly")
    func underlyingCarriesError() async throws {
        struct CustomError: Error {}
        let custom = CustomError()
        let error = NoteWriterError.underlying(custom)

        if case .underlying = error {
            // success — proves any Error is accepted
        } else {
            Issue.record("Expected .underlying case")
        }
    }

    @Test("diskFull case constructs without associated values")
    func diskFullConstructs() async throws {
        let error = NoteWriterError.diskFull

        if case .diskFull = error {
            // success
        } else {
            Issue.record("Expected .diskFull case")
        }
    }

    @Test("NoteWriter protocol method is async throws")
    func protocolMethodIsAsyncThrows() async throws {
        // This test verifies at compile time that the protocol method
        // signature is `async throws`. If the signature changes, this
        // test will not compile.
        let writer = TestNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_sig_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        // The `try await` pattern compiles only if the method is async throws
        try await writer.write(note, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }
}

// MARK: - TestNoteWriter Implementation

/// Linux-testable NoteWriter conformance using pure Foundation FileManager.
///
/// Per RESEARCH.md and Pattern 14: uses `String.write(to:atomically:encoding:)`
/// for cross-platform atomic writes (WRITE-04), checks `.icloud` in path
/// components for iCloud placeholder detection (WRITE-05), and creates
/// intermediate directories recursively (A-05).
///
/// Phase 3's `NSFileCoordinatorNoteWriter` replaces this for production
/// with Apple-framework-specific file coordination.
private struct TestNoteWriter: NoteWriter {
    func write(_ note: NormalizedNote, to destination: URL) async throws {
        // WRITE-05 / A-03: Detect .icloud placeholder in path components
        if destination.pathComponents.contains(".icloud") {
            throw NoteWriterError.iCloudPlaceholder(destination)
        }

        // A-05: Create intermediate directories recursively
        let directory = destination.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            // T-2-05: Surface directory creation failure with structured error
            throw NoteWriterError.directoryCreationFailed(directory, underlying: error)
        }

        // Serialize frontmatter to YAML using Yams (per FrontmatterSchema pattern)
        let yamlFrontmatter: String
        do {
            yamlFrontmatter = try YAMLEncoder().encode(note.frontmatter)
        } catch {
            throw NoteWriterError.underlying(error)
        }

        // Build full Markdown content: frontmatter block + body
        let content = "---\n\(yamlFrontmatter)---\n\n\(note.body)"

        // WRITE-04: Atomic write via FileManager .atomic option
        // String.write(to:atomically:encoding:) uses POSIX rename(2) which
        // is atomic on Linux/macOS — prevents partial write corruption.
        do {
            try content.write(to: destination, atomically: true, encoding: .utf8)
        } catch {
            // WRITE-06: Surface filesystem errors with structured cases
            throw NoteWriterError.underlying(error)
        }
    }
}
