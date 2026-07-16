import Foundation
import UnibrainCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Conformance to ``LLMSummarizer`` backed by Z.ai GLM Chat Completions.
///
/// Per CLOUD-06: uses `glm-4.6` via `POST /api/paas/v4/chat/completions`.
/// OpenAI-compatible auth (Bearer token) per 06-CONTEXT.md.
public struct ZaiLLMSummarizer: LLMSummarizer, Sendable {
    public typealias Request = SummarizerRequest
    public typealias Response = SummarizerResponse

    public static let model = "glm-4.6"
    public static let baseURLString = "https://api.z.ai/api/paas/v4/chat/completions"
    public static let providerHost = "api.z.ai"

    private let client: OpenAICompatibleClient

    public init(
        apiKeyStore: any APIKeyStoring,
        consentStore: any ConsentStoring,
        reachability: any ReachabilityProbe = TCPReachability(),
        retry: RetryComposer = RetryComposer(),
        session: any HTTPSession = URLSessionAdapter()
    ) {
        self.client = OpenAICompatibleClient(
            provider: .zai,
            baseURLString: Self.baseURLString,
            model: Self.model,
            providerHost: Self.providerHost,
            apiKeyStore: apiKeyStore,
            consentStore: consentStore,
            reachability: reachability,
            retry: retry,
            session: session
        )
    }

    public func summarize(_ request: Request) async throws -> Response {
        try await client.summarize(request)
    }
}
