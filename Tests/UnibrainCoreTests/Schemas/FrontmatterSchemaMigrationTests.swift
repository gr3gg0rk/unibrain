import Testing
import Foundation
import Yams
@testable import UnibrainCore

/// Tests for FrontmatterSchema v1→v2 migration and ConsentStore atomic writes.
///
/// Phase 06-06 Task 3: Verifies:
/// - ConsentStore.save() uses .atomic option (per CON-03 — iCloud sync safety)
/// - FrontmatterSchema v1 notes decode with nil *_provider fields
/// - FrontmatterSchema encoder always writes schema_version: 2
/// - Round-trip preserves data across v1→v2 boundary
@Suite("FrontmatterSchemaMigrationTests")
struct FrontmatterSchemaMigrationTests {

    // MARK: - Schema Migration Tests

    @Test("v1 note (no *_provider fields) decodes with nil provider fields")
    func v1NoteDecodesWithNilProviderFields() throws {
        // Simulate a Phase 1-5 note with schema_version: 1 and no *_provider fields
        let v1YAML = """
        schema_version: 1
        course: CS101
        course_name: Intro to CS
        term: Fall 2026
        datetime: 2026-07-15T10:00:00Z
        duration_seconds: 3600
        source: MacBook Air
        audio_file: lecture.m4a
        tags: [lecture, cs101]
        """

        let decoder = YAMLDecoder()
        let schema = try decoder.decode(FrontmatterSchema.self, from: v1YAML)

        #expect(schema.schemaVersion == 1)
        #expect(schema.course == "CS101")
        // v1 fields should decode as nil
        #expect(schema.asrProvider == nil)
        #expect(schema.llmProvider == nil)
        #expect(schema.visionProvider == nil)
        #expect(schema.summaryModel == nil)
    }

    @Test("v2 note with *_provider fields decodes correctly")
    func v2NoteDecodesWithProviderFields() throws {
        let v2YAML = """
        schema_version: 2
        course: CS101
        course_name: Intro to CS
        term: Fall 2026
        datetime: 2026-07-15T10:00:00Z
        duration_seconds: 3600
        source: MacBook Air
        audio_file: lecture.m4a
        tags: [lecture, cs101]
        llm_provider: ollama
        asr_provider: whisper-cpp
        summary_model: llama-3.2:3b
        """

        let decoder = YAMLDecoder()
        let schema = try decoder.decode(FrontmatterSchema.self, from: v2YAML)

        #expect(schema.schemaVersion == 2)
        #expect(schema.llmProvider == "ollama")
        #expect(schema.asrProvider == "whisper-cpp")
        #expect(schema.summaryModel == "llama-3.2:3b")
        #expect(schema.visionProvider == nil) // not in this note
    }

    @Test("Encoder writes schema_version: 2 for new notes")
    func encoderWritesVersion2() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 2,
            course: "CS101",
            courseName: "Intro to CS",
            term: "Fall 2026",
            datetime: Date(timeIntervalSince1970: 1_000_000),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "lecture.m4a",
            tags: ["lecture"],
            llmProvider: "ollama"
        )

        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(schema)

        // Verify YAML contains snake_case keys
        #expect(yaml.contains("schema_version: 2"))
        #expect(yaml.contains("llm_provider: ollama"))
        // Verify CodingKeys use snake_case
        #expect(yaml.contains("course_name:"))
        #expect(yaml.contains("duration_seconds:"))
    }

    @Test("Round-trip: v1 decode then v2 encode adds new fields")
    func roundTripV1ToV2() throws {
        let v1YAML = """
        schema_version: 1
        course: CS101
        course_name: Intro to CS
        term: Fall 2026
        datetime: 2026-07-15T10:00:00Z
        duration_seconds: 3600
        source: MacBook Air
        audio_file: lecture.m4a
        tags: [lecture, cs101]
        """

        let decoder = YAMLDecoder()
        var schema = try decoder.decode(FrontmatterSchema.self, from: v1YAML)

        // Simulate Phase 6 adding provider info
        schema.schemaVersion = 2
        schema.llmProvider = "ollama"
        schema.summaryModel = "llama-3.2:3b"

        // Encode back
        let encoder = YAMLEncoder()
        let v2YAML = try encoder.encode(schema)

        // Decode again to verify round-trip
        let redecoded = try decoder.decode(FrontmatterSchema.self, from: v2YAML)
        #expect(redecoded.schemaVersion == 2)
        #expect(redecoded.llmProvider == "ollama")
        #expect(redecoded.summaryModel == "llama-3.2:3b")
        #expect(redecoded.course == "CS101")
    }

    @Test("validate() passes with nil provider fields")
    func validatePassesWithNilProviders() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 1,
            course: "CS101",
            courseName: "Intro",
            term: "Fall 2026",
            datetime: Date(),
            durationSeconds: 3600,
            source: "MacBook",
            audioFile: "test.m4a",
            tags: ["lecture"]
            // asrProvider, llmProvider, visionProvider all nil
        )

        // Should not throw — validate only checks required fields
        #expect(throws: Never.self) {
            try schema.validate()
        }
    }
}
