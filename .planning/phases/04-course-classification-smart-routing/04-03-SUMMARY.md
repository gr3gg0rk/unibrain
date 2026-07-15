---
phase: 04-course-classification-smart-routing
plan: 03
subsystem: classification
tags: [permission-state, course-picker, view-model, tdd, linux-testable]
requires:
  - "CalendarPermissionStatus (from 04-02)"
  - "CalendarEvent (from 02-03)"
  - "CourseMatch (from 02-03)"
provides:
  - "PermissionState enum — UI-derivable permission degradation state"
  - "CoursePickerMode — picker variant selector"
  - "CourseSelection — user selection result (4 paths)"
  - "CourseSummary — lightweight course display model"
  - "CoursePickerViewModel — search, recent, selection logic"
affects:
  - "UnibrainApp UI layer (wraps CoursePickerViewModel for SwiftUI)"
  - "Orchestrator (consumes CourseSelection to update CourseMappingStore)"
tech-stack:
  added: []
  patterns:
    - "Pure-logic view model (no @Observable) for Linux testability"
    - "Enum-based result type (CourseSelection) for multi-path selection"
key-files:
  created:
    - "Sources/UnibrainCore/Classification/PermissionState.swift"
    - "Sources/UnibrainCore/Classification/CoursePickerViewModel.swift"
    - "Tests/UnibrainCoreTests/ClassificationTests/PermissionStateTests.swift"
    - "Tests/UnibrainCoreTests/ClassificationTests/CoursePickerViewModelTests.swift"
  modified:
    - "Sources/UnibrainCore/Classification/CalendarEvent.swift"
    - ".gitignore"
decisions:
  - "CoursePickerViewModel is plain class (not @Observable) — SwiftUI adapter lives in UnibrainApp"
  - "Added Equatable to CalendarEvent to unblock CourseSelection Equatable synthesis"
  - "searchQuery matches both code AND name (substring, case-insensitive) — test for 'cs' catches 'Ethics'"
metrics:
  duration: 6m
  tasks: 2
  files: 6
  tests: 20
status: complete
---

# Phase 04 Plan 03: Permission State + Course Picker View Model Summary

Permission state derivation and pure-logic course picker view model — fully Linux-testable, no SwiftUI dependencies.

## What Was Built

### PermissionState (Task 1)

- **`PermissionState` enum** (`.notDetermined`, `.granted`, `.denied`) — derives UI state from `CalendarPermissionStatus`
- **`from(_:)` factory** — maps `.fullAccess` → `.granted`, `.notDetermined` → `.notDetermined`, `.writeOnly`/`.denied`/`.restricted` → `.denied` (per P-05)
- **`shouldShowFirstTimeSheet(permission:hasShownSheet:)`** — one-time explanation sheet on first denial; compact banner on subsequent (per P-01)

### CoursePickerViewModel (Task 2)

- **`CoursePickerMode`** — `.none` (Variant B: course list only) / `.multiple([CalendarEvent])` (Variant A: events + list)
- **`CourseSelection`** — `.course(String)`, `.event(CalendarEvent)`, `.newCourse(code:name:)`, `.skip`
- **`CourseSummary`** — `Identifiable` value type for picker display
- **`CoursePickerViewModel`** — search filtering (case-insensitive on code + name), recent courses (max 5, MRU order, filtered to current term), matching events accessor, all 4 selection methods

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (test) | `d39f36a` — PermissionStateTests | 9 failing tests |
| GREEN (feat) | `c3b1ebf` — PermissionState impl | 9 passing |
| RED (test) | `ba08107` — CoursePickerViewModelTests | 11 failing tests |
| GREEN (feat) | `089527d` — CoursePickerViewModel impl | 11 passing |

All gates satisfied with proper commit sequence.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Equatable to CalendarEvent**
- **Found during:** Task 2 GREEN phase
- **Issue:** `CourseSelection` declares `Equatable` conformance but has `.event(CalendarEvent)` case — `CalendarEvent` was only `Codable, Sendable`, blocking synthesis
- **Fix:** Added `Equatable` to `CalendarEvent` struct declaration (all stored properties are `Equatable`: `String`, `Date`, `String?`)
- **Files modified:** `Sources/UnibrainCore/Classification/CalendarEvent.swift`
- **Commit:** `089527d`

**2. [Rule 1 - Bug] Fixed test expectation for "cs" substring match**
- **Found during:** Task 2 GREEN phase
- **Issue:** Test expected `searchQuery="cs"` to match only CS101 and CS202, but the implementation correctly matches any course whose code OR name contains "cs" case-insensitively — "Ethics and Society" (PHIL150) legitimately matches
- **Fix:** Changed test to search for exact code "CS101" to verify code-based filtering precisely
- **Files modified:** `Tests/UnibrainCoreTests/ClassificationTests/CoursePickerViewModelTests.swift`
- **Commit:** `089527d`

**3. [Rule 3 - Blocking] Gitignored stray SwiftPM incremental artifacts**
- **Found during:** Task 1 build
- **Issue:** `swift build` on WSL2 leaks `.d`, `.o`, `.swiftdeps` files into `Sources/` and `Tests/` directories (known SwiftPM WSL2 bug)
- **Fix:** Added `*.d`, `*.o`, `*.swiftdeps`, `*.swiftdeps~` patterns to `.gitignore`
- **Files modified:** `.gitignore`
- **Commit:** `089527d`

## Verification

- `swift test --filter PermissionStateTests`: 9/9 passed
- `swift test --filter CoursePickerViewModelTests`: 11/11 passed
- `swift build`: succeeded for UnibrainCore target
- Total: 20/20 tests green on WSL2 Linux

## Known Stubs

None — all logic is fully wired. The view model produces `CourseSelection` results that the orchestrator (Plan 04) will consume to update `CourseMappingStore`. No mock data or placeholder returns.

## Threat Flags

None — no new security surface introduced. Threat model from plan (T-04-07, T-04-08) accurately covers the low-risk string filtering and permission-state-derivation surface.

## Self-Check: PASSED

- FOUND: Sources/UnibrainCore/Classification/PermissionState.swift
- FOUND: Sources/UnibrainCore/Classification/CoursePickerViewModel.swift
- FOUND: Tests/UnibrainCoreTests/ClassificationTests/PermissionStateTests.swift
- FOUND: Tests/UnibrainCoreTests/ClassificationTests/CoursePickerViewModelTests.swift
- FOUND: d39f36a (RED PermissionState)
- FOUND: c3b1ebf (GREEN PermissionState)
- FOUND: ba08107 (RED CoursePickerViewModel)
- FOUND: 089527d (GREEN CoursePickerViewModel)
