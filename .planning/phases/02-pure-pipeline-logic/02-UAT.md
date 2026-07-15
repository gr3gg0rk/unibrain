---
status: complete
phase: 02-pure-pipeline-logic
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md, 02-04-SUMMARY.md]
started: 2026-07-15T16:25:00Z
updated: 2026-07-15T18:20:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Cold Start Smoke Test — Linux CI builds UnibrainCore from scratch

expected: Push to main triggers `.github/workflows/ci.yml`. The `linux-tests` job on `ubuntu-latest` installs Swift 6.0.3, resolves SPM deps, builds the `UnibrainCore` target, and runs `swift test --filter UnibrainCoreTests`. All 117 tests (13 Phase 1 + 104 Phase 2) pass.
result: pass
evidence: "CI run 29439950523, Linux job 87436028384 — 1m1s — ✓ Build UnibrainCore target + ✓ Run UnibrainCore tests"

### 2. FrontmatterSchema validation (12 fields, snake_case, non-empty guards)

expected: `FrontmatterSchemaTests` suite passes — validate() rejects empty course/courseName/term, rejects durationSeconds ≤ 0, accepts well-formed 12-field schemas. CodingKeys emit snake_case.
result: pass
evidence: "macOS job 87436028377 — Suite 'FrontmatterSchema' passed"

### 3. NoteNormalizer pure transform (title, wiki-link, transcript section, frontmatter)

expected: `NoteNormalizer Normalize` + `NoteNormalizer Paragraph Grouping` suites pass — H1 title in YYYY-MM-DD format, audio wiki-link `![[file]]`, `## Transcript` heading, paragraph grouping by 3s gap threshold.
result: pass
evidence: "macOS job — Suites 'NoteNormalizer Normalize' + 'NoteNormalizer Paragraph Grouping' passed"

### 4. NoteWriter atomic write + .icloud detection (TestNoteWriter + NSFileCoordinatorNoteWriter)

expected: `NoteWriter` suite passes on macOS — atomic write round-trips, .icloud placeholder detection throws `NoteWriterError.iCloudPlaceholder`, directory creation failures throw structured errors. NSFileCoordinatorNoteWriter uses `.forReplacing` + `Data.write(.atomic)` for double-layered atomicity.
result: pass
evidence: "macOS job — Suite 'NoteWriter' passed, Suite 'NSFileCoordinatorNoteWriter' passed (after iCloud placeholder filename fix in 024a271)"

### 5. CourseClassifier boundary conditions + FolderNameSanitizer path-traversal mitigation

expected: `CourseClassifier` suite passes — ±30min default window, boundary cases (event ends at windowStart, event starts at windowEnd, event fully contains window), .single/.multiple/.none outcomes. `FolderNameSanitizer` strips `/`, `:`, leading dots, path traversal neutralized.
result: pass
evidence: "macOS job — Suites 'CourseClassifier' + 'FolderNameSanitizer' passed"

### 6. PipelineOrchestrator state machine (8 states, concurrent-run rejection, cooperative cancellation, fail-fast)

expected: `PipelineOrchestrator` suite passes — idle initial state, full transition through stages to `.completed`, concurrent-run rejection throws `.alreadyRunning`, transcriber/writer errors transition to `.failed`, `cancel()` transitions to `.cancelled`, `reset()` returns to `.idle`. The 4 behavior-unverified items from the original VERIFICATION.md are now empirically executed.
result: pass
evidence: "macOS job — Suite 'PipelineOrchestrator' passed (1.131s) — tests 'run transitions through all stages to .completed', 'run throws .alreadyRunning when called while not idle', 'transcriber error transitions to .failed state', 'writer error transitions to .failed state' all visible in CI log"

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0

## Gaps

[none]

## Methodology Note

Phase 02 is a pure-logic phase with no user-facing UI; the MVP user-story UAT framing does not apply (the phase goal is not in `As a… I want to… so that….` form). Per user direction (option 3 in the verify-work routing dialog), Linux CI was treated as the human verifier: a green run on both Linux (UnibrainCore tests) and macOS (full build + all tests) constitutes passing UAT. The "user" whose experience is verified is the developer relying on the CI signal to trust that the pure pipeline logic is correct.
