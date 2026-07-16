import SwiftUI

#if os(macOS)

/// Callout shown when Ollama is reachable but the llama-3.2:3b model is not
/// present locally.
///
/// Per OLL-03: explicit "Pull model" button so Angelica sees the ~2GB
/// commitment before it starts (important for tethered-hotspot scenarios).
/// The button fires `ollama pull llama-3.2:3b` via Process (Task 5 wires
/// the actual invocation + progress parsing).
struct ModelPullCallout: View {
    let isPulling: Bool
    let progress: Double // 0.0 ... 1.0
    let onPull: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.blue)
                Text("Model not pulled yet").font(.headline)
            }

            Text("llama-3.2:3b (~2GB) is required for summarization.")
                .font(.body)

            if isPulling {
                VStack(alignment: .leading) {
                    ProgressView(value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(action: onPull) {
                    Label("Pull llama-3.2:3b (~2GB)", systemImage: "arrow.down.to.line")
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ModelPullCallout(isPulling: false, progress: 0.0, onPull: {})
        .frame(width: 400)
}

#endif // os(macOS)
