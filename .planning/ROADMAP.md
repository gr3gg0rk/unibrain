# Roadmap: unibrain

## Overview

A six-phase journey from foundation to a shipping local-first lecture capture app. Phase 1 lays the SPM architecture, provider-protocol layer, and macOS CI that make WSL2 development survivable. Phase 2 builds the pure pipeline logic (Normalizer, Orchestrator, FrontmatterSchema) fully testable on Linux. Phase 3 delivers the first end-to-end vertical slice on macOS: record, transcribe with whisper.cpp+Metal, write a note. Phase 4 adds the competitive moat — schedule-aware course classification via EventKit. Phase 5 adds the iPhone capture surface with iCloud handoff and full onboarding. Phase 6 layers on gated summarization, all four cloud providers, and the consent/audit/settings infrastructure that completes the MVP.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - SPM architecture, provider protocols, macOS CI, ModelLoadGate, Yams, Apple Dev decision
- [ ] **Phase 2: Pure Pipeline Logic** - WSL2-testable core: FrontmatterSchema, Normalizer, Orchestrator, atomic-write helpers, CourseClassifier pure logic
- [ ] **Phase 3: macOS Capture + Transcribe** - First end-to-end vertical slice: AVFoundation record, whisper.cpp+Metal, hardcoded-folder write-out
- [ ] **Phase 4: Course Classification + Smart Routing** - The moat: EventKit calendar-to-course mapping, manual picker fallback, multi-term folders
- [ ] **Phase 5: iOS Capture + iCloud Handoff + Onboarding** - Second capture surface: iOS background recording, iCloud Drive handoff, full onboarding flow
- [ ] **Phase 6: Gated Summarization + Cloud Providers + MVP Polish** - Ollama local summary, four cloud providers, Keychain keys, per-document consent, audit trail, Settings UI

## Phase Details

### Phase 1: Foundation

**Goal**: The architectural bedrock (SPM layered cake, protocol-abstraction layer for all four inference modalities, macOS CI with caching, the ModelLoadGate actor that enforces 8GB RAM discipline, Yams for YAML, and the Apple Developer Program decision) exists and builds green before any feature code.
**Mode**: mvp
**Depends on**: Nothing (first phase)
**Requirements**: FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, DISC-01, DISC-02, DISC-03
**Success Criteria** (what must be TRUE):

  1. `swift build` succeeds on WSL2 Linux for the `UnibrainCore` library target (Foundation-only, no Apple frameworks)
  2. `swift test` passes on WSL2 Linux with stub/mock protocol implementations — the pure-logic test harness is proven
  3. GitHub Actions macOS CI (`macos-15` runner) builds the SPM package and runs tests on every push to main, with SPM cache and DerivedData cache verified as hits on the second run
  4. The four provider protocols (`LLMSummarizer`, `AudioTranscriber`, `VisionDescriber`, `AudioSynthesizer`) compile behind `#if canImport()` guards and the `ModelLoadGate` actor enforces one-heavy-local-model-at-a-time in a unit test
  5. The Apple Developer Program decision (paid $99/yr vs free) is documented in PROJECT.md Key Decisions with the chosen rationale

**Plans**: 4/4 plans executed
**Wave 1**

- [x] 01-01-PLAN.md — Swift 6.0.x toolchain install, Package.swift, .gitignore, all source scaffolds and test stubs (Wave 0)
- [x] 01-02-PLAN.md — ModelLoadGate deny-on-conflict implementation with comprehensive tests (Wave 1)
- [x] 01-03-PLAN.md — FrontmatterSchema Yams round-trip tests, provider protocol mock tests, GitHub Actions CI workflow (Wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 01-04-PLAN.md — PROJECT.md Key Decisions update, Xcode app shell, SKELETON.md, phase verification checkpoint (Wave 2)

### Phase 2: Pure Pipeline Logic

**Goal**: Every line of business logic that can be expressed without Apple frameworks is written, tested, and green on WSL2 Linux — the FrontmatterSchema, NoteNormalizer, VaultWriter atomic-write logic, CourseClassifier pure matching logic, and the PipelineOrchestrator state machine with all-mock dependencies — establishing the protocol contracts that platform implementations must satisfy.
**Mode**: mvp
**Depends on**: Phase 1
**Requirements**: WRITE-01, WRITE-02, WRITE-03, WRITE-04, WRITE-05, WRITE-06
**Success Criteria** (what must be TRUE):

  1. A unit test on Linux feeds a mock transcript + mock course to `NoteNormalizer` and the output Markdown matches the expected frontmatter schema (all WRITE-02 fields present, correct YAML, schema_version: 1) and references the audio file via Obsidian wiki-link syntax
  2. A unit test on Linux writes a note via `VaultWriter` to a temp directory using `.atomic` flag and `NSFileCoordinator`-equivalent coordination abstraction, and the file round-trips (read-back content matches)
  3. A unit test on Linux simulates a `.icloud` placeholder file and verifies `VaultWriter` detects and skips it gracefully (WRITE-05)
  4. A unit test on Linux forces a write failure and verifies a clear error type is surfaced (WRITE-06) — no silent swallow
  5. The `PipelineOrchestrator` state machine unit test (all-mock dependencies) walks through idle -> transcribing -> classifying -> normalizing -> writing -> completed transitions and rejects a second concurrent run

**Plans**: 1/4 plans executed

**Wave 1** (parallel, no dependencies)

- [x] 02-01-PLAN.md — Note shape contract: NormalizedNote, NoteNormalizer, FrontmatterSchema validation (Wave 1)
- [ ] 02-02-PLAN.md — Atomic write contract: NoteWriter protocol, NoteWriterError, TestNoteWriter (Wave 1)
- [ ] 02-03-PLAN.md — Classification pure logic: CalendarEvent, CourseClassifier, FolderNameSanitizer (Wave 1)

**Wave 2** (blocked on Wave 1 completion)

- [ ] 02-04-PLAN.md — Orchestrator integration: PipelineState, PipelineInputs, PipelineOrchestrator actor (Wave 2)

### Phase 3: macOS Capture + Transcribe

**Goal**: A user can record a lecture on a MacBook NEO via the menu-bar record button, stop it, and within minutes see a transcript written as a Markdown note into a hardcoded vault folder — proving the whisper.cpp+Metal integration, the Task.detached threading model, the RAM discipline (model loaded only at inference time then released), and the end-to-end pipeline on macOS.
**Mode**: mvp
**Depends on**: Phase 2
**Requirements**: CAPT-01, CAPT-02, CAPT-04, CAPT-05, CAPT-06, TRAN-01, TRAN-02, TRAN-03, TRAN-04, TRAN-05, TRAN-06
**Success Criteria** (what must be TRUE):

  1. User clicks the menu-bar record button on macOS and sees a live timer + waveform + mic-level meter confirming the lecturer is audible (CAPT-01, CAPT-04, CAPT-05)
  2. User can pause and resume a recording; the final `.m4a` (AAC) file is contiguous with pause/resume timestamps preserved (CAPT-02, CAPT-06)
  3. User stops a 10-minute recording and a transcript appears in a Markdown note in the (hardcoded) vault folder within 5 minutes of stopping (TRAN-01, TRAN-04)
  4. During transcription the UI stays responsive (menu bar interactive, no beachball) — Xcode Time Profiler on macOS CI confirms `whisper_full` runs off MainThread (TRAN-03)
  5. After transcription completes, the whisper.cpp model is released from memory (Activity Monitor / `memory_pressure` confirms return to baseline) and the transcript is post-processed into paragraphs by segment time gaps (TRAN-05, TRAN-06); the `small.en` model was downloaded on first run with checksum verification (TRAN-02)

**Plans**: TBD
**UI hint**: yes

### Phase 4: Course Classification + Smart Routing

**Goal**: Every recording auto-routes to the correct course folder based on the student's Apple Calendar schedule — the competitive moat — with a manual picker fallback when classification is ambiguous, multi-term folder structure, and the current-term filter that keeps past-term noise out of matching.
**Mode**: mvp
**Depends on**: Phase 3
**Requirements**: CLAS-01, CLAS-02, CLAS-03, CLAS-04, CLAS-05, CLAS-06, CLAS-07, ONBD-02, ONBD-03
**Success Criteria** (what must be TRUE):

  1. User starts a recording during a scheduled lecture and the resulting note lands in `{vault}/{term}/{course-code}/YYYY-MM-DD-{COURSE}-Lecture.md` automatically (CLAS-01, CLAS-02, CLAS-05)
  2. When the user denies calendar Full Access (or only Write-Only is granted), the app degrades gracefully: a clear in-app explanation with a Settings deep-link is shown AND a manual course picker (recent courses + search) lets the user pick the right destination (ONBD-02, ONBD-03, CLAS-04)
  3. An unrecognized calendar event title triggers auto-creation of a sanitized course folder rather than dropping the recording (CLAS-03)
  4. Setting a "Current term" label filters out past-term calendar events from classification — a recording made during an old-term timeslot does not route to a past-term folder (CLAS-06)
  5. When the user manually picks a course for a recording, that override is remembered for the next recording of the same course (CLAS-07)

**Plans**: TBD
**UI hint**: yes

### Phase 5: iOS Capture + iCloud Handoff + Onboarding

**Goal**: The student can record on iPhone (the discreet in-class device), the audio syncs to the MacBook via iCloud Drive for transcription, AND the first-run onboarding flow (welcome -> vault picker -> mic permission -> calendar permission -> current-term label -> ready) is complete so a fresh install is usable without manual configuration.
**Mode**: mvp
**Depends on**: Phase 4
**Requirements**: CAPT-03, ONBD-01, ONBD-04, ONBD-05, DISC-04
**Success Criteria** (what must be TRUE):

  1. User starts a recording on iPhone, locks the screen, waits 30 minutes, unlocks — the recording continued in the background and the audio file is intact on disk (CAPT-03, DISC-04)
  2. Audio recorded on iPhone appears in the macOS `_inbox/` folder via iCloud Drive sync, and the MacBook pipeline picks it up and processes it (transcribe -> classify -> write) without user intervention
  3. A first-run user walks through the onboarding flow (welcome -> vault folder picker suggesting iCloud Drive -> mic permission -> calendar permission -> current-term label -> ready) and reaches the main app ready to record (ONBD-01, ONBD-04)
  4. The user can re-open the permissions screen post-onboarding to audit or re-grant mic/calendar access (ONBD-05)

**Plans**: TBD
**UI hint**: yes

### Phase 6: Gated Summarization + Cloud Providers + MVP Polish

**Goal**: Summarization (local Ollama, off by default) and the four cloud providers (OpenAI, Anthropic, Grok, Z.ai) are selectable per modality in Settings, API keys live in Keychain/Secure Enclave, every cloud call has a first-use consent gate and audit trail, and the app is polished to MVP-ship quality with zero telemetry.
**Mode**: mvp
**Depends on**: Phase 5
**Requirements**: SUMM-01, SUMM-02, SUMM-03, SUMM-04, SUMM-05, SUMM-06, SUMM-07, CLOUD-01, CLOUD-02, CLOUD-03, CLOUD-04, CLOUD-05, CLOUD-06, CLOUD-07, CLOUD-08, CLOUD-09, CLOUD-10, CLOUD-11, CLOUD-12, CLOUD-13, DISC-05, DISC-06
**Success Criteria** (what must be TRUE):

  1. User opts in to summarization in Settings; a transcripted note gets a 5-8 bullet "## Summary" section generated by Ollama `llama-3.2-3b` (keep_alive: 0) appended to the same file, and "Regenerate Summary" re-runs on the possibly-edited transcript replacing only that section (SUMM-01..06)
  2. The ModelLoadGate actor refuses to start an Ollama summarization while whisper.cpp ASR is loaded (SUMM-07, DISC-01 enforcement verified)
  3. In Settings the user sees per-modality provider selectors (LLM / ASR / Vision / TTS each settable to Local / Off / a configured cloud provider); Local is the default on first launch; adding a provider requires entering an API key which is stored in Keychain (macOS) or Secure Enclave (iOS) and never written to plaintext config (CLOUD-01, CLOUD-02, CLOUD-07)
  4. The first time the user routes a recording through a cloud provider per modality, a consent dialog appears ("Allow OpenAI to transcribe this recording?" with "Always allow" toggle); the resulting note's frontmatter records `provider_used` (CLOUD-08, CLOUD-13); a cloud failure surfaces a clear error with retry/fallback-to-local (CLOUD-10, CLOUD-11)
  5. The app's only outbound network traffic is user-initiated inference calls — zero telemetry, zero analytics, zero phone-home verified by network inspection; the full local-first path (capture -> classify -> transcribe -> write) works offline by default (CLOUD-12, DISC-05, DISC-06)

**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete    | 2026-07-14 |
| 2. Pure Pipeline Logic | 1/4 | In Progress|  |
| 3. macOS Capture + Transcribe | 0/0 | Not started | - |
| 4. Course Classification + Smart Routing | 0/0 | Not started | - |
| 5. iOS Capture + iCloud Handoff + Onboarding | 0/0 | Not started | - |
| 6. Gated Summarization + Cloud Providers + MVP Polish | 0/0 | Not started | - |
