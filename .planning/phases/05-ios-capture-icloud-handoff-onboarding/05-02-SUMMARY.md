---
phase: 05-ios-capture-icloud-handoff-onboarding
plan: 02
subsystem: ios
tags: [ios, avaudiosession, background-audio, mpnowplayinginfo, tabview, icloud-handoff]

# Dependency graph
requires:
  - phase: 05-ios-capture-icloud-handoff-onboarding
    provides: OnboardingViewModel, BookmarkStore, PermissionsSheet, Info.plist keys
  - phase: 03-macos-capture-transcribe
    provides: AudioRecorder, RecordingSession actor
provides:
  - iOSAudioSessionManager — AVAudioSession .playAndRecord + interruption observer
  - iOSAudioSessionConfig — cross-platform testable config value type
  - NowPlayingManager — MPNowPlayingInfoCenter lock-screen display + MPRemoteCommandCenter handlers
  - NowPlayingMetadata — extracted dictionary builder for testability
  - InboxFilename — IC-03 cross-platform filename value type
  - iOSTabView / iOSRecordTab / iOSRecentTab / iOSSettingsTab — three-tab iOS shell
  - iOSRecordViewModel — @Observable record-only view model
affects: [05-03-icloud-handoff, 06-cloud-provider-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AVAudioSession .playAndRecord + .defaultToSpeaker + .allowBluetoothA2DP (IOS-03)"
    - "Interruption observer: AVAudioSession.interruptionNotification → onPause/onResume closures"
    - "mediaServicesWereResetNotification observer for full audio subsystem reset"
    - "MPNowPlayingInfoCenter lock-screen display via NowPlayingMetadata dictionary"
    - "MPRemoteCommandCenter: pauseCommand + togglePlayPauseCommand handlers"
    - "Extract cross-platform value types (iOSAudioSessionConfig, NowPlayingMetadata, InboxFilename) for Linux-testable coverage"

key-files:
  created:
    - Sources/UnibrainProviders/Capture/iOSAudioSessionManager.swift
    - Sources/UnibrainProviders/Capture/iOSAudioSessionConfig.swift
    - Sources/UnibrainProviders/Playback/NowPlayingManager.swift
    - Sources/UnibrainProviders/Playback/NowPlayingMetadata.swift
    - Sources/UnibrainProviders/Inbox/InboxFilename.swift
    - UnibrainApp/Views/iOS/iOSTabView.swift
    - UnibrainApp/Views/iOS/iOSRecordTab.swift
    - UnibrainApp/Views/iOS/iOSRecentTab.swift
    - UnibrainApp/Views/iOS/iOSSettingsTab.swift
    - Tests/UnibrainProvidersTests/Inbox/InboxFilenameTests.swift
    - Tests/UnibrainProvidersTests/Capture/iOSAudioSessionConfigTests.swift
    - Tests/UnibrainProvidersTests/Playback/NowPlayingMetadataTests.swift
  modified:
    - Sources/UnibrainProviders/Capture/AudioRecorder.swift
    - UnibrainApp/UnibrainApp.swift
    - UnibrainApp/ContentView.swift

key-decisions:
  - "iOSAudioSessionManager is @unchecked Sendable final class — interruption callbacks serialized via RecordingSession actor"
  - "AudioRecorder.start(to:) now calls iOSAudioSessionManager.configure() BEFORE AVAudioRecorder init (Pitfall 1)"
  - "iOSRecordViewModel is record-only (no transcribe pipeline) — iOS hands off to macOS via iCloud Drive"
  - "Cross-platform value types (iOSAudioSessionConfig, NowPlayingMetadata, InboxFilename) extracted to enable Linux SPM test coverage"
  - "NowPlayingMetadata uses String-literal keys (MPNowPlayingInfoPropertyElapsedPlaybackTime etc.) — avoids importing MediaPlayer on Linux"
  - "iOSSettingsTab embeds PermissionsSheet from Wave 1 — single source of permission audit UI"

patterns-established:
  - "Extract-testable-value-type: pure value types alongside #if os(iOS) classes for Linux SPM coverage"
  - "IO-01 (Interruption observer): Notification observer maps .began → onPause, .ended+shouldResume → onResume"
  - "IC-03 (Inbox filename): {source}-{YYYYMMDDTHHMMSS}-{uuidSuffix}.m4a — pure value type, cross-platform"

requirements-completed: [CAPT-03, DISC-04, IC-03, IOS-02, IOS-03]

coverage:
  - id: D1
    description: "AVAudioSession configured with .playAndRecord, .defaultToSpeaker, .allowBluetoothA2DP"
    requirement: "IOS-02"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Capture/iOSAudioSessionConfigTests.swift"
        status: pass
    human_judgment: true
    rationale: "Config value type tested on Linux; actual session activation requires iOS device"
  - id: D2
    description: "Interruption notification auto-pauses on .began, auto-resumes on .ended+shouldResume"
    requirement: "IOS-03"
    verification: []
    human_judgment: true
    rationale: "Requires physical iPhone + incoming call test — deferred to device verification"
  - id: D3
    description: "Lock screen displays 'Recording — {elapsed}' with Stop/Pause buttons"
    requirement: "IOS-02"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Playback/NowPlayingMetadataTests.swift"
        status: pass
    human_judgment: true
    rationale: "Metadata builder tested; lock-screen rendering requires iOS device"
  - id: D4
    description: "Inbox filename follows IC-03 pattern: {source}-{timestamp}-{uuid}.m4a"
    requirement: "IC-03"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Inbox/InboxFilenameTests.swift"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-16
status: complete
verification: deferred
---

# Phase 5 Plan 02: iOS Capture Surface — Background Recording + Now Playing + TabView Shell Summary

**iOS capture surface with background audio session, lock-screen Now Playing display, interruption auto-pause/resume, and three-tab iOS app shell**

## Performance

- **Duration:** ~8 min (code work; device verification deferred)
- **Tasks:** 2/3 complete (Task 3 = human-verify checkpoint, deferred)
- **Files modified:** 12 (9 created, 3 modified)

## Accomplishments

- **iOSAudioSessionManager:** configures AVAudioSession with `.playAndRecord + .defaultToSpeaker + .allowBluetoothA2DP`, observes `interruptionNotification` and `mediaServicesWereResetNotification` for auto-pause/resume (IOS-03)
- **NowPlayingManager:** `MPNowPlayingInfoCenter` lock-screen display updated each timer tick; `MPRemoteCommandCenter` wires `pauseCommand` and `togglePlayPauseCommand` (IOS-02)
- **AudioRecorder integration:** `start(to:)` now invokes `iOSAudioSessionManager.configure()` BEFORE `AVAudioRecorder` init (Pitfall 1 — session must be active first for background survival)
- **iOSTabView shell:** three-tab `TabView` (Record / Recent / Settings) per IOS-01
- **iOSRecordTab:** full-screen recording UI with 48pt monospaced timer, Canvas waveform (96pt), 3-segment mic meter, Pause/Stop buttons per IOS-04
- **iOSRecordViewModel:** `@Observable @MainActor` record-only view model owning `RecordingSession + NowPlayingManager`, polls at 30fps, moves audio to vault `_inbox/` on Stop with IC-03 filename
- **Cross-platform testability layer:** `iOSAudioSessionConfig`, `NowPlayingMetadata`, `InboxFilename` extracted as pure value types — 9 Linux SPM tests cover the logic without requiring iOS Simulator

## Task Commits

1. **Task 1: iOS audio session + Now Playing + interruption handling** — `8d26799` (feat) + `6d63b6c` (test)
2. **Task 2: iOS TabView shell + Record/Recent/Settings tabs** — `7f6c61e` (feat)
3. **Task 3: iOS device verification** — DEFERRED (verification_deferred_human)

## Files Created/Modified

### Created
- `Sources/UnibrainProviders/Capture/iOSAudioSessionManager.swift` — `#if os(iOS)` AVAudioSession config + interruption observer
- `Sources/UnibrainProviders/Capture/iOSAudioSessionConfig.swift` — cross-platform config value type
- `Sources/UnibrainProviders/Playback/NowPlayingManager.swift` — `#if os(iOS)` MPNowPlayingInfoCenter + MPRemoteCommandCenter
- `Sources/UnibrainProviders/Playback/NowPlayingMetadata.swift` — cross-platform metadata dictionary builder
- `Sources/UnibrainProviders/Inbox/InboxFilename.swift` — IC-03 filename value type
- `UnibrainApp/Views/iOS/iOSTabView.swift` — three-tab TabView shell
- `UnibrainApp/Views/iOS/iOSRecordTab.swift` — full-screen record UI (482 lines)
- `UnibrainApp/Views/iOS/iOSRecentTab.swift` — vault note list with empty state + pull-to-refresh
- `UnibrainApp/Views/iOS/iOSSettingsTab.swift` — Form with Permissions + About sections
- `Tests/UnibrainProvidersTests/Inbox/InboxFilenameTests.swift` — 4 tests
- `Tests/UnibrainProvidersTests/Capture/iOSAudioSessionConfigTests.swift` — 2 tests
- `Tests/UnibrainProvidersTests/Playback/NowPlayingMetadataTests.swift` — 3 tests

### Modified
- `Sources/UnibrainProviders/Capture/AudioRecorder.swift` — `start(to:)` calls `iOSAudioSessionManager.configure()` first
- `UnibrainApp/UnibrainApp.swift` — iOS branch renders `iOSTabView`, macOS pipeline guarded behind `#if os(macOS)` (Pitfall 6)
- `UnibrainApp/ContentView.swift` — explicitly guarded as macOS-only

## Decisions Made

- **Extract-testable-value-type pattern** — iOS-only classes (`iOSAudioSessionManager`, `NowPlayingManager`) paired with cross-platform value types (`iOSAudioSessionConfig`, `NowPlayingMetadata`) so logic is Linux-testable without iOS Simulator
- **NowPlayingMetadata uses String-literal keys** — avoids importing `MediaPlayer` on Linux while preserving the exact `MPNowPlayingInfoProperty*` keys at runtime
- **iOSRecordViewModel polls at 30fps** — drives both timer display and `MPNowPlayingInfoCenter` updates
- **iOSSettingsTab embeds PermissionsSheet** from Wave 1 — single source of permission audit UI across platforms

## Deviations from Plan

### Deferred Verification

**Task 3 (iOS device verification) deferred** — requires Apple Developer Program ($99/yr) activation + physical iPhone + iCloud Drive on both devices. Same blocker as Phase 03 Task 4 and Phase 04 04-05 Task 3. Code compiles on Linux (209 tests pass). Device testing resumable via `/gsd-verify-work 05`.

**Total deviations:** 1 deferred task (device verification)
**Impact on plan:** Code-complete. Verification deferred to device testing.

## Issues Encountered

None — code execution was clean. All SPM tests pass (209/209). iOS Simulator cannot test background recording survival (30+ min lock screen), real audio interruptions, or iCloud Drive sync — all require physical device.

## User Setup Required

- **Apple Developer Program** ($99/yr) — required for TestFlight deployment to Angelica's iPhone
- **iCloud Drive** enabled on both MacBook and iPhone with the same Apple ID
- **Onboarding completed on macOS first** — then iPhone picks the same iCloud Drive folder via BookmarkStore

## Next Phase Readiness

- iOS capture surface is code-complete and ready for Plan 03 (macOS iCloud handoff) to consume the `_inbox/` files that iOS writes
- `InboxFilename` IC-03 naming pattern is testable and ready for `InboxWatcher` to detect on macOS
- Device verification deferred — does not block Wave 3 (05-03) which is macOS-side inbox watching

---
*Phase: 05-ios-capture-icloud-handoff-onboarding*
*Completed: 2026-07-16 (code); device verification deferred*
