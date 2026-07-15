---
phase: 04
plan: 04
subsystem: pipeline-core
tags: [orchestrator, pause-resume, checked-continuation, vault-resolver, routing]
requires:
  - 04-01-CourseMappingStore
  - 04-02-EventKitAdapter
  - 04-03-CoursePickerViewModel
provides:
  - PipelineState.awaitingUserChoice
  - PipelineOrchestrator.pause-resume
  - ScheduleAwareVaultResolver
  - NoteNormalizer.parameterized
affects:
  - PipelineOrchestratorTests
  - NoteNormalizerTests
tech-stack:
  added: []
  patterns:
    - CheckedContinuation pause/resume (SR-14875 safe — resume from outside actor)
    - Parameter injection replacing hardcoded values
    - Mapping snapshot injection (read-only dict in resolver, actor-managed writes elsewhere)
key-files:
  created:
    - Sources/UnibrainProviders/VaultWriting/ScheduleAwareVaultResolver.swift
    - Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorPauseTests.swift
    - Tests/UnibrainProvidersTests/VaultWriting/ScheduleAwareVaultResolverTests.swift
  modified:
    - Sources/UnibrainCore/Pipeline/PipelineState.swift
    - Sources/UnibrainCore/Pipeline/PipelineOrchestrator.swift
    - Sources/UnibrainCore/Pipeline/PipelineInputs.swift
    - Sources/UnibrainCore/Normalization/NoteNormalizer.swift
    - Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorTests.swift
    - Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift
decisions:
  - Orchestrator stores CheckedContinuation as actor state; UI resumes from outside (SR-14875 safe pattern)
  - Resolver receives mapping snapshot as plain dict at init — no actor dependency, fully testable
  - Empty term label falls back to "default-term" folder to always produce a named directory
  - callsCourseClassifier test updated from .failed expectation to .awaitingUserChoice pause+resume
metrics:
  duration: 6m
  completed: 2026-07-15
  tasks: 2
  files: 9
status: complete
---

# Phase 04 Plan 04: Pipeline Integration + ScheduleAwareVaultResolver Summary

Parameterized the NoteNormalizer (replacing hardcoded term/source values), extended the PipelineOrchestrator with pause/resume via CheckedContinuation for manual course selection, and created ScheduleAwareVaultResolver for multi-term, course-aware vault routing.

## What Was Built

### Task 1: PipelineState + Orchestrator pause/resume + NoteNormalizer parameterization

**PipelineState.swift** — Added `.awaitingUserChoice` as the 9th state between `.classifying` and `.normalizing`. This state represents the pipeline parked, waiting for the user to manually select a course from the picker UI.

**PipelineOrchestrator.swift** — Core architectural change:
- Added `selectionContinuation: CheckedContinuation<CalendarEvent, any Error>?` as stored actor state
- When `CourseClassifier.match()` returns `.multiple` or `.none`, the orchestrator transitions to `.awaitingUserChoice` and calls `resolveViaUserChoice()` which parks via `withCheckedThrowingContinuation`
- `resume(with:)` — Called from the UI layer (@MainActor), crosses actor boundary to resume the continuation with the user-selected event (SR-14875 safe pattern)
- `skipClassification()` — Creates a synthetic `_unsorted` CalendarEvent and resumes the continuation (MP-03 Skip path)
- `cancel()` — Now resumes any parked continuation with `CancellationError` before cancelling the active task (T-04-10 mitigation against orphaned pipelines)
- The resolver always receives a `.single(resolvedEvent)` match — the orchestrator resolves ambiguity before calling resolve()

**PipelineInputs.swift** — Added `termLabel: String` field with default `""` for backward compatibility. Existing Phase 2/3 call sites that don't pass it still compile.

**NoteNormalizer.swift** — Changed `normalize()` signature to accept `term:` and `source:` as parameters instead of hardcoding `"Fall 2026"` and `"MacBook Air"`. The orchestrator passes `inputs.termLabel` and `inputs.source` through.

### Task 2: ScheduleAwareVaultResolver

**ScheduleAwareVaultResolver.swift** — New resolver replacing HardcodedVaultResolver for Phase 4+ recordings:
- Builds `{vault}/{sanitizedTerm}/{courseComponent}/YYYY-MM-DD-{courseComponent}-Lecture.md` paths (CLAS-05)
- CLAS-02 mapping lookup: checks the injected mapping dict for the event title; if mapped, uses the `courseCode` as the path component
- CLAS-03 auto-create: unmapped event titles are sanitized via FolderNameSanitizer and the folder is auto-created
- MP-03 skip: the `_unsorted` title naturally routes to the `_unsorted/` folder — no special-casing
- A-05: recursive directory creation via `FileManager.createDirectory(withIntermediateDirectories: true)`
- T-04-11 path traversal mitigation: FolderNameSanitizer strips `/`, `:`, leading dots on both term label and event title
- Empty term label falls back to `"default-term"` folder
- Sendable struct with no actor dependency — reads from a plain dict snapshot injected at init time

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated callsCourseClassifier test for new pause behavior**
- **Found during:** Task 1 GREEN phase
- **Issue:** The existing `callsCourseClassifier` test expected `.failed` state when CourseClassifier returns `.none`. With Phase 4's pause/resume change, `.none` now transitions to `.awaitingUserChoice` instead of failing immediately.
- **Fix:** Updated the test to verify the pipeline pauses at `.awaitingUserChoice`, then resumes with the event to complete. The test now reflects the Phase 4 contract (pause + resume replaces immediate failure).
- **Files modified:** `Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorTests.swift`
- **Commit:** d7bdc59

## Verification Results

- `swift test` (200 tests) passes on WSL2 Linux — all existing Phase 2/3 tests green
- PipelineOrchestratorPauseTests: 11 tests pass (pause/resume, skip, cancel, termLabel, parameterized normalizer)
- PipelineOrchestratorTests: 28 tests pass (backward compat with updated callsCourseClassifier)
- NoteNormalizerTests: 18 tests pass (all existing tests updated with term/source params)
- ScheduleAwareVaultResolverTests: 9 tests (macOS-only, will run on CI)
- `swift build` succeeds for UnibrainCore and UnibrainProviders

## TDD Gate Compliance

- RED commit: `7aef9da` (test: failing tests for pause/resume + parameterized normalizer)
- GREEN commit: `d7bdc59` (feat: implementation passing all tests)
- RED commit: `7e1e373` (test: failing tests for ScheduleAwareVaultResolver)
- GREEN commit: `0f3eb08` (feat: ScheduleAwareVaultResolver implementation)

All four gate commits present and in correct order.

## Known Stubs

None — all implementations are complete with real behavior.

## Threat Flags

None — no security-relevant surface beyond what the plan's threat model already covers (T-04-09, T-04-10, T-04-11 all mitigated as specified).

## Self-Check: PASSED

### Files Verified

- FOUND: Sources/UnibrainCore/Pipeline/PipelineState.swift
- FOUND: Sources/UnibrainCore/Pipeline/PipelineOrchestrator.swift
- FOUND: Sources/UnibrainCore/Pipeline/PipelineInputs.swift
- FOUND: Sources/UnibrainCore/Normalization/NoteNormalizer.swift
- FOUND: Sources/UnibrainProviders/VaultWriting/ScheduleAwareVaultResolver.swift
- FOUND: Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorPauseTests.swift
- FOUND: Tests/UnibrainProvidersTests/VaultWriting/ScheduleAwareVaultResolverTests.swift

### Commits Verified

- FOUND: 7aef9da (test: failing tests for pause/resume)
- FOUND: d7bdc59 (feat: pause/resume implementation)
- FOUND: 7e1e373 (test: failing tests for resolver)
- FOUND: 0f3eb08 (feat: resolver implementation)
