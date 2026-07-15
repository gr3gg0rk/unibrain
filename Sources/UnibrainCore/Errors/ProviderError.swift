import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Shared error type for all provider conformances.
///
/// Per D-16: every provider (local and cloud) throws ``ProviderError``.
/// This enum is intentionally NOT declared `Sendable` because the
/// `underlying(any Error)` case holds a non-Sendable existential.
/// ProviderError instances are thrown and caught within a single
/// task/actor context — they are never passed across concurrency boundaries.
///
/// Threat mitigation (T-01-04): structured enum cases prevent raw backend
/// error strings from leaking internal state to callers or users.
public enum ProviderError: Error {
    /// Network request failed (e.g., connection refused, timeout).
    case networkFailure(URLRequest, URLError)
    /// The model returned an error or produced invalid output.
    case modelError(String)
    /// The provider rate-limited the request. `retryAfter` is the
    /// server-suggested wait time, if provided.
    case rateLimited(retryAfter: TimeInterval?)
    /// The response could not be parsed or was unexpected.
    case invalidResponse(String)
    /// The request was cancelled (e.g., user tapped stop).
    case cancelled
    /// An underlying error from the backend that does not fit other cases.
    case underlying(any Error)

    /// The current platform does not support this provider.
    /// Used when a macOS-version-gated API is unavailable.
    case unsupportedPlatform
}
