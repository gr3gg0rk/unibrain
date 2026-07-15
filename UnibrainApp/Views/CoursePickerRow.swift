import SwiftUI
import UnibrainCore

// MARK: - CoursePickerRow

/// Single row showing course title and code in the course picker.
///
/// Per UI-SPEC: `.subheadline` for course title (primary),
/// `.caption` for course code (secondary).
/// Accessibility label combines name + code for VoiceOver.
struct CoursePickerRow: View {
    let summary: CourseSummary

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(summary.code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.name), \(summary.code)")
        .accessibilityHint("Selects this course for the current recording")
    }
}
