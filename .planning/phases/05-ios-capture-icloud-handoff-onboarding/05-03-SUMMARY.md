---
phase: 05-ios-capture-icloud-handoff-onboarding
plan: 03
subsystem: inbox
tags: [icloud-handoff, nsmetadataquery, fifo-queue, dead-letter, inbox-watcher, macos]

# Dependency graph
requires:
  - phase: 05-ios-capture-icloud-handoff-onboarding
    provides: InboxFilename (IC-03), BookmarkStore, OnboardingViewModel
  - phase: 03-macos-capture-transcribe
    provides: PipelineOrchestrator, PipelineWiring, NSFileCoordinatorNoteWriter, MenuBarViewModel
  - phase: 04-course-classification-smart-routing
    provides: ScheduleAwareVaultResolver, CourseMappingStore, CourseMapping
provides:
  - InboxWatcher — NSMetadataQuery wrapper for _inbox/ monitoring (macOS-only)
  - InboxQueue — serial FIFO queue actor (macOS-only)
  - InboxFileDownloader — .icloud placeholder detection + active download + poll (macOS-only)
  - DeadLetterHandler — retry tracking + backoff + dead-letter to _failed/ with sidecar (macOS-only)
  - InboxError — structured error enum for inbox pipeline (macOS-only)
  - InboxProcessingState — display state enum for popover queue progress
  - DeadLetterSidecar — Codable sidecar JSON struct (T-05-10 metadata-only)
affects: [06-cloud-provider-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSMetadataQuery path-based scope for external iCloud folders (TRIG-01, A1)"
    - "Hybrid launch scan + live watch: FileManager.contentsOfDirectory on start + NSMetadataQuery for live monitoring (TRIG-01)"
    - "Serial FIFO queue actor with de-duplication (TRIG-02)"
    - "IC-04 active download: URL.startDownloadingUbiquitousItem + poll ubiquitousItemDownloadingStatusKey every 2s up to 120s timeout"
    - "TRIG-04 dead-letter: move file to _failed/ with .error.json sidecar (DeadLetterSidecar Codable struct, metadata-only per T-05-10)"
    - "TRIG-03 move-on-success: audio moves from _inbox/ to {vault}/{term}/{course}/ after pipeline success"
    - "InboxProcessingState enum drives popover rendering (idle/downloading/transcribing/failed)"

key-files:
  created:
    - Sources/UnibrainProviders/Inbox/InboxError.swift
    - Sources/UnibrainProviders/Inbox/InboxQueue.swift
    - Sources/UnibrainProviders/Inbox/DeadLetterHandler.swift
    - Sources/UnibrainProviders/Inbox/InboxFileDownloader.swift
    - Sources/UnibrainProviders/Inbox/InboxWatcher.swift
    - Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift
    - Tests/UnibrainProvidersTests/Inbox/DeadLetterHandlerTests.swift
    - Tests/UnibrainProvidersTests/Inbox/InboxFileDownloaderTests.swift
  modified:
    - Sources/UnibrainCore/Errors/NoteWriterError.swift
    - Sources/UnibrainProviders/Pipeline/PipelineWiring.swift
    - UnibrainApp/ViewModels/MenuBarViewModel.swift
    - UnibrainApp/MenuBarPopover.swift
    - Tests/UnibrainCoreTests/NormalizationTests/NoteWriterTests.swift

key-decisions:
  - "InboxQueue is in-memory actor (CONTEXT discretion) — launch scan (TRIG-01) recovers lost files on restart"
  - "DeadLetterHandler uses actor isolation for retryTracker — no concurrent access concern since queue is serial (TRIG-02)"
  - "InboxFileDownloader detects .icloud via pathExtension == 'icloud' — simplest reliable detection per Pitfall 5"
  - "DeadLetterSidecar uses snake_case CodingKeys for JSON interop across iCloud-synced devices (mirrors CourseMappingDocument pattern)"
  - "InboxProcessingState enum is Equatable for SwiftUI diffing — custom == due to associated values"
  - "PipelineWiring.processInboxFile searches for recently created note to derive audio destination (P-15 alongside note)"
  - "parseRecordingStart extracts IC-03 YYYYMMDDTHHMMSS from filename, falls back to file creation date"

patterns-established:
  - "TRIG-01 (Hybrid watcher): FileManager launch scan on start() + NSMetadataQuery for live monitoring"
  - "TRIG-02 (Serial FIFO): actor-isolated queue with de-duplication, processNext returns nil when empty"
  - "TRIG-03 (Move-on-success): audio moves from _inbox/ to course folder after pipeline writes note"
  - "TRIG-04 (Retry+dead-letter): 3 retries with [30s, 2min, 10min] backoff, then dead-letter to _failed/ with sidecar"
  - "IC-04 (Active download): checkFileStatus detects .icloud, startDownload triggers ubiquitous item download + polls"
  - "T-05-10 (Sidecar safety): DeadLetterSidecar contains only metadata — error_type, error_message, retry_count, failed_at, original_filename"

requirements-completed: [CAPT-03, DISC-04]

coverage:
  - id: D1
    description: "InboxQueue processes files FIFO with de-duplication"
    requirement: "TRIG-02"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift"
        status: unknown
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift#processNextReturnsNilWhenEmpty"
        status: unknown
    human_judgment: true
    rationale: "Tests are #if os(macOS)-guarded — run on macOS CI; status unknown until CI execution"
  - id: D2
    description: "DeadLetterHandler moves files to _failed/ with sidecar, tracks retries"
    requirement: "TRIG-04"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Inbox/DeadLetterHandlerTests.swift"
        status: unknown
    human_judgment: true
    rationale: "Tests are #if os(macOS)-guarded — run on macOS CI"
  - id: D3
    description: "InboxFileDownloader detects .icloud placeholders and real .m4a files"
    requirement: "IC-04"
    verification:
      - kind: unit
        ref: "Tests/UnibrainProvidersTests/Inbox/InboxFileDownloaderTests.swift"
        status: unknown
    human_judgment: true
    rationale: "Tests are #if os(macOS)-guarded — run on macOS CI"
  - id: D4
    description: "InboxWatcher detects new _inbox/ files via NSMetadataQuery + launch scan"
    requirement: "TRIG-01"
    verification: []
    human_judgment: true
    rationale: "NSMetadataQuery requires real iCloud-synced folder — device verification needed"
  - id: D5
    description: "macOS popover shows iCloud Inbox queue progress + failure recovery"
    requirement: "UI-SPEC Surface 4"
    verification: []
    human_judgment: true
    rationale: "SwiftUI rendering — manual macOS device verification"

# Metrics
duration: 12min
completed: 2026-07-16
status: complete
verification: deferred
---

# Phase 5 Plan 03: iCloud Handoff Queue + Dead-Letter + Popover UI Summary

**macOS inbox pipeline: NSMetadataQuery watcher detects iPhone-origin files in _inbox/, processes them FIFO through the full pipeline with IC-04 active download, TRIG-03 move-on-success, and TRIG-04 retry+dead-letter**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-16T03:19:52Z
- **Completed:** 2026-07-16T03:31:52Z
- **Tasks:** 2
- **Files modified:** 13 (8 created, 5 modified)

## Accomplishments

- **InboxError:** structured error enum with `downloadTimedOut`, `pipelineFailed`, `deadLetterExhausted`, `inboxNotReady` cases; `errorType` and `errorMessage` accessors produce T-05-10-safe metadata for sidecar JSON
- **InboxQueue:** serial FIFO actor with de-duplication, `processNext`/`markComplete`/`pendingCount`/`processing`; enforces TRIG-02 one-at-a-time semantics
- **DeadLetterHandler:** retry tracking actor with 3x max retries, [30s, 2min, 10min] backoff schedule; `deadLetter()` moves file to `_failed/` and writes `.error.json` sidecar via `DeadLetterSidecar` Codable struct
- **InboxFileDownloader:** IC-04 `.icloud` placeholder detection via `pathExtension`; `startDownload()` triggers `URL.startDownloadingUbiquitousItem()` + polls `ubiquitousItemDownloadingStatusKey` every 2s up to 120s timeout; `realFilePath(for:)` resolves placeholder to real file path
- **InboxWatcher:** hybrid TRIG-01 watcher wrapping `NSMetadataQuery` with path-based scope (A1), predicate scoped to `_inbox/`, launch scan + live `.NSMetadataQueryDidUpdate` monitoring; filters `.icloud` placeholders and `_failed/` directory
- **PipelineWiring extension:** `processInboxFile` constructs fresh `PipelineInputs`, runs full pipeline, moves audio to course folder on success (TRIG-03); `parseRecordingStart` extracts IC-03 timestamp from filename with file creation date fallback
- **MenuBarViewModel extension:** `inboxPendingCount`, `inboxProcessingState`, `startInboxMonitoring`, `processNextInboxFileIfNeeded` (IC-04 download + pipeline), `handleInboxFailure` (TRIG-04 retry/dead-letter), `retryFailedRecording`, `deleteFailedRecording`; `InboxProcessingState` enum (idle/downloading/transcribing/failed)
- **MenuBarPopover extension:** iCloud Inbox pending count in idle state, `inboxProcessingView` renders downloading/transcribing/failed states with ProgressView + filename + queue count + Retry/Delete buttons, Manage Permissions button (ONBD-05)
- **NoteWriterError extension:** `iCloudDownloadTimedOut` case (IC-04 amends A-03 for iCloud-handoff path; existing `iCloudPlaceholder` remains as hard-error for non-iCloud destinations)

## Task Commits

1. **Task 1 (TDD): InboxQueue + DeadLetterHandler + InboxFileDownloader + InboxError**
   - RED: `71ee5e5` — failing tests for all three components
   - GREEN: `71db49e` — implementation passing all tests
2. **Task 2: InboxWatcher + pipeline wiring + popover UI** — `6d3587a` (feat)

## Files Created/Modified

### Created
- `Sources/UnibrainProviders/Inbox/InboxError.swift` — structured error enum (macOS-only)
- `Sources/UnibrainProviders/Inbox/InboxQueue.swift` — serial FIFO actor (macOS-only)
- `Sources/UnibrainProviders/Inbox/DeadLetterHandler.swift` — retry+dead-letter actor (macOS-only)
- `Sources/UnibrainProviders/Inbox/InboxFileDownloader.swift` — IC-04 download handler (macOS-only)
- `Sources/UnibrainProviders/Inbox/InboxWatcher.swift` — NSMetadataQuery wrapper (macOS-only)
- `Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift` — FIFO ordering, empty queue, sequential, de-dup
- `Tests/UnibrainProvidersTests/Inbox/DeadLetterHandlerTests.swift` — sidecar creation, retry tracking, max enforcement
- `Tests/UnibrainProvidersTests/Inbox/InboxFileDownloaderTests.swift` — .icloud detection, .m4a ready, placeholder path

### Modified
- `Sources/UnibrainCore/Errors/NoteWriterError.swift` — added `iCloudDownloadTimedOut` case
- `Sources/UnibrainProviders/Pipeline/PipelineWiring.swift` — added `processInboxFile`, `parseRecordingStart`, helper methods
- `UnibrainApp/ViewModels/MenuBarViewModel.swift` — inbox state, monitoring lifecycle, failure recovery, `InboxProcessingState` enum
- `UnibrainApp/MenuBarPopover.swift` — iCloud inbox pending count, processing states, Manage Permissions button
- `Tests/UnibrainCoreTests/NormalizationTests/NoteWriterTests.swift` — added new error case to exhaustive switch

## Decisions Made

- **InboxQueue is in-memory actor** — CONTEXT discretion; launch scan (TRIG-01) recovers lost files on restart
- **DeadLetterHandler as actor** — serializes retry tracker access; no concurrent concern since queue is one-at-a-time
- **InboxFileDownloader detects `.icloud` via pathExtension** — simplest reliable detection per Pitfall 5; avoids file-content probing
- **DeadLetterSidecar uses snake_case CodingKeys** — mirrors `CourseMappingDocument` pattern for iCloud cross-device interop
- **InboxProcessingState custom Equatable** — SwiftUI diffing needs value equality despite associated values
- **processInboxFile searches for recently-created note** — derives course folder from the note the pipeline just wrote, then moves audio alongside (P-15)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed NoteWriterError switch exhaustiveness in existing test**
- **Found during:** Task 1 GREEN phase
- **Issue:** Adding `iCloudDownloadTimedOut` to `NoteWriterError` broke an exhaustive switch in `NoteWriterTests.swift` — existing test enumerated all error cases but didn't include the new one
- **Fix:** Added `.iCloudDownloadTimedOut` to both the errors array and the switch statement in the test
- **Files modified:** Tests/UnibrainCoreTests/NormalizationTests/NoteWriterTests.swift
- **Commit:** `71db49e` (Task 1 GREEN)

---

**Total deviations:** 1 auto-fixed (1 bug from own change)
**Impact on plan:** Minimal — test exhaustiveness fix for new enum case. No scope creep.

## Issues Encountered

None — plan executed cleanly. All SPM tests pass (219/219). macOS-only code (`InboxWatcher`, `MenuBarViewModel` inbox extensions, `MenuBarPopover` inbox UI) compiles on macOS CI only — not buildable from WSL2/Linux per established Phase 3/4/5 pattern.

## User Setup Required

- **iCloud Drive** enabled on macOS with the same Apple ID as iPhone
- **Onboarding completed on macOS first** — BookmarkStore resolves the vault URL for inbox monitoring
- **Physical iPhone + iCloud sync** required for end-to-end verification (deferred)

## Next Phase Readiness

- macOS inbox pipeline is code-complete: NSMetadataQuery detects files (TRIG-01), serial FIFO processes one-at-a-time (TRIG-02), audio moves to course folder on success (TRIG-03), failures retry 3x then dead-letter (TRIG-04), `.icloud` placeholders trigger active download (IC-04)
- Popover shows live queue status with Retry/Delete for failures (UI-SPEC Surface 4)
- Device verification deferred — does not block Phase 06 planning

## Known Stubs

None — all data flows are wired. The `processInboxFile` method constructs real `PipelineInputs` and runs the real orchestrator. The popover reads live `inboxPendingCount` and `inboxProcessingState` from the view model.

## Self-Check: PASSED

- FOUND: Sources/UnibrainProviders/Inbox/InboxError.swift
- FOUND: Sources/UnibrainProviders/Inbox/InboxQueue.swift
- FOUND: Sources/UnibrainProviders/Inbox/DeadLetterHandler.swift
- FOUND: Sources/UnibrainProviders/Inbox/InboxFileDownloader.swift
- FOUND: Sources/UnibrainProviders/Inbox/InboxWatcher.swift
- FOUND: Tests/UnibrainProvidersTests/Inbox/InboxQueueTests.swift
- FOUND: Tests/UnibrainProvidersTests/Inbox/DeadLetterHandlerTests.swift
- FOUND: Tests/UnibrainProvidersTests/Inbox/InboxFileDownloaderTests.swift
- FOUND: 71ee5e5 (RED test commit)
- FOUND: 71db49e (GREEN implementation commit)
- FOUND: 6d3587a (Task 2 commit)

---
*Phase: 05-ios-capture-icloud-handoff-onboarding*
*Completed: 2026-07-16 (code); device verification deferred*
