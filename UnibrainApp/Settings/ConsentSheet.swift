import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - ConsentSheet

/// SwiftUI sheet for first-use per-provider×modality consent (CON-01, CON-02).
///
/// Phase 06-04 Task 2: Slides down from menu-bar popover when a cloud call
/// is about to fire and no consent record exists for the `{provider}×{modality}`
/// pair. Three actions per CON-01:
/// - "Only this once" — proceeds without saving consent
/// - "Always allow {Provider} for {modality}" — proceeds + persists (CON-02)
/// - "Cancel" — blocks cloud call, returns to previous state
///
/// Per 06-UI-SPEC.md Surface 7: Provider name displayed, modality-specific
/// verb in heading, content description in body.
///
/// **macOS-only:** ConsentSheet is presented inside MenuBarPopover which is
/// macOS-only. iOS inherits consent state via iCloud Drive sync (SET-03).
#if os(macOS)
struct ConsentSheet: View {

    // MARK: - Dependencies

    @State private var consentViewModel: ConsentViewModel
    let provider: CloudProvider
    let modality: Modality

    // MARK: - Callbacks

    /// Invoked with the user's decision. `.onceOnly` and `.alwaysAllowed`
    /// continue the pipeline; `.cancelled` aborts the cloud call.
    let onDecision: (ConsentDecision) -> Void

    // MARK: - State

    @State private var alwaysAllowToggle: Bool = false
    @State private var isProcessing: Bool = false

    // MARK: - Init

    init(
        consentViewModel: ConsentViewModel,
        provider: CloudProvider,
        modality: Modality,
        onDecision: @escaping (ConsentDecision) -> Void
    ) {
        self._consentViewModel = State(initialValue: consentViewModel)
        self.provider = provider
        self.modality = modality
        self.onDecision = onDecision
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headingText)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(toggleLabelText, isOn: $alwaysAllowToggle)
                .font(.callout)

            HStack(spacing: 8) {
                Button("Only this once") {
                    grantConsent(alwaysAllow: false)
                }
                .buttonStyle(.bordered)

                Button(alwaysAllowButtonText) {
                    grantConsent(alwaysAllow: true)
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    onDecision(.cancelled)
                }
                .buttonStyle(.bordered)
            }
            .disabled(isProcessing)
        }
        .padding(20)
        .frame(maxWidth: 360)
    }

    // MARK: - Helpers

    private var headingText: String {
        "Allow \(providerDisplayName) to \(modalityVerb) this recording?"
    }

    private var bodyText: String {
        switch modality {
        case .llm:
            return "\(providerDisplayName) will process your transcript to generate a summary. The transcript leaves your device during this process."
        case .asr:
            return "\(providerDisplayName) will process your lecture audio to generate a transcript. Audio leaves your device during this process."
        case .vision:
            return "\(providerDisplayName) will process your image to generate a description. The image leaves your device during this process."
        case .tts:
            return "\(providerDisplayName) will process your text to generate audio speech. The text leaves your device during this process."
        }
    }

    private var toggleLabelText: String {
        "Always allow \(providerDisplayName) for \(modality.rawValue.uppercased())"
    }

    private var alwaysAllowButtonText: String {
        alwaysAllowToggle
            ? "Always allow \(providerDisplayName) for \(modality.rawValue.uppercased())"
            : "Always allow"
    }

    private var providerDisplayName: String {
        switch provider {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .grok: return "Grok"
        case .zai: return "Z.ai"
        case .ollama: return "Ollama"
        case .whisperCpp: return "whisper.cpp"
        }
    }

    private var modalityVerb: String {
        switch modality {
        case .llm: return "summarize"
        case .asr: return "transcribe"
        case .vision: return "describe"
        case .tts: return "speak"
        }
    }

    private func grantConsent(alwaysAllow: Bool) {
        isProcessing = true
        Task { @MainActor in
            do {
                try await consentViewModel.grantConsent(
                    provider: provider,
                    modality: modality,
                    alwaysAllow: alwaysAllow
                )
                onDecision(alwaysAllow ? .alwaysAllowed : .onceOnly)
            } catch {
                // ConsentStore write failed — treat as cancelled (defensive)
                onDecision(.cancelled)
            }
            isProcessing = false
        }
    }
}

// MARK: - ConsentDecision

/// User decision from the ConsentSheet.
///
/// Flow-through:
/// - `.onceOnly`: proceed with cloud call this time, do not persist
/// - `.alwaysAllowed`: proceed with cloud call, persist "Always allow" (CON-02)
/// - `.cancelled`: abort cloud call, recording preserved
public enum ConsentDecision: Sendable {
    case onceOnly
    case alwaysAllowed
    case cancelled
}

// MARK: - Preview

#Preview("ConsentSheet — OpenAI LLM") {
    ConsentSheet(
        consentViewModel: ConsentViewModel(
            consentStore: PreviewConsentStore()
        ),
        provider: .openai,
        modality: .llm,
        onDecision: { _ in }
    )
}

/// Inline preview-only ConsentStoring conformer.
private struct PreviewConsentStore: ConsentStoring {
    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool { false }
    func consentRecord(for provider: CloudProvider, modality: Modality) async -> ConsentRecord? { nil }
    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {}
    func revokeConsent(provider: CloudProvider, modality: Modality) async throws {}
    func load() async throws {}
}
#endif // os(macOS)
