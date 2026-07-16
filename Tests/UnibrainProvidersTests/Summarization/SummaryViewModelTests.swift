import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

@Suite
enum SummaryViewModelTests {

    @Test("generateSummary returns summary when Ollama available and enabled")
    static func generateSummarySucceeds() async throws {
        let vm = SummaryViewModel(
            summarizer: OllamaLLMSummarizer(
                clientShim: StubOllamaHTTPClient(response: "Bullets"),
                modelLoadGate: ModelLoadGate()
            ),
            healthCheck: StubHealthCheck(result: true)
        )
        vm.isEnabled = true
        vm.selectedProvider = .ollama

        let context = CourseContext(courseName: "CS101", professorName: "Turing", lectureDate: Date())
        let result = try await vm.generateSummary(transcript: "Lecture transcript.", courseContext: context)
        #expect(result == "Bullets")
    }

    @Test("generateSummary throws when summarization disabled")
    static func generateSummaryThrowsWhenDisabled() async throws {
        let vm = SummaryViewModel(
            summarizer: OllamaLLMSummarizer(
                clientShim: StubOllamaHTTPClient(),
                modelLoadGate: ModelLoadGate()
            ),
            healthCheck: StubHealthCheck(result: true)
        )
        vm.isEnabled = false
        vm.selectedProvider = .ollama

        let context = CourseContext(courseName: "CS101", professorName: nil, lectureDate: Date())
        do {
            _ = try await vm.generateSummary(transcript: "x", courseContext: context)
            #expect(Bool(false), "Expected ProviderError.cancelled")
        } catch let err as ProviderError {
            if case .cancelled = err {
                // expected
            } else {
                #expect(Bool(false), "Expected .cancelled, got \(err)")
            }
        }
    }

    @Test("generateSummary throws when Ollama health check fails")
    static func generateSummaryThrowsWhenUnreachable() async throws {
        let vm = SummaryViewModel(
            summarizer: OllamaLLMSummarizer(
                clientShim: StubOllamaHTTPClient(),
                modelLoadGate: ModelLoadGate()
            ),
            healthCheck: StubHealthCheck(result: false)
        )
        vm.isEnabled = true
        vm.selectedProvider = .ollama

        let context = CourseContext(courseName: "CS101", professorName: nil, lectureDate: Date())
        do {
            _ = try await vm.generateSummary(transcript: "x", courseContext: context)
            #expect(Bool(false), "Expected ProviderError.providerUnreachable")
        } catch let err as ProviderError {
            if case .providerUnreachable = err {
                // expected
            } else {
                #expect(Bool(false), "Expected .providerUnreachable, got \(err)")
            }
        }
    }
}

@Suite
enum RegenerateSummaryUseCaseTests {

    @Test("execute replaces ## Summary section only")
    static func executeReplacesSummaryOnly() async throws {
        let originalNote = """
        # Lecture

        Body of lecture.

        ## Summary

        <!-- unibrain:summary-start -->
        - Old bullet
        <!-- unibrain:summary-end -->
        """

        let usecase = RegenerateSummaryUseCase(
            summarizer: OllamaLLMSummarizer(
                clientShim: StubOllamaHTTPClient(response: "- Fresh bullet"),
                modelLoadGate: ModelLoadGate()
            ),
            healthCheck: StubHealthCheck(result: true)
        )

        let context = CourseContext(courseName: "CS101", professorName: nil, lectureDate: Date())
        let updated = try await usecase.execute(
            note: originalNote,
            transcript: "x",
            courseContext: context
        )

        #expect(updated.contains("# Lecture"))
        #expect(updated.contains("Body of lecture."))
        #expect(updated.contains("- Fresh bullet"))
        #expect(!updated.contains("- Old bullet"))
    }
}

/// Test double for OllamaHealthCheck returning a fixed result.
private struct StubHealthCheck: HealthChecking {
    let result: Bool
    func check() async -> Bool { result }
}
