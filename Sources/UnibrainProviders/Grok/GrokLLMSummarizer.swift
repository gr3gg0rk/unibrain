import Foundation
import UnibrainCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared OpenAI-compatible Chat Completions logic.
///
/// Per 06-CONTEXT.md Claude's Discretion: Grok (X) and Z.ai use
/// OpenAI-compatible auth and request format. This struct factors out the
/// common HTTP call so both providers only differ in endpoint, model, and
/// CloudProvider enum case.
struct OpenAICompatibleClient: Sendable {
    let provider: CloudProvider
    let baseURLString: String
    let model: String
    let providerHost: String

    let apiKeyStore: any APIKeyStoring
    let consentStore: any ConsentStoring
    let reachability: any ReachabilityProbe
    let retry: RetryComposer
    let session: any HTTPSession

    func summarize(_ request: SummarizerRequest) async throws -> SummarizerResponse {
        guard await consentStore.hasConsent(provider: provider, modality: .llm) else {
            throw ProviderError.consentDenied(provider: provider, modality: .llm)
        }
        try await reachability.check(host: providerHost, port: 443, timeout: 2.0)
        guard let apiKey = try await apiKeyStore.fetch(provider: provider) else {
            throw ProviderError.apiKeyMissing(provider: provider)
        }

        let systemPrompt = "You are a study assistant. Summarize the lecture transcript as 5-8 bullet points of key concepts and definitions."
        let userPrompt = Self.buildUserPrompt(request: request)
        let chatRequest = ChatRequest(
            model: model,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: userPrompt)
            ],
            temperature: 0.7,
            max_tokens: 512
        )

        let summary = try await retry.withRetry(maxRetries: 3) { _ in
            try await self.send(chatRequest: chatRequest, apiKey: apiKey)
        }
        return SummarizerResponse(summaryText: summary)
    }

    private func send(chatRequest: ChatRequest, apiKey: String) async throws -> String {
        let url = URL(string: baseURLString)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 60
        urlRequest.httpBody = try JSONEncoder().encode(chatRequest)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw ProviderError.networkFailure(urlRequest, error as? URLError ?? URLError(.unknown))
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse("Non-HTTP response")
        }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw ProviderError.rateLimited(retryAfter: retryAfter)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ProviderError.modelError("\(provider.rawValue) HTTP \(http.statusCode): \(body)")
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw ProviderError.invalidResponse("No content in choices")
            }
            return content
        } catch let err as ProviderError {
            throw err
        } catch {
            throw ProviderError.invalidResponse("Failed to decode response: \(error)")
        }
    }

    static func buildUserPrompt(request: SummarizerRequest) -> String {
        "Transcript:\n\(request.transcript)\n\nSummarize this lecture as 5-8 bullet points of the key concepts and definitions a student needs to know."
    }
}

/// Conformance to ``LLMSummarizer`` backed by Grok (X AI) Chat Completions.
///
/// Per CLOUD-05: uses `grok-2` via `POST /v1/chat/completions`.
/// OpenAI-compatible auth (Bearer token) per 06-CONTEXT.md.
public struct GrokLLMSummarizer: LLMSummarizer, Sendable {
    public typealias Request = SummarizerRequest
    public typealias Response = SummarizerResponse

    public static let model = "grok-2"
    public static let baseURLString = "https://api.x.ai/v1/chat/completions"
    public static let providerHost = "api.x.ai"

    private let client: OpenAICompatibleClient

    public init(
        apiKeyStore: any APIKeyStoring,
        consentStore: any ConsentStoring,
        reachability: any ReachabilityProbe = TCPReachability(),
        retry: RetryComposer = RetryComposer(),
        session: any HTTPSession = URLSessionAdapter()
    ) {
        self.client = OpenAICompatibleClient(
            provider: .grok,
            baseURLString: Self.baseURLString,
            model: Self.model,
            providerHost: Self.providerHost,
            apiKeyStore: apiKeyStore,
            consentStore: consentStore,
            reachability: reachability,
            retry: retry,
            session: session
        )
    }

    public func summarize(_ request: Request) async throws -> Response {
        try await client.summarize(request)
    }
}
