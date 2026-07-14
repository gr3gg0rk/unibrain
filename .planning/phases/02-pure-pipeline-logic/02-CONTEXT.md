# Phase 2: Pure Pipeline Logic - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Every line of business logic that can be expressed without Apple frameworks ships here, tested and green on WSL2 Linux: FrontmatterSchema validation/normalization, NoteNormalizer (transcript + metadata → Markdown), VaultWriter atomic-write logic, CourseClassifier pure matching, FolderNameSanitizer, and the PipelineOrchestrator state machine — all in `UnibrainCore`, all Linux-buildable, all tested via `UnibrainCoreTests`. No Apple frameworks. No UI. No real audio capture, real ASR, real EventKit, or real filesystem coordinator — those ship in Phases 3/4. Phase 2 produces the pure contracts and logic that platform implementations must satisfy.

</domain>

<decisions>
## Implementation Decisions

### NoteNormalizer Output Shape

- **N-01: Standard note shape.** Body = H1 title + inline audio wiki-link near the top + `## Transcript` section containing grouped paragraphs. The `## Summary` section is added in Phase 6 only when `summaryModel` is non-nil (not emitted as an empty placeholder in Phase 2 notes). Rationale: Obsidian-idiomatic — audio plays inside the note, transcript reads below, summary appears only when generated.
- **N-02: H1 title format = `YYYY-MM-DD — {course_code} Lecture`.** Example: `# 2026-09-15 — CS101 Lecture`. Filename mirrors H1: `YYYY-MM-DD-{course_code}-Lecture.md`. Date-first ensures sortability in Obsidian's file explorer; course_code is visible at a glance; "Lecture" suffix is explicit.
- **N-03: Segments-in contract.** NoteNormalizer takes `[(start: TimeInterval, end: TimeInterval, text: String)]` — an array of abstract timed segments — and groups them into paragraphs by time-gap heuristic. The segment type is Apple-framework-agnostic; Phase 3's ASR adapter maps whisper.cpp segments into this abstract shape. TRAN-05 paragraph post-processing logic lives in Phase 2 where it is Linux-testable.
- **N-04: Default paragraph-break threshold = 3 seconds.** Any silence ≥ 3s between segments starts a new paragraph. Tunable via a parameter with a sensible default — easy to adjust based on Angelica's real lecture cadence once Phase 3 ships.

### Atomic Write Abstraction

- **A-01: `NoteWriter` protocol in `UnibrainCore`; macOS conformance in `UnibrainProviders`.** Protocol-based abstraction mirroring D-15's provider pattern. Linux tests inject a `TestNoteWriter` (FileManager temp + POSIX `rename(2)`); Phase 3 ships `NSFileCoordinatorNoteWriter` in `UnibrainProviders` wrapping `NSFileCoordinator.coordinateWritingItem(at:options:error:byAccessor:)`. Orchestrator takes `any NoteWriter` as a dependency.
- **A-02: Protocol signature = `func write(_ note: NormalizedNote, to destination: URL) async throws`.** `NormalizedNote` is a `Sendable` value type produced by NoteNormalizer (carries H1 title, body Markdown string, and `FrontmatterSchema`). Writer serializes to bytes and performs the atomic write. Keeps the normalizer pure (no URL or filesystem concerns).
- **A-03: `.icloud` placeholder detection = hard error.** A destination whose path contains a `.icloud` suffix (iCloud Drive not-yet-downloaded placeholder, per WRITE-05) triggers `NoteWriterError.iCloudPlaceholder(URL)`. Never silently skip — Angelica would lose the recording. Orchestrator catches and surfaces a clear message ("Recording is still syncing from iCloud — wait for download and try again").
- **A-04: Dedicated `NoteWriterError` enum in `UnibrainCore`.** Cases: `.iCloudPlaceholder(URL)`, `.diskFull`, `.permissionDenied(URL)`, `.alreadyExists(URL)`, `.directoryCreationFailed(URL, underlying: any Error)`, `.underlying(any Error)`. Mirrors the ProviderError pattern (D-16) — structured cases prevent raw POSIX errors from leaking to the UI. Satisfies WRITE-06 ("clear error type surfaced, no silent swallow").
- **A-05: NoteWriter creates the `{vault}/{term}/{course_code}/` folder tree recursively before writing.** Idempotent via `FileManager.createDirectory(withIntermediateDirectories: true)`. Callers (Orchestrator, Phase 4 course-folder creation) don't need to pre-create anything.

### CourseClassifier Pure Matching

- **C-01: `CalendarEvent` struct in `UnibrainCore`.** `struct CalendarEvent: Sendable { let id: String; let title: String; let startDate: Date; let endDate: Date; let location: String? }`. Phase 4's EventKit adapter maps `EKEvent` → `CalendarEvent` at the boundary. Phase 2 tests build fake events directly. `id` enables stable identity across recurrences; `location` is optional (useful for room-conflict resolution, not always present).
- **C-02: Output enum = `enum CourseMatch { case single(CalendarEvent); case multiple([CalendarEvent]); case none }`.** Three states. `.single` = exactly one event overlaps (auto-route). `.multiple` = 2+ events overlap (Phase 4 shows manual picker). `.none` = zero events overlap (Phase 4 falls back to manual picker / recent courses). The matched event is returned raw so Phase 4 can read its title for folder-sanitization and apply the title→course-code mapping. Phase 2 does NOT resolve to course codes.
- **C-03: Time-overlap window = `recordingStart ± 30min`.** Match if event overlaps `[recordingStart - 30min, recordingEnd + 30min]`. Mirrors CLAS-01's ±30min buffer. Tolerates Angelica arriving 20min early or a lecture running late. Symmetric and tunable via a parameter. Phase 4's EventKit query uses the same window — consistent matching across the stack.
- **C-04: Title → course-code mapping table (CLAS-02) lives in Phase 4.** Phase 2 ships the pure time-overlap matcher only. The mapping table is a settings/UI concern (user-edited, persisted in Settings) — defer to Phase 4. Phase 2 returns the raw matched `CalendarEvent`; Phase 4 resolves it.
- **C-05: `FolderNameSanitizer.sanitize(folderName:)` ships in Phase 2.** Pure static function. Strips characters unsafe on macOS/iOS filesystems (`/`, `:`, leading dots), collapses whitespace, enforces max length 100 chars. Fully Linux-testable. Phase 4 calls it when auto-creating course folders for unrecognized event titles (CLAS-03).

### PipelineOrchestrator State Machine

- **O-01: 8-state lifecycle.** `enum PipelineState { case idle; case transcribing; case classifying; case normalizing; case writing; case completed; case failed(any Error); case cancelled }`. Each stage is a distinct state so Phase 3 UI can render "Transcribing…" vs "Writing note…" distinctly. `.failed` carries the error; `.cancelled` is a clean terminal state. Maps 1:1 to success criterion #5 (idle → transcribing → classifying → normalizing → writing → completed).
- **O-02: `actor PipelineOrchestrator` — Swift 6 actor isolates `state`.** Methods: `func run(inputs: PipelineInputs) async throws`, `func cancel() async`, `var currentState: PipelineState`. Concurrency-safety by language guarantee (matches `ModelLoadGate` pattern from Phase 1, D-11..14). Concurrent-run rejection (success criterion #5) is trivially enforced: the actor checks `state == .idle` at `run()` entry; otherwise throws `.alreadyRunning`.
- **O-03: Fail-fast failure model.** Any stage throwing → `state = .failed(error)` (terminal). The pipeline cannot resume mid-run; caller acknowledges the error (e.g., dismisses the error UI), which resets state to `.idle`, then explicitly retries via `run()` again. Matches success criterion #4 ("clear error type surfaced, no silent swallow"). Stage-local retry policy (e.g., cloud provider CLOUD-10 retry) is Phase 6's concern — Phase 2 ships fail-fast.
- **O-04: Cooperative cancellation via `Task.cancel()`.** `func cancel() async` sets `state = .cancelled` and cancels the internal `Task` carrying the active run. The run's current `await` point throws `CancellationError`; the orchestrator catches it and transitions cleanly to `.cancelled`. Phase 3 wires the menu-bar Stop button to `cancel()`. Users expect "Stop" to mean "halt now" — cooperative cancellation is the Swift 6 idiom; no unsafe thread-kill primitives.
- **O-05: `PipelineInputs` value type + injected dependencies.** `struct PipelineInputs: Sendable { let recordingURL: URL; let recordingStart: Date; let recordingEnd: Date; let durationSeconds: Int; let source: String; let events: [CalendarEvent] }` — passed to `orchestrator.run(inputs:)`. Dependencies (`any AudioTranscriber`, `any NoteWriter`, etc.) are injected at orchestrator init via its constructor. Clean separation: orchestrator owns the state machine, inputs are data, dependencies are protocols. Phase 3 builds a `PipelineInputs` from the capture session + fetched calendar events.

### Claude's Discretion

- FrontmatterSchema YAML encoding details (null field emission policy, datetime format, tags array shape) — Phase 1's existing `FrontmatterSchema` already uses Yams + snake_case CodingKeys; Phase 2 extends it with validation logic. Standard YAML conventions apply (ISO 8601 datetime, block-style tags, emit `key: null` for explicit nulls).
- Test framework for Phase 2 tests — Phase 1 established swift-testing (`@Test`, `#expect`); Phase 2 continues that pattern.
- `NormalizedNote` exact field shape — the struct carries H1 title, body Markdown, and `FrontmatterSchema`; the planner can refine the field list.
- `PipelineError` enum — a small enum (e.g., `.alreadyRunning`, `.invalidInputs`, `.cancelled`) for orchestrator-internal errors distinct from the `any Error` carried in `.failed`. Planner can fold into `NoteWriterError` or define separately.
- `CalendarEvent.id` generation strategy for fake events in tests — UUIDs are fine.
- `FolderNameSanitizer` exact character blacklist and length cap (100 suggested) — refine during planning if macOS filesystem limits demand different values.
- Where `PipelineInputs` construction lives in Phase 3 (Orchestrator builder, capture-session extension, etc.) — Phase 3's call.

### Folded Todos

None — no pending todos in the project state matched Phase 2 scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Planning (in this repo)
- `.planning/PROJECT.md` — project definition, constraints, key decisions table. The "Local-first by default, cloud by choice" framing and 8GB RAM discipline thesis shape every Phase 2 contract.
- `.planning/REQUIREMENTS.md` §"Vault Write-Out" — Phase 2 requirements: WRITE-01 (path), WRITE-02 (frontmatter fields), WRITE-03 (audio wiki-link), WRITE-04 (atomic via NSFileCoordinator), WRITE-05 (`.icloud` skip), WRITE-06 (clear error type). Also DISC-03 (Linux-runnable pure-logic tests) and DISC-06 (iCloud Drive sync conflict safety via atomic writes + schema_version).
- `.planning/ROADMAP.md` §"Phase 2: Pure Pipeline Logic" — phase goal, mode (mvp), dependencies (Phase 1), requirements, five success criteria.
- `.planning/STATE.md` §"Accumulated Context / Decisions" — Phase 1 decisions carried forward (D-07 module structure, D-08 test target split, D-10 Yams-only, D-16 ProviderError pattern, D-17 single-shot protocols).

### Phase 1 CONTEXT (decisions carried forward)
- `.planning/phases/01-foundation/01-CONTEXT.md` — D-07 (three SPM targets: `UnibrainCore` Foundation-only library, `UnibrainProviders` macOS/iOS-only, `UnibrainApp` Xcode app), D-08 (test target split: `UnibrainCoreTests` Linux-runnable, `UnibrainProvidersTests` macOS-only), D-10 (Phase 1 deps: Yams 6.2.2 in `UnibrainCore` only), D-15 (four standalone provider protocols), D-16 (`ProviderError` shared enum), D-17 (single-shot async/throws API). Every Phase 2 module conforms to these.

### Existing Code (the assets Phase 2 extends)
- `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift` — existing `Codable, Sendable` struct with all 12 WRITE-02 fields and snake_case CodingKeys. Phase 2 adds validation/normalization logic (e.g., a `validate()` method, default value injection).
- `Sources/UnibrainCore/Errors/ProviderError.swift` — Phase 1's shared error enum. The Phase 2 `NoteWriterError` (A-04) follows the same shape and pattern.
- `Sources/UnibrainCore/ModelLoadGate/ModelLoadGate.swift` — Phase 1's actor pattern (deny-on-conflict, acquire/release lease). The Phase 2 `PipelineOrchestrator` actor (O-02) follows the same Swift 6 actor-isolation idiom.
- `Sources/UnibrainCore/Protocols/{LLMSummarizer,AudioTranscriber,VisionDescriber,AudioSynthesizer}.swift` — Phase 1's four provider protocols. Phase 2's `NoteWriter` protocol (A-01) slots in alongside as a fifth pure-logic protocol in `UnibrainCore`.
- `Tests/UnibrainCoreTests/` — existing test files (`FrontmatterSchemaTests.swift`, `ModelLoadGateTests.swift`, `ProviderProtocolTests.swift`) establish the swift-testing pattern Phase 2 extends.
- `Package.swift` — target structure (`UnibrainCore` library, `UnibrainProviders` library, `UnibrainApp` app, `UnibrainCoreTests` + `UnibrainProvidersTests`). All Phase 2 sources go in `UnibrainCore`; tests in `UnibrainCoreTests`.

### External Documentation
No external specs, ADRs, or feature docs referenced during this discussion. Apple's `NSFileCoordinator` documentation is relevant for Phase 3's macOS conformance but not Phase 2's protocol definition.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `FrontmatterSchema` (in `Sources/UnibrainCore/Schemas/FrontmatterSchema.swift`) — already a `Codable, Sendable` struct with the full WRITE-02 field set and snake_case CodingKeys. Phase 2 wraps it in a `NormalizedNote` value type alongside the rendered body Markdown.
- `ProviderError` pattern (in `Sources/UnibrainCore/Errors/ProviderError.swift`) — the structured-enum-with-`.underlying(any Error)` shape is the template for Phase 2's `NoteWriterError`.
- `ModelLoadGate` actor (in `Sources/UnibrainCore/ModelLoadGate/`) — the Swift 6 `actor` with acquire/release lease pattern is the template for Phase 2's `PipelineOrchestrator` actor.
- Four provider protocols (in `Sources/UnibrainCore/Protocols/`) — the `associatedtype Request; associatedtype Response; func run(_:) async throws -> Response` shape. Phase 2's `NoteWriter` protocol is simpler (specific input/output types, no associatedtypes).
- Yams dependency — already wired in `Package.swift` for `UnibrainCore`. Phase 2's frontmatter serialization reuses it directly.

### Established Patterns
- Swift 6 strict concurrency (`actor`, `Sendable`, `async/await`, structured concurrency) — Phase 2 leans on this for `PipelineOrchestrator` and all value types crossing isolation boundaries.
- Protocol-abstraction layer — every Apple-framework-specific concern lives behind a protocol in `UnibrainCore`; macOS/iOS conformances ship in `UnibrainProviders`. Phase 2's `NoteWriter` and `CalendarEvent` follow this exactly.
- swift-testing framework — `@Test`, `#expect`, parameterized tests. All Phase 2 tests use this; XCTest is not used.
- Linux-runnable test target — `UnibrainCoreTests` builds and runs on WSL2 Linux via `swift test`; `UnibrainProvidersTests` is macOS-only behind `#if canImport(...)` guards.

### Integration Points
- `PipelineOrchestrator` is the central coordinator. Phase 3 wires the menu-bar record button + capture session to `orchestrator.run(inputs:)`. Phase 4 wires the EventKit adapter to produce `[CalendarEvent]` for `PipelineInputs.events`. Phase 6 wires the optional summarization step after the normalizer.
- `NoteWriter` protocol — Phase 3 ships `NSFileCoordinatorNoteWriter` conformance in `UnibrainProviders`; the Linux `TestNoteWriter` ships in Phase 2's test target.
- `CalendarEvent` struct — Phase 4 ships the `EKEvent` → `CalendarEvent` adapter in `UnibrainProviders`.
- `CourseClassifier.match(events:against:window:)` — Phase 4 calls this from the EventKit adapter; returns `CourseMatch` for the Orchestrator to act on.
- `FolderNameSanitizer.sanitize(folderName:)` — Phase 4 calls it when auto-creating course folders for `.none` matches (CLAS-03).
- `NormalizedNote` — produced by `NoteNormalizer.normalize(transcript:course:audioFile:)`, consumed by `NoteWriter.write(_:to:)`. Single producer, single consumer.

</code_context>

<specifics>
## Specific Ideas

- The segments-in contract (N-03) is the most consequential Phase 2 decision: it pushes TRAN-05 paragraph post-processing into Phase 2's Linux-testable surface. Phase 3's ASR adapter becomes a thin shape-mapper (whisper.cpp segment → abstract timed segment), not a logic carrier. This de-risks Phase 3 significantly — paragraph logic is exercised on Linux with synthetic segments before any real ASR output exists.
- The `CourseMatch` three-state enum (C-02) deliberately does NOT include `.ambiguous`. Ambiguity is expressed as `.multiple` — Phase 4's manual picker resolves it. Keeps Phase 2's contract minimal.
- The fail-fast model (O-03) means Phase 2 has no retry policy. This is intentional — Phase 6's cloud providers genuinely need retry (CLOUD-10), but adding retry in Phase 2 would be speculative (no real backends to exercise it).
- `PipelineInputs` carrying `[CalendarEvent]` (O-05) means the Orchestrator is **classification-input-ready** but does not call EventKit itself. Phase 4 fetches events and injects them. This keeps Phase 2 pure and Phase 4's EventKit code isolated to the adapter.
- The `NoteWriter` protocol returning `void` (just `async throws`) means success is implicit — no return value to inspect. If Phase 6 wants post-write metadata (e.g., bytes written, final URL), the protocol can be extended then.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. The following items were considered but explicitly belong in other phases:

- **Title → course-code mapping table (CLAS-02)** → Phase 4. Settings/UI concern. Phase 2 ships the pure time-overlap matcher only (C-04).
- **Real `NSFileCoordinator` conformance on macOS** → Phase 3. Phase 2 ships the `NoteWriter` protocol + `TestNoteWriter` for Linux (A-01).
- **Real `EKEvent` → `CalendarEvent` adapter** → Phase 4. Phase 2 ships the `CalendarEvent` struct + pure matcher.
- **Stage-local retry policy for cloud providers** → Phase 6 (CLOUD-10). Phase 2 ships fail-fast (O-03).
- **`## Summary` section emission** → Phase 6 (SUMM-05). Phase 2's normalizer does not emit the section when `summaryModel` is nil.
- **Whisper.cpp / SpeechAnalyzer / WhisperKit integration** → Phase 3 (TRAN-01). Phase 2's `NoteNormalizer` takes abstract timed segments, not whisper.cpp types.
- **Streaming ASR / streaming LLM token output** → v2 (per Phase 1 D-17). Phase 2 protocols are single-shot.
- **Manual course picker UI** → Phase 4 (CLAS-04). Phase 2's `CourseMatch.multiple` is the trigger; Phase 4 renders the picker.
- **`.awaitingUserChoice` pause state in Orchestrator** → Phase 4. Phase 2 ships fail-fast; the manual-picker UX is Phase 4's responsibility and can layer on top.
- **Confidence score in `CourseMatch`** → v2. Angelica doesn't need a confidence bar in MVP.

### Reviewed Todos (not folded)

None — no todos existed in the project state.

</deferred>

---

*Phase: 2-Pure Pipeline Logic*
*Context gathered: 2026-07-14*
