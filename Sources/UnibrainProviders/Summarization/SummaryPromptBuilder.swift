import Foundation

/// Course metadata interpolated into the summary prompt template.
public struct CourseContext: Sendable {
    public let courseName: String
    public let professorName: String?
    public let lectureDate: Date

    public init(courseName: String, professorName: String?, lectureDate: Date) {
        self.courseName = courseName
        self.professorName = professorName
        self.lectureDate = lectureDate
    }
}

/// Loads the summary prompt template and interpolates course + transcript.
///
/// Per SUMM-04: the system prompt is locked in `summary-default.md`.
/// Placeholders `{course_name}`, `{professor_name}`, `{lecture_date}`,
/// `{transcript_text}` are substituted before sending to the LLM.
public struct SummaryPromptBuilder: Sendable {
    private let template: String

    /// Initialize with an explicit template (used by tests).
    public init(template: String) {
        self.template = template
    }

    /// Initialize by loading `summary-default.md` from `bundle`.
    public init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "summary-default", withExtension: "md") else {
            throw PromptError.templateNotFound("summary-default.md not found in bundle")
        }
        self.template = try String(contentsOf: url, encoding: .utf8)
    }

    /// Builds the user-turn prompt by interpolating `courseContext` and
    /// `transcript` into the template placeholders.
    public func build(transcript: String, courseContext: CourseContext) async throws -> String {
        let formatter = ISO8601DateFormatter()
        let professor = courseContext.professorName ?? "Unknown"
        return template
            .replacingOccurrences(of: "{course_name}", with: courseContext.courseName)
            .replacingOccurrences(of: "{professor_name}", with: professor)
            .replacingOccurrences(of: "{lecture_date}", with: formatter.string(from: courseContext.lectureDate))
            .replacingOccurrences(of: "{transcript_text}", with: transcript)
    }
}

extension SummaryPromptBuilder {
    public enum PromptError: Error, Sendable {
        case templateNotFound(String)
    }
}
