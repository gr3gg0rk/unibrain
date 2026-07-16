import SwiftUI

/// Onboarding final page: Ready.
///
/// Per UI-SPEC Surface 1 Final Page: checkmark icon, "You're all set!" heading,
/// brief body text, "Start Using unibrain" button.
struct OnboardingReadyPage: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            // Heading
            Text("You're all set!")
                .font(.title2)
                .fontWeight(.semibold)

            // Body
            Text("Record on your iPhone in class, and notes appear on your MacBook automatically.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Start button
            Button {
                viewModel.completeOnboarding()
            } label: {
                Text("Start Using unibrain")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 48)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}
