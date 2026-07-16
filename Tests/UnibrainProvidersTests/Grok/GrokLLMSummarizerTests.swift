import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum GrokLLMSummarizerTests {

    @Test("GrokLLMSummarizer.summarize returns summary text on success")
    static func returnsSummaryOnSuccess() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = GrokLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "xai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        let response = try await summarizer.summarize(.stub())
        #expect(response.summaryText == "Summary.")
    }

    @Test("Request targets docs.x.ai and uses grok-2 model")
    static func requestEndpointAndModel() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = GrokLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "xai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        #expect(request.url!.absoluteString == "https://api.x.ai/v1/chat/completions")

        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder().decode(OpenAIChatRequest.self, from: body)
        #expect(decoded.model == "grok-2")
    }

    @Test("Request uses Authorization: Bearer header (OpenAI-compatible)")
    static func usesBearerAuth() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = GrokLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "xai-test-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        let auth = try #require(request.value(forHTTPHeaderField: "Authorization"))
        #expect(auth == "Bearer xai-test-key")
    }

    @Test("summarize throws apiKeyMissing when no key in Keychain")
    static func throwsWhenAPIKeyMissing() async throws {
        let env = CloudStubEnv.noAPIKey()
        let summarizer = GrokLLMSummarizer(
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
        let summarizer = GrokLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "xai-test-key"),
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
        let summarizer = GrokLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "xai-test-key"),
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
