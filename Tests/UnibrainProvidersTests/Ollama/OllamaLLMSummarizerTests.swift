import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

/// Test double for OllamaHTTPClient returning canned responses.
public final class StubOllamaHTTPClient: OllamaLLMSummarizer.Shim, @unchecked Sendable {
    public let stubbedResponse: String
    public let stubbedError: Error?
    public private(set) var capturedRequests: [OllamaHTTPClient.GenerateRequest] = []

    public init(response: String = "summary", error: Error? = nil) {
        self.stubbedResponse = response
        self.stubbedError = error
    }

    public func postGenerate(request: OllamaHTTPClient.GenerateRequest) async throws -> String {
        capturedRequests.append(request)
        if let stubbedError { throw stubbedError }
        return stubbedResponse
    }
}

@Suite
enum OllamaLLMSummarizerTests {

    @Test("OllamaLLMSummarizer returns response from OllamaHTTPClient",
          arguments: ["Mock summary", "ok", "another response"])
    static func summarizerReturnsOllamaResponse(expected: String) async throws {
        let stub = StubOllamaHTTPClient(response: expected)
        let summarizer = OllamaLLMSummarizer(clientShim: stub, modelLoadGate: ModelLoadGate())
        let result = try await summarizer.summarize("transcript text")
        #expect(result == expected)
        #expect(stub.capturedRequests.count == 1)
    }

    @Test("Request encodes model as llama-3.2:3b with keep_alive=0")
    static func requestEncodesModelAndKeepAlive() async throws {
        let stub = StubOllamaHTTPClient(response: "ok")
        let summarizer = OllamaLLMSummarizer(clientShim: stub, modelLoadGate: ModelLoadGate())
        _ = try await summarizer.summarize("transcript")
        let request = try #require(stub.capturedRequests.first)
        #expect(request.model == "llama-3.2:3b")
        #expect(request.keep_alive == 0)
        #expect(request.stream == false)
    }

    @Test("Summarizer accepts transcript and embeds it in prompt")
    static func summarizerEmbedsTranscriptInPrompt() async throws {
        let stub = StubOllamaHTTPClient(response: "ok")
        let summarizer = OllamaLLMSummarizer(clientShim: stub, modelLoadGate: ModelLoadGate())
        _ = try await summarizer.summarize("UNIQUE_TRANSCRIPT_TOKEN")
        let request = try #require(stub.capturedRequests.first)
        #expect(request.prompt.contains("UNIQUE_TRANSCRIPT_TOKEN"))
    }

    @Test("Summarizer throws ModelLoadGateError.busy when ASR is held (SUMM-07)",
          .serialized)
    static func summarizerThrowsBusyWhenASRHeld() async throws {
        // Use the shared singleton — this is the production code path.
        // Drain any leftover state first.
        await ModelLoadGate.shared.release(.asr)
        await ModelLoadGate.shared.release(.ollama)

        let asrLease = try await ModelLoadGate.shared.acquire(.asr)
        defer { Task { await asrLease.release() } }

        let stub = StubOllamaHTTPClient(response: "ok")
        let summarizer = OllamaLLMSummarizer(clientShim: stub, modelLoadGate: ModelLoadGate.shared)

        do {
            _ = try await summarizer.summarize("transcript")
            #expect(Bool(false), "Expected summarize() to throw ModelLoadGateError.busy")
        } catch let err as ModelLoadGateError {
            if case .busy(let current) = err {
                #expect(current == .asr)
            } else {
                #expect(Bool(false), "Expected .busy case, got \(err)")
            }
        }
    }
}
