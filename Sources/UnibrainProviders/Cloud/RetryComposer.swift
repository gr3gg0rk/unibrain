import Foundation
import UnibrainCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provider-inner retry with exponential backoff per CF-03.
///
/// Per CLOUD-10: cloud provider clients wrap their HTTP call in
/// `RetryComposer.withRetry(maxRetries: 3)`. The composer retries transient
/// failures (`.rateLimited`, `.networkFailure`, `.modelError`) using the
/// delays `[2s, 8s, 30s]` per the CF-03 exponential backoff schedule.
///
/// Per T-06-15 (mitigate): the composer always sleeps between retries — no
/// tight retry loop. The sleeper is injectable so tests can capture delay
/// timing without real `Task.sleep`.
///
/// Queue-outer retry is a separate concern handled by the Phase 5 InboxQueue
/// boundary (not in this plan).
public struct RetryComposer: Sendable {
    /// Delay schedule between attempts (seconds). Per CF-03: [2, 8, 30].
    public let delays: [TimeInterval]

    /// Sleep function (nanoseconds). Defaults to `Task.sleep(nanoseconds:)`.
    /// Tests inject a capture closure to verify timing without real waits.
    public let sleeper: @Sendable (UInt64) async -> Void

    /// Creates a composer with an explicit delay schedule and sleeper.
    ///
    /// - Parameters:
    ///   - delays: Per-attempt delay in seconds. Index 0 = delay before
    ///     attempt 1 (after attempt 0 fails). Unused indexes are ignored
    ///     if `maxRetries` is smaller than `delays.count`.
    ///   - sleeper: Closure invoked with nanoseconds to sleep.
    public init(
        delays: [TimeInterval] = [2, 8, 30],
        sleeper: @escaping @Sendable (UInt64) async -> Void = { ns in
            try? await Task.sleep(nanoseconds: ns)
        }
    ) {
        self.delays = delays
        self.sleeper = sleeper
    }

    /// Runs `operation` with up to `maxRetries` attempts.
    ///
    /// Per CF-03: default 3 retries. On transient failure, sleeps per the
    /// delay schedule, then retries. After exhausting retries, throws the
    /// last error.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of attempts (including the first).
    ///   - operation: Closure receiving the current attempt index (0-based).
    /// - Returns: The result of a successful operation call.
    /// - Throws: The last error if all attempts fail; or any non-retryable
    ///   error propagated as-is.
    public func withRetry<T>(
        maxRetries: Int = 3,
        operation: @escaping @Sendable (Int) async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                return try await operation(attempt)
            } catch let error as ProviderError {
                lastError = error

                // If this was the last attempt, don't sleep — just exit loop.
                if attempt + 1 >= maxRetries { break }

                let delaySeconds = self.delay(for: error, attempt: attempt)
                let delayNs = UInt64(delaySeconds * 1_000_000_000)
                await sleeper(delayNs)
            }
        }
        // We only reach here if all retries failed. The lastError is
        // guaranteed to be set because maxRetries >= 1.
        throw lastError!
    }

    /// Computes the delay for a given error and attempt index.
    ///
    /// Per CF-03: exponential backoff schedule [2, 8, 30] seconds.
    /// Per 06-AI-SPEC §"Failure Recovery": when `.rateLimited` provides a
    /// `retryAfter`, that value overrides the schedule.
    private func delay(for error: ProviderError, attempt: Int) -> TimeInterval {
        if case .rateLimited(let retryAfter?) = error {
            return retryAfter
        }
        let idx = min(attempt, delays.count - 1)
        return delays[idx]
    }
}
