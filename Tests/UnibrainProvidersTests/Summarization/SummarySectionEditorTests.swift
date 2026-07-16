import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

@Suite
enum SummarySectionEditorTests {

    @Test("appendSummary adds ## Summary section with HTML markers at end")
    static func appendSummaryAddsSection() {
        let note = "# Lecture Notes\n\nTranscript text."
        let summary = "- Concept A\n- Concept B"
        let result = SummarySectionEditor.appendSummary(note: note, summary: summary)

        #expect(result.contains("## Summary"))
        #expect(result.contains("<!-- unibrain:summary-start -->"))
        #expect(result.contains("<!-- unibrain:summary-end -->"))
        #expect(result.contains("- Concept A"))
        // Markers wrap the summary body
        #expect(result.contains("<!-- unibrain:summary-start -->\n- Concept A\n- Concept B\n<!-- unibrain:summary-end -->"))
    }

    @Test("appendSummary is idempotent when marker already exists")
    static func appendSummaryIsIdempotent() {
        let note = "# Lecture\n\nTranscript.\n\n## Summary\n\n<!-- unibrain:summary-start -->\nold\n<!-- unibrain:summary-end -->"
        let result = SummarySectionEditor.appendSummary(note: note, summary: "new")
        // Should NOT append a second ## Summary section
        #expect(result.components(separatedBy: "## Summary").count - 1 == 1)
        // Original content preserved
        #expect(result.contains("old"))
        #expect(!result.contains("new"))
    }

    @Test("replaceSummary swaps content between markers, preserves the rest")
    static func replaceSummarySwapsContent() {
        let note = """
        # Lecture

        Body transcript text.

        ## Summary

        <!-- unibrain:summary-start -->
        - Old bullet
        <!-- unibrain:summary-end -->
        """
        let result = SummarySectionEditor.replaceSummary(note: note, newSummary: "- Fresh bullet")
        #expect(result.contains("# Lecture"))
        #expect(result.contains("Body transcript text."))
        #expect(result.contains("## Summary"))
        #expect(result.contains("- Fresh bullet"))
        #expect(!result.contains("- Old bullet"))
        // Markers preserved
        #expect(result.contains("<!-- unibrain:summary-start -->"))
        #expect(result.contains("<!-- unibrain:summary-end -->"))
    }

    @Test("replaceSummary is a no-op when markers absent")
    static func replaceSummaryNoMarkers() {
        let note = "# Just a lecture\n\nNo markers here."
        let result = SummarySectionEditor.replaceSummary(note: note, newSummary: "fresh")
        #expect(result == note)
    }
}

@Suite
enum SummaryPromptBuilderTests {

    @Test("SummaryPromptBuilder interpolates course + transcript into template")
    static func builderInterpolatesValues() async throws {
        let template = """
        Course: {course_name}
        Professor: {professor_name}
        Date: {lecture_date}
        Transcript: {transcript_text}
        """
        let builder = SummaryPromptBuilder(template: template)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let context = CourseContext(courseName: "CS101", professorName: "Dr. Turing", lectureDate: date)
        let prompt = try await builder.build(transcript: "Today we cover sorting.", courseContext: context)

        #expect(prompt.contains("Course: CS101"))
        #expect(prompt.contains("Professor: Dr. Turing"))
        #expect(prompt.contains("Today we cover sorting."))
        #expect(!prompt.contains("{course_name}"))
        #expect(!prompt.contains("{transcript_text}"))
    }

    @Test("SummaryPromptBuilder uses 'Unknown' for missing professor")
    static func builderDefaultsProfessor() async throws {
        let template = "Professor: {professor_name}"
        let builder = SummaryPromptBuilder(template: template)
        let context = CourseContext(courseName: "CS101", professorName: nil, lectureDate: Date())
        let prompt = try await builder.build(transcript: "x", courseContext: context)
        #expect(prompt.contains("Professor: Unknown"))
    }
}
