import SwiftUI
import UnibrainCore

// MARK: - ManageCoursesView

/// Editable mapping table for course management.
///
/// Per UI-SPEC Surface 2: Shows mapping table with add/delete/edit.
/// Per M-04: Minimal in-app Manage Courses surface (~50-100 lines).
/// Per Pitfall 2: Renders inline within the 280pt popover — NOT a .sheet.
struct ManageCoursesView: View {
    let viewModel: MenuBarViewModel

    @State private var mappings: [String: CourseMapping] = [:]
    @State private var showingAddForm: Bool = false
    @State private var newEventTitle: String = ""
    @State private var newCourseCode: String = ""
    @State private var newCourseName: String = ""
    @State private var deletingKey: String?

    var body: some View {
        VStack(spacing: 12) {
            Text("Manage Courses")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Current term display
            if !viewModel.currentTermLabel.isEmpty {
                VStack(spacing: 2) {
                    Text("Current Term: \(viewModel.currentTermLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Mapping table
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(mappings.keys.sorted()), id: \.self) { eventTitle in
                        if let mapping = mappings[eventTitle] {
                            mappingRow(eventTitle: eventTitle, mapping: mapping)
                        }
                    }
                }
            }

            // Add mapping form (inline)
            if showingAddForm {
                VStack(spacing: 8) {
                    TextField("Event Title", text: $newEventTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Course Code", text: $newCourseCode)
                        .textFieldStyle(.roundedBorder)
                    TextField("Course Name", text: $newCourseName)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Cancel") {
                            showingAddForm = false
                            newEventTitle = ""
                            newCourseCode = ""
                            newCourseName = ""
                        }
                        .buttonStyle(.bordered)

                        Button("Add") {
                            addMapping()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newEventTitle.isEmpty || newCourseCode.isEmpty)
                    }
                }
            } else {
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Course Mapping", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                viewModel.overlayState = .none
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .task {
            await loadMappings()
        }
        .alert("Delete mapping?", isPresented: Binding(
            get: { deletingKey != nil },
            set: { if !$0 { deletingKey = nil } }
        )) {
            Button("Keep Mapping", role: .cancel) {
                deletingKey = nil
            }
            Button("Delete", role: .destructive) {
                if let key = deletingKey {
                    deleteMapping(key)
                }
                deletingKey = nil
            }
        } message: {
            if let key = deletingKey {
                Text("Delete mapping for '\(key)'? Recordings with this event title will auto-create a new folder next time.")
            }
        }
    }

    // MARK: - Mapping Row

    @ViewBuilder
    private func mappingRow(eventTitle: String, mapping: CourseMapping) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(eventTitle)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(mapping.courseCode) \u{00b7} \(mapping.courseName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deletingKey = eventTitle
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(eventTitle), \(mapping.courseCode)")
    }

    // MARK: - Actions

    private func loadMappings() async {
        mappings = await viewModel.loadAllMappings()
    }

    private func addMapping() {
        let title = newEventTitle
        let code = newCourseCode
        let name = newCourseName.isEmpty ? newCourseCode : newCourseName
        let mapping = CourseMapping(courseCode: code, courseName: name)
        mappings[title] = mapping
        showingAddForm = false
        newEventTitle = ""
        newCourseCode = ""
        newCourseName = ""
        Task {
            await viewModel.addMapping(eventTitle: title, code: code, name: name)
        }
    }

    private func deleteMapping(_ key: String) {
        mappings.removeValue(forKey: key)
        Task {
            await viewModel.deleteMapping(eventTitle: key)
        }
    }
}
