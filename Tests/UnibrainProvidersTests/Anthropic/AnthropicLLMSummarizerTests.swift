import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum AnthropicLLMSummarizerTests {

    @Test("AnthropicLLMSummarizer.summarize returns summary text on success")
    static func returnsSummaryOnSuccess() async throws {
        let env = CloudStubEnv.httpSuccess(
            body: """
            {
              "id": "msg_1",
              "type": "message",
              "role": "assistant",
              "model": "claude-sonnet-4-20250514",
              "content": [{"type": "text", "text": "Anthropic summary bullets."}],
              "stop_reason": "end_turn"
            }
            """
        )
        let summarizer = AnthropicLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-anthropic-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        let response = try await summarizer.summarize(.stub())
        #expect(response.summaryText == "Anthropic summary bullets.")
    }

    @Test("Request uses x-api-key header (NOT Authorization Bearer)")
    static func usesAPIKeyHeader() async throws {
        let env = CloudStubEnv.httpSuccess(body: AnthropicResponses.simple)
        let summarizer = AnthropicLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-anthropic-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        let apiKeyHeader = try #require(request.value(forHTTPHeaderField: "x-api-key"))
        #expect(apiKeyHeader == "sk-test-anthropic-key")
        // Must NOT use Authorization: Bearer
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Request includes anthropic-version: 2023-06-01 header")
    static func includesAnthropicVersionHeader() async throws {
        let env = CloudStubEnv.httpSuccess(body: AnthropicResponses.simple)
        let summarizer = AnthropicLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-anthropic-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        let version = try #require(request.value(forHTTPHeaderField: "anthropic-version"))
        #expect(version == "2023-06-01")
    }

    @Test("Request uses claude-sonnet-4-20250514 model with messages format")
    static func requestModelAndFormat() async throws {
        let env = CloudStubEnv.httpSuccess(body: AnthropicResponses.simple)
        let summarizer = AnthropicLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-anthropic-key"),
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let body = try #require(env.session.capturedRequests.first?.httpBody)
        let decoded = try JSONDecoder().decode(AnthropicMessagesRequest.self, from: body)
        #expect(decoded.model == "claude-sonnet-4-20250514")
        #expect(decoded.max_tokens == 512)
        #expect(decoded.temperature == 0.7)
        #expect(decoded.messages.count == 1)
        #expect(decoded.messages[0].role == "user")
        // system prompt lives at top-level, not in messages
        #expect(!decoded.system.isEmpty)
    }

    @Test("summarize throws apiKeyMissing when no key in Keychain")
    static func throwsWhenAPIKeyMissing() async throws {
        let env = CloudStubEnv.noAPIKey()
        let summarizer = AnthropicLLMSummarizer(
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
        let summarizer = AnthropicLLMSummarizer(
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

    @Test("summarize retries 3x on rateLimited")
    static func retriesOnRateLimited() async throws {
        let env = CloudStubEnv.httpStatus(
            status: 429,
            body: """
            {"type":"error","error":{"type":"rate_limit_error","message":"Rate limited"}}
            """
        )
        let summarizer = AnthropicLLMSummarizer(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-anthropic-key"),
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

// MARK: - Anthropic Test Helpers

struct AnthropicMessagesRequest: Decodable {
    let model: String
    let max_tokens: Int
    let temperature: Double
    let system: String
    let messages: [AnthropicMessage]
}

struct AnthropicMessage: Decodable {
    let role: String
    let content: String
}

enum AnthropicResponses {
    static let simple = """
    {
      "id": "msg_1",
      "type": "message",
      "role": "assistant",
      "model": "claude-sonnet-4-20250514",
      "content": [{"type": "text", "text": "Summary."}],
      "stop_reason": "end_turn"
    }
    """
}

// stub() is shared via the OpenAILLMSummarizer.Request extension in
// OpenAILLMSummarizerTests.swift — both are SummarizerRequest.

