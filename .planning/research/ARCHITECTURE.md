# Architecture Research

**Domain:** Local-first Apple-native lecture capture + study assistant (SwiftUI, on-device ASR/LLM, Obsidian vault output)
**Researched:** 2026-07-13
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         APP LAYER (SwiftUI)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐      │
│  │  macOS App   │  │  iOS App     │  │  Settings / Pipeline │      │
│  │  (menu bar + │  │  (capture    │  │  Status UI           │      │
│  │   full UI)   │  │   only)      │  │                      │      │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘      │
│         │                 │                     │                    │
├─────────┴─────────────────┴─────────────────────┴──────────────────┤
│                    SHARED PIPELINE (SPM Package)                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ Capture  │→│ Transcribe│→│ Classify │→│ Normalize│→│  Write   │ │
│  │ Module   │ │ Module   │ │ Module   │ │ Module   │ │ Module   │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └────┬─────┘ │
│                                                           │       │
│  ┌──────────────────────────────────────────────────┐     │       │
│  │          Pipeline Orchestrator (actor)            │─────┘       │
│  │  Coordinates steps, manages RAM budget, retries   │             │
│  └──────────────────────────────────────────────────┘             │
├────────────────────────────────────────────────────────────────────┤
│                    PLATFORM SERVICES LAYER                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │AVFounda- │ │whisper.  │ │EventKit  │ │FileMana- │ │ Ollama   │ │
│  │tion      │ │cpp/Metal │ │(Calendar)│ │ger +     │ │(HTTP     │ │
│  │(record)  │ │(ASR)     │ │(course)  │ │iCloud    │ │localhost)│ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │
│  │ SwiftData    │  │ UserDefaults │  │ BackgroundTasks /     │     │
│  │ (session     │  │ (flags,      │  │ launchd (deferred     │     │
│  │  metadata)   │  │  config)     │  │  pipeline runs)       │     │
│  └──────────────┘  └──────────────┘  └──────────────────────┘     │
├────────────────────────────────────────────────────────────────────┤
│                        OUTPUT LAYER                                  │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  Obsidian Vault (iCloud Drive)                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │
│  │  │ Course A/   │  │ Course B/   │  │ _inbox/     │         │   │
│  │  │ lecture.md  │  │ lecture.md  │  │ pending.md  │         │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **CaptureEngine** | Record audio from built-in mic, handle start/stop, write WAV/m4a to temp dir | AVAudioRecorder (simple file capture) or AVAudioEngine (if live levels/monitoring needed) |
| **TranscriptionEngine** | Load whisper.cpp model, transcribe audio file to text, release RAM immediately | whisper.cpp via xcframework, Metal-accelerated; wrapped in a Swift actor |
| **CourseResolver** | Query Apple Calendar via EventKit for events matching recording timestamp; return course name + metadata | EKEventStore with `requestFullAccessToEvents()`, predicate-based date range search |
| **NoteNormalizer** | Transform transcript + course metadata into Markdown with YAML frontmatter | Pure Swift string templating; schema-versioned frontmatter |
| **VaultWriter** | Write final Markdown note to correct course folder in Obsidian vault | FileManager with `.atomic` writes, NSFileCoordinator for iCloud safety |
| **SummaryEngine** (gated) | Optionally call Ollama for key-point summary, append to note | HTTP POST to `localhost:11434/api/generate` via URLSession |
| **PipelineOrchestrator** | Sequence the above steps, enforce RAM discipline (one heavy model at a time), handle errors/retries | Swift actor with async/await; state machine for pipeline progress |
| **SessionStore** | Persist in-progress recording sessions, survive app backgrounding | SwiftData model for session metadata; UserDefaults for lightweight flags |

## Recommended Project Structure

### Xcode Workspace + SPM Package Layout

```
unibrain/
├── Package.swift                          # SPM manifest (shared library)
├── Sources/
│   ├── UnibrainCore/                      # Shared pipeline logic (all platforms)
│   │   ├── Pipeline/
│   │   │   ├── PipelineOrchestrator.swift # Actor: sequences steps, RAM discipline
│   │   │   ├── PipelineState.swift        # State machine: idle→capturing→transcribing→...
│   │   │   └── PipelineConfig.swift       # Model paths, vault path, RAM budget
│   │   ├── Capture/
│   │   │   ├── CaptureEngine.swift        # Protocol-based capture interface
│   │   │   ├── AudioRecorder.swift        # AVAudioRecorder implementation
│   │   │   └── CaptureSession.swift       # Value type: session metadata
│   │   ├── Transcription/
│   │   │   ├── TranscriptionEngine.swift  # Protocol: transcribe(URL) async throws -> String
│   │   │   └── WhisperEngine.swift        # whisper.cpp bridge (macOS only)
│   │   ├── Classification/
│   │   │   ├── CourseResolver.swift       # Protocol: resolve(timestamp) -> Course?
│   │   │   ├── EventKitResolver.swift     # EventKit implementation
│   │   │   └── Course.swift               # Value type: course code, name, folder
│   │   ├── Normalization/
│   │   │   ├── NoteNormalizer.swift       # Transcript + Course → Markdown string
│   │   │   ├── FrontmatterSchema.swift    # Versioned YAML frontmatter builder
│   │   │   └── NoteTemplate.swift         # Markdown body structure
│   │   ├── Vault/
│   │   │   ├── VaultWriter.swift          # Atomic write to vault folder
│   │   │   ├── VaultCoordinator.swift     # NSFileCoordinator wrapper
│   │   │   └── VaultPathResolver.swift    # Map course → folder path
│   │   ├── Summarization/
│   │   │   ├── SummaryEngine.swift        # Protocol: summarize(text) async -> String
│   │   │   └── OllamaEngine.swift         # HTTP client for localhost:11434
│   │   └── Models/
│   │       ├── CaptureSession.swift       # SwiftData @Model (session persistence)
│   │       ├── PipelineRun.swift          # SwiftData @Model (pipeline history)
│   │       └── AppSettings.swift          # Config value type
│   │
│   ├── UnibrainPlatform/                  # Platform-specific bridges
│   │   ├── Capture/
│   │   │   ├── iOSCaptureDelegate.swift   # #if os(iOS): AVAudioSession config
│   │   │   └── macOSCaptureDelegate.swift  # #if os(macOS): device selection
│   │   └── Whisper/
│   │       └── WhisperBridge.h            # C bridging header for whisper.cpp
│   │
│   └── whispercpp/                        # Vendored or submodule whisper.cpp
│       └── (built as xcframework)
│
├── Tests/
│   ├── UnibrainCoreTests/
│   │   ├── PipelineOrchestratorTests.swift
│   │   ├── NoteNormalizerTests.swift      # Pure logic: runs on any platform
│   │   ├── FrontmatterSchemaTests.swift   # Pure logic: frontmatter generation
│   │   ├── CourseResolverTests.swift      # Mock EventKit protocol
│   │   ├── VaultWriterTests.swift         # Temp-dir based file writes
│   │   └── Mocks/
│   │       ├── MockCaptureEngine.swift
│   │       ├── MockTranscriptionEngine.swift
│   │       ├── MockCourseResolver.swift
│   │       └── MockSummaryEngine.swift
│   └── UnibrainIntegrationTests/
│       └── PipelineEndToEndTests.swift    # Requires macOS runner
│
├── Apps/
│   ├── UnibrainMac/                       # macOS app target
│   │   ├── UnibrainMacApp.swift           # @main, menu bar + window
│   │   ├── MenuBarView.swift
│   │   ├── PipelineStatusView.swift
│   │   ├── ContentView.swift
│   │   └── Info.plist                     # NSMicrophoneUsageDescription, etc.
│   └── UnibrainiOS/                       # iOS app target
│       ├── UnibrainiOSApp.swift           # @main
│       ├── CaptureView.swift              # Record button, session list
│       ├── SessionListView.swift
│       └── Info.plist                     # NSMicrophoneUsageDescription, etc.
│
├── .github/workflows/
│   ├── ci.yml                             # Matrix: macos-14 + macos-15
│   └── ios-ci.yml                         # iOS simulator build + test
│
└── docs/
    └── frontmatter-schema.md              # Versioned schema documentation
```

### Structure Rationale

- **UnibrainCore (SPM library):** All pipeline logic lives here. Platform-agnostic at the protocol level. Every external dependency (AVFoundation, EventKit, whisper.cpp, Ollama) is abstracted behind a protocol, so the pipeline logic is fully testable with mocks on any Swift-supporting platform (including Linux CI for pure-logic tests).
- **UnibrainPlatform:** Platform-specific glue code separated by `#if os()` conditionals. This is where AVAudioRecorder configuration, EventKit access, and whisper.cpp bridging live.
- **Apps/UnibrainMac:** Thin SwiftUI shell. Menu bar presence for quick start/stop. Full window for pipeline status, settings, session history. This is where transcription actually runs (heavy compute stays on macOS).
- **Apps/UnibrainiOS:** Thin SwiftUI shell. Capture-only. Records audio, stores session metadata via SwiftData, drops audio file for macOS to pick up via iCloud Drive sync. Does NOT run whisper.cpp.
- **Tests/:** Split into pure-logic tests (run anywhere, including Linux Swift toolchain from WSL2) and integration tests (require macOS runner with microphone/calendar frameworks).

## Architectural Patterns

### Pattern 1: Protocol-Abstracted Pipeline Steps

**What:** Each pipeline step is a protocol with a single async method. The orchestrator depends on protocols, not concrete implementations. This makes the entire pipeline testable without a Mac.

**When to use:** Always for this project. The WSL2 dev constraint means we need maximum testability on non-Apple platforms.

**Trade-offs:** Slightly more boilerplate (protocol + mock + impl per step), but the payoff is enormous: pure-logic tests run on Linux, catching regressions before the macOS CI runner even sees the code.

**Example:**
```swift
// In UnibrainCore/Transcription/TranscriptionEngine.swift
public protocol TranscriptionEngine: Sendable {
    func transcribe(audioFileURL: URL) async throws -> String
}

// In UnibrainPlatform/Whisper/WhisperEngine.swift
#if os(macOS)
public final class WhisperEngine: TranscriptionEngine {
    public func transcribe(audioFileURL: URL) async throws -> String {
        // whisper.cpp Metal-accelerated transcription
        // Load model, transcribe, release RAM
    }
}
#endif

// In Tests/Mocks/MockTranscriptionEngine.swift
public final class MockTranscriptionEngine: TranscriptionEngine {
    public var stubbedResult: String = "Mock transcript"
    public func transcribe(audioFileURL: URL) async throws -> String {
        return stubbedResult
    }
}
```

### Pattern 2: Actor-Isolated Pipeline Orchestrator

**What:** A Swift `actor` owns the pipeline state machine and serializes pipeline runs. Only one heavy model (ASR or LLM) loaded at any time. The actor enforces the 8GB RAM discipline at the language level.

**When to use:** For the entire pipeline lifecycle. The actor is the single source of truth for "what's the pipeline doing right now?"

**Trade-offs:** Actor isolation means all pipeline state access is serialized. For this single-user app, that is exactly the constraint we want — no concurrent transcriptions fighting for 8GB.

**Example:**
```swift
// In UnibrainCore/Pipeline/PipelineOrchestrator.swift
public actor PipelineOrchestrator {
    private var state: PipelineState = .idle
    private let capture: any CaptureEngine
    private let transcriber: any TranscriptionEngine
    private let resolver: any CourseResolver
    private let normalizer: NoteNormalizer
    private let writer: VaultWriter
    private let summarizer: (any SummaryEngine)?

    public init(/* inject all protocols */) { ... }

    public func runPipeline(for session: CaptureSession) async throws {
        // State machine: only one pipeline runs at a time
        guard case .idle = state else { throw PipelineError.alreadyRunning }
        state = .transcribing(session)

        // Step 1: Transcribe (heavy — whisper.cpp model loaded here)
        let transcript = try await transcriber.transcribe(audioFileURL: session.fileURL)
        // Model released when transcriber goes out of scope or explicitly unloads

        // Step 2: Classify (light — EventKit query)
        state = .classifying(session)
        let course = try await resolver.resolve(for: session.startedAt)

        // Step 3: Normalize (pure — string building)
        state = .normalizing(session)
        let markdown = normalizer.normalize(transcript: transcript, course: course, session: session)

        // Step 4: Write (light — FileManager atomic write)
        state = .writing(session)
        try await writer.write(markdown, to: course)

        // Step 5: Summarize (heavy — Ollama model, gated)
        if let summarizer, config.summarizationEnabled {
            state = .summarizing(session)
            let summary = try await summarizer.summarize(transcript)
            try await writer.appendSummary(summary, to: course, session: session)
        }

        state = .completed(session)
    }
}
```

### Pattern 3: iCloud Drive File Drop (iPhone → MacBook)

**What:** iPhone captures audio to a shared iCloud Drive folder. MacBook monitors that folder (via `NSMetadataQuery` for iCloud sync status or a dispatch source on directory changes) and picks up new audio files for transcription. No direct device-to-device communication needed.

**When to use:** For the iPhone-to-MacBook handoff in MVP. Simpler than Multipeer Connectivity, more reliable than Handoff for large files.

**Trade-offs:** Depends on iCloud Drive sync timing (seconds to minutes). Not real-time, but for lecture capture (1-2 hour recordings), the sync latency is irrelevant — the MacBook processes when it next sees the file.

**Alternative considered:** Multipeer Connectivity (peer-to-peer, no iCloud dependency) — rejected for MVP because it requires both devices to be awake and in proximity, adds complexity, and iCloud Drive is already the vault sync mechanism.

**Example:**
```swift
// In UnibrainPlatform/iOSCaptureDelegate.swift
#if os(iOS)
// On iPhone: write recording to app's iCloud container
let icloudURL = FileManager.default.url(
    for: .documentDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
).appendingPathComponent("UnibrainInbox/\(session.id).m4a")
try audioData.write(to: icloudURL, options: .atomic)
#endif

// In UnibrainPlatform/macOSCaptureDelegate.swift
#if os(macOS)
// On MacBook: monitor iCloud Drive inbox folder for new files
let inboxURL = vaultURL.appendingPathComponent("_inbox/")
// Use DispatchSource to watch for new files, then enqueue pipeline run
#endif
```

### Pattern 4: Atomic Vault Writes with Schema Versioning

**What:** Every vault write uses `Data.write(to:options:.atomic)` (write-to-temp-then-rename) to prevent partial files. YAML frontmatter includes a `schema_version` field so future migrations can detect and upgrade old notes.

**When to use:** Every VaultWriter operation. Non-negotiable for iCloud Drive sync safety.

**Trade-offs:** Slightly more I/O (temp file + rename vs direct write), but prevents the corruption and conflict scenarios documented with iCloud Drive + frequent small writes.

**Example:**
```swift
// Frontmatter schema (versioned)
let frontmatter: String = """
---
schema_version: 1
course: \(course.code)
course_name: \(course.name)
datetime: \(session.startedAt.ISO8601Format())
duration_seconds: \(session.duration)
source: \(session.sourceDevice)  # "iphone" | "macbook"
audio_file: \(audioFilename)
tags: [lecture, \(course.code.lowercased())]
transcription_engine: whisper-cpp
transcription_model: \(config.whisperModel)
vector_id:        # Phase 2: populated by embeddings indexer
summary_engine:   # Only if summarization ran
---
"""

// Atomic write
let data = markdown.data(using: .utf8)!
try data.write(to: noteURL, options: .atomic)
```

## Data Flow

### Primary Pipeline (macBook recording)

```
[User clicks Record in menu bar]
    │
    ▼
[CaptureEngine] ──AVAudioRecorder──→ [temp_dir/session_id.m4a]
    │                                       │
    │ (user clicks Stop)                    │
    ▼                                       ▼
[PipelineOrchestrator] ──→ [TranscriptionEngine]
                              │ loads whisper.cpp model (Metal)
                              │ transcribes .m4a → text
                              │ releases model from RAM
                              ▼
                          [CourseResolver]
                              │ queries EventKit for events at timestamp
                              │ resolves: timestamp → {course code, name, calendar}
                              ▼
                          [NoteNormalizer]
                              │ builds Markdown + YAML frontmatter
                              ▼
                          [VaultWriter]
                              │ resolves folder: vault/COURSE_CODE/
                              │ atomic writes: lecture-YYYY-MM-DD-HHMM.md
                              ▼
                          [SummaryEngine] (gated, off by default)
                              │ HTTP POST to Ollama localhost:11434
                              │ appends summary section to note
                              ▼
                          [Pipeline complete]
                              │ updates SwiftData PipelineRun record
                              ▼
                          [State: .idle]
```

### iPhone Capture Flow (deferred transcription)

```
[iPhone: User taps Record]
    │
    ▼
[iOS CaptureEngine] ──AVAudioRecorder──→ [iCloud Drive/UnibrainInbox/session_id.m4a]
    │                                              │
    │ (user taps Stop)                             │ iCloud sync (seconds to minutes)
    ▼                                              ▼
[iOS SessionStore] ──SwiftData──→ [macBook detects new file in _inbox/]
    (records session metadata)       │
                                    ▼
                              [macBook PipelineOrchestrator]
                                    │ same pipeline as above
                                    ▼
                              [Vault note written on MacBook]
```

### State Management

```
┌──────────────────────────────────────────────────┐
│                  State Locations                   │
├──────────────────┬────────────────────────────────┤
│ Location         │ What lives there                │
├──────────────────┼────────────────────────────────┤
│ In-memory        │ Current PipelineState (actor)   │
│ (actor)          │ Active transcription buffer     │
│                  │                                 │
│ UserDefaults     │ is_recording flag               │
│                  │ current_session_id              │
│                  │ pipeline config (vault path,    │
│                  │   model selection, gates)       │
│                  │                                 │
│ SwiftData        │ CaptureSession records          │
│ (SQLite)         │ PipelineRun history             │
│                  │ (survives app restart)          │
│                  │                                 │
│ Vault (files)    │ Final Markdown notes            │
│ (Obsidian)       │ (the actual deliverable)        │
│                  │                                 │
│ Temp dir         │ In-progress audio files         │
│ (filesystem)     │ (cleaned up after pipeline)     │
└──────────────────┴────────────────────────────────┘
```

### iOS Backgrounding Survival

When the iOS app is backgrounded mid-recording:

1. **AVAudioSession** configured with `.playAndRecord` category + `.mixWithOthers` — allows audio to continue in background (with proper `UIBackgroundModes` = `audio` in Info.plist).
2. **UserDefaults** stores `is_recording: true` + `current_session_id` synchronously on every state change.
3. **SwiftData** persists the `CaptureSession` model (start time, device, file URL) on recording start.
4. On app relaunch (after crash/force-quit), the app checks UserDefaults `is_recording` flag. If `true` and the audio file exists but session is marked incomplete, it offers to finalize or discard.
5. If iOS kills the app entirely, the audio file is already on disk (AVAudioRecorder writes continuously). The session record in SwiftData identifies it as orphaned for recovery.

### Key Data Flows

1. **Recording to Note (macOS direct):** `AVAudioRecorder → temp .m4a → whisper.cpp → transcript text → EventKit course lookup → Markdown + frontmatter → atomic write to vault/COURSE_CODE/`. Duration: real-time recording + ~0.1x realtime for transcription (Metal-accelerated small.en on M1/M2).

2. **Recording to Note (iPhone → MacBook):** `iPhone AVAudioRecorder → iCloud Drive inbox .m4a → MacBook folder watch → same pipeline as above`. Adds iCloud sync latency (minutes). MacBook must be awake/open to process.

3. **Summarization (gated):** After note is written, if `summarizationEnabled` in config, Ollama is called via `localhost:11434/api/generate`. Summary appended to same Markdown file via read-modify-atomic-write. RAM discipline: whisper.cpp model must be fully released before Ollama model loads.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 user (Angelica) | Current design — single-user, single-pipeline-at-a-time, no concurrency concerns |
| 2 users (Angelica + Isabella) | Separate vaults, separate app instances. No architecture change needed — each device runs independently. |
| 10+ users (hypothetical) | Would need a shared transcription queue, but this is explicitly out of scope |

**This app does not need to scale.** It is single-user, single-device-pair, local-first. The "scaling" concern here is data volume over a semester: ~100 lectures x 1-2 hours each = ~200 audio files + 200 Markdown notes. This is trivial for FileManager and iCloud Drive. The real scaling concern is **vault organization** — after 100+ notes, the folder structure and naming convention must keep notes findable.

### Scaling Priorities

1. **First concern: RAM pressure during transcription.** whisper.cpp `small.en` + Metal uses ~1GB during inference on an 8GB MacBook Air. Mitigation: model loaded only during active transcription, released immediately after. No concurrent summarization.
2. **Second concern: iCloud Drive sync conflicts.** If Angelica edits a note on iPad while MacBook is appending a summary. Mitigation: atomic writes, schema-versioned notes, `_inbox/` staging folder for new captures.

## Anti-Patterns

### Anti-Pattern 1: Real-Time Streaming Transcription in MVP

**What people do:** Try to transcribe audio in real-time as it's being recorded (streaming ASR).
**Why it's wrong:** Real-time streaming with whisper.cpp is complex (ring buffer management, partial result handling, higher CPU/RAM usage during the entire lecture). On an 8GB MacBook Air, running AVAudioRecorder + whisper.cpp simultaneously for 2 hours risks memory pressure. It is not needed for the MVP value proposition (recording lands in the right folder, transcribed and summarized).
**Do this instead:** Record to file first (AVAudioRecorder, cheap). Transcribe after recording stops (whisper.cpp batch mode, efficient). This is simpler, more reliable, and easier to test.

### Anti-Pattern 2: Running whisper.cpp on iPhone

**What people do:** Try to run whisper.cpp on the iPhone for on-device transcription of captured audio.
**Why it's wrong:** iPhone has thermal constraints, battery constraints, and less RAM than the MacBook Air. A 2-hour lecture transcription on iPhone would drain battery and potentially cause thermal throttling. The iPhone's job is capture; the MacBook's job is compute.
**Do this instead:** iPhone records and syncs via iCloud Drive. MacBook transcribes. This is a deliberate division of labor based on hardware capabilities.

### Anti-Pattern 3: Direct Vault Writes Without Atomic Semantics

**What people do:** Write Markdown files directly to the iCloud-synced vault folder using `String.write(toFile:)` without `.atomic`.
**Why it's wrong:** iCloud Drive sync can pick up a partially written file, leading to truncated notes or sync conflicts. The iCloud conflict resolution is last-writer-wins by default, which can silently drop content.
**Do this instead:** Always use `Data.write(to:options:.atomic)`. For read-modify-write (summary append), use `NSFileCoordinator` to coordinate with iCloud sync. This is critical for data integrity.

### Anti-Pattern 4: Coupling Pipeline Logic to Apple Frameworks

**What people do:** Import AVFoundation, EventKit, etc. directly in pipeline orchestration code.
**Why it's wrong:** Makes the pipeline logic untestable without Apple frameworks. Since development happens on WSL2 with no Mac, this means every logic change requires a full CI cycle to catch type errors.
**Do this instead:** Define protocols in `UnibrainCore`. Implement them in `UnibrainPlatform` with `#if os()` guards. Test pipeline logic with mocks in `UnibrainCoreTests` — these tests can run on Linux Swift toolchain for fast feedback during WSL2 development.

### Anti-Pattern 5: Blocking the Main Actor During Transcription

**What people do:** Call `whisper_full()` synchronously on the main thread, freezing the UI for minutes.
**Why it's wrong:** The menu bar UI becomes unresponsive. macOS may show a spinning beachball and offer to force-quit the app.
**Do this instead:** All transcription runs in a Swift `actor` off the main thread. UI subscribes to pipeline state changes via `@MainActor`-isolated observable state. The pipeline actor publishes state transitions that the SwiftUI view observes.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **whisper.cpp** | C library via xcframework, bridged through Swift actor | Build with `-DGGML_METAL=ON` for Metal acceleration. Model file (`ggml-small.en.bin`) bundled or user-selectable. Released from memory after each transcription. |
| **Ollama** | HTTP client to `localhost:11434/api/generate` | Must be installed and running separately on the MacBook. App detects availability (port check) and disables summarization gate if Ollama is not running. |
| **EventKit** | `EKEventStore` with `requestFullAccessToEvents()` | Requires `NSCalendarsFullAccessUsageDescription` in Info.plist. On macOS sandbox: `com.apple.security.personal-information.calendars` entitlement. Query events matching recording timestamp ±30 min. |
| **iCloud Drive** | FileManager + NSFileCoordinator | iPhone writes to iCloud Drive inbox folder. MacBook reads from same folder. No CloudKit needed — plain file sync. |
| **AVFoundation** | `AVAudioRecorder` for file-based capture | Requires `NSMicrophoneUsageDescription` in Info.plist. iOS: `UIBackgroundModes` includes `audio` for background recording. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| App UI ↔ PipelineOrchestrator | Async/await + observed state | UI calls `orchestrator.startPipeline(session)`. Pipeline publishes state transitions. UI is `@MainActor`, orchestrator is its own actor. |
| PipelineOrchestrator ↔ Step Engines | Protocol-based async calls | Each step is `any TranscriptionEngine`, `any CourseResolver`, etc. Orchestrator has no knowledge of concrete implementations. |
| iOS App ↔ macOS App | iCloud Drive file drop (indirect) | No direct communication. iPhone writes file + SwiftData metadata. MacBook watches folder. Decoupled by design. |
| UnibrainCore ↔ UnibrainPlatform | Swift protocols | Core defines protocols; Platform provides `#if os()` implementations. App target injects platform impls into core orchestrator. |
| VaultWriter ↔ Obsidian | Filesystem only | No Obsidian plugin API, no plugin dependency. Plain Markdown + YAML frontmatter. Obsidian reads files naturally. |

## Suggested Build Order

The build order is driven by hard dependencies. Each phase produces a testable vertical slice.

### Phase 1: Pure Logic (No Apple Frameworks Required)

**Goal:** Core pipeline logic testable on Linux Swift toolchain from WSL2.

Build these modules with full test coverage using mocks:
- `NoteNormalizer` + `FrontmatterSchema` — pure string building, no dependencies
- `CourseResolver` protocol + mock — no EventKit dependency yet
- `VaultWriter` logic (using temp-dir paths, not real vault) — tests file I/O patterns
- `PipelineOrchestrator` with all-mock dependencies — validates state machine
- `PipelineState` enum + transitions

**Why first:** Everything else depends on these types being correct. Can write and test this entire phase from WSL2 without a Mac. Establishes the protocol contracts that platform implementations must satisfy.

### Phase 2: macOS Capture + Transcribe (Vertical Slice)

**Goal:** Record on MacBook → transcribe → write to a single hardcoded folder.

- `AudioRecorder` (AVAudioRecorder) — macOS implementation
- `WhisperEngine` — whisper.cpp xcframework integration with Metal
- Wire real implementations into orchestrator
- Write to hardcoded vault path (no course resolution yet)
- Minimal macOS menu bar UI: Record / Stop / Status

**Why second:** This is the minimal end-to-end pipeline. Proves the whisper.cpp integration, the actor-based orchestration, and the vault write-out. Tests run on GitHub Actions macOS runner.

**Depends on:** Phase 1 (pipeline logic, normalizer, writer).

### Phase 3: Course Classification + Smart Routing

**Goal:** Recording auto-routes to correct course folder.

- `EventKitResolver` — EKEventStore integration
- `Course` model + folder mapping
- `VaultPathResolver` — map course to vault folder structure
- Replace hardcoded folder with dynamic routing

**Why third:** Classification is meaningless without a working pipeline to attach to. But once Phase 2 works, this is the feature that makes the app actually useful (the core value proposition).

**Depends on:** Phase 2 (pipeline must be working end-to-end first).

### Phase 4: iOS Capture + iCloud Handoff

**Goal:** iPhone records → MacBook transcribes.

- iOS app target (SwiftUI capture UI)
- SwiftData session persistence
- iCloud Drive write from iOS
- macOS folder watcher for inbox
- Background recording support

**Why fourth:** iPhone capture adds an entire second app target + cross-device coordination. Better to nail the macOS pipeline first, then add the iPhone as an alternate capture source.

**Depends on:** Phase 3 (macBook pipeline fully working, vault routing proven).

### Phase 5: Gated Summarization

**Goal:** Optional Ollama summary appended to note.

- `OllamaEngine` — HTTP client
- RAM discipline enforcement (ensure whisper model released before Ollama call)
- Settings UI for enabling/disabling
- Summary section template

**Why last (MVP):** Summarization is explicitly gated/optional. The core value (record → classify → write) does not depend on it. Ship the core loop first, layer summarization on top.

**Depends on:** Phase 3 (pipeline must produce notes before we can append summaries).

### Build Order Diagram

```
Phase 1: Pure Logic (WSL2-testable)
    │
    ▼
Phase 2: macOS Capture + Transcribe (CI on macOS runner)
    │
    ▼
Phase 3: Course Classification + Routing
    │                       │
    ▼                       ▼
Phase 4: iOS Capture    Phase 5: Gated Summary
(iCloud handoff)        (Ollama integration)
```

### CI/Test Topology

| Test Type | Where It Runs | What It Tests |
|-----------|--------------|---------------|
| `swift test` (Linux, WSL2 local) | Local dev machine | Pure-logic modules (Normalizer, FrontmatterSchema, PipelineOrchestrator with mocks, VaultWriter with temp dirs) |
| `swift test` (macOS-14 runner) | GitHub Actions | Same pure-logic tests + macOS-specific implementations |
| `swift test` (macOS-15 runner) | GitHub Actions | Same, ensuring forward compatibility |
| `xcodebuild test` (iOS simulator) | GitHub Actions | iOS app target compiles, basic UI tests |
| `xcodebuild build` (macOS) | GitHub Actions | macOS app target compiles + links whisper.cpp xcframework |

**WSL2 local dev loop:**
```bash
# From WSL2, can run pure-logic tests without a Mac:
swift test --filter UnibrainCoreTests

# Cannot build/test platform-specific code locally.
# Push to git → GitHub Actions macOS runner builds + tests.
```

**GitHub Actions CI matrix:**
```yaml
strategy:
  matrix:
    os: [macos-14, macos-15]
    xcode: ['16.0', '16.2']
```

## Sources

- [Apple Developer Documentation - AVAudioRecorder](https://developer.apple.com/documentation/avfaudio/avaudiorecorder) — HIGH confidence, official docs
- [Apple Developer Documentation - BackgroundTasks](https://developer.apple.com/documentation/backgroundtasks) — HIGH confidence, official docs
- [Apple Developer Documentation - EventKit / EKEventStore](https://developer.apple.com/documentation/eventkit/accessing-the-event-store) — HIGH confidence, official docs
- [Apple Developer Documentation - Swift Packages](https://developer.apple.com/documentation/xcode/swift-packages) — HIGH confidence, official docs
- [ggml-org/whisper.cpp (GitHub)](https://github.com/ggml-org/whisper.cpp) — HIGH confidence, official repo
- [Whisper.cpp CMake Guide for macOS & iOS Apps](https://prakashjoshipax.com/whispercpp-cmake-guide-for-macos-and-ios-apps/) — MEDIUM confidence, community guide
- [SwiftWhisper SPM Package](https://swiftpackageindex.com/exPHAT/SwiftWhisper) — MEDIUM confidence, community package
- [Building a 100% Local Meeting Transcription App for macOS](https://dev.to/thehwang/building-a-100-local-meeting-transcription-app-for-macos-with-whispercpp-and-screencapturekit-33m7) — MEDIUM confidence, practical tutorial
- [Ollama API Introduction](https://docs.ollama.com/api/introduction) — HIGH confidence, official docs
- [Ollama OpenAI Compatibility](https://ollama.com/blog/openai-compatibility) — HIGH confidence, official blog
- [Run LLMs Locally in Swift - James Rochabrun](https://jamesrochabrun.medium.com/run-llms-locally-in-swift-d42e8b22909a) — MEDIUM confidence, tutorial
- [Swift 6 Concurrency - Practical Guide](https://medium.com/@nasibali/swift-6-concurrency-from-async-await-to-strict-isolation-a-practical-guide-4e18b0192f3c) — MEDIUM confidence, community guide
- [SE-0461: Async Function Isolation](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md) — HIGH confidence, Swift Evolution proposal
- [Problematic Swift Concurrency Patterns - Matt Massicotte](https://www.massicotte.org/problematic-patterns/) — MEDIUM-HIGH confidence, expert blog
- [Platform specific code in Swift Packages - Pol Piella](https://www.polpiella.dev/platform-specific-code-in-swift-packages) — MEDIUM confidence, community blog
- [Conditional Compilation - Apple Developer](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version) — HIGH confidence, official docs
- [Building and Testing Swift - GitHub Docs](https://docs.github.com/actions/guides/building-and-testing-swift) — HIGH confidence, official docs
- [In-Depth Guide to iCloud Documents - fatbobman](https://fatbobman.com/en/posts/in-depth-guide-to-icloud-documents/) — MEDIUM confidence, community blog
- [Beware UserDefaults - Christian Selig](https://christianselig.com/2024/10/beware-userdefaults/) — MEDIUM-HIGH confidence, cautionary deep-dive
- [Atomic File Sync - Stack Overflow](https://stackoverflow.com/questions/20966747/icloud-shoebox-apps-how-to-atomically-sync-a-file-package) — MEDIUM confidence, community Q&A
- [Logseq iCloud Data Loss](https://discuss.logseq.com/t/im-using-logseq-with-icloud-but-experiencing-data-loss-or-file-conflicts/13393) — MEDIUM confidence, real-world case study

---
*Architecture research for: Local-first Apple-native lecture capture + study assistant*
*Researched: 2026-07-13*
