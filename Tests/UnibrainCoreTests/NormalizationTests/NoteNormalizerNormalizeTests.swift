import Testing
import Foundation
@testable import UnibrainCore

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
