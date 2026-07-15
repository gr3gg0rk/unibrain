import SwiftUI

// MARK: - PermissionBanner

/// Compact ongoing banner for denied calendar permission.
///
/// Per UI-SPEC Surface 3: Orange-tinted background with warning icon.
/// Tappable to open System Settings.
struct PermissionBanner: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        Button {
            viewModel.openSystemSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Calendar off \u{2014} manual pick")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    Text("required. Tap to enable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(8)
            .background(Color.orange.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Calendar off, manual pick required. Tap to enable.")
    }
}
