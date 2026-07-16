import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import UnibrainProviders
import UnibrainCore

@Test("OllamaHealthCheck returns true when /api/tags responds 200")
func healthCheckReturnsTrueWhenOllamaRunning() async throws {
    let stub = StubURLSession(responder: .success(body: #"{"models":[]}"#))
    let checker = OllamaHealthCheck(session: stub, timeout: 2.0)
    let result = await checker.check()
    #expect(result == true)
}

@Test("OllamaHealthCheck returns false when connection refused")
func healthCheckReturnsFalseWhenOllamaNotRunning() async throws {
    let stub = StubURLSession(responder: .connectionFailure)
    let checker = OllamaHealthCheck(session: stub, timeout: 2.0)
    let result = await checker.check()
    #expect(result == false)
}

@Test("OllamaHealthCheck returns false on timeout")
func healthCheckReturnsFalseOnTimeout() async throws {
    let stub = StubURLSession(responder: .timedOut)
    let checker = OllamaHealthCheck(session: stub, timeout: 2.0)
    let result = await checker.check()
    #expect(result == false)
}

@Test("OllamaHTTPClient.postGenerate returns decoded response on 200")
func postGenerateReturnsResponseOn200() async throws {
    let responseBody = #"{"response":"summary text","done":true}"#
    let stub = StubURLSession(responder: .success(body: responseBody))
    let client = OllamaHTTPClient(session: stub)
    let request = OllamaHTTPClient.GenerateRequest(
        model: "llama-3.2:3b",
        prompt: "test prompt",
        stream: false,
        keep_alive: 0
    )
    let result = try await client.postGenerate(request: request)
    #expect(result == "summary text")
}

@Test("OllamaHTTPClient throws ProviderError on non-200 response")
func postGenerateThrowsOnNon200() async throws {
    let stub = StubURLSession(responder: .status(code: 500, body: "internal error"))
    let client = OllamaHTTPClient(session: stub)
    let request = OllamaHTTPClient.GenerateRequest(
        model: "llama-3.2:3b",
        prompt: "test prompt",
        stream: false,
        keep_alive: 0
    )
    await #expect(throws: ProviderError.self) {
        _ = try await client.postGenerate(request: request)
    }
}
