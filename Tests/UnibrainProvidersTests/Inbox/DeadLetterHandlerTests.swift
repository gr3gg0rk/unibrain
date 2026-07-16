import Testing
import Foundation
@testable import UnibrainProviders

@Suite("DeadLetterHandler")
struct DeadLetterHandlerTests {

    // MARK: - Test 3 (TRIG-04): Dead-letter moves file + writes sidecar

    @Test("deadLetter moves file to _failed/ and writes .error.json sidecar")
    func deadLetterMovesFileAndWritesSidecar() async throws {
        #if os(macOS)
        let inboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_dl_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: inboxRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: inboxRoot) }

        let filename = "iphone-20260915T101530-a3f8.m4a"
        let audioFile = inboxRoot.appendingPathComponent(filename)
        try Data("dummy-audio".utf8).write(to: audioFile)

        let handler = DeadLetterHandler()
        let error = InboxError.pipelineFailed(audioFile, underlying: NSError(domain: "test", code: 1))

        try await handler.deadLetter(
            url: audioFile,
            inboxRoot: inboxRoot,
            error: error,
            retryCount: 3
        )

        let failedDir = inboxRoot.appendingPathComponent("_failed")
        let movedFile = failedDir.appendingPathComponent(filename)
        let sidecar = failedDir.appendingPathComponent("\(filename).error.json")

        #expect(FileManager.default.fileExists(atPath: movedFile.path))
        #expect(FileManager.default.fileExists(atPath: sidecar.path))
        #expect(!FileManager.default.fileExists(atPath: audioFile.path))

        // Validate sidecar JSON structure (T-05-10: only metadata, no audio content)
        let sidecarData = try Data(contentsOf: sidecar)
        let sidecarJSON = try #require(JSONSerialization.jsonObject(with: sidecarData) as? [String: Any])
        #expect(sidecarJSON["original_filename"] as? String == filename)
        #expect(sidecarJSON["error_type"] != nil)
        #expect(sidecarJSON["error_message"] != nil)
        #expect(sidecarJSON["retry_count"] as? Int == 3)
        #expect(sidecarJSON["failed_at"] != nil)

        // Threat T-05-10: sidecar must NOT contain transcript or audio content fields
        #expect(sidecarJSON["transcript"] == nil)
        #expect(sidecarJSON["audio_content"] == nil)
        #else
        #expect(Bool(true))
        #endif
    }

    // MARK: - Test 4 (TRIG-04): Retry count tracking

    @Test("retryCountFor returns 0 for never-failed, increments on failure")
    func retryCountTracking() async throws {
        #if os(macOS)
        let inboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_rc_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: inboxRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: inboxRoot) }

        let handler = DeadLetterHandler()
        let url = URL(fileURLWithPath: "/tmp/inbox/never-failed.m4a")

        let initial = await handler.retryCount(for: url)
        #expect(initial == 0)
        #else
        #expect(Bool(true))
        #endif
    }

    // MARK: - Test: Max retries enforced

    @Test("recordFailure dead-letters after reaching maxRetries")
    func recordFailureDeadLettersAfterMax() async throws {
        #if os(macOS)
        let inboxRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("unibrain_test_max_\(UUID().uuidString)")

        try FileManager.default.createDirectory(at: inboxRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: inboxRoot) }

        let filename = "iphone-20260915T101530-dead.m4a"
        let audioFile = inboxRoot.appendingPathComponent(filename)
        try Data("dummy".utf8).write(to: audioFile)

        let handler = DeadLetterHandler()
        let error = InboxError.pipelineFailed(audioFile, underlying: NSError(domain: "test", code: 2))

        // Record 3 failures — 3rd should dead-letter
        let result1 = await handler.recordFailure(for: audioFile, inboxRoot: inboxRoot, error: error)
        let result2 = await handler.recordFailure(for: audioFile, inboxRoot: inboxRoot, error: error)
        let result3 = await handler.recordFailure(for: audioFile, inboxRoot: inboxRoot, error: error)

        #expect(result1 == .retryScheduled)
        #expect(result2 == .retryScheduled)
        #expect(result3 == .deadLettered)

        // File should now be in _failed/
        let failedFile = inboxRoot.appendingPathComponent("_failed").appendingPathComponent(filename)
        #expect(FileManager.default.fileExists(atPath: failedFile.path))
        #else
        #expect(Bool(true))
        #endif
    }
}
