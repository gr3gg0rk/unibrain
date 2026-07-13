# Pitfalls Research

**Domain:** Local-first Apple-native lecture capture + study assistant (SwiftUI, whisper.cpp/Metal, EventKit, AVFoundation, Obsidian vault write-out, GitHub Actions macOS CI)
**Researched:** 2026-07-13
**Confidence:** MEDIUM (HIGH for licensing/GH Actions/Swift-on-Linux; MEDIUM for performance/runtime claims based on community benchmarks rather than in-house testing)

## Critical Pitfalls

### Pitfall 1: whisper.cpp `whisper_full()` blocks the MainActor, freezing the UI

**What goes wrong:**
`whisper_full()` is a synchronous, long-running C function call. A developer wraps it in a plain `Task { }` thinking Swift concurrency moves it off the main thread. It does not. The UI freezes for the entire duration of transcription (1.5-3 minutes for a 1-hour lecture with `small.en`), the app appears hung, and macOS may show a spinning beachball. If the system sends a memory warning during this time and the app cannot respond (because the main thread is blocked), the jetsam killer may terminate the app.

**Why it happens:**
Swift's structured concurrency (`Task { }`) inherits the current actor context. If called from a `@MainActor`-annotated view or view model, the `Task` body runs on the main actor. A synchronous C call like `whisper_full()` has no suspension points, so it monopolizes the thread for its entire duration. Many tutorials and even the official whisper.swiftui example get this wrong.

**How to avoid:**
1. Use `Task.detached { }` (not `Task { }`) to explicitly escape the main actor when calling `whisper_full()`.
2. Alternatively, bridge with GCD: `DispatchQueue.global(qos: .userInitiated).async` wrapping the C call, then `withCheckedContinuation` to return to async/await.
3. Consider using [SwiftWhisper](https://swiftpackageindex.com/exPHAT/SwiftWhisper) (exPHAT/SwiftWhisper) which provides a Swift-friendly wrapper that handles threading correctly.
4. Ensure only one `whisper_context` is active per thread (thread-safe as long as no concurrent access to the same context, per [whisper.cpp issue #341](https://github.com/ggml-org/whisper.cpp/issues/341)).

**Warning signs:**
- UI beachball/spinning wheel during transcription
- Swift Concurrency warnings about "task or actor-isolated code running on the main thread"
- App killed by jetsam during transcription on 8GB devices
- Xcode Time Profiler showing `whisper_full` on MainThread

**Phase to address:**
Phase 1 (Audio Capture + Transcription). This is a Day-1 architecture decision in the transcription service layer. Get the threading model right before building any UI on top of it.

---

### Pitfall 2: whisper.cpp + Ollama simultaneously exhausts 8GB unified memory

**What goes wrong:**
On Angelica's 8GB MacBook Air, running whisper.cpp inference (~1-3GB for `small.en`) at the same time as an Ollama model load (~3-5GB even for a small 3-4B quantized model) exceeds available memory. macOS begins aggressive swapping. Metal/MPS "gives up" on keeping the model resident in memory, causing performance yo-yoing — the model gets evicted to swap, then reloaded, then evicted again. In the worst case, the jetsam killer terminates the process. The user sees a transcription that takes 30 minutes instead of 3, or the app crashes mid-lecture.

**Why it happens:**
macOS unified memory is shared between CPU and GPU. The OS itself needs ~2-3GB. whisper.cpp's Metal context allocates GPU memory. Ollama allocates GPU memory for its model. On 8GB, there is physically not enough room for both simultaneously, plus the OS, plus the recording pipeline. macOS does swap, but Metal-accelerated workloads perform catastrophically when swapped because GPU memory access cannot tolerate disk-latency page faults.

**How to avoid:**
1. Enforce a strict "one heavy model at a time" policy at the application level using a semaphore or actor-based gate. The transcription service and the summarization service share a `ModelLoadGate` actor that only allows one to hold the lock.
2. Never auto-trigger summarization (Ollama) while transcription (whisper.cpp) is running. Summarization is a post-transcription step.
3. Fully tear down the whisper context (`whisper_free`) before loading the Ollama model. Verify memory release with `memory_pressure` or `vm_stat`.
4. Use the smallest viable Ollama model (Llama 3.2 1B Q4 or Qwen 0.5B) — not a 7B model.
5. Monitor `os_proc_available_memory()` and log memory pressure state transitions.
6. Make Ollama summarization opt-in (gated behind a user toggle), as the PROJECT.md already specifies.

**Warning signs:**
- `memory_pressure` tool showing "Warn" or "Critical" during transcription
- Activity Monitor showing swap usage climbing above 2GB
- Transcription taking 5x+ longer than expected benchmarks
- Console.app showing jetsam reports for the app
- Ollama log: "giving up" messages or model load failures

**Phase to address:**
Phase 1 (Transcription) must implement the `ModelLoadGate` actor. Phase 2 (Summarization) must integrate with it. The gate is a cross-cutting concern that must exist before either service is functional.

---

### Pitfall 3: EventKit permission silently degrades to Write-Only (Add-Only) access

**What goes wrong:**
The app requests calendar access. The system grants only "Add-Only" (Write-Only) access by default on iOS 17+. The app thinks it has permission and tries to read events to classify recordings by course schedule. `EKEventStore.events()` returns an empty array. No error is thrown — it just returns nothing. The app fails to classify any recording to a course, which is the core value proposition.

**Why it happens:**
iOS 17 introduced a tiered calendar permission model: None, Write-Only (Add-Only), and Full Access. The deprecated `requestAccess(to:completion:)` API fails at runtime on iOS 17+. The new `requestFullAccessToEvents()` API prompts the user, but the system may default to Write-Only. To get Full Access, the user must manually navigate to Settings > Privacy & Security > Calendars > [App] and switch the toggle. Many users (especially non-technical users like a student) will never do this.

**How to avoid:**
1. Use the iOS 17+ API: `eventStore.requestFullAccessToEvents()` (not the deprecated `requestAccess(to:completion:)`).
2. After requesting permission, check the actual access level: `EKEventStore.authorizationStatus(for: .event)` must return `.fullAccess`, not `.writeOnly`.
3. If only Write-Only access is granted, show a clear in-app UI explaining: "unibrain needs Full Access to read your class schedule and auto-file recordings. Tap here to enable." Deep-link to `UIApplication.openSettingsURLString`.
4. Add a fallback manual course-selection UI for when Full Access is denied — never let classification silently fail.
5. Subscribe to `EKEventStoreChanged` notification to detect when the user changes permission settings while the app is running.
6. Handle the iOS 18 bug where calendar events disappear after OS update — re-fetch events and show a re-prompt if events are unexpectedly empty.

**Warning signs:**
- `authorizationStatus` returns `.writeOnly` instead of `.fullAccess`
- `events(matching:)` returns empty arrays despite the user having calendar events
- Course classification always falls back to "Uncategorized"
- No `EKEventStoreChanged` notifications received after schedule changes
- CI tests using deprecated EventKit API pass but fail on real devices

**Phase to address:**
Phase 1 (Course Classification). The permission flow and access-level verification must be part of the classification service from the start. The fallback manual selection UI is also Phase 1 because classification failure breaks the core value loop.

---

### Pitfall 4: iOS background audio recording gets silently killed mid-lecture

**What goes wrong:**
Angelica starts recording a lecture on her iPhone, then locks the screen or switches to another app (e.g., to take notes). The recording continues in the background via Background Modes. Ten minutes later, iOS silently terminates the app due to memory pressure, audio session interruption from another app (phone call, Siri), or system resource management. The recording is truncated or lost. No error is surfaced to the user until she opens the app later and discovers the recording stopped at minute 10.

**Why it happens:**
iOS aggressively kills background apps, especially under memory pressure. Background audio recording requires specific configuration (Background Modes capability, `AVAudioSession.Category.playAndRecord` with appropriate options). Even when configured correctly, iOS may kill the app if another audio app interrupts (phone call, Siri, another recording app, alarm). iOS 13.2+ significantly increased background app killing aggressiveness. On devices with limited RAM, the jetsam killer prioritizes terminating background apps consuming significant memory.

**How to avoid:**
1. Enable the `Audio, AirPlay, and Picture in Picture` Background Mode in the app's capabilities.
2. Configure the audio session category as `.playAndRecord` with options (`.defaultToSpeaker`, `.allowBluetoothA2DP`) before starting recording.
3. Observe `AVAudioSession.interruptionNotification` and `AVAudioSession.silenceSecondaryAudioHintNotification` to handle interruptions gracefully (pause/resume recording).
4. Observe `UIApplication.willResignActiveNotification` and `UIApplication.didEnterBackgroundNotification` to save recording state.
5. Write audio to disk incrementally (not just in memory) so that if the app is killed, the partial recording is recoverable. Use `AVAudioFile` with periodic flush, or write chunks to temporary files and concatenate.
6. On the MacBook Air (macOS), background recording is far less constrained — prefer Mac as the primary recording device and treat iPhone recording as secondary/experimental.
7. Implement a recovery flow: on app launch, check for orphaned temporary audio files from a killed recording session and offer to process them.
8. Use the `startRecording()` method to begin a background task via `UIApplication.beginBackgroundTask(withName:)` to get a grace period.

**Warning signs:**
- Audio files shorter than expected after a recording session
- Console.app or Xcode device logs showing jetsam reports
- `AVAudioSession.interruptionNotification` fired during recording
- App relaunched (not resumed) when user returns
- Missing audio data at the end of a long recording

**Phase to address:**
Phase 1 (Audio Capture). The incremental-write-to-disk pattern and interruption handling must be architected from the start — retrofitting crash recovery onto a recording pipeline that buffers in memory is a rewrite.

---

### Pitfall 5: iCloud Drive `.icloud` placeholder files break vault reads and writes

**What goes wrong:**
The app writes a Markdown note to the Obsidian vault in iCloud Drive. Later, the app (or Obsidian, or a Hermes Phase-2 job) tries to read the file, but iCloud has evicted it to cloud-only storage and replaced it with a `.icloud` placeholder file. The read fails or returns garbage. Alternatively, the app writes to a file that iCloud is currently syncing from another device, creating a sync conflict — iCloud duplicates the file with a conflict suffix, and now there are two versions of the lecture note with different content.

**Why it happens:**
iCloud Drive uses "optimistic storage" — it evicts rarely-accessed files to cloud storage, replacing them with `.icloud` placeholder stubs. This happens automatically based on disk space pressure. When two devices write to the same file (e.g., the app on MacBook writes a note while Obsidian on iPhone has the same vault open), iCloud creates conflict files instead of merging. iCloud's file watcher (`fs.watch`/`DispatchSource`) does not always fire for files synced from other devices, so the app may not detect updates.

**How to avoid:**
1. Before reading any vault file, check for the existence of a `.icloud` placeholder with the same name. If found, trigger a download using `NSFileManager.startDownloadingUbiquitousItem(at:)`.
2. Mark the vault folder as "Keep Downloaded" (pin it locally) — instruct Angelica to do this during setup. Programmatically, use `URLResourceKey.ubiquitousItemDownloadingStatusKey` to check/set download status.
3. Use atomic writes: write to a temporary file, then rename to the final path. This reduces the window for sync conflicts.
4. Never write to the same file from two processes simultaneously. If Obsidian is open, queue writes. Use file coordination (`NSFileCoordinator`) for all vault file operations.
5. Implement conflict detection: after writing, check for sibling files with conflict suffixes (e.g., `note 2.md`, `note (conflicted copy).md`).
6. For Phase 2+ Hermes jobs: never write to Angelica's vault directly. Hermes observes a read-only sync copy and writes to a separate ingestion queue.
7. Design frontmatter schema with merge-friendliness in mind: use YAML (line-oriented, somewhat mergeable) rather than JSON.

**Warning signs:**
- File reads returning empty data or `nil` for files that should exist
- `.icloud` files appearing in the vault directory listing
- Duplicate/conflicted files appearing in the vault (e.g., `Lecture 3 (1).md`)
- Obsidian showing stale content after the app wrote a note
- `fs.watch` / `DispatchSource` filesystem events not firing for iCloud-synced changes
- `NSFileCoordinator` callbacks timing out

**Phase to address:**
Phase 1 (Obsidian Write-Out). File coordination and `.icloud` handling must be part of the vault-write service from the first commit. Phase 2 (Hermes integration) must enforce the read-only boundary.

---

### Pitfall 6: Writing Swift blind from WSL2 — Apple frameworks don't exist on Linux

**What goes wrong:**
The developer writes Swift code on WSL2 Linux. The code compiles fine with the Linux Swift toolchain because non-UI logic uses only Foundation. But the moment any code imports `AVFoundation`, `EventKit`, `UIKit`, `AppKit`, or `Speech`, the Linux compiler fails with "no such module." The developer cannot run unit tests for any Apple-framework-dependent code locally. CI catches errors, but the feedback loop is slow (macOS runner queue + build time). More subtly, the developer writes code that uses Apple framework APIs incorrectly because they can't test interactively, and the first time the code actually runs is on Angelica's MacBook or in CI.

**Why it happens:**
Apple's proprietary frameworks (AVFoundation, EventKit, UIKit, AppKit, Vision, Speech) are closed-source and depend on the Objective-C runtime, which is unavailable on Linux. The open-source Swift toolchain from swift.org only includes Foundation, Dispatch, XCTest, and Swift Testing. There is no way to compile or run EventKit code on Linux. Period.

**How to avoid:**
1. Architect the codebase as a layered cake: a platform-agnostic core library (course classification logic, frontmatter generation, Markdown formatting, schedule matching algorithms) that depends only on Foundation, and a thin Apple-platform shell (UI, AVFoundation recording, EventKit access, whisper.cpp bridging) that wraps the core.
2. Use `#if canImport(EventKit)` / `#if canImport(AVFoundation)` guards for all platform-specific code. Prefer `canImport` over `#if os(macOS)`.
3. Define protocols (interfaces) for platform-specific capabilities (e.g., `protocol AudioRecorder`, `protocol ScheduleProvider`, `protocol TranscriptionService`). Implement them concretely in Apple-framework-dependent code; test against mocks in the platform-agnostic core.
4. Run `swift test` on WSL2 for all core logic tests. These tests must pass on Linux.
5. Run `swift test` on GitHub Actions macOS runner for integration tests that exercise the real Apple frameworks.
6. Use [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) (works on Linux without Xcode) for formatting.
7. Use [SwiftLint](https://github.com/realm/SwiftLint) via its SwiftPM command plugin (the cleanest Linux path; standalone installation is awkward).
8. Use [Swift Testing](https://developer.apple.com/xcode/swift-testing/) (cross-platform, works on Linux) rather than XCTest for new test code.
9. Run the compiler inside a Linux Docker container for a cross-platform sanity check before pushing.
10. Accept that UI code cannot be tested from WSL2 — budget CI time for UI/integration tests on macOS runners.

**Warning signs:**
- `swift test` on WSL2 fails with "no such module" for Apple frameworks
- Core logic mixed into UI/view-model files (cannot be extracted for Linux testing)
- CI builds fail repeatedly with API misuse errors that would have been caught by interactive testing
- Developer spending excessive time pushing "fix" commits to test if code compiles on macOS CI

**Phase to address:**
Phase 0 (Project Foundation / Architecture). The layered architecture and protocol boundaries must be established before any feature code is written. This is the single most important structural decision for this project's dev workflow.

---

### Pitfall 7: GitHub Actions macOS runner free-tier minute burn-through

**What goes wrong:**
The developer sets up a GitHub Actions workflow that builds and tests the Swift project on every push. Each build takes 8-12 minutes on a macOS runner. The free tier provides 2,000 included minutes/month, but macOS runners carry a 10x multiplier — effectively only ~200 macOS minutes/month. After 17-25 builds, the free tier is exhausted. Subsequent builds are billed at $0.062/minute, or CI simply stops running. The developer stops getting CI feedback and starts shipping unverified code.

**Why it happens:**
macOS runners are expensive to operate (Apple hardware, macOS licensing). GitHub passes this cost through with a 10x multiplier on free-tier minute consumption. A single iOS build with SPM resolution, compilation, and test execution can easily consume 10+ minutes. With aggressive iteration (10+ pushes per day), the free tier evaporates within 2-3 days.

**How to avoid:**
1. Cache SPM dependencies: cache `SourcePackages/` directory keyed on `Package.resolved` hash. Saves 3-5 minutes per build.
2. Cache DerivedData: cache `~/Library/Developer/Xcode/DerivedData/` for incremental builds. Beware 10GB cache limit per repo.
3. Do not run CI on every push to every branch. Trigger on PRs to main and scheduled nightly builds only.
4. Split CI into a fast "compile check" job (no tests, just `swift build`) and a slower "full test" job (only on PRs).
5. Run Linux-testable core logic tests on free Linux runners (no multiplier) — only run macOS runner for Apple-framework integration tests.
6. Consider a self-hosted runner if any Mac ever enters the lab (self-hosted runners are free until March 2026, then $0.002/min for private repos — vastly cheaper than hosted macOS).
7. Monitor minute consumption in GitHub billing dashboard. Set up spending alerts.
8. Use `paths:` filters to skip CI when only documentation or non-Swift files change.

**Warning signs:**
- GitHub Actions billing dashboard showing minute consumption approaching 200 (macOS-adjusted)
- CI jobs queued and not starting (free tier exhausted)
- Unexpected billing charges
- Builds taking longer than expected due to full SPM resolution each time

**Phase to address:**
Phase 0 (CI Setup). The caching strategy and trigger rules must be configured before the first real feature push. Revisit monthly during active development.

---

### Pitfall 8: Free Apple Developer account cannot use TestFlight or collect crash logs

**What goes wrong:**
The developer (Greg) plans to distribute builds to Angelica via TestFlight for testing on her MacBook Air. He discovers that a free Apple Developer account (Personal Team) cannot use TestFlight at all. He falls back to Xcode sideloading, which requires physical access to Angelica's Mac, signing with a Personal Team profile that expires every 7 days. When the app crashes on Angelica's device, there is no remote crash log collection — Xcode Organizer crash reports require a paid ($99/year) membership. Greg has to walk Angelica through manually exporting crash logs from Settings > Privacy & Security > Analytics Data, which is a poor experience for a non-developer family member.

**Why it happens:**
Apple gates TestFlight, remote crash reporting, and extended-signing behind the paid Apple Developer Program ($99/year). Free accounts get 3 devices, 7-day provisioning profiles, local-only crash logs, and no App Store submission. This is Apple's business model, not a bug.

**How to avoid:**
1. Budget $99/year for an Apple Developer Program membership. It is the single highest-ROI spend for this project. It unlocks TestFlight (100 devices, 1-year profiles, remote crash collection).
2. With a paid account: distribute via TestFlight. Angelica installs builds via the TestFlight app, updates are push-notified, and crash logs flow back to Xcode Organizer automatically.
3. Without a paid account (not recommended): create a device-local crash logger in-app. On uncaught exception or signal handler, write a crash report file to the app's Documents directory. Provide a "Share Crash Log" button that Angelica can tap to email/AirDrop the log to Greg.
4. Implement in-app telemetry (local-only, privacy-preserving): log key lifecycle events (recording started/stopped, transcription started/completed, memory pressure events, file write results) to a local log file that Angelica can share.
5. Manage version skew: display the app version and git commit hash in the Settings view so Angelica can report "I'm on version X" and Greg knows which build she has.

**Warning signs:**
- Angelica reporting a crash with no crash log available
- Provisioning profile expired (app won't launch, "Untrusted Developer" or similar)
- Version confusion: Angelica reports a bug, Greg can't reproduce because she's on an older build
- Physical Mac access required for every build update

**Phase to address:**
Phase 0 (Developer Setup). The Apple Developer membership decision and distribution strategy must be settled before the first device build. In-app crash logging (if going free-tier route) is Phase 1.

---

### Pitfall 9: whisper.cpp Metal build failures in Swift Package Manager

**What goes wrong:**
The developer integrates whisper.cpp as a Swift Package (either via SwiftWhisper or directly). The package includes `.metal` shader files for GPU acceleration. The SPM build fails because SPM does not support bridging headers and has limited Metal shader support. Alternatively, the build succeeds on the macOS runner but fails when targeting iOS because of architecture differences or missing Metal framework linking. Or the model file (`ggml-small.en.bin`) is corrupted during download or git-lfs checkout, causing `whisper_init_from_file_with_params` to fail silently with a null context.

**Why it happens:**
SPM was not originally designed for Metal shaders or C/C++ interop. While recent Swift versions improved this, edge cases remain. whisper.cpp's Metal backend requires `.metal` files to be compiled and embedded correctly. Model files (~240MB for `small.en`) can be corrupted by incomplete downloads, git-lfs issues, or filesystem encoding problems with paths containing spaces or Unicode.

**How to avoid:**
1. Use [SwiftWhisper](https://swiftpackageindex.com/exPHAT/SwiftWhisper) as the integration layer — it handles SPM/Metal bridging and is actively maintained.
2. If integrating whisper.cpp directly, use the official SPM support from the whisper.cpp repo (it has a `Package.swift`).
3. Do NOT commit model files to git. Download them at build time or first-launch via a download manager. Verify the SHA256 checksum after download.
4. Store model files in the app's Application Support directory, not in the vault or temp directory.
5. Test the Metal path explicitly: add a CI test that loads the model and runs a 1-second inference. This catches model corruption and Metal linking issues.
6. Handle model loading failure gracefully: show an error UI, offer to re-download the model.

**Warning signs:**
- SPM build errors mentioning `.metal` files or "bridging header"
- `whisper_init_from_file_with_params` returning nil/null context
- Transcription producing empty output or garbage text
- CI build succeeding on macOS but failing on iOS target
- Model file size mismatch (expected ~240MB for small.en, actual different)

**Phase to address:**
Phase 1 (Transcription). The model download/verification pipeline must be built alongside the transcription service.

---

### Pitfall 10: Obsidian frontmatter schema drift across semesters

**What goes wrong:**
Phase 1 defines a frontmatter schema (`course`, `datetime`, `source`, `tags`, `syllabus_link`, `vector_id`). By Phase 2, new fields are needed (`embedding_status`, `quiz_generated`, `review_count`). By the second semester, the schema has evolved but notes from the first semester still have the old schema. Obsidian has no built-in schema enforcement, so frontmatter is inconsistent across the vault. Dataview queries break. The Hermes daily-ingest QA job (Phase 2+) fails because it can't parse notes with missing or differently-named fields.

**Why it happens:**
Obsidian stores frontmatter as YAML in Markdown files — there is no database, no migration system, no schema validator. Every note is a standalone file. When the schema evolves, existing notes are not automatically updated. Unlike a database with `ALTER TABLE`, there is no migration path. Developers used to database-backed apps forget this.

**How to avoid:**
1. Include a `schema_version` field in frontmatter from Day 1 (e.g., `schema_version: 1`).
2. Build a vault migration tool (Swift script or in-app maintenance task) that reads all notes, checks `schema_version`, and applies transformations to bring them to the current version. Run this on app launch (background) or on-demand.
3. Keep frontmatter additive — never remove fields, only add new ones. Old fields remain as inert metadata.
3. Use a descriptive migration approach: define the target-state frontmatter for each note type, and a function that transforms any version's frontmatter to the current target. This is more robust than imperative field-by-field patching.
4. Document the frontmatter schema in a `SCHEMA.md` file in the vault root (non-Markdown-processed by Obsidian).
5. Test migrations against a fixture vault (copy of real notes) before running on Angelica's actual vault.
6. For Phase 2 Hermes jobs: always read frontmatter defensively — check for field existence and type before using values.

**Warning signs:**
- Dataview queries in Obsidian returning errors or missing notes
- Notes with missing fields that should be present
- Hermes ingestion jobs failing to parse frontmatter
- Inconsistent field names across notes (e.g., `course` vs `course_name` vs `class`)

**Phase to address:**
Phase 1 (Obsidian Write-Out) must include `schema_version: 1` in all notes. Phase 2 (Vault Migration Tool) must ship before any schema changes. Any phase that adds frontmatter fields must also ship a migration.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Buffer entire recording in RAM before writing to disk | Simpler code, no file I/O during recording | Lost recording if app is killed; huge memory footprint on long lectures | Never for lecture-length audio |
| Skip `#if canImport` guards, put everything in one target | Faster initial development | Cannot run any tests on WSL2; every code change requires macOS CI to verify | Never — must architect for cross-platform from day 1 |
| Commit model files to git repo | No download step at first launch | Repo bloats by hundreds of MB; git operations slow; LFS costs | Never — download at runtime with checksum verification |
| Skip CI caching to get started faster | First CI setup is simpler | Burns through free-tier macOS minutes in days | Only for first 1-2 builds; add caching immediately after |
| Use deprecated `requestAccess(to:)` EventKit API | Works on older iOS versions | Fails at runtime on iOS 17+; silent permission degradation | Never — target iOS 17+ and use new APIs |
| Write notes to vault without `NSFileCoordinator` | Simpler file I/O code | iCloud sync conflicts, data corruption, race conditions with Obsidian | Never for iCloud-synced vaults |
| Run whisper.cpp and Ollama without a memory gate | Simpler service orchestration | Swap death, jetsam kills, 8GB device unusable | Never on 8GB devices |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| whisper.cpp + Metal | Calling `whisper_full()` on the main actor | Use `Task.detached` or GCD global queue; ensure single context per thread |
| whisper.cpp model files | Committing to git or skipping checksum verification | Download at runtime, verify SHA256, store in Application Support |
| EventKit | Creating multiple `EKEventStore` instances | Reuse a single instance; stale data from new instances |
| EventKit permissions | Assuming `.authorized` means full read access | Check specifically for `.fullAccess` on iOS 17+, not `.writeOnly` |
| AVFoundation recording | Setting audio session category after starting recording | Configure `.playAndRecord` category and activate session BEFORE starting `AVAudioRecorder` |
| iCloud Drive vault | Reading files without checking for `.icloud` placeholders | Check `URLResourceKey.ubiquitousItemDownloadingStatusKey`; trigger download if needed |
| iCloud Drive vault | Writing without `NSFileCoordinator` | Always use `NSFileCoordinator.coordinate(writingItemAt:)` for vault writes |
| Obsidian frontmatter | Using JSON instead of YAML | YAML is line-oriented and more merge-friendly; Obsidian Properties expects YAML |
| GitHub Actions macOS CI | Running full build+test on every push | Split into fast compile-check (all pushes) and full test (PRs only); cache SPM + DerivedData |
| Swift on WSL2 | Testing Apple-framework code locally | Impossible — use protocol abstractions; test core logic on Linux, integration on macOS CI |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Running ASR + LLM simultaneously on 8GB | Swap death, 10x slowdown, jetsam kills | Strict one-model-at-a-time gate actor | Always on 8GB; tolerable on 16GB+ |
| Loading large whisper model (medium/large) on 8GB | Memory exhaustion, OOM kill | Use `small.en` only (~240MB, ~1GB at runtime) | medium.en needs ~2.5GB, large needs ~5GB — too much for 8GB |
| Not releasing whisper context after transcription | Persistent 1GB+ memory hold | Call `whisper_free()` / `whisper_free_context()` immediately after use; verify with memory profiler | After 2-3 transcriptions without release |
| Synchronous file writes on main thread during vault write-out | UI freeze when saving notes | Use async file I/O on background queue; use `NSFileCoordinator` async methods | Noticeable on files > 100KB or slow disk |
| EventKit fetch with broad date range | Slow queries, excessive results | Fetch only the window around the recording timestamp (+/- 2 hours) | Breaks with multi-year calendar history |
| Full DerivedData cache in CI | Exhausts 10GB repo cache limit | Cache only `SourcePackages/` and selective DerivedData subdirectories | After 3-4 SPM dependency changes |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing transcription text unencrypted on disk | Lecture content exposed if device is lost/stolen | Use macOS FileVault (system-level); for app-level, use `Data Protection` class `.complete` on iOS |
| Logging audio file paths or transcription content in crash logs | PII leakage in crash reports sent to Apple/developer | Redact all content in logging; log only metadata (durations, error codes) |
| Shipping model files without license attribution | MIT license violation (unlikely to be enforced but still non-compliant) | Include `LICENSE` and `ATTRIBUTIONS.md` in the app bundle |
| Granting the app broader filesystem access than needed | Privacy violation; App Store rejection (if ever submitted) | Use app-scoped containers (Application Support, Documents); never request full disk access |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Silent course classification failure (no Full Access) | All recordings land in "Uncategorized" — defeats the core value | Show clear permission explanation UI with deep-link to Settings; offer manual course selection fallback |
| Recording killed in background with no notification | User thinks they recorded the whole lecture; discovers truncation later | Send a local notification when recording is interrupted or the app is background-killed; show a recovery prompt on next launch |
| Long transcription with no progress indicator | User thinks the app is frozen; force-quits it | Show a progress bar or percentage (whisper.cpp provides segment callbacks for progress estimation) |
| Model download on first launch with no progress | User sees a blank screen or spinner for 5+ minutes | Show download progress, file size, and estimated time; offer WiFi-only download option |
| Frontmatter visible in Obsidian editor without Properties panel | User accidentally edits YAML, breaks schema | Instruct user to enable Obsidian Properties (v1.4+) which provides structured frontmatter editing |
| iCloud sync conflict files confuse user | User sees duplicate notes with "conflicted copy" suffix and doesn't know which to keep | Implement conflict detection and a merge UI in-app; document in the setup guide |

## "Looks Done But Isn't" Checklist

- [ ] **Recording:** App records audio and saves a file — but does it survive being backgrounded? Verify: start recording, lock phone, wait 10 minutes, unlock, confirm recording continued.
- [ ] **Transcription:** whisper.cpp produces text — but is it on a background thread? Verify: open Xcode Time Profiler during transcription, confirm `whisper_full` is NOT on MainThread.
- [ ] **Classification:** Schedule-to-course mapping works — but only with Full Access? Verify: check `authorizationStatus` returns `.fullAccess`, not `.writeOnly`. Test with a fresh calendar entry.
- [ ] **Vault write:** Note appears in Obsidian — but does it survive iCloud sync? Verify: write note on Mac, open Obsidian on iPhone, confirm note appears without conflict files.
- [ ] **Memory discipline:** Only one model loaded at a time — but is the gate actually enforced? Verify: trigger transcription, then immediately trigger summarization, confirm one blocks the other.
- [ ] **CI:** Build passes on macOS runner — but is it cached? Verify: check build time for first run vs. second run with cache; confirm SPM cache hit in logs.
- [ ] **Cross-platform tests:** Core logic tests pass on WSL2 — but do they cover all business logic? Verify: `swift test --enable-code-coverage` on Linux; confirm >80% of core module.
- [ ] **Model integrity:** Model file loads — but is it the right model? Verify: checksum the model file against the known SHA256 from HuggingFace.
- [ ] **Permission re-request:** User denies calendar access, later grants it in Settings — does the app detect it? Verify: deny, background app, grant in Settings, return to app, confirm `EKEventStoreChanged` fires.
- [ ] **Offline operation:** Everything works offline — for real? Verify: disable WiFi, record, transcribe, write to vault, confirm no network calls are required.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Main-thread blocking during transcription | LOW | Wrap `whisper_full` in `Task.detached`; rerun |
| 8GB OOM during simultaneous model load | MEDIUM | Implement `ModelLoadGate` actor; ensure `whisper_free` before Ollama load; test memory pressure |
| EventKit Write-Only access granted instead of Full | LOW | Add permission-level check + Settings deep-link UI; re-request via new API |
| Background recording killed mid-lecture | HIGH | Cannot recover lost audio; implement incremental-to-disk writing to minimize future loss; add recovery prompt for partial files |
| iCloud `.icloud` placeholder blocking reads | MEDIUM | Implement `startDownloadingUbiquitousItem` + retry logic; pin vault folder as "Keep Downloaded" |
| CI free-tier exhaustion | LOW | Add caching; reduce trigger frequency; split fast/slow jobs; consider self-hosted runner |
| Model file corruption | LOW | Re-download with checksum verification; add integrity check on app launch |
| Frontmatter schema drift across vault | MEDIUM | Build vault migration tool; run on app launch; test against fixture vault first |
| Swift code untestable from WSL2 (mixed concerns) | HIGH | Refactor to extract core logic behind protocols; significant restructuring cost |
| TestFlight unavailable (free account) | LOW | Pay $99/year for Apple Developer Program; alternative: in-app crash logger + manual sharing |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Main-thread blocking (whisper_full) | Phase 1: Transcription | Xcode Time Profiler shows `whisper_full` off MainThread |
| 8GB OOM (ASR + LLM simultaneously) | Phase 1: Transcription (gate actor) | `memory_pressure` stays in "Normal" during sequential ASR→LLM |
| EventKit Write-Only degradation | Phase 1: Classification | `authorizationStatus == .fullAccess` verified in test + manual Settings flow |
| iOS background recording kill | Phase 1: Audio Capture | 30-minute background recording survives on iPhone with locked screen |
| iCloud `.icloud` placeholder/conflict | Phase 1: Vault Write-Out | Write note on Mac, read on iPhone, no conflicts; `.icloud` files handled |
| Swift blind from WSL2 (untestable code) | Phase 0: Architecture | `swift test` on WSL2 passes for >80% of core module; CI runs integration tests |
| GitHub Actions minute burn | Phase 0: CI Setup | CI build time <5 min with cache; <200 macOS minutes/month consumption |
| Free account TestFlight limitation | Phase 0: Developer Setup | Paid Apple Developer membership active; OR in-app crash logger shipped |
| whisper.cpp Metal SPM build failure | Phase 1: Transcription | CI builds for both macOS and iOS targets; model checksum verified |
| Frontmatter schema drift | Phase 1: Vault Write-Out (schema_version) | `schema_version: 1` in all notes; migration tool tested against fixture vault |

## Sources

- [whisper.swiftui example issue #1720](https://github.com/ggml-org/whisper.cpp/issues/1720) — SwiftUI integration runtime failures
- [SwiftWhisper (Swift Package Index)](https://swiftpackageindex.com/exPHAT/SwiftWhisper) — Pure-Swift whisper.cpp wrapper
- [whisper.cpp thread safety issue #341](https://github.com/ggml-org/whisper.cpp/issues/341) — Single context thread safety
- [whisper.cpp Metal discussion #1767](https://github.com/ggml-org/whisper.cpp/discussions/1767) — Model size issues on 8GB M2 Air
- [whisper.cpp benchmark (getspeakup.app)](https://getspeakup.app/blog/whisper-cpp-benchmark-mac/) — M1-M4 benchmarks with Metal vs CPU
- [OpenWhispr model sizes](https://openwhispr.com/blog/whisper-model-sizes-explained) — 8GB M1 Air benchmarks
- [whisper.cpp vs faster-whisper 2026](https://www.promptquorum.com/power-local-llm/local-whisper-stt-comparison-2026) — ~10x real-time on large-v3, faster on small.en
- [ollama/ollama#4151](https://github.com/ollama/ollama/issues/4151) — Memory pressure yo-yoing on constrained systems
- [8GB Mac Local AI Survival Guide](https://localllmsetup.com/blog/8gb-mac-local-ai-survival-guide) — Swap death mitigation
- [ModelPiper: Ollama multi-model on Mac](https://modelpiper.com/blog/ollama-multi-model-mac) — 8GB fits one small model only
- [Apple EventKit Docs](https://developer.apple.com/documentation/eventkit/accessing-the-event-store) — requestFullAccessToEvents API
- [WWDC23 Session 10052](https://developer.apple.com/videos/play/wwdc2023/10052/) — Calendar access level changes
- [NC Software: Calendar permissions iOS 17+](https://www.nc-software.com/apdl-calendar-permissions-issue-ios-17) — Write-Only default pitfall
- [Expo #16807](https://github.com/expo/expo/issues/16807) — Background audio recording silent termination
- [Apple: Responding to low-memory warnings](https://developer.apple.com/documentation/xcode/responding-to-low-memory-warnings) — Official memory guidance
- [iOS 13.2 background killing roundup](https://mjtsai.com/blog/2019/10/30/ios-13-2-killing-background-apps-more/) — Aggressive jetsam history
- [Obsidian Forum: iCloud data loss](https://forum.obsidian.md/t/icloud-data-loss-issue-sync-conflict-handling/113584) — iCloud sync conflicts
- [Obsidian Forum: iCloud sync issues](https://forum.obsidian.md/t/icloud-sync-issues/28320) — Stalled sync
- [mnott/Obsidian-iCloud (GitHub)](https://github.com/mnott/Obsidian-iCloud) — `.icloud` placeholder tool
- [Carlo Zottmann: iCloud Drive sync deep dive](https://zottmann.org/2025/09/08/ios-icloud-drive-synchronization-deep.html) — Technical analysis
- [GitHub Actions billing docs](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions) — macOS runner pricing
- [nowham.dev: GitHub Actions iOS caching](https://nowham.dev/posts/github-actions-ios-caching/) — DerivedData/SPM caching guide
- [Swift Forums: canImport pattern](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version) — Conditional compilation
- [Fatbobman: Swift on Linux](https://fatbobman.com/en/posts/swift-in-linux/) — Full Linux dev setup
- [Swift Testing (Swift Package Index)](https://swiftpackageindex.com/swiftlang/swift-testing) — Cross-platform testing framework
- [Apple: Compare Developer Memberships](https://developer.apple.com/support/compare-memberships/) — Free vs paid account features
- [Apple: Acquiring crash reports](https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs) — Xcode Organizer crash logs
- [whisper.cpp (GitHub)](https://github.com/ggml-org/whisper.cpp) — MIT license, official repo
- [ggerganov/whisper.cpp (HuggingFace)](https://huggingface.co/ggerganov/whisper.cpp) — MIT-licensed GGML models

---
*Pitfalls research for: Local-first Apple-native lecture capture + study assistant*
*Researched: 2026-07-13*
