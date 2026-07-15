---
phase: 03-macos-capture-transcribe
plan: 01
subsystem: audio-capture
tags: [avfoundation, audio-recording, state-machine, swift-actor]
dependency_graph:
  requires:
    - UnibrainCore (ProviderError pattern, no direct dependency)
  provides:
    - AudioRecorder (AVAudioRecorder wrapper with start/stop/pause/resume + level metering)
    - RecordingSession (actor state machine: idle/recording/paused/stopped with elapsed time tracking)
  affects:
    - Menu-bar popover UI (will consume RecordingSession for live timer + mic meter)
    - PipelineOrchestrator (will consume RecordingResult.audioURL as PipelineInputs.recordingURL)
tech_stack:
  added:
    - AVFoundation (AVAudioRecorder, AVAudioSession)
  patterns:
    - Actor-based state machine with Sendable isolation
    - Temp-then-move file lifecycle (P-D2 crash safety)
    - Pause interval tracking for inline transcript markers (P-D1)
key_files:
  created:
    - Sources/UnibrainProviders/Capture/AudioRecorder.swift
    - Sources/UnibrainProviders/Capture/RecordingSession.swift
    - Tests/UnibrainProvidersTests/Capture/AudioRecorderTests.swift
    - Tests/UnibrainProvidersTests/Capture/RecordingSessionTests.swift
  modified: []
decisions:
  - "Used PauseInterval struct (Sendable) instead of raw tuple for type safety and future extensibility"
  - "AudioRecorder is @unchecked Sendable class — AVAudioRecorder is not Sendable but access is serialized via RecordingSession actor"
  - "RecordingSession.Error enum shadows Swift.Error within namespace — tests use (any Error).self existential to avoid ambiguity"
  - "isPaused on AudioRecorder uses currentTime > 0 heuristic — RecordingSession actor state is authoritative"
metrics:
  duration: 15m
  completed: "2026-07-15"
  tasks: 2
  files: 4
status: complete
---

# Phase 03 Plan 01: Audio Capture Layer Summary

AVAudioRecorder wrapper producing 16kHz mono AAC .m4a files with pause/resume and live mic-level metering, plus a RecordingSession actor state machine tracking elapsed time and driving the recording lifecycle.

## What Was Built

### AudioRecorder (Sources/UnibrainProviders/Capture/AudioRecorder.swift)

A `final class` wrapping `AVAudioRecorder` that provides:

- **start(to:)** — Configures AVAudioSession with `.playAndRecord` category, creates an AVAudioRecorder with 16kHz mono AAC settings (CAPT-06), enables metering BEFORE recording starts (Pitfall 3), and begins recording.
- **pause()/resume()** — Delegates to AVAudioRecorder.pause()/record() for contiguous file recording (CAPT-02).
- **stop()** — Finalizes the recording and releases the recorder instance.
- **currentLevel** — Returns `averagePower(forChannel: 0)` in dB (-160.0 to 0.0) for the mic-level meter (CAPT-05).
- **isMeteringEnabled** — Read-only property verifying metering is active.
- **audioSettings** — Static constant exposing the 16kHz/mono/AAC/high-quality settings dictionary.

The class is `@unchecked Sendable` because `AVAudioRecorder` is not Sendable, but all access is serialized through the `RecordingSession` actor.

### RecordingSession (Sources/UnibrainProviders/Capture/RecordingSession.swift)

A `public actor` implementing the recording lifecycle state machine:

- **States**: `idle` → `recording` → `paused` → `stopped` (with `reset()` returning to `idle`).
- **startRecording(destination:)** — Creates a temp URL in NSTemporaryDirectory(), starts AudioRecorder, stores the destination URL for later move (P-D2).
- **pause()** — Pauses the recorder, records `pausedAt` timestamp.
- **resume()** — Computes pause duration, adds to `totalPausedTime`, records a `PauseInterval` for P-D1 inline transcript markers, resumes the recorder.
- **stop()** — Stops the recorder, computes final duration, moves temp file to destination via `FileManager.moveItem`, returns `RecordingSession.Result`.
- **elapsedSeconds** — Computes live recording time excluding paused intervals (CAPT-04). Freezes when paused.
- **currentLevel** — Delegates to `AudioRecorder.currentLevel` (CAPT-05).
- **reset()** — Clears all state for session reuse.
- **Error handling** — Typed `Error` enum with `.alreadyRecording`, `.notRecording`, `.notPaused`, `.notActive` for invalid transitions.

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (Task 1) | d3a2570 — `test(03-01): add failing tests for AudioRecorder` | PASS |
| GREEN (Task 1) | 341389a — `feat(03-01): implement AudioRecorder` | PASS |
| RED (Task 2) | 067623f — `test(03-01): add failing tests for RecordingSession` | PASS |
| GREEN (Task 2) | 21777d7 — `feat(03-01): implement RecordingSession` | PASS |

Both tasks followed strict RED → GREEN cycle. Tests were written first, committed as failing, then implementation was committed to pass them.

## Requirement Coverage

| Requirement | How Satisfied | Verification |
|-------------|---------------|--------------|
| CAPT-01 | AudioRecorder.start(to:)/stop() + RecordingSession.startRecording()/stop() | AudioRecorderTests: startProducesValidM4AFile, stopFinalizesRecording |
| CAPT-02 | AudioRecorder.pause()/resume() maintain single file; RecordingSession tracks pause state | AudioRecorderTests: pauseResumeProducesContiguousFile; RecordingSessionTests: pause/resume transition tests |
| CAPT-04 | RecordingSession.elapsedSeconds computes live time excluding pauses | RecordingSessionTests: elapsedSecondsIncreasesDuringRecording, elapsedSecondsExcludesPausedTime |
| CAPT-05 | AudioRecorder.currentLevel returns averagePower dB; RecordingSession.currentLevel delegates | AudioRecorderTests: currentLevelReturnsMeaningfulValue, currentLevelReturnsSilenceWhenNotRecording |
| CAPT-06 | AudioRecorder.audioSettings: 16kHz, mono, AAC, high quality | AudioRecorderTests: audioSettingsAre16kHzMonoAAC |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical Functionality] PauseInterval as Sendable struct instead of raw tuple**
- **Found during:** Task 2 implementation
- **Issue:** Plan specified `pauseIntervals returns [(start: TimeInterval, duration: TimeInterval)]` — a tuple array. Tuples are not Sendable in Swift 6, which would prevent `RecordingSession.Result` from being Sendable.
- **Fix:** Created `RecordingSession.PauseInterval` as a `Sendable, Equatable` struct with `start` and `duration` properties. This preserves the same API surface (`.start`, `.duration` access) while satisfying Swift 6 strict concurrency.
- **Files modified:** RecordingSession.swift (implementation), RecordingSessionTests.swift (tests use `.start` and `.duration` which work identically)
- **Commit:** 21777d7

None - plan executed as written except for the Sendable tuple fix above.

## Known Stubs

None — all code is fully implemented. No placeholder values, no TODO/FIXME markers, no empty implementations.

## Threat Flags

None — no new network endpoints, auth paths, or file access patterns beyond the plan's scope. Audio recording writes to the local temp directory; no external input is processed.

## Verification

Build and test verification deferred to macOS CI (GitHub Actions macos-15 runner). WSL2 has no Swift compiler or AVFoundation framework. All tests are guarded with `#if canImport(AVFoundation)` so they compile on Linux (as no-ops) and execute on macOS CI.

**CI verification commands:**
- `swift build` — verifies both source files compile
- `swift test --filter UnibrainProvidersTests.AudioRecorderTests` — verifies Task 1
- `swift test --filter UnibrainProvidersTests.RecordingSessionTests` — verifies Task 2
- `swift test --filter UnibrainProvidersTests` — verifies all provider tests

## Self-Check: PASSED

- [x] Sources/UnibrainProviders/Capture/AudioRecorder.swift exists
- [x] Sources/UnibrainProviders/Capture/RecordingSession.swift exists
- [x] Tests/UnibrainProvidersTests/Capture/AudioRecorderTests.swift exists
- [x] Tests/UnibrainProvidersTests/Capture/RecordingSessionTests.swift exists
- [x] Commit d3a2570 exists (RED Task 1)
- [x] Commit 341389a exists (GREEN Task 1)
- [x] Commit 067623f exists (RED Task 2)
- [x] Commit 21777d7 exists (GREEN Task 2)
