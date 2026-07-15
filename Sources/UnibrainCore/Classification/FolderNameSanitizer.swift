import Foundation

/// Sanitizes strings for safe use as macOS/iOS folder names.
///
/// Per C-05: Pure static function. Strips characters unsafe on macOS/iOS
/// filesystems, collapses whitespace via regex, enforces max length.
///
/// Per T-2-01 (mitigate): Prevents path traversal attacks (../../etc/passwd)
/// by stripping reserved characters (/ and :) before any filesystem use.
public struct FolderNameSanitizer {

    /// Maximum allowed folder name length (per C-05).
    static let maxLength = 100

    /// Default fallback name when sanitization produces empty result.
    static let defaultName = "Untitled Course"

    /// Sanitizes a string for safe use as a folder name.
    ///
    /// Per C-05, applies these steps in order:
    /// 1. Replace reserved characters (`/`, `:`, `\n`, `\r`) with space
    /// 2. Strip leading dots (prevents hidden-file creation on macOS/iOS)
    /// 3. Collapse whitespace runs to single space via `\s+` regex
    /// 4. Trim leading/trailing whitespace
    /// 5. Enforce max length (100 characters)
    /// 6. Return `"Untitled Course"` if empty after sanitization
    ///
    /// Per T-2-01: Path traversal vectors like `../../etc/passwd` are neutralized
    /// because `/` is replaced with space in step 1, preventing directory creation.
    ///
    /// - Parameter folderName: Raw string (e.g., from calendar event title).
    /// - Returns: Sanitized string safe for filesystem use.
    public static func sanitize(folderName: String) -> String {
        // Step 1: Replace reserved characters with space
        var sanitized = folderName
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        // Step 2: Strip leading dots (prevents hidden-file creation)
        while sanitized.hasPrefix(".") {
            sanitized.removeFirst()
        }

        // Step 3: Collapse whitespace runs to single space (Swift 6 regex literal)
        if let regex = try? Regex(#"\s+"#) {
            sanitized = sanitized.replacing(regex, with: " ")
        }

        // Step 4: Trim leading/trailing whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)

        // Step 5: Enforce max length
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }

        // Step 6: Return default if empty
        return sanitized.isEmpty ? defaultName : sanitized
    }
}
