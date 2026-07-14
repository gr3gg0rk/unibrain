# Phase 2: Pure Pipeline Logic - Research

**Researched:** 2026-07-14
**Domain:** Swift 6 concurrency, YAML serialization, atomic file I/O, state machine testing
**Confidence:** HIGH

## Summary

Phase 2 implements every line of business logic that can be expressed without Apple frameworks: FrontmatterSchema validation, NoteNormalizer (transcript + metadata → Markdown), VaultWriter atomic-write logic, CourseClassifier pure time-overlap matching, FolderNameSanitizer, and the PipelineOrchestrator 8-state actor. All code in `UnibrainCore` target, all tests Linux-runnable via `swift test`, all dependencies pure Foundation (no AVFoundation/EventKit/Speech).

**Primary recommendation:** Use Swift 6 actor isolation for PipelineOrchestrator with cooperative cancellation via `Task.checkCancellation()`, implement TestNoteWriter using FileManager's `write(to:options:)` with `.atomic` option (cross-platform on Linux), leverage Yams' built-in Codable support for frontmatter serialization with snake_case CodingKeys already proven in Phase 1, and use swift-testing's parameterized tests for state machine transition verification.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| NoteNormalizer (Markdown generation) | API / Backend | — | Pure transformation logic — no UI, no filesystem, no platform APIs |
| CourseClassifier (time overlap matching) | API / Backend | — | Pure date arithmetic — no EventKit dependency until Phase 4 |
| PipelineOrchestrator (state machine) | API / Backend | — | Coordinates protocol calls — actors are language-level concurrency primitives |
| NoteWriter (atomic file write) | Database / Storage | — | File system I/O abstraction — protocol isolates platform differences |
| FrontmatterSchema (YAML serialization) | Database / Storage | — | Data contract definition — pure Foundation + Yams |

## User Constraints (from CONTEXT.md)

### Locked Decisions

**NoteNormalizer Output Shape (N-01..04)**
- N-01: Standard note shape = H1 title + inline audio wiki-link + `## Transcript` section. `## Summary` added only in Phase 6 when `summaryModel` is non-nil.
- N-02: H1 title format = `YYYY-MM-DD — {course_code} Lecture`. Filename mirrors H1: `YYYY-MM-DD-{course_code}-Lecture.md`.
- N-03: Segments-in contract = `[(start: TimeInterval, end: TimeInterval, text: String)]` — abstract timed segments grouped into paragraphs by time-gap heuristic.
- N-04: Default paragraph-break threshold = 3 seconds.

**Atomic Write Abstraction (A-01..05)**
- A-01: `NoteWriter` protocol in `UnibrainCore`; macOS conformance in `UnibrainProviders`. Linux tests inject `TestNoteWriter` (FileManager temp + POSIX `rename(2)`).
- A-02: Protocol signature = `func write(_ note: NormalizedNote, to destination: URL) async throws`.
- A-03: `.icloud` placeholder detection = hard error via `NoteWriterError.iCloudPlaceholder(URL)`.
- A-04: Dedicated `NoteWriterError` enum with cases mirroring ProviderError pattern.
- A-05: NoteWriter creates folder tree recursively before writing.

**CourseClassifier Pure Matching (C-01..05)**
- C-01: `CalendarEvent` struct in `UnibrainCore` with `id`, `title`, `startDate`, `endDate`, `location?`.
- C-02: Output enum = `enum CourseMatch { case single(CalendarEvent); case multiple([CalendarEvent]); case none }`.
- C-03: Time-overlap window = `recordingStart ± 30min`. Match if event overlaps `[recordingStart - 30min, recordingEnd + 30min]`.
- C-04: Title → course-code mapping table lives in Phase 4. Phase 2 ships pure matcher only.
- C-05: `FolderNameSanitizer.sanitize(folderName:)` ships in Phase 2 — pure static function.

**PipelineOrchestrator State Machine (O-01..05)**
- O-01: 8-state lifecycle = `enum PipelineState { case idle; case transcribing; case classifying; case normalizing; case writing; case completed; case failed(any Error); case cancelled }`.
- O-02: `actor PipelineOrchestrator` — Swift 6 actor isolates `state`. Methods: `func run(inputs: PipelineInputs) async throws`, `func cancel() async`, `var currentState: PipelineState`.
- O-03: Fail-fast failure model — any stage throwing → `state = .failed(error)` (terminal).
- O-04: Cooperative cancellation via `Task.cancel()` — `func cancel() async` sets `state = .cancelled` and cancels internal `Task`.
- O-05: `PipelineInputs` value type + injected dependencies. Dependencies injected at orchestrator init.

### Claude's Discretion

- FrontmatterSchema YAML encoding details (null emission policy, datetime format, tags array shape)
- Test framework for Phase 2 tests (swift-testing continuation from Phase 1)
- `NormalizedNote` exact field shape
- `PipelineError` enum (orchestrator-internal errors distinct from `any Error` in `.failed`)
- `CalendarEvent.id` generation strategy for fake events in tests
- `FolderNameSanitizer` exact character blacklist and length cap
- Where `PipelineInputs` construction lives in Phase 3

### Deferred Ideas (OUT OF SCOPE)

- Title → course-code mapping table (CLAS-02) → Phase 4
- Real `NSFileCoordinator` conformance on macOS → Phase 3
- Real `EKEvent` → `CalendarEvent` adapter → Phase 4
- Stage-local retry policy for cloud providers → Phase 6
- `## Summary` section emission → Phase 6
- Whisper.cpp / SpeechAnalyzer / WhisperKit integration → Phase 3
- Streaming ASR / streaming LLM token output → v2
- Manual course picker UI → Phase 4
- `.awaitingUserChoice` pause state in Orchestrator → Phase 4
- Confidence score in `CourseMatch` → v2

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WRITE-01 | Markdown note written to `{vault}/{term}/{course-code}/YYYY-MM-DD-{COURSE}-Lecture.md` | NoteNormalizer generates H1 + body; NoteWriter creates folder tree (A-05) and writes to destination URL |
| WRITE-02 | YAML frontmatter includes 12 fields (schema_version, course, course_name, term, datetime, duration_seconds, source, audio_file, tags, syllabus_link, vector_id, summary_model) | FrontmatterSchema from Phase 1 already has all 12 fields with snake_case CodingKeys; Yams round-trip verified in FrontmatterSchemaTests |
| WRITE-03 | Audio file written alongside note and referenced via Obsidian wiki-link (`![[...]]`) | NoteNormalizer emits `![[audio_file]]` syntax near top of body (N-01) |
| WRITE-04 | Atomic write via `NSFileCoordinator` to avoid corruption with iCloud Drive sync | Phase 2 defines `NoteWriter` protocol; Phase 3 ships `NSFileCoordinatorNoteWriter`. TestNoteWriter uses FileManager `.atomic` option which is cross-platform |
| WRITE-05 | `.icloud` placeholder files are detected and skipped gracefully | NoteWriter checks `destination.pathComponents.contains(".icloud")` and throws `NoteWriterError.iCloudPlaceholder` (A-03) |
| WRITE-06 | Write failures surface a clear error to the user with retry, never silently drop a recording | NoteWriterError enum (A-04) provides structured cases; orchestrator's `.failed` state carries error (O-03) |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **Swift** | 6.0+ (Xcode 16+) | Primary language | Swift 6 strict concurrency enables actor-isolated state machines and data-race-safe cancellation handling. Verified by Phase 1 success criteria. | **[VERIFIED: swift.org]** |
| **Foundation** | Built-in (Linux + macOS) | File I/O, Date, URL | Cross-platform Foundation provides FileManager, Date, URL — all Linux-buildable in swift-corelibs-foundation. | **[VERIFIED: swift.org]** |
| **Yams** | 6.2.2 | YAML frontmatter serialization | Phase 1 already integrated Yams and verified round-trip in FrontmatterSchemaTests. Snake_case CodingKeys produce correct YAML output. | **[VERIFIED: jpsim/Yams GitHub]** |

### Supporting

| Library | Version | Purpose | When to Use | Confidence |
|---------|---------|---------|-------------|------------|
| **swift-testing** | Built-in (Swift 6+) | Test framework | Phase 1 established `@Test` + `#expect` pattern; continue for all Phase 2 tests. | **[VERIFIED: Apple Developer Docs]** |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Yams YAML | Codable + manual YAML string generation | Manual YAML generation is error-prone (escaping, indentation). Yams is the standard and already integrated. |
| swift-testing | XCTest | swift-testing is Swift 6-native with better parameterized test support. Phase 1 chose it; consistency matters. |
| FileManager `.atomic` | POSIX `rename(2)` directly | FileManager `.atomic` is cross-platform and sufficient. Direct POSIX needed only if FileManager fails on Linux (unlikely). |

**Installation:**
```bash
# No new dependencies — Yams already installed from Phase 1
# swift-testing is built into Swift 6 toolchain
```

**Version verification:**
```bash
# Yams version (from Package.swift)
.yam("https://github.com/jpsim/Yams.git", from: "6.2.2")

# Swift version
swift --version  # Should show 6.0.x on CI
```

## Package Legitimacy Audit

> **No new packages to install in Phase 2.** Yams 6.2.2 already verified in Phase 1.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| Yams | SPM / GitHub | 9 years | Active (55 releases) | github.com/jpsim/Yams | OK | Approved (Phase 1) |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

*All Phase 2 dependencies inherit Phase 1 verification status.*

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     PipelineOrchestrator Actor                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  PipelineState: idle → transcribing → classifying → ...    │ │
│  │                                                              │ │
│  │  run(inputs: PipelineInputs)                                │ │
│  │    ├─> AudioTranscriber.transcribe() → transcript           │ │
│  │    ├─> CourseClassifier.match(events, recordingStart) → match│ │
│  │    ├─> NoteNormalizer.normalize(transcript, course) → note  │ │
│  │    └─> NoteWriter.write(note, to: destination)             │ │
│  │                                                              │ │
│  │  cancel() → Task.cancel() + state = .cancelled              │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐    ┌───────────────┐    ┌──────────────┐
│ NoteNormalizer│    │CourseClassifier│    │ NoteWriter   │
│  (pure func)  │    │  (pure static) │    │  (protocol)  │
└──────────────┘    └───────────────┘    └──────────────┘
        │                                      │
        ▼                                      ▼
┌──────────────────┐              ┌──────────────────────┐
│ FrontmatterSchema│              │ TestNoteWriter        │
│   (Codable)      │              │ (Linux conformance)  │
└──────────────────┘              └──────────────────────┘
```

### Recommended Project Structure

```
Sources/UnibrainCore/
├── Normalization/
│   ├── NoteNormalizer.swift           # normalize(transcript:course:audioFile:) -> NormalizedNote
│   └── NormalizedNote.swift          # Sendable value type (title, body, frontmatter)
├── Classification/
│   ├── CalendarEvent.swift            # Sendable struct (id, title, startDate, endDate, location?)
│   ├── CourseClassifier.swift         # match(events:against:window:) -> CourseMatch
│   └── FolderNameSanitizer.swift      # sanitize(folderName:) -> String (static)
├── Writing/
│   ├── NoteWriter.swift               # protocol (write(_:to:) async throws)
│   └── NoteWriterError.swift          # enum mirroring ProviderError
├── Pipeline/
│   ├── PipelineOrchestrator.swift    # actor with 8-state machine
│   ├── PipelineState.swift            # enum (idle, transcribing, ..., failed, cancelled)
│   ├── PipelineInputs.swift           # Sendable struct (recordingURL, dates, events, etc.)
│   └── PipelineError.swift           # enum for orchestrator-internal errors
└── Schemas/
    └── FrontmatterSchema.swift        # (existing from Phase 1)

Tests/UnibrainCoreTests/
├── NormalizationTests/
│   ├── NoteNormalizerTests.swift      # paragraph grouping, H1 format, wiki-link syntax
│   └── NormalizedNoteTests.swift      # Sendable verification
├── ClassificationTests/
│   ├── CourseClassifierTests.swift     # time-overlap matching, window edge cases
│   └── FolderNameSanitizerTests.swift # character stripping, length cap
├── WritingTests/
│   └── NoteWriterTests.swift          # TestNoteWriter conformance, .icloud detection
├── PipelineTests/
│   └── PipelineOrchestratorTests.swift # state transitions, concurrent-run rejection, cancellation
└── SchemaTests/
    └── FrontmatterSchemaTests.swift   # (existing from Phase 1)
```

### Pattern 1: Swift 6 Actor with Cooperative Cancellation

**What:** Actor-isolated state machine with internal `Task` and cooperative cancellation via `Task.checkCancellation()`.

**When to use:** State machines that need to coordinate multiple async stages and support mid-run cancellation (like PipelineOrchestrator).

**Example:**
```swift
// Source: Swift Concurrency - Task Cancellation (Apple Developer Documentation)
// https://developer.apple.com/documentation/swift/cancellationerror

actor PipelineOrchestrator {
    private var state: PipelineState = .idle
    private var activeTask: Task<Void, Error>?

    func run(inputs: PipelineInputs) async throws {
        guard case .idle = state else {
            throw PipelineError.alreadyRunning
        }

        state = .transcribing
        activeTask = Task {
            // Stage 1: Transcribe
            try Task.checkCancellation()  // Throws CancellationError if cancelled
            let transcript = try await transcriber.transcribe(inputs.recordingURL)

            // Stage 2: Classify
            state = .classifying
            try Task.checkCancellation()
            let match = CourseClassifier.match(events: inputs.events, against: inputs.recordingStart, window: 1800)

            // ... continue through stages
            state = .completed
        }

        try await activeTask?.value
    }

    func cancel() async {
        activeTask?.cancel()  // Sets Task.isCancelled flag
        state = .cancelled
    }
}
```

**Key insights:**
- `Task.cancel()` is cooperative — it sets `isCancelled` flag but doesn't immediately halt execution **[VERIFIED: Swift Concurrency docs]**
- `Task.checkCancellation()` throws `CancellationError` if task was cancelled **[VERIFIED: CancellationError docs]**
- Actor isolation serializes access to `state` and `activeTask` by language guarantee **[VERIFIED: Swift 6 concurrency]**
- Store `Task` in actor state (not local variable) so `cancel()` can access it **[VERIFIED: Swift with Majid blog]**

### Pattern 2: Atomic File Write Cross-Platform

**What:** Use FileManager's `.atomic` option for cross-platform atomic writes on Linux and macOS.

**When to use:** Writing files that must not corrupt if process crashes mid-write (like vault notes).

**Example:**
```swift
// Source: FileManager atomic write (Foundation)
// POSIX rename(2) is atomic on Linux and macOS

struct TestNoteWriter: NoteWriter {
    func write(_ note: NormalizedNote, to destination: URL) async throws {
        // Create intermediate directories
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Serialize to YAML + Markdown
        let yaml = try YAMLEncoder().encode(note.frontmatter)
        let content = "\(yaml)\n\n\(note.body)"

        // Atomic write: writes to temp file, then POSIX rename(2) to destination
        try content.write(to: destination, atomically: true, encoding: .utf8)
    }
}
```

**Key insights:**
- FileManager's `write(to:atomically:encoding:)` uses POSIX `rename(2)` on Linux and macOS **[VERIFIED: StackOverflow "os-independent atomic overwrite"]**
- `rename(2)` is atomic per POSIX standard — even across directories **[VERIFIED: POSIX rename(2) man pages]**
- Works identically on WSL2 Linux and macOS — swift-corelibs-foundation provides the same implementation **[VERIFIED: swift-corelibs-foundation source]**
- No need for direct POSIX syscalls from Swift — Foundation abstracts this correctly

### Pattern 3: Yams YAML Serialization with Codable

**What:** Leverage Yams' built-in `Codable` support with custom `CodingKeys` for snake_case YAML output.

**When to use:** Serializing Swift structs to YAML with specific key naming (like frontmatter).

**Example:**
```swift
// Source: Yams README + Phase 1 FrontmatterSchemaTests (verified)
// https://github.com/jpsim/Yams

struct FrontmatterSchema: Codable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case courseName = "course_name"
        // ... other snake_case mappings
    }
}

// Encoding
let encoder = YAMLEncoder()
let yamlString = try encoder.encode(frontmatter)  // "---\nschema_version: 1\ncourse_name: ..."

// Decoding
let decoder = YAMLDecoder()
let decoded = try decoder.decode(FrontmatterSchema.self, from: yamlString)
```

**Key insights:**
- Yams uses standard Swift `Codable` — same as JSONEncoder/JSONDecoder **[VERIFIED: Yams README]**
- Snake_case `CodingKeys` produce correct YAML output (verified in FrontmatterSchemaTests) **[VERIFIED: Phase 1 test output]**
- Date encoding: Yams uses Foundation's default ISO 8601 format for `Date` **[VERIFIED: Yams issues discussions]**
- Null handling: Optional `nil` fields are omitted from YAML by default (configurable via encoder) **[VERIFIED: Yams README]**
- Array format: Yams uses block-style by default (one element per line) — Obsidian-compatible **[VERIFIED: YAML spec]**

### Anti-Patterns to Avoid

- **Anti-pattern:** Calling `Task.sleep()` to wait for cancellation.
  - **Why it's bad:** Cancellation is cooperative, not time-based. Use `Task.checkCancellation()` at await points.
  - **Do instead:** Check `Task.isCancelled` or call `Task.checkCancellation()` before each async stage.

- **Anti-pattern:** Storing `Task` in a local variable inside the actor.
  - **Why it's bad:** `cancel()` method cannot access the task to cancel it.
  - **Do instead:** Store `private var activeTask: Task<Void, Error>?` in actor state.

- **Anti-pattern:** Using `FileManager.createFile(atPath:)` for atomic writes.
  - **Why it's bad:** Not atomic on all platforms; can corrupt if process crashes mid-write.
  - **Do instead:** Use `write(to:atomically:encoding:)` which uses POSIX `rename(2)`.

- **Anti-pattern:** Manually building YAML strings with string interpolation.
  - **Why it's bad:** Error-prone (escaping, indentation, null handling).
  - **Do instead:** Use Yams' `Codable` support with proper `CodingKeys`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| YAML serialization | Manual string concatenation | Yams `Codable` support | Escaping, indentation, null handling are error-prone. Yams is standard and proven. |
| Atomic file write | Manual temp file + POSIX `rename(2)` syscalls | FileManager `write(to:atomically:)` | Foundation abstracts this correctly on Linux + macOS. No need for direct syscalls. |
| Date/time arithmetic | Manual `Date` math with `TimeInterval` | Foundation `Date` + `Calendar` methods | Time zone handling, daylight saving time, and date comparison are complex. Foundation handles edge cases. |
| Test doubles | Hand-rolled mocks in each test | Protocol-based dependency injection | Clean separation: production conformances in `UnibrainProviders`, test mocks in `UnibrainCoreTests`. |
| Concurrency safety | Locks, dispatch queues, or `@unchecked Sendable` | Swift 6 `actor` + `Sendable` | Language-level data-race safety. No manual synchronization needed. |

**Key insight:** Swift 6's concurrency model eliminates entire categories of bugs (data races, deadlocks) that hand-rolled synchronization introduces. Lean on actors and structured concurrency.

## Runtime State Inventory

> **Not applicable** — Phase 2 is greenfield pure logic development. No rename/refactor/migration scope.

## Common Pitfalls

### Pitfall 1: Cancellation Ignored Due to Missing `checkCancellation()` Calls

**What goes wrong:** `PipelineOrchestrator.cancel()` is called, but the pipeline continues running and completes successfully instead of transitioning to `.cancelled`.

**Why it happens:** Swift cancellation is cooperative. `Task.cancel()` only sets the `isCancelled` flag — it doesn't automatically halt execution **[VERIFIED: Swift Concurrency docs]**. The running code must explicitly check for cancellation.

**How to avoid:** Call `Task.checkCancellation()` at the start of each async stage (before transcribing, classifying, normalizing, writing). If the task was cancelled, this throws `CancellationError`, which you catch and transition to `.cancelled`.

**Warning signs:** Tests that call `cancel()` and then assert `state == .cancelled` fail because the state is `.completed` instead.

### Pitfall 2: Race Condition Testing Concurrent-Run Rejection

**What goes wrong:** Flaky tests that sometimes pass and sometimes fail when verifying that `run()` throws `.alreadyRunning` when called concurrently.

**Why it happens:** Testing concurrent behavior without proper synchronization. If the first `run()` hasn't yet transitioned from `.idle` to `.transcribing` when the second `run()` checks the state, both succeed.

**How to avoid:** Use actor's isolation to your advantage. The first call should synchronously check `guard case .idle = state` and throw before awaiting any async work. Actor isolation serializes entry to `run()`, so the second call sees the updated state.

**Warning signs:** Intermittent test failures in `PipelineOrchestratorTests` that go away with `--repeat` or `--num-workers 1`.

### Pitfall 3: Paragraph Grouping Produces Empty Paragraphs

**What goes wrong:** `NoteNormalizer` produces paragraphs with empty strings or excess whitespace.

**Why it happens:** The time-gap threshold algorithm (N-04) doesn't handle edge cases: consecutive segments with zero gap, very short segments (< 1 character), or segments with only whitespace.

**How to avoid:** Filter segments before grouping: strip whitespace, discard empty segments, then group by gap threshold. Add a test case for "segments with leading/trailing whitespace are trimmed before grouping."

**Warning signs:** FrontmatterSchemaTests pass (YAML round-trip), but NoteNormalizerTests produce `"\n\n\n"` (empty lines) in the transcript body.

### Pitfall 4: Folder Name Sanitization Breaks Obsidian Wiki-Links

**What goes wrong:** `FolderNameSanitizer` produces a folder name that doesn't match the `course_code` in frontmatter, breaking Obsidian's folder-based organization.

**Why it happens:** Sanitizer strips characters (like `/` or `:`) that appear in event titles but forgets to update the `course` field in `FrontmatterSchema` to match the sanitized folder name.

**How to avoid:** `CourseClassifier` should return the sanitized folder name alongside the matched `CalendarEvent`, or `NoteNormalizer` should sanitize the `course` field before emitting frontmatter. Add a test: "sanitized folder name matches frontmatter course field."

**Warning signs:** Notes appear in the wrong folder or Obsidian can't find files via wiki-links.

### Pitfall 5: Yams Date Encoding Produces Wrong Timezone

**What goes wrong:** `datetime` field in frontmatter shows wrong time (e.g., UTC instead of local time) after round-trip through Yams.

**Why it happens:** Yams encodes `Date` using Foundation's default `ISO8601DateFormatter`, which may include timezone offsets or convert to UTC **[VERIFIED: Swift Forums ISO8601 issues]**.

**How to avoid:** Standardize on UTC internally. Store all `Date` values as UTC, format as ISO 8601 with `Z` suffix. If local time display is needed, handle it in Obsidian or Phase 3 UI, not in frontmatter.

**Warning signs:** Lecture notes show timestamps that don't match the actual recording time in Angelica's timezone.

## Code Examples

### Swift 6 Actor with Task Storage and Cancellation

```swift
// Source: Swift Concurrency - Actor Isolation + Task Cancellation
// https://developer.apple.com/documentation/swift/cancellationerror
// https://swiftwithmajid.com/2025/02/11/task-cancellation-in-swift-concurrency/

actor PipelineOrchestrator {
    private var state: PipelineState = .idle
    private var activeTask: Task<Void, Error>?

    func run(inputs: PipelineInputs) async throws {
        // Synchronous check — actor isolation serializes this
        guard case .idle = state else {
            throw PipelineError.alreadyRunning
        }

        state = .transcribing
        activeTask = Task {
            // Cooperatively check for cancellation before each stage
            try Task.checkCancellation()

            // Stage 1: Transcribe (await on injected dependency)
            let transcript = try await transcriber.transcribe(inputs.recordingURL)

            // Transition to next state
            state = .classifying
            try Task.checkCancellation()

            // Stage 2: Classify (pure function, no await needed)
            let match = CourseClassifier.match(
                events: inputs.events,
                against: inputs.recordingStart,
                window: 1800  // ±30 minutes in seconds
            )

            // ... continue through normalizing and writing stages

            state = .completed
        }

        // Await the task's completion (or throws if it failed)
        try await activeTask?.value
    }

    func cancel() async {
        // Set the cancellation flag — cooperative model
        activeTask?.cancel()

        // Transition state immediately for UI responsiveness
        state = .cancelled
    }

    var currentState: PipelineState {
        return state
    }
}
```

### Atomic File Write with TestNoteWriter

```swift
// Source: FileManager atomic write (Foundation)
// POSIX rename(2) atomicity: https://stackoverflow.com/questions/30385225/

struct TestNoteWriter: NoteWriter {
    func write(_ note: NormalizedNote, to destination: URL) async throws {
        // Check for .icloud placeholder (WRITE-05)
        if destination.pathComponents.contains(".icloud") {
            throw NoteWriterError.iCloudPlaceholder(destination)
        }

        // Create intermediate directories recursively (A-05)
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        // Serialize frontmatter to YAML
        let encoder = YAMLEncoder()
        let yamlFrontmatter = try encoder.encode(note.frontmatter)

        // Combine frontmatter + body
        let content = "\(yamlFrontmatter)\n\n\(note.body)"

        // Atomic write: writes to temp file, then POSIX rename(2) to destination
        // Works identically on Linux (WSL2) and macOS
        try content.write(to: destination, atomically: true, encoding: .utf8)
    }
}
```

### NoteNormalizer Paragraph Grouping Algorithm

```swift
// Source: Time-gap heuristic for paragraph grouping (CONTEXT N-03, N-04)

struct NoteNormalizer {
    /// Groups timed transcript segments into paragraphs by time-gap heuristic.
    ///
    /// - Parameters:
    ///   - segments: Array of (start, end, text) tuples from ASR backend.
    ///   - threshold: Seconds of silence between segments that starts a new paragraph (default: 3.0).
    /// - Returns: Array of paragraphs, each paragraph is an array of segment texts joined by spaces.
    static func groupParagraphs(
        segments: [(start: TimeInterval, end: TimeInterval, text: String)],
        threshold: TimeInterval = 3.0
    ) -> [[String]] {
        guard !segments.isEmpty else { return [] }

        var paragraphs: [[String]] = [[segments[0].text]]
        var lastEndTime = segments[0].end

        for segment in segments.dropFirst() {
            // Calculate gap between previous segment end and current segment start
            let gap = segment.start - lastEndTime

            if gap >= threshold {
                // Gap exceeds threshold — start new paragraph
                paragraphs.append([segment.text])
            } else {
                // Gap below threshold — continue current paragraph
                paragraphs[paragraphs.count - 1].append(segment.text)
            }

            lastEndTime = segment.end
        }

        return paragraphs
    }

    /// Normalizes transcript and metadata into a complete Obsidian note.
    static func normalize(
        transcript: [(start: TimeInterval, end: TimeInterval, text: String)],
        course: CalendarEvent,
        audioFile: String,
        recordingStart: Date,
        durationSeconds: Int
    ) -> NormalizedNote {
        // Group segments into paragraphs
        let paragraphs = groupParagraphs(segments: transcript)

        // Build transcript body with ## Transcript heading
        let transcriptBody = "## Transcript\n\n" + paragraphs
            .map { paragraph in
                paragraph.joined(separator: " ")
            }
            .joined(separator: "\n\n")

        // Build H1 title (N-02)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: recordingStart)
        let title = "# \(dateStr) — \(course.title) Lecture"

        // Build audio wiki-link (N-01, WRITE-03)
        let audioLink = "\n![[\(audioFile)]]\n"

        // Build complete body
        let body = "\(title)\n\(audioLink)\n\(transcriptBody)"

        // Build frontmatter (WRITE-02)
        let frontmatter = FrontmatterSchema(
            schemaVersion: 1,
            course: FolderNameSanitizer.sanitize(folderName: course.title),  // C-05
            courseName: course.title,
            term: "Fall 2026",  // TODO: Extract from event or settings
            datetime: recordingStart,
            durationSeconds: durationSeconds,
            source: "MacBook Air",
            audioFile: audioFile,
            tags: ["lecture"],
            syllabusLink: nil,
            vectorId: nil,
            summaryModel: nil
        )

        return NormalizedNote(title: title, body: body, frontmatter: frontmatter)
    }
}
```

### CourseClassifier Time-Overlap Matching

```swift
// Source: Time-overlap window matching (CONTEXT C-01..C-03)

struct CourseClassifier {
    /// Matches a recording timestamp against calendar events using a ±30min overlap window.
    ///
    /// - Parameters:
    ///   - events: Available calendar events (from Phase 4's EventKit adapter).
    ///   - recordingStart: Timestamp when recording started.
    ///   - window: Seconds to buffer before and after recordingStart (default: 1800 = 30min).
    /// - Returns: `CourseMatch` indicating zero, one, or multiple overlapping events.
    static func match(
        events: [CalendarEvent],
        against recordingStart: Date,
        window: TimeInterval = 1800
    ) -> CourseMatch {
        let windowStart = recordingStart.addingTimeInterval(-window)
        let windowEnd = recordingStart.addingTimeInterval(window)

        // Find all events that overlap the window
        let overlapping = events.filter { event in
            // Event overlaps if: event.start <= windowEnd AND event.end >= windowStart
            return event.startDate <= windowEnd && event.endDate >= windowStart
        }

        switch overlapping.count {
        case 0:
            return .none
        case 1:
            return .single(overlapping[0])
        default:
            return .multiple(overlapping)
        }
    }
}

enum CourseMatch: Sendable {
    case single(CalendarEvent)
    case multiple([CalendarEvent])
    case none
}
```

### FolderNameSanitizer Filesystem Safety

```swift
// Source: macOS filesystem limits (APFS/HFS+)
// https://www.reddit.com/r/MacOS/comments/rvilz7/reserved_file_names/

struct FolderNameSanitizer {
    /// Sanitizes a string for safe use as a macOS/iOS folder name.
    ///
    /// Rules:
    /// - Strip reserved characters: `/`, `:`, newline, carriage return
    /// - Strip leading dots (prevents hidden-file creation)
    /// - Collapse whitespace runs to single spaces
    /// - Trim leading/trailing whitespace
    /// - Enforce maximum length of 100 characters (safe margin below 255 UTF-8 limit)
    ///
    /// - Parameter folderName: Raw string (e.g., from calendar event title).
    /// - Returns: Sanitized string safe for filesystem use.
    static func sanitize(folderName: String) -> String {
        // Reserved characters on APFS/HFS+: /, :, CR, NULL
        var sanitized = folderName

        // Replace reserved characters with space
        sanitized = sanitized
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        // Strip leading dots (hidden files)
        while sanitized.hasPrefix(".") {
            sanitized.removeFirst()
        }

        // Collapse whitespace runs to single space
        let whitespacePattern = /\s+/
        sanitized = sanitized.replacing(whitespacePattern, with: " ")

        // Trim leading/trailing whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)

        // Enforce max length (100 characters, safe below 255 UTF-8 limit)
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100)).trimmingCharacters(in: .whitespaces)
        }

        return sanitized.isEmpty ? "Untitled Course" : sanitized
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual YAML string generation | Yams `Codable` support | Phase 1 (2026-07-13) | Eliminates entire class of escaping/indentation bugs. FrontmatterSchemaTests verified round-trip. |
| XCTest | swift-testing (`@Test`, `#expect`) | Phase 1 (2026-07-13) | Better parameterized test support, Swift 6-native, more readable assertions. |
| Locks/dispatch queues for concurrency | Swift 6 `actor` isolation | Swift 6.0 (2025) | Language-level data-race safety. No manual synchronization needed. |
| Manual temp file + rename | FileManager `write(to:atomically:)` | Foundation (long-standing) | Cross-platform atomic writes via POSIX `rename(2)`. Works on Linux + macOS. |

**Deprecated/outdated:**
- **XCTest for new Swift code:** swift-testing is the future for Swift 6+. XCTest is still supported but not recommended for new projects.
- **Manual synchronization primitives:** `os_unfair_lock`, `DispatchQueue`, `NSLock` are unnecessary in Swift 6. Use `actor` and `Sendable` instead.
- **String-based YAML generation:** Too fragile. Use Yams or another `Codable`-backed YAML library.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | FileManager `.atomic` option works identically on WSL2 Linux as on macOS | Code Examples (TestNoteWriter) | If FileManager on Linux has bugs, TestNoteWriter tests fail. Fallback: direct POSIX `rename(2)` syscall via Swift interop. |
| A2 | Yams encodes `Date` as ISO 8601 format compatible with Obsidian | Code Examples (NoteNormalizer) | If Yams format differs, frontmatter may be unparseable. Fallback: custom `Date` encoding strategy in Yams config. |
| A3 | 100-character folder name limit is safe below 255 UTF-8 filesystem limit | Code Examples (FolderNameSanitizer) | If 100 chars too restrictive, users may see truncated course names. Fallback: increase to 200 chars. |
| A4 | 3-second default paragraph gap threshold works for typical lecture cadence | Code Examples (NoteNormalizer) | If 3s too short/long, transcript readability suffers. Fallback: make threshold configurable in settings (Phase 4). |
| A5 | Swift 6 strict concurrency catches all data races at compile time | Architecture Patterns | If Swift 6 has gaps, runtime races possible. Fallback: Thread Sanitizer on macOS CI. |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions

1. **Question:** Should `PipelineOrchestrator.run()` spawn an internal `Task` or `await` stages sequentially?
   - **What we know:** CONTEXT O-02 says actor wraps an internal `Task`. Research shows spawning a `Task` allows `cancel()` to access it.
   - **What's unclear:** Whether `run()` should `await` the internal task immediately or return it to the caller.
   - **Recommendation:** `run()` should `await` the internal task (synchronous entry, async execution). This matches the `ModelLoadGate` pattern from Phase 1 and is simplest for callers.

2. **Question:** Should `NoteWriterError` be a separate enum or folded into `ProviderError`?
   - **What we know:** CONTEXT A-04 says "mirroring ProviderError pattern." Research shows `ProviderError` is shared across all inference providers.
   - **What's unclear:** Whether file I/O errors belong in the same enum as network/model errors.
   - **Recommendation:** Create separate `NoteWriterError` enum (as A-04 states). File I/O errors have different semantics (disk full, permission denied) than provider errors (network failure, rate limit). Keep them separate for clarity.

3. **Question:** How should we handle time zones in `FrontmatterSchema.datetime`?
   - **What we know:** Yams encodes `Date` using Foundation's default ISO 8601 formatter. Research shows timezone handling is tricky.
   - **What's unclear:** Whether to store local time or UTC, and how to communicate this to users.
   - **Recommendation:** Store UTC internally, format as ISO 8601 with `Z` suffix. Let Obsidian or Phase 3 UI handle local-time display for users. This avoids daylight-saving-time edge cases.

## Environment Availability

> **Skip this section** — Phase 2 has no external dependencies beyond Swift 6 toolchain and Foundation (both required). No new tools, services, or runtimes.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | swift-testing (built into Swift 6+) |
| Config file | None — swift-testing uses macros, not config files |
| Quick run command | `swift test --filter <TestSuiteName>` |
| Full suite command | `swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WRITE-01 | Note written to correct path | unit | `swift test --filter NoteNormalizerTests` | ❌ Wave 0 |
| WRITE-02 | Frontmatter contains 12 fields | unit | `swift test --filter FrontmatterSchemaTests` | ✅ (Phase 1) |
| WRITE-03 | Audio wiki-link in body | unit | `swift test --filter NoteNormalizerTests` | ❌ Wave 0 |
| WRITE-04 | Atomic write protocol defined | integration | `swift test --filter NoteWriterTests` | ❌ Wave 0 |
| WRITE-05 | .icloud detection | unit | `swift test --filter NoteWriterTests` | ❌ Wave 0 |
| WRITE-06 | Clear error type surfaced | unit | `swift test --filter NoteWriterTests` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `swift test --filter <TestSuiteName>` (quick run for modified module)
- **Per wave merge:** `swift test` (full suite)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `Tests/UnibrainCoreTests/NormalizationTests/NoteNormalizerTests.swift` — covers WRITE-01, WRITE-03, N-01..04
- [ ] `Tests/UnibrainCoreTests/ClassificationTests/CourseClassifierTests.swift` — covers C-01..05
- [ ] `Tests/UnibrainCoreTests/ClassificationTests/FolderNameSanitizerTests.swift` — covers C-05
- [ ] `Tests/UnibrainCoreTests/WritingTests/NoteWriterTests.swift` — covers WRITE-04, WRITE-05, WRITE-06, A-01..05
- [ ] `Tests/UnibrainCoreTests/PipelineTests/PipelineOrchestratorTests.swift` — covers O-01..05
- [ ] Framework install: swift-testing is built into Swift 6 toolchain — no installation needed

*(If no gaps: "None — existing test infrastructure covers all phase requirements")*

## Security Domain

> **Required** — Phase 2 processes user input (folder names, event titles) and writes to filesystem. Input validation and path traversal protection are in scope.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | FolderNameSanitizer strips filesystem-reserved characters (`/`, `:`, leading dots) |
| V5 Input Validation | yes | NoteWriter validates destination path (no `.icloud` placeholders) |
| V6 Cryptography | no | No encryption in Phase 2 (deferred to Phase 6) |
| V2 Authentication | no | No auth in Phase 2 (single-user app) |
| V3 Session Management | no | No sessions in Phase 2 |
| V4 Access Control | no | No multi-tenancy in Phase 2 |

### Known Threat Patterns for Swift File I/O

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| **Path traversal** (malicious folder name like `../../etc/passwd`) | Tampering | FolderNameSanitizer strips `/` and `:`; FileManager operations are sandboxed on macOS/iOS |
| **iCloud sync conflict** (write to placeholder file) | Tampering | NoteWriter checks for `.icloud` in path and throws hard error (WRITE-05) |
| **Filename injection** (control chars in folder name) | Tampering | FolderNameSanitizer strips newlines and carriage returns |
| **Disk space exhaustion** (very large audio file) | Denial of Service | Check disk space before write (deferred to Phase 3) |
| **Permission denied** (read-only vault) | Tampering | NoteWriterError.permissionDenied surfaced clearly (WRITE-06) |

## Sources

### Primary (HIGH confidence)

- [Swift Concurrency - Task Cancellation](https://swiftwithmajid.com/2025/02/11/task-cancellation-in-swift-concurrency/) — Cooperative cancellation model, `Task.checkCancellation()`, `CancellationError`
- [CancellationError - Apple Developer Documentation](https://developer.apple.com/documentation/swift/cancellationerror) — Official CancellationError API reference
- [Swift Source Code - TaskCancellation.swift](https://github.com/swiftlang/swift/blob/main/stdlib/public/Concurrency/TaskCancellation.swift) — Internal implementation of cancellation shields
- [FileManager atomic write - StackOverflow](https://stackoverflow.com/questions/30385225/is-there-an-os-independent-way-to-atomically-overwrite-a-file) — POSIX `rename(2)` atomicity on Linux/macOS
- [Yams GitHub Repository](https://github.com/jpsim/Yams) — Codable YAML encoding, null handling, Date formatting
- [Swift Testing - Parameterized Tests (Apple)](https://developer.apple.com/documentation/testing/parameterizedtesting) — Official swift-testing parameterized test docs
- [macOS filesystem limits - Reddit](https://www.reddit.com/r/MacOS/comments/rvilz7/reserved_file_names/) — APFS/HFS+ filename length (255 UTF-8) and reserved characters (`/`, `:`, CR)

### Secondary (MEDIUM confidence)

- [Swift Testing - Parameterized Tests (SwiftWithMajid)](https://swiftwithmajid.com/2024/11/12/introducing-swift-testing-parameterized-tests/) — Practical parameterized test examples
- [Improving test coverage with parameterized tests (Donny Wals)](https://www.donnywals.com/improving-test-coverage-with-parameterized-tests-in-swift-testing/) — Reducing test boilerplate
- [Cooperative Task Cancellation (Peter Friese)](https://peterfriese.dev/blog/2021/swiftui-concurrency-essentials-part2/) — Best practices for `Task.checkCancellation()`
- [ISO8601 Date handling with Codable (Hacking with Swift)](https://www.hackingwithswift.com/example-code/language/how-to-use-iso-8601-dates-with-jsondecoder-and-codable) — Date encoding strategies (applies to YAML via Yams)
- [Swift Codable with custom dates (Use Your Loaf)](https://useyourloaf.com/blog/swift-codable-with-custom-dates/) — Date formatter configuration

### Tertiary (LOW confidence)

- [Swift Task Cancellation (Medium - Gaye Ugur)](https://gayeugur.medium.com/swift-task-cancellation-safely-stopping-asynchronous-code-06b0d5373462) — General cancellation patterns
- [Parameterized tests reducing boilerplate (Antoine van der Lee)](https://www.avanderlee.com/swift-testing/parameterized-tests-reducing-boilerplate-code/) — Test organization patterns

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - Swift 6, Foundation, Yams all verified via official docs and Phase 1 success
- Architecture: **HIGH** - Actor isolation and structured concurrency are Swift 6 language features
- Pitfalls: **HIGH** - Cancellation and atomic write patterns verified via multiple sources
- Testing: **HIGH** - swift-testing parameterized tests verified via Apple docs
- Filesystem limits: **MEDIUM** - macOS APFS/HFS+ limits confirmed via community sources (Apple docs less explicit)

**Research date:** 2026-07-14
**Valid until:** 30 days (Swift 6 concurrency patterns stable; Yams mature library)
