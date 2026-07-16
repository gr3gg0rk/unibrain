import SwiftUI
import UnibrainCore

/// Onboarding page 3: Microphone permission.
///
/// Per ONBD-02: HARD-FAIL — Continue disabled until mic is granted.
/// Shows green checkmark on grant, warning + Settings deep-link on deny.
struct OnboardingMicPage: View {

    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Heading
            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 32)

            Spacer()

            // Mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.accentColor)

            // Explanation
            Text("unibrain needs microphone access to record your lectures. Audio never leaves your devices unless you explicitly enable cloud processing.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()

            // Status display
            switch viewModel.micPermissionStatus {
            case .granted:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Microphone enabled")
                        .font(.body)
                }
            case .denied:
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Microphone access required. Tap Open System Settings to enable.")
                            .font(.caption)
                    }
                    Button("Open System Settings") {
                        openMicrophoneSettings()
                    }
                    .buttonStyle(.bordered)
                }
            case .notDetermined:
                EmptyView()
            }

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                if viewModel.micPermissionStatus != .granted {
                    Button("Allow Microphone Access") {
                        Task {
                            await viewModel.requestMicPermission()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button("Continue") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.micPermissionStatus != .granted)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    /// Opens System Settings to the microphone privacy section.
    private func openMicrophoneSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #elseif os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
