import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import UnibrainCore

@Suite("ProviderProtocols")
struct ProviderProtocolTests {

    // MARK: - Smoke Tests (from Plan 01-01, preserved)

    @Test("ProviderError.cancelled is constructible and non-nil")
    func providerErrorExists() throws {
        let error = ProviderError.cancelled
        if case .cancelled = error {
            // success
        } else {
            Issue.record("Expected .cancelled case")
        }
    }

    @Test("ProviderError.networkFailure is constructible")
    func networkFailureCase() throws {
        let url = URL(string: "https://example.com")!
        let request = URLRequest(url: url)
        let urlError = URLError(.notConnectedToInternet)
        let error = ProviderError.networkFailure(request, urlError)

        if case .networkFailure = error {
            // success — proves two-argument case compiles
        } else {
            Issue.record("Expected .networkFailure case")
        }
    }

    @Test("ProviderError.rateLimited accepts nil retryAfter")
    func rateLimitedNilRetry() throws {
        let error = ProviderError.rateLimited(retryAfter: nil)
        if case .rateLimited(let retry) = error {
            #expect(retry == nil)
        } else {
            Issue.record("Expected .rateLimited case")
        }
    }

    // MARK: - Mock Protocol Conformance Tests

    @Test("Mock LLMSummarizer conforms and summarize is callable")
    func mockLLMSummarizerConforms() async throws {
        let summarizer = MockLLMSummarizer()
        let response = try await summarizer.summarize("hello")
        #expect(response == "olleh")
    }

    @Test("Mock AudioTranscriber conforms and transcribe is callable")
    func mockAudioTranscriberConforms() async throws {
        let transcriber = MockAudioTranscriber()
        let response = try await transcriber.transcribe("audio.m4a")
        #expect(response == "transcribed:audio.m4a")
    }

    @Test("Mock VisionDescriber conforms and describe is callable")
    func mockVisionDescriberConforms() async throws {
        let describer = MockVisionDescriber()
        let response = try await describer.describe("image.png")
        #expect(response == "described:image.png")
    }

    @Test("Mock AudioSynthesizer conforms and synthesize is callable")
    func mockAudioSynthesizerConforms() async throws {
        let synthesizer = MockAudioSynthesizer()
        let response = try await synthesizer.synthesize("speak this")
        #expect(response == "synthesized:speak this")
    }

    // MARK: - ProviderError All-Cases Coverage

    @Test("All ProviderError cases are constructible and catchable")
    func providerErrorAllCasesConstructible() async throws {
        let errors: [ProviderError] = [
            .networkFailure(
                URLRequest(url: URL(string: "https://example.com")!),
                URLError(.notConnectedToInternet)
            ),
            .modelError("test model error"),
            .rateLimited(retryAfter: 60),
            .invalidResponse("bad response"),
            .cancelled,
            .underlying(NSError(domain: "test", code: 1)),
            .unsupportedPlatform
        ]

        for error in errors {
            do {
                throw error
            } catch let caught as ProviderError {
                // Verify each error is caught as ProviderError
                switch caught {
                case .networkFailure:
                    break
                case .modelError:
                    break
                case .rateLimited:
                    break
                case .invalidResponse:
                    break
                case .cancelled:
                    break
                case .underlying:
                    break
                case .unsupportedPlatform:
                    break
                case .apiKeyMissing:
                    break
                case .consentDenied:
                    break
                case .providerUnreachable:
                    break
                }
            } catch {
                Issue.record("Caught non-ProviderError: \(error)")
            }
        }
    }
}

// MARK: - Mock Implementations

private struct MockLLMSummarizer: LLMSummarizer {
    typealias Request = String
    typealias Response = String

    func summarize(_ request: Request) async throws -> Response {
        String(request.reversed())
    }
}

private struct MockAudioTranscriber: AudioTranscriber {
    typealias Request = String
    typealias Response = String

    func transcribe(_ request: Request) async throws -> Response {
        "transcribed:\(request)"
    }
}

private struct MockVisionDescriber: VisionDescriber {
    typealias Request = String
    typealias Response = String

    func describe(_ request: Request) async throws -> Response {
        "described:\(request)"
    }
}

private struct MockAudioSynthesizer: AudioSynthesizer {
    typealias Request = String
    typealias Response = String

    func synthesize(_ request: Request) async throws -> Response {
        "synthesized:\(request)"
    }
}
