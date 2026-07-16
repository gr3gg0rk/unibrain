import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import UnibrainCore

/// Tests for ProviderError cloud-specific cases.
///
/// Phase 06-01 Task 1: Extends ProviderError with three cloud-specific cases
/// and adds CloudProvider/Modality enums.
@Suite("ProviderErrorTests")
struct ProviderErrorTests {

    // MARK: - Cloud-Specific Error Cases

    @Test("ProviderError.apiKeyMissing constructs with provider enum")
    func apiKeyMissingConstruction() throws {
        let provider = CloudProvider.openai
        let error = ProviderError.apiKeyMissing(provider: provider)

        switch error {
        case .apiKeyMissing(let p):
            #expect(p == provider)
        default:
            Issue.record("Expected .apiKeyMissing case")
        }
    }

    @Test("ProviderError.consentDenied constructs with provider+modality")
    func consentDeniedConstruction() throws {
        let provider = CloudProvider.anthropic
        let modality = Modality.llm
        let error = ProviderError.consentDenied(provider: provider, modality: modality)

        switch error {
        case .consentDenied(let p, let m):
            #expect(p == provider)
            #expect(m == modality)
        default:
            Issue.record("Expected .consentDenied case")
        }
    }

    @Test("ProviderError.providerUnreachable constructs with hostname")
    func providerUnreachableConstruction() throws {
        let hostname = "api.openai.com"
        let error = ProviderError.providerUnreachable(host: hostname)

        switch error {
        case .providerUnreachable(let h):
            #expect(h == hostname)
        default:
            Issue.record("Expected .providerUnreachable case")
        }
    }

    @Test("All new cloud error cases are catchable as ProviderError")
    func cloudErrorsCatchable() throws {
        let errors: [ProviderError] = [
            .apiKeyMissing(provider: .openai),
            .consentDenied(provider: .anthropic, modality: .llm),
            .providerUnreachable(host: "api.example.com")
        ]

        for error in errors {
            // Verify each error is a ProviderError enum member
            switch error {
            case .apiKeyMissing, .consentDenied, .providerUnreachable:
                continue
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - CloudProvider Enum

    @Test("CloudProvider enum has all required cases")
    func cloudProviderCases() throws {
        let providers: [CloudProvider] = [
            .openai, .anthropic, .grok, .zai, .ollama, .whisperCpp
        ]

        #expect(providers.count == 6, "Should have 6 provider cases")

        // Verify String-backed raw values
        #expect(CloudProvider.openai.rawValue == "openai")
        #expect(CloudProvider.anthropic.rawValue == "anthropic")
        #expect(CloudProvider.grok.rawValue == "grok")
        #expect(CloudProvider.zai.rawValue == "zai")
        #expect(CloudProvider.ollama.rawValue == "ollama")
        #expect(CloudProvider.whisperCpp.rawValue == "whisper-cpp")
    }

    @Test("CloudProvider is Sendable")
    func cloudProviderSendable() throws {
        // Sendable verification via type check
        let provider: CloudProvider = .openai
        let boxed: any Sendable = provider
        _ = boxed
    }

    // MARK: - Modality Enum

    @Test("Modality enum has all required cases")
    func modalityCases() throws {
        let modalities: [Modality] = [.llm, .asr, .vision, .tts]

        #expect(modalities.count == 4, "Should have 4 modality cases")

        // Verify String-backed raw values
        #expect(Modality.llm.rawValue == "llm")
        #expect(Modality.asr.rawValue == "asr")
        #expect(Modality.vision.rawValue == "vision")
        #expect(Modality.tts.rawValue == "tts")
    }

    @Test("Modality is Sendable")
    func modalitySendable() throws {
        // Sendable verification via type check
        let modality: Modality = .llm
        let boxed: any Sendable = modality
        _ = boxed
    }

    // MARK: - HeavyModelKind Ollama Case

    @Test("HeavyModelKind.ollama case exists with correct raw value")
    func heavyModelKindOllama() throws {
        let kind = HeavyModelKind.ollama
        #expect(kind.rawValue == "ollama")
    }
}
