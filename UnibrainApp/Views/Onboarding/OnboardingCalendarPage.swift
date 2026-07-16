import SwiftUI
import UnibrainCore

/// Onboarding page 4: Calendar permission.
///
/// Per ONBD-03: OPTIONAL — Continue enabled regardless of calendar status.
/// Shows green checkmark on grant, "Skip (Manual Pick)" always available.
struct OnboardingCalendarPage: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Heading
            Text("Calendar Access")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 32)

            Spacer()

            // Icon
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.accentColor)

            // Explanation
            Text("unibrain uses your calendar to automatically route recordings to the right course folder.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Text("Optional — you can pick the course manually if you prefer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Status display
            if viewModel.calendarPermissionStatus == .granted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Calendar connected")
                        .font(.body)
                }
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if viewModel.calendarPermissionStatus != .granted {
                    Button("Allow Calendar Access") {
                        Task {
                            await viewModel.requestCalendarPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Skip (Manual Pick)") {
                        viewModel.advance()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button("Continue") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}
