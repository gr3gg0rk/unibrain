import Foundation
import UnibrainCore

// MARK: - Modality Provider Enums

/// LLM provider options for the Providers tab picker (SET-02, CLOUD-01).
///
/// Default: `.local` (Ollama) per CLOUD-02 (Local is always default).
public enum LLMModalityProvider: String, CaseIterable, Sendable {
    case off
    case local
    case openai
    case anthropic
    case grok
    case zai

    public var label: String {
        switch self {
        case .off: return "Off"
        case .local: return "Local (Ollama)"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .grok: return "Grok (X)"
        case .zai: return "Z.ai"
        }
    }

    public var isCloud: Bool {
        switch self {
        case .off, .local: return false
        case .openai, .anthropic, .grok, .zai: return true
        }
    }

    public var cloudProvider: CloudProvider? {
        switch self {
        case .off, .local: return nil
        case .openai: return .openai
        case .anthropic: return .anthropic
        case .grok: return .grok
        case .zai: return .zai
        }
    }
}

/// ASR provider options for the Providers tab picker (SET-02, CLOUD-01).
///
/// Default: `.local` (whisper.cpp) per CLOUD-02.
public enum ASRModalityProvider: String, CaseIterable, Sendable {
    case off
    case local
    case openai

    public var label: String {
        switch self {
        case .off: return "Off"
        case .local: return "Local (whisper.cpp)"
        case .openai: return "OpenAI (Whisper-1)"
        }
    }

    public var isCloud: Bool {
        switch self {
        case .off, .local: return false
        case .openai: return true
        }
    }

    public var cloudProvider: CloudProvider? {
        switch self {
        case .off, .local: return nil
        case .openai: return .openai
        }
    }
}

/// Vision provider options for the Providers tab picker (SET-02, CLOUD-01).
///
/// Default: `.off` (no Vision ingestion in v1).
public enum VisionModalityProvider: String, CaseIterable, Sendable {
    case off
    case openai
    case anthropic

    public var label: String {
        switch self {
        case .off: return "Off"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    public var isCloud: Bool {
        switch self {
        case .off: return false
        case .openai, .anthropic: return true
        }
    }

    public var cloudProvider: CloudProvider? {
        switch self {
        case .off: return nil
        case .openai: return .openai
        case .anthropic: return .anthropic
        }
    }
}

/// TTS provider options for the Providers tab picker (SET-02, CLOUD-01).
///
/// Default: `.off` (no TTS feature in v1 — selectable but no consumer).
public enum TTSModalityProvider: String, CaseIterable, Sendable {
    case off
    case openai

    public var label: String {
        switch self {
        case .off: return "Off"
        case .openai: return "OpenAI (tts-1)"
        }
    }

    public var isCloud: Bool {
        switch self {
        case .off: return false
        case .openai: return true
        }
    }

    public var cloudProvider: CloudProvider? {
        switch self {
        case .off: return nil
        case .openai: return .openai
        }
    }
}

// MARK: - API Key Validation (T-06-24)

/// Validates API key format per provider (T-06-24 mitigation).
///
/// Per threat model: SecureField masks input. Validation regex checks format
/// before storing to Keychain. Matches are permissive (prefix-based) to allow
/// for key rotation/format changes without breaking validation.
public enum APIKeyValidator {

    /// Returns true if the key matches the expected format for the provider.
    public static func isValid(_ key: String, for provider: CloudProvider) -> Bool {
        guard !key.isEmpty else { return false }
        switch provider {
        case .openai:
            // OpenAI keys: sk-... (traditional) or sk-proj-... (project keys)
            return key.hasPrefix("sk-")
        case .anthropic:
            // Anthropic keys: sk-ant-...
            return key.hasPrefix("sk-ant-")
        case .grok:
            // Grok (X) keys: xai-...
            return key.hasPrefix("xai-")
        case .zai:
            // Z.ai keys: vary — accept any non-empty 16+ char string
            return key.count >= 16
        case .ollama, .whisperCpp:
            // Local providers don't need API keys
            return false
        }
    }
}
