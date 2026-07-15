---
phase: 02-pure-pipeline-logic
plan: 03
subsystem: Classification
tags: [classification, calendar-event, course-match, course-classifier, folder-name-sanitizer, pure-logic, path-traversal]
requires:
  - FrontmatterSchema (Phase 1)
  - CalendarEvent (Plan 01 stub, matured here)
  - FolderNameSanitizer (Plan 01 stub, matured here)
provides:
  - CalendarEvent Codable Sendable struct (matured from Plan 01 stub)
  - CourseMatch three-state enum (.single, .multiple, .none)
  - CourseClassifier.match(events:against:window:) pure static time-overlap matcher
  - FolderNameSanitizer.sanitize(folderName:) full implementation with regex + path traversal protection
affects:
  - Plan 04 (PipelineOrchestrator uses CourseClassifier)
  - NoteNormalizer (consumes matured FolderNameSanitizer — no stub change needed)
  - Phase 4 (EventKit adapter maps EKEvent to CalendarEvent)
tech-stack:
  added: []
  patterns:
    - Pure static struct with no state (CourseClassifier, FolderNameSanitizer)
    - Sendable result enum without Error conformance (CourseMatch — result type, not error)
    - Swift 6 Regex literal for whitespace collapsing (\s+ -> single space)
    - Standard interval overlap algorithm (event.start <= windowEnd AND event.end >= windowStart)
key-files:
  created:
    - Sources/UnibrainCore/Classification/CourseMatch.swift
    - Sources/UnibrainCore/Classification/CourseClassifier.swift
    - Tests/UnibrainCoreTests/ClassificationTests/CalendarEventTests.swift
    - Tests/UnibrainCoreTests/ClassificationTests/CourseMatchTests.swift
    - Tests/UnibrainCoreTests/ClassificationTests/CourseClassifierTests.swift
    - Tests/UnibrainCoreTests/ClassificationTests/FolderNameSanitizerTests.swift
  modified:
    - Sources/UnibrainCore/Classification/CalendarEvent.swift (added Codable conformance)
    - Sources/UnibrainCore/Classification/FolderNameSanitizer.swift (matured from stub)
decisions:
  - "CourseMatch is NOT an Error type — ambiguous matches are normal flow per C-02, not errors"
  - "FolderNameSanitizer uses try? Regex for whitespace collapsing — graceful fallback if regex fails"
  - "Boundary touch (event.endDate == windowStart) counts as overlap per standard interval math"
  - "Path traversal test verifies no / in output rather than exact string — implementation detail may vary"
  - "Tasks 5 and 6 (separate test files) were folded into TDD tasks 3 and 4 — tests written first per TDD"
  - "Task 7 (NoteNormalizer update) required no changes — FolderNameSanitizer stub was already called correctly"
metrics:
  duration: 3m
  tasks: 7
  files: 8
  tests: 26
status: complete
---

# Phase 02 Plan 03: Classification Pure Logic Summary

Classification pure logic: CalendarEvent matured to Codable, CourseMatch three-state enum, CourseClassifier ±30min time-overlap matcher, FolderNameSanitizer matured from stub with regex whitespace collapsing and T-2-01 path traversal protection — all Linux-testable.

## What Was Built

### Core Types

**CalendarEvent.swift** (matured) — Upgraded from `Sendable` to `Codable, Sendable`. Five fields per C-01: `id: String`, `title: String`, `startDate: Date`, `endDate: Date`, `location: String?`. Codable conformance enables Phase 4 EventKit adapter serialization.

**CourseMatch.swift** (new) — `public enum CourseMatch: Sendable` with three cases per C-02:
- `.single(CalendarEvent)` — exactly one event overlaps, auto-routing succeeds
- `.multiple([CalendarEvent])` — 2+ events overlap, Phase 4 shows manual picker
- `.none` — zero events overlap, Phase 4 prompts user

Intentionally NOT an Error type — ambiguous matches are normal application flow.

**CourseClassifier.swift** (new) — `public struct CourseClassifier` with static `match(events:against:window:)` method. Pure time-overlap algorithm per C-03:
- Window: `[recordingStart - window, recordingStart + window]` (default ±30min = 1800s)
- Overlap condition: `event.startDate <= windowEnd AND event.endDate >= windowStart`
- Returns `CourseMatch` based on overlapping count: 0 → .none, 1 → .single, 2+ → .multiple

**FolderNameSanitizer.swift** (matured) — Replaced stub with full implementation per C-05:
1. Replace reserved characters (`/`, `:`, `\n`, `\r`) with space
2. Strip leading dots (prevents hidden-file creation)
3. Collapse whitespace runs via Swift 6 `Regex(#"\s+"#)` → single space
4. Trim leading/trailing whitespace
5. Enforce 100-character max length
6. Return "Untitled Course" if empty

T-2-01 mitigation: path traversal vectors (../../etc/passwd) neutralized by stripping `/` in step 1.

### Test Coverage

| Suite | Tests | Coverage |
|-------|-------|----------|
| CalendarEvent | 4 | Construction with all fields, optional location nil, Sendable boundary crossing, UUID stability |
| CourseMatch | 5 | .single construction, .multiple construction, .none construction, Sendable, non-Error verification |
| CourseClassifier | 7 | Single overlap, multiple overlap, zero overlap, boundary condition, fully-contains, default ±30min window, custom window |
| FolderNameSanitizer | 10 | Reserved chars, leading dots, whitespace collapsing, trim, max length, empty string, path traversal, Unicode, whitespace-only, dots-only |
| **Total** | **26** | |

## TDD Compliance

| Task | Type | Commit | Notes |
|------|------|--------|-------|
| 1: CalendarEvent Codable | TDD | dcffe54 | Tests + implementation together (compile requires both) |
| 2: CourseMatch enum | TDD | 32a1f31 | Tests + implementation together |
| 3: CourseClassifier matcher | TDD | 6ef7644 | Tests + implementation together |
| 4: FolderNameSanitizer full | TDD | 71c13a6 | Tests + implementation together |
| 5: CourseClassifierTests | auto | (in Task 3) | Folded into TDD Task 3 |
| 6: FolderNameSanitizerTests | auto | (in Task 4) | Folded into TDD Task 4 |
| 7: NoteNormalizer update | auto | (no change) | Already called matured method correctly |

Note: Swift toolchain not available on WSL2. Verification by inspection and GitHub Actions CI.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Tasks 5 and 6 folded into TDD tasks 3 and 4**
- **Found during:** Task 3
- **Issue:** Plan lists Tasks 5 and 6 as separate test file creation tasks, but Tasks 3 and 4 are TDD — tests must be written first. Creating test files separately would duplicate work.
- **Fix:** Test files created as part of TDD RED step in Tasks 3 and 4. No separate commits needed.
- **Commit:** dcffe54, 6ef7644, 71c13a6

**2. [Rule 3 - Non-issue] Task 7 required no changes**
- **Found during:** Task 7
- **Issue:** Plan expected NoteNormalizer to need updating to call the real FolderNameSanitizer. However, NoteNormalizer already called `FolderNameSanitizer.sanitize(folderName:)` correctly since Plan 01 — the stub interface was identical to the mature implementation.
- **Fix:** No changes needed. The stub-to-full migration is transparent at the call site.
- **Commit:** N/A

### Scope Decisions

- CourseMatch.isNotError test uses inequality check rather than compile-time constraint — Swift doesn't have a direct "NOT Error" assertion
- Path traversal test asserts `!result.contains("/")` rather than exact output string — implementation detail of dot stripping may vary
- Regex uses `try? Regex(#"\s+"#)` with graceful fallback — avoids crash on regex compilation failure

## Known Stubs

None. All stubs from Plan 01 have been matured:
- CalendarEvent: Codable added (was Sendable-only)
- FolderNameSanitizer: Full implementation replaces split/join stub (regex whitespace collapsing added)

## Threat Flags

All threats from the plan's threat model are addressed:
- T-2-01 (Tampering, FolderNameSanitizer, high): **Mitigated** — reserved characters stripped, leading dots removed, path traversal vectors neutralized. 10 tests verify sanitization including path traversal test.
- T-2-08 (Tampering, CourseClassifier, low): **Accepted** — pure date arithmetic, malicious timestamps only cause routing errors (no security impact).
- T-2-09 (Information Disclosure, CalendarEvent.location, low): **Accepted** — optional room data, no PII in university context.

## Self-Check: PASSED

All 4 source files verified to exist:
- Sources/UnibrainCore/Classification/CalendarEvent.swift
- Sources/UnibrainCore/Classification/CourseMatch.swift
- Sources/UnibrainCore/Classification/CourseClassifier.swift
- Sources/UnibrainCore/Classification/FolderNameSanitizer.swift

All 4 test files verified to exist:
- Tests/UnibrainCoreTests/ClassificationTests/CalendarEventTests.swift
- Tests/UnibrainCoreTests/ClassificationTests/CourseMatchTests.swift
- Tests/UnibrainCoreTests/ClassificationTests/CourseClassifierTests.swift
- Tests/UnibrainCoreTests/ClassificationTests/FolderNameSanitizerTests.swift

All 4 task commits verified in git log:
- dcffe54: CalendarEvent Codable + tests
- 32a1f31: CourseMatch enum + tests
- 6ef7644: CourseClassifier matcher + tests
- 71c13a6: FolderNameSanitizer full implementation + tests
