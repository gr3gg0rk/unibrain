import Testing
import Foundation
#if canImport(AVFoundation)
import AVFoundation
import AVFAudio
#endif
@testable import UnibrainProviders

@Suite("AudioRecorder")
struct AudioRecorderTests {

    // MARK: - Test Helpers

    /// Creates a unique temp URL for test recordings.
    private func makeTempURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("unibrain_test_\(UUID().uuidString).m4a")
    }

    /// Cleans up a temp file after test.
    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Audio Settings Tests (CAPT-06)

    @Test("AudioRecorder configures 16kHz mono AAC settings per CLAUDE.md")
    func audioSettingsAre16kHzMonoAAC() throws {
        #if canImport(AVFoundation)
        let settings = AudioRecorder.audioSettings
        #expect(settings[AVFormatIDKey] as? UInt32 == kAudioFormatMPEG4AAC)
        #expect(settings[AVSampleRateKey] as? Double == 16000.0)
        #expect(settings[AVNumberOfChannelsKey] as? Int == 1)
        #expect(settings[AVEncoderAudioQualityKey] as? Int == AVAudioQuality.high.rawValue)
        #else
        // Linux: settings are not available without AVFoundation
        // This test is macOS-only and runs on CI
        #endif
    }

    // MARK: - Start/Stop Recording Tests (CAPT-01)

    @Test("start(to:) produces a valid .m4a file when recording")
    func startProducesValidM4AFile() async throws {
        #if canImport(AVFoundation)
        let url = makeTempURL()
        defer { cleanup(url) }

        let recorder = AudioRecorder()
        try recorder.start(to: url)

        // Record briefly to produce a non-empty file
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2s

        recorder.stop()

        // Verify the file exists
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Verify the file has content (non-zero size)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int ?? 0
        #expect(fileSize > 0, "Recorded .m4a file should have non-zero size")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("stop() finalizes the recording and sets recorder to nil")
    func stopFinalizesRecording() async throws {
        #if canImport(AVFoundation)
        let url = makeTempURL()
        defer { cleanup(url) }

        let recorder = AudioRecorder()
        try recorder.start(to: url)
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        recorder.stop()

        // After stop, isRecording should be false
        #expect(!recorder.isRecording)
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Pause/Resume Tests (CAPT-02)

    @Test("pause() and resume() maintain a single contiguous file")
    func pauseResumeProducesContiguousFile() async throws {
        #if canImport(AVFoundation)
        let url = makeTempURL()
        defer { cleanup(url) }

        let recorder = AudioRecorder()
        try recorder.start(to: url)

        // Record for 0.2s
        try await Task.sleep(nanoseconds: 200_000_000)

        // Pause
        recorder.pause()
        #expect(recorder.isPaused)
        #expect(!recorder.isRecording)

        // Wait while paused (no audio recorded during this time)
        try await Task.sleep(nanoseconds: 300_000_000)

        // Resume — should continue writing to the SAME file
        recorder.resume()
        #expect(!recorder.isPaused)
        #expect(recorder.isRecording)

        // Record for another 0.2s
        try await Task.sleep(nanoseconds: 200_000_000)

        recorder.stop()

        // Verify the file exists and has content
        #expect(FileManager.default.fileExists(atPath: url.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int ?? 0
        #expect(fileSize > 0, "Paused+resumed .m4a file should have non-zero size")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("isPaused is true after pause(), false after resume()")
    func isPausedReflectsState() async throws {
        #if canImport(AVFoundation)
        let url = makeTempURL()
        defer { cleanup(url) }

        let recorder = AudioRecorder()
        try recorder.start(to: url)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Initially not paused
        #expect(!recorder.isPaused)

        // Pause
        recorder.pause()
        #expect(recorder.isPaused)

        // Resume
        recorder.resume()
        #expect(!recorder.isPaused)

        recorder.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Level Metering Tests (CAPT-05)

    @Test("currentLevel returns a meaningful dB value when recording is active")
    func currentLevelReturnsMeaningfulValue() async throws {
        #if canImport(AVFoundation)
        let url = makeTempURL()
        defer { cleanup(url) }

        let recorder = AudioRecorder()
        try recorder.start(to: url)

        // Record briefly so metering has data
        try await Task.sleep(nanoseconds: 300_000_000)

        let level = recorder.currentLevel

        // averagePower returns dB in range -160.0 (silence) to 0.0 (max)
        #expect(level >= -160.0, "currentLevel should be >= -160.0 dB")
        #expect(level <= 0.0, "currentLevel should be <= 0.0 dB")

        recorder.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("currentLevel returns -160 when not recording")
    func currentLevelReturnsSilenceWhenNotRecording() {
        #if canImport(AVFoundation)
        let recorder = AudioRecorder()
        // Not recording — should return silence floor
        let level = recorder.currentLevel
        #expect(level == -160.0, "currentLevel should be -160.0 when not recording")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("isMeteringEnabled is true after start()")
    func meteringEnabledAfterStart() async throws {
        #if canImport(AVFoundation)
        let url = makeTempURL()
        defer { cleanup(url) }

        let recorder = AudioRecorder()
        try recorder.start(to: url)

        // Per Pitfall 3: isMeteringEnabled MUST be true before recording starts
        #expect(recorder.isMeteringEnabled)

        recorder.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Error Handling Tests

    @Test("start(to:) with invalid URL throws error")
    func startWithInvalidURLThrows() {
        #if canImport(AVFoundation)
        let recorder = AudioRecorder()
        // A URL to a non-existent directory should fail
        let badURL = URL(fileURLWithPath: "/nonexistent/dir/that/does/not/exist/recording.m4a")

        #expect(throws: (any Error).self) {
            try recorder.start(to: badURL)
        }
        #else
        // macOS-only test — runs on CI
        #endif
    }
}
