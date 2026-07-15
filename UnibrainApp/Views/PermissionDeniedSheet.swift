import SwiftUI

// MARK: - PermissionDeniedSheet

/// First-time calendar permission explanation overlay.
///
/// Per UI-SPEC Surface 3: Inline overlay (NOT a .sheet per Pitfall 2).
/// Explains why calendar access is needed and provides a Settings deep-link.
struct PermissionDeniedSheet: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Calendar Access Needed")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                Text("unibrain uses your calendar to automatically route recordings to the right course folder.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text("Without calendar access, you'll need to pick the course manually each time you record.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Button {
                    viewModel.openSystemSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.overlayState = .coursePicker(.none)
                } label: {
                    Text("Continue with Manual Pick")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
    }
}
