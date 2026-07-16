import Foundation

#if os(macOS)

/// Hybrid iCloud-aware file watcher for `_inbox/` (TRIG-01).
///
/// Per TRIG-01 and RESEARCH.md Pattern 4: wraps `NSMetadataQuery` to watch
/// `{vault}/_inbox/` for new files arriving via iCloud Drive sync. Combines:
/// 1. **Launch scan**: one-shot `FileManager.default.contentsOfDirectory` on
///    `start()` to catch files that arrived while the app was closed.
/// 2. **Live watch**: `NSMetadataQuery` with predicate scoped to the inbox
///    path, firing `.NSMetadataQueryDidUpdate` notifications when iCloud
///    adds or downloads files.
///
/// Per A1 (RESEARCH.md): the picked vault folder IS inside
/// `~/Library/Mobile Documents/com~apple~CloudDocs/`, so iCloud sync
/// metadata is present. The search scope uses the inbox path directly.
///
/// Per Pitfall 2: the predicate MUST use the actual inbox path. Test with
/// real iCloud-synced files on device.
public final class InboxWatcher: @unchecked Sendable {

    /// The inbox URL being watched.
    public let inboxURL: URL

    /// Called when new files are discovered (launch scan or live update).
    private let onNewFiles: @Sendable ([URL]) -> Void

    /// The underlying metadata query (nil when stopped).
    private var metadataQuery: NSMetadataQuery?

    /// Notification observer token for query updates.
    private var updateObserver: NSObjectProtocol?

    /// Creates a new inbox watcher.
    ///
    /// - Parameters:
    ///   - inboxURL: The `_inbox/` directory URL to watch.
    ///   - onNewFiles: Closure called with newly discovered file URLs.
    public init(
        inboxURL: URL,
        onNewFiles: @Sendable @escaping ([URL]) -> Void
    ) {
        self.inboxURL = inboxURL
        self.onNewFiles = onNewFiles
    }

    /// Starts watching the inbox directory.
    ///
    /// Per TRIG-01 hybrid: performs a launch scan FIRST (catches files that
    /// arrived while the app was closed), then starts the NSMetadataQuery
    /// for live monitoring.
    public func start() {
        // TRIG-01: launch scan — catch files from while app was closed
        performLaunchScan()

        // TRIG-01: live NSMetadataQuery watch
        let query = NSMetadataQuery()
        // Per A1: use path-based scope for external iCloud folders
        query.searchScopes = [inboxURL.path]
        query.predicate = NSPredicate(
            format: "%K BEGINSWITH %@",
            NSMetadataItemPathKey,
            inboxURL.path
        )
        query.sortDescriptors = [
            NSSortDescriptor(
                key: NSMetadataItemFSContentChangeDateKey,
                ascending: true
            )
        ]

        // Per Pattern 4: register for update notifications
        updateObserver = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.handleQueryUpdate(notification)
        }

        query.start()
        metadataQuery = query
    }

    /// Stops watching and removes observers.
    public func stop() {
        if let observer = updateObserver {
            NotificationCenter.default.removeObserver(observer)
            updateObserver = nil
        }
        metadataQuery?.stop()
        metadataQuery = nil
    }

    deinit {
        stop()
    }

    // MARK: - Private

    /// Performs a one-shot FileManager scan of the inbox directory.
    ///
    /// Per TRIG-01: catches files that arrived while the app was closed.
    /// Excludes the `_failed/` subdirectory and `.icloud` placeholder
    /// dot-prefix files (those are handled when they transition to real files).
    private func performLaunchScan() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Filter: real audio files only (not _failed/ dir, not .icloud placeholders)
            let audioFiles = contents.filter { url in
                url.pathExtension == "m4a" || url.pathExtension == "wav"
            }.sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey])
                    .contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }

            if !audioFiles.isEmpty {
                onNewFiles(audioFiles)
            }
        } catch {
            // Inbox directory doesn't exist yet — no files to scan.
            // The queue processor will create it when needed.
        }
    }

    /// Handles an NSMetadataQuery update notification.
    ///
    /// Per Pattern 4: extracts `NSMetadataQueryUpdateAddedItemsKey` from the
    /// notification, maps each `NSMetadataItem` to its URL via
    /// `NSMetadataItemURLKey`, and calls `onNewFiles`.
    private func handleQueryUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let addedURLs: [URL] = []

        // Per Pattern 4: extract newly added items
        if let addedItems = userInfo[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] {
            for item in addedItems {
                if let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL {
                    // Skip .icloud placeholders — they'll be handled by
                    // InboxFileDownloader when they transition to real files
                    if url.pathExtension == "icloud" { continue }
                    // Skip _failed/ directory contents
                    if url.path.contains("/_failed/") { continue }
                    addedURLs.append(url)
                }
            }
        }

        if !addedURLs.isEmpty {
            onNewFiles(addedURLs)
        }
    }
}

#endif // os(macOS)
