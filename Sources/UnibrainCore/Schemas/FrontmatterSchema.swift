import Foundation
import Yams

/// Codable schema for Obsidian Markdown YAML frontmatter.
///
/// Per FOUND-05: every lecture note written to the vault carries
/// structured frontmatter with these fields. The schema is encoded
/// to YAML via Yams and prepended to the note content.
///
/// Per WRITE-02: field set matches the Obsidian frontmatter contract.
/// CodingKeys map Swift camelCase to snake_case YAML keys.
public struct FrontmatterSchema: Codable, Sendable {
    /// Schema version for forward compatibility.
    public var schemaVersion: Int
    /// Course code (e.g., "CS101").
    public var course: String
    /// Human-readable course name (e.g., "Intro to Computer Science").
    public var courseName: String
    /// Academic term (e.g., "Fall 2026").
    public var term: String
    /// Recording date and time.
    public var datetime: Date
    /// Recording duration in seconds.
    public var durationSeconds: Int
    /// Source of the recording (e.g., "MacBook Air", "iPhone").
    public var source: String
    /// Audio filename relative to the note.
    public var audioFile: String
    /// Topic tags for the note.
    public var tags: [String]
    /// Optional syllabus link.
    public var syllabusLink: String?
    /// Optional vector embedding ID for semantic search.
    public var vectorId: String?
    /// Optional model name used for the summary.
    public var summaryModel: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case course
        case courseName = "course_name"
        case term
        case datetime
        case durationSeconds = "duration_seconds"
        case source
        case audioFile = "audio_file"
        case tags
        case syllabusLink = "syllabus_link"
        case vectorId = "vector_id"
        case summaryModel = "summary_model"
    }

    public init(
        schemaVersion: Int,
        course: String,
        courseName: String,
        term: String,
        datetime: Date,
        durationSeconds: Int,
        source: String,
        audioFile: String,
        tags: [String],
        syllabusLink: String? = nil,
        vectorId: String? = nil,
        summaryModel: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.course = course
        self.courseName = courseName
        self.term = term
        self.datetime = datetime
        self.durationSeconds = durationSeconds
        self.source = source
        self.audioFile = audioFile
        self.tags = tags
        self.syllabusLink = syllabusLink
        self.vectorId = vectorId
        self.summaryModel = summaryModel
    }

    /// Validates the frontmatter schema for required fields and data consistency.
    ///
    /// Per WRITE-02: all required fields must be non-empty before emitting a note.
    /// Per T-2-03 (mitigate): prevents null/empty frontmatter from reaching the vault.
    ///
    /// - Throws: ``FrontmatterValidationError`` if validation fails:
    ///   - `.emptyField` for empty required string fields
    ///   - `.invalidDuration` for non-positive duration_seconds
    ///   - `.missingRequiredField` for empty tags array
    public func validate() throws {
        guard !course.isEmpty else {
            throw FrontmatterValidationError.emptyField("course")
        }
        guard !courseName.isEmpty else {
            throw FrontmatterValidationError.emptyField("course_name")
        }
        guard !term.isEmpty else {
            throw FrontmatterValidationError.emptyField("term")
        }
        guard durationSeconds > 0 else {
            throw FrontmatterValidationError.invalidDuration(durationSeconds)
        }
        guard !tags.isEmpty else {
            throw FrontmatterValidationError.missingRequiredField("tags")
        }
    }
}
