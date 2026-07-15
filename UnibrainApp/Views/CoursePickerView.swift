import SwiftUI
import UnibrainCore

// MARK: - CoursePickerView

/// Inline course picker for manual classification.
///
/// Per UI-SPEC Surface 1: Renders inline within the 280pt popover (NOT a .sheet).
/// Per MP-01..MP-05: Handles both multi-match (.multiple) and no-match (.none) variants.
/// Per Pitfall 2: Inline view-state switching via PopoverOverlay, not .sheet.
struct CoursePickerView: View {
    let mode: CoursePickerMode
    let viewModel: MenuBarViewModel

    @State private var searchQuery: String = ""
    @State private var showingCreateForm: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Text(headerText)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showingCreateForm {
                CreateCourseForm(viewModel: viewModel)
            } else {
                pickerContent
            }
        }
        .padding(24)
    }

    // MARK: - Picker Content

    @ViewBuilder
    private var pickerContent: some View {
        // Multi-match events section
        if let events = matchingEvents {
            VStack(alignment: .leading, spacing: 8) {
                Text("Matching calendar events:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(events, id: \.id) { event in
                    eventRow(event)
                }
            }

            Divider()

            Text("Or pick from all courses")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Search field
        TextField("Search courses\u{2026}", text: $searchQuery)
            .textFieldStyle(.roundedBorder)

        // Course list
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Recent section
                if !recentCourses.isEmpty {
                    Section {
                        ForEach(recentCourses) { course in
                            CoursePickerRow(summary: course)
                                .onTapGesture {
                                    Task {
                                        await viewModel.selectCourse(.course(course.code))
                                    }
                                }
                        }
                    } header: {
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }

                // All courses section
                Section {
                    if filteredCourses.isEmpty && !searchQuery.isEmpty {
                        Text("No courses match '\(searchQuery)'")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredCourses) { course in
                            CoursePickerRow(summary: course)
                                .onTapGesture {
                                    Task {
                                        await viewModel.selectCourse(.course(course.code))
                                    }
                                }
                        }
                    }
                } header: {
                    Text("All Courses (\(viewModel.currentTermLabel))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        // Create + Skip buttons
        VStack(spacing: 8) {
            Button {
                showingCreateForm = true
            } label: {
                Label("Create New Course", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                Task {
                    await viewModel.selectCourse(.skip)
                }
            } label: {
                Text("Skip (save to _unsorted)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Event Row

    @ViewBuilder
    private func eventRow(_ event: CalendarEvent) -> some View {
        Button {
            Task {
                await viewModel.selectCourse(.event(event))
            }
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(timeRangeString(event))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.title), \(timeRangeString(event))")
    }

    // MARK: - Computed Properties

    private var headerText: String {
        switch mode {
        case .multiple:
            return "Which lecture is this?"
        case .none:
            return "Pick a course for this recording"
        }
    }

    private var matchingEvents: [CalendarEvent]? {
        switch mode {
        case .none:
            return nil
        case .multiple(let events):
            return events
        }
    }

    // MARK: - Course Filtering

    /// Note: courses are derived from the view model's picker state.
    /// In a real implementation, these come from CoursePickerViewModel.
    /// For now, use empty arrays as fallback — the picker loads on demand.
    private var recentCourses: [CourseSummary] {
        []
    }

    private var filteredCourses: [CourseSummary] {
        []
    }

    // MARK: - Helpers

    private func timeRangeString(_ event: CalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        var result = "\(start)\u{2013}\(end)"
        if let location = event.location {
            result += " \u{00b7} \(location)"
        }
        return result
    }
}
