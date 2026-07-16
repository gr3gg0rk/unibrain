import SwiftUI

/// Onboarding page 5 (macOS only): Current term input.
///
/// Per ONB-01 and CT-01: Collects term label + start/end dates.
/// Writes to CourseMappingStore on Continue via viewModel.saveTerm().
/// iOS skips this page — term inherited via courses.json.
///
/// Per RESEARCH.md A4: Guarded by `#if os(macOS)`.
#if os(macOS)
struct OnboardingTermPage: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Heading
            Text("Set Your Current Term")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 32)

            Spacer()

            // Icon
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 48))
                .foregroundStyle(.accentColor)

            // Explanation
            Text("unibrain organizes notes by term. Set your current term so recordings route to the right folder.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()

            // Term input form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Term Label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., Fall 2026", text: $viewModel.termLabel)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.termStartDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("End Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.termEndDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button("Continue") {
                Task {
                    await viewModel.saveTerm()
                    viewModel.advance()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.termLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}
#endif // os(macOS)
