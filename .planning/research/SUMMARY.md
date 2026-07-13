# Project Research Summary

**Project:** unibrain
**Domain:** Local-first Apple-native lecture capture + study assistant (SwiftUI multiplatform, single-user)
**Researched:** 2026-07-13
**Confidence:** HIGH

## Executive Summary

unibrain is a single-user, local-first, Apple-native lecture capture app that records lectures on MacBook Air and iPhone, transcribes them on-device via whisper.cpp/Metal, auto-classifies each recording to the correct course via Apple Calendar, and writes structured Markdown notes with YAML frontmatter into an Obsidian vault. The core value proposition is narrow and uncompromising: every recording lands in the right course folder, transcribed and optionally summarized, without the student ever manually organizing it. The first user is Angelica (university freshman, MacBook Air 8GB / iPhone / iPad Pro), with Isabella (master's program) as a secondary future user.

The recommended approach is a native SwiftUI multiplatform app (NOT Mac Catalyst) with Swift 6.0 strict concurrency, built and tested on GitHub Actions macOS runners (no Mac in the dev loop). The architecture separates pure-logic pipeline code (testable on WSL2/Linux) from Apple-framework shell code (testable only on macOS CI) via protocol abstractions. whisper.cpp with the `small.en` model (~852 MB runtime RAM) is the ASR engine; Ollama with `llama-3.2-3b` is the gated summarization engine. Critically, the 8GB unified memory budget makes simultaneous ASR + LLM operation impossible — a strict sequential gating actor is mandatory from Day 1. The competitive moat against Apple Notes iOS 26 (which ships free on Angelica's devices with native transcription + summary) is schedule-aware course classification via EventKit — no competitor does this.

The dominant risks cluster around the 8GB RAM constraint (jetsam kills if ASR and LLM coexist), the WSL2-without-a-Mac dev constraint (every Apple-framework code change requires a CI round-trip), and iCloud Drive file integrity (`.icloud` placeholders, sync conflicts). Mitigation for all three is architectural, not tactical: a `ModelLoadGate` actor enforces one-heavy-model-at-a-time; protocol-abstracted pipeline logic runs on Linux with mocks; atomic writes plus `NSFileCoordinator` protect vault integrity. Secondary risks — GitHub Actions macOS free-tier exhaustion (~20 builds/month on private repos; public repo gives unlimited), TestFlight unavailable without $99/yr Apple Developer membership — are budget decisions, not engineering problems.

## Key Findings

### Recommended Stack

The stack is conservative and Apple-native throughout: Swift 6.0+ / SwiftUI (iOS 17+ / macOS 14+) multiplatform target, AVFoundation for capture, whisper.cpp with Metal acceleration for ASR, Ollama HTTP API for gated summarization, EventKit for calendar-based course classification, FileManager + Yams for Obsidian vault write-out, GitHub Actions macos-15 runners for CI. The single non-Apple dependency of note is whisper.cpp (MIT-licensed C/C++), bridged via SwiftWhisper SPM package or the official whisper.cpp SPM support.

**Core technologies:**
- **Swift 6.0+ / SwiftUI multiplatform**: Primary language + UI framework — Swift 6 strict concurrency is essential for safe model load/unload gating on 8GB; native multiplatform (NOT Mac Catalyst) for clean per-platform container access
- **whisper.cpp v1.7.x+ (target v1.9.x) + Metal**: ASR engine — best accuracy/footprint tradeoff on 8GB; ~3x realtime with Metal; `small.en` model (~852 MB runtime RAM) is the sweet spot
- **Ollama HTTP API (localhost:11434)**: Gated summarization — clean separation of concerns; Angelica manages Ollama as a user app, unibrain is a thin HTTP client; `keep_alive: 0` unloads model immediately
- **EventKit (`requestFullAccessToEvents`)**: Course classification — the competitive moat; reads Apple Calendar to map recording timestamp to course
- **Yams 6.2.2**: YAML frontmatter serialization — standard Swift YAML library; every note write depends on it
- **GitHub Actions macos-15 runners**: Build/test path from WSL2 — no Mac in the dev loop; pin to macos-15 explicitly to avoid surprise migration

**Critical version requirements:**
- Swift 6.0 requires Xcode 16+ (only on macOS runners)
- EventKit `requestFullAccessToEvents` requires iOS 17+ / macOS 14+
- SwiftUI `@Observable` macro requires iOS 17+ / macOS 14+
- Pin GitHub Actions to `macos-15` explicitly (macos-latest migration risk)

### Expected Features

**Must have (table stakes):**
- One-tap start/stop recording (macOS + iOS) — primary action, friction here = abandonment
- Pause/resume recording — expected by every competitor
- Background recording (iOS) — lectures are 50-90 min, screen cannot stay on
- Recording timer + live mic level indicator — visual confirmation of capture
- Automatic transcription (whisper.cpp, post-capture) — THE core feature
- Readable transcript (paragraph breaks, punctuation) — raw ASR output needs post-processing
- Summary / key points (gated, off by default) — Apple Notes iOS 26 has this natively
- Note saved to the right place (auto-classification) — the core differentiator but also table stakes baseline
- Searchable transcript text — Obsidian handles this natively via full-text Markdown search
- Offline operation — lecture halls have poor Wi-Fi; no network calls in core path

**Should have (differentiators):**
- **Schedule-aware course classification** — THE moat; no competitor does this
- Manual course picker fallback — graceful degradation when classification fails
- RAM-conscious model management (one heavy model at a time) — no competitor needs this; unibrain does
- YAML frontmatter metadata — Obsidian plugins and Dataview consume it
- macOS menu-bar quick record — best UX for the MacBook use case (one click to start)
- Multi-term support — `{term}/{course-code}/` folder structure
- Privacy by architecture — lecture content never leaves Angelica's devices

**Defer (v2+):**
- Audio-transcript playback sync (word-level timestamps) — Phase 2
- iOS Action Button / Lock Screen shortcut — Phase 2
- Hands-free bookmark during recording — Phase 2
- Local embeddings + semantic search — Phase 2
- Quiz generation / flashcards (FSRS) — Phase 2
- PDF / whiteboard photo OCR (Vision framework) — Phase 2
- Hermes daily-ingest QA + Study Pack Discord jobs — Phase 2+

### Architecture Approach

The architecture is a three-layer cake: (1) a thin SwiftUI app shell per platform (macOS menu bar + window, iOS capture-only), (2) a shared SPM library (`UnibrainCore`) containing all pipeline logic abstracted behind protocols, and (3) a platform-specific bridge layer (`UnibrainPlatform`) with concrete implementations guarded by `#if canImport()`. The pipeline itself is a five-stage actor-isolated state machine: CaptureEngine to TranscriptionEngine to CourseResolver to NoteNormalizer to VaultWriter, with an optional gated SummaryEngine. The PipelineOrchestrator actor serializes pipeline runs and enforces the one-heavy-model-at-a-time RAM discipline at the language level. iPhone captures audio and drops it into iCloud Drive; MacBook watches the inbox folder and runs the full pipeline.

**Major components:**
1. **PipelineOrchestrator (actor)** — sequences the five pipeline stages, enforces RAM budget, manages state machine (idle to capturing to transcribing to classifying to normalizing to writing to summarizing to completed)
2. **CaptureEngine / TranscriptionEngine / CourseResolver / NoteNormalizer / VaultWriter / SummaryEngine** — protocol-abstracted pipeline steps; each has a mock for Linux testing and a concrete `#if os()` implementation for macOS/iOS
3. **VaultWriter** — atomic writes (`Data.write(to:options:.atomic)`) + `NSFileCoordinator` for iCloud safety; schema-versioned YAML frontmatter from Day 1
4. **SessionStore (SwiftData)** — persists in-progress recording sessions and pipeline history; survives app backgrounding and crashes

### Critical Pitfalls

1. **whisper.cpp `whisper_full()` blocks the MainActor** — use `Task.detached` (NOT `Task`) or GCD global queue to escape the main actor; this is a Day-1 architecture decision in the transcription service layer, verified via Xcode Time Profiler showing `whisper_full` off MainThread
2. **whisper.cpp + Ollama simultaneously exhausts 8GB unified memory** — enforce a strict one-heavy-model-at-a-time policy via a `ModelLoadGate` actor; never auto-trigger summarization while transcription is running; call `whisper_free()` before loading Ollama; use `llama-3.2-3b` (not 7B)
3. **EventKit permission silently degrades to Write-Only (Add-Only) on iOS 17+** — use `requestFullAccessToEvents()` (not deprecated `requestAccess(to:)`); check `authorizationStatus` returns `.fullAccess` not `.writeOnly`; show clear in-app UI with Settings deep-link if denied; provide manual course picker fallback
4. **iOS background audio recording gets silently killed mid-lecture** — enable Background Modes `audio`; configure `.playAndRecord` session BEFORE starting recorder; write audio to disk incrementally (not just in memory); observe interruption notifications; prefer MacBook as primary recording device
5. **Writing Swift blind from WSL2 — Apple frameworks do not exist on Linux** — architect as layered cake: platform-agnostic core (Foundation only) + thin Apple shell; use `#if canImport()` guards; define protocols for all platform-specific capabilities; run `swift test` on WSL2 for core logic; run macOS CI for integration tests
6. **GitHub Actions macOS runner free-tier burn-through** — private repos get ~200 effective macOS minutes/month (10x multiplier); use a PUBLIC repo for unlimited free macOS CI; cache SPM + selective DerivedData; trigger CI on PRs to main + nightly only, not every push
7. **Free Apple Developer account blocks TestFlight and remote crash logs** — budget $99/year for Apple Developer Program membership; it is the single highest-ROI spend for this project (unlocks TestFlight, 1-year profiles, remote crash collection); without it, build an in-app crash logger

## Implications for Roadmap

Based on research, the research files converge on a clear phase sequence. STACK.md says macOS-first (iPhone is a capture surface, MacBook is the compute device). ARCHITECTURE.md says pure-logic Phase 1 first (testable on WSL2 without a Mac), then macOS vertical slice, then classification, then iOS, then gated summary. PITFALLS.md says Phase 0 Foundation is mandatory (layered architecture + CI caching + Apple Developer account decision must be settled before any feature code). The reconciliation is a six-phase structure: Phase 0 Foundation, then Phase 1 Pure Logic, then the MVP phases.

### Phase 0: Foundation (Architecture + CI + Developer Setup)

**Rationale:** PITFALLS.md is explicit — the layered architecture, CI caching strategy, and Apple Developer membership decision must be settled before any feature code. ARCHITECTURE.md confirms the protocol boundaries and project structure must exist first. Getting this wrong means every subsequent phase pays a tax.
**Delivers:** SPM package structure (`UnibrainCore` + `UnibrainPlatform` + app targets), protocol definitions for all six pipeline steps, GitHub Actions workflow with SPM caching, public repo decision, Apple Developer membership purchase, `swift test` passing on WSL2 with empty stubs.
**Addresses:** Project foundation requirements (build/test via GitHub Actions macOS CI).
**Avoids:** Pitfall 6 (Swift blind from WSL2), Pitfall 7 (GitHub Actions minute burn), Pitfall 8 (TestFlight limitation).

### Phase 1: Pure Pipeline Logic (WSL2-Testable)

**Rationale:** ARCHITECTURE.md is unequivocal — build and test all pipeline logic with mocks on the Linux Swift toolchain before touching any Apple framework. This is the only phase fully runnable from WSL2 without a Mac round-trip. Establishes the protocol contracts that platform implementations must satisfy.
**Delivers:** `NoteNormalizer` + `FrontmatterSchema` (pure string building), `CourseResolver` protocol + mock, `VaultWriter` logic (temp-dir based), `PipelineOrchestrator` state machine with all-mock dependencies, `PipelineState` enum + transitions. Full test coverage on Linux.
**Addresses:** Core value loop scaffolding (classification logic, note formatting, vault write-out).
**Avoids:** Pitfall 6 (untestable code) — every line of business logic is testable from WSL2.

### Phase 2: macOS Capture + Transcribe (Vertical Slice)

**Rationale:** This is the minimal end-to-end pipeline. Proves the whisper.cpp integration, the actor-based orchestration, the Metal acceleration, and the vault write-out. STACK.md recommends macOS-first because the MacBook is the compute device. ARCHITECTURE.md calls this the "minimal end-to-end pipeline." Write to a hardcoded vault path first — no course resolution yet.
**Delivers:** `AudioRecorder` (AVAudioRecorder, macOS), `WhisperEngine` (whisper.cpp xcframework + Metal), `Task.detached` threading model, minimal macOS menu bar UI (Record / Stop / Status), note written to a single hardcoded folder.
**Addresses:** Audio capture (macOS), local transcription, Obsidian write-out, 8GB RAM discipline (model loaded only at inference time, released immediately).
**Avoids:** Pitfall 1 (MainActor blocking — use `Task.detached` from Day 1), Pitfall 2 (RAM exhaustion — `ModelLoadGate` actor enforces one model at a time), Pitfall 9 (whisper.cpp Metal SPM build failure — use SwiftWhisper, verify model checksum).

### Phase 3: Course Classification + Smart Routing

**Rationale:** This is the feature that makes the app actually useful — the core value proposition. FEATURES.md identifies schedule-aware course classification as THE competitive moat. ARCHITECTURE.md places it after Phase 2 because classification is meaningless without a working pipeline to attach to. Once Phase 2 works, this is what justifies the app over Apple Notes.
**Delivers:** `EventKitResolver` (EKEventStore with `requestFullAccessToEvents`), `Course` model + folder mapping, `VaultPathResolver` (course to vault folder), manual course picker fallback UI, permission flow with `.fullAccess` verification + Settings deep-link, multi-term folder structure.
**Addresses:** Course classification via Apple Calendar, auto-populated frontmatter, multi-term support, graceful degradation.
**Avoids:** Pitfall 3 (EventKit Write-Only degradation — verify `.fullAccess`, provide manual fallback).

### Phase 4: iOS Capture + iCloud Handoff

**Rationale:** iPhone is the realistic in-class recording device (more discreet than opening a MacBook). ARCHITECTURE.md places this after the macOS pipeline is proven. iPhone records and syncs via iCloud Drive; MacBook watches the inbox folder and runs the full pipeline. This is an entire second app target + cross-device coordination.
**Delivers:** iOS app target (SwiftUI capture UI), SwiftData session persistence, iCloud Drive write from iOS, macOS folder watcher for `_inbox/`, background recording support (Background Modes `audio`), incremental-to-disk audio writing, crash recovery flow for killed sessions.
**Addresses:** Audio capture (iOS), iPhone-to-MacBook handoff.
**Avoids:** Pitfall 4 (iOS background kill — incremental-to-disk writing, interruption handling, recovery flow), Pitfall 5 (iCloud `.icloud` placeholders — check download status, trigger download if needed).

### Phase 5: Gated Summarization + MVP Polish

**Rationale:** Summarization is explicitly optional and gated. The core value loop (record to classify to write) does not depend on it. FEATURES.md lists it as "MVP Should Include if time permits." Ship the core loop first, layer summarization on top. This phase also includes the polish features (menu-bar quick record, settings surface, onboarding flow) that make the app feel complete.
**Delivers:** `OllamaEngine` (HTTP client to localhost:11434), RAM discipline enforcement (whisper model released before Ollama load), Settings UI (vault path, model selection, summary toggle), summary section template, onboarding flow (permissions + vault picker + term label), in-app crash logger (if not on paid Apple Developer account).
**Addresses:** Gated summarization, 8GB RAM discipline (full enforcement), settings surface, onboarding.
**Avoids:** Pitfall 2 (sequential gating — whisper_free before Ollama load, verified via `memory_pressure`), Pitfall 8 (crash logging — in-app logger as fallback).

### Phase Ordering Rationale

- **Phase 0 before Phase 1:** Architecture and CI must exist before any feature code. PITFALLS.md is explicit that retrofitting cross-platform structure onto a mixed-concern codebase is a HIGH-cost recovery.
- **Phase 1 before Phase 2:** Pure logic must be testable from WSL2 before touching Apple frameworks. This is the single dev-workflow decision that makes the WSL2-without-Mac constraint survivable.
- **Phase 2 before Phase 3:** The pipeline must work end-to-end (even with a hardcoded folder) before adding the classification intelligence that makes it useful. Proving the whisper.cpp + Metal + actor integration is the riskiest technical step.
- **Phase 3 before Phase 4:** The macOS pipeline must be fully working before adding a second app target + cross-device coordination. iPhone is a capture surface, not a compute device.
- **Phase 4 before Phase 5:** Summarization is gated and optional. The core loop (record to classify to write) ships first. Summarization layers on top of a proven pipeline.
- **Grouping logic:** Phases 0-1 are infrastructure. Phases 2-3 are the macOS MVP (record to classify to write). Phase 4 adds the iPhone capture surface. Phase 5 adds the optional LLM layer and polish.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 0:** GitHub Actions macOS CI caching strategy (SPM cache + selective DerivedData) — needs a working `.github/workflows/ci.yml` with verified cache keys; the public-vs-private repo decision affects minute economics
- **Phase 2:** whisper.cpp + Metal SPM integration — SwiftWhisper vs official whisper.cpp SPM package; Metal shader compilation in SPM; model file download + SHA256 verification pipeline; `Task.detached` threading verification via Xcode Time Profiler
- **Phase 3:** EventKit permission flow on real devices — `.fullAccess` vs `.writeOnly` behavior varies by iOS version; iOS 18 bug where events disappear after OS update; manual course picker UX design

Phases with standard patterns (skip research-phase):
- **Phase 1:** Pure Swift logic with mocks — well-documented testing patterns; no external dependencies beyond Foundation
- **Phase 4:** AVAudioRecorder + iCloud Drive file drop — standard Apple APIs with extensive documentation
- **Phase 5:** Ollama HTTP API — stable, well-documented REST API; simple URLSession client

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core stack (Swift/SwiftUI/AVFoundation/EventKit/Yams) verified against official Apple docs. whisper.cpp + Metal verified against GitHub repo and multiple benchmarks. Ollama HTTP API verified against official docs. Version requirements cross-checked. |
| Features | MEDIUM | Competitive analysis sourced from vendor sites and community blogs. Apple Notes iOS 26 threat is real but device OS version unconfirmed. The moat (schedule-aware classification) is clearly differentiated. |
| Architecture | HIGH | Protocol-abstracted pipeline + actor-isolated orchestrator is a well-established Swift pattern. Cross-platform SPM structure verified against Apple docs and community guides. iCloud Drive file drop pattern is standard. |
| Pitfalls | MEDIUM | HIGH confidence for licensing, GitHub Actions billing, and Swift-on-Linux constraints (verified against official docs). MEDIUM for performance claims (whisper.cpp RAM footprint, Ollama memory pressure, Metal speedup) based on community benchmarks rather than in-house testing on Angelica's exact hardware. |

**Overall confidence:** HIGH

### Gaps to Address

- **Angelica's device OS versions unconfirmed:** If MacBook Air is on macOS 26 / iOS 26, Apple SpeechAnalyzer becomes a viable primary ASR path (faster, native, eliminates whisper.cpp's ~852 MB RAM footprint). Decision deferred until OS confirmed. Must verify during Phase 0 or early Phase 2.
- **whisper.cpp `small.en` accuracy on technical/academic content unverified:** Benchmarks are general-purpose. Lecture content (accented speech, technical terms, long-form) may require `medium.en` (~2.1 GB RAM) or post-processing correction. Test during Phase 2 with real lecture audio.
- **Ollama `llama-3.2-3b` summarization quality unverified:** Summary quality for lecture-specific content (key concepts, definitions) needs prompt engineering iteration. Test during Phase 5.
- **iCloud Drive sync reliability for Obsidian vault:** Real-world sync conflict frequency and `.icloud` placeholder eviction behavior need validation on Angelica's actual devices. Test during Phase 4.
- **GitHub Actions macOS queue times:** If queue times exceed 10 minutes during active development, consider Depot.dev ($0.08/min) or self-hosted runner. Monitor from Phase 0 onward.
- **Angelica's vault topology assumption unconfirmed:** PROJECT.md assumes a separate vault on her MacBook Air, synced via iCloud Drive. This has not been explicitly confirmed by Greg. Verify before Phase 1.

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation](https://developer.apple.com/documentation/) — AVAudioRecorder, EventKit/EKEventStore, SwiftUI multiplatform, BackgroundTasks, Swift Packages
- [WWDC23 Session 10052](https://developer.apple.com/videos/play/wwdc2023/10052/) — Calendar access level changes (iOS 17+)
- [WWDC25 Session 277](https://developer.apple.com/videos/play/wwdc2025/277/) — SpeechAnalyzer API (iOS 26)
- [WWDC25 Session 251](https://developer.apple.com/videos/play/wwdc2025/251/) — Audio recording improvements
- [whisper.cpp (ggml-org)](https://github.com/ggml-org/whisper.cpp) — ASR engine, model sizes, Metal/CoreML support
- [Ollama API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md) — HTTP API spec, keep_alive parameter
- [Yams on Swift Package Index](https://swiftpackageindex.com/jpsim/Yams) — v6.2.2 YAML library
- [GitHub Actions Billing](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions) — macOS runner pricing, free tier
- [Apple: Compare Developer Memberships](https://developer.apple.com/support/compare-memberships/) — Free vs paid account features

### Secondary (MEDIUM confidence)
- [SwiftWhisper (exPHAT) on Swift Package Index](https://swiftpackageindex.com/exPHAT/SwiftWhisper) — SPM whisper.cpp wrapper
- [whisper.cpp Benchmark on Mac (getspeakup.app)](https://getspeakup.app/blog/whisper-cpp-benchmark-mac/) — Metal 4.4x speedup metrics
- [Whisper Model Sizes Explained (openwhispr.com)](https://openwhispr.com/blog/whisper-model-sizes-explained) — RAM/disk metrics per model
- [Building a 100% Local Meeting Transcription App for macOS](https://dev.to/thehwang/building-a-100-local-meeting-transcription-app-for-macos-with-whispercpp-and-screencapturekit-33m7) — Practical whisper.cpp integration guide
- [Otter.ai](https://otter.ai/) — Competitive feature benchmark
- [Apple Newsroom: Apple Intelligence expansion](https://www.apple.com/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/) — Apple Notes iOS 26 transcription + summary
- [In-Depth Guide to iCloud Documents (fatbobman)](https://fatbobman.com/en/posts/in-depth-guide-to-icloud-documents/) — iCloud Drive sync patterns
- [Problematic Swift Concurrency Patterns (Matt Massicotte)](https://www.massicotte.org/problematic-patterns/) — Actor isolation pitfalls
- [whisper.cpp issue #2310](https://github.com/ggml-org/whisper.cpp/issues/2310) — Memory consumption on 8GB systems
- [8GB Mac Local AI Survival Guide](https://localllmsetup.com/blog/8gb-mac-local-ai-survival-guide) — Swap death mitigation
- [Obsidian Forum: iCloud sync issues](https://forum.obsidian.md/t/icloud-sync-issues/28320) — Real-world sync conflicts

### Tertiary (LOW confidence)
- [Plaud NotePin to Obsidian workflow (Reddit)](https://www.reddit.com/r/PLAUDAI/comments/1o1fg87/) — Hardware capture + Obsidian export precedent
- [Lock Screen Shortcut widget (vendor)](https://recorderplus.com/?ht_kb=start-recording) — Lock screen recording patterns
- [whisper.cpp vs faster-whisper 2026 (promptquorum)](https://www.promptquorum.com/power-local-llm/local-whisper-stt-comparison-2026) — Speed benchmarks, needs validation on target hardware

---
*Research completed: 2026-07-13*
*Ready for roadmap: yes*
