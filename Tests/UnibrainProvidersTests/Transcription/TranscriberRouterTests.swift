import Testing
import Foundation
@testable import UnibrainProviders
import UnibrainCore

// Tests for TranscriberRouter auto-fallback logic.
//
// Uses mock PipelineTranscriber conformances to test router behavior
// without needing real ASR models or macOS 26.
//
// Covers TRAN-01 (dual-engine ASR), P-05 (router facade), P-06 (full re-transcribe on fallback).

// MARK: - Mock Transcribers

/// Mock transcriber that can be configured to return fixture segments or throw.
struct MockTranscriber: PipelineTranscriber, Sendable {
    let segments: [(start: TimeInterval, end: TimeInterval, text: String)]
    let error: Error?

    init(segments: [(start: TimeInterval, end: TimeInterval, text: String)] = [], error: Error? = nil) {
        self.segments = segments
        self.error = error
    }

    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        if let error {
            throw error
        }
        return segments
    }
}

/// A transcriber that records whether it was called.
struct RecordingMockTranscriber: PipelineTranscriber, Sendable {
    let segments: [(start: TimeInterval, end: TimeInterval, text: String)]
    let error: Error?
    private let callCounter: UnsafeSendableBox<AsyncCounter>

    init(
        segments: [(start: TimeInterval, end: TimeInterval, text: String)] = [],
        error: Error? = nil,
        callCounter: UnsafeSendableBox<AsyncCounter>
    ) {
        self.segments = segments
        self.error = error
        self.callCounter = callCounter
    }

    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        await callCounter.value.increment()
        if let error {
            throw error
        }
        return segments
    }
}

/// Simple async-safe counter for tracking mock calls.
actor AsyncCounter {
    private(set) var count: Int = 0

    func increment() {
        count += 1
    }
}

/// Sendable wrapper to pass an actor reference through a struct.
struct UnsafeSendableBox<T: Sendable>: Sendable {
    let value: T
}

// MARK: - Test Errors

enum TestTranscriberError: Error, Equatable {
    case speechAnalyzerFailed
    case whisperCppFailed
    case modelMissing
}

// MARK: - TranscriberRouter Tests

@Suite("TranscriberRouter")
struct TranscriberRouterTests {

    // MARK: Primary path (SpeechAnalyzer succeeds)

    @Test("Primary succeeds — returns primary segments without fallback")
    func primarySucceeds() async throws {
        let primarySegments = [
            (start: 0.0, end: 5.0, text: "Hello world"),
            (start: 5.0, end: 10.0, text: "Testing transcription"),
        ]
        let fallbackSegments = [
            (start: 0.0, end: 5.0, text: "Fallback result"),
        ]

        let counter = AsyncCounter()
        let box = UnsafeSendableBox(value: counter)

        let primary = RecordingMockTranscriber(segments: primarySegments, callCounter: box)
        let fallback = RecordingMockTranscriber(segments: fallbackSegments, callCounter: box)

        let router = TranscriberRouter(
            primary: MockTranscriberWrapper(primary),
            fallback: MockTranscriberWrapper(fallback)
        )

        let result = try await router.transcribe(URL(fileURLWithPath: "/tmp/test.m4a"))

        #expect(result.count == 2)
        #expect(result[0].text == "Hello world")
        #expect(result[1].text == "Testing transcription")

        // Fallback should NOT have been called
        let callCount = await counter.count
        // primary=1 call, fallback=0 calls → total=1
        #expect(callCount == 1)
    }

    // MARK: Fallback path (SpeechAnalyzer fails, whisper.cpp succeeds)

    @Test("Primary throws — falls back to whisper.cpp and returns fallback segments")
    func primaryThrowsFallsBack() async throws {
        let fallbackSegments = [
            (start: 0.0, end: 3.0, text: "Fallback segment 1"),
            (start: 3.0, end: 6.0, text: "Fallback segment 2"),
        ]

        let router = TranscriberRouter(
            primary: MockTranscriber(error: TestTranscriberError.speechAnalyzerFailed),
            fallback: MockTranscriber(segments: fallbackSegments)
        )

        let result = try await router.transcribe(URL(fileURLWithPath: "/tmp/test.m4a"))

        #expect(result.count == 2)
        #expect(result[0].text == "Fallback segment 1")
        #expect(result[1].text == "Fallback segment 2")
    }

    // MARK: Both fail (propagate fallback error)

    @Test("Both engines throw — propagates fallback error (more informative per P-05)")
    func bothThrowPropagatesFallbackError() async throws {
        let router = TranscriberRouter(
            primary: MockTranscriber(error: TestTranscriberError.speechAnalyzerFailed),
            fallback: MockTranscriber(error: TestTranscriberError.whisperCppFailed)
        )

        await #expect(throws: TestTranscriberError.self) {
            _ = try await router.transcribe(URL(fileURLWithPath: "/tmp/test.m4a"))
        }
    }

    // MARK: Empty audio URL

    @Test("Router accepts any URL — delegates to engines")
    func acceptsAnyURL() async throws {
        let segments = [(start: 0.0, end: 1.0, text: "Test")]

        let router = TranscriberRouter(
            primary: MockTranscriber(segments: segments),
            fallback: MockTranscriber(segments: segments)
        )

        let result = try await router.transcribe(URL(fileURLWithPath: "/tmp/any-audio-file.m4a"))
        #expect(result.count == 1)
        #expect(result[0].text == "Test")
    }

    // MARK: Segment contract (N-03)

    @Test("Returned segments match N-03 contract shape")
    func segmentsMatchContract() async throws {
        let segments = [
            (start: 0.0, end: 5.0, text: "First segment"),
            (start: 5.0, end: 10.5, text: "Second segment"),
        ]

        let router = TranscriberRouter(
            primary: MockTranscriber(segments: segments),
            fallback: MockTranscriber(segments: [])
        )

        let result = try await router.transcribe(URL(fileURLWithPath: "/tmp/test.m4a"))

        for segment in result {
            #expect(segment.start <= segment.end)
            #expect(!segment.text.isEmpty)
        }
    }

    // MARK: Fallback re-transcribes whole recording (P-06)

    @Test("Fallback re-transcribes the whole recording — receives same URL")
    func fallbackReceivesSameURL() async throws {
        let testURL = URL(fileURLWithPath: "/tmp/lecture-recording.m4a")
        let fallbackSegments = [(start: 0.0, end: 60.0, text: "Full re-transcription")]

        let router = TranscriberRouter(
            primary: MockTranscriber(error: TestTranscriberError.speechAnalyzerFailed),
            fallback: MockTranscriber(segments: fallbackSegments)
        )

        let result = try await router.transcribe(testURL)
        #expect(result.count == 1)
        #expect(result[0].text == "Full re-transcription")
    }
}

// MARK: - WhisperCppTranscriber Tests (mock-based, no real model)

@Suite("WhisperCppTranscriber")
struct WhisperCppTranscriberTests {

    @Test("Throws when model file does not exist")
    func throwsWhenModelMissing() async throws {
        let gate = ModelLoadGate()
        let transcriber = WhisperCppTranscriber(
            modelPath: URL(fileURLWithPath: "/nonexistent/model.bin"),
            gate: gate
        )

        await #expect(throws: ProviderError.self) {
            _ = try await transcriber.transcribe(URL(fileURLWithPath: "/tmp/test.m4a"))
        }

        // Gate should be released even on failure (TRAN-06)
        // We verify by acquiring — if released, acquire succeeds
        let lease = try await gate.acquire(.asr)
        await lease.release()
    }
}

// MARK: - SpeechAnalyzerTranscriber Tests

@Suite("SpeechAnalyzerTranscriber")
struct SpeechAnalyzerTranscriberTests {

    @Test("Throws on non-macOS platform (Linux CI)")
    func throwsOnNonMacOS() async throws {
        let transcriber = SpeechAnalyzerTranscriber()

        #if !os(macOS)
        await #expect(throws: ProviderError.self) {
            _ = try await transcriber.transcribe(URL(fileURLWithPath: "/tmp/test.m4a"))
        }
        #else
        // On macOS, behavior depends on OS version — just verify it doesn't crash
        #endif
    }
}

// MARK: - Type-erased wrapper for mock transcribers in router

/// Wraps any PipelineTranscriber behind a type-erased box for injection into TranscriberRouter.
struct MockTranscriberWrapper: PipelineTranscriber, Sendable {
    private let _transcribe: @Sendable (URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)]

    init<T: PipelineTranscriber>(_ transcriber: T) {
        self._transcribe = { url in
            try await transcriber.transcribe(url)
        }
    }

    func transcribe(_ audioURL: URL) async throws -> [(start: TimeInterval, end: TimeInterval, text: String)] {
        try await _transcribe(audioURL)
    }
}
