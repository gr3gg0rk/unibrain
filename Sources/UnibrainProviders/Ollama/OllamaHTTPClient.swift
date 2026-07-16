import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore

/// Lightweight URLSession abstraction enabling tests to inject stub
/// responses without opening real sockets.
public protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Production adapter wrapping `URLSession` for the `HTTPSession` protocol.
///
/// `URLSession.data(for:)` is `async` on Darwin but has a different shape on
/// Linux FoundationNetworking; this adapter bridges both by calling the
/// `Codable`-compatible async API.
public struct URLSessionAdapter: HTTPSession {
    public let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

/// HTTP client wrapping Ollama's `POST /api/generate` endpoint.
///
/// Per SUMM-01: Single-shot non-streaming call.
/// Per SUMM-03: `keep_alive: 0` ensures Ollama unloads the model from RAM
/// immediately after inference, preserving the 8GB RAM discipline.
///
/// Localhost HTTP (no TLS) — Ollama runs on Angelica's machine (T-06-07: accept).
public struct OllamaHTTPClient: Sendable {
    /// Endpoint base URL. Default points to a local Ollama instance.
    public let baseURL: URL

    /// URLSession-like session. Injectable for testing.
    private let session: any HTTPSession

    public init(baseURL: URL = URL(string: "http://localhost:11434")!, session: any HTTPSession = URLSessionAdapter()) {
        self.baseURL = baseURL
        self.session = session
    }

    /// Request payload for `POST /api/generate`.
    public struct GenerateRequest: Codable, Sendable {
        public let model: String
        public let prompt: String
        public let stream: Bool
        public let keep_alive: Int

        public init(model: String, prompt: String, stream: Bool, keep_alive: Int) {
            self.model = model
            self.prompt = prompt
            self.stream = stream
            self.keep_alive = keep_alive
        }
    }

    /// Decoded response from `POST /api/generate`.
    public struct GenerateResponse: Codable, Sendable {
        public let response: String
        public let done: Bool
    }

    /// Posts a generate request and returns the assistant text on success.
    ///
    /// - Parameter request: The generate request payload.
    /// - Returns: The `response` field from Ollama's JSON payload.
    /// - Throws: ``ProviderError`` on any failure (network, non-200, decode).
    public func postGenerate(request: GenerateRequest) async throws -> String {
        let url = baseURL.appendingPathComponent("api").appendingPathComponent("generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 120 // generation can take 30-60s; 2s timeout only applies to health check
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw ProviderError.networkFailure(urlRequest, error as? URLError ?? URLError(.unknown, userInfo: [NSLocalizedDescriptionKey: String(describing: error)]))
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse("Non-HTTP response from Ollama")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ProviderError.modelError("Ollama HTTP \(http.statusCode): \(body)")
        }

        do {
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            return decoded.response
        } catch {
            throw ProviderError.invalidResponse("Failed to decode Ollama response: \(error)")
        }
    }
}
