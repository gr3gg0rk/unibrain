import Foundation
import UnibrainCore

/// Regenerates the `## Summary` section of a note by invoking
/// ``SummaryViewModel`` and replacing the marked block via
/// ``SummarySectionEditor``.
///
/// Per OLL-04: Regenerate replaces only the summary section, preserving any
/// edits Angelica made to the transcript above.
public struct RegenerateSummaryUseCase: Sendable {
    private let summarizer: OllamaLLMSummarizer
    private let healthCheck: any HealthChecking

    public init(
        summarizer: OllamaLLMSummarizer,
        healthCheck: any HealthChecking
    ) {
        self.summarizer = summarizer
        self.healthCheck = healthCheck
    }

    /// Regenerates the summary section of `note`.
    ///
    /// - Parameters:
    ///   - note: Existing lecture note (with `## Summary` block present).
    ///   - transcript: Transcript text to summarize.
    ///   - courseContext: Course metadata for the prompt builder.
    /// - Returns: Updated note with the summary block replaced.
    public func execute(
        note: String,
        transcript: String,
        courseContext: CourseContext
    ) async throws -> String {
        let reachable = await healthCheck.check()
        guard reachable else {
            throw ProviderError.providerUnreachable(host: "localhost:11434")
        }
        let newSummary = try await summarizer.summarize(transcript)
        // CLOUD-13 / CON-04: inject audit trail fields into frontmatter
        // so AuditTrailStore can classify the note as summarized.
        var updatedNote = SummarySectionEditor.replaceSummary(note: note, newSummary: newSummary)
        updatedNote = SummarySectionEditor.injectAuditFields(
            note: updatedNote,
            summaryModel: OllamaLLMSummarizer.model,
            llmProvider: "ollama"
        )
        return updatedNote
    }
}
