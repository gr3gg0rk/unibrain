import Testing
import Foundation
@testable import UnibrainProviders

@Suite("InboxFileDownloader")
struct InboxFileDownloaderTests {

    // MARK: - Test 5 (IC-04): .icloud placeholder detection

    @Test("checkFileStatus detects .icloud placeholder and returns downloadNeeded")
    func detectsICloudPlaceholder() async throws {
        #if os(macOS)
        let downloader = InboxFileDownloader()

        // Per Pitfall 5 / IC-04: .icloud placeholder files look like:
        // .{original-filename}.icloud  (e.g., .iphone-20260915T101530-a3f8.m4a.icloud)
        let placeholderURL = URL(fileURLWithPath:
            "/tmp/inbox/.iphone-20260915T101530-a3f8.m4a.icloud")

        let status = downloader.checkFileStatus(at: placeholderURL)
        // The downloader detects .icloud extension regardless of file existence
        // (the real file will appear after download).
        if case .downloadNeeded = status {
            // pass
        } else {
            #expect(Bool(false), "Expected .downloadNeeded for .icloud placeholder")
        }
        #else
        #expect(Bool(true))
        #endif
    }

    // MARK: - Test 6 (IC-04): Real .m4a returns .ready

    @Test("checkFileStatus detects real .m4a and returns ready")
    func detectsRealM4A() async throws {
        #if os(macOS)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_dl_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let realFile = tempDir.appendingPathComponent("iphone-20260915T101530-a3f8.m4a")
        try Data("audio-bytes".utf8).write(to: realFile)

        let downloader = InboxFileDownloader()
        let status = downloader.checkFileStatus(at: realFile)

        if case .ready = status {
            // pass
        } else {
            #expect(Bool(false), "Expected .ready for real .m4a file")
        }
        #else
        #expect(Bool(true))
        #endif
    }

    // MARK: - Test: Non-existent file without .icloud extension

    @Test("checkFileStatus returns downloadNeeded for non-existent .icloud path")
    func nonExistentICloudReturnsDownloadNeeded() async throws {
        #if os(macOS)
        let downloader = InboxFileDownloader()
        let url = URL(fileURLWithPath: "/tmp/inbox/.some-file.m4a.icloud")
        let status = downloader.checkFileStatus(at: url)
        if case .downloadNeeded = status {
            // pass
        } else {
            #expect(Bool(false), "Expected .downloadNeeded for .icloud path")
        }
        #else
        #expect(Bool(true))
        #endif
    }
}
