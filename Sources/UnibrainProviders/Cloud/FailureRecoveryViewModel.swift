import Foundation
import UnibrainCore

// MARK: - CloudFailureContext

/// Context for a cloud provider failure presented in the recovery sheet.
///
/// Phase 06-04 Task 3: Carries the error and the request context so the
/// CloudFailureSheet (Task 4) and ProviderRouter.executeWithRecovery (Task 5)
/// can drive retry / fallback / cancel decisions.
public struct CloudFailureContext: Sendable {
    /// Provider that failed.
    public let provider: CloudProvider
    /// Modality the call belonged to.
    public let modality: Modality
    /// Underlying provider error.
    public let error: ProviderError
    /// Optional transcript text (for LLM modality) — preserved across retries.
    public let transcript: String?
    /// Optional note identifier — for surfacing in Audit tab (CF-04).
    public let note: String?

    public init(
        provider: CloudProvider,
        modality: Modality,
        error: ProviderError,
        transcript: String? = nil,
        note: String? = nil
    ) {
        self.provider = provider
        self.modality = modality
        self.error = error
        self.transcript = transcript
        self.note = note
    }
}

// MARK: - FailureRecoveryViewModel

/// Manages cloud failure presentation, error messages, and retry/fallback logic.
///
/// Phase 06-04 Task 3: Bridges the UI (CloudFailureSheet) and ProviderRouter.
/// Per CF-01..CF-04:
/// - CF-01: surfaces retry / fallback / cancel choices to user
/// - CF-02: providerUnreachable fast-fails (no retry button)
/// - CF-03: rateLimited / networkFailure allow retry (within provider limits)
/// - CF-04: failure context persisted for Audit tab
///
/// `@unchecked Sendable`: stateless logic — all public methods are pure
/// functions of their inputs. Safe to call from any actor.
public final class FailureRecoveryViewModel: @unchecked Sendable {

    public init() {}

    // MARK: - Sheet Presentation

    /// Returns `true` when the error is user-recoverable and should surface
    /// the CloudFailureSheet (CF-01).
    public func shouldShowSheet(for error: ProviderError) -> Bool {
        switch error {
        case .networkFailure,
             .rateLimited,
             .providerUnreachable,
             .apiKeyMissing,
             .consentDenied:
            return true
        case .cancelled,
             .modelError,
             .invalidResponse,
             .unsupportedPlatform,
             .underlying:
            // Internal errors — no user recovery path
            return false
        }
    }

    // MARK: - Error Messages

    /// Returns a human-readable, provider-specific error message for the
    /// CloudFailureSheet body (per 06-UI-SPEC.md Surface 8 copy).
    public func errorMessage(for provider: CloudProvider, error: ProviderError) -> String {
        let providerName = Self.displayName(for: provider)
        switch error {
        case .rateLimited:
            return "\(providerName) rate-limited — too many requests. Try again in a minute, or fall back to \(Self.fallbackName(for: .llm))."
        case .providerUnreachable(let host):
            return "\(providerName) unreachable — network down. Check your connection and retry, or fall back to local."
        case .apiKeyMissing:
            return "\(providerName) API key missing or invalid. Add key in Settings → Providers, or fall back to local."
        case .networkFailure:
            return "\(providerName) network error. Retry or fall back to local."
        case .consentDenied(let p, let m):
            return "Consent required. Allow \(Self.displayName(for: p)) for \(m.rawValue.uppercased()) in Settings, or fall back to local."
        case .modelError(let detail):
            // Defensive: strip any API key shape from model errors
            let sanitized = Self.sanitize(detail)
            return "\(providerName) returned an error\(sanitized.isEmpty ? "" : ": \(sanitized)"). Retry or fall back to local."
        case .invalidResponse(let detail):
            let sanitized = Self.sanitize(detail)
            return "\(providerName) returned an unexpected response\(sanitized.isEmpty ? "" : ": \(sanitized)"). Retry or fall back to local."
        case .cancelled:
            return "Operation cancelled."
        case .unsupportedPlatform:
            return "\(providerName) is not supported on this device."
        case .underlying:
            return "\(providerName) returned an error. Retry or fall back to local."
        }
    }

    // MARK: - Retry Logic

    /// Returns `true` when retry is appropriate for the error.
    ///
    /// Per CF-02: providerUnreachable fast-fails — no retry.
    /// Per CF-03: rateLimited / networkFailure allow retry (provider-inner).
    /// apiKeyMissing and consentDenied require user action, not retry.
    public func canRetry(for error: ProviderError) -> Bool {
        switch error {
        case .providerUnreachable:
            return false // CF-02 fast-fail
        case .apiKeyMissing, .consentDenied:
            return false // user action required
        case .rateLimited, .networkFailure:
            return true // CF-03 retry applies
        case .cancelled, .modelError, .invalidResponse, .unsupportedPlatform, .underlying:
            return false
        }
    }

    // MARK: - Fallback Provider

    /// Returns the local fallback provider for the modality, or `nil` if
    /// no local fallback exists in MVP (per 06-CONTEXT.md).
    public func fallbackProvider(for modality: Modality) -> CloudProvider? {
        switch modality {
        case .llm:
            return .ollama
        case .asr:
            return .whisperCpp
        case .vision, .tts:
            return nil // No local Vision/TTS fallback in MVP
        }
    }

    // MARK: - Internal Helpers

    /// Pretty provider name for user-facing copy.
    static func displayName(for provider: CloudProvider) -> String {
        switch provider {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .grok: return "Grok"
        case .zai: return "Z.ai"
        case .ollama: return "Ollama"
        case .whisperCpp: return "whisper.cpp"
        }
    }

    /// Pretty local fallback name for modality.
    static func fallbackName(for modality: Modality) -> String {
        switch modality {
        case .llm: return "Ollama"
        case .asr: return "whisper.cpp"
        case .vision, .tts: return "local"
        }
    }

    /// Strip API-key-shaped substrings from provider error details.
    ///
    /// Defensive — provider clients never log keys, but this is a second line
    /// of defense against accidental key leakage in error messages (T-06-20).
    private static let keyPatterns: [String] = [
        "sk-[A-Za-z0-9]{20,}",
        "xai-[A-Za-z0-9]{20,}",
        "sk-ant-[A-Za-z0-9]{20,}"
    ]

    static func sanitize(_ text: String) -> String {
        var result = text
        for pattern in keyPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "[redacted]")
            }
        }
        return result
    }
}
