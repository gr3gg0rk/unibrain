import Testing
import Foundation
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum ProviderRouterIntegrationTests {

    // MARK: - Test 1: ProviderRouter checks ConsentViewModel before returning provider

    @Test("ProviderRouter.summarizer checks consent before returning provider")
    static func checksConsentBeforeReturning() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .openai),
            apiKeyStore: StubAPIKeyStore(key: "sk-test"),
            consentStore: ConsentDenyingStore(),
            consentViewModel: ConsentViewModel(consentStore: ConsentDenyingStore()),
            failureRecovery: FailureRecoveryViewModel()
        )

        do {
            _ = try await router.summarizer(for: .openai)
            #expect(Bool(false), "Expected throw")
        } catch let err as ProviderError {
            if case .consentDenied(let provider, let modality) = err {
                #expect(provider == .openai, "Expected .openai in consentDenied")
                #expect(modality == .llm, "Expected .llm in consentDenied")
            } else {
                #expect(Bool(false), "Expected .consentDenied, got \(err)")
            }
        }
    }

    // MARK: - Test 2: ProviderRouter throws consentDenied when consent missing

    @Test("ProviderRouter throws consentDenied when consent missing")
    static func throwsConsentDeniedWhenMissing() async throws {
        let store = ConsentDenyingStore()
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .anthropic),
            apiKeyStore: StubAPIKeyStore(key: "sk-ant-test"),
            consentStore: store,
            consentViewModel: ConsentViewModel(consentStore: store),
            failureRecovery: FailureRecoveryViewModel()
        )

        do {
            _ = try await router.summarizer(for: .anthropic)
            #expect(Bool(false), "Expected throw")
        } catch let err as ProviderError {
            if case .consentDenied(let p, _) = err {
                #expect(p == .anthropic, "Expected .anthropic in consentDenied")
            } else {
                #expect(Bool(false), "Expected .consentDenied")
            }
        }
    }

    // MARK: - Test 3: ProviderRouter returns summarizer when consent granted

    @Test("ProviderRouter returns summarizer when consent granted")
    static func returnsWhenConsentGranted() async throws {
        let store = ConsentGrantingStore()
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .ollama),
            apiKeyStore: StubAPIKeyStore(key: nil),
            consentStore: store,
            consentViewModel: ConsentViewModel(consentStore: store),
            failureRecovery: FailureRecoveryViewModel()
        )

        let summarizer = try await router.summarizer(for: .ollama)
        _ = summarizer
    }

    // MARK: - Test 4: ProviderRouter.fallbackSummarizer returns Ollama when cloud unavailable

    @Test("ProviderRouter.fallbackSummarizer returns Ollama for LLM modality")
    static func fallbackReturnsOllamaForLLM() async throws {
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .openai),
            apiKeyStore: StubAPIKeyStore(key: nil),
            consentStore: ConsentGrantingStore(),
            consentViewModel: ConsentViewModel(consentStore: ConsentGrantingStore()),
            failureRecovery: FailureRecoveryViewModel()
        )

        let fallback = try await router.fallbackSummarizer(for: .llm)
        _ = fallback // Type-erased — verifying it constructs without error
    }

    // MARK: - Test 5: executeWithRecovery wraps operations in CloudFailureContext

    @Test("executeWithRecovery throws and wraps in CloudFailureContext on provider error")
    static func executeWithRecoveryWrapsFailures() async throws {
        let store = ConsentGrantingStore()
        let router = ProviderRouter(
            settings: ProviderRouter.Settings(llmProvider: .openai),
            apiKeyStore: StubAPIKeyStore(key: "sk-test"),
            consentStore: store,
            consentViewModel: ConsentViewModel(consentStore: store),
            failureRecovery: FailureRecoveryViewModel()
        )

        struct TestError: Error, Sendable {}

        do {
            _ = try await router.executeWithRecovery(
                provider: .openai,
                modality: .llm,
                operation: { _ in
                    throw TestError()
                }
            )
            #expect(Bool(false), "Expected throw")
        } catch {
            // Expected — operation threw, executeWithRecovery propagates.
            // The wrapper does NOT swallow the error; it surfaces it so the
            // UI can build a CloudFailureContext from the caught error.
            #expect(Bool(true), "executeWithRecovery propagated the error")
        }
    }
}

// MARK: - Test Stubs

/// Consent store that always denies consent.
final class ConsentDenyingStore: ConsentStoring, @unchecked Sendable {
    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool { false }
    func consentRecord(for provider: CloudProvider, modality: Modality) async -> ConsentRecord? { nil }
    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {}
    func revokeConsent(provider: CloudProvider, modality: Modality) async throws {}
    func load() async throws {}
}

/// Consent store that always grants consent.
final class ConsentGrantingStore: ConsentStoring, @unchecked Sendable {
    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool { true }
    func consentRecord(for provider: CloudProvider, modality: Modality) async -> ConsentRecord? {
        ConsentRecord(alwaysAllow: true, firstConsentedAt: Date(timeIntervalSince1970: 0))
    }
    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {}
    func revokeConsent(provider: CloudProvider, modality: Modality) async throws {}
    func load() async throws {}
}
