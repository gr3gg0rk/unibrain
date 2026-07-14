import Testing
import Foundation
import Yams
@testable import UnibrainCore

@Suite("FrontmatterSchema")
struct FrontmatterSchemaTests {

    @Test("Creating FrontmatterSchema with required fields")
    func createSchema() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to Computer Science",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400,
            source: "MacBook Air",
            audioFile: "lecture-2026-09-15.m4a",
            tags: ["lecture", "week1"],
            syllabusLink: nil,
            vectorId: nil,
            summaryModel: nil
        )
        #expect(schema.course == "CS101")
        #expect(schema.schemaVersion == 1)
        #expect(schema.durationSeconds == 5400)
        #expect(schema.tags.count == 2)
    }

    // MARK: - Yams Round-Trip Tests

    @Test("Full Yams round-trip preserves all 12 fields")
    func roundTripPreservesAllFields() throws {
        let original = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "lecture",
            audioFile: "recording.m4a",
            tags: ["cs", "lecture"],
            syllabusLink: "https://example.edu/syllabus",
            vectorId: "vec-001",
            summaryModel: "llama-3.2-3b"
        )

        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(original)

        let decoder = YAMLDecoder()
        let decoded = try decoder.decode(FrontmatterSchema.self, from: yamlString)

        #expect(decoded.schemaVersion == original.schemaVersion)
        #expect(decoded.course == original.course)
        #expect(decoded.courseName == original.courseName)
        #expect(decoded.term == original.term)
        #expect(decoded.datetime == original.datetime)
        #expect(decoded.durationSeconds == original.durationSeconds)
        #expect(decoded.source == original.source)
        #expect(decoded.audioFile == original.audioFile)
        #expect(decoded.tags == original.tags)
        #expect(decoded.syllabusLink == original.syllabusLink)
        #expect(decoded.vectorId == original.vectorId)
        #expect(decoded.summaryModel == original.summaryModel)
    }

    @Test("Nullable fields survive nil round-trip through Yams")
    func nullableFieldsSurviveNilRoundTrip() throws {
        let original = FrontmatterSchema(
            schemaVersion: 1,
            course: "MATH201",
            courseName: "Linear Algebra",
            term: "Spring 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 2700,
            source: "iPhone",
            audioFile: "math-lecture.wav",
            tags: ["math", "algebra"],
            syllabusLink: nil,
            vectorId: nil,
            summaryModel: nil
        )

        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(original)

        let decoder = YAMLDecoder()
        let decoded = try decoder.decode(FrontmatterSchema.self, from: yamlString)

        #expect(decoded.syllabusLink == nil)
        #expect(decoded.vectorId == nil)
        #expect(decoded.summaryModel == nil)
    }

    @Test("YAML output uses snake_case keys")
    func yamlOutputUsesSnakeCaseKeys() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "lecture",
            audioFile: "recording.m4a",
            tags: ["cs"],
            syllabusLink: nil,
            vectorId: nil,
            summaryModel: nil
        )

        let encoder = YAMLEncoder()
        let yamlString = try encoder.encode(schema)

        // Verify snake_case CodingKeys appear in the YAML output
        #expect(yamlString.contains("schema_version"))
        #expect(yamlString.contains("course_name"))
        #expect(yamlString.contains("duration_seconds"))
        #expect(yamlString.contains("audio_file"))
    }

    // MARK: - Validation Tests

    @Test("validate() succeeds when all required fields are non-empty and duration > 0")
    func validateSucceedsOnValidSchema() throws {
        let schema = FrontmatterSchema(
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

        #expect(throws: Never.self) {
            try schema.validate()
        }
    }

    @Test("validate() throws emptyField when course is empty")
    func validateThrowsOnEmptyCourse() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"]
        )

        #expect(throws: FrontmatterValidationError.emptyField("course")) {
            try schema.validate()
        }
    }

    @Test("validate() throws emptyField when courseName is empty")
    func validateThrowsOnEmptyCourseName() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"]
        )

        #expect(throws: FrontmatterValidationError.emptyField("course_name")) {
            try schema.validate()
        }
    }

    @Test("validate() throws emptyField when term is empty")
    func validateThrowsOnEmptyTerm() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"]
        )

        #expect(throws: FrontmatterValidationError.emptyField("term")) {
            try schema.validate()
        }
    }

    @Test("validate() throws invalidDuration when duration <= 0")
    func validateThrowsOnZeroDuration() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 0,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"]
        )

        #expect(throws: FrontmatterValidationError.invalidDuration(0)) {
            try schema.validate()
        }
    }

    @Test("validate() throws missingRequiredField when tags is empty")
    func validateThrowsOnEmptyTags() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: []
        )

        #expect(throws: FrontmatterValidationError.missingRequiredField("tags")) {
            try schema.validate()
        }
    }
}
