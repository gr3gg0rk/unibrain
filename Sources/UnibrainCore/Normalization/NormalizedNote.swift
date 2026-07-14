import Foundation

/// Carries the complete note content ready for NoteWriter to serialize and write to the vault.
///
/// Per N-01: The note body follows the standard shape:
/// H1 title + inline audio wiki-link near the top + ## Transcript section
/// containing grouped paragraphs. The ## Summary section is added in Phase 6
/// only when summaryModel is non-nil.
///
/// Per A-02: NoteWriter.write(_:to:) consumes this value type. NoteNormalizer
/// produces it. Single producer, single consumer.
public struct NormalizedNote: Sendable {
    /// The H1 title line (e.g., "# 2026-09-15 — CS101 Lecture").
    public var title: String
    /// The full Markdown body including audio wiki-link, transcript sections.
    public var body: String
    /// Structured frontmatter with all WRITE-02 fields for YAML encoding.
    public var frontmatter: FrontmatterSchema

    public init(title: String, body: String, frontmatter: FrontmatterSchema) {
        self.title = title
        self.body = body
        self.frontmatter = frontmatter
    }
}
