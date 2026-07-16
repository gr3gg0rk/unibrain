import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore

/// Lightweight health-check actor wrapping Ollama's `GET /api/tags`.
///
/// Per OLL-01: when Angelica enables "Local (Ollama)" summarization in
/// Settings, this check fires. A failure surfaces the detect-and-link
/// callout guiding her to install Ollama.
///
/// Per SUMM-01: 2-second timeout — avoids the 60s URLRequest default hang
/// when Ollama is not running (poor UX in the Settings toggle flow).
public actor OllamaHealthCheck {
    /// Endpoint base URL. Default points to a local Ollama instance.
    private let baseURL: URL

    /// URLSession-like session. Injectable for testing.
    private let session: any HTTPSession

    /// Hard cap for the reachability probe.
    private let timeout: TimeInterval

    public init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        session: any HTTPSession = URLSessionAdapter(),
        timeout: TimeInterval = 2.0
    ) {
        self.baseURL = baseURL
        self.session = session
        self.timeout = timeout
    }

    /// Returns `true` when Ollama responds 200 to `GET /api/tags`, `false` on
    /// any other outcome (TCP refused, timeout, non-200).
    public func check() async -> Bool {
        let url = baseURL.appendingPathComponent("api").appendingPathComponent("tags")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
