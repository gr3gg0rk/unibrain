import Foundation

/// Protocol for single-shot image/scene description (vision-to-text).
///
/// Per D-15: standalone protocol with no common ancestor.
/// Per D-17: single-shot only in Phase 1.
public protocol VisionDescriber {
    associatedtype Request
    associatedtype Response

    /// Describe the visual content of the given request payload.
    ///
    /// - Parameter request: Provider-specific request payload (e.g., image data).
    /// - Returns: Provider-specific response payload (e.g., description text).
    /// - Throws: ``ProviderError`` on failure.
    func describe(_ request: Request) async throws -> Response
}
