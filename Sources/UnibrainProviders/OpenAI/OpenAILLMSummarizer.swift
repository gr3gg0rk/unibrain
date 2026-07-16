import Foundation
import UnibrainCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Conformance to ``LLMSummarizer`` backed by OpenAI's Chat Completions API.
///
/// Per CLOUD-03: uses `gpt-4o` model via `POST /v1/chat/completions`.
/// Per 06-AI-SPEC: temperature 0.7, max_tokens 512.
///
/// Per CF-02: runs a TCP reachability check against `api.openai.com:443`
/// before the HTTP call (2s timeout).
/// Per CF-03: wraps the HTTP call in ``RetryComposer`` (3 attempts).
/// Per CON-02: checks ConsentStore before any network activity.
/// Per CLOUD-07: fetches API key from APIKeyStore (Keychain-backed).
public struct OpenAILLMSummarizer: LLMSummarizer, Sendable {
    public typealias Request = SummarizerRequest
    public typealias Response = SummarizerResponse

    public static let model = "gpt-4o"
    public static let baseURLString = "https://api.openai.com/v1/chat/completions"
    public static let providerHost = "api.openai.com"

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
        // CON-02: consent gate
        guard await consentStore.hasConsent(provider: .openai, modality: .llm) else {
            throw ProviderError.consentDenied(provider: .openai, modality: .llm)
        }
        // CF-02: reachability pre-check
        try await reachability.check(host: Self.providerHost, port: 443, timeout: 2.0)
        // CLOUD-07: API key fetch
        guard let apiKey = try await apiKeyStore.fetch(provider: .openai) else {
            throw ProviderError.apiKeyMissing(provider: .openai)
        }

        let systemPrompt = "You are a study assistant. Summarize the lecture transcript as 5-8 bullet points of key concepts and definitions."
        let userPrompt = Self.buildUserPrompt(request: request)
        let chatRequest = ChatRequest(
            model: Self.model,
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
        return Response(summaryText: summary)
    }

    private func send(chatRequest: ChatRequest, apiKey: String) async throws -> String {
        let url = URL(string: Self.baseURLString)!
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
            throw ProviderError.modelError("OpenAI HTTP \(http.statusCode): \(body)")
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
            throw ProviderError.invalidResponse("Failed to decode OpenAI response: \(error)")
        }
    }

    static func buildUserPrompt(request: Request) -> String {
        "Transcript:\n\(request.transcript)\n\nSummarize this lecture as 5-8 bullet points of the key concepts and definitions a student needs to know."
    }
}

// MARK: - Shared Request/Response Types

public struct SummarizerRequest: Sendable {
    public let transcript: String
    public let courseContext: CourseContext
    public init(transcript: String, courseContext: CourseContext) {
        self.transcript = transcript
        self.courseContext = courseContext
    }
}

public struct SummarizerResponse: Sendable {
    public let summaryText: String
    public init(summaryText: String) { self.summaryText = summaryText }
}

// MARK: - OpenAI Wire Types

struct ChatRequest: Codable, Sendable {
    let model: String
    let messages: [Message]
    let temperature: Double
    let max_tokens: Int
}

struct Message: Codable, Sendable {
    let role: String
    let content: String
}

struct ChatResponse: Codable, Sendable {
    let id: String
    let model: String
    let choices: [Choice]
}

struct Choice: Codable, Sendable {
    let message: Message
}
