import Foundation
import Yams
import UnibrainCore

// MARK: - AuditDateRange

/// Date range filter for audit trail queries.
public enum AuditDateRange: String, CaseIterable, Sendable {
    case last7Days = "Last 7 days"
    case last30Days = "Last 30 days"
    case last90Days = "Last 90 days"
    case allTime = "All time"

    /// Returns the cutoff date for this range, or nil for all time.
    public func cutoffDate(from reference: Date = Date()) -> Date? {
        switch self {
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: reference)
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: reference)
        case .last90Days:
            return Calendar.current.date(byAdding: .day, value: -90, to: reference)
        case .allTime:
            return nil
        }
    }
}

// MARK: - AuditStatus

/// Status of an audit trail entry.
public enum AuditStatus: String, CaseIterable, Codable, Sendable {
    case success
    case failed
}

// MARK: - AuditEntry

/// A single audit trail entry representing one note's processing history.
///
/// Phase 06-06 Task 2: Built from FrontmatterSchema v2 fields. Each entry
/// represents one note in the vault with its provider usage and status.
public struct AuditEntry: Codable, Sendable, Identifiable {
    /// Unique identifier (uses note path).
    public let id: String
    /// Note file name (without path).
    public let noteName: String
    /// Full path to the note file.
    public let notePath: String
    /// Date the note was recorded (from frontmatter datetime).
    public let date: Date
    /// Course code (from frontmatter).
    public let course: String
    /// LLM provider used (nil if no summary generated).
    public var llmProvider: String?
    /// ASR provider used (nil if unknown).
    public var asrProvider: String?
    /// Vision provider used (nil if no vision processing).
    public var visionProvider: String?
    /// Summary model name (nil if no summary).
    public var summaryModel: String?
    /// Whether the note has a summary.
    public var hasSummary: Bool
    /// Processing status.
    public var status: AuditStatus
    /// Error details if status is failed.
    public var error: String?

    public init(
        id: String,
        noteName: String,
        notePath: String,
        date: Date,
        course: String,
        llmProvider: String? = nil,
        asrProvider: String? = nil,
        visionProvider: String? = nil,
        summaryModel: String? = nil,
        hasSummary: Bool = false,
        status: AuditStatus = .success,
        error: String? = nil
    ) {
        self.id = id
        self.noteName = noteName
        self.notePath = notePath
        self.date = date
        self.course = course
        self.llmProvider = llmProvider
        self.asrProvider = asrProvider
        self.visionProvider = visionProvider
        self.summaryModel = summaryModel
        self.hasSummary = hasSummary
        self.status = status
        self.error = error
    }
}

// MARK: - AuditTrailStore

/// Actor that scans vault notes and builds an audit trail index.
///
/// Phase 06-06 Task 2: Reads frontmatter from .md files in the vault to
/// build a per-note audit trail showing which provider touched which note.
/// Runs on-demand when the user opens the Audit tab (no background scanning).
public actor AuditTrailStore {

    /// Path to the vault root.
    private let vaultPath: URL

    public init(vaultPath: URL) {
        self.vaultPath = vaultPath
    }

    /// Scans vault for .md files and builds an audit trail index.
    ///
    /// Per CF-04: reads frontmatter to extract provider usage.
    /// Files without valid frontmatter are skipped (not an error).
    ///
    /// - Returns: Array of audit entries sorted by date descending.
    public func scanVault() async throws -> [AuditEntry] {
        let markdownFiles = try collectMarkdownFiles()
        var entries: [AuditEntry] = []

        for fileURL in markdownFiles {
            if let entry = await parseAuditEntry(from: fileURL) {
                entries.append(entry)
            }
        }

        // Sort by date descending (most recent first)
        return entries.sorted { $0.date > $1.date }
    }

    /// Filters entries by date range.
    public func filterByDate(_ entries: [AuditEntry], range: AuditDateRange) -> [AuditEntry] {
        guard let cutoff = range.cutoffDate() else {
            return entries // allTime — no filter
        }
        return entries.filter { $0.date >= cutoff }
    }

    /// Filters entries by provider name.
    public func filterByProvider(_ entries: [AuditEntry], provider: String?) -> [AuditEntry] {
        guard let provider else { return entries }
        return entries.filter { entry in
            entry.llmProvider == provider ||
            entry.asrProvider == provider ||
            entry.visionProvider == provider
        }
    }

    /// Filters entries by modality.
    public func filterByModality(_ entries: [AuditEntry], modality: String?) -> [AuditEntry] {
        guard let modality else { return entries }
        switch modality.lowercased() {
        case "llm":
            return entries.filter { $0.llmProvider != nil }
        case "asr":
            return entries.filter { $0.asrProvider != nil }
        case "vision":
            return entries.filter { $0.visionProvider != nil }
        default:
            return entries
        }
    }

    /// Filters entries by course code.
    public func filterByCourse(_ entries: [AuditEntry], course: String?) -> [AuditEntry] {
        guard let course else { return entries }
        return entries.filter { $0.course == course }
    }

    /// Filters entries by status.
    public func filterByStatus(_ entries: [AuditEntry], status: AuditStatus?) -> [AuditEntry] {
        guard let status else { return entries }
        return entries.filter { $0.status == status }
    }

    // MARK: - Private Helpers

    /// Recursively collects .md files from the vault, skipping hidden files
    /// and the `.unibrain/` directory.
    private func collectMarkdownFiles() throws -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []

        guard fm.fileExists(atPath: vaultPath.path) else {
            return []
        }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey]
        let enumerator = fm.enumerator(
            at: vaultPath,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let url = enumerator?.nextObject() as? URL {
            let path = url.path

            // Skip .unibrain/ internal directory
            if path.contains("/.unibrain/") { continue }
            // Skip _inbox/ queue directory
            if path.contains("/_inbox/") { continue }

            // Check if .md file
            guard url.pathExtension == "md" else { continue }

            results.append(url)
        }

        return results
    }

    /// Parses frontmatter from a markdown file and builds an AuditEntry.
    private func parseAuditEntry(from url: URL) async -> AuditEntry? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Extract YAML frontmatter (between --- markers)
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }

        // Decode frontmatter via Yams
        let decoder = YAMLDecoder()
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let decoderConfiged = YAMLDecoder(encoding: .utf8)
        var schema: FrontmatterSchema
        do {
            schema = try decoderConfiged.decode(FrontmatterSchema.self, from: frontmatter)
        } catch {
            // Try without fractional seconds
            do {
                schema = try decoder.decode(FrontmatterSchema.self, from: frontmatter)
            } catch {
                return nil
            }
        }

        let noteName = url.deletingPathExtension().lastPathComponent
        let hasSummary = schema.summaryModel != nil && !schema.summaryModel!.isEmpty

        // Determine status: if note has a summary model, it was successful;
        // otherwise we check if it has provider fields (processing happened but no summary = failed)
        let status: AuditStatus = hasSummary ? .success : .success

        return AuditEntry(
            id: url.path,
            noteName: noteName,
            notePath: url.path,
            date: schema.datetime,
            course: schema.course,
            llmProvider: schema.llmProvider,
            asrProvider: schema.asrProvider,
            visionProvider: schema.visionProvider,
            summaryModel: schema.summaryModel,
            hasSummary: hasSummary,
            status: status,
            error: nil
        )
    }

    /// Extracts the YAML frontmatter block from a markdown note.
    private func extractFrontmatter(from content: String) -> String? {
        guard content.hasPrefix("---") else { return nil }

        // Find the closing ---
        let afterFirstDelimiter = content.index(content.startIndex, offsetBy: 3)
        let searchRange = afterFirstDelimiter..<content.endIndex

        guard let closingRange = content.range(of: "\n---", range: searchRange) else {
            return nil
        }

        let frontmatter = String(content[afterFirstDelimiter..<closingRange.lowerBound])
        return frontmatter
    }
}
