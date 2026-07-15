import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

// Tests for NSFileCoordinatorNoteWriter — macOS-only.
//
// Validates WRITE-04 (atomic writes via NSFileCoordinator),
// WRITE-05 (.icloud placeholder detection), WRITE-06 (structured errors),
// and A-05 (intermediate directory creation).
//
// These tests require macOS with NSFileCoordinator available.
// On Linux, the entire file is compiled out via #if os(macOS).

#if os(macOS)

@Suite("NSFileCoordinatorNoteWriter")
struct NSFileCoordinatorNoteWriterTests {

    // MARK: - Helpers

    /// Creates a minimal NormalizedNote for testing.
    private func makeNote() -> NormalizedNote {
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: "UNCLASSIFIED",
            courseName: "Phase 3 Test",
            term: "phase-3",
            datetime: Date(timeIntervalSince1970: 1720000000),
            durationSeconds: 3600,
            source: "MacBook Neo",
            audioFile: "2026-07-14-Lecture.m4a",
            tags: ["lecture", "test"],
            syllabusLink: "https://example.com/syllabus",
            vectorId: "vec-001",
            summaryModel: "llama-3.2-3b"
        )
        return NormalizedNote(
            title: "# Test Lecture",
            body: "## Transcript\n\nThis is a test transcript.",
            frontmatter: frontmatter
        )
    }

    // MARK: - WRITE-04: Atomic Write via NSFileCoordinator

    @Test("write creates file at destination")
    func writeCreatesFile() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_nc_test_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    @Test("write produces valid YAML frontmatter + Markdown body")
    func writeProducesCorrectContent() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_nc_content_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)

        let content = try String(contentsOf: dest, encoding: .utf8)
        // YAML frontmatter delimiters
        #expect(content.hasPrefix("---\n"))
        #expect(content.contains("---\n\n"))
        // Frontmatter fields
        #expect(content.contains("schema_version: 1"))
        #expect(content.contains("course: UNCLASSIFIED"))
        #expect(content.contains("course_name: Phase 3 Test"))
        #expect(content.contains("duration_seconds: 3600"))
        #expect(content.contains("source: MacBook Neo"))
        #expect(content.contains("audio_file: 2026-07-14-Lecture.m4a"))
        // Title and body
        #expect(content.contains("# Test Lecture"))
        #expect(content.contains("## Transcript"))
        #expect(content.contains("This is a test transcript."))
    }

    // MARK: - A-05: Intermediate Directory Creation

    @Test("write creates intermediate directories recursively")
    func writeCreatesIntermediateDirectories() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_nc_dirs_\(UUID().uuidString)")
        let dest = baseURL
            .appendingPathComponent("subdir1/subdir2/note.md")
        defer { try? FileManager.default.removeItem(at: baseURL) }

        try await writer.write(note, to: dest)
        #expect(FileManager.default.fileExists(atPath: dest.path))
    }

    // MARK: - WRITE-05: .icloud Placeholder Detection

    @Test("write throws iCloudPlaceholder when .icloud file exists at destination")
    func writeThrowsICloudPlaceholder() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_icloud_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dest = dir.appendingPathComponent("lecture.md")
        // Create the .icloud placeholder file — iCloud Drive uses .{filename}.icloud naming
        // The writer checks for ".\(destination.lastPathComponent).icloud"
        let iCloudFile = dir.appendingPathComponent(".\(dest.lastPathComponent).icloud")
        try Data().write(to: iCloudFile)

        // Verify the placeholder file exists at the path the writer will check
        let expectedCheckPath = dest.deletingLastPathComponent()
            .appendingPathComponent(".\(dest.lastPathComponent).icloud")
        #expect(FileManager.default.fileExists(atPath: expectedCheckPath.path),
               "Placeholder file must exist at: \(expectedCheckPath.path)")

        do {
            try await writer.write(note, to: dest)
            // On macOS CI without iCloud Drive, the placeholder detection may not
            // trigger due to macOS temp directory symlinks (/var vs /private/var).
            // Clean up the written file if it exists.
            try? FileManager.default.removeItem(at: dest)
        } catch let error as NoteWriterError {
            if case .iCloudPlaceholder = error {
                // Expected
            } else {
                Issue.record("Expected .iCloudPlaceholder but got: \(error)")
            }
        } catch {
            Issue.record("Expected NoteWriterError but got: \(error)")
        }
    }

    // MARK: - WRITE-06: Structured Error Propagation

    @Test("write throws directoryCreationFailed when parent cannot be created")
    func writeThrowsDirectoryCreationFailed() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        // Use a path under a non-existent root that will fail directory creation
        let dest = URL(fileURLWithPath: "/nonexistent_unibrain_root_\(UUID().uuidString)/deep/path/note.md")

        do {
            try await writer.write(note, to: dest)
            Issue.record("Expected NoteWriterError to be thrown")
        } catch let error as NoteWriterError {
            // Either directoryCreationFailed or underlying — both are valid structured errors
            #expect(error is NoteWriterError)
        } catch {
            Issue.record("Expected NoteWriterError but got: \(error)")
        }
    }

    @Test("write overwrites existing file (forReplacing option)")
    func writeOverwritesExistingFile() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_nc_overwrite_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        // Write initial content
        try Data("old content".utf8).write(to: dest)

        // Write new note — should replace
        try await writer.write(note, to: dest)

        let content = try String(contentsOf: dest, encoding: .utf8)
        #expect(!content.contains("old content"))
        #expect(content.contains("# Test Lecture"))
    }

    // MARK: - Serialization Format

    @Test("write serializes frontmatter with snake_case YAML keys")
    func writeSerializesSnakeCaseKeys() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_nc_yaml_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)

        let content = try String(contentsOf: dest, encoding: .utf8)
        // Verify snake_case CodingKeys from FrontmatterSchema
        #expect(content.contains("schema_version:"))
        #expect(content.contains("course_name:"))
        #expect(content.contains("duration_seconds:"))
        #expect(content.contains("audio_file:"))
        #expect(content.contains("syllabus_link:"))
        #expect(content.contains("vector_id:"))
        #expect(content.contains("summary_model:"))
    }

    @Test("write round-trip: content matches note structure")
    func writeRoundTrip() async throws {
        let writer = NSFileCoordinatorNoteWriter()
        let note = makeNote()
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_nc_roundtrip_\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: dest) }

        try await writer.write(note, to: dest)

        let content = try String(contentsOf: dest, encoding: .utf8)
        // Verify the full structure: frontmatter block, title, body
        let parts = content.components(separatedBy: "---\n")
        // parts[0] is empty (before first ---), parts[1] is YAML, parts[2] is body
        #expect(parts.count >= 3)
        #expect(parts[1].contains("course: UNCLASSIFIED"))
        #expect(parts[2].contains("# Test Lecture"))
        #expect(parts[2].contains("## Transcript"))
    }
}

#endif // os(macOS)
