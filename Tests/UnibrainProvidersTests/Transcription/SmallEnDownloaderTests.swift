import Testing
import Foundation
@testable import UnibrainProviders

// Tests for SmallEnDownloader — background model download with SHA256 verification.
//
// Covers TRAN-02 (model download + checksum), P-17 (background download),
// P-18 (retry once then non-blocking warning), P-19 (model storage path).
//
// Tests use a mock URLSession to avoid real network calls.

@Suite("SmallEnDownloader")
struct SmallEnDownloaderTests {

    // MARK: - Initial State

    @Test("Starts in .notStarted state")
    func startsInNotStartedState() async {
        let downloader = SmallEnDownloader()

        let state = await downloader.currentState
        #expect(state == .notStarted)
    }

    // MARK: - State Transitions

    @Test("startDownload transitions to .downloading then .verified on success")
    func downloadSucceeds() async {
        let downloader = SmallEnDownloader(
            downloadURL: URL(string: "https://example.com/model.bin")!,
            expectedSHA256: "known-hash",
            urlSession: MockURLSession(shouldSucceed: true, mockData: Data([0x00, 0x01, 0x02, 0x03]))
        )

        await downloader.startDownload()

        let state = await downloader.currentState
        #expect(state == .verified)
    }

    @Test("Download failure triggers retry-once then .failed (P-18)")
    func downloadFailureRetriesOnceThenFails() async {
        let downloader = SmallEnDownloader(
            downloadURL: URL(string: "https://example.com/model.bin")!,
            expectedSHA256: "known-hash",
            urlSession: MockURLSession(shouldSucceed: false, mockData: Data())
        )

        await downloader.startDownload()

        let state = await downloader.currentState
        if case .failed = state {
            // Expected — download failed after retry
        } else {
            Issue.record("Expected .failed state, got \(state)")
        }
    }

    @Test("SHA256 mismatch triggers retry-once then .failed (P-18)")
    func checksumMismatchRetriesThenFails() async {
        let downloader = SmallEnDownloader(
            downloadURL: URL(string: "https://example.com/model.bin")!,
            expectedSHA256: "expected-hash-that-wont-match",
            urlSession: MockURLSession(shouldSucceed: true, mockData: Data([0xAA, 0xBB, 0xCC]))
        )

        await downloader.startDownload()

        let state = await downloader.currentState
        if case .failed = state {
            // Expected — checksum mismatch after retry
        } else {
            Issue.record("Expected .failed state after checksum mismatch, got \(state)")
        }
    }

    // MARK: - Non-blocking (P-18: NEVER blocks recording)

    @Test("startDownload never throws — failed download sets .failed state (P-18)")
    func downloadNeverThrows() async {
        let downloader = SmallEnDownloader(
            downloadURL: URL(string: "https://example.com/model.bin")!,
            expectedSHA256: "known-hash",
            urlSession: MockURLSession(shouldSucceed: false, mockData: Data())
        )

        // This should NOT throw — failures are captured in state
        await downloader.startDownload()

        let state = await downloader.currentState
        if case .failed = state {
            // Expected
        } else {
            Issue.record("Expected .failed state, got \(state)")
        }
    }

    // MARK: - Retry from .failed state

    @Test("Can retry from .failed state")
    func retryFromFailedState() async {
        let downloader = SmallEnDownloader(
            downloadURL: URL(string: "https://example.com/model.bin")!,
            expectedSHA256: "known-hash",
            urlSession: MockURLSession(shouldSucceed: false, mockData: Data())
        )

        // First attempt fails
        await downloader.startDownload()
        let state1 = await downloader.currentState
        if case .failed = state1 {} else {
            Issue.record("Expected .failed after first attempt")
        }

        // Retry should be allowed from .failed
        await downloader.startDownload()
        let state2 = await downloader.currentState
        if case .failed = state2 {} else {
            Issue.record("Expected .failed after retry from failed")
        }
    }

    // MARK: - Model storage path (P-19)

    @Test("Model storage path is under Application Support/Unibrain/models/ (P-19)")
    func modelStoragePathCorrect() {
        let path = SmallEnDownloader.modelStoragePath

        // Path should contain "Unibrain/models/ggml-small.en.bin"
        #expect(path.path.contains("Unibrain"))
        #expect(path.path.contains("models"))
        #expect(path.path.contains("ggml-small.en.bin"))
    }

    // MARK: - Download URL (P-D6)

    @Test("Download URL points to GitHub releases (P-D6)")
    func downloadURLIsGitHubReleases() {
        let url = SmallEnDownloader.downloadURL

        #expect(url.host?.contains("github.com") == true)
        #expect(url.path.contains("ggml-small.en.bin"))
    }

    // MARK: - isModelPresent

    @Test("isModelPresent returns false when model doesn't exist")
    func isModelPresentFalseWhenMissing() async {
        let downloader = SmallEnDownloader()

        let present = await downloader.isModelPresent
        #expect(present == false)
    }

    // MARK: - Expected SHA256 is non-empty

    @Test("Expected SHA256 hash is embedded as non-empty string")
    func expectedSHA256IsNonEmpty() {
        #expect(!SmallEnDownloader.expectedSHA256.isEmpty)
    }
}

// MARK: - Mock URLSession

/// Mock URLSession protocol for testing without real network calls.
protocol MockURLSessionProtocol: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

/// Mock URLSession that either succeeds or fails.
struct MockURLSession: MockURLSessionProtocol, Sendable {
    let shouldSucceed: Bool
    let mockData: Data

    func data(from url: URL) async throws -> (Data, URLResponse) {
        if shouldSucceed {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (mockData, response)
        } else {
            throw URLError(.networkConnectionLost)
        }
    }
}
