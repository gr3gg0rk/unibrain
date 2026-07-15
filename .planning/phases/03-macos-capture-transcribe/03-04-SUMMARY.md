---
phase: 03-macos-capture-transcribe
plan: 04
subsystem: ui
tags: [swiftui, macos, menu-bar, avfoundation, observational-viewmodel]

# Dependency graph
requires:
  - phase: 03-macos-capture-transcribe
    provides: RecordingSession actor (03-01), SmallEnDownloader + TranscriberRouter (03-02), PipelineWiring + HardcodedVaultResolver + NSFileCoordinatorNoteWriter (03-03)
provides:
  - MenuBarViewModel @Observable bridge wiring RecordingSession + SmallEnDownloader + PipelineOrchestrator into SwiftUI
  - MenuBarPopover SwiftUI view rendering all popover states (idle, recording, paused, transcribing, error) with live timer, waveform, mic meter
  - UnibrainApp menu-bar shell with state-driven MenuBarExtra icon and notification permission
affects: [04-course-classification-smart-routing, 05-ios-capture-icloud-handoff-onboarding, 06-gated-summarization-cloud-providers-mvp-polish]

# Tech tracking
tech-stack:
  added: [SwiftUI MenuBarExtra, @Observable macro, UNUserNotificationCenter, TimelineView, Canvas]
  patterns: [@Observable @MainActor view model bridging actor dependencies to SwiftUI, state-driven MenuBarExtra label, Task.detached for off-main-thread pipeline execution]

key-files:
  created:
    - UnibrainApp/ViewModels/MenuBarViewModel.swift
    - UnibrainApp/MenuBarPopover.swift
  modified:
    - UnibrainApp/UnibrainApp.swift
    - UnibrainApp/ContentView.swift

key-decisions:
  - "MenuBarViewModel uses @Observable + @MainActor (iOS 17+ / macOS 14+) instead of ObservableObject — matches PROJECT.md deployment targets and avoids thread-hop overhead"
  - "Pipeline execution runs in Task.detached(priority: .userInitiated) from stopRecording() so the menu bar stays interactive (TRAN-03)"
  - "State-driven icon per P-D3: brain (idle), brain.fill red (recording), brain.fill yellow (paused), brain.fill accent (transcribing)"
  - "Popover locked to 280pt width per UI-SPEC P-08 layout token"
  - "Background model download starts via .task modifier on first app launch (P-17) — no user action required"

patterns-established:
  - "@Observable @MainActor view model: the SwiftUI-facing pattern for bridging actor-isolated pipeline dependencies into views (reusable for Phase 4+ screens)"
  - "State-driven MenuBarExtra label: switch on sessionState for icon/color — extensible to additional states in Phase 4/5/6"
  - "Task.detached for pipeline execution: the standard recipe for keeping UI responsive while the orchestrator runs"

requirements-completed: [CAPT-01, CAPT-02, CAPT-04, CAPT-05, CAPT-06]

# Coverage metadata (#1602) — UI deliverables require macOS device verification (no Linux CI path).
# Task 4 in PLAN is `checkpoint:human-verify` for the full record → transcribe → write flow.
coverage:
  - id: D1
    description: "MenuBarViewModel @Observable view model bridging RecordingSession, SmallEnDownloader, and PipelineOrchestrator"
    requirement: CAPT-01
    verification: []
    human_judgment: true
    rationale: "ViewModel wiring can only be verified by running the macOS app and observing state transitions through the popover — no Linux-testable surface."
  - id: D2
    description: "MenuBarPopover SwiftUI view with all states (idle, recording, paused, transcribing, error), live timer, waveform Canvas, and 3-segment mic-level meter"
    requirement: CAPT-04
    verification: []
    human_judgment: true
    rationale: "SwiftUI/AppKit rendering requires macOS; waveform + mic meter are interactive-run observables. Phase 3 has no screenshot/UI test harness on Linux."
  - id: D3
    description: "Pause/resume flow with contiguous final .m4a and pause timestamps preserved (CAPT-02, CAPT-06)"
    requirement: CAPT-02
    verification: []
    human_judgment: true
    rationale: "Requires recording real audio on a Mac and inspecting the resulting .m4a + frontmatter; cannot be exercised on Linux."
  - id: D4
    description: "State-driven MenuBarExtra icon transitioning brain / brain.fill red / brain.fill yellow / brain.fill accent per P-D3"
    requirement: CAPT-05
    verification: []
    human_judgment: true
    rationale: "Menu-bar rendering and icon tinting are macOS-only; verified via the 11-step checklist in PLAN Task 4."
  - id: D5
    description: "Responsive UI during transcription — menu bar stays interactive, no beachball (TRAN-03)"
    requirement: CAPT-06
    verification: []
    human_judgment: true
    rationale: "Requires running app on macOS while transcription executes; Xcode Time Profiler verification per PLAN Success Criteria #4."

# Metrics
duration: 9min
completed: 2026-07-15
status: complete
---

# Phase 3 Plan 4: Menu-bar Popover UI Summary

**SwiftUI menu-bar recording surface with state-driven icon, live waveform, mic meter, and Task.detached pipeline execution — the user-facing capstone of Phase 3.**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-07-14T21:03:03-07:00 (after 03-03 docs commit)
- **Completed:** 2026-07-14T21:12:40-07:00 (Task 3 commit `2242d3c`)
- **Tasks:** 3 auto tasks committed (Task 4 is `checkpoint:human-verify`, outstanding)
- **Files modified:** 4 (+876 lines)

## Accomplishments
- `MenuBarViewModel` (`@Observable @MainActor`) wiring all three actor dependencies into a single UI-facing state machine with display-state enum, rolling waveform buffer (64 samples), mic-level polling, and download-progress observation
- `MenuBarPopover` SwiftUI view rendering all five states per UI-SPEC: idle (readiness + Record), recording (timer + Canvas waveform + 3-segment mic meter + Pause/Stop), paused (frozen timer + caption + Resume/Stop), transcribing (spinner + ETA), error (warning + Retry)
- `UnibrainApp` shell wiring `MenuBarExtra` with state-driven icon per P-D3 (brain / brain.fill red/yellow/accent), background model download via `.task` (P-17), `UNUserNotificationCenter` permission request, and minimal `WindowGroup` containing `ContentView` for future Settings (Phase 6)
- Pipeline execution dispatched via `Task.detached(priority: .userInitiated)` on Stop — keeps MainActor free so the menu bar stays interactive (TRAN-03)

## Task Commits

Each task was committed atomically:

1. **Task 1: MenuBarViewModel** — `e2b7afb` (feat)
2. **Task 2: MenuBarPopover SwiftUI view** — `0b168f8` (feat)
3. **Task 3: MenuBarExtra wiring with state-driven icon** — `2242d3c` (feat)

**Task 4: Human verification** — NOT YET COMPLETE. The 11-step macOS device checklist (icon states, record/pause/resume/stop flow, transcription completion notification, vault file write-out, UI responsiveness) is the gate that closes Phase 3.

## Files Created/Modified
- `UnibrainApp/ViewModels/MenuBarViewModel.swift` (375 lines) — `@Observable @MainActor` view model, display-state enum, polling tasks, Task.detached pipeline dispatch
- `UnibrainApp/MenuBarPopover.swift` (350 lines) — All five popover states with Canvas waveform, TimelineView animation, mic-level meter, monospaced timer
- `UnibrainApp/UnibrainApp.swift` (+108 lines) — MenuBarExtra with state-driven label, PipelineWiring init, notification permission, background model download
- `UnibrainApp/ContentView.swift` (+48 lines) — Minimal window content showing app name and session state label (future Settings entry, Phase 6)

## Decisions Made
- Used `@Observable @MainActor` (iOS 17+ / macOS 14+) instead of `ObservableObject`/`@Published` — matches PROJECT.md deployment targets and removes Combine thread-hop overhead
- Polling at ~30fps for waveform/mic meter rather than AVAudioEngine tap — keeps RecordingSession API stable (Phase 3 Manager's contract) and avoids double-buffering on 8GB
- `Task.detached(priority: .userInitiated)` rather than plain `Task` for pipeline dispatch — explicit non-MainActor isolation so the orchestrator's actor hopping is the only concurrency boundary

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `NoteWriter` protocol marked `Sendable` to satisfy Swift 6 data-race safety**
- **Found during:** Post-execution verification (full `swift build` after Task 3 landed)
- **Issue:** `PipelineOrchestrator.swift:191` failed compilation: `sending 'self'-isolated 'self.writer' to nonisolated instance method 'write(_:to:)' risks causing data races`. `PipelineTranscriber` and `VaultPathResolver` were already `Sendable`; `NoteWriter` was the lone holdout.
- **Fix:** Added `Sendable` conformance to the `NoteWriter` protocol declaration. All production and test conformers (`NSFileCoordinatorNoteWriter`, `TestNoteWriter`, `MockNoteWriter`, `TrackingNoteWriter`) were already implicitly or explicitly `Sendable`.
- **Files modified:** `Sources/UnibrainCore/Normalization/NoteWriter.swift`
- **Verification:** `swift build --target UnibrainCore` completes clean (0.23s) with no sendability errors
- **Committed in:** this summary's accompanying fix commit

---

**Total deviations:** 1 auto-fixed (1 blocking Swift 6 conformance)
**Impact on plan:** Auto-fix necessary for the project to compile under Swift 6 strict concurrency. Aligns `NoteWriter` with the `Sendable` pattern already established for the other two pipeline protocols. No scope creep.

## Issues Encountered
- `swift build` on WSL2 still fails after this plan, but ONLY because `SmallEnDownloader` imports `CryptoKit` (Apple-only). This was flagged in 03-02 SUMMARY and is the expected platform boundary — full build verification happens on the GitHub Actions `macos-15` runner. `swift build --target UnibrainCore` (which contains the sendability fix) succeeds cleanly on Linux.

## User Setup Required
None — no external service configuration required for the UI plan. (Model download destinations and SmallEnDownloader setup were handled in 03-02.)

## Next Phase Readiness
- **Ready for Phase 4:** The `@Observable @MainActor` view-model pattern is reusable for the course-picker / current-term UI in Phase 4. MenuBarViewModel already exposes `sessionState` and is extensible.
- **Ready for Phase 5:** The menu-bar shell + window group pattern ports to iOS with `#if os(macOS)` guards already in place on `MenuBarExtra`.
- **Ready for Phase 6:** `ContentView` has the hook for a future Settings entry point; Settings provider selectors (Phase 6) can land there.
- **Blocker before Phase 3 closes:** Task 4 human verification on a macOS device. Angelica's MacBook Neo is the target device; until then Phase 3 cannot be marked complete.
- **Existing concerns carried forward:** whisper.cpp + Metal SPM integration still flagged as riskiest step; Phase 2 verification (`/gsd-verify-work 02`) still deferred.

---
*Phase: 03-macos-capture-transcribe*
*Completed: 2026-07-15*
