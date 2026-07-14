# Phase 2: Pure Pipeline Logic - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 2-Pure Pipeline Logic
**Areas discussed:** NoteNormalizer output shape, Atomic write abstraction, CourseClassifier contract, Orchestrator state machine

---

## NoteNormalizer Output Shape

### Q1: What should the normalized Markdown note look like in Obsidian?

| Option | Description | Selected |
|--------|-------------|----------|
| Standard: title + audio link + Transcript section | Title + body structure. Body has an embedded `![[audio.m4a]]` wiki-link near the top, then `## Transcript` with paragraphs. The `## Summary` section is added in Phase 6 (not emitted when summaryModel is nil). Obsidian-idiomatic — audio inline so it plays inside the note, transcript below for reading, summary section appears later only when generated. | ✓ |
| Minimal: frontmatter only, no inline audio link | Minimalist: no audio wiki-link in body (audio path is in frontmatter only, user drags audio in manually if they want playback in-note). Cleaner Markdown but loses the in-Obsidian audio playback affordance. | |
| Rich: metadata table + audio + transcript | Lecture-centric: `# {Course Name} — {Date}` as H1, then a metadata table (instructor, term, duration) before the audio link + transcript. More structured reading experience but heavier Markdown that may feel cluttered in Obsidian's preview. | |

**User's choice:** Standard: title + audio link + Transcript section
**Notes:** Captured as N-01.

### Q2: What's the H1 title format for each note?

| Option | Description | Selected |
|--------|-------------|----------|
| `YYYY-MM-DD — {course_code} Lecture` | e.g., `# 2026-09-15 — CS101 Lecture`. Sortable in Obsidian's file explorer (date-first), course code is right there, 'Lecture' suffix is explicit. Filename mirrors H1. | ✓ |
| `{course_code} — {course_name} — {date}` | e.g., `# CS101 — Intro to Computer Science — 2026-09-15`. Course-first, human-readable, but loses date-sortability in file explorer. | |
| `Lecture — {date}` (minimal) | e.g., `# Lecture — 2026-09-15`. Simplest. Course context lives only in frontmatter and folder path. | |

**User's choice:** `YYYY-MM-DD — {course_code} Lecture`
**Notes:** Captured as N-02. Filename also mirrors H1: `YYYY-MM-DD-{course_code}-Lecture.md`.

### Q3: How should the normalizer handle transcript paragraphs (TRAN-05)?

| Option | Description | Selected |
|--------|-------------|----------|
| Segments-in: normalizer groups by time gaps | Normalizer takes `[(start: TimeInterval, end: TimeInterval, text: String)]` — an array of timed segments — and groups them into paragraphs by time-gap heuristic (gap > N seconds = new paragraph). The segment type is abstract (no whisper.cpp dependency). Phase 3's ASR adapter just maps whisper.cpp segments into this shape. Puts TRAN-05 paragraph logic in Phase 2 where it's testable on Linux, and Phase 3 becomes a thin adapter. | ✓ |
| String-in: caller handles paragraphs | Normalizer takes plain `String` transcript text already split into paragraphs by the caller. Phase 3 owns the segment→paragraph post-processing (TRAN-05) and hands the result to the normalizer. Phase 2 normalizer is simpler but Phase 3 carries more logic that isn't Linux-tested. | |
| String-in: normalizer splits by blank lines / sentences | Normalizer takes plain `String` and does paragraph splitting by blank-line heuristic or sentence-boundary detection (no timestamps). Pure-text approach — loses time-gap accuracy but simpler contract. | |

**User's choice:** Segments-in: normalizer groups by time gaps
**Notes:** Captured as N-03. Most consequential Phase 2 decision — pushes TRAN-05 into Linux-testable surface.

### Q4: What's the default paragraph-break threshold?

| Option | Description | Selected |
|--------|-------------|----------|
| 3 seconds default, tunable | Any silence ≥ 3 seconds between segments starts a new paragraph. Lectures naturally have ~1-2s pauses between sentences; 3s catches topic shifts without fragmenting. Tunable via a parameter with a sensible default. | ✓ |
| 1.5 seconds (fine-grained) | Stricter: 1.5s gap starts a new paragraph. More paragraphs, closer to sentence-by-sentence segmentation. Risk of over-fragmenting. | |
| 5 seconds (coarse) | Looser: 5s gap. Fewer, longer paragraphs. Better for lectures with long continuous explanations; may merge distinct topics. | |
| Hardcode 3s, no parameter | Skip the configurable parameter — hardcode 3s as a private constant. Simpler API surface. | |

**User's choice:** 3 seconds default, tunable
**Notes:** Captured as N-04.

---

## Atomic Write Abstraction

### Q1: How should VaultWriter abstract NSFileCoordinator for Linux testability?

| Option | Description | Selected |
|--------|-------------|----------|
| Protocol in UnibrainCore, macOS impl in UnibrainProviders | Define `protocol NoteWriter { func write(_ note: NormalizedNote, to vaultURL: URL) async throws }` in `UnibrainCore`. Linux tests inject a `TestNoteWriter` (FileManager temp + atomic rename via POSIX `rename(2)`). macOS ships `NSFileCoordinatorNoteWriter` in `UnibrainProviders` (Phase 3). Orchestrator takes `any NoteWriter` as a dependency — same protocol-injection pattern as the four provider protocols (D-15). | ✓ |
| Closure-based FileCoordinator protocol (mirror NSFileCoordinator) | Define `protocol FileCoordinator { func coordinateWrite<T>(url: URL, _ body: () throws -> T) rethrows -> T }` — a literal clone of NSFileCoordinator's closure-based API. Linux impl is a no-op pass-through; macOS impl wraps NSFileCoordinator. More faithful to Apple's API but heavier abstraction. | |
| No protocol — concrete struct with `#if os(macOS)` later | Skip the protocol entirely. Put `VaultWriter` as a concrete struct in `UnibrainCore` using FileManager + temp-file-and-rename. On macOS in Phase 3, swap internals via `#if os(macOS)`. Less abstraction but Phase 2 ships less code. | |

**User's choice:** Protocol in UnibrainCore, macOS impl in UnibrainProviders
**Notes:** Captured as A-01.

### Q2: What should the NoteWriter protocol signature look like?

| Option | Description | Selected |
|--------|-------------|----------|
| `write(NormalizedNote, to: URL)` | The normalizer produces a `NormalizedNote` value type (title, body, frontmatter) and hands it to the writer. Writer is responsible for serializing to bytes + atomic write. Keeps the normalizer pure. | ✓ |
| `write(String, to: URL)` (string-only) | Writer takes a fully-rendered Markdown string. Normalizer is responsible for serializing frontmatter + body to a single string; writer just persists bytes. Simpler protocol but pushes serialization to normalizer. | |
| `write(Data, to: URL)` (raw bytes) | Writer takes raw bytes. Caller fully responsible for encoding. Most flexible but loses type safety on the note shape. | |

**User's choice:** `write(NormalizedNote, to: URL)`
**Notes:** Captured as A-02.

### Q3: How should `.icloud` placeholder detection work (WRITE-05)?

| Option | Description | Selected |
|--------|-------------|----------|
| Hard error + surface to user | Treat `.icloud` extension as a hard error: `NoteWriterError.iCloudPlaceholder(url)`. The Orchestrator catches it and surfaces a clear message. Never silently skip a write — Angelica would lose the recording if we skipped. | ✓ |
| Both `.icloud` extension AND zero-byte detection | Detect `.icloud` suffix AND zero-byte files. Throw the same error for both. Slightly more defensive but adds a second heuristic that may false-positive on legitimately empty files. | |
| Check in Orchestrator, not in NoteWriter | Don't check at write time. The `.icloud` check belongs in the Orchestrator's pre-write validation step. NoteWriter is purely about bytes-to-disk atomicity. | |

**User's choice:** Hard error + surface to user
**Notes:** Captured as A-03.

### Q4: What error type should NoteWriter throw (WRITE-06)?

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated `NoteWriterError` enum | Define in `UnibrainCore` with structured cases: `.iCloudPlaceholder(URL)`, `.diskFull`, `.permissionDenied(URL)`, `.alreadyExists(URL)`, `.directoryCreationFailed(URL, underlying)`, `.underlying(any Error)`. Mirrors the ProviderError pattern (D-16). | ✓ |
| Reuse `ProviderError.underlying` | Reuse the existing `ProviderError` from Phase 1. Wrap write failures as `.underlying(errno)`. Single error type but shaped for inference calls (networkFailure, rateLimited), not filesystem failures. | |
| Broader `VaultError` enum (future-proof) | New `VaultError` covering BOTH NoteWriter failures AND future vault operations (folder creation, sanitization, scanning). Broader scope — ready for Phase 4. | |

**User's choice:** Dedicated `NoteWriterError` enum
**Notes:** Captured as A-04.

### Q5: Who creates the `{vault}/{term}/{course_code}/` folder tree on first write?

| Option | Description | Selected |
|--------|-------------|----------|
| Writer creates folders recursively | NoteWriter creates `{vault}/{term}/{course_code}/` recursively if missing, THEN writes the note. Single responsibility. Atomicity: directory creation is idempotent. | ✓ |
| Caller pre-creates folders | NoteWriter writes to the destination only; caller is responsible for ensuring the folder exists. If missing, throw `.directoryMissing`. Cleaner separation but every caller has to repeat the create-if-missing dance. | |
| Writer creates only course folder (split responsibility) | NoteWriter creates the immediate parent folder only (the course folder), but `{vault}` and `{term}` must already exist. Splits responsibility across phases. | |

**User's choice:** Writer creates folders recursively
**Notes:** Captured as A-05.

---

## CourseClassifier Contract

### Q1: What's the abstract 'event' input type for CourseClassifier?

| Option | Description | Selected |
|--------|-------------|----------|
| `CalendarEvent` struct in UnibrainCore | `struct CalendarEvent: Sendable { id, title, startDate, endDate, location? }`. Phase 4's EventKit adapter maps `EKEvent` → `CalendarEvent` at the boundary. Phase 2 tests build fake events directly. | ✓ |
| Minimal tuple (time + title only) | Tuple `(startDate: Date, endDate: Date, title: String)`. Minimal payload. Loses ID and location. | |
| `CalendarEvent` protocol (EKEvent conforms directly) | Protocol with associated requirements. Phase 4's `EKEvent` conforms directly. More swifty but protocols-with-requirements complicate test fixtures and array storage. | |

**User's choice:** `CalendarEvent` struct in UnibrainCore
**Notes:** Captured as C-01.

### Q2: What's the CourseClassifier output shape?

| Option | Description | Selected |
|--------|-------------|----------|
| `enum CourseMatch { single / multiple / none }` | Three states. `.single` = exactly one event overlaps. `.multiple` = 2+ events overlap. `.none` = zero events. Returns the raw matched event so Phase 4 can read its title for folder-sanitization / mapping. Phase 2 doesn't resolve to course codes. | ✓ |
| Resolved course codes + `.ambiguous` state | Returns resolved course CODES, not raw events. Phase 2 owns the title→course-code mapping table. Adds `.ambiguous` as a fourth state. | |
| Result struct with confidence score | Richer return with confidence score. Lets Phase 4 surface 'best guess + alternatives'. Overkill for MVP. | |

**User's choice:** `enum CourseMatch { single / multiple / none }`
**Notes:** Captured as C-02.

### Q3: What time-overlap window does the pure matcher use?

| Option | Description | Selected |
|--------|-------------|----------|
| `recordingStart ± 30min` buffer (mirror CLAS-01) | Match if event overlaps `[recordingStart - 30min, recordingEnd + 30min]`. Mirrors CLAS-01 exactly. Tolerates Angelica arriving 20min early or a lecture running late. Tunable. | ✓ |
| Strict time overlap, no buffer | Match if event's time range overlaps the recording's time range. Tighter but brittle: a 2-minute clock skew could miss the match. | |
| `± 30min` + overlap-duration tiebreaker | ±30min AND prefer the event with the most overlap. Adds a tiebreaker heuristic for back-to-back lectures. | |

**User's choice:** `recordingStart ± 30min` buffer
**Notes:** Captured as C-03.

### Q4: Where does the title → course-code mapping responsibility live?

| Option | Description | Selected |
|--------|-------------|----------|
| Phase 4 owns title→course mapping | Phase 2 ships the pure time-overlap matcher. Title → course-code mapping table (CLAS-02) lives in Phase 4 — that's a settings/UI concern. Phase 2 returns the raw matched `CalendarEvent`; Phase 4 looks up the course code. | ✓ |
| Phase 2 ships mapping value type + resolve function | Phase 2 ships BOTH the matcher AND a `CourseMapping` value type plus a `resolve(event:using:)` function. Phase 4 wires in the user-edited settings table. Slightly larger Phase 2 surface. | |
| Phase 2 ships full mapping table + protocol | Phase 2 owns the entire mapping: ships a `CourseMappingTable` protocol with a default in-memory implementation. Phase 4 persists it. Risks scope creep into persistence. | |

**User's choice:** Phase 4 owns title→course mapping
**Notes:** Captured as C-04.

### Q5: Does Phase 2 ship the folder-name sanitizer (for CLAS-03)?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, ship sanitizer in Phase 2 | Phase 2 ships `static func sanitize(folderName: String) -> String`. Strips unsafe chars (`/`, `:`, leading dots), collapses whitespace, enforces max length (e.g., 100 chars). Pure function, fully Linux-testable. Phase 4 calls it when creating course folders. | ✓ |
| Defer sanitizer to Phase 4 | Defer to Phase 4. Phase 2 only ships the matcher; folder creation happens in Phase 4 where it can decide sanitization rules in context. | |
| Sanitizer inside NoteWriter (write-time) | Sanitizer lives in `NoteWriter` since the writer creates folders recursively (A-05). Centralizes filesystem concerns but couples sanitization to write-time. | |

**User's choice:** Yes, ship sanitizer in Phase 2
**Notes:** Captured as C-05.

---

## Orchestrator State Machine

### Q1: What's the PipelineOrchestrator state set?

| Option | Description | Selected |
|--------|-------------|----------|
| 8-state lifecycle with error + cancelled | `enum PipelineState { idle; transcribing; classifying; normalizing; writing; completed; failed(any Error); cancelled }`. Each stage distinct so Phase 3 UI can render 'Transcribing…' vs 'Writing note…'. Maps 1:1 to success criterion #5. | ✓ |
| 4-state with nested `Stage` enum | `enum PipelineState { idle; running(stage: Stage); completed; failed(any Error) }`. Fewer top-level cases; `running` carries the current stage. More compact but UI has to unwrap. | |
| 4-state minimal (no stage in enum) | `enum PipelineState { idle; running; completed; failed }`. Minimal. No stage visibility from the state enum itself. | |

**User's choice:** 8-state lifecycle with error + cancelled
**Notes:** Captured as O-01.

### Q2: What concurrency model does PipelineOrchestrator use?

| Option | Description | Selected |
|--------|-------------|----------|
| `actor PipelineOrchestrator` | Swift 6 actor isolates the mutable `state` property. Concurrency-safety by language guarantee. Matches the `ModelLoadGate` actor pattern from Phase 1. Concurrent-run rejection trivially enforced. | ✓ |
| `class` + lock | `final class PipelineOrchestrator: @unchecked Sendable` with internal lock. More manual but allows non-async API. Adds lock discipline burden. | |
| `struct` with stateless `run()` (no rejection) | Stateless struct with `run(dependencies:) async throws -> PipelineResult`. No concurrent-run rejection — caller's responsibility. Simplest but loses guarantee that success criterion #5 demands. | |

**User's choice:** `actor PipelineOrchestrator`
**Notes:** Captured as O-02.

### Q3: What's the failure model when a stage throws?

| Option | Description | Selected |
|--------|-------------|----------|
| Fail-fast: any stage error terminates the run | Any stage throwing → `state = .failed(error)` (terminal). Caller acknowledges (dismiss error UI) which resets to `.idle`, then explicitly retries. Matches success criterion #4. Pipeline run is atomic. | ✓ |
| Stage-local retry policy (defer cloud retry to Phase 6) | Stage-local retry: transcribe fails → retry N times with backoff before escalating. Adds retry policy complexity in Phase 2. Phase 6 genuinely needs retry. | |
| Soft-fail with `.awaitingUserChoice` pause state | If classification returns `.none` or `.multiple`, don't fail — pause in `.awaitingUserChoice` for Phase 4 to resolve. Couples Phase 2 to Phase 4's UX. | |

**User's choice:** Fail-fast: any stage error terminates the run
**Notes:** Captured as O-03.

### Q4: Does the orchestrator support mid-run cancellation?

| Option | Description | Selected |
|--------|-------------|----------|
| Cooperative cancel via Task.cancel() | `func cancel() async` sets `state = .cancelled` and cancels the internal `Task`. The run's current `await` throws `CancellationError`; orchestrator catches and transitions to `.cancelled`. Phase 3 wires Stop button to `cancel()`. Swift 6 idiom. | ✓ |
| Defer cancellation to Phase 3 | No explicit cancel API in Phase 2. Cancellation is Phase 3's concern. Phase 2 ships run-to-completion-or-fail only. Less code but Phase 3 has to layer cancellation on top. | |
| Forceful kill (not viable in Swift) | Kill the run task without cooperation. Risky — Task.cancel() is cooperative by design; no safe 'kill thread' primitive. Mentioned for completeness. | |

**User's choice:** Cooperative cancel via Task.cancel()
**Notes:** Captured as O-04.

### Q5: How does the caller pass run-time inputs to the orchestrator?

| Option | Description | Selected |
|--------|-------------|----------|
| `PipelineInputs` value type + injected dependencies | `struct PipelineInputs: Sendable { recordingURL, recordingStart, recordingEnd, durationSeconds, source, events }` passed to `orchestrator.run(inputs:)`. Dependencies injected at orchestrator init. Clean separation: orchestrator owns state machine, inputs are data, dependencies are protocols. | ✓ |
| Builder pattern (`PipelineBuilder`) | Builder pattern produces an opaque `Pipeline` the orchestrator runs. More fluent API but adds a builder type for marginal benefit. | |
| Method chaining on orchestrator (confusing) | `orchestrator.withRecording(url).withEvents([…]).run()`. Mutates orchestrator state per-call. Confusing — the actor is supposed to be the state machine, not a config builder. | |

**User's choice:** `PipelineInputs` value type + injected dependencies
**Notes:** Captured as O-05.

---

## Claude's Discretion

- FrontmatterSchema YAML encoding details (null field emission, datetime format, tags array shape) — Phase 1's existing schema uses Yams + snake_case CodingKeys; standard YAML conventions apply.
- Test framework — Phase 1 established swift-testing; Phase 2 continues.
- `NormalizedNote` exact field shape — planner can refine.
- `PipelineError` enum for orchestrator-internal errors — planner can fold into `NoteWriterError` or define separately.
- `CalendarEvent.id` generation strategy for fake events — UUIDs are fine.
- `FolderNameSanitizer` exact character blacklist and length cap — refine during planning.
- Where `PipelineInputs` construction lives in Phase 3 — Phase 3's call.

## Deferred Ideas

- Title → course-code mapping table → Phase 4 (CLAS-02)
- Real NSFileCoordinator conformance → Phase 3
- Real EKEvent → CalendarEvent adapter → Phase 4
- Stage-local retry policy → Phase 6 (CLOUD-10)
- `## Summary` section emission → Phase 6 (SUMM-05)
- Whisper.cpp/SpeechAnalyzer/WhisperKit integration → Phase 3 (TRAN-01)
- Streaming ASR / streaming LLM token output → v2
- Manual course picker UI → Phase 4 (CLAS-04)
- `.awaitingUserChoice` pause state → Phase 4
- Confidence score in `CourseMatch` → v2
