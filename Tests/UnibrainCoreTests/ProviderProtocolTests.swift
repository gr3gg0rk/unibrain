import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import UnibrainCore

@Suite("ProviderProtocols")
struct ProviderProtocolTests {

    @Test("ProviderError.cancelled is constructible and non-nil")
    func providerErrorExists() throws {
        let error = ProviderError.cancelled
        // The fact that this line compiles proves the enum and its cases exist.
        // We use a pattern match to verify it is the cancelled case.
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
}
