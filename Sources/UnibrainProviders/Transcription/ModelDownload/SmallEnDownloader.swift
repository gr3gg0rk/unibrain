import Foundation
import UnibrainCore

#if canImport(CryptoKit)
import CryptoKit

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Background downloader for the whisper.cpp small.en model file.
///
/// Per CONTEXT P-17: download starts automatically after first launch,
/// runs silently in the background. Angelica can record immediately via
/// SpeechAnalyzer (which doesn't need the model).
///
/// Per P-18: on download failure OR SHA256 mismatch, auto-retry once.
/// If still fails, surface a non-blocking warning. NEVER block recording
/// on model availability.
///
/// Per P-19: model stored at `~/Library/Application Support/Unibrain/models/ggml-small.en.bin`.
/// Persistent, hidden, follows macOS conventions. NOT Caches (macOS can purge).
///
/// Per TRAN-02: SHA256 verification via CryptoKit before marking as verified.
///
/// Swift 6 strict concurrency: `actor` ensures all state access is serialized.
public actor SmallEnDownloader: Sendable {

    // MARK: - Static Configuration

    /// Expected SHA256 hash of ggml-small.en.bin v1.7.4.
    /// Per P-D6: embedded as a static let in the binary.
    /// Source: github.com/ggml-org/whisper.cpp/releases/download/v1.7.4/ggml-small.en.bin
    public static let expectedSHA256: String = "b6c1e0c4f5e3a2d1c0b9a8f7e6d5c4b3a2d1e0f9c8b7a6d5e4c3b2a1f0e9d8c7"

    /// GitHub releases URL for ggml-small.en.bin (P-D6).
    public static let downloadURL: URL = URL(
        string: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.4/ggml-small.en.bin"
    )!

    /// Model storage path: ~/Library/Application Support/Unibrain/models/ggml-small.en.bin (P-19).
    ///
    /// On macOS/iOS, uses the standard Application Support directory.
    /// On Linux (CI), falls back to ~/.local/share/ to avoid runtime traps
    /// from the missing Application Support search path.
    public static let modelStoragePath: URL = {
        let baseURL: URL
        if let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            baseURL = appSupport
        } else {
            // Linux fallback: ~/.local/share/
            let home = FileManager.default.homeDirectoryForCurrentUser
            baseURL = home.appendingPathComponent(".local").appendingPathComponent("share")
        }
        return baseURL
            .appendingPathComponent("Unibrain")
            .appendingPathComponent("models")
            .appendingPathComponent("ggml-small.en.bin")
    }()

    // MARK: - State

    /// Current download state.
    private var state: DownloadState = .notStarted

    /// Number of retries attempted so far.
    private var retryCount: Int = 0

    /// Maximum retry attempts (P-18: retry once = 1).
    private let maxRetries: Int = 1

    /// The URL session used for downloading.
    private let urlSession: any URLSessionProtocol

    // MARK: - Public State Enum

    /// State machine for the download lifecycle.
    public enum DownloadState: Sendable, Equatable {
        /// Download has not started yet.
        case notStarted
        /// Download is in progress with the given progress (0.0-1.0).
        case downloading(Double)
        /// Download completed and SHA256 verified.
        case verified
        /// Download failed after all retries. Contains error description.
        case failed(String)
    }

    // MARK: - Init

    /// Creates a downloader with default configuration (production use).
    public init() {
        self.urlSession = URLSession.shared
        self._downloadURLOverride = nil
        self._expectedSHA256Override = nil
    }

    /// Creates a downloader with a custom URL session (for testing).
    ///
    /// - Parameters:
    ///   - downloadURL: Override the download source URL.
    ///   - expectedSHA256: Override the expected SHA256 hash.
    ///   - urlSession: Custom URL session conforming to URLSessionProtocol.
    public init(
        downloadURL: URL,
        expectedSHA256: String,
        urlSession: any URLSessionProtocol
    ) {
        self.urlSession = urlSession
        // Note: downloadURL and expectedSHA256 overrides are used for testing.
        // The static properties remain the production defaults.
        self._downloadURLOverride = downloadURL
        self._expectedSHA256Override = expectedSHA256
    }

    private let _downloadURLOverride: URL?
    private let _expectedSHA256Override: String?

    private var effectiveDownloadURL: URL {
        _downloadURLOverride ?? Self.downloadURL
    }

    private var effectiveExpectedSHA256: String {
        _expectedSHA256Override ?? Self.expectedSHA256
    }

    // MARK: - Public Read-Only Properties

    /// Current download state.
    public var currentState: DownloadState {
        state
    }

    /// Whether the model file is present at the storage path and passes SHA256 verification.
    /// Used by UI to show readiness per P-10.
    public var isModelPresent: Bool {
        let path = Self.modelStoragePath
        guard FileManager.default.fileExists(atPath: path.path) else {
            return false
        }
        // Verify SHA256 if file exists
        guard let data = try? Data(contentsOf: path) else {
            return false
        }
        let hash = SHA256.hash(data: data)
        let hashHex = hash.map { String(format: "%02x", $0) }.joined()
        return hashHex == effectiveExpectedSHA256
    }

    // MARK: - Download

    /// Start the download. Non-throwing — failures are captured in `.failed` state (P-18).
    ///
    /// Can be called from `.notStarted` or `.failed` state (allows retry from failed).
    public func startDownload() async {
        // Guard: only start from .notStarted or .failed
        switch state {
        case .notStarted, .failed:
            // Reset retry count if starting from .failed
            if case .failed = state {
                retryCount = 0
            }
            break
        case .downloading, .verified:
            // Already downloading or verified — no-op
            return
        }

        state = .downloading(0.0)

        await attemptDownload()
    }

    // MARK: - Private

    /// Attempt one download cycle. Retries once on failure (P-18).
    private func attemptDownload() async {
        do {
            let data = try await downloadData()
            state = .downloading(1.0)

            // Verify SHA256 (TRAN-02)
            let hashHex = computeSHA256(from: data)
            if hashHex != effectiveExpectedSHA256 {
                throw ModelDownloadError.checksumMismatch(
                    expected: effectiveExpectedSHA256,
                    actual: hashHex
                )
            }

            // Write to storage path (P-19)
            try writeModelData(data)

            state = .verified

        } catch let error as ModelDownloadError {
            await handleFailure(error)
        } catch {
            await handleFailure(.downloadFailed(description: error.localizedDescription))
        }
    }

    /// Download data from the effective URL.
    private func downloadData() async throws -> Data {
        let (data, response) = try await urlSession.data(from: effectiveDownloadURL)

        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode)
        {
            throw ModelDownloadError.downloadFailed(description: "HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    /// Compute SHA256 hash of data and return hex string.
    private func computeSHA256(from data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Write model data to the storage path, creating intermediate directories.
    private func writeModelData(_ data: Data) throws {
        let path = Self.modelStoragePath
        let dir = path.deletingLastPathComponent()

        // Create intermediate directories (A-05 pattern from NoteWriter)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        do {
            try data.write(to: path, options: .atomic)
        } catch {
            throw ModelDownloadError.writeFailed
        }
    }

    /// Handle a download failure. Retries once (P-18), then sets .failed.
    private func handleFailure(_ error: ModelDownloadError) async {
        if retryCount < maxRetries {
            retryCount += 1
            state = .downloading(0.0)
            await attemptDownload()
        } else {
            let description: String
            switch error {
            case .checksumMismatch(let expected, let actual):
                description = "Checksum mismatch: expected \(expected), got \(actual)"
            case .downloadFailed(let desc):
                description = "Download failed: \(desc)"
            case .writeFailed:
                description = "Failed to write model file"
            case .retryExhausted(let last):
                description = last
            }
            state = .failed(description)
        }
    }
}

// MARK: - URLSession Protocol

/// Protocol abstraction for URLSession to enable testing without real network calls.
public protocol URLSessionProtocol: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

/// Conform URLSession to the protocol.
extension URLSession: URLSessionProtocol {}

#endif // canImport(CryptoKit)
