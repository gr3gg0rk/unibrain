import Testing
import Foundation
@testable import UnibrainCore

@Suite("CoursePickerViewModel")
struct CoursePickerViewModelTests {

    // MARK: - Helpers

    private func makeCourses() -> [CourseSummary] {
        [
            CourseSummary(code: "CS101", name: "Intro to Computer Science"),
            CourseSummary(code: "MATH200", name: "Linear Algebra"),
            CourseSummary(code: "PHIL150", name: "Ethics and Society"),
            CourseSummary(code: "BIO110", name: "Cell Biology"),
            CourseSummary(code: "CHEM120", name: "General Chemistry"),
            CourseSummary(code: "CS202", name: "Data Structures"),
        ]
    }

    private func makeEvents() -> [CalendarEvent] {
        let now = Date()
        return [
            CalendarEvent(
                id: "evt-1",
                title: "CS101 Lecture",
                startDate: now,
                endDate: now.addingTimeInterval(3600),
                location: "Room A"
            ),
            CalendarEvent(
                id: "evt-2",
                title: "CS101 Lab",
                startDate: now.addingTimeInterval(7200),
                endDate: now.addingTimeInterval(10800),
                location: "Lab B"
            ),
        ]
    }

    // MARK: - filteredCourses

    @Test("filteredCourses returns all courses when searchQuery is empty")
    func filteredCoursesEmptySearch() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: ["CS101"]
        )
        #expect(vm.filteredCourses.count == 6)
        #expect(vm.filteredCourses == makeCourses())
    }

    @Test("filteredCourses filters by code case-insensitive")
    func filteredCoursesByCode() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: []
        )
        // "cs" matches CS101, CS202 (codes) AND PHIL150 ("Ethics" contains "cs")
        vm.searchQuery = "CS101"
        let codes = vm.filteredCourses.map(\.code)
        #expect(codes == ["CS101"])
    }

    @Test("filteredCourses filters by name case-insensitive")
    func filteredCoursesByName() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: []
        )
        vm.searchQuery = "biology"
        let codes = vm.filteredCourses.map(\.code)
        #expect(codes == ["BIO110"])
    }

    // MARK: - recentCourses

    @Test("recentCourses returns at most 5, ordered by recentCodes")
    func recentCoursesMaxFive() {
        let codes = ["CS101", "MATH200", "PHIL150", "BIO110", "CHEM120", "CS202"]
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: codes
        )
        // Max 5 even though recentCodes has 6
        #expect(vm.recentCourses.count == 5)
        // Ordered by recentCodes — first item is CS101
        #expect(vm.recentCourses.first?.code == "CS101")
        #expect(vm.recentCourses.last?.code == "CHEM120")
    }

    @Test("recentCourses excludes courses not in current term's course list")
    func recentCoursesExcludesMissing() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: ["CS101", "ARCH999", "MATH200"]
        )
        // ARCH999 not in courses — should be excluded
        let codes = vm.recentCourses.map(\.code)
        #expect(codes.count == 2)
        #expect(codes.contains("CS101"))
        #expect(codes.contains("MATH200"))
        #expect(!codes.contains("ARCH999"))
    }

    // MARK: - matchingEvents

    @Test("matchingEvents returns events from .multiple mode")
    func matchingEventsFromMultiple() {
        let events = makeEvents()
        let vm = CoursePickerViewModel(
            mode: .multiple(events),
            courses: makeCourses(),
            recentCodes: []
        )
        let matching = vm.matchingEvents
        #expect(matching != nil)
        #expect(matching?.count == 2)
        #expect(matching?[0].id == "evt-1")
        #expect(matching?[1].id == "evt-2")
    }

    @Test("matchingEvents returns nil for .none mode")
    func matchingEventsNone() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: []
        )
        #expect(vm.matchingEvents == nil)
    }

    // MARK: - Selection paths

    @Test("select(course:) produces .course(code)")
    func selectCourse() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: []
        )
        let course = CourseSummary(code: "CS101", name: "Intro to CS")
        vm.select(course: course)
        guard case .course(let code) = vm.selection else {
            Issue.record("Expected .course selection")
            return
        }
        #expect(code == "CS101")
    }

    @Test("selectEvent produces .event(CalendarEvent)")
    func selectEvent() {
        let events = makeEvents()
        let vm = CoursePickerViewModel(
            mode: .multiple(events),
            courses: makeCourses(),
            recentCodes: []
        )
        vm.selectEvent(events[1])
        guard case .event(let selected) = vm.selection else {
            Issue.record("Expected .event selection")
            return
        }
        #expect(selected.id == "evt-2")
    }

    @Test("skip() produces .skip")
    func skipSelection() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: []
        )
        vm.skip()
        guard case .skip = vm.selection else {
            Issue.record("Expected .skip selection")
            return
        }
        #expect(Bool(true))
    }

    @Test("createNew produces .newCourse(code, name)")
    func createNewSelection() {
        let vm = CoursePickerViewModel(
            mode: .none,
            courses: makeCourses(),
            recentCodes: []
        )
        vm.createNew(code: "ARCH999", name: "Introduction to Architecture")
        guard case .newCourse(let code, let name) = vm.selection else {
            Issue.record("Expected .newCourse selection")
            return
        }
        #expect(code == "ARCH999")
        #expect(name == "Introduction to Architecture")
    }
}
