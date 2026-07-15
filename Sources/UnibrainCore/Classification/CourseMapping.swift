import Foundation

/// Term date range for course classification filtering (CT-01).
///
/// Per CT-01: Single term + date range stored in `.unibrain/courses.json`.
/// The wide default (distantPast...distantFuture) ensures recordings are never
/// accidentally filtered before the user sets a real term.
public struct TermDefinition: Codable, Sendable {
    /// Human-readable label (e.g., "Fall 2026").
    public var label: String
    /// Term start date (inclusive).
    public var startDate: Date
    /// Term end date (inclusive).
    public var endDate: Date

    public init(label: String, startDate: Date, endDate: Date) {
        self.label = label
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// Maps an event title to a course code and name (CLAS-02).
///
/// Per M-01: Stored in `.unibrain/courses.json` keyed by calendar event title.
/// Per M-02: Auto-learned on first encounter (empty default, grows over time).
public struct CourseMapping: Codable, Sendable {
    /// Course code (e.g., "CS101").
    public var courseCode: String
    /// Human-readable course name (e.g., "Intro to Computer Science").
    public var courseName: String

    public init(courseCode: String, courseName: String) {
        self.courseCode = courseCode
        self.courseName = courseName
    }
}

/// Versioned JSON document for course mapping persistence (CLAS-02, CT-01).
///
/// Per M-01: Lives at `{vault}/.unibrain/courses.json`.
/// Per CT-01: `currentTerm` and `recentCourseCodes` share the same file
/// as the mapping table (single source of truth).
///
/// Uses snake_case CodingKeys for JSON interop across iCloud-synced devices.
/// All properties are `var` so the store can mutate in place on load/save.
public struct CourseMappingDocument: Codable, Sendable {
    /// Schema version for forward compatibility (currently 1).
    public var schemaVersion: Int
    /// Current academic term for date-range filtering.
    public var currentTerm: TermDefinition
    /// Event title → course mapping dictionary.
    public var mappings: [String: CourseMapping]
    /// Most-recently-used course codes (max 5, MRU ordering).
    public var recentCourseCodes: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case currentTerm = "current_term"
        case mappings
        case recentCourseCodes = "recent_course_codes"
    }

    /// Factory for the default empty document.
    ///
    /// Per M-02: Auto-learn on encounter — starts empty.
    /// Per CT-01: Default term has empty label and wide date range so
    /// recordings are never filtered out before the user configures a real term.
    public static let empty = CourseMappingDocument(
        schemaVersion: 1,
        currentTerm: TermDefinition(
            label: "",
            startDate: .distantPast,
            endDate: .distantFuture
        ),
        mappings: [:],
        recentCourseCodes: []
    )

    public init(
        schemaVersion: Int,
        currentTerm: TermDefinition,
        mappings: [String: CourseMapping],
        recentCourseCodes: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.currentTerm = currentTerm
        self.mappings = mappings
        self.recentCourseCodes = recentCourseCodes
    }
}
