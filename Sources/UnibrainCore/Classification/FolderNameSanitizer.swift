import Foundation

/// Sanitizes strings for safe use as macOS/iOS folder names.
///
/// Per C-05: Pure static function. Strips characters unsafe on macOS/iOS
/// filesystems, collapses whitespace, enforces max length.
///
/// **STUB:** This is a temporary implementation for Plan 01. Plan 03 will
/// implement full sanitization with regex whitespace collapsing and
/// path traversal protection (T-2-01 risk accepted).
public struct FolderNameSanitizer {

    /// Sanitizes a string for safe use as a folder name.
    ///
    /// - Parameter folderName: Raw string (e.g., from calendar event title).
    /// - Returns: Sanitized string safe for filesystem use.
    public static func sanitize(folderName: String) -> String {
        var sanitized = folderName

        // Replace reserved characters with space
        sanitized = sanitized
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        // Strip leading dots (hidden files)
        while sanitized.hasPrefix(".") {
            sanitized.removeFirst()
        }

        // Collapse whitespace runs to single space
        sanitized = sanitized.split(separator: " ").joined(separator: " ")

        // Trim leading/trailing whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)

        // Enforce max length (100 characters)
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100)).trimmingCharacters(in: .whitespaces)
        }

        return sanitized.isEmpty ? "Untitled Course" : sanitized
    }
}
