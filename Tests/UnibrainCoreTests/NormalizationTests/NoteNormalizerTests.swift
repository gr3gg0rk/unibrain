import Testing
import Foundation
@testable import UnibrainCore

/// Comprehensive tests for NoteNormalizer covering paragraph grouping (N-03/N-04),
/// H1 title format (N-02), audio wiki-link emission (WRITE-03), transcript
/// section heading (N-01), frontmatter completeness (WRITE-02), validation
/// integration, no-summary-section (N-01), and course sanitization.
///
/// Per Pattern 13: Uses @Suite/@Test/#expect pattern from FrontmatterSchemaTests.
/// Per 02-VALIDATION.md: All tests run on WSL2 Linux without Apple frameworks.

// MARK: - Paragraph Grouping Tests (N-03, N-04)

@Suite("NoteNormalizer Paragraph Grouping")
struct NoteNormalizerGroupParagraphsTests {

    @Test("groupParagraphs with empty segments returns empty array")
    func emptySegmentsReturnsEmpty() throws {
        let result = NoteNormalizer.groupParagraphs(segments: [])
        #expect(result.isEmpty)
    }

    @Test("groupParagraphs with single segment returns single paragraph")
    func singleSegmentReturnsSingleParagraph() throws {
        let segments = [(start: 0.0, end: 5.0, text: "Hello world")]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0] == ["Hello world"])
    }

    @Test("groupParagraphs groups segments within 3-second gap into same paragraph")
    func groupsWithinThreshold() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "First segment"),
            (start: 6.0, end: 10.0, text: "Second segment"),
            (start: 11.0, end: 15.0, text: "Third segment"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0].count == 3)
        #expect(result[0][0] == "First segment")
        #expect(result[0][1] == "Second segment")
        #expect(result[0][2] == "Third segment")
    }

    @Test("groupParagraphs starts new paragraph when gap >= 3 seconds")
    func startsNewParagraphOnLargeGap() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "First paragraph"),
            (start: 10.0, end: 15.0, text: "Gap too large"),  // gap = 5.0s >= 3.0
            (start: 16.0, end: 20.0, text: "Second paragraph continues"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 2)
        #expect(result[0] == ["First paragraph"])
        #expect(result[1] == ["Gap too large", "Second paragraph continues"])
    }

    @Test("groupParagraphs handles consecutive segments with zero gap")
    func handlesZeroGap() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "Zero gap one"),
            (start: 5.0, end: 10.0, text: "Zero gap two"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0].count == 2)
    }

    @Test("groupParagraphs filters segments with empty/whitespace-only text")
    func filtersEmptySegments() throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "Real content"),
            (start: 5.5, end: 6.0, text: ""),
            (start: 6.5, end: 7.0, text: "   "),
            (start: 7.0, end: 9.0, text: "More content"),
        ]
        let result = NoteNormalizer.groupParagraphs(segments: segments)
        #expect(result.count == 1)
        #expect(result[0].count == 2)
        #expect(result[0][0] == "Real content")
        #expect(result[0][1] == "More content")
    }
}

// MARK: - Normalize Tests (N-01, N-02, WRITE-02, WRITE-03)

@Suite("NoteNormalizer Normalize")
struct NoteNormalizerNormalizeTests {

    // MARK: - Test Helpers

    /// Creates a realistic fake calendar event for testing.
    private func makeCourse(
        title: String = "Intro to Computer Science",
        startOffset: TimeInterval = 0
    ) -> CalendarEvent {
        CalendarEvent(
            id: UUID().uuidString,
            title: title,
            startDate: Date(timeIntervalSince1970: 1_700_000_000 + startOffset),
            endDate: Date(timeIntervalSince1970: 1_700_000_000 + startOffset + 5400),
            location: "Room 101"
        )
    }

    /// Creates realistic fake transcript segments.
    private func makeTranscript() -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        [
            (start: 0.0, end: 5.0, text: "Welcome to today's lecture."),
            (start: 6.0, end: 12.0, text: "We'll cover the basics."),
            (start: 20.0, end: 25.0, text: "Now let's dive deeper."),  // 8s gap → new paragraph
        ]
    }

    // MARK: - H1 Title Format Tests (N-02)

    @Test("normalize() emits H1 title in YYYY-MM-DD — {course} Lecture format")
    func emitsH1TitleInCorrectFormat() throws {
        let course = makeCourse(title: "Intro to Computer Science")
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        // Per N-02: H1 title format = YYYY-MM-DD — {course_code} Lecture
        // The course field uses FolderNameSanitizer.sanitize(course.title)
        // Timestamp 1_700_000_000 = 2023-11-14 in UTC
        let sanitized = FolderNameSanitizer.sanitize(folderName: course.title)
        #expect(note.title == "# 2023-11-14 — \(sanitized) Lecture")
        #expect(note.title.hasPrefix("# 2023-11-14 — "))
        #expect(note.title.hasSuffix(" Lecture"))
    }

    // MARK: - Audio Wiki-Link Tests (N-01, WRITE-03)

    @Test("normalize() emits audio wiki-link near top of body")
    func emitsAudioWikiLink() throws {
        let course = makeCourse()
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture-2026-09-14.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        // Per N-01 and WRITE-03: audio wiki-link ![[filename]] near top of body
        #expect(note.body.contains("![[lecture-2026-09-14.m4a]]"))
    }

    @Test("normalize() emits wiki-link before transcript section")
    func wikiLinkBeforeTranscript() throws {
        let course = makeCourse()
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        let wikiLinkRange = note.body.range(of: "![[lecture.m4a]]")
        let transcriptRange = note.body.range(of: "## Transcript")
        #expect(wikiLinkRange != nil)
        #expect(transcriptRange != nil)
        #expect(wikiLinkRange!.lowerBound < transcriptRange!.lowerBound)
    }

    // MARK: - Transcript Section Tests (N-01)

    @Test("normalize() emits ## Transcript section heading")
    func emitsTranscriptHeading() throws {
        let course = makeCourse()
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        #expect(note.body.contains("## Transcript"))
    }

    @Test("normalize() groups paragraphs into transcript body")
    func groupsParagraphsInBody() throws {
        let course = makeCourse()
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        // The transcript has a gap of 8s between segments 2 and 3,
        // so should produce 2 paragraphs separated by \n\n
        let transcriptRange = note.body.range(of: "## Transcript\n\n")
        #expect(transcriptRange != nil)

        let bodyAfterHeading = String(note.body[transcriptRange!.upperBound...])
        let paragraphs = bodyAfterHeading.components(separatedBy: "\n\n")
        #expect(paragraphs.count >= 2)
    }

    // MARK: - Frontmatter Completeness Tests (WRITE-02)

    @Test("normalize() creates FrontmatterSchema with all 12 WRITE-02 fields")
    func createsCompleteFrontmatter() throws {
        let course = makeCourse(title: "Intro to CS")
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        let fm = note.frontmatter
        #expect(fm.schemaVersion == 1)
        #expect(!fm.course.isEmpty)
        #expect(!fm.courseName.isEmpty)
        #expect(!fm.term.isEmpty)
        #expect(fm.datetime == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(fm.durationSeconds == 5400)
        #expect(!fm.source.isEmpty)
        #expect(fm.audioFile == "lecture.m4a")
        #expect(!fm.tags.isEmpty)
        // Optional fields are nil by default in Phase 2
        #expect(fm.syllabusLink == nil)
        #expect(fm.vectorId == nil)
        #expect(fm.summaryModel == nil)
    }

    @Test("normalize() calls frontmatter.validate() before returning")
    func callsValidateBeforeReturning() throws {
        let course = makeCourse()
        // Valid inputs should not throw
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        // If validate() was called and passed, frontmatter is valid
        #expect(throws: Never.self) {
            try note.frontmatter.validate()
        }
    }

    // MARK: - No Summary Section Test (N-01)

    @Test("normalize() does NOT emit ## Summary section")
    func doesNotEmitSummarySection() throws {
        let course = makeCourse()
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        // Per N-01: ## Summary section is added in Phase 6 only when
        // summaryModel is non-nil — NOT emitted as placeholder in Phase 2
        #expect(!note.body.contains("## Summary"))
    }

    // MARK: - Course Sanitization Test

    @Test("normalize() sanitizes course field using FolderNameSanitizer")
    func sanitizesCourseField() throws {
        let course = makeCourse(title: "CS/101: Intro")
        let note = NoteNormalizer.normalize(
            transcript: makeTranscript(),
            course: course,
            audioFile: "lecture.m4a",
            recordingStart: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5400
        )

        // course field should be sanitized version of course.title
        let expected = FolderNameSanitizer.sanitize(folderName: "CS/101: Intro")
        #expect(note.frontmatter.course == expected)
        // courseName should be the raw title
        #expect(note.frontmatter.courseName == "CS/101: Intro")
    }
}
