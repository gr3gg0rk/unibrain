import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import UnibrainCore
@testable import UnibrainProviders

@Suite
enum RetryComposerTests {

    @Test("RetryComposer succeeds on first attempt without delay")
    static func succeedsOnFirstAttempt() async throws {
        let composer = RetryComposer(delays: [2, 8, 30], sleeper: { _ in })

        let result = try await composer.withRetry(maxRetries: 3) { attempt in
            return "ok-\(attempt)"
        }

        #expect(result == "ok-0")
    }

    @Test("RetryComposer retries on rateLimited then succeeds")
    static func retriesOnRateLimitedThenSucceeds() async throws {
        let capturedDelays = ActorDelayCapture()
        let sleeper: @Sendable (UInt64) async -> Void = { ns in
            await capturedDelays.record(ns)
        }
        let composer = RetryComposer(delays: [2, 8, 30], sleeper: sleeper)

        let result = try await composer.withRetry(maxRetries: 3) { attempt in
            if attempt < 1 {
                throw ProviderError.rateLimited(retryAfter: nil)
            }
            return "recovered"
        }

        #expect(result == "recovered")
        let delays = await capturedDelays.delays
        #expect(delays.count == 1)
        #expect(delays[0] == 2_000_000_000) // 2 seconds in ns
    }

    @Test("RetryComposer retries on networkFailure with exponential backoff")
    static func retriesOnNetworkFailureWithBackoff() async throws {
        let capturedDelays = ActorDelayCapture()
        let sleeper: @Sendable (UInt64) async -> Void = { ns in
            await capturedDelays.record(ns)
        }
        let composer = RetryComposer(delays: [2, 8, 30], sleeper: sleeper)

        _ = try? await composer.withRetry(maxRetries: 3) { attempt in
            throw ProviderError.networkFailure(
                URLRequest(url: URL(string: "https://example.com")!),
                URLError(.timedOut)
            )
        }

        let delays = await capturedDelays.delays
        #expect(delays.count == 2) // 3 attempts => 2 sleeps
        #expect(delays[0] == 2_000_000_000)
        #expect(delays[1] == 8_000_000_000)
    }

    @Test("RetryComposer uses retryAfter from rateLimited error when present")
    static func usesRetryAfterFromError() async throws {
        let capturedDelays = ActorDelayCapture()
        let sleeper: @Sendable (UInt64) async -> Void = { ns in
            await capturedDelays.record(ns)
        }
        let composer = RetryComposer(delays: [2, 8, 30], sleeper: sleeper)

        _ = try? await composer.withRetry(maxRetries: 3) { _ in
            throw ProviderError.rateLimited(retryAfter: 5.0)
        }

        let delays = await capturedDelays.delays
        // 3 attempts => 2 sleeps (between attempts 0->1 and 1->2)
        #expect(delays.count == 2)
        // retryAfter (5s) overrides exponential backoff for all attempts
        for ns in delays {
            #expect(ns == 5_000_000_000)
        }
    }

    @Test("RetryComposer throws final error after all attempts fail")
    static func throwsFinalErrorAfterAllAttemptsFail() async throws {
        let composer = RetryComposer(delays: [0, 0, 0], sleeper: { _ in })

        do {
            _ = try await composer.withRetry(maxRetries: 3) { _ in
                throw ProviderError.modelError("permanent")
            }
            #expect(Bool(false), "Expected throw")
        } catch let err as ProviderError {
            if case .modelError(let msg) = err {
                #expect(msg == "permanent")
            } else {
                #expect(Bool(false), "Expected .modelError, got \(err)")
            }
        }
    }
}

// MARK: - Test Helpers

actor ActorDelayCapture {
    private(set) var delays: [UInt64] = []
    func record(_ ns: UInt64) { delays.append(ns) }
}
