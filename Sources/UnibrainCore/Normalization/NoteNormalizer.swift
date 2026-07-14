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
}
