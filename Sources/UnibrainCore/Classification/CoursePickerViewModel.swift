import Foundation

/// Determines which variant of the manual picker UI is shown.
///
/// Per CLAS-04: The picker fires when `CourseClassifier.match` returns
/// `.multiple` or `.none`.
///
/// Per UI-SPEC Surface 1:
/// - Variant A (`.multiple`): shows matched events at top + course list
/// - Variant B (`.none`): shows course list only
public enum CoursePickerMode: Sendable, Equatable {
    /// Zero events matched — show course list only (UI-SPEC Variant B).
    case none
    /// Two or more events matched — show events + course list (UI-SPEC Variant A).
    case multiple([CalendarEvent])
}

/// The user's selection from the manual course picker.
///
/// Per M-03: The orchestrator consumes this result to update both the
/// mapping table (`CourseMappingStore.upsert`) and the recent list
/// (`CourseMappingStore.addRecent`).
public enum CourseSelection: Sendable, Equatable {
    /// User picked an existing course code from the list.
    case course(String)
    /// User picked a specific calendar event from the multi-match list (MP-05).
    case event(CalendarEvent)
    /// User created a new course via the Create New form (MP-03).
    case newCourse(code: String, name: String)
    /// User chose Skip — routing to `_unsorted/` (MP-03).
    case skip
}

/// Lightweight summary of a course for picker display.
///
/// `Identifiable` enables SwiftUI `ForEach` / `List` usage without
/// additional wrapping.
public struct CourseSummary: Sendable, Equatable, Identifiable {
    /// Course code (e.g., "CS101").
    public let code: String
    /// Human-readable course name (e.g., "Intro to Computer Science").
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    public var id: String { code }
}

/// Pure-logic view model for the manual course picker.
///
/// Per ONBD-02/ONBD-03: This class is plain (NOT `@Observable`) so it stays
/// fully Linux-testable. The UnibrainApp UI layer wraps it with a SwiftUI
/// adapter or uses it directly with manual binding.
///
/// Per MP-02: `recentCourses` returns at most 5 items, ordered by
/// `recentCodes`, filtered to courses present in the current term.
///
/// Per MP-03: All four selection paths produce a `CourseSelection` variant
/// the orchestrator can resume with.
public class CoursePickerViewModel {

    /// Picker mode — controls which UI variant the consumer renders.
    public private(set) var mode: CoursePickerMode
    /// All courses available in the current term (CT-01).
    public private(set) var allCourses: [CourseSummary]
    /// Recently-used course codes (MRU order, max 5 consumed).
    public private(set) var recentCodes: [String]
    /// The user's selection, or `nil` until they pick.
    public private(set) var selection: CourseSelection?
    /// Search query — bound directly to a UI `TextField`.
    public var searchQuery: String = ""

    /// Creates a view model for the given mode and course list.
    ///
    /// - Parameters:
    ///   - mode: Picker variant (`.none` or `.multiple`).
    ///   - courses: All courses available in the current term.
    ///   - recentCodes: MRU list of course codes (may exceed 5; consumed lazily).
    public init(
        mode: CoursePickerMode,
        courses: [CourseSummary],
        recentCodes: [String]
    ) {
        self.mode = mode
        self.allCourses = courses
        self.recentCodes = recentCodes
    }

    // MARK: - Computed views

    /// Up to 5 recent courses, ordered by `recentCodes`, filtered to
    /// courses present in `allCourses` (MP-02).
    ///
    /// Courses in `recentCodes` that are not in the current term's
    /// `allCourses` are silently dropped — stale recents shouldn't surface.
    public var recentCourses: [CourseSummary] {
        let courseByCode = Dictionary(uniqueKeysWithValues: allCourses.map { ($0.code, $0) })
        return recentCodes.compactMap { courseByCode[$0] }.prefix(5).map { $0 }
    }

    /// Courses filtered by `searchQuery` (case-insensitive on code or name).
    ///
    /// When `searchQuery` is empty, returns `allCourses` unfiltered.
    public var filteredCourses: [CourseSummary] {
        guard !searchQuery.isEmpty else { return allCourses }
        let needle = searchQuery.lowercased()
        return allCourses.filter { course in
            course.code.lowercased().contains(needle)
                || course.name.lowercased().contains(needle)
        }
    }

    /// Events from `.multiple` mode, or `nil` when mode is `.none` (MP-05).
    public var matchingEvents: [CalendarEvent]? {
        switch mode {
        case .none:
            return nil
        case .multiple(let events):
            return events
        }
    }

    // MARK: - Selection actions

    /// User picked an existing course from the list (MP-03).
    public func select(course: CourseSummary) {
        selection = .course(course.code)
    }

    /// User picked a specific calendar event from the multi-match list (MP-05).
    public func selectEvent(_ event: CalendarEvent) {
        selection = .event(event)
    }

    /// User chose Skip — routing to `_unsorted/` (MP-03).
    public func skip() {
        selection = .skip
    }

    /// User created a new course via the Create New form (MP-03).
    public func createNew(code: String, name: String) {
        selection = .newCourse(code: code, name: name)
    }
}
