import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum FailureRecoveryViewModelTests {

    // MARK: - Test 1: shouldShowSheet returns true for user-recoverable errors

    @Test("FailureRecoveryViewModel.shouldShowSheet returns true for recoverable errors")
    static func shouldShowSheetTrueForRecoverable() {
        let vm = FailureRecoveryViewModel()

        #expect(vm.shouldShowSheet(for: .rateLimited(retryAfter: 30)) == true, "rateLimited → sheet")
        #expect(vm.shouldShowSheet(for: .providerUnreachable(host: "api.openai.com")) == true, "providerUnreachable → sheet")
        #expect(vm.shouldShowSheet(for: .apiKeyMissing(provider: .openai)) == true, "apiKeyMissing → sheet")
        #expect(vm.shouldShowSheet(for: .networkFailure(URLRequest(url: URL(string: "https://x")!), URLError(.timedOut))) == true, "networkFailure → sheet")
        #expect(vm.shouldShowSheet(for: .consentDenied(provider: .openai, modality: .llm)) == true, "consentDenied → sheet")
    }

    // MARK: - Test 2: errorMessage returns human-readable provider-specific message

    @Test("FailureRecoveryViewModel.errorMessage returns human-readable message")
    static func errorMessageIsHumanReadable() {
        let vm = FailureRecoveryViewModel()

        let rateMsg = vm.errorMessage(for: .openai, error: .rateLimited(retryAfter: 30))
        #expect(rateMsg.contains("OpenAI") && rateMsg.contains("rate-limited"), "rateLimited msg should name provider")

        let unreachableMsg = vm.errorMessage(for: .anthropic, error: .providerUnreachable(host: "api.anthropic.com"))
        #expect(unreachableMsg.contains("Anthropic") && unreachableMsg.contains("unreachable"), "unreachable msg should name provider")

        let keyMissingMsg = vm.errorMessage(for: .grok, error: .apiKeyMissing(provider: .grok))
        #expect(keyMissingMsg.contains("API key") && keyMissingMsg.contains("Grok"), "apiKeyMissing msg should name provider")
    }

    // MARK: - Test 3: canRetry returns false for providerUnreachable (CF-02)

    @Test("FailureRecoveryViewModel.canRetry returns false for providerUnreachable (CF-02)")
    static func cannotRetryUnreachable() {
        let vm = FailureRecoveryViewModel()
        #expect(vm.canRetry(for: .providerUnreachable(host: "api.openai.com")) == false, "providerUnreachable must fast-fail per CF-02")
    }

    // MARK: - Test 4: canRetry returns true for rateLimited (CF-03)

    @Test("FailureRecoveryViewModel.canRetry returns true for rateLimited (CF-03)")
    static func canRetryRateLimited() {
        let vm = FailureRecoveryViewModel()
        #expect(vm.canRetry(for: .rateLimited(retryAfter: 30)) == true, "rateLimited should be retryable per CF-03")
        #expect(vm.canRetry(for: .networkFailure(URLRequest(url: URL(string: "https://x")!), URLError(.timedOut))) == true, "networkFailure should be retryable")
    }

    // MARK: - Test 5: fallbackProvider returns local provider

    @Test("FailureRecoveryViewModel.fallbackProvider returns local provider")
    static func fallbackProviderReturnsLocal() {
        let vm = FailureRecoveryViewModel()

        let llmFallback = vm.fallbackProvider(for: .llm)
        #expect(llmFallback == .ollama, "LLM fallback must be Ollama")

        let asrFallback = vm.fallbackProvider(for: .asr)
        #expect(asrFallback == .whisperCpp, "ASR fallback must be whisper.cpp")

        // Vision/TTS have no local fallback in MVP
        let visionFallback = vm.fallbackProvider(for: .vision)
        #expect(visionFallback == nil, "Vision has no local fallback in MVP")

        let ttsFallback = vm.fallbackProvider(for: .tts)
        #expect(ttsFallback == nil, "TTS has no local fallback in MVP")
    }
}
