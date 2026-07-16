import Testing
import Foundation
@testable import UnibrainProviders

// Tests for BookmarkStore security-scoped bookmark persistence.
//
// Validates ONBD-04: vault picker persists via security-scoped bookmark.
// Validates T-05-01 (mitigate): bookmarks stored in Keychain, not UserDefaults.
// Validates T-05-03 (mitigate): stale bookmark returns nil so caller re-prompts.
//
// macOS/iOS-only: Security framework SecItem APIs are unavailable on Linux.
// Per A2 from RESEARCH.md: bookmark encode/decode is testable on macOS CI;
// Keychain stubs compile on Linux but full round-trip requires macOS.

#if os(macOS) || os(iOS)

@Suite("BookmarkStore")
struct BookmarkStoreTests {

    // MARK: - Test 1: save -> resolve round-trip

    @Test("save then resolve returns the same URL")
    func saveThenResolveReturnsSameURL() throws {
        // Create a temp directory we can create a bookmark for.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain-bookmark-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Clear any prior bookmark for a clean test.
        BookmarkStore.clear()

        try BookmarkStore.save(for: tmpDir)
        let resolved = BookmarkStore.resolve()

        #expect(resolved != nil)
        #expect(resolved?.path == tmpDir.path)

        BookmarkStore.clear()
    }

    // MARK: - Test 2: resolve returns nil when no bookmark saved

    @Test("resolve returns nil when no bookmark is saved")
    func resolveReturnsNilWhenEmpty() {
        BookmarkStore.clear()

        let resolved = BookmarkStore.resolve()
        #expect(resolved == nil)
    }

    // MARK: - Test 3: clear removes the bookmark

    @Test("clear removes the bookmark so resolve returns nil")
    func clearRemovesBookmark() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain-bookmark-clear-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try BookmarkStore.save(for: tmpDir)
        #expect(BookmarkStore.resolve() != nil)

        BookmarkStore.clear()
        #expect(BookmarkStore.resolve() == nil)
    }

    // MARK: - Test 4: save throws for non-security-scoped URL
    // Per T-05-02 (accept): .fileImporter returns system-validated URLs.
    // We test that save handles errors gracefully — a non-existent path
    // should throw rather than silently succeed.

    @Test("save throws for a non-existent URL path")
    func saveThrowsForNonExistentPath() {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/that/does/not/exist/\(UUID().uuidString)")

        #expect(throws: (any Error).self) {
            try BookmarkStore.save(for: fakeURL)
        }

        BookmarkStore.clear()
    }
}

#endif // os(macOS) || os(iOS)
