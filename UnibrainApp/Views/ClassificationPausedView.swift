import SwiftUI

// MARK: - ClassificationPausedView

/// Brief loading state between transcription done and picker/classification result.
///
/// Per UI-SPEC Popover State Extensions: Shows ProgressView with
/// "Transcription done." headline + "Picking course\u{2026}" subheadline +
/// "Analyzing calendar\u{2026}" caption.
/// Cancel button provides escape hatch to _unsorted.
struct ClassificationPausedView: View {
    let viewModel: MenuBarViewModel

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Transcription done.")
                    .font(.headline)

                Text("Picking course\u{2026}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Analyzing calendar\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task {
                    await viewModel.skipClassification()
                }
            } label: {
                Text("Cancel (save to _unsorted)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }
}
