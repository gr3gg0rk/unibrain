import Foundation

/// Validation errors thrown by ``FrontmatterSchema.validate()``.
///
/// Per T-2-03 (mitigate): validate() ensures required fields are non-empty
/// before emitting a note, preventing null/empty frontmatter from reaching
/// the vault. This enum provides structured error types for callers to
/// pattern-match on.
///
/// Follows the ProviderError pattern (D-16) — structured cases prevent
/// raw error strings from leaking to the UI.
public enum FrontmatterValidationError: Error, Sendable, Equatable {
    /// A required string field is empty.
    /// - Parameter field: The CodingKey name of the empty field (e.g., "course").
    case emptyField(String)
    /// The duration_seconds field is not a positive value.
    /// - Parameter duration: The invalid duration value.
    case invalidDuration(Int)
    /// A required field is missing entirely (nil or empty array).
    /// - Parameter field: The CodingKey name of the missing field.
    case missingRequiredField(String)
}
