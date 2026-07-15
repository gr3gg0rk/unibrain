import Foundation

/// Errors that can occur during model download and verification.
///
/// Per TRAN-02: model download includes SHA256 checksum verification.
/// Per P-18: failures retry once, then surface as non-blocking warnings.
public enum ModelDownloadError: Error, Sendable, Equatable {
    /// The downloaded file's SHA256 hash does not match the expected value.
    case checksumMismatch(expected: String, actual: String)

    /// The download request failed (network error, server error, etc.).
    case downloadFailed(description: String)

    /// The downloaded data could not be written to the storage path.
    case writeFailed

    /// All retry attempts have been exhausted.
    /// Contains a description of the last error encountered.
    case retryExhausted(lastError: String)
}
