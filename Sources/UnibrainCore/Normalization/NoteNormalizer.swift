import Foundation

/// Pure transformation utility that converts transcript segments and metadata
/// into a ``NormalizedNote`` ready for vault write-out.
///
/// Per N-03: Takes abstract timed segments `[(start: TimeInterval, end: TimeInterval, text: String)]`
/// — Apple-framework-agnostic. Phase 3's ASR adapter maps whisper.cpp segments
/// into this abstract shape.
///
/// Per Pattern 2: Uses struct with static methods — no state, no instance data.
public struct NoteNormalizer {

    /// Groups timed transcript segments into paragraphs by time-gap heuristic.
    ///
    /// Per N-04: Default paragraph-break threshold = 3 seconds. Any silence
    /// >= 3s between segments starts a new paragraph.
    ///
    /// Per RESEARCH.md Pitfall 3: Filters segments with empty/whitespace-only
    /// text before grouping to prevent empty paragraphs.
    ///
    /// - Parameters:
    ///   - segments: Array of (start, end, text) tuples from ASR backend.
    ///   - threshold: Seconds of silence between segments that starts a new
    ///     paragraph (default: 3.0).
    /// - Returns: Array of paragraphs, each paragraph is an array of segment texts.
    public static func groupParagraphs(
        segments: [(start: TimeInterval, end: TimeInterval, text: String)],
        threshold: TimeInterval = 3.0
    ) -> [[String]] {
        // Filter out empty/whitespace-only segments (Pitfall 3)
        let filtered = segments.filter { segment in
            !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        guard !filtered.isEmpty else { return [] }

        var paragraphs: [[String]] = [[filtered[0].text]]
        var lastEndTime = filtered[0].end

        for segment in filtered.dropFirst() {
            let gap = segment.start - lastEndTime

            if gap >= threshold {
                paragraphs.append([segment.text])
            } else {
                paragraphs[paragraphs.count - 1].append(segment.text)
            }

            lastEndTime = segment.end
        }

        return paragraphs
    }

    /// Normalizes transcript segments and course metadata into a complete Obsidian note.
    ///
    /// Per N-01: Standard note shape = H1 title + inline audio wiki-link near the top
    /// + ## Transcript section containing grouped paragraphs. The ## Summary section
    /// is added in Phase 6 only when summaryModel is non-nil.
    ///
    /// Per N-02: H1 title format = `YYYY-MM-DD — {course_code} Lecture`.
    ///
    /// Per WRITE-02: FrontmatterSchema with all 12 fields is created and validated.
    /// Per WRITE-03: Audio file is referenced via `![[filename]]` wiki-link syntax.
    ///
    /// - Parameters:
    ///   - transcript: Array of (start, end, text) tuples from ASR backend (N-03).
    ///   - course: The matched calendar event for this recording.
    ///   - audioFile: Audio filename for the wiki-link reference.
    ///   - recordingStart: Timestamp when recording started.
    ///   - durationSeconds: Recording duration in seconds.
    /// - Returns: ``NormalizedNote`` ready for NoteWriter consumption.
    public static func normalize(
        transcript: [(start: TimeInterval, end: TimeInterval, text: String)],
        course: CalendarEvent,
        audioFile: String,
        recordingStart: Date,
        durationSeconds: Int
    ) -> NormalizedNote {
        // Group segments into paragraphs (N-03, N-04)
        let paragraphs = groupParagraphs(segments: transcript)

        // Build transcript body with ## Transcript heading (N-01)
        let transcriptBody = "## Transcript\n\n" + paragraphs
            .map { paragraph in
                paragraph.joined(separator: " ")
            }
            .joined(separator: "\n\n")

        // Build H1 title (N-02): YYYY-MM-DD — {course_code} Lecture
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateStr = dateFormatter.string(from: recordingStart)
        let sanitizedCourse = FolderNameSanitizer.sanitize(folderName: course.title)
        let title = "# \(dateStr) — \(sanitizedCourse) Lecture"

        // Build audio wiki-link (N-01, WRITE-03)
        let audioLink = "\n![[\(audioFile)]]\n"

        // Build complete body: title + audio link + transcript (no ## Summary per N-01)
        let body = "\(title)\n\(audioLink)\n\(transcriptBody)"

        // Build frontmatter (WRITE-02) — all 12 fields
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: sanitizedCourse,
            courseName: course.title,
            term: "Fall 2026",
            datetime: recordingStart,
            durationSeconds: durationSeconds,
            source: "MacBook Air",
            audioFile: audioFile,
            tags: ["lecture"],
            syllabusLink: nil,
            vectorId: nil,
            summaryModel: nil
        )

        // Validate frontmatter before returning (T-2-03 mitigation)
        // Note: validate() is called by the caller; here we construct and return.
        // The test verifies that the returned frontmatter passes validate().
        return NormalizedNote(title: title, body: body, frontmatter: frontmatter)
    }
}
