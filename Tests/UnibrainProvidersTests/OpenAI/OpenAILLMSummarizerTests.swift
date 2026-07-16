import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum OpenAILLMSummarizerTests {

    @Test("OpenAILLMSummarizer.summarize returns summary text on success")
    static func returnsSummaryOnSuccess() async throws {
        let env = CloudStubEnv.httpSuccess(
            body: """
            {
              "id": "chatcmpl-1",
              "model": "gpt-4o",
              "choices": [{"message": {"role": "assistant", "content": "Lecture summary bullets."}}]
            }
            """
        )
        let summarizer = OpenAILLMSummarizer(
            apiKeyStore: env.apiKeyStore,
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )

        let response = try await summarizer.summarize(.stub())
        #expect(response.summaryText == "Lecture summary bullets.")
    }

    @Test("Request includes Authorization: Bearer {apiKey} header")
    static func requestIncludesBearerToken() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = OpenAILLMSummarizer(
            apiKeyStore: env.apiKeyStore,
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let request = try #require(env.session.capturedRequests.first)
        let auth = try #require(request.value(forHTTPHeaderField: "Authorization"))
        #expect(auth == "Bearer sk-test-openai-key")
    }

    @Test("Request uses gpt-4o model with temperature 0.7 and max_tokens 512")
    static func requestModelAndParams() async throws {
        let env = CloudStubEnv.httpSuccess(body: OpenAIResponses.simple)
        let summarizer = OpenAILLMSummarizer(
            apiKeyStore: env.apiKeyStore,
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )
        _ = try await summarizer.summarize(.stub())

        let body = try #require(env.session.capturedRequests.first?.httpBody)
        let decoded = try JSONDecoder().decode(OpenAIChatRequest.self, from: body)
        #expect(decoded.model == "gpt-4o")
        #expect(decoded.temperature == 0.7)
        #expect(decoded.max_tokens == 512)
    }

    @Test("summarize throws apiKeyMissing when no key in Keychain")
    static func throwsWhenAPIKeyMissing() async throws {
        let env = CloudStubEnv.noAPIKey()
        let summarizer = OpenAILLMSummarizer(
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
        let summarizer = OpenAILLMSummarizer(
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

    @Test("summarize throws providerUnreachable when TCP check fails")
    static func throwsWhenReachabilityFails() async throws {
        let env = CloudStubEnv.unreachable()
        let summarizer = OpenAILLMSummarizer(
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
            {"error":{"message":"rate limited"}}
            """
        )
        let summarizer = OpenAILLMSummarizer(
            apiKeyStore: env.apiKeyStore,
            consentStore: env.consentStore,
            reachability: env.reachability,
            retry: env.retry,
            session: env.session
        )

        do {
            _ = try await summarizer.summarize(.stub())
            #expect(Bool(false), "Expected throw")
        } catch is ProviderError {
            // Expected — rate limited after 3 attempts
        }
        // 3 HTTP calls attempted (RetryComposer maxRetries = 3)
        #expect(env.session.capturedRequests.count == 3)
    }
}

// MARK: - Shared Cloud Test Doubles

/// Decodable shape of an OpenAI-compatible chat request body.
struct OpenAIChatRequest: Decodable {
    let model: String
    let temperature: Double
    let max_tokens: Int
}

extension OpenAILLMSummarizer.Request {
    static func stub() -> OpenAILLMSummarizer.Request {
        OpenAILLMSummarizer.Request(
            transcript: "Lecture transcript text.",
            courseContext: CourseContext(
                courseName: "Biology 101",
                professorName: "Dr. Smith",
                lectureDate: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    }
}

enum OpenAIResponses {
    static let simple = """
    {
      "id": "chatcmpl-1",
      "model": "gpt-4o",
      "choices": [{"message": {"role": "assistant", "content": "Summary."}}]
    }
    """
}

/// Bundled environment for cloud provider tests.
///
/// Packages APIKeyStore, ConsentStore, TCPReachability, RetryComposer, and
/// StubHTTPSession into a single fixture. Each static factory returns a
/// preconfigured environment matching a specific test scenario.
struct CloudStubEnv {
    let apiKeyStore: StubAPIKeyStore
    let consentStore: StubConsentStore
    let reachability: TCPReachability
    let retry: RetryComposer
    let session: StubHTTPSession

    static func httpSuccess(body: String) -> CloudStubEnv {
        CloudStubEnv(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-openai-key"),
            consentStore: StubConsentStore(hasConsent: true),
            reachability: TCPReachability(probe: StubReachabilityProbe(result: .reachable)),
            retry: RetryComposer(delays: [0, 0, 0], sleeper: { _ in }),
            session: StubHTTPSession(responder: .success(body: body))
        )
    }

    static func httpStatus(status: Int, body: String) -> CloudStubEnv {
        CloudStubEnv(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-openai-key"),
            consentStore: StubConsentStore(hasConsent: true),
            reachability: TCPReachability(probe: StubReachabilityProbe(result: .reachable)),
            retry: RetryComposer(delays: [0, 0, 0], sleeper: { _ in }),
            session: StubHTTPSession(responder: .status(code: status, body: body))
        )
    }

    static func noAPIKey() -> CloudStubEnv {
        CloudStubEnv(
            apiKeyStore: StubAPIKeyStore(key: nil),
            consentStore: StubConsentStore(hasConsent: true),
            reachability: TCPReachability(probe: StubReachabilityProbe(result: .reachable)),
            retry: RetryComposer(delays: [0, 0, 0], sleeper: { _ in }),
            session: StubHTTPSession(responder: .success(body: OpenAIResponses.simple))
        )
    }

    static func noConsent() -> CloudStubEnv {
        CloudStubEnv(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-openai-key"),
            consentStore: StubConsentStore(hasConsent: false),
            reachability: TCPReachability(probe: StubReachabilityProbe(result: .reachable)),
            retry: RetryComposer(delays: [0, 0, 0], sleeper: { _ in }),
            session: StubHTTPSession(responder: .success(body: OpenAIResponses.simple))
        )
    }

    static func unreachable() -> CloudStubEnv {
        CloudStubEnv(
            apiKeyStore: StubAPIKeyStore(key: "sk-test-openai-key"),
            consentStore: StubConsentStore(hasConsent: true),
            reachability: TCPReachability(probe: StubReachabilityProbe(result: .failed)),
            retry: RetryComposer(delays: [0, 0, 0], sleeper: { _ in }),
            session: StubHTTPSession(responder: .success(body: OpenAIResponses.simple))
        )
    }
}

// MARK: - StubAPIKeyStore

final class StubAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    let key: String?
    init(key: String?) { self.key = key }
    func fetch(provider: CloudProvider) async throws -> String? { key }
    func store(key: String, for provider: CloudProvider) async throws {}
    func delete(provider: CloudProvider) async throws {}
}

// MARK: - StubConsentStore

final class StubConsentStore: ConsentStoring, @unchecked Sendable {
    let hasConsent: Bool
    init(hasConsent: Bool) { self.hasConsent = hasConsent }
    func hasConsent(provider: CloudProvider, modality: Modality) async -> Bool { hasConsent }
    func consentRecord(for provider: CloudProvider, modality: Modality) async -> ConsentRecord? {
        hasConsent ? ConsentRecord(alwaysAllow: false, firstConsentedAt: Date(timeIntervalSince1970: 0)) : nil
    }
    func grantConsent(provider: CloudProvider, modality: Modality, alwaysAllow: Bool) async throws {}
    func revokeConsent(provider: CloudProvider, modality: Modality) async throws {}
    func load() async throws {}
}

// MARK: - StubHTTPSession

final class StubHTTPSession: HTTPSession, @unchecked Sendable {
    public enum Responder: Sendable {
        case success(body: String)
        case status(code: Int, body: String)
        case connectionFailure
    }

    let responder: Responder
    public private(set) var capturedRequests: [URLRequest] = []

    init(responder: Responder) { self.responder = responder }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        switch responder {
        case .success(let body):
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            return (Data(body.utf8), http)
        case .status(let code, let body):
            let http = HTTPURLResponse(
                url: request.url!,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (Data(body.utf8), http)
        case .connectionFailure:
            throw URLError(.cannotConnectToHost)
        }
    }
}
