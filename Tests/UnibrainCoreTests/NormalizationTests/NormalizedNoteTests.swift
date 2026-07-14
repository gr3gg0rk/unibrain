import Testing
import Foundation
@testable import UnibrainCore

@Suite("NormalizedNote")
struct NormalizedNoteTests {

    @Test("NormalizedNote constructs with title, body, and frontmatter fields")
    func constructsWithAllFields() throws {
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"]
        )

        let note = NormalizedNote(
            title: "# 2026-09-15 — CS101 Lecture",
            body: "Some body text",
            frontmatter: frontmatter
        )

        #expect(note.title == "# 2026-09-15 — CS101 Lecture")
        #expect(note.body == "Some body text")
        #expect(note.frontmatter.course == "CS101")
    }

    @Test("NormalizedNote is Sendable and can cross concurrency boundaries")
    func isSendable() async throws {
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"]
        )

        let note = NormalizedNote(
            title: "# Test",
            body: "Body",
            frontmatter: frontmatter
        )

        // Sendable conformance verified by passing across actor boundary
        let result = await TestActor.shared.echo(note)
        #expect(result.title == note.title)
    }

    @Test("NormalizedNote stores FrontmatterSchema with all 12 fields")
    func storesAllFrontmatterFields() throws {
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: "MATH201",
            courseName: "Linear Algebra",
            term: "Spring 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 2700,
            source: "iPhone",
            audioFile: "math.wav",
            tags: ["math", "algebra"],
            syllabusLink: "https://example.edu/syllabus",
            vectorId: "vec-001",
            summaryModel: "llama-3.2-3b"
        )

        let note = NormalizedNote(
            title: "# Test",
            body: "Body",
            frontmatter: frontmatter
        )

        #expect(note.frontmatter.schemaVersion == 1)
        #expect(note.frontmatter.course == "MATH201")
        #expect(note.frontmatter.courseName == "Linear Algebra")
        #expect(note.frontmatter.term == "Spring 2026")
        #expect(note.frontmatter.durationSeconds == 2700)
        #expect(note.frontmatter.source == "iPhone")
        #expect(note.frontmatter.audioFile == "math.wav")
        #expect(note.frontmatter.tags.count == 2)
        #expect(note.frontmatter.syllabusLink == "https://example.edu/syllabus")
        #expect(note.frontmatter.vectorId == "vec-001")
        #expect(note.frontmatter.summaryModel == "llama-3.2-3b")
    }
}

/// Helper actor to verify Sendable conformance by crossing isolation boundaries.
private actor TestActor {
    static let shared = TestActor()

    func echo<T>(_ value: T) -> T where T: Sendable {
        value
    }
}
