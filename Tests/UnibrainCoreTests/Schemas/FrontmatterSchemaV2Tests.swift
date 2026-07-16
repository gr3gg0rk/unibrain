import Testing
import Foundation
import Yams
@testable import UnibrainCore

/// Tests for FrontmatterSchema v2 (audit trail fields).
///
/// Phase 06-01 Task 4: Extends FrontmatterSchema with *_provider fields
/// and bumps schema_version 1→2. Tests verify backward compatibility.
@Suite("FrontmatterSchemaV2Tests")
struct FrontmatterSchemaV2Tests {

    // MARK: - Schema Version 2 Encoding

    @Test("FrontmatterSchema with schemaVersion: 2 encodes to YAML with *_provider keys")
    func v2EncodingProducesProviderFields() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 2,
            course: "CS101",
            courseName: "Intro to Computer Science",
            term: "Fall 2026",
            datetime: Date(),
            durationSeconds: 3000,
            source: "MacBook Air",
            audioFile: "lecture.mp3",
            tags: ["lecture", "intro"],
            asrProvider: "whisper-cpp",
            llmProvider: "ollama",
            visionProvider: nil
        )

        let yaml = try YAMLEncoder().encode(schema)
        #expect(yaml.contains("asr_provider: whisper-cpp"))
        #expect(yaml.contains("llm_provider: ollama"))
        #expect(yaml.contains("schema_version: 2"))
    }

    // MARK: - Backward Compatibility

    @Test("Decoding schema_version: 1 note defaults new fields to nil")
    func v1DecodingDefaultsNewFieldsToNil() throws {
        let yamlString = """
schema_version: 1
course: CS101
course_name: Intro to Computer Science
term: Fall 2026
datetime: 2026-07-16T10:00:00Z
duration_seconds: 3000
source: MacBook Air
audio_file: lecture.mp3
tags:
  - lecture
  - intro
"""

        let schema = try YAMLDecoder().decode(FrontmatterSchema.self, from: yamlString)
        #expect(schema.schemaVersion == 1)
        #expect(schema.asrProvider == nil)
        #expect(schema.llmProvider == nil)
        #expect(schema.visionProvider == nil)
    }

    // MARK: - Round-Trip Integrity

    @Test("Round-trip preserves all fields including new *_provider fields")
    func roundTripPreservesAllFields() throws {
        let original = FrontmatterSchema(
            schemaVersion: 2,
            course: "MATH101",
            courseName: "Calculus I",
            term: "Spring 2026",
            datetime: Date(timeIntervalSince1970: 1710585600),
            durationSeconds: 2700,
            source: "iPhone",
            audioFile: "calc_lecture.mp3",
            tags: ["calculus", "derivatives"],
            syllabusLink: "https://example.com/syllabus",
            vectorId: "vec-123",
            summaryModel: "llama-3.2:3b",
            asrProvider: "openai",
            llmProvider: "anthropic",
            visionProvider: "openai"
        )

        let yaml = try YAMLEncoder().encode(original)
        let decoded = try YAMLDecoder().decode(FrontmatterSchema.self, from: yaml)

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
        #expect(decoded.asrProvider == original.asrProvider)
        #expect(decoded.llmProvider == original.llmProvider)
        #expect(decoded.visionProvider == original.visionProvider)
        #expect(decoded.schemaVersion == 2)
    }

    // MARK: - Validation Compatibility

    @Test("Validation still passes with nil *_provider fields")
    func validationPassesWithNilProviderFields() throws {
        let schema = FrontmatterSchema(
            schemaVersion: 2,
            course: "PHYS101",
            courseName: "Physics I",
            term: "Fall 2026",
            datetime: Date(),
            durationSeconds: 3600,
            source: "MacBook Air",
            audioFile: "physics_lecture.mp3",
            tags: ["physics", "mechanics"],
            asrProvider: nil,
            llmProvider: nil,
            visionProvider: nil
        )

        // Validation should pass - optional provider fields don't affect required field validation
        try schema.validate()
    }
}
