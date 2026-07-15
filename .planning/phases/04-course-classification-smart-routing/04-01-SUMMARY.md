---
phase: 04-course-classification-smart-routing
plan: 01
subsystem: classification
tags: [persistence, codable, actor, swift6, courses-json]
requires: []
provides:
  - CourseMappingStore actor (async CRUD on .unibrain/courses.json)
  - CourseMappingDocument Codable schema (schema_version 1)
  - TermDefinition + CourseMapping Sendable structs
affects:
  - 04-02 (ScheduleAwareVaultResolver reads mappings)
  - 04-03 (orchestrator calls upsert on auto-learn)
  - 04-04 (picker reads allRecentCourses + allMappings)
  - 04-05 (Manage Courses sheet reads/deletes mappings)
tech-stack:
  added: []
  patterns:
    - actor-isolated file persistence (matches PipelineOrchestrator)
    - Codable snake_case CodingKeys for iCloud JSON interop
    - Data.write(.atomic) for crash-safe persistence
key-files:
  created:
    - Sources/UnibrainCore/Classification/CourseMapping.swift
    - Sources/UnibrainCore/Classification/CourseMappingStore.swift
    - Tests/UnibrainCoreTests/ClassificationTests/CourseMappingStoreTests.swift
  modified: []
decisions:
  - "Actor methods are async throws (not just throws) per Swift 6 actor isolation — matches PipelineOrchestrator.run() pattern"
  - "load() returns .empty on malformed JSON (T-04-02), never throws on corrupted data"
  - "Pretty-printed + sorted JSON output for clean iCloud diffs and human editability"
  - "Default term uses distantPast/distantFuture so recordings are never filtered before user configures a real term"
metrics:
  duration: 5m
  completed: "2026-07-15"
  tasks: 1
  files: 3
status: complete
---

# Phase 4 Plan 1: Course Mapping Store Summary

Codable schema (`TermDefinition`, `CourseMapping`, `CourseMappingDocument`) and `CourseMappingStore` actor providing atomic async CRUD on vault-side `.unibrain/courses.json` — the persistence backbone for schedule-aware routing (CLAS-02).

## What Was Built

### CourseMapping.swift (Codable Schema)

Three `Codable & Sendable` structs for the versioned JSON document:

- **`TermDefinition`**: `{ label, startDate, endDate }` — the current academic term for date-range filtering (CT-01)
- **`CourseMapping`**: `{ courseCode, courseName }` — maps a calendar event title to a course
- **`CourseMappingDocument`**: `{ schemaVersion, currentTerm, mappings, recentCourseCodes }` — the top-level document with snake_case CodingKeys (`schema_version`, `current_term`, `recent_course_codes`). Includes `static let empty` factory with wide default term (distantPast/distantFuture).

### CourseMappingStore.swift (Actor)

`public actor CourseMappingStore` with these `async throws` methods:

| Method | Purpose |
|--------|---------|
| `load()` | Reads JSON from `{vault}/.unibrain/courses.json`; returns `.empty` on missing/malformed (T-04-02) |
| `lookup(eventTitle:)` | Returns mapped `CourseMapping?` for an event title (M-01) |
| `upsert(eventTitle:mapping:)` | Inserts/updates a mapping — M-02 auto-learn + M-03 manual pick path |
| `addRecent(courseCode:)` | MRU list management — deduplicates, inserts at 0, trims to 5 (M-03) |
| `setCurrentTerm(label:startDate:endDate:)` | Updates current term + persists (CT-01) |
| `deleteMapping(eventTitle:)` | Removes mapping — for Manage Courses delete (M-04) |
| `allMappings()` | Returns full dict for Manage Courses sheet (M-04) |
| `allRecentCourses()` | Returns recent list for picker (M-03) |
| `currentTerm()` | Returns term for UI display + filter (CT-01) |

Uses `Data.write(to:options:.atomic)` for POSIX-level atomicity (T-04-03 mitigation). Actor isolation prevents concurrent writes from the same process. `os.Logger` warning on malformed JSON (guarded by `#if canImport(os)` for Linux testability).

### Tests (10 tests, all green on Linux)

- Test 1: Document round-trips through JSON with snake_case keys
- Test 2: `load()` returns empty default on non-existent file
- Test 3: `load()` returns empty default on malformed JSON (T-04-02)
- Test 4: `lookup()` returns mapping after upsert, nil for unmapped
- Test 5: `upsert()` persists and is visible on fresh `load()` (M-02)
- Test 6: `addRecent()` deduplicates, inserts at position 0, trims to 5 (M-03)
- Test 7: `setCurrentTerm()` updates and persists (CT-01)
- Test 8: `load()` decodes pre-written snake_case JSON (iCloud sync simulation)
- Test 9: `deleteMapping()` removes entry and persists
- Test 10: `allMappings()` returns complete dict

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Actor methods changed from `throws` to `async throws`**
- **Found during:** Task 1 GREEN phase
- **Issue:** Swift 6 strict concurrency requires `async` on all actor-isolated methods called from outside the actor context. The plan specified `throws` signatures (e.g., `load() throws ->`), but the Swift 6 compiler rejects synchronous calls to actor-isolated methods from non-isolated contexts.
- **Fix:** Changed all public and private methods to `async throws` (or `async` for void-returning). Updated tests to use `await`. This matches the existing `PipelineOrchestrator.run(inputs:) async throws` pattern in the codebase.
- **Files modified:** `CourseMappingStore.swift` (10 method signatures), `CourseMappingStoreTests.swift` (all test functions marked `async throws`)
- **Commit:** cc65491

## TDD Gate Compliance

- **RED gate:** `test(04-01): add failing tests for CourseMappingStore` — commit 79e6ff9 (10 tests, all fail to compile because types don't exist)
- **GREEN gate:** `feat(04-01): implement CourseMapping schema + CourseMappingStore actor` — commit cc65491 (all 10 tests pass)
- **REFACTOR gate:** Not needed — implementation is clean on first pass

## Verification

- `swift build` succeeds for UnibrainCore target
- `swift test --filter CourseMappingStoreTests` — 10/10 passed
- No new SPM dependencies added (Foundation only)

## Known Stubs

None. All methods are fully implemented with disk persistence.

## Threat Flags

None. The threat model's three items (T-04-01 path traversal, T-04-02 malformed JSON, T-04-03 iCloud atomicity) are all mitigated in the implementation as designed.

## Self-Check: PASSED

- `Sources/UnibrainCore/Classification/CourseMapping.swift` — FOUND
- `Sources/UnibrainCore/Classification/CourseMappingStore.swift` — FOUND
- `Tests/UnibrainCoreTests/ClassificationTests/CourseMappingStoreTests.swift` — FOUND
- Commit `79e6ff9` (RED) — FOUND in git log
- Commit `cc65491` (GREEN) — FOUND in git log
