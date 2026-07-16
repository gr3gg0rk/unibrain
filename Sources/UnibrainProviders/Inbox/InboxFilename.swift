import Foundation

/// Generates IC-03-compliant filenames for `_inbox/` audio files.
///
/// Per IC-03: Filenames follow the pattern
/// `{source}-{YYYYMMDDTHHMMSS}-{shortUUID}.m4a`.
/// Example: `iphone-20260915T101530-a3f8.m4a`.
///
/// ISO 8601 timestamp guarantees chronological sortability.
/// Source prefix identifies origin at a glance (iphone/macos).
/// Short UUID suffix guarantees uniqueness even if two devices start
/// recording in the same second.
///
/// Cross-platform — no #if guards needed. Pure value type.
public enum InboxFilename: Sendable {

    /// Generates an IC-03-compliant inbox filename.
    ///
    /// - Parameters:
    ///   - source: The recording source prefix (e.g., "iphone", "macos").
    ///   - timestamp: The recording start timestamp.
    ///   - uuidSuffix: A 4-character hex string for uniqueness.
    /// - Returns: The filename string (e.g., "iphone-20260915T101530-a3f8.m4a").
    public static func generate(
        source: String,
        timestamp: Date,
        uuidSuffix: String
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        let timestampString = formatter.string(from: timestamp)
        return "\(source)-\(timestampString)-\(uuidSuffix).m4a"
    }
}
