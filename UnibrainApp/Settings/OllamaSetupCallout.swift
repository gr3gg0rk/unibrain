import SwiftUI

#if os(macOS)

/// Detect-and-link callout shown when Ollama is not reachable on localhost:11434.
///
/// Per OLL-01: Angelica installs Ollama herself from ollama.com. No in-app
/// installer, no auto-launch. She installs, then clicks Re-check.
struct OllamaSetupCallout: View {
    let isChecking: Bool
    let onRecheck: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Ollama not detected").font(.headline)
            }

            Text("Ollama is required for local summarization. Download and install Ollama, then click Re-check.")
                .font(.body)

            HStack {
                Button(action: openOllamaDownload) {
                    Label("Download Ollama", systemImage: "arrow.down.circle")
                }
                Button(action: onRecheck) {
                    if isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Re-check")
                    }
                }
                .disabled(isChecking)
                Button("Cancel", role: .cancel, action: onCancel)
                    .disabled(isChecking)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func openOllamaDownload() {
        if let url = URL(string: "https://ollama.com") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    OllamaSetupCallout(
        isChecking: false,
        onRecheck: {},
        onCancel: {}
    )
    .frame(width: 400)
}

#endif // os(macOS)
