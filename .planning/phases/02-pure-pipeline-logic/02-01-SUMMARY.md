---
phase: 02-pure-pipeline-logic
plan: 01
subsystem: Normalization
tags: [note-normalizer, frontmatter, validation, paragraph-grouping, pure-logic]
requires:
  - FrontmatterSchema (Phase 1)
  - ProviderError pattern (Phase 1)
provides:
  - NormalizedNote value type (title + body + frontmatter contract)
  - NoteNormalizer.normalize() (transcript + course → NormalizedNote)
  - NoteNormalizer.groupParagraphs() (3-second gap heuristic)
  - FrontmatterSchema.validate() (required field enforcement)
  - FrontmatterValidationError (structured validation errors)
  - CalendarEvent struct (classification input type)
  - FolderNameSanitizer stub (filesystem-safe name sanitization)
affects:
  - Plan 02 (NoteWriter protocol consumes NormalizedNote)
  - Plan 03 (FolderNameSanitizer full implementation replaces stub)
  - Plan 04 (CourseClassifier uses CalendarEvent)
  - Phase 3 (ASR adapter maps whisper.cpp segments to N-03 contract)
  - Phase 6 (## Summary section emission when summaryModel non-nil)
tech-stack:
  added: []
  patterns:
    - Pure static struct with no state (NoteNormalizer)
    - Sendable value type for cross-actor data (NormalizedNote)
    - Error enum with Equatable for test assertion (FrontmatterValidationError)
    - TDD RED/GREEN cycle per task
key-files:
  created:
    - Sources/UnibrainCore/Normalization/NormalizedNote.swift
    - Sources/UnibrainCore/Normalization/NoteNormalizer.swift
    - Sources/UnibrainCore/Errors/FrontmatterValidationError.swift
    - Sources/UnibrainCore/Classification/CalendarEvent.swift
    - Sources/UnibrainCore/Classification/FolderNameSanitizer.swift
    - Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift
    - Tests/UnibrainCoreTests/NormalizationTests/NormalizedNoteTests.swift
    - Tests/UnibrainCoreTests/NormalizationTests/FrontmatterValidationErrorTests.swift
  modified:
    - Sources/UnibrainCore/Schemas/FrontmatterSchema.swift
    - Tests/UnibrainCoreTests/FrontmatterSchemaTests.swift
decisions:
  - "NormalizedNote is Sendable but NOT Codable — no serialization needed (A-02 contract)"
  - "FolderNameSanitizer uses split/join for whitespace collapsing instead of regex (stub; Plan 03 adds regex)"
  - "FrontmatterValidationError conforms to Equatable for #expect(throws:) test assertions"
  - "CalendarEvent created early (needed by NoteNormalizer.normalize) per C-01 contract"
  - "DateFormatter uses UTC timezone for consistent date formatting across environments"
metrics:
  duration: 12m
  tasks: 6
  files: 10
  tests: 32
status: complete
---

# Phase 02 Plan 01: Note Normalization Contract Summary

Pure-logic note normalization pipeline: NormalizedNote value type, NoteNormalizer (paragraph grouping + Markdown generation), FrontmatterSchema.validate(), and FrontmatterValidationError — all Linux-testable, proving WRITE-01/02/03 requirements.

## What Was Built

### Core Types

**NormalizedNote.swift** — `public struct NormalizedNote: Sendable` carrying `title: String`, `body: String`, `frontmatter: FrontmatterSchema`. The single value type that flows from NoteNormalizer to NoteWriter. Not Codable (no serialization needed).

**NoteNormalizer.swift** — `public struct NoteNormalizer` with two static methods:
- `groupParagraphs(segments:threshold:)` — Groups ASR segments into paragraphs by 3-second gap heuristic (N-04). Filters empty/whitespace-only segments before grouping (Pitfall 3 avoidance).
- `normalize(transcript:course:audioFile:recordingStart:durationSeconds:)` — Produces complete NormalizedNote with H1 title (`YYYY-MM-DD — {course} Lecture`), audio wiki-link (`![[filename]]`), `## Transcript` section, and validated FrontmatterSchema.

**FrontmatterValidationError.swift** — `public enum FrontmatterValidationError: Error, Sendable, Equatable` with three cases: `.emptyField(String)`, `.invalidDuration(Int)`, `.missingRequiredField(String)`. Equatable conformance enables `#expect(throws:)` in tests.

**CalendarEvent.swift** — `public struct CalendarEvent: Sendable` with `id`, `title`, `startDate`, `endDate`, `location?`. Apple-framework-agnostic event type per C-01. Phase 4's EventKit adapter maps EKEvent to this.

**FolderNameSanitizer.swift** — `public struct FolderNameSanitizer` with static `sanitize(folderName:)`. Stub implementation for Plan 01; Plan 03 adds regex whitespace collapsing and full path traversal protection.

### Modified Files

**FrontmatterSchema.swift** — Added `public func validate() throws` method checking: course non-empty, courseName non-empty, term non-empty, durationSeconds > 0, tags non-empty. No changes to existing init or CodingKeys.

**FrontmatterSchemaTests.swift** — Added 6 validation tests (4 existing + 6 new = 10 total).

## Test Coverage

| Suite | Tests | Coverage |
|-------|-------|----------|
| NoteNormalizer Paragraph Grouping | 6 | Empty input, single segment, within-threshold, large gap, zero gap, whitespace filtering |
| NoteNormalizer Normalize | 9 | H1 format, wiki-link emission, wiki-link ordering, transcript heading, paragraph grouping in body, frontmatter completeness, validation, no summary, course sanitization |
| NormalizedNote | 3 | Construction, Sendable conformance, 12-field storage |
| FrontmatterValidationError | 4 | Case construction (3 cases), Error catchability |
| FrontmatterSchema | 10 | Creation, Yams round-trip, snake_case keys, nil round-trip, validation (6 tests) |
| **Total** | **32** | |

All 45 tests in the project pass (32 from this plan + 13 from Phase 1).

## TDD Compliance

All 5 implementation tasks followed strict TDD RED/GREEN cycle:

| Task | Type | RED Commit | GREEN Commit |
|------|------|------------|--------------|
| 1: NormalizedNote | TDD | e4ceb61 | e4ceb61 |
| 2: FrontmatterValidationError | TDD | 1d8ad3c | 1d8ad3c |
| 3: FrontmatterSchema.validate() | TDD | 468a3f6 | 468a3f6 |
| 4: groupParagraphs() | TDD | 5dcdd27 | 5dcdd27 |
| 5: normalize() | TDD | 9b1d6b3 | 9b1d6b3 |
| 6: Comprehensive tests | auto | d39ee64 (consolidation) | - |

Note: TDD commits use single-commit pattern (test + implementation together) since swift build verification requires both to compile.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added Equatable conformance to FrontmatterValidationError**
- **Found during:** Task 3
- **Issue:** `#expect(throws: FrontmatterValidationError.emptyField(...))` requires the error type to conform to `Equatable`. Swift Testing's typed `throws` assertion has an `Equatable` constraint.
- **Fix:** Added `Equatable` to the conformance list: `public enum FrontmatterValidationError: Error, Sendable, Equatable`
- **Files modified:** Sources/UnibrainCore/Errors/FrontmatterValidationError.swift
- **Commit:** 468a3f6

**2. [Rule 1 - Bug] Fixed paragraph grouping test data (filter test)**
- **Found during:** Task 4
- **Issue:** The "filters empty segments" test had segments where the gap between the first and last real segment (after filtering) was >= 3.0s, causing an unexpected paragraph split.
- **Fix:** Adjusted segment timestamps so the gap after filtering is < 3.0s.
- **Files modified:** Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift
- **Commit:** 5dcdd27

**3. [Rule 3 - Blocking] Created CalendarEvent and FolderNameSanitizer early**
- **Found during:** Task 5
- **Issue:** `NoteNormalizer.normalize()` depends on `CalendarEvent` (C-01) and `FolderNameSanitizer` (C-05) which don't exist yet. These are planned for Plan 03/04 but needed now for normalize() to compile.
- **Fix:** Created CalendarEvent per C-01 contract and FolderNameSanitizer as a temporary stub (T-2-01 accepted risk). Plan 03 will implement full FolderNameSanitizer with regex support.
- **Files created:** Sources/UnibrainCore/Classification/CalendarEvent.swift, Sources/UnibrainCore/Classification/FolderNameSanitizer.swift
- **Commit:** 9b1d6b3

**4. [Rule 1 - Bug] Fixed H1 title date expectation in test**
- **Found during:** Task 5
- **Issue:** Test expected date `2026-09-14` but timestamp `1_700_000_000` equals `2023-11-14` in UTC.
- **Fix:** Updated test expectations to use correct date `2023-11-14` matching the actual timestamp.
- **Files modified:** Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift (was NoteNormalizerNormalizeTests.swift)
- **Commit:** 9b1d6b3

### Scope Decisions

- NormalizedNote tests kept in separate file (`NormalizedNoteTests.swift`) rather than merged into `NoteNormalizerTests.swift` — better organization, same coverage
- FolderNameSanitizer uses `split/join` instead of regex literal for whitespace collapsing — works on Linux Swift 6.0.3 without regex issues; Plan 03 will upgrade

## Known Stubs

| File | Stub | Reason | Resolved By |
|------|------|--------|-------------|
| FolderNameSanitizer.swift | Uses `split/join` instead of `/\s+/` regex for whitespace collapsing | Stub for Plan 01; avoids regex edge cases on Linux | Plan 03 (full implementation) |
| NoteNormalizer.normalize() | `term` hardcoded to "Fall 2026" | Term resolution needs Phase 4 calendar integration | Phase 4 |
| NoteNormalizer.normalize() | `source` hardcoded to "MacBook Air" | Source needs capture session metadata | Phase 3 |

## Threat Flags

No new threat surface introduced beyond what's documented in the plan's threat model. T-2-01 (FolderNameSanitizer stub) risk accepted as documented.

## Self-Check: PASSED

All source files verified to exist on disk. All 6 task commits verified in git log. All 45 tests pass on WSL2 Linux via `swift test`.
