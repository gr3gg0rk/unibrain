import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - CreateCourseForm

/// Inline form for creating a new course (code + name fields).
///
/// Per UI-SPEC Variant C: Two TextFields + Discard + Create + Route buttons.
/// Per Pitfall 2: Renders inline within the popover overlay — NOT a .sheet.
/// Per MP-03: Code sanitized via FolderNameSanitizer on save.
struct CreateCourseForm: View {
    let viewModel: MenuBarViewModel

    @State private var courseCode: String = ""
    @State private var courseName: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Create New Course")
                .font(.headline)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Course Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., CS101", text: $courseCode)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Course Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., Intro to CS", text: $courseName)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 12) {
                Button("Discard New Course") {
                    courseCode = ""
                    courseName = ""
                }
                .buttonStyle(.bordered)

                Button("Create + Route") {
                    let sanitized = FolderNameSanitizer.sanitize(folderName: courseCode)
                    let name = courseName.isEmpty ? sanitized : courseName
                    Task {
                        await viewModel.selectCourse(.newCourse(code: sanitized, name: name))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(courseCode.isEmpty)
            }
        }
        .padding(24)
    }
}
