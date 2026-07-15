---
phase: 04-course-classification-smart-routing
plan: 02
subsystem: classification
tags: [eventkit, calendar, protocol-abstraction, term-filter]
requires:
  - "04-01: CourseMapping + CourseMappingStore (TermDefinition exists)"
  - "02-01: CalendarEvent struct"
  - "02-03: CourseClassifier (±30min window overlap logic)"
  - "01-03: ProviderError enum"
provides:
  - "CalendarEventProvider protocol (Sendable, UnibrainCore)"
  - "CalendarPermissionStatus enum (5 cases, Sendable)"
  - "TermRangeFilter struct (±30min Swift-side filter)"
  - "EventKitCalendarAdapter actor (macOS + iOS, UnibrainProviders)"
affects:
  - "04-03: ScheduleAwareVaultResolver will use events from this adapter"
  - "04-04: PipelineOrchestrator pause/resume will fetch events via this provider"
  - "04-05: UI permission flow will use checkAuthorization + requestFullAccess"
tech-stack:
  added: []
  patterns:
    - "Protocol abstraction (UnibrainCore) + platform-guarded actor conformance (UnibrainProviders)"
    - "Two-stage filter: EventKit term-range predicate + Swift-side ±30min narrowing"
    - "Explicit .fullAccess verification after requestFullAccessToEvents (P-05)"
key-files:
  created:
    - "Sources/UnibrainCore/Protocols/CalendarEventProvider.swift"
    - "Sources/UnibrainCore/Classification/TermRangeFilter.swift"
    - "Sources/UnibrainProviders/Calendar/EventKitCalendarAdapter.swift"
    - "Tests/UnibrainCoreTests/ClassificationTests/TermRangeFilterTests.swift"
    - "Tests/UnibrainProvidersTests/Calendar/EventKitCalendarAdapterTests.swift"
  modified: []
decisions:
  - "CalendarPermissionStatus.canReadEvents helper added — only .fullAccess returns true (P-05)"
  - "Sendable proof test uses async Task instead of any Sendable existential (avoids Swift 6.0.3 compiler crash)"
  - "fetchEvents throws ProviderError.underlying(NSError) on permission denial — ProviderError is non-Sendable, caught at call site"
metrics:
  duration: "5m"
  completed: "2026-07-15"
  tasks: 2
  files: 5
status: complete
---

# Phase 04 Plan 02: Calendar Event Provider + TermRangeFilter Summary

Created the EventKit integration layer: a protocol abstraction in UnibrainCore (Linux-testable), a macOS+iOS adapter in UnibrainProviders, and the ±30min recording-window filter that narrows calendar events before classification.

## What Was Built

### CalendarEventProvider Protocol (UnibrainCore)

`Sources/UnibrainCore/Protocols/CalendarEventProvider.swift` defines:
- `CalendarPermissionStatus` enum with 5 cases: `.notDetermined`, `.fullAccess`, `.writeOnly`, `.denied`, `.restricted`. Sendable.
- `canReadEvents` computed property: returns `true` only for `.fullAccess` (P-05 — `.writeOnly` treated as denied).
- `CalendarEventProvider` protocol with 3 async methods: `checkAuthorization()`, `requestFullAccess()`, `fetchEvents(in:)`.

### TermRangeFilter (UnibrainCore)

`Sources/UnibrainCore/Classification/TermRangeFilter.swift` defines:
- `filterEvents(allEvents:recordingStart:window:)` — pure static function that narrows events to those overlapping `[recordingStart - window, recordingStart + window]`. Default window is 1800s (±30min per C-03).
- This is the CT-02 stage 2 Swift-side filter. The term-range predicate is applied separately in the EventKit adapter query.

### EventKitCalendarAdapter (UnibrainProviders)

`Sources/UnibrainProviders/Calendar/EventKitCalendarAdapter.swift` defines:
- `actor EventKitCalendarAdapter` conforming to `CalendarEventProvider`, behind `#if os(macOS) || os(iOS)`.
- `checkAuthorization()` maps all 5 `EKAuthorizationStatus` cases + `@unknown default` → `.denied`.
- `requestFullAccess()` calls `requestFullAccessToEvents()`, then verifies `authorizationStatus == .fullAccess` explicitly (P-05). Returns `false` on throw or non-full grant.
- `fetchEvents(in:)` checks permission before every query (T-04-04), queries all calendars inclusively with `calendars: nil` (P-04), maps `EKEvent` → `CalendarEvent` at the boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Swift 6.0.3 compiler crash in Sendable test**
- **Found during:** Task 1 GREEN phase
- **Issue:** Assigning `CalendarPermissionStatus` to `any Sendable` and comparing with `!= nil` triggered a Swift 6.0.3 compiler crash (`Invalid conformance in type-checked AST`, signal 6).
- **Fix:** Rewrote the Sendable test to use an async `Task { @Sendable }` closure that captures the value across an isolation boundary — a more idiomatic Sendable proof.
- **Files modified:** `Tests/UnibrainCoreTests/ClassificationTests/TermRangeFilterTests.swift`
- **Commit:** 74ce826

## TDD Gate Compliance

- RED commit: `40cb27c` — `test(04-02): add failing tests for TermRangeFilter + CalendarPermissionStatus` (7 tests failing)
- GREEN commit: `74ce826` — `feat(04-02): implement CalendarEventProvider protocol, CalendarPermissionStatus, TermRangeFilter` (7 tests passing)
- RED commit: `ad949cf` — `test(04-02): add macOS-only EventKitCalendarAdapter tests` (4 tests, macOS-only)
- GREEN commit: `0df6882` — `feat(04-02): implement EventKitCalendarAdapter actor (macOS + iOS)` (macOS CI)

All gates satisfied. No RED or GREEN gate commits missing.

## Verification Results

- `swift test --filter TermRangeFilter`: 7/7 tests pass on WSL2 Linux
- `swift test` (full suite): 169/169 tests pass — zero regressions
- `swift build`: both UnibrainCore and UnibrainProviders targets compile cleanly
- macOS-only tests (`EventKitCalendarAdapterTests`) compile as no-op on Linux, will run on macOS CI
- No new SPM dependencies (EventKit is a system framework)

## Threat Mitigation Status

| Threat ID | Mitigation | Status |
|-----------|-----------|--------|
| T-04-04 (Info Disclosure) | `fetchEvents` checks `authorizationStatus == .fullAccess` before every query | Implemented |
| T-04-05 (Tampering) | Event titles passed as raw `CalendarEvent.title`; `FolderNameSanitizer` (Phase 2) strips unsafe chars before filesystem use | Not in scope (adapter doesn't use titles as paths) |
| T-04-06 (DoS) | `EventKitCalendarAdapter` is an actor — `fetchEvents` runs in actor isolation, never on MainActor | Implemented |

## Known Stubs

None — all code is functional, not placeholder.

## Self-Check: PASSED

Files verified:
- FOUND: Sources/UnibrainCore/Protocols/CalendarEventProvider.swift
- FOUND: Sources/UnibrainCore/Classification/TermRangeFilter.swift
- FOUND: Sources/UnibrainProviders/Calendar/EventKitCalendarAdapter.swift
- FOUND: Tests/UnibrainCoreTests/ClassificationTests/TermRangeFilterTests.swift
- FOUND: Tests/UnibrainProvidersTests/Calendar/EventKitCalendarAdapterTests.swift

Commits verified:
- FOUND: 40cb27c (test RED Task 1)
- FOUND: 74ce826 (feat GREEN Task 1)
- FOUND: ad949cf (test RED Task 2)
- FOUND: 0df6882 (feat GREEN Task 2)
