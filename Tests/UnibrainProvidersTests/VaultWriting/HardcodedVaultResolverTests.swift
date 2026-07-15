import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

// Tests for HardcodedVaultResolver and PipelineWiring.
//
// Validates P-13 (vault root ~/Documents/Unibrain/),
// P-14 (lectures/YYYY-MM-DD-Lecture.md path),
// P-16 (does NOT write to _inbox/),
// and PipelineWiring orchestrator assembly.
//
// macOS-only: HardcodedVaultResolver uses FileManager.documentDirectory
// which is not available on Linux.

#if os(macOS)

@Suite("HardcodedVaultResolver")
struct HardcodedVaultResolverTests {

    // MARK: - P-13/P-14: Path Resolution

    @Test("resolve returns path under ~/Documents/Unibrain/lectures/")
    func resolveReturnsCorrectVaultPath() throws {
        let resolver = HardcodedVaultResolver()
        let recordingStart = Date(timeIntervalSince1970: 1723680000) // 2024-08-15

        let url = try resolver.resolve(match: .none, recordingStart: recordingStart)

        // P-13: vault root = ~/Documents/Unibrain/
        #expect(url.path.contains("Unibrain"))
        // P-14: lectures/ folder
        #expect(url.path.contains("lectures"))
        // P-14: filename pattern YYYY-MM-DD-Lecture.md
        #expect(url.lastPathComponent == "2024-08-15-Lecture.md")
    }

    @Test("resolve formats date as YYYY-MM-DD")
    func resolveFormatsDateCorrectly() throws {
        let resolver = HardcodedVaultResolver()

        // Test multiple dates
        let testCases: [(TimeInterval, String)] = [
            (1723680000, "2024-08-15"),  // Aug 15, 2024
            (1723766400, "2024-08-16"),  // Aug 16, 2024
            (1704067200, "2024-01-01"),  // Jan 1, 2024
        ]

        for (timestamp, expectedDate) in testCases {
            let url = try resolver.resolve(match: .none, recordingStart: Date(timeIntervalSince1970: timestamp))
            #expect(url.lastPathComponent == "\(expectedDate)-Lecture.md",
                    "Expected \(expectedDate)-Lecture.md but got \(url.lastPathComponent)")
        }
    }

    @Test("resolve creates lectures directory if it does not exist")
    func resolveCreatesLecturesDirectory() throws {
        let resolver = HardcodedVaultResolver()

        // Remove lectures dir if it exists, then resolve should recreate it
        let lecturesDir = HardcodedVaultResolver.lecturesDir
        if FileManager.default.fileExists(atPath: lecturesDir.path) {
            try FileManager.default.removeItem(at: lecturesDir)
        }

        #expect(!FileManager.default.fileExists(atPath: lecturesDir.path))

        _ = try resolver.resolve(match: .none, recordingStart: Date())

        #expect(FileManager.default.fileExists(atPath: lecturesDir.path))
    }

    // MARK: - P-16: _inbox/ Reserved

    @Test("resolve does NOT write to _inbox/")
    func resolveDoesNotUseInbox() throws {
        let resolver = HardcodedVaultResolver()
        let url = try resolver.resolve(match: .none, recordingStart: Date())

        #expect(!url.path.contains("_inbox"))
        #expect(!url.path.contains("inbox"))
    }

    // MARK: - CourseMatch Handling (Phase 3: all UNCLASSIFIED)

    @Test("resolve ignores CourseMatch.none and returns hardcoded path")
    func resolveIgnoresCourseMatchNone() throws {
        let resolver = HardcodedVaultResolver()
        let date = Date(timeIntervalSince1970: 1723680000)

        let urlNone = try resolver.resolve(match: .none, recordingStart: date)

        // Phase 3: all recordings are UNCLASSIFIED per P-14
        #expect(urlNone.path.contains("lectures"))
        #expect(urlNone.lastPathComponent == "2024-08-15-Lecture.md")
    }

    @Test("resolve ignores CourseMatch.single and returns same hardcoded path")
    func resolveIgnoresCourseMatchSingle() throws {
        let resolver = HardcodedVaultResolver()
        let date = Date(timeIntervalSince1970: 1723680000)

        let event = CalendarEvent(
            id: "test-1",
            title: "Intro to CS",
            startDate: date,
            endDate: date.addingTimeInterval(3600),
            location: "Room 101"
        )

        let urlSingle = try resolver.resolve(match: .single(event), recordingStart: date)

        // Phase 3: ignores the match, same hardcoded path
        #expect(urlSingle.lastPathComponent == "2024-08-15-Lecture.md")
        #expect(urlSingle.path.contains("lectures"))
    }

    // MARK: - Static Properties

    @Test("vaultRoot is under Documents/Unibrain")
    func vaultRootIsCorrect() {
        let root = HardcodedVaultResolver.vaultRoot

        #expect(root.path.contains("Documents"))
        #expect(root.path.contains("Unibrain"))
        #expect(root.lastPathComponent == "Unibrain")
    }

    @Test("lecturesDir is under vaultRoot/lectures")
    func lecturesDirIsCorrect() {
        let dir = HardcodedVaultResolver.lecturesDir

        #expect(dir.path.contains("Unibrain"))
        #expect(dir.path.contains("lectures"))
        #expect(dir.lastPathComponent == "lectures")
    }
}

@Suite("PipelineWiring")
struct PipelineWiringTests {

    @Test("makeOrchestrator returns a PipelineOrchestrator")
    func makeOrchestratorReturnsOrchestrator() throws {
        let modelPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("ggml-small.en.bin")

        let orchestrator = PipelineWiring.makeOrchestrator(modelPath: modelPath)

        // Verify the orchestrator is in idle state
        #expect(await orchestrator.currentState == .idle)
    }

    @Test("makeRecordingSession returns a RecordingSession")
    func makeRecordingSessionReturnsSession() async throws {
        let session = PipelineWiring.makeRecordingSession()

        let state = await session.currentState
        #expect(state == .idle)
    }

    @Test("makePipelineInputs maps RecordingResult correctly")
    func makePipelineInputsMapsCorrectly() throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_recording.m4a")
        let recordingResult = RecordingSession.Result(
            audioURL: audioURL,
            durationSeconds: 1800,
            pauseIntervals: []
        )
        let recordingStart = Date(timeIntervalSince1970: 1723680000)

        let inputs = PipelineWiring.makePipelineInputs(
            recordingResult: recordingResult,
            source: "MacBook Neo",
            recordingStart: recordingStart
        )

        #expect(inputs.recordingURL == audioURL)
        #expect(inputs.source == "MacBook Neo")
        #expect(inputs.durationSeconds == 1800)
        #expect(inputs.recordingStart == recordingStart)
        // Phase 3: no calendar events
        #expect(inputs.events.isEmpty)
        // recordingEnd should be after recordingStart
        #expect(inputs.recordingEnd > inputs.recordingStart)
    }

    @Test("makePipelineInputs sets recordingEnd based on duration")
    func makePipelineInputsSetsRecordingEnd() throws {
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_recording_2.m4a")
        let durationSeconds = 3600
        let recordingResult = RecordingSession.Result(
            audioURL: audioURL,
            durationSeconds: durationSeconds,
            pauseIntervals: []
        )
        let recordingStart = Date(timeIntervalSince1970: 1723680000)

        let inputs = PipelineWiring.makePipelineInputs(
            recordingResult: recordingResult,
            source: "MacBook Neo",
            recordingStart: recordingStart
        )

        let expectedEnd = recordingStart.addingTimeInterval(TimeInterval(durationSeconds))
        #expect(inputs.recordingEnd == expectedEnd)
    }
}

#endif // os(macOS)
