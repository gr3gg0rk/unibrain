import Testing
import Foundation
@testable import UnibrainProviders
@testable import UnibrainCore

/// Tests for AuditTrailStore (vault scanning + audit index building).
///
/// Phase 06-06 Task 2: Per CF-04, audit trail reads frontmatter to build
/// per-note provider usage index. Tests verify vault scanning, filtering,
/// and frontmatter parsing.
@Suite("AuditTrailStoreTests")
struct AuditTrailStoreTests {

    // MARK: - Scan Vault

    @Test("scanVault returns entries for notes with valid frontmatter")
    func scanVaultReturnsEntries() async throws {
        let vaultPath = try createTestVault()

        let store = AuditTrailStore(vaultPath: vaultPath)
        let entries = try await store.scanVault()

        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.course == "CS101")
        #expect(entry.llmProvider == "ollama")
        #expect(entry.asrProvider == "whisper-cpp")
        #expect(entry.summaryModel == "llama-3.2:3b")
        #expect(entry.hasSummary == true)
        #expect(entry.status == .success)
    }

    @Test("scanVault skips files without frontmatter")
    func scanVaultSkipsFilesWithoutFrontmatter() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-test-\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: vaultPath, withIntermediateDirectories: true)

        // Write a .md file without frontmatter
        let noFmPath = vaultPath.appendingPathComponent("no-frontmatter.md")
        try "# Just a note\n\nNo frontmatter here.".write(
            to: noFmPath, atomically: true, encoding: .utf8)

        let store = AuditTrailStore(vaultPath: vaultPath)
        let entries = try await store.scanVault()

        #expect(entries.isEmpty)
    }

    @Test("scanVault skips .unibrain/ internal directory")
    func scanVaultSkipsUnibrainDir() async throws {
        let vaultPath = try createTestVault()

        // Write a .md file inside .unibrain/ (should be skipped)
        let unibrainDir = vaultPath.appendingPathComponent(".unibrain")
        try FileManager.default.createDirectory(
            at: unibrainDir, withIntermediateDirectories: true)
        let internalMd = unibrainDir.appendingPathComponent("internal.md")
        try "---\ncourse: SECRET\n---\nInternal".write(
            to: internalMd, atomically: true, encoding: .utf8)

        let store = AuditTrailStore(vaultPath: vaultPath)
        let entries = try await store.scanVault()

        // Only the original test note, not the internal one
        #expect(entries.count == 1)
        #expect(entries.first?.course != "SECRET")
    }

    @Test("scanVault returns entries sorted by date descending")
    func scanVaultSortedByDateDesc() async throws {
        let vaultPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-sort-\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: vaultPath, withIntermediateDirectories: true)

        // Write two notes with different dates
        let oldNote = vaultPath.appendingPathComponent("old.md")
        try """
        ---
        schema_version: 2
        course: CS101
        course_name: Intro
        term: Fall 2026
        datetime: 2026-07-01T10:00:00Z
        duration_seconds: 300
        source: MacBook
        audio_file: old.m4a
        tags: [lecture]
        ---
        """.write(to: oldNote, atomically: true, encoding: .utf8)

        let newNote = vaultPath.appendingPathComponent("new.md")
        try """
        ---
        schema_version: 2
        course: CS102
        course_name: Intro 2
        term: Fall 2026
        datetime: 2026-07-15T10:00:00Z
        duration_seconds: 300
        source: MacBook
        audio_file: new.m4a
        tags: [lecture]
        ---
        """.write(to: newNote, atomically: true, encoding: .utf8)

        let store = AuditTrailStore(vaultPath: vaultPath)
        let entries = try await store.scanVault()

        #expect(entries.count == 2)
        #expect(entries[0].course == "CS102") // newer first
        #expect(entries[1].course == "CS101")
    }

    // MARK: - Filters

    @Test("filterByDate returns only entries within range")
    func filterByDateWorks() async throws {
        let now = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -20, to: now)!

        let entries = [
            AuditEntry(
                id: "1", noteName: "recent", notePath: "/recent.md",
                date: now, course: "CS101"
            ),
            AuditEntry(
                id: "2", noteName: "old", notePath: "/old.md",
                date: oldDate, course: "CS102"
            ),
        ]

        let store = AuditTrailStore(
            vaultPath: FileManager.default.temporaryDirectory)

        let filtered7 = await store.filterByDate(entries, range: .last7Days)
        #expect(filtered7.count == 1)
        #expect(filtered7.first?.noteName == "recent")

        let filtered90 = await store.filterByDate(entries, range: .last90Days)
        #expect(filtered90.count == 2)
    }

    @Test("filterByProvider matches LLM, ASR, or Vision provider")
    func filterByProviderWorks() async throws {
        let entries = [
            AuditEntry(
                id: "1", noteName: "n1", notePath: "/n1.md",
                date: Date(), course: "CS101",
                llmProvider: "openai"
            ),
            AuditEntry(
                id: "2", noteName: "n2", notePath: "/n2.md",
                date: Date(), course: "CS102",
                asrProvider: "whisper-cpp"
            ),
            AuditEntry(
                id: "3", noteName: "n3", notePath: "/n3.md",
                date: Date(), course: "CS103"
            ),
        ]

        let store = AuditTrailStore(
            vaultPath: FileManager.default.temporaryDirectory)

        let openai = await store.filterByProvider(entries, provider: "openai")
        #expect(openai.count == 1)

        let whisper = await store.filterByProvider(entries, provider: "whisper-cpp")
        #expect(whisper.count == 1)

        let allEntries = await store.filterByProvider(entries, provider: nil)
        #expect(allEntries.count == 3)
    }

    @Test("filterByStatus filters by success or failed")
    func filterByStatusWorks() async throws {
        let entries = [
            AuditEntry(
                id: "1", noteName: "n1", notePath: "/n1.md",
                date: Date(), course: "CS101", status: .success
            ),
            AuditEntry(
                id: "2", noteName: "n2", notePath: "/n2.md",
                date: Date(), course: "CS102", status: .failed,
                error: "Rate limited"
            ),
        ]

        let store = AuditTrailStore(
            vaultPath: FileManager.default.temporaryDirectory)

        let successOnly = await store.filterByStatus(entries, status: .success)
        #expect(successOnly.count == 1)
        #expect(successOnly.first?.status == .success)

        let failedOnly = await store.filterByStatus(entries, status: .failed)
        #expect(failedOnly.count == 1)
        #expect(failedOnly.first?.error == "Rate limited")
    }

    // MARK: - Helpers

    /// Creates a test vault with one well-formed note.
    private func createTestVault() throws -> URL {
        let vaultPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-vault-\(UUID().uuidString)")

        try FileManager.default.createDirectory(
            at: vaultPath, withIntermediateDirectories: true)

        let notePath = vaultPath.appendingPathComponent("test-lecture.md")
        let frontmatter = """
        ---
        schema_version: 2
        course: CS101
        course_name: Intro to Computer Science
        term: Fall 2026
        datetime: 2026-07-15T10:00:00Z
        duration_seconds: 3600
        source: MacBook Air
        audio_file: test.m4a
        tags: [lecture, cs101]
        llm_provider: ollama
        asr_provider: whisper-cpp
        summary_model: llama-3.2:3b
        ---
        """
        try frontmatter.write(to: notePath, atomically: true, encoding: .utf8)

        return vaultPath
    }
}
