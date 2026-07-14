import Testing
import Foundation
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
}
