import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum ZaiLLMSummarizerTests {

    @Test("ZaiLLMSummarizer.summarize returns summary text on success")
    static func returnsSummaryOnSuccess() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = ZaiLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "zai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        let response = try await summarizer.summarize(.stub())
        #expect(response.summaryText == "Summary.")
    }

    @Test("Request targets api.z.ai and uses glm-4.6 model")
    static func requestEndpointAndModel() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = ZaiLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "zai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        #expect(request.url!.absoluteString == "https://api.z.ai/api/paas/v4/chat/completions")

        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder().decode(OpenAIChatRequest.self, from: body)
        #expect(decoded.model == "glm-4.6")
    }

    @Test("Request uses Authorization: Bearer header (OpenAI-compatible)")
    static func usesBearerAuth() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = ZaiLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "zai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        let auth = try #require(request.value(forHTTPHeaderField: "Authorization"))
        #expect(auth == "Bearer zai-test-key")
    }

    @Test("summarize throws apiKeyMissing when no key in Keychain")
    static func throwsWhenAPIKeyMissing() async throws {
        let env = CloudStubEnv.noAPIKey()
        let summarizer = ZaiLLMSummarizer(
            apiKeyStore: env.apiKeyStore,
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )

        await #expect(throws: ProviderError.self) {
            _ = try await summarizer.summarize(.stub())
        }
    }

    @Test("summarize throws consentDenied when consent not granted")
    static func throwsWhenConsentMissing() async throws {
        let env = CloudStubEnv.noConsent()
        let summarizer = ZaiLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "zai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )

        await #expect(throws: ProviderError.self) {
            _ = try await summarizer.summarize(.stub())
        }
    }

    @Test("summarize retries 3x on rateLimited")
    static func retriesOnRateLimited() async throws {
        let env = CloudStubEnv.httpStatus(
            status: 429,
            body: """
            {"error":{"message":"rate limited"}}
            """
        )
        let summarizer = ZaiLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "zai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )

        do {
            _ = try await summarizer.summarize(.stub())
            #expect(Bool(false), "Expected throw")
        } catch is ProviderError {
            // Expected
        }
        #expect(env.session.capturedRequests.count == 3)
    }
}
