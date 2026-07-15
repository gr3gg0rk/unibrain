import SwiftUI

/// Minimal main-window content view.
///
/// Per P-08: the menu-bar popover IS the primary recording surface.
/// This window is minimal — shows app name + current session state label.
/// Future Settings entry point comes in Phase 6.
struct ContentView: View {
    var viewModel: MenuBarViewModel?

    var body: some View {
        VStack(spacing: 16) {
            Text("Unibrain")
                .font(.title)
                .fontWeight(.semibold)

            if let viewModel {
                Text(stateLabel(viewModel.sessionState))
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("Initializing…")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Recording controls are in the menu bar")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
        .frame(width: 320, height: 200)
        .padding()
    }

    /// Maps session state to a human-readable label for the status display.
    private func stateLabel(_ state: SessionDisplayState) -> String {
        switch state {
        case .idle:
            "Ready"
        case .recording:
            "Recording…"
        case .paused:
            "Paused"
        case .transcribing:
            "Transcribing…"
        case .completed:
            "Transcript ready"
        case .error(let message):
            "Error: \(message)"
        }
    }
}
