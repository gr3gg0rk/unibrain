import SwiftUI
import UniformTypeIdentifiers
import UnibrainProviders

/// Onboarding page 2: Vault folder picker.
///
/// Per ONBD-04 / ONB-03: Uses `.fileImporter` with `UTType.folder`.
/// Suggests iCloud Drive as the default location.
/// Per ONB-01 (iOS): Shows "Open on Mac first" banner if courses.json not found.
struct OnboardingVaultPage: View {

    let viewModel: OnboardingViewModel

    @State private var showingPicker = false

    var body: some View {
        VStack(spacing: 16) {
            // Heading
            Text("Choose Your Vault Folder")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.top, 32)

            // Explanation
            Text("Pick the folder where unibrain will save your lecture notes. iCloud Drive is recommended so your notes sync across devices.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Spacer()

            // Selected path display
            if let url = viewModel.selectedVaultURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.accentColor)
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Select a folder to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // iOS inheritance banner
            #if os(iOS)
            if viewModel.showMacFirstBanner {
                VStack(spacing: 4) {
                    Text("Open unibrain on your Mac first")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Set up your course schedule on macOS, then pick the same folder here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
            }
            #endif

            // Buttons
            VStack(spacing: 12) {
                Button("Choose Folder\u{2026}") {
                    showingPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Continue") {
                    viewModel.advance()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.selectedVaultURL == nil)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    _ = url.startAccessingSecurityScopedResource()
                    viewModel.pickVault(url: url)
                }
            case .failure:
                break
            }
        }
    }
}
