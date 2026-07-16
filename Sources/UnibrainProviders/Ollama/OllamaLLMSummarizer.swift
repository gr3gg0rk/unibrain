import Foundation
import UnibrainCore

/// Conformance to ``LLMSummarizer`` backed by Ollama's local HTTP API.
///
/// Per SUMM-01: POST /api/generate.
/// Per SUMM-03: llama-3.2:3b with keep_alive: 0 (immediate unload after inference).
/// Per SUMM-07: acquires ModelLoadGate.shared(.ollama) before calling Ollama;
///   the gate denies acquire if ASR is held (8GB RAM discipline).
///
/// The acquire/release lifecycle is paired via a `defer` so the gate is released
/// on every path (success, provider error, cancellation).
public struct OllamaLLMSummarizer: LLMSummarizer, Sendable {
    public typealias Request = String
    public typealias Response = String

    /// Abstraction over ``OllamaHTTPClient`` enabling tests to inject stub
    /// responses without binding to a real `URLSession` or opening sockets.
    public protocol Shim: Sendable {
        func postGenerate(request: OllamaHTTPClient.GenerateRequest) async throws -> String
    }

    /// Default shim that delegates to a real ``OllamaHTTPClient``.
    public struct DefaultShim: Shim, Sendable {
        private let client: OllamaHTTPClient
        public init(client: OllamaHTTPClient = OllamaHTTPClient()) { self.client = client }
        public func postGenerate(request: OllamaHTTPClient.GenerateRequest) async throws -> String {
            try await client.postGenerate(request: request)
        }
    }

    /// Model identifier per SUMM-03.
    public static let model = "llama-3.2:3b"

    private let clientShim: any Shim
    private let modelLoadGate: ModelLoadGate

    public init(
        clientShim: any Shim = DefaultShim(),
        modelLoadGate: ModelLoadGate = .shared
    ) {
        self.clientShim = clientShim
        self.modelLoadGate = modelLoadGate
    }

    public func summarize(_ transcript: String) async throws -> String {
        // SUMM-07: acquire gate before any Ollama call. Throws .busy when ASR held.
        let lease = try await modelLoadGate.acquire(.ollama)

        // Compute the result first, then release, then return. Releasing
        // inline (not via detached Task) keeps the lifecycle deterministic
        // for both production and tests — callers know that when summarize
        // returns or throws, the gate is no longer held.
        do {
            let prompt = Self.buildPrompt(transcript: transcript)
            let request = OllamaHTTPClient.GenerateRequest(
                model: Self.model,
                prompt: prompt,
                stream: false,
                keep_alive: 0
            )
            let response = try await clientShim.postGenerate(request: request)
            await lease.release()
            return response
        } catch {
            await lease.release()
            throw error
        }
    }

    /// Builds the user-prompt body by interpolating the transcript into the
    /// locked template stored in `summary-default.md`.
    ///
    /// Per SUMM-04: the system prompt is locked in the bundled resource file.
    /// The transcript is appended to the placeholder block per the template's
    /// `{transcript_text}` placeholder.
    static func buildPrompt(transcript: String) -> String {
        // Inline minimal prompt — the full template load happens at the
        // SummaryPromptBuilder layer (Task 3). The summarizer just needs a
        // workable user-turn that includes the transcript verbatim.
        "Transcript:\n\(transcript)\n\nSummarize this lecture as 5-8 bullet points of the key concepts and definitions a student needs to know."
    }
}
