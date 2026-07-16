import Foundation
import UnibrainCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Conformance to ``LLMSummarizer`` backed by Anthropic's Messages API.
///
/// Per CLOUD-04: uses `claude-sonnet-4-20250514` via `POST /v1/messages`.
/// Per 06-AI-SPEC: temperature 0.7, max_tokens 512.
/// CRITICAL: Anthropic requires `x-api-key` header (NOT Authorization Bearer)
/// AND `anthropic-version: 2023-06-01` header — missing either causes 400.
///
/// Per CF-02: runs a TCP reachability check against `api.anthropic.com:443`.
/// Per CF-03: wraps the HTTP call in ``RetryComposer`` (3 attempts).
/// Per CON-02: checks ConsentStore before any network activity.
/// Per CLOUD-07: fetches API key from APIKeyStore (Keychain-backed).
public struct AnthropicLLMSummarizer: LLMSummarizer, Sendable {
    public typealias Request = SummarizerRequest
    public typealias Response = SummarizerResponse

    public static let model = "claude-sonnet-4-20250514"
    public static let baseURLString = "https://api.anthropic.com/v1/messages"
    public static let providerHost = "api.anthropic.com"
    public static let anthropicVersion = "2023-06-01"

    private let apiKeyStore: any APIKeyStoring
    private let consentStore: any ConsentStoring
    private let reachability: any ReachabilityProbe
    private let retry: RetryComposer
    private let session: any HTTPSession

    public init(
        apiKeyStore: any APIKeyStoring,
        consentStore: any ConsentStoring,
        reachability: any ReachabilityProbe = TCPReachability(),
        retry: RetryComposer = RetryComposer(),
        session: any HTTPSession = URLSessionAdapter()
    ) {
        self.apiKeyStore = apiKeyStore
        self.consentStore = consentStore
        self.reachability = reachability
        self.retry = retry
        self.session = session
    }

    public func summarize(_ request: Request) async throws -> Response {
        guard await consentStore.hasConsent(provider: .anthropic, modality: .llm) else {
            throw ProviderError.consentDenied(provider: .anthropic, modality: .llm)
        }
        try await reachability.check(host: Self.providerHost, port: 443, timeout: 2.0)
        guard let apiKey = try await apiKeyStore.fetch(provider: .anthropic) else {
            throw ProviderError.apiKeyMissing(provider: .anthropic)
        }

        let systemPrompt = "You are a study assistant. Summarize the lecture transcript as 5-8 bullet points of key concepts and definitions."
        let userPrompt = Self.buildUserPrompt(request: request)
        let messagesRequest = MessagesRequest(
            model: Self.model,
            max_tokens: 512,
            messages: [AnthropicMessage(role: "user", content: userPrompt)],
            temperature: 0.7,
            system: systemPrompt
        )

        let summary = try await retry.withRetry(maxRetries: 3) { _ in
            try await self.send(messagesRequest: messagesRequest, apiKey: apiKey)
        }
        return Response(summaryText: summary)
    }

    private func send(messagesRequest: MessagesRequest, apiKey: String) async throws -> String {
        let url = URL(string: Self.baseURLString)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // CRITICAL: Anthropic uses x-api-key (NOT Authorization Bearer)
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        // CRITICAL: anthropic-version header is required
        urlRequest.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.timeoutInterval = 60
        urlRequest.httpBody = try JSONEncoder().encode(messagesRequest)

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
            throw ProviderError.modelError("Anthropic HTTP \(http.statusCode): \(body)")
        }

        do {
            let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
            guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
                throw ProviderError.invalidResponse("No text content in Anthropic response")
            }
            return text
        } catch let err as ProviderError {
            throw err
        } catch {
            throw ProviderError.invalidResponse("Failed to decode Anthropic response: \(error)")
        }
    }

    static func buildUserPrompt(request: Request) -> String {
        "Transcript:\n\(request.transcript)\n\nSummarize this lecture as 5-8 bullet points of the key concepts and definitions a student needs to know."
    }
}

// MARK: - Anthropic Wire Types

struct MessagesRequest: Codable, Sendable {
    let model: String
    let max_tokens: Int
    let messages: [AnthropicMessage]
    let temperature: Double
    let system: String
}

struct AnthropicMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct MessagesResponse: Codable, Sendable {
    let id: String
    let model: String
    let content: [ContentBlock]
    let stop_reason: String?
}

struct ContentBlock: Codable, Sendable {
    let type: String
    let text: String
}
