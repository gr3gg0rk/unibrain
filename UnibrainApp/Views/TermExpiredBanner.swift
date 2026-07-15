import SwiftUI

// MARK: - TermExpiredBanner

/// Non-blocking banner when term has ended.
///
/// Per UI-SPEC Surface 4: Same visual language as PermissionBanner.
/// Shows "Set Term" button that opens the term editor inline.
struct TermExpiredBanner: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text("\(viewModel.currentTermLabel) ended \u{2014} set your new term?")
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button("Set Term") {
                viewModel.overlayState = .termEditor
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityAddTraits(.isHeader)
    }
}
