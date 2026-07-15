import Testing
import Foundation
@testable import UnibrainProviders

@Suite("RecordingSession")
struct RecordingSessionTests {

    // MARK: - Test Helpers

    /// Creates a unique temp destination URL for test recordings.
    private func makeDestinationURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dir = tempDir.appendingPathComponent("unibrain_session_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("lecture.m4a")
    }

    /// Cleans up temp files after test.
    private func cleanup(_ url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Initial State Tests

    @Test("RecordingSession starts in .idle state")
    func startsIdle() async {
        #if canImport(AVFoundation)
        let session = RecordingSession()
        #expect(await session.currentState == .idle)
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("elapsedSeconds is 0 when idle")
    func elapsedSecondsZeroWhenIdle() async {
        #if canImport(AVFoundation)
        let session = RecordingSession()
        let elapsed = await session.elapsedSeconds
        #expect(elapsed == 0)
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("currentLevel is -160 when idle")
    func currentLevelSilenceWhenIdle() async {
        #if canImport(AVFoundation)
        let session = RecordingSession()
        let level = await session.currentLevel
        #expect(level == -160.0)
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - State Transition Tests

    @Test("startRecording transitions to .recording state")
    func startRecordingTransitionsToRecording() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        #expect(await session.currentState == .recording)

        await session.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("pause transitions from .recording to .paused")
    func pauseTransitionsToPaused() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        // Brief recording before pause
        try await Task.sleep(nanoseconds: 100_000_000)

        try await session.pause()
        #expect(await session.currentState == .paused)

        await session.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("resume transitions from .paused to .recording")
    func resumeTransitionsToRecording() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)
        try await Task.sleep(nanoseconds: 100_000_000)

        try await session.pause()
        #expect(await session.currentState == .paused)

        try await session.resume()
        #expect(await session.currentState == .recording)

        await session.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("stop transitions to .stopped state")
    func stopTransitionsToStopped() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await session.stop()
        #expect(await session.currentState == .stopped)
        #expect(result.audioURL == dest)
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Invalid Transition Tests

    @Test("pause when .idle throws error")
    func pauseWhenIdleThrows() async {
        #if canImport(AVFoundation)
        let session = RecordingSession()
        await #expect(throws: (any Error).self) {
            try await session.pause()
        }
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("resume when .idle throws error")
    func resumeWhenIdleThrows() async {
        #if canImport(AVFoundation)
        let session = RecordingSession()
        await #expect(throws: (any Error).self) {
            try await session.resume()
        }
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("stop when .idle throws error")
    func stopWhenIdleThrows() async {
        #if canImport(AVFoundation)
        let session = RecordingSession()
        await #expect(throws: (any Error).self) {
            _ = try await session.stop()
        }
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("startRecording when already recording throws error")
    func startRecordingWhenRecordingThrows() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        await #expect(throws: (any Error).self) {
            try await session.startRecording(destination: dest)
        }

        await session.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Elapsed Time Tests (CAPT-04)

    @Test("elapsedSeconds increases during recording")
    func elapsedSecondsIncreasesDuringRecording() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        // Record for 0.3s
        try await Task.sleep(nanoseconds: 300_000_000)

        let elapsed = await session.elapsedSeconds
        // Should be roughly 0.3s (allow some tolerance)
        #expect(elapsed > 0.1, "elapsedSeconds should be > 0.1 after 0.3s recording")
        #expect(elapsed < 2.0, "elapsedSeconds should be reasonable (< 2.0s)")

        await session.stop()
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("elapsedSeconds excludes paused time")
    func elapsedSecondsExcludesPausedTime() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        // Record for 0.2s
        try await Task.sleep(nanoseconds: 200_000_000)
        let elapsedBeforePause = await session.elapsedSeconds

        // Pause for 0.5s
        try await session.pause()
        try await Task.sleep(nanoseconds: 500_000_000)

        let elapsedWhilePaused = await session.elapsedSeconds

        // Resume and record for 0.2s more
        try await session.resume()
        try await Task.sleep(nanoseconds: 200_000_000)

        let elapsedAfterResume = await session.elapsedSeconds

        await session.stop()

        // Elapsed while paused should be frozen (not include pause time)
        #expect(elapsedWhilePaused <= elapsedBeforePause + 0.05,
                "elapsedSeconds should not increase while paused")

        // After resume, elapsed should increase but NOT include the 0.5s pause
        #expect(elapsedAfterResume > elapsedWhilePaused,
                "elapsedSeconds should increase after resume")
        #expect(elapsedAfterResume < elapsedBeforePause + 0.5,
                "elapsedSeconds should exclude paused time")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Pause Intervals Tests (P-D1)

    @Test("pauseIntervals records pause duration and start time")
    func pauseIntervalsRecorded() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        // Record for 0.2s
        try await Task.sleep(nanoseconds: 200_000_000)

        // Pause for 0.3s
        try await session.pause()
        try await Task.sleep(nanoseconds: 300_000_000)

        // Resume
        try await session.resume()

        // Record for 0.1s more
        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await session.stop()

        // Should have 1 pause interval
        #expect(result.pauseIntervals.count == 1,
                "Should record exactly 1 pause interval")

        let interval = result.pauseIntervals[0]
        // Start should be roughly 0.2s into the recording
        #expect(interval.start >= 0.0, "Pause start should be >= 0")
        #expect(interval.start < 1.0, "Pause start should be < 1.0s")
        // Duration should be roughly 0.3s (allow tolerance)
        #expect(interval.duration > 0.1, "Pause duration should be > 0.1s")
        #expect(interval.duration < 1.0, "Pause duration should be < 1.0s")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("multiple pause/resume cycles produce multiple intervals")
    func multiplePauseCycles() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        // First pause cycle
        try await Task.sleep(nanoseconds: 100_000_000)
        try await session.pause()
        try await Task.sleep(nanoseconds: 100_000_000)
        try await session.resume()

        // Second pause cycle
        try await Task.sleep(nanoseconds: 100_000_000)
        try await session.pause()
        try await Task.sleep(nanoseconds: 100_000_000)
        try await session.resume()

        try await Task.sleep(nanoseconds: 100_000_000)

        let result = try await session.stop()

        #expect(result.pauseIntervals.count == 2,
                "Should record exactly 2 pause intervals")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Stop Moves Temp File (P-D2)

    @Test("stop() moves temp file to destination URL")
    func stopMovesTempFileToDestination() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        try await Task.sleep(nanoseconds: 200_000_000)

        let result = try await session.stop()

        // The destination file should exist
        #expect(FileManager.default.fileExists(atPath: dest.path),
               "Destination file should exist after stop()")

        // The result URL should match the destination
        #expect(result.audioURL == dest)

        // The file should have content
        let attrs = try FileManager.default.attributesOfItem(atPath: dest.path)
        let fileSize = attrs[.size] as? Int ?? 0
        #expect(fileSize > 0, "Moved file should have non-zero size")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("RecordingResult contains durationSeconds")
    func resultContainsDurationSeconds() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)

        try await Task.sleep(nanoseconds: 300_000_000)

        let result = try await session.stop()

        // Duration should be roughly 0.3s (as Int, so 0)
        // But should be non-negative
        #expect(result.durationSeconds >= 0,
               "durationSeconds should be >= 0")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    // MARK: - Reset Tests

    @Test("reset returns from .stopped to .idle")
    func resetReturnsToIdle() async throws {
        #if canImport(AVFoundation)
        let dest = makeDestinationURL()
        defer { cleanup(dest) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest)
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try await session.stop()

        #expect(await session.currentState == .stopped)

        await session.reset()
        #expect(await session.currentState == .idle)

        // elapsedSeconds should be 0 after reset
        let elapsed = await session.elapsedSeconds
        #expect(elapsed == 0, "elapsedSeconds should be 0 after reset")
        #else
        // macOS-only test — runs on CI
        #endif
    }

    @Test("startRecording works after reset")
    func startRecordingAfterReset() async throws {
        #if canImport(AVFoundation)
        let dest1 = makeDestinationURL()
        defer { cleanup(dest1) }

        let session = RecordingSession()
        try await session.startRecording(destination: dest1)
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try await session.stop()

        await session.reset()

        // Should be able to start a new recording
        let dest2 = makeDestinationURL()
        defer { cleanup(dest2) }

        try await session.startRecording(destination: dest2)
        #expect(await session.currentState == .recording)

        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try await session.stop()

        #expect(FileManager.default.fileExists(atPath: dest2.path))
        #else
        // macOS-only test — runs on CI
        #endif
    }
}
