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

    /// Injects or updates summary audit fields in the note's YAML frontmatter.
    ///
    /// Per CLOUD-13 / CON-04: after a summary is generated, the frontmatter
    /// must record `summary_model` and `llm_provider` so the audit trail
    /// (AuditTrailStore) can classify the note correctly.
    ///
    /// If the fields already exist, their values are replaced. If not, they
    /// are inserted before the closing `---`.
    ///
    /// - Parameters:
    ///   - note: Lecture note with YAML frontmatter.
    ///   - summaryModel: Model name (e.g., "llama-3.2:3b").
    ///   - llmProvider: Provider name (e.g., "ollama").
    /// - Returns: Note with updated frontmatter. If no frontmatter block
    ///   exists, the original note is returned unchanged.
    public static func injectAuditFields(
        note: String,
        summaryModel: String,
        llmProvider: String
    ) -> String {
        guard note.hasPrefix("---") else { return note }
        let lines = note.components(separatedBy: "\n")
        guard lines.count >= 2 else { return note }

        var closingLineIndex: Int?
        for i in 1..<lines.count {
            if lines[i].hasPrefix("---") {
                closingLineIndex = i
                break
            }
        }
        guard let closeIdx = closingLineIndex else { return note }

        var updatedLines = lines
        var summaryModelSet = false
        var llmProviderSet = false

        for i in 1..<closeIdx {
            if updatedLines[i].hasPrefix("summary_model:") {
                updatedLines[i] = "summary_model: \(summaryModel)"
                summaryModelSet = true
            } else if updatedLines[i].hasPrefix("llm_provider:") {
                updatedLines[i] = "llm_provider: \(llmProvider)"
                llmProviderSet = true
            }
        }

        var insertIndex = closeIdx
        if !summaryModelSet {
            updatedLines.insert("summary_model: \(summaryModel)", at: insertIndex)
            insertIndex += 1
        }
        if !llmProviderSet {
            updatedLines.insert("llm_provider: \(llmProvider)", at: insertIndex)
        }

        return updatedLines.joined(separator: "\n")
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
