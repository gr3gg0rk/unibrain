import SwiftUI

// MARK: - TermEditorForm

/// Term label + start/end date editor.
///
/// Per UI-SPEC Surface 4: Inline overlay for setting current term.
/// Per CT-01: Updates label, start date, and end date.
struct TermEditorForm: View {
    let viewModel: MenuBarViewModel

    @State private var label: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(120 * 24 * 3600)

    var body: some View {
        VStack(spacing: 16) {
            Text("Set Current Term")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Term Label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., Fall 2026", text: $label)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("End Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }

            Button {
                Task {
                    await viewModel.setTerm(label: label, startDate: startDate, endDate: endDate)
                    viewModel.overlayState = .none
                }
            } label: {
                Text("Set Current Term")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(label.isEmpty)
        }
        .padding(24)
        .onAppear {
            label = viewModel.currentTermLabel
        }
    }
}
