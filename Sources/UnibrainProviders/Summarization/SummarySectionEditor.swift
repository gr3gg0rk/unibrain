import Foundation

/// Appends or replaces the `## Summary` section in a Markdown lecture note.
///
/// Per OLL-04: summaries are wrapped in HTML comment markers
/// `<!-- unibrain:summary-start -->` / `<!-- unibrain:summary-end -->` so
/// Regenerate Summary can replace only the marked section without touching
/// the transcript above.
public enum SummarySectionEditor {
    /// Opening marker for the summary block.
    public static let startMarker = "<!-- unibrain:summary-start -->"
    /// Closing marker for the summary block.
    public static let endMarker = "<!-- unibrain:summary-end -->"

    /// Appends a new `## Summary` section at the end of `note`, unless the
    /// section already exists (idempotent — returns the note unchanged).
    ///
    /// - Parameters:
    ///   - note: Original lecture note (transcript + frontmatter).
    ///   - summary: Summary body to insert between the markers.
    /// - Returns: Note with `## Summary` appended, or the original note if
    ///   the section already exists.
    public static func appendSummary(note: String, summary: String) -> String {
        // Idempotency: do not append twice.
        if note.contains(endMarker) || note.contains(startMarker) {
            return note
        }
        let block = "\n\n## Summary\n\n\(startMarker)\n\(summary)\n\(endMarker)"
        return note + block
    }

    /// Replaces the summary content between the HTML markers, preserving the
    /// surrounding transcript and frontmatter.
    ///
    /// If the markers are missing, returns the note unchanged (no-op).
    ///
    /// - Parameters:
    ///   - note: Note whose summary block should be replaced.
    ///   - newSummary: New summary body to insert between the markers.
    /// - Returns: Note with the summary block updated, or the original note
    ///   if no markers were found.
    public static func replaceSummary(note: String, newSummary: String) -> String {
        guard
            let startRange = note.range(of: startMarker),
            let endRange = note.range(of: endMarker)
        else {
            return note
        }
        // Build the new block: startMarker + new content + endMarker
        let replacement = "\(startMarker)\n\(newSummary)\n\(endMarker)"
        // Replace from start of startMarker to end of endMarker
        let combined = startRange.lowerBound..<endRange.upperBound
        var result = note
        result.replaceSubrange(combined, with: replacement)
        return result
    }
}
