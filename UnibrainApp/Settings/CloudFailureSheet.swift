import SwiftUI
import UnibrainCore
import UnibrainProviders

// MARK: - CloudFailureSheet

/// SwiftUI sheet for cloud provider failure recovery (CF-01, CF-02, CF-03).
///
/// Phase 06-04 Task 4: Slides down from menu-bar popover when a cloud
/// provider call fails after provider-inner retries (CF-03). Three actions:
/// - "Retry {Provider}" — re-attempts the cloud call (CF-03 retry budget)
/// - "Fall back to local" — switches to Ollama / whisper.cpp
/// - "Cancel recording" — aborts, preserves audio
///
/// Per 06-UI-SPEC.md Surface 8: Network unreachable variant (CF-02) hides
/// the Retry button.
///
/// **macOS-only:** CloudFailureSheet is presented inside MenuBarPopover
/// which is macOS-only. iOS does not run cloud calls in MVP (SET-03).
#if os(macOS)
struct CloudFailureSheet: View {

    // MARK: - Dependencies

    let failureRecovery: FailureRecoveryViewModel
    let context: CloudFailureContext

    // MARK: - Callbacks

    /// Invoked with the user's recovery decision.
    let onDecision: (CloudFailureDecision) -> Void

    // MARK: - State

    @State private var isProcessing: Bool = false

    // MARK: - Init

    init(
        failureRecovery: FailureRecoveryViewModel,
        context: CloudFailureContext,
        onDecision: @escaping (CloudFailureDecision) -> Void
    ) {
        self.failureRecovery = failureRecovery
        self.context = context
        self.onDecision = onDecision
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Cloud processing failed")
                    .font(.headline)
            }

            Text(errorMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if showRetryButton {
                    Button("Retry \(providerDisplayName)") {
                        onDecision(.retry)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if showFallbackButton {
                    Button("Fall back to local") {
                        onDecision(.fallback)
                    }
                    .buttonStyle(.bordered)
                }

                Button(cancelButtonText) {
                    onDecision(.cancel)
                }
                .buttonStyle(.bordered)
            }
            .disabled(isProcessing)
        }
        .padding(20)
        .frame(maxWidth: 360)
    }

    // MARK: - Helpers

    private var errorMessage: String {
        failureRecovery.errorMessage(for: context.provider, error: context.error)
    }

    private var showRetryButton: Bool {
        failureRecovery.canRetry(for: context.error)
    }

    private var showFallbackButton: Bool {
        failureRecovery.fallbackProvider(for: context.modality) != nil
    }

    private var cancelButtonText: String {
        // CF-02 variant uses "Cancel"; active recording uses "Cancel recording"
        switch context.error {
        case .providerUnreachable:
            return "Cancel"
        default:
            return "Cancel recording"
        }
    }

    private var providerDisplayName: String {
        switch context.provider {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .grok: return "Grok"
        case .zai: return "Z.ai"
        case .ollama: return "Ollama"
        case .whisperCpp: return "whisper.cpp"
        }
    }
}

// MARK: - CloudFailureDecision

/// User decision from the CloudFailureSheet.
///
/// - `.retry`: re-attempt cloud call (CF-03 budget)
/// - `.fallback`: switch to local provider
/// - `.cancel`: abort, preserve audio
public enum CloudFailureDecision: Sendable {
    case retry
    case fallback
    case cancel
}

// MARK: - Preview

#Preview("CloudFailureSheet — OpenAI rate-limited") {
    CloudFailureSheet(
        failureRecovery: FailureRecoveryViewModel(),
        context: CloudFailureContext(
            provider: .openai,
            modality: .llm,
            error: .rateLimited(retryAfter: 30)
        ),
        onDecision: { _ in }
    )
}

#Preview("CloudFailureSheet — Network unreachable (CF-02)") {
    CloudFailureSheet(
        failureRecovery: FailureRecoveryViewModel(),
        context: CloudFailureContext(
            provider: .openai,
            modality: .llm,
            error: .providerUnreachable(host: "api.openai.com")
        ),
        onDecision: { _ in }
    )
}
#endif // os(macOS)
