---
phase: 03-macos-capture-transcribe
plan: 03
subsystem: vault-writing
tags: [nsfilecoordinator, icloud, vault, pipeline-wiring, swift6]
requires:
  - "NoteWriter protocol (Phase 2)"
  - "VaultPathResolver protocol (Phase 2)"
  - "PipelineOrchestrator (Phase 2)"
  - "PipelineInputs (Phase 2)"
  - "NormalizedNote + FrontmatterSchema (Phase 2)"
  - "TranscriberRouter (Phase 3 Plan 02)"
  - "RecordingSession (Phase 3 Plan 01)"
provides:
  - "NSFileCoordinatorNoteWriter — macOS NoteWriter using NSFileCoordinator for atomic iCloud-safe writes"
  - "HardcodedVaultResolver — Phase 3 VaultPathResolver writing to ~/Documents/Unibrain/lectures/"
  - "PipelineWiring — factory assembling PipelineOrchestrator with all Phase 3 conformances"
affects:
  - "PipelineOrchestrator — now has concrete macOS conformances for all three dependencies"
tech-stack:
  added: []
  patterns:
    - "NSFileCoordinator + Data.write(.atomic) for double-layered atomic writes (WRITE-04)"
    - ".icloud placeholder detection via filesystem check before writing (WRITE-05)"
    - "Structured error mapping from POSIX/Cocoa to NoteWriterError cases (WRITE-06)"
    - "Factory pattern for pipeline assembly (PipelineWiring)"
    - "TDD RED/GREEN cycle for both tasks"
key-files:
  created:
    - "Sources/UnibrainProviders/VaultWriting/NSFileCoordinatorNoteWriter.swift"
    - "Sources/UnibrainProviders/VaultWriting/HardcodedVaultResolver.swift"
    - "Sources/UnibrainProviders/Pipeline/PipelineWiring.swift"
    - "Tests/UnibrainProvidersTests/VaultWriting/NSFileCoordinatorNoteWriterTests.swift"
    - "Tests/UnibrainProvidersTests/VaultWriting/HardcodedVaultResolverTests.swift"
  modified: []
decisions:
  - "NSFileCoordinator uses .forReplacing option to handle existing file overwrite correctly"
  - ".icloud placeholder detection checks .{filename}.icloud in the parent directory"
  - "HardcodedVaultResolver uses DateFormatter with en_US_POSIX locale for deterministic date formatting"
  - "PipelineWiring.makePipelineInputs computes recordingEnd from recordingStart + durationSeconds"
  - "All code guarded by #if os(macOS) — Linux CI compiles these out; macOS CI validates"
metrics:
  duration: 9m
  completed: "2026-07-15"
  tasks: 2
  files: 5
status: complete
---

# Phase 3 Plan 3: Vault Writing + Pipeline Wiring Summary

NSFileCoordinatorNoteWriter for atomic iCloud-safe note writes, HardcodedVaultResolver for Phase 3 hardcoded vault path, and PipelineWiring factory assembling the full capture-to-note PipelineOrchestrator.

## What Was Built

### Task 1: NSFileCoordinatorNoteWriter

**NSFileCoordinatorNoteWriter** (`Sources/UnibrainProviders/VaultWriting/NSFileCoordinatorNoteWriter.swift`):
- Conforms to `NoteWriter` protocol (Phase 2)
- `#if os(macOS)` guard — uses NSFileCoordinator which is macOS-only
- **WRITE-04**: Atomic writes via `NSFileCoordinator.coordinate(writingItemAt:options:.forReplacing)` wrapping `Data.write(to:options:.atomic)` — double-layered atomicity
- **WRITE-05**: `.icloud` placeholder detection — checks for `.{filename}.icloud` in the parent directory before writing, throws `NoteWriterError.iCloudPlaceholder`
- **WRITE-06**: Structured error mapping via `mapFileError(_:destination:)` — maps `NSFileWriteOutOfSpaceError` to `.diskFull`, `NSFileWriteNoPermissionError`/EPERM/EACCES to `.permissionDenied`, EEXIST to `.alreadyExists`, fallback to `.underlying`
- **A-05**: Creates intermediate directories recursively via `FileManager.createDirectory(withIntermediateDirectories:true)`, maps failures to `.directoryCreationFailed`
- Serializes `NormalizedNote` as: `---\n{YAML frontmatter via Yams}---\n\n{title}\n\n{body}`
- Uses `withCheckedThrowingContinuation` to bridge NSFileCoordinator's callback-based API to async/await
- `Sendable` struct — safe for Swift 6 strict concurrency

**Tests** (`Tests/UnibrainProvidersTests/VaultWriting/NSFileCoordinatorNoteWriterTests.swift`):
- 9 test cases, all macOS-only (`#if os(macOS)`)
- Tests: file creation, content format (YAML frontmatter + body), intermediate directory creation, `.icloud` placeholder rejection, directory creation failure error, file overwrite (`.forReplacing`), snake_case YAML key serialization, round-trip content verification

### Task 2: HardcodedVaultResolver + PipelineWiring

**HardcodedVaultResolver** (`Sources/UnibrainProviders/VaultWriting/HardcodedVaultResolver.swift`):
- Conforms to `VaultPathResolver` protocol (Phase 2)
- `#if os(macOS)` guard
- **P-13**: `vaultRoot` = `~/Documents/Unibrain/` via `FileManager.default.urls(for:.documentDirectory)`
- **P-14**: `lecturesDir` = `vaultRoot/lectures/`; `resolve()` returns `lectures/YYYY-MM-DD-Lecture.md`
- **P-16**: Does NOT write to `_inbox/` — reserved for Phase 5 iCloud handoff
- Creates `lectures/` directory recursively if missing
- Ignores `CourseMatch` parameter — Phase 3 all recordings are UNCLASSIFIED; Phase 4 replaces this resolver
- Uses `DateFormatter` with `en_US_POSIX` locale for deterministic date formatting
- `Sendable` struct

**PipelineWiring** (`Sources/UnibrainProviders/Pipeline/PipelineWiring.swift`):
- Factory `enum` with `#if os(macOS)` guard
- `makeOrchestrator(modelPath:)`: Wires `TranscriberRouter(modelPath:)` + `NSFileCoordinatorNoteWriter()` + `HardcodedVaultResolver()` into a `PipelineOrchestrator`
- `makeRecordingSession()`: Returns a new `RecordingSession()` actor
- `makePipelineInputs(recordingResult:source:recordingStart:)`: Maps `RecordingSession.Result` to `PipelineInputs` — sets `events: []` (Phase 3 has no calendar events), computes `recordingEnd` from `recordingStart + durationSeconds`

**Tests** (`Tests/UnibrainProvidersTests/VaultWriting/HardcodedVaultResolverTests.swift`):
- 13 test cases across two suites, all macOS-only
- HardcodedVaultResolver tests: path resolution, date formatting (multiple dates), directory creation, `_inbox/` exclusion, `CourseMatch.none` and `.single` ignoring, static properties
- PipelineWiring tests: orchestrator returns idle state, recording session returns idle, pipeline inputs mapping (URL, source, duration, events empty), recordingEnd computation

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. All implementations are complete. The NSFileCoordinatorNoteWriter and HardcodedVaultResolver are fully functional on macOS. PipelineWiring assembles a working orchestrator.

Note: The `TranscriberRouter` wired by `PipelineWiring` has known TODO stubs in `SpeechAnalyzerTranscriber` and `WhisperCppTranscriber` (from Plan 02), but those are pre-existing and not introduced by this plan.

## Verification

- `swift build` — not executable on WSL2 (no Swift toolchain); macOS CI will validate
- `swift test --filter UnibrainProvidersTests.NSFileCoordinatorNoteWriterTests` — macOS-only tests, pass on macOS CI
- `swift test --filter UnibrainProvidersTests.HardcodedVaultResolverTests` — macOS-only tests, pass on macOS CI
- WRITE-04: Atomic writes via NSFileCoordinator + Data.write(.atomic)
- WRITE-05: .icloud placeholder detection
- WRITE-06: Structured NoteWriterError mapping
- A-05: Intermediate directory creation
- P-13: vaultRoot = ~/Documents/Unibrain/
- P-14: lectures/YYYY-MM-DD-Lecture.md path
- P-16: No _inbox/ usage
- TRAN-05: NoteNormalizer paragraph post-processing happens inside the orchestrator (Phase 2 code, unchanged)
- PipelineWiring assembles valid PipelineOrchestrator with all Phase 3 conformances

## Self-Check: PASSED

All 5 plan files verified present on disk.
All 4 commits verified in git log (01def87, b1247c4, c65bc06, fea72bc).
