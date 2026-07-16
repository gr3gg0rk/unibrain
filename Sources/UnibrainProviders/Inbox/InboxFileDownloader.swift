import Foundation

#if os(macOS)

/// Handles `.icloud` placeholder detection and active download (IC-04).
///
/// Per IC-04: when macOS detects an `_inbox/` file that is a `.icloud`
/// placeholder (not-yet-downloaded), this component triggers
/// `URL.startDownloadingUbiquitousItem()` to force iCloud to fetch the
/// file, polls `URLResourceKey.ubiquitousItemDownloadingStatusKey` until
/// `.current`, then returns so the pipeline can proceed.
///
/// Per Pitfall 5: this runs BEFORE the file enters the pipeline — once
/// downloaded, the existing ``NSFileCoordinatorNoteWriter`` processes it
/// normally without hitting the Phase 2 A-03 ``iCloudPlaceholder`` error.
public final class InboxFileDownloader: Sendable {

    /// Default polling timeout in seconds (IC-04).
    public static let defaultTimeout: TimeInterval = 120

    /// Polling interval in seconds (IC-04).
    public static let pollInterval: TimeInterval = 2

    /// Timeout for download polling.
    private let timeout: TimeInterval

    /// Creates a new inbox file downloader.
    ///
    /// - Parameter timeout: Maximum seconds to wait for download (default: 120).
    public init(timeout: TimeInterval = InboxFileDownloader.defaultTimeout) {
        self.timeout = timeout
    }

    /// File status as determined by ``checkFileStatus(at:)``.
    public enum FileStatus: Sendable, Equatable {
        /// The file is a real downloaded file — proceed with pipeline.
        case ready
        /// The file is a `.icloud` placeholder — call ``startDownload(at:)``
        /// to trigger ubiquitous item download.
        case downloadNeeded
    }

    /// Checks whether a URL is a real file or a `.icloud` placeholder.
    ///
    /// Per IC-04 and Pitfall 5: detects `.icloud` placeholder files by
    /// examining the path extension. `.icloud` placeholders have names
    /// like `.{original-filename}.icloud` (e.g., `.iphone-...m4a.icloud`).
    ///
    /// - Parameter url: The URL to check.
    /// - Returns: `.ready` if the file is a real downloaded file;
    ///   `.downloadNeeded` if the path has a `.icloud` extension.
    public func checkFileStatus(at url: URL) -> FileStatus {
        // Per Pitfall 5: .icloud placeholders have pathExtension == "icloud"
        // and the real filename is prefixed with a dot:
        //   .iphone-20260915T101530-a3f8.m4a.icloud
        if url.pathExtension == "icloud" {
            return .downloadNeeded
        }

        // Real file — check if it exists on disk
        if FileManager.default.fileExists(atPath: url.path) {
            return .ready
        }

        // File doesn't exist and isn't a .icloud placeholder.
        // This could be a file that hasn't synced yet. Return .downloadNeeded
        // so the caller can attempt to trigger a download.
        return .downloadNeeded
    }

    /// Triggers an iCloud download for a `.icloud` placeholder and polls
    /// until the file is downloaded or the timeout expires.
    ///
    /// Per IC-04: calls `URL.startDownloadingUbiquitousItem()` via
    /// FileManager, then polls `URLResourceKey.ubiquitousItemDownloadingStatusKey`
    /// every 2 seconds up to the timeout (default 120s).
    ///
    /// - Parameter url: The placeholder URL (the `.icloud` file path).
    /// - Throws: ``InboxError/downloadTimedOut`` if the file does not reach
    ///   `.current` download status within the timeout.
    public func startDownload(at url: URL) async throws {
        // Per IC-04: trigger the ubiquitous item download.
        // The URL must be inside an iCloud-synced location.
        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        } catch {
            // If startDownloading fails (e.g., not a ubiquitous item, or
            // already downloaded), check if the file is now available.
            if FileManager.default.fileExists(atPath: url.path) {
                return
            }
            // Per Pitfall 5: the URL might be the placeholder path; check
            // if the real file (without .icloud extension) exists.
            let realPath = realFilePath(for: url)
            if let realPath, FileManager.default.fileExists(atPath: realPath.path) {
                return
            }
            throw InboxError.downloadTimedOut(url)
        }

        // Poll for download completion (IC-04)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))

            // Check if the real file has appeared on disk
            let realPath = realFilePath(for: url)
            if let realPath, FileManager.default.fileExists(atPath: realPath.path) {
                return
            }

            // Also check ubiquitous item downloading status
            do {
                let resourceValues = try url.resourceValues(
                    forKeys: [.ubiquitousItemDownloadingStatusKey]
                )
                if let status = resourceValues.ubiquitousItemDownloadingStatus,
                   status == .current {
                    return
                }
            } catch {
                // Resource value fetch failed — continue polling
            }
        }

        throw InboxError.downloadTimedOut(url)
    }

    /// Resolves the real file path from a `.icloud` placeholder path.
    ///
    /// Per Pitfall 5: `.icloud` placeholders are named
    /// `.{original-filename}.icloud` in the same directory as the real file.
    /// This strips the leading dot and `.icloud` extension to find the real path.
    ///
    /// - Parameter placeholderURL: The `.icloud` placeholder URL.
    /// - Returns: The real file URL if parseable, nil otherwise.
    public func realFilePath(for placeholderURL: URL) -> URL? {
        let filename = placeholderURL.lastPathComponent
        guard filename.hasPrefix(".") && filename.hasSuffix(".icloud") else {
            return nil
        }
        // Strip leading "." and trailing ".icloud"
        let stripped = String(filename.dropFirst().dropLast(6))
        return placeholderURL.deletingLastPathComponent().appendingPathComponent(stripped)
    }
}

#endif // os(macOS)
